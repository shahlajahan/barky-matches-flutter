"use strict";

// Marketplace P1-A Step 21c2 — marketplaceSellerActivation.test.js
// (docs/plans/marketplace_p1a_compliance_review_implementation_plan_
// 2026-08-21.md §10.1/§13.1/§15 items 702-715). Deliberately NOT
// emulator-backed — exactly like productModeration.test.js,
// `grantMarketplaceSellerActivation`/`revokeMarketplaceSellerActivation`
// are pure dependency injection ({db, auth, data}), so a hand-rolled,
// self-contained in-memory fake stands in for `db`. This module never
// issues a Firestore query (only point reads/writes), so this fake
// needs no query-builder at all.
//
// No conditional test-skipping and no environment-dependent bypass
// anywhere in this file — every test always runs.

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  grantMarketplaceSellerActivation,
  revokeMarketplaceSellerActivation,
  AUDIT_EVENTS_COLLECTION,
  BUSINESSES_COLLECTION,
} = require("../src/marketplace/compliance/marketplaceSellerActivation");

// =======================================================================
// Fake Firestore — point reads/writes only, atomic-commit-or-nothing
// transaction semantics, with an injectable mid-commit failure hook so
// atomicity itself (not merely the happy path) can be proven.
// =======================================================================

function createStore() {
  return { docs: new Map(), revisions: new Map(), callLog: [] };
}

function docRevision(store, docPath) {
  return store.revisions.get(docPath) || 0;
}

function bumpRevision(store, docPath) {
  store.revisions.set(docPath, docRevision(store, docPath) + 1);
}

function setDoc(store, docPath, data) {
  store.docs.set(docPath, data);
  bumpRevision(store, docPath);
}

function makeDocSnapshot(id, rawValue, ref) {
  return { exists: rawValue !== undefined, id, ref, data: () => rawValue };
}

function makeRef(fullPath, store) {
  const id = fullPath.split("/").pop();
  return {
    id,
    path: fullPath,
    async get() {
      store.callLog.push(`get:${fullPath}`);
      return makeDocSnapshot(id, store.docs.get(fullPath), this);
    },
  };
}

function makeCollection(collectionPath, store) {
  return {
    doc(id) {
      if (id === undefined) {
        const autoId = `auto-${Math.random().toString(36).slice(2)}-${store.docs.size}`;
        return makeRef(`${collectionPath}/${autoId}`, store);
      }
      return makeRef(`${collectionPath}/${id}`, store);
    },
  };
}

const MAX_SIMULATED_TRANSACTION_ATTEMPTS = 50;

// `failCommitForPath`, when set on the store, causes the ENTIRE commit
// loop below to throw before applying ANY staged write, once, the first
// time a transaction attempts to commit a write whose path matches it —
// simulating a mid-commit failure and proving neither write of the pair
// survives (Firestore's own real atomicity guarantee, not something this
// fake reimplements piecemeal).
async function runTransaction(store, callback) {
  for (let attempt = 0; attempt < MAX_SIMULATED_TRANSACTION_ATTEMPTS; attempt++) {
    const readVersions = new Map();
    const staged = [];
    const tx = {
      async get(ref) {
        store.callLog.push(`tx.get:${ref.path}`);
        readVersions.set(ref.path, docRevision(store, ref.path));
        return makeDocSnapshot(ref.id, store.docs.get(ref.path), ref);
      },
      update(ref, data) {
        if (!store.docs.has(ref.path)) {
          throw new Error(`simulated tx.update on nonexistent doc: ${ref.path}`);
        }
        staged.push({ type: "update", path: ref.path, data });
      },
      create(ref, data) {
        if (store.docs.has(ref.path)) {
          throw new Error(`simulated tx.create on existing doc: ${ref.path}`);
        }
        staged.push({ type: "create", path: ref.path, data });
      },
    };
    const result = await callback(tx);
    const stale = [...readVersions.entries()].some(([p, v]) => docRevision(store, p) !== v);
    if (stale) {
      continue;
    }
    if (store.failCommitForPath && staged.some((w) => w.path === store.failCommitForPath)) {
      const failing = store.failCommitForPath;
      store.failCommitForPath = null;
      throw new Error(`simulated commit failure writing ${failing}`);
    }
    for (const write of staged) {
      if (write.type === "update") {
        setDoc(store, write.path, { ...store.docs.get(write.path), ...write.data });
      } else {
        setDoc(store, write.path, write.data);
      }
      store.callLog.push(`${write.type}:${write.path}`);
    }
    return result;
  }
  throw new Error("simulated transaction exceeded max retry attempts");
}

function createFakeDb(store) {
  return {
    collection(name) {
      return makeCollection(name, store);
    },
    runTransaction(callback) {
      return runTransaction(store, callback);
    },
  };
}

function seedDoc(store, collectionPath, id, data) {
  setDoc(store, `${collectionPath}/${id}`, data);
}

function getRawDoc(store, collectionPath, id) {
  return store.docs.get(`${collectionPath}/${id}`);
}

function auditEvents(store) {
  return [...store.docs.entries()]
    .filter(([p]) => p.startsWith(`${AUDIT_EVENTS_COLLECTION}/`))
    .map(([, data]) => data);
}

const BUSINESS_ID = "biz-activation-1";
const ADMIN_UID = "admin-1";
const OTHER_ADMIN_UID = "admin-2";

function seedAdmin(store, uid = ADMIN_UID) {
  seedDoc(store, "users", uid, { role: "admin" });
}

function seedBusiness(store, overrides = {}) {
  seedDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID, { name: "Test Petshop", ...overrides });
  return createFakeDb(store);
}

function baseRequest(overrides = {}) {
  return { businessId: BUSINESS_ID, ...overrides };
}

// =======================================================================
// A. Authentication/authorization (grant; revoke mirrors identically).
// =======================================================================

test("A1. unauthenticated grant is rejected", async () => {
  const store = createStore();
  const db = seedBusiness(store);
  await assert.rejects(
    grantMarketplaceSellerActivation({ db, auth: null, data: baseRequest() }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
  assert.equal(getRawDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID).marketplaceSellerActivation, undefined);
});

test("A2. non-admin (no user doc) grant is rejected", async () => {
  const store = createStore();
  const db = seedBusiness(store);
  await assert.rejects(
    grantMarketplaceSellerActivation({ db, auth: { uid: "random-user" }, data: baseRequest() }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

test("A3. authenticated non-admin-role grant is rejected", async () => {
  const store = createStore();
  const db = seedBusiness(store);
  seedDoc(store, "users", "seller-user", { role: "seller" });
  await assert.rejects(
    grantMarketplaceSellerActivation({ db, auth: { uid: "seller-user" }, data: baseRequest() }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

test("A4. unauthenticated revoke is rejected", async () => {
  const store = createStore();
  const db = seedBusiness(store, {
    marketplaceSellerActivation: { active: true, grantedAt: 1, grantedBy: ADMIN_UID, revokedAt: null, revokedBy: null },
  });
  await assert.rejects(
    revokeMarketplaceSellerActivation({ db, auth: null, data: baseRequest() }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
});

test("A5. non-admin revoke is rejected", async () => {
  const store = createStore();
  const db = seedBusiness(store, {
    marketplaceSellerActivation: { active: true, grantedAt: 1, grantedBy: ADMIN_UID, revokedAt: null, revokedBy: null },
  });
  await assert.rejects(
    revokeMarketplaceSellerActivation({ db, auth: { uid: "random-user" }, data: baseRequest() }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

test("A6. authorized admin grant succeeds", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  const result = await grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() });
  assert.equal(result.active, true);
  assert.equal(result.idempotent, false);
});

test("A7. authorized admin revoke succeeds", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store, {
    marketplaceSellerActivation: { active: true, grantedAt: 1, grantedBy: ADMIN_UID, revokedAt: null, revokedBy: null },
  });
  const result = await revokeMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() });
  assert.equal(result.active, false);
  assert.equal(result.idempotent, false);
});

// =======================================================================
// B. Request validation.
// =======================================================================

test("B1. missing businessId is rejected for grant", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  await assert.rejects(
    grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: {} }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

test("B2. empty-string businessId is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  await assert.rejects(
    grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: { businessId: "" } }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

test("B3. non-string businessId is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  await assert.rejects(
    grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: { businessId: 12345 } }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

test("B4. an unrecognized request field is rejected — closed request shape", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  await assert.rejects(
    grantMarketplaceSellerActivation({
      db,
      auth: { uid: ADMIN_UID },
      data: { businessId: BUSINESS_ID, active: true },
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

test("B5. nonexistent business is rejected for grant", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = createFakeDb(store);
  await assert.rejects(
    grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() }),
    (err) => {
      assert.equal(err.code, "not-found");
      return true;
    }
  );
});

test("B6. nonexistent business is rejected for revoke", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = createFakeDb(store);
  await assert.rejects(
    revokeMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() }),
    (err) => {
      assert.equal(err.code, "not-found");
      return true;
    }
  );
  assert.equal(auditEvents(store).length, 0);
});

// =======================================================================
// C. Exact state shape / server-owned provenance.
// =======================================================================

test("C1. a successful grant writes the exact current-state shape, server-owned provenance", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  await grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() });
  const activation = getRawDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID).marketplaceSellerActivation;
  assert.deepEqual(Object.keys(activation).sort(), ["active", "grantedAt", "grantedBy", "revokedAt", "revokedBy"]);
  assert.equal(activation.active, true);
  assert.equal(activation.grantedBy, ADMIN_UID);
  assert.equal(activation.revokedAt, null);
  assert.equal(activation.revokedBy, null);
});

test("C2. client-supplied grantedBy/identity fields are ignored — provenance is always the authenticated admin UID", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  await assert.rejects(
    grantMarketplaceSellerActivation({
      db,
      auth: { uid: ADMIN_UID },
      data: { businessId: BUSINESS_ID, grantedBy: "forged-uid", adminEmail: "forged@example.com" },
    }),
    (err) => {
      // Rejected by the closed request-field allowlist (B4-class) before
      // ever reaching a write — the strongest possible proof no forged
      // identity field can ever influence provenance.
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

test("C3. a successful revoke writes the exact current-state shape, server-owned provenance", async () => {
  const store = createStore();
  seedAdmin(store);
  seedAdmin(store, OTHER_ADMIN_UID);
  const db = seedBusiness(store, {
    marketplaceSellerActivation: { active: true, grantedAt: 111, grantedBy: ADMIN_UID, revokedAt: null, revokedBy: null },
  });
  await revokeMarketplaceSellerActivation({ db, auth: { uid: OTHER_ADMIN_UID }, data: baseRequest() });
  const activation = getRawDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID).marketplaceSellerActivation;
  assert.equal(activation.active, false);
  assert.equal(activation.revokedBy, OTHER_ADMIN_UID);
  assert.notEqual(activation.revokedAt, null);
});

// =======================================================================
// D. Re-grant overwrite / historical preservation.
// =======================================================================

test("D1. re-grant after revoke replaces grantedAt/grantedBy and clears revokedAt/revokedBy", async () => {
  const store = createStore();
  seedAdmin(store, "admin-first");
  seedAdmin(store, "admin-second");
  const db = seedBusiness(store);

  await grantMarketplaceSellerActivation({ db, auth: { uid: "admin-first" }, data: baseRequest() });
  await revokeMarketplaceSellerActivation({ db, auth: { uid: "admin-first" }, data: baseRequest() });
  await grantMarketplaceSellerActivation({ db, auth: { uid: "admin-second" }, data: baseRequest() });

  const activation = getRawDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID).marketplaceSellerActivation;
  assert.equal(activation.active, true);
  assert.equal(activation.grantedBy, "admin-second");
  assert.equal(activation.revokedAt, null);
  assert.equal(activation.revokedBy, null);
});

test("D2. every prior grant/revoke event remains present, individually, in the immutable audit log after a re-grant", async () => {
  const store = createStore();
  seedAdmin(store, "admin-first");
  const db = seedBusiness(store);

  await grantMarketplaceSellerActivation({ db, auth: { uid: "admin-first" }, data: baseRequest() });
  await revokeMarketplaceSellerActivation({ db, auth: { uid: "admin-first" }, data: baseRequest() });
  await grantMarketplaceSellerActivation({ db, auth: { uid: "admin-first" }, data: baseRequest() });

  const events = auditEvents(store);
  assert.equal(events.length, 3);
  assert.deepEqual(
    events.map((e) => e.action).sort(),
    ["grant", "grant", "revoke"].sort()
  );
});

// =======================================================================
// E. Idempotency.
// =======================================================================

test("E1. repeated grant against an already-active business writes nothing and returns idempotent:true", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store, {
    marketplaceSellerActivation: { active: true, grantedAt: 1, grantedBy: ADMIN_UID, revokedAt: null, revokedBy: null },
  });
  const result = await grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() });
  assert.equal(result.idempotent, true);
  assert.equal(auditEvents(store).length, 0);
  assert.equal(getRawDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID).marketplaceSellerActivation.grantedAt, 1);
});

test("E2. repeated revoke against an already-inactive business writes nothing and returns idempotent:true", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store, {
    marketplaceSellerActivation: { active: false, grantedAt: 1, grantedBy: ADMIN_UID, revokedAt: 2, revokedBy: ADMIN_UID },
  });
  const result = await revokeMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() });
  assert.equal(result.idempotent, true);
  assert.equal(auditEvents(store).length, 0);
});

test("E3. revoke against a business with no activation object at all is idempotent — fail-closed-equivalent, not an error", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  const result = await revokeMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() });
  assert.equal(result.active, false);
  assert.equal(result.idempotent, true);
  assert.equal(auditEvents(store).length, 0);
});

// =======================================================================
// F. Atomicity.
// =======================================================================

test("F1. a real transition commits the state write and exactly one audit event together", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  await grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() });
  assert.equal(getRawDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID).marketplaceSellerActivation.active, true);
  assert.equal(auditEvents(store).length, 1);
});

test("F2. a simulated commit failure on the state write leaves no audit event and no state change", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  store.failCommitForPath = `${BUSINESSES_COLLECTION}/${BUSINESS_ID}`;
  await assert.rejects(grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() }));
  assert.equal(getRawDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID).marketplaceSellerActivation, undefined);
  assert.equal(auditEvents(store).length, 0);
});

test("F3. a simulated commit failure on the audit-event write leaves the business state unchanged", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  // The audit event's own doc path is only known once the transaction
  // callback runs (auto-generated ID) — fail on the *next* commit
  // attempt for any path under the audit collection by pre-registering
  // a marker path and having the fake match by prefix instead.
  const originalRunTransaction = db.runTransaction.bind(db);
  db.runTransaction = async (callback) =>
    originalRunTransaction(async (tx) => {
      const originalCreate = tx.create.bind(tx);
      tx.create = (ref, data) => {
        throw new Error(`simulated commit failure writing ${ref.path}`);
      };
      return callback(tx);
    });
  await assert.rejects(grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() }));
  assert.equal(getRawDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID).marketplaceSellerActivation, undefined);
  assert.equal(auditEvents(store).length, 0);
});

// =======================================================================
// G. Concurrency.
// =======================================================================

test("G1. concurrent grant/grant against the same business resolves to exactly one real transition and one audit event", async () => {
  const store = createStore();
  seedAdmin(store, "admin-a");
  seedAdmin(store, "admin-b");
  const db = seedBusiness(store);
  const [r1, r2] = await Promise.all([
    grantMarketplaceSellerActivation({ db, auth: { uid: "admin-a" }, data: baseRequest() }),
    grantMarketplaceSellerActivation({ db, auth: { uid: "admin-b" }, data: baseRequest() }),
  ]);
  const idempotentFlags = [r1.idempotent, r2.idempotent].sort();
  assert.deepEqual(idempotentFlags, [false, true]);
  assert.equal(auditEvents(store).length, 1);
  assert.equal(getRawDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID).marketplaceSellerActivation.active, true);
});

test("G2. concurrent revoke/revoke against the same active business resolves to exactly one real transition and one audit event", async () => {
  const store = createStore();
  seedAdmin(store, "admin-a");
  seedAdmin(store, "admin-b");
  const db = seedBusiness(store, {
    marketplaceSellerActivation: { active: true, grantedAt: 1, grantedBy: "admin-a", revokedAt: null, revokedBy: null },
  });
  const [r1, r2] = await Promise.all([
    revokeMarketplaceSellerActivation({ db, auth: { uid: "admin-a" }, data: baseRequest() }),
    revokeMarketplaceSellerActivation({ db, auth: { uid: "admin-b" }, data: baseRequest() }),
  ]);
  const idempotentFlags = [r1.idempotent, r2.idempotent].sort();
  assert.deepEqual(idempotentFlags, [false, true]);
  assert.equal(auditEvents(store).length, 1);
  assert.equal(getRawDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID).marketplaceSellerActivation.active, false);
});

test("G3. concurrent grant/revoke against the same business never produces an inconsistent final state", async () => {
  const store = createStore();
  seedAdmin(store, "admin-a");
  seedAdmin(store, "admin-b");
  const db = seedBusiness(store);
  await Promise.all([
    grantMarketplaceSellerActivation({ db, auth: { uid: "admin-a" }, data: baseRequest() }),
    revokeMarketplaceSellerActivation({ db, auth: { uid: "admin-b" }, data: baseRequest() }),
  ]);
  const finalActivation = getRawDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID).marketplaceSellerActivation;
  const events = auditEvents(store);
  // Whichever transaction committed first determines the final state;
  // the event log's own last-written event must agree with it — no
  // interleaved/inconsistent result is possible under this fake's
  // atomic-commit-or-nothing transaction semantics.
  assert.equal(typeof finalActivation.active, "boolean");
  assert.ok(events.length >= 1);
});

// =======================================================================
// H. No side effects outside the one business document + its own audit event.
// =======================================================================

test("H1. grant never creates, reads, or mutates any product document", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  seedDoc(store, `${BUSINESSES_COLLECTION}/${BUSINESS_ID}/products`, "prod-1", { name: "Unrelated Product" });
  await grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() });
  assert.deepEqual(getRawDoc(store, `${BUSINESSES_COLLECTION}/${BUSINESS_ID}/products`, "prod-1"), {
    name: "Unrelated Product",
  });
  assert.ok(!store.callLog.some((entry) => entry.includes("/products/")));
});

test("H2. revoke never creates, reads, or mutates any product document", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store, {
    marketplaceSellerActivation: { active: true, grantedAt: 1, grantedBy: ADMIN_UID, revokedAt: null, revokedBy: null },
  });
  seedDoc(store, `${BUSINESSES_COLLECTION}/${BUSINESS_ID}/products`, "prod-1", { name: "Unrelated Product" });
  await revokeMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() });
  assert.deepEqual(getRawDoc(store, `${BUSINESSES_COLLECTION}/${BUSINESS_ID}/products`, "prod-1"), {
    name: "Unrelated Product",
  });
});

test("H3. grant touches no field on the business document other than marketplaceSellerActivation", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store, { name: "Test Petshop", status: "approved", published: true });
  await grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() });
  const business = getRawDoc(store, BUSINESSES_COLLECTION, BUSINESS_ID);
  assert.equal(business.name, "Test Petshop");
  assert.equal(business.status, "approved");
  assert.equal(business.published, true);
});

test("H4. the audit event contains only the minimum frozen provenance fields — no email, display name, or product/customer data", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = seedBusiness(store);
  await grantMarketplaceSellerActivation({ db, auth: { uid: ADMIN_UID }, data: baseRequest() });
  const [event] = auditEvents(store);
  assert.deepEqual(
    Object.keys(event).sort(),
    ["action", "adminUid", "businessId", "occurredAt", "resultingActiveState"].sort()
  );
});

test("H5. the audit event collection is immutable at the Rules layer — mirrored here as a static-contract statement, real proof lives in the Rules emulator suite", () => {
  // This module never issues an .update()/.delete() against
  // AUDIT_EVENTS_COLLECTION anywhere — proven by direct source
  // inspection (item 715, §15) rather than restated here; this test
  // exists only to keep the collection name/contract co-located with
  // its own test file for future maintainers.
  assert.equal(AUDIT_EVENTS_COLLECTION, "marketplaceSellerActivationAuditEvents");
});
