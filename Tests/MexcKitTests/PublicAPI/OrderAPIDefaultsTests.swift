import Foundation
import MexcKit
import Testing

// Only `import MexcKit`, as an app writes: the shorter calls reach an app's own conformer.
extension MexcKitTests {
    @Suite("Order API defaults")
    struct OrderAPIDefaultsTests {
        @Test func `the shorter calls forward to the full requirement`() async throws {
            let recorder = RecordingOrders()
            let orders: any MexcFutures.OrderAPI = recorder
            try await orders.cancelAll()
            _ = try await orders.pending()
            _ = try await orders.history("BTC_USDT")
            _ = try await orders.history("BTC_USDT", page: .init(number: 2, size: 100))
            _ = try await orders.closed("BTC_USDT")
            _ = try await orders.fills("BTC_USDT", page: .init(number: 3, size: 1000))
            try await orders.cancel(.init(rawValue: "7"))
            #expect(await recorder.calls.value == [
                "cancelAll nil", "pending 1 20", "history BTC_USDT 1,2,3,4,5 nil nil nil 1 20",
                "history BTC_USDT 1,2,3,4,5 nil nil nil 2 100", "closed BTC_USDT nil nil 1 20",
                "fills BTC_USDT nil nil 3 1000", "cancel 7",
            ])
        }

        @Test func `canceling one order throws the error reported for it`() async throws {
            let orders: any MexcFutures.OrderAPI = RecordingOrders(cancelError: MexcError(code: .orderNotCancellable))
            let error = try await #require(throws: MexcError.self) { try await orders.cancel(.init(rawValue: "7")) }
            #expect(error.code == .orderNotCancellable)
        }
    }
}

/// Orders that record how each requirement was called.
private struct RecordingOrders: MexcFutures.OrderAPI {
    var cancelError: MexcError?
    let calls = Calls()

    actor Calls {
        var value: [String] = []
        func record(_ call: String) { value.append(call) }
    }

    func cancel(_ ids: [MexcFutures.OrderID]) async throws -> [MexcFutures.BatchResult<MexcFutures.OrderID>] {
        await calls.record("cancel \(ids.map(\.rawValue).joined(separator: ","))")
        return ids.map { .init(id: $0, error: cancelError) }
    }

    func cancelAll(_ symbol: MexcFutures.Symbol?) async throws {
        await calls.record("cancelAll \(symbol?.rawValue ?? "nil")")
    }

    func pending(page: MexcFutures.PageRequest) async throws -> [MexcFutures.Order] {
        await calls.record("pending \(page.number) \(page.size)")
        return []
    }

    func history(
        _ symbol: MexcFutures.Symbol, states: [MexcFutures.OrderState], category: MexcFutures.OrderCategory?,
        start: Date?, end: Date?, page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.Order] {
        let states = states.map { String($0.rawValue) }.joined(separator: ",")
        let category = category.map { String($0.rawValue) } ?? "nil"
        await calls.record(
            "history \(symbol) \(states) \(category) \(describe(start, end)) \(page.number) \(page.size)"
        )
        return []
    }

    func closed(
        _ symbol: MexcFutures.Symbol, start: Date?, end: Date?, page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.Order] {
        await calls.record("closed \(symbol) \(describe(start, end)) \(page.number) \(page.size)")
        return []
    }

    func fills(
        _ symbol: MexcFutures.Symbol, start: Date?, end: Date?, page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.Fill] {
        await calls.record("fills \(symbol) \(describe(start, end)) \(page.number) \(page.size)")
        return []
    }

    func place(_ request: MexcFutures.OrderRequest) async throws -> MexcFutures.PlacedOrder {
        .init(id: .init(rawValue: "1"), acceptedAt: .now)
    }

    func place(_ requests: [MexcFutures.OrderRequest]) async throws -> [MexcFutures.BatchResult<MexcFutures.OrderID>] {
        []
    }

    func chase(_ id: MexcFutures.OrderID) async throws {}

    func modify(_ id: MexcFutures.OrderID, price: Decimal, volume: Decimal) async throws -> MexcFutures.OrderID { id }

    func cancel(externalID: MexcFutures.ExternalOrderID, in symbol: MexcFutures.Symbol) async throws {}

    func cancel(
        externalIDs: [MexcFutures.ExternalOrderID], in symbol: MexcFutures.Symbol
    ) async throws -> [MexcFutures.BatchResult<MexcFutures.OrderID>] { [] }

    func get(_ id: MexcFutures.OrderID) async throws -> MexcFutures.Order { throw CancellationError() }

    func get(_ ids: [MexcFutures.OrderID]) async throws -> [MexcFutures.Order] { [] }

    func get(
        externalID: MexcFutures.ExternalOrderID, in symbol: MexcFutures.Symbol
    ) async throws -> MexcFutures.Order { throw CancellationError() }

    func get(
        externalIDs: [MexcFutures.ExternalOrderID], in symbol: MexcFutures.Symbol
    ) async throws -> [MexcFutures.Order] { [] }

    func fills(of id: MexcFutures.OrderID) async throws -> [MexcFutures.Fill] { [] }

    func pendingCounts() async throws -> MexcFutures.PendingOrderCounts {
        .init(total: 0, limitOrders: 0, stopOrders: 0, planOrders: 0, trailingOrders: 0)
    }

    private func describe(_ start: Date?, _ end: Date?) -> String {
        "\(start == nil ? "nil" : "set") \(end == nil ? "nil" : "set")"
    }
}
