FROM ghcr.io/nixos/nix:latest

ARG PI_WEB_VERSION=latest

ENV NIX_CONFIG="experimental-features = nix-command flakes" \
    PATH="/nix/var/nix/profiles/runtime/bin:/usr/local/bin:/root/.nix-profile/bin:/usr/bin:/bin" \
    HOME=/home/pi \
    USER=pi \
    LOGNAME=pi \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

COPY flake.nix flake.lock entrypoint.sh /usr/share/pi-web-container/
COPY nix/ /usr/share/pi-web-container/nix/
COPY seed/ /usr/share/pi-web-container/seed/
RUN cd /usr/share/pi-web-container \
 && HOME=/root nix profile add .#runtimeEnv .#entrypoint --profile /nix/var/nix/profiles/runtime \
 && setup="$(nix build .#setup --no-link --print-out-paths)" \
 && "$setup/bin/pi-web-container-setup" \
 && nix-store --gc \
 && rm -rf /root/.cache/nix /root/.local/state/nix

RUN HOME=/root npm install -g --prefix /usr/local --no-audit --no-fund \
      "@agegr/pi-web@${PI_WEB_VERSION}" \
 && rm -rf /root/.npm

WORKDIR /home/pi
EXPOSE 30141 6767
CMD ["/nix/var/nix/profiles/runtime/bin/pi-web-entrypoint"]
