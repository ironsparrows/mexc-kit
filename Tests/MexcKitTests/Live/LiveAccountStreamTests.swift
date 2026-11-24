import Foundation
import MexcKit
import MexcKitTestSupport
import Testing

// Places small real orders: opens the smallest long in BTC_USDT and closes it, while the order,
// position, fill and balance streams are open, and checks their pushes decode. Then, on another such
// long, places and cancels a stop order, a trailing order, a plan order and a limit order with
// attached stops, as the live plan, stop and trailing order suite does, while their streams are open.
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

    @Test func `conditional orders and attached stops stream while they're placed and canceled`() async throws {
        async let stops = Self.values(2, of: client.stream.stopOrders([Self.btc]))
        async let trailing = Self.values(2, of: client.stream.trailingOrders([Self.btc]))
        async let plans = Self.values(2, of: client.stream.planOrders([Self.btc]))
        async let attached = Self.values(1, of: client.stream.attachedStops([Self.btc]))
        try await Task.sleep(for: .seconds(3))

        let contract = try await client.market.contract(Self.btc)
        let last = try await client.market.ticker(Self.btc).lastPrice
        let mode = try await client.account.positionMode()
        let options = MexcFutures.OrderRequest.Options(positionMode: mode)
        let volume = contract.minimumVolume
        _ = try await client.order.place(
            .open(.long, Self.btc, .market, volume: volume, leverage: 5, margin: .isolated, options: options)
        )
        let position = try #require(try await client.position.list(Self.btc).first { $0.side == .long })

        let stop = try await client.stopOrder.place(.init(
            position: position.id, volume: volume,
            stopLoss: .market(at: contract.round(price: last * Decimal(string: "0.9")!, rule: .down))
        ))
        let trailingOrder = try await client.trailingOrder.place(.close(
            .long, Self.btc, volume: volume, leverage: 5, margin: .isolated, callback: .percentage(Decimal(string: "0.05")!),
            activationPrice: contract.round(price: last * Decimal(string: "1.5")!, rule: .up),
            positionMode: mode
        ))
        let plan = try await client.planOrder.place(.open(
            .long, Self.btc, .market, volume: volume, leverage: 5, margin: .isolated,
            trigger: .init(price: contract.round(price: last * Decimal(string: "1.5")!, rule: .up), condition: .atOrAbove),
            lifetime: .oneDay, options: .init(positionMode: mode)
        ))
        let limit = try await client.order.place(.open(
            .long, Self.btc, .limit(price: contract.round(price: last * Decimal(string: "0.9")!, rule: .down)),
            volume: volume, leverage: 5, margin: .isolated, options: options
        ))
        try await client.stopOrder.setAttachedStops(
            of: limit.id, takeProfit: .init(price: contract.round(price: last, rule: .up)),
            stopLoss: .init(price: contract.round(price: last * Decimal(string: "0.8")!, rule: .down))
        )

        try await client.order.cancel(limit.id)
        try await client.stopOrder.cancel(stop)
        try await client.trailingOrder.cancel(trailingOrder, in: Self.btc)
        try await client.planOrder.cancel(plan, in: Self.btc)
        _ = try await client.order.place(
            .close(.long, Self.btc, .market, volume: volume, margin: .isolated, position: position.id, options: options)
        )

        #expect(try await stops.allSatisfy { $0.symbol == Self.btc })
        #expect(try await trailing.allSatisfy { $0.symbol == Self.btc })
        #expect(try await plans.allSatisfy { $0.symbol == Self.btc })
        #expect(try await attached.allSatisfy { $0.order == limit.id })
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
