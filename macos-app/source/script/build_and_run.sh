#!/usr/bin/env bash
set -euo pipefail

# This path used to build the retired English/CSV prototype. Keep it as a
# compatibility redirect so an old Codex Run action cannot recreate that app.
REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

echo "The legacy MD Desk prototype is retired; opening the current native app." >&2
exec "$REPOSITORY_ROOT/script/build_and_run.sh" "$@"
