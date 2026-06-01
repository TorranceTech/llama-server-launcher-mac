#!/bin/bash
# build_mac.sh — Build the macOS .app bundle and .dmg installer
# Uses the system Python 3.11 (Homebrew) instead of PyInstaller, so the app
# behaves identically to running:  /opt/homebrew/bin/python3.11 llamacpp-server-launcher.py
# Usage: ./build_mac.sh
# Requires: create-dmg (brew install create-dmg), python@3.11 + python-tk@3.11

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Llama Server Launcher"
DMG_NAME="LlamaServerLauncher-Mac"
DIST_DIR="$SCRIPT_DIR/dist"
DMG_DIR="$SCRIPT_DIR/dmg_staging"

# ── Check dependencies ──────────────────────────────────────────────────────
echo "==> Checking build dependencies..."

PYTHON311=""
for candidate in /opt/homebrew/bin/python3.11 /usr/local/bin/python3.11; do
    if [ -x "$candidate" ] && "$candidate" -c "import tkinter" 2>/dev/null; then
        PYTHON311="$candidate"
        break
    fi
done

if [ -z "$PYTHON311" ]; then
    echo "ERROR: Python 3.11 with tkinter not found."
    echo "  Install with: brew install python@3.11 && brew install python-tk@3.11"
    exit 1
fi
echo "  Python: $PYTHON311"

if ! command -v create-dmg &> /dev/null; then
    echo "  create-dmg not found. Install it with: brew install create-dmg"
    exit 1
fi

# ── Clean previous build ─────────────────────────────────────────────────────
echo "==> Cleaning previous build artifacts..."
rm -rf "$DIST_DIR" "$DMG_DIR"
mkdir -p "$DMG_DIR"

# ── Regenerate icon ───────────────────────────────────────────────────────────
echo "==> Generating app icon..."
ICON_SRC="$SCRIPT_DIR/images/app_icon_src.png"
ICONSET="/tmp/AppIcon.iconset"
ICNS_OUT="$SCRIPT_DIR/images/app_icon.icns"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16   16   "$ICON_SRC" --out "$ICONSET/icon_16x16.png"      > /dev/null
sips -z 32   32   "$ICON_SRC" --out "$ICONSET/icon_16x16@2x.png"   > /dev/null
sips -z 32   32   "$ICON_SRC" --out "$ICONSET/icon_32x32.png"      > /dev/null
sips -z 64   64   "$ICON_SRC" --out "$ICONSET/icon_32x32@2x.png"   > /dev/null
sips -z 128  128  "$ICON_SRC" --out "$ICONSET/icon_128x128.png"    > /dev/null
sips -z 256  256  "$ICON_SRC" --out "$ICONSET/icon_128x128@2x.png" > /dev/null
sips -z 256  256  "$ICON_SRC" --out "$ICONSET/icon_256x256.png"    > /dev/null
sips -z 512  512  "$ICON_SRC" --out "$ICONSET/icon_256x256@2x.png" > /dev/null
sips -z 512  512  "$ICON_SRC" --out "$ICONSET/icon_512x512.png"    > /dev/null
sips -z 1024 1024 "$ICON_SRC" --out "$ICONSET/icon_512x512@2x.png" > /dev/null
iconutil -c icns "$ICONSET" -o "$ICNS_OUT"
echo "  Icon: $ICNS_OUT"

# ── Assemble .app bundle ──────────────────────────────────────────────────────
echo "==> Assembling .app bundle..."
APP_PATH="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy Python source files into the bundle
cp "$SCRIPT_DIR/llamacpp-server-launcher.py" "$RESOURCES_DIR/"
cp -r "$SCRIPT_DIR/modules"  "$RESOURCES_DIR/"
cp -r "$SCRIPT_DIR/config"   "$RESOURCES_DIR/"
[ -d "$SCRIPT_DIR/images" ] && cp -r "$SCRIPT_DIR/images" "$RESOURCES_DIR/"

# Install third-party packages (requests, psutil) into bundled site-packages
echo "  Installing bundled packages..."
"$PYTHON311" -m pip install --quiet --target "$RESOURCES_DIR/site-packages" \
    requests psutil

# Copy icon
cp "$ICNS_OUT" "$RESOURCES_DIR/app_icon.icns"

# ── Create launcher shell script ──────────────────────────────────────────────
LAUNCHER="$MACOS_DIR/$APP_NAME"
cat > "$LAUNCHER" << 'LAUNCHER_EOF'
#!/bin/bash
# Launcher for Llama Server Launcher — uses system Python 3.11

RESOURCES="$(cd "$(dirname "$0")/../Resources" && pwd)"

# Find Python 3.11 with tkinter support
PYTHON=""
for candidate in \
    /opt/homebrew/bin/python3.11 \
    /usr/local/bin/python3.11 \
    "$(command -v python3.11 2>/dev/null)"; do
    if [ -x "$candidate" ] && "$candidate" -c "import tkinter" 2>/dev/null; then
        PYTHON="$candidate"
        break
    fi
done

if [ -z "$PYTHON" ]; then
    osascript -e 'display alert "Python 3.11 + tkinter Required" message "Llama Server Launcher requires Python 3.11 with tkinter.\n\nInstall with Homebrew:\n  brew install python@3.11\n  brew install python-tk@3.11" as critical'
    exit 1
fi

# Prepend bundled site-packages so requests/psutil are always available
export PYTHONPATH="$RESOURCES/site-packages:${PYTHONPATH:-}"

cd "$RESOURCES"
exec "$PYTHON" "$RESOURCES/llamacpp-server-launcher.py"
LAUNCHER_EOF
chmod +x "$LAUNCHER"

# ── Write Info.plist ──────────────────────────────────────────────────────────
VERSION=$(cat "$SCRIPT_DIR/config/version" 2>/dev/null || echo "1.0.0")

cat > "$CONTENTS/Info.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Llama Server Launcher</string>
    <key>CFBundleIdentifier</key>
    <string>com.llamacpp.launcher</string>
    <key>CFBundleName</key>
    <string>Llama Server Launcher</string>
    <key>CFBundleDisplayName</key>
    <string>Llama Server Launcher</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleIconFile</key>
    <string>app_icon</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
PLIST_EOF

echo "  App bundle: $APP_PATH"

# ── Create .dmg ───────────────────────────────────────────────────────────────
echo "==> Creating DMG..."

DMG_FILE="$SCRIPT_DIR/${DMG_NAME}-${VERSION}.dmg"
rm -f "$DMG_FILE"

# Stage the app — create-dmg adds the Applications symlink via --app-drop-link
cp -r "$APP_PATH" "$DMG_DIR/"

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
echo "Requires: Python 3.11 + tkinter  (brew install python@3.11 python-tk@3.11)"
