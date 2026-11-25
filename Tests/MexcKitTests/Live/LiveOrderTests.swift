import Foundation
import MexcKit
import MexcKitTestSupport
import Testing

// Places small real orders: opens the smallest long in BTC_USDC and closes it, and rests a post-only buy
// 5% below the market, inside MEXC's price band, then changes and cancels it. Each test changes things
// first and reads afterwards, so a read that fails to decode leaves nothing open. A third test places
// two resting orders in a batch, another with an external ID, and a limit buy it chases to the best bid,
// cancels them by ID, by external ID and in every market, and closes the long the chase may have
// opened. Batches need a market maker account; MEXC's refusal is a known issue.
extension LiveTrading {
    @Suite(
        "Live orders", .tags(.live), .enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run"),
        .timeLimit(.minutes(2))
    )
    struct LiveOrderTests {
        private static let btc: MexcFutures.Symbol = "BTC_USDC"
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
            // MEXC sometimes answers a change right after placing with 2054, its "try editing the order again
            // later"; that is a known issue here, and the order is canceled either way.
            var modified: MexcFutures.OrderID?
            try await withKnownIssue("MEXC asks to edit the order again later", isIntermittent: true) {
                modified = try await client.order.modify(
                    placed.id, price: price - contract.priceTick, volume: contract.minimumVolume
                )
            } matching: { issue in
                (issue.error as? MexcError)?.code == MexcError.Code(rawValue: 2054)
            }
            // MEXC may answer a change with a new order ID, so each cancel below reports per order instead of
            // throwing, and the last one cancels whatever still rests.
            _ = try await client.order.cancel(externalIDs: [externalID], in: Self.btc)
            _ = try await client.order.cancel([placed.id] + [modified].compactMap { $0 })
            try await client.order.cancelAll(Self.btc)

            await #expect(throws: Never.self) { _ = try await client.order.pending() }
            await #expect(throws: Never.self) { _ = try await client.order.get(externalID: externalID, in: Self.btc) }
            await #expect(throws: Never.self) { _ = try await client.order.get(externalIDs: [externalID], in: Self.btc) }
        }

        @Test func `orders are placed in a batch, chased, and canceled by external ID and in every market`() async throws {
            let chaseFailures = collectUntilCancelled(client.stream.chaseFailures([Self.btc]))
            defer { chaseFailures.cancel() }
            let contract = try await client.market.contract(Self.btc)
            let ticker = try await client.market.ticker(Self.btc)
            let options = MexcFutures.OrderRequest.Options(positionMode: try await client.account.positionMode())
            let volume = contract.minimumVolume
            let price = contract.round(price: ticker.lastPrice * Decimal(string: "0.95")!, rule: .down)

            // Each step is checked on its own, so the cancels in every market and the close below always run.
            // MEXC offers batches to market maker accounts only; its refusal is a known issue here.
            try await withKnownIssue("Only market maker accounts can place batches", isIntermittent: true) {
                let batch = try await client.order.place([
                    .open(.long, Self.btc, .postOnly(price: price), volume: volume, leverage: 5, marginMode: .isolated, options: options),
                    .open(
                        .long, Self.btc, .postOnly(price: price - contract.priceTick), volume: volume, leverage: 5,
                        marginMode: .isolated, options: options
                    ),
                ])
                if let error = batch.compactMap({ $0.error }).first { throw error }
                let canceled = try await client.order.cancel(batch.compactMap { $0.id })
                #expect(canceled.allSatisfy { $0.succeeded })
            } matching: { $0.error is MexcError }

            await #expect(throws: Never.self) {
                let externalID = MexcFutures.ExternalOrderID(rawValue: "live-\(UUID().uuidString.prefix(8))")
                _ = try await client.order.place(.open(
                    .long, Self.btc, .postOnly(price: price), volume: volume, leverage: 5, marginMode: .isolated,
                    externalID: externalID, options: options
                ))
                try await client.order.cancel(externalID: externalID, in: Self.btc)
            }

            // Chasing moves the limit buy to the best bid, where it can fill.
            await #expect(throws: Never.self) {
                let chased = try await client.order.place(.open(
                    .long, Self.btc, .limit(price: price), volume: volume, leverage: 5, marginMode: .isolated, options: options
                ))
                try await client.order.chase(chased.id)
            }
            try await client.order.cancelAll()
            if let position = try await client.position.list(Self.btc).first(where: { $0.side == .long }) {
                _ = try await client.order.place(.close(
                    .long, Self.btc, .market, volume: position.volume, marginMode: .isolated, position: position.id,
                    options: options
                ))
            }
            #expect(try await client.position.list(Self.btc).isEmpty)

            chaseFailures.cancel()
            await #expect(throws: Never.self) { _ = try await chaseFailures.value }
        }
    }
}
