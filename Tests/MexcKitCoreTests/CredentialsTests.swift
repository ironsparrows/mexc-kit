import MexcKitCore
import Testing

extension MexcKitCoreTests {
    @Suite("Credentials")
    struct CredentialsTests {
        private let credentials = MexcCredentials(apiKey: "mx0testkey", secret: "testsecret")

        @Test func `printing credentials never shows the key or the secret`() {
            var dumped = ""
            dump(credentials, to: &dumped)
            for text in ["\(credentials)", String(reflecting: credentials), dumped] {
                #expect(!text.contains("testsecret"))
                #expect(!text.contains("mx0testkey"))
            }
        }
    }
}
