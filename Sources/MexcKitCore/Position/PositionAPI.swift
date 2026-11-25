public import Foundation

// MARK: - Protocol

extension MexcFutures {
    /// The account's positions: open positions, closed ones, funding payments and leverage; reversing or
    /// closing them, and changing their leverage and margin.
    ///
    /// Every request needs credentials. Reading needs MEXC's "View Order Details" permission; changing
    /// needs "Order Placing". A request MEXC can't take as built throws
    /// ``ClientError/Reason/invalidRequest`` before anything is sent.
    public protocol PositionAPI: Sendable {
        /// The open positions, filtered by the values that aren't `nil`.
        func list(_ symbol: Symbol?, position: PositionID?) async throws -> [Position]

        /// One page of closed positions, filtered by the values that aren't `nil`; `start` and `end`
        /// limit the time range as MEXC applies it. Pages hold at most 100.
        func history(
            _ symbol: Symbol?, side: PositionSide?, start: Date?, end: Date?, page: PageRequest
        ) async throws -> [Position]

        /// One page of funding payments, filtered by the values that aren't `nil`; `start` and `end`
        /// limit the time range as MEXC applies it. Pages hold at most 100.
        func fundingPayments(
            _ symbol: Symbol?, position: PositionID?, side: PositionSide?, start: Date?, end: Date?,
            page: PageRequest
        ) async throws -> Page<FundingPayment>

        /// The leverage of each side and margin mode in one market.
        func leverage(_ symbol: Symbol) async throws -> [LeverageSetting]

        /// The leverage of each side and margin mode in one market for a sub-account, by its name. Needs
        /// the master account's key. MEXC returns the market's default leverage for a side without a
        /// position.
        func leverage(_ symbol: Symbol, subAccount: String) async throws -> [LeverageSetting]

        /// Sets the leverage of an open position. MEXC allows 10 leverage changes in 10 seconds.
        func setLeverage(_ leverage: Int, of position: PositionID) async throws

        /// Sets the leverage of one side and margin mode in a market where the account has no position
        /// on that side. MEXC allows 10 leverage changes in 10 seconds.
        func setLeverage(
            _ leverage: Int, in symbol: Symbol, side: PositionSide, marginMode: MarginMode
        ) async throws

        /// Adds margin to a position, or removes it when `change` is negative. A `change` of 0 throws
        /// ``ClientError/Reason/invalidRequest`` before anything is sent.
        func adjustMargin(of position: PositionID, by change: Decimal) async throws

        /// Turns MEXC's auto-add margin on or off for a position; ``Position/addsMarginAutomatically``
        /// reports it.
        func setAddsMarginAutomatically(_ enabled: Bool, of position: PositionID) async throws

        /// Reverses `volume` of an open position in one market. Needs MEXC's "Order Placing"
        /// permission.
        func reverse(_ position: PositionID, in symbol: Symbol, volume: Decimal) async throws

        /// Closes every open position. Needs MEXC's "Order Placing" permission.
        func closeAll() async throws
    }
}

// MARK: - Defaults

extension MexcFutures.PositionAPI {
    /// Every open position, or those in one market.
    public func list(_ symbol: MexcFutures.Symbol? = nil) async throws -> [MexcFutures.Position] {
        try await list(symbol, position: nil)
    }

    /// One page of closed positions, the first unless `page` says otherwise.
    public func history(
        _ symbol: MexcFutures.Symbol? = nil, page: MexcFutures.PageRequest = .first
    ) async throws -> [MexcFutures.Position] {
        try await history(symbol, side: nil, start: nil, end: nil, page: page)
    }

    /// One page of funding payments, the first unless `page` says otherwise.
    public func fundingPayments(
        _ symbol: MexcFutures.Symbol? = nil, page: MexcFutures.PageRequest = .first
    ) async throws -> MexcFutures.Page<MexcFutures.FundingPayment> {
        try await fundingPayments(symbol, position: nil, side: nil, start: nil, end: nil, page: page)
    }
}
