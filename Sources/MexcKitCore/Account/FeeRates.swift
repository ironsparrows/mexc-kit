public import Foundation

// MARK: - Model

extension MexcFutures {
    /// The account's trading fee rates, in one market or in general, and what they're based on.
    ///
    /// MEXC documents every property but doesn't always send them all, and its documentation marks
    /// none as optional; `nil` means the response didn't include the field. Not exposed: which contracts the tiers apply to (MEXC
    /// identifies them by contract ID, this SDK by symbol), the tiers' statistic window, and the
    /// leverage mode's rates, whose shape MEXC doesn't document.
    public struct FeeRates: Hashable, Sendable {
        /// The market the rates apply to; `nil` when the response leaves it out.
        public let symbol: Symbol?
        /// The maker rate the account pays, after discounts and deductions.
        public let maker: Decimal
        /// The taker rate the account pays, after discounts and deductions.
        public let taker: Decimal
        /// The maker rate before discounts and deductions.
        public let standardMaker: Decimal
        /// The taker rate before discounts and deductions.
        public let standardTaker: Decimal
        public let mode: Mode
        /// Whether the account takes part in MEXC's fee discount.
        public let joinsDiscount: Bool
        /// Whether the account currently receives the discount.
        public let receivesDiscount: Bool
        /// The discount rate, as MEXC reports it; `nil` when the response leaves it out, as it does for
        /// some accounts.
        public let discountRate: Decimal?
        /// Whether the account takes part in MEXC's fee deduction.
        public let joinsDeduction: Bool
        /// Whether the account currently receives the deduction.
        public let receivesDeduction: Bool
        /// The deduction rate, as MEXC reports it; `nil` when the response leaves it out.
        public let deductionRate: Decimal?
        /// MEXC's "trading volume in the last 30 days", as an amount.
        public let tradedAmount: Decimal
        /// The wallet balance of yesterday.
        public let walletBalance: Decimal?
        /// The fee tiers; empty unless ``mode`` is ``Mode/tiered``.
        public let tiers: [Tier]
        /// The traded amount the tiers are measured against.
        public let tierTradedAmount: Decimal?
        /// The leverage the account can use in ``symbol``.
        public let leverage: ClosedRange<Int>?

        public init(
            symbol: Symbol?, maker: Decimal, taker: Decimal, standardMaker: Decimal, standardTaker: Decimal, mode: Mode,
            joinsDiscount: Bool, receivesDiscount: Bool, discountRate: Decimal?, joinsDeduction: Bool,
            receivesDeduction: Bool, deductionRate: Decimal?, tradedAmount: Decimal, walletBalance: Decimal?,
            tiers: [Tier], tierTradedAmount: Decimal?, leverage: ClosedRange<Int>?
        ) {
            self.symbol = symbol
            self.maker = maker
            self.taker = taker
            self.standardMaker = standardMaker
            self.standardTaker = standardTaker
            self.mode = mode
            self.joinsDiscount = joinsDiscount
            self.receivesDiscount = receivesDiscount
            self.discountRate = discountRate
            self.joinsDeduction = joinsDeduction
            self.receivesDeduction = receivesDeduction
            self.deductionRate = deductionRate
            self.tradedAmount = tradedAmount
            self.walletBalance = walletBalance
            self.tiers = tiers
            self.tierTradedAmount = tierTradedAmount
            self.leverage = leverage
        }
    }
}

extension MexcFutures.FeeRates {
    /// How MEXC sets the account's fee rates.
    public struct Mode: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        /// MEXC's standard rates.
        public static let normal = Self(rawValue: "NORMAL")
        /// Rates that depend on the leverage.
        public static let leverage = Self(rawValue: "LEVERAGE")
        /// Rates that depend on the traded amount.
        public static let tiered = Self(rawValue: "TIERED")
    }

    /// The rates of one traded-amount tier.
    public struct Tier: Hashable, Sendable {
        public let minimumTradedAmount: Decimal
        /// `nil` for the highest tier.
        public let maximumTradedAmount: Decimal?
        public let maker: Decimal
        public let taker: Decimal
        public let standardMaker: Decimal
        public let standardTaker: Decimal

        public init(
            minimumTradedAmount: Decimal, maximumTradedAmount: Decimal?, maker: Decimal, taker: Decimal,
            standardMaker: Decimal, standardTaker: Decimal
        ) {
            self.minimumTradedAmount = minimumTradedAmount
            self.maximumTradedAmount = maximumTradedAmount
            self.maker = maker
            self.taker = taker
            self.standardMaker = standardMaker
            self.standardTaker = standardTaker
        }
    }
}

// MARK: - Wire

extension MexcFutures.FeeRates: Decodable {
    private enum CodingKeys: String, CodingKey {
        case symbol, realMakerFee, realTakerFee, originalMakerFee, originalTakerFee, feeRateMode, joinDiscount
        case enjoyDiscount, discountRate, joinDeduct, enjoyDeduct, deductRate, dealAmount, walletBalance
        case tieredFeeRates, tieredDealAmount, minLeverage, maxLeverage
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decodeIfPresent(MexcFutures.Symbol.self, forKey: .symbol)
        maker = try container.decimal(forKey: .realMakerFee)
        taker = try container.decimal(forKey: .realTakerFee)
        standardMaker = try container.decimal(forKey: .originalMakerFee)
        standardTaker = try container.decimal(forKey: .originalTakerFee)
        mode = try container.decode(Mode.self, forKey: .feeRateMode)
        joinsDiscount = try container.decode(Bool.self, forKey: .joinDiscount)
        receivesDiscount = try container.decode(Bool.self, forKey: .enjoyDiscount)
        discountRate = try container.decimalIfPresent(forKey: .discountRate)
        joinsDeduction = try container.decode(Bool.self, forKey: .joinDeduct)
        receivesDeduction = try container.decode(Bool.self, forKey: .enjoyDeduct)
        deductionRate = try container.decimalIfPresent(forKey: .deductRate)
        tradedAmount = try container.decimal(forKey: .dealAmount)
        walletBalance = try container.decimalIfPresent(forKey: .walletBalance)
        tiers = try container.decodeIfPresent([Tier].self, forKey: .tieredFeeRates) ?? []
        tierTradedAmount = try container.decimalIfPresent(forKey: .tieredDealAmount)
        let minimumLeverage = try container.decodeIfPresent(Int.self, forKey: .minLeverage)
        let maximumLeverage = try container.decodeIfPresent(Int.self, forKey: .maxLeverage)
        if let minimumLeverage, let maximumLeverage {
            guard minimumLeverage <= maximumLeverage else {
                throw DecodingError.dataCorruptedError(
                    forKey: .maxLeverage, in: container,
                    debugDescription: "maxLeverage \(maximumLeverage) is below minLeverage \(minimumLeverage)"
                )
            }
            leverage = minimumLeverage...maximumLeverage
        } else {
            leverage = nil
        }
    }
}

extension MexcFutures.FeeRates.Tier: Decodable {
    private enum CodingKeys: String, CodingKey {
        case minTieredDealAmount, maxTieredDealAmount, realMakerFee, realTakerFee, makerFeeRate, takerFeeRate
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        minimumTradedAmount = try container.decimal(forKey: .minTieredDealAmount)
        maximumTradedAmount = try container.decimalIfPresent(forKey: .maxTieredDealAmount)
        maker = try container.decimal(forKey: .realMakerFee)
        taker = try container.decimal(forKey: .realTakerFee)
        standardMaker = try container.decimal(forKey: .makerFeeRate)
        standardTaker = try container.decimal(forKey: .takerFeeRate)
    }
}
