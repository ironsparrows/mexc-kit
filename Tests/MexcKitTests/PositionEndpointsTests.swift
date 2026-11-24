import Foundation
import Testing
@testable import MexcKit

// Private responses can't be recorded without the user's key, so each call runs against the example
// in MEXC's documentation for its endpoint (whitespace aside), except funding payments, whose
// documented example is another endpoint's response. The closed-positions example is an array while
// the documented fields describe a page; both shapes are tested, since nothing else shows which MEXC
// sends.
@Suite("Position endpoints")
struct PositionEndpointsTests {
    @Test func `open positions decode at full precision`() async throws {
        let (positions, url) = try await call(fixture: "Position/open_positions") { try await $0.list() }
        #expect(url == "https://api.mexc.com/api/v1/private/position/open_positions")
        #expect(positions == [.init(
            id: .init(rawValue: "1109973831"), symbol: "BTC_USDT", side: .long, marginMode: .isolated,
            state: .holding, leverage: 2, volume: 5, frozenVolume: 0, closedVolume: 0,
            averagePrice: Decimal(string: "109777.5")!, averageOpenPrice: Decimal(string: "109777.5")!,
            averageClosePrice: 0, liquidationPrice: Decimal(string: "55020.5")!,
            initialMargin: Decimal(string: "27.444375")!, originalInitialMargin: Decimal(string: "27.444375")!,
            funding: 0, realizedProfit: 0, addsMarginAutomatically: false,
            unrealizedProfit: Decimal(string: "-0.0039")!, closingProfit: 0, profitRatio: 0,
            marginRatio: Decimal(string: "0.0027")!, fee: 0, totalFee: 0, autoDeleveragingLevel: nil,
            createdAt: Date(timeIntervalSince1970: 1_761_887_133.854),
            updatedAt: Date(timeIntervalSince1970: 1_761_887_133.854)
        )])
    }

    @Test func `open positions filtered by symbol and ID`() async throws {
        let (_, url) = try await call(fixture: "Position/open_positions") {
            try await $0.list("BTC_USDT", position: .init(rawValue: "1109973831"))
        }
        #expect(url == """
            https://api.mexc.com/api/v1/private/position/open_positions?positionId=1109973831&symbol=BTC_USDT
            """)
    }

    @Test func `the full-precision price wins over the plain number`() throws {
        let json = #"""
            {"positionId":"1","symbol":"BTC_USDT","positionType":2,"openType":2,"state":2,"leverage":10,
             "holdVol":1,"frozenVol":0,"closeVol":0,"holdAvgPrice":0.1,"holdAvgPriceFullyScale":"0.123456789",
             "openAvgPrice":0.1,"closeAvgPrice":0,"liquidatePrice":null,"im":1,"oim":1,"holdFee":-0.5,"realised":0,
             "autoAddIm":true,"adlLevel":3,"createTime":1}
            """#
        let position = try JSONDecoder().decode(MexcFutures.Position.self, from: Data(json.utf8))
        #expect(position.averagePrice == Decimal(string: "0.123456789"))
        #expect(position.averageOpenPrice == Decimal(string: "0.1"))
        #expect(position.side == .short)
        #expect(position.marginMode == .cross)
        #expect(position.state == .systemHeld)
        #expect(position.funding == Decimal(string: "-0.5"))
        #expect(position.liquidationPrice == nil)
        #expect(position.updatedAt == nil)
        #expect(position.autoDeleveragingLevel == 3)
        #expect(position.unrealizedProfit == nil)
        #expect(position.marginRatio == nil)
    }

    @Test func `closed positions from the documented array`() async throws {
        let start = Date(timeIntervalSince1970: 1_754_000_000.5)
        let end = Date(timeIntervalSince1970: 1_758_000_000)
        let (positions, url) = try await call(fixture: "Position/history_positions") {
            try await $0.history("BTC_USDT", side: .long, start: start, end: end, page: .init(number: 3, size: 100))
        }
        #expect(url == """
            https://api.mexc.com/api/v1/private/position/list/history_positions\
            ?end_time=1758000000000&page_num=3&page_size=100&position_type=1&start_time=1754000000500\
            &symbol=BTC_USDT
            """)
        #expect(positions.map(\.id.rawValue) == ["1027177055", "980739233"])
        #expect(positions.allSatisfy { $0.state == .closed && $0.volume == 0 && $0.marginRatio == nil })
        #expect(positions[0].averageClosePrice == Decimal(string: "113572.3"))
        #expect(positions[0].realizedProfit == Decimal(string: "0.2155"))
        #expect(positions[0].closingProfit == Decimal(string: "0.2245"))
        #expect(positions[0].fee == Decimal(string: "-0.009"))
        #expect(positions[1].leverage == 20)
    }

    @Test func `closed positions from a page, as the documented fields describe`() async throws {
        let json = #"""
            {"success":true,"code":0,"data":{"pageSize":20,"totalCount":1,"totalPage":1,"currentPage":1,
             "resultList":[{"positionId":7,"symbol":"ETH_USDT","positionType":1,"openType":1,"state":3,
             "leverage":5,"holdVol":0,"frozenVol":0,"closeVol":3,"holdAvgPrice":2500,"openAvgPrice":2500,
             "closeAvgPrice":2600,"liquidatePrice":0,"im":0,"oim":0,"holdFee":0,"realised":12,
             "autoAddIm":false,"createTime":1,"updateTime":2}]}}
            """#
        let (positions, url) = try await call(json: json) { try await $0.history() }
        #expect(url == "https://api.mexc.com/api/v1/private/position/list/history_positions?page_num=1&page_size=20")
        #expect(positions.map(\.id.rawValue) == ["7"])
    }

    @Test func `a list that is neither an array nor a page throws`() async throws {
        let transport = FakeTransport(json: #"{"success":true,"code":0,"data":{"positionId":7}}"#)
        await #expect(throws: DecodingError.self) {
            try await PositionEndpoints(rest: .test(transport: transport)).history()
        }
    }

    @Test func `funding payments`() async throws {
        // Built from the documented response fields: the documented example is the funding rate.
        let json = #"""
            {"success":true,"code":0,"data":{"pageSize":20,"totalCount":1,"totalPage":1,"currentPage":1,
             "resultList":[{"id":5537,"symbol":"BTC_USDT","positionType":2,"positionValue":109.7775,
             "funding":-0.0010977,"rate":0.00001,"settleTime":1761897600000}]}}
            """#
        let (page, url) = try await call(json: json) {
            try await $0.fundingPayments(
                "BTC_USDT", position: .init(rawValue: "1109973831"), side: .short,
                start: Date(timeIntervalSince1970: 1), end: Date(timeIntervalSince1970: 2), page: .first
            )
        }
        #expect(url == """
            https://api.mexc.com/api/v1/private/position/funding_records\
            ?end_time=2000&page_num=1&page_size=20&position_id=1109973831&position_type=2&start_time=1000\
            &symbol=BTC_USDT
            """)
        #expect(page.items == [.init(
            id: "5537", symbol: "BTC_USDT", side: .short, positionValue: Decimal(string: "109.7775")!,
            amount: Decimal(string: "-0.0010977")!, rate: Decimal(string: "0.00001")!,
            settledAt: Date(timeIntervalSince1970: 1_761_897_600)
        )])
    }

    @Test func `funding payments without filters`() async throws {
        let json = #"{"success":true,"code":0,"data":{"pageSize":20,"totalCount":0,"totalPage":0,"currentPage":1,"resultList":[]}}"#
        let (page, url) = try await call(json: json) { try await $0.fundingPayments() }
        #expect(url == "https://api.mexc.com/api/v1/private/position/funding_records?page_num=1&page_size=20")
        #expect(page.items.isEmpty)
    }

    @Test func `leverage of each side`() async throws {
        let (settings, url) = try await call(fixture: "Position/leverage") { try await $0.leverage("BTC_USDT") }
        #expect(url == "https://api.mexc.com/api/v1/private/position/leverage?symbol=BTC_USDT")
        #expect(settings == [MexcFutures.PositionSide.long, .short].map { side in
            .init(
                side: side, marginMode: .isolated, leverage: 2, maximumLeverage: 500,
                maintenanceMarginRate: Decimal(string: "0.001")!
            )
        })
    }

    @Test func `reversing a position sends its ID as a number`() async throws {
        let transport = FakeTransport(json: #"{"success":true,"code":0}"#)
        try await PositionEndpoints(rest: .test(transport: transport)).reverse(
            .init(rawValue: "1109973831"), in: "BTC_USDT", volume: Decimal(string: "2.5")!
        )
        let sent = try #require(await transport.requests.first)
        #expect(sent.method == .post)
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/position/reverse")
        #expect(sent.bodyText == #"{"positionId":1109973831,"symbol":"BTC_USDT","vol":2.5}"#)
        #expect(sent.headers.contains { $0.name == "Signature" })
    }

    @Test func `closing every position is a signed POST without a body`() async throws {
        let transport = FakeTransport(json: #"{"success":true,"code":0,"data":[]}"#)
        try await PositionEndpoints(rest: .test(transport: transport)).closeAll()
        let sent = try #require(await transport.requests.first)
        #expect(sent.method == .post)
        #expect(sent.url.absoluteString == "https://api.mexc.com/api/v1/private/position/close_all")
        #expect(sent.body == nil)
        #expect(sent.headers.contains { $0.name == "Signature" })
    }

    private func call<Value>(
        fixture: String, _ body: (PositionEndpoints) async throws -> Value
    ) async throws -> (Value, String) {
        try await call(transport: FakeTransport(fixture: fixture), body)
    }

    private func call<Value>(
        json: String, _ body: (PositionEndpoints) async throws -> Value
    ) async throws -> (Value, String) {
        try await call(transport: FakeTransport(json: json), body)
    }

    /// Runs `body` and returns its result and the URL it requested, checking that every request was a
    /// signed GET.
    private func call<Value>(
        transport: FakeTransport, _ body: (PositionEndpoints) async throws -> Value
    ) async throws -> (Value, String) {
        let result = try await body(PositionEndpoints(rest: .test(transport: transport)))
        let requests = await transport.requests
        #expect(requests.count == 1)
        #expect(requests.allSatisfy { $0.method == .get && $0.headers.contains { $0.name == "Signature" } })
        return (result, requests.first?.url.absoluteString ?? "")
    }
}
