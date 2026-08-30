#!/usr/bin/env bash
set -uo pipefail

state=/tmp/pi-web-container
rm -rf "$state"

paseo_setting=${PASEO_ENABLED:-true}
case ${paseo_setting,,} in
  1 | true | yes | on) paseo_enabled=1 ;;
  0 | false | no | off) paseo_enabled=0 ;;
  *)
    echo "[entrypoint] Invalid PASEO_ENABLED value: $paseo_setting" >&2
    exit 2
    ;;
esac

install -d -m 700 "$HOME"
mkdir -p "$state" "$HOME/.pi/agent"
[ "$paseo_enabled" -eq 0 ] || mkdir -p "$HOME/.paseo"

seed=/usr/share/pi-web-container/seed/pi-agent
seed_state="$HOME/.pi/agent/.seed-state"
install -d -m 700 "$seed_state"

file_hash() {
  sha256sum "$1" | cut -d ' ' -f 1
}

update_seed() {
  local file=$1
  local source="$seed/$file"
  local target="$HOME/.pi/agent/$file"
  local stamp="$seed_state/$file.sha256"
  local update=0

  if [ ! -e "$target" ]; then
    update=1
  elif [ -e "$stamp" ] && [ "$(file_hash "$target")" = "$(cat "$stamp")" ]; then
    update=1
  fi

  if [ "$update" -eq 1 ]; then
    install -m 600 "$source" "$target"
    file_hash "$target" > "$stamp"
  fi
}

for file in settings.json models.json mcp.json; do
  update_seed "$file"
done
[ -e "$HOME/.pi/agent/instructions.md" ] || install -m 600 "$seed/instructions.md" "$HOME/.pi/agent/instructions.md"

if ! node "$seed/environment.mjs" "$state/environment.md" "$paseo_enabled"; then
  echo "[entrypoint] Failed to generate environment.md." >&2
  exit 1
fi
install -m 600 "$state/environment.md" "$HOME/.pi/agent/environment.md"
rm -f "$seed_state/environment.md.sha256"

agents="$HOME/.pi/agent/AGENTS.md"
candidate="$state/AGENTS.md"

cat "$HOME/.pi/agent/environment.md" > "$candidate"
if [ -s "$HOME/.pi/agent/instructions.md" ]; then
  printf '\n' >> "$candidate"
  cat "$HOME/.pi/agent/instructions.md" >> "$candidate"
fi

install -m 600 "$candidate" "$agents"
rm -f "$seed_state/AGENTS.md.sha256"

cd "$HOME"
bind_addr=${CONTAINER_BIND_ADDR:-127.0.0.1}

supervise() {
  local name=$1
  shift
  while [ ! -e "$state/stop" ]; do
    "$@" &
    echo $! > "$state/$name.pid"
    wait $!
    rm -f "$state/$name.pid"
    [ -e "$state/stop" ] || sleep "${CONTAINER_RESTART_DELAY:-3}"
  done
}

pair_once() {
  local marker="$HOME/.paseo/.pairing-shown"
  [ -e "$marker" ] && return

  for _ in $(seq 1 60); do
    if curl -fsS -m 2 -o /dev/null http://127.0.0.1:6767/api/health; then
      if paseo daemon pair --relay; then
        touch "$marker"
      fi
      return
    fi
    sleep 1
  done
  echo "[entrypoint] Paseo did not become ready; pairing code was not printed." >&2
}

shutdown() {
  touch "$state/stop"
  local file pid
  for file in "$state"/*.pid; do
    [ -e "$file" ] || continue
    pid=$(cat "$file")
    kill "$pid" 2>/dev/null || true
  done
  for pid in $(jobs -p); do
    kill "$pid" 2>/dev/null || true
  done
  wait
  exit 0
}
trap shutdown TERM INT

if [ "$paseo_enabled" -eq 1 ]; then
  supervise paseo env \
    PASEO_LISTEN="$bind_addr:6767" \
    PASEO_WEB_UI_ENABLED=true \
    paseo-server &
  pair_once &
else
  echo "[entrypoint] Paseo is disabled."
fi

supervise pi-web env \
  PI_WEB_SKIP_VERSION_CHECK=1 \
  pi-web --hostname "$bind_addr" --port 30141 --no-open &

wait
