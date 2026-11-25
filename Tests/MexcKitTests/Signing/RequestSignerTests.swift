import Testing
@testable import MexcKit

@Suite("Request signer")
struct RequestSignerTests {
    // Signatures produced by MEXC's official Node.js signer for the same inputs.
    @Test(arguments: [
        ("page_num=1&page_size=20&symbol=BTC_USDT", "637fda6412263a9c9bde77885be3851375651d9ddc5a3828b8971851c0a156a0"),
        (#"{"symbol":"BTC_USDT","price":"0.1","vol":1}"#, "e9a49ab8fdcc79043e5e288e1e9ba22901de14883a6fdfeca6d7400d841da4a8"),
    ])
    func `signatures match MEXC's signer`(parameters: String, expected: String) {
        let signer = RequestSigner(credentials: MexcCredentials(apiKey: "mx0testkey", secret: "testsecret"))
        #expect(signer.signature(requestTime: "1700000000000", parameters: parameters) == expected)
    }
}
