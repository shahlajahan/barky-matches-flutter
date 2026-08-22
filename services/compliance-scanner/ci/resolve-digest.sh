#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, digest resolution (Slice 2.2 final correction). Split out
# from push-candidate.sh specifically because this is a READ-ONLY
# operation with no lease-fencing requirement — keeping it separate
# lets push-candidate.sh stay focused on the one MUTATING action it
# performs, and lets this step run on the plain, single-purpose
# gcloud-only builder image rather than the combined ci-builder image
# push-candidate.sh needs for its inline lease check.
#
# Digest captured from Artifact Registry's own record of what was just
# pushed — never assumed from the local build, and never trusted from
# any other step's own output (Mandatory correction 5: "digest files
# cannot be replaced by untrusted step output" — this is the ONLY place
# /workspace/.candidate-digest is ever written, and it is written from
# a fresh `gcloud artifacts docker images describe` call against the
# real registry, not copied from a prior step's claim).
set -eu

: "${PROJECT_ID:?PROJECT_ID is required}"

cd "$(dirname "$0")/.."

REMOTE_TAG="$(cat /workspace/.remote-tag)"

DIGEST=$(gcloud artifacts docker images describe "$REMOTE_TAG" \
  --project="$PROJECT_ID" \
  --format="value(image_summary.digest)")
[ -n "$DIGEST" ] || { echo "failed to resolve pushed image digest"; exit 1; }
echo "$DIGEST" > /workspace/.candidate-digest
echo "resolved digest: ${REMOTE_TAG%:*}@${DIGEST}"
