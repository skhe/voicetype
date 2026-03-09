#!/usr/bin/env bash
# build-release.sh — VoiceType macOS release builder
#
# Usage:
#   ./scripts/build-release.sh [version] [flags]
#
# Flags:
#   --no-sign        Ad-hoc sign only; skip notarization (no certificate needed)
#   --skip-notarize  Sign with Developer ID but skip notarization step
#
# Examples:
#   ./scripts/build-release.sh 0.1.0 --no-sign        # local/beta DMG, no cert required
#   ./scripts/build-release.sh 1.0.0                  # full sign + notarize
#   ./scripts/build-release.sh 1.0.0 --skip-notarize  # sign only
#
# Prerequisites (full signing):
#   - Xcode with Developer ID Application certificate installed
#   - APPLE_TEAM_ID, APPLE_ID, APPLE_APP_PASSWORD env vars set

set -euo pipefail

VERSION="${1:-1.0.0}"
FLAG="${2:-}"
NO_SIGN=false
SKIP_NOTARIZE=false

case "$FLAG" in
  --no-sign)        NO_SIGN=true; SKIP_NOTARIZE=true ;;
  --skip-notarize)  SKIP_NOTARIZE=true ;;
  "")               ;;
  *) echo "Unknown flag: $FLAG"; exit 1 ;;
esac

APP_NAME="VoiceType"
SCHEME="VoiceType"
ARCHIVE_PATH="build/${APP_NAME}.xcarchive"
EXPORT_PATH="build/export"
APP_BUNDLE="build/${APP_NAME}.app"
DMG_STAGING="build/dmg-staging"
DMG_PATH="build/${APP_NAME}-${VERSION}.dmg"
ENTITLEMENTS="VoiceType.entitlements"

echo "==> Building VoiceType v${VERSION} (no-sign=$NO_SIGN)"

# Use xcpretty for nicer output if available; never swallow xcodebuild exit code
if command -v xcpretty &>/dev/null; then PRETTY="xcpretty"; else PRETTY="cat"; fi

# ── 1. Clean ──────────────────────────────────────────────────────────────
rm -rf build
mkdir -p build "$DMG_STAGING"

# ── 2. Archive ────────────────────────────────────────────────────────────
echo "==> Archiving…"

if $NO_SIGN; then
    xcodebuild archive \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=macOS" \
        CODE_SIGN_IDENTITY="-" \
        CODE_SIGN_STYLE=Manual \
        AD_HOC_CODE_SIGNING_ALLOWED=YES \
        SKIP_INSTALL=NO \
        | $PRETTY
else
    xcodebuild archive \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=macOS" \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM="${APPLE_TEAM_ID:?Set APPLE_TEAM_ID env var}" \
        OTHER_CODE_SIGN_FLAGS="--entitlements ${ENTITLEMENTS} --options runtime" \
        SKIP_INSTALL=NO \
        | $PRETTY
fi

# ── 3. Build .app bundle ──────────────────────────────────────────────────
# SPM archives produce a CLI binary at Products/usr/local/bin/.
# We construct the proper .app bundle structure manually.
echo "==> Assembling .app bundle…"

BINARY_SRC="${ARCHIVE_PATH}/Products/usr/local/bin/${APP_NAME}"
if [[ ! -f "$BINARY_SRC" ]]; then
    echo "ERROR: Binary not found at $BINARY_SRC"
    echo "Archive contents:"
    find "$ARCHIVE_PATH/Products" -type f | head -20
    exit 1
fi

mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp "$BINARY_SRC" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Info.plist"  "${APP_BUNDLE}/Contents/Info.plist"

# Copy app icon if present
if [[ -d "Assets.xcassets/AppIcon.appiconset" ]]; then
    cp -R "Assets.xcassets" "${APP_BUNDLE}/Contents/Resources/"
fi

# ── 4. Sign ───────────────────────────────────────────────────────────────
if $NO_SIGN; then
    echo "==> Ad-hoc signing with entitlements…"
    codesign --force --deep --sign - \
        --entitlements "$ENTITLEMENTS" \
        "$APP_BUNDLE"
else
    # ── 4a. Developer ID export ──────────────────────────────────────────
    echo "==> Exporting with Developer ID…"
    cat > build/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>${APPLE_TEAM_ID:-XXXXXXXXXX}</string>
    <key>signingStyle</key><string>automatic</string>
    <key>hardened runtime</key><true/>
</dict>
</plist>
EOF
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist build/ExportOptions.plist \
        | $PRETTY

    # If export produced an .app use it; otherwise fall back to our assembled bundle
    if [[ -d "${EXPORT_PATH}/${APP_NAME}.app" ]]; then
        rm -rf "$APP_BUNDLE"
        APP_BUNDLE="${EXPORT_PATH}/${APP_NAME}.app"
    fi

    # ── 4b. Notarize ─────────────────────────────────────────────────────
    if ! $SKIP_NOTARIZE; then
        echo "==> Notarizing…"
        ditto -c -k --keepParent "$APP_BUNDLE" "build/${APP_NAME}.zip"
        xcrun notarytool submit "build/${APP_NAME}.zip" \
            --apple-id "${APPLE_ID:?Set APPLE_ID env var}" \
            --password "${APPLE_APP_PASSWORD:?Set APPLE_APP_PASSWORD env var}" \
            --team-id "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID env var}" \
            --wait
        xcrun stapler staple "$APP_BUNDLE"
        echo "==> Notarization complete"
    else
        echo "==> Skipping notarization"
    fi
fi

# ── 5. Stage DMG contents ─────────────────────────────────────────────────
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -sf /Applications "$DMG_STAGING/Applications"

# ── 6. Create DMG ─────────────────────────────────────────────────────────
echo "==> Creating DMG…"
STAGED_APP="${DMG_STAGING}/${APP_NAME}.app"
ICON_PATH="${STAGED_APP}/Contents/Resources/AppIcon.icns"

if command -v create-dmg &>/dev/null && [[ -f "$ICON_PATH" ]]; then
    create-dmg \
        --volname "${APP_NAME} ${VERSION}" \
        --volicon "$ICON_PATH" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 150 185 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 450 185 \
        "$DMG_PATH" \
        "$DMG_STAGING"
else
    hdiutil create -volname "${APP_NAME} ${VERSION}" \
        -srcfolder "$DMG_STAGING" \
        -ov -format UDZO \
        "$DMG_PATH"
fi

echo ""
echo "==> Done: $DMG_PATH"
ls -lh "$DMG_PATH"
if $NO_SIGN; then
    echo ""
    echo "NOTE: This DMG is ad-hoc signed (no Developer ID)."
    echo "To install: right-click VoiceType.app → Open, or allow in"
    echo "System Settings → Privacy & Security after first blocked launch."
fi
