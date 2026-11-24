import Foundation
import Testing
@testable import MexcKit

// Private responses can't be recorded without the user's key, so each call runs against the example
// in MEXC's documentation for its endpoint (whitespace aside): the exact URL it signs and sends, and
// what it decodes. Tests that use other responses say so.
@Suite("Account endpoints")
struct AccountEndpointsTests {
    @Test func `every balance`() async throws {
        let (balances, url) = try await call("Account/assets") { try await $0.balances() }
        #expect(url == "https://api.mexc.com/api/v1/private/account/assets")
        #expect(balances == [.init(
            asset: "USDT", available: Decimal(string: "32.80984793658")!, frozen: 0, positionMargin: 0,
            cash: Decimal(string: "32.80984793")!, equity: Decimal(string: "32.80984793")!, unrealizedProfit: 0,
            transferable: Decimal(string: "32.80984793658")!, availableToOpen: Decimal(string: "32.80984793658")!,
            bonus: 0, bonusExpiresAt: nil, debt: 0, contributedMargin: 0
        )])
    }

    @Test func `one balance keeps every digit`() async throws {
        let (balance, url) = try await call("Account/asset") { try await $0.balance("MX") }
        #expect(url == "https://api.mexc.com/api/v1/private/account/asset/MX")
        #expect(balance.asset == "MX")
        #expect(balance.available == Decimal(string: "0.99647149597724856"))
    }

    @Test func `a balance without the optional fields`() throws {
        let json = #"""
            {"currency":"USDT","positionMargin":1,"availableBalance":2,"cashBalance":3,"frozenBalance":4,
             "equity":5,"unrealized":-6,"bonusExpireTime":1760537642000}
            """#
        let balance = try JSONDecoder().decode(MexcFutures.Balance.self, from: Data(json.utf8))
        #expect(balance.unrealizedProfit == -6)
        #expect(balance.bonusExpiresAt == Date(timeIntervalSince1970: 1_760_537_642))
        #expect(balance.transferable == nil)
        #expect(balance.availableToOpen == nil)
        #expect(balance.bonus == nil)
        #expect(balance.debt == nil)
        #expect(balance.contributedMargin == nil)
    }

    @Test func `transfers with every filter`() async throws {
        let (page, url) = try await call("Account/transfer_record") {
            try await $0.transfers(asset: "USDT", direction: .incoming, state: .succeeded, page: .init(number: 2, size: 50))
        }
        #expect(url == """
            https://api.mexc.com/api/v1/private/account/transfer_record\
            ?currency=USDT&page_num=2&page_size=50&state=SUCCESS&type=IN
            """)
        #expect(page.totalCount == 1)
        #expect(page.items == [.init(
            id: "303381159", transactionID: "86f334f8850346e89ce4d0ba52b7aa87", asset: "USDT", amount: 1,
            direction: .incoming, state: .succeeded, createdAt: Date(timeIntervalSince1970: 1_760_537_642),
            updatedAt: Date(timeIntervalSince1970: 1_760_537_641)
        )])
    }

    @Test func `transfers without filters`() async throws {
        let (_, url) = try await call("Account/transfer_record") { try await $0.transfers() }
        #expect(url == "https://api.mexc.com/api/v1/private/account/transfer_record?page_num=1&page_size=20")
    }

    @Test(arguments: [(MexcFutures.ProfitRatePeriod.day, "1"), (.week, "2")])
    func `the profit rate of a period`(period: MexcFutures.ProfitRatePeriod, segment: String) async throws {
        let (rate, url) = try await call("Account/profit_rate") { try await $0.profitRate(period) }
        #expect(url == "https://api.mexc.com/api/v1/private/account/profit_rate/\(segment)")
        #expect(rate == .init(rate: 0, time: Date(timeIntervalSince1970: 1_666_612_800)))
    }

    @Test func `risk limits come flat, by symbol then side`() async throws {
        let (limits, url) = try await call("Account/risk_limit") { try await $0.riskLimits("BTC_USDT") }
        #expect(url == "https://api.mexc.com/api/v1/private/account/risk_limit?symbol=BTC_USDT")
        #expect(limits == [
            .init(symbol: "BTC_USDT", side: .long, marginMode: .isolated, limit: .init(
                level: 1, maximumVolume: 50_000, maintenanceMarginRate: Decimal(string: "0.001")!,
                initialMarginRate: Decimal(string: "0.002")!, maximumLeverage: 500
            )),
            .init(symbol: "BTC_USDT", side: .short, marginMode: .isolated, limit: .init(
                level: 6, maximumVolume: 4_500_000, maintenanceMarginRate: Decimal(string: "0.05")!,
                initialMarginRate: Decimal(string: "0.1")!, maximumLeverage: 500
            )),
        ])
    }

    @Test func `risk limits of every market are sorted across symbols`() async throws {
        let json = #"""
            {"success":true,"code":0,"data":{
             "ETH_USDT":[{"symbol":"ETH_USDT","positionType":2,"level":1,"maxVol":1,"mmr":0.01,"imr":0.02,"maxLeverage":100},
                         {"symbol":"ETH_USDT","positionType":1,"openType":2,"level":1,"maxVol":1,"mmr":0.01,"imr":0.02,"maxLeverage":100},
                         {"symbol":"ETH_USDT","positionType":1,"openType":1,"level":1,"maxVol":1,"mmr":0.01,"imr":0.02,"maxLeverage":100}],
             "BTC_USDT":[{"symbol":"BTC_USDT","positionType":1,"level":1,"maxVol":1,"mmr":0.01,"imr":0.02,"maxLeverage":100}]}}
            """#
        let transport = FakeTransport(json: json)
        let limits = try await AccountEndpoints(rest: .test(transport: transport)).riskLimits()
        #expect(await transport.requests.first?.url.absoluteString == "https://api.mexc.com/api/v1/private/account/risk_limit")
        #expect(limits.map { "\($0.symbol) \($0.side.rawValue) \($0.marginMode?.rawValue ?? 0)" } == [
            "BTC_USDT 1 0", "ETH_USDT 1 1", "ETH_USDT 1 2", "ETH_USDT 2 0",
        ])
    }

    @Test func `the position mode`() async throws {
        let (mode, url) = try await call("Account/position_mode") { try await $0.positionMode() }
        #expect(url == "https://api.mexc.com/api/v1/private/position/position_mode")
        #expect(mode == .hedge)
    }

    @Test func `the one-way position mode`() async throws {
        let transport = FakeTransport(json: #"{"success":true,"code":0,"data":2}"#)
        #expect(try await AccountEndpoints(rest: .test(transport: transport)).positionMode() == .oneWay)
    }

    @Test func `fee rates in one market, with their tiers`() async throws {
        let (rates, url) = try await call("Account/tiered_fee_rate") { try await $0.feeRates("BTC_USDT") }
        #expect(url == "https://api.mexc.com/api/v1/private/account/tiered_fee_rate/v2?symbol=BTC_USDT")
        #expect(rates == .init(
            symbol: "BTC_USDT", maker: 0, taker: 0, standardMaker: 0, standardTaker: 0, mode: .tiered,
            joinsDiscount: true, receivesDiscount: true, discountRate: Decimal(string: "0.5")!, joinsDeduction: true,
            receivesDeduction: true, deductionRate: Decimal(string: "0.8")!, tradedAmount: 0,
            walletBalance: Decimal(string: "35.10272884")!,
            tiers: [
                .init(
                    minimumTradedAmount: 0, maximumTradedAmount: 10_000_000, maker: 0, taker: 0, standardMaker: 0,
                    standardTaker: 0
                ),
                .init(
                    minimumTradedAmount: 10_000_001, maximumTradedAmount: nil, maker: Decimal(string: "0.00005")!,
                    taker: Decimal(string: "0.0002")!, standardMaker: Decimal(string: "0.0001")!,
                    standardTaker: Decimal(string: "0.0004")!
                ),
            ],
            tierTradedAmount: 54, leverage: 1...50
        ))
    }

    @Test func `fee rates without the fields MEXC doesn't mark as always sent`() async throws {
        // Not MEXC's example: its documented fields, without the optional ones.
        let (rates, url) = try await call(json: """
            {"success":true,"code":0,"data":{"joinDiscount":false,"enjoyDiscount":false,"discountRate":1,\
            "joinDeduct":false,"enjoyDeduct":false,"deductRate":1,"originalMakerFee":0.0001,"originalTakerFee":0.0004,\
            "realMakerFee":0.0001,"realTakerFee":0.0004,"dealAmount":12.5,"feeRateMode":"NORMAL"}}
            """) { try await $0.feeRates(nil) }
        #expect(url == "https://api.mexc.com/api/v1/private/account/tiered_fee_rate/v2")
        #expect(rates.symbol == nil && rates.walletBalance == nil && rates.leverage == nil)
        #expect(rates.mode == .normal)
        #expect(rates.tiers.isEmpty)
    }

    @Test func `fee rates whose leverage range is reversed throw`() async throws {
        // Not MEXC's example: a malformed range.
        let transport = FakeTransport(json: """
            {"success":true,"code":0,"data":{"joinDiscount":false,"enjoyDiscount":false,"discountRate":1,\
            "joinDeduct":false,"enjoyDeduct":false,"deductRate":1,"originalMakerFee":0,"originalTakerFee":0,\
            "realMakerFee":0,"realTakerFee":0,"dealAmount":0,"feeRateMode":"NORMAL","minLeverage":50,"maxLeverage":1}}
            """)
        await #expect(throws: DecodingError.self) {
            try await AccountEndpoints(rest: .test(transport: transport)).feeRates(nil)
        }
    }

    @Test func `fee totals`() async throws {
        let (totals, url) = try await call("Account/order_deal_fee_total") { try await $0.feeTotals() }
        #expect(url == "https://api.mexc.com/api/v1/private/account/asset_book/order_deal_fee/total")
        #expect(totals == .init(paid: 0, saved: 0))
    }

    @Test func `discount usage`() async throws {
        let (usage, url) = try await call("Account/discountType") { try await $0.discountUsage() }
        #expect(url == "https://api.mexc.com/api/v1/private/account/discountType")
        #expect(usage == .init(usesSpotDiscount: true, usesDeduction: false))
    }

    @Test func `fee deduction assets`() async throws {
        let (assets, url) = try await call("Account/feeDeductConfigs") { try await $0.feeDeductionAssets() }
        #expect(url == "https://api.mexc.com/api/v1/private/account/feeDeductConfigs")
        #expect(assets == [
            .init(asset: "MX", settlementAsset: "USDT", discountRatio: Decimal(string: "0.8")!),
            .init(asset: "MXPOINT", settlementAsset: "USDT", discountRatio: 1),
        ])
    }

    @Test func `fee discounts read the levels inside their string`() async throws {
        let (discounts, url) = try await call("Account/contractFeeDiscountConfig") { try await $0.feeDiscounts() }
        #expect(url == "https://api.mexc.com/api/v1/private/account/config/contractFeeDiscountConfig")
        #expect(discounts == [
            .init(asset: "MX", isEnabled: true, levels: [
                .init(number: 1, bounds: 500...2_147_483_647, days: 1, discount: Decimal(string: "0.5")!),
            ]),
        ])
    }

    @Test(arguments: [#""discountConfig":"","#, ""])
    func `a fee discount without levels has none`(levels: String) async throws {
        // Not MEXC's example: an empty or missing level list.
        let (discounts, _) = try await call(json: """
            {"success":true,"code":200,"data":[{\(levels)"currency":"BNB","state":"DISABLED"}]}
            """) { try await $0.feeDiscounts() }
        #expect(discounts == [.init(asset: "BNB", isEnabled: false, levels: [])])
    }

    @Test func `a fee discount whose levels aren't a list throws`() async throws {
        // Not MEXC's example: a malformed level string.
        let transport = FakeTransport(json: #"""
            {"success":true,"code":200,"data":[{"currency":"MX","state":"ENABLED","discountConfig":"{\"level\":1}"}]}
            """#)
        await #expect(throws: DecodingError.self) {
            try await AccountEndpoints(rest: .test(transport: transport)).feeDiscounts()
        }
    }

    @Test func `fee deductions of fills`() async throws {
        let (deductions, url) = try await call("Account/fee_details") {
            try await $0.feeDeductions(
                "BTC_USDT", fills: [.init(rawValue: "54236193"), .init(rawValue: "52060733")],
                start: Date(timeIntervalSince1970: 1), end: Date(timeIntervalSince1970: 2), page: .first
            )
        }
        #expect(url == """
            https://api.mexc.com/api/v1/private/order/fee_details\
            ?end_time=2000&ids=54236193%2C52060733&page_num=1&page_size=20&start_time=1000&symbol=BTC_USDT
            """)
        #expect(deductions == [
            .init(
                fillID: .init(rawValue: "54236193"), orderID: .init(rawValue: "739132568196170240"), symbol: nil,
                fee: Decimal(string: "0.0906990372")!, feeAsset: "USDT", source: .trialBonus,
                deductedFee: Decimal(string: "0.0906990372")!, deductedFeeAsset: "USDT",
                filledAt: Date(timeIntervalSince1970: 1_761_893_337)
            ),
            .init(
                fillID: .init(rawValue: "52060733"), orderID: .init(rawValue: "735908917455962624"), symbol: nil,
                fee: Decimal(string: "0.297936756")!, feeAsset: "USDT", source: .notDeducted, deductedFee: nil,
                deductedFeeAsset: nil, filledAt: Date(timeIntervalSince1970: 1_761_124_758)
            ),
        ])
    }

    @Test func `a deduction source sent as a string, as documented, decodes`() async throws {
        // Not MEXC's example: the field as its table types it.
        let (deductions, url) = try await call(json: """
            {"success":true,"code":0,"data":[{"id":1,"orderId":2,"symbol":"BTC_USDT","feeCurrency":"USDT","fee":0,\
            "deductType":"1","timestamp":1}]}
            """) { try await $0.feeDeductions("BTC_USDT") }
        #expect(url == "https://api.mexc.com/api/v1/private/order/fee_details?page_num=1&page_size=20&symbol=BTC_USDT")
        #expect(deductions.map(\.source) == [.mxPoint])
        #expect(deductions.map(\.symbol) == ["BTC_USDT"])
    }

    @Test func `a deduction source that isn't a number throws`() async throws {
        let transport = FakeTransport(json: """
            {"success":true,"code":0,"data":[{"id":1,"orderId":2,"feeCurrency":"USDT","fee":0,"deductType":"x",\
            "timestamp":1}]}
            """)
        await #expect(throws: DecodingError.self) {
            try await AccountEndpoints(rest: .test(transport: transport)).feeDeductions("BTC_USDT")
        }
    }

    private func call<Value>(
        _ fixture: String, _ body: (AccountEndpoints) async throws -> Value
    ) async throws -> (Value, String) {
        try await call(transport: FakeTransport(fixture: fixture), body)
    }

    private func call<Value>(
        json: String, _ body: (AccountEndpoints) async throws -> Value
    ) async throws -> (Value, String) {
        try await call(transport: FakeTransport(json: json), body)
    }

    /// Runs `body` and returns its result and the URL it requested, checking that every request was a
    /// signed GET.
    private func call<Value>(
        transport: FakeTransport, _ body: (AccountEndpoints) async throws -> Value
    ) async throws -> (Value, String) {
        let result = try await body(AccountEndpoints(rest: .test(transport: transport)))
        let requests = await transport.requests
        #expect(requests.count == 1)
        #expect(requests.allSatisfy { $0.method == .get && $0.headers.contains { $0.name == "Signature" } })
        return (result, requests.first?.url.absoluteString ?? "")
    }
}
