#!/bin/zsh

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
package="$root/integrations/master-dance-admin"

if [[ ! -f "$package/dist/mcp/server.js" ]]; then
  printf "Master Dance MCP is not built. Run: cd '%s' && npm install && npm run build\n" "$package" >&2
  exit 1
fi

exec /usr/bin/env node "$package/dist/mcp/server.js"
