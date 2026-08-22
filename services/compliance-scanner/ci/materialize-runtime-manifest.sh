#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, environment-specific runtime fixture-manifest materialization
# (Slice 2.2 runtime-manifest correction).
#
# Runs BEFORE ci/verify-fixtures.sh (see this pipeline's own waitFor
# graph in cloudbuild.signature-refresh.yaml). Downloads the REAL,
# environment-specific fixture manifest (real, non-sentinel GCS
# generations for benign-text/eicar-standard/encrypted-pdf) from a
# validated `gs://` URI at an EXACT, pinned generation, and writes it to
# a single fixed, pipeline-owned /workspace path.
#
# services/compliance-scanner/ci/fixtureManifest.json — the committed,
# environment-neutral manifest — is never read, written, or referenced
# by this script. It stays exactly as committed, still failing closed
# on its own PENDING_PROVISIONING sentinels if anything ever tried to
# use it directly for a real run (see that file's own comments and
# ci/verify-fixtures.sh, which reads the fixed path this script
# produces, never the committed file, for a real pipeline run).
#
# The output path (RUNTIME_FIXTURE_MANIFEST_OUT) is always a plain,
# fixed literal set by cloudbuild.signature-refresh.yaml's own `env:`
# list for this step — never a Cloud Build substitution — so no
# operator-supplied value can redirect where this gets written.
#
# Builder-image note: pure Node — ci/materializeRuntimeManifest.js uses
# @google-cloud/storage directly, no gcloud CLI needed. Runs on the
# plain, single-purpose official node image, same as ci/acquire-lock.sh
# and ci/verify-fixtures.sh.
set -eu

: "${RUNTIME_FIXTURE_MANIFEST_GCS_URI:?RUNTIME_FIXTURE_MANIFEST_GCS_URI is required}"
: "${RUNTIME_FIXTURE_MANIFEST_GENERATION:?RUNTIME_FIXTURE_MANIFEST_GENERATION is required}"
: "${SYNTHETIC_TEST_BUCKET:?SYNTHETIC_TEST_BUCKET is required}"
: "${RUNTIME_FIXTURE_MANIFEST_OUT:?RUNTIME_FIXTURE_MANIFEST_OUT is required}"

cd "$(dirname "$0")/.."

node ci/materializeRuntimeManifest.js \
  --uri="$RUNTIME_FIXTURE_MANIFEST_GCS_URI" \
  --generation="$RUNTIME_FIXTURE_MANIFEST_GENERATION" \
  --synthetic-bucket="$SYNTHETIC_TEST_BUCKET" \
  --out="$RUNTIME_FIXTURE_MANIFEST_OUT"

echo "materialize-runtime-manifest: runtime fixture manifest materialized to ${RUNTIME_FIXTURE_MANIFEST_OUT}"
