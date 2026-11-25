public import Foundation

// MARK: - Model

extension MexcFutures {
    /// The balance of a market's insurance fund at one time.
    public struct InsuranceFund: Hashable, Sendable {
        public let symbol: Symbol
        public let asset: String
        public let balance: Decimal
        public let time: Date

        public init(symbol: Symbol, asset: String, balance: Decimal, time: Date) {
            self.symbol = symbol
            self.asset = asset
            self.balance = balance
            self.time = time
        }
    }
}

// MARK: - Wire

extension MexcFutures.InsuranceFund: Decodable {
    private enum CodingKeys: String, CodingKey {
        case symbol, currency, available, timestamp, snapshotTime
    }

    /// Decodes the current balance, timed by `timestamp`, or a past one, timed by `snapshotTime`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        symbol = try container.decode(MexcFutures.Symbol.self, forKey: .symbol)
        asset = try container.decode(String.self, forKey: .currency)
        balance = try container.decimal(forKey: .available)
        time = try container.contains(.snapshotTime)
            ? container.millisecondDate(forKey: .snapshotTime)
            : container.millisecondDate(forKey: .timestamp)
    }
}
