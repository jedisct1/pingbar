#!/bin/bash
set -e

# Direct Swift compilation without SwiftPM
echo "Building PingBar directly with Swift compiler..."

# Create build directory
mkdir -p .build/direct

# Create a combined main file that doesn't use modules
cat > .build/direct/main_combined.swift << 'EOF'
import Cocoa
import Foundation

@main
struct PingBarMain {
    static func main() {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }
}
EOF

# Compile all Swift files except the original main.swift (which imports PingBarLib)
xcrun swiftc \
    -target x86_64-apple-macos12.0 \
    -o .build/direct/PingBar \
    Sources/PingBarApp.swift \
    Sources/PingManager.swift \
    Sources/DNSManager.swift \
    Sources/NetworkUtilities.swift \
    Sources/PreferencesWindowController.swift \
    Sources/LaunchAgentManager.swift \
    Sources/SparklineRenderer.swift \
    .build/direct/main_combined.swift \
    -framework Cocoa \
    -framework Foundation \
    -framework Security

echo "Build complete: .build/direct/PingBar"