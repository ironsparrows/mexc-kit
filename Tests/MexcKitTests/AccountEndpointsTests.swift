import Foundation
import Testing
@testable import MexcKit

// Private responses can't be recorded without the user's key, so each call runs against the example
// in MEXC's documentation for its endpoint (whitespace aside): the exact URL it signs and sends, and
// what it decodes.
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

    /// Runs `body` against the fixture and returns its result and the URL it requested, checking that
    /// every request was a signed GET.
    private func call<Value>(
        _ fixture: String, _ body: (AccountEndpoints) async throws -> Value
    ) async throws -> (Value, String) {
        let transport = try FakeTransport(fixture: fixture)
        let result = try await body(AccountEndpoints(rest: .test(transport: transport)))
        let requests = await transport.requests
        #expect(requests.count == 1)
        #expect(requests.allSatisfy { $0.method == .get && $0.headers.contains { $0.name == "Signature" } })
        return (result, requests.first?.url.absoluteString ?? "")
    }
}
