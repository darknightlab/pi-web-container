# pi-web-container

A rootless Podman/Docker container running:

- [PI Web](https://github.com/agegr/pi-web): browser UI for Pi sessions
- [Paseo](https://paseo.sh): optional Web, mobile, desktop, and CLI access to coding agents
- [Pi](https://github.com/earendil-works/pi): coding agent used by both services
- A persistent Xvfb/Fluxbox desktop with a D-Bus/AT-SPI accessibility session
- [Cua Driver](https://github.com/trycua/cua) and Playwright MCP for desktop/browser automation
- Optional password-protected noVNC access to the virtual desktop

When enabled, Paseo shares the same Pi configuration and sessions as PI Web. The application image builds on `ghcr.io/canoziia/agent-infra-container:nix`.

## Start

```bash
cp .env.example .env
podman compose up -d
podman compose logs -f
```

Docker Compose works too:

```bash
docker compose up -d
docker compose logs -f
```

Open:

- PI Web: <http://127.0.0.1:30141>
- Paseo: <http://127.0.0.1:6767>

The default image is:

```text
ghcr.io/darknightlab/pi-web-container:main
```

Compose uses host networking by default, while both services bind to `127.0.0.1`. This keeps the host-networked services accessible only from the host loopback interface.

For bridge networking, remove `network_mode: host`, uncomment the `ports:` block in `compose.yml`, and set:

```dotenv
CONTAINER_BIND_ADDR=0.0.0.0
```

A bridge container listening only on its own `127.0.0.1` cannot receive traffic forwarded to its container IP.

## PI Web

Open <http://127.0.0.1:30141> to browse and resume Pi sessions, configure models, inspect files, and use Git worktrees.

A new home starts with anonymous OpenCode Free models and the same initial Pi package configuration shipped by this repository. The seeded `settings.json`, `models.json`, `mcp-adapter.json`, and `agents/settings.json` follow upstream image updates as long as you have not edited them; once you customize a file (or your persistent home predates the seed stamp), it is preserved and left untouched. `instructions.md`, `agents/general-purpose.md`, `agents/general-purpose-read-only.md`, and `agents/review.md` are overwritten from the image on every start, even if you have edited them. `$HOME/.playwright/cli.config.json` also uses `overwrite` on every start. The agent presets include `general-purpose`, `general-purpose-read-only`, read-only `review`, and agent settings with a concurrency limit of 10. The entrypoint's `update_seed <file> [mode] [source] [target]` supports `update` (the default: install missing files and update unchanged seeded files while preserving user edits) and `overwrite` (always replace the target). `settings.json`, `models.json`, `mcp-adapter.json`, and `agents/settings.json` use `update`; `instructions.md`, `agents/general-purpose.md`, `agents/general-purpose-read-only.md`, and `agents/review.md` use `overwrite`. `environment.md` and `AGENTS.md` are regenerated on every start from the generated environment plus your `instructions.md`.

Useful commands:

```bash
podman compose exec pi-web pi
podman compose exec pi-web pi --list-models
podman compose exec pi-web pi config
```

## Virtual desktop

Xvfb and Fluxbox run on `DISPLAY=:0` by default. When host networking exposes a conflicting host X11/Xwayland abstract socket, select an unused display such as `DISPLAY=:99` in `.env`. Playwright MCP uses the Nix-provided Chromium without an explicit head mode, so its headed default follows the available X display. MCP browser sessions use `--isolated`, keeping each temporary profile separate and discarding it after the session.

noVNC is enabled by default, loopback-only and passwordless; noVNC listens on
`127.0.0.1:6080` and x11vnc on `127.0.0.1:5900`. To turn it off set:

```dotenv
NOVNC_ENABLED=false
```

To keep it on but require a password:

```dotenv
NOVNC_BIND_ADDR=127.0.0.1
VNC_PASSWORD=change-me
```

`VNC_PASSWORD` is optional. When it is empty, x11vnc starts with `-nopw`; use
that together with an authenticated ingress (Cloudflare Access, Tailscale, an
SSH tunnel). When it is set it must be at least eight bytes and is also handed
to the embedded Pi Web viewer so it can autoconnect.

With `NOVNC_ENABLED=true`, PI Web also proxies noVNC under its own origin at
`/vnc/` and adds a **virtual desktop** button next to the terminal button in the
file explorer header, which opens noVNC in the right-hand panel. This works in
a plain `next start` because Next forwards the noVNC `websock` WebSocket upgrade
for the `/vnc/*` rewrite. The proxy target is baked into the PI Web build and
defaults to `http://127.0.0.1:6080`; if you change `NOVNC_PORT`, rebuild with
`--build-arg PI_WEB_VNC_TARGET=http://127.0.0.1:<port>`.

You can still open <http://127.0.0.1:6080/vnc.html> directly. The raw VNC server
always binds to loopback and Compose never publishes it. With host networking it
is host-local on port 5900; change `VNC_INTERNAL_PORT` if that port is already
occupied. For remote standalone noVNC access, use a protected tunnel. For bridge
networking, set `NOVNC_BIND_ADDR=0.0.0.0` and publish port 6080.

## Cua Driver

Pi's seeded MCP configuration starts `cua-driver mcp` over stdio. On Linux this
process owns its runtime directly and targets the container's X11 session through
the configured `DISPLAY`. The runtime's shared D-Bus session allows compatible native apps
to expose AT-SPI accessibility trees. Cua provides desktop screenshots, window
discovery, semantic actions where supported, and mouse and keyboard actions
alongside the browser-focused Playwright MCP server.

The default Cua permission mode is `standard`. Existing Chromium profiles remain
an explicit authorization boundary; use a reviewed bounded capability manifest
for unattended access to sensitive resources. Do not switch to `unrestricted`
unless the container is disposable or fully trusted and the full effect of every
allowed action is acceptable.

The base image installs Cua Driver but does not start it. Pi owns the MCP process,
while this runtime image owns Xvfb/Fluxbox and service supervision.

## Paseo

Open <http://127.0.0.1:6767> for the Paseo Web UI. To run PI Web without Paseo, set `PASEO_ENABLED=false` in `.env`; this skips the server and first-run pairing without deleting existing Paseo data.

On first start, the container log prints a pairing QR code and link for the Paseo mobile or desktop app:

```bash
podman compose logs -f
```

Print the pairing information again:

```bash
podman compose exec pi-web paseo daemon pair --relay
```

Useful commands:

```bash
podman compose exec pi-web paseo daemon status
podman compose exec pi-web paseo provider diagnostic pi
podman compose exec pi-web sh -lc 'paseo project create "$HOME"'
podman compose exec pi-web paseo run "your task"
podman compose exec pi-web paseo ls -a -g
```

Paseo supports Pi natively. Sessions created through Paseo use the same Pi data and can also appear in PI Web.

## Configuration

Edit `.env` before starting the container.

Common options:

| Variable               | Purpose                                                                                                      |
| ---------------------- | ------------------------------------------------------------------------------------------------------------ |
| `PI_WEB_IMAGE`         | Container image                                                                                              |
| `CONTAINER_USER`       | Login alias and home-directory name created by the entrypoint; defaults to `pi`                              |
| `CONTAINER_BIND_ADDR`  | Service listen address; `127.0.0.1` for host mode, `0.0.0.0` for bridge mode                                 |
| `PI_WEB_BIND_ADDR`     | Bridge-mode host publish address                                                                             |
| `PI_WEB_PORT`          | PI Web listen port; defaults to `30141`                                                                      |
| `PASEO_PORT`           | Paseo listen port; defaults to `6767`                                                                        |
| `PASEO_ENABLED`        | Enable the Paseo server and first-run pairing; defaults to `true`                                            |
| `DISPLAY`              | Virtual X display; defaults to `:0`; use an unused value such as `:99` if host networking causes a collision |
| `XVFB_RESOLUTION`      | Virtual desktop resolution and depth; defaults to `1920x1080x24`                                             |
| `NOVNC_ENABLED`        | Enable x11vnc and noVNC; defaults to `true`                                                                  |
| `NOVNC_BIND_ADDR`      | noVNC listen address; defaults to `127.0.0.1`                                                                |
| `NOVNC_PORT`           | noVNC listen port and bridge-mode container port; defaults to `6080`                                         |
| `NOVNC_PUBLISH_ADDR`   | Bridge-mode host publish address for noVNC                                                                   |
| `VNC_INTERNAL_PORT`    | Loopback-only raw VNC port; defaults to `5900` and is never published by Compose                             |
| `VNC_PASSWORD`         | Optional; at least eight bytes when set. Empty starts x11vnc with `-nopw` (front it with an authenticated ingress) |
| `PI_WEB_PASSWORD`      | PI Web Basic Auth password; username is `pi`                                                                 |
| `PI_WEB_ALLOWED_HOSTS` | Additional PI Web hostnames                                                                                  |
| `PASEO_PASSWORD`       | Paseo direct-connection password                                                                             |
| `PASEO_HOSTNAMES`      | Additional Paseo hostnames                                                                                   |
| `PASEO_RELAY_ENDPOINT` | Custom relay endpoint in `host:port` form                                                                    |
| `PASEO_RELAY_USE_TLS`  | Set to `true` for a custom TLS relay                                                                         |

For a custom relay:

```dotenv
PASEO_RELAY_ENDPOINT=relay.example.com:443
PASEO_RELAY_USE_TLS=true
```

See `.env.example` for all supported variables.

## Persistent data

Compose mounts:

```text
./data/home  ->  /home
```

The entrypoint creates `/home/$CONTAINER_USER` on first start and exports it as `HOME`; the default is `/home/pi`. Changing `CONTAINER_USER` selects a different persistent home under the same volume. Back up `./data/home` to preserve Pi sessions, credentials, Paseo pairing state, settings, and projects.

## Update

```bash
podman compose pull
podman compose up -d
```

For Docker:

```bash
docker compose pull
docker compose up -d
```

## Build locally

The build configuration is included in `compose.yml`:

```bash
podman compose build
podman compose up -d
```

The Dockerfile extends `ghcr.io/canoziia/agent-infra-container:nix`, fetches the official `agegr/pi-web` repository at the `main` ref, applies every `*.patch` file from the repository-owned `patches/pi-web/` directory, then builds, packs, and installs PI Web globally under `/usr/local`. This keeps local fixes as small, rebaseable patches instead of a long-lived fork. The Pi CLI is not pinned separately: it is installed at the exact `@earendil-works/pi-coding-agent` version the PI Web build uses, so the terminal `pi`, Paseo's Pi provider, and PI Web's session engine never skew. Paseo's version is pinned by `npm/runtime/package-lock.json` for reproducible image builds.

The defaults use the `main` branch of `agegr/pi-web`. If an upstream change makes a patch fail to apply, the build stops so you can rebase it. Patches live in `patches/pi-web/`; there are currently none active (the previous `preserve-streaming-message-on-session-resume` fix has been merged upstream).

The Pi CLI version is not pinned in this repository; it follows the `@earendil-works/pi-coding-agent` version the PI Web build resolves. To update Paseo's pinned version intentionally, change the `@getpaseo/*` versions in `npm/runtime/package.json` and regenerate the lock:

```bash
cd npm/runtime
rm package-lock.json
npm install --package-lock-only --ignore-scripts --no-audit --no-fund
```

## Stop

```bash
podman compose down
```

## Security

PI Web, Paseo, and noVNC can access or control processes with access to the mounted home directory. Host mode binds all enabled services to loopback by default. For remote access, set the relevant passwords and use HTTPS, Cloudflare Access, Tailscale, or an SSH tunnel. Never expose raw VNC port 5900.

## Licenses

PI Web and Pi are MIT licensed. Paseo is AGPL-3.0+.
