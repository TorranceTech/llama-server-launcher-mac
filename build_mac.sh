#!/bin/bash
# build_mac.sh — Build the macOS .app bundle and .dmg installer
# Usage: ./build_mac.sh
# Requires: Python 3.11 (with tkinter), create-dmg (brew install create-dmg)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Llama Server Launcher"
DMG_NAME="LlamaServerLauncher-Mac"
BUILD_ENV="$SCRIPT_DIR/build-env"
DIST_DIR="$SCRIPT_DIR/dist"
BUILD_DIR="$SCRIPT_DIR/build"
DMG_DIR="$SCRIPT_DIR/dmg_staging"

# ── Check dependencies ──────────────────────────────────────────────────────
echo "==> Checking build dependencies..."

if [ ! -f "$BUILD_ENV/bin/pyinstaller" ]; then
    echo "  build-env not found. Creating..."
    uv venv "$BUILD_ENV" --python 3.11
    uv pip install --python "$BUILD_ENV" pyinstaller requests psutil
fi

if ! command -v create-dmg &> /dev/null; then
    echo "  create-dmg not found. Install it with: brew install create-dmg"
    exit 1
fi

# ── Clean previous build ─────────────────────────────────────────────────────
echo "==> Cleaning previous build artifacts..."
rm -rf "$DIST_DIR" "$BUILD_DIR" "$DMG_DIR"
mkdir -p "$DMG_DIR"

# ── Regenerate icon ───────────────────────────────────────────────────────────
echo "==> Generating app icon..."
ICON_SRC="$SCRIPT_DIR/images/main.png"
ICONSET="/tmp/AppIcon.iconset"
ICNS_OUT="$SCRIPT_DIR/images/app_icon.icns"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16   16   "$ICON_SRC" --out "$ICONSET/icon_16x16.png"   > /dev/null
sips -z 32   32   "$ICON_SRC" --out "$ICONSET/icon_16x16@2x.png" > /dev/null
sips -z 32   32   "$ICON_SRC" --out "$ICONSET/icon_32x32.png"   > /dev/null
sips -z 64   64   "$ICON_SRC" --out "$ICONSET/icon_32x32@2x.png" > /dev/null
sips -z 128  128  "$ICON_SRC" --out "$ICONSET/icon_128x128.png"  > /dev/null
sips -z 256  256  "$ICON_SRC" --out "$ICONSET/icon_128x128@2x.png" > /dev/null
sips -z 256  256  "$ICON_SRC" --out "$ICONSET/icon_256x256.png"  > /dev/null
sips -z 512  512  "$ICON_SRC" --out "$ICONSET/icon_256x256@2x.png" > /dev/null
sips -z 512  512  "$ICON_SRC" --out "$ICONSET/icon_512x512.png"  > /dev/null
sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET/icon_512x512@2x.png" > /dev/null
iconutil -c icns "$ICONSET" -o "$ICNS_OUT"
echo "  Icon: $ICNS_OUT"

# ── Build .app with PyInstaller ───────────────────────────────────────────────
echo "==> Building .app bundle with PyInstaller..."
cd "$SCRIPT_DIR"

"$BUILD_ENV/bin/pyinstaller" \
    --clean \
    --noconfirm \
    llama_launcher.spec

APP_PATH="$DIST_DIR/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: .app not found at $APP_PATH"
    exit 1
fi

echo "  App bundle: $APP_PATH"

# ── Create .dmg ───────────────────────────────────────────────────────────────
echo "==> Creating DMG..."

# Read version from config/version file
VERSION=$(cat "$SCRIPT_DIR/config/version" 2>/dev/null || echo "1.0.0")
DMG_FILE="$SCRIPT_DIR/${DMG_NAME}-${VERSION}.dmg"

# Stage the app and a symlink to /Applications for drag-and-drop install
cp -r "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

create-dmg \
    --volname "$APP_NAME" \
    --volicon "$ICNS_OUT" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 128 \
    --icon "$APP_NAME.app" 150 185 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 450 185 \
    --no-internet-enable \
    "$DMG_FILE" \
    "$DMG_DIR"

echo ""
echo "==> Done!"
echo "    App:  $APP_PATH"
echo "    DMG:  $DMG_FILE"
echo ""
echo "Drag '$APP_NAME.app' to Applications to install."
