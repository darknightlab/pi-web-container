#!/usr/bin/env bash
set -euo pipefail

state=/tmp/pi-web-container
rm -rf "$state"
install -d -m 700 "$state" "$state/supervisor.d"

parse_bool() {
  local name=$1
  local value=$2
  case ${value,,} in
    1 | true | yes | on) printf '1' ;;
    0 | false | no | off) printf '0' ;;
    *)
      echo "[entrypoint] Invalid $name value: $value" >&2
      exit 2
      ;;
  esac
}

validate_port() {
  local name=$1
  local value=$2
  if ! [[ $value =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ] || [ "$value" -gt 65535 ]; then
    echo "[entrypoint] Invalid $name value: $value" >&2
    exit 2
  fi
}

paseo_enabled=$(parse_bool PASEO_ENABLED "${PASEO_ENABLED:-true}")
novnc_enabled=$(parse_bool NOVNC_ENABLED "${NOVNC_ENABLED:-false}")

export DISPLAY=${DISPLAY:-:0}
export XVFB_RESOLUTION=${XVFB_RESOLUTION:-1920x1080x24}
if ! [[ $DISPLAY =~ ^:[0-9]+$ ]]; then
  echo "[entrypoint] DISPLAY must be a local display such as :0: $DISPLAY" >&2
  exit 2
fi
if ! [[ $XVFB_RESOLUTION =~ ^[1-9][0-9]*x[1-9][0-9]*x[1-9][0-9]*$ ]]; then
  echo "[entrypoint] Invalid XVFB_RESOLUTION value: $XVFB_RESOLUTION" >&2
  exit 2
fi

install -d -m 700 "$HOME"
mkdir -p "$HOME/.pi/agent"
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

if [ "$paseo_enabled" -eq 1 ]; then
  cat > "$state/supervisor.d/paseo.conf" <<'EOF'
[program:paseo]
command=/usr/local/libexec/pi-web-container/service paseo
priority=30
autostart=true
autorestart=true
startsecs=3
startretries=30
stopsignal=TERM
stopwaitsecs=20
stopasgroup=true
killasgroup=true
redirect_stderr=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0

[program:paseo-pair]
command=/usr/local/libexec/pi-web-container/service paseo-pair
priority=40
autostart=true
autorestart=false
startsecs=0
startretries=0
exitcodes=0
stopsignal=TERM
stopwaitsecs=5
stopasgroup=true
killasgroup=true
redirect_stderr=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
EOF
else
  echo "[entrypoint] Paseo is disabled."
fi

if [ "$novnc_enabled" -eq 1 ]; then
  : "${VNC_PASSWORD:?[entrypoint] VNC_PASSWORD is required when NOVNC_ENABLED=true.}"
  if [ "${#VNC_PASSWORD}" -lt 8 ]; then
    echo "[entrypoint] VNC_PASSWORD must contain at least eight bytes." >&2
    exit 2
  fi
  export NOVNC_BIND_ADDR=${NOVNC_BIND_ADDR:-127.0.0.1}
  export NOVNC_PORT=${NOVNC_PORT:-6080}
  export VNC_INTERNAL_PORT=${VNC_INTERNAL_PORT:-5900}
  validate_port NOVNC_PORT "$NOVNC_PORT"
  validate_port VNC_INTERNAL_PORT "$VNC_INTERNAL_PORT"
  printf '%s\n' "$VNC_PASSWORD" > "$state/vnc-password"
  chmod 600 "$state/vnc-password"
  unset VNC_PASSWORD

  cat > "$state/supervisor.d/novnc.conf" <<'EOF'
[program:x11vnc]
command=/usr/local/libexec/pi-web-container/service x11vnc
priority=30
autostart=true
autorestart=true
startsecs=1
startretries=30
stopsignal=TERM
stopwaitsecs=10
stopasgroup=true
killasgroup=true
redirect_stderr=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0

[program:novnc]
command=/usr/local/libexec/pi-web-container/service novnc
priority=40
autostart=true
autorestart=true
startsecs=1
startretries=30
stopsignal=TERM
stopwaitsecs=10
stopasgroup=true
killasgroup=true
redirect_stderr=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
EOF
else
  echo "[entrypoint] noVNC is disabled."
fi

exec supervisord -c /etc/supervisord.conf
