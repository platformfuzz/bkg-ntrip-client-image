FROM debian:13-slim

ARG BNC_VERSION=2.13.5.2
ARG BNC_DIST=debian13
ARG BNC_BINARY=bnc-${BNC_VERSION}-${BNC_DIST}
ARG BNC_URL=https://igs.bkg.bund.de/root_ftp/NTRIP/software/BNC/${BNC_BINARY}

# Runtime dependencies for BNC
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates wget \
      libqt5gui5 libqt5widgets5 libqt5network5 libqt5svg5 \
      libqt5printsupport5 libqt5core5a libgl1 \
 && rm -rf /var/lib/apt/lists/*

# Install BNC binary
RUN mkdir -p /opt/bnc && cd /opt/bnc \
 && wget -q "${BNC_URL}" -O BNC \
 && chmod +x BNC \
 && ln -s /opt/bnc/BNC /usr/local/bin/BNC

# BNC-required directories
RUN mkdir -p /srv/bnc/conf /srv/bnc/logs /srv/bnc/rnx

# Runtime dir for Qt (must be 0700 for headless mode)
ENV XDG_RUNTIME_DIR=/tmp/runtime-bncuser
RUN mkdir -p "${XDG_RUNTIME_DIR}" && chmod 700 "${XDG_RUNTIME_DIR}"

# Non-root user + ownership of required dirs
RUN useradd -m -u 1000 bncuser \
 && chown -R bncuser:bncuser /srv/bnc "${XDG_RUNTIME_DIR}"

WORKDIR /srv/bnc
VOLUME ["/srv/bnc/conf"]
VOLUME ["/srv/bnc/logs"]
VOLUME ["/srv/bnc/rnx"]

# Healthcheck: ensure BNC process is running and log file has been updated
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD /bin/sh -c '\
    ls /proc/*/comm 2>/dev/null | xargs -r grep -q "^BNC$" \
    && ls /srv/bnc/logs/bnclog_* >/dev/null 2>&1 \
    || exit 1'

# Entry logic: seed config if missing, do not overwrite if mounted
# Fix permissions for mounted volumes (logs, rnx) if they exist, then switch to bncuser
ENTRYPOINT ["/bin/sh", "-c", "\
  export QT_QPA_PLATFORM=offscreen ; \
  if [ ! -f /srv/bnc/conf/bnc.conf ]; then \
    echo '[entrypoint] No external config found, seeding internal default'; \
    cp /opt/bnc/bnc.conf.default /srv/bnc/conf/bnc.conf; \
  fi; \
  [ -d /srv/bnc/logs ] && chown -R bncuser:bncuser /srv/bnc/logs 2>/dev/null || true; \
  [ -d /srv/bnc/rnx ] && chown -R bncuser:bncuser /srv/bnc/rnx 2>/dev/null || true; \
  exec su bncuser -c 'export QT_QPA_PLATFORM=offscreen; exec BNC \"$@\"' -- \"$@\" \
"]

CMD ["-nw", "--conf", "/srv/bnc/conf/bnc.conf"]
