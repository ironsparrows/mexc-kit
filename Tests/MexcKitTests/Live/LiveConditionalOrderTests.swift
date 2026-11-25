import Foundation
import MexcKit
import MexcKitTestSupport
import Testing

// Places small real orders: opens the smallest long in BTC_USDC, puts a stop-loss 10% below the market
// and a trailing close that activates only 50% above it on the position, places a plan order that
// triggers only 50% above the market, cancels all three and closes the position. It changes things first
// and reads afterwards, so a read that fails to decode leaves nothing open; the pending stop orders are
// read after the cancel, so they decode only if MEXC still lists one. A second test, on another such
// long, changes each kind before canceling it: the stop-loss and a take-profit of the stop order, the
// trailing order's callback and activation price, and the plan order's trigger and attached stops; then
// cancels the stop orders by position and the plan orders by market.
extension LiveTrading {
    @Suite(
        "Live plan, stop and trailing orders", .tags(.live),
        .enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run"), .timeLimit(.minutes(2))
    )
    struct LiveConditionalOrderTests {
        private static let btc: MexcFutures.Symbol = "BTC_USDC"
        private let client = MexcFutures.Client(credentials: LiveTestSettings.credentials)

        @Test func `each kind is placed and canceled, and every read decodes`() async throws {
            let contract = try await client.market.contract(Self.btc)
            let last = try await client.market.ticker(Self.btc).lastPrice
            let mode = try await client.account.positionMode()
            let volume = contract.minimumVolume
            let started = Date.now

            _ = try await client.order.place(
                .open(.long, Self.btc, .market, volume: volume, leverage: 5, marginMode: .isolated, options: .init(positionMode: mode))
            )
            let position = try #require(try await client.position.list(Self.btc).first { $0.side == .long })

            let stop = try await client.stopOrder.place(.init(
                position: position.id, volume: volume,
                stopLoss: .market(at: contract.round(price: last * Decimal(string: "0.9")!, rule: .down))
            ))
            let trailing = try await client.trailingOrder.place(.close(
                .long, Self.btc, volume: volume, leverage: 5, marginMode: .isolated, callback: .percentage(Decimal(string: "0.05")!),
                activationPrice: contract.round(price: last * Decimal(string: "1.5")!, rule: .up), positionMode: mode
            ))
            let plan = try await client.planOrder.place(.open(
                .long, Self.btc, .market, volume: volume, leverage: 5, marginMode: .isolated,
                trigger: .init(price: contract.round(price: last * Decimal(string: "1.5")!, rule: .up), condition: .atOrAbove),
                lifetime: .oneDay, options: .init(positionMode: mode)
            ))

            try await client.stopOrder.cancel(stop)
            try await client.trailingOrder.cancel(trailing, in: Self.btc)
            try await client.planOrder.cancel(plan, in: Self.btc)
            _ = try await client.order.place(.close(
                .long, Self.btc, .market, volume: volume, marginMode: .isolated, position: position.id,
                options: .init(positionMode: mode)
            ))

            await #expect(throws: Never.self) { _ = try await client.stopOrder.pending(Self.btc) }
            await #expect(throws: Never.self) { _ = try await client.stopOrder.list(Self.btc) }
            await #expect(throws: Never.self) { _ = try await client.trailingOrder.list(Self.btc) }
            await #expect(throws: Never.self) {
                _ = try await client.planOrder.list(Self.btc, from: started.addingTimeInterval(-60), to: .now)
            }
        }

        @Test func `each kind is changed, then canceled in bulk`() async throws {
            let started = Date.now
            let contract = try await client.market.contract(Self.btc)
            let last = try await client.market.ticker(Self.btc).lastPrice
            let mode = try await client.account.positionMode()
            let volume = contract.minimumVolume
            func above(_ factor: String) -> Decimal { contract.round(price: last * Decimal(string: factor)!, rule: .up) }
            func below(_ factor: String) -> Decimal { contract.round(price: last * Decimal(string: factor)!, rule: .down) }

            _ = try await client.order.place(
                .open(.long, Self.btc, .market, volume: volume, leverage: 5, marginMode: .isolated, options: .init(positionMode: mode))
            )
            let position = try #require(try await client.position.list(Self.btc).first { $0.side == .long })

            // Checked as one step, so the close and the cancels below always run.
            await #expect(throws: Never.self) {
                let stop = try await client.stopOrder.place(.init(
                    position: position.id, volume: volume, stopLoss: .market(at: below("0.9"))
                ))
                try await client.stopOrder.modify(stop, takeProfit: .init(price: above("1.5")), stopLoss: .init(price: below("0.85")))

                let trailing = try await client.trailingOrder.place(.close(
                    .long, Self.btc, volume: volume, leverage: 5, marginMode: .isolated, callback: .percentage(Decimal(string: "0.05")!),
                    activationPrice: above("1.5"), positionMode: mode
                ))
                try await client.trailingOrder.modify(
                    trailing, in: Self.btc, volume: volume, callback: .percentage(Decimal(string: "0.06")!),
                    activationPrice: above("1.6"), source: .last
                )

                let plan = try await client.planOrder.place(.open(
                    .long, Self.btc, .limit(price: above("1.5")), volume: volume, leverage: 5, marginMode: .isolated,
                    trigger: .init(price: above("1.5"), condition: .atOrAbove), lifetime: .oneDay, options: .init(positionMode: mode)
                ))
                try await client.planOrder.modify(
                    plan, in: Self.btc, trigger: .init(price: above("1.6"), condition: .atOrAbove), pricing: .limit(price: above("1.6"))
                )
                try await client.planOrder.setAttachedStops(
                    of: plan, in: Self.btc, takeProfit: .init(price: above("2")), stopLoss: .init(price: above("1.4"))
                )

                try await client.stopOrder.cancelAll(position: position.id)
                try await client.trailingOrder.cancel(trailing, in: Self.btc)
                try await client.planOrder.cancelAll(Self.btc)
            }
            _ = try await client.order.place(.close(
                .long, Self.btc, .market, volume: volume, marginMode: .isolated, position: position.id,
                options: .init(positionMode: mode)
            ))
            // Left over only when the step above failed: there may be nothing to cancel.
            _ = try? await client.planOrder.cancelAll(Self.btc)
            _ = try? await client.stopOrder.cancelAll(Self.btc)

            await #expect(throws: Never.self) { _ = try await client.stopOrder.list(Self.btc) }
            await #expect(throws: Never.self) { _ = try await client.trailingOrder.list(Self.btc) }
            await #expect(throws: Never.self) {
                _ = try await client.planOrder.list(Self.btc, from: started.addingTimeInterval(-60), to: .now)
            }
        }
    }
}
