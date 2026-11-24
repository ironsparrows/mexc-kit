import Foundation

/// One REST endpoint call: what to send, whether to sign it, and what its `data` decodes to.
///
/// Domain conformers describe each call as an endpoint and hand it to ``RESTClient/send(_:)``.
struct Endpoint<Response: Decodable & Sendable>: Sendable {
    /// The path below the REST base URL, such as `/api/v1/contract/deals/BTC_USDT`, unencoded: each
    /// segment is percent-encoded when sent. Path parameters are part of it and are never signed.
    let path: String
    let authentication: Authentication
    let content: Content

    var method: TransportRequest.Method {
        switch content {
        case .query: .get
        case .body: .post
        }
    }

    /// A GET request. Parameters whose value is `nil` are neither sent nor signed.
    static func get(
        _ path: String, query: KeyValuePairs<String, String?> = [:], authentication: Authentication = .public,
        commaSigning: QueryString.CommaSigning = .encoded
    ) -> Self {
        let parameters = Dictionary(query.compactMap { name, value in value.map { (name, $0) } }) { _, last in last }
        return Self(path: path, authentication: authentication, content: .query(parameters, commaSigning))
    }

    /// A POST request. Every POST endpoint is private, so it is signed unless stated otherwise.
    static func post(_ path: String, _ body: Body = .empty, authentication: Authentication = .signed) -> Self {
        Self(path: path, authentication: authentication, content: .body(body))
    }
}

extension Endpoint {
    enum Authentication: Sendable {
        /// A public endpoint: the request carries no key or signature, and credentials aren't read.
        case `public`
        /// A private endpoint: the request carries `ApiKey`, `Request-Time` and `Signature`.
        case signed
    }

    /// What a request sends besides its path: GET query parameters, or a POST body.
    enum Content: Sendable {
        /// Sent and signed sorted by name.
        case query([String: String], QueryString.CommaSigning)
        case body(Body)
    }

    /// The body of a POST request.
    enum Body: Sendable {
        /// A JSON value, encoded once with ``JSONEncoder/requestBody``; the sent bytes are the signed
        /// bytes.
        case json(any Encodable & Sendable)
        /// No body. Signed as the empty string.
        case empty
        /// An empty form-encoded body, for the endpoint MEXC documents with
        /// `Content-Type: application/x-www-form-urlencoded` and only a path parameter. Signed as the
        /// empty string.
        case emptyForm
    }
}

extension JSONEncoder {
    /// Encodes request bodies with sorted keys, so the same request always produces the same bytes.
    static var requestBody: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
