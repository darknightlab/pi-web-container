FROM ghcr.io/nixos/nix:latest

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

ARG PI_WEB_REPOSITORY=https://github.com/canoziia/pi-web.git
ARG PI_WEB_REF=main

RUN mkdir -p /tmp/pi-web-src /tmp/pi-web-package \
 && git -C /tmp/pi-web-src init \
 && git -C /tmp/pi-web-src remote add origin "$PI_WEB_REPOSITORY" \
 && git -C /tmp/pi-web-src fetch --depth=1 origin "$PI_WEB_REF" \
 && git -C /tmp/pi-web-src checkout --detach FETCH_HEAD \
 && cd /tmp/pi-web-src \
 && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci --no-audit --no-fund \
 && NEXT_TELEMETRY_DISABLED=1 npm run build \
 && npm pack --pack-destination /tmp/pi-web-package \
 && HOME=/root npm install -g --prefix /usr/local --no-audit --no-fund \
      /tmp/pi-web-package/*.tgz \
 && rm -rf /tmp/pi-web-src /tmp/pi-web-package /root/.npm

WORKDIR /home/pi
EXPOSE 30141 6767
CMD ["/nix/var/nix/profiles/runtime/bin/pi-web-entrypoint"]
