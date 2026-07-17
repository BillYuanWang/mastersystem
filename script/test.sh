#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTING_RUNTIME_DIR="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

cd "$ROOT_DIR"
if [[ -f "$TESTING_RUNTIME_DIR/lib_TestingInterop.dylib" ]]; then
  swift test \
    --disable-xctest \
    -Xlinker "-L$TESTING_RUNTIME_DIR" \
    -Xlinker -rpath \
    -Xlinker "$TESTING_RUNTIME_DIR"
else
  swift test --disable-xctest
fi
