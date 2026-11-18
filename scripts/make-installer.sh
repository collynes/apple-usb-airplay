#!/bin/bash
# Builds iPhone Screen Viewer and packages it as a drag-to-Applications DMG.
#
#   ./scripts/make-installer.sh
#
# Optional, for a DMG that opens on other Macs without Gatekeeper warnings
# (needs a paid Apple Developer account):
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" \
#   DEVELOPMENT_TEAM=TEAMID \
#   NOTARY_PROFILE=my-notary-profile \
#   ./scripts/make-installer.sh
# (create the profile once with: xcrun notarytool store-credentials my-notary-profile)
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="ScreenViewer"
VOLUME_NAME="iPhone Screen Viewer"
WORK="build/installer"
DIST="dist"

VERSION=$(xcodebuild -project ScreenViewer.xcodeproj -target "$APP_NAME" -configuration Release -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ MARKETING_VERSION = / {print $2; exit}')
VERSION=${VERSION:-1.0}

echo "==> Building $APP_NAME $VERSION (Release, Apple silicon + Intel)"
rm -rf "$WORK"
mkdir -p "$WORK" "$DIST"

SIGN_ARGS=()
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  SIGN_ARGS=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$DEVELOPER_ID" "OTHER_CODE_SIGN_FLAGS=--timestamp")
  [[ -n "${DEVELOPMENT_TEAM:-}" ]] && SIGN_ARGS+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
fi

xcodebuild -project ScreenViewer.xcodeproj -scheme "$APP_NAME" -configuration Release \
  -derivedDataPath "$WORK/DerivedData" \
  ONLY_ACTIVE_ARCH=NO ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} \
  build | grep -E "error|warning: .*Swift|BUILD" || true

APP="$WORK/DerivedData/Build/Products/Release/$APP_NAME.app"
[[ -d "$APP" ]] || { echo "Build failed: $APP not found"; exit 1; }

echo "==> Preparing disk image contents"
STAGE="$WORK/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/How to install.txt" <<TXT
iPhone Screen Viewer $VERSION

1. Drag ScreenViewer onto the Applications folder.
2. Open it from Applications.

If macOS says it can't verify the app (it isn't signed by a registered developer):
  - Open System Settings > Privacy & Security, scroll down and click "Open Anyway", or
  - in Terminal run:  xattr -dr com.apple.quarantine /Applications/ScreenViewer.app

Requires macOS 12 or later.
TXT

DMG="$DIST/iPhoneScreenViewer-$VERSION.dmg"
rm -f "$DMG"
echo "==> Creating $DMG"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [[ -n "${DEVELOPER_ID:-}" ]]; then
  echo "==> Signing disk image"
  codesign --sign "$DEVELOPER_ID" --timestamp "$DMG"
fi

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "==> Notarizing (this can take a few minutes)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

echo
echo "Done: $(pwd)/$DMG"
codesign -dv "$APP" 2>&1 | grep -E "Authority|Signature" || true
