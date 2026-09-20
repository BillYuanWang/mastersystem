#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_ROOT="${DERIVED_ROOT:-/private/tmp/MasterDanceReleasePreflight}"

(
  cd "$ROOT_DIR/apps"
  xcodegen generate --spec project.yml
)

plutil -lint \
  "$ROOT_DIR/apps/MasterDanceAdmin/Info.plist" \
  "$ROOT_DIR/apps/MasterDanceMobile/Info.plist" \
  "$ROOT_DIR/apps/Shared/Resources/PrivacyInfo.xcprivacy"

"$ROOT_DIR/script/test.sh"

rm -rf "$DERIVED_ROOT"

xcodebuild \
  -project "$ROOT_DIR/apps/MasterDance.xcodeproj" \
  -scheme MasterDanceAdmin \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_ROOT/macOS" \
  CODE_SIGNING_ALLOWED=NO \
  build \
  -quiet

xcodebuild \
  -project "$ROOT_DIR/apps/MasterDance.xcodeproj" \
  -scheme MasterDanceMobile \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_ROOT/iOS" \
  CODE_SIGNING_ALLOWED=NO \
  build \
  -quiet

MAC_APP="$DERIVED_ROOT/macOS/Build/Products/Release/MD Desk.app"
IOS_APP="$DERIVED_ROOT/iOS/Build/Products/Release-iphoneos/Master Dance.app"

test -d "$MAC_APP"
test -d "$IOS_APP"
test -f "$MAC_APP/Contents/Resources/PrivacyInfo.xcprivacy"
test -f "$IOS_APP/PrivacyInfo.xcprivacy"

MAC_BUILD="$(plutil -extract CFBundleVersion raw -o - "$MAC_APP/Contents/Info.plist")"
IOS_BUILD="$(plutil -extract CFBundleVersion raw -o - "$IOS_APP/Info.plist")"

echo
echo "Unsigned Release preflight passed."
echo "macOS build: $MAC_BUILD"
echo "iOS build: $IOS_BUILD"

if security find-identity -v -p codesigning | rg -q "Developer ID Application"; then
  echo "Developer ID Application certificate: available"
else
  echo "Developer ID Application certificate: missing"
fi

if security find-identity -v -p codesigning | rg -q "Apple Distribution"; then
  echo "Apple Distribution certificate: available"
else
  echo "Apple Distribution certificate: missing"
fi
