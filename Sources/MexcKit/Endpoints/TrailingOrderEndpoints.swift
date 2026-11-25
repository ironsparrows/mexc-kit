import Foundation

/// The live ``MexcFutures/TrailingOrderAPI``.
struct TrailingOrderEndpoints: MexcFutures.TrailingOrderAPI {
    let rest: RESTClient

    // MARK: - Endpoints

    func place(_ request: MexcFutures.TrailingOrderRequest) async throws -> MexcFutures.TrailingOrderID {
        try await rest.send(.post("/api/v1/private/trackorder/place", .json(TrailingOrderBody(request))))
    }

    func modify(
        _ id: MexcFutures.TrailingOrderID, in symbol: MexcFutures.Symbol, volume: Decimal,
        callback: MexcFutures.TrailingOrder.Callback, activationPrice: Decimal?, source: MexcFutures.PriceSource
    ) async throws {
        let body = Modification(
            symbol: symbol, trackOrderId: try NumericID(id), vol: volume, backType: callback.kind,
            backValue: callback.value, activePrice: activationPrice, trend: source
        )
        let _: NoData = try await rest.send(.post("/api/v1/private/trackorder/change_order", .json(body)))
    }

    func cancel(_ id: MexcFutures.TrailingOrderID, in symbol: MexcFutures.Symbol) async throws {
        let body = Cancellation(symbol: symbol, trackOrderId: try NumericID(id))
        let _: NoData = try await rest.send(.post("/api/v1/private/trackorder/cancel", .json(body)))
    }

    func list(
        _ symbol: MexcFutures.Symbol?, states: [MexcFutures.TrailingOrderState], side: MexcFutures.OrderSide?,
        start: Date?, end: Date?, page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.TrailingOrder] {
        let orders: ArrayOrPage<MexcFutures.TrailingOrder> = try await rest.send(
            .get("/api/v1/private/trackorder/list/orders", query: [
                "symbol": symbol?.rawValue,
                // MEXC requires states; none means every state.
                "states": (states.isEmpty ? Self.everyState : states).map { String($0.rawValue) }
                    .joined(separator: ","),
                "side": side.map { String($0.rawValue) },
                "start_time": start.map { String($0.millisecondsSince1970) },
                "end_time": end.map { String($0.millisecondsSince1970) },
                // Unlike MEXC's other lists, this one names its page parameters in camel case.
                "pageIndex": String(page.number),
                "pageSize": String(page.size),
            ], authentication: .signed)
        )
        return orders.items
    }

    private static let everyState: [MexcFutures.TrailingOrderState] = [.inactive, .active, .triggered, .failed, .canceled]
}

// MARK: - Wire

/// A `trackorder/place` body, with MEXC's field names.
private struct TrailingOrderBody: Encodable, Sendable {
    let symbol: MexcFutures.Symbol
    let side: MexcFutures.OrderSide
    let vol: Decimal
    let leverage: Int
    let openType: MexcFutures.MarginMode
    let backType: MexcFutures.TrailingOrder.Callback.Kind
    let backValue: Decimal
    let activePrice: Decimal?
    let trend: MexcFutures.PriceSource
    let positionMode: MexcFutures.PositionMode
    let reduceOnly: Bool?

    init(_ request: MexcFutures.TrailingOrderRequest) {
        symbol = request.symbol
        side = request.side
        vol = request.volume
        leverage = request.leverage
        openType = request.marginMode
        backType = request.callback.kind
        backValue = request.callback.value
        activePrice = request.activationPrice
        trend = request.source
        positionMode = request.positionMode
        reduceOnly = request.reduceOnly ? true : nil
    }
}

private struct Modification: Encodable, Sendable {
    let symbol: MexcFutures.Symbol
    let trackOrderId: NumericID
    let vol: Decimal
    let backType: MexcFutures.TrailingOrder.Callback.Kind
    let backValue: Decimal
    let activePrice: Decimal?
    let trend: MexcFutures.PriceSource
}

private struct Cancellation: Encodable, Sendable {
    let symbol: MexcFutures.Symbol
    let trackOrderId: NumericID
}
