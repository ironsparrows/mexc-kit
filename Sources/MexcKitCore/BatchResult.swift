extension MexcFutures {
    /// The outcome of one item of a batch request, which MEXC accepts as a whole and answers item by
    /// item.
    public struct BatchResult<ID: Hashable & Sendable>: Sendable {
        /// The item's ID; `nil` when MEXC reports none.
        public let id: ID?
        /// Why MEXC refused the item; `nil` when it succeeded.
        public let error: MexcError?

        public var succeeded: Bool { error == nil }

        public init(id: ID?, error: MexcError?) {
            self.id = id
            self.error = error
        }
    }
}
