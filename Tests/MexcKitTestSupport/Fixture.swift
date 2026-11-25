package import Foundation
package import Testing

/// Responses and pushes recorded from MEXC, in `Fixtures`: each domain's REST responses in a folder
/// of their own, and the streams' binary `ContractWrapper` frames in `Stream`.
package enum Fixture {
    /// A recorded REST response, such as `"Market/ticker"` for `Fixtures/Market/ticker.json`.
    package static func response(_ name: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> Data {
        try contents(of: name, withExtension: "json", sourceLocation: sourceLocation)
    }

    /// A recorded push, such as `"push.deal.ETH_USDT"` for `Fixtures/Stream/push.deal.ETH_USDT.bin`.
    package static func push(_ name: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> Data {
        try contents(of: "Stream/" + name, withExtension: "bin", sourceLocation: sourceLocation)
    }

    private static func contents(
        of name: String, withExtension fileExtension: String, sourceLocation: SourceLocation
    ) throws -> Data {
        let path = "Fixtures/" + name
        let url = try #require(
            Bundle.module.url(
                forResource: (path as NSString).lastPathComponent, withExtension: fileExtension,
                subdirectory: (path as NSString).deletingLastPathComponent
            ),
            "No fixture \(path).\(fileExtension)",
            sourceLocation: sourceLocation
        )
        return try Data(contentsOf: url)
    }
}
