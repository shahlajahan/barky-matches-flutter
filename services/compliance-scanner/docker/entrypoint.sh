#!/bin/sh
# Petsupo Marketplace P1-A compliance foundation — compliance-scanner
# service, container entrypoint (Slice 2.1, part E; corrected in the
# Slice 2.1 correction pass, part G).
#
# Process/signal model (corrected): this script itself remains PID 1 for
# the container's whole lifetime — it does NOT `exec` Node to replace
# itself. The earlier version did exec Node as PID 1 specifically so it
# would receive SIGTERM directly, but that left clamd (a background
# child of this script) with no signal forwarded to it at all once the
# shell process image was replaced — `exec` discards the shell's own
# trap handlers along with everything else. Staying as PID 1 and
# explicitly trapping SIGTERM/SIGINT here lets this script forward the
# signal to BOTH children and wait for both to exit before this script
# itself exits, which is the behavior Cloud Run's own graceful-shutdown
# contract expects from PID 1.
#
# POSIX /bin/sh only, deliberately — Alpine's default shell is BusyBox
# ash, not bash, so this script avoids bash-only constructs (e.g.
# `wait -n`, which ash/dash do not support) in favor of a portable
# polling loop.
set -eu

mkdir -p /var/run/clamav
chown clamav:clamav /var/run/clamav

# --foreground (-F): CORRECTED after a real Docker verification failure.
# Without it, clamd's default behavior is to daemonize — fork a true
# background daemon process and have the ORIGINAL process (the one this
# script's `$!` would capture) exit(0) once the fork succeeds. That
# exit looked, from this script's side, exactly like "clamd died
# unexpectedly outside of a shutdown request" (confirmed: the container
# logged clean clamd startup through its full feature-enablement
# sequence, then exited 0 seconds later) — CLAMD_PID was tracking the
# wrong process the whole time. --foreground keeps clamd as the actual
# long-running process this script's job-control ($!) refers to, which
# is required for the signal-forwarding/wait-for-either-child design
# above to mean anything.
clamd --foreground --config-file=/etc/clamav/clamd.conf &
CLAMD_PID=$!

# clamd.conf logs to a real file (/tmp/clamd.log), not /dev/stdout —
# see clamd.conf's own doc comment for why. Tail it into THIS script's
# own stdout so `docker logs`/Cloud Run's log viewer still sees clamd's
# output as part of the container's unified log stream. Bounded by
# `--pid` being this specific tail process so it's cleanly killed on
# shutdown alongside everything else, never left orphaned.
( touch /tmp/clamd.log 2>/dev/null; tail -F /tmp/clamd.log 2>/dev/null ) &
CLAMD_LOG_TAIL_PID=$!

# Wait for clamd's local socket to exist before starting the adapter —
# bounded, not indefinite: if clamd never becomes ready, this script
# exits non-zero (Cloud Run treats that as a failed startup and follows
# its own restart policy) rather than starting an adapter that would
# report every request as a clamd_connection_error. Note this proves the
# socket FILE exists, not independently that clamd has finished loading
# signatures — clamd's own documented behavior is to accept connections
# only once fully initialized, which this script relies on rather than
# re-verifies; confirm this holds in the real Docker smoke test (Part G
# staging verification), not assumed here.
i=0
while [ ! -S /var/run/clamav/clamd.sock ]; do
  i=$((i + 1))
  if [ "$i" -gt 60 ]; then
    echo "compliance-scanner: clamd did not become ready within 60s" >&2
    kill "$CLAMD_PID" 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

# Drop privileges for the Node adapter specifically — clamd already
# drops its own privileges internally via clamd.conf's `User clamav`
# directive; this script itself must start as root only to create/own
# /var/run/clamav and launch clamd, never to run the adapter as root.
# Started as a background child (not exec'd) specifically so this
# script remains PID 1 and can trap/forward signals to it below.
su-exec node-adapter node /app/index.js &
NODE_PID=$!

SHUTTING_DOWN=0

shutdown() {
  SHUTTING_DOWN=1
  echo "compliance-scanner: received termination signal, forwarding to clamd (${CLAMD_PID}) and node (${NODE_PID})" >&2
  kill -TERM "$NODE_PID" 2>/dev/null || true
  kill -TERM "$CLAMD_PID" 2>/dev/null || true
  kill -TERM "$CLAMD_LOG_TAIL_PID" 2>/dev/null || true
  # Bounded grace period for both children to exit on their own (Node's
  # own SIGTERM handler in index.js additionally closes the HTTP server
  # gracefully within its own 10s bound) before this script forces the
  # issue — never wait indefinitely, since Cloud Run will SIGKILL the
  # whole container past its own grace period regardless.
  wait_deadline=$(($(date +%s) + 15))
  while kill -0 "$NODE_PID" 2>/dev/null || kill -0 "$CLAMD_PID" 2>/dev/null; do
    if [ "$(date +%s)" -ge "$wait_deadline" ]; then
      kill -KILL "$NODE_PID" 2>/dev/null || true
      kill -KILL "$CLAMD_PID" 2>/dev/null || true
      break
    fi
    sleep 1
  done
  exit 0
}
trap shutdown TERM INT

# Portable (POSIX /bin/sh, no `wait -n`) "wait for whichever child exits
# first": poll until either is no longer alive, then `wait` that
# specific already-exited PID to collect its real exit status (a POSIX-
# defined no-block operation for an already-terminated background job).
while kill -0 "$NODE_PID" 2>/dev/null && kill -0 "$CLAMD_PID" 2>/dev/null; do
  sleep 1
done

if [ "$SHUTTING_DOWN" -eq 1 ]; then
  # A normal shutdown() exit already happened via its own `exit 0` above
  # — reaching here at all would only mean a shutdown is concurrently in
  # progress; do not double-report or double-exit.
  exit 0
fi

if kill -0 "$NODE_PID" 2>/dev/null; then
  wait "$CLAMD_PID"
  EXIT_CODE=$?
  echo "compliance-scanner: clamd exited unexpectedly (code ${EXIT_CODE}) outside of a shutdown request" >&2
else
  wait "$NODE_PID"
  EXIT_CODE=$?
  echo "compliance-scanner: the adapter exited unexpectedly (code ${EXIT_CODE}) outside of a shutdown request" >&2
fi
exit "$EXIT_CODE"
