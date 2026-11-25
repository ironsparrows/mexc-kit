public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A plan order to place: an order MEXC places once its trigger price is reached. Built with
    /// ``open(_:_:_:volume:leverage:marginMode:trigger:lifetime:takeProfit:stopLoss:options:)`` or
    /// ``close(_:_:_:volume:marginMode:trigger:lifetime:options:)``.
    ///
    /// Volumes are in contracts. MEXC doesn't take a best price on a plan order: placing one with
    /// ``OrderRequest/Pricing/bestPrice(_:)`` throws ``ClientError/Reason/invalidRequest`` before anything
    /// is sent.
    public struct PlanOrderRequest: Hashable, Sendable {
        public let symbol: Symbol
        public let side: OrderSide
        /// The order placed when the trigger is reached.
        public let pricing: OrderRequest.Pricing
        public let volume: Decimal
        /// The leverage; set when opening a position.
        public let leverage: Int?
        public let marginMode: MarginMode
        public let trigger: Trigger
        public let lifetime: Lifetime
        public let takeProfit: AttachedStop?
        public let stopLoss: AttachedStop?
        public let options: Options

        /// Opens a position, or adds to one, once the trigger is reached.
        public static func open(
            _ direction: OrderRequest.Direction, _ symbol: Symbol, _ pricing: OrderRequest.Pricing, volume: Decimal,
            leverage: Int, marginMode: MarginMode, trigger: Trigger, lifetime: Lifetime,
            takeProfit: AttachedStop? = nil, stopLoss: AttachedStop? = nil, options: Options = .init()
        ) -> Self {
            Self(
                symbol: symbol, side: direction == .long ? .openLong : .openShort, pricing: pricing, volume: volume,
                leverage: leverage, marginMode: marginMode, trigger: trigger, lifetime: lifetime, takeProfit: takeProfit,
                stopLoss: stopLoss, options: options
            )
        }

        /// Reduces or closes a position once the trigger is reached; `direction` is the position's.
        public static func close(
            _ direction: OrderRequest.Direction, _ symbol: Symbol, _ pricing: OrderRequest.Pricing, volume: Decimal,
            marginMode: MarginMode, trigger: Trigger, lifetime: Lifetime, options: Options = .init()
        ) -> Self {
            Self(
                symbol: symbol, side: direction == .long ? .closeLong : .closeShort, pricing: pricing, volume: volume,
                leverage: nil, marginMode: marginMode, trigger: trigger, lifetime: lifetime, takeProfit: nil,
                stopLoss: nil, options: options
            )
        }
    }
}

// MARK: - Lifetime

extension MexcFutures.PlanOrderRequest {
    /// How long MEXC keeps a plan order waiting for its trigger.
    public struct Lifetime: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let oneDay = Self(rawValue: 1)
        public static let sevenDays = Self(rawValue: 2)
    }
}

// MARK: - Options

extension MexcFutures.PlanOrderRequest {
    /// The less common settings of a plan order. Each is left out of the request unless set, so MEXC
    /// applies its default.
    public struct Options: Hashable, Sendable {
        /// Only reduces a position.
        public var reduceOnly: Bool
        /// The account's position mode.
        public var positionMode: MexcFutures.PositionMode?
        /// MEXC's trigger protection.
        public var triggerProtection: Bool

        public init(
            reduceOnly: Bool = false, positionMode: MexcFutures.PositionMode? = nil, triggerProtection: Bool = false
        ) {
            self.reduceOnly = reduceOnly
            self.positionMode = positionMode
            self.triggerProtection = triggerProtection
        }
    }
}
