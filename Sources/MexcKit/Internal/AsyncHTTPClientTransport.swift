import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1

/// Sends requests with AsyncHTTPClient, on every platform.
///
/// Network failures are thrown as ``MexcFutures/ClientError`` with ``MexcFutures/ClientError/Reason/timedOut``
/// or ``MexcFutures/ClientError/Reason/connectionFailed``, so apps never see AsyncHTTPClient's or
/// SwiftNIO's error types. `CancellationError` passes through.
struct AsyncHTTPClientTransport: HTTPTransport {
    var client: HTTPClient = .mexc
    /// The largest response body read. The full contract list, the largest response, is about 2 MB.
    var maximumResponseSize = 32 * 1024 * 1024

    func send(_ request: TransportRequest) async throws -> TransportResponse {
        var outgoing = HTTPClientRequest(url: request.url.absoluteString)
        outgoing.method = HTTPMethod(rawValue: request.method.rawValue)
        for header in request.headers {
            outgoing.headers.add(name: header.name, value: header.value)
        }
        if let body = request.body {
            outgoing.body = .bytes(body)
        }
        do {
            // AsyncHTTPClient's deadline ends when the response head arrives, so the body gets the
            // time that is left.
            let deadline = ContinuousClock.now + request.timeout
            let response = try await client.execute(outgoing, timeout: TimeAmount(request.timeout))
            let body = try await withDeadline(deadline) { [maximumResponseSize] in
                try await response.body.collect(upTo: maximumResponseSize)
            }
            return TransportResponse(status: Int(response.status.code), body: Data(body.readableBytesView))
        } catch {
            throw Self.clientError(for: error)
        }
    }

    /// The error apps see for an error AsyncHTTPClient or SwiftNIO threw.
    ///
    /// AsyncHTTPClient's timeouts become ``MexcFutures/ClientError/Reason/timedOut``; every other
    /// failure becomes ``MexcFutures/ClientError/Reason/connectionFailed``. Neither tells whether the
    /// request left the device: a deadline can pass while the request waits for a connection or while
    /// MEXC processes it.
    static func clientError(for error: any Error) -> any Error {
        switch error {
        case is CancellationError:
            error
        case let error as HTTPClientError where timeouts.contains(error):
            MexcFutures.ClientError(.timedOut, underlyingError: error)
        case is NIOTooManyBytesError:
            MexcFutures.ClientError(
                .connectionFailed, message: "The response is larger than the client reads", underlyingError: error
            )
        default:
            MexcFutures.ClientError(.connectionFailed, underlyingError: error)
        }
    }

    private static let timeouts: [HTTPClientError] = [
        .deadlineExceeded, .connectTimeout, .readTimeout, .writeTimeout, .tlsHandshakeTimeout,
        .getConnectionFromPoolTimeout, .socksHandshakeTimeout, .httpProxyHandshakeTimeout,
    ]
}

/// Runs `operation`, or throws `HTTPClientError.deadlineExceeded` once `deadline` passes.
private func withDeadline<Result: Sendable>(
    _ deadline: ContinuousClock.Instant, _ operation: @escaping @Sendable () async throws -> Result
) async throws -> Result {
    try await withThrowingTaskGroup(of: Result?.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(until: deadline, clock: .continuous)
            return nil
        }
        defer { group.cancelAll() }
        guard let result = try await group.next(), let result else {
            throw HTTPClientError.deadlineExceeded
        }
        return result
    }
}

extension HTTPClient {
    /// The client every ``MexcFutures/Client`` sends with.
    ///
    /// The shared client's settings, except that it never follows redirects, so a signed request
    /// never goes to another host or loses its method and body.
    static let mexc: HTTPClient = {
        var configuration = HTTPClient.Configuration.singletonConfiguration
        configuration.redirectConfiguration = .disallow
        return HTTPClient(eventLoopGroup: HTTPClient.defaultEventLoopGroup, configuration: configuration)
    }()
}
