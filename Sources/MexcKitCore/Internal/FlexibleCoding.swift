package import Foundation

// MEXC sends one field as a JSON number in one response and as a string in another, and uses
// milliseconds for most timestamps but seconds for candles. Wire types decode such fields through
// these values instead of the plain types.

/// A decimal sent as a JSON number or as a string, decoded without passing through `Double`.
struct FlexibleDecimal: Decodable {
    let value: Decimal

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Decimal.self) {
            value = number
            return
        }
        let text = try container.decode(String.self)
        guard let parsed = Self.parse(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a decimal number: \(text)")
        }
        value = parsed
    }

    /// Parses a whole string as a decimal number. `Decimal(string:)` alone accepts a valid prefix
    /// (`"1.5x"` is 1.5, `"1,5"` is 1), so the string is checked first.
    static func parse(_ text: String) -> Decimal? {
        guard isDecimalNumber(text.utf8),
            let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
            !value.isNaN
        else { return nil }
        return value
    }

    /// Whether the bytes are `[+-]digits[.digits][(e|E)[+-]digits]`, with digits on at least one side
    /// of the point.
    private static func isDecimalNumber(_ bytes: String.UTF8View) -> Bool {
        var index = bytes.startIndex
        func skip(_ accepted: (UInt8) -> Bool) -> Int {
            var count = 0
            while index != bytes.endIndex, accepted(bytes[index]) {
                index = bytes.index(after: index)
                count += 1
            }
            return count
        }
        let isDigit: (UInt8) -> Bool = { $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }
        let isSign: (UInt8) -> Bool = { $0 == UInt8(ascii: "+") || $0 == UInt8(ascii: "-") }

        if index != bytes.endIndex, isSign(bytes[index]) { index = bytes.index(after: index) }
        var digits = skip(isDigit)
        if index != bytes.endIndex, bytes[index] == UInt8(ascii: ".") {
            index = bytes.index(after: index)
            digits += skip(isDigit)
        }
        guard digits > 0 else { return false }
        if index != bytes.endIndex, bytes[index] == UInt8(ascii: "e") || bytes[index] == UInt8(ascii: "E") {
            index = bytes.index(after: index)
            if index != bytes.endIndex, isSign(bytes[index]) { index = bytes.index(after: index) }
            guard skip(isDigit) > 0 else { return false }
        }
        return index == bytes.endIndex
    }
}

/// A string sent as a JSON string or as a JSON integer, such as an ID.
struct FlexibleString: Decodable {
    let value: String

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            value = text
        } else if let number = try? container.decode(Int64.self) {
            value = String(number)
        } else {
            value = String(try container.decode(UInt64.self))
        }
    }
}

/// A point in time sent as whole milliseconds since 1970, as a JSON integer or a string.
package struct MillisecondTimestamp: Decodable, Sendable {
    package let date: Date

    package init(from decoder: any Decoder) throws {
        let milliseconds = try decodeInteger(from: decoder)
        date = Date(timeIntervalSince1970: Double(milliseconds) / 1000)
    }
}

/// A point in time sent as whole seconds since 1970, as a JSON integer or a string.
package struct SecondTimestamp: Decodable, Sendable {
    package let date: Date

    package init(from decoder: any Decoder) throws {
        date = Date(timeIntervalSince1970: Double(try decodeInteger(from: decoder)))
    }
}

private func decodeInteger(from decoder: any Decoder) throws -> Int64 {
    let container = try decoder.singleValueContainer()
    if let number = try? container.decode(Int64.self) { return number }
    let text = try container.decode(String.self)
    guard let number = Int64(text) else {
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an integer: \(text)")
    }
    return number
}

extension KeyedDecodingContainer {
    func decimal(forKey key: Key) throws -> Decimal {
        try decode(FlexibleDecimal.self, forKey: key).value
    }

    func decimalIfPresent(forKey key: Key) throws -> Decimal? {
        try decodeIfPresent(FlexibleDecimal.self, forKey: key)?.value
    }

    func millisecondDate(forKey key: Key) throws -> Date {
        try decode(MillisecondTimestamp.self, forKey: key).date
    }

    func millisecondDateIfPresent(forKey key: Key) throws -> Date? {
        try decodeIfPresent(MillisecondTimestamp.self, forKey: key)?.date
    }
}
