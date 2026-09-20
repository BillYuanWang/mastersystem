#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/apps/MasterDance.xcodeproj"
INFO_PLIST="$ROOT_DIR/apps/MasterDanceMobile/Info.plist"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist/ios}"
TEAM_ID="${TEAM_ID:-}"
PROFILE_NAME="${PROFILE_NAME:-Master Dance iOS App Store}"

if [[ -z "$TEAM_ID" ]]; then
  echo "Set TEAM_ID to the Agentech Apple Developer Team ID." >&2
  exit 2
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
WORK_DIR="$OUTPUT_DIR/work-$VERSION-$BUILD"
ARCHIVE_PATH="$WORK_DIR/Master Dance.xcarchive"
EXPORT_PATH="$WORK_DIR/upload"
EXPORT_OPTIONS="$WORK_DIR/ExportOptions.plist"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"

cat >"$EXPORT_OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>destination</key>
  <string>upload</string>
  <key>manageAppVersionAndBuildNumber</key>
  <false/>
  <key>method</key>
  <string>app-store-connect</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>Apple Distribution</string>
  <key>provisioningProfiles</key>
  <dict>
    <key>com.masterdance.mobile</key>
    <string>$PROFILE_NAME</string>
  </dict>
  <key>teamID</key>
  <string>$TEAM_ID</string>
  <key>testFlightInternalTestingOnly</key>
  <true/>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
PLIST

(
  cd "$ROOT_DIR/apps"
  xcodegen generate --spec project.yml
)

xcodebuild archive \
  -project "$PROJECT" \
  -scheme MasterDanceMobile \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  archive

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

echo
echo "Master Dance $VERSION ($BUILD) was uploaded for internal TestFlight."
echo "Wait for Apple processing, then add internal testers in App Store Connect."
