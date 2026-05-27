// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrackpadHost",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "TrackpadHost",
            targets: ["TrackpadHost"]
        ),
        .library(
            name: "TrackpadHostCore",
            targets: ["TrackpadHostCore"]
        ),
    ],
    dependencies: [
        .package(path: "../../../packages/TrackpadKit"),
    ],
    targets: [
        .executableTarget(
            name: "TrackpadHost",
            dependencies: ["TrackpadHostCore"]
        ),
        .target(
            name: "TrackpadHostCore",
            dependencies: ["TrackpadKit"]
        ),
        .testTarget(
            name: "TrackpadHostCoreTests",
            dependencies: ["TrackpadHostCore"]
        ),
    ]
)
