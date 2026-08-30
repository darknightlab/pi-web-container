#!/usr/bin/env bash
set -euo pipefail

state=/tmp/pi-web-container

wait_for_x() {
  local display_number=${DISPLAY#:}
  local socket="/tmp/.X11-unix/X${display_number}"
  until [ -S "$socket" ]; do
    sleep 0.1
  done
}

start_xvfb() {
  local display=${DISPLAY:-:0}
  local display_number=${display#:}
  local lock="/tmp/.X${display_number}-lock"
  local socket="/tmp/.X11-unix/X${display_number}"
  local pid=

  if [ -e "$lock" ]; then
    pid=$(tr -cd '0-9' < "$lock")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "[desktop] Display $display is already in use." >&2
      exit 1
    fi
  fi
  rm -f "$lock" "$socket"

  exec Xvfb "$display" \
    -screen 0 "${XVFB_RESOLUTION:-1920x1080x24}" \
    -nolisten tcp \
    -noreset
}

start_fluxbox() {
  wait_for_x
  unset WAYLAND_DISPLAY
  export XDG_SESSION_TYPE=x11
  exec fluxbox
}

start_pi_web() {
  cd "$HOME"
  exec env PI_WEB_SKIP_VERSION_CHECK=1 \
    pi-web \
      --hostname "${CONTAINER_BIND_ADDR:-127.0.0.1}" \
      --port 30141 \
      --no-open
}

start_paseo() {
  local entry=/usr/local/lib/pi-web-container/runtime/node_modules/@getpaseo/server/dist/scripts/supervisor-entrypoint.js
  cd "$HOME"
  exec env \
    PASEO_LISTEN="${CONTAINER_BIND_ADDR:-127.0.0.1}:6767" \
    PASEO_NODE_ENV=production \
    PASEO_WEB_UI_ENABLED=true \
    node "$entry"
}

pair_paseo() {
  local marker="$HOME/.paseo/.pairing-shown"
  [ -e "$marker" ] && exit 0

  for _ in $(seq 1 60); do
    if curl -fsS -m 2 -o /dev/null http://127.0.0.1:6767/api/health; then
      if paseo daemon pair --relay; then
        touch "$marker"
      fi
      exit 0
    fi
    sleep 1
  done

  echo "[entrypoint] Paseo did not become ready; pairing code was not printed." >&2
  exit 1
}

start_x11vnc() {
  wait_for_x
  unset WAYLAND_DISPLAY
  export XDG_SESSION_TYPE=x11
  exec x11vnc \
    -display "${DISPLAY:-:0}" \
    -localhost \
    -rfbport "${VNC_INTERNAL_PORT:-5900}" \
    -passwdfile "$state/vnc-password" \
    -forever \
    -shared
}

start_novnc() {
  exec novnc \
    --listen "${NOVNC_BIND_ADDR:-127.0.0.1}:${NOVNC_PORT:-6080}" \
    --vnc "127.0.0.1:${VNC_INTERNAL_PORT:-5900}"
}

case ${1:-} in
  fluxbox) start_fluxbox ;;
  novnc) start_novnc ;;
  paseo) start_paseo ;;
  paseo-pair) pair_paseo ;;
  pi-web) start_pi_web ;;
  x11vnc) start_x11vnc ;;
  xvfb) start_xvfb ;;
  *)
    echo "Usage: $0 {xvfb|fluxbox|pi-web|paseo|paseo-pair|x11vnc|novnc}" >&2
    exit 2
    ;;
esac
