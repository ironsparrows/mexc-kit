import Foundation
import MexcKit
import MexcKitTestSupport
import Testing

// Places small real orders: opens the smallest long in BTC_USDT and closes it, and rests a post-only buy
// 5% below the market, inside MEXC's price band, then changes and cancels it. Each test changes things
// first and reads afterwards, so a read that fails to decode leaves nothing open.
extension LiveTrading {
    @Suite(
        "Live orders", .tags(.live), .enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run"),
        .timeLimit(.minutes(2))
    )
    struct LiveOrderTests {
        private static let btc: MexcFutures.Symbol = "BTC_USDT"
        private let client = MexcFutures.Client(credentials: LiveTestSettings.credentials)

        @Test func `a position opens and closes, and every order read decodes`() async throws {
            let contract = try await client.market.contract(Self.btc)
            let options = MexcFutures.OrderRequest.Options(positionMode: try await client.account.positionMode())
            let volume = contract.minimumVolume

            let opened = try await client.order.place(
                .open(.long, Self.btc, .market, volume: volume, leverage: 5, marginMode: .isolated, options: options)
            )
            let positions = try await client.position.list(Self.btc)
            let position = try #require(positions.first { $0.side == .long })
            let closed = try await client.order.place(
                .close(.long, Self.btc, .market, volume: volume, marginMode: .isolated, position: position.id, options: options)
            )

            await #expect(throws: Never.self) { _ = try await client.order.get(opened.id) }
            // Two IDs, so the comma in `order_ids` is signed and sent.
            await #expect(throws: Never.self) { _ = try await client.order.get([opened.id, closed.id]) }
            await #expect(throws: Never.self) { _ = try await client.order.fills(of: opened.id) }
            await #expect(throws: Never.self) { _ = try await client.order.pendingCounts() }
            await #expect(throws: Never.self) { _ = try await client.order.history(Self.btc) }
            await #expect(throws: Never.self) { _ = try await client.order.closed(Self.btc) }
            await #expect(throws: Never.self) { _ = try await client.order.fills(Self.btc) }
        }

        @Test func `a resting order is changed and canceled, and every read decodes`() async throws {
            let contract = try await client.market.contract(Self.btc)
            let ticker = try await client.market.ticker(Self.btc)
            let options = MexcFutures.OrderRequest.Options(positionMode: try await client.account.positionMode())
            let price = contract.round(price: ticker.lastPrice * Decimal(string: "0.95")!, rule: .down)
            let externalID = MexcFutures.ExternalOrderID(rawValue: "live-\(UUID().uuidString.prefix(8))")

            let placed = try await client.order.place(
                .open(
                    .long, Self.btc, .postOnly(price: price), volume: contract.minimumVolume, leverage: 5,
                    marginMode: .isolated, externalID: externalID, options: options
                )
            )
            // MEXC may answer a change with a new order ID, so each cancel below reports per order instead of
            // throwing, and the last one cancels whatever still rests.
            let modified = try await client.order.modify(
                placed.id, price: price - contract.priceTick, volume: contract.minimumVolume
            )
            _ = try await client.order.cancel(externalIDs: [externalID], in: Self.btc)
            _ = try await client.order.cancel([modified])
            try await client.order.cancelAll(Self.btc)

            await #expect(throws: Never.self) { _ = try await client.order.pending() }
            await #expect(throws: Never.self) { _ = try await client.order.get(externalID: externalID, in: Self.btc) }
            await #expect(throws: Never.self) { _ = try await client.order.get(externalIDs: [externalID], in: Self.btc) }
        }
    }
}
