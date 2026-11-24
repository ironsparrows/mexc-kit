public import Foundation

/// A failure MEXC reported in its response.
///
/// MEXC can report a failure with HTTP status 200, so check ``code``, not ``httpStatus``, to tell
/// failures apart. ``description`` leaves out ``body``, which can hold balances and positions.
///
/// `localizedDescription` is MEXC's message. When the response has none, it is the message MEXC's
/// futures documentation gives for the code, or ``description`` for a code it doesn't list.
/// `recoverySuggestion` is the documentation's explanation of the code.
public struct MexcError: Error, Sendable, CustomStringConvertible {
    public var code: Code
    /// The message in MEXC's response.
    public var message: String?
    public var httpStatus: Int?
    /// The raw response body, for diagnostics.
    public var body: Data?

    public init(code: Code, message: String? = nil, httpStatus: Int? = nil, body: Data? = nil) {
        self.code = code
        self.message = message
        self.httpStatus = httpStatus
        self.body = body
    }

    public var description: String {
        var text = "MEXC error \(code.rawValue)"
        if let httpStatus { text += " (HTTP \(httpStatus))" }
        if let message, !message.isEmpty { text += ": \(message)" }
        return text
    }
}

extension MexcError: LocalizedError {
    public var errorDescription: String? {
        if let message, !message.isEmpty { return message }
        return code.futuresDocumentation?.readableMessage ?? description
    }

    public var recoverySuggestion: String? { code.futuresDocumentation?.details }
}

extension MexcError {
    /// A MEXC error code.
    ///
    /// The codes apps most often act on have members. Every other code MEXC sends is still
    /// available as ``rawValue``, and every documented one still has its text in the error's
    /// `localizedDescription` and `recoverySuggestion`.
    public struct Code: RawRepresentable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        // MARK: Access

        /// Not logged in, or the login expired.
        public static let notLoggedIn = Self(rawValue: 401)
        public static let apiKeyExpired = Self(rawValue: 402)
        /// The request's IP address isn't on the API key's whitelist.
        public static let ipNotWhitelisted = Self(rawValue: 406)
        /// The API key may lack permission for this endpoint, or the endpoint isn't available to the
        /// account.
        public static let noPermission = Self(rawValue: 511)
        public static let signatureFailed = Self(rawValue: 602)
        public static let readPermissionRequired = Self(rawValue: 701)
        public static let writePermissionRequired = Self(rawValue: 702)
        /// The API key needs MEXC's "trading information" read access.
        public static let tradingInfoReadPermissionRequired = Self(rawValue: 703)
        /// The API key needs MEXC's "trading information" write access.
        public static let tradingInfoWritePermissionRequired = Self(rawValue: 704)
        public static let tradingForbidden = Self(rawValue: 6001)

        // MARK: Availability and rate limits

        /// An internal error. Before retrying a request that changes something, check whether it
        /// took effect.
        public static let internalError = Self(rawValue: 500)
        public static let busy = Self(rawValue: 501)
        public static let tooFrequent = Self(rawValue: 510)
        public static let tradingTooFrequent = Self(rawValue: 2037)
        public static let dailyOrderLimitReached = Self(rawValue: 2036)

        // MARK: Parameters

        public static let invalidParameter = Self(rawValue: 600)
        /// An amount or quantity is invalid.
        public static let invalidAmount = Self(rawValue: 1004)
        public static let invalidTimeRange = Self(rawValue: 6003)
        public static let unsupportedCurrency = Self(rawValue: 4001)

        // MARK: Contracts

        public static let contractNotFound = Self(rawValue: 1001)
        public static let contractNotActivated = Self(rawValue: 1002)
        public static let contractUnavailable = Self(rawValue: 6005)

        // MARK: Orders

        public static let invalidOrderSide = Self(rawValue: 2001)
        public static let invalidOrderType = Self(rawValue: 2029)
        public static let invalidPrice = Self(rawValue: 2007)
        public static let invalidVolume = Self(rawValue: 2011)
        /// The price or volume doesn't match the contract's precision.
        public static let invalidPrecision = Self(rawValue: 2015)
        public static let sellPriceBelowMinimum = Self(rawValue: 2004)
        public static let priceBelowLiquidationPrice = Self(rawValue: 2032)
        public static let priceAboveLiquidationPrice = Self(rawValue: 2033)
        public static let volumeTooLarge = Self(rawValue: 2028)
        public static let insufficientBalance = Self(rawValue: 2005)
        /// An ``MexcFutures/ExternalOrderID`` is longer than 32 characters.
        public static let externalOrderIDTooLong = Self(rawValue: 2030)
        public static let orderNotFound = Self(rawValue: 2040)
        /// The order's state doesn't allow canceling it.
        public static let orderNotCancellable = Self(rawValue: 2041)
        public static let tooManyCancellations = Self(rawValue: 2013)
        public static let batchTooLarge = Self(rawValue: 2014)
        public static let batchQueryTooLarge = Self(rawValue: 2034)

        // MARK: Positions

        public static let positionNotFound = Self(rawValue: 2009)
        /// The order would close more than the position's closable volume.
        public static let closeVolumeTooLarge = Self(rawValue: 2008)
        public static let leverageOutOfRange = Self(rawValue: 2006)
        /// The margin to remove is more than the position allows.
        public static let marginReductionTooLarge = Self(rawValue: 2018)
        /// The position is already larger than the risk limit allows for a new order.
        public static let positionAboveRiskLimit = Self(rawValue: 2025)
        /// The current risk limit's maximum position is exceeded.
        public static let riskLimitExceeded = Self(rawValue: 2031)
        /// The maximum position size for the current leverage tier is reached.
        public static let leverageTierLimitReached = Self(rawValue: 2038)

        // MARK: Plan and stop orders

        /// The trigger's ``MexcFutures/PriceSource`` is invalid.
        public static let invalidTriggerPriceSource = Self(rawValue: 3001)
        /// The trigger's ``MexcFutures/TriggerCondition`` is invalid.
        public static let invalidTriggerCondition = Self(rawValue: 3002)
        public static let invalidTriggerPrice = Self(rawValue: 3004)
        /// Neither a take-profit nor a stop-loss price was given.
        public static let missingStopPrices = Self(rawValue: 5001)
        public static let stopOrderNotFound = Self(rawValue: 5002)
        public static let invalidStopOrderPrice = Self(rawValue: 5003)
        /// The stop order's volume is more than the position can close.
        public static let stopOrderVolumeTooLarge = Self(rawValue: 5004)
    }
}
