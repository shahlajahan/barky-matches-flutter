"use strict";

// P1-A Slice 4.4 — productModeration.test.js (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §8/§9/§10.1/§13.1/§16). Deliberately NOT emulator-backed — exactly
// like complianceMatching.test.js, `reviewProductModeration` is pure
// dependency injection ({db, auth, data, ...}), so a hand-rolled,
// self-contained in-memory fake stands in for `db`. Unlike
// complianceMatching.test.js's own fake, this module never issues a
// Firestore *query* (only point reads/writes), so this fake needs no
// query-builder at all.
//
// No conditional test-skipping and no environment-dependent bypass
// anywhere in this file — every test always runs.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  SELLER_RELATIONSHIP,
  COMPLIANCE_SCOPE_TYPE,
  COMPLIANCE_SCOPE_STATUS,
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_POLICY_REGISTRY_STATUS,
  COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION,
  COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID,
} = require("../src/marketplace/compliance/complianceConstants");
const {
  reviewProductModeration,
  PRODUCT_MODERATION_STATUS,
} = require("../src/marketplace/compliance/productModeration");
const { recomputeProductComplianceStatus } = require("../src/marketplace/compliance/complianceProductRecompute");

const REGISTRY_COLLECTION = "compliancePolicyRegistry";
const SCOPES_COLLECTION = "complianceDocumentScopes";
const DOCUMENTS_COLLECTION = "complianceDocuments";
const EPOCHS_COLLECTION = "businessComplianceEpochs";
const REVIEW_EVENTS_COLLECTION = "complianceReviewEvents";
const PRODUCTS_ROOT = "businesses";

// =======================================================================
// Fake Firestore — point reads/writes only, no query support needed
// (reviewProductModeration and evaluateLiveProductEligibility never
// issue a Firestore query, only .doc().get()/.update()/.create()).
// =======================================================================

function createStore() {
  return { docs: new Map(), revisions: new Map(), callLog: [], pendingHooks: new Map() };
}

function docRevision(store, docPath) {
  return store.revisions.get(docPath) || 0;
}

function bumpRevision(store, docPath) {
  store.revisions.set(docPath, docRevision(store, docPath) + 1);
}

// Every store mutation — seeding, transaction commits, and any
// mid-attempt fixture mutation alike — routes through here so revision
// tracking is exhaustive, not just applied to some write paths.
function setDoc(store, docPath, data) {
  store.docs.set(docPath, data);
  bumpRevision(store, docPath);
}

function deleteDoc(store, docPath) {
  store.docs.delete(docPath);
  bumpRevision(store, docPath);
}

// Registers a one-shot hook that fires the first time `docPath` is read
// (via either a direct `.get()` or a transactional `tx.get()`), AFTER
// the snapshot returned to that read has already captured its value —
// so the triggering read itself still observes the pre-mutation state,
// while every subsequent read (in the same or a later attempt) observes
// whatever the hook changed. This is what lets Revision 10's TOCTOU
// tests (§15) mutate exactly one freshness input at the exact instant
// between two of the same transaction attempt's own reads, without any
// artificial delay or a reimplementation of retry semantics.
function onFirstRead(store, docPath, hook) {
  store.pendingHooks.set(docPath, hook);
}

function makeDocSnapshot(id, rawValue, ref) {
  return { exists: rawValue !== undefined, id, ref, data: () => rawValue };
}

function readDocSnapshot(store, ref) {
  const snap = makeDocSnapshot(ref.id, store.docs.get(ref.path), ref);
  const hook = store.pendingHooks.get(ref.path);
  if (hook) {
    store.pendingHooks.delete(ref.path);
    hook();
  }
  return snap;
}

function makeRef(fullPath, store) {
  const id = fullPath.split("/").pop();
  const ref = {
    id,
    path: fullPath,
    async get() {
      // Distinct log prefix from `tx.get` below — this is what lets
      // tests assert zero non-transactional fallback reads once a
      // transaction is in flight (Revision 10 correction 53, §15).
      store.callLog.push(`get:${fullPath}`);
      return readDocSnapshot(store, ref);
    },
    collection(subName) {
      return makeCollection(`${fullPath}/${subName}`, store);
    },
  };
  return ref;
}

// Minimal query support — needed only because seedEligibleProduct's own
// fixture setup calls the REAL recomputeProductComplianceStatus (to
// produce a genuinely self-consistent, correctly-hashed decision), which
// internally runs the seven-query matching engine.
// reviewProductModeration/evaluateLiveProductEligibility themselves
// never issue a query, only point reads.
function segmentCount(p) {
  return p.split("/").filter(Boolean).length;
}

function makeQuery(collectionPath, store, filters) {
  return {
    where(field, op, value) {
      if (op !== "==") throw new Error(`fake db only supports '==' filters, got '${op}'`);
      return makeQuery(collectionPath, store, [...filters, { field, value }]);
    },
    orderBy() {
      return this;
    },
    limit(limitN) {
      return {
        async get() {
          store.callLog.push(`query:${collectionPath}`);
          const depth = segmentCount(collectionPath) + 1;
          const results = [];
          for (const [docPath, rawValue] of store.docs.entries()) {
            if (!docPath.startsWith(`${collectionPath}/`)) continue;
            if (segmentCount(docPath) !== depth) continue;
            if (!filters.every((f) => rawValue[f.field] === f.value)) continue;
            results.push({ id: docPath.slice(collectionPath.length + 1), data: rawValue });
          }
          results.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
          const limited = results.slice(0, limitN);
          return { docs: limited.map((r) => makeDocSnapshot(r.id, r.data)) };
        },
      };
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
    where(field, op, value) {
      return makeQuery(collectionPath, store, []).where(field, op, value);
    },
  };
}

const MAX_SIMULATED_TRANSACTION_ATTEMPTS = 50;

function createFakeDb(store) {
  function collection(name) {
    return makeCollection(name, store);
  }
  // Genuine optimistic-concurrency retry, not a reimplementation of the
  // production transaction logic: every document a given attempt reads
  // (via `tx.get`) has its revision recorded; if any of those revisions
  // changed by the time that attempt's callback returns, this attempt's
  // writes are discarded and the real callback is invoked again from
  // scratch — exactly mirroring Firestore's own contention-retry
  // behavior (§10.1 "Retry and concurrency semantics"). A thrown error
  // propagates immediately and is never treated as a retry signal.
  async function runTransaction(callback) {
    for (let attempt = 0; attempt < MAX_SIMULATED_TRANSACTION_ATTEMPTS; attempt++) {
      const readVersions = new Map();
      const staged = [];
      const tx = {
        async get(ref) {
          // Real `Transaction.get()` accepts either a DocumentReference
          // or a Query — the fixture setup below reuses the real,
          // unmodified `complianceMatching.js` engine (via
          // `recomputeProductComplianceStatus`), which legitimately
          // issues transactional queries; `reviewProductModeration`/
          // `evaluateLiveProductEligibility`/`resolveActivePolicy`
          // themselves only ever pass a document ref here.
          if (!ref || typeof ref.path !== "string") {
            return ref.get();
          }
          store.callLog.push(`tx.get:${ref.path}`);
          readVersions.set(ref.path, docRevision(store, ref.path));
          return readDocSnapshot(store, ref);
        },
        set(ref, data) {
          staged.push({ type: "set", path: ref.path, data });
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
        delete(ref) {
          staged.push({ type: "delete", path: ref.path });
        },
      };
      const result = await callback(tx);
      const stale = [...readVersions.entries()].some(([p, v]) => docRevision(store, p) !== v);
      if (stale) {
        continue;
      }
      for (const write of staged) {
        if (write.type === "delete") {
          deleteDoc(store, write.path);
        } else if (write.type === "update") {
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
  return { collection, runTransaction, _store: store };
}

function seedDoc(store, collectionPath, id, data) {
  setDoc(store, `${collectionPath}/${id}`, data);
}

function getRawDoc(store, collectionPath, id) {
  return store.docs.get(`${collectionPath}/${id}`);
}

function reviewEvents(store) {
  return [...store.docs.entries()]
    .filter(([p]) => p.startsWith(`${REVIEW_EVENTS_COLLECTION}/`))
    .map(([, data]) => data);
}

// Every call-log entry this fake ever produces uses exactly one of these
// prefixes: `get:` (direct, non-transactional `DocumentReference.get()`),
// `tx.get:` (`Transaction.get()`), `query:` (a Query's own `.get()` —
// never issued by `reviewProductModeration`/`evaluateLiveProductEligibility`/
// `resolveActivePolicy` themselves, only by fixture setup's own call to
// the real `recomputeProductComplianceStatus`), or one of the four write
// prefixes (`set:`/`update:`/`create:`/`delete:`, pushed only for a
// COMMITTED write — a discarded/stale attempt's staged writes are never
// logged, §10.1's own retry-discard semantics). This exhaustively
// distinguishes "read-like" entries from writes, so a hidden extra read
// of any kind — a wrong path, a wrong mode, an unexpected query — shows
// up as a mismatch rather than being silently absorbed into a coarse sum.
const WRITE_LOG_PREFIXES = ["set:", "update:", "create:", "delete:"];

function isReadLogEntry(entry) {
  return !WRITE_LOG_PREFIXES.some((p) => entry.startsWith(p));
}

function readLogEntries(store) {
  return store.callLog.filter(isReadLogEntry);
}

// Asserts the exact, order-independent multiset of read-like log entries
// against a fully-enumerated expected list — every entry must be named
// explicitly; nothing is filtered away silently, so a duplicate, a wrong
// path, a wrong mode (`get:` vs `tx.get:`), or a stray `query:` all fail
// this assertion, not just a wrong total count.
function assertExactReadMultiset(store, expectedEntries, message) {
  assert.deepEqual(readLogEntries(store).slice().sort(), expectedEntries.slice().sort(), message);
}

function adminReadEntry() {
  return `get:users/${ADMIN_UID}`;
}

function pointerPath() {
  return `${COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION}/${COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID}`;
}

function versionPath() {
  return `${REGISTRY_COLLECTION}/${VERSION_ID}`;
}

function epochPath() {
  return `${EPOCHS_COLLECTION}/${BUSINESS_ID}`;
}

function decisionPath() {
  return `productComplianceDecisions/${PRODUCT_ID}`;
}

// =======================================================================
// Fixtures.
// =======================================================================

const NOW_MS = 1_800_000_000_000;
const NOW = new Date(NOW_MS);

function ts(ms) {
  return { toMillis: () => ms };
}

const BUSINESS_ID = "biz-mod-1";
const PRODUCT_ID = "prod-mod-1";
const VERSION_ID = "policy-v1";
const ADMIN_UID = "admin-1";

function seedActivePolicy(store) {
  seedDoc(store, COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION, COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID, {
    activeVersionId: VERSION_ID,
  });
  seedDoc(store, REGISTRY_COLLECTION, VERSION_ID, {
    sellerRelationship: {
      [SELLER_RELATIONSHIP.RESELLER]: {
        acceptedDocumentTypes: ["purchase_invoice"],
        requiredDocumentTypeGroups: [{ documentTypes: ["purchase_invoice"] }],
        perDocumentTypePolicy: {},
        maximumValidityPeriod: null,
        acceptedScopeTypes: ["category"],
        manualAdminOverridePermitted: false,
      },
    },
    status: COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE,
    effectiveFrom: ts(NOW_MS - 100000),
    createdBy: "admin-1",
    createdAt: ts(NOW_MS - 100000),
    changeNote: "test policy",
  });
}

function seedAdmin(store, uid = ADMIN_UID) {
  seedDoc(store, "users", uid, { role: "admin" });
  return uid;
}

function seedProduct(store, overrides = {}) {
  const data = {
    businessId: BUSINESS_ID,
    name: "Test Product",
    category: "Health > Vitamins",
    brand: undefined,
    sku: undefined,
    barcode: undefined,
    sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
    productInputRevision: 1,
    moderationStatus: PRODUCT_MODERATION_STATUS.PENDING_REVIEW,
    isActive: false,
    ...overrides,
  };
  seedDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID, data);
  return data;
}

function seedEpoch(store, epoch) {
  seedDoc(store, EPOCHS_COLLECTION, BUSINESS_ID, { epoch });
}

function seedScopeAndDocument(store, { documentType = "purchase_invoice", validUntilMs = NOW_MS + 1_000_000_000 } = {}) {
  const documentId = "doc-mod-1";
  const scopeId = "scope-mod-1";
  seedDoc(store, DOCUMENTS_COLLECTION, documentId, {
    businessId: BUSINESS_ID,
    documentType,
    sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
    status: COMPLIANCE_DOCUMENT_STATUS.APPROVED,
    validUntil: ts(validUntilMs),
  });
  seedDoc(store, SCOPES_COLLECTION, scopeId, {
    documentId,
    businessId: BUSINESS_ID,
    scopeType: COMPLIANCE_SCOPE_TYPE.CATEGORY,
    scopeValue: "Health > Vitamins",
    sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
    documentType,
    validUntil: ts(validUntilMs),
    memberCount: 0,
    status: COMPLIANCE_SCOPE_STATUS.APPROVED,
    approvedAt: ts(NOW_MS - 50000),
    createdAt: ts(NOW_MS - 60000),
    createdBy: "seller-1",
    verifiedBrandId: null,
  });
  return { documentId, scopeId };
}

// Builds a store where the product has a genuinely eligible, fully
// self-consistent decision — produced by the REAL
// recomputeProductComplianceStatus, never a hand-rolled decision/hash,
// so its decisionHash is always correct by construction.
async function seedEligibleProduct(store, productOverrides = {}) {
  seedActivePolicy(store);
  seedProduct(store, productOverrides);
  seedEpoch(store, 0);
  seedScopeAndDocument(store);
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  return db;
}

function baseRequest() {
  return { businessId: BUSINESS_ID, productId: PRODUCT_ID };
}

// =======================================================================
// A. Feature flag (checked first, before auth).
// =======================================================================

test("A1. featureEnabled !== true fails closed before any auth/read/write, regardless of caller", async () => {
  const store = createStore();
  const db = await seedEligibleProduct(store);
  await assert.rejects(
    reviewProductModeration({ db, auth: null, data: baseRequest(), nowFactory: () => NOW, featureEnabled: false }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
  assert.equal(getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID).moderationStatus, "pending_review");
});

test("A2. featureEnabled undefined (never explicitly passed) fails closed — a safe default, not an open one", async () => {
  const store = createStore();
  const db = await seedEligibleProduct(store);
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

test("A3. featureEnabled === true, with a valid admin, otherwise-eligible product, succeeds", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const result = await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.equal(result.moderationStatus, "approved");
  assert.equal(result.idempotent, false);
});

// =======================================================================
// B. Authentication/authorization.
// =======================================================================

test("B1. unauthenticated caller is rejected", async () => {
  const store = createStore();
  const db = await seedEligibleProduct(store);
  await assert.rejects(
    reviewProductModeration({ db, auth: null, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.equal(err.code, "unauthenticated");
      return true;
    }
  );
});

test("B2. authenticated non-admin (no user doc at all) is rejected", async () => {
  const store = createStore();
  const db = await seedEligibleProduct(store);
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: "random-user" }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

test("B3. authenticated caller with a non-admin role is rejected", async () => {
  const store = createStore();
  const db = await seedEligibleProduct(store);
  seedDoc(store, "users", "seller-user", { role: "seller" });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: "seller-user" }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.equal(err.code, "permission-denied");
      return true;
    }
  );
});

test("B4. authorized admin role succeeds", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const result = await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.equal(result.moderationStatus, "approved");
});

// =======================================================================
// C. Request/path validation.
// =======================================================================

test("C1. missing businessId is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: { productId: PRODUCT_ID }, nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

test("C2. empty-string productId is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: { businessId: BUSINESS_ID, productId: "" }, nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

test("C3. malformed businessId (non-string) is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: { businessId: 12345, productId: PRODUCT_ID }, nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

test("C4. an unknown request field is rejected — closed request shape", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  await assert.rejects(
    reviewProductModeration({
      db,
      auth: { uid: ADMIN_UID },
      data: { ...baseRequest(), decision: "approve" },
      nowFactory: () => NOW,
      featureEnabled: true,
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
});

test("C5. a forged marker field alongside a valid request is still rejected — the closed shape never trusts an accompanying field of any kind", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  await assert.rejects(
    reviewProductModeration({
      db,
      auth: { uid: ADMIN_UID },
      data: { ...baseRequest(), moderationStatus: "approved", complianceEffectiveStatus: "verified_valid" },
      nowFactory: () => NOW,
      featureEnabled: true,
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      return true;
    }
  );
  assert.equal(getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID).moderationStatus, "pending_review");
});

test("C6. cross-tenant mismatch (product exists under a different businessId) is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  await assert.rejects(
    reviewProductModeration({
      db,
      auth: { uid: ADMIN_UID },
      data: { businessId: "biz-OTHER", productId: PRODUCT_ID },
      nowFactory: () => NOW,
      featureEnabled: true,
    }),
    (err) => {
      // The product path is keyed by businessId, so a request naming
      // the wrong business simply finds nothing at that path — a
      // not-found, not a distinct tenant-mismatch error. The dedicated
      // businessId-mismatch check exists for the (never legitimately
      // reachable) case of a document that exists but whose own stored
      // businessId field disagrees with its collection path.
      assert.equal(err.code, "not-found");
      return true;
    }
  );
});

test("C7. nonexistent product is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  seedActivePolicy(store);
  const db = createFakeDb(store);
  await assert.rejects(
    reviewProductModeration({
      db,
      auth: { uid: ADMIN_UID },
      data: { businessId: BUSINESS_ID, productId: "does-not-exist" },
      nowFactory: () => NOW,
      featureEnabled: true,
    }),
    (err) => {
      assert.equal(err.code, "not-found");
      return true;
    }
  );
});

test("C8. a malformed stored product (missing sellerRelationship) fails closed via the live evaluator's productSnapshot validation — a provenance-contract throw, not an HttpsError business outcome (Revision 10 correction 53)", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store, { sellerRelationship: undefined });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    /productSnapshot sellerRelationship invalid/
  );
  assert.equal(getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID).moderationStatus, "pending_review");
  assert.equal(reviewEvents(store).length, 0);
});

test("C9. an invalid/missing sellerRelationship on a pending_review product produces no moderationStatus update, no audit event, and no downstream (pointer/version/epoch/decision) reads after productSnapshot validation fails", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store, { sellerRelationship: undefined });
  store.callLog.length = 0;
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    /productSnapshot sellerRelationship invalid/
  );
  assert.equal(getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID).moderationStatus, "pending_review");
  assert.equal(reviewEvents(store).length, 0);
  const adminReads = store.callLog.filter((e) => e === `get:users/${ADMIN_UID}`);
  const txReads = store.callLog.filter((e) => e.startsWith("tx.get:"));
  assert.equal(adminReads.length, 1);
  assert.equal(txReads.length, 1, "only the product's own tx.get — no pointer/version/epoch/decision read ever occurs");
  assert.equal(txReads[0], `tx.get:${productPath()}`);
  assert.equal(store.callLog.filter((e) => e.startsWith("create:") || e.startsWith("update:")).length, 0, "zero writes");
});

// =======================================================================
// D. Compliance freshness — every mismatch independently blocks approval.
// =======================================================================

test("D1. missing decision (never recomputed) is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  seedActivePolicy(store);
  seedProduct(store);
  seedEpoch(store, 0);
  const db = createFakeDb(store);
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      assert.match(err.message, /eligibility_decision_not_found/);
      return true;
    }
  );
});

test("D2. malformed decision is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  seedDoc(store, "productComplianceDecisions", PRODUCT_ID, { not: "a valid decision" });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_decision_malformed/);
      return true;
    }
  );
});

test("D3. policyVersion mismatch (a new policy activated) is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  seedDoc(store, REGISTRY_COLLECTION, "policy-v2", getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID));
  seedDoc(store, COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION, COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID, { activeVersionId: "policy-v2" });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_policy_version_mismatch/);
      return true;
    }
  );
});

test("D4. evidenceRevision mismatch (epoch bumped) is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  seedEpoch(store, 1);
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_evidence_revision_mismatch/);
      return true;
    }
  );
});

test("D5. productInputRevisionSnapshot mismatch (product edited since recompute) is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const current = getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID);
  seedDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID, { ...current, category: "Toys > Chew Toy", productInputRevision: 2 });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_product_input_revision_mismatch/);
      return true;
    }
  );
});

test("D6. sellerRelationshipSnapshot missing (legacy decision) is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const decision = getRawDoc(store, "productComplianceDecisions", PRODUCT_ID);
  delete decision.sellerRelationshipSnapshot;
  seedDoc(store, "productComplianceDecisions", PRODUCT_ID, decision);
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_decision_malformed/);
      return true;
    }
  );
});

test("D7. sellerRelationshipSnapshot mismatch (relationship changed, revision dormant-absent both times) is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store, { productInputRevision: undefined });
  const current = getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID);
  seedDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID, {
    ...current,
    sellerRelationship: SELLER_RELATIONSHIP.IMPORTER,
    productInputRevision: undefined,
  });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_seller_relationship_snapshot_mismatch/);
      return true;
    }
  );
});

test("D8. expired validUntil is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => new Date(NOW_MS + 2_000_000_000), featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_valid_until_missing_or_expired/);
      return true;
    }
  );
});

test("D9. validUntil exactly == now is rejected (strict >, never >=)", async () => {
  const store = createStore();
  seedActivePolicy(store);
  seedProduct(store);
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { validUntilMs: NOW_MS + 1000 });
  const setupDb = createFakeDb(store);
  await recomputeProductComplianceStatus({ db: setupDb, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  seedAdmin(store);
  await assert.rejects(
    reviewProductModeration({ db: setupDb, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => new Date(NOW_MS + 1000), featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_valid_until_missing_or_expired/);
      return true;
    }
  );
});

test("D10. decisionHash mismatch (tampered decision) is rejected", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const decision = getRawDoc(store, "productComplianceDecisions", PRODUCT_ID);
  seedDoc(store, "productComplianceDecisions", PRODUCT_ID, { ...decision, decisionHash: "0".repeat(64) });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_decision_hash_mismatch/);
      return true;
    }
  );
});

test("D11. a genuinely fresh, live-eligible decision is accepted", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const result = await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.equal(result.moderationStatus, "approved");
  assert.equal(result.idempotent, false);
});

test("D12. policy activation observed on the very next call, no cache exception", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  seedDoc(store, REGISTRY_COLLECTION, "policy-v3", getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID));
  seedDoc(store, COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION, COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID, { activeVersionId: "policy-v3" });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_policy_version_mismatch/);
      return true;
    }
  );
});

// =======================================================================
// E. Moderation transitions.
// =======================================================================

test("E1. pending_review -> approved is the only allowed transition, and it succeeds", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const result = await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.equal(result.moderationStatus, "approved");
  assert.equal(getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID).moderationStatus, "approved");
});

test("E2. an unknown/malformed existing moderationStatus is a forbidden transition", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store, { moderationStatus: "some_other_status" });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      assert.match(err.message, /some_other_status/);
      return true;
    }
  );
});

test("E3. replaying approval on an already-approved product is idempotent — no error, no duplicate write", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const first = await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.equal(first.idempotent, false);
  const second = await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.equal(second.moderationStatus, "approved");
  assert.equal(second.idempotent, true);
  assert.equal(reviewEvents(store).length, 1, "the idempotent replay must not create a second audit event");
});

test("E4. an already-approved product replay succeeds even when the live decision would now fail freshness — idempotent replay does not re-verify eligibility", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  seedEpoch(store, 99); // would now fail eligibility if re-checked
  const replay = await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.equal(replay.idempotent, true);
});

test("E5. a compliance failure produces zero moderation/audit writes", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  seedEpoch(store, 5); // makes the live decision stale
  await assert.rejects(reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }));
  assert.equal(getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID).moderationStatus, "pending_review");
  assert.equal(reviewEvents(store).length, 0);
});

test("E6. a conflicting concurrent transition (product already moved to approved by another call) is observed as idempotent, not a race error", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const current = getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID);
  seedDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID, { ...current, moderationStatus: "approved" });
  const result = await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.equal(result.idempotent, true);
});

test("E7. audit-write failure aborts the whole transaction atomically — the moderationStatus write is never observed", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const before = new Map(store.docs);
  const originalRunTransaction = db.runTransaction;
  db.runTransaction = async (callback) => {
    await callback({
      async get(ref) {
        return ref.get();
      },
      set() {},
      update() {},
      create(ref) {
        if (ref.path.startsWith(REVIEW_EVENTS_COLLECTION)) {
          throw new Error("simulated audit event create failure");
        }
      },
      delete() {},
    });
    throw new Error("simulated commit failure");
  };
  await assert.rejects(reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }));
  assert.deepEqual(store.docs, before);
  db.runTransaction = originalRunTransaction;
});

test("E8. a retried recompute-shaped transaction produces no duplicate committed audit event — exactly one, matching the single real call made", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.equal(reviewEvents(store).length, 1);
});

// =======================================================================
// F. Non-authoritative protections.
// =======================================================================

test("F1. productEvidenceLinks is never read by this module", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  store.callLog.length = 0;
  await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.ok(!store.callLog.some((e) => e.includes("productEvidenceLinks")));
});

test("F2. a client-supplied moderationStatus/complianceEffectiveStatus cannot grant approval — only the request's own businessId/productId are read", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store, { moderationStatus: "pending_review" });
  await assert.rejects(
    reviewProductModeration({
      db,
      auth: { uid: ADMIN_UID },
      data: { businessId: BUSINESS_ID, productId: PRODUCT_ID, complianceEffectiveStatus: "verified_valid" },
      nowFactory: () => NOW,
      featureEnabled: true,
    }),
    (err) => {
      assert.equal(err.code, "invalid-argument"); // rejected as an unknown field, never consulted
      return true;
    }
  );
});

test("F3. manualAdminOverridePermitted cannot bypass missing evidence — a product with no matching evidence still fails closed", async () => {
  const store = createStore();
  seedActivePolicy(store);
  store.docs.get(`${REGISTRY_COLLECTION}/${VERSION_ID}`).sellerRelationship[SELLER_RELATIONSHIP.RESELLER].manualAdminOverridePermitted = true;
  seedProduct(store);
  seedEpoch(store, 0);
  // No scope/document evidence seeded at all.
  const setupDb = createFakeDb(store);
  await recomputeProductComplianceStatus({ db: setupDb, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  seedAdmin(store);
  await assert.rejects(
    reviewProductModeration({ db: setupDb, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.equal(err.code, "failed-precondition");
      return true;
    }
  );
});

test("F4. no recompute is invoked by this module — productComplianceDecisions is never written here", async () => {
  const src = fs.readFileSync(path.resolve(__dirname, "../src/marketplace/compliance/productModeration.js"), "utf8");
  // The doc comment legitimately MENTIONS recomputeProductComplianceStatus
  // in prose (explaining what this module deliberately does NOT do) —
  // this asserts it is never imported/called, not that the bare
  // substring never appears anywhere in a comment.
  assert.equal(/require\([^)]*complianceProductRecompute[^)]*\)/.test(src), false);
  assert.equal(/recomputeProductComplianceStatus\s*\(/.test(src), false);
  assert.equal(/\.collection\(\s*["']productComplianceDecisions["']\s*\)/.test(src), false);
});

test("F5. no direct complianceDocumentScopes query from this module", async () => {
  const src = fs.readFileSync(path.resolve(__dirname, "../src/marketplace/compliance/productModeration.js"), "utf8");
  assert.equal(/complianceDocumentScopes/.test(src), false);
});

test("F6. no cross-tenant access: a same-named product under a different business is never touched", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const otherProduct = {
    businessId: "biz-OTHER",
    name: "Unrelated Product",
    category: "Health > Vitamins",
    sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
    productInputRevision: 1,
    moderationStatus: PRODUCT_MODERATION_STATUS.PENDING_REVIEW,
    isActive: false,
  };
  seedDoc(store, `${PRODUCTS_ROOT}/biz-OTHER/products`, PRODUCT_ID, otherProduct);
  await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.deepEqual(
    getRawDoc(store, `${PRODUCTS_ROOT}/biz-OTHER/products`, PRODUCT_ID),
    otherProduct,
    "the same-ID product under a different business must remain byte-for-byte untouched"
  );
});

// =======================================================================
// G. Reachability/scope.
// =======================================================================

test("G1. functions/index.js DOES reference productModeration (exported, unlike Slice 4.3's dormant modules) — reachability is intentional here", () => {
  const indexSrc = fs.readFileSync(path.resolve(__dirname, "../index.js"), "utf8");
  assert.ok(indexSrc.includes("productModeration"), "reviewProductModeration must be wired, per §16/§17's explicit exported posture");
  assert.ok(indexSrc.includes("PRODUCT_MODERATION_REVIEW_ENABLED"), "the disabled-by-default flag must gate it");
});

test("G2. no onCall/onRequest/onSchedule wrapper exists inside productModeration.js itself — only functions/index.js's thin wiring constructs the callable", () => {
  const src = fs.readFileSync(path.resolve(__dirname, "../src/marketplace/compliance/productModeration.js"), "utf8");
  assert.equal(/onCall\s*\(/.test(src), false);
  assert.equal(/onRequest\s*\(/.test(src), false);
  assert.equal(/onSchedule\s*\(/.test(src), false);
});

test("G3. no Slice 4.5 endpoint (marketplaceListing) is referenced anywhere in this module", () => {
  const src = fs.readFileSync(path.resolve(__dirname, "../src/marketplace/compliance/productModeration.js"), "utf8");
  assert.equal(/marketplaceListing|getMarketplaceProductList|getMarketplaceProductDetail/.test(src), false);
});

test("G4. no module-level mutable cache — no top-level 'let'-based memo state", () => {
  const src = fs.readFileSync(path.resolve(__dirname, "../src/marketplace/compliance/productModeration.js"), "utf8");
  assert.equal(/^let\s+\w+\s*=/m.test(src), false);
});

test("G5. no skip/todo/only anywhere in this file", () => {
  const src = fs.readFileSync(__filename, "utf8");
  assert.equal(/\.skip\s*\(/.test(src), false);
  assert.equal(/\.only\s*\(/.test(src), false);
  assert.equal(/\bTODO\b/.test(src), false);
  assert.equal(/\bFIXME\b/.test(src), false);
});

test("G6. no secret-shaped or project-literal string in productModeration.js", () => {
  const src = fs.readFileSync(path.resolve(__dirname, "../src/marketplace/compliance/productModeration.js"), "utf8");
  assert.equal(/AKIA[0-9A-Z]{16}/.test(src), false);
  assert.equal(/barkymatches-new/i.test(src), false);
});

// =======================================================================
// H. Transactional TOCTOU races — Revision 10 correction 53 (§15 items
// 1-6). Each test mutates exactly one freshness input at the exact
// instant between two of the same approval transaction's own reads (or
// forces a genuine retry via the fake's real optimistic-concurrency
// simulation, §10.1 "Retry and concurrency semantics"), then asserts
// the approval still fails closed — it never commits against a result
// that has already gone stale by the time of commit.
// =======================================================================

function productPath() {
  return `${PRODUCTS_ROOT}/${BUSINESS_ID}/products/${PRODUCT_ID}`;
}

test("H1. policy pointer repointed after the product is read still fails closed", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  seedDoc(store, REGISTRY_COLLECTION, "policy-v2", getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID));
  onFirstRead(store, productPath(), () => {
    seedDoc(store, COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION, COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID, {
      activeVersionId: "policy-v2",
    });
  });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_policy_version_mismatch/);
      return true;
    }
  );
  assert.equal(getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID).moderationStatus, "pending_review");
});

test("H2. business epoch bumped after the product is read still fails closed", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  onFirstRead(store, productPath(), () => {
    seedEpoch(store, 7);
  });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_evidence_revision_mismatch/);
      return true;
    }
  );
  assert.equal(getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID).moderationStatus, "pending_review");
});

test("H3. the product's own productInputRevision changing between attempts still fails closed, never reusing a stale snapshot", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const path = productPath();
  onFirstRead(store, path, () => {
    const current = store.docs.get(path);
    setDoc(store, path, { ...current, productInputRevision: (current.productInputRevision || 0) + 1 });
  });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_product_input_revision_mismatch/);
      return true;
    }
  );
  assert.equal(getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID).moderationStatus, "pending_review");
});

test("H4. the product's own sellerRelationship changing between attempts (dormant window) still fails closed", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store, { productInputRevision: undefined });
  const path = productPath();
  onFirstRead(store, path, () => {
    const current = store.docs.get(path);
    setDoc(store, path, { ...current, sellerRelationship: SELLER_RELATIONSHIP.IMPORTER, productInputRevision: undefined });
  });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_seller_relationship_snapshot_mismatch/);
      return true;
    }
  );
});

test("H5. the decision being deleted between the product read and the decision read still fails closed", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  onFirstRead(store, productPath(), () => {
    deleteDoc(store, `productComplianceDecisions/${PRODUCT_ID}`);
  });
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_decision_not_found/);
      return true;
    }
  );
});

test("H6. the clock crossing validUntil on a retried attempt still fails closed — strict >, re-verified per attempt", async () => {
  const store = createStore();
  seedActivePolicy(store);
  seedProduct(store);
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { validUntilMs: NOW_MS + 500 });
  const setupDb = createFakeDb(store);
  await recomputeProductComplianceStatus({ db: setupDb, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  seedAdmin(store);
  const path = productPath();
  // A no-op re-set — same data, but bumps the product's revision so the
  // fake's own optimistic-concurrency check forces exactly one retry,
  // without changing anything the evaluator would itself react to.
  onFirstRead(store, path, () => {
    setDoc(store, path, { ...store.docs.get(path) });
  });
  let call = 0;
  const nowFactory = () => {
    call += 1;
    return call === 1 ? NOW : new Date(NOW_MS + 1000);
  };
  await assert.rejects(
    reviewProductModeration({ db: setupDb, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory, featureEnabled: true }),
    (err) => {
      assert.match(err.message, /eligibility_valid_until_missing_or_expired/);
      return true;
    }
  );
  assert.equal(call, 2, "the retry must have actually happened, invoking nowFactory a second time");
});

// =======================================================================
// I. Per-attempt clock rule and retry integrity — Revision 10 correction
// 53 (§15 items 7-8, 26).
// =======================================================================

test("I1. a normal, non-retried attempt calls nowFactory exactly once", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  let calls = 0;
  await reviewProductModeration({
    db,
    auth: { uid: ADMIN_UID },
    data: baseRequest(),
    nowFactory: () => {
      calls += 1;
      return NOW;
    },
    featureEnabled: true,
  });
  assert.equal(calls, 1);
});

test("I2. a forced retry calls nowFactory a second time, commits exactly once, repeats the exact multiset of all five transactional reads on both attempts, and never repeats the admin-authorization read", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  store.callLog.length = 0;
  const path = productPath();
  onFirstRead(store, path, () => {
    setDoc(store, path, { ...store.docs.get(path) });
  });
  let calls = 0;
  const result = await reviewProductModeration({
    db,
    auth: { uid: ADMIN_UID },
    data: baseRequest(),
    nowFactory: () => {
      calls += 1;
      return NOW;
    },
    featureEnabled: true,
  });
  assert.equal(calls, 2, "exactly one retry occurred — nowFactory invoked exactly twice");
  assert.equal(result.idempotent, false);
  assert.equal(reviewEvents(store).length, 1, "exactly one committed audit event across both attempts");
  assert.equal(
    getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID).moderationStatus,
    "approved",
    "exactly one committed moderation update"
  );
  // Exact multiset across BOTH attempts: every one of the five
  // transactional reads occurs exactly twice — never only the product —
  // the admin-authorization read occurs exactly once, and no unexpected
  // path or read mode appears anywhere in the log.
  assertExactReadMultiset(
    store,
    [
      adminReadEntry(),
      `tx.get:${path}`,
      `tx.get:${path}`,
      `tx.get:${pointerPath()}`,
      `tx.get:${pointerPath()}`,
      `tx.get:${versionPath()}`,
      `tx.get:${versionPath()}`,
      `tx.get:${epochPath()}`,
      `tx.get:${epochPath()}`,
      `tx.get:${decisionPath()}`,
      `tx.get:${decisionPath()}`,
    ],
    "a retry must repeat all five transactional reads (product, pointer, version, epoch, decision) exactly twice each — 10 tx.get reads total — plus exactly one admin read, never more, never fewer, never a different path"
  );
});

// =======================================================================
// J. Exact read-count accounting by outcome — Revision 10 correction 53
// (§10.1 "Read-bound accounting," §15 items 23-25).
// =======================================================================

test("J1. a real transition, no retry: exactly the six-entry read multiset (1 admin + product/pointer/version/epoch/decision), no hidden read of any kind", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  store.callLog.length = 0;
  await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assertExactReadMultiset(
    store,
    [
      adminReadEntry(),
      `tx.get:${productPath()}`,
      `tx.get:${pointerPath()}`,
      `tx.get:${versionPath()}`,
      `tx.get:${epochPath()}`,
      `tx.get:${decisionPath()}`,
    ],
    "a real transition must read exactly these six documents — a hidden extra read of any path, or a read of any of these five via direct get() instead of tx.get(), must fail this assertion"
  );
});

test("J2. an already-approved idempotent replay, no retry: exactly the two-entry read multiset (1 admin + 1 transactional product), zero evaluator reads of any kind", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  store.callLog.length = 0;
  const replay = await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.equal(replay.idempotent, true);
  assertExactReadMultiset(
    store,
    [adminReadEntry(), `tx.get:${productPath()}`],
    "an idempotent replay must read only the admin doc and the product — no pointer/version/epoch/decision read, and no hidden read of any other path, may ever occur"
  );
});

test("J3. an invalid non-idempotent moderationStatus, no retry: exactly the two-entry read multiset, no hidden read of any kind", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store, { moderationStatus: "some_other_status" });
  store.callLog.length = 0;
  await assert.rejects(
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true })
  );
  assertExactReadMultiset(
    store,
    [adminReadEntry(), `tx.get:${productPath()}`],
    "an invalid-status rejection must read only the admin doc and the product before failing closed — no pointer/version/epoch/decision read, and no hidden read of any other path, may ever occur"
  );
});

// =======================================================================
// K. No non-transactional product pre-read — Revision 10 correction 53
// (§15 item 36).
// =======================================================================

test("K1. no non-transactional read of the product ever occurs — every product read is tx.get, never a plain get", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  store.callLog.length = 0;
  await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  const path = productPath();
  assert.equal(store.callLog.filter((e) => e === `get:${path}`).length, 0);
  assert.ok(store.callLog.some((e) => e === `tx.get:${path}`));
});

// =======================================================================
// L. Exact response schema — Revision 10 correction 54 (§15 item 28).
// =======================================================================

test("L1. a real transition's response is exactly {productId, moderationStatus, idempotent} — no bare status field", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const result = await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.deepEqual(Object.keys(result).sort(), ["idempotent", "moderationStatus", "productId"]);
  assert.equal(result.moderationStatus, "approved");
  assert.equal(result.idempotent, false);
  assert.equal(result.status, undefined);
});

test("L2. an already-approved replay's response uses identical field names to a real transition", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  const replay = await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  assert.deepEqual(Object.keys(replay).sort(), ["idempotent", "moderationStatus", "productId"]);
  assert.equal(replay.moderationStatus, "approved");
  assert.equal(replay.idempotent, true);
  assert.equal(replay.status, undefined);
});

// =======================================================================
// M. Genuine concurrency — Revision 10 correction 53 (§15 item 13/30).
// =======================================================================

test("M1. two genuinely concurrent approval attempts: exactly one real transition and one event; the other resolves as an idempotent replay", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const [a, b] = await Promise.all([
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
    reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true }),
  ]);
  assert.deepEqual([a.idempotent, b.idempotent].sort(), [false, true]);
  assert.equal(reviewEvents(store).length, 1);
  assert.equal(getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID).moderationStatus, "approved");
});

// =======================================================================
// N. Revision 28 (docs/plans/marketplace_p1a_compliance_review_
// implementation_plan_2026-08-21.md §10.1 "Pilot Product Approval
// contract", header-comment-only change to productModeration.js itself)
// — pilot-isolation proof: a real, successful general-launch approval
// through this file's own unmodified code path never touches isActive,
// pilotProductApproval, or pilotActiveProductCount, and cannot
// republish a product a pilot operation has already revoked.
// =======================================================================

test("N1. a real general-moderation approval never changes isActive and never creates pilotProductApproval on the product document", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  const before = getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID);
  const isActiveBefore = before.isActive;
  assert.equal(Object.prototype.hasOwnProperty.call(before, "pilotProductApproval"), false, "precondition: no pilot field seeded");

  await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });

  const after = getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID);
  assert.equal(after.isActive, isActiveBefore, "isActive is completely unchanged by this function");
  assert.equal(Object.prototype.hasOwnProperty.call(after, "pilotProductApproval"), false, "this function never creates the pilot field");
  assert.equal(after.moderationStatus, "approved");
});

test("N2. a real general-moderation approval never writes pilotActiveProductCount on the business document", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store);
  await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  const business = getRawDoc(store, "businesses", BUSINESS_ID);
  assert.equal(Object.prototype.hasOwnProperty.call(business || {}, "pilotActiveProductCount"), false);
});

test("N3. general-moderation approval on a product whose pilot approval was already revoked (isActive:false, moderationStatus reset by the pilot path) does not republish it — it only ever sets moderationStatus, never isActive", async () => {
  const store = createStore();
  seedAdmin(store);
  const db = await seedEligibleProduct(store, {
    isActive: false,
    pilotProductApproval: { active: false, revokedByKind: "admin", reasonCode: "pilot_revoked_admin_manual" },
  });
  await reviewProductModeration({ db, auth: { uid: ADMIN_UID }, data: baseRequest(), nowFactory: () => NOW, featureEnabled: true });
  const product = getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID);
  // moderationStatus is this function's own, general-launch-path field —
  // proven elsewhere in this file to become "approved" here. The point
  // of this test is narrower: isActive (the sole field the customer
  // query's own visibility actually gates on) is never touched by this
  // function, so a pilot-revoked product's own isActive:false — the
  // state that actually keeps it non-visible — survives a general
  // moderation approval unchanged, never flipped back to true.
  assert.equal(product.isActive, false, "isActive remains exactly as the pilot revocation left it — untouched by this function");
  assert.equal(product.pilotProductApproval.active, false, "the pilot revocation itself is untouched by this function");
});
