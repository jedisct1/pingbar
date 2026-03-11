#!/bin/bash
set -euo pipefail

APP_NAME="PingBar"
APP_BUNDLE="$APP_NAME.app"
UNIVERSAL_DIR=".build/universal"
UNIVERSAL_BIN="$UNIVERSAL_DIR/$APP_NAME"
VERSION=$(grep -A1 "CFBundleShortVersionString" Info.plist | grep -o '[0-9.]*')
ARCHIVE_NAME="pingbar-${VERSION}.tar.gz"

echo "Building release binaries..."
swift build -c release --arch arm64
swift build -c release --arch x86_64

mkdir -p "$UNIVERSAL_DIR"

echo "Creating universal binary..."
lipo -create \
  .build/arm64-apple-macosx/release/$APP_NAME \
  .build/x86_64-apple-macosx/release/$APP_NAME \
  -output "$UNIVERSAL_BIN"

lipo -info "$UNIVERSAL_BIN"

echo "Bundling app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$UNIVERSAL_BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"

if [ -f "PingBar.icns" ]; then
  cp PingBar.icns "$APP_BUNDLE/Contents/Resources/"
fi

chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "Creating archive $ARCHIVE_NAME..."
rm -f "$ARCHIVE_NAME"
tar -czf "$ARCHIVE_NAME" "$APP_BUNDLE"

echo "SHA256:"
shasum -a 256 "$ARCHIVE_NAME"

echo "Created $ARCHIVE_NAME"
