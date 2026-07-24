#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT_DIR/brand/MasterDanceLogoSource.png"
SHARED_RESOURCES="$ROOT_DIR/apps/Shared/Resources"
IOS_ICON="$ROOT_DIR/apps/MasterDanceMobile/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
TEMP_DIR="$(mktemp -d)"
ICONSET="$TEMP_DIR/AppIcon.iconset"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing approved logo source: $SOURCE" >&2
  exit 1
fi

mkdir -p "$SHARED_RESOURCES" "$ICONSET"

# Formal lockup: exact colors and composition, downsampled only.
sips -z 1024 1024 "$SOURCE" --out "$SHARED_RESOURCES/MasterDanceLogo.png" >/dev/null

# Compact mark: source pixels only, with the wordmark intentionally excluded.
sips --cropToHeightWidth 700 860 --cropOffset 135 185 "$SOURCE" \
  --out "$SHARED_RESOURCES/MasterDanceLogoMark.png" >/dev/null

# App icons use the compact gold mark. Edge pixels extend the original ivory
# background into a square without recoloring or redrawing the approved mark.
swift "$ROOT_DIR/script/render_square_mark.swift" \
  "$SHARED_RESOURCES/MasterDanceLogoMark.png" "$TEMP_DIR/AppIconMark.png"
sips -z 1024 1024 "$TEMP_DIR/AppIconMark.png" --out "$IOS_ICON" >/dev/null

# macOS uses the same mark inside the platform's rounded app-icon silhouette.
swift "$ROOT_DIR/script/render_rounded_icon.swift" "$IOS_ICON" "$TEMP_DIR/AppIconRounded.png"

for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"; do
  size="${spec%% *}"
  filename="${spec#* }"
  sips -z "$size" "$size" "$TEMP_DIR/AppIconRounded.png" --out "$ICONSET/$filename" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$SHARED_RESOURCES/AppIcon.icns"

echo "Generated Master Dance brand assets from $SOURCE"
