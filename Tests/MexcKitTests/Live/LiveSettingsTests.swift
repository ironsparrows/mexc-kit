import MexcKit
import MexcKitTestSupport
import Testing

// Changes the ETH_USDT short leverage and sets it back: the order suites trade BTC_USDT longs, and with
// no position there, MEXC takes the market, side and margin mode. Reads the position mode and the
// self-trade prevention groups without changing them; the groups need a market maker account.
@Suite(
    "Live position settings and self-trade prevention", .tags(.live),
    .enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run"), .timeLimit(.minutes(2))
)
struct LiveSettingsTests {
    private static let eth: MexcFutures.Symbol = "ETH_USDT"
    private let client = MexcFutures.Client(credentials: LiveTestSettings.credentials)

    @Test func `leverage changes and is set back, and settings decode`() async throws {
        let current = try #require(try await client.position.leverage(Self.eth).first { $0.side == .short })
        let changed = current.leverage == 5 ? 6 : 5

        try await client.position.setLeverage(changed, in: Self.eth, side: .short, marginMode: current.marginMode)
        let after = try await client.position.leverage(Self.eth)
        try await client.position.setLeverage(
            current.leverage, in: Self.eth, side: .short, marginMode: current.marginMode
        )

        #expect(after.contains { $0.side == .short && $0.leverage == changed })
        _ = try await client.account.positionMode()
    }

    @Test func `self-trade prevention groups decode`() async throws {
        _ = try await client.selfTradePrevention.groups()
        _ = try await client.selfTradePrevention.currentGroup()
    }
}
