import Foundation

/// Sends one HTTP request and returns the whole response.
///
/// The seam between the request flow and the network: ``AsyncHTTPClientTransport`` sends over the
/// network, and tests substitute a fake that records requests and replays responses.
protocol HTTPTransport: Sendable {
    func send(_ request: TransportRequest) async throws -> TransportResponse
}

/// A request with its final bytes: the sorted, percent-encoded query, the headers including the
/// signature, and the body that was signed.
struct TransportRequest: Hashable, Sendable {
    var method: Method
    var url: URL
    var headers: [Header]
    var body: Data?
    /// How long the request may take, from sending to the last byte of the response.
    var timeout: Duration

    enum Method: String, Sendable {
        case get = "GET"
        case post = "POST"
    }

    struct Header: Hashable, Sendable {
        var name: String
        var value: String
    }
}

struct TransportResponse: Hashable, Sendable {
    var status: Int
    var body: Data
}
