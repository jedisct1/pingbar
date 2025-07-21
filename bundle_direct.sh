#!/bin/bash
set -e

APP_NAME="PingBar"
EXECUTABLE=".build/direct/$APP_NAME"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Build if executable doesn't exist
if [ ! -f "$EXECUTABLE" ]; then
    echo "Building with direct compilation..."
    ./build_direct.sh
fi

echo "Creating app bundle..."

# Clean up any previous bundle
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy executable
cp "$EXECUTABLE" "$MACOS_DIR/"

# Copy Info.plist
cp Info.plist "$CONTENTS_DIR/Info.plist"

# Copy icon if it exists
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/"
fi

echo "App bundle created: $APP_BUNDLE"
echo "You can now run: open $APP_BUNDLE"