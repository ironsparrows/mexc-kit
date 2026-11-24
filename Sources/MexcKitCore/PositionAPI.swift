public import Foundation

// MARK: - Protocol

extension MexcFutures {
    /// The account's positions: open positions, closed ones, funding payments and leverage.
    ///
    /// Every request needs credentials with MEXC's "View Order Details" permission.
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
