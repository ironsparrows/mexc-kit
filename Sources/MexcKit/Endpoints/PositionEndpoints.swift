import Foundation

/// The live ``MexcFutures/PositionAPI``.
struct PositionEndpoints: MexcFutures.PositionAPI {
    let rest: RESTClient

    // MARK: - Endpoints

    func list(
        _ symbol: MexcFutures.Symbol?, position: MexcFutures.PositionID?
    ) async throws -> [MexcFutures.Position] {
        try await rest.send(.get("/api/v1/private/position/open_positions", query: [
            "symbol": symbol?.rawValue,
            "positionId": position?.rawValue,
        ], authentication: .signed))
    }

    func history(
        _ symbol: MexcFutures.Symbol?, side: MexcFutures.PositionSide?, start: Date?, end: Date?,
        page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.Position] {
        let positions: ArrayOrPage<MexcFutures.Position> = try await rest.send(
            .get("/api/v1/private/position/list/history_positions", query: [
                "symbol": symbol?.rawValue,
                // The docs list `type` and `position_type` with the same meaning; `position_type` is
                // also what the funding records take.
                "position_type": side.map { String($0.rawValue) },
                "start_time": start.map(Self.milliseconds),
                "end_time": end.map(Self.milliseconds),
                "page_num": String(page.number),
                "page_size": String(page.size),
            ], authentication: .signed)
        )
        return positions.items
    }

    func fundingPayments(
        _ symbol: MexcFutures.Symbol?, position: MexcFutures.PositionID?, side: MexcFutures.PositionSide?,
        start: Date?, end: Date?, page: MexcFutures.PageRequest
    ) async throws -> MexcFutures.Page<MexcFutures.FundingPayment> {
        try await rest.send(.get("/api/v1/private/position/funding_records", query: [
            "symbol": symbol?.rawValue,
            "position_id": position?.rawValue,
            "position_type": side.map { String($0.rawValue) },
            "start_time": start.map(Self.milliseconds),
            "end_time": end.map(Self.milliseconds),
            "page_num": String(page.number),
            "page_size": String(page.size),
        ], authentication: .signed))
    }

    func leverage(_ symbol: MexcFutures.Symbol) async throws -> [MexcFutures.LeverageSetting] {
        try await rest.send(.get(
            "/api/v1/private/position/leverage", query: ["symbol": symbol.rawValue], authentication: .signed
        ))
    }

    func reverse(_ position: MexcFutures.PositionID, in symbol: MexcFutures.Symbol, volume: Decimal) async throws {
        let body = Reversal(positionId: try NumericID(position), symbol: symbol, vol: volume)
        let _: NoData = try await rest.send(.post("/api/v1/private/position/reverse", .json(body)))
    }

    func closeAll() async throws {
        // An empty JSON object, sent and signed, as Mexc.Net sends for this endpoint: MEXC documents
        // no parameters, and a body is the safer guess for its JSON handler.
        let _: NoData = try await rest.send(.post("/api/v1/private/position/close_all", .json(EmptyObject())))
    }

    func leverage(_ symbol: MexcFutures.Symbol, subAccount: String) async throws -> [MexcFutures.LeverageSetting] {
        try await rest.send(.get("/api/v1/private/position/leverage/subaccount", query: [
            "subAccount": subAccount,
            "symbol": symbol.rawValue,
        ], authentication: .signed))
    }

    func setLeverage(_ leverage: Int, of position: MexcFutures.PositionID) async throws {
        let body = LeverageChange(leverage: leverage, positionId: try NumericID(position))
        let _: NoData = try await rest.send(.post("/api/v1/private/position/change_leverage", .json(body)))
    }

    func setLeverage(
        _ leverage: Int, in symbol: MexcFutures.Symbol, side: MexcFutures.PositionSide,
        marginMode: MexcFutures.MarginMode
    ) async throws {
        let body = LeverageChange(leverage: leverage, symbol: symbol, positionType: side, openType: marginMode)
        let _: NoData = try await rest.send(.post("/api/v1/private/position/change_leverage", .json(body)))
    }

    func adjustMargin(of position: MexcFutures.PositionID, by change: Decimal) async throws {
        guard change != 0 else {
            throw MexcFutures.ClientError(.invalidRequest, message: "A margin change can't be 0")
        }
        let body = MarginChange(
            positionId: try NumericID(position), amount: change.magnitude, type: change > 0 ? "ADD" : "SUB"
        )
        let _: NoData = try await rest.send(.post("/api/v1/private/position/change_margin", .json(body)))
    }

    func setAddsMarginAutomatically(_ enabled: Bool, of position: MexcFutures.PositionID) async throws {
        let body = AutoAddMargin(positionId: try NumericID(position), isEnabled: enabled)
        let _: NoData = try await rest.send(.post("/api/v1/private/position/change_auto_add_im", .json(body)))
    }

    private static func milliseconds(_ date: Date) -> String {
        String(date.millisecondsSince1970)
    }
}

// MARK: - Wire

/// `{}`.
private struct EmptyObject: Encodable {}

private struct Reversal: Encodable, Sendable {
    let positionId: NumericID
    let symbol: MexcFutures.Symbol
    let vol: Decimal
}

/// A `change_leverage` body: the position when there is one, else the market, side and margin mode.
///
/// MEXC's optional `leverageMode` ("advanced" or "simple"), `marginSelected` and `leverageSelected` ("flag
/// for adjusting all contracts' margin mode" and "leverage mode") aren't sent.
private struct LeverageChange: Encodable, Sendable {
    let leverage: Int
    var positionId: NumericID?
    var symbol: MexcFutures.Symbol?
    var positionType: MexcFutures.PositionSide?
    var openType: MexcFutures.MarginMode?

    init(leverage: Int, positionId: NumericID) {
        self.leverage = leverage
        self.positionId = positionId
    }

    init(
        leverage: Int, symbol: MexcFutures.Symbol, positionType: MexcFutures.PositionSide,
        openType: MexcFutures.MarginMode
    ) {
        self.leverage = leverage
        self.symbol = symbol
        self.positionType = positionType
        self.openType = openType
    }
}

private struct MarginChange: Encodable, Sendable {
    let positionId: NumericID
    let amount: Decimal
    let type: String
}

private struct AutoAddMargin: Encodable, Sendable {
    let positionId: NumericID
    let isEnabled: Bool
}
