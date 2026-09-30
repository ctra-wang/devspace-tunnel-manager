#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="DevSpace Tunnel Manager"
EXECUTABLE_NAME="DevSpaceTunnelManager"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"

cd "$ROOT_DIR"

echo "▶ Building arm64 release binary..."
xcrun swift build -c release --arch arm64

echo "▶ Creating app bundle..."
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$ROOT_DIR/.build/arm64-apple-macosx/release/$EXECUTABLE_NAME" "$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME"
cp "$ROOT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "▶ Ad-hoc signing..."
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "Built:"
echo "$APP_DIR"
echo ""
echo "Launch with:"
echo "open \"$APP_DIR\""
