// Each vocabulary is a struct with static members, not an enum, so a value MEXC adds later still
// decodes, keeps its raw value and encodes back unchanged.

// MARK: - Orders

extension MexcFutures {
    /// How an order executes.
    public struct OrderType: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let limit = Self(rawValue: 1)
        /// A limit order that only adds liquidity (maker only).
        public static let postOnly = Self(rawValue: 2)
        public static let immediateOrCancel = Self(rawValue: 3)
        public static let fillOrKill = Self(rawValue: 4)
        public static let market = Self(rawValue: 5)
        /// Market-to-limit. Seen on order updates; not among the types offered when placing an order.
        public static let marketToLimit = Self(rawValue: 6)
    }

    /// What an order does to a position: open or close, long or short.
    public struct OrderSide: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let openLong = Self(rawValue: 1)
        public static let closeShort = Self(rawValue: 2)
        public static let openShort = Self(rawValue: 3)
        public static let closeLong = Self(rawValue: 4)
    }

    /// An order's lifecycle state.
    ///
    /// ``pending`` and ``open`` are both pending orders: not yet final.
    public struct OrderState: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        /// MEXC's state 1, "pending".
        public static let pending = Self(rawValue: 1)
        /// MEXC's state 2, "unfilled" or "open".
        public static let open = Self(rawValue: 2)
        public static let filled = Self(rawValue: 3)
        public static let canceled = Self(rawValue: 4)
        public static let invalid = Self(rawValue: 5)
    }

    /// How an order came about. Names follow MEXC's categories.
    public struct OrderCategory: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let limit = Self(rawValue: 1)
        public static let liquidationCustody = Self(rawValue: 2)
        public static let custodyClose = Self(rawValue: 3)
        /// MEXC's "ADL reduction".
        public static let autoDeleveraging = Self(rawValue: 4)
        /// MEXC's "delivery order".
        public static let delivery = Self(rawValue: 5)
        /// MEXC's "forced liquidation hedge".
        public static let liquidationHedge = Self(rawValue: 6)
    }

    /// Why MEXC rejected or ended an order, as reported on order updates.
    ///
    /// The names follow MEXC's `errorCode` enum; `.other` is MEXC's catch-all.
    public struct OrderErrorCode: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let normal = Self(rawValue: 0)
        public static let invalidParameter = Self(rawValue: 1)
        public static let insufficientBalance = Self(rawValue: 2)
        public static let positionNotFound = Self(rawValue: 3)
        public static let insufficientPosition = Self(rawValue: 4)
        public static let positionLiquidated = Self(rawValue: 5)
        public static let orderLiquidated = Self(rawValue: 6)
        public static let riskLevelLimit = Self(rawValue: 7)
        public static let canceledBySystem = Self(rawValue: 8)
        public static let positionModeMismatch = Self(rawValue: 9)
        public static let reduceOnlyLiquidated = Self(rawValue: 10)
        public static let contractNotEnabled = Self(rawValue: 11)
        public static let canceledForDelivery = Self(rawValue: 12)
        public static let canceledForPositionLiquidation = Self(rawValue: 13)
        public static let canceledForAutoDeleveraging = Self(rawValue: 14)
        /// MEXC's `BLACK_USER_CANCEL`.
        public static let canceledForBlacklistedUser = Self(rawValue: 15)
        public static let canceledForFundingSettlement = Self(rawValue: 16)
        /// MEXC's `POSITION_IM_CHANGE_CANCEL`.
        public static let canceledForInitialMarginChange = Self(rawValue: 17)
        public static let canceledImmediateOrCancel = Self(rawValue: 18)
        public static let canceledFillOrKill = Self(rawValue: 19)
        public static let canceledPostOnly = Self(rawValue: 20)
        public static let canceledMarket = Self(rawValue: 21)
        /// MEXC's `OID_DUPLICATE`.
        public static let duplicateOrderID = Self(rawValue: 22)
        /// MEXC's `CID_DUPLICATE`.
        public static let duplicateClientOrderID = Self(rawValue: 23)
        public static let other = Self(rawValue: 999)
    }

    /// The kind of best-price (BBO) order, named after MEXC's opposite-1, opposite-5, same-side-1 and
    /// same-side-5.
    ///
    /// MEXC uses 0 for an order that isn't a best-price order; it has no member here.
    public struct BestPrice: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let opposite1 = Self(rawValue: 1)
        public static let opposite5 = Self(rawValue: 2)
        public static let sameSide1 = Self(rawValue: 3)
        public static let sameSide5 = Self(rawValue: 4)
    }

    /// What MEXC does when an order would trade with another order of the same account or group.
    public struct SelfTradePreventionMode: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        /// No self-trade prevention.
        public static let off = Self(rawValue: 0)
        public static let cancelBoth = Self(rawValue: 1)
        public static let cancelMaker = Self(rawValue: 2)
        public static let cancelTaker = Self(rawValue: 3)
    }
}

// MARK: - Positions

extension MexcFutures {
    /// The direction of a position.
    public struct PositionSide: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let long = Self(rawValue: 1)
        public static let short = Self(rawValue: 2)
    }

    /// Whether a position's margin is its own or shared with the account.
    public struct MarginMode: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let isolated = Self(rawValue: 1)
        public static let cross = Self(rawValue: 2)
    }

    /// Whether a contract can hold a long and a short position at once.
    public struct PositionMode: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let hedge = Self(rawValue: 1)
        public static let oneWay = Self(rawValue: 2)
    }

    /// MEXC's leverage mode, which its documentation names without describing.
    public struct LeverageMode: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let advanced = Self(rawValue: 1)
        public static let simple = Self(rawValue: 2)
    }

    /// A position's lifecycle state.
    public struct PositionState: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let holding = Self(rawValue: 1)
        /// MEXC's "system-held".
        public static let systemHeld = Self(rawValue: 2)
        public static let closed = Self(rawValue: 3)
    }
}

// MARK: - Triggers

extension MexcFutures {
    /// Which price a trigger or a take-profit and stop-loss watches.
    public struct PriceSource: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        /// The last traded price.
        public static let last = Self(rawValue: 1)
        public static let fair = Self(rawValue: 2)
        public static let index = Self(rawValue: 3)
    }

    /// When a plan order triggers, compared with its trigger price.
    public struct TriggerCondition: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let atOrAbove = Self(rawValue: 1)
        public static let atOrBelow = Self(rawValue: 2)
    }

    /// A plan order's lifecycle state.
    public struct PlanOrderState: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let untriggered = Self(rawValue: 1)
        public static let canceled = Self(rawValue: 2)
        public static let executed = Self(rawValue: 3)
        public static let invalid = Self(rawValue: 4)
        /// MEXC's "execution failed".
        public static let failed = Self(rawValue: 5)
    }

    /// A trailing order's lifecycle state.
    public struct TrailingOrderState: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        /// Not activated yet.
        public static let inactive = Self(rawValue: 0)
        public static let active = Self(rawValue: 1)
        /// MEXC's "triggered successfully", also called "executed successfully".
        public static let triggered = Self(rawValue: 2)
        /// MEXC's "trigger failed", also called "execution failed".
        public static let failed = Self(rawValue: 3)
        public static let canceled = Self(rawValue: 4)
    }
}

// MARK: - Account

extension MexcFutures {
    /// The state of an asset transfer.
    public struct TransferState: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let waiting = Self(rawValue: "WAIT")
        public static let succeeded = Self(rawValue: "SUCCESS")
        public static let failed = Self(rawValue: "FAILED")
    }

    /// Whether a transfer moved an asset into the futures account or out of it.
    public struct TransferDirection: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        /// Into the futures account.
        public static let incoming = Self(rawValue: "IN")
        /// Out of the futures account.
        public static let outgoing = Self(rawValue: "OUT")
    }

    /// The period a profit rate covers.
    public struct ProfitRatePeriod: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let day = Self(rawValue: 1)
        public static let week = Self(rawValue: 2)
    }
}
