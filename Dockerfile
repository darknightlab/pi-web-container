# PI WEB on the official Nix container image.
# Runs on any Linux with podman/docker (rootless works too).
#
# The toolchain and dev tools come from the Nix flake (flake.nix), with their
# bins linked into /usr/local so they work for the non-root runtime user.
# PI WEB itself is installed from npm on top, with node-pty compiled in-image.
FROM ghcr.io/nixos/nix:latest

ENV NIX_CONFIG="experimental-features = nix-command flakes" \
    PATH="/usr/local/bin:$PATH" \
    npm_config_prefix=/usr/local \
    HOME=/data/home \
    XDG_CONFIG_HOME=/data/config \
    PI_WEB_HOST=0.0.0.0 \
    PI_WEB_PORT=8504 \
    PI_WEB_DATA_DIR=/data/pi-web \
    PI_WEB_SESSIOND_SOCKET=/data/pi-web/sessiond.sock \
    PI_CODING_AGENT_DIR=/data/pi-agent

ARG PI_WEB_VERSION=latest

WORKDIR /

# Nix-managed toolchain + developer tools (see flake.nix).
# Symlink the devEnv bins into /usr/local so they stay usable after USER 1000.
COPY flake.nix flake.lock /
RUN dev="$(nix build .#devEnv --no-link --print-out-paths)" \
 && for f in "$dev"/bin/*; do ln -s "$f" /usr/local/bin/; done

# PI WEB plus its peer dependencies (including the bundled Pi agent).
# The peer `pi` binary does not land on PATH, so we link it like upstream does.
RUN npm install -g --allow-scripts=node-pty --no-audit --no-fund "@jmfederico/pi-web@${PI_WEB_VERSION}" \
 && ln -sf /usr/local/lib/node_modules/@jmfederico/pi-web/node_modules/.bin/pi /usr/local/bin/pi

COPY entrypoint.sh /usr/local/bin/pi-web-entrypoint
RUN chmod +x /usr/local/bin/pi-web-entrypoint

# Run as root inside a ROOTLESS container: container uid 0 maps to the host
# non-root user, so nix can write /nix/store to install packages without ever
# gaining host root. With a rootful runtime this would be real root - keep rootless.

# Single-process-friendly container: session daemon runs in the background,
# the web server stays in the foreground so podman/docker manage its lifetime.
CMD ["/usr/local/bin/pi-web-entrypoint"]
