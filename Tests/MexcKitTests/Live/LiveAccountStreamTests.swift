import Foundation
import MexcKit
import MexcKitTestSupport
import Testing

// Places small real orders: opens the smallest long in BTC_USDT and closes it, while the order,
// position, fill and balance streams are open, and checks their pushes decode.
@Suite(
    "Live account streams", .tags(.live),
    .enabled(if: areLiveTestsEnabled, "Set MEXC_API_KEY and MEXC_API_SECRET to run"), .timeLimit(.minutes(2))
)
struct LiveAccountStreamTests {
    private static let btc: MexcFutures.Symbol = "BTC_USDT"
    private let client = MexcFutures.Client(credentials: LiveTestSettings.credentials)

    @Test func `orders, fills, positions and balances stream while a position opens and closes`() async throws {
        async let orders = Self.values(2, of: client.stream.orders([Self.btc]))
        async let positions = Self.values(1, of: client.stream.positions([Self.btc]))
        async let fills = Self.values(1, of: client.stream.fills([Self.btc]))
        async let balances = Self.values(1, of: client.stream.balances())
        // The streams log in and filter before MEXC pushes anything; nothing acknowledges the filter.
        try await Task.sleep(for: .seconds(3))

        let contract = try await client.market.contract(Self.btc)
        let options = MexcFutures.OrderRequest.Options(positionMode: try await client.account.positionMode())
        let volume = contract.minimumVolume
        _ = try await client.order.place(
            .open(.long, Self.btc, .market, volume: volume, leverage: 5, margin: .isolated, options: options)
        )
        let position = try #require(try await client.position.list(Self.btc).first { $0.side == .long })
        _ = try await client.order.place(
            .close(.long, Self.btc, .market, volume: volume, margin: .isolated, position: position.id, options: options)
        )

        #expect(try await orders.allSatisfy { $0.symbol == Self.btc && $0.volume == volume })
        #expect(try await positions.allSatisfy { $0.symbol == Self.btc })
        #expect(try await fills.allSatisfy { $0.symbol == Self.btc && $0.volume == volume })
        #expect(try await balances.isEmpty == false)
    }

    private static func values<Element: Sendable>(
        _ count: Int, of stream: AsyncThrowingStream<Element, any Error>
    ) async throws -> [Element] {
        var values: [Element] = []
        for try await value in stream {
            values.append(value)
            if values.count == count { break }
        }
        return values
    }
}
