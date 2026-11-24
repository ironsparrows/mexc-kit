public import Foundation

// MARK: - Protocol

extension MexcFutures {
    /// The account's trailing orders.
    ///
    /// Placing, changing and canceling need credentials with MEXC's "Order Placing" permission; listing
    /// needs "View Order Details". A request MEXC can't take as built throws
    /// ``ClientError/Reason/invalidRequest`` before anything is sent. A request that changes something
    /// and fails with ``MexcError/Code/internalError``, ``ClientError/Reason/timedOut`` or
    /// ``ClientError/Reason/connectionFailed`` may still have taken effect: check before repeating it.
    public protocol TrailingOrderAPI: Sendable {
        /// Places a trailing order.
        func place(_ request: TrailingOrderRequest) async throws -> TrailingOrderID

        /// Changes a trailing order's volume, callback, activation price and followed price.
        func modify(
            _ id: TrailingOrderID, in symbol: Symbol, volume: Decimal, callback: TrailingOrder.Callback,
            activationPrice: Decimal?, source: PriceSource
        ) async throws

        /// Cancels a trailing order.
        func cancel(_ id: TrailingOrderID, in symbol: Symbol) async throws

        /// One page of trailing orders in any of `states`, or in any state when `states` is empty,
        /// filtered by the values that aren't `nil`; `start` and `end` limit the time range as MEXC
        /// applies it.
        func list(
            _ symbol: Symbol?, states: [TrailingOrderState], side: OrderSide?, start: Date?, end: Date?,
            page: PageRequest
        ) async throws -> [TrailingOrder]
    }
}

// MARK: - Defaults

extension MexcFutures.TrailingOrderAPI {
    /// One page of trailing orders in any state, the first unless `page` says otherwise.
    public func list(
        _ symbol: MexcFutures.Symbol? = nil, page: MexcFutures.PageRequest = .first
    ) async throws -> [MexcFutures.TrailingOrder] {
        try await list(symbol, states: [], side: nil, start: nil, end: nil, page: page)
    }
}
