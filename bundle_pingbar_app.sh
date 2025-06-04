#!/bin/bash
set -e

APP_NAME="PingBar"
BUILD_DIR=".build/release"
EXECUTABLE="$BUILD_DIR/$APP_NAME"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Build release version if executable doesn't exist
if [ ! -f "$EXECUTABLE" ]; then
    echo "Building release version..."
    swift build -c release
fi

# Clean up any previous bundle
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy executable
cp "$EXECUTABLE" "$MACOS_DIR/"

# Copy Info.plist
cp Info.plist "$CONTENTS_DIR/Info.plist"

# Copy icon if it exists
if [ -f "PingBar.icns" ]; then
    cp PingBar.icns "$RESOURCES_DIR/"
fi

# Make executable
chmod +x "$MACOS_DIR/$APP_NAME"

echo "Created $APP_BUNDLE"

# Optional: Create a symlink for easy access
if [ "$1" = "--link" ]; then
    ln -sf "$(pwd)/$APP_BUNDLE" ~/Applications/
    echo "Linked to ~/Applications/$APP_BUNDLE"
fi