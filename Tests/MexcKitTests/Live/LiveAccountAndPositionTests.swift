import MexcKit
import MexcKitTestSupport
import Testing

@Suite(
    "Live account and positions", .tags(.live), .enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run"),
    .timeLimit(.minutes(2))
)
struct LiveAccountAndPositionTests {
    private static let btc: MexcFutures.Symbol = "BTC_USDT"
    private let client = MexcFutures.Client(credentials: LiveTestSettings.credentials)

    @Test func `the account decodes`() async throws {
        _ = try await client.account.balances()
        #expect(try await client.account.balance("USDT").asset == "USDT")
        _ = try await client.account.transfers()
        _ = try await client.account.profitRate(.day)
        _ = try await client.account.profitRate(.week)
        _ = try await client.account.riskLimits(Self.btc)
        _ = try await client.account.positionMode()
        _ = try await client.account.feeRates()
        _ = try await client.account.feeRates(Self.btc)
        _ = try await client.account.feeTotals()
        _ = try await client.account.discountUsage()
        _ = try await client.account.feeDeductionAssets()
        _ = try await client.account.feeDiscounts()
        _ = try await client.account.feeDeductions(Self.btc)
    }

    @Test func `positions decode`() async throws {
        _ = try await client.position.list()
        _ = try await client.position.history()
        _ = try await client.position.fundingPayments()
        #expect(try await client.position.leverage(Self.btc).isEmpty == false)
    }
}
