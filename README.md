# pi-web-container

A rootless Podman/Docker container running:

- [PI Web](https://github.com/canoziia/pi-web): browser UI for Pi sessions
- [Paseo](https://paseo.sh): optional Web, mobile, desktop, and CLI access to coding agents
- [Pi](https://github.com/earendil-works/pi): coding agent used by both services
- A persistent Xvfb/Fluxbox desktop for headed Chromium and Playwright MCP
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

A new home starts with anonymous OpenCode Free models and the same initial Pi package configuration shipped by this repository. Existing persistent Pi settings are preserved.

Useful commands:

```bash
podman compose exec pi-web pi
podman compose exec pi-web pi --list-models
podman compose exec pi-web pi config
```

## Virtual desktop

Xvfb and Fluxbox run on `DISPLAY=:0`. Playwright MCP uses the Nix-provided Chromium without an explicit head mode, so its headed default follows the available X display. MCP browser sessions use `--isolated`, keeping each temporary profile separate and discarding it after the session.

noVNC is disabled by default. To enable browser access to the virtual desktop, set:

```dotenv
NOVNC_ENABLED=true
NOVNC_BIND_ADDR=127.0.0.1
VNC_PASSWORD=change-me
```

Then open <http://127.0.0.1:6080/vnc.html>. The raw VNC server always binds to loopback and Compose never publishes it. With host networking it is host-local on port 5900; change `VNC_INTERNAL_PORT` if that port is already occupied. For remote noVNC access, use a protected tunnel. For bridge networking, set `NOVNC_BIND_ADDR=0.0.0.0` and publish port 6080.

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
podman compose exec pi-web paseo project create /home/pi
podman compose exec pi-web paseo run "your task"
podman compose exec pi-web paseo ls -a -g
```

Paseo supports Pi natively. Sessions created through Paseo use the same Pi data and can also appear in PI Web.

## Configuration

Edit `.env` before starting the container.

Common options:

| Variable | Purpose |
| --- | --- |
| `PI_WEB_IMAGE` | Container image |
| `PI_WEB_REPOSITORY` | PI Web Git repository used for local image builds |
| `PI_WEB_REF` | PI Web branch, tag, or commit used for local image builds |
| `CONTAINER_BIND_ADDR` | Service listen address; `127.0.0.1` for host mode, `0.0.0.0` for bridge mode |
| `PI_WEB_BIND_ADDR` | Bridge-mode host publish address |
| `PI_WEB_PORT` | Bridge-mode PI Web host port |
| `PASEO_PORT` | Bridge-mode Paseo host port |
| `PASEO_ENABLED` | Enable the Paseo server and first-run pairing; defaults to `true` |
| `DISPLAY` | Virtual X display; defaults to `:0` |
| `XVFB_RESOLUTION` | Virtual desktop resolution and depth; defaults to `1920x1080x24` |
| `NOVNC_ENABLED` | Enable x11vnc and noVNC; defaults to `false` |
| `NOVNC_BIND_ADDR` | noVNC listen address; defaults to `127.0.0.1` |
| `NOVNC_PORT` | noVNC listen port and bridge-mode container port; defaults to `6080` |
| `NOVNC_PUBLISH_ADDR` | Bridge-mode host publish address for noVNC |
| `VNC_INTERNAL_PORT` | Loopback-only raw VNC port; defaults to `5900` and is never published by Compose |
| `VNC_PASSWORD` | Required and at least eight bytes when noVNC is enabled; classic VNC uses only the first eight bytes |
| `PI_WEB_PASSWORD` | PI Web Basic Auth password; username is `pi` |
| `PI_WEB_ALLOWED_HOSTS` | Additional PI Web hostnames |
| `PASEO_PASSWORD` | Paseo direct-connection password |
| `PASEO_HOSTNAMES` | Additional Paseo hostnames |
| `PASEO_RELAY_ENDPOINT` | Custom relay endpoint in `host:port` form |
| `PASEO_RELAY_USE_TLS` | Set to `true` for a custom TLS relay |

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

The default working directory is `/home/pi`. Back up `./data/home` to preserve Pi sessions, credentials, Paseo pairing state, settings, and projects.

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

The Dockerfile extends `ghcr.io/canoziia/agent-infra-container:nix`, fetches `PI_WEB_REPOSITORY` at `PI_WEB_REF`, then builds, packs, and installs PI Web globally under `/usr/local`. Pi follows npm's `latest` tag and Paseo follows npm's `beta` tag; the repository-owned `npm/runtime/package-lock.json` pins their resolved versions and complete dependency graph for reproducible image builds. The defaults use the `main` branch of `canoziia/pi-web`.

To update the pinned agent runtime intentionally:

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
