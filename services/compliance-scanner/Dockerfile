# Petsupo Marketplace P1-A compliance foundation — compliance-scanner
# service (Slice 2.1, part E; corrected in the Slice 2.1 correction pass,
# part G). Multi-stage build:
#   1. "signatures" — fetches the current ClamAV database via freshclam
#      ONCE, at build time, and derives signatureBuiltAt from the
#      downloaded database's OWN embedded metadata via `sigtool --info`
#      — never the build host's wall clock (see docker/build-
#      signatures.sh's own doc comment for the full reasoning; this is a
#      Slice 2.1 correction-pass fix, part B).
#   2. "deps" — installs the adapter's Node dependencies from the
#      committed package-lock.json via `npm ci` (reproducible install).
#   3. final runtime — clamav/clamav (official, Cisco-Talos-maintained
#      Alpine-based image: https://hub.docker.com/r/clamav/clamav,
#      https://github.com/Cisco-Talos/clamav-docker) plus Node.js, the
#      baked-in signatures, and the adapter — nothing else.
#
# Reproducibility boundary, stated honestly (do not read this Dockerfile
# as claiming full digest pinning): the base image below is pinned to a
# specific TAG, not a resolved sha256 digest — the digest a given tag
# resolves to is not knowable from this file alone and was not verified
# against a live registry in this session (no Docker/registry access
# was used to build or pull anything here — implementation-and-local-
# verification only, per this task's scope). Before the first real
# build, resolve and pin the actual digest:
#   docker pull clamav/clamav:1.4 && \
#     docker inspect --format='{{index .RepoDigests 0}}' clamav/clamav:1.4
# and replace both FROM lines that reference clamav/clamav:1.4 below with
# that digest. The signature database itself is, by construction, NEVER
# pinned/reproducible byte-for-byte across builds — freshclam always
# fetches "current" at build time (that is the entire point of the
# daily-rebuild policy) — so "reproducible" here means "the base image
# and adapter code are pinned and auditable", not "every build produces
# byte-identical signatures".
#
# Platform: pinned explicitly to linux/amd64 on every stage (Slice 2.1
# correction-pass, part G) — Cloud Run's traditional/default target
# architecture. Without this, a build run on an Apple Silicon (arm64)
# host would by default produce an arm64 image via Docker Desktop's
# native-architecture default, which either fails to run on Cloud Run or
# silently requires an explicit arm64 Cloud Run configuration this
# design does not assume. Pinning it here means every builder, on any
# host architecture, produces the same target platform without needing
# to remember a `--platform` build flag.

FROM --platform=linux/amd64 clamav/clamav:1.4 AS signatures
# GNU coreutils (Slice 2.1 correction-pass, part G/A finding — CORRECTED
# after a real build failure): build-signatures.sh's `date -u -d
# "$RAW_BUILD_TIME"` call requires GNU date's flexible -d parsing; the
# base image's default BusyBox `date` rejected the CVD's own real build-
# time string format ("21 Aug 2026 06:26 +0000") outright — empirically
# confirmed by the real build failure this fixes, not assumed in
# advance. Alpine's `coreutils` package replaces the BusyBox `date`
# applet at the same /bin/date path with genuine GNU coreutils
# (confirmed: `date --version` reports "GNU coreutils" after this
# install, at the same PATH location, so build-signatures.sh needs no
# path change), which parses the CVD's format correctly.
RUN apk add --no-cache coreutils
COPY docker/build-signatures.sh /build-signatures.sh
RUN chmod +x /build-signatures.sh && /build-signatures.sh

FROM --platform=linux/amd64 node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

FROM --platform=linux/amd64 clamav/clamav:1.4 AS runtime

# Node version pinning (Slice 2.1 correction-pass, part G finding;
# CORRECTED after a real build failure during Docker verification — see
# below). The original approach here was `apk add "nodejs~20"`, intended
# to fail loudly rather than silently drift if Alpine's package index
# didn't offer Node 20. It worked exactly as designed: the real build
# FAILED, because clamav/clamav:1.4's Alpine base (3.24) only offers
# nodejs-24.18.1 in its package index — there is no Node 20 package
# available there at all, so the constraint correctly refused to
# silently install a mismatched major version. Root cause: relying on
# the base image's OWN package index for Node was never going to
# reliably produce Node 20, regardless of version-constraint syntax.
#
# Fix: copy the ACTUAL Node 20 binary (+ npm) straight from the `deps`
# stage's node:20-alpine — the same image `npm ci` itself ran under —
# instead of asking clamav/clamav's Alpine index for a Node package at
# all. node:20-alpine (Alpine 3.23) and clamav/clamav:1.4 (Alpine 3.24)
# are adjacent Alpine minor releases against the same musl ABI family;
# copying prebuilt musl binaries across adjacent Alpine minors this way
# is the same technique the official Node Alpine Dockerfiles themselves
# use. This guarantees exact version parity with zero dependency on
# whatever Node version a given Alpine release happens to package.
# CORRECTED after a second real build/inspection failure: in
# node:20-alpine, /usr/local/bin/npm and /usr/local/bin/npx are SYMLINKS
# into /usr/local/lib/node_modules/npm/bin/*-cli.js (their own internal
# `require('../lib/cli.js')` calls are relative to THAT real location).
# `COPY --from=... /usr/local/bin/npm /usr/local/bin/npm` dereferenced
# the symlink and copied the target file's raw CONTENT as a new, plain
# 54-byte file directly at /usr/local/bin/npm — empirically confirmed
# broken (`npm --version` failed with Cannot find module '../lib/cli.js'
# once its relative require resolved against the wrong directory depth).
# Fix: copy only node itself (a real binary, not a symlink — copies
# correctly as-is) and the actual node_modules/npm package tree, then
# RECREATE the bin symlinks explicitly at their correct relative depth
# rather than copying the pre-existing symlinks/their dereferenced
# targets from the other stage.
COPY --from=deps /usr/local/bin/node /usr/local/bin/node
COPY --from=deps /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -sf ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# su-exec: minimal, audited privilege-drop tool (Alpine-native) used by
# docker/entrypoint.sh to run the Node adapter as a non-root user while
# still allowing the entrypoint itself to start as root only long enough
# to prepare /var/run/clamav and launch clamd (which drops its own
# privileges internally via clamd.conf's `User clamav`).
#
# Local verification note (Slice 2.1 review correction 3 — see the
# deployment readiness doc's §4a for the full explanation): this
# root-then-drop-privileges sequence was proven under `docker run
# --cap-drop ALL` plus exactly CHOWN, SETUID, SETGID, and DAC_OVERRIDE
# re-added — that is a fact about the LOCAL DOCKER TEST posture only.
# Cloud Run does not expose Docker-style --cap-add/--cap-drop
# configuration, so those four capability names are not a Cloud Run
# deployment setting to carry forward; the real Cloud Run staging test
# must instead prove the outcomes (entrypoint starts, required
# directories are writable, clamd initializes and drops to `clamav`,
# Node runs as `node-adapter`, socket ownership/mode are correct) —
# and if Cloud Run's runtime model can't support this exact sequence,
# the startup/user model gets redesigned, not granted elevated
# execution.
RUN apk add --no-cache su-exec libstdc++ libgcc \
    && addgroup -S node-adapter \
    && adduser -S -G node-adapter -H node-adapter \
    # Socket access fix (Slice 2.1 correction-pass, part G finding):
    # clamd.conf sets LocalSocketGroup clamav + LocalSocketMode 660 on
    # the Unix socket — a node-adapter user in its OWN, separate group
    # would NOT have permission to connect to it. Adding node-adapter as
    # a supplementary member of the clamav group (without changing its
    # primary group) grants exactly the access needed, nothing more.
    && addgroup node-adapter clamav

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY package.json package-lock.json index.js ./
COPY src ./src
COPY docker/clamd.conf /etc/clamav/clamd.conf
COPY docker/entrypoint.sh /entrypoint.sh
COPY --from=signatures /var/lib/clamav /var/lib/clamav
COPY --from=signatures /opt/clamav-signatures/metadata.json /opt/clamav-signatures/metadata.json

RUN chmod +x /entrypoint.sh \
    && chown -R node-adapter:node-adapter /app \
    && mkdir -p /var/run/clamav \
    && chown clamav:clamav /var/run/clamav /var/lib/clamav

ENV SIGNATURE_METADATA_PATH=/opt/clamav-signatures/metadata.json
ENV CLAMD_SOCKET_PATH=/var/run/clamav/clamd.sock
ENV PORT=8080

# Only the adapter's HTTP port is exposed — clamd's socket is a local
# Unix socket (see clamd.conf), never a network-reachable port at all,
# so there is nothing clamd-related to expose in the first place.
EXPOSE 8080

# Root filesystem expectation: everything under /app (adapter code,
# node_modules) and /var/lib/clamav (baked signatures) is written once
# at build time and never modified at runtime — this image is compatible
# with `docker run --read-only` / Cloud Run's read-only root filesystem
# option, PROVIDED the two genuinely-writable runtime locations below
# are mounted as writable tmpfs, since the adapter and clamd both need
# them:
#   - /tmp (the adapter's private per-scan temporary file — see
#     scanHandler.js — and clamd's own scratch space; Alpine's default
#     /tmp is world-writable (mode 1777) out of the box, so no
#     additional Dockerfile step is needed for this specifically to
#     work as non-root — only to make it a tmpfs mount under a
#     read-only root)
#   - /var/run/clamav (clamd's socket + pid file, created at container
#     start by entrypoint.sh, not baked into the image)
# No other path needs to be writable; this is not currently enforced by
# the Dockerfile itself (Cloud Run's `--execution-environment` / mounted-
# volume configuration for a read-only root is a deploy-time setting,
# out of this task's "no GCP resource creation" scope) — documented here
# so the deploy-time configuration in the readiness doc can apply it.

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD wget -q -O- http://127.0.0.1:8080/healthz || exit 1

# Exec-form entrypoint. Process/signal model corrected in the Slice 2.1
# correction pass (part G) — see entrypoint.sh's own doc comment: the
# entrypoint script itself now remains PID 1 (it no longer `exec`s Node
# to replace itself) specifically so it can trap and forward SIGTERM to
# BOTH clamd and the Node adapter, rather than only the one that happens
# to become PID 1.
ENTRYPOINT ["/entrypoint.sh"]
