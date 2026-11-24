import Foundation
import Testing

/// Every Swift example in the README and the DocC articles appears, line for line and in order, in
/// one function of `DocumentationExamples.swift`, which the build compiles. Blank lines and
/// `import` lines don't count, and neither do package manifest lines such as `.package(path:)`.
@Suite("Documentation examples")
struct DocumentationExampleTests {
    private static let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()

    @Test(arguments: [
        "README.md", "Sources/MexcKit/MexcKit.docc/MexcKit.md", "Sources/MexcKit/MexcKit.docc/GettingStarted.md",
    ])
    func `each example matches compiled code`(document: String) throws {
        let examples = Self.swiftBlocks(in: try String(contentsOf: Self.root.appending(path: document), encoding: .utf8))
        #expect(!examples.isEmpty)
        let bodies = try Self.functionBodies()
        for example in examples {
            #expect(
                bodies.contains { Self.contains($0, example) },
                "Not in DocumentationExamples.swift:\n\(example.joined(separator: "\n"))"
            )
        }
    }

    /// The lines of each ```swift block, without blank and `import` lines, leaving out manifest
    /// fragments.
    private static func swiftBlocks(in text: String) -> [[String]] {
        var blocks: [[String]] = []
        var block: [String]?
        for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if block == nil, line == "```swift" {
                block = []
            } else if let lines = block, line == "```" {
                if let first = lines.first, !first.hasPrefix(".package("), !first.hasPrefix(".product(") {
                    blocks.append(lines)
                }
                block = nil
            } else if block != nil, !line.trimmingCharacters(in: .whitespaces).isEmpty, !line.hasPrefix("import ") {
                block?.append(line)
            }
        }
        return blocks
    }

    /// The non-blank lines of each `static func` in `DocumentationExamples.swift`, unindented to the
    /// function body's level.
    private static func functionBodies() throws -> [[String]] {
        let url = root.appending(path: "Tests/MexcKitTests/DocumentationExamples.swift")
        var bodies: [[String]] = []
        var body: [String]?
        for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init) {
            if line.hasPrefix("    static func ") {
                body = []
            } else if body != nil, line == "    }" {
                bodies.append(body ?? [])
                body = nil
            } else if body != nil, !line.trimmingCharacters(in: .whitespaces).isEmpty {
                body?.append(String(line.dropFirst(8)))
            }
        }
        return bodies
    }

    /// Whether `lines` appears in `body` as consecutive lines.
    private static func contains(_ body: [String], _ lines: [String]) -> Bool {
        guard lines.count <= body.count else { return false }
        return (0...(body.count - lines.count)).contains { Array(body[$0..<($0 + lines.count)]) == lines }
    }
}
