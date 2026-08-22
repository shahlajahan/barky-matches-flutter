#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, mandatory security-fixture integrity gate (Slice 2.2
# adversarial correction, Mandatory correction 1).
#
# Checks EXISTENCE, GENERATION, real downloaded-content SHA-256, and
# SIZE of every required fixture (ci/fixtureManifest.js's
# REQUIRED_FIXTURE_IDS) against ci/fixtureManifest.json. A missing,
# generation-mismatched, hash-mismatched, or size-mismatched mandatory
# fixture exits non-zero here, which — via this step's `waitFor`
# position in cloudbuild.signature-refresh.yaml — makes candidate push,
# deployment, and promotion structurally unreachable: no later step
# runs at all once this one fails.
#
# This step deliberately does NOT upload, create, or regenerate any
# fixture — see ci/fixtureManifest.js's own doc comment for why doing
# so mid-pipeline would validate nothing. Fixtures are provisioned
# exactly once by a separate, documented process (see the readiness
# doc); this step only proves what is ALREADY there still matches.
#
# The VERDICT half of fixture verification (does this fixture actually
# scan the way the manifest expects) requires a running scanner and
# therefore happens later, as part of ci/verify-candidate-container.sh
# and ci/verify-deployed-candidate.sh — both of which re-use these same
# manifest-pinned, already-integrity-checked fixtures rather than
# generating their own.
#
# Builder-image note (Slice 2.2 final correction): pure Node —
# ci/fixtureManifest.js uses @google-cloud/storage directly, no gcloud
# CLI needed. This step also writes /workspace/.fixtures.env and
# /workspace/.eicar-materialized.bin for later, node-free steps to
# consume (see ci/fixtureManifest.js's own doc comment). Runs on the
# plain, single-purpose official node image.
set -eu

: "${SYNTHETIC_TEST_BUCKET:?SYNTHETIC_TEST_BUCKET is required}"

cd "$(dirname "$0")/.."

node ci/fixtureManifest.js \
  --bucket="$SYNTHETIC_TEST_BUCKET" \
  --manifest=ci/fixtureManifest.json
