"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// signature-refresh pipeline, FENCED concurrency lock (Slice 2.2,
// corrected per the adversarial review — Mandatory correction 2).
//
// This module is split deliberately into two halves:
//   1. Pure decision functions (decideAcquisition/decideRenewal/
//      decideRelease) — no GCP access, no I/O, fully deterministic,
//      fully unit-testable without a live bucket. This is the
//      "locally verified" half — signatureRefreshLock.test.js exercises
//      ONLY this half.
//   2. A thin CLI wrapper (only reached via `require.main === module`)
//      that performs the actual atomic GCS operations via
//      `@google-cloud/storage` directly (file.save()/file.delete() with
//      `preconditionOpts: { ifGenerationMatch: ... }`) — NOT by
//      shelling out to the `gcloud` CLI binary; see this file's own
//      CLI-section comment further down for why (builder-image
//      resolution: this keeps the runtime requirement to "Node.js +
//      this package's node_modules", nothing else). This half requires
//      a real bucket and is explicitly "requires later staging
//      execution" — no local test exercises it, and nothing in this
//      repository claims otherwise (see the Slice 2.2 correction
//      report's honesty-language section).
//
// ---------------------------------------------------------------------
// Fencing model (corrected design — read before changing)
// ---------------------------------------------------------------------
// The GCS object GENERATION returned by a successful acquire/renew IS
// the fencing token, full stop — not a separate random value. This is
// deliberate: GCS already guarantees generations are unique,
// monotonically increasing per object, and unforgeable by anything
// other than a successful conditional write. A separate "unpredictable
// lease token" field would only duplicate a weaker version of a
// guarantee GCS already provides for free, and would introduce a class
// of bug (token stored inconsistently with the generation it was meant
// to represent) that using the generation directly cannot have.
//
// The lock object's OWN JSON body also carries the generation the
// holder most recently wrote it at (`fencingGeneration`), purely for
// human-readable audit/debugging — the CLI's actual atomicity NEVER
// trusts this self-reported field; every acquire/renew/release always
// re-reads the object's real GCS generation immediately beforehand and
// uses THAT as the precondition. Two values existing (JSON field vs.
// real GCS generation) is intentional defense: if they were ever to
// disagree, that itself is evidence of tampering or a bug, not
// something either half of this module treats as authoritative on its
// own.
//
// Renewal-before-mutation, not a background heartbeat: this design
// deliberately does NOT run a persistent background renewal process.
// Cloud Build steps are separate container invocations — a heartbeat
// started in one step cannot reliably persist into, or be cleanly
// killed by, a later step, and an improperly-managed background process
// is exactly the failure mode the corrected design must avoid. Instead,
// every MUTATING pipeline phase (push, deploy, promote/rollback,
// cleanup) calls `renew` as its OWN first action, synchronously, before
// doing anything else. `renew` atomically (a) verifies this exact build
// still owns the CURRENT live lease (buildId AND generation both must
// match — an old, superseded generation can never renew, even if it
// carries the same buildId string) and (b) extends the expiry, in one
// conditional write. If renewal is refused for any reason, the caller
// must fail closed immediately and MUST NOT proceed to the mutation it
// was about to perform — see cloudbuild.signature-refresh.yaml's
// push-candidate/deploy-candidate/promote/release-lock steps, each of
// which calls `renew` before its own gcloud/docker mutation and treats
// a non-zero exit from `renew` as fatal.
//
// Provable timing relationship (documented here, enforced in the YAML):
// each successful renewal grants a fresh window of `leaseSeconds`
// (recommended 900s / 15 minutes — tight enough to bound staleness
// after a crash, loose enough that no single mutating step should ever
// approach it under normal conditions). Every mutating Cloud Build step
// (push-candidate, deploy-candidate, promote, release-lock) has an
// EXPLICIT per-step `timeout:` of 600s (10 minutes) in the YAML — a
// step that somehow runs longer than that is killed by Cloud Build
// itself before it could ever approach the 900s lease window granted at
// that step's own start. 600s < 900s with a real, stated 300s margin —
// this is the "explicitly proven relationship" the corrected design
// requires, not an assumption.
//
// Crash recovery unchanged from the original design: a build that
// acquires or renews the lock and then crashes outright (container
// killed, never reaches its own next renewal or release) leaves the
// lock in place with a finite `expiresAt`. Any later build's
// acquisition attempt correctly classifies it as "steal" once
// `now > expiresAt` — automatic, no manual intervention, no
// non-expiring lock, no "list running builds and hope" heuristic.

const LOCK_SCHEMA_VERSION = 2; // bumped: v1 lock objects lack fencingGeneration

/**
 * @param {object} args
 * @param {{ buildId: string, acquiredAt: string, expiresAt: string, leaseSeconds: number, schemaVersion?: number } | null} args.existingLock
 *   Parsed content of the existing lock object, or null if the object
 *   does not currently exist (a 404 on read).
 * @param {number | null} args.existingGeneration
 *   The GCS object generation the existing lock content was read at, or
 *   null if the object does not exist. Required whenever existingLock
 *   is non-null.
 * @param {Date} args.now
 * @param {string} args.buildId Unique identifier for THIS build attempt
 *   (Cloud Build's own $BUILD_ID is the intended value in production).
 * @param {number} args.leaseSeconds Finite lease duration this build
 *   would request if it acquires the lock. Must be a positive integer.
 * @returns {
 *   | { action: "create", newLock: object }
 *   | { action: "steal", expectedGeneration: number, newLock: object }
 *   | { action: "refuse", reason: "live_lease_held", heldBy: string, expiresAt: string }
 *   | { action: "refuse", reason: "invalid_lease_seconds" }
 * }
 */
function decideAcquisition({ existingLock, existingGeneration, now, buildId, leaseSeconds }) {
  if (!Number.isInteger(leaseSeconds) || leaseSeconds <= 0) {
    return { action: "refuse", reason: "invalid_lease_seconds" };
  }

  const nowIso = now.toISOString();
  const expiresAtIso = new Date(now.getTime() + leaseSeconds * 1000).toISOString();
  const newLock = {
    schemaVersion: LOCK_SCHEMA_VERSION,
    buildId,
    acquiredAt: nowIso,
    renewedAt: nowIso,
    expiresAt: expiresAtIso,
    leaseSeconds,
    // Self-reported only — see this file's top-of-file comment on why
    // the CLI half never trusts this field for real atomicity decisions.
    fencingGeneration: existingGeneration === null ? null : existingGeneration,
  };

  if (existingLock === null) {
    return { action: "create", newLock };
  }

  const existingExpiresAtMs = Date.parse(existingLock.expiresAt);
  const isExpired = !Number.isFinite(existingExpiresAtMs) || existingExpiresAtMs <= now.getTime();

  if (!isExpired) {
    return {
      action: "refuse",
      reason: "live_lease_held",
      heldBy: existingLock.buildId,
      expiresAt: existingLock.expiresAt,
    };
  }

  if (typeof existingGeneration !== "number" || !Number.isFinite(existingGeneration)) {
    // Defensive — a caller bug, not a real-world GCS state. An expired
    // lock we cannot cite a generation for cannot be safely stolen.
    return {
      action: "refuse",
      reason: "live_lease_held",
      heldBy: existingLock.buildId,
      expiresAt: existingLock.expiresAt,
    };
  }

  return { action: "steal", expectedGeneration: existingGeneration, newLock };
}

/**
 * Fenced renewal — the core of the corrected design. Must be called by
 * every mutating pipeline phase, synchronously, as its own first
 * action, before that phase's real mutation. Verifies ownership
 * (buildId) AND fencing (the exact generation this build believes it
 * currently holds) before ever agreeing to extend the lease. Neither
 * check alone is sufficient — see the "same buildId, stale generation"
 * and "different buildId entirely" test cases in
 * signatureRefreshLock.test.js for why both are required.
 *
 * @param {object} args
 * @param {{ buildId: string, expiresAt: string } | null} args.existingLock
 * @param {number | null} args.existingGeneration
 * @param {string} args.buildId The build attempting to renew.
 * @param {number} args.heldGeneration The fencing token (generation)
 *   this build currently believes it holds — from its own most recent
 *   successful acquire or renew.
 * @param {Date} args.now
 * @param {number} args.leaseSeconds
 * @returns {
 *   | { action: "renew", expectedGeneration: number, newLock: object }
 *   | { action: "refuse", reason: "lease_lost" }
 *   | { action: "refuse", reason: "not_owner", heldBy: string }
 *   | { action: "refuse", reason: "generation_mismatch" }
 *   | { action: "refuse", reason: "invalid_lease_seconds" }
 * }
 */
function decideRenewal({ existingLock, existingGeneration, buildId, heldGeneration, now, leaseSeconds }) {
  if (!Number.isInteger(leaseSeconds) || leaseSeconds <= 0) {
    return { action: "refuse", reason: "invalid_lease_seconds" };
  }

  if (existingLock === null) {
    // The lock object is simply gone — released, expired-and-reclaimed-
    // and-since-released, or otherwise vanished. This build's lease is
    // categorically lost; it must fail closed, never treat "no lock
    // object" as "no problem".
    return { action: "refuse", reason: "lease_lost" };
  }

  if (existingLock.buildId !== buildId) {
    // A DIFFERENT build's identity now occupies the path — our lease
    // was reclaimed (we were too slow, or we crashed and were declared
    // expired). Fencing: we must never renew, and the caller must never
    // proceed to mutate anything after this refusal.
    return { action: "refuse", reason: "not_owner", heldBy: existingLock.buildId };
  }

  if (existingGeneration !== heldGeneration) {
    // Same buildId, but the live object's generation does not match
    // what this exact process believes it holds. This is the fencing
    // check that catches the specific case a buildId-only check would
    // miss: an OLD, superseded copy of the same build's own logic
    // (e.g. two overlapping invocations sharing a manually-fixed
    // buildId, or a stale in-memory generation from before some other
    // renewal already happened) can never renew or act as though it
    // still holds the current, live lease.
    return { action: "refuse", reason: "generation_mismatch" };
  }

  const nowIso = now.toISOString();
  const newLock = {
    schemaVersion: LOCK_SCHEMA_VERSION,
    buildId,
    acquiredAt: existingLock.acquiredAt,
    renewedAt: nowIso,
    expiresAt: new Date(now.getTime() + leaseSeconds * 1000).toISOString(),
    leaseSeconds,
    fencingGeneration: heldGeneration,
  };

  return { action: "renew", expectedGeneration: heldGeneration, newLock };
}

/**
 * @param {object} args
 * @param {{ buildId: string, acquiredAt: string, expiresAt: string } | null} args.existingLock
 * @param {number | null} args.existingGeneration
 * @param {string} args.buildId The build attempting the release.
 * @param {number} args.heldGeneration The generation THIS build believes
 *   it holds the lock at (returned from its own most recent successful
 *   acquire or renew).
 * @returns {
 *   | { action: "release", expectedGeneration: number }
 *   | { action: "noop", reason: "already_gone" }
 *   | { action: "refuse", reason: "not_owner", heldBy: string }
 *   | { action: "refuse", reason: "generation_mismatch" }
 * }
 */
function decideRelease({ existingLock, existingGeneration, buildId, heldGeneration }) {
  if (existingLock === null) {
    // Already released, expired-and-stolen, or never existed — nothing
    // for this build to do. Not an error: a build racing its own
    // deferred cleanup against an already-completed release must not
    // fail loudly for this.
    return { action: "noop", reason: "already_gone" };
  }

  if (existingLock.buildId !== buildId) {
    // Someone else's lease now occupies this path (our own expired,
    // was stolen, and the new holder hasn't finished yet). We must
    // never touch it. This is also the "cleanup under a lost lease"
    // guard: the release-lock step MUST call `renew` first (per this
    // file's top-of-file comment) and abort before ever reaching this
    // release call if renewal itself already failed — this check here
    // is the second, independent layer, not the only one.
    return { action: "refuse", reason: "not_owner", heldBy: existingLock.buildId };
  }

  if (existingGeneration !== heldGeneration) {
    // Same buildId string reused across distinct attempts (e.g. a
    // manually re-triggered build with a fixed identifier) — the
    // generation check is what actually proves this is the same
    // physical lease this exact process acquired/last renewed, not a
    // coincidentally same-named later one.
    return { action: "refuse", reason: "generation_mismatch" };
  }

  return { action: "release", expectedGeneration: heldGeneration };
}

module.exports = {
  LOCK_SCHEMA_VERSION,
  decideAcquisition,
  decideRenewal,
  decideRelease,
};

// ---------------------------------------------------------------------
// CLI wrapper — real GCS access, not exercised by any local test.
// STATICALLY reviewed and syntax-checked (`node --check`) only. Its
// actual atomic behavior against a real bucket REQUIRES STAGING
// EXECUTION and is not proven by anything in this repository.
//
// Uses `@google-cloud/storage` (already a dependency of this service —
// see package.json, already used by src/gcsReader.js) directly, via
// Application Default Credentials — NOT the `gcloud` CLI binary. This
// is a deliberate choice made during the Slice 2.2 final correction
// (builder-image resolution): it means this script's runtime
// requirement is exactly "a Node.js runtime with this package's
// node_modules installed", nothing else — no `gcloud` binary needs to
// be present in whatever container runs this step. See
// cloudbuild.signature-refresh.yaml's acquire-lock/release-lock steps,
// which use the pinned official `node` image for exactly this reason.
// ---------------------------------------------------------------------
if (require.main === module) {
  /* eslint-disable no-console */
  const { Storage } = require("@google-cloud/storage");

  function usageError(message) {
    console.error(`signature-refresh-lock: ${message}`);
    console.error(
      "usage: node signatureRefreshLock.js <acquire|renew|release> --bucket=B --object=O --build-id=ID [--lease-seconds=N] [--generation=G]"
    );
    process.exit(2);
  }

  function parseArgs(argv) {
    const out = {};
    for (const raw of argv) {
      const m = raw.match(/^--([a-zA-Z-]+)=(.*)$/);
      if (!m) continue;
      out[m[1].replace(/-([a-z])/g, (_, c) => c.toUpperCase())] = m[2];
    }
    return out;
  }

  async function readLock(storage, bucket, object) {
    try {
      const file = storage.bucket(bucket).file(object);
      const [buf] = await file.download();
      const [metadata] = await file.getMetadata();
      return { content: JSON.parse(buf.toString("utf8")), generation: Number(metadata.generation) };
    } catch (err) {
      return { content: null, generation: null };
    }
  }

  // GCS's own documented precondition semantics: ifGenerationMatch: 0
  // means "succeed only if no live object currently exists at this
  // path" (the same atomic "create-only" guarantee the gcloud-CLI-based
  // design relied on) — @google-cloud/storage exposes this exact
  // precondition via file.save()'s preconditionOpts, applied
  // server-side by GCS itself, not emulated client-side by this code.
  async function writeLockWithPrecondition(storage, bucket, object, lockContent, expectedGeneration) {
    const file = storage.bucket(bucket).file(object);
    await file.save(JSON.stringify(lockContent), {
      resumable: false,
      preconditionOpts: { ifGenerationMatch: expectedGeneration },
      metadata: { contentType: "application/json" },
    });
  }

  async function deleteLockWithPrecondition(storage, bucket, object, expectedGeneration) {
    const file = storage.bucket(bucket).file(object);
    await file.delete({ preconditionOpts: { ifGenerationMatch: expectedGeneration } });
  }

  async function main() {
    const [, , command, ...rest] = process.argv;
    const args = parseArgs(rest);

    if (!args.bucket || !args.object || !args.buildId) {
      usageError("--bucket, --object, and --build-id are required");
    }
    const storage = new Storage();

    if (command === "acquire") {
      const leaseSeconds = Number(args.leaseSeconds || 900);
      const { content: existingLock, generation: existingGeneration } = await readLock(storage, args.bucket, args.object);
      const decision = decideAcquisition({
        existingLock,
        existingGeneration,
        now: new Date(),
        buildId: args.buildId,
        leaseSeconds,
      });

      if (decision.action === "refuse") {
        console.error(`signature-refresh-lock: refused to acquire — ${JSON.stringify(decision)}`);
        process.exit(1);
      }

      const expectedGeneration = decision.action === "create" ? 0 : decision.expectedGeneration;
      await writeLockWithPrecondition(storage, args.bucket, args.object, decision.newLock, expectedGeneration);
      // Report the generation THIS build now holds (the fencing token),
      // read back rather than assumed, since GCS assigns the real value.
      const { generation: heldGeneration } = await readLock(storage, args.bucket, args.object);
      console.log(JSON.stringify({ acquired: true, generation: heldGeneration, lock: decision.newLock }));
      process.exit(0);
    }

    if (command === "renew") {
      if (args.generation === undefined) {
        usageError("--generation is required for renew (the fencing token from the most recent acquire/renew)");
      }
      const leaseSeconds = Number(args.leaseSeconds || 900);
      const { content: existingLock, generation: existingGeneration } = await readLock(storage, args.bucket, args.object);
      const decision = decideRenewal({
        existingLock,
        existingGeneration,
        buildId: args.buildId,
        heldGeneration: Number(args.generation),
        now: new Date(),
        leaseSeconds,
      });

      if (decision.action === "refuse") {
        // Fail closed, always — this is the exact behavior every mutating
        // pipeline step depends on: a non-zero exit here must stop that
        // step before its real mutation runs.
        console.error(`signature-refresh-lock: LEASE LOST, refusing to renew — ${JSON.stringify(decision)}`);
        process.exit(1);
      }

      await writeLockWithPrecondition(storage, args.bucket, args.object, decision.newLock, decision.expectedGeneration);
      const { generation: newGeneration } = await readLock(storage, args.bucket, args.object);
      console.log(JSON.stringify({ renewed: true, generation: newGeneration, lock: decision.newLock }));
      process.exit(0);
    }

    if (command === "release") {
      if (args.generation === undefined) {
        usageError("--generation is required for release (the fencing token from the most recent acquire/renew)");
      }
      const { content: existingLock, generation: existingGeneration } = await readLock(storage, args.bucket, args.object);
      const decision = decideRelease({
        existingLock,
        existingGeneration,
        buildId: args.buildId,
        heldGeneration: Number(args.generation),
      });

      if (decision.action === "refuse") {
        console.error(`signature-refresh-lock: refused to release — ${JSON.stringify(decision)}`);
        process.exit(1);
      }
      if (decision.action === "noop") {
        console.log(JSON.stringify({ released: false, reason: decision.reason }));
        process.exit(0);
      }
      await deleteLockWithPrecondition(storage, args.bucket, args.object, decision.expectedGeneration);
      console.log(JSON.stringify({ released: true }));
      process.exit(0);
    }

    usageError(`unknown command "${command}"`);
  }

  main().catch((err) => {
    console.error(`signature-refresh-lock: unexpected error — ${err && err.message}`);
    process.exit(1);
  });
}
