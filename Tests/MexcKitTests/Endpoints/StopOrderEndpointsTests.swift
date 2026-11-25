import Foundation
import Testing

@testable import MexcKit

// Private responses can't be recorded without the user's key. The pending list runs against the example
// in MEXC's documentation (whitespace aside). The documented examples of placing and of the full list are
// placeholders (`success: false`, zero values, empty timestamps), so those calls answer with responses
// built from the documented fields. Each test pins the exact request.
extension MexcKitTests {
    @Suite("Stop order endpoints")
    struct StopOrderEndpointsTests {
        private static let accepted = #"{"success":true,"code":0}"#
        private static let position = MexcFutures.PositionID(rawValue: "1027177055")

        @Test func `placing a stop order with a market take-profit and a limit stop-loss`() async throws {
            let request = MexcFutures.StopOrderRequest(
                position: Self.position, volume: 2, takeProfit: .market(at: 64000, source: .fair),
                stopLoss: .limit(57900, at: 58000), triggerProtection: true
            )
            let (id, sent) = try await call(json: #"{"success":true,"code":0,"data":357859177}"#) {
                try await $0.place(request)
            }
            #expect(id == .init(rawValue: "357859177"))
            #expect(sent.method == .post)
            #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/stoporder/place")
            #expect(
                sent.bodyText == """
                    {"lossTrend":1,"positionId":1027177055,"priceProtect":1,"profitTrend":2,"stopLossOrderPrice":57900,\
                    "stopLossPrice":58000,"stopLossType":1,"takeProfitPrice":64000,"vol":2}
                    """)
        }

        @Test func `a stop order with only a stop-loss sends both trigger types`() async throws {
            let request = MexcFutures.StopOrderRequest(position: Self.position, volume: 1, stopLoss: .market(at: 58000))
            let (_, sent) = try await call(json: #"{"success":true,"code":0,"data":"1"}"#) { try await $0.place(request) }
            #expect(sent.bodyText == #"{"lossTrend":1,"positionId":1027177055,"profitTrend":1,"stopLossPrice":58000,"vol":1}"#)
        }

        @Test func `a stop order without an exit throws before sending`() async throws {
            let transport = FakeTransport()
            let endpoints = StopOrderEndpoints(rest: .test(transport: transport))
            let place = try await #require(throws: MexcFutures.ClientError.self) {
                try await endpoints.place(.init(position: Self.position, volume: 1))
            }
            #expect(place.reason == .invalidRequest)
            let modify = try await #require(throws: MexcFutures.ClientError.self) {
                try await endpoints.modify(.init(rawValue: "1"), takeProfit: nil, stopLoss: nil)
            }
            #expect(modify.reason == .invalidRequest)
            let cancel = try await #require(throws: MexcFutures.ClientError.self) {
                try await endpoints.cancel([.init(rawValue: "abc")])
            }
            #expect(cancel.reason == .invalidRequest)
            #expect(await transport.requests.isEmpty)
        }

        @Test func `modifying a stop order's trigger prices`() async throws {
            let (_, sent) = try await call(json: Self.accepted) {
                try await $0.modify(.init(rawValue: "357859177"), takeProfit: nil, stopLoss: .init(price: 58500, source: .index))
            }
            #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/stoporder/change_plan_price")
            #expect(sent.bodyText == #"{"lossTrend":3,"stopLossPrice":58500,"stopPlanOrderId":357859177}"#)
        }

        @Test func `setting and removing a limit order's attached stops`() async throws {
            let order = MexcFutures.OrderID(rawValue: "739113577038255616")
            let (_, set) = try await call(json: Self.accepted) {
                try await $0.setAttachedStops(of: order, takeProfit: .init(price: 64000), stopLoss: .init(price: 58000))
            }
            #expect(set.url.absoluteString == "https://api.mexc.com/api/v1/private/stoporder/change_price")
            #expect(
                set.bodyText == """
                    {"lossTrend":1,"orderId":739113577038255616,"profitTrend":1,"stopLossPrice":58000,"takeProfitPrice":64000}
                    """)
            let (_, removed) = try await call(json: Self.accepted) {
                try await $0.setAttachedStops(of: order, takeProfit: nil, stopLoss: nil)
            }
            #expect(removed.bodyText == #"{"orderId":739113577038255616}"#)
        }

        @Test func `canceling stop orders`() async throws {
            let (_, sent) = try await call(json: Self.accepted) {
                try await $0.cancel([.init(rawValue: "1"), .init(rawValue: "2")])
            }
            #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/stoporder/cancel")
            #expect(sent.bodyText == #"[{"stopPlanOrderId":1},{"stopPlanOrderId":2}]"#)
        }

        @Test(arguments: [
            (MexcFutures.Symbol?.some("BTC_USDT"), MexcFutures.PositionID?.none, #"{"symbol":"BTC_USDT"}"#),
            (nil, .some(.init(rawValue: "1027177055")), #"{"positionId":1027177055}"#),
            (nil, nil, "{}"),
        ])
        func `canceling every stop order`(
            symbol: MexcFutures.Symbol?, position: MexcFutures.PositionID?, body: String
        ) async throws {
            let (_, sent) = try await call(json: Self.accepted) { try await $0.cancelAll(symbol, position: position) }
            #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/stoporder/cancel_all")
            #expect(sent.bodyText == body)
        }

        @Test func `pending stop orders`() async throws {
            let (orders, sent) = try await call(fixture: "StopOrder/open_orders") { try await $0.pending("BTC_USDT") }
            #expect(sent.method == .get)
            #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/stoporder/open_orders?symbol=BTC_USDT")
            #expect(
                orders == [
                    .init(
                        id: .init(rawValue: "357859177"), symbol: "BTC_USDT", position: Self.position, side: .long,
                        order: .init(rawValue: "720733527158642176"), takeProfit: .market(at: Decimal(string: "113573.9")!),
                        stopLoss: .market(at: 111_325), volume: 2, state: .executed, isFinished: true, triggered: .stopLoss,
                        placedVolume: 2, placedOrder: .init(rawValue: "720744238723187712"), errorCode: nil,
                        triggerProtection: false, createdAt: Date(timeIntervalSince1970: 1_757_506_663),
                        updatedAt: Date(timeIntervalSince1970: 1_757_509_217)
                    )
                ])
        }

        @Test func `the stop order list with every filter`() async throws {
            // Built from the documented response fields: the documented example is a placeholder.
            let json = #"""
                {"success":true,"code":0,"data":[{"id":9,"orderId":0,"symbol":"BTC_USDT","positionId":0,
                 "stopLossPrice":0,"takeProfitPrice":64000,"profitTrend":3,"takeProfitType":1,
                 "takeProfitOrderPrice":64100,"state":1,"triggerSide":0,"positionType":2,"vol":1,"placeOrderId":0,
                 "errorCode":0,"isFinished":0,"createTime":1757506663000}]}
                """#
            let (orders, sent) = try await call(json: json) {
                try await $0.list(
                    "BTC_USDT", state: .untriggered, side: .short, start: Date(timeIntervalSince1970: 1),
                    end: Date(timeIntervalSince1970: 2), page: .first
                )
            }
            #expect(
                sent.url.absoluteString == """
                    https://api.mexc.com/api/v1/private/stoporder/list/orders\
                    ?end_time=2000&page_num=1&page_size=20&start_time=1000&state=1&symbol=BTC_USDT&type=2
                    """)
            let order = try #require(orders.first)
            #expect(order.order == nil)
            #expect(order.position == nil)
            #expect(order.takeProfit == .limit(64100, at: 64000, source: .index))
            #expect(order.stopLoss == nil)
            #expect(order.triggered == nil)
            #expect(order.placedOrder == nil)
            #expect(!order.isFinished)
            #expect(order.updatedAt == nil)
        }

        @Test func `the stop order list without filters`() async throws {
            let (_, sent) = try await call(json: #"{"success":true,"code":0,"data":[]}"#) { try await $0.list() }
            #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/stoporder/list/orders?page_num=1&page_size=20")
        }

        private func call<Value>(
            fixture: String, _ body: (StopOrderEndpoints) async throws -> Value
        ) async throws -> (Value, TransportRequest) {
            try await call(transport: FakeTransport(fixture: fixture), body)
        }

        private func call<Value>(
            json: String, _ body: (StopOrderEndpoints) async throws -> Value
        ) async throws -> (Value, TransportRequest) {
            try await call(transport: FakeTransport(json: json), body)
        }

        /// Runs `body` and returns its result and the one request it sent, checking that it was signed.
        private func call<Value>(
            transport: FakeTransport, _ body: (StopOrderEndpoints) async throws -> Value
        ) async throws -> (Value, TransportRequest) {
            let result = try await body(StopOrderEndpoints(rest: .test(transport: transport)))
            let requests = await transport.requests
            #expect(requests.count == 1)
            let request = try #require(requests.first)
            #expect(request.headers.contains { $0.name == "Signature" })
            return (result, request)
        }
    }
}
