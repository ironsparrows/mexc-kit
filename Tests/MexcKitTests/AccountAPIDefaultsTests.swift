import Foundation
import MexcKit
import Testing

// Only `import MexcKit`, as an app writes: the shorter calls reach an app's own conformer.
@Suite("Account API defaults")
struct AccountAPIDefaultsTests {
    @Test func `the shorter calls forward to the full requirement`() async throws {
        let recorder = RecordingAccount()
        let account: any MexcFutures.AccountAPI = recorder
        _ = try await account.transfers()
        _ = try await account.transfers(page: .init(number: 2, size: 100))
        _ = try await account.riskLimits()
        #expect(await recorder.calls.value == ["transfers nil nil nil 1 20", "transfers nil nil nil 2 100", "riskLimits nil"])
    }
}

/// An account that records how each requirement was called.
private struct RecordingAccount: MexcFutures.AccountAPI {
    let calls = Calls()

    actor Calls {
        var value: [String] = []
        func record(_ call: String) { value.append(call) }
    }

    func transfers(
        asset: String?, direction: MexcFutures.TransferDirection?, state: MexcFutures.TransferState?,
        page: MexcFutures.PageRequest
    ) async throws -> MexcFutures.Page<MexcFutures.Transfer> {
        let filters = [asset, direction?.rawValue, state?.rawValue].map { $0 ?? "nil" }.joined(separator: " ")
        await calls.record("transfers \(filters) \(page.number) \(page.size)")
        return .init(items: [], currentPage: page.number, pageSize: page.size, totalCount: 0, totalPages: 0)
    }

    func riskLimits(_ symbol: MexcFutures.Symbol?) async throws -> [MexcFutures.PositionRiskLimit] {
        await calls.record("riskLimits \(symbol?.rawValue ?? "nil")")
        return []
    }

    func balances() async throws -> [MexcFutures.Balance] { [] }
    func balance(_ asset: String) async throws -> MexcFutures.Balance { throw CancellationError() }
    func profitRate(_ period: MexcFutures.ProfitRatePeriod) async throws -> MexcFutures.ProfitRate {
        throw CancellationError()
    }
    func positionMode() async throws -> MexcFutures.PositionMode { .hedge }
}
