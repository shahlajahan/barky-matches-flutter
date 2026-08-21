#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — compliance-scanner
# service, build-time signature refresh (Slice 2.1 correction, part B).
#
# Runs ONLY inside the Dockerfile's build stage — never at container
# request/startup time.
#
# Correction (Slice 2.1 second pass): the original version of this
# script recorded `date -u` — the BUILD MACHINE's own wall clock at the
# moment the script ran — as signatureBuiltAt. That is not what it
# claims to be: it proves only "a script executed at this time", not
# "the signatures we actually shipped were built at this time". A stale
# mirror, a partially-failed freshclam that still leaves usable files
# behind, or simple clock skew between the build host and the real CVD
# build time could all make that claim false while still "looking"
# fresh. This script now derives signatureBuiltAt FROM THE DOWNLOADED
# DATABASE FILE'S OWN METADATA via `sigtool --info` — the authoritative,
# ClamAV-native source of truth for when a given signature database was
# actually built — and fails the build outright rather than shipping an
# image whose freshness claim cannot be proven this way.
set -eu

DB_DIR="/var/lib/clamav"
METADATA_PATH="/opt/clamav-signatures/metadata.json"
# MAX_AGE_HOURS is the single canonical literal this script defines this
# value with — kept as its own plain, directly-parseable assignment
# (Slice 2.1 review correction 1) specifically so a repository test
# (functions/test/complianceSignatureFreshnessConsistency.test.js) can
# extract it deterministically by name and compare it, unit-converted,
# against the independent COMPLIANCE_SIGNATURE_MAX_AGE_MS (Functions)
# and SIGNATURE_MAX_AGE_MS (scanner contract.js) constants — three
# separately-enforced values in three separate deployable units that
# must still agree, with no shared import between any of them at
# runtime or build time. Do not fold this back into an inline
# arithmetic expression; the test parses this exact "MAX_AGE_HOURS="
# line by name.
MAX_AGE_HOURS=48
MAX_AGE_SECONDS=$((MAX_AGE_HOURS * 60 * 60)) # must match COMPLIANCE_SIGNATURE_MAX_AGE_MS (Functions) and SIGNATURE_MAX_AGE_MS (scanner) — verified by the consistency test referenced above, not by comment alone

mkdir -p "$DB_DIR" "$(dirname "$METADATA_PATH")"

echo "compliance-scanner: running freshclam..."
if ! freshclam --datadir="$DB_DIR" --stdout --show-progress; then
  echo "compliance-scanner: BUILD FAILED — freshclam did not complete successfully" >&2
  exit 1
fi

# freshclam may leave either the signed .cvd or an incrementally-patched
# .cld for daily/main — prefer whichever actually exists, and fail if
# neither does (freshclam "succeeding" with no usable database file is
# still a failure for our purposes).
DAILY_DB=""
for candidate in "$DB_DIR/daily.cvd" "$DB_DIR/daily.cld"; do
  if [ -f "$candidate" ]; then
    DAILY_DB="$candidate"
    break
  fi
done
if [ -z "$DAILY_DB" ]; then
  echo "compliance-scanner: BUILD FAILED — no daily.cvd/daily.cld present after freshclam" >&2
  exit 1
fi

MAIN_DB=""
for candidate in "$DB_DIR/main.cvd" "$DB_DIR/main.cld"; do
  if [ -f "$candidate" ]; then
    MAIN_DB="$candidate"
    break
  fi
done
if [ -z "$MAIN_DB" ]; then
  echo "compliance-scanner: BUILD FAILED — no main.cvd/main.cld present after freshclam" >&2
  exit 1
fi

# `sigtool --info` is the authoritative, ClamAV-native way to read a CVD/
# CLD file's own embedded build metadata — never the build host's clock.
SIGTOOL_OUTPUT=$(sigtool --info "$DAILY_DB" 2>&1) || {
  echo "compliance-scanner: BUILD FAILED — sigtool --info could not read $DAILY_DB" >&2
  echo "$SIGTOOL_OUTPUT" >&2
  exit 1
}

# Field label varies slightly across ClamAV releases ("Build time" is
# the documented/common label); match case-insensitively and accept
# either spelling rather than silently guessing on a miss.
RAW_BUILD_TIME=$(printf '%s\n' "$SIGTOOL_OUTPUT" | grep -iE '^(Build time|Builder time)' | head -n1 | cut -d: -f2- | sed 's/^ *//')
if [ -z "$RAW_BUILD_TIME" ]; then
  echo "compliance-scanner: BUILD FAILED — could not parse a build-time field from sigtool --info output" >&2
  echo "$SIGTOOL_OUTPUT" >&2
  exit 1
fi

SIGNATURE_VERSION=$(printf '%s\n' "$SIGTOOL_OUTPUT" | grep -iE '^Version' | head -n1 | cut -d: -f2- | sed 's/^ *//')
if [ -z "$SIGNATURE_VERSION" ]; then
  echo "compliance-scanner: BUILD FAILED — could not parse a version field from sigtool --info output" >&2
  exit 1
fi

# Convert the CVD's own build-time string to strict ISO-8601 UTC.
# Requires GNU date's -d parsing (the Dockerfile installs `coreutils` in
# this stage specifically for this — Alpine's default BusyBox date does
# not reliably parse CVD's "23 Aug 2026 08:00 -0000"-style format).
SIGNATURE_BUILT_AT=$(date -u -d "$RAW_BUILD_TIME" +"%Y-%m-%dT%H:%M:%SZ") || {
  echo "compliance-scanner: BUILD FAILED — could not parse build-time value '$RAW_BUILD_TIME' as a date" >&2
  exit 1
}

# Fail closed at BUILD time too, not only at runtime: if the database we
# just fetched is already older than the freshness budget (a broken or
# stale mirror), do not ship it — better a failed build than a container
# that starts already unhealthy.
BUILT_AT_EPOCH=$(date -u -d "$SIGNATURE_BUILT_AT" +%s)
NOW_EPOCH=$(date -u +%s)
AGE_SECONDS=$((NOW_EPOCH - BUILT_AT_EPOCH))
if [ "$AGE_SECONDS" -lt 0 ]; then
  echo "compliance-scanner: BUILD FAILED — parsed signature build time is in the future ($SIGNATURE_BUILT_AT)" >&2
  exit 1
fi
if [ "$AGE_SECONDS" -gt "$MAX_AGE_SECONDS" ]; then
  echo "compliance-scanner: BUILD FAILED — fetched signatures are already stale at build time (built $SIGNATURE_BUILT_AT, ${AGE_SECONDS}s old, budget ${MAX_AGE_SECONDS}s)" >&2
  exit 1
fi

ENGINE_VERSION=$(clamscan --version | awk '{print $2}')
if [ -z "$ENGINE_VERSION" ]; then
  echo "compliance-scanner: BUILD FAILED — could not determine clamscan engine version" >&2
  exit 1
fi

cat > "$METADATA_PATH" <<EOF
{
  "signatureBuiltAt": "${SIGNATURE_BUILT_AT}",
  "engineVersion": "clamav-${ENGINE_VERSION}",
  "signatureVersion": "${SIGNATURE_VERSION}"
}
EOF

echo "compliance-scanner: signature metadata recorded — built ${SIGNATURE_BUILT_AT} (engine ${ENGINE_VERSION}, daily version ${SIGNATURE_VERSION}), age ${AGE_SECONDS}s"
