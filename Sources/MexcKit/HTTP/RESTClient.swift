import Foundation

/// Reads the credentials for each private request, so a rotated key is picked up without a new client.
typealias CredentialsProvider = @Sendable () async throws -> MexcCredentials

/// Sends ``Endpoint``s to MEXC's REST API.
///
/// Each request's bytes are built once: the query or body that is signed is the one that is sent.
struct RESTClient: Sendable {
    let baseURL: URL
    let transport: any HTTPTransport
    let credentials: CredentialsProvider?
    let clock: ServerClock
    let receiveWindow: Duration?
    let language: String?
    let timeout: Duration

    /// Sends the endpoint's request and decodes the `data` of its response.
    ///
    /// Throws ``MexcFutures/ClientError`` with ``MexcFutures/ClientError/Reason/missingCredentials``
    /// before sending a private request without credentials, and ``MexcError`` for a failure MEXC
    /// reports.
    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let request = try await request(for: endpoint)
        let response = try await transport.send(request)
        return try await Envelope.data(Response.self, from: response)
    }

    /// The exact request ``send(_:)`` sends for the endpoint.
    func request<Response>(for endpoint: Endpoint<Response>) async throws -> TransportRequest {
        var query = ""
        var body: Data?
        let signedParameters: String
        var contentType = "application/json"
        switch endpoint.content {
        case .query(let parameters, let commaSigning):
            let queryString = QueryString(parameters)
            query = queryString.encoded
            signedParameters = queryString.signed(commaSigning)
        case .body(.json(let value)):
            let encoded = try JSONEncoder.requestBody.encode(value)
            body = encoded
            signedParameters = String(decoding: encoded, as: UTF8.self)
        case .body(.empty):
            signedParameters = ""
        case .body(.emptyForm):
            signedParameters = ""
            contentType = "application/x-www-form-urlencoded"
        }

        var headers = [TransportRequest.Header(name: "Content-Type", value: contentType)]
        if let language {
            headers.append(.init(name: "Language", value: language))
        }
        if case .signed = endpoint.authentication {
            headers += try await signature(for: signedParameters)
        }
        return TransportRequest(
            method: endpoint.method, url: url(path: endpoint.path, query: query), headers: headers, body: body,
            timeout: timeout
        )
    }

    /// The base URL with the path, each of its segments percent-encoded, and the encoded query.
    private func url(path: String, query: String) -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            preconditionFailure("Not a URL with components: \(baseURL)")
        }
        let basePath = components.percentEncodedPath.hasSuffix("/")
            ? String(components.percentEncodedPath.dropLast())
            : components.percentEncodedPath
        let segments = path.split(separator: "/", omittingEmptySubsequences: false).map { String($0).percentEncoded }
        components.percentEncodedPath = basePath + segments.joined(separator: "/")
        components.percentEncodedQuery = query.isEmpty ? nil : query
        // Every part is percent-encoded and the base came from a URL, so the result is a URL.
        guard let url = components.url else {
            preconditionFailure("Not a URL: \(components)")
        }
        return url
    }

    /// The headers that authenticate a private request whose signed parameters are `parameters`.
    private func signature(for parameters: String) async throws -> [TransportRequest.Header] {
        guard let credentials else {
            throw MexcFutures.ClientError(.missingCredentials)
        }
        let signer = RequestSigner(credentials: try await credentials())
        let requestTime = String(await clock.now().millisecondsSince1970)
        var headers: [TransportRequest.Header] = [
            .init(name: "ApiKey", value: signer.credentials.apiKey),
            .init(name: "Request-Time", value: requestTime),
            .init(name: "Signature", value: signer.signature(requestTime: requestTime, parameters: parameters)),
        ]
        if let receiveWindow {
            headers.append(.init(name: "Recv-Window", value: String(receiveWindow.milliseconds)))
        }
        return headers
    }
}

extension Date {
    /// Whole milliseconds since 1970, rounded down.
    var millisecondsSince1970: Int64 { Int64((timeIntervalSince1970 * 1000).rounded(.down)) }
}

extension Duration {
    /// Whole milliseconds, rounded toward zero.
    fileprivate var milliseconds: Int64 {
        let (seconds, attoseconds) = components
        return seconds * 1000 + attoseconds / 1_000_000_000_000_000
    }
}
