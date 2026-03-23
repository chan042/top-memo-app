#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/Distribution/build-common.sh"

APP_NAME="TopMemo"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
APP_ICON_SOURCE="$ROOT_DIR/image/TopMemo_app_ic.png"
TEMP_DIR=""

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    release_build_lock
}

handle_signal() {
    cleanup
    exit 1
}

trap cleanup EXIT
trap handle_signal INT TERM

acquire_build_lock "$BUILD_DIR"
TEMP_DIR="$(mktemp -d "$BUILD_DIR/.make-dmg.XXXXXX")"
rm -rf "$BUILD_DIR/dmg-staging"
rm -f "$BUILD_DIR/TopMemoDmgIcon.png" "$BUILD_DIR/TopMemoDmgIcon.rsrc"

STAGING_DIR="$TEMP_DIR/dmg-staging"
DMG_TMP_PATH="$TEMP_DIR/$APP_NAME.dmg"
DMG_ICON_TEMP_PNG="$TEMP_DIR/TopMemoDmgIcon.png"
ICON_RSRC="$TEMP_DIR/TopMemoDmgIcon.rsrc"

zsh "$ROOT_DIR/Distribution/build-app.sh" >/dev/null

mkdir -p "$STAGING_DIR"
ditto "$APP_DIR" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_TMP_PATH" >/dev/null

if [[ -f "$APP_ICON_SOURCE" ]]; then
    xattr -c "$DMG_TMP_PATH" 2>/dev/null || true
    rm -f "$ICON_RSRC"
    cp "$APP_ICON_SOURCE" "$DMG_ICON_TEMP_PNG"
    xattr -c "$DMG_ICON_TEMP_PNG" 2>/dev/null || true
    sips -i "$DMG_ICON_TEMP_PNG" >/dev/null
    DeRez -only icns "$DMG_ICON_TEMP_PNG" > "$ICON_RSRC"
    Rez -append "$ICON_RSRC" -o "$DMG_TMP_PATH"
    SetFile -a C "$DMG_TMP_PATH"
fi

codesign --force --sign - "$DMG_TMP_PATH" >/dev/null 2>&1 || true

rm -f "$DMG_PATH"
mv "$DMG_TMP_PATH" "$DMG_PATH"

echo "$DMG_PATH"
