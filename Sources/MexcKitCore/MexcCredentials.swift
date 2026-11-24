/// An API key and its secret, which sign private requests.
///
/// Neither the key nor the secret appears in ``description``, `String(reflecting:)` or `dump(_:)`.
public struct MexcCredentials: Sendable, CustomStringConvertible, CustomReflectable {
    public var apiKey: String
    public var secret: String

    public init(apiKey: String, secret: String) {
        self.apiKey = apiKey
        self.secret = secret
    }

    public var description: String { "MexcCredentials(apiKey: <redacted>, secret: <redacted>)" }

    public var customMirror: Mirror {
        Mirror(self, children: ["apiKey": "<redacted>", "secret": "<redacted>"], displayStyle: .struct)
    }
}
