public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A take-profit or stop-loss price carried by an order, and the price that triggers it.
    public struct AttachedStop: Hashable, Sendable {
        public let price: Decimal
        /// The price MEXC compares with ``price``. MEXC's default is ``PriceSource/last``.
        public let source: PriceSource

        public init(price: Decimal, source: PriceSource = .last) {
            self.price = price
            self.source = source
        }
    }
}

// MARK: - Wire

extension KeyedDecodingContainer {
    /// A take-profit or stop-loss: `nil` when its price is missing or 0, and watching the last price
    /// unless `source` says otherwise.
    func attachedStop(price priceKey: Key, source sourceKey: Key) throws -> MexcFutures.AttachedStop? {
        guard let price = try decimalIfPresent(forKey: priceKey), price != 0 else { return nil }
        let source = try decodeIfPresent(MexcFutures.PriceSource.self, forKey: sourceKey)
        return MexcFutures.AttachedStop(price: price, source: source ?? .last)
    }
}
