FROM ghcr.io/canoziia/agent-infra-container:nix

# Fail during image construction if the base image does not provide the Cua
# Driver contract consumed by the seeded MCP configuration below. Isolate the
# check so it cannot bake a generated telemetry identity into the image.
RUN state="$(mktemp -d)" \
 && export HOME="$state" \
           CUA_DRIVER_RS_TELEMETRY_ENABLED=false \
           CUA_DRIVER_RS_UPDATE_CHECK=false \
 && cua-driver --version \
 && cua-driver cursor-theme list --json >/dev/null \
 && rm -rf "$state"

# Build PI Web from the official source, then apply the repository-owned
# patches/pi-web/ directory on top so any local fixes can follow upstream cleanly.
ARG PI_WEB_REPOSITORY=https://github.com/agegr/pi-web.git
ARG PI_WEB_REF=main

COPY patches/pi-web/ /tmp/pi-web-patches/
WORKDIR /tmp/pi-web-src
RUN mkdir -p /tmp/pi-web-package \
 && git -C /tmp/pi-web-src init \
 && git -C /tmp/pi-web-src remote add origin "$PI_WEB_REPOSITORY" \
 && git -C /tmp/pi-web-src fetch --depth=1 origin "$PI_WEB_REF" \
 && git -C /tmp/pi-web-src checkout --detach FETCH_HEAD \
 && for patch in /tmp/pi-web-patches/*.patch; do \
        [ -e "$patch" ] || continue; \
        git -C /tmp/pi-web-src apply --whitespace=nowarn "$patch" || exit 1; \
      done \
 && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci --no-audit --no-fund \
 && NEXT_TELEMETRY_DISABLED=1 npm run build \
 && npm pack --pack-destination /tmp/pi-web-package \
 && npm install -g --prefix /usr/local --no-audit --no-fund \
      /tmp/pi-web-package/*.tgz \
 && rm -rf /tmp/pi-web-src /tmp/pi-web-package /root/.npm

COPY npm/runtime/package.json npm/runtime/package-lock.json /usr/local/lib/pi-web-container/runtime/
WORKDIR /usr/local/lib/pi-web-container/runtime
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund \
 && ln -s ../lib/pi-web-container/runtime/node_modules/.bin/pi /usr/local/bin/pi \
 && ln -s ../lib/pi-web-container/runtime/node_modules/.bin/paseo /usr/local/bin/paseo \
 && pi --version \
 && paseo --version \
 && node -e 'const { createRequire } = require("node:module"); const req = createRequire("/usr/local/lib/pi-web-container/runtime/node_modules/@getpaseo/server/package.json"); if (typeof req("node-pty").spawn !== "function") process.exit(1)' \
 && rm -rf /root/.npm

# Runtime identity setup belongs after build/install layers so changes here do
# not invalidate the expensive PI Web and npm dependency caches.
RUN { printf 'pi:x:0:0:PI container user:/home/pi:/nix/var/nix/profiles/runtime/bin/bash\n'; cat /etc/passwd; } > /tmp/passwd \
 && mv /tmp/passwd /etc/passwd \
 && { printf 'pi:x:0:\n'; cat /etc/group; } > /tmp/group \
 && mv /tmp/group /etc/group \
 && printf '\npi ALL=(ALL:ALL) NOPASSWD: ALL\n' >> /etc/sudoers \
 && chmod 440 /etc/sudoers \
 && install -d -m 700 /home/pi

ENV HOME=/home/pi \
    USER=pi \
    LOGNAME=pi \
    XDG_RUNTIME_DIR=/tmp/pi-web-container/runtime \
    DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/pi-web-container/session-bus.sock

COPY entrypoint.sh /usr/local/bin/pi-web-entrypoint
COPY service.sh /usr/local/libexec/pi-web-container/service
COPY supervisord.conf /etc/supervisord.conf
COPY seed/ /usr/share/pi-web-container/seed/
RUN chmod 755 /usr/local/bin/pi-web-entrypoint \
              /usr/local/libexec/pi-web-container/service

WORKDIR /home/pi
CMD ["/usr/local/bin/pi-web-entrypoint"]
