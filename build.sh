#!/bin/bash
# Builds Speakeasy.app (ad-hoc signed) into ./build. Usage: ./build.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP="build/Speakeasy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Speakeasy" "$APP/Contents/MacOS/Speakeasy"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# SwiftPM resource bundles (KeyboardShortcuts localizations) are looked up in Contents/Resources.
for bundle in "$BIN_DIR"/*.bundle; do
    [ -e "$bundle" ] && cp -R "$bundle" "$APP/Contents/Resources/"
done

codesign --force --deep --sign - "$APP"
echo "Built $APP"
