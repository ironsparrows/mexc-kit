import Foundation

/// The live ``MexcFutures/OrderAPI``.
struct OrderEndpoints: MexcFutures.OrderAPI {
    let rest: RESTClient

    // MARK: - Endpoints

    func place(_ request: MexcFutures.OrderRequest) async throws -> MexcFutures.PlacedOrder {
        try await rest.send(.post("/api/v1/private/order/create", .json(try OrderBody(request, inBatch: false))))
    }

    func place(_ requests: [MexcFutures.OrderRequest]) async throws -> [MexcFutures.BatchResult<MexcFutures.OrderID>] {
        let body = try requests.map { try OrderBody($0, inBatch: true) }
        let items: [BatchItem] = try await rest.send(.post("/api/v1/private/order/submit_batch", .json(body)))
        return items.map(\.result)
    }

    func chase(_ id: MexcFutures.OrderID) async throws {
        let body = ["orderId": try NumericID(id)]
        let _: NoData = try await rest.send(.post("/api/v1/private/order/chase_limit_order", .json(body)))
    }

    func modify(_ id: MexcFutures.OrderID, price: Decimal, volume: Decimal) async throws -> MexcFutures.OrderID {
        let body = Modification(orderId: try NumericID(id), price: price, vol: volume)
        return try await rest.send(.post("/api/v1/private/order/change_limit_order", .json(body)))
    }

    func cancel(_ ids: [MexcFutures.OrderID]) async throws -> [MexcFutures.BatchResult<MexcFutures.OrderID>] {
        guard !ids.isEmpty else { return [] }
        let body = try ids.map(NumericID.init)
        let items: [BatchItem] = try await rest.send(.post("/api/v1/private/order/cancel", .json(body)))
        return items.map(\.result)
    }

    func cancel(externalID: MexcFutures.ExternalOrderID, in symbol: MexcFutures.Symbol) async throws {
        let body = [ExternalOrder(symbol: symbol, externalOid: externalID)]
        let items: [BatchItem] = try await rest.send(.post("/api/v1/private/order/cancel_with_external", .json(body)))
        if let error = items.lazy.compactMap(\.result.error).first {
            throw error
        }
    }

    func cancel(
        externalIDs: [MexcFutures.ExternalOrderID], in symbol: MexcFutures.Symbol
    ) async throws -> [MexcFutures.BatchResult<MexcFutures.OrderID>] {
        let body = externalIDs.map { ExternalOrder(symbol: symbol, externalOid: $0) }
        let items: [BatchItem] = try await rest.send(
            .post("/api/v1/private/order/batch_cancel_with_external", .json(body))
        )
        return items.map(\.result)
    }

    func cancelAll(_ symbol: MexcFutures.Symbol?) async throws {
        // MEXC cancels the orders of every market when `symbol` is the empty string.
        let body = ["symbol": symbol?.rawValue ?? ""]
        let _: NoData = try await rest.send(.post("/api/v1/private/order/cancel_all", .json(body)))
    }

    func get(_ id: MexcFutures.OrderID) async throws -> MexcFutures.Order {
        try await rest.send(.get("/api/v1/private/order/get/\(id.rawValue)", authentication: .signed))
    }

    func get(_ ids: [MexcFutures.OrderID]) async throws -> [MexcFutures.Order] {
        guard !ids.isEmpty else { return [] }
        return try await rest.send(.get("/api/v1/private/order/batch_query", query: [
            "order_ids": ids.map(\.rawValue).joined(separator: ","),
        ], authentication: .signed))
    }

    func get(externalID: MexcFutures.ExternalOrderID, in symbol: MexcFutures.Symbol) async throws -> MexcFutures.Order {
        try await rest.send(.get(
            "/api/v1/private/order/external/\(symbol.rawValue)/\(externalID.rawValue)", authentication: .signed
        ))
    }

    func get(
        externalIDs: [MexcFutures.ExternalOrderID], in symbol: MexcFutures.Symbol
    ) async throws -> [MexcFutures.Order] {
        let body = externalIDs.map { ExternalOrder(symbol: symbol, externalOid: $0) }
        return try await rest.send(.post("/api/v1/private/order/batch_query_with_external", .json(body)))
    }

    func pending(page: MexcFutures.PageRequest) async throws -> [MexcFutures.Order] {
        let orders: ArrayOrPage<MexcFutures.Order> = try await rest.send(
            .get("/api/v1/private/order/list/open_orders", query: [
                "page_num": String(page.number),
                "page_size": String(page.size),
            ], authentication: .signed)
        )
        return orders.items
    }

    func history(
        _ symbol: MexcFutures.Symbol, states: [MexcFutures.OrderState], category: MexcFutures.OrderCategory?,
        start: Date?, end: Date?, page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.Order] {
        let orders: ArrayOrPage<MexcFutures.Order> = try await rest.send(
            .get("/api/v1/private/order/list/history_orders", query: [
                "symbol": symbol.rawValue,
                // No states sends none, for any state, as plan orders do.
                "states": states.isEmpty ? nil : states.map { String($0.rawValue) }.joined(separator: ","),
                "category": category.map { String($0.rawValue) },
                "start_time": start.map(Self.milliseconds),
                "end_time": end.map(Self.milliseconds),
                "page_num": String(page.number),
                "page_size": String(page.size),
            ], authentication: .signed)
        )
        return orders.items
    }

    func closed(
        _ symbol: MexcFutures.Symbol, start: Date?, end: Date?, page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.Order] {
        let orders: ArrayOrPage<MexcFutures.Order> = try await rest.send(
            .get("/api/v1/private/order/list/close_orders", query: [
                "symbol": symbol.rawValue,
                "start_time": start.map(Self.milliseconds),
                "end_time": end.map(Self.milliseconds),
                "page_num": String(page.number),
                "page_size": String(page.size),
            ], authentication: .signed)
        )
        return orders.items
    }

    func fills(
        _ symbol: MexcFutures.Symbol, start: Date?, end: Date?, page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.Fill] {
        let fills: ArrayOrPage<MexcFutures.Fill> = try await rest.send(
            .get("/api/v1/private/order/list/order_deals/v3", query: [
                "symbol": symbol.rawValue,
                "start_time": start.map(Self.milliseconds),
                "end_time": end.map(Self.milliseconds),
                "page_num": String(page.number),
                "page_size": String(page.size),
            ], authentication: .signed)
        )
        return fills.items
    }

    func fills(of id: MexcFutures.OrderID) async throws -> [MexcFutures.Fill] {
        try await rest.send(.get("/api/v1/private/order/deal_details/\(id.rawValue)", authentication: .signed))
    }

    func pendingCounts() async throws -> MexcFutures.PendingOrderCounts {
        try await rest.send(.get("/api/v1/private/order/open_order_total_count", authentication: .signed))
    }

    private static func milliseconds(_ date: Date) -> String {
        String(date.millisecondsSince1970)
    }
}

// MARK: - Wire

/// A `create` or `submit_batch` order, with MEXC's field names.
private struct OrderBody: Encodable, Sendable {
    let symbol: MexcFutures.Symbol
    let side: MexcFutures.OrderSide
    let type: MexcFutures.OrderType
    let price: Decimal?
    let bboTypeNum: MexcFutures.BestPrice?
    let vol: Decimal
    let leverage: Int?
    let openType: MexcFutures.MarginMode
    let positionId: NumericID?
    let externalOid: MexcFutures.ExternalOrderID?
    let takeProfitPrice: Decimal?
    let profitTrend: MexcFutures.PriceSource?
    let stopLossPrice: Decimal?
    let lossTrend: MexcFutures.PriceSource?
    let positionMode: MexcFutures.PositionMode?
    let reduceOnly: Bool?
    let priceProtect: Int?
    let marketCeiling: Bool?
    let flashClose: Bool?
    let stpMode: MexcFutures.SelfTradePreventionMode?

    /// The fields of `request`, leaving out every option that isn't set.
    ///
    /// Throws ``MexcFutures/ClientError/Reason/invalidRequest`` for what MEXC doesn't take: an external
    /// ID on a best-price order, and in a batch, attached stops, trigger protection or a best price. A
    /// batch order without a self-trade prevention mode gets ``MexcFutures/SelfTradePreventionMode/off``,
    /// since MEXC requires one there.
    init(_ request: MexcFutures.OrderRequest, inBatch: Bool) throws {
        let options = request.options
        if request.pricing.bestPrice != nil, request.externalID != nil {
            throw MexcFutures.ClientError(.invalidRequest, message: "A best-price order can't have an external ID")
        }
        if inBatch, request.takeProfit != nil || request.stopLoss != nil || options.triggerProtection
            || request.pricing.bestPrice != nil
        {
            throw MexcFutures.ClientError(
                .invalidRequest,
                message: "A batch order can't have a take-profit, stop-loss, trigger protection or best price"
            )
        }
        symbol = request.symbol
        side = request.side
        type = request.pricing.type
        price = request.pricing.price
        bboTypeNum = request.pricing.bestPrice
        vol = request.volume
        leverage = request.leverage
        openType = request.marginMode
        positionId = try request.position.map(NumericID.init)
        externalOid = request.externalID
        takeProfitPrice = request.takeProfit?.price
        profitTrend = request.takeProfit?.source
        stopLossPrice = request.stopLoss?.price
        lossTrend = request.stopLoss?.source
        positionMode = options.positionMode
        reduceOnly = options.reduceOnly ? true : nil
        priceProtect = options.triggerProtection ? 1 : nil
        marketCeiling = options.marketCeiling ? true : nil
        flashClose = options.flashClose ? true : nil
        stpMode = options.selfTradePrevention ?? (inBatch ? .off : nil)
    }
}

private struct Modification: Encodable, Sendable {
    let orderId: NumericID
    let price: Decimal
    let vol: Decimal
}

private struct ExternalOrder: Encodable, Sendable {
    let symbol: MexcFutures.Symbol
    let externalOid: MexcFutures.ExternalOrderID
}

/// One item of a batch answer: `{"orderId": 1, "errorCode": 2040, "errorMsg": "order not exist"}`, with
/// `errorCode` 0 for success.
private struct BatchItem: Decodable, Sendable {
    let orderId: MexcFutures.OrderID?
    let errorCode: Int?
    let errorMsg: String?

    var result: MexcFutures.BatchResult<MexcFutures.OrderID> {
        let error = errorCode.flatMap { $0 == 0 ? nil : MexcError(code: .init(rawValue: $0), message: errorMsg) }
        return .init(id: orderId, error: error)
    }
}
