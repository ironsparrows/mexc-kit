public import Foundation

// MARK: - Model

extension MexcFutures {
    /// A market's prices over one interval.
    public struct Candle: Hashable, Sendable {
        /// When the interval starts.
        public let time: Date
        public let open: Decimal
        public let high: Decimal
        public let low: Decimal
        public let close: Decimal
        /// The volume traded in the interval, in contracts. 0 for index and fair price candles.
        public let volume: Decimal
        /// The value traded in the interval, in the quote asset. 0 for index and fair price candles.
        public let turnover: Decimal

        public init(time: Date, open: Decimal, high: Decimal, low: Decimal, close: Decimal, volume: Decimal, turnover: Decimal) {
            self.time = time
            self.open = open
            self.high = high
            self.low = low
            self.close = close
            self.volume = volume
            self.turnover = turnover
        }
    }
}

extension MexcFutures.Candle {
    /// How long one candle lasts.
    public struct Interval: RawRepresentable, Hashable, Sendable, Codable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let oneMinute = Self(rawValue: "Min1")
        public static let fiveMinutes = Self(rawValue: "Min5")
        public static let fifteenMinutes = Self(rawValue: "Min15")
        public static let thirtyMinutes = Self(rawValue: "Min30")
        public static let oneHour = Self(rawValue: "Min60")
        public static let fourHours = Self(rawValue: "Hour4")
        public static let eightHours = Self(rawValue: "Hour8")
        public static let oneDay = Self(rawValue: "Day1")
        public static let oneWeek = Self(rawValue: "Week1")
        public static let oneMonth = Self(rawValue: "Month1")
    }
}
