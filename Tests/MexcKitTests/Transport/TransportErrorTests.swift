import AsyncHTTPClient
import Foundation
import NIOCore
import Testing

@testable import MexcKit

extension MexcKitTests {
    @Suite("Transport errors")
    struct TransportErrorTests {
        @Test(arguments: [
            HTTPClientError.deadlineExceeded, .connectTimeout, .readTimeout, .writeTimeout, .tlsHandshakeTimeout,
            .getConnectionFromPoolTimeout, .socksHandshakeTimeout, .httpProxyHandshakeTimeout,
        ])
        func `timeouts become timedOut`(error: HTTPClientError) throws {
            let mapped = try #require(AsyncHTTPClientTransport.clientError(for: error) as? MexcFutures.ClientError)
            #expect(mapped.reason == .timedOut)
            #expect(mapped.underlyingError as? HTTPClientError == error)
        }

        @Test(arguments: [
            HTTPClientError.remoteConnectionClosed, .cancelled, .invalidURL, .bodyLengthMismatch, .alreadyShutdown,
        ])
        func `other client errors become connectionFailed`(error: HTTPClientError) throws {
            let mapped = try #require(AsyncHTTPClientTransport.clientError(for: error) as? MexcFutures.ClientError)
            #expect(mapped.reason == .connectionFailed)
            #expect(mapped.underlyingError as? HTTPClientError == error)
        }

        @Test(
            arguments: [
                IOError(errnoCode: 61, reason: "connect"), ChannelError.ioOnClosedChannel, ChannelError.eof,
            ] as [any Error])
        func `NIO errors become connectionFailed`(error: any Error) throws {
            let mapped = try #require(AsyncHTTPClientTransport.clientError(for: error) as? MexcFutures.ClientError)
            #expect(mapped.reason == .connectionFailed)
        }

        #if canImport(Network)
        @Test(
            arguments: [
                HTTPClient.NWPOSIXError(.ENETDOWN, reason: "offline"), HTTPClient.NWTLSError(-9806, reason: "handshake"),
            ] as [any Error])
        func `Network framework errors become connectionFailed`(error: any Error) throws {
            let mapped = try #require(AsyncHTTPClientTransport.clientError(for: error) as? MexcFutures.ClientError)
            #expect(mapped.reason == .connectionFailed)
        }
        #endif

        @Test func `a response that is too large becomes connectionFailed with a message`() throws {
            let mapped = try #require(
                AsyncHTTPClientTransport.clientError(for: NIOTooManyBytesError(maxBytes: 10)) as? MexcFutures.ClientError
            )
            #expect(mapped.reason == .connectionFailed)
            #expect(mapped.message != nil)
        }

        @Test func `cancellation passes through`() {
            #expect(AsyncHTTPClientTransport.clientError(for: CancellationError()) is CancellationError)
        }
    }
}
