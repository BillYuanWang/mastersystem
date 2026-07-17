#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_ROOT="${TMPDIR:-/tmp}/master-dance-swift-cache"
BINARY_PATH="$CACHE_ROOT/MasterDanceCoreSmokeTest"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SWIFT_INTERFACE="$(find "$SDK_PATH/usr/lib/swift/Swift.swiftmodule" -name '*apple-macos.swiftinterface' -print -quit)"
SDK_SWIFT_VERSION=""

mkdir -p "$CACHE_ROOT"

if [[ -n "$SWIFT_INTERFACE" ]]; then
  SDK_SWIFT_VERSION="$(sed -n 's|// swift-compiler-version: Apple Swift version \([^ ]*\).*|\1|p' "$SWIFT_INTERFACE" | head -1)"
fi

SWIFT_ARGS=(
  -module-cache-path "$CACHE_ROOT/modules"
)

if [[ -n "$SDK_SWIFT_VERSION" ]]; then
  SWIFT_ARGS+=(
    -Xfrontend -interface-compiler-version
    -Xfrontend "$SDK_SWIFT_VERSION"
  )
fi

swiftc \
  "${SWIFT_ARGS[@]}" \
  "$ROOT_DIR"/packages/MasterDanceCore/Sources/MasterDanceCore/*.swift \
  "$ROOT_DIR"/packages/MasterDanceCore/Sources/MasterDanceCore/Migration/*.swift \
  "$ROOT_DIR/scripts/CoreSmokeTest.swift" \
  -o "$BINARY_PATH"

"$BINARY_PATH"
