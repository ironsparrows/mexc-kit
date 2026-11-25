import Foundation
import Testing
@testable import MexcKitCore

@Suite("Flexible coding")
struct FlexibleCodingTests {
    @Test(arguments: [
        // A live insurance-fund balance: 39 significant digits.
        ("119931819.315941628598651062896794110492", "119931819.315941628598651062896794110492"),
        // A live kline volume and a live stream deal price, in exponent form.
        ("2.967133E7", "29671330"),
        ("6.04E+4", "60400"),
        ("0.000018", "0.000018"),
        ("-0.1", "-0.1"),
        ("60487", "60487"),
    ])
    func `a decimal decodes exactly from a JSON number`(json: String, expected: String) throws {
        let decoded = try decode(FlexibleDecimal.self, from: "[\(json)]").value
        #expect("\(decoded)" == expected)
    }

    @Test(arguments: [
        ("\"119931819.315941628598651062896794110492\"", "119931819.315941628598651062896794110492"),
        ("\"60456.3\"", "60456.3"),
        ("\"1e-8\"", "0.00000001"),
        ("\".5\"", "0.5"),
    ])
    func `a decimal decodes exactly from a JSON string`(json: String, expected: String) throws {
        let decoded = try decode(FlexibleDecimal.self, from: "[\(json)]").value
        #expect("\(decoded)" == expected)
    }

    @Test(arguments: [
        "\"1.5x\"", "\"1,5\"", "\" 1\"", "\"\"", "\".\"", "\"1e\"", "\"e5\"", "\"+-1\"", "\"nan\"", "\"1e400\"",
        "\"١٢\"", "true", "null",
    ])
    func `a decimal that isn't a whole number string fails to decode`(json: String) {
        #expect(throws: DecodingError.self) { try decode(FlexibleDecimal.self, from: "[\(json)]") }
    }

    @Test(arguments: [
        ("\"739113577038255616\"", "739113577038255616"),
        // Above 2^53, so a Double would round it.
        ("768116802038827520", "768116802038827520"),
        ("18446744073709551615", "18446744073709551615"),
        ("-42", "-42"),
    ])
    func `a string decodes from a JSON string or integer`(json: String, expected: String) throws {
        #expect(try decode(FlexibleString.self, from: "[\(json)]").value == expected)
    }

    @Test(arguments: ["1.5", "18446744073709551616", "true", "null"])
    func `a string fails to decode from anything else`(json: String) {
        #expect(throws: DecodingError.self) { try decode(FlexibleString.self, from: "[\(json)]") }
    }

    @Test(arguments: ["1795503914418", "\"1795503914418\""])
    func `a millisecond timestamp keeps its milliseconds`(json: String) throws {
        let date = try decode(MillisecondTimestamp.self, from: "[\(json)]").date
        #expect(Int64((date.timeIntervalSince1970 * 1000).rounded()) == 1_795_503_914_418)
    }

    @Test(arguments: ["1795503900", "\"1795503900\""])
    func `a second timestamp is read as seconds`(json: String) throws {
        let date = try decode(SecondTimestamp.self, from: "[\(json)]").date
        #expect(date.timeIntervalSince1970 == 1_795_503_900)
    }

    @Test(arguments: ["\"soon\"", "1.5", "null"])
    func `a timestamp that isn't an integer fails to decode`(json: String) {
        #expect(throws: DecodingError.self) { try decode(MillisecondTimestamp.self, from: "[\(json)]") }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from json: String) throws -> Value {
        let values = try JSONDecoder().decode([Value].self, from: Data(json.utf8))
        return try #require(values.first)
    }
}
