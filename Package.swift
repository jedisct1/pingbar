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
        .target(
            name: "PingBarLib",
            path: "Sources",
            exclude: ["main.swift"]
        ),
        .executableTarget(
            name: "PingBar",
            dependencies: ["PingBarLib"],
            path: "Sources",
            sources: ["main.swift"]
        ),
        .testTarget(
            name: "PingBarTests",
            dependencies: ["PingBarLib"],
            path: "Tests"
        ),
    ]
)
