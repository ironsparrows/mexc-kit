import Foundation
import Testing
@testable import MexcKit

// Private responses can't be recorded without the user's key, so the place and list calls run against
// the examples in MEXC's documentation (whitespace aside); the others answer as MEXC documents, with
// no `data`. Each test pins the exact request.
@Suite("Trailing order endpoints")
struct TrailingOrderEndpointsTests {
    private static let accepted = #"{"success":true,"code":0}"#
    private static let id = MexcFutures.TrailingOrderID(rawValue: "739218627261666816")

    @Test func `placing an opening trailing order`() async throws {
        let request = MexcFutures.TrailingOrderRequest.open(
            .short, "BTC_USDT", volume: 3, leverage: 10, marginMode: .cross, callback: .percentage(Decimal(string: "0.02")!),
            activationPrice: 61000, source: .fair, positionMode: .hedge
        )
        let (id, sent) = try await call(fixture: "TrailingOrder/place") { try await $0.place(request) }
        #expect(id == Self.id)
        #expect(sent.method == .post)
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/trackorder/place")
        #expect(sent.bodyText == """
            {"activePrice":61000,"backType":1,"backValue":0.02,"leverage":10,"openType":2,"positionMode":1,\
            "side":3,"symbol":"BTC_USDT","trend":2,"vol":3}
            """)
    }

    @Test func `placing a closing trailing order`() async throws {
        let request = MexcFutures.TrailingOrderRequest.close(
            .long, "BTC_USDT", volume: 1, leverage: 5, marginMode: .isolated, callback: .distance(500),
            positionMode: .oneWay, reduceOnly: true
        )
        let (_, sent) = try await call(fixture: "TrailingOrder/place") { try await $0.place(request) }
        #expect(sent.bodyText == """
            {"backType":2,"backValue":500,"leverage":5,"openType":1,"positionMode":2,"reduceOnly":true,"side":4,\
            "symbol":"BTC_USDT","trend":1,"vol":1}
            """)
    }

    @Test func `modifying a trailing order`() async throws {
        let (_, sent) = try await call(json: Self.accepted) {
            try await $0.modify(
                Self.id, in: "BTC_USDT", volume: 2, callback: .distance(400), activationPrice: nil, source: .index
            )
        }
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/trackorder/change_order")
        #expect(sent.bodyText == """
            {"backType":2,"backValue":400,"symbol":"BTC_USDT","trackOrderId":739218627261666816,"trend":3,"vol":2}
            """)
    }

    @Test func `canceling a trailing order`() async throws {
        let (_, sent) = try await call(json: Self.accepted) { try await $0.cancel(Self.id, in: "BTC_USDT") }
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/trackorder/cancel")
        #expect(sent.bodyText == #"{"symbol":"BTC_USDT","trackOrderId":739218627261666816}"#)
    }

    @Test func `the trailing order list`() async throws {
        let (orders, sent) = try await call(fixture: "TrailingOrder/list_orders") {
            try await $0.list(
                "DOGE_USDT", states: [.inactive, .active], side: .openLong, start: Date(timeIntervalSince1970: 1),
                end: Date(timeIntervalSince1970: 2), page: .init(number: 3, size: 10)
            )
        }
        #expect(sent.method == .get)
        #expect(sent.url.absoluteString == """
            https://api.mexc.com/api/v1/private/trackorder/list/orders\
            ?end_time=2000&pageIndex=3&pageSize=10&side=1&start_time=1000&states=0%2C1&symbol=DOGE_USDT
            """)
        #expect(orders == [.init(
            id: .init(rawValue: "739628779353703936"), symbol: "DOGE_USDT", side: .openLong, marginMode: .isolated,
            leverage: 2, volume: 100, source: .last, callback: .percentage(Decimal(string: "0.02")!),
            activationPrice: nil, referencePrice: Decimal(string: "0.18657")!, triggerPrice: Decimal(string: "0.1903")!,
            triggerCondition: .atOrAbove, state: .active, order: nil, errorCode: nil, positionMode: .hedge,
            reduceOnly: false, createdAt: Date(timeIntervalSince1970: 1_762_011_642.623),
            updatedAt: Date(timeIntervalSince1970: 1_762_011_642.623)
        )])
    }

    @Test func `the trailing order list in any state`() async throws {
        let (_, sent) = try await call(fixture: "TrailingOrder/list_orders") { try await $0.list() }
        #expect(sent.url.absoluteString == """
            https://api.mexc.com/api/v1/private/trackorder/list/orders?pageIndex=1&pageSize=20&states=0%2C1%2C2%2C3%2C4
            """)
    }

    private func call<Value>(
        fixture: String, _ body: (TrailingOrderEndpoints) async throws -> Value
    ) async throws -> (Value, TransportRequest) {
        try await call(transport: FakeTransport(fixture: fixture), body)
    }

    private func call<Value>(
        json: String, _ body: (TrailingOrderEndpoints) async throws -> Value
    ) async throws -> (Value, TransportRequest) {
        try await call(transport: FakeTransport(json: json), body)
    }

    /// Runs `body` and returns its result and the one request it sent, checking that it was signed.
    private func call<Value>(
        transport: FakeTransport, _ body: (TrailingOrderEndpoints) async throws -> Value
    ) async throws -> (Value, TransportRequest) {
        let result = try await body(TrailingOrderEndpoints(rest: .test(transport: transport)))
        let requests = await transport.requests
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.headers.contains { $0.name == "Signature" })
        return (result, request)
    }
}
