import Foundation
import Testing
@testable import MexcKit

// Requests over real local HTTP through AsyncHTTPClient, so the bytes on the wire are checked, not
// only the requests handed to the transport. The signed requests go through the internal request
// flow, since no public private endpoint exists yet.
extension MexcKitTests {
    @Suite("Loopback")
    struct LoopbackTests {
        private static let testCredentials = MexcCredentials(apiKey: "mx0testkey", secret: "testsecret")
        private static let success = #"{"success":true,"code":0,"data":true}"#

        @Test func `synchronizing the clock asks MEXC for its time`() async throws {
            try await LoopbackServer.run(
                answering: .respond(status: 200, body: #"{"success":true,"code":0,"data":1795503909246}"#)
            ) { server in
                let client = MexcFutures.Client(configuration: .init(restURL: server.url))

                try await client.synchronizeClock()

                let request = try #require(await server.requests.first { _ in true })
                #expect(request.method == "GET")
                #expect(request.uri == "/api/v1/contract/ping")
                #expect(request.headers["Content-Type"] == "application/json")
                #expect(request.headers["ApiKey"] == nil)
            }
        }

        @Test func `a failure with HTTP 200 throws MexcError`() async throws {
            try await LoopbackServer.run(
                answering: .respond(status: 200, body: #"{"success":false,"code":510,"message":"Too frequent"}"#)
            ) { server in
                let client = MexcFutures.Client(configuration: .init(restURL: server.url))

                let error = try await #require(throws: MexcError.self) { try await client.synchronizeClock() }

                #expect(error.code == .tooFrequent)
                #expect(error.message == "Too frequent")
                #expect(error.httpStatus == 200)
            }
        }

        @Test func `an HTTP error without an envelope throws MexcError with the status`() async throws {
            try await LoopbackServer.run(answering: .respond(status: 502, body: "<html>Bad Gateway</html>")) { server in
                let client = MexcFutures.Client(configuration: .init(restURL: server.url))

                let error = try await #require(throws: MexcError.self) { try await client.synchronizeClock() }

                #expect(error.code.rawValue == 502)
            }
        }

        @Test func `a redirect isn't followed`() async throws {
            try await LoopbackServer.run(
                answering: .respond(status: 302, body: "", headers: ["Location": "http://127.0.0.1:1/elsewhere"])
            ) { server in
                let client = MexcFutures.Client(credentials: Self.testCredentials, configuration: .init(restURL: server.url))

                let error = try await #require(throws: MexcError.self) {
                    try await client.rest.send(Endpoint<Bool>.post("/api/v1/private/position/close_all"))
                }

                #expect(error.code.rawValue == 302)
                #expect(error.httpStatus == 302)
            }
        }

        @Test func `a signed POST sends the bytes it signed`() async throws {
            struct Body: Encodable, Sendable {
                var symbol = "BTC_USDT"
                var price = Decimal(string: "60000.5")!
                var vol = 1
            }
            try await LoopbackServer.run(answering: .respond(status: 200, body: Self.success)) { server in
                let client = MexcFutures.Client(
                    credentials: Self.testCredentials,
                    configuration: .init(restURL: server.url, receiveWindow: .seconds(5))
                )

                let accepted = try await client.rest.send(Endpoint<Bool>.post("/api/v1/private/order/create", .json(Body())))

                #expect(accepted)
                let request = try #require(await server.requests.first { _ in true })
                #expect(request.method == "POST")
                #expect(request.uri == "/api/v1/private/order/create")
                #expect(request.body == #"{"price":60000.5,"symbol":"BTC_USDT","vol":1}"#)
                #expect(request.headers["Content-Type"] == "application/json")
                #expect(request.headers["ApiKey"] == "mx0testkey")
                #expect(request.headers["Recv-Window"] == "5000")
                let requestTime = try #require(request.headers["Request-Time"])
                let signer = RequestSigner(credentials: Self.testCredentials)
                #expect(request.headers["Signature"] == signer.signature(requestTime: requestTime, parameters: request.body))
            }
        }

        @Test func `an empty form POST sends no body`() async throws {
            try await LoopbackServer.run(answering: .respond(status: 200, body: Self.success)) { server in
                let client = MexcFutures.Client(credentials: Self.testCredentials, configuration: .init(restURL: server.url))

                _ = try await client.rest.send(Endpoint<Bool>.post(
                    "/api/v1/private/multiAssets/changeMultiAssetMode/true", .emptyForm
                ))

                let request = try #require(await server.requests.first { _ in true })
                #expect(request.headers["Content-Type"] == "application/x-www-form-urlencoded")
                #expect(request.body.isEmpty)
                #expect(request.headers["Content-Length"] ?? "0" == "0")
            }
        }

        @Test func `a signed GET sends the sorted query it signed`() async throws {
            try await LoopbackServer.run(answering: .respond(status: 200, body: Self.success)) { server in
                let client = MexcFutures.Client(credentials: Self.testCredentials, configuration: .init(restURL: server.url))

                _ = try await client.rest.send(Endpoint<Bool>.get(
                    "/api/v1/private/order/batch_query", query: ["symbol": "BTC_USDT", "order_ids": "1,2"],
                    authentication: .signed
                ))

                let request = try #require(await server.requests.first { _ in true })
                #expect(request.uri == "/api/v1/private/order/batch_query?order_ids=1%2C2&symbol=BTC_USDT")
                let requestTime = try #require(request.headers["Request-Time"])
                let signer = RequestSigner(credentials: Self.testCredentials)
                #expect(request.headers["Signature"] == signer.signature(
                    requestTime: requestTime, parameters: "order_ids=1%2C2&symbol=BTC_USDT"
                ))
            }
        }

        @Test func `a request MEXC doesn't answer in time throws timedOut`() async throws {
            try await LoopbackServer.run(answering: .never) { server in
                let client = MexcFutures.Client(configuration: .init(restURL: server.url, timeout: .milliseconds(200)))

                let error = try await #require(throws: MexcFutures.ClientError.self) { try await client.synchronizeClock() }

                #expect(error.reason == .timedOut)
            }
        }

        @Test func `a body that stops arriving throws timedOut`() async throws {
            try await LoopbackServer.run(answering: .stallBody) { server in
                let client = MexcFutures.Client(configuration: .init(restURL: server.url, timeout: .milliseconds(300)))

                let error = try await #require(throws: MexcFutures.ClientError.self) { try await client.synchronizeClock() }

                #expect(error.reason == .timedOut)
            }
        }

        @Test func `a connection closed before the response throws connectionFailed`() async throws {
            try await LoopbackServer.run(answering: .close) { server in
                let client = MexcFutures.Client(configuration: .init(restURL: server.url))

                let error = try await #require(throws: MexcFutures.ClientError.self) { try await client.synchronizeClock() }

                #expect(error.reason == .connectionFailed)
                #expect(error.underlyingError != nil)
            }
        }

        // AsyncHTTPClient retries a refused connection until the timeout, then throws the last
        // connection error, so a short timeout keeps the test fast.
        @Test func `a refused connection throws connectionFailed`() async throws {
            let client = MexcFutures.Client(
                configuration: .init(restURL: try await LoopbackServer.unusedURL(), timeout: .milliseconds(500))
            )

            let error = try await #require(throws: MexcFutures.ClientError.self) { try await client.synchronizeClock() }

            #expect(error.reason == .connectionFailed)
        }
    }
}
