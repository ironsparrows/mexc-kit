import Foundation

// Reading the values of a Protobuf push. Protobuf leaves a missing value empty or 0, or, for a field
// marked `optional`, reports it absent; a value a model needs throws `DecodingError` when it's
// missing, as a JSON response's would.

/// A string Protobuf sends, which a missing value leaves empty.
func required(_ text: String, _ field: String) throws -> String {
    guard !text.isEmpty else { throw DecodingError.missing(field) }
    return text
}

/// A number Protobuf sends without `optional`, which a missing value leaves 0.
func requiredNonZero<Number: BinaryInteger>(_ number: Number, _ field: String) throws -> Int {
    guard number != 0 else { throw DecodingError.missing(field) }
    return Int(number)
}

/// A value Protobuf marks `optional`, which must be there.
func required<Value>(_ isPresent: Bool, _ value: Value, _ field: String) throws -> Value {
    guard isPresent else { throw DecodingError.missing(field) }
    return value
}

extension DecodingError {
    static func missing(_ field: String) -> Self {
        .dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "A push is missing its \(field)"))
    }
}

extension Decimal {
    /// A decimal Protobuf sends as a string, such as `"60391.6"`.
    static func stream(_ text: String, _ field: String) throws -> Decimal {
        guard let value = Decimal(string: text) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "\(field) isn't a decimal: \"\(text)\"")
            )
        }
        return value
    }

    /// A decimal Protobuf sends as a string, or `nil` when the string is empty.
    static func streamIfPresent(_ text: String, _ field: String) throws -> Decimal? {
        text.isEmpty ? nil : try stream(text, field)
    }
}

extension Date {
    init(milliseconds: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }

    /// A time Protobuf sends in milliseconds, which a missing value leaves 0.
    static func stream(_ milliseconds: Int64, _ field: String) throws -> Date {
        guard milliseconds != 0 else { throw DecodingError.missing(field) }
        return Date(milliseconds: milliseconds)
    }

    /// A time Protobuf sends in milliseconds, or `nil` when it's 0.
    static func streamIfPresent(_ milliseconds: Int64) -> Date? {
        milliseconds == 0 ? nil : Date(milliseconds: milliseconds)
    }
}

/// An ID Protobuf sends as a string, or `nil` when it's empty or 0, MEXC's way of naming none.
func optionalID(_ text: String) -> String? {
    text.isEmpty || text == "0" ? nil : text
}
