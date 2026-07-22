#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
GENERATOR="$ROOT/script/build_tutorial_pdf.py"

if [ -n "${CODEX_PYTHON:-}" ] && "$CODEX_PYTHON" -c 'import reportlab' >/dev/null 2>&1; then
    exec "$CODEX_PYTHON" "$GENERATOR"
fi

if command -v python3 >/dev/null 2>&1 && python3 -c 'import reportlab' >/dev/null 2>&1; then
    exec python3 "$GENERATOR"
fi

CODEX_RUNTIME_PYTHON="$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3"
if [ -x "$CODEX_RUNTIME_PYTHON" ] && "$CODEX_RUNTIME_PYTHON" -c 'import reportlab' >/dev/null 2>&1; then
    exec "$CODEX_RUNTIME_PYTHON" "$GENERATOR"
fi

printf '%s\n' 'Cannot build TUTORIAL.pdf: Python package "reportlab" is unavailable.' >&2
printf '%s\n' 'Set CODEX_PYTHON to a Python executable that can import reportlab.' >&2
exit 1
