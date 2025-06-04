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
            sources: [
                "PingBarApp.swift",
                "PingManager.swift",
                "DNSManager.swift",
                "NetworkUtilities.swift",
                "PreferencesWindowController.swift",
                "LaunchAgentManager.swift",
                "SparklineRenderer.swift"
            ]
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
