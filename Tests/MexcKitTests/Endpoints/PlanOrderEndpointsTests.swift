import Foundation
import Testing
@testable import MexcKit

// Private responses can't be recorded without the user's key, so the place and list calls run against
// the examples in MEXC's documentation (whitespace aside); the others answer as MEXC documents, with
// no `data`. Each test pins the exact request.
@Suite("Plan order endpoints")
struct PlanOrderEndpointsTests {
    private static let accepted = #"{"success":true,"code":0}"#
    private static let id = MexcFutures.PlanOrderID(rawValue: "739206374277809664")

    @Test func `placing an opening plan order sends every field that is set`() async throws {
        let request = MexcFutures.PlanOrderRequest.open(
            .long, "BTC_USDT", .limit(price: Decimal(string: "61000.5")!), volume: 2, leverage: 10, marginMode: .isolated,
            trigger: .init(price: 61000, condition: .atOrAbove, source: .fair), lifetime: .sevenDays,
            takeProfit: .init(price: 64000), stopLoss: .init(price: 58000, source: .index),
            options: .init(reduceOnly: true, positionMode: .oneWay, triggerProtection: true)
        )
        let (id, sent) = try await call(fixture: "PlanOrder/place") { try await $0.place(request) }
        #expect(id == Self.id)
        #expect(sent.method == .post)
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/planorder/place/v2")
        #expect(sent.bodyText == """
            {"executeCycle":2,"leverage":10,"lossTrend":3,"openType":1,"orderType":1,"positionMode":2,\
            "price":61000.5,"priceProtect":1,"profitTrend":1,"reduceOnly":true,"side":1,"stopLossPrice":58000,\
            "symbol":"BTC_USDT","takeProfitPrice":64000,"trend":2,"triggerPrice":61000,"triggerType":1,"vol":2}
            """)
    }

    @Test func `placing a closing market plan order sends no price, leverage or options`() async throws {
        let request = MexcFutures.PlanOrderRequest.close(
            .short, "BTC_USDT", .market, volume: 1, marginMode: .cross,
            trigger: .init(price: 58000, condition: .atOrBelow), lifetime: .oneDay
        )
        let (_, sent) = try await call(fixture: "PlanOrder/place") { try await $0.place(request) }
        #expect(sent.bodyText == """
            {"executeCycle":1,"openType":2,"orderType":5,"side":2,"symbol":"BTC_USDT","trend":1,\
            "triggerPrice":58000,"triggerType":2,"vol":1}
            """)
    }

    @Test func `a best-price plan order throws before sending`() async throws {
        let transport = FakeTransport()
        let endpoints = PlanOrderEndpoints(rest: .test(transport: transport))
        let request = MexcFutures.PlanOrderRequest.open(
            .long, "BTC_USDT", .bestPrice(.opposite1), volume: 1, leverage: 5, marginMode: .isolated,
            trigger: .init(price: 1, condition: .atOrAbove), lifetime: .oneDay
        )
        let place = try await #require(throws: MexcFutures.ClientError.self) { try await endpoints.place(request) }
        #expect(place.reason == .invalidRequest)
        let modify = try await #require(throws: MexcFutures.ClientError.self) {
            try await endpoints.modify(
                Self.id, in: "BTC_USDT", trigger: .init(price: 1, condition: .atOrAbove), pricing: .bestPrice(.sameSide1)
            )
        }
        #expect(modify.reason == .invalidRequest)
        #expect(await transport.requests.isEmpty)
    }

    @Test func `changing a plan order to a market order throws before sending, since MEXC requires a price`() async throws {
        let transport = FakeTransport()
        let error = try await #require(throws: MexcFutures.ClientError.self) {
            try await PlanOrderEndpoints(rest: .test(transport: transport)).modify(
                Self.id, in: "BTC_USDT", trigger: .init(price: 1, condition: .atOrAbove), pricing: .market
            )
        }
        #expect(error.reason == .invalidRequest)
        #expect(await transport.requests.isEmpty)
    }

    @Test func `canceling a plan order with a non-numeric ID throws before sending`() async throws {
        let transport = FakeTransport()
        let error = try await #require(throws: MexcFutures.ClientError.self) {
            try await PlanOrderEndpoints(rest: .test(transport: transport)).cancel([.init(rawValue: "abc")], in: "BTC_USDT")
        }
        #expect(error.reason == .invalidRequest)
        #expect(await transport.requests.isEmpty)
    }

    @Test func `modifying a plan order`() async throws {
        let (_, sent) = try await call(json: Self.accepted) {
            try await $0.modify(
                Self.id, in: "BTC_USDT", trigger: .init(price: 60500, condition: .atOrBelow, source: .index),
                pricing: .postOnly(price: 60400)
            )
        }
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/planorder/change_price")
        #expect(sent.bodyText == """
            {"orderId":739206374277809664,"orderType":2,"price":60400,"symbol":"BTC_USDT","trend":3,\
            "triggerPrice":60500,"triggerType":2}
            """)
    }

    @Test func `setting and removing a plan order's attached stops`() async throws {
        let (_, set) = try await call(json: Self.accepted) {
            try await $0.setAttachedStops(
                of: Self.id, in: "BTC_USDT", takeProfit: .init(price: 64000, source: .fair), stopLoss: nil
            )
        }
        #expect(set.url.absoluteString == "https://api.mexc.com/api/v1/private/planorder/change_stop_order")
        #expect(set.bodyText == #"{"orderId":739206374277809664,"profitTrend":2,"symbol":"BTC_USDT","takeProfitPrice":64000}"#)
        let (_, removed) = try await call(json: Self.accepted) {
            try await $0.setAttachedStops(of: Self.id, in: "BTC_USDT", takeProfit: nil, stopLoss: nil)
        }
        #expect(removed.bodyText == #"{"orderId":739206374277809664,"symbol":"BTC_USDT"}"#)
    }

    @Test func `canceling plan orders sends each with its market`() async throws {
        let (_, sent) = try await call(json: Self.accepted) {
            try await $0.cancel([Self.id, .init(rawValue: "2")], in: "BTC_USDT")
        }
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/planorder/cancel")
        #expect(sent.bodyText == """
            [{"orderId":"739206374277809664","symbol":"BTC_USDT"},{"orderId":"2","symbol":"BTC_USDT"}]
            """)
    }

    @Test(arguments: [(MexcFutures.Symbol?.some("BTC_USDT"), #"{"symbol":"BTC_USDT"}"#), (nil, "{}")])
    func `canceling every plan order`(symbol: MexcFutures.Symbol?, body: String) async throws {
        let (_, sent) = try await call(json: Self.accepted) { try await $0.cancelAll(symbol) }
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/planorder/cancel_all")
        #expect(sent.bodyText == body)
    }

    @Test func `the plan order list`() async throws {
        let start = Date(timeIntervalSince1970: 1_761_800_000)
        let end = Date(timeIntervalSince1970: 1_761_900_000)
        let (orders, sent) = try await call(fixture: "PlanOrder/list_orders") {
            try await $0.list(
                "DOGE_USD", states: [.untriggered, .executed], side: .openLong, start: start, end: end,
                page: .init(number: 2, size: 50)
            )
        }
        #expect(sent.method == .get)
        #expect(sent.url.absoluteString == """
            https://api.mexc.com/api/v1/private/planorder/list/orders\
            ?end_time=1761900000000&page_num=2&page_size=50&side=1&start_time=1761800000000&states=1%2C3\
            &symbol=DOGE_USD
            """)
        #expect(orders == [.init(
            id: .init(rawValue: "739114860879304259"), symbol: "DOGE_USD", side: .openLong, type: .limit,
            marginMode: .isolated, leverage: 2,
            trigger: .init(price: Decimal(string: "0.00001")!, condition: .atOrBelow, source: .last),
            price: Decimal(string: "0.00001")!, volume: 1, state: .untriggered, lifetime: .seconds(87600 * 3600),
            takeProfit: nil, stopLoss: nil, order: nil, errorCode: nil, positionMode: .hedge, reduceOnly: false,
            triggerProtection: false, createdAt: Date(timeIntervalSince1970: 1_761_889_115),
            updatedAt: Date(timeIntervalSince1970: 1_761_889_115)
        )])
    }

    @Test func `the plan order list in any state`() async throws {
        let (_, sent) = try await call(fixture: "PlanOrder/list_orders") {
            try await $0.list(from: Date(timeIntervalSince1970: 1), to: Date(timeIntervalSince1970: 2))
        }
        #expect(sent.url.absoluteString == """
            https://api.mexc.com/api/v1/private/planorder/list/orders\
            ?end_time=2000&page_num=1&page_size=20&start_time=1000
            """)
    }

    @Test func `an executed plan order with attached stops and a failure code`() throws {
        // Built from the documented response fields, with values the example doesn't show.
        let json = #"""
            {"id":5,"symbol":"BTC_USDT","leverage":20,"side":3,"triggerPrice":"58000","vol":4,"openType":2,
             "triggerType":2,"state":5,"executeCycle":24,"trend":3,"orderType":5,"errorCode":2005,"orderId":"8",
             "takeProfitPrice":55000,"profitTrend":2,"stopLossPrice":59000,"positionMode":0,"createTime":1}
            """#
        let order = try JSONDecoder().decode(MexcFutures.PlanOrder.self, from: Data(json.utf8))
        #expect(order.side == .openShort)
        #expect(order.type == .market)
        #expect(order.price == nil)
        #expect(order.state == .failed)
        #expect(order.lifetime == .seconds(24 * 3600))
        #expect(order.takeProfit == .init(price: 55000, source: .fair))
        #expect(order.stopLoss == .init(price: 59000, source: .last))
        #expect(order.order == .init(rawValue: "8"))
        #expect(order.errorCode == .init(rawValue: 2005))
        #expect(order.positionMode == nil)
        #expect(order.updatedAt == nil)
    }

    private func call<Value>(
        fixture: String, _ body: (PlanOrderEndpoints) async throws -> Value
    ) async throws -> (Value, TransportRequest) {
        try await call(transport: FakeTransport(fixture: fixture), body)
    }

    private func call<Value>(
        json: String, _ body: (PlanOrderEndpoints) async throws -> Value
    ) async throws -> (Value, TransportRequest) {
        try await call(transport: FakeTransport(json: json), body)
    }

    /// Runs `body` and returns its result and the one request it sent, checking that it was signed.
    private func call<Value>(
        transport: FakeTransport, _ body: (PlanOrderEndpoints) async throws -> Value
    ) async throws -> (Value, TransportRequest) {
        let result = try await body(PlanOrderEndpoints(rest: .test(transport: transport)))
        let requests = await transport.requests
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.headers.contains { $0.name == "Signature" })
        return (result, request)
    }
}
