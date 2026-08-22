#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, final cleanup stage (Slice 2.2 adversarial correction).
# Renews (proving live ownership) BEFORE releasing — a build whose
# lease was already lost must not attempt to release someone else's
# live lease (Mandatory correction 2, item 12: "cleanup cannot run
# under a lost lease").
#
# Builder-image note (Slice 2.2 final correction): pure Node — both the
# renewal check and the release call go through
# ci/signatureRefreshLock.js, which uses @google-cloud/storage directly
# (not the gcloud CLI binary — see that file's own doc comment). No
# gcloud, no docker needed for this step at all; runs on the plain,
# single-purpose official node image.
set -eu

: "${LOCK_BUCKET:?LOCK_BUCKET is required}"
: "${LOCK_OBJECT:?LOCK_OBJECT is required}"
: "${BUILD_ID:?BUILD_ID is required}"
: "${LOCK_LEASE_SECONDS:?LOCK_LEASE_SECONDS is required}"

cd "$(dirname "$0")/.."

sh ci/renew-lease-or-fail.sh

HELD_GENERATION="$(cat /workspace/.lock-generation)"

node ci/signatureRefreshLock.js release \
  --bucket="$LOCK_BUCKET" \
  --object="$LOCK_OBJECT" \
  --build-id="$BUILD_ID" \
  --generation="$HELD_GENERATION"
