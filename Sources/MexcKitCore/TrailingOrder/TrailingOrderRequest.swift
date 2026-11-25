public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A trailing order to place, built with
    /// ``open(_:_:volume:leverage:marginMode:callback:activationPrice:source:positionMode:)`` or
    /// ``close(_:_:volume:leverage:marginMode:callback:activationPrice:source:positionMode:reduceOnly:)``.
    ///
    /// Volumes are in contracts. MEXC requires the account's position mode on every trailing order.
    public struct TrailingOrderRequest: Hashable, Sendable {
        public let symbol: Symbol
        public let side: OrderSide
        public let volume: Decimal
        public let leverage: Int
        public let marginMode: MarginMode
        public let callback: TrailingOrder.Callback
        /// MEXC's activation price; `nil` sends none.
        public let activationPrice: Decimal?
        /// The price MEXC follows.
        public let source: PriceSource
        public let positionMode: PositionMode
        /// Only reduces a position.
        public let reduceOnly: Bool

        /// Opens a position, or adds to one, once the price moves back by the callback.
        public static func open(
            _ direction: OrderRequest.Direction, _ symbol: Symbol, volume: Decimal, leverage: Int, marginMode: MarginMode,
            callback: TrailingOrder.Callback, activationPrice: Decimal? = nil, source: PriceSource = .last,
            positionMode: PositionMode
        ) -> Self {
            Self(
                symbol: symbol, side: direction == .long ? .openLong : .openShort, volume: volume, leverage: leverage,
                marginMode: marginMode, callback: callback, activationPrice: activationPrice, source: source,
                positionMode: positionMode, reduceOnly: false
            )
        }

        /// Reduces or closes a position once the price moves back by the callback; `direction` is the
        /// position's. MEXC requires the leverage here too.
        public static func close(
            _ direction: OrderRequest.Direction, _ symbol: Symbol, volume: Decimal, leverage: Int, marginMode: MarginMode,
            callback: TrailingOrder.Callback, activationPrice: Decimal? = nil, source: PriceSource = .last,
            positionMode: PositionMode, reduceOnly: Bool = false
        ) -> Self {
            Self(
                symbol: symbol, side: direction == .long ? .closeLong : .closeShort, volume: volume, leverage: leverage,
                marginMode: marginMode, callback: callback, activationPrice: activationPrice, source: source,
                positionMode: positionMode, reduceOnly: reduceOnly
            )
        }
    }
}
