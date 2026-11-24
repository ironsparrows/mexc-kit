// swift-tools-version: 6.4

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "mexc-kit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "MexcKit", targets: ["MexcKit"]),
        .library(name: "MexcKitCore", targets: ["MexcKitCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"6.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.100.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.37.1"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.16.2"),
    ],
    targets: [
        .target(
            name: "MexcKitCore",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "MexcKit",
            dependencies: [
                "MexcKitCore",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "MexcKitCoreTests",
            dependencies: ["MexcKitCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "MexcKitTests",
            dependencies: [
                "MexcKit",
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ],
            resources: [.copy("Fixtures")],
            swiftSettings: swiftSettings
        ),
    ]
)
