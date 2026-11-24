public import Foundation

// MARK: - Protocol

extension MexcFutures {
    /// The futures account: balances, transfers, profit rate, risk limits, position mode and fees.
    ///
    /// Every request needs credentials. Balances, transfers, the profit rate, fee totals, discount usage
    /// and the fee configurations need MEXC's "View Account Details" permission; risk limits, the
    /// position mode, fee rates and fee deductions need "View Order Details".
    public protocol AccountAPI: Sendable {
        /// The balance of every asset in the futures account.
        func balances() async throws -> [Balance]

        /// The balance of one asset, such as `"USDT"`.
        func balance(_ asset: String) async throws -> Balance

        /// Transfers into and out of the futures account, filtered by the values that aren't `nil`.
        /// Pages hold at most 100.
        func transfers(
            asset: String?, direction: TransferDirection?, state: TransferState?, page: PageRequest
        ) async throws -> Page<Transfer>

        /// The account's profit rate over the last day or week.
        func profitRate(_ period: ProfitRatePeriod) async throws -> ProfitRate

        /// The risk limit tiers in one market, or in every market when `symbol` is `nil`, sorted by
        /// symbol, side and margin mode.
        func riskLimits(_ symbol: Symbol?) async throws -> [PositionRiskLimit]

        /// Whether the account holds long and short positions in one market at once.
        func positionMode() async throws -> PositionMode

        /// The account's fee rates in one market, or its general rates when `symbol` is `nil`.
        func feeRates(_ symbol: Symbol?) async throws -> FeeRates

        /// The fees paid and saved over the last 30 days.
        func feeTotals() async throws -> FeeTotals

        /// Which fee reduction applies to the account.
        func discountUsage() async throws -> DiscountUsage

        /// The assets fees can be deducted from.
        func feeDeductionAssets() async throws -> [FeeDeductionAsset]

        /// The spot fee discounts that apply to futures fees.
        func feeDiscounts() async throws -> [FeeDiscount]

        /// One page of fees and their deductions in one market, of up to 20 fills when `fills` isn't
        /// empty. Without `start`, MEXC starts 7 days ago; it allows at most 90 days. Pages hold at most
        /// 100.
        func feeDeductions(
            _ symbol: Symbol, fills: [FillID], start: Date?, end: Date?, page: PageRequest
        ) async throws -> [FeeDeduction]
    }
}

// MARK: - Defaults

extension MexcFutures.AccountAPI {
    /// One page of every transfer, the first unless `page` says otherwise.
    public func transfers(
        page: MexcFutures.PageRequest = .first
    ) async throws -> MexcFutures.Page<MexcFutures.Transfer> {
        try await transfers(asset: nil, direction: nil, state: nil, page: page)
    }

    /// The risk limit tiers in every market.
    public func riskLimits() async throws -> [MexcFutures.PositionRiskLimit] {
        try await riskLimits(nil)
    }

    /// The account's general fee rates.
    public func feeRates() async throws -> MexcFutures.FeeRates {
        try await feeRates(nil)
    }

    /// One page of fees and their deductions in one market over MEXC's default range, the first unless
    /// `page` says otherwise.
    public func feeDeductions(
        _ symbol: MexcFutures.Symbol, page: MexcFutures.PageRequest = .first
    ) async throws -> [MexcFutures.FeeDeduction] {
        try await feeDeductions(symbol, fills: [], start: nil, end: nil, page: page)
    }
}
