import MexcKit
import MexcKitTestSupport
import Testing

extension MexcKitTests {
    @Suite(
        "Live account and positions", .tags(.live), .enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run"),
        .timeLimit(.minutes(2))
    )
    struct LiveAccountAndPositionTests {
        private static let btc: MexcFutures.Symbol = "BTC_USDT"
        private let client = MexcFutures.Client(credentials: LiveTestSettings.credentials)

        // Each read is checked on its own, so one that doesn't decode doesn't hide the ones after it.
        @Test func `the account decodes`() async throws {
            await #expect(throws: Never.self) { _ = try await client.account.balances() }
            await #expect(throws: Never.self) {
                let balance = try await client.account.balance("USDT")
                #expect(balance.asset == "USDT")
            }
            await #expect(throws: Never.self) { _ = try await client.account.transfers() }
            await #expect(throws: Never.self) { _ = try await client.account.profitRate(.day) }
            await #expect(throws: Never.self) { _ = try await client.account.profitRate(.week) }
            await #expect(throws: Never.self) { _ = try await client.account.riskLimits(Self.btc) }
            await #expect(throws: Never.self) { _ = try await client.account.positionMode() }
            await #expect(throws: Never.self) { _ = try await client.account.feeRates() }
            await #expect(throws: Never.self) { _ = try await client.account.feeRates(Self.btc) }
            await #expect(throws: Never.self) { _ = try await client.account.feeTotals() }
            await #expect(throws: Never.self) { _ = try await client.account.discountUsage() }
            await #expect(throws: Never.self) { _ = try await client.account.feeDeductionAssets() }
            await #expect(throws: Never.self) { _ = try await client.account.feeDiscounts() }
            await #expect(throws: Never.self) { _ = try await client.account.feeDeductions(Self.btc) }
        }

        @Test func `positions decode`() async throws {
            await #expect(throws: Never.self) { _ = try await client.position.list() }
            await #expect(throws: Never.self) { _ = try await client.position.history() }
            await #expect(throws: Never.self) { _ = try await client.position.fundingPayments() }
            #expect(try await client.position.leverage(Self.btc).isEmpty == false)
        }
    }
}
