// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TrackpadKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TrackpadKit",
            targets: ["TrackpadKit"]
        ),
    ],
    targets: [
        .target(
            name: "TrackpadKit",
            dependencies: [
                "TrackpadProtocol",
                "TrackpadCore",
                "TrackpadTransport",
                "TrackpadSecurity",
            ]
        ),
        .target(
            name: "TrackpadProtocol"
        ),
        .target(
            name: "TrackpadCore",
            dependencies: ["TrackpadProtocol"]
        ),
        .target(
            name: "TrackpadTransport",
            dependencies: ["TrackpadProtocol"]
        ),
        .target(
            name: "TrackpadSecurity"
        ),
        .testTarget(
            name: "TrackpadKitTests",
            dependencies: ["TrackpadKit"]
        ),
    ]
)
