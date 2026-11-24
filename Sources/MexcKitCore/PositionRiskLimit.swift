// MARK: - Model

extension MexcFutures {
    /// The risk limit tier the account is at in one market, for one side and margin mode.
    public struct PositionRiskLimit: Hashable, Sendable {
        public let symbol: Symbol
        public let side: PositionSide
        /// The margin mode. In MEXC's example response, not in its field list; `nil` when the response
        /// didn't include it.
        public let marginMode: MarginMode?
        /// The tier: the lower of the tiers set by leverage and by position size.
        ///
        /// When the contract limits positions by value, MEXC converts the maximum volume to contracts
        /// at the current fair price.
        public let limit: Contract.RiskLimit

        public init(symbol: Symbol, side: PositionSide, marginMode: MarginMode?, limit: Contract.RiskLimit) {
            self.symbol = symbol
            self.side = side
            self.marginMode = marginMode
            self.limit = limit
        }
    }
}

// MARK: - Wire

extension MexcFutures.PositionRiskLimit: Decodable {
    private enum CodingKeys: String, CodingKey {
        case symbol, positionType, openType
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        side = try container.decode(MexcFutures.PositionSide.self, forKey: .positionType)
        marginMode = try container.decodeIfPresent(MexcFutures.MarginMode.self, forKey: .openType)
        limit = try MexcFutures.Contract.RiskLimit(from: decoder)
    }
}
