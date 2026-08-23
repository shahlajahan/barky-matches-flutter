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

# Deterministic, short, DNS-label-safe candidate tag (Slice 2.2
# correction, closing a real staging deploy failure — build
# c90ebe89-5c04-424b-abaa-16bb25e7db6f: "traffic tag
# 'candidate-<40-char COMMIT_SHA>-<8-char BUILD_ID>' and service name
# 'compliance-scanner' together are too long. Combined traffic tag and
# service name cannot exceed 46 characters"). The FULL COMMIT_SHA is
# used everywhere else this pipeline needs it — the pushed image tag
# (push-candidate.sh's ${COMMIT_SHA}-${BUILD_ID}), the promoted
# Artifact Registry tag (promote.sh's promoted-${COMMIT_SHA}-
# ${BUILD_ID}, a Docker tag with a 128-character limit, nowhere near
# this constraint) — only the Cloud Run traffic tag specifically needs
# shortening, because Cloud Run's combined service-name+tag limit (46
# chars) is far tighter than Artifact Registry's. This is the ONLY
# place CANDIDATE_TRAFFIC_TAG is constructed; promote.sh and
# verify-deployed-candidate.sh both read it back verbatim from
# /workspace/.candidate-traffic-tag, so whatever valid string ends up
# there is what those steps use too — no other file needs a change.
#
# Both COMMIT_SHA and BUILD_ID are validated against their real,
# well-formed shapes BEFORE truncation — a malformed value fails
# closed here, immediately, rather than being silently sliced into a
# plausible-looking but meaningless tag fragment (the same
# case-pattern-match technique verify-deployed-candidate.sh's own
# sha256_of() already uses for exactly this reason — see that
# function's doc comment).
case "$COMMIT_SHA" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
    : # exactly 40 lowercase hex characters — a well-formed git SHA-1
    ;;
  *)
    echo "deploy-candidate: COMMIT_SHA is not a well-formed 40-character lowercase hex git SHA: '${COMMIT_SHA}'" >&2
    exit 1
    ;;
esac
case "$BUILD_ID" in
  [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
    : # Cloud Build's own well-formed UUID shape for BUILD_ID
    ;;
  *)
    echo "deploy-candidate: BUILD_ID is not a well-formed UUID: '${BUILD_ID}'" >&2
    exit 1
    ;;
esac

SHORT_COMMIT_SHA=$(printf '%s' "$COMMIT_SHA" | cut -c1-8)
SHORT_BUILD_ID=$(printf '%s' "$BUILD_ID" | cut -c1-8)
CANDIDATE_TRAFFIC_TAG="candidate-${SHORT_COMMIT_SHA}-${SHORT_BUILD_ID}"

# Enforce Cloud Run's documented combined service-name + traffic-tag
# limit locally, BEFORE ever invoking gcloud — fail closed with a
# clear, actionable diagnostic instead of letting gcloud's own remote
# validation surface a cryptic mid-deploy error, exactly the failure
# mode this correction closes.
CANDIDATE_TAG_COMBINED_LENGTH=$((${#SERVICE} + ${#CANDIDATE_TRAFFIC_TAG}))
if [ "$CANDIDATE_TAG_COMBINED_LENGTH" -gt 46 ]; then
  echo "deploy-candidate: combined service name ('${SERVICE}', ${#SERVICE} chars) and traffic tag ('${CANDIDATE_TRAFFIC_TAG}', ${#CANDIDATE_TRAFFIC_TAG} chars) = ${CANDIDATE_TAG_COMBINED_LENGTH} characters, exceeding Cloud Run's 46-character combined limit" >&2
  exit 1
fi

# Audit trail: the full, untruncated identifiers remain available in
# this step's own logs (Cloud Build's own log capture, not a separate
# file) even though the traffic tag itself is shortened.
echo "deploy-candidate: full COMMIT_SHA=${COMMIT_SHA} full BUILD_ID=${BUILD_ID} candidate traffic tag=${CANDIDATE_TRAFFIC_TAG} (${CANDIDATE_TAG_COMBINED_LENGTH}/46 chars combined with service name '${SERVICE}')"

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
