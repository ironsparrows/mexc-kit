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
        _ = try await account.feeRates()
        _ = try await account.feeDeductions("BTC_USDT")
        _ = try await account.feeDeductions("BTC_USDT", page: .init(number: 2, size: 100))
        #expect(await recorder.calls.value == [
            "transfers nil nil nil 1 20", "transfers nil nil nil 2 100", "riskLimits nil", "feeRates nil",
            "feeDeductions BTC_USDT [] nil nil 1 20", "feeDeductions BTC_USDT [] nil nil 2 100",
        ])
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
    func positionMode(subaccount: String) async throws -> MexcFutures.PositionMode { .hedge }
    func setPositionMode(_ mode: MexcFutures.PositionMode) async throws {}
    func setMultiAssetMode(_ enabled: Bool) async throws {}

    func feeRates(_ symbol: MexcFutures.Symbol?) async throws -> MexcFutures.FeeRates {
        await calls.record("feeRates \(symbol?.rawValue ?? "nil")")
        return .init(
            symbol: symbol, maker: 0, taker: 0, standardMaker: 0, standardTaker: 0, mode: .normal, joinsDiscount: false,
            receivesDiscount: false, discountRate: 1, joinsDeduction: false, receivesDeduction: false, deductionRate: 1,
            tradedAmount: 0, walletBalance: nil, tiers: [], tierTradedAmount: nil, leverage: nil
        )
    }

    func feeDeductions(
        _ symbol: MexcFutures.Symbol, fills: [MexcFutures.FillID], start: Date?, end: Date?,
        page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.FeeDeduction] {
        let dates = "\(start == nil ? "nil" : "set") \(end == nil ? "nil" : "set")"
        await calls.record("feeDeductions \(symbol) \(fills.map(\.rawValue)) \(dates) \(page.number) \(page.size)")
        return []
    }

    func feeTotals() async throws -> MexcFutures.FeeTotals { .init(paid: 0, saved: 0) }
    func discountUsage() async throws -> MexcFutures.DiscountUsage { .init(usesSpotDiscount: false, usesDeduction: false) }
    func feeDeductionAssets() async throws -> [MexcFutures.FeeDeductionAsset] { [] }
    func feeDiscounts() async throws -> [MexcFutures.FeeDiscount] { [] }
}
