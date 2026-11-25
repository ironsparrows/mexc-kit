import Foundation
import MexcKit
import Testing

// Only `import MexcKit`, as an app writes: the shorter calls reach an app's own conformers.
extension MexcKitTests {
    @Suite("Plan, stop and trailing order API defaults")
    struct ConditionalOrderAPIDefaultsTests {
        @Test func `the shorter plan order calls forward to the full requirements`() async throws {
            let recorder = RecordingOrders()
            let plans: any MexcFutures.PlanOrderAPI = recorder
            try await plans.cancel(.init(rawValue: "7"), in: "BTC_USDT")
            try await plans.cancelAll()
            _ = try await plans.list(from: Date(timeIntervalSince1970: 1), to: Date(timeIntervalSince1970: 2))
            #expect(await recorder.calls.value == ["plan cancel 7 BTC_USDT", "plan cancelAll nil", "plan list nil [] nil 1 20"])
        }

        @Test func `the shorter stop order calls forward to the full requirements`() async throws {
            let recorder = RecordingOrders()
            let stops: any MexcFutures.StopOrderAPI = recorder
            try await stops.cancel(MexcFutures.StopOrderID(rawValue: "8"))
            try await stops.cancelAll()
            try await stops.cancelAll("BTC_USDT")
            try await stops.cancelAll(position: .init(rawValue: "9"))
            _ = try await stops.pending()
            _ = try await stops.list(page: .init(number: 2, size: 100))
            #expect(await recorder.calls.value == [
                "stop cancel 8", "stop cancelAll nil nil", "stop cancelAll BTC_USDT nil", "stop cancelAll nil 9", "stop pending nil",
                "stop list nil nil nil 2 100",
            ])
        }

        @Test func `the shorter trailing order call lists in any state`() async throws {
            let recorder = RecordingOrders()
            let trailing: any MexcFutures.TrailingOrderAPI = recorder
            _ = try await trailing.list("BTC_USDT")
            #expect(await recorder.calls.value == ["trailing list BTC_USDT [] 1 20"])
        }
    }
}

/// Plan, stop and trailing orders that record how each requirement was called.
private struct RecordingOrders: MexcFutures.PlanOrderAPI, MexcFutures.StopOrderAPI, MexcFutures.TrailingOrderAPI {
    let calls = Calls()

    actor Calls {
        var value: [String] = []
        func record(_ call: String) { value.append(call) }
    }

    // MARK: Plan orders

    func place(_ request: MexcFutures.PlanOrderRequest) async throws -> MexcFutures.PlanOrderID { .init(rawValue: "1") }

    func modify(
        _ id: MexcFutures.PlanOrderID, in symbol: MexcFutures.Symbol, trigger: MexcFutures.Trigger,
        pricing: MexcFutures.OrderRequest.Pricing
    ) async throws {}

    func setAttachedStops(
        of id: MexcFutures.PlanOrderID, in symbol: MexcFutures.Symbol, takeProfit: MexcFutures.AttachedStop?,
        stopLoss: MexcFutures.AttachedStop?
    ) async throws {}

    func cancel(_ ids: [MexcFutures.PlanOrderID], in symbol: MexcFutures.Symbol) async throws {
        await calls.record("plan cancel \(ids.map(\.rawValue).joined(separator: ",")) \(symbol)")
    }

    func cancelAll(_ symbol: MexcFutures.Symbol?) async throws {
        await calls.record("plan cancelAll \(symbol?.rawValue ?? "nil")")
    }

    func list(
        _ symbol: MexcFutures.Symbol?, states: [MexcFutures.PlanOrderState], side: MexcFutures.OrderSide?,
        start: Date, end: Date, page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.PlanOrder] {
        let side = side.map { String($0.rawValue) } ?? "nil"
        await calls.record("plan list \(symbol?.rawValue ?? "nil") \(states.map(\.rawValue)) \(side) \(page.number) \(page.size)")
        return []
    }

    // MARK: Stop orders

    func place(_ request: MexcFutures.StopOrderRequest) async throws -> MexcFutures.StopOrderID { .init(rawValue: "1") }

    func modify(
        _ id: MexcFutures.StopOrderID, takeProfit: MexcFutures.AttachedStop?, stopLoss: MexcFutures.AttachedStop?
    ) async throws {}

    func setAttachedStops(
        of id: MexcFutures.OrderID, takeProfit: MexcFutures.AttachedStop?, stopLoss: MexcFutures.AttachedStop?
    ) async throws {}

    func cancel(_ ids: [MexcFutures.StopOrderID]) async throws {
        await calls.record("stop cancel \(ids.map(\.rawValue).joined(separator: ","))")
    }

    func cancelAll(_ symbol: MexcFutures.Symbol?, position: MexcFutures.PositionID?) async throws {
        await calls.record("stop cancelAll \(symbol?.rawValue ?? "nil") \(position?.rawValue ?? "nil")")
    }

    func pending(_ symbol: MexcFutures.Symbol?) async throws -> [MexcFutures.StopOrder] {
        await calls.record("stop pending \(symbol?.rawValue ?? "nil")")
        return []
    }

    func list(
        _ symbol: MexcFutures.Symbol?, state: MexcFutures.PlanOrderState?, side: MexcFutures.PositionSide?,
        start: Date?, end: Date?, page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.StopOrder] {
        let filters = [symbol?.rawValue, state.map { String($0.rawValue) }, side.map { String($0.rawValue) }]
        await calls.record("stop list \(filters.map { $0 ?? "nil" }.joined(separator: " ")) \(page.number) \(page.size)")
        return []
    }

    // MARK: Trailing orders

    func place(_ request: MexcFutures.TrailingOrderRequest) async throws -> MexcFutures.TrailingOrderID {
        .init(rawValue: "1")
    }

    func modify(
        _ id: MexcFutures.TrailingOrderID, in symbol: MexcFutures.Symbol, volume: Decimal,
        callback: MexcFutures.TrailingOrder.Callback, activationPrice: Decimal?, source: MexcFutures.PriceSource
    ) async throws {}

    func cancel(_ id: MexcFutures.TrailingOrderID, in symbol: MexcFutures.Symbol) async throws {}

    func list(
        _ symbol: MexcFutures.Symbol?, states: [MexcFutures.TrailingOrderState], side: MexcFutures.OrderSide?,
        start: Date?, end: Date?, page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.TrailingOrder] {
        await calls.record("trailing list \(symbol?.rawValue ?? "nil") \(states.map(\.rawValue)) \(page.number) \(page.size)")
        return []
    }
}
