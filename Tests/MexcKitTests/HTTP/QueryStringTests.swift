import Testing
@testable import MexcKit

@Suite("Query string")
struct QueryStringTests {
    @Test func `parameters are sorted by name`() {
        let query = QueryString(["symbol": "BTC_USDT", "page_size": "20", "page_num": "1"])
        #expect(query.encoded == "page_num=1&page_size=20&symbol=BTC_USDT")
    }

    @Test func `names sort by bytes, so uppercase comes first`() {
        #expect(QueryString(["b": "1", "a": "2", "Z": "3"]).encoded == "Z=3&a=2&b=1")
    }

    @Test(arguments: [
        ("1,2,3", "1%2C2%2C3"),
        ("a b", "a%20b"),
        ("x+y=z&w", "x%2By%3Dz%26w"),
        ("-._~", "-._~"),
        ("é", "%C3%A9"),
    ])
    func `values are percent-encoded except unreserved characters`(value: String, encoded: String) {
        #expect(QueryString(["v": value]).encoded == "v=\(encoded)")
    }

    @Test func `no parameters give an empty query`() {
        #expect(QueryString([:]).encoded.isEmpty)
    }

    @Test func `comma signing changes only commas`() {
        let query = QueryString(["order_ids": "1,2,3", "note": "a b"])
        #expect(query.signed(.encoded) == "note=a%20b&order_ids=1%2C2%2C3")
        #expect(query.signed(.raw) == "note=a%20b&order_ids=1,2,3")
    }
}
