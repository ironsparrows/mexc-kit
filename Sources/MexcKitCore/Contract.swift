public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A futures market: its symbol and trading rules.
    ///
    /// Sizes are in contracts; ``contractSize`` converts one contract to the base asset.
    public struct Contract: Hashable, Sendable {
        public let symbol: Symbol
        /// The English display name, such as `"BTC_USDT PERPETUAL"`.
        public let displayName: String
        public let baseAsset: String
        public let quoteAsset: String
        /// The asset margin and profit are settled in.
        public let settlementAsset: String
        /// How much of the base asset one contract is.
        public let contractSize: Decimal
        public let leverage: ClosedRange<Int>
        /// The smallest price change. Prices must be a multiple of it.
        public let priceTick: Decimal
        /// The smallest volume change. Volumes must be a multiple of it.
        public let volumeStep: Decimal
        /// The number of decimal places in a price.
        public let priceScale: Int
        /// The number of decimal places in a volume.
        public let volumeScale: Int
        public let minimumVolume: Decimal
        public let maximumVolume: Decimal
        /// The largest volume of one limit order.
        public let maximumLimitOrderVolume: Decimal
        public let takerFeeRate: Decimal
        public let makerFeeRate: Decimal
        public let initialMarginRate: Decimal
        public let maintenanceMarginRate: Decimal
        /// The tiers of the risk limit, from the smallest position up. Empty unless the market uses
        /// MEXC's custom risk limit tiers.
        public let riskLimits: [RiskLimit]
        /// The margin modes a position in this market can use. Empty for an opening type this version
        /// of the SDK doesn't know.
        public let marginModes: Set<MarginMode>
        public let state: State
        /// Whether orders can be placed through the API.
        public let allowsAPITrading: Bool
        /// The exchanges whose prices make up the index price.
        public let indexSources: [String]
        /// The price steps order book depth can be grouped by.
        public let depthSteps: [Decimal]
        public let listedAt: Date

        public init(
            symbol: Symbol, displayName: String, baseAsset: String, quoteAsset: String, settlementAsset: String,
            contractSize: Decimal, leverage: ClosedRange<Int>, priceTick: Decimal, volumeStep: Decimal,
            priceScale: Int, volumeScale: Int, minimumVolume: Decimal, maximumVolume: Decimal,
            maximumLimitOrderVolume: Decimal, takerFeeRate: Decimal, makerFeeRate: Decimal,
            initialMarginRate: Decimal, maintenanceMarginRate: Decimal, riskLimits: [RiskLimit],
            marginModes: Set<MarginMode>, state: State, allowsAPITrading: Bool, indexSources: [String],
            depthSteps: [Decimal], listedAt: Date
        ) {
            self.symbol = symbol
            self.displayName = displayName
            self.baseAsset = baseAsset
            self.quoteAsset = quoteAsset
            self.settlementAsset = settlementAsset
            self.contractSize = contractSize
            self.leverage = leverage
            self.priceTick = priceTick
            self.volumeStep = volumeStep
            self.priceScale = priceScale
            self.volumeScale = volumeScale
            self.minimumVolume = minimumVolume
            self.maximumVolume = maximumVolume
            self.maximumLimitOrderVolume = maximumLimitOrderVolume
            self.takerFeeRate = takerFeeRate
            self.makerFeeRate = makerFeeRate
            self.initialMarginRate = initialMarginRate
            self.maintenanceMarginRate = maintenanceMarginRate
            self.riskLimits = riskLimits
            self.marginModes = marginModes
            self.state = state
            self.allowsAPITrading = allowsAPITrading
            self.indexSources = indexSources
            self.depthSteps = depthSteps
            self.listedAt = listedAt
        }
    }
}

extension MexcFutures.Contract {
    /// One tier of a contract's risk limit: up to ``maximumVolume``, positions use these rates and
    /// at most this leverage.
    public struct RiskLimit: Hashable, Sendable {
        public let level: Int
        public let maximumVolume: Decimal
        public let maintenanceMarginRate: Decimal
        public let initialMarginRate: Decimal
        public let maximumLeverage: Int

        public init(
            level: Int, maximumVolume: Decimal, maintenanceMarginRate: Decimal, initialMarginRate: Decimal,
            maximumLeverage: Int
        ) {
            self.level = level
            self.maximumVolume = maximumVolume
            self.maintenanceMarginRate = maintenanceMarginRate
            self.initialMarginRate = initialMarginRate
            self.maximumLeverage = maximumLeverage
        }
    }

    /// Whether a contract trades.
    public struct State: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let enabled = Self(rawValue: 0)
        public static let delivering = Self(rawValue: 1)
        public static let delivered = Self(rawValue: 2)
        public static let offline = Self(rawValue: 3)
        public static let paused = Self(rawValue: 4)
    }
}

// MARK: - Reading

extension MexcFutures.Contract {
    /// The price snapped to a multiple of ``priceTick``.
    ///
    /// Build prices from strings or integers, such as `Decimal(string: "60000.5")`: a floating-point
    /// literal like `0.000018` isn't exact as a `Decimal`.
    public func round(price: Decimal, rule: FloatingPointRoundingRule) -> Decimal {
        Self.snap(price, to: priceTick, rule)
    }

    /// The volume snapped to a multiple of ``volumeStep``.
    public func round(volume: Decimal, rule: FloatingPointRoundingRule) -> Decimal {
        Self.snap(volume, to: volumeStep, rule)
    }

    private static func snap(_ value: Decimal, to step: Decimal, _ rule: FloatingPointRoundingRule) -> Decimal {
        guard step > 0 else { return value }
        var steps = value / step
        var rounded = Decimal()
        let mode: NSDecimalNumber.RoundingMode = switch rule {
        case .down: .down
        case .up: .up
        case .toNearestOrEven: .bankers
        case .toNearestOrAwayFromZero: .plain
        case .towardZero: steps < 0 ? .up : .down
        case .awayFromZero: steps < 0 ? .down : .up
        @unknown default: .bankers
        }
        NSDecimalRound(&rounded, &steps, 0, mode)
        return rounded * step
    }
}

// MARK: - Wire

extension MexcFutures.Contract: Decodable {
    private enum CodingKeys: String, CodingKey {
        case symbol, displayNameEn, baseCoin, quoteCoin, settleCoin, contractSize, minLeverage, maxLeverage
        case priceUnit, volUnit, priceScale, volScale, minVol, maxVol, limitMaxVol, takerFeeRate, makerFeeRate
        case initialMarginRate, maintenanceMarginRate, riskLimitCustom, positionOpenType, state, apiAllowed
        case indexOrigin, depthStepList, createTime
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        displayName = try container.decode(String.self, forKey: .displayNameEn)
        baseAsset = try container.decode(String.self, forKey: .baseCoin)
        quoteAsset = try container.decode(String.self, forKey: .quoteCoin)
        settlementAsset = try container.decode(String.self, forKey: .settleCoin)
        contractSize = try container.decimal(forKey: .contractSize)
        let minimumLeverage = try container.decode(Int.self, forKey: .minLeverage)
        let maximumLeverage = try container.decode(Int.self, forKey: .maxLeverage)
        guard minimumLeverage <= maximumLeverage else {
            throw DecodingError.dataCorruptedError(
                forKey: .maxLeverage, in: container,
                debugDescription: "Maximum leverage \(maximumLeverage) is below the minimum \(minimumLeverage)"
            )
        }
        leverage = minimumLeverage...maximumLeverage
        priceTick = try container.decimal(forKey: .priceUnit)
        volumeStep = try container.decimal(forKey: .volUnit)
        priceScale = try container.decode(Int.self, forKey: .priceScale)
        volumeScale = try container.decode(Int.self, forKey: .volScale)
        minimumVolume = try container.decimal(forKey: .minVol)
        maximumVolume = try container.decimal(forKey: .maxVol)
        maximumLimitOrderVolume = try container.decimal(forKey: .limitMaxVol)
        takerFeeRate = try container.decimal(forKey: .takerFeeRate)
        makerFeeRate = try container.decimal(forKey: .makerFeeRate)
        initialMarginRate = try container.decimal(forKey: .initialMarginRate)
        maintenanceMarginRate = try container.decimal(forKey: .maintenanceMarginRate)
        riskLimits = try container.decodeIfPresent([RiskLimit].self, forKey: .riskLimitCustom) ?? []
        marginModes = switch try container.decode(Int.self, forKey: .positionOpenType) {
        case 1: [.isolated]
        case 2: [.cross]
        case 3: [.isolated, .cross]
        default: []
        }
        state = try container.decode(State.self, forKey: .state)
        allowsAPITrading = try container.decode(Bool.self, forKey: .apiAllowed)
        indexSources = try container.decodeIfPresent([String].self, forKey: .indexOrigin) ?? []
        depthSteps = try (container.decodeIfPresent([FlexibleDecimal].self, forKey: .depthStepList) ?? []).map(\.value)
        listedAt = try container.millisecondDate(forKey: .createTime)
    }
}

extension MexcFutures.Contract.RiskLimit: Decodable {
    private enum CodingKeys: String, CodingKey {
        case level, maxVol, mmr, imr, maxLeverage
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        level = try container.decode(Int.self, forKey: .level)
        maximumVolume = try container.decimal(forKey: .maxVol)
        maintenanceMarginRate = try container.decimal(forKey: .mmr)
        initialMarginRate = try container.decimal(forKey: .imr)
        maximumLeverage = try container.decode(Int.self, forKey: .maxLeverage)
    }
}
