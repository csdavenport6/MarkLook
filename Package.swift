// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MarkLookCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MarkLookCore", targets: ["MarkLookCore"])
    ],
    targets: [
        .target(name: "MarkLookCore", path: "Shared"),
        .testTarget(name: "MarkLookCoreTests", dependencies: ["MarkLookCore"], path: "Tests")
    ]
)
