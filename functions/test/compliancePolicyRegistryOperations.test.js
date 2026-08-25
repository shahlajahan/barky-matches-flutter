"use strict";

// P1-A Slice 4.1 — compliancePolicyRegistryOperations.js tests (docs/
// plans/marketplace_p1a_compliance_review_implementation_plan_2026-08-21
// .md, §4/§13.1/§16, Revision 4). Deliberately NOT emulator-backed —
// this slice's module is never wired into any onCall/HTTP/trigger, so
// nothing here needs the Firestore emulator, network, credentials, or
// GCP/Firebase access of any kind. A hand-rolled, self-contained
// in-memory fake stands in for `db` (same established repo convention
// as settlementFinalizer.test.js's `fakeDb()` — no shared fake-Firestore
// helper exists in this codebase to reuse, so one is built here, scoped
// to this file only).
//
// No conditional test-skipping and no environment-dependent bypass
// anywhere in this file — every test always runs.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  createCompliancePolicyVersion,
  resolveActivePolicy,
  bootstrapCompliancePolicyRegistry,
  activatePolicyVersion,
  validateCompliancePolicyVersionDocument,
  isValidRegistryVersionId,
  REASON,
} = require("../src/marketplace/compliance/compliancePolicyRegistryOperations");

const POINTER_COLLECTION = "compliancePolicyRegistryPointer";
const POINTER_DOC_ID = "current";
const REGISTRY_COLLECTION = "compliancePolicyRegistry";

// ---------------------------------------------------------------------
// Minimal in-memory Firestore fake, extended for Revision 4:
//   - store.docs: Map<"collection/id", data-or-primitive> — `undefined`
//     means "does not exist"; a non-plain-object value simulates a
//     malformed document.
//   - store.docVersions: Map<"collection/id", number> — bumped on every
//     committed write to that path. Used to simulate Firestore's own
//     optimistic-concurrency transaction retry: if any document a
//     transaction READ has a different version at commit time than it
//     did at read time, the whole transaction callback re-runs against
//     fresh reads (bounded retry count), exactly like real Firestore.
//     Only document-ref reads participate in this check (not query
//     reads) — sufficient for every scenario this file exercises, since
//     the documents that matter (pointer/target/current) are always
//     read by ref.
//   - store.failOnRead / store.failOnQuery / store.failOnCreate:
//     simulated adapter failures.
//   - store.queryOverride: forces the anomaly query's result, for the
//     handful of scenarios not reachable through any normal,
//     invariant-respecting write path.
//   - store.callLog: chronological "get:<path>" / "query:<collection>"
//     / "create:<path>" / "update:<path>" log, used to prove ordering.
// ---------------------------------------------------------------------

function createStore() {
  return {
    docs: new Map(),
    docVersions: new Map(),
    failOnRead: new Set(),
    failOnCreate: new Set(),
    failOnQuery: false,
    queryOverride: null,
    callLog: [],
    nonTransactionalGetPaths: [],
    transactionalGetPaths: [],
    runTransactionCallCount: 0,
    whereCallCollections: [],
    inTransaction: false,
  };
}

function bumpVersion(store, docPath) {
  store.docVersions.set(docPath, (store.docVersions.get(docPath) || 0) + 1);
}

function makeDocSnapshot(id, rawValue) {
  return {
    exists: rawValue !== undefined,
    id,
    data: () => rawValue,
  };
}

function makeRef(collectionName, id, store) {
  const docPath = `${collectionName}/${id}`;
  return {
    id,
    path: docPath,
    async get() {
      if (store.inTransaction) {
        store.transactionalGetPaths.push(docPath);
      } else {
        store.nonTransactionalGetPaths.push(docPath);
      }
      store.callLog.push(`get:${docPath}`);
      if (store.failOnRead.has(docPath)) {
        throw new Error("simulated adapter read failure");
      }
      return makeDocSnapshot(id, store.docs.get(docPath));
    },
    async create(data) {
      store.callLog.push(`create:${docPath}`);
      if (store.failOnCreate.has(docPath)) {
        throw new Error("simulated adapter write failure");
      }
      if (store.docs.get(docPath) !== undefined) {
        throw new Error(`simulated ref.create on existing doc: ${docPath}`);
      }
      store.docs.set(docPath, data);
      bumpVersion(store, docPath);
    },
  };
}

function makeAnomalyQuery(collectionName, store, { field, op, value, limitN }) {
  return {
    async get() {
      store.callLog.push(`query:${collectionName}`);
      if (store.failOnQuery) {
        throw new Error("simulated adapter query failure");
      }
      if (store.queryOverride) {
        return { docs: store.queryOverride.map((entry) => makeDocSnapshot(entry.id, entry.data)) };
      }
      const results = [];
      for (const [docPath, rawValue] of store.docs.entries()) {
        if (!docPath.startsWith(`${collectionName}/`)) continue;
        if (!rawValue || typeof rawValue !== "object" || Array.isArray(rawValue)) continue;
        if (op === "==" && rawValue[field] !== value) continue;
        const id = docPath.slice(collectionName.length + 1);
        results.push(makeDocSnapshot(id, rawValue));
        if (results.length >= limitN) break;
      }
      return { docs: results };
    },
  };
}

function createFakeDb(store) {
  function collection(name) {
    return {
      doc(id) {
        return makeRef(name, id, store);
      },
      where(field, op, value) {
        return {
          limit(limitN) {
            store.whereCallCollections.push(name);
            return makeAnomalyQuery(name, store, { field, op, value, limitN });
          },
        };
      },
    };
  }

  async function runTransaction(callback, attempt = 0) {
    store.runTransactionCallCount += 1;
    const readVersions = new Map();
    const staged = [];
    const tx = {
      async get(refOrQuery) {
        if (refOrQuery.path) {
          readVersions.set(refOrQuery.path, store.docVersions.get(refOrQuery.path) || 0);
        }
        return refOrQuery.get();
      },
      create(ref, data) {
        staged.push({ type: "create", path: ref.path, data });
      },
      update(ref, data) {
        const existing = store.docs.get(ref.path);
        if (existing === undefined) {
          throw new Error(`simulated tx.update on nonexistent doc: ${ref.path}`);
        }
        staged.push({ type: "update", path: ref.path, data });
      },
    };

    store.inTransaction = true;
    let result;
    try {
      result = await callback(tx);
    } finally {
      store.inTransaction = false;
    }

    // Optimistic-concurrency check: if any path this transaction READ
    // has since been committed by a different, interleaved transaction,
    // retry from scratch against fresh state — exactly matching real
    // Firestore's own automatic transaction retry.
    for (const [readPath, versionAtRead] of readVersions.entries()) {
      const currentVersion = store.docVersions.get(readPath) || 0;
      if (currentVersion !== versionAtRead) {
        if (attempt >= 5) {
          throw new Error("simulated transaction retry limit exceeded");
        }
        return runTransaction(callback, attempt + 1);
      }
    }

    for (const write of staged) {
      if (write.type === "create") {
        if (store.docs.get(write.path) !== undefined) {
          throw new Error(`simulated tx.create on existing doc: ${write.path}`);
        }
        store.docs.set(write.path, write.data);
      } else {
        const current = store.docs.get(write.path);
        store.docs.set(write.path, { ...current, ...write.data });
      }
      bumpVersion(store, write.path);
      store.callLog.push(`${write.type}:${write.path}`);
    }
    return result;
  }

  return { collection, runTransaction };
}

function seedDoc(store, collectionName, id, data) {
  store.docs.set(`${collectionName}/${id}`, data);
  bumpVersion(store, `${collectionName}/${id}`);
}

function getRawDoc(store, collectionName, id) {
  return store.docs.get(`${collectionName}/${id}`);
}

function snapshotDocs(store) {
  return new Map(store.docs);
}

function assertNoWrites(store, before) {
  assert.deepEqual(store.docs, before, "no document may change on a failed call");
}

async function assertRejectsWithReason(fn, expectedReasonPrefix, expectedCode) {
  await assert.rejects(fn, (err) => {
    assert.equal(typeof err.message, "string");
    assert.ok(
      err.message.startsWith(expectedReasonPrefix),
      `expected message to start with "${expectedReasonPrefix}", got "${err.message}"`
    );
    if (expectedCode) {
      assert.equal(err.code, expectedCode);
    }
    return true;
  });
}

// ---------------------------------------------------------------------
// Fixture builders.
// ---------------------------------------------------------------------

function makeTimestamp(ms) {
  return { toMillis: () => ms };
}

const NOW_MS = 1_700_000_000_000;

function makeValidRelationshipEntry(overrides = {}) {
  return {
    acceptedDocumentTypes: ["purchase_invoice", "manufacturer_evidence", "supplier_agreement"],
    requiredDocumentTypeGroups: [["purchase_invoice"], ["manufacturer_evidence", "supplier_agreement"]],
    perDocumentTypePolicy: {
      purchase_invoice: { validUntilRequired: true, issueDateRequired: false },
    },
    maximumValidityPeriod: null,
    acceptedScopeTypes: ["business", "brand"],
    manualAdminOverridePermitted: false,
    ...overrides,
  };
}

function makeValidDocument({
  status = "draft",
  nowMs = NOW_MS,
  effectiveFromMs = nowMs - 10_000,
  createdAtMs = nowMs - 10_000,
  sellerRelationship,
  changeNote = "initial version",
  createdBy = "admin-uid-1",
} = {}) {
  return {
    sellerRelationship:
      sellerRelationship !== undefined ? sellerRelationship : { manufacturer: makeValidRelationshipEntry() },
    status,
    effectiveFrom: makeTimestamp(effectiveFromMs),
    createdBy,
    createdAt: makeTimestamp(createdAtMs),
    changeNote,
  };
}

function seedActiveRegistry({ store, versionId = "v1", nowMs = NOW_MS }) {
  seedDoc(store, POINTER_COLLECTION, POINTER_DOC_ID, { activeVersionId: versionId });
  seedDoc(store, REGISTRY_COLLECTION, versionId, makeValidDocument({ status: "active", nowMs }));
  return versionId;
}

// =======================================================================
// A. createCompliancePolicyVersion
// =======================================================================

test("createCompliancePolicyVersion: valid draft creation succeeds", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const result = await createCompliancePolicyVersion({
    db,
    sellerRelationship: { manufacturer: makeValidRelationshipEntry() },
    effectiveFrom: makeTimestamp(NOW_MS - 1000),
    changeNote: "note",
    initialStatus: "draft",
    createdBy: "admin-1",
    now: new Date(NOW_MS),
    generateVersionId: () => "fixed-version-1",
  });
  assert.deepEqual(result, { versionId: "fixed-version-1", status: "draft" });
  const stored = getRawDoc(store, REGISTRY_COLLECTION, "fixed-version-1");
  assert.equal(stored.status, "draft");
});

test("createCompliancePolicyVersion: valid inactive empty placeholder succeeds", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const result = await createCompliancePolicyVersion({
    db,
    sellerRelationship: {},
    effectiveFrom: makeTimestamp(NOW_MS - 1000),
    changeNote: "placeholder",
    initialStatus: "inactive",
    createdBy: "admin-1",
    now: new Date(NOW_MS),
    generateVersionId: () => "placeholder-1",
  });
  assert.equal(result.status, "inactive");
  assert.deepEqual(getRawDoc(store, REGISTRY_COLLECTION, "placeholder-1").sellerRelationship, {});
});

test("createCompliancePolicyVersion: generated UUID is returned and used as the document ID", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const result = await createCompliancePolicyVersion({
    db,
    sellerRelationship: { manufacturer: makeValidRelationshipEntry() },
    effectiveFrom: makeTimestamp(NOW_MS - 1000),
    changeNote: "note",
    initialStatus: "draft",
    createdBy: "admin-1",
    now: new Date(NOW_MS),
  });
  assert.equal(isValidRegistryVersionId(result.versionId), true);
  assert.ok(getRawDoc(store, REGISTRY_COLLECTION, result.versionId));
});

test("createCompliancePolicyVersion: caller cannot choose versionId or createdAt", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const result = await createCompliancePolicyVersion({
    db,
    versionId: "attacker-chosen-id",
    createdAt: makeTimestamp(0),
    sellerRelationship: { manufacturer: makeValidRelationshipEntry() },
    effectiveFrom: makeTimestamp(NOW_MS - 1000),
    changeNote: "note",
    initialStatus: "draft",
    createdBy: "admin-1",
    now: new Date(NOW_MS),
    generateVersionId: () => "server-generated-id",
  });
  assert.equal(result.versionId, "server-generated-id");
  assert.equal(getRawDoc(store, REGISTRY_COLLECTION, "attacker-chosen-id"), undefined);
  const stored = getRawDoc(store, REGISTRY_COLLECTION, "server-generated-id");
  assert.equal(stored.createdAt.toMillis(), NOW_MS);
});

test("createCompliancePolicyVersion: active/retired initial status rejected", async () => {
  for (const badStatus of ["active", "retired"]) {
    const store = createStore();
    const db = createFakeDb(store);
    const before = snapshotDocs(store);
    await assert.rejects(
      () =>
        createCompliancePolicyVersion({
          db,
          sellerRelationship: { manufacturer: makeValidRelationshipEntry() },
          effectiveFrom: makeTimestamp(NOW_MS - 1000),
          changeNote: "note",
          initialStatus: badStatus,
          createdBy: "admin-1",
          now: new Date(NOW_MS),
        }),
      (err) => {
        assert.equal(err.code, "invalid-argument");
        assert.ok(err.message.startsWith(REASON.CREATION_INITIAL_STATUS_INVALID));
        return true;
      }
    );
    assertNoWrites(store, before);
  }
});

test("createCompliancePolicyVersion: invalid UUID generator output rejected, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const before = snapshotDocs(store);
  await assert.rejects(
    () =>
      createCompliancePolicyVersion({
        db,
        sellerRelationship: { manufacturer: makeValidRelationshipEntry() },
        effectiveFrom: makeTimestamp(NOW_MS - 1000),
        changeNote: "note",
        initialStatus: "draft",
        createdBy: "admin-1",
        now: new Date(NOW_MS),
        generateVersionId: () => "has/slash",
      }),
    (err) => {
      assert.equal(err.code, "internal");
      assert.ok(err.message.startsWith(REASON.CREATION_VERSION_ID_GENERATION_INVALID));
      return true;
    }
  );
  assertNoWrites(store, before);
});

test("createCompliancePolicyVersion: create collision does not overwrite the existing document", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const existing = makeValidDocument({ status: "draft", changeNote: "original, must not change" });
  seedDoc(store, REGISTRY_COLLECTION, "collide-1", existing);
  const before = snapshotDocs(store);

  await assert.rejects(
    () =>
      createCompliancePolicyVersion({
        db,
        sellerRelationship: { manufacturer: makeValidRelationshipEntry() },
        effectiveFrom: makeTimestamp(NOW_MS - 1000),
        changeNote: "attacker note",
        initialStatus: "draft",
        createdBy: "admin-1",
        now: new Date(NOW_MS),
        generateVersionId: () => "collide-1",
      }),
    (err) => {
      assert.equal(err.code, "aborted");
      assert.ok(err.message.startsWith(REASON.CREATION_WRITE_FAILED));
      return true;
    }
  );
  assertNoWrites(store, before);
  assert.deepEqual(getRawDoc(store, REGISTRY_COLLECTION, "collide-1"), existing);
});

test("createCompliancePolicyVersion: adapter write failure is safe, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  store.failOnCreate.add(`${REGISTRY_COLLECTION}/fail-1`);
  const before = snapshotDocs(store);
  await assert.rejects(
    () =>
      createCompliancePolicyVersion({
        db,
        sellerRelationship: { manufacturer: makeValidRelationshipEntry() },
        effectiveFrom: makeTimestamp(NOW_MS - 1000),
        changeNote: "note",
        initialStatus: "draft",
        createdBy: "admin-1",
        now: new Date(NOW_MS),
        generateVersionId: () => "fail-1",
      }),
    (err) => {
      assert.equal(err.code, "aborted");
      assert.ok(err.message.startsWith(REASON.CREATION_WRITE_FAILED));
      return true;
    }
  );
  assertNoWrites(store, before);
});

test("createCompliancePolicyVersion: duplicate calls are honestly non-idempotent — two distinct abandoned versions", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const ids = ["dup-a", "dup-b"];
  let call = 0;
  const first = await createCompliancePolicyVersion({
    db,
    sellerRelationship: { manufacturer: makeValidRelationshipEntry() },
    effectiveFrom: makeTimestamp(NOW_MS - 1000),
    changeNote: "identical content",
    initialStatus: "draft",
    createdBy: "admin-1",
    now: new Date(NOW_MS),
    generateVersionId: () => ids[call++],
  });
  const second = await createCompliancePolicyVersion({
    db,
    sellerRelationship: { manufacturer: makeValidRelationshipEntry() },
    effectiveFrom: makeTimestamp(NOW_MS - 1000),
    changeNote: "identical content",
    initialStatus: "draft",
    createdBy: "admin-1",
    now: new Date(NOW_MS),
    generateVersionId: () => ids[call++],
  });
  assert.notEqual(first.versionId, second.versionId);
  assert.ok(getRawDoc(store, REGISTRY_COLLECTION, "dup-a"));
  assert.ok(getRawDoc(store, REGISTRY_COLLECTION, "dup-b"));
});

test("createCompliancePolicyVersion: draft with empty sellerRelationship is rejected", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const before = snapshotDocs(store);
  await assert.rejects(
    () =>
      createCompliancePolicyVersion({
        db,
        sellerRelationship: {},
        effectiveFrom: makeTimestamp(NOW_MS - 1000),
        changeNote: "note",
        initialStatus: "draft",
        createdBy: "admin-1",
        now: new Date(NOW_MS),
      }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      assert.ok(err.message.includes(REASON.CONTENT_NO_RELATIONSHIP_CONFIGURED));
      return true;
    }
  );
  assertNoWrites(store, before);
});

test("createCompliancePolicyVersion: inactive with present but malformed relationship entry is rejected", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const before = snapshotDocs(store);
  await assert.rejects(
    () =>
      createCompliancePolicyVersion({
        db,
        sellerRelationship: { manufacturer: { garbage: true } },
        effectiveFrom: makeTimestamp(NOW_MS - 1000),
        changeNote: "note",
        initialStatus: "inactive",
        createdBy: "admin-1",
        now: new Date(NOW_MS),
      }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      assert.ok(err.message.includes(REASON.CONTENT_RELATIONSHIP_ENTRY_UNKNOWN_KEY));
      return true;
    }
  );
  assertNoWrites(store, before);
});

// =======================================================================
// B. validateCompliancePolicyVersionDocument — the full matrix
// =======================================================================

test("validator: a fully valid draft document is valid, with no nowMs boundary", () => {
  const doc = makeValidDocument({ status: "draft" });
  const result = validateCompliancePolicyVersionDocument(doc, {
    allowedStatuses: ["draft"],
    requireActivationEligible: true,
  });
  assert.deepEqual(result, { valid: true });
});

test("validator: exactly six top-level fields required — missing field rejected", () => {
  const doc = makeValidDocument();
  delete doc.changeNote;
  const result = validateCompliancePolicyVersionDocument(doc);
  assert.equal(result.valid, false);
  assert.equal(result.reason, REASON.DOCUMENT_MISSING_FIELD);
});

test("validator: unknown top-level field rejected", () => {
  const doc = { ...makeValidDocument(), extra: "nope" };
  const result = validateCompliancePolicyVersionDocument(doc);
  assert.equal(result.valid, false);
  assert.equal(result.reason, REASON.DOCUMENT_UNKNOWN_FIELD);
});

test("validator: non-object document rejected", () => {
  for (const bad of [null, "string", 42, [], undefined]) {
    const result = validateCompliancePolicyVersionDocument(bad);
    assert.equal(result.valid, false);
    assert.equal(result.reason, REASON.DOCUMENT_NOT_OBJECT);
  }
});

test("validator: status/context matrix", () => {
  for (const status of ["draft", "active", "inactive", "retired"]) {
    const doc = makeValidDocument({ status });
    const result = validateCompliancePolicyVersionDocument(doc, { requireActivationEligible: false });
    assert.equal(result.valid, true, `status ${status} alone should be structurally valid`);
  }
  const badStatusDoc = { ...makeValidDocument(), status: "archived" };
  assert.equal(validateCompliancePolicyVersionDocument(badStatusDoc).reason, REASON.DOCUMENT_STATUS_INVALID);

  const draftDoc = makeValidDocument({ status: "draft" });
  const notAllowed = validateCompliancePolicyVersionDocument(draftDoc, { allowedStatuses: ["active"] });
  assert.equal(notAllowed.reason, REASON.DOCUMENT_STATUS_NOT_ALLOWED);
});

test("validator: obsolete flat requiredDocumentTypes field is rejected as unknown", () => {
  const entry = makeValidRelationshipEntry();
  delete entry.requiredDocumentTypeGroups;
  entry.requiredDocumentTypes = ["purchase_invoice"];
  const doc = makeValidDocument({ sellerRelationship: { manufacturer: entry } });
  const result = validateCompliancePolicyVersionDocument(doc, { requireActivationEligible: true });
  assert.equal(result.valid, false);
  assert.equal(result.reason, REASON.CONTENT_RELATIONSHIP_ENTRY_UNKNOWN_KEY);
});

test("validator: relationship entry missing/unknown nested keys", () => {
  const missing = makeValidRelationshipEntry();
  delete missing.acceptedScopeTypes;
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: missing } }))
      .reason,
    REASON.CONTENT_RELATIONSHIP_ENTRY_MISSING_FIELD
  );

  const unknown = { ...makeValidRelationshipEntry(), extraField: 1 };
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: unknown } }))
      .reason,
    REASON.CONTENT_RELATIONSHIP_ENTRY_UNKNOWN_KEY
  );

  assert.equal(
    validateCompliancePolicyVersionDocument(
      makeValidDocument({ sellerRelationship: { manufacturer: "not-an-object" } })
    ).reason,
    REASON.CONTENT_RELATIONSHIP_ENTRY_NOT_OBJECT
  );
});

test("validator: unknown relationship key rejected", () => {
  const doc = makeValidDocument({ sellerRelationship: { not_a_real_relationship: makeValidRelationshipEntry() } });
  assert.equal(validateCompliancePolicyVersionDocument(doc).reason, REASON.CONTENT_UNKNOWN_RELATIONSHIP_KEY);
});

test("validator: requiredDocumentTypeGroups outer length matrix — 0, 1, 5, 6", () => {
  function withGroups(groups, requireActivationEligible) {
    const entry = makeValidRelationshipEntry({
      requiredDocumentTypeGroups: groups,
      acceptedDocumentTypes: [
        "purchase_invoice",
        "supplier_agreement",
        "authorization_letter",
        "dealership_distribution_agreement",
        "trademark_evidence",
        "manufacturer_evidence",
      ],
    });
    return validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: entry } }), {
      requireActivationEligible,
    });
  }

  // 0 groups on a PRESENT relationship entry is always illegal —
  // requireActivationEligible only gates whether the TOP-LEVEL map may
  // be empty, never whether a present entry's own groups may be empty.
  assert.equal(withGroups([], false).reason, REASON.CONTENT_REQUIRED_GROUPS_INVALID);
  assert.equal(withGroups([], true).reason, REASON.CONTENT_REQUIRED_GROUPS_INVALID);

  // 1 group: legal in both contexts.
  assert.equal(withGroups([["purchase_invoice"]], true).valid, true);

  // 5 groups: legal (exactly the frozen cap).
  const fiveGroups = [
    ["purchase_invoice"],
    ["supplier_agreement"],
    ["authorization_letter"],
    ["dealership_distribution_agreement"],
    ["trademark_evidence"],
  ];
  assert.equal(withGroups(fiveGroups, true).valid, true);

  // 6 groups: illegal always (exceeds the frozen requiredEvidenceSlots cap).
  const sixGroups = [...fiveGroups, ["manufacturer_evidence"]];
  assert.equal(withGroups(sixGroups, true).reason, REASON.CONTENT_REQUIRED_GROUPS_INVALID);
  assert.equal(withGroups(sixGroups, false).reason, REASON.CONTENT_REQUIRED_GROUPS_INVALID);
});

test("validator: inner group empty/non-array/invalid-type/duplicate-member rejected", () => {
  function withInner(groups) {
    const entry = makeValidRelationshipEntry({ requiredDocumentTypeGroups: groups });
    return validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: entry } }), {
      requireActivationEligible: true,
    });
  }
  assert.equal(withInner([[]]).reason, REASON.CONTENT_REQUIRED_GROUP_EMPTY);
  assert.equal(withInner(["not-an-array"]).reason, REASON.CONTENT_REQUIRED_GROUP_EMPTY);
  assert.equal(withInner([[123]]).reason, REASON.CONTENT_REQUIRED_GROUP_MEMBER_INVALID);
  assert.equal(withInner([["not_a_real_type"]]).reason, REASON.CONTENT_REQUIRED_GROUP_MEMBER_INVALID);
  assert.equal(
    withInner([["purchase_invoice", "purchase_invoice"]]).reason,
    REASON.CONTENT_REQUIRED_GROUP_MEMBER_INVALID
  );
});

test("validator: duplicate groups rejected after canonicalization (order-independent)", () => {
  const entry = makeValidRelationshipEntry({
    acceptedDocumentTypes: ["manufacturer_evidence", "supplier_agreement"],
    requiredDocumentTypeGroups: [
      ["manufacturer_evidence", "supplier_agreement"],
      ["supplier_agreement", "manufacturer_evidence"],
    ],
  });
  const result = validateCompliancePolicyVersionDocument(
    makeValidDocument({ sellerRelationship: { manufacturer: entry } }),
    { requireActivationEligible: true }
  );
  assert.equal(result.reason, REASON.CONTENT_REQUIRED_GROUPS_DUPLICATE);
});

test("validator: required group member not in acceptedDocumentTypes rejected", () => {
  const entry = makeValidRelationshipEntry({
    acceptedDocumentTypes: ["purchase_invoice"],
    requiredDocumentTypeGroups: [["manufacturer_evidence"]],
  });
  const result = validateCompliancePolicyVersionDocument(
    makeValidDocument({ sellerRelationship: { manufacturer: entry } })
  );
  assert.equal(result.reason, REASON.CONTENT_REQUIRED_NOT_ACCEPTED);
});

test("validator: acceptedDocumentTypes duplicates/invalid-member rejected", () => {
  const dup = makeValidRelationshipEntry({ acceptedDocumentTypes: ["purchase_invoice", "purchase_invoice"] });
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: dup } })).reason,
    REASON.CONTENT_ACCEPTED_DOCUMENT_TYPES_INVALID
  );
  const bad = makeValidRelationshipEntry({ acceptedDocumentTypes: ["not_a_type"] });
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: bad } })).reason,
    REASON.CONTENT_ACCEPTED_DOCUMENT_TYPES_INVALID
  );
  const notArray = makeValidRelationshipEntry({ acceptedDocumentTypes: "not-an-array" });
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: notArray } }))
      .reason,
    REASON.CONTENT_ACCEPTED_DOCUMENT_TYPES_INVALID
  );
});

test("validator: acceptedScopeTypes empty/duplicate/invalid", () => {
  // Empty acceptedScopeTypes on a PRESENT relationship entry is always
  // illegal — requireActivationEligible does not relax this; the only
  // status-gated exception in the whole schema is the top-level map's
  // own emptiness, never a present entry's fields.
  const empty = makeValidRelationshipEntry({ acceptedScopeTypes: [] });
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: empty } }), {
      requireActivationEligible: true,
    }).reason,
    REASON.CONTENT_ACCEPTED_SCOPE_TYPES_EMPTY
  );
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: empty } }), {
      requireActivationEligible: false,
    }).reason,
    REASON.CONTENT_ACCEPTED_SCOPE_TYPES_EMPTY
  );
  const dup = makeValidRelationshipEntry({ acceptedScopeTypes: ["business", "business"] });
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: dup } })).reason,
    REASON.CONTENT_ACCEPTED_SCOPE_TYPES_INVALID
  );
  const bad = makeValidRelationshipEntry({ acceptedScopeTypes: ["not_a_scope"] });
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: bad } })).reason,
    REASON.CONTENT_ACCEPTED_SCOPE_TYPES_INVALID
  );
});

test("validator: perDocumentTypePolicy unknown/unaccepted keys and malformed entries", () => {
  const unaccepted = makeValidRelationshipEntry({
    perDocumentTypePolicy: { authorization_letter: { validUntilRequired: true, issueDateRequired: true } },
  });
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: unaccepted } }))
      .reason,
    REASON.CONTENT_PER_DOCUMENT_TYPE_POLICY_INVALID
  );

  const malformedEntry = makeValidRelationshipEntry({
    perDocumentTypePolicy: { purchase_invoice: { validUntilRequired: "yes", issueDateRequired: false } },
  });
  assert.equal(
    validateCompliancePolicyVersionDocument(
      makeValidDocument({ sellerRelationship: { manufacturer: malformedEntry } })
    ).reason,
    REASON.CONTENT_PER_DOCUMENT_TYPE_POLICY_ENTRY_INVALID
  );

  const extraKey = makeValidRelationshipEntry({
    perDocumentTypePolicy: {
      purchase_invoice: { validUntilRequired: true, issueDateRequired: false, extra: 1 },
    },
  });
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: extraKey } }))
      .reason,
    REASON.CONTENT_PER_DOCUMENT_TYPE_POLICY_ENTRY_INVALID
  );

  const notObject = makeValidRelationshipEntry({ perDocumentTypePolicy: "nope" });
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: notObject } }))
      .reason,
    REASON.CONTENT_PER_DOCUMENT_TYPE_POLICY_INVALID
  );
});

test("validator: maximumValidityPeriod null/valid/float/zero/negative/NaN/Infinity/unsafe", () => {
  function withPeriod(value) {
    const entry = makeValidRelationshipEntry({ maximumValidityPeriod: value });
    return validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: entry } }));
  }
  assert.equal(withPeriod(null).valid, true);
  assert.equal(withPeriod(86400000).valid, true);
  assert.equal(withPeriod(1.5).reason, REASON.CONTENT_MAXIMUM_VALIDITY_PERIOD_INVALID);
  assert.equal(withPeriod(0).reason, REASON.CONTENT_MAXIMUM_VALIDITY_PERIOD_INVALID);
  assert.equal(withPeriod(-1).reason, REASON.CONTENT_MAXIMUM_VALIDITY_PERIOD_INVALID);
  assert.equal(withPeriod(NaN).reason, REASON.CONTENT_MAXIMUM_VALIDITY_PERIOD_INVALID);
  assert.equal(withPeriod(Infinity).reason, REASON.CONTENT_MAXIMUM_VALIDITY_PERIOD_INVALID);
  assert.equal(withPeriod(Number.MAX_SAFE_INTEGER + 10).reason, REASON.CONTENT_MAXIMUM_VALIDITY_PERIOD_INVALID);
  assert.equal(withPeriod(Number.MAX_SAFE_INTEGER).valid, true);
});

test("validator: manualAdminOverridePermitted must be boolean only", () => {
  const bad = makeValidRelationshipEntry({ manualAdminOverridePermitted: "true" });
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ sellerRelationship: { manufacturer: bad } })).reason,
    REASON.CONTENT_MANUAL_OVERRIDE_FLAG_INVALID
  );
});

test("validator: createdBy/changeNote bounds", () => {
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ createdBy: "" })).reason,
    REASON.DOCUMENT_CREATED_BY_INVALID
  );
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ createdBy: "a".repeat(129) })).reason,
    REASON.DOCUMENT_CREATED_BY_INVALID
  );
  assert.equal(validateCompliancePolicyVersionDocument(makeValidDocument({ createdBy: "a".repeat(128) })).valid, true);
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ changeNote: "" })).reason,
    REASON.DOCUMENT_CHANGE_NOTE_INVALID
  );
  assert.equal(
    validateCompliancePolicyVersionDocument(makeValidDocument({ changeNote: "a".repeat(2001) })).reason,
    REASON.DOCUMENT_CHANGE_NOTE_INVALID
  );
});

test("validator: malformed/throwing/non-finite timestamps fail closed", () => {
  const missingToMillis = makeValidDocument();
  missingToMillis.effectiveFrom = { notAFunction: true };
  assert.equal(
    validateCompliancePolicyVersionDocument(missingToMillis).reason,
    REASON.DOCUMENT_EFFECTIVE_FROM_INVALID
  );

  const throwing = makeValidDocument();
  throwing.effectiveFrom = {
    toMillis() {
      throw new Error("boom");
    },
  };
  assert.equal(validateCompliancePolicyVersionDocument(throwing).reason, REASON.DOCUMENT_EFFECTIVE_FROM_INVALID);

  const nonFinite = makeValidDocument();
  nonFinite.createdAt = makeTimestamp(NaN);
  assert.equal(validateCompliancePolicyVersionDocument(nonFinite).reason, REASON.DOCUMENT_CREATED_AT_INVALID);

  const infiniteVal = makeValidDocument();
  infiniteVal.createdAt = makeTimestamp(Infinity);
  assert.equal(validateCompliancePolicyVersionDocument(infiniteVal).reason, REASON.DOCUMENT_CREATED_AT_INVALID);
});

test("validator: effectiveFrom boundary — equality and ±1ms", () => {
  const atEquality = makeValidDocument({ effectiveFromMs: NOW_MS });
  assert.equal(validateCompliancePolicyVersionDocument(atEquality, { nowMs: NOW_MS }).valid, true);

  const oneMsBefore = makeValidDocument({ effectiveFromMs: NOW_MS - 1 });
  assert.equal(validateCompliancePolicyVersionDocument(oneMsBefore, { nowMs: NOW_MS }).valid, true);

  const oneMsAfter = makeValidDocument({ effectiveFromMs: NOW_MS + 1 });
  assert.equal(
    validateCompliancePolicyVersionDocument(oneMsAfter, { nowMs: NOW_MS }).reason,
    REASON.EFFECTIVE_FROM_FUTURE
  );
});

test("validator: future createdAt rejected when nowMs is available", () => {
  const doc = makeValidDocument({ createdAtMs: NOW_MS + 1 });
  assert.equal(
    validateCompliancePolicyVersionDocument(doc, { nowMs: NOW_MS }).reason,
    REASON.DOCUMENT_CREATED_AT_FUTURE
  );
  // Without nowMs, the same document is not checked for this and passes.
  assert.equal(validateCompliancePolicyVersionDocument(doc).valid, true);
});

test("validator: an inactive document with a PRESENT but all-empty relationship entry is rejected — the empty-map exception never extends to a present entry's own fields", () => {
  // The exact regression case: only the top-level map may be `{}` for
  // `inactive`. Once a key is present, its entry is validated
  // identically to a draft/active entry — a present-but-hollow
  // "reseller" configuration must still fail closed.
  const doc = makeValidDocument({
    status: "inactive",
    sellerRelationship: {
      reseller: {
        acceptedDocumentTypes: [],
        requiredDocumentTypeGroups: [],
        perDocumentTypePolicy: {},
        maximumValidityPeriod: null,
        acceptedScopeTypes: [],
        manualAdminOverridePermitted: false,
      },
    },
  });
  const result = validateCompliancePolicyVersionDocument(doc, {
    allowedStatuses: ["inactive"],
    requireActivationEligible: false,
  });
  assert.equal(result.valid, false);
  assert.equal(result.reason, REASON.CONTENT_REQUIRED_GROUPS_INVALID);
});

test("validator: inactive with empty sellerRelationship is allowed; draft/active are rejected", () => {
  const inactive = makeValidDocument({ status: "inactive", sellerRelationship: {} });
  assert.equal(
    validateCompliancePolicyVersionDocument(inactive, { allowedStatuses: ["inactive"], requireActivationEligible: false })
      .valid,
    true
  );

  const draft = makeValidDocument({ status: "draft", sellerRelationship: {} });
  assert.equal(
    validateCompliancePolicyVersionDocument(draft, { allowedStatuses: ["draft"], requireActivationEligible: true })
      .reason,
    REASON.CONTENT_NO_RELATIONSHIP_CONFIGURED
  );

  const active = makeValidDocument({ status: "active", sellerRelationship: {} });
  assert.equal(
    validateCompliancePolicyVersionDocument(active, { allowedStatuses: ["active"], requireActivationEligible: true })
      .reason,
    REASON.CONTENT_NO_RELATIONSHIP_CONFIGURED
  );
});

// =======================================================================
// C. bootstrapCompliancePolicyRegistry
// =======================================================================

test("bootstrapCompliancePolicyRegistry: succeeds from a truly empty registry", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedDoc(store, REGISTRY_COLLECTION, "v1", makeValidDocument({ status: "draft" }));

  const result = await bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v1", now: new Date(NOW_MS) });
  assert.deepEqual(result, { activeVersionId: "v1" });
  assert.equal(getRawDoc(store, REGISTRY_COLLECTION, "v1").status, "active");
  assert.equal(getRawDoc(store, POINTER_COLLECTION, POINTER_DOC_ID).activeVersionId, "v1");
});

test("bootstrapCompliancePolicyRegistry: exactly two writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedDoc(store, REGISTRY_COLLECTION, "v1", makeValidDocument({ status: "draft" }));
  await bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v1", now: new Date(NOW_MS) });
  const writes = store.callLog.filter((e) => e.startsWith("update:") || e.startsWith("create:"));
  assert.equal(writes.length, 2);
  assert.deepEqual(new Set(writes), new Set([`update:${REGISTRY_COLLECTION}/v1`, `create:${POINTER_COLLECTION}/${POINTER_DOC_ID}`]));
});

test("bootstrapCompliancePolicyRegistry: target content unchanged except status", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const content = makeValidDocument({ status: "draft" });
  seedDoc(store, REGISTRY_COLLECTION, "v1", content);
  await bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v1", now: new Date(NOW_MS) });
  const after = getRawDoc(store, REGISTRY_COLLECTION, "v1");
  const { status: _s, ...afterContent } = after;
  const { status: _s2, ...beforeContent } = content;
  assert.deepEqual(afterContent, beforeContent);
  assert.equal(after.status, "active");
});

test("bootstrapCompliancePolicyRegistry: pointer write is create-only (never set/merge/update)", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedDoc(store, REGISTRY_COLLECTION, "v1", makeValidDocument({ status: "draft" }));
  await bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v1", now: new Date(NOW_MS) });
  assert.ok(store.callLog.includes(`create:${POINTER_COLLECTION}/${POINTER_DOC_ID}`));
  assert.equal(store.callLog.includes(`update:${POINTER_COLLECTION}/${POINTER_DOC_ID}`), false);
});

test("bootstrapCompliancePolicyRegistry fails closed: pointer already exists, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v-existing" });
  seedDoc(store, REGISTRY_COLLECTION, "v-new", makeValidDocument({ status: "draft" }));
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v-new", now: new Date(NOW_MS) }),
    REASON.BOOTSTRAP_POINTER_ALREADY_EXISTS,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("bootstrapCompliancePolicyRegistry fails closed: an active version exists despite no pointer, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedDoc(store, REGISTRY_COLLECTION, "v-rogue-active", makeValidDocument({ status: "active" }));
  seedDoc(store, REGISTRY_COLLECTION, "v-target", makeValidDocument({ status: "draft" }));
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v-target", now: new Date(NOW_MS) }),
    `${REASON.BOOTSTRAP_ANOMALY_ACTIVE_COUNT_NONZERO}:1`,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("bootstrapCompliancePolicyRegistry fails closed: missing target, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v-ghost", now: new Date(NOW_MS) }),
    REASON.BOOTSTRAP_TARGET_MISSING,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("bootstrapCompliancePolicyRegistry fails closed: malformed target, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedDoc(store, REGISTRY_COLLECTION, "v-bad", "not-an-object");
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v-bad", now: new Date(NOW_MS) }),
    `${REASON.BOOTSTRAP_TARGET_INVALID_PREFIX}:${REASON.DOCUMENT_NOT_OBJECT}`,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("bootstrapCompliancePolicyRegistry fails closed: non-draft (inactive/retired) target, zero writes", async () => {
  for (const status of ["inactive", "retired"]) {
    const store = createStore();
    const db = createFakeDb(store);
    seedDoc(store, REGISTRY_COLLECTION, "v-nd", makeValidDocument({ status }));
    const before = snapshotDocs(store);
    await assertRejectsWithReason(
      () => bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v-nd", now: new Date(NOW_MS) }),
      `${REASON.BOOTSTRAP_TARGET_INVALID_PREFIX}:${REASON.DOCUMENT_STATUS_NOT_ALLOWED}`,
      "failed-precondition"
    );
    assertNoWrites(store, before);
  }
});

test("bootstrapCompliancePolicyRegistry fails closed: an already-active target is caught by the anomaly check first", async () => {
  // A target whose own stored status is already `active` is itself the
  // thing the bounded anomaly query finds — the anomaly check (an
  // active version exists despite no pointer) correctly fires before
  // the target-status check is ever reached, since both are genuine,
  // independently-sufficient reasons to reject.
  const store = createStore();
  const db = createFakeDb(store);
  seedDoc(store, REGISTRY_COLLECTION, "v-nd", makeValidDocument({ status: "active" }));
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v-nd", now: new Date(NOW_MS) }),
    `${REASON.BOOTSTRAP_ANOMALY_ACTIVE_COUNT_NONZERO}:1`,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("bootstrapCompliancePolicyRegistry fails closed: future-effective target, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedDoc(store, REGISTRY_COLLECTION, "v-future", makeValidDocument({ status: "draft", effectiveFromMs: NOW_MS + 10_000 }));
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v-future", now: new Date(NOW_MS) }),
    `${REASON.BOOTSTRAP_TARGET_INVALID_PREFIX}:${REASON.EFFECTIVE_FROM_FUTURE}`,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("bootstrapCompliancePolicyRegistry fails closed: invalid target ID rejected before path construction", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const before = snapshotDocs(store);
  await assert.rejects(
    () => bootstrapCompliancePolicyRegistry({ db, targetVersionId: "has/slash", now: new Date(NOW_MS) }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      assert.ok(err.message.startsWith(REASON.BOOTSTRAP_TARGET_VERSION_ID_INVALID));
      return true;
    }
  );
  assert.equal(store.runTransactionCallCount, 0, "an invalid target ID must be rejected before any transaction opens");
  assertNoWrites(store, before);
});

test("bootstrapCompliancePolicyRegistry fails closed: query/read/write failure, zero writes", async () => {
  const store1 = createStore();
  const db1 = createFakeDb(store1);
  seedDoc(store1, REGISTRY_COLLECTION, "v1", makeValidDocument({ status: "draft" }));
  store1.failOnRead.add(`${POINTER_COLLECTION}/${POINTER_DOC_ID}`);
  const before1 = snapshotDocs(store1);
  await assertRejectsWithReason(
    () => bootstrapCompliancePolicyRegistry({ db: db1, targetVersionId: "v1", now: new Date(NOW_MS) }),
    REASON.BOOTSTRAP_POINTER_READ_FAILED,
    "unavailable"
  );
  assertNoWrites(store1, before1);

  const store2 = createStore();
  const db2 = createFakeDb(store2);
  seedDoc(store2, REGISTRY_COLLECTION, "v1", makeValidDocument({ status: "draft" }));
  store2.failOnQuery = true;
  const before2 = snapshotDocs(store2);
  await assertRejectsWithReason(
    () => bootstrapCompliancePolicyRegistry({ db: db2, targetVersionId: "v1", now: new Date(NOW_MS) }),
    REASON.BOOTSTRAP_ANOMALY_QUERY_FAILED,
    "unavailable"
  );
  assertNoWrites(store2, before2);
});

test("bootstrapCompliancePolicyRegistry: concurrent callers — exactly one succeeds", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedDoc(store, REGISTRY_COLLECTION, "v1", makeValidDocument({ status: "draft" }));

  const results = await Promise.allSettled([
    bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v1", now: new Date(NOW_MS) }),
    bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v1", now: new Date(NOW_MS) }),
  ]);

  const fulfilled = results.filter((r) => r.status === "fulfilled");
  const rejected = results.filter((r) => r.status === "rejected");
  assert.equal(fulfilled.length, 1, "exactly one concurrent bootstrap attempt must succeed");
  assert.equal(rejected.length, 1);
  assert.ok(rejected[0].reason.message.startsWith(REASON.BOOTSTRAP_POINTER_ALREADY_EXISTS));
  assert.equal(getRawDoc(store, POINTER_COLLECTION, POINTER_DOC_ID).activeVersionId, "v1");
});

test("bootstrapCompliancePolicyRegistry: retry after a successful bootstrap fails with zero new writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedDoc(store, REGISTRY_COLLECTION, "v1", makeValidDocument({ status: "draft" }));
  await bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v1", now: new Date(NOW_MS) });
  const afterFirst = snapshotDocs(store);

  await assertRejectsWithReason(
    () => bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v1", now: new Date(NOW_MS) }),
    REASON.BOOTSTRAP_POINTER_ALREADY_EXISTS,
    "failed-precondition"
  );
  assert.deepEqual(store.docs, afterFirst);
});

test("bootstrapCompliancePolicyRegistry never auto-creates the target or repairs an anomaly", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const before = snapshotDocs(store);
  try {
    await bootstrapCompliancePolicyRegistry({ db, targetVersionId: "v-never-created", now: new Date(NOW_MS) });
  } catch {
    // expected
  }
  assert.equal(getRawDoc(store, REGISTRY_COLLECTION, "v-never-created"), undefined);
  assertNoWrites(store, before);
});

// =======================================================================
// D. activatePolicyVersion — ordinary, subsequent-activation-only
// =======================================================================

test("activatePolicyVersion: valid current-active + draft target succeeds, exactly three writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  seedDoc(store, REGISTRY_COLLECTION, "v2", makeValidDocument({ status: "draft" }));

  const result = await activatePolicyVersion({ db, targetVersionId: "v2", now: new Date(NOW_MS) });
  assert.deepEqual(result, { previousActiveVersionId: "v1", activeVersionId: "v2" });

  const writes = store.callLog.filter((e) => e.startsWith("update:") || e.startsWith("create:"));
  assert.equal(writes.length, 3);
  assert.equal(getRawDoc(store, REGISTRY_COLLECTION, "v1").status, "retired");
  assert.equal(getRawDoc(store, REGISTRY_COLLECTION, "v2").status, "active");
  assert.equal(getRawDoc(store, POINTER_COLLECTION, POINTER_DOC_ID).activeVersionId, "v2");
});

test("activatePolicyVersion: immutable content proof — only status changes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const currentContent = makeValidDocument({ status: "active", changeNote: "current" });
  const targetContent = makeValidDocument({ status: "draft", changeNote: "target" });
  seedDoc(store, POINTER_COLLECTION, POINTER_DOC_ID, { activeVersionId: "v1" });
  seedDoc(store, REGISTRY_COLLECTION, "v1", currentContent);
  seedDoc(store, REGISTRY_COLLECTION, "v2", targetContent);

  await activatePolicyVersion({ db, targetVersionId: "v2", now: new Date(NOW_MS) });

  const { status: _s1, ...v1After } = getRawDoc(store, REGISTRY_COLLECTION, "v1");
  const { status: _s2, ...v1Before } = currentContent;
  const { status: _s3, ...v2After } = getRawDoc(store, REGISTRY_COLLECTION, "v2");
  const { status: _s4, ...v2Before } = targetContent;
  assert.deepEqual(v1After, v1Before);
  assert.deepEqual(v2After, v2Before);
});

test("activatePolicyVersion fails closed: malformed current active version aborts, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedDoc(store, POINTER_COLLECTION, POINTER_DOC_ID, { activeVersionId: "v1" });
  seedDoc(store, REGISTRY_COLLECTION, "v1", { status: "active" }); // missing required fields
  seedDoc(store, REGISTRY_COLLECTION, "v2", makeValidDocument({ status: "draft" }));
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db, targetVersionId: "v2", now: new Date(NOW_MS) }),
    `${REASON.ACTIVATION_CURRENT_INVALID_PREFIX}:${REASON.DOCUMENT_MISSING_FIELD}`,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("activatePolicyVersion fails closed: malformed target aborts, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  seedDoc(store, REGISTRY_COLLECTION, "v2", { status: "draft" }); // missing required fields
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db, targetVersionId: "v2", now: new Date(NOW_MS) }),
    `${REASON.ACTIVATION_TARGET_INVALID_PREFIX}:${REASON.DOCUMENT_MISSING_FIELD}`,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("activatePolicyVersion fails closed: target requirement-group violation aborts, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  const badEntry = makeValidRelationshipEntry({ requiredDocumentTypeGroups: [] });
  seedDoc(store, REGISTRY_COLLECTION, "v2", makeValidDocument({ status: "draft", sellerRelationship: { manufacturer: badEntry } }));
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db, targetVersionId: "v2", now: new Date(NOW_MS) }),
    `${REASON.ACTIVATION_TARGET_INVALID_PREFIX}:${REASON.CONTENT_REQUIRED_GROUPS_INVALID}`,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("activatePolicyVersion fails closed: future target/current effectiveFrom aborts, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  seedDoc(
    store,
    REGISTRY_COLLECTION,
    "v2",
    makeValidDocument({ status: "draft", effectiveFromMs: NOW_MS + 100_000 })
  );
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db, targetVersionId: "v2", now: new Date(NOW_MS) }),
    `${REASON.ACTIVATION_TARGET_INVALID_PREFIX}:${REASON.EFFECTIVE_FROM_FUTURE}`,
    "failed-precondition"
  );
  assertNoWrites(store, before);

  const store2 = createStore();
  const db2 = createFakeDb(store2);
  seedDoc(store2, POINTER_COLLECTION, POINTER_DOC_ID, { activeVersionId: "v1" });
  seedDoc(store2, REGISTRY_COLLECTION, "v1", makeValidDocument({ status: "active", effectiveFromMs: NOW_MS + 100_000 }));
  seedDoc(store2, REGISTRY_COLLECTION, "v2", makeValidDocument({ status: "draft" }));
  const before2 = snapshotDocs(store2);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db: db2, targetVersionId: "v2", now: new Date(NOW_MS) }),
    `${REASON.ACTIVATION_CURRENT_INVALID_PREFIX}:${REASON.EFFECTIVE_FROM_FUTURE}`,
    "failed-precondition"
  );
  assertNoWrites(store2, before2);
});

test("activatePolicyVersion fails closed: inactive target rejected, never treated as draft", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  seedDoc(store, REGISTRY_COLLECTION, "v2", makeValidDocument({ status: "inactive" }));
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db, targetVersionId: "v2", now: new Date(NOW_MS) }),
    `${REASON.ACTIVATION_TARGET_INVALID_PREFIX}:${REASON.DOCUMENT_STATUS_NOT_ALLOWED}`,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("activatePolicyVersion fails closed: target equals current active version, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db, targetVersionId: "v1", now: new Date(NOW_MS) }),
    REASON.ACTIVATION_TARGET_EQUALS_CURRENT,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("activatePolicyVersion fails closed: missing pointer, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedDoc(store, REGISTRY_COLLECTION, "v2", makeValidDocument({ status: "draft" }));
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db, targetVersionId: "v2", now: new Date(NOW_MS) }),
    REASON.POINTER_MISSING,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("activatePolicyVersion fails closed: missing target, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db, targetVersionId: "v-ghost", now: new Date(NOW_MS) }),
    REASON.ACTIVATION_TARGET_MISSING,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("activatePolicyVersion fails closed: active-status anomaly query zero/two results, zero writes", async () => {
  const storeZero = createStore();
  const dbZero = createFakeDb(storeZero);
  seedActiveRegistry({ store: storeZero, versionId: "v1" });
  seedDoc(storeZero, REGISTRY_COLLECTION, "v2", makeValidDocument({ status: "draft" }));
  storeZero.queryOverride = [];
  const beforeZero = snapshotDocs(storeZero);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db: dbZero, targetVersionId: "v2", now: new Date(NOW_MS) }),
    `${REASON.ACTIVATION_ANOMALY_COUNT_MISMATCH}:0`,
    "failed-precondition"
  );
  assertNoWrites(storeZero, beforeZero);

  const storeTwo = createStore();
  const dbTwo = createFakeDb(storeTwo);
  seedActiveRegistry({ store: storeTwo, versionId: "v1" });
  seedDoc(storeTwo, REGISTRY_COLLECTION, "v-rogue", makeValidDocument({ status: "active" }));
  seedDoc(storeTwo, REGISTRY_COLLECTION, "v2", makeValidDocument({ status: "draft" }));
  const beforeTwo = snapshotDocs(storeTwo);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db: dbTwo, targetVersionId: "v2", now: new Date(NOW_MS) }),
    `${REASON.ACTIVATION_ANOMALY_COUNT_MISMATCH}:2`,
    "failed-precondition"
  );
  assertNoWrites(storeTwo, beforeTwo);
});

test("activatePolicyVersion fails closed: anomaly result differs from pointer target, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  seedDoc(store, REGISTRY_COLLECTION, "v2", makeValidDocument({ status: "draft" }));
  store.queryOverride = [{ id: "v-rogue", data: { status: "active" } }];
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db, targetVersionId: "v2", now: new Date(NOW_MS) }),
    REASON.ACTIVATION_ANOMALY_ID_MISMATCH,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("activatePolicyVersion fails closed: malformed anomaly-query result, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  seedDoc(store, REGISTRY_COLLECTION, "v2", makeValidDocument({ status: "draft" }));
  store.queryOverride = [{ id: "v1", data: { notStatus: "whoops" } }];
  const before = snapshotDocs(store);
  await assertRejectsWithReason(
    () => activatePolicyVersion({ db, targetVersionId: "v2", now: new Date(NOW_MS) }),
    REASON.ACTIVATION_ANOMALY_RESULT_MALFORMED,
    "failed-precondition"
  );
  assertNoWrites(store, before);
});

test("activatePolicyVersion fails closed: invalid target ID, never opens a transaction, zero writes", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  const before = snapshotDocs(store);
  await assert.rejects(
    () => activatePolicyVersion({ db, targetVersionId: "has/slash", now: new Date(NOW_MS) }),
    (err) => {
      assert.equal(err.code, "invalid-argument");
      assert.ok(err.message.startsWith(REASON.ACTIVATION_TARGET_VERSION_ID_INVALID));
      return true;
    }
  );
  assert.equal(store.runTransactionCallCount, 0);
  assertNoWrites(store, before);
});

test("a retried activation of an already-activated target does not produce a partial or duplicate transition", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  seedDoc(store, REGISTRY_COLLECTION, "v2", makeValidDocument({ status: "draft" }));

  await activatePolicyVersion({ db, targetVersionId: "v2", now: new Date(NOW_MS) });
  const afterFirst = snapshotDocs(store);

  await assertRejectsWithReason(
    () => activatePolicyVersion({ db, targetVersionId: "v2", now: new Date(NOW_MS) }),
    REASON.ACTIVATION_TARGET_EQUALS_CURRENT,
    "failed-precondition"
  );
  assert.deepEqual(store.docs, afterFirst);
});

// =======================================================================
// E. resolveActivePolicy
// =======================================================================

test("resolveActivePolicy: resolves a valid pointer and exact active version", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  const result = await resolveActivePolicy({ db, now: new Date(NOW_MS) });
  assert.equal(result.activeVersionId, "v1");
  assert.equal(result.version.status, "active");
});

test("resolveActivePolicy: fresh pointer and fresh version on every independent invocation, no cross-request cache", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  const first = await resolveActivePolicy({ db, now: new Date(NOW_MS) });
  assert.equal(first.activeVersionId, "v1");

  seedActiveRegistry({ store, versionId: "v2" });
  const second = await resolveActivePolicy({ db, now: new Date(NOW_MS) });
  assert.equal(second.activeVersionId, "v2", "must observe the new pointer/version, not a cached v1");
});

test("resolveActivePolicy fails closed: malformed nested active version content", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  const badEntry = makeValidRelationshipEntry({ acceptedScopeTypes: [] });
  seedDoc(store, POINTER_COLLECTION, POINTER_DOC_ID, { activeVersionId: "v1" });
  seedDoc(store, REGISTRY_COLLECTION, "v1", makeValidDocument({ status: "active", sellerRelationship: { manufacturer: badEntry } }));
  await assertRejectsWithReason(
    () => resolveActivePolicy({ db, now: new Date(NOW_MS) }),
    `${REASON.RESOLVE_ACTIVE_INVALID_PREFIX}:${REASON.CONTENT_ACCEPTED_SCOPE_TYPES_EMPTY}`,
    "failed-precondition"
  );
});

test("resolveActivePolicy fails closed: future effectiveFrom / future createdAt on the active version", async () => {
  const storeA = createStore();
  const dbA = createFakeDb(storeA);
  seedDoc(storeA, POINTER_COLLECTION, POINTER_DOC_ID, { activeVersionId: "v1" });
  seedDoc(storeA, REGISTRY_COLLECTION, "v1", makeValidDocument({ status: "active", effectiveFromMs: NOW_MS + 5000 }));
  await assertRejectsWithReason(
    () => resolveActivePolicy({ db: dbA, now: new Date(NOW_MS) }),
    `${REASON.RESOLVE_ACTIVE_INVALID_PREFIX}:${REASON.EFFECTIVE_FROM_FUTURE}`,
    "failed-precondition"
  );

  const storeB = createStore();
  const dbB = createFakeDb(storeB);
  seedDoc(storeB, POINTER_COLLECTION, POINTER_DOC_ID, { activeVersionId: "v1" });
  seedDoc(storeB, REGISTRY_COLLECTION, "v1", makeValidDocument({ status: "active", createdAtMs: NOW_MS + 5000 }));
  await assertRejectsWithReason(
    () => resolveActivePolicy({ db: dbB, now: new Date(NOW_MS) }),
    `${REASON.RESOLVE_ACTIVE_INVALID_PREFIX}:${REASON.DOCUMENT_CREATED_AT_FUTURE}`,
    "failed-precondition"
  );
});

test("resolveActivePolicy fails closed: missing pointer, malformed pointer, dangling/malformed version", async () => {
  const s1 = createStore();
  await assertRejectsWithReason(
    () => resolveActivePolicy({ db: createFakeDb(s1), now: new Date(NOW_MS) }),
    REASON.POINTER_MISSING,
    "failed-precondition"
  );

  const s2 = createStore();
  seedDoc(s2, POINTER_COLLECTION, POINTER_DOC_ID, "garbage");
  await assertRejectsWithReason(
    () => resolveActivePolicy({ db: createFakeDb(s2), now: new Date(NOW_MS) }),
    REASON.POINTER_MALFORMED,
    "failed-precondition"
  );

  const s3 = createStore();
  seedDoc(s3, POINTER_COLLECTION, POINTER_DOC_ID, { activeVersionId: "v-ghost" });
  await assertRejectsWithReason(
    () => resolveActivePolicy({ db: createFakeDb(s3), now: new Date(NOW_MS) }),
    REASON.VERSION_DANGLING,
    "failed-precondition"
  );

  const s4 = createStore();
  seedDoc(s4, POINTER_COLLECTION, POINTER_DOC_ID, { activeVersionId: "v1" });
  seedDoc(s4, REGISTRY_COLLECTION, "v1", "not-an-object");
  await assertRejectsWithReason(
    () => resolveActivePolicy({ db: createFakeDb(s4), now: new Date(NOW_MS) }),
    `${REASON.RESOLVE_ACTIVE_INVALID_PREFIX}:${REASON.DOCUMENT_NOT_OBJECT}`,
    "failed-precondition"
  );
});

test("resolveActivePolicy fails closed: pointer/version status inconsistency (version not active)", async () => {
  const store = createStore();
  seedDoc(store, POINTER_COLLECTION, POINTER_DOC_ID, { activeVersionId: "v1" });
  seedDoc(store, REGISTRY_COLLECTION, "v1", makeValidDocument({ status: "draft" }));
  await assertRejectsWithReason(
    () => resolveActivePolicy({ db: createFakeDb(store), now: new Date(NOW_MS) }),
    `${REASON.RESOLVE_ACTIVE_INVALID_PREFIX}:${REASON.DOCUMENT_STATUS_NOT_ALLOWED}`,
    "failed-precondition"
  );
});

test("resolveActivePolicy never issues a status-based query — resolution authority is the pointer alone", async () => {
  const store = createStore();
  const db = createFakeDb(store);
  seedActiveRegistry({ store, versionId: "v1" });
  await resolveActivePolicy({ db, now: new Date(NOW_MS) });
  assert.deepEqual(store.whereCallCollections, []);
});

test("resolveActivePolicy never returns a fallback — every anomaly rejects, none resolve", async () => {
  const scenarios = [
    (store) => {},
    (store) => seedDoc(store, POINTER_COLLECTION, POINTER_DOC_ID, "garbage"),
    (store) => seedDoc(store, POINTER_COLLECTION, POINTER_DOC_ID, { activeVersionId: "v-ghost" }),
  ];
  for (const seed of scenarios) {
    const store = createStore();
    const db = createFakeDb(store);
    seed(store);
    let resolved = false;
    try {
      await resolveActivePolicy({ db, now: new Date(NOW_MS) });
      resolved = true;
    } catch {
      // expected
    }
    assert.equal(resolved, false);
  }
});

// =======================================================================
// F. Architecture / static tests
// =======================================================================

const MODULE_PATH = path.join(
  __dirname,
  "..",
  "src",
  "marketplace",
  "compliance",
  "compliancePolicyRegistryOperations.js"
);
const MODULE_SOURCE = fs.readFileSync(MODULE_PATH, "utf8");
const INDEX_SOURCE = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");

test("exactly one authoritative validator exists, and all four operations invoke it", () => {
  const defCount = (MODULE_SOURCE.match(/function validateCompliancePolicyVersionDocument\(/g) || []).length;
  assert.equal(defCount, 1);
  const callCount = (MODULE_SOURCE.match(/validateCompliancePolicyVersionDocument\(/g) || []).length;
  // 1 definition + at least 4 call sites (create, bootstrap, activation
  // x2 for current+target, resolve).
  assert.ok(callCount >= 6, `expected >=6 references (1 def + >=5 calls), found ${callCount}`);
});

test("no executable TTL/pointer-or-version-cache implementation exists in the module source", () => {
  const forbidden = ["setTimeout(", "setInterval(", "Date.now() +", "cachedPointer", "cachedVersion"];
  for (const token of forbidden) {
    assert.equal(MODULE_SOURCE.includes(token), false, `forbidden token "${token}" found`);
  }
});

test("no module-level mutable state exists — only frozen/const top-level bindings", () => {
  const topLevelDeclarations = MODULE_SOURCE.match(/^(let|var)\s+\w+/gm) || [];
  assert.deepEqual(topLevelDeclarations, []);
});

test("no live requiredDocumentTypes (flat, obsolete field) implementation remains", () => {
  assert.equal(MODULE_SOURCE.includes('"requiredDocumentTypes"'), false);
  assert.equal(/[^e]requiredDocumentTypes[^G]/.test(MODULE_SOURCE), false);
});

test("functions/index.js does not export or reference this module", () => {
  assert.equal(INDEX_SOURCE.includes("compliancePolicyRegistryOperations"), false);
  for (const fn of [
    "createCompliancePolicyVersion",
    "resolveActivePolicy",
    "bootstrapCompliancePolicyRegistry",
    "activatePolicyVersion",
  ]) {
    assert.equal(INDEX_SOURCE.includes(fn), false);
  }
});

test("module source contains no callable/HTTP/trigger/scheduler wrapper", () => {
  const forbidden = [
    "onCall(",
    "onRequest(",
    "onSchedule(",
    "onDocumentWritten(",
    "onDocumentCreated(",
    "onDocumentUpdated(",
    "onTaskDispatched(",
    "functions.https",
    "functions.pubsub",
  ];
  for (const token of forbidden) {
    assert.equal(MODULE_SOURCE.includes(token), false, `forbidden token "${token}" found`);
  }
});

test("module does not import (require) complianceDocumentOperations (Slice 3)", () => {
  const requireLines = MODULE_SOURCE.match(/require\([^)]*\)/g) || [];
  assert.equal(
    requireLines.some((l) => l.includes("complianceDocumentOperations")),
    false
  );
});

test("module source introduces no real policy content or staging/production project literal", () => {
  const forbidden = ["barkymatches-new", "petsupo-platform-staging", "petsupo-prod", "firebaseio.com", ".firebaseapp.com"];
  for (const token of forbidden) {
    assert.equal(MODULE_SOURCE.includes(token), false, `forbidden literal "${token}" found`);
  }
});

test("the anomaly query is bounded with limit(2) in both bootstrap and activation", () => {
  const matches = MODULE_SOURCE.match(/\.where\(\s*"status"\s*,\s*"=="\s*,\s*COMPLIANCE_POLICY_REGISTRY_STATUS\.ACTIVE\s*\)\s*\.limit\(2\)/g) || [];
  assert.equal(matches.length, 2);
});

test("resolveActivePolicy source never queries by status — only .doc(...).get()", () => {
  const start = MODULE_SOURCE.indexOf("async function resolveActivePolicy");
  const end = MODULE_SOURCE.indexOf("// C. bootstrapCompliancePolicyRegistry");
  const body = MODULE_SOURCE.slice(start, end);
  assert.equal(body.includes(".where("), false);
});

test("no skip/todo/environment-dependent bypass anywhere in this test file", () => {
  // Scans only the region BEFORE this test's own definition — this
  // test's own assertions necessarily contain the denylisted strings as
  // literal arguments, which would otherwise trivially self-match.
  const testSource = fs.readFileSync(__filename, "utf8");
  const selfStart = testSource.indexOf('test("no skip/todo/environment-dependent bypass');
  const scanRegion = testSource.slice(0, selfStart);
  assert.equal(/\{\s*skip\s*:/.test(scanRegion), false);
  assert.equal(/\btest\.todo\(/.test(scanRegion), false);
  assert.equal(scanRegion.includes("FIRESTORE_EMULATOR_HOST"), false);
  assert.equal(scanRegion.includes("GCLOUD_PROJECT"), false);
});

test("isValidRegistryVersionId: identifier-shape allowlist matrix", () => {
  assert.equal(isValidRegistryVersionId("v1"), true);
  assert.equal(isValidRegistryVersionId(""), false);
  assert.equal(isValidRegistryVersionId("has/slash"), false);
  assert.equal(isValidRegistryVersionId(".."), false);
  assert.equal(isValidRegistryVersionId("-leading-dash"), false);
  assert.equal(isValidRegistryVersionId("trailing-dash-"), false);
  assert.equal(isValidRegistryVersionId("has\x00control"), false);
  assert.equal(isValidRegistryVersionId("a".repeat(129)), false);
  assert.equal(isValidRegistryVersionId("a".repeat(128)), true);
  assert.equal(isValidRegistryVersionId(123), false);
});

// =======================================================================
// G. Manual-override hard invariant — Slice 4.1 never treats
//    manualAdminOverridePermitted as evidence satisfaction. No evaluator
//    is implemented in Slice 4.1; this proves the validator's own
//    treatment of the field is a pure structural boolean with no
//    special-cased bypass logic anywhere in this module.
// =======================================================================

test("manualAdminOverridePermitted is validated as a pure boolean and never referenced as a bypass anywhere else in the module", () => {
  // The only appearance of the field name outside the schema/allowlist
  // declarations and its own boolean-type check must be its doc-comment
  // explanation — never a conditional that skips/relaxes any other
  // check (evidence, malware, revocation, business/type/scope matching)
  // based on its value.
  const occurrences = MODULE_SOURCE.split("manualAdminOverridePermitted").length - 1;
  // Exactly: allowlist array entry, destructure, type-check reference,
  // plus doc-comment prose mentions — never used in an `if` guarding a
  // requirement/evidence/eligibility check.
  const ifGuardPattern = /if\s*\([^)]*manualAdminOverridePermitted[^)]*\)\s*\{[^}]*(satisf|evidence|eligib|bypass|approve|malware|revok|expire)/i;
  assert.equal(ifGuardPattern.test(MODULE_SOURCE), false);
  assert.ok(occurrences > 0, "the field must still be validated somewhere");
});

test("manualAdminOverridePermitted alone cannot satisfy a requirement group — structural proof via the validator", () => {
  // A relationship entry with manualAdminOverridePermitted: true but an
  // otherwise-empty requiredDocumentTypeGroups is still rejected exactly
  // like manualAdminOverridePermitted: false would be — the flag has no
  // effect on the outcome.
  const entryOverrideTrue = makeValidRelationshipEntry({
    requiredDocumentTypeGroups: [],
    manualAdminOverridePermitted: true,
  });
  const entryOverrideFalse = makeValidRelationshipEntry({
    requiredDocumentTypeGroups: [],
    manualAdminOverridePermitted: false,
  });
  const resultTrue = validateCompliancePolicyVersionDocument(
    makeValidDocument({ sellerRelationship: { manufacturer: entryOverrideTrue } }),
    { requireActivationEligible: true }
  );
  const resultFalse = validateCompliancePolicyVersionDocument(
    makeValidDocument({ sellerRelationship: { manufacturer: entryOverrideFalse } }),
    { requireActivationEligible: true }
  );
  assert.equal(resultTrue.valid, false);
  assert.equal(resultFalse.valid, false);
  assert.equal(resultTrue.reason, resultFalse.reason);
});
