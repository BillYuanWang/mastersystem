#!/bin/zsh

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/integrations/master-dance-admin"

npm run check
npm run build
npm test
