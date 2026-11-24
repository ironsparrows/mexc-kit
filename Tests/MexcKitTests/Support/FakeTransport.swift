import Foundation
import Testing
@testable import MexcKit

/// Records every request and answers each with the next scripted response.
actor FakeTransport: HTTPTransport {
    private(set) var requests: [TransportRequest] = []
    private var responses: [TransportResponse]

    init(responses: [TransportResponse] = []) {
        self.responses = responses
    }

    init(status: Int = 200, json: String) {
        self.init(responses: [TransportResponse(status: status, body: Data(json.utf8))])
    }

    /// A transport that answers with a recorded response from `Fixtures`, such as `"Market/ticker"`.
    init(fixture name: String) throws {
        let path = "Fixtures/" + name
        let url = try #require(Bundle.module.url(
            forResource: (path as NSString).lastPathComponent, withExtension: "json",
            subdirectory: (path as NSString).deletingLastPathComponent
        ))
        self.init(responses: [TransportResponse(status: 200, body: try Data(contentsOf: url))])
    }

    func send(_ request: TransportRequest) async throws -> TransportResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            Issue.record("No response scripted for \(request.url)")
            throw CancellationError()
        }
        return responses.removeFirst()
    }
}

extension RESTClient {
    /// A client with fixed test credentials and a local clock stopped at 1,700,000,000 s.
    static func test(
        transport: any HTTPTransport = FakeTransport(),
        credentials: CredentialsProvider? = { MexcCredentials(apiKey: "mx0testkey", secret: "testsecret") },
        receiveWindow: Duration? = nil,
        language: String? = nil
    ) -> RESTClient {
        RESTClient(
            baseURL: URL(string: "https://api.mexc.com")!,
            transport: transport,
            credentials: credentials,
            clock: ServerClock { Date(timeIntervalSince1970: 1_700_000_000) },
            receiveWindow: receiveWindow,
            language: language,
            timeout: .seconds(30)
        )
    }
}

extension TransportRequest {
    /// The request as text: the method and URL, one line per header, then the body after a blank line.
    var rendered: String {
        var lines = ["\(method.rawValue) \(url.absoluteString)"]
        lines += headers.map { "\($0.name): \($0.value)" }
        if let body {
            lines += ["", String(decoding: body, as: UTF8.self)]
        }
        return lines.joined(separator: "\n")
    }
}
