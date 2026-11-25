import Foundation
import Testing

@testable import MexcKit

// Exact requests, with the test credentials `mx0testkey`/`testsecret` and the request time
// 1700000000000. Each expected signature was computed independently of the SDK.
extension MexcKitTests {
    @Suite("Requests")
    struct RequestTests {
        @Test func `a public GET carries no key or signature`() async throws {
            let request = try await RESTClient.test().request(
                for: Endpoint<Bool>.get(
                    "/api/v1/contract/deals/BTC_USDT", query: ["limit": "100"]
                ))
            #expect(
                request.rendered == """
                    GET https://api.mexc.com/api/v1/contract/deals/BTC_USDT?limit=100
                    Content-Type: application/json
                    """)
        }

        @Test func `a signed GET signs the sorted query it sends`() async throws {
            let request = try await RESTClient.test().request(
                for: Endpoint<Bool>.get(
                    "/api/v1/private/order/list/history_orders",
                    query: ["symbol": "BTC_USDT", "page_num": "1", "page_size": "20", "states": nil],
                    authentication: .signed
                ))
            #expect(
                request.rendered == """
                    GET https://api.mexc.com/api/v1/private/order/list/history_orders?page_num=1&page_size=20&symbol=BTC_USDT
                    Content-Type: application/json
                    ApiKey: mx0testkey
                    Request-Time: 1700000000000
                    Signature: 637fda6412263a9c9bde77885be3851375651d9ddc5a3828b8971851c0a156a0
                    """)
        }

        @Test(arguments: [
            (QueryString.CommaSigning.encoded, "40c27ee8ec6c47d55fcb1ea966296171f6228323e9d1383a279fd3f491deb66e"),
            (.raw, "eb2001d58ab825379b26aafa7c943ab5a23e05816b5e6ef0d75c9888e18dcb4a"),
        ])
        func `a comma list is sent encoded and signed as chosen`(
            commaSigning: QueryString.CommaSigning, signature: String
        ) async throws {
            let request = try await RESTClient.test().request(
                for: Endpoint<Bool>.get(
                    "/api/v1/private/order/batch_query", query: ["order_ids": "1,2,3"], authentication: .signed,
                    commaSigning: commaSigning
                ))
            #expect(request.url.absoluteString == "https://api.mexc.com/api/v1/private/order/batch_query?order_ids=1%2C2%2C3")
            #expect(request.headers.last == .init(name: "Signature", value: signature))
        }

        @Test func `a JSON POST signs the body it sends`() async throws {
            struct Body: Encodable, Sendable {
                var symbol = "BTC_USDT"
                var price = Decimal(string: "60000.5")!
                var vol = 1
            }
            let request = try await RESTClient.test().request(
                for: Endpoint<Bool>.post(
                    "/api/v1/private/order/create", .json(Body())
                ))
            #expect(
                request.rendered == """
                    POST https://api.mexc.com/api/v1/private/order/create
                    Content-Type: application/json
                    ApiKey: mx0testkey
                    Request-Time: 1700000000000
                    Signature: b78bb2bba1b42e3b664677ecfa8e8052b997a6116632d613043db9c9da6801a6

                    {"price":60000.5,"symbol":"BTC_USDT","vol":1}
                    """)
        }

        @Test func `a POST without parameters sends no body and signs the empty string`() async throws {
            let request = try await RESTClient.test().request(
                for: Endpoint<Bool>.post(
                    "/api/v1/private/position/close_all"
                ))
            #expect(
                request.rendered == """
                    POST https://api.mexc.com/api/v1/private/position/close_all
                    Content-Type: application/json
                    ApiKey: mx0testkey
                    Request-Time: 1700000000000
                    Signature: 714a5b3c4e04c2cb808c224fe8f77bbbec89c8014d52eee3d9b064004ca0e9f9
                    """)
        }

        @Test func `an empty form POST is form-encoded and signs the empty string`() async throws {
            let request = try await RESTClient.test().request(
                for: Endpoint<Bool>.post(
                    "/api/v1/private/multiAssets/changeMultiAssetMode/true", .emptyForm
                ))
            #expect(
                request.rendered == """
                    POST https://api.mexc.com/api/v1/private/multiAssets/changeMultiAssetMode/true
                    Content-Type: application/x-www-form-urlencoded
                    ApiKey: mx0testkey
                    Request-Time: 1700000000000
                    Signature: 714a5b3c4e04c2cb808c224fe8f77bbbec89c8014d52eee3d9b064004ca0e9f9
                    """)
        }

        @Test func `the receive window and language are sent when configured`() async throws {
            let client = RESTClient.test(receiveWindow: .seconds(5), language: "en-US")
            let request = try await client.request(for: Endpoint<Bool>.post("/api/v1/private/position/close_all"))
            #expect(
                request.rendered == """
                    POST https://api.mexc.com/api/v1/private/position/close_all
                    Content-Type: application/json
                    Language: en-US
                    ApiKey: mx0testkey
                    Request-Time: 1700000000000
                    Signature: 714a5b3c4e04c2cb808c224fe8f77bbbec89c8014d52eee3d9b064004ca0e9f9
                    Recv-Window: 5000
                    """)
        }

        @Test func `a private request without credentials throws before sending`() async throws {
            let transport = FakeTransport()
            let client = RESTClient.test(transport: transport, credentials: nil)
            let error = try await #require(throws: MexcFutures.ClientError.self) {
                try await client.send(Endpoint<Bool>.post("/api/v1/private/position/close_all"))
            }
            #expect(error.reason == .missingCredentials)
            #expect(await transport.requests.isEmpty)
        }

        @Test func `a public request never reads credentials`() async throws {
            let client = RESTClient.test(
                transport: FakeTransport(json: #"{"success":true,"code":0,"data":1795503909246}"#),
                credentials: {
                    Issue.record("Credentials were read")
                    return MexcCredentials(apiKey: "", secret: "")
                }
            )
            let time = try await client.send(.serverTime)
            #expect(time.date == Date(timeIntervalSince1970: 1_795_503_909.246))
        }

        @Test func `credentials are read for every private request`() async throws {
            let keys = KeySequence()
            let client = RESTClient.test(credentials: { await keys.next() })
            let endpoint = Endpoint<Bool>.post("/api/v1/private/position/close_all")
            let first = try await client.request(for: endpoint)
            let second = try await client.request(for: endpoint)
            #expect(first.headers.contains(.init(name: "ApiKey", value: "key-1")))
            #expect(second.headers.contains(.init(name: "ApiKey", value: "key-2")))
        }

        @Test func `path segments are percent-encoded`() async throws {
            let request = try await RESTClient.test().request(for: Endpoint<Bool>.get("/api/v1/contract/deals/BTC USDT?x/"))
            #expect(request.url.absoluteString == "https://api.mexc.com/api/v1/contract/deals/BTC%20USDT%3Fx/")
        }

        @Test func `a base URL with a path keeps it`() async throws {
            let client = RESTClient(
                baseURL: URL(string: "https://proxy.example/mexc/")!, transport: FakeTransport(), credentials: nil,
                clock: ServerClock(), receiveWindow: nil, language: nil, timeout: .seconds(1)
            )
            let request = try await client.request(for: Endpoint<Bool>.get("/api/v1/contract/ping"))
            #expect(request.url.absoluteString == "https://proxy.example/mexc/api/v1/contract/ping")
        }
    }
}

/// Hands out a new key on each read, like an app that rotates its key.
private actor KeySequence {
    private var count = 0

    func next() -> MexcCredentials {
        count += 1
        return MexcCredentials(apiKey: "key-\(count)", secret: "secret")
    }
}
