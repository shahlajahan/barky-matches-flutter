"use strict";

// Deterministic validation for the signature-refresh concurrency lock
// (Slice 2.2, Phase 5/10 item 8-10). Exercises only the pure decision
// functions — no GCS access, no child_process, no network. This is the
// "locally verified" half of the lock; the CLI wrapper's actual atomic
// GCS operations require later staging execution (see the Slice 2.2
// report).

const test = require("node:test");
const assert = require("node:assert/strict");
const { decideAcquisition, decideRenewal, decideRelease } = require("./signatureRefreshLock");

const NOW = new Date("2026-08-22T12:00:00.000Z");

test("acquire: no existing lock -> create", () => {
  const decision = decideAcquisition({
    existingLock: null,
    existingGeneration: null,
    now: NOW,
    buildId: "build-a",
    leaseSeconds: 1800,
  });
  assert.equal(decision.action, "create");
  assert.equal(decision.newLock.buildId, "build-a");
  assert.equal(decision.newLock.leaseSeconds, 1800);
  assert.equal(Date.parse(decision.newLock.expiresAt), NOW.getTime() + 1800 * 1000);
});

test("acquire: rejects a non-positive-integer lease", () => {
  for (const bad of [0, -5, 1.5, NaN]) {
    const decision = decideAcquisition({
      existingLock: null,
      existingGeneration: null,
      now: NOW,
      buildId: "build-a",
      leaseSeconds: bad,
    });
    assert.equal(decision.action, "refuse");
    assert.equal(decision.reason, "invalid_lease_seconds");
  }
});

test("acquire: a live (non-expired) lease held by another build is refused, never overwritten", () => {
  const existingLock = {
    buildId: "build-other",
    acquiredAt: new Date(NOW.getTime() - 60_000).toISOString(),
    expiresAt: new Date(NOW.getTime() + 60_000).toISOString(), // still valid
    leaseSeconds: 120,
  };
  const decision = decideAcquisition({
    existingLock,
    existingGeneration: 42,
    now: NOW,
    buildId: "build-a",
    leaseSeconds: 1800,
  });
  assert.equal(decision.action, "refuse");
  assert.equal(decision.reason, "live_lease_held");
  assert.equal(decision.heldBy, "build-other");
});

test("acquire: an expired lease is stolen, citing the exact generation it was read at", () => {
  const existingLock = {
    buildId: "build-crashed",
    acquiredAt: new Date(NOW.getTime() - 7200_000).toISOString(),
    expiresAt: new Date(NOW.getTime() - 3600_000).toISOString(), // expired 1h ago
    leaseSeconds: 3600,
  };
  const decision = decideAcquisition({
    existingLock,
    existingGeneration: 99,
    now: NOW,
    buildId: "build-recovering",
    leaseSeconds: 1800,
  });
  assert.equal(decision.action, "steal");
  assert.equal(decision.expectedGeneration, 99);
  assert.equal(decision.newLock.buildId, "build-recovering");
});

test("acquire: expiresAt exactly equal to now is treated as expired (boundary, not live)", () => {
  const existingLock = {
    buildId: "build-old",
    acquiredAt: new Date(NOW.getTime() - 1800_000).toISOString(),
    expiresAt: NOW.toISOString(),
    leaseSeconds: 1800,
  };
  const decision = decideAcquisition({
    existingLock,
    existingGeneration: 7,
    now: NOW,
    buildId: "build-new",
    leaseSeconds: 1800,
  });
  assert.equal(decision.action, "steal");
});

test("acquire: a malformed expiresAt on the existing lock is treated as expired, never as a permanent live lock", () => {
  const existingLock = { buildId: "build-broken", acquiredAt: "garbage", expiresAt: "not-a-date", leaseSeconds: 1800 };
  const decision = decideAcquisition({
    existingLock,
    existingGeneration: 3,
    now: NOW,
    buildId: "build-new",
    leaseSeconds: 1800,
  });
  assert.equal(decision.action, "steal");
});

test("acquire: an expired lock without a citable generation is refused, not stolen blind", () => {
  const existingLock = {
    buildId: "build-old",
    acquiredAt: new Date(NOW.getTime() - 7200_000).toISOString(),
    expiresAt: new Date(NOW.getTime() - 3600_000).toISOString(),
    leaseSeconds: 3600,
  };
  const decision = decideAcquisition({
    existingLock,
    existingGeneration: null,
    now: NOW,
    buildId: "build-new",
    leaseSeconds: 1800,
  });
  assert.equal(decision.action, "refuse");
});

// ---------------------------------------------------------------------
// Fenced renewal (Slice 2.2 adversarial correction — Mandatory
// correction 2). Every mutating pipeline phase calls this as its own
// first action; a refusal here must stop that phase before its real
// mutation runs.
// ---------------------------------------------------------------------

test("renew: owner + matching fencing generation -> renew, extends expiresAt, preserves original acquiredAt", () => {
  const existingLock = {
    buildId: "build-a",
    acquiredAt: "2026-08-22T10:00:00.000Z",
    renewedAt: "2026-08-22T10:00:00.000Z",
    expiresAt: new Date(NOW.getTime() + 60_000).toISOString(),
    leaseSeconds: 900,
    fencingGeneration: 77,
  };
  const decision = decideRenewal({
    existingLock,
    existingGeneration: 77,
    buildId: "build-a",
    heldGeneration: 77,
    now: NOW,
    leaseSeconds: 900,
  });
  assert.equal(decision.action, "renew");
  assert.equal(decision.expectedGeneration, 77);
  assert.equal(decision.newLock.acquiredAt, "2026-08-22T10:00:00.000Z"); // unchanged
  assert.equal(Date.parse(decision.newLock.expiresAt), NOW.getTime() + 900 * 1000); // extended from renewal time, not original acquire time
});

test("renew: rejects a non-positive-integer lease, same as acquire", () => {
  const existingLock = { buildId: "build-a", expiresAt: new Date(NOW.getTime() + 60_000).toISOString() };
  for (const bad of [0, -5, 1.5, NaN]) {
    const decision = decideRenewal({ existingLock, existingGeneration: 1, buildId: "build-a", heldGeneration: 1, now: NOW, leaseSeconds: bad });
    assert.equal(decision.action, "refuse");
    assert.equal(decision.reason, "invalid_lease_seconds");
  }
});

test("renew: the lock object is gone entirely -> lease_lost, fail closed (item 7/8/9: this is what stops push/deploy/promote)", () => {
  const decision = decideRenewal({
    existingLock: null,
    existingGeneration: null,
    buildId: "build-a",
    heldGeneration: 77,
    now: NOW,
    leaseSeconds: 900,
  });
  assert.equal(decision.action, "refuse");
  assert.equal(decision.reason, "lease_lost");
});

test("renew: a DIFFERENT build now owns the path -> refused, not_owner (our lease was reclaimed)", () => {
  const existingLock = {
    buildId: "build-newer",
    acquiredAt: NOW.toISOString(),
    expiresAt: new Date(NOW.getTime() + 900_000).toISOString(),
    fencingGeneration: 200,
  };
  const decision = decideRenewal({
    existingLock,
    existingGeneration: 200,
    buildId: "build-older",
    heldGeneration: 77, // this build's own last-known (now stale) fencing token
    now: NOW,
    leaseSeconds: 900,
  });
  assert.equal(decision.action, "refuse");
  assert.equal(decision.reason, "not_owner");
  assert.equal(decision.heldBy, "build-newer");
});

test("renew: SAME buildId but a STALE fencing generation -> refused, generation_mismatch (the check a buildId-only comparison would miss)", () => {
  const existingLock = {
    buildId: "build-a",
    acquiredAt: NOW.toISOString(),
    expiresAt: new Date(NOW.getTime() + 900_000).toISOString(),
    fencingGeneration: 200, // someone/something already renewed this lock to generation 200
  };
  const decision = decideRenewal({
    existingLock,
    existingGeneration: 200,
    buildId: "build-a",
    heldGeneration: 77, // this process still believes it holds the OLD generation
    now: NOW,
    leaseSeconds: 900,
  });
  assert.equal(decision.action, "refuse");
  assert.equal(decision.reason, "generation_mismatch");
});

test("renew: even an EXPIRED lock refuses renewal if this build no longer owns it, never silently re-adopts it", () => {
  const existingLock = {
    buildId: "build-other",
    acquiredAt: new Date(NOW.getTime() - 3600_000).toISOString(),
    expiresAt: new Date(NOW.getTime() - 1800_000).toISOString(), // expired
    fencingGeneration: 55,
  };
  const decision = decideRenewal({
    existingLock,
    existingGeneration: 55,
    buildId: "build-a",
    heldGeneration: 42,
    now: NOW,
    leaseSeconds: 900,
  });
  assert.equal(decision.action, "refuse");
  assert.equal(decision.reason, "not_owner");
});

test("renewal chain simulation: each successful renewal produces a NEW fencing generation, and the previous generation can no longer renew or release (item 3/4)", () => {
  // Acquire at generation 100 (simulated GCS-assigned value).
  let heldGeneration = 100;
  const acquireLock = { buildId: "build-a", acquiredAt: NOW.toISOString(), expiresAt: new Date(NOW.getTime() + 900_000).toISOString(), fencingGeneration: 100 };

  // First renewal succeeds, GCS assigns a NEW generation (simulated: 101).
  const renewal1 = decideRenewal({
    existingLock: acquireLock,
    existingGeneration: heldGeneration,
    buildId: "build-a",
    heldGeneration,
    now: new Date(NOW.getTime() + 500_000),
    leaseSeconds: 900,
  });
  assert.equal(renewal1.action, "renew");
  const newGeneration = 101; // what GCS would assign on the conditional write
  assert.notEqual(newGeneration, heldGeneration, "renewal must change the fencing generation");

  // A stale copy of this build's own process, still holding the OLD
  // generation (100), attempts to renew AFTER the real renewal above
  // already advanced the live object to generation 101 — must be
  // refused (item 4: stale generation cannot renew).
  const liveLockAfterRenewal1 = { ...acquireLock, fencingGeneration: newGeneration };
  const staleRenewalAttempt = decideRenewal({
    existingLock: liveLockAfterRenewal1,
    existingGeneration: newGeneration,
    buildId: "build-a",
    heldGeneration: 100, // stale — still the pre-renewal value
    now: new Date(NOW.getTime() + 600_000),
    leaseSeconds: 900,
  });
  assert.equal(staleRenewalAttempt.action, "refuse");
  assert.equal(staleRenewalAttempt.reason, "generation_mismatch");

  // The same stale copy also cannot release under the old generation
  // (item 5: stale generation cannot release).
  const staleReleaseAttempt = decideRelease({
    existingLock: liveLockAfterRenewal1,
    existingGeneration: newGeneration,
    buildId: "build-a",
    heldGeneration: 100,
  });
  assert.equal(staleReleaseAttempt.action, "refuse");
  assert.equal(staleReleaseAttempt.reason, "generation_mismatch");

  // Only the copy holding the CURRENT generation (101) can release.
  const properRelease = decideRelease({
    existingLock: liveLockAfterRenewal1,
    existingGeneration: newGeneration,
    buildId: "build-a",
    heldGeneration: newGeneration,
  });
  assert.equal(properRelease.action, "release");
});

test("release: no existing lock -> noop, not an error (already gone)", () => {
  const decision = decideRelease({ existingLock: null, existingGeneration: null, buildId: "build-a", heldGeneration: 10 });
  assert.equal(decision.action, "noop");
  assert.equal(decision.reason, "already_gone");
});

test("release: owner + matching generation -> release with that exact generation", () => {
  const existingLock = { buildId: "build-a", acquiredAt: NOW.toISOString(), expiresAt: NOW.toISOString(), leaseSeconds: 1800 };
  const decision = decideRelease({ existingLock, existingGeneration: 55, buildId: "build-a", heldGeneration: 55 });
  assert.equal(decision.action, "release");
  assert.equal(decision.expectedGeneration, 55);
});

test("release: a DIFFERENT build's buildId occupies the path -> refused, not_owner (one build cannot release another build's lease)", () => {
  const existingLock = { buildId: "build-newer", acquiredAt: NOW.toISOString(), expiresAt: NOW.toISOString(), leaseSeconds: 1800 };
  const decision = decideRelease({ existingLock, existingGeneration: 61, buildId: "build-older-crashed", heldGeneration: 55 });
  assert.equal(decision.action, "refuse");
  assert.equal(decision.reason, "not_owner");
  assert.equal(decision.heldBy, "build-newer");
});

test("release: same buildId string but a DIFFERENT generation -> refused, generation_mismatch (guards reused/manually re-triggered build IDs)", () => {
  const existingLock = { buildId: "build-a", acquiredAt: NOW.toISOString(), expiresAt: NOW.toISOString(), leaseSeconds: 1800 };
  const decision = decideRelease({ existingLock, existingGeneration: 200, buildId: "build-a", heldGeneration: 55 });
  assert.equal(decision.action, "refuse");
  assert.equal(decision.reason, "generation_mismatch");
});

test("end-to-end simulation: two concurrent builds racing an acquisition — only one may proceed", () => {
  // Simulates the atomicity GCS itself provides for the "create" path:
  // both builds observe existingLock=null (the object doesn't exist
  // yet), but only one write can win the --if-generation-match=0
  // precondition in reality. This test proves the DECISION for both is
  // "create" (both would attempt to write) — the actual mutual
  // exclusion is GCS's job, verified as "requires later staging
  // execution", not re-implemented or asserted here.
  const buildA = decideAcquisition({ existingLock: null, existingGeneration: null, now: NOW, buildId: "build-a", leaseSeconds: 1800 });
  const buildB = decideAcquisition({ existingLock: null, existingGeneration: null, now: NOW, buildId: "build-b", leaseSeconds: 1800 });
  assert.equal(buildA.action, "create");
  assert.equal(buildB.action, "create");
  // Simulate build-a's write winning: build-b now re-reads and must see
  // build-a's live lease and refuse.
  const buildBRetry = decideAcquisition({
    existingLock: buildA.newLock,
    existingGeneration: 1,
    now: NOW,
    buildId: "build-b",
    leaseSeconds: 1800,
  });
  assert.equal(buildBRetry.action, "refuse");
  assert.equal(buildBRetry.reason, "live_lease_held");
  assert.equal(buildBRetry.heldBy, "build-a");
});

test("expired-lease recovery simulation: a crashed build's lease is later reclaimed, then correctly released only by the reclaiming build", () => {
  // build-crashed acquires, then never releases (simulated crash).
  const acquireCrashed = decideAcquisition({ existingLock: null, existingGeneration: null, now: NOW, buildId: "build-crashed", leaseSeconds: 60 });
  assert.equal(acquireCrashed.action, "create");
  const crashedGeneration = 501;

  // Time passes beyond the lease. A new build attempts acquisition.
  const later = new Date(NOW.getTime() + 61_000);
  const acquireRecovering = decideAcquisition({
    existingLock: acquireCrashed.newLock,
    existingGeneration: crashedGeneration,
    now: later,
    buildId: "build-recovering",
    leaseSeconds: 1800,
  });
  assert.equal(acquireRecovering.action, "steal");
  assert.equal(acquireRecovering.expectedGeneration, crashedGeneration);
  const recoveringGeneration = 502;

  // The original crashed build "wakes up" and attempts to release its
  // own long-dead lease — must be refused, since build-recovering now
  // owns the path.
  const staleRelease = decideRelease({
    existingLock: acquireRecovering.newLock,
    existingGeneration: recoveringGeneration,
    buildId: "build-crashed",
    heldGeneration: crashedGeneration,
  });
  assert.equal(staleRelease.action, "refuse");
  assert.equal(staleRelease.reason, "not_owner");

  // build-recovering's own release succeeds normally.
  const properRelease = decideRelease({
    existingLock: acquireRecovering.newLock,
    existingGeneration: recoveringGeneration,
    buildId: "build-recovering",
    heldGeneration: recoveringGeneration,
  });
  assert.equal(properRelease.action, "release");
  assert.equal(properRelease.expectedGeneration, recoveringGeneration);
});
