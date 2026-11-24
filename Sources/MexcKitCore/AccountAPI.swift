// MARK: - Protocol

extension MexcFutures {
    /// The futures account: balances, transfers, profit rate, risk limits and position mode.
    ///
    /// Every request needs credentials. Balances, transfers and the profit rate need MEXC's
    /// "View Account Details" permission; risk limits and the position mode need "View Order Details".
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
}
