#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, fenced-lease renewal checkpoint (Slice 2.2 adversarial
# correction, Mandatory correction 2). Invoked as the FIRST action of
# every mutating pipeline phase — candidate push, candidate deployment,
# traffic promotion (and its own rollback), and cleanup — per
# ci/signatureRefreshLock.js's own doc comment on why renewal-at-
# checkpoint (not a background heartbeat) is the correct design for
# Cloud Build's actual step-per-container execution model.
#
# On success: overwrites /workspace/.lock-generation with the NEW
# fencing token, so the calling step's subsequent real mutation (and
# any later step) always fences against the current, just-renewed
# generation — never a stale one.
#
# On failure (this build no longer owns the live lease, for ANY
# reason): exits non-zero immediately. Every caller of this script uses
# `set -e` (or explicit `|| exit 1`) so that failure here always aborts
# the calling step BEFORE its real mutation runs — a lost lease must
# never be followed by a push, a deploy, a traffic shift, or a cleanup
# delete. This is the single enforcement point Mandatory correction 2's
# items 7, 8, 9, and 12 all reduce to.
set -eu

: "${LOCK_BUCKET:?LOCK_BUCKET is required}"
: "${LOCK_OBJECT:?LOCK_OBJECT is required}"
: "${BUILD_ID:?BUILD_ID is required}"
: "${LOCK_LEASE_SECONDS:?LOCK_LEASE_SECONDS is required}"

cd "$(dirname "$0")/.."

HELD_GENERATION="$(cat /workspace/.lock-generation)"

if ! node ci/signatureRefreshLock.js renew \
  --bucket="$LOCK_BUCKET" \
  --object="$LOCK_OBJECT" \
  --build-id="$BUILD_ID" \
  --generation="$HELD_GENERATION" \
  --lease-seconds="$LOCK_LEASE_SECONDS" \
  > /workspace/.lock-renew-result.json 2>/workspace/.lock-renew-error.log
then
  echo "renew-lease-or-fail: LEASE LOST — refusing to proceed with the mutation this checkpoint guards." >&2
  cat /workspace/.lock-renew-error.log >&2
  exit 1
fi

node -e "console.log(JSON.parse(require('fs').readFileSync('/workspace/.lock-renew-result.json')).generation)" \
  > /workspace/.lock-generation

echo "renew-lease-or-fail: renewed, new fencing generation $(cat /workspace/.lock-generation)"
