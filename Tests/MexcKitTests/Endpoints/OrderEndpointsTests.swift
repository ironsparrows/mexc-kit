import Foundation
import Testing
@testable import MexcKit

// Private responses can't be recorded without the user's key, so the order lists and fills run against
// the examples in MEXC's documentation for their endpoints (whitespace aside), and the short answers
// are written inline from the documented examples.
@Suite("Order endpoints")
struct OrderEndpointsTests {
    private static let accepted = #"{"success":true,"code":0}"#

    @Test func `placing an order sends the documented fields and decodes the ID`() async throws {
        let request = MexcFutures.OrderRequest.open(
            .long, "BTC_USDT", .limit(price: Decimal(string: "60000.5")!), volume: 10, leverage: 20, marginMode: .isolated,
            takeProfit: .init(price: 64000, source: .fair), stopLoss: .init(price: 58000),
            externalID: "grid-7", options: .init(reduceOnly: true, positionMode: .oneWay, triggerProtection: true)
        )
        let (placed, sent) = try await call(
            json: #"{"success":true,"code":0,"data":{"orderId":"739113577038255616","ts":1761888808839}}"#
        ) { try await $0.place(request) }
        #expect(placed == .init(
            id: .init(rawValue: "739113577038255616"), acceptedAt: Date(timeIntervalSince1970: 1_761_888_808.839)
        ))
        #expect(sent.method == .post)
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/order/create")
        #expect(sent.bodyText == """
            {"externalOid":"grid-7","leverage":20,"lossTrend":1,"openType":1,"positionMode":2,"price":60000.5,\
            "priceProtect":1,"profitTrend":2,"reduceOnly":true,"side":1,"stopLossPrice":58000,"symbol":"BTC_USDT",\
            "takeProfitPrice":64000,"type":1,"vol":10}
            """)
    }

    @Test func `a market close leaves out the price, the leverage and unset options`() async throws {
        let request = MexcFutures.OrderRequest.close(
            .short, "BTC_USDT", .market, volume: 3, marginMode: .cross, position: .init(rawValue: "1109973831")
        )
        let (_, sent) = try await call(
            json: #"{"success":true,"code":0,"data":{"orderId":"1","ts":1}}"#
        ) { try await $0.place(request) }
        #expect(sent.bodyText == #"{"openType":2,"positionId":1109973831,"side":2,"symbol":"BTC_USDT","type":5,"vol":3}"#)
    }

    @Test func `a best-price order is a limit order with its level and no price`() async throws {
        let request = MexcFutures.OrderRequest.open(
            .short, "ETH_USDT", .bestPrice(.opposite5), volume: 1, leverage: 5, marginMode: .cross,
            options: .init(marketCeiling: true, flashClose: true, selfTradePrevention: .cancelMaker)
        )
        let (_, sent) = try await call(
            json: #"{"success":true,"code":0,"data":{"orderId":"1","ts":1}}"#
        ) { try await $0.place(request) }
        #expect(sent.bodyText == """
            {"bboTypeNum":2,"flashClose":true,"leverage":5,"marketCeiling":true,"openType":2,"side":3,"stpMode":2,\
            "symbol":"ETH_USDT","type":1,"vol":1}
            """)
    }

    @Test func `a batch sends an array with a self-trade mode on every order and reads each result`() async throws {
        let requests: [MexcFutures.OrderRequest] = [
            .open(.long, "BTC_USDT", .postOnly(price: 50000), volume: 1, leverage: 10, marginMode: .isolated),
            .open(
                .long, "BTC_USDT", .postOnly(price: 49000), volume: 1, leverage: 10, marginMode: .isolated,
                options: .init(selfTradePrevention: .cancelTaker)
            ),
        ]
        let (results, sent) = try await call(json: """
            {"success":true,"code":0,"data":[{"orderId":768116802038827520,"errorCode":0},\
            {"orderId":768116802038352385,"errorCode":2005,"errorMsg":"Balance insufficient"}]}
            """) { try await $0.place(requests) }
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/order/submit_batch")
        #expect(sent.bodyText == """
            [{"leverage":10,"openType":1,"price":50000,"side":1,"stpMode":0,"symbol":"BTC_USDT","type":2,"vol":1},\
            {"leverage":10,"openType":1,"price":49000,"side":1,"stpMode":3,"symbol":"BTC_USDT","type":2,"vol":1}]
            """)
        #expect(results.map(\.id?.rawValue) == ["768116802038827520", "768116802038352385"])
        #expect(results[0].succeeded)
        #expect(results[1].error?.code == .insufficientBalance)
        #expect(results[1].error?.message == "Balance insufficient")
    }

    @Test func `chasing and modifying send the order ID as a number`() async throws {
        let id = MexcFutures.OrderID(rawValue: "739204819784386560")
        let (_, chase) = try await call(json: Self.accepted) { try await $0.chase(id) }
        #expect(chase.url.absoluteString == "https://api.mexc.com/api/v1/private/order/chase_limit_order")
        #expect(chase.bodyText == #"{"orderId":739204819784386560}"#)

        let (modified, modify) = try await call(json: #"{"success":true,"code":0,"data":"739204819784386560"}"#) {
            try await $0.modify(id, price: Decimal(string: "0.18")!, volume: 2)
        }
        #expect(modified == id)
        #expect(modify.url.absoluteString == "https://api.mexc.com/api/v1/private/order/change_limit_order")
        #expect(modify.bodyText == #"{"orderId":739204819784386560,"price":0.18,"vol":2}"#)
    }

    @Test func `an ID that isn't a number throws before anything is sent`() async throws {
        let transport = FakeTransport()
        let error = try await #require(throws: MexcFutures.ClientError.self) {
            try await OrderEndpoints(rest: .test(transport: transport)).chase(.init(rawValue: "abc"))
        }
        #expect(error.reason == .invalidRequest)
        #expect(await transport.requests.isEmpty)
    }

    @Test(arguments: [
        MexcFutures.OrderRequest.open(
            .long, "BTC_USDT", .limit(price: 1), volume: 1, leverage: 1, marginMode: .cross, takeProfit: .init(price: 2)
        ),
        .open(.long, "BTC_USDT", .limit(price: 1), volume: 1, leverage: 1, marginMode: .cross, stopLoss: .init(price: 1)),
        .open(
            .long, "BTC_USDT", .limit(price: 1), volume: 1, leverage: 1, marginMode: .cross,
            options: .init(triggerProtection: true)
        ),
        .open(.long, "BTC_USDT", .bestPrice(.opposite1), volume: 1, leverage: 1, marginMode: .cross),
    ])
    func `a batch order MEXC's batch can't carry throws before anything is sent`(
        request: MexcFutures.OrderRequest
    ) async throws {
        let transport = FakeTransport()
        let error = try await #require(throws: MexcFutures.ClientError.self) {
            try await OrderEndpoints(rest: .test(transport: transport)).place([request])
        }
        #expect(error.reason == .invalidRequest)
        #expect(await transport.requests.isEmpty)
    }

    @Test func `a best-price order with an external ID throws before anything is sent`() async throws {
        let transport = FakeTransport()
        let request = MexcFutures.OrderRequest.close(
            .long, "BTC_USDT", .bestPrice(.sameSide1), volume: 1, marginMode: .cross, externalID: "x"
        )
        let error = try await #require(throws: MexcFutures.ClientError.self) {
            try await OrderEndpoints(rest: .test(transport: transport)).place(request)
        }
        #expect(error.reason == .invalidRequest)
        #expect(await transport.requests.isEmpty)
    }

    @Test func `canceling by ID sends a number array and reads each result`() async throws {
        let (results, sent) = try await call(json: """
            {"success":true,"code":0,"data":[{"orderId":101716841474621953,"errorCode":2040,"errorMsg":"order not exist"},\
            {"orderId":108885377779302912,"errorCode":2041,"errorMsg":"order state cannot be cancelled"},\
            {"orderId":108886241042563584,"errorCode":0,"errorMsg":"success"}]}
            """) {
            try await $0.cancel([.init(rawValue: "101716841474621953"), .init(rawValue: "108885377779302912")])
        }
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/order/cancel")
        #expect(sent.bodyText == "[101716841474621953,108885377779302912]")
        #expect(results.map(\.error?.code) == [.orderNotFound, .orderNotCancellable, nil])
        #expect(results.map(\.id?.rawValue) == ["101716841474621953", "108885377779302912", "108886241042563584"])
    }

    @Test func `canceling one order throws its own result's error`() async throws {
        // MEXC's answer lists another order first; only the canceled order's result counts.
        let transport = FakeTransport(json: #"""
            {"success":true,"code":0,"data":[{"orderId":2,"errorCode":0},
            {"orderId":1,"errorCode":2041,"errorMsg":"order state cannot be cancelled"}]}
            """#)
        let error = try await #require(throws: MexcError.self) {
            try await OrderEndpoints(rest: .test(transport: transport)).cancel(MexcFutures.OrderID(rawValue: "1"))
        }
        #expect(error.code == .orderNotCancellable)
    }

    @Test func `a fill's and an order's 0 for category and position mode are none, as in the stream`() throws {
        let fill = try JSONDecoder().decode(MexcFutures.Fill.self, from: Data(#"""
            {"id":"1","symbol":"ETH_USDT","side":2,"vol":1,"price":1208.35,"feeCurrency":"USDT","fee":0.01,
             "timestamp":1609992674000,"category":0,"positionMode":0,"taker":true}
            """#.utf8))
        #expect(fill.category == nil && fill.positionMode == nil)
        let order = try JSONDecoder().decode(MexcFutures.Order.self, from: Data(#"""
            {"orderId":"9","symbol":"DOGE_USDT","positionId":0,"price":0.2,"vol":1,"leverage":20,"side":1,
             "category":1,"orderType":1,"dealVol":0,"orderMargin":0.01,"takerFee":0,"makerFee":0,"profit":0,
             "feeCurrency":"USDT","openType":1,"state":4,"positionMode":0,"createTime":1}
            """#.utf8))
        #expect(order.positionMode == nil)
    }

    @Test func `getting or canceling no orders sends nothing`() async throws {
        let transport = FakeTransport()
        let endpoints = OrderEndpoints(rest: .test(transport: transport))
        #expect(try await endpoints.get([]).isEmpty)
        #expect(try await endpoints.cancel([]).isEmpty)
        #expect(await transport.requests.isEmpty)
    }

    @Test func `orders in any state send no states`() async throws {
        let (_, sent) = try await call(json: #"{"success":true,"code":0,"data":[]}"#) {
            try await $0.history("DOGE_USDT", states: [], category: nil, start: nil, end: nil, page: .first)
        }
        #expect(sent.url.absoluteString == """
            https://api.mexc.com/api/v1/private/order/list/history_orders?page_num=1&page_size=20&symbol=DOGE_USDT
            """)
    }

    @Test func `canceling by external IDs sends the market with each ID`() async throws {
        let (results, sent) = try await call(json: """
            {"success":true,"code":0,"data":[{"orderId":1,"errorCode":0,"errorMsg":"success"}]}
            """) { try await $0.cancel(externalIDs: ["ext_11", "ext_12"], in: "BTC_USDT") }
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/order/batch_cancel_with_external")
        #expect(sent.bodyText == #"[{"externalOid":"ext_11","symbol":"BTC_USDT"},{"externalOid":"ext_12","symbol":"BTC_USDT"}]"#)
        #expect(results.allSatisfy { $0.succeeded })
    }

    @Test func `canceling one external ID throws the error MEXC reports for it`() async throws {
        let transport = FakeTransport(json: """
            {"success":true,"code":0,"data":[{"orderId":1,"errorCode":2040,"errorMsg":"order not exist"}]}
            """)
        let orders = OrderEndpoints(rest: .test(transport: transport))
        let error = try await #require(throws: MexcError.self) { try await orders.cancel(externalID: "ext_11", in: "BTC_USDT") }
        #expect(error.code == .orderNotFound)
        let sent = try #require(await transport.requests.first)
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/order/cancel_with_external")
        #expect(sent.bodyText == #"[{"externalOid":"ext_11","symbol":"BTC_USDT"}]"#)
    }

    @Test(arguments: [("BTC_USDT", #"{"symbol":"BTC_USDT"}"#), (nil, #"{"symbol":""}"#)])
    func `canceling all orders sends the market, or the empty string for every market`(
        symbol: String?, body: String
    ) async throws {
        let (_, sent) = try await call(json: Self.accepted) { try await $0.cancelAll(symbol.map { .init(rawValue: $0) }) }
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/order/cancel_all")
        #expect(sent.bodyText == body)
    }

    @Test func `an order decodes at full precision`() async throws {
        let (order, sent) = try await call(fixture: "Order/get") { try await $0.get(.init(rawValue: "739106551624717312")) }
        #expect(sent.method == .get)
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/order/get/739106551624717312")
        #expect(order == .init(
            id: .init(rawValue: "739106551624717312"), symbol: "BTC_USDT", position: .init(rawValue: "1109973831"),
            side: .openLong, type: .market, category: .limit, state: .filled, marginMode: .isolated, leverage: 2,
            price: Decimal(string: "109777.5")!, volume: 5, filledVolume: 5, averageFillPrice: Decimal(string: "109777.5")!,
            margin: Decimal(string: "27.444375")!, usedMargin: Decimal(string: "27.444375")!, takerFee: 0, makerFee: 0,
            totalFee: 0, feeAsset: "USDT", profit: 0, takeProfit: nil, stopLoss: nil, bestPrice: nil,
            externalID: "_m_903a9f81cc1148be99ac9ece15981374", errorCode: .normal, positionMode: .hedge,
            reduceOnly: nil, triggerProtection: nil, createdAt: Date(timeIntervalSince1970: 1_761_887_134),
            updatedAt: Date(timeIntervalSince1970: 1_761_887_134)
        ))
    }

    @Test func `orders by IDs send them comma-separated`() async throws {
        let ids: [MexcFutures.OrderID] = [.init(rawValue: "743829153601634818"), .init(rawValue: "2")]
        let (orders, sent) = try await call(fixture: "Order/batch_query") { try await $0.get(ids) }
        #expect(sent.url.absoluteString == """
            https://api.mexc.com/api/v1/private/order/batch_query?order_ids=743829153601634818%2C2
            """)
        #expect(orders.map(\.id) == [ids[0]])
        #expect(orders[0].position == nil)
        #expect(orders[0].reduceOnly == false)
        #expect(orders[0].averageFillPrice == nil)
        #expect(orders[0].state == .open)
    }

    @Test func `an order by external ID is read from its market's path`() async throws {
        let (order, sent) = try await call(fixture: "Order/get") { try await $0.get(externalID: "grid 7", in: "BTC_USDT") }
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/order/external/BTC_USDT/grid%207")
        #expect(order.symbol == "BTC_USDT")
    }

    @Test func `orders by external IDs are a signed POST with the market on each ID`() async throws {
        let (orders, sent) = try await call(fixture: "Order/batch_query") {
            try await $0.get(externalIDs: ["_m_a6e614e4107e4d13893f9f4a3f46d2d8"], in: "BTC_USDT")
        }
        #expect(sent.method == .post)
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/order/batch_query_with_external")
        #expect(sent.bodyText == #"[{"externalOid":"_m_a6e614e4107e4d13893f9f4a3f46d2d8","symbol":"BTC_USDT"}]"#)
        #expect(orders.count == 1)
    }

    @Test func `pending orders`() async throws {
        let (orders, sent) = try await call(fixture: "Order/open_orders") { try await $0.pending(page: .init(number: 2, size: 100)) }
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/order/list/open_orders?page_num=2&page_size=100")
        #expect(orders.map(\.symbol) == ["ETH_USDT", "BTC_USDT"])
        #expect(orders[1].margin == Decimal(string: "80.016"))
    }

    @Test func `order history sends the states and filters`() async throws {
        let (orders, sent) = try await call(fixture: "Order/history_orders") {
            try await $0.history(
                "DOGE_USDT", states: [.filled, .canceled], category: .limit, start: Date(timeIntervalSince1970: 1),
                end: Date(timeIntervalSince1970: 2), page: .first
            )
        }
        #expect(sent.url.absoluteString == """
            https://api.mexc.com/api/v1/private/order/list/history_orders\
            ?category=1&end_time=2000&page_num=1&page_size=20&start_time=1000&states=3%2C4&symbol=DOGE_USDT
            """)
        #expect(orders.map(\.externalID) == ["test00002", "test00001"])
        #expect(orders[0].price == Decimal(string: "0.18695"))
        #expect(orders[0].side == .openShort)
    }

    @Test func `order history also decodes from a page, as the documented fields describe`() async throws {
        let json = #"""
            {"success":true,"code":0,"data":{"pageSize":20,"totalCount":1,"totalPage":1,"currentPage":1,
             "resultList":[{"orderId":"9","symbol":"DOGE_USDT","positionId":0,"price":0.2,"vol":1,"leverage":20,
             "side":1,"category":1,"orderType":1,"dealVol":0,"orderMargin":0.01,"takerFee":0,"makerFee":0,"profit":0,
             "feeCurrency":"USDT","openType":1,"state":4,"createTime":1}]}}
            """#
        let (orders, sent) = try await call(json: json) { try await $0.history("DOGE_USDT") }
        #expect(sent.url.absoluteString == """
            https://api.mexc.com/api/v1/private/order/list/history_orders\
            ?page_num=1&page_size=20&states=1%2C2%2C3%2C4%2C5&symbol=DOGE_USDT
            """)
        #expect(orders.map(\.state) == [.canceled])
    }

    @Test func `closed orders`() async throws {
        let (orders, sent) = try await call(fixture: "Order/close_orders") { try await $0.closed("DOGE_USDT") }
        #expect(sent.url.absoluteString == """
            https://api.mexc.com/api/v1/private/order/list/close_orders?page_num=1&page_size=20&symbol=DOGE_USDT
            """)
        // This example has no `dealAvgPriceStr`; the plain number is used.
        #expect(orders.map(\.averageFillPrice) == [Decimal(string: "0.18695")])
    }

    @Test func `fills in one market`() async throws {
        let (fills, sent) = try await call(fixture: "Order/order_deals") { try await $0.fills("DOGE_USDT") }
        #expect(sent.url.absoluteString == """
            https://api.mexc.com/api/v1/private/order/list/order_deals/v3?page_num=1&page_size=20&symbol=DOGE_USDT
            """)
        #expect(fills.first == .init(
            id: .init(rawValue: "9466823344"), symbol: "DOGE_USDT", order: .init(rawValue: "739211854408619008"),
            side: .openShort, price: Decimal(string: "0.18695")!, volume: 1, fee: 0, feeAsset: "USDT", profit: 0,
            category: .limit, isTaker: true, positionMode: .hedge,
            filledAt: Date(timeIntervalSince1970: 1_761_912_240)
        ))
    }

    @Test func `fills of one order`() async throws {
        let (fills, sent) = try await call(fixture: "Order/deal_details") { try await $0.fills(of: .init(rawValue: "102015012431820288")) }
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/order/deal_details/102015012431820288")
        #expect(fills.map(\.fee) == [Decimal(string: "0.0072501")])
        #expect(fills.map(\.positionMode) == [nil])
    }

    @Test func `pending counts`() async throws {
        let (counts, sent) = try await call(json: """
            {"success":true,"code":0,"data":{"sumCount":1,"limitOrderCount":1,"stopOrderCount":0,"planOrderCount":0,\
            "trackOrderCount":0}}
            """) { try await $0.pendingCounts() }
        #expect(sent.method == .get)
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/order/open_order_total_count")
        #expect(counts == .init(total: 1, limitOrders: 1, stopOrders: 0, planOrders: 0, trailingOrders: 0))
    }

    @Test func `an attached stop and a best price decode, and missing optional fields are nil`() throws {
        let json = #"""
            {"orderId":5,"symbol":"BTC_USDT","positionId":7,"price":1,"vol":1,"leverage":3,"side":2,"category":1,
             "orderType":1,"dealVol":0,"orderMargin":0,"takerFee":0,"makerFee":0,"profit":0,"feeCurrency":"USDT",
             "openType":2,"state":1,"takeProfitPrice":70000,"profitTrend":3,"stopLossPrice":0,"bboTypeNum":4,
             "priceProtect":1,"createTime":1}
            """#
        let order = try JSONDecoder().decode(MexcFutures.Order.self, from: Data(json.utf8))
        #expect(order.takeProfit == .init(price: 70000, source: .index))
        #expect(order.stopLoss == nil)
        #expect(order.bestPrice == .sameSide5)
        #expect(order.triggerProtection == true)
        #expect(order.averageFillPrice == nil)
        #expect(order.externalID == nil)
        #expect(order.updatedAt == nil)
        #expect(order.position == .init(rawValue: "7"))
    }

    private func call<Value>(
        fixture: String, _ body: (OrderEndpoints) async throws -> Value
    ) async throws -> (Value, TransportRequest) {
        try await call(transport: FakeTransport(fixture: fixture), body)
    }

    private func call<Value>(
        json: String, _ body: (OrderEndpoints) async throws -> Value
    ) async throws -> (Value, TransportRequest) {
        try await call(transport: FakeTransport(json: json), body)
    }

    /// Runs `body` and returns its result and the one request it sent, checking that it was signed.
    private func call<Value>(
        transport: FakeTransport, _ body: (OrderEndpoints) async throws -> Value
    ) async throws -> (Value, TransportRequest) {
        let result = try await body(OrderEndpoints(rest: .test(transport: transport)))
        let requests = await transport.requests
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.headers.contains { $0.name == "Signature" })
        return (result, request)
    }
}
