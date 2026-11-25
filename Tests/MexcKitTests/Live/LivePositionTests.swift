import Foundation
import MexcKit
import MexcKitTestSupport
import Testing

// Places small real orders and changes the account's settings. The first test opens the smallest long in
// BTC_USDC, adds margin and removes it, turns automatic margin on and off, changes the position's
// leverage and sets it back, reverses the long into a short, and closes every position in every market.
// Meanwhile the risk limit, liquidation risk, liquidation notice, leverage mode and trial bonus streams
// stay open: they push only on events, and whatever arrives must decode. The second test switches the
// account's position mode and back, which resets the risk limit level to 1 when leaving hedge mode, and
// turns multi-asset mode on and off, which leaves it off; the position mode stream must push and decode.
extension MexcKitTests.LiveTrading {
    @Suite(
        "Live position changes", .tags(.live),
        .enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run"), .timeLimit(.minutes(2))
    )
    struct LivePositionTests {
        private static let btc: MexcFutures.Symbol = "BTC_USDC"
        private let client = MexcFutures.Client(credentials: LiveTestSettings.credentials)

        @Test func `a position's margin and leverage change, and it reverses and every position closes`() async throws {
            let riskLimits = collectUntilCancelled(client.stream.riskLimits([Self.btc]))
            let liquidationRisks = collectUntilCancelled(client.stream.liquidationRisks([Self.btc]))
            let liquidationNotices = collectUntilCancelled(client.stream.liquidationNotices())
            let leverageModes = collectUntilCancelled(client.stream.leverageModes())
            let trialBonuses = collectUntilCancelled(client.stream.trialBonuses())
            defer {
                riskLimits.cancel()
                liquidationRisks.cancel()
                liquidationNotices.cancel()
                leverageModes.cancel()
                trialBonuses.cancel()
            }
            // The streams log in and filter before MEXC pushes anything; nothing acknowledges the filter.
            try await Task.sleep(for: .seconds(3))

            let contract = try await client.market.contract(Self.btc)
            let options = MexcFutures.OrderRequest.Options(positionMode: try await client.account.positionMode())
            let volume = contract.minimumVolume
            _ = try await client.order.place(
                .open(.long, Self.btc, .market, volume: volume, leverage: 5, marginMode: .isolated, options: options)
            )
            // Checked as one step, so closing every position below always runs.
            await #expect(throws: Never.self) {
                let position = try #require(try await client.position.list(Self.btc).first { $0.side == .long })
                try await client.position.adjustMargin(of: position.id, by: 1)
                try await client.position.adjustMargin(of: position.id, by: -1)
                try await client.position.setAddsMarginAutomatically(!position.addsMarginAutomatically, of: position.id)
                try await client.position.setAddsMarginAutomatically(position.addsMarginAutomatically, of: position.id)
                try await client.position.setLeverage(position.leverage == 5 ? 6 : 5, of: position.id)
                try await client.position.setLeverage(position.leverage, of: position.id)
                try await client.position.reverse(position.id, in: Self.btc, volume: volume)
            }
            try await client.position.closeAll()
            #expect(try await client.position.list(Self.btc).isEmpty)

            riskLimits.cancel()
            liquidationRisks.cancel()
            liquidationNotices.cancel()
            leverageModes.cancel()
            trialBonuses.cancel()
            await #expect(throws: Never.self) { _ = try await riskLimits.value }
            await #expect(throws: Never.self) { _ = try await liquidationRisks.value }
            await #expect(throws: Never.self) { _ = try await liquidationNotices.value }
            await #expect(throws: Never.self) { _ = try await leverageModes.value }
            await #expect(throws: Never.self) { _ = try await trialBonuses.value }
        }

        @Test func `the account's position mode and multi-asset mode change and are set back`() async throws {
            let positionModes = collectUntilCancelled(client.stream.positionModes())
            defer { positionModes.cancel() }
            try await Task.sleep(for: .seconds(3))

            let mode = try await client.account.positionMode()
            try await client.account.setPositionMode(mode == .hedge ? .oneWay : .hedge)
            try await client.account.setPositionMode(mode)
            try await client.account.setMultiAssetMode(true)
            try await client.account.setMultiAssetMode(false)
            #expect(try await client.account.positionMode() == mode)

            // MEXC pushes each change shortly after it answers.
            try await Task.sleep(for: .seconds(2))
            positionModes.cancel()
            let pushed = try await positionModes.value
            #expect(pushed.last == mode)
        }
    }
}
