// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectivityKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15),
        .macOS(.v13),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "ConnectivityKit",
            targets: ["ConnectivityKit"]
        ),
    ],
    targets: [
        .target(
            name: "ConnectivityKit"
        ),
        .testTarget(
            name: "ConnectivityKitTests",
            dependencies: ["ConnectivityKit"]
        ),
    ]
)
