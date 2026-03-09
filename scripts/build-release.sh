#!/usr/bin/env bash
# build-release.sh — VoiceType macOS release builder
# Usage: ./scripts/build-release.sh [version] [--skip-notarize]
#
# Prerequisites:
#   - Xcode with Developer ID Application certificate installed
#   - APPLE_TEAM_ID, APPLE_ID, APPLE_APP_PASSWORD env vars set
#     (or use `xcrun notarytool store-credentials`)
#   - create-dmg: brew install create-dmg

set -euo pipefail

VERSION="${1:-1.0.0}"
SKIP_NOTARIZE="${2:-}"
APP_NAME="VoiceType"
BUNDLE_ID="com.skhe.voicetype"
SCHEME="VoiceType"
ARCHIVE_PATH="build/${APP_NAME}.xcarchive"
EXPORT_PATH="build/export"
DMG_PATH="build/${APP_NAME}-${VERSION}.dmg"
ENTITLEMENTS="VoiceType.entitlements"

echo "==> Building VoiceType v${VERSION}"

# Use xcpretty for nicer output if available, but never swallow xcodebuild's exit code
if command -v xcpretty &>/dev/null; then
    PRETTY="xcpretty"
else
    PRETTY="cat"
fi

# ── 1. Clean ──────────────────────────────────────────────────────────────
rm -rf build
mkdir -p build

# ── 2. Archive ────────────────────────────────────────────────────────────
echo "==> Archiving…"
# Use pipefail-safe pattern: run xcodebuild in a subshell, capture its exit
set -o pipefail
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="${APPLE_TEAM_ID:-}" \
    OTHER_CODE_SIGN_FLAGS="--entitlements ${ENTITLEMENTS} --options runtime" \
    SKIP_INSTALL=NO \
    | $PRETTY

# ── 3. Export ─────────────────────────────────────────────────────────────
echo "==> Exporting…"
cat > build/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID:-XXXXXXXXXX}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>hardened runtime</key>
    <true/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist build/ExportOptions.plist \
    | $PRETTY

APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"

# ── 4. Notarize ───────────────────────────────────────────────────────────
if [[ "$SKIP_NOTARIZE" != "--skip-notarize" ]]; then
    echo "==> Notarizing…"
    ditto -c -k --keepParent "$APP_PATH" "build/${APP_NAME}.zip"
    xcrun notarytool submit "build/${APP_NAME}.zip" \
        --apple-id "${APPLE_ID:?Set APPLE_ID env var}" \
        --password "${APPLE_APP_PASSWORD:?Set APPLE_APP_PASSWORD env var}" \
        --team-id "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID env var}" \
        --wait
    xcrun stapler staple "$APP_PATH"
    echo "==> Notarization complete"
else
    echo "==> Skipping notarization (--skip-notarize)"
fi

# ── 5. Create DMG ─────────────────────────────────────────────────────────
echo "==> Creating DMG…"
if command -v create-dmg &>/dev/null; then
    create-dmg \
        --volname "${APP_NAME} ${VERSION}" \
        --volicon "${APP_NAME}.app/Contents/Resources/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 150 185 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 450 185 \
        "$DMG_PATH" \
        "$EXPORT_PATH"
else
    # Fallback: plain hdiutil DMG (no background, no symlink)
    hdiutil create -volname "${APP_NAME} ${VERSION}" \
        -srcfolder "$EXPORT_PATH" \
        -ov -format UDZO \
        "$DMG_PATH"
fi

echo "==> Done: $DMG_PATH"
ls -lh "$DMG_PATH"
