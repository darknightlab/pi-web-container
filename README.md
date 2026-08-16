# pi-web-container

Portable [PI WEB](https://pi-web.dev) development container, built from the
official [Nix container image](https://ghcr.io/nixos/nix) and intended to run
on any Linux with podman or docker (rootless included).

The image keeps your Nix workflow intact: the toolchain is a Nix flake
`devEnv` (Node latest, Python, GCC, and the `git`/`tmux`/`direnv`/`starship`
dev tools plus CLI utilities from your NixOS setup), built via `nix build .#devEnv`.
PI WEB and its peer Pi agent are then installed from npm, and the bundled `pi`
binary is linked onto `PATH`, exactly like PI WEB's upstream Dockerfile does.

## Layout

```text
.
├── flake.nix        # devEnv: Nix-managed toolchain + dev tools
├── flake.lock
├── Dockerfile       # flake devEnv + npm PI WEB, based on ghcr.io/nixos/nix
├── entrypoint.sh   # session daemon (background) + web server (foreground)
├── .github/workflows/  # docker-publish.yml: build & push to ghcr.io
├── compose.yml    # compose/podman orchestrator (defaults to ghcr latest)
└── .env.example
```

## Quick start

Default behavior pulls the cloud image `ghcr.io/darknightlab/pi-web-container:latest`.

```bash
cp .env.example .env
# optional: edit PI_WEB_VERSION / PI_WEB_PORT / PI_WEB_BIND_ADDR

podman compose up -d
# or: docker compose up -d
```

To build locally instead (uncomment the `build:` block), use `--build`: `podman compose up -d --build`.

Then open <http://127.0.0.1:8504>.

Workspace is mounted at `./workspace`, and persistent PI WEB / Pi state lives in
`./data`.

## Commands

```bash
podman compose up -d --build      # build locally and start
podman compose up -d            # pull cloud image and start
podman compose ps              # status
podman compose logs -f pi-web   # logs
podman compose down           # stop
```

## Build arguments

| Variable        | Default  | Meaning                          |
| --------------- | -------- | -------------------------------- |
| `PI_WEB_VERSION` | `latest` | npm release for `@jmfederico/pi-web` |

## Notes

- The image is a minimal container: Pi agents run inside the container and work on the
  mounted workspace paths.
- Keep the web port bound to localhost by default. For remote use, prefer an SSH
  tunnel, a trusted VPN, or an authenticated reverse proxy; do not expose it
  directly to the public internet.
