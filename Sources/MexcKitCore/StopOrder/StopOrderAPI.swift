public import Foundation

// MARK: - Protocol

extension MexcFutures {
    /// The account's stop orders, which take profit or stop losses on a position, and the attached stops
    /// of limit orders.
    ///
    /// Placing, changing and canceling need credentials with MEXC's "Order Placing" permission; listing
    /// needs "View Order Details". A request MEXC can't take as built throws
    /// ``ClientError/Reason/invalidRequest`` before anything is sent. A request that changes something
    /// and fails with ``MexcError/Code/internalError``, ``ClientError/Reason/timedOut`` or
    /// ``ClientError/Reason/connectionFailed`` may still have taken effect: check before repeating it.
    public protocol StopOrderAPI: Sendable {
        /// Places a stop order on a position.
        ///
        /// When the position already has a waiting stop order at the same price, MEXC returns that
        /// order's ID and updates its volume asynchronously, so a read right after may still show the
        /// old volume.
        func place(_ request: StopOrderRequest) async throws -> StopOrderID

        /// Changes the trigger prices of a waiting stop order. At least one must be set.
        func modify(_ id: StopOrderID, takeProfit: AttachedStop?, stopLoss: AttachedStop?) async throws

        /// Sets the take-profit and stop-loss a limit order carries. Both `nil` removes them.
        func setAttachedStops(of id: OrderID, takeProfit: AttachedStop?, stopLoss: AttachedStop?) async throws

        /// Cancels up to 50 waiting stop orders.
        func cancel(_ ids: [StopOrderID]) async throws

        /// Cancels every waiting stop order of one position, else of one market, else of every market.
        func cancelAll(_ symbol: Symbol?, position: PositionID?) async throws

        /// The waiting stop orders in one market, or in every market when `symbol` is `nil`.
        func pending(_ symbol: Symbol?) async throws -> [StopOrder]

        /// One page of stop orders, filtered by the values that aren't `nil`; `start` and `end` limit
        /// the time range as MEXC applies it. Pages hold at most 100.
        func list(
            _ symbol: Symbol?, state: PlanOrderState?, side: PositionSide?, start: Date?, end: Date?,
            page: PageRequest
        ) async throws -> [StopOrder]
    }
}

// MARK: - Defaults

extension MexcFutures.StopOrderAPI {
    /// Cancels one waiting stop order.
    public func cancel(_ id: MexcFutures.StopOrderID) async throws {
        try await cancel([id])
    }

    /// Cancels every waiting stop order in every market.
    public func cancelAll() async throws {
        try await cancelAll(nil, position: nil)
    }

    /// Cancels every waiting stop order in one market.
    public func cancelAll(_ symbol: MexcFutures.Symbol) async throws {
        try await cancelAll(symbol, position: nil)
    }

    /// Cancels every waiting stop order of one position.
    public func cancelAll(position: MexcFutures.PositionID) async throws {
        try await cancelAll(nil, position: position)
    }

    /// The waiting stop orders in every market.
    public func pending() async throws -> [MexcFutures.StopOrder] {
        try await pending(nil)
    }

    /// One page of stop orders, the first unless `page` says otherwise.
    public func list(
        _ symbol: MexcFutures.Symbol? = nil, page: MexcFutures.PageRequest = .first
    ) async throws -> [MexcFutures.StopOrder] {
        try await list(symbol, state: nil, side: nil, start: nil, end: nil, page: page)
    }
}
