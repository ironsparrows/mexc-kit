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

    private static func milliseconds(_ date: Date) -> String {
        String(date.millisecondsSince1970)
    }
}

// MARK: - Wire

/// A list MEXC documents both as a bare array and as a page: its documentation lists page fields, and
/// its example is an array. Either decodes to the items.
private struct ArrayOrPage<Element: Decodable & Sendable>: Decodable, Sendable {
    let items: [Element]

    init(from decoder: any Decoder) throws {
        if (try? decoder.unkeyedContainer()) != nil {
            items = try [Element](from: decoder)
        } else {
            items = try MexcFutures.Page<Element>(from: decoder).items
        }
    }
}
