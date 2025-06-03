#!/bin/bash
set -e

# === USER: FILL THESE VARIABLES ===
DEV_ID="Developer ID Application: Your Name (TEAMID)"  # Change this to your certificate name
APPLE_ID="your@appleid.com"                            # Your Apple ID
TEAM_ID="TEAMID"                                       # Your Apple Developer Team ID
APP_SPECIFIC_PW="app-specific-password"                # App-specific password (generate at appleid.apple.com)
# ===================================

APP="PingBar.app"
ZIP="PingBar.zip"

if [ ! -d "$APP" ]; then
  echo "Error: $APP not found. Build and bundle the app first."
  exit 1
fi

echo "[1/4] Signing the app..."
codesign --deep --force --verify --verbose --sign "$DEV_ID" "$APP"


echo "[2/4] Zipping the app for notarization..."
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"


echo "[3/4] Submitting for notarization..."
xcrun notarytool submit "$ZIP" --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$APP_SPECIFIC_PW" --wait


echo "[4/4] Stapling the notarization ticket..."
xcrun stapler staple "$APP"

echo "Done! $APP is signed and notarized." 