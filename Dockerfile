FROM ghcr.io/canoziia/agent-infra-container:nix

COPY flake.nix flake.lock /usr/share/pi-web-container/
COPY nix/ /usr/share/pi-web-container/nix/
WORKDIR /usr/share/pi-web-container
RUN export HOME=/root \
 && nix profile add .#runtimeEnv --profile /nix/var/nix/profiles/runtime \
 && setup="$(nix build .#setup --no-link --print-out-paths)" \
 && "$setup/bin/pi-web-container-setup" \
 && nix-store --gc \
 && rm -rf /root/.cache/nix /root/.local/state/nix

ARG PI_WEB_REPOSITORY=https://github.com/canoziia/pi-web.git
ARG PI_WEB_REF=main

WORKDIR /tmp/pi-web-src
RUN mkdir -p /tmp/pi-web-package \
 && git -C /tmp/pi-web-src init \
 && git -C /tmp/pi-web-src remote add origin "$PI_WEB_REPOSITORY" \
 && git -C /tmp/pi-web-src fetch --depth=1 origin "$PI_WEB_REF" \
 && git -C /tmp/pi-web-src checkout --detach FETCH_HEAD \
 && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci --no-audit --no-fund \
 && NEXT_TELEMETRY_DISABLED=1 npm run build \
 && npm pack --pack-destination /tmp/pi-web-package \
 && HOME=/root npm install -g --prefix /usr/local --no-audit --no-fund \
      /tmp/pi-web-package/*.tgz \
 && rm -rf /tmp/pi-web-src /tmp/pi-web-package /root/.npm

ENV HOME=/home/pi \
    USER=pi \
    LOGNAME=pi

COPY entrypoint.sh /usr/local/bin/pi-web-entrypoint
COPY service.sh /usr/local/libexec/pi-web-container/service
COPY supervisord.conf /etc/supervisord.conf
COPY seed/ /usr/share/pi-web-container/seed/
RUN chmod 755 /usr/local/bin/pi-web-entrypoint \
              /usr/local/libexec/pi-web-container/service

WORKDIR /home/pi
EXPOSE 30141 6080 6767
CMD ["/usr/local/bin/pi-web-entrypoint"]
