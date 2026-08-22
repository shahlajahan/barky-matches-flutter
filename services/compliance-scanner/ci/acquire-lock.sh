#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, Stage 0 (Slice 2.2 adversarial correction). Extracted from
# the Cloud Build YAML per Mandatory correction 5, so it can be
# syntax-checked (`sh -n`) and reasoned about independently of the YAML.
#
# Reads its configuration from plain shell environment variables (set
# via the Cloud Build step's own `env:` list, which is where any
# ${_SUBSTITUTION} -> real value resolution happens) — this script
# itself never contains a Cloud Build substitution token, eliminating
# any $ / ${...} / $$ collision between Cloud Build's own substitution
# syntax and this script's shell syntax.
#
# Builder-image note (Slice 2.2 final correction): pure Node —
# ci/signatureRefreshLock.js uses @google-cloud/storage directly, no
# gcloud CLI needed. Runs on the plain, single-purpose official node
# image.
set -eu

: "${LOCK_BUCKET:?LOCK_BUCKET is required}"
: "${LOCK_OBJECT:?LOCK_OBJECT is required}"
: "${BUILD_ID:?BUILD_ID is required}"
: "${LOCK_LEASE_SECONDS:?LOCK_LEASE_SECONDS is required}"

cd "$(dirname "$0")/.."

# Correction A (read-only review, second pass): the original
# `node ... | tee /workspace/.lock-result.json` pattern let a refused
# acquisition (node exits 1, writes only to stderr) hide behind `tee`'s
# own always-successful exit code — under plain POSIX `set -eu` (no
# `pipefail` in dash/sh), only the LAST command in a pipe determines
# whether `set -e` aborts, so the real failure was masked and only
# surfaced later as a confusing secondary JSON-parse crash on an empty
# file. Corrected to the same safe, non-piped idiom
# ci/renew-lease-or-fail.sh already uses: redirect stdout/stderr to
# separate temp files, check the command's OWN exit status directly via
# `if !`, and only ever materialize /workspace/.lock-result.json on
# confirmed success — a refused/failed acquisition never produces a
# partial or empty result file, and the script exits immediately with
# the real stderr reason (e.g. live_lease_held) preserved, never
# proceeding to JSON parsing.
ACQUIRE_STDOUT="/workspace/.lock-acquire-stdout.tmp"
ACQUIRE_STDERR="/workspace/.lock-acquire-stderr.tmp"
rm -f "$ACQUIRE_STDOUT" "$ACQUIRE_STDERR" /workspace/.lock-result.json

if ! node ci/signatureRefreshLock.js acquire \
  --bucket="$LOCK_BUCKET" \
  --object="$LOCK_OBJECT" \
  --build-id="$BUILD_ID" \
  --lease-seconds="$LOCK_LEASE_SECONDS" \
  > "$ACQUIRE_STDOUT" 2>"$ACQUIRE_STDERR"
then
  echo "acquire-lock: ACQUISITION FAILED — refusing to proceed to result parsing." >&2
  cat "$ACQUIRE_STDERR" >&2
  rm -f "$ACQUIRE_STDOUT" "$ACQUIRE_STDERR"
  exit 1
fi

# Only reached on confirmed success — the result file is materialized
# at its canonical path exactly once, here, never as a byproduct of a
# failed attempt.
mv "$ACQUIRE_STDOUT" /workspace/.lock-result.json
rm -f "$ACQUIRE_STDERR"
cat /workspace/.lock-result.json

node -e "console.log(JSON.parse(require('fs').readFileSync('/workspace/.lock-result.json')).generation)" \
  > /workspace/.lock-generation

echo "acquire-lock: fencing generation $(cat /workspace/.lock-generation) held by build ${BUILD_ID}"
