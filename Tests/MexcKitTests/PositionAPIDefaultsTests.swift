import Foundation
import MexcKit
import Testing

// Only `import MexcKit`, as an app writes: the shorter calls reach an app's own conformer.
@Suite("Position API defaults")
struct PositionAPIDefaultsTests {
    @Test func `the shorter calls forward to the full requirement`() async throws {
        let recorder = RecordingPositions()
        let positions: any MexcFutures.PositionAPI = recorder
        _ = try await positions.list()
        _ = try await positions.list("BTC_USDT")
        _ = try await positions.history()
        _ = try await positions.history("BTC_USDT", page: .init(number: 2, size: 100))
        _ = try await positions.fundingPayments()
        _ = try await positions.fundingPayments("BTC_USDT", page: .init(number: 2, size: 100))
        #expect(await recorder.calls.value == [
            "list nil nil", "list BTC_USDT nil", "history nil nil nil nil 1 20",
            "history BTC_USDT nil nil nil 2 100", "fundingPayments nil nil nil nil nil 1 20",
            "fundingPayments BTC_USDT nil nil nil nil 2 100",
        ])
    }
}

/// Positions that record how each requirement was called.
private struct RecordingPositions: MexcFutures.PositionAPI {
    let calls = Calls()

    actor Calls {
        var value: [String] = []
        func record(_ call: String) { value.append(call) }
    }

    func list(
        _ symbol: MexcFutures.Symbol?, position: MexcFutures.PositionID?
    ) async throws -> [MexcFutures.Position] {
        await calls.record("list \(symbol?.rawValue ?? "nil") \(position?.rawValue ?? "nil")")
        return []
    }

    func history(
        _ symbol: MexcFutures.Symbol?, side: MexcFutures.PositionSide?, start: Date?, end: Date?,
        page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.Position] {
        await calls.record("history \(describe(symbol, side, start, end)) \(page.number) \(page.size)")
        return []
    }

    func fundingPayments(
        _ symbol: MexcFutures.Symbol?, position: MexcFutures.PositionID?, side: MexcFutures.PositionSide?,
        start: Date?, end: Date?, page: MexcFutures.PageRequest
    ) async throws -> MexcFutures.Page<MexcFutures.FundingPayment> {
        let filters = "\(describe(symbol, side, start, end)) \(position?.rawValue ?? "nil")"
        await calls.record("fundingPayments \(filters) \(page.number) \(page.size)")
        return .init(items: [], currentPage: page.number, pageSize: page.size, totalCount: 0, totalPages: 0)
    }

    func leverage(_ symbol: MexcFutures.Symbol) async throws -> [MexcFutures.LeverageSetting] { [] }

    private func describe(
        _ symbol: MexcFutures.Symbol?, _ side: MexcFutures.PositionSide?, _ start: Date?, _ end: Date?
    ) -> String {
        let side = side.map { String($0.rawValue) } ?? "nil"
        return "\(symbol?.rawValue ?? "nil") \(side) \(start == nil ? "nil" : "set") \(end == nil ? "nil" : "set")"
    }
}
