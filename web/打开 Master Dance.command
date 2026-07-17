#!/bin/zsh
set -u

DIR="${0:A:h}"
cd "$DIR"

PORT=8765
while lsof -nP -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; do
  PORT=$((PORT + 1))
done

echo "Master Dance Reserve"
echo "Opening http://127.0.0.1:$PORT/index.html"
echo "Keep this window open while using the schedule system."
echo

python3 server.py "$PORT" &
SERVER_PID=$!

sleep 0.8
open "http://127.0.0.1:$PORT/index.html"

trap 'kill "$SERVER_PID" 2>/dev/null' INT TERM EXIT
wait "$SERVER_PID"
