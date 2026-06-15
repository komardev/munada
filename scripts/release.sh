#!/usr/bin/env bash
# Build, sign (Developer ID + hardened runtime), notarize, and staple Munada.app.
#
# Prerequisites (one-time):
#   - Apple Developer Program membership
#   - A "Developer ID Application" certificate in your keychain
#   - Notary credentials stored as a keychain profile:
#       xcrun notarytool store-credentials munada-notary \
#         --apple-id "you@example.com" --team-id "TEAMID" --password "app-specific-pw"
#
# Usage:
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./scripts/release.sh
#
# Optional env:
#   NOTARY_PROFILE   keychain profile name (default: munada-notary)

set -euo pipefail
cd "$(dirname "$0")/.."

: "${SIGN_ID:?Set SIGN_ID to your 'Developer ID Application: ... (TEAMID)' identity}"
NOTARY_PROFILE="${NOTARY_PROFILE:-munada-notary}"

echo "==> Generating project"
xcodegen generate

echo "==> Building Release"
xcodebuild -project Munada.xcodeproj -scheme Munada -configuration Release \
  -derivedDataPath build build

APP="build/Build/Products/Release/Munada.app"

echo "==> Signing with hardened runtime"
codesign --force --deep --options runtime --timestamp --sign "$SIGN_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Zipping for notarization"
DIST="dist"
mkdir -p "$DIST"
ZIP="$DIST/Munada.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> Submitting to Apple notary (this can take a few minutes)"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Repackaging stapled app"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "==> Done: $ZIP (notarized + stapled, ready to upload to a GitHub Release)"
