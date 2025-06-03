// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PingBar",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "PingBar", targets: ["PingBar"])
    ],
    targets: [
        .executableTarget(
            name: "PingBar",
            path: "Sources"
        ),
        .testTarget(
            name: "PingBarTests",
            dependencies: ["PingBar"],
            path: "Tests"
        ),
    ]
)
