#!/usr/bin/env bash
set -euo pipefail

# PI WEB runs as two processes: a session daemon that owns Pi agent runtimes
# and a web/API server. In a container we start the daemon in the background
# and keep the web server in the foreground so the container lifecycle is simple.

mkdir -p "$HOME" "$(dirname "$PI_WEB_SESSIOND_SOCKET")"

echo "[pi-web] starting session daemon"
pi-web-sessiond &

sessiond_pid=$!
cleanup() {
  kill "$sessiond_pid" 2>/dev/null || true
  wait "$sessiond_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "[pi-web] waiting for session daemon socket: $PI_WEB_SESSIOND_SOCKET"
for _ in $(seq 1 30); do
  if [ -S "$PI_WEB_SESSIOND_SOCKET" ]; then
    break
  fi
  sleep 1
done

if [ ! -S "$PI_WEB_SESSIOND_SOCKET" ]; then
  echo "[pi-web] session daemon did not become ready" >&2
  exit 1
fi

echo "[pi-web] starting web server on :$PI_WEB_PORT"
exec pi-web-server
