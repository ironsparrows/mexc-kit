import Foundation
import MexcKit
import MexcKitTestSupport
import Testing

// Places small real orders: opens the smallest long in BTC_USDT, puts a stop-loss 10% below the market
// and a trailing close that activates only 50% above it on the position, places a plan order that
// triggers only 50% above the market, cancels all three and closes the position. It changes things first
// and reads afterwards, so a read that fails to decode leaves nothing open; the pending stop orders are
// read after the cancel, so they decode only if MEXC still lists one.
extension LiveTrading {
    @Suite(
        "Live plan, stop and trailing orders", .tags(.live),
        .enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run"), .timeLimit(.minutes(2))
    )
    struct LiveConditionalOrderTests {
        private static let btc: MexcFutures.Symbol = "BTC_USDT"
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

            _ = try await client.stopOrder.pending(Self.btc)
            _ = try await client.stopOrder.list(Self.btc)
            _ = try await client.trailingOrder.list(Self.btc)
            _ = try await client.planOrder.list(Self.btc, from: started.addingTimeInterval(-60), to: .now)
        }
    }
}
