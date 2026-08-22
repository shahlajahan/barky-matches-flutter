#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, Stage 1: build candidate image (Slice 2.2 adversarial
# correction). Non-mutating (no push, no deploy) — does not renew the
# lease; only push-candidate onward does, per Mandatory correction 2.
set -eu

: "${COMMIT_SHA:?COMMIT_SHA is required}"
: "${BUILD_ID:?BUILD_ID is required}"
: "${IMAGE_NAME:?IMAGE_NAME is required}"

cd "$(dirname "$0")/.."

IMAGE_LOCAL="${IMAGE_NAME}:${COMMIT_SHA}-${BUILD_ID}"
echo "$IMAGE_LOCAL" > /workspace/.image-local-ref

# --platform linux/amd64 explicit and unconditional, matching the
# Dockerfile's own per-stage pin — Cloud Run's supported target
# architecture, regardless of the build machine's own architecture.
# build-signatures.sh (invoked by the Dockerfile's "signatures" stage)
# already fails this build outright if signatures are missing,
# unparseable, future-dated, or already stale at build time — see its
# own doc comment for the 9 distinct fail-closed conditions; nothing in
# this pipeline re-implements or weakens that check.
docker build --platform linux/amd64 -t "$IMAGE_LOCAL" .
