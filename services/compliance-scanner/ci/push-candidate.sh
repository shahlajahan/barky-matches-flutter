#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, Stage 3: push candidate (Slice 2.2 adversarial correction).
# MUTATING (writes to Artifact Registry) — renews the lease first
# (Mandatory correction 2, item 1/7).
#
# Builder-image note (Slice 2.2 final correction): this is one of the
# few steps that genuinely needs docker AND node together in the SAME
# script — the lease renewal check (node-based) must happen inline,
# immediately before the mutation it guards, and Cloud Build has no
# separate "pre-step check" mechanism that could run it in a different
# step's image first. Runs on ci/Dockerfile.ci-builder's image (built
# and its tool contents verified locally in this review — see that
# Dockerfile's own doc comment; NOT pushed to any registry yet).
# Digest resolution itself is a read-only operation with no lease
# fencing requirement, so it is a SEPARATE step (resolve-digest) on the
# plain, single-purpose gcloud-only image, not part of this script.
set -eu

: "${PROJECT_ID:?PROJECT_ID is required}"
: "${REGION:?REGION is required}"
: "${REPOSITORY:?REPOSITORY is required}"
: "${IMAGE_NAME:?IMAGE_NAME is required}"
: "${COMMIT_SHA:?COMMIT_SHA is required}"
: "${BUILD_ID:?BUILD_ID is required}"

cd "$(dirname "$0")/.."

sh ci/renew-lease-or-fail.sh

IMAGE_LOCAL="$(cat /workspace/.image-local-ref)"
REMOTE_TAG="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${COMMIT_SHA}-${BUILD_ID}"
echo "$REMOTE_TAG" > /workspace/.remote-tag
docker tag "$IMAGE_LOCAL" "$REMOTE_TAG"
docker push "$REMOTE_TAG"
