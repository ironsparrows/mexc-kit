/// The live ``MexcFutures/AccountAPI``.
struct AccountEndpoints: MexcFutures.AccountAPI {
    let rest: RESTClient

    // MARK: - Endpoints

    func balances() async throws -> [MexcFutures.Balance] {
        try await rest.send(.get("/api/v1/private/account/assets", authentication: .signed))
    }

    func balance(_ asset: String) async throws -> MexcFutures.Balance {
        try await rest.send(.get("/api/v1/private/account/asset/\(asset)", authentication: .signed))
    }

    func transfers(
        asset: String?, direction: MexcFutures.TransferDirection?, state: MexcFutures.TransferState?,
        page: MexcFutures.PageRequest
    ) async throws -> MexcFutures.Page<MexcFutures.Transfer> {
        try await rest.send(.get("/api/v1/private/account/transfer_record", query: [
            "currency": asset,
            "type": direction?.rawValue,
            "state": state?.rawValue,
            "page_num": String(page.number),
            "page_size": String(page.size),
        ], authentication: .signed))
    }

    func profitRate(_ period: MexcFutures.ProfitRatePeriod) async throws -> MexcFutures.ProfitRate {
        try await rest.send(.get("/api/v1/private/account/profit_rate/\(period.rawValue)", authentication: .signed))
    }

    func riskLimits(_ symbol: MexcFutures.Symbol?) async throws -> [MexcFutures.PositionRiskLimit] {
        // MEXC groups the tiers by symbol; the dictionary's order is arbitrary, so sort.
        let bySymbol: [String: [MexcFutures.PositionRiskLimit]] = try await rest.send(
            .get("/api/v1/private/account/risk_limit", query: ["symbol": symbol?.rawValue], authentication: .signed)
        )
        return bySymbol.values.joined().sorted {
            ($0.symbol.rawValue, $0.side.rawValue, $0.marginMode?.rawValue ?? 0)
                < ($1.symbol.rawValue, $1.side.rawValue, $1.marginMode?.rawValue ?? 0)
        }
    }

    func positionMode() async throws -> MexcFutures.PositionMode {
        try await rest.send(.get("/api/v1/private/position/position_mode", authentication: .signed))
    }
}
