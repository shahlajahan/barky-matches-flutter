#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, Stage 6: promote, with fenced, self-contained rollback
# (Slice 2.2 adversarial correction, Mandatory corrections 2 & 3).
#
# Renews the lease before EACH traffic mutation below (the initial
# promotion shift, and — separately — the conditional rollback shift,
# if reached) — not just once at the top of this script — per
# Mandatory correction 2's explicit "rollback-related mutation" fencing
# requirement.
#
# Never assumes the prior revision held 100% traffic: restores the
# COMPLETE traffic allocation captured by ci/deploy-candidate.sh
# (/workspace/.previous-traffic-allocation.json), which may legitimately
# span multiple revisions/tags.
#
# Never removes the candidate's own traffic tag — tag removal is not
# part of this pipeline at all, avoiding any risk of that operation
# altering the serving revision.
#
# Builder-image note (Slice 2.2 final correction): this script uses
# gcloud, python3, AND node — never docker. Runs on the combined
# ci-builder image (ci/Dockerfile.ci-builder), the same reasoning as
# ci/push-candidate.sh and ci/deploy-candidate.sh: it must verify the
# fenced concurrency lease (node, via ci/renew-lease-or-fail.sh) and
# perform its own gcloud mutation within the same script. The two
# small JSON manipulations below (reconstructing --to-revisions from
# the captured full allocation, and verifying a rollback actually
# restored it) use python3's stdlib json module — unrelated to, and
# unaffected by, the candidate-traffic resolver correction elsewhere in
# this file, which uses the canonical Node resolver
# (ci/resolveCandidateTrafficEntry.js — see below).
set -eu

: "${PROJECT_ID:?PROJECT_ID is required}"
: "${REGION:?REGION is required}"
: "${SERVICE:?SERVICE is required}"

cd "$(dirname "$0")/.."

DIGEST="$(cat /workspace/.candidate-digest)"
CANDIDATE_TRAFFIC_TAG="$(cat /workspace/.candidate-traffic-tag)"

# Candidate revision resolution (Slice 2.2 correction — shares the
# exact same fix and root cause as ci/verify-deployed-candidate.sh's
# own correction; see that file's doc comment for the full defect
# history: build aa407156-0dea-4ed0-9e85-47354d3bbf3e proved gcloud's
# --format resource-key language does not support the JMESPath-style
# embedded predicate `status.traffic[?tag=='...']` this script
# previously used here too. Never exercised in a real build — no build
# had ever reached promote.sh — but it is the IDENTICAL construction,
# confirmed via the same live read-only reproduction).
#
# Uses ci/resolveCandidateTrafficEntry.js (Node) — the ONE canonical
# candidate-traffic resolver this entire pipeline uses; no second
# implementation exists anywhere in this repository (single-
# authoritative-resolver correction). This step already runs on the
# combined ci-builder image (needed here for the inline lease-renewal
# check, which requires node), which is confirmed to bundle node —
# so this consumer, like verify-deployed-candidate.sh, invokes the
# canonical Node resolver rather than maintaining a separate port.
# An earlier version of this correction rewrote this logic in Node
# specifically so it could be behaviorally tested with zero process
# spawns from pipelineStatic.test.js (which runs on the node-only
# node:20.18.1-bookworm-slim image verify-source uses), while
# verify-deployed-candidate.sh temporarily kept a separate Python port
# because its own image at the time lacked node. That split was a
# real semantic-drift risk — two independently-maintained
# implementations of the same fail-closed security check, with
# nothing proving they stayed in sync — so verify-deployed-candidate.sh
# was moved onto this same ci-builder image instead, and its Python
# port was deleted. The resolver's validation contract (exactly-one-
# match required, url must be HTTPS with no whitespace/control
# characters, revisionName must match Cloud Run's own safe shape, no
# fallback to the untagged baseline or any other entry) now exists in
# exactly one place.
#
# CANDIDATE_TRAFFIC_TAG is passed via the environment, never
# interpolated into source or a command line. The helper also returns
# the matched entry's url; this script has no further use for it
# beyond the resolution itself, but both lines are read and validated
# here so a malformed or partially-invalid resolver response can never
# silently supply only a "looks fine" revisionName.
CANDIDATE_TRAFFIC_JSON=$(gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" --region="${REGION}" \
  --format="json(status.traffic)")

CANDIDATE_TRAFFIC_RESOLVED=$(printf '%s' "$CANDIDATE_TRAFFIC_JSON" \
  | CANDIDATE_TRAFFIC_TAG="$CANDIDATE_TRAFFIC_TAG" node ci/resolveCandidateTrafficEntry.js) \
  || { echo "could not resolve candidate tag URL/revision"; exit 1; }
CANDIDATE_URL=$(printf '%s\n' "$CANDIDATE_TRAFFIC_RESOLVED" | sed -n '1p')
CANDIDATE_REVISION=$(printf '%s\n' "$CANDIDATE_TRAFFIC_RESOLVED" | sed -n '2p')
[ -n "$CANDIDATE_URL" ] || { echo "could not resolve candidate tag URL"; exit 1; }
[ -n "$CANDIDATE_REVISION" ] || { echo "could not resolve candidate revision name"; exit 1; }

# Convert the captured full traffic allocation JSON into a
# --to-revisions=rev1=pct1,rev2=pct2,... argument, exactly restoring
# every entry that existed before this pipeline touched anything —
# never a simplified "one revision at 100%" guess.
PREVIOUS_TO_REVISIONS=$(python3 -c "
import json, sys
with open('/workspace/.previous-traffic-allocation.json') as f:
    data = json.load(f)
traffic = (data.get('status') or {}).get('traffic') or []
parts = [f\"{t['revisionName']}={t['percent']}\" for t in traffic if t.get('revisionName') and isinstance(t.get('percent'), (int, float))]
if not parts:
    print('no prior traffic allocation captured — refusing to promote without a provable rollback target', file=sys.stderr)
    sys.exit(1)
print(','.join(parts))
")
echo "recorded rollback target: ${PREVIOUS_TO_REVISIONS}"

critical_terminal_failure() {
  # Rollback itself failed — the most severe failure mode this pipeline
  # can reach. Loud, distinctive, and preserves everything: does not
  # delete logs, does not attempt cleanup, does not release the lease
  # (it expires naturally per ci/signatureRefreshLock.js's documented
  # crash-recovery design — no non-expiring lock, no manual unlock
  # needed, but also nothing here masks or discards the failure state
  # for a human investigating it).
  echo "###############################################################" >&2
  echo "# CRITICAL TERMINAL FAILURE — ROLLBACK ITSELF FAILED           #" >&2
  echo "# Service:            ${SERVICE}" >&2
  echo "# Candidate revision: ${CANDIDATE_REVISION} (digest ${DIGEST})" >&2
  echo "# Intended rollback:  ${PREVIOUS_TO_REVISIONS}" >&2
  echo "# Manual intervention required — traffic state is NOT confirmed" >&2
  echo "# to be either the candidate or the prior known-good allocation." >&2
  echo "###############################################################" >&2
  exit 3
}

# --- fenced promotion shift ---
sh ci/renew-lease-or-fail.sh

gcloud run services update-traffic "${SERVICE}" \
  --project="${PROJECT_ID}" --region="${REGION}" \
  --to-revisions="${CANDIDATE_REVISION}=100"

# Re-verify the SERVING state from the COMPLETE traffic array, never a
# fixed array index (traffic-array-ordering correction, closing a real
# staging failure — build c2fdcda9-1b0a-4e88-8f90-760a6ad32a5b, step
# promote: "PROMOTION VERIFICATION FAILED", despite the just-promoted
# revision's own digest and runtime SA both being independently
# confirmed correct). Root cause: the previous version of this check
# read `status.traffic[0].revisionName` / `.percent` — a fixed numeric
# index — to identify "the currently serving revision". Cloud Run's own
# API does NOT guarantee the newly-100%-revision appears at index 0
# once other tagged, zero-percent entries also exist in the array; this
# defect was invisible until this exact build because no earlier build
# had ever reached promote.sh with more than a trivial one-entry
# traffic array (5 pre-existing tagged candidates were present at the
# time, and gcloud's own human-readable traffic listing that build
# printed the 100% entry LAST, not first — direct empirical
# confirmation the index assumption was wrong).
#
# Fixed by fetching status.traffic ONCE as structured JSON (the same
# `--format="json(status.traffic)"` shape already used above for the
# candidate resolver, and already proven safe — gcloud's own --format
# resource-key language does not support embedded predicates like
# `[?tag==...]`, so this is a plain, unfiltered structural read, not a
# query), then verifying SEMANTIC IDENTITY — never array position — via
# a small inline Node check: exactly one traffic entry has percent==100
# AND that entry's revisionName equals CANDIDATE_REVISION, AND no other
# entry has positive (>0) traffic. This introduces no new interpreter,
# package, or file: promote.sh already runs on the combined ci-builder
# image and already invokes `node` for the candidate resolver and the
# fenced lease check above. CANDIDATE_REVISION and the traffic JSON are
# passed as separate argv values (process.argv[1]/[2]), never
# interpolated into the script source, exactly like
# ci/resolveCandidateTrafficEntry.js's own env-var-only input
# discipline elsewhere in this pipeline.
SERVING_TRAFFIC_JSON=$(gcloud run services describe "${SERVICE}" \
  --project="${PROJECT_ID}" --region="${REGION}" \
  --format="json(status.traffic)")

PROMOTION_OK=1
if ! PROMOTION_TRAFFIC_CHECK=$(node -e '
"use strict";
let parsed;
try {
  parsed = JSON.parse(process.argv[1]);
} catch (err) {
  console.error("status.traffic is not valid JSON");
  process.exit(1);
}
const candidateRevision = process.argv[2] || "";
if (!candidateRevision) {
  console.error("CANDIDATE_REVISION argument is required");
  process.exit(1);
}
const traffic = parsed && parsed.status && Array.isArray(parsed.status.traffic) ? parsed.status.traffic : null;
if (!traffic) {
  console.error("status.traffic is missing or not an array");
  process.exit(1);
}
const positive = traffic.filter((t) => t && typeof t === "object" && typeof t.percent === "number" && t.percent > 0);
const servingCandidate = positive.filter((t) => t.percent === 100 && t.revisionName === candidateRevision);
const otherPositive = positive.filter((t) => !(t.percent === 100 && t.revisionName === candidateRevision));
if (servingCandidate.length !== 1) {
  console.error("expected exactly one traffic entry at 100% for " + candidateRevision + ", found " + servingCandidate.length);
  process.exit(1);
}
if (otherPositive.length !== 0) {
  console.error("unexpected additional positive-traffic entries: " + JSON.stringify(otherPositive));
  process.exit(1);
}
' -- "$SERVING_TRAFFIC_JSON" "$CANDIDATE_REVISION" 2>&1); then
  PROMOTION_OK=0
  echo "promotion traffic verification failed: ${PROMOTION_TRAFFIC_CHECK}" >&2
fi

SERVING_IMAGE=$(gcloud run revisions describe "$CANDIDATE_REVISION" \
  --project="${PROJECT_ID}" --region="${REGION}" --format="value(spec.containers[0].image)")
SERVING_SA=$(gcloud run revisions describe "$CANDIDATE_REVISION" \
  --project="${PROJECT_ID}" --region="${REGION}" --format="value(spec.serviceAccountName)")

if ! echo "$SERVING_IMAGE" | grep -qF "$DIGEST"; then PROMOTION_OK=0; fi
if [ "$SERVING_SA" != "${SCANNER_RUNTIME_SA:?SCANNER_RUNTIME_SA is required}" ]; then PROMOTION_OK=0; fi

if [ "$PROMOTION_OK" = "0" ]; then
  echo "PROMOTION VERIFICATION FAILED — restoring prior traffic allocation" >&2

  # Fenced AGAIN, separately, immediately before the rollback mutation
  # itself — not reusing the fencing check performed before the
  # promotion shift above.
  if ! sh ci/renew-lease-or-fail.sh; then
    critical_terminal_failure
  fi

  if ! gcloud run services update-traffic "${SERVICE}" \
    --project="${PROJECT_ID}" --region="${REGION}" \
    --to-revisions="${PREVIOUS_TO_REVISIONS}"
  then
    critical_terminal_failure
  fi

  # Verify the ROLLBACK actually took effect too — a rollback command
  # that reports success but did not truly restore traffic is exactly
  # as dangerous as a promotion that silently didn't happen.
  RESTORED=$(gcloud run services describe "${SERVICE}" \
    --project="${PROJECT_ID}" --region="${REGION}" \
    --format="json(status.traffic)")
  RESTORED_OK=$(python3 -c "
import json, sys
expected = []
for p in '${PREVIOUS_TO_REVISIONS}'.split(','):
    r, pct = p.split('=')
    expected.append({'revisionName': r, 'percent': int(pct)})
data = json.loads(sys.argv[1])
actual = [t for t in (data.get('status') or {}).get('traffic') or [] if t.get('revisionName') and isinstance(t.get('percent'), (int, float))]
matches = all(any(a['revisionName'] == e['revisionName'] and a['percent'] == e['percent'] for a in actual) for e in expected) and len(actual) == len(expected)
print('true' if matches else 'false')
" "$RESTORED")
  if [ "$RESTORED_OK" != "true" ]; then
    critical_terminal_failure
  fi

  echo "rollback confirmed: traffic restored to ${PREVIOUS_TO_REVISIONS}" >&2
  exit 1
fi

echo "promoted: ${SERVICE} now serving ${CANDIDATE_REVISION} at ${SERVING_IMAGE} (SA ${SERVING_SA})"
echo "rollback target preserved (not deleted): ${PREVIOUS_TO_REVISIONS}"

# Correction C (read-only review, second pass): the promoted-tag
# mutation below is itself a real Artifact Registry write and was
# previously relying on the renewal performed before the traffic shift
# at the top of this script — several read-only `gcloud describe` calls
# earlier. Every cloud mutation must be immediately preceded by its own
# successful renewal, not inherit one from an earlier point in the
# script, so a THIRD, independent fence check runs here, immediately
# before the tag mutation, using whatever generation is currently
# persisted in /workspace/.lock-generation (the promotion shift's own
# renewal result) and overwriting it again with the freshly-renewed
# generation on success — never reusing a stale value. If this renewal
# is refused, the tag mutation must not run at all; the overall build
# still correctly reports success for the traffic promotion itself
# (already verified and serving), but the promoted-tag bookkeeping is
# skipped and loudly reported rather than silently attempted under a
# lease this build may no longer hold.
if ! sh ci/renew-lease-or-fail.sh; then
  echo "###############################################################" >&2
  echo "# LEASE LOST IMMEDIATELY BEFORE PROMOTED-TAG MUTATION          #" >&2
  echo "# Traffic promotion itself already succeeded and is unaffected #" >&2
  echo "# by this — but the promoted- tag was NOT applied. Artifact    #" >&2
  echo "# Registry retention/cleanup tooling will not yet recognize    #" >&2
  echo "# this digest as protected until an operator applies the tag   #" >&2
  echo "# manually or a later run does so under its own valid lease.   #" >&2
  echo "# Digest: ${DIGEST}" >&2
  echo "###############################################################" >&2
  exit 1
fi

# Apply the stable "promoted-" tag the Artifact Registry cleanup policy
# (ci/artifact-registry-cleanup-policy.template.json) relies on to
# distinguish real releases from failed/unpromoted "candidate-" tags —
# applied only now, after traffic has been verified actually serving
# from this digest AND after the fresh renewal immediately above
# succeeded, never earlier.
PROMOTED_TAG="promoted-${COMMIT_SHA:?COMMIT_SHA is required}-${BUILD_ID:?BUILD_ID is required}"
gcloud artifacts docker tags add \
  --project="${PROJECT_ID}" \
  "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY:?REPOSITORY is required}/${IMAGE_NAME:?IMAGE_NAME is required}@${DIGEST}" \
  "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${PROMOTED_TAG}"
