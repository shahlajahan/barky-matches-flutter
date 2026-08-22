#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, Stage 2b: local candidate container verification (Slice 2.2
# adversarial correction, Mandatory correction 1). Runs the FRESHLY
# BUILT, NOT YET PUSHED image under the same hardened posture already
# proven in the Slice 2.1 local Docker verification (--read-only, tmpfs
# /tmp, tmpfs /var/run/clamav, --cap-drop ALL plus the four
# empirically-required capabilities).
#
# Uses the manifest-pinned fixtures (already integrity-verified by
# ci/verify-fixtures.sh — this script does not re-verify their
# existence/hash/generation, only their SCAN VERDICT) rather than
# uploading fresh disposable content. The container performs its own
# generation-pinned GCS download internally via its normal /v1/scan
# handling — this script only constructs the request body from the
# manifest and checks the response.
#
# REQUIRES the container to have real GCS credentials available
# (Application Default Credentials reachable from inside the nested
# docker container running within this Cloud Build step) to read the
# fixture bucket — this specific credential-passthrough mechanism is
# NOT proven by this script and REQUIRES STAGING EXECUTION to confirm;
# see the Slice 2.2 correction report.
#
# Builder-image note (Slice 2.2 final correction): this script uses
# ONLY docker and curl — no gcloud, no node. Fixture metadata comes
# from sourcing /workspace/.fixtures.env, written earlier by
# ci/verify-fixtures.sh's node-based step; this step never invokes
# `node` itself. This lets this step run on the pinned official Docker
# builder image (which does not include Node) rather than requiring a
# combined-tool image — see cloudbuild.signature-refresh.yaml's own
# builder-image inventory comment for the full per-step mapping.
set -eu

: "${SYNTHETIC_TEST_BUCKET:?SYNTHETIC_TEST_BUCKET is required}"
: "${BUILD_ID:?BUILD_ID is required}"

cd "$(dirname "$0")/.."

[ -f /workspace/.fixtures.env ] || { echo "missing /workspace/.fixtures.env — verify-fixtures-integrity must run and succeed first"; exit 1; }
. /workspace/.fixtures.env

IMAGE_LOCAL="$(cat /workspace/.image-local-ref)"
CONTAINER_NAME="signature-refresh-candidate-${BUILD_ID}"

docker run -d --name "$CONTAINER_NAME" \
  --platform linux/amd64 \
  --read-only \
  --tmpfs /tmp:rw,size=64m \
  --tmpfs /var/run/clamav:rw,size=8m \
  --cap-drop ALL \
  --cap-add CHOWN --cap-add SETUID --cap-add SETGID --cap-add DAC_OVERRIDE \
  -p 18080:8080 \
  -e COMPLIANCE_BUCKET_NAME="${SYNTHETIC_TEST_BUCKET}" \
  "$IMAGE_LOCAL"

cleanup() { docker logs "$CONTAINER_NAME" || true; docker rm -f "$CONTAINER_NAME" || true; }
trap cleanup EXIT

# Internal /healthz check — bounded wait, never indefinite.
ok=""
for _ in $(seq 1 30); do
  if curl -fs "http://127.0.0.1:18080/healthz" > /tmp/healthz.json; then ok=1; break; fi
  sleep 2
done
[ -n "$ok" ] || { echo "candidate container never became healthy"; exit 1; }
grep -q '"status":"healthy"' /tmp/healthz.json || { echo "candidate /healthz reported unhealthy: $(cat /tmp/healthz.json)"; exit 1; }

# Confirmation that the Node/clamd process and socket expectations
# hold — the same signals already validated during Slice 2.1's real
# Docker verification.
docker logs "$CONTAINER_NAME" 2>&1 | grep -q "event=server_started" \
  || { echo "node adapter did not report server_started"; exit 1; }

# /status must be reachable and byte-identical to /healthz — the same
# IAM-gated surface /v1/scan uses (Slice 2.2, Phase 2).
curl -fs "http://127.0.0.1:18080/status" > /tmp/status.json
diff /tmp/healthz.json /tmp/status.json || { echo "/status diverged from /healthz"; exit 1; }

# --- mandatory fixture verdict checks, against manifest-pinned real
#     GCS objects (already integrity-verified by verify-fixtures.sh) ---
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

  body=$(printf '{"contractVersion":1,"requestId":"ci-%s-%s","bucket":"%s","objectPath":"%s","generation":"%s","sha256":"%s","sizeBytes":%s}' \
    "$BUILD_ID" "$fixture_id" "$SYNTHETIC_TEST_BUCKET" "$object_path" "$generation" "$sha256" "$size_bytes")
  result=$(curl -fs -X POST -H "content-type: application/json" -d "$body" "http://127.0.0.1:18080/v1/scan")

  echo "$result" | grep -q "\"verdict\":\"${expect_verdict}\"" \
    || { echo "MANDATORY FIXTURE FAILED (${fixture_id}): expected verdict ${expect_verdict}, got: $result"; exit 1; }
  if [ -n "$expect_error_code" ]; then
    echo "$result" | grep -q "\"errorCode\":\"${expect_error_code}\"" \
      || { echo "MANDATORY FIXTURE FAILED (${fixture_id}): expected errorCode ${expect_error_code}, got: $result"; exit 1; }
  fi
  echo "fixture ${fixture_id}: verdict OK"
}

scan_fixture "benign-text" "FIXTURE_BENIGN_TEXT" "clean"
scan_fixture "eicar-standard" "FIXTURE_EICAR_STANDARD" "infected"
# Encrypted-document fixture is MANDATORY — no warn-and-skip. Absence,
# integrity mismatch, or wrong verdict here fails the build exactly
# like the other two (Mandatory correction 1's core requirement).
scan_fixture "encrypted-pdf" "FIXTURE_ENCRYPTED_PDF" "error" "encrypted_document_unsupported"

# --- scan/log safety check ---
docker logs "$CONTAINER_NAME" 2>&1 > /tmp/container.log
for forbidden in "$SYNTHETIC_TEST_BUCKET" "compliance_quarantine/ci-fixtures"; do
  if grep -qF "$forbidden" /tmp/container.log; then
    echo "candidate container logs leaked sensitive content: $forbidden"; exit 1
  fi
done
