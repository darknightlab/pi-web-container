#!/usr/bin/env bash
set -euo pipefail

# PI WEB runs as two processes: a session daemon that owns Pi agent runtimes
# and a web/API server. In a container we start the daemon in the background
# and keep the web server in the foreground so the container lifecycle is simple.

export LANG="${LANG:-C.UTF-8}"
export LC_ALL="${LC_ALL:-C.UTF-8}"

mkdir -p "$HOME" "$(dirname "$PI_WEB_SESSIOND_SOCKET")"

# Seed a comfortable $HOME shell on first start (PI WEB's bash-able /bin/bash).
if [ ! -f "$HOME/.bash_profile" ]; then
  cat > "$HOME/.bash_profile" <<'PROF'
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
PROF
fi
if [ ! -f "$HOME/.bashrc" ]; then
  cat > "$HOME/.bashrc" <<'RC'
# A pleasant default prompt for the PI WEB shell.
if [ -x /usr/local/bin/starship ]; then
  eval "$(starship init bash)"
else
  PS1='\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\] \$ '
fi
export PS1
alias ls='ls --color=auto'
RC
fi

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
