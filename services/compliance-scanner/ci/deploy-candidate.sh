#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, Stage 4: deploy a zero-traffic candidate revision (Slice 2.2
# adversarial correction, Mandatory correction 3). MUTATING — renews
# the lease first.
#
# Records the COMPLETE pre-existing traffic allocation (every
# revision/percent/tag entry Cloud Run reports right now), not merely
# "the one presumed previous revision" — a service can legitimately be
# split across multiple revisions (e.g. a manual canary already in
# progress) at the moment this pipeline runs, and promote.sh's rollback
# must be able to restore that exact state, not a simplified guess.
#
# Builder-image note (Slice 2.2 final correction): needs gcloud AND
# node together (the inline lease-renewal check) — runs on
# ci/Dockerfile.ci-builder's image, for the same reason documented in
# ci/push-candidate.sh's own comment.
set -eu

: "${PROJECT_ID:?PROJECT_ID is required}"
: "${REGION:?REGION is required}"
: "${SERVICE:?SERVICE is required}"
: "${SCANNER_RUNTIME_SA:?SCANNER_RUNTIME_SA is required}"
: "${COMMIT_SHA:?COMMIT_SHA is required}"
: "${BUILD_ID:?BUILD_ID is required}"

cd "$(dirname "$0")/.."

sh ci/renew-lease-or-fail.sh

DIGEST="$(cat /workspace/.candidate-digest)"
REGION_HOST="${REGION}-docker.pkg.dev"
IMAGE_REF="${REGION_HOST}/${PROJECT_ID}/${REPOSITORY:?REPOSITORY is required}/${IMAGE_NAME:?IMAGE_NAME is required}@${DIGEST}"

# Deterministic, short, DNS-label-safe candidate tag.
SHORT_BUILD_ID=$(echo "${BUILD_ID}" | cut -c1-8)
CANDIDATE_TRAFFIC_TAG="candidate-${COMMIT_SHA}-${SHORT_BUILD_ID}"
echo "$CANDIDATE_TRAFFIC_TAG" > /workspace/.candidate-traffic-tag

# Full pre-existing traffic allocation, captured BEFORE this deploy
# touches anything — the exact state promote.sh must be able to restore
# verbatim on rollback. Cloud Run's own --format=json(status.traffic)
# already reports every revisionName/percent/tag entry, not just the
# first one.
gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" --region="${REGION}" \
  --format="json(status.traffic)" \
  > /workspace/.previous-traffic-allocation.json
echo "recorded full pre-existing traffic allocation:"
cat /workspace/.previous-traffic-allocation.json

# --no-traffic + --tag: a real, addressable, isolated Cloud Run traffic-
# tag URL for the candidate, receiving ZERO production/staging traffic.
# --tag does not modify the service's IAM policy in any way — it is
# purely a routing mechanism; the service's existing run.invoker
# binding (never touched by this pipeline) continues to gate every URL
# variant of this service identically. No --allow-unauthenticated
# anywhere in this pipeline, this script included.
gcloud run deploy "${SERVICE}" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --image="${IMAGE_REF}" \
  --service-account="${SCANNER_RUNTIME_SA}" \
  --no-allow-unauthenticated \
  --no-traffic \
  --tag="${CANDIDATE_TRAFFIC_TAG}"

gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" --region="${REGION}" \
  --format="value(status.traffic)" | grep -q "$CANDIDATE_TRAFFIC_TAG" \
  || { echo "candidate revision did not receive its expected traffic tag"; exit 1; }
