"use strict";

// P1-A Slice 2 — createComplianceUploadSession Functions tests (docs/
// plans/marketplace_p1a_compliance_review_implementation_plan_2026-08-21
// .md). Exercises the exported onCall wrapper via its .run() test helper
// (same established pattern as createProduct.test.js/
// resolveBusinessRequest.integration.test.js), against the Firestore
// emulator, seeding businesses/{id} directly via the Admin SDK exactly
// as production data would look — never through Firestore Rules, which
// never apply to this server-side path.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();
const functions = require("../index");
const {
  assertCallerOwnsBusiness,
} = require("../src/marketplace/compliance/complianceUploadSessions");

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

let seq = 0;
function nextBusinessId() {
  seq += 1;
  return `compliance-session-test-biz-${seq}`;
}

// Slice 2.1 correction (part G): createComplianceUploadSession now has a
// server-side, default-deny canary gate (COMPLIANCE_UPLOAD_CANARY_
// BUSINESS_IDS). Every OTHER test in this file exercises unrelated
// mechanics (auth, ownership, idempotency, quota) that must keep passing
// regardless of the canary boundary's own existence — so every business
// this helper seeds is automatically appended to the process-wide
// allowlist env var, keeping this file's existing tests focused on what
// they actually test. The canary gate's own deny/allow behavior is
// tested explicitly and in isolation further below, saving/restoring
// this env var around those specific tests so they never leak into
// (or depend on) this blanket allow-listing.
function addToCanaryAllowlist(businessId) {
  const existing = process.env.COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS || "";
  const entries = existing.split(",").map((e) => e.trim()).filter(Boolean);
  entries.push(businessId);
  process.env.COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS = entries.join(",");
}

async function seedBusiness(ownerUid) {
  const businessId = nextBusinessId();
  await db.collection("businesses").doc(businessId).set({ ownerUid });
  addToCanaryAllowlist(businessId);
  return businessId;
}

const validRequest = (businessId) => ({
  businessId,
  originalFilename: "invoice.pdf",
  declaredMimeType: "application/pdf",
  declaredSizeBytes: 2048,
  documentType: "purchase_invoice",
});

// 1. unauthenticated upload-session creation fails
itest("unauthenticated session creation fails", async () => {
  const businessId = await seedBusiness("seller-1");
  await assert.rejects(
    functions.createComplianceUploadSession.run({
      auth: null,
      data: validRequest(businessId),
    }),
    (error) => {
      assert.equal(error.code, "unauthenticated");
      return true;
    }
  );
});

// 2. unauthorized business member fails
itest("a signed-in user with no relationship to the business fails", async () => {
  const businessId = await seedBusiness("seller-1");
  await assert.rejects(
    functions.createComplianceUploadSession.run({
      auth: { uid: "random-other-user" },
      data: validRequest(businessId),
    }),
    (error) => {
      assert.equal(error.code, "permission-denied");
      return true;
    }
  );
});

// 3. seller cannot create a session for another business
itest("the owner of a different business cannot create a session for this one", async () => {
  const businessId = await seedBusiness("seller-1");
  await seedBusiness("seller-2"); // seller-2 owns a different business entirely
  await assert.rejects(
    functions.createComplianceUploadSession.run({
      auth: { uid: "seller-2" },
      data: validRequest(businessId),
    }),
    (error) => {
      assert.equal(error.code, "permission-denied");
      return true;
    }
  );
});

itest("a nonexistent business fails not-found, not a silent pass", async () => {
  await assert.rejects(
    functions.createComplianceUploadSession.run({
      auth: { uid: "seller-1" },
      data: validRequest("does-not-exist-business-id"),
    }),
    (error) => {
      assert.equal(error.code, "not-found");
      return true;
    }
  );
});

// 4. unknown request fields fail
itest("an unknown request field is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  await assert.rejects(
    functions.createComplianceUploadSession.run({
      auth: { uid: "seller-1" },
      data: { ...validRequest(businessId), storagePath: "compliance_docs/x/y/z" },
    }),
    (error) => {
      assert.equal(error.code, "invalid-argument");
      return true;
    }
  );
});

itest("a caller-supplied status/reviewer/hash field is rejected outright", async () => {
  const businessId = await seedBusiness("seller-1");
  for (const injected of [
    { status: "approved" },
    { reviewedBy: "attacker-uid" },
    { contentHash: "deadbeef" },
    { sessionId: "attacker-chosen-id" },
    { updatedAt: new Date() },
  ]) {
    await assert.rejects(
      functions.createComplianceUploadSession.run({
        auth: { uid: "seller-1" },
        data: { ...validRequest(businessId), ...injected },
      }),
      (error) => {
        assert.equal(error.code, "invalid-argument");
        return true;
      }
    );
  }
});

// 5. invalid document-purpose value fails
itest("an invalid documentType is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  await assert.rejects(
    functions.createComplianceUploadSession.run({
      auth: { uid: "seller-1" },
      data: { ...validRequest(businessId), documentType: "medical_prescription" },
    }),
    (error) => {
      assert.equal(error.code, "invalid-argument");
      return true;
    }
  );
});

// 6. unsupported MIME fails
itest("an unsupported declared MIME type is rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  for (const mime of ["image/svg+xml", "text/html", "image/webp", "image/heic", "application/zip"]) {
    await assert.rejects(
      functions.createComplianceUploadSession.run({
        auth: { uid: "seller-1" },
        data: { ...validRequest(businessId), declaredMimeType: mime },
      }),
      (error) => {
        assert.equal(error.code, "invalid-argument");
        return true;
      }
    );
  }
});

// 7. zero, negative, malformed, or oversized declared size fails
itest("zero, negative, decimal, and oversized declared size are all rejected", async () => {
  const businessId = await seedBusiness("seller-1");
  for (const size of [0, -1, 3.5, 999999999]) {
    await assert.rejects(
      functions.createComplianceUploadSession.run({
        auth: { uid: "seller-1" },
        data: { ...validRequest(businessId), declaredSizeBytes: size },
      }),
      (error) => {
        assert.equal(error.code, "invalid-argument");
        return true;
      }
    );
  }
});

// 8. server controls session ID, path, businessId, UID, states, timestamps
itest("the server generates the session ID, path, status, and timestamps regardless of client input", async () => {
  const businessId = await seedBusiness("seller-1");
  const result = await functions.createComplianceUploadSession.run({
    auth: { uid: "seller-1" },
    data: validRequest(businessId),
  });
  assert.equal(result.status, "upload_authorized");
  assert.ok(result.sessionId, "no sessionId was returned to the client in this response shape check");

  const snap = await db.collection("complianceUploadSessions").doc(result.sessionId).get();
  const data = snap.data();
  assert.equal(data.businessId, businessId);
  assert.equal(data.issuedBy, "seller-1");
  assert.equal(data.status, "upload_authorized");
  assert.equal(data.objectPath, `compliance_quarantine/${businessId}/${result.sessionId}/${data.objectId}`);
  assert.ok(data.expiresAt, "expiresAt must be server-set");
  assert.ok(data.documentId, "documentId must be server-reserved");
  assert.equal(data.consumedAt, null);
  assert.equal(data.scanVerdict, null);
});

// 9. idempotency retry does not create duplicate active sessions
itest("retrying with the same idempotency key reuses the existing session, not a duplicate", async () => {
  const businessId = await seedBusiness("seller-1");
  const request = { ...validRequest(businessId), clientIdempotencyKey: "retry-key-1" };

  const first = await functions.createComplianceUploadSession.run({
    auth: { uid: "seller-1" },
    data: request,
  });
  const second = await functions.createComplianceUploadSession.run({
    auth: { uid: "seller-1" },
    data: request,
  });

  assert.equal(first.sessionId, second.sessionId);

  const allSessionsForBusiness = await db
    .collection("complianceUploadSessions")
    .where("businessId", "==", businessId)
    .get();
  assert.equal(allSessionsForBusiness.size, 1);
});

itest("two different idempotency keys produce two distinct sessions", async () => {
  const businessId = await seedBusiness("seller-1");
  const first = await functions.createComplianceUploadSession.run({
    auth: { uid: "seller-1" },
    data: { ...validRequest(businessId), clientIdempotencyKey: "key-a" },
  });
  const second = await functions.createComplianceUploadSession.run({
    auth: { uid: "seller-1" },
    data: { ...validRequest(businessId), clientIdempotencyKey: "key-b" },
  });
  assert.notEqual(first.sessionId, second.sessionId);
});

itest("two calls with no idempotency key each create a fresh session", async () => {
  const businessId = await seedBusiness("seller-1");
  const first = await functions.createComplianceUploadSession.run({
    auth: { uid: "seller-1" },
    data: validRequest(businessId),
  });
  const second = await functions.createComplianceUploadSession.run({
    auth: { uid: "seller-1" },
    data: validRequest(businessId),
  });
  assert.notEqual(first.sessionId, second.sessionId);
});

// ---------------------------------------------------------------------
// Slice 2 correction (adversarial review 2026-08-21) — idempotency
// mismatch (finding C/D) and quota (finding B)
// ---------------------------------------------------------------------

const {
  buildComplianceUploadQuotaScopeId,
  buildComplianceUploadQuotaDailyDocId,
  getUtcDateKey,
} = require("../src/marketplace/compliance/complianceValidators");
const {
  COMPLIANCE_MAX_ACTIVE_UPLOAD_SESSIONS_PER_SCOPE,
  COMPLIANCE_MAX_UPLOAD_SESSIONS_PER_SCOPE_PER_UTC_DAY,
  COMPLIANCE_MAX_UPLOAD_BYTES_PER_SCOPE_PER_UTC_DAY,
} = require("../src/marketplace/compliance/complianceConstants");

async function readQuotaScope(businessId, uid) {
  const scopeId = buildComplianceUploadQuotaScopeId({ businessId, uid });
  const snap = await db.collection("complianceUploadQuotaScopes").doc(scopeId).get();
  return snap.exists ? snap.data() : null;
}

async function readQuotaDaily(businessId, uid, when = new Date()) {
  const utcDateKey = getUtcDateKey(when);
  const dailyDocId = buildComplianceUploadQuotaDailyDocId({ businessId, uid, utcDateKey });
  const snap = await db.collection("complianceUploadQuotaDaily").doc(dailyDocId).get();
  return snap.exists ? snap.data() : null;
}

// 2. idempotent metadata mismatch is rejected
itest("a retry with the same idempotency key but different file metadata is rejected, not silently reused", async () => {
  const businessId = await seedBusiness("seller-1");
  const key = "mismatch-key-1";
  const first = await functions.createComplianceUploadSession.run({
    auth: { uid: "seller-1" },
    data: { ...validRequest(businessId), clientIdempotencyKey: key },
  });

  await assert.rejects(
    functions.createComplianceUploadSession.run({
      auth: { uid: "seller-1" },
      data: {
        ...validRequest(businessId),
        originalFilename: "a-different-file.pdf",
        clientIdempotencyKey: key,
      },
    }),
    (error) => {
      assert.equal(error.code, "failed-precondition");
      assert.match(String(error.message), /idempotency_conflict/);
      return true;
    }
  );

  // The original session must be untouched, and no second session or
  // extra quota consumption may have occurred.
  const snap = await db.collection("complianceUploadSessions").doc(first.sessionId).get();
  assert.equal(snap.data().originalFilename, "invoice.pdf");
  const daily = await readQuotaDaily(businessId, "seller-1");
  assert.equal(daily.createdSessionCount, 1);
});

// 3. concurrent identical requests create exactly one session
itest("concurrent identical requests (same idempotency key) create exactly one session", async () => {
  const businessId = await seedBusiness("seller-1");
  const request = { ...validRequest(businessId), clientIdempotencyKey: "concurrent-identical-1" };

  const results = await Promise.all(
    Array.from({ length: 5 }, () =>
      functions.createComplianceUploadSession.run({ auth: { uid: "seller-1" }, data: request })
    )
  );
  const sessionIds = new Set(results.map((r) => r.sessionId));
  assert.equal(sessionIds.size, 1, "every concurrent identical retry must resolve to the same session");

  const daily = await readQuotaDaily(businessId, "seller-1");
  assert.equal(daily.createdSessionCount, 1, "quota must be consumed exactly once, not once per concurrent retry");
});

// 4. concurrent requests cannot exceed the active-session cap
itest("concurrent requests cannot exceed the active-session cap", async () => {
  const businessId = await seedBusiness("seller-1");
  // Fill the cap minus one sequentially (each a distinct session).
  for (let i = 0; i < COMPLIANCE_MAX_ACTIVE_UPLOAD_SESSIONS_PER_SCOPE - 1; i += 1) {
    await functions.createComplianceUploadSession.run({
      auth: { uid: "seller-1" },
      data: { ...validRequest(businessId), clientIdempotencyKey: `fill-${i}` },
    });
  }

  // Now race several more concurrent, distinct requests for the single
  // remaining slot (plus extras that must all be rejected).
  const attempts = 5;
  const outcomes = await Promise.allSettled(
    Array.from({ length: attempts }, (_, i) =>
      functions.createComplianceUploadSession.run({
        auth: { uid: "seller-1" },
        data: { ...validRequest(businessId), clientIdempotencyKey: `race-${i}` },
      })
    )
  );
  const succeeded = outcomes.filter((o) => o.status === "fulfilled");
  const rejected = outcomes.filter((o) => o.status === "rejected");
  assert.equal(succeeded.length, 1, "only exactly one of the concurrent requests may claim the last active slot");
  assert.equal(rejected.length, attempts - 1);
  for (const r of rejected) {
    assert.equal(r.reason.code, "resource-exhausted");
  }

  const scope = await readQuotaScope(businessId, "seller-1");
  assert.equal(scope.activeSessionCount, COMPLIANCE_MAX_ACTIVE_UPLOAD_SESSIONS_PER_SCOPE);
});

// 5. daily count quota is atomic
itest("daily session-count quota is enforced atomically under concurrency", async () => {
  const businessId = await seedBusiness("seller-1");
  const scopeId = buildComplianceUploadQuotaScopeId({ businessId, uid: "seller-1" });
  const utcDateKey = getUtcDateKey(new Date());
  const dailyDocId = buildComplianceUploadQuotaDailyDocId({ businessId, uid: "seller-1", utcDateKey });
  // Seed the daily counter one below the limit directly (Admin SDK,
  // bypassing the callable) so the test doesn't need to create 49 real
  // sessions to reach the boundary.
  await db.collection("complianceUploadQuotaDaily").doc(dailyDocId).set({
    businessId,
    uid: "seller-1",
    utcDateKey,
    createdSessionCount: COMPLIANCE_MAX_UPLOAD_SESSIONS_PER_SCOPE_PER_UTC_DAY - 1,
    declaredBytesCreated: 0,
    updatedAt: new Date(),
  });

  const attempts = 5;
  const outcomes = await Promise.allSettled(
    Array.from({ length: attempts }, (_, i) =>
      functions.createComplianceUploadSession.run({
        auth: { uid: "seller-1" },
        data: { ...validRequest(businessId), clientIdempotencyKey: `daily-race-${i}` },
      })
    )
  );
  const succeeded = outcomes.filter((o) => o.status === "fulfilled");
  assert.equal(succeeded.length, 1, "only one request may claim the last daily-count slot");

  const daily = await db.collection("complianceUploadQuotaDaily").doc(dailyDocId).get();
  assert.equal(daily.data().createdSessionCount, COMPLIANCE_MAX_UPLOAD_SESSIONS_PER_SCOPE_PER_UTC_DAY);
});

// 6. daily byte quota is atomic
itest("daily byte quota is enforced atomically under concurrency", async () => {
  const businessId = await seedBusiness("seller-1");
  const utcDateKey = getUtcDateKey(new Date());
  const dailyDocId = buildComplianceUploadQuotaDailyDocId({ businessId, uid: "seller-1", utcDateKey });
  const remaining = 3000; // bytes of headroom left in the daily budget
  await db.collection("complianceUploadQuotaDaily").doc(dailyDocId).set({
    businessId,
    uid: "seller-1",
    utcDateKey,
    createdSessionCount: 0,
    declaredBytesCreated: COMPLIANCE_MAX_UPLOAD_BYTES_PER_SCOPE_PER_UTC_DAY - remaining,
    updatedAt: new Date(),
  });

  const attempts = 5;
  const outcomes = await Promise.allSettled(
    Array.from({ length: attempts }, (_, i) =>
      functions.createComplianceUploadSession.run({
        auth: { uid: "seller-1" },
        data: {
          ...validRequest(businessId),
          declaredSizeBytes: 2048, // > remaining/2, so at most one can fit
          clientIdempotencyKey: `byte-race-${i}`,
        },
      })
    )
  );
  const succeeded = outcomes.filter((o) => o.status === "fulfilled");
  assert.equal(succeeded.length, 1, "only one request may fit inside the remaining byte budget");
  for (const o of outcomes.filter((x) => x.status === "rejected")) {
    assert.equal(o.reason.code, "resource-exhausted");
  }
});

// 7. idempotent retry does not consume quota twice (already partially
// covered above; this asserts it directly against the scope counter too)
itest("an idempotent retry does not increment active-session quota a second time", async () => {
  const businessId = await seedBusiness("seller-1");
  const request = { ...validRequest(businessId), clientIdempotencyKey: "no-double-consume" };
  await functions.createComplianceUploadSession.run({ auth: { uid: "seller-1" }, data: request });
  await functions.createComplianceUploadSession.run({ auth: { uid: "seller-1" }, data: request });

  const scope = await readQuotaScope(businessId, "seller-1");
  assert.equal(scope.activeSessionCount, 1);
});

// 8. terminal transitions release active quota exactly once
itest("expiring a session releases its active quota slot exactly once", async () => {
  const {
    expireStaleUploadSessions,
  } = require("../src/marketplace/compliance/complianceUploadCleanup");
  const businessId = await seedBusiness("seller-1");
  const created = await functions.createComplianceUploadSession.run({
    auth: { uid: "seller-1" },
    data: validRequest(businessId),
  });

  let scope = await readQuotaScope(businessId, "seller-1");
  assert.equal(scope.activeSessionCount, 1);

  await db.collection("complianceUploadSessions").doc(created.sessionId).update({
    expiresAt: new Date(Date.now() - 1000),
  });

  const bucket = { file: () => ({ exists: async () => [false] }) };
  await expireStaleUploadSessions({ db, bucket, now: new Date(), logger: { info() {}, error() {}, warn() {} } });
  // A second sweep pass must not double-release even if it re-queries a
  // session that (in a real bucket) is already gone from its window.
  await expireStaleUploadSessions({ db, bucket, now: new Date(), logger: { info() {}, error() {}, warn() {} } });

  scope = await readQuotaScope(businessId, "seller-1");
  assert.equal(scope.activeSessionCount, 0, "quota must be released exactly once, never double-released");
});

// ---------------------------------------------------------------------
// Slice 2.1 correction (part G) — canary allowlist gate. Each test here
// explicitly controls COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS and restores
// it afterward, so these tests never depend on (or interfere with) the
// blanket allow-listing addToCanaryAllowlist() gives every other test in
// this file.
// ---------------------------------------------------------------------

async function withCanaryAllowlist(value, fn) {
  const previous = process.env.COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS;
  process.env.COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS = value;
  try {
    await fn();
  } finally {
    process.env.COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS = previous;
  }
}

// Seeds a business WITHOUT the blanket allow-listing seedBusiness() does.
async function seedBusinessWithoutCanary(ownerUid) {
  const businessId = nextBusinessId();
  await db.collection("businesses").doc(businessId).set({ ownerUid });
  return businessId;
}

itest("default deny: an unset canary allowlist rejects every business, including a real, valid, owned one", async () => {
  await withCanaryAllowlist(undefined, async () => {
    const businessId = await seedBusinessWithoutCanary("seller-1");
    await assert.rejects(
      functions.createComplianceUploadSession.run({
        auth: { uid: "seller-1" },
        data: validRequest(businessId),
      }),
      (error) => {
        assert.equal(error.code, "failed-precondition");
        return true;
      }
    );
  });
});

itest("default deny: an empty-string canary allowlist rejects every business", async () => {
  await withCanaryAllowlist("", async () => {
    const businessId = await seedBusinessWithoutCanary("seller-1");
    await assert.rejects(
      functions.createComplianceUploadSession.run({
        auth: { uid: "seller-1" },
        data: validRequest(businessId),
      }),
      (error) => {
        assert.equal(error.code, "failed-precondition");
        return true;
      }
    );
  });
});

itest("default deny: a malformed allowlist value (whitespace/commas only) rejects every business", async () => {
  await withCanaryAllowlist(" , , ,,", async () => {
    const businessId = await seedBusinessWithoutCanary("seller-1");
    await assert.rejects(
      functions.createComplianceUploadSession.run({
        auth: { uid: "seller-1" },
        data: validRequest(businessId),
      })
    );
  });
});

itest("default deny: a business present in the allowlist for a DIFFERENT businessId is still rejected", async () => {
  const businessId = await seedBusinessWithoutCanary("seller-1");
  await withCanaryAllowlist("some-other-business-entirely", async () => {
    await assert.rejects(
      functions.createComplianceUploadSession.run({
        auth: { uid: "seller-1" },
        data: validRequest(businessId),
      })
    );
  });
});

itest("explicit synthetic allowlist: a business explicitly listed is permitted to create a session", async () => {
  const businessId = await seedBusinessWithoutCanary("seller-1");
  await withCanaryAllowlist(businessId, async () => {
    const result = await functions.createComplianceUploadSession.run({
      auth: { uid: "seller-1" },
      data: validRequest(businessId),
    });
    assert.equal(result.status, "upload_authorized");
  });
});

itest("explicit synthetic allowlist: comma-separated entries with surrounding whitespace are trimmed correctly", async () => {
  const businessId = await seedBusinessWithoutCanary("seller-1");
  await withCanaryAllowlist(`  some-unrelated-id ,  ${businessId}  , another-unrelated-id`, async () => {
    const result = await functions.createComplianceUploadSession.run({
      auth: { uid: "seller-1" },
      data: validRequest(businessId),
    });
    assert.equal(result.status, "upload_authorized");
  });
});

itest("the canary gate is checked after ownership — a non-owner still gets a permission-denied, not a canary-specific error", async () => {
  const businessId = await seedBusinessWithoutCanary("seller-1");
  await withCanaryAllowlist(businessId, async () => {
    await assert.rejects(
      functions.createComplianceUploadSession.run({
        auth: { uid: "seller-2" }, // not the owner
        data: validRequest(businessId),
      }),
      (error) => {
        assert.equal(error.code, "permission-denied");
        return true;
      }
    );
  });
});

itest("the canary gate does not bypass quota — an allow-listed business still hits its active-session cap", async () => {
  const businessId = await seedBusinessWithoutCanary("seller-1");
  await withCanaryAllowlist(businessId, async () => {
    for (let i = 0; i < COMPLIANCE_MAX_ACTIVE_UPLOAD_SESSIONS_PER_SCOPE; i += 1) {
      await functions.createComplianceUploadSession.run({
        auth: { uid: "seller-1" },
        data: { ...validRequest(businessId), clientIdempotencyKey: `canary-quota-${i}` },
      });
    }
    await assert.rejects(
      functions.createComplianceUploadSession.run({
        auth: { uid: "seller-1" },
        data: { ...validRequest(businessId), clientIdempotencyKey: "canary-quota-overflow" },
      }),
      (error) => {
        assert.equal(error.code, "resource-exhausted");
        return true;
      }
    );
  });
});

// ---------------------------------------------------------------------
// Marketplace P1-A Slice 4.10 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §0.17 Phase 5, committed
// Revision 19, corrected by independent review) — `assertCallerOwnsBusiness`
// gains an additive, optional `tx` parameter, mirroring Revision 10's
// own already-frozen `tx`/`productSnapshot` pattern. This module already
// owns this function's coverage (confirmed: no second test file exists
// for it) — these tests are added here directly, not in a new file,
// exercising the function's own exported behavior rather than only its
// one indirect call site inside `createComplianceUploadSession`. §15
// item 525.
// ---------------------------------------------------------------------

itest(
  "525a. the additive tx parameter genuinely participates in the caller's own transaction — a real, instrumented Firestore Transaction proves assertCallerOwnsBusiness calls tx.get() exactly once, never a plain ref.get()",
  async () => {
    // Per §0.17 Phase 11, point 12 (committed Revision 19): "no Type-A
    // retry-determinism proof is claimed unless callback re-execution is
    // directly instrumented (e.g., a fake/counting Firestore transaction
    // harness proving the callback body ran more than once for a
    // forced-conflict scenario)" — this test follows exactly that
    // sanctioned technique, applied to the read call itself rather than
    // callback re-execution: the `tx` object is the real, live Firestore
    // Transaction the emulator handed back for this exact transaction
    // attempt (never a fake/mock of the SDK), wrapped only to count
    // which of its own real methods get called — genuine emulator
    // evidence, not a fabricated double. A best-effort, non-asserted
    // concurrent-conflict scenario is exercised immediately below this
    // test as a secondary, informational data point only, since the
    // Firestore emulator's own conflict-detection timing is not always
    // reliably provokable within a bounded test duration.
    const businessId = await seedBusiness("seller-1");
    let txGetCalls = 0;

    await db.runTransaction(async (tx) => {
      const realGet = tx.get.bind(tx);
      const instrumentedTx = Object.create(tx);
      instrumentedTx.get = (...args) => {
        txGetCalls += 1;
        return realGet(...args);
      };
      await assertCallerOwnsBusiness({
        db,
        businessId,
        uid: "seller-1",
        tx: instrumentedTx,
      });
    });

    assert.equal(
      txGetCalls,
      1,
      "assertCallerOwnsBusiness must call tx.get() exactly once when tx is supplied — never a fallback to a plain ref.get()"
    );
  }
);

itest(
  "525a-info. best-effort: two genuinely concurrent transactions, one reading and one writing the same business document, may force a real SDK-level retry (informational only, not required to pass deterministically)",
  async () => {
    const businessId = await seedBusiness("seller-1");
    let attemptsA = 0;
    const txA = db.runTransaction(async (tx) => {
      attemptsA += 1;
      await assertCallerOwnsBusiness({ db, businessId, uid: "seller-1", tx });
      await new Promise((resolve) => setTimeout(resolve, 150));
      tx.set(db.collection("test-scratch").doc(`tx-proof-a-${businessId}`), {
        attemptsA,
      });
    });
    let attemptsB = 0;
    const txB = db.runTransaction(async (tx) => {
      attemptsB += 1;
      await assertCallerOwnsBusiness({ db, businessId, uid: "seller-1", tx });
      tx.update(db.collection("businesses").doc(businessId), {
        pingedAt: Date.now(),
      });
    });
    await Promise.all([txA, txB]);
    // No hard assertion on attemptsA/attemptsB — the deterministic proof
    // is item 525a above; this is retained only as an informational,
    // best-effort real-emulator data point, logged rather than asserted,
    // since the emulator's own conflict-detection timing is not always
    // reliably reproducible.
    console.log(
      `[525a-info] attemptsA=${attemptsA} attemptsB=${attemptsB}`
    );
  }
);

itest(
  "525b. every existing non-transactional caller is byte-for-byte unaffected — omitting tx preserves the exact prior owner/non-owner behavior",
  async () => {
    const businessId = await seedBusiness("seller-1");
    await assert.doesNotReject(
      assertCallerOwnsBusiness({ db, businessId, uid: "seller-1" })
    );
    await assert.rejects(
      assertCallerOwnsBusiness({ db, businessId, uid: "seller-2" }),
      (error) => {
        assert.equal(error.code, "permission-denied");
        return true;
      }
    );
    await assert.rejects(
      assertCallerOwnsBusiness({ db, businessId: "nonexistent-biz", uid: "seller-1" }),
      (error) => {
        assert.equal(error.code, "not-found");
        return true;
      }
    );
  }
);
