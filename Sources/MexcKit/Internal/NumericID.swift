/// An ID sent as a JSON number, for request bodies whose documentation types the ID as a `long`.
///
/// IDs are strings in this SDK, since MEXC's responses send them both ways.
struct NumericID: Encodable, Hashable, Sendable {
    let value: Int64

    /// Throws ``MexcFutures/ClientError/Reason/invalidRequest`` when the ID isn't a whole number, which
    /// MEXC never assigns.
    init<ID: RawRepresentable<String>>(_ id: ID) throws {
        guard let value = Int64(id.rawValue) else {
            throw MexcFutures.ClientError(.invalidRequest, message: "Not a numeric ID: \(id.rawValue)")
        }
        self.value = value
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
