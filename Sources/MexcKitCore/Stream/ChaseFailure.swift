// MARK: - Model

extension MexcFutures {
    /// MEXC's report that chasing an order failed.
    ///
    /// The report names the market and the error, not the order.
    public struct ChaseFailure: Hashable, Sendable {
        public let symbol: Symbol
        /// Why chasing failed. MEXC's documentation calls it an error code, without saying which
        /// table; its example sends 1001.
        public let errorCode: MexcError.Code

        public init(symbol: Symbol, errorCode: MexcError.Code) {
            self.symbol = symbol
            self.errorCode = errorCode
        }
    }
}
