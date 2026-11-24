extension MexcFutures {
    /// Every futures capability, grouped by domain.
    ///
    /// `MexcFutures.Client` is the live conformer. To mock one domain, conform a type to that domain's protocol,
    /// such as ``MarketAPI``.
    public protocol API: Sendable {
        /// Public market data. Never needs credentials.
        var market: any MarketAPI { get }
    }
}
