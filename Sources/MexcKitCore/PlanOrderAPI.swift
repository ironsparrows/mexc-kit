public import Foundation

// MARK: - Protocol

extension MexcFutures {
    /// The account's plan orders: orders MEXC places once a trigger price is reached.
    ///
    /// Placing, changing and canceling need credentials with MEXC's "Order Placing" permission; listing
    /// needs "View Order Details". A request MEXC can't take as built throws
    /// ``ClientError/Reason/invalidRequest`` before anything is sent. A request that changes something
    /// and fails with ``MexcError/Code/internalError``, ``ClientError/Reason/timedOut`` or
    /// ``ClientError/Reason/connectionFailed`` may still have taken effect: check before repeating it.
    public protocol PlanOrderAPI: Sendable {
        /// Places a plan order.
        func place(_ request: PlanOrderRequest) async throws -> PlanOrderID

        /// Changes a waiting plan order's trigger and the order it places.
        ///
        /// MEXC requires a price here: a `pricing` of ``OrderRequest/Pricing/market`` or
        /// ``OrderRequest/Pricing/bestPrice(_:)`` throws ``ClientError/Reason/invalidRequest`` before
        /// anything is sent.
        func modify(
            _ id: PlanOrderID, in symbol: Symbol, trigger: Trigger, pricing: OrderRequest.Pricing
        ) async throws

        /// Sets the take-profit and stop-loss of the order a plan order places. `nil` removes one; both
        /// `nil` removes both.
        func setAttachedStops(
            of id: PlanOrderID, in symbol: Symbol, takeProfit: AttachedStop?, stopLoss: AttachedStop?
        ) async throws

        /// Cancels up to 50 waiting plan orders in one market.
        func cancel(_ ids: [PlanOrderID], in symbol: Symbol) async throws

        /// Cancels every waiting plan order in one market, or in every market when `symbol` is `nil`.
        func cancelAll(_ symbol: Symbol?) async throws

        /// One page of plan orders in the time range from `start` to `end`, as MEXC applies it, filtered
        /// by the values that aren't `nil` and, unless `states` is empty, by state. MEXC requires the time
        /// range. Pages hold at most 100.
        func list(
            _ symbol: Symbol?, states: [PlanOrderState], side: OrderSide?, start: Date, end: Date,
            page: PageRequest
        ) async throws -> [PlanOrder]
    }
}

// MARK: - Defaults

extension MexcFutures.PlanOrderAPI {
    /// Cancels one waiting plan order.
    public func cancel(_ id: MexcFutures.PlanOrderID, in symbol: MexcFutures.Symbol) async throws {
        try await cancel([id], in: symbol)
    }

    /// Cancels every waiting plan order in every market.
    public func cancelAll() async throws {
        try await cancelAll(nil)
    }

    /// One page of plan orders in any state in the time range from `start` to `end`, the first unless
    /// `page` says otherwise.
    public func list(
        _ symbol: MexcFutures.Symbol? = nil, from start: Date, to end: Date, page: MexcFutures.PageRequest = .first
    ) async throws -> [MexcFutures.PlanOrder] {
        try await list(symbol, states: [], side: nil, start: start, end: end, page: page)
    }
}
