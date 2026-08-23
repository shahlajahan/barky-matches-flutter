#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, Stage 5: verify the deployed candidate (Slice 2.2
# adversarial correction). Uses MONITORING_SA, an identity distinct
# from compliance-functions-sa and from any human account.
#
# Non-mutating against Cloud Run/Artifact Registry (read-only describe
# calls, plus HTTP requests to the candidate's own tag URL) — does not
# renew the lease. Writes synthetic generation-pinning test objects to
# the fixture bucket under a build-scoped prefix (cleaned up at the end
# of this script), which is a mutation of the SYNTHETIC bucket only,
# never of Cloud Run/Artifact Registry/IAM state, and is therefore not
# one of the five lease-fenced mutating phases Mandatory correction 2
# enumerates.
#
# Builder-image note (Slice 2.2 final correction): this script uses
# ONLY gcloud, curl, and sha256sum — no node, no docker. Fixture
# metadata comes from sourcing /workspace/.fixtures.env, and the
# EICAR fixture's real bytes come from the already-decoded,
# already-hash-verified /workspace/.eicar-materialized.bin — both
# written earlier by ci/verify-fixtures.sh's node-based step. This
# lets this step run on the pinned official Cloud SDK builder image
# (gcloud+curl+sha256sum, no Node) rather than requiring a
# combined-tool image.
set -eu

: "${PROJECT_ID:?PROJECT_ID is required}"
: "${REGION:?REGION is required}"
: "${SERVICE:?SERVICE is required}"
: "${MONITORING_SA:?MONITORING_SA is required}"
: "${SYNTHETIC_TEST_BUCKET:?SYNTHETIC_TEST_BUCKET is required}"
: "${SCANNER_RUNTIME_SA:?SCANNER_RUNTIME_SA is required}"
: "${BUILD_ID:?BUILD_ID is required}"

cd "$(dirname "$0")/.."

[ -f /workspace/.fixtures.env ] || { echo "missing /workspace/.fixtures.env — verify-fixtures-integrity must run and succeed first"; exit 1; }
. /workspace/.fixtures.env
[ -f /workspace/.eicar-materialized.bin ] || { echo "missing /workspace/.eicar-materialized.bin — verify-fixtures-integrity must run and succeed first"; exit 1; }

CANDIDATE_TRAFFIC_TAG="$(cat /workspace/.candidate-traffic-tag)"
DIGEST="$(cat /workspace/.candidate-digest)"

# Candidate URL/revision resolution (Slice 2.2 correction, closing a
# real staging failure — build aa407156-0dea-4ed0-9e85-47354d3bbf3e,
# step verify-deployed-candidate: "could not resolve candidate tag
# URL"). The previous two separate queries each embedded a
# JMESPath-style predicate — `status.traffic[?tag=='...']` — directly
# inside gcloud's own --format resource-key expression. gcloud's
# resource-key language does not support that predicate syntax at all;
# every variant (with or without --flatten) silently resolved to an
# empty string (exit 0, no error) rather than failing loudly — proven
# empirically against the real deployed candidate from build aa407156,
# whose matching traffic entry genuinely existed and was trivially
# resolvable via a plain `--format=json(status.traffic)` read. This
# defect was invisible until now because no earlier build had ever
# reached this step.
#
# Fixed by calling gcloud exactly once for the structured JSON traffic
# array, then resolving BOTH the url and the revisionName from the
# SAME matched entry via ci/resolveCandidateTrafficEntry.py — a
# small, independently-testable helper (see its own doc comment for
# the full validation contract: exactly-one-match required, url must
# be HTTPS with no whitespace/control characters, revisionName must
# match Cloud Run's own safe shape, and the untagged 100%-traffic
# baseline entry is never treated as a fallback). CANDIDATE_TRAFFIC_TAG
# is passed to that helper via the environment, never interpolated
# into Python source or shell-quoted into a command line — a
# maliciously- or accidentally-crafted tag value can only ever be
# compared as inert string data, never alter the match logic or
# execute as code.
CANDIDATE_TRAFFIC_JSON=$(gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" --region="${REGION}" \
  --format="json(status.traffic)")

CANDIDATE_TRAFFIC_RESOLVED=$(printf '%s' "$CANDIDATE_TRAFFIC_JSON" \
  | CANDIDATE_TRAFFIC_TAG="$CANDIDATE_TRAFFIC_TAG" python3 ci/resolveCandidateTrafficEntry.py) \
  || { echo "could not resolve candidate tag URL/revision"; exit 1; }
CANDIDATE_URL=$(printf '%s\n' "$CANDIDATE_TRAFFIC_RESOLVED" | sed -n '1p')
CANDIDATE_REVISION=$(printf '%s\n' "$CANDIDATE_TRAFFIC_RESOLVED" | sed -n '2p')
[ -n "$CANDIDATE_URL" ] || { echo "could not resolve candidate tag URL"; exit 1; }
[ -n "$CANDIDATE_REVISION" ] || { echo "could not resolve candidate revision name"; exit 1; }

# Kept as a SEPARATE variable from CANDIDATE_URL, deliberately never
# derived from it (Slice 2.2 final correction, Mandatory correction 1
# of this pass). Per
# https://docs.cloud.google.com/run/docs/authenticating/service-to-service:
# "If you are not using a custom audience, the aud value must remain as
# the URL of the service, even when making requests to a specific
# traffic tag." status.url is Cloud Run's own base/default service
# URL, distinct from any tag URL — this is what every ID token below is
# audienced for, even though every HTTP request still TARGETS
# CANDIDATE_URL. No custom audience is introduced in this phase.
BASE_SERVICE_URL=$(gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" --region="${REGION}" \
  --format="value(status.url)")
[ -n "$BASE_SERVICE_URL" ] || { echo "could not resolve base service URL"; exit 1; }

# CANDIDATE_REVISION is already resolved above, together with
# CANDIDATE_URL, from the same single gcloud describe call and the
# same matched traffic entry — not re-derived here.

# --- digest and runtime service account verified BEFORE any traffic
#     decision is made, not assumed from the deploy command's own
#     success message (Mandatory correction 3) ---
ACTUAL_IMAGE=$(gcloud run revisions describe "$CANDIDATE_REVISION" \
  --project="${PROJECT_ID}" --region="${REGION}" --format="value(spec.containers[0].image)")
echo "$ACTUAL_IMAGE" | grep -qF "$DIGEST" || { echo "candidate revision image does not match expected digest"; exit 1; }

ACTUAL_SA=$(gcloud run revisions describe "$CANDIDATE_REVISION" \
  --project="${PROJECT_ID}" --region="${REGION}" --format="value(spec.serviceAccountName)")
[ "$ACTUAL_SA" = "${SCANNER_RUNTIME_SA}" ] || { echo "candidate revision runtime SA mismatch: $ACTUAL_SA"; exit 1; }

# Request target = CANDIDATE_URL (the tagged revision). Token audience
# = BASE_SERVICE_URL (never CANDIDATE_URL) — see the note above
# CANDIDATE_URL/BASE_SERVICE_URL's declarations for the authoritative
# source. Two separate variables, never one derived from the other.
TOKEN=$(gcloud auth print-identity-token \
  --impersonate-service-account="${MONITORING_SA}" \
  --audiences="${BASE_SERVICE_URL}")

# authenticated /status
STATUS_CODE=$(curl -s -o /tmp/status.json -w "%{http_code}" \
  -H "Authorization: Bearer ${TOKEN}" "${CANDIDATE_URL}/status")
[ "$STATUS_CODE" = "200" ] || { echo "/status not healthy on candidate: $STATUS_CODE $(cat /tmp/status.json)"; exit 1; }
grep -q '"status":"healthy"' /tmp/status.json || { echo "/status body not healthy: $(cat /tmp/status.json)"; exit 1; }

# missing authentication rejected
NOAUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${CANDIDATE_URL}/status")
[ "$NOAUTH_CODE" = "403" ] || { echo "unauthenticated /status was not rejected: got $NOAUTH_CODE"; exit 1; }

# invalid authentication rejected
BADAUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer not-a-real-token" "${CANDIDATE_URL}/status")
[ "$BADAUTH_CODE" = "401" ] || { echo "invalid /status auth was not rejected: got $BADAUTH_CODE"; exit 1; }

# --- mandatory fixture verdict checks against the REAL deployed
#     candidate (mirrors ci/verify-candidate-container.sh, against the
#     live Cloud Run URL instead of the local container) ---
scan_fixture() {
  fixture_id="$1"
  env_prefix="$2"
  expect_verdict="$3"
  expect_error_code="${4:-}"

  eval "object_path=\$${env_prefix}_OBJECT_PATH"
  eval "generation=\$${env_prefix}_GENERATION"
  eval "sha256=\$${env_prefix}_SHA256"
  eval "size_bytes=\$${env_prefix}_SIZE_BYTES"
  [ -n "$object_path" ] || { echo "missing ${env_prefix}_OBJECT_PATH in /workspace/.fixtures.env"; exit 1; }

  body=$(printf '{"contractVersion":1,"requestId":"ci-%s-deployed-%s","bucket":"%s","objectPath":"%s","generation":"%s","sha256":"%s","sizeBytes":%s}' \
    "$BUILD_ID" "$fixture_id" "$SYNTHETIC_TEST_BUCKET" "$object_path" "$generation" "$sha256" "$size_bytes")
  result=$(curl -fs -X POST -H "Authorization: Bearer ${TOKEN}" -H "content-type: application/json" -d "$body" "${CANDIDATE_URL}/v1/scan")

  echo "$result" | grep -q "\"verdict\":\"${expect_verdict}\"" \
    || { echo "MANDATORY FIXTURE FAILED on deployed candidate (${fixture_id}): expected ${expect_verdict}, got: $result"; exit 1; }
  if [ -n "$expect_error_code" ]; then
    echo "$result" | grep -q "\"errorCode\":\"${expect_error_code}\"" \
      || { echo "MANDATORY FIXTURE FAILED on deployed candidate (${fixture_id}): expected errorCode ${expect_error_code}, got: $result"; exit 1; }
  fi
}

scan_fixture "benign-text" "FIXTURE_BENIGN_TEXT" "clean"
scan_fixture "eicar-standard" "FIXTURE_EICAR_STANDARD" "infected"
scan_fixture "encrypted-pdf" "FIXTURE_ENCRYPTED_PDF" "error" "encrypted_document_unsupported"

# Correction B (read-only review, second pass): computes and validates
# a SHA-256 digest without a `sha256sum | awk` pipeline — the original
# pattern let a failing `sha256sum` (missing/unreadable file) hide
# behind `awk`'s own trivial success on empty input, under the same
# POSIX pipe-exit-status gap Correction A already closed for
# ci/acquire-lock.sh. `sha256sum`'s own exit status is checked directly
# via a plain (non-piped) command substitution — which `set -e`
# correctly catches, exactly as verified for other standalone
# substitutions throughout this pipeline — and the digest is parsed via
# a pure POSIX parameter expansion, never a subprocess. Final
# validation is a `case` pattern match against exactly 64 lowercase hex
# characters — no grep, no pipe, no subprocess at all for this step.
sha256_of() {
  file="$1"
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "sha256_of: file missing or unreadable: $file" >&2
    return 1
  fi

  raw_output=""
  if ! raw_output="$(sha256sum "$file")"; then
    echo "sha256_of: sha256sum failed for $file" >&2
    return 1
  fi
  if [ -z "$raw_output" ]; then
    echo "sha256_of: sha256sum produced empty output for $file" >&2
    return 1
  fi

  # sha256sum's own output format is "<64-hex-digest>  <filename>" —
  # take everything before the first space, no subprocess needed.
  digest="${raw_output%% *}"

  case "$digest" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])
      : # exactly 64 lowercase hex characters — valid
      ;;
    *)
      echo "sha256_of: malformed digest for $file: '$digest'" >&2
      return 1
      ;;
  esac

  echo "$digest"
}

# --- generation-pinning re-verification against the REAL deployed
#     candidate — same technique proven in the Slice 2.1 staging
#     verification: same object path, two generations, pinned reads
#     must distinguish them. Synthetic, build-scoped, cleaned up below.
#
# v1's content is the canonical EICAR bytes — already decoded and
# hash-verified once, earlier, by ci/verify-fixtures.sh's node-based
# step (Mandatory correction 3), and reused here read-only from
# /workspace/.eicar-materialized.bin. This step never decodes anything
# itself and never contains a raw EICAR literal in its own source.
PREFIX="compliance_quarantine/ci-${BUILD_ID}/deployed-verify"
GEN_PATH="${PREFIX}/generation-test.bin"
cp /workspace/.eicar-materialized.bin /tmp/v1.bin
gcloud storage cp /tmp/v1.bin "gs://${SYNTHETIC_TEST_BUCKET}/${GEN_PATH}"
GEN1=$(gcloud storage objects describe "gs://${SYNTHETIC_TEST_BUCKET}/${GEN_PATH}" --format="value(generation)")
printf 'synthetic benign replacement content' > /tmp/v2.bin
gcloud storage cp /tmp/v2.bin "gs://${SYNTHETIC_TEST_BUCKET}/${GEN_PATH}"
GEN2=$(gcloud storage objects describe "gs://${SYNTHETIC_TEST_BUCKET}/${GEN_PATH}" --format="value(generation)")

SHA1="$(sha256_of /tmp/v1.bin)" || exit 1
SIZE1=$(wc -c < /tmp/v1.bin | tr -d ' ')
BODY1=$(printf '{"contractVersion":1,"requestId":"ci-%s-gen1","bucket":"%s","objectPath":"%s","generation":"%s","sha256":"%s","sizeBytes":%s}' \
  "$BUILD_ID" "$SYNTHETIC_TEST_BUCKET" "$GEN_PATH" "$GEN1" "$SHA1" "$SIZE1")
RESULT1=$(curl -fs -X POST -H "Authorization: Bearer ${TOKEN}" -H "content-type: application/json" -d "$BODY1" "${CANDIDATE_URL}/v1/scan")
echo "$RESULT1" | grep -q '"verdict":"infected"' || { echo "generation-pinned read of old (EICAR) generation failed: $RESULT1"; exit 1; }

SHA2="$(sha256_of /tmp/v2.bin)" || exit 1
SIZE2=$(wc -c < /tmp/v2.bin | tr -d ' ')
BODY2=$(printf '{"contractVersion":1,"requestId":"ci-%s-gen2","bucket":"%s","objectPath":"%s","generation":"%s","sha256":"%s","sizeBytes":%s}' \
  "$BUILD_ID" "$SYNTHETIC_TEST_BUCKET" "$GEN_PATH" "$GEN2" "$SHA2" "$SIZE2")
RESULT2=$(curl -fs -X POST -H "Authorization: Bearer ${TOKEN}" -H "content-type: application/json" -d "$BODY2" "${CANDIDATE_URL}/v1/scan")
echo "$RESULT2" | grep -q '"verdict":"clean"' || { echo "generation-pinned read of new (benign) generation failed: $RESULT2"; exit 1; }

gcloud storage rm -a "gs://${SYNTHETIC_TEST_BUCKET}/${GEN_PATH}" || true

echo "verify-deployed-candidate: all checks passed for revision ${CANDIDATE_REVISION} at digest ${DIGEST}"
