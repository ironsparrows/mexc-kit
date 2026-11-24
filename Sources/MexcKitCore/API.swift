extension MexcFutures {
    /// Every futures capability, grouped by domain.
    ///
    /// `MexcFutures.Client` is the live conformer. To mock one domain, conform a type to that domain's protocol,
    /// such as ``MarketAPI``.
    public protocol API: Sendable {
        /// Public market data. Never needs credentials.
        var market: any MarketAPI { get }
        /// The futures account: balances, transfers, profit rate, risk limits and position mode.
        var account: any AccountAPI { get }
        /// Open and closed positions, funding payments and leverage, and reversing or closing positions.
        var position: any PositionAPI { get }
        /// Placing, changing, canceling and reading orders, and their fills.
        var order: any OrderAPI { get }
    }
}
