#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/apps/MasterDance.xcodeproj"
INFO_PLIST="$ROOT_DIR/apps/MasterDanceAdmin/Info.plist"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist/macos}"
TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-MD-DESK-NOTARY}"

if [[ -z "$TEAM_ID" ]]; then
  echo "Set TEAM_ID to the Agentech Apple Developer Team ID." >&2
  exit 2
fi

if ! security find-identity -v -p codesigning | rg -q "Developer ID Application"; then
  echo "No Developer ID Application certificate is available in Keychain." >&2
  echo "Sign in to Xcode and create or download the certificate first." >&2
  exit 2
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" \
  --output-format json >/dev/null; then
  echo "Notary profile '$NOTARY_PROFILE' is unavailable or invalid." >&2
  echo "Run ./script/setup_notary_profile.sh first." >&2
  exit 2
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
WORK_DIR="$OUTPUT_DIR/work-$VERSION-$BUILD"
ARCHIVE_PATH="$WORK_DIR/MD Desk.xcarchive"
EXPORT_PATH="$WORK_DIR/export"
UPLOAD_ZIP="$WORK_DIR/MD-Desk-$VERSION-$BUILD-notarization.zip"
FINAL_ZIP="$OUTPUT_DIR/MD-Desk-$VERSION-$BUILD-macOS.zip"
EXPORT_OPTIONS="$WORK_DIR/ExportOptions.plist"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

cat >"$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>export</string>
  <key>method</key>
  <string>developer-id</string>
  <key>signingCertificate</key>
  <string>Developer ID Application</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
</dict>
</plist>
PLIST

(
  cd "$ROOT_DIR/apps"
  xcodegen generate --spec project.yml
)

xcodebuild archive \
  -project "$PROJECT" \
  -scheme MasterDanceAdmin \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  archive

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

APP_PATH="$EXPORT_PATH/MD Desk.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Exported app was not found at '$APP_PATH'." >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$UPLOAD_ZIP"

xcrun notarytool submit "$UPLOAD_ZIP" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait \
  --timeout 90m

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

rm -f "$FINAL_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$FINAL_ZIP"

echo
echo "Ready for employee installation:"
echo "$FINAL_ZIP"
