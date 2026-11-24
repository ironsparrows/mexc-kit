public import Foundation

// MARK: - Model

extension MexcFutures {
    /// An order to place, built with ``open(_:_:_:volume:leverage:marginMode:takeProfit:stopLoss:externalID:options:)``
    /// or ``close(_:_:_:volume:marginMode:position:externalID:options:)``, which take only what each kind of
    /// order carries.
    ///
    /// Volumes are in contracts. Build prices and volumes with `Decimal(string:)` or integer literals:
    /// a floating-point literal such as `0.1` isn't exact as a `Decimal`.
    ///
    /// MEXC treats an order as placed in hedge mode unless ``Options/positionMode`` says otherwise, so an
    /// account in one-way mode sets it on every order.
    public struct OrderRequest: Hashable, Sendable {
        public let symbol: Symbol
        public let side: OrderSide
        public let pricing: Pricing
        public let volume: Decimal
        /// The leverage; set when opening a position.
        public let leverage: Int?
        public let marginMode: MarginMode
        public let takeProfit: AttachedStop?
        public let stopLoss: AttachedStop?
        /// The app's ID for the order. MEXC doesn't take one on a best-price order: placing one with an
        /// external ID throws ``ClientError/Reason/invalidRequest`` before anything is sent.
        public let externalID: ExternalOrderID?
        /// The position the order applies to.
        public let position: PositionID?
        public let options: Options

        /// Opens a position, or adds to one.
        public static func open(
            _ direction: Direction, _ symbol: Symbol, _ pricing: Pricing, volume: Decimal, leverage: Int,
            marginMode: MarginMode, takeProfit: AttachedStop? = nil, stopLoss: AttachedStop? = nil,
            externalID: ExternalOrderID? = nil, options: Options = .init()
        ) -> Self {
            Self(
                symbol: symbol, side: direction == .long ? .openLong : .openShort, pricing: pricing, volume: volume,
                leverage: leverage, marginMode: marginMode, takeProfit: takeProfit, stopLoss: stopLoss,
                externalID: externalID, position: nil, options: options
            )
        }

        /// Reduces or closes a position; `direction` is the position's.
        public static func close(
            _ direction: Direction, _ symbol: Symbol, _ pricing: Pricing, volume: Decimal, marginMode: MarginMode,
            position: PositionID? = nil, externalID: ExternalOrderID? = nil, options: Options = .init()
        ) -> Self {
            Self(
                symbol: symbol, side: direction == .long ? .closeLong : .closeShort, pricing: pricing, volume: volume,
                leverage: nil, marginMode: marginMode, takeProfit: nil, stopLoss: nil, externalID: externalID,
                position: position, options: options
            )
        }
    }
}

// MARK: - Direction

extension MexcFutures.OrderRequest {
    /// The side of the position an order opens or closes.
    public enum Direction: Hashable, Sendable {
        case long
        case short
    }
}

// MARK: - Pricing

extension MexcFutures.OrderRequest {
    /// How the order is priced and executes.
    public struct Pricing: Hashable, Sendable {
        public let type: MexcFutures.OrderType
        /// The limit price; `nil` for market and best-price orders.
        public let price: Decimal?
        /// The best-price level; `nil` unless the order is a best-price order.
        public let bestPrice: MexcFutures.BestPrice?

        private init(type: MexcFutures.OrderType, price: Decimal?, bestPrice: MexcFutures.BestPrice? = nil) {
            self.type = type
            self.price = price
            self.bestPrice = bestPrice
        }

        public static func limit(price: Decimal) -> Self { Self(type: .limit, price: price) }

        /// A limit order that only adds liquidity (maker only).
        public static func postOnly(price: Decimal) -> Self { Self(type: .postOnly, price: price) }

        public static func immediateOrCancel(price: Decimal) -> Self { Self(type: .immediateOrCancel, price: price) }

        public static func fillOrKill(price: Decimal) -> Self { Self(type: .fillOrKill, price: price) }

        public static let market = Self(type: .market, price: nil)

        /// A limit order priced by MEXC at a level of the order book (BBO).
        public static func bestPrice(_ level: MexcFutures.BestPrice) -> Self {
            Self(type: .limit, price: nil, bestPrice: level)
        }
    }
}

// MARK: - Options

extension MexcFutures.OrderRequest {
    /// The less common settings of an order. Each is left out of the request unless set, so MEXC
    /// applies its default.
    public struct Options: Hashable, Sendable {
        /// Only reduces a position. MEXC applies it in one-way mode only.
        public var reduceOnly: Bool
        /// The account's position mode. MEXC assumes ``MexcFutures/PositionMode/hedge`` when it's
        /// `nil`, so an account in one-way mode sets it on every order.
        public var positionMode: MexcFutures.PositionMode?
        /// MEXC's trigger protection for the attached take-profit and stop-loss.
        public var triggerProtection: Bool
        /// MEXC's "100% market open".
        public var marketCeiling: Bool
        /// MEXC's "flash close".
        public var flashClose: Bool
        public var selfTradePrevention: MexcFutures.SelfTradePreventionMode?

        public init(
            reduceOnly: Bool = false, positionMode: MexcFutures.PositionMode? = nil, triggerProtection: Bool = false,
            marketCeiling: Bool = false, flashClose: Bool = false,
            selfTradePrevention: MexcFutures.SelfTradePreventionMode? = nil
        ) {
            self.reduceOnly = reduceOnly
            self.positionMode = positionMode
            self.triggerProtection = triggerProtection
            self.marketCeiling = marketCeiling
            self.flashClose = flashClose
            self.selfTradePrevention = selfTradePrevention
        }
    }
}
