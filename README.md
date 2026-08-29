# pi-web-container

A rootless Podman/Docker container running:

- [PI Web](https://github.com/agegr/pi-web): browser UI for Pi sessions
- [Paseo](https://paseo.sh): Web, mobile, desktop, and CLI access to coding agents
- [Pi](https://github.com/earendil-works/pi): coding agent used by both services

PI Web and Paseo share the same Pi configuration and sessions.

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

## Paseo

Open <http://127.0.0.1:6767> for the Paseo Web UI.

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
| `CONTAINER_BIND_ADDR` | Service listen address; `127.0.0.1` for host mode, `0.0.0.0` for bridge mode |
| `PI_WEB_BIND_ADDR` | Bridge-mode host publish address |
| `PI_WEB_PORT` | Bridge-mode PI Web host port |
| `PASEO_PORT` | Bridge-mode Paseo host port |
| `PI_WEB_PASSWORD` | PI Web Basic Auth password; username is `pi` |
| `PI_WEB_ALLOWED_HOSTS` | Additional PI Web hostnames |
| `PASEO_PASSWORD` | Paseo direct-connection password |
| `PASEO_HOSTNAMES` | Additional Paseo hostnames |
| `PASEO_RELAY_ENDPOINT` | Custom relay endpoint in `host:port` form |
| `PASEO_RELAY_USE_TLS` | Set to `true` for a custom TLS relay |
| `CONTAINER_RESTART_DELAY` | Delay before restarting a failed service |

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

Uncomment the `build:` block in `compose.yml`, then run:

```bash
podman compose up -d --build
```

`PI_WEB_VERSION` controls the npm version of `@agegr/pi-web`; the Dockerfile default is `latest`.

## Stop

```bash
podman compose down
```

## Security

Both services can run coding agents with access to the mounted home directory. Host mode binds both services to loopback by default. For remote access, set both passwords and use HTTPS, Tailscale, or an SSH tunnel.

## Licenses

PI Web and Pi are MIT licensed. Paseo is AGPL-3.0+.
