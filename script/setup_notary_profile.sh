#!/usr/bin/env bash
set -euo pipefail

PROFILE_NAME="${1:-MD-DESK-NOTARY}"
APPLE_ID="${APPLE_ID:-}"
TEAM_ID="${TEAM_ID:-}"

if [[ -z "$APPLE_ID" ]]; then
  read -r -p "Apple Developer account email: " APPLE_ID
fi

if [[ -z "$TEAM_ID" ]]; then
  read -r -p "Apple Developer Team ID: " TEAM_ID
fi

if [[ -z "$APPLE_ID" || -z "$TEAM_ID" ]]; then
  echo "Apple ID and Team ID are required." >&2
  exit 2
fi

cat <<'MESSAGE'
Apple will now ask for an app-specific password in a secure terminal prompt.
Create one at account.apple.com if you do not already have one.
The password is stored only in your macOS Keychain and is never written here.
MESSAGE

xcrun notarytool store-credentials "$PROFILE_NAME" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --validate

echo "Notary profile '$PROFILE_NAME' is ready."
