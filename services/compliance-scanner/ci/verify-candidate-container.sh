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
#
# ---------------------------------------------------------------------
# Network correction (Slice 2.2, closing a real staging build failure —
# build eb02b226-1f41-4029-a748-1a7d69810a4b, step
# verify-candidate-container: "candidate container never became
# healthy"). Root cause: this script previously published the candidate
# on the host with `-p 18080:8080` and polled it via
# `http://127.0.0.1:18080`. Under Cloud Build's actual nested-Docker
# execution model, `gcr.io/cloud-builders/docker` runs `docker` commands
# against the SAME Docker daemon the build's own step containers run
# under (via the mounted docker.sock) — so `127.0.0.1` inside THIS
# step's own container never reliably reaches a `-p`-published port on
# a SIBLING container the daemon started on the build VM's host network
# stack. The container's own internal logs proved it became fully
# healthy (clamd initialized, Node adapter logged server_started) well
# within the old 60-second budget — the defect was never readiness
# timing, only address reachability. Confirmed via Google's documented
# Cloud Build pattern for nested containers: every Cloud Build step
# container, AND every container a step's own `docker run` starts, is
# already attached to a predefined Docker network literally named
# `cloudbuild` — containers on that network resolve each other by
# --name over Docker's embedded DNS, with no host port publishing
# needed at all. This script now runs the candidate on that network
# under a unique, Docker-safe container name and addresses it ONLY by
# that name — never 127.0.0.1, localhost, host.docker.internal, a
# bridge-gateway guess, or a scraped host IP.
# ---------------------------------------------------------------------
set -eu

: "${SYNTHETIC_TEST_BUCKET:?SYNTHETIC_TEST_BUCKET is required}"
: "${BUILD_ID:?BUILD_ID is required}"

cd "$(dirname "$0")/.."

[ -f /workspace/.fixtures.env ] || { echo "missing /workspace/.fixtures.env — verify-fixtures-integrity must run and succeed first"; exit 1; }
. /workspace/.fixtures.env

IMAGE_LOCAL="$(cat /workspace/.image-local-ref)"

# The predefined Docker network Cloud Build attaches every step
# container (and every container a step's own `docker run` starts) to.
# A fixed literal, never a substitution — see the correction note above.
CLOUDBUILD_NETWORK="cloudbuild"

# Fail closed with a precise diagnostic if the expected network is
# missing, rather than silently falling back to a host-published port
# or any other reachable-but-wrong address.
if ! docker network inspect "$CLOUDBUILD_NETWORK" >/dev/null 2>&1; then
  echo "verify-candidate-container: the expected '${CLOUDBUILD_NETWORK}' Docker network does not exist in this build environment — refusing to fall back to a host-published port or localhost. This step requires Cloud Build's predefined nested-container network." >&2
  exit 1
fi

# Docker-safe, unique-per-build container name. BUILD_ID is a Cloud
# Build built-in substitution (a system-generated UUID), not
# operator-supplied text, but this still normalizes it defensively to
# the exact character class Docker container names accept
# ([a-zA-Z0-9][a-zA-Z0-9_.-]*) rather than trusting its content
# unconditionally — no other value is interpolated into this name.
SAFE_BUILD_ID=$(printf '%s' "$BUILD_ID" | tr -c 'a-zA-Z0-9_.-' '-')
CONTAINER_NAME="verify-candidate-${SAFE_BUILD_ID}"

# The ONE place the candidate's address is constructed. Every later
# request (health, status, every fixture scan) derives from this same
# variable, so no individual request can drift to a different address.
CANDIDATE_BASE_URL="http://${CONTAINER_NAME}:8080"

docker run -d --name "$CONTAINER_NAME" \
  --network="$CLOUDBUILD_NETWORK" \
  --platform linux/amd64 \
  --read-only \
  --tmpfs /tmp:rw,size=64m \
  --tmpfs /var/run/clamav:rw,size=8m \
  --cap-drop ALL \
  --cap-add CHOWN --cap-add SETUID --cap-add SETGID --cap-add DAC_OVERRIDE \
  -e COMPLIANCE_BUCKET_NAME="${SYNTHETIC_TEST_BUCKET}" \
  "$IMAGE_LOCAL" >/dev/null

# Cleanup removes ONLY this exact, uniquely-named container — never a
# broader match, never another build's container (CONTAINER_NAME is
# derived from THIS build's own BUILD_ID) — and never touches any
# image. Bounded log tail (never the full, unbounded history) so a
# long-running candidate can't flood the build log. Runs on every exit
# path: normal completion, any `exit 1` below, or a signal.
cleanup() {
  docker logs --tail 200 "$CONTAINER_NAME" 2>&1 || true
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

# Maps a curl exit code to a compact, human-readable failure category —
# diagnostic only, never a behavioral branch. See `man curl` (EXIT
# CODES) for the authoritative meaning of each number.
curl_exit_category() {
  case "$1" in
    0) echo "ok" ;;
    6) echo "could_not_resolve_host" ;;
    7) echo "could_not_connect" ;;
    28) echo "timeout" ;;
    52) echo "empty_reply" ;;
    56) echo "recv_error" ;;
    *) echo "other:$1" ;;
  esac
}

# On final failure only (never on every attempt, to keep the loop's own
# output compact): bounded, non-sensitive diagnostics proving WHERE the
# failure sits — container state, network attachment, and an
# in-container reachability probe — without ever printing
# credentials, Authorization headers, signed URLs, manifest contents,
# or fixture contents. Response BODIES are deliberately never printed
# here, even from the safe, sanitized /healthz endpoint — only pass/
# fail signals.
dump_candidate_diagnostics() {
  echo "verify-candidate-container: diagnostics for ${CONTAINER_NAME} on network ${CLOUDBUILD_NETWORK}" >&2
  docker inspect \
    --format 'state={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}(no healthcheck){{end}}' \
    "$CONTAINER_NAME" 2>&1 || echo "verify-candidate-container: docker inspect (state) failed" >&2
  docker inspect \
    --format 'networks={{range $net,$cfg := .NetworkSettings.Networks}}{{$net}}:{{$cfg.IPAddress}} {{end}}' \
    "$CONTAINER_NAME" 2>&1 || echo "verify-candidate-container: docker inspect (networks) failed" >&2
  # In-container reachability probe — reuses the exact tool the
  # Dockerfile's own HEALTHCHECK instruction already relies on
  # (wget, always present in this image for that reason), run via
  # `docker exec` so it observes the app from inside the candidate's
  # own network namespace. Only the exit code is reported, never the
  # response body.
  if docker exec "$CONTAINER_NAME" wget -q -O /dev/null "http://127.0.0.1:8080/healthz" 2>/dev/null; then
    echo "verify-candidate-container: in-container probe (127.0.0.1:8080/healthz from inside the candidate) succeeded — the app IS listening; the failure is therefore in reaching it over the ${CLOUDBUILD_NETWORK} network, not in app readiness" >&2
  else
    echo "verify-candidate-container: in-container probe (127.0.0.1:8080/healthz from inside the candidate) also failed — the app itself may not be listening yet" >&2
  fi
  # One final, bounded verbose connectivity attempt against the exact
  # address every real request used. This request carries no
  # credentials, Authorization header, or signed URL of any kind (none
  # of this script's requests ever do), but the verbose stream is still
  # filtered defensively for the header/token strings a future request
  # type could introduce, and the response BODY is discarded — only
  # connection-level lines (connect/resolve/TLS/HTTP status) matter
  # here.
  curl -v -s -o /dev/null -m 5 "${CANDIDATE_BASE_URL}/healthz" 2>&1 \
    | grep -viE 'Authorization:|Bearer |set-cookie:' \
    | tail -n 20 >&2 || true
}

# Bounded health-check wait — never indefinite. Per-attempt diagnostics
# are compact and non-sensitive: attempt number, curl's own exit code,
# the HTTP status when one was actually received, and a derived failure
# category — never a response body.
ok=""
attempt=0
consecutive_ok=0
for _ in $(seq 1 30); do
  attempt=$((attempt + 1))
  # set +e/-e bracketing is required here, not cosmetic: under `set -e`,
  # an assignment whose value is a failing command substitution
  # (`http_code=$(curl ...)` when curl exits non-zero, e.g. connection
  # refused) aborts the script immediately at that line — `curl_exit=$?`
  # below would never run, and this loop could never see or report a
  # single retry. Confirmed empirically via local topology testing,
  # which is exactly the class of bug this correction exists to guard
  # against structurally, not just describe.
  set +e
  http_code=$(curl -s -o /tmp/healthz.json -w '%{http_code}' "${CANDIDATE_BASE_URL}/healthz" 2>/tmp/healthz-curl-stderr.log)
  curl_exit=$?
  set -e
  if [ "$curl_exit" -eq 0 ] && [ "$http_code" = "200" ]; then
    # Require TWO consecutive successful polls, not just one, before
    # declaring the candidate ready — discovered by local topology
    # testing: clamd can accept a connection and answer one healthz
    # probe right at the exact edge of its own startup, then have the
    # very next probe (e.g. this script's own subsequent /status check,
    # a real request moments later) transiently fail while it finishes
    # settling. This debounces exactly that boundary, still within the
    # same fixed 30-attempt/60s bound — never a longer overall wait,
    # never an address change, and it cannot mask a candidate that
    # never becomes reliably healthy (a single flap after this point
    # would surface as a real failure on the next real request, not be
    # hidden).
    consecutive_ok=$((consecutive_ok + 1))
    if [ "$consecutive_ok" -ge 2 ]; then
      ok=1
      break
    fi
    sleep 1
    continue
  fi
  consecutive_ok=0
  echo "verify-candidate-container: healthz attempt ${attempt}/30: curl_exit=${curl_exit} ($(curl_exit_category "$curl_exit")) http_status=${http_code:-none}" >&2
  sleep 2
done
if [ -z "$ok" ]; then
  echo "candidate container never became healthy" >&2
  dump_candidate_diagnostics
  exit 1
fi
grep -q '"status":"healthy"' /tmp/healthz.json || { echo "candidate /healthz reported unhealthy: $(cat /tmp/healthz.json)"; exit 1; }

# Confirmation that the Node/clamd process and socket expectations
# hold — the same signals already validated during Slice 2.1's real
# Docker verification.
#
# Pattern correction (discovered by local topology testing, not a
# network defect): this previously grepped for the literal substring
# `event=server_started` (key=value form), but src/logger.js
# (createLogger's `write()`) always serializes via
# `JSON.stringify({ level, ...safe, ts })` — real output is JSON, e.g.
# `{"level":"info","event":"server_started","ts":"..."}`, which never
# contains an `event=server_started` substring at all. This check could
# therefore never have matched, in any environment — it simply was
# never exercised before, because every prior build attempt failed
# earlier, at the (now-fixed) network-unreachable healthz loop above,
# so this line never actually ran against real candidate output until
# now. Corrected to the real JSON substring, `"event":"server_started"`
# — level is always serialized first and event always immediately
# after it (see logger.js's fixed `{ level, ...safe, ts }` field order),
# so this exact substring is stable, not dependent on JSON
# key-ordering being coincidental.
#
# Kept as a short, bounded retry (3 attempts, 1s apart) purely as
# ordinary defense against `docker logs`' own async capture of
# container stdout potentially lagging a real write by a small amount
# — not a timeout increase for the network reachability check above,
# and not what was masking this check; it stays bounded and cannot mask
# a candidate that genuinely never started.
server_started_ok=""
for _ in 1 2 3; do
  if docker logs "$CONTAINER_NAME" 2>&1 | grep -q '"event":"server_started"'; then
    server_started_ok=1
    break
  fi
  sleep 1
done
[ -n "$server_started_ok" ] || { echo "node adapter did not report server_started"; exit 1; }

# /status must be reachable and byte-identical to /healthz — the same
# IAM-gated surface /v1/scan uses (Slice 2.2, Phase 2).
curl -fs "${CANDIDATE_BASE_URL}/status" > /tmp/status.json
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
  result=$(curl -fs -X POST -H "content-type: application/json" -d "$body" "${CANDIDATE_BASE_URL}/v1/scan")

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
