#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, Stage -1: install the scanner service's own Node
# dependencies (runtime-manifest correction, dependency-provisioning
# fix).
#
# Root cause this closes: acquire-lock.sh, materialize-runtime-manifest.sh
# (via ci/signatureRefreshLock.js / ci/materializeRuntimeManifest.js),
# and verify-fixtures.sh (via ci/fixtureManifest.js) all
# `require("@google-cloud/storage")` before ci/verify-source.sh's own
# `npm ci` — the pipeline's only other install step — ever runs
# (verify-source runs in PARALLEL with, not before, several of them).
# The plain `node:20.18.1-bookworm-slim` image these steps use ships no
# application dependencies of its own, and this repository does not
# commit node_modules (confirmed via `git ls-files` — never a
# gitignore-driven assumption). Nothing therefore guaranteed
# node_modules/@google-cloud/storage existed in /workspace at the point
# any of those steps ran. This script is Cloud Build's first step
# specifically so every later step's require() calls resolve.
#
# --ignore-scripts: verified safe, not assumed. Every one of this
# lockfile's 89 locked packages (package-lock.json, lockfileVersion 3)
# was checked for `hasInstallScript: true` — none exist anywhere in the
# @google-cloud/storage dependency tree, so no package here relies on a
# preinstall/install/postinstall script running. Passed explicitly
# (rather than only relying on there being no scripts to skip) so a
# future dependency bump can't silently reintroduce an install-time
# script this pipeline never intended to execute.
set -eu

cd "$(dirname "$0")/.."

npm ci --ignore-scripts

echo "install-dependencies: node_modules installed from the committed lockfile"
