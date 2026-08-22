#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — signature-refresh
# pipeline, Stage 2a: source-level unit tests and static checks (Slice
# 2.2 adversarial correction). Runs against the checked-out SOURCE,
# independent of the built image or any live GCP resource — the
# strongest "locally verified" category: deterministic, no network.
set -eu

cd "$(dirname "$0")/.."

npm ci
node --test test/ ci/*.test.js

# Node syntax check across every .js file in this service.
find . -name node_modules -prune -o -name '*.js' -print | xargs -n1 node --check

# Shell syntax check across every .sh file this service ships.
find . -name node_modules -prune -o -name '*.sh' -print | xargs -n1 sh -n
