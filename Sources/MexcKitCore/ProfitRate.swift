public import Foundation

// MARK: - Model

extension MexcFutures {
    /// The account's profit rate over a day or a week.
    public struct ProfitRate: Hashable, Sendable {
        /// The rate, as MEXC reports it.
        public let rate: Decimal
        /// MEXC's "statistic time".
        public let time: Date

        public init(rate: Decimal, time: Date) {
            self.rate = rate
            self.time = time
        }
    }
}

// MARK: - Wire

extension MexcFutures.ProfitRate: Decodable {
    private enum CodingKeys: String, CodingKey {
        case profitRate, statisticTime
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rate = try container.decimal(forKey: .profitRate)
        time = try container.millisecondDate(forKey: .statisticTime)
    }
}
