#!/usr/bin/env bash
# Build OWLCleaner and assemble a signed .app bundle.
#
# The code-signing identity must be STABLE across builds so the Full Disk Access
# grant survives rebuilds (TCC keys the grant on the designated requirement).
# Override with: OWL_SIGN_ID="<identity hash or name>" ./Scripts/make_app.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP_NAME="OWLCleaner"
BUNDLE_ID="com.aunguyen.owlcleaner"
APP_DIR="$ROOT/build/${APP_NAME}.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

# Optional stable signing identity (overridable). When set, the bundle's
# designated requirement stays constant across rebuilds so a Full Disk Access
# grant persists. Unset -> ad-hoc signature (fine for local/dev use).
SIGN_ID="${OWL_SIGN_ID:-}"

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG"
BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"

echo "==> Assembling bundle…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"

if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"
  ICON_KEY='<key>CFBundleIconFile</key><string>AppIcon</string>'
else
  ICON_KEY=''
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSUIElement</key><false/>
    $ICON_KEY
</dict>
</plist>
PLIST

echo "==> Code signing…"
if [[ -n "$SIGN_ID" ]]; then
  if codesign --force --deep --sign "$SIGN_ID" "$APP_DIR" 2>/dev/null; then
    echo "    signed with '$SIGN_ID' (stable designated requirement → Full Disk Access persists across rebuilds)"
  else
    echo "    WARNING: identity '$SIGN_ID' unavailable; falling back to ad-hoc."
    codesign --force --deep --sign - "$APP_DIR"
  fi
else
  codesign --force --deep --sign - "$APP_DIR"
  echo "    ad-hoc signed. Set OWL_SIGN_ID=<identity> for a stable signature so the"
  echo "    Full Disk Access grant survives rebuilds (see README)."
fi

echo "==> Done: $APP_DIR"
