// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrackpadIOSCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TrackpadIOSCore",
            targets: ["TrackpadIOSCore"]
        ),
    ],
    dependencies: [
        .package(path: "../../../packages/TrackpadKit"),
    ],
    targets: [
        .target(
            name: "TrackpadIOSCore",
            dependencies: [
                .product(name: "TrackpadKit", package: "TrackpadKit"),
            ]
        ),
        .testTarget(
            name: "TrackpadIOSCoreTests",
            dependencies: ["TrackpadIOSCore"]
        ),
    ]
)
