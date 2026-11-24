public import Foundation

// MARK: - Model

extension MexcFutures {
    /// The leverage the account uses in one market, for one side and margin mode.
    public struct LeverageSetting: Hashable, Sendable {
        public let side: PositionSide
        public let marginMode: MarginMode
        public let leverage: Int
        public let maximumLeverage: Int
        /// The maintenance margin rate. `nil` when the response didn't include it, which MEXC's
        /// documentation doesn't rule out.
        public let maintenanceMarginRate: Decimal?

        public init(
            side: PositionSide, marginMode: MarginMode, leverage: Int, maximumLeverage: Int,
            maintenanceMarginRate: Decimal?
        ) {
            self.side = side
            self.marginMode = marginMode
            self.leverage = leverage
            self.maximumLeverage = maximumLeverage
            self.maintenanceMarginRate = maintenanceMarginRate
        }
    }
}

// MARK: - Wire

extension MexcFutures.LeverageSetting: Decodable {
    private enum CodingKeys: String, CodingKey {
        case positionType, openType, leverage, maxLeverageView, currentMmr
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        side = try container.decode(MexcFutures.PositionSide.self, forKey: .positionType)
        marginMode = try container.decode(MexcFutures.MarginMode.self, forKey: .openType)
        leverage = try container.decode(Int.self, forKey: .leverage)
        maximumLeverage = try container.decode(Int.self, forKey: .maxLeverageView)
        maintenanceMarginRate = try container.decimalIfPresent(forKey: .currentMmr)
    }
}
