import Foundation

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

    func feeRates(_ symbol: MexcFutures.Symbol?) async throws -> MexcFutures.FeeRates {
        try await rest.send(.get(
            "/api/v1/private/account/tiered_fee_rate/v2", query: ["symbol": symbol?.rawValue], authentication: .signed
        ))
    }

    func feeTotals() async throws -> MexcFutures.FeeTotals {
        try await rest.send(.get("/api/v1/private/account/asset_book/order_deal_fee/total", authentication: .signed))
    }

    func discountUsage() async throws -> MexcFutures.DiscountUsage {
        try await rest.send(.get("/api/v1/private/account/discountType", authentication: .signed))
    }

    func feeDeductionAssets() async throws -> [MexcFutures.FeeDeductionAsset] {
        try await rest.send(.get("/api/v1/private/account/feeDeductConfigs", authentication: .signed))
    }

    func feeDiscounts() async throws -> [MexcFutures.FeeDiscount] {
        try await rest.send(.get("/api/v1/private/account/config/contractFeeDiscountConfig", authentication: .signed))
    }

    func feeDeductions(
        _ symbol: MexcFutures.Symbol, fills: [MexcFutures.FillID], start: Date?, end: Date?,
        page: MexcFutures.PageRequest
    ) async throws -> [MexcFutures.FeeDeduction] {
        let deductions: ArrayOrPage<MexcFutures.FeeDeduction> = try await rest.send(
            .get("/api/v1/private/order/fee_details", query: [
                "symbol": symbol.rawValue,
                // MEXC documents "up to 20" IDs but not the separator; commas are its list form elsewhere.
                "ids": fills.isEmpty ? nil : fills.map(\.rawValue).joined(separator: ","),
                "start_time": start.map { String($0.millisecondsSince1970) },
                "end_time": end.map { String($0.millisecondsSince1970) },
                "page_num": String(page.number),
                "page_size": String(page.size),
            ], authentication: .signed)
        )
        return deductions.items
    }
}
