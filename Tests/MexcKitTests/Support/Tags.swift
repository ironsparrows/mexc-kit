import Foundation
import Testing

extension Tag {
    /// Tests against MEXC's production servers. They run only when `MEXC_LIVE=1` is set.
    @Tag static var live: Self
}

extension Trait where Self == ConditionTrait {
    /// Skips the test unless `MEXC_LIVE=1` is set.
    static var liveServersEnabled: Self {
        .enabled("Set MEXC_LIVE=1 to run tests against MEXC's servers") {
            ProcessInfo.processInfo.environment["MEXC_LIVE"] == "1"
        }
    }
}
