import Foundation
package import MexcKitCore
package import Testing

// Live tests run when an API key and its secret are set, in the environment (`MEXC_API_KEY`,
// `MEXC_API_SECRET`) or in `LocalLiveTestSettings.swift` beside this file: a gitignored file only a
// contributor creates, so Xcode runs need no environment variables. Without that file, the
// protocol's defaults below are empty and the package still builds.

/// Whether live tests run: an API key and its secret are set.
package var areLiveTestsEnabled: Bool { LiveTestSettings.credentials != nil }

/// The settings live tests read.
package enum LiveTestSettings {
    /// The API key and secret: both from the environment when both are set there, else both from
    /// the local file when both are set there, else `nil`.
    package static let credentials: MexcCredentials? = {
        let environment = ProcessInfo.processInfo.environment
        if let apiKey = environment["MEXC_API_KEY"], !apiKey.isEmpty,
            let secret = environment["MEXC_API_SECRET"], !secret.isEmpty
        {
            return MexcCredentials(apiKey: apiKey, secret: secret)
        }
        if !LocalLiveTestSettings.apiKey.isEmpty, !LocalLiveTestSettings.secret.isEmpty {
            return MexcCredentials(apiKey: LocalLiveTestSettings.apiKey, secret: LocalLiveTestSettings.secret)
        }
        return nil
    }()
}

/// What the local file sets. Its defaults are empty.
protocol LocalLiveTestValues {
    static var apiKey: String { get }
    static var secret: String { get }
}

extension LocalLiveTestValues {
    static var apiKey: String { "" }
    static var secret: String { "" }
}

/// The local settings. `LocalLiveTestSettings.swift`, when present, gives this type its own
/// `static let apiKey` and `static let secret`, which replace the empty defaults.
enum LocalLiveTestSettings: LocalLiveTestValues {}

extension Tag {
    /// Tests that call MEXC's live servers.
    @Tag package static var live: Self
}
