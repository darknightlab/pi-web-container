FROM ghcr.io/canoziia/agent-infra-container:nix

RUN { printf 'pi:x:0:0:PI container user:/home/pi:/nix/var/nix/profiles/runtime/bin/bash\n'; cat /etc/passwd; } > /tmp/passwd \
 && mv /tmp/passwd /etc/passwd \
 && { printf 'pi:x:0:\n'; cat /etc/group; } > /tmp/group \
 && mv /tmp/group /etc/group \
 && printf '\npi ALL=(ALL:ALL) NOPASSWD: ALL\n' >> /etc/sudoers \
 && chmod 440 /etc/sudoers \
 && install -d -m 700 /home/pi

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
