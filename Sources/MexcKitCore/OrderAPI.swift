public import Foundation

// MARK: - Protocol

extension MexcFutures {
    /// The account's orders: placing, changing and canceling them, and reading them and their fills.
    ///
    /// Placing, changing and canceling need credentials with MEXC's "Order Placing" permission; reading
    /// needs "View Order Details". A request MEXC can't take as built, such as an ID that isn't a number,
    /// throws ``ClientError/Reason/invalidRequest`` before anything is sent.
    ///
    /// Batch calls answer each item with a ``BatchResult``; match a result to its order by
    /// ``BatchResult/id``. A request that changes something and fails with
    /// ``MexcError/Code/internalError``, ``ClientError/Reason/timedOut`` or
    /// ``ClientError/Reason/connectionFailed`` may still have taken effect: check before repeating it.
    public protocol OrderAPI: Sendable {
        /// Places an order.
        func place(_ request: OrderRequest) async throws -> PlacedOrder

        /// Places up to 50 orders, each answered on its own. MEXC offers this to market maker accounts
        /// only.
        ///
        /// MEXC's batch doesn't take attached stops, trigger protection or best prices: an order with any
        /// of them throws ``ClientError/Reason/invalidRequest`` before anything is sent. MEXC requires a
        /// self-trade prevention mode on each order of a batch; an order without one is sent with
        /// ``SelfTradePreventionMode/off``.
        func place(_ requests: [OrderRequest]) async throws -> [BatchResult<OrderID>]

        /// Chases a limit order: MEXC moves its price to the corresponding one-tick price.
        func chase(_ id: OrderID) async throws

        /// Changes a limit order's price and volume, and returns the order's ID as MEXC reports it.
        func modify(_ id: OrderID, price: Decimal, volume: Decimal) async throws -> OrderID

        /// Cancels up to 50 pending orders, each answered on its own.
        func cancel(_ ids: [OrderID]) async throws -> [BatchResult<OrderID>]

        /// Cancels the order with an external ID in one market.
        ///
        /// Throws the ``MexcError`` MEXC reports for the order, such as
        /// ``MexcError/Code/orderNotFound``.
        func cancel(externalID: ExternalOrderID, in symbol: Symbol) async throws

        /// Cancels the orders with these external IDs in one market, each answered on its own.
        func cancel(externalIDs: [ExternalOrderID], in symbol: Symbol) async throws -> [BatchResult<OrderID>]

        /// Cancels every pending order in one market, or in every market when `symbol` is `nil`.
        func cancelAll(_ symbol: Symbol?) async throws

        func get(_ id: OrderID) async throws -> Order

        /// Up to 50 orders.
        func get(_ ids: [OrderID]) async throws -> [Order]

        /// The order with an external ID in one market.
        func get(externalID: ExternalOrderID, in symbol: Symbol) async throws -> Order

        /// The orders with these external IDs in one market.
        func get(externalIDs: [ExternalOrderID], in symbol: Symbol) async throws -> [Order]

        /// One page of pending orders in every market. Pages hold at most 100.
        func pending(page: PageRequest) async throws -> [Order]

        /// One page of orders in one market in any of `states`, filtered by the other values that
        /// aren't `nil`; `start` and `end` limit the time range as MEXC applies it. Pages hold at most
        /// 100.
        func history(
            _ symbol: Symbol, states: [OrderState], category: OrderCategory?, start: Date?, end: Date?,
            page: PageRequest
        ) async throws -> [Order]

        /// One page of orders MEXC lists as closed in one market; `start` and `end` limit the time range
        /// as MEXC applies it. Pages hold at most 1000.
        func closed(_ symbol: Symbol, start: Date?, end: Date?, page: PageRequest) async throws -> [Order]

        /// One page of fills in one market; `start` and `end` limit the time range as MEXC applies it.
        /// Pages hold at most 1000.
        func fills(_ symbol: Symbol, start: Date?, end: Date?, page: PageRequest) async throws -> [Fill]

        /// The fills of one order.
        func fills(of id: OrderID) async throws -> [Fill]

        /// How many orders of each kind are pending.
        func pendingCounts() async throws -> PendingOrderCounts
    }
}

// MARK: - Defaults

extension MexcFutures.OrderAPI {
    /// Cancels one pending order.
    ///
    /// Throws the ``MexcError`` MEXC reports for the order, such as
    /// ``MexcError/Code/orderNotCancellable``.
    public func cancel(_ id: MexcFutures.OrderID) async throws {
        if let error = try await cancel([id]).lazy.compactMap(\.error).first {
            throw error
        }
    }

    /// Cancels every pending order in every market.
    public func cancelAll() async throws {
        try await cancelAll(nil)
    }

    /// The first page of pending orders.
    public func pending() async throws -> [MexcFutures.Order] {
        try await pending(page: .first)
    }

    /// One page of orders in one market in any state, the first unless `page` says otherwise.
    public func history(
        _ symbol: MexcFutures.Symbol, page: MexcFutures.PageRequest = .first
    ) async throws -> [MexcFutures.Order] {
        try await history(
            symbol, states: [.pending, .open, .filled, .canceled, .invalid], category: nil, start: nil, end: nil,
            page: page
        )
    }

    /// One page of closed orders in one market, the first unless `page` says otherwise.
    public func closed(
        _ symbol: MexcFutures.Symbol, page: MexcFutures.PageRequest = .first
    ) async throws -> [MexcFutures.Order] {
        try await closed(symbol, start: nil, end: nil, page: page)
    }

    /// One page of fills in one market, the first unless `page` says otherwise.
    public func fills(
        _ symbol: MexcFutures.Symbol, page: MexcFutures.PageRequest = .first
    ) async throws -> [MexcFutures.Fill] {
        try await fills(symbol, start: nil, end: nil, page: page)
    }
}
