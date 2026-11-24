public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A position in one market: open, or closed in the position history.
    ///
    /// Volumes are in contracts. The optional properties are in MEXC's documentation but not yet in a
    /// recorded response, or MEXC documents them as sometimes missing; `nil` means the response didn't
    /// include the field.
    public struct Position: Hashable, Sendable {
        public let id: PositionID
        public let symbol: Symbol
        public let side: PositionSide
        public let marginMode: MarginMode
        public let state: PositionState
        public let leverage: Int
        /// The volume held.
        public let volume: Decimal
        /// MEXC's "frozen volume".
        public let frozenVolume: Decimal
        /// The volume closed so far.
        public let closedVolume: Decimal
        /// The average price of the volume held, at full precision.
        public let averagePrice: Decimal
        /// The average opening price, at full precision.
        public let averageOpenPrice: Decimal
        /// The average closing price.
        public let averageClosePrice: Decimal
        /// The liquidation price in isolated margin mode. `nil` when the response didn't include it.
        public let liquidationPrice: Decimal?
        /// The initial margin, which can be adjusted in isolated mode to move the liquidation price.
        public let initialMargin: Decimal
        /// The initial margin when the position opened.
        public let originalInitialMargin: Decimal
        /// The sum of the position's funding payments: positive when received, negative when paid.
        public let funding: Decimal
        /// The realized profit; negative for a loss.
        public let realizedProfit: Decimal
        /// MEXC's "auto-add initial margin supported" flag.
        public let addsMarginAutomatically: Bool
        /// The unrealized profit; negative for a loss.
        public let unrealizedProfit: Decimal?
        /// The profit of the closed volume, without fees.
        public let closingProfit: Decimal?
        /// The return: realized profit divided by initial margin.
        public let profitRatio: Decimal?
        /// The position's current margin ratio.
        public let marginRatio: Decimal?
        /// The fees, not counting deductions, signed as MEXC reports them.
        public let fee: Decimal?
        /// The accumulated fees, signed as MEXC reports them.
        public let totalFee: Decimal?
        /// The auto-deleveraging rank from 1 to 5. `nil` while MEXC refreshes it.
        public let autoDeleveragingLevel: Int?
        public let createdAt: Date
        public let updatedAt: Date?

        public init(
            id: PositionID, symbol: Symbol, side: PositionSide, marginMode: MarginMode, state: PositionState,
            leverage: Int, volume: Decimal, frozenVolume: Decimal, closedVolume: Decimal, averagePrice: Decimal,
            averageOpenPrice: Decimal, averageClosePrice: Decimal, liquidationPrice: Decimal?, initialMargin: Decimal,
            originalInitialMargin: Decimal, funding: Decimal, realizedProfit: Decimal,
            addsMarginAutomatically: Bool, unrealizedProfit: Decimal?, closingProfit: Decimal?,
            profitRatio: Decimal?, marginRatio: Decimal?, fee: Decimal?, totalFee: Decimal?,
            autoDeleveragingLevel: Int?, createdAt: Date, updatedAt: Date?
        ) {
            self.id = id
            self.symbol = symbol
            self.side = side
            self.marginMode = marginMode
            self.state = state
            self.leverage = leverage
            self.volume = volume
            self.frozenVolume = frozenVolume
            self.closedVolume = closedVolume
            self.averagePrice = averagePrice
            self.averageOpenPrice = averageOpenPrice
            self.averageClosePrice = averageClosePrice
            self.liquidationPrice = liquidationPrice
            self.initialMargin = initialMargin
            self.originalInitialMargin = originalInitialMargin
            self.funding = funding
            self.realizedProfit = realizedProfit
            self.addsMarginAutomatically = addsMarginAutomatically
            self.unrealizedProfit = unrealizedProfit
            self.closingProfit = closingProfit
            self.profitRatio = profitRatio
            self.marginRatio = marginRatio
            self.fee = fee
            self.totalFee = totalFee
            self.autoDeleveragingLevel = autoDeleveragingLevel
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

// MARK: - Wire

extension MexcFutures.Position: Decodable {
    private enum CodingKeys: String, CodingKey {
        case positionId, symbol, positionType, openType, state, leverage, holdVol, frozenVol, closeVol
        case holdAvgPrice, holdAvgPriceFullyScale, openAvgPrice, openAvgPriceFullyScale, closeAvgPrice
        case liquidatePrice, im, oim, holdFee, realised, autoAddIm, unRealizedPnl, closeProfitLoss, profitRatio
        case marginRatio, fee, totalFee, adlLevel, createTime, updateTime
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(MexcFutures.PositionID.self, forKey: .positionId)
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        side = try container.decode(MexcFutures.PositionSide.self, forKey: .positionType)
        marginMode = try container.decode(MexcFutures.MarginMode.self, forKey: .openType)
        state = try container.decode(MexcFutures.PositionState.self, forKey: .state)
        leverage = try container.decode(Int.self, forKey: .leverage)
        volume = try container.decimal(forKey: .holdVol)
        frozenVolume = try container.decimal(forKey: .frozenVol)
        closedVolume = try container.decimal(forKey: .closeVol)
        // The `FullyScale` strings carry digits the plain numbers may round away.
        averagePrice = try container.decimalIfPresent(forKey: .holdAvgPriceFullyScale)
            ?? container.decimal(forKey: .holdAvgPrice)
        averageOpenPrice = try container.decimalIfPresent(forKey: .openAvgPriceFullyScale)
            ?? container.decimal(forKey: .openAvgPrice)
        averageClosePrice = try container.decimal(forKey: .closeAvgPrice)
        liquidationPrice = try container.decimalIfPresent(forKey: .liquidatePrice)
        initialMargin = try container.decimal(forKey: .im)
        originalInitialMargin = try container.decimal(forKey: .oim)
        funding = try container.decimal(forKey: .holdFee)
        realizedProfit = try container.decimal(forKey: .realised)
        addsMarginAutomatically = try container.decode(Bool.self, forKey: .autoAddIm)
        unrealizedProfit = try container.decimalIfPresent(forKey: .unRealizedPnl)
        closingProfit = try container.decimalIfPresent(forKey: .closeProfitLoss)
        profitRatio = try container.decimalIfPresent(forKey: .profitRatio)
        marginRatio = try container.decimalIfPresent(forKey: .marginRatio)
        fee = try container.decimalIfPresent(forKey: .fee)
        totalFee = try container.decimalIfPresent(forKey: .totalFee)
        autoDeleveragingLevel = try container.decodeIfPresent(Int.self, forKey: .adlLevel)
        createdAt = try container.millisecondDate(forKey: .createTime)
        updatedAt = try container.millisecondDateIfPresent(forKey: .updateTime)
    }
}
