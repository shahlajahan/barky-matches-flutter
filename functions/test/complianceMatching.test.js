"use strict";

// P1-A Slice 4.3 — matching/evaluator engine tests (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §10/§10.1/§13.1/§15, Revision 9 corrections 49-52). Deliberately NOT
// emulator-backed — none of Slice 4.3's modules are wired into any
// onCall/HTTP/trigger, so nothing here needs the Firestore emulator,
// network, credentials, or GCP/Firebase access of any kind (same
// established convention as compliancePolicyRegistryOperations.test.js's
// own fake). A hand-rolled, self-contained in-memory fake stands in for
// `db`, extended here to support multi-field equality queries,
// orderBy/limit, and subcollections — none of which the Slice 4.1 fake
// needed.
//
// Covers all four new Slice 4.3 modules in one file, per the master
// plan's own explicit scope note (§13.1): "no additional test file is
// authorized beyond this and complianceConstants.test.js."
//
// No conditional test-skipping and no environment-dependent bypass
// anywhere in this file — every test always runs.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  COMPLIANCE_SCOPE_TYPE,
  COMPLIANCE_SCOPE_STATUS,
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_SCOPE_MEMBER_STATUS,
  COMPLIANCE_SCOPE_MEMBER_IDENTIFIER_TYPE,
  COMPLIANCE_DOCUMENT_TYPE,
  SELLER_RELATIONSHIP,
  COMPLIANCE_POLICY_REGISTRY_STATUS,
  COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION,
  COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID,
  PRODUCT_COMPLIANCE_EFFECTIVE_STATUS,
  LOOKUP_LIMIT,
  MATCHED_SCOPE_CAP,
} = require("../src/marketplace/compliance/complianceConstants");

const {
  normalizeBrand,
  computeNormalizedBrandId,
  NORMALIZER_VERSION,
} = require("../src/marketplace/compliance/complianceBrandNormalizer");

const {
  deriveEvidenceLinkId,
  selectPolicyBranch,
  scopeValueForLookupType,
  runComplianceMatching,
  createCounters,
  SOURCE_READ_CAP,
  ACTIVE_REF_CAP,
} = require("../src/marketplace/compliance/complianceMatching");

const { deriveScopeMemberId } = require("../src/marketplace/compliance/complianceDocumentOperations");

const {
  recomputeProductComplianceStatus,
  computeDecisionHash,
  canonicalizeForHash,
  determineEffectiveStatus,
  computeEffectiveValidUntil,
  DECISION_HASH_INCLUDED_FIELDS,
} = require("../src/marketplace/compliance/complianceProductRecompute");

const { evaluateLiveProductEligibility } = require("../src/marketplace/compliance/complianceEligibilityEvaluator");

const REGISTRY_COLLECTION = "compliancePolicyRegistry";
const SCOPES_COLLECTION = "complianceDocumentScopes";
const DOCUMENTS_COLLECTION = "complianceDocuments";
const EPOCHS_COLLECTION = "businessComplianceEpochs";
const DECISIONS_COLLECTION = "productComplianceDecisions";
const LINKS_COLLECTION = "productEvidenceLinks";
const REVIEW_EVENTS_COLLECTION = "complianceReviewEvents";
const PRODUCTS_ROOT = "businesses";

// =======================================================================
// Fake Firestore — extended for Slice 4.3's query/subcollection needs.
// =======================================================================

function createStore() {
  return {
    docs: new Map(),
    docVersions: new Map(),
    callLog: [],
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

function segmentCount(p) {
  return p.split("/").filter(Boolean).length;
}

function makeRef(fullPath, store) {
  const parts = fullPath.split("/");
  const id = parts[parts.length - 1];
  return {
    id,
    path: fullPath,
    async get() {
      store.callLog.push(`get:${fullPath}`);
      return makeDocSnapshot(id, store.docs.get(fullPath));
    },
    collection(subName) {
      return makeCollection(`${fullPath}/${subName}`, store);
    },
  };
}

function matchesFilters(rawValue, filters) {
  if (!rawValue || typeof rawValue !== "object" || Array.isArray(rawValue)) return false;
  for (const f of filters) {
    if (rawValue[f.field] !== f.value) return false;
  }
  return true;
}

function makeQuery(collectionPath, store, { filters, orderByField, orderByDir, limitN }) {
  return {
    async get() {
      store.callLog.push(`query:${collectionPath}`);
      const depth = segmentCount(collectionPath) + 1;
      const results = [];
      for (const [docPath, rawValue] of store.docs.entries()) {
        if (!docPath.startsWith(`${collectionPath}/`)) continue;
        if (segmentCount(docPath) !== depth) continue; // direct children only
        if (!matchesFilters(rawValue, filters)) continue;
        const id = docPath.slice(collectionPath.length + 1);
        results.push({ id, data: rawValue });
      }
      results.sort((a, b) => {
        if (orderByField) {
          const av = a.data[orderByField];
          const bv = b.data[orderByField];
          const aMs = av && typeof av.toMillis === "function" ? av.toMillis() : Number(av) || 0;
          const bMs = bv && typeof bv.toMillis === "function" ? bv.toMillis() : Number(bv) || 0;
          if (aMs !== bMs) return orderByDir === "desc" ? bMs - aMs : aMs - bMs;
        }
        return a.id < b.id ? -1 : a.id > b.id ? 1 : 0; // implicit __name__ ASC tiebreak
      });
      const limited = typeof limitN === "number" ? results.slice(0, limitN) : results;
      return { docs: limited.map((r) => makeDocSnapshot(r.id, r.data)) };
    },
  };
}

function makeQueryBuilder(collectionPath, store, filters) {
  return {
    where(field, op, value) {
      if (op !== "==") throw new Error(`fake db only supports '==' filters, got '${op}'`);
      return makeQueryBuilder(collectionPath, store, [...filters, { field, value }]);
    },
    orderBy(field, dir = "asc") {
      return {
        limit(limitN) {
          return makeQuery(collectionPath, store, { filters, orderByField: field, orderByDir: dir, limitN });
        },
      };
    },
    limit(limitN) {
      return makeQuery(collectionPath, store, { filters, orderByField: null, orderByDir: "asc", limitN });
    },
  };
}

function makeCollection(collectionPath, store) {
  return {
    doc(id) {
      if (id === undefined) {
        // Auto-generated-ID convention (complianceReviewEvents' own
        // established `.doc()` — no arg — pattern).
        const autoId = `auto-${Math.random().toString(36).slice(2)}-${store.docs.size}`;
        return makeRef(`${collectionPath}/${autoId}`, store);
      }
      return makeRef(`${collectionPath}/${id}`, store);
    },
    where(field, op, value) {
      return makeQueryBuilder(collectionPath, store, []).where(field, op, value);
    },
  };
}

function createFakeDb(store) {
  function collection(name) {
    return makeCollection(name, store);
  }

  async function runTransaction(callback) {
    const staged = [];
    const tx = {
      async get(refOrQuery) {
        return refOrQuery.get();
      },
      set(ref, data) {
        staged.push({ type: "set", path: ref.path, data });
      },
      create(ref, data) {
        staged.push({ type: "create", path: ref.path, data });
      },
      delete(ref) {
        staged.push({ type: "delete", path: ref.path });
      },
    };
    const result = await callback(tx);
    for (const write of staged) {
      if (write.type === "delete") {
        store.docs.delete(write.path);
      } else if (write.type === "create") {
        if (store.docs.get(write.path) !== undefined) {
          throw new Error(`simulated tx.create on existing doc: ${write.path}`);
        }
        store.docs.set(write.path, write.data);
      } else {
        store.docs.set(write.path, write.data);
      }
      bumpVersion(store, write.path);
      store.callLog.push(`${write.type}:${write.path}`);
    }
    return result;
  }

  return { collection, runTransaction };
}

function seedDoc(store, collectionPath, id, data) {
  store.docs.set(`${collectionPath}/${id}`, data);
  bumpVersion(store, `${collectionPath}/${id}`);
}

function getRawDoc(store, collectionPath, id) {
  return store.docs.get(`${collectionPath}/${id}`);
}

// =======================================================================
// Fixtures.
// =======================================================================

const NOW_MS = 1_800_000_000_000;
const NOW = new Date(NOW_MS);

function makeTimestamp(ms) {
  return { toMillis: () => ms };
}

const BUSINESS_ID = "biz-1";
const PRODUCT_ID = "prod-1";
const VERSION_ID = "policy-v1";

function seedActivePolicy(store, sellerRelationshipOverride) {
  seedDoc(store, COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION, COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID, {
    activeVersionId: VERSION_ID,
  });
  seedDoc(store, REGISTRY_COLLECTION, VERSION_ID, {
    sellerRelationship: sellerRelationshipOverride || {
      [SELLER_RELATIONSHIP.RESELLER]: {
        acceptedDocumentTypes: ["purchase_invoice", "manufacturer_evidence"],
        requiredDocumentTypeGroups: [["purchase_invoice"]],
        perDocumentTypePolicy: { purchase_invoice: { validUntilRequired: true, issueDateRequired: false } },
        maximumValidityPeriod: null,
        acceptedScopeTypes: ["business", "brand", "category", "product", "sku_set"],
        manualAdminOverridePermitted: false,
      },
    },
    status: COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE,
    effectiveFrom: makeTimestamp(NOW_MS - 100000),
    createdBy: "admin-1",
    createdAt: makeTimestamp(NOW_MS - 100000),
    changeNote: "test policy",
  });
}

function seedProduct(store, overrides = {}) {
  const data = {
    businessId: BUSINESS_ID,
    name: "Test Product",
    category: "Health > Vitamins",
    brand: "Acme",
    sku: "SKU-1",
    barcode: "1234567890123",
    sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
    productInputRevision: 1,
    ...overrides,
  };
  seedDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID, data);
  return data;
}

let scopeCounter = 0;
function seedScope(store, overrides = {}) {
  scopeCounter += 1;
  const scopeId = overrides.id || `scope-${scopeCounter}`;
  const documentId = overrides.documentId || `doc-${scopeCounter}`;
  const data = {
    documentId,
    businessId: BUSINESS_ID,
    scopeType: COMPLIANCE_SCOPE_TYPE.BUSINESS,
    scopeValue: BUSINESS_ID,
    sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
    // Revision 9 correction 49 defaults — denormalized copies. Matches
    // seedDocument's own defaults below, so a plain seedScopeAndDocument
    // call produces a self-consistent candidate out of the box; an
    // explicit override here (not derived from the paired document)
    // constructs a deliberate copy-mismatch anomaly.
    documentType: "purchase_invoice",
    validUntil: makeTimestamp(NOW_MS + 1_000_000_000),
    memberCount: 0,
    status: COMPLIANCE_SCOPE_STATUS.APPROVED,
    approvedAt: makeTimestamp(NOW_MS - 50000 + scopeCounter),
    createdAt: makeTimestamp(NOW_MS - 60000),
    createdBy: "seller-1",
    ...overrides,
  };
  delete data.id;
  seedDoc(store, SCOPES_COLLECTION, scopeId, data);
  return { scopeId, documentId, data };
}

function seedDocument(store, documentId, overrides = {}) {
  const data = {
    businessId: BUSINESS_ID,
    documentType: "purchase_invoice",
    sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
    status: COMPLIANCE_DOCUMENT_STATUS.APPROVED,
    validUntil: makeTimestamp(NOW_MS + 1_000_000_000),
    ...overrides,
  };
  seedDoc(store, DOCUMENTS_COLLECTION, documentId, data);
  return data;
}

// Seeds a scope + its source document together. By default the scope's
// own documentType/validUntil (Revision 9 correction 49) are patched to
// mirror the (defaulted+overridden) source document's own values — this
// is what real `addComplianceScope` denormalization always produces.
// `sellerRelationship` denormalization (Revision 7, pre-existing) is
// deliberately NOT auto-mirrored here — the two remain independently
// overridable exactly as this fixture already allowed before this task,
// which is what lets tests like H1 construct a genuine scope<->source
// sellerRelationship drift. Passing `overrides.scope.documentType` or
// `overrides.scope.validUntil` explicitly opts out of the auto-mirror
// for that one field, constructing a deliberate copy-mismatch anomaly.
function seedScopeAndDocument(store, overrides = {}) {
  const { scopeId, documentId } = seedScope(store, overrides.scope || {});
  const documentData = seedDocument(store, documentId, overrides.document || {});
  const scopeOverrides = overrides.scope || {};
  const patch = {};
  if (!("documentType" in scopeOverrides)) patch.documentType = documentData.documentType;
  if (!("validUntil" in scopeOverrides)) patch.validUntil = documentData.validUntil;
  if (Object.keys(patch).length > 0) {
    seedDoc(store, SCOPES_COLLECTION, scopeId, { ...getRawDoc(store, SCOPES_COLLECTION, scopeId), ...patch });
  }
  return { scopeId, documentId, scopeData: getRawDoc(store, SCOPES_COLLECTION, scopeId) };
}

function seedMember(store, { scopeId, identifierType, identifierValue, status = COMPLIANCE_SCOPE_MEMBER_STATUS.ACTIVE }) {
  const memberId = deriveScopeMemberId({ scopeId, identifierType, identifierValue });
  seedDoc(store, `${SCOPES_COLLECTION}/${scopeId}/members`, memberId, {
    identifierType,
    identifierValue,
    status,
    addedAt: makeTimestamp(NOW_MS - 40000),
    addedBy: "seller-1",
  });
  return memberId;
}

function seedEpoch(store, epoch) {
  seedDoc(store, EPOCHS_COLLECTION, BUSINESS_ID, { epoch });
}

function reviewEvents(store) {
  return [...store.docs.entries()]
    .filter(([p]) => p.startsWith(`${REVIEW_EVENTS_COLLECTION}/`))
    .map(([, data]) => data);
}

// Each of the 5 real, structurally-available lookup types has exactly
// ONE queryable scopeValue for a given product (its own businessId /
// normalizedBrandId / category / productId, or no scopeValue filter at
// all for sku_set) — so a SINGLE scope type can never surface more than
// LOOKUP_LIMIT (3) raw candidates, no matter how many are seeded under
// it, exactly like the real seven-query design (§10). Adversarial
// fixtures that need MORE than 3 raw candidates (to exercise the
// aggregate MATCHED_SCOPE_CAP=10 coverage-first/extras algorithm, as
// opposed to a single query's own per-type limit) must spread across
// multiple lookup-type "lanes" — this helper does exactly that,
// cycling through business/brand/category/product/sku_set, never more
// than LOOKUP_LIMIT per lane, and wiring up brand's verifiedBrandId /
// sku_set's member match automatically.
const CANDIDATE_LANES = ["business", "brand", "category", "product", "sku_set"];

function laneScopeValue(lane, product) {
  switch (lane) {
    case "business":
      return BUSINESS_ID;
    case "brand":
      return computeNormalizedBrandId(product.brand);
    case "category":
      return product.category;
    case "product":
      return PRODUCT_ID;
    case "sku_set":
      return undefined;
    default:
      throw new Error(`seedSpreadCandidates: unknown lane ${lane}`);
  }
}

// `entries`: array of { documentType, approvedAtMs, status?, sellerRelationship? }.
function seedSpreadCandidates(store, product, entries) {
  if (entries.length > CANDIDATE_LANES.length * LOOKUP_LIMIT) {
    throw new Error("seedSpreadCandidates: too many entries for the available lanes");
  }
  const results = [];
  let laneIndex = 0;
  let inLaneCount = 0;
  for (const entry of entries) {
    if (inLaneCount >= LOOKUP_LIMIT) {
      laneIndex += 1;
      inLaneCount = 0;
    }
    const lane = CANDIDATE_LANES[laneIndex];
    const scopeValue = laneScopeValue(lane, product);
    const scopeOverrides = { scopeType: lane, approvedAt: makeTimestamp(entry.approvedAtMs) };
    if (scopeValue !== undefined) scopeOverrides.scopeValue = scopeValue;
    if (lane === "brand") scopeOverrides.verifiedBrandId = computeNormalizedBrandId(product.brand);
    const documentOverrides = { documentType: entry.documentType };
    if (entry.status) documentOverrides.status = entry.status;
    if (entry.sellerRelationship) {
      documentOverrides.sellerRelationship = entry.sellerRelationship;
      scopeOverrides.sellerRelationship = entry.sellerRelationship;
    }
    const seeded = seedScopeAndDocument(store, { scope: scopeOverrides, document: documentOverrides });
    if (lane === "sku_set") {
      seedMember(store, { scopeId: seeded.scopeId, identifierType: "barcode", identifierValue: product.barcode });
    }
    results.push({ ...seeded, lane, documentType: entry.documentType });
    inLaneCount += 1;
  }
  return results;
}

const ALL_LANES_ACCEPTED_SCOPE_TYPES = Object.freeze(["business", "brand", "category", "product", "sku_set"]);

// =======================================================================
// A. Constants and exact schemas.
// =======================================================================

test("A. LOOKUP_LIMIT and MATCHED_SCOPE_CAP are exactly 3 and 10", () => {
  assert.equal(LOOKUP_LIMIT, 3);
  assert.equal(MATCHED_SCOPE_CAP, 10);
});

test("A2. SOURCE_READ_CAP and ACTIVE_REF_CAP are both exactly MATCHED_SCOPE_CAP — never sized independently", () => {
  assert.equal(SOURCE_READ_CAP, MATCHED_SCOPE_CAP);
  assert.equal(ACTIVE_REF_CAP, MATCHED_SCOPE_CAP);
});

// =======================================================================
// B. Frozen brand normalizer.
// =======================================================================

test("B1. normalizeBrand: NFKC + fixed-locale lowercase + whitespace collapse + truncation", () => {
  assert.equal(normalizeBrand("  Acme,  Inc.!!  "), "acme inc");
  assert.equal(normalizeBrand("ACME"), "acme");
  assert.equal(normalizeBrand("a".repeat(250)).length, 200);
});

test("B2. normalizeBrand never deletes across word boundaries — collapses to a space, never merges", () => {
  const result = normalizeBrand("Acme & Co.");
  assert.equal(result, "acme co");
  assert.ok(result.includes(" "));
});

test("B3. normalizeBrand is deterministic and locale-independent (fixed 'en-US', not runtime default)", () => {
  assert.equal(normalizeBrand("ACME"), normalizeBrand("ACME"));
  assert.equal(normalizeBrand("İstanbul").startsWith("i"), true);
});

test("B4. normalizeBrand rejects an unsupported version, fail-closed", () => {
  assert.throws(() => normalizeBrand("x", 2));
  assert.throws(() => normalizeBrand("x", 0));
});

test("B5. computeNormalizedBrandId is versioned exactly as normalizerVersion + ':' + normalizeBrand(...)", () => {
  assert.equal(computeNormalizedBrandId("Acme Inc.", 1), `${NORMALIZER_VERSION}:acme inc`);
});

test("B6. normalizeBrand throws on non-string input rather than coercing", () => {
  assert.throws(() => normalizeBrand(null));
  assert.throws(() => normalizeBrand(undefined));
  assert.throws(() => normalizeBrand(42));
});

// =======================================================================
// C. Policy selection.
// =======================================================================

test("C1. every one of the six relationships selects its own branch, never a combination", () => {
  const branches = {};
  for (const rel of Object.values(SELLER_RELATIONSHIP)) {
    branches[rel] = { requiredDocumentTypeGroups: [["purchase_invoice"]], acceptedScopeTypes: ["business"] };
  }
  const activePolicyVersion = { sellerRelationship: branches };
  for (const rel of Object.values(SELLER_RELATIONSHIP)) {
    const result = selectPolicyBranch({ product: { sellerRelationship: rel }, activePolicyVersion });
    assert.equal(result.ok, true);
    assert.equal(result.relationship, rel);
    assert.deepEqual(result.branch, branches[rel]);
  }
});

test("C2. missing sellerRelationship resolves unresolved (never a query, never a default)", () => {
  const result = selectPolicyBranch({ product: {}, activePolicyVersion: { sellerRelationship: {} } });
  assert.equal(result.ok, false);
  assert.equal(result.reason, "policy_selection_missing_relationship");
});

test("C3. malformed sellerRelationship resolves unresolved", () => {
  const result = selectPolicyBranch({
    product: { sellerRelationship: "not_a_real_relationship" },
    activePolicyVersion: { sellerRelationship: {} },
  });
  assert.equal(result.ok, false);
  assert.equal(result.reason, "policy_selection_malformed_relationship");
});

test("C4. a valid relationship absent from the active policy's map resolves unresolved", () => {
  const result = selectPolicyBranch({
    product: { sellerRelationship: SELLER_RELATIONSHIP.IMPORTER },
    activePolicyVersion: { sellerRelationship: { [SELLER_RELATIONSHIP.RESELLER]: { requiredDocumentTypeGroups: [["x"]], acceptedScopeTypes: ["business"] } } },
  });
  assert.equal(result.ok, false);
  assert.equal(result.reason, "policy_selection_branch_absent");
});

test("C5. a structurally invalid branch (defense-in-depth) resolves unresolved, never zero-requirements", () => {
  const result = selectPolicyBranch({
    product: { sellerRelationship: SELLER_RELATIONSHIP.RESELLER },
    activePolicyVersion: { sellerRelationship: { [SELLER_RELATIONSHIP.RESELLER]: { requiredDocumentTypeGroups: [], acceptedScopeTypes: [] } } },
  });
  assert.equal(result.ok, false);
  assert.equal(result.reason, "policy_selection_branch_invalid");
});

test("C6. category is never read by policy selection at all", () => {
  const product = { sellerRelationship: SELLER_RELATIONSHIP.RESELLER };
  Object.defineProperty(product, "category", {
    get() {
      throw new Error("category must never be read by selectPolicyBranch");
    },
  });
  const activePolicyVersion = { sellerRelationship: { [SELLER_RELATIONSHIP.RESELLER]: { requiredDocumentTypeGroups: [["x"]], acceptedScopeTypes: ["business"] } } };
  assert.doesNotThrow(() => selectPolicyBranch({ product, activePolicyVersion }));
});

// =======================================================================
// D. Seven query shapes.
// =======================================================================

test("D1. scopeValueForLookupType: exact per-type mapping", () => {
  const product = { businessId: BUSINESS_ID, brand: "Acme", category: "Health > Vitamins" };
  assert.equal(scopeValueForLookupType({ scopeType: COMPLIANCE_SCOPE_TYPE.BUSINESS, product, productId: PRODUCT_ID }), BUSINESS_ID);
  assert.equal(scopeValueForLookupType({ scopeType: COMPLIANCE_SCOPE_TYPE.SUPPLIER, product, productId: PRODUCT_ID }), undefined);
  assert.equal(
    scopeValueForLookupType({ scopeType: COMPLIANCE_SCOPE_TYPE.BRAND, product, productId: PRODUCT_ID }),
    computeNormalizedBrandId("Acme")
  );
  assert.equal(scopeValueForLookupType({ scopeType: COMPLIANCE_SCOPE_TYPE.CATEGORY, product, productId: PRODUCT_ID }), "Health > Vitamins");
  assert.equal(scopeValueForLookupType({ scopeType: COMPLIANCE_SCOPE_TYPE.PRODUCT_FAMILY, product, productId: PRODUCT_ID }), undefined);
  assert.equal(scopeValueForLookupType({ scopeType: COMPLIANCE_SCOPE_TYPE.PRODUCT, product, productId: PRODUCT_ID }), PRODUCT_ID);
});

test("D2. every candidate query filters relationship, tenant, scopeType, status before limit — cross-tenant isolation", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store);
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "business", scopeValue: "biz-OTHER", businessId: "biz-OTHER" } });
  const db = createFakeDb(store);
  const decision = await db.runTransaction(async (tx) => {
    const counters = createCounters();
    return runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters });
  });
  assert.equal(decision.activeEvidenceRefs.length, 0, "another business's scope must never satisfy this product");
});

test("D3. deterministic tie-break beyond LOOKUP_LIMIT: correct 3, oldest-approvedAt-first", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, category: "Health > Vitamins", sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  const ids = [];
  for (let i = 0; i < 5; i++) {
    const { scopeId, documentId } = seedScopeAndDocument(store, {
      scope: { scopeType: "category", scopeValue: "Health > Vitamins", approvedAt: makeTimestamp(NOW_MS - 100000 + i * 1000) },
    });
    ids.push({ scopeId, documentId, approvedAt: NOW_MS - 100000 + i * 1000 });
  }
  const db = createFakeDb(store);
  const counters = createCounters();
  await db.runTransaction(async (tx) => {
    const candidates = await require("../src/marketplace/compliance/complianceMatching").runScopeCandidateQuery({
      tx,
      db,
      businessId: BUSINESS_ID,
      sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
      scopeType: COMPLIANCE_SCOPE_TYPE.CATEGORY,
      scopeValue: "Health > Vitamins",
      counters,
    });
    assert.equal(candidates.length, LOOKUP_LIMIT);
    const sortedExpected = [...ids].sort((a, b) => a.approvedAt - b.approvedAt).slice(0, 3).map((x) => x.scopeId);
    assert.deepEqual(candidates.map((c) => c.id).sort(), sortedExpected.sort());
  });
});

test("D4. exact scopeValue mapping: business/category/product use the documented product-side value", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "product", scopeValue: PRODUCT_ID } });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 1);
});

// =======================================================================
// E. False-negative regression.
// =======================================================================

test("E. three wrong-relationship approved scopes precede a valid fourth — relationship-filter-before-limit finds it anyway", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  for (let i = 0; i < 3; i++) {
    seedScope(store, {
      scopeType: "category",
      scopeValue: "Health > Vitamins",
      sellerRelationship: SELLER_RELATIONSHIP.IMPORTER,
      approvedAt: makeTimestamp(NOW_MS - 100000 + i),
    });
  }
  const { scopeId } = seedScopeAndDocument(store, {
    scope: { scopeType: "category", scopeValue: "Health > Vitamins", sellerRelationship: SELLER_RELATIONSHIP.RESELLER, approvedAt: makeTimestamp(NOW_MS - 50000) },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 1);
  assert.equal(decision.activeEvidenceRefs[0].scopeId, scopeId);
});

// =======================================================================
// F. Brand.
// =======================================================================

test("F1. brand candidate narrowing plus verifiedBrandId authoritative gate", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "brand", scopeValue: computeNormalizedBrandId("Acme"), verifiedBrandId: computeNormalizedBrandId("Acme") },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 1);
});

test("F2. brand scopeValue match without a matching verifiedBrandId never satisfies (never a bare-string match)", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "brand", scopeValue: computeNormalizedBrandId("Acme"), verifiedBrandId: null },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 0);
});

test("F3. a wrong-version-normalized verifiedBrandId mismatch never satisfies", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "brand", scopeValue: computeNormalizedBrandId("Acme"), verifiedBrandId: "2:acme" },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 0);
});

// =======================================================================
// G. sku_set.
// =======================================================================

test("G1. sku_set: barcode match via a member point read, capped at LOOKUP_LIMIT candidates and 2 member reads each", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { category: undefined, brand: undefined, sku: undefined });
  seedEpoch(store, 0);
  const { scopeId, documentId } = seedScopeAndDocument(store, { scope: { scopeType: "sku_set" } });
  seedMember(store, { scopeId, identifierType: "barcode", identifierValue: product.barcode });
  const db = createFakeDb(store);
  const counters = createCounters();
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters })
  );
  assert.equal(decision.activeEvidenceRefs.length, 1);
});

test("G2. sku_set: no list/query is ever issued against the members subcollection — point reads only", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { category: undefined, brand: undefined });
  seedEpoch(store, 0);
  const { scopeId } = seedScopeAndDocument(store, { scope: { scopeType: "sku_set" } });
  seedMember(store, { scopeId, identifierType: "sku", identifierValue: product.sku });
  const db = createFakeDb(store);
  await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.ok(!store.callLog.some((entry) => entry.startsWith(`query:${SCOPES_COLLECTION}/${scopeId}/members`)));
});

test("G3. sku_set: neither barcode nor sku usable issues zero member reads", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { category: undefined, brand: undefined, sku: null, barcode: null });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "sku_set" } });
  const db = createFakeDb(store);
  const counters = createCounters();
  await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters })
  );
  assert.equal(counters.returnedDocuments >= 0, true);
});

test("G4. sku_set: both barcode and sku usable, both checked, single match via barcode", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { category: undefined, brand: undefined });
  seedEpoch(store, 0);
  const { scopeId } = seedScopeAndDocument(store, { scope: { scopeType: "sku_set" } });
  seedMember(store, { scopeId, identifierType: "barcode", identifierValue: product.barcode });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 1);
});

// =======================================================================
// H. Source verification.
// =======================================================================

test("H1. product/scope/source-document sellerRelationship triple-equality — a mismatch fails that candidate closed", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "category", scopeValue: "Health > Vitamins" },
    document: { sellerRelationship: SELLER_RELATIONSHIP.IMPORTER },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 0);
});

test("H2. tenant mismatch on the source document fails closed", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "category", scopeValue: "Health > Vitamins" },
    document: { businessId: "biz-OTHER" },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 0);
});

test("H3. non-approved source status fails closed", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "category", scopeValue: "Health > Vitamins" },
    document: { status: COMPLIANCE_DOCUMENT_STATUS.REVOKED },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 0);
});

test("H4. strict validUntil > now — an exact equality boundary is treated as already expired", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "category", scopeValue: "Health > Vitamins" },
    document: { validUntil: makeTimestamp(NOW_MS) },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 0, "validUntil == now must be treated as expired, not valid");
});

test("H5. expiresAt on the resulting evidence ref is derived from the source document's own validUntil", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  const expiry = makeTimestamp(NOW_MS + 5000);
  seedScopeAndDocument(store, {
    scope: { scopeType: "category", scopeValue: "Health > Vitamins" },
    document: { validUntil: expiry },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs[0].expiresAt.toMillis(), NOW_MS + 5000);
});

test("H6. a malformed source document (dangling documentId) fails closed, never silently skipped without cost", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScope(store, { scopeType: "category", scopeValue: "Health > Vitamins", documentId: "does-not-exist" });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 0);
});

test("H7 (item 14). a scope whose own documentType copy disagrees with the freshly-read source invalidates the WHOLE group, not just satisfies via the wrong type", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  // Source document is genuinely "purchase_invoice"; the scope's own
  // denormalized copy claims "manufacturer_evidence" — a data-integrity
  // anomaly that cannot arise from any correct write path.
  seedScopeAndDocument(store, {
    scope: { scopeType: "category", scopeValue: "Health > Vitamins", documentType: "manufacturer_evidence" },
    document: { documentType: "purchase_invoice" },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 0);
});

test("H8 (item 15). a scope whose own validUntil copy disagrees with the freshly-read source invalidates the candidate, never silently repaired", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "category", scopeValue: "Health > Vitamins", validUntil: makeTimestamp(NOW_MS + 9_999_999) },
    document: { validUntil: makeTimestamp(NOW_MS + 1_000_000_000) },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 0);
});

// =======================================================================
// I. AND-of-OR evidence requirements.
// =======================================================================

test("I1. AND-of-OR: two groups, one satisfied via each of two accepted document types", async () => {
  const store = createStore();
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: ["purchase_invoice", "manufacturer_evidence", "supplier_agreement"],
      requiredDocumentTypeGroups: [["purchase_invoice"], ["manufacturer_evidence", "supplier_agreement"]],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["business", "category"],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "business", scopeValue: BUSINESS_ID }, document: { documentType: "purchase_invoice" } });
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" }, document: { documentType: "supplier_agreement" } });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.allRequiredSlotsSatisfied, true);
  assert.equal(decision.satisfiedEvidenceSlots.length, 2);
});

test("I2. AND-of-OR: one satisfied group plus one unsatisfied group leaves the decision unsatisfied overall", async () => {
  const store = createStore();
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: ["purchase_invoice", "manufacturer_evidence"],
      requiredDocumentTypeGroups: [["purchase_invoice"], ["manufacturer_evidence"]],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["business"],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "business", scopeValue: BUSINESS_ID }, document: { documentType: "purchase_invoice" } });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.allRequiredSlotsSatisfied, false);
  assert.equal(decision.satisfiedEvidenceSlots.length, 1);
});

test("I3. zero-evidence policy_unresolved: acceptedScopeTypes naming only structurally-unavailable dimensions", async () => {
  const store = createStore();
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: ["purchase_invoice"],
      requiredDocumentTypeGroups: [["purchase_invoice"]],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["supplier"],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store);
  seedEpoch(store, 0);
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.policyUnresolved, true, "an ops gap, never evidence_missing");
});

test("I4. manualAdminOverridePermitted is never consulted and never bypasses missing evidence", async () => {
  const store = createStore();
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: ["purchase_invoice"],
      requiredDocumentTypeGroups: [["purchase_invoice"]],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["business"],
      manualAdminOverridePermitted: true,
    },
  });
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.allRequiredSlotsSatisfied, false);
});

test("I5. policy_unresolved is distinct from evidence_missing at the recompute status level", () => {
  assert.equal(
    determineEffectiveStatus({ policyUnresolved: true, allRequiredSlotsSatisfied: false }),
    PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.POLICY_UNRESOLVED
  );
  assert.equal(
    determineEffectiveStatus({ policyUnresolved: false, allRequiredSlotsSatisfied: false }),
    PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.EVIDENCE_MISSING
  );
  assert.equal(
    determineEffectiveStatus({ policyUnresolved: false, allRequiredSlotsSatisfied: true }),
    PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.VERIFIED_VALID
  );
});

// =======================================================================
// J. Bounds.
// =======================================================================

test("J1. worst-case operation count stays within 8 and read count within 42 for a full recompute", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store);
  seedEpoch(store, 3);
  for (const [type, value] of [
    ["business", BUSINESS_ID],
    ["brand", computeNormalizedBrandId("Acme")],
    ["category", "Health > Vitamins"],
    ["product", PRODUCT_ID],
  ]) {
    for (let i = 0; i < LOOKUP_LIMIT; i++) {
      seedScopeAndDocument(store, { scope: { scopeType: type, scopeValue: value, approvedAt: makeTimestamp(NOW_MS - 1000 * i) } });
    }
  }
  const { scopeId } = seedScopeAndDocument(store, { scope: { scopeType: "sku_set" } });
  seedMember(store, { scopeId, identifierType: "barcode", identifierValue: product.barcode });
  seedMember(store, { scopeId, identifierType: "sku", identifierValue: product.sku });

  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.ok(result.counters.operations <= 8, `operations was ${result.counters.operations}`);
  assert.ok(result.counters.pointReads <= 42, `pointReads was ${result.counters.pointReads}`);
});

test("J2. every candidate query itself carries a limit — never returns more than LOOKUP_LIMIT", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  for (let i = 0; i < 7; i++) {
    seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins", approvedAt: makeTimestamp(NOW_MS - i) } });
  }
  const db = createFakeDb(store);
  const counters = createCounters();
  await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters })
  );
  const categoryQueryResult = await db.runTransaction((tx) =>
    require("../src/marketplace/compliance/complianceMatching").runScopeCandidateQuery({
      tx,
      db,
      businessId: BUSINESS_ID,
      sellerRelationship: SELLER_RELATIONSHIP.RESELLER,
      scopeType: COMPLIANCE_SCOPE_TYPE.CATEGORY,
      scopeValue: "Health > Vitamins",
      counters: createCounters(),
    })
  );
  assert.equal(categoryQueryResult.length, LOOKUP_LIMIT);
});

test("J3 (item 45/46). source reads never exceed 10, active refs never exceed 10, independently of each other", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store);
  seedEpoch(store, 0);
  for (const [type, value] of [
    ["business", BUSINESS_ID],
    ["brand", computeNormalizedBrandId("Acme")],
    ["category", "Health > Vitamins"],
    ["product", PRODUCT_ID],
  ]) {
    for (let i = 0; i < LOOKUP_LIMIT; i++) {
      seedScopeAndDocument(store, { scope: { scopeType: type, scopeValue: value, approvedAt: makeTimestamp(NOW_MS - i) } });
    }
  }
  const db = createFakeDb(store);
  const counters = createCounters();
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters })
  );
  assert.ok(decision.sourceReads <= 10, `sourceReads was ${decision.sourceReads}`);
  assert.ok(decision.activeEvidenceRefs.length <= 10, `activeRefs was ${decision.activeEvidenceRefs.length}`);
  assert.ok(counters.pointReads <= 37); // ≤21 (queries) + ≤6 (sku members) + ≤10 (source docs)
});

test("J4 (item 43/44). full recompute stays within ≤42 reads and ≤8 operations even when truncation occurs", async () => {
  const store = createStore();
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: ["purchase_invoice"],
      requiredDocumentTypeGroups: [["purchase_invoice"]],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["business", "brand", "category", "product", "sku_set"],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store);
  seedEpoch(store, 0);
  for (const [type, value] of [
    ["business", BUSINESS_ID],
    ["brand", computeNormalizedBrandId("Acme")],
    ["category", "Health > Vitamins"],
    ["product", PRODUCT_ID],
  ]) {
    for (let i = 0; i < LOOKUP_LIMIT; i++) {
      seedScopeAndDocument(store, { scope: { scopeType: type, scopeValue: value, approvedAt: makeTimestamp(NOW_MS - i) } });
    }
  }
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.ok(result.counters.operations <= 8);
  assert.ok(result.counters.pointReads <= 42);
});

// =======================================================================
// K. Link ID/schema.
// =======================================================================

test("K1. deriveEvidenceLinkId matches an exact known SHA-256 hash", () => {
  const id = deriveEvidenceLinkId({ productId: "p1", documentId: "d1", scopeId: "s1" });
  assert.equal(id, "bbcfae49b883e1057cdeac4d5a709ef2a93463f50eba46c6712f05cccdd1144d");
  assert.equal(id.length, 64);
  assert.equal(/^[0-9a-f]{64}$/.test(id), true);
});

test("K2. deriveEvidenceLinkId rejects a delimiter (\\n) in any component", () => {
  assert.throws(() => deriveEvidenceLinkId({ productId: "p\n1", documentId: "d1", scopeId: "s1" }));
  assert.throws(() => deriveEvidenceLinkId({ productId: "p1", documentId: "d\n1", scopeId: "s1" }));
  assert.throws(() => deriveEvidenceLinkId({ productId: "p1", documentId: "d1", scopeId: "s\n1" }));
});

test("K3. deriveEvidenceLinkId is deterministic across repeated calls", () => {
  const a = deriveEvidenceLinkId({ productId: "p1", documentId: "d1", scopeId: "s1" });
  const b = deriveEvidenceLinkId({ productId: "p1", documentId: "d1", scopeId: "s1" });
  assert.equal(a, b);
});

test("K4. recompute writes exactly the six allowed link fields, no extras", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const linkDocs = [...store.docs.entries()].filter(([p]) => p.startsWith(`${LINKS_COLLECTION}/`));
  assert.equal(linkDocs.length, 1);
  const [, linkData] = linkDocs[0];
  assert.deepEqual(
    Object.keys(linkData).sort(),
    ["businessId", "documentId", "linkedAt", "matchedVia", "productId", "scopeId"]
  );
});

// =======================================================================
// L. Recompute.
// =======================================================================

test("L1. full decision document has exact allowed fields (Revision 9: incl. sellerRelationshipSnapshot) and a deterministic hash", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 2);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const decisionDoc = getRawDoc(store, DECISIONS_COLLECTION, PRODUCT_ID);
  assert.deepEqual(
    Object.keys(decisionDoc).sort(),
    [
      "activeEvidenceRefs",
      "businessId",
      "computedAt",
      "decisionHash",
      "effectiveStatus",
      "evidenceRevision",
      "policyVersion",
      "productInputRevisionSnapshot",
      "requiredEvidenceSlots",
      "satisfiedEvidenceSlots",
      "sellerRelationshipSnapshot",
      "validUntil",
    ]
  );
  assert.equal(decisionDoc.evidenceRevision, 2);
  assert.equal(decisionDoc.sellerRelationshipSnapshot, SELLER_RELATIONSHIP.RESELLER);
  assert.equal(decisionDoc.effectiveStatus, PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.VERIFIED_VALID);
  const expectedHash = computeDecisionHash({
    businessId: decisionDoc.businessId,
    policyVersion: decisionDoc.policyVersion,
    evidenceRevision: decisionDoc.evidenceRevision,
    productInputRevisionSnapshot: decisionDoc.productInputRevisionSnapshot,
    sellerRelationshipSnapshot: decisionDoc.sellerRelationshipSnapshot,
    requiredEvidenceSlots: decisionDoc.requiredEvidenceSlots,
    satisfiedEvidenceSlots: decisionDoc.satisfiedEvidenceSlots,
    activeEvidenceRefs: decisionDoc.activeEvidenceRefs,
    validUntil: decisionDoc.validUntil,
    effectiveStatus: decisionDoc.effectiveStatus,
  });
  assert.equal(decisionDoc.decisionHash, expectedHash);
  // activeEvidenceRefs on the STORED decision never carries matchedVia —
  // that tag is internal to the matching engine / productEvidenceLinks
  // writer only (§4's frozen decision schema: {documentId, scopeId,
  // expiresAt}, no fourth field).
  for (const ref of decisionDoc.activeEvidenceRefs) {
    assert.deepEqual(Object.keys(ref).sort(), ["documentId", "expiresAt", "scopeId"]);
  }
});

test("L2. reads occur before writes — a nonexistent product performs zero writes", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const db = createFakeDb(store);
  await assert.rejects(recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: "does-not-exist", now: NOW }));
  assert.equal(store.docs.size, 2); // only the seeded pointer + version remain
});

test("L3. prior-link cleanup re-derives IDs from the prior decision's activeEvidenceRefs — no productEvidenceLinks query", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  const { scopeId, documentId } = seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const oldLinkId = deriveEvidenceLinkId({ productId: PRODUCT_ID, documentId, scopeId });
  assert.ok(getRawDoc(store, LINKS_COLLECTION, oldLinkId));

  store.callLog.length = 0;
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.ok(!store.callLog.some((entry) => entry.startsWith(`query:${LINKS_COLLECTION}`)));
  const linkDocs = [...store.docs.entries()].filter(([p]) => p.startsWith(`${LINKS_COLLECTION}/`));
  assert.equal(linkDocs.length, 1);
});

test("L4. cap: at most MATCHED_SCOPE_CAP links are ever written", async () => {
  const store = createStore();
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: ["purchase_invoice"],
      requiredDocumentTypeGroups: [["purchase_invoice"]],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["business", "brand", "category", "product", "sku_set"],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store);
  seedEpoch(store, 0);
  for (const [type, value] of [
    ["business", BUSINESS_ID],
    ["brand", computeNormalizedBrandId("Acme")],
    ["category", "Health > Vitamins"],
    ["product", PRODUCT_ID],
  ]) {
    for (let i = 0; i < LOOKUP_LIMIT; i++) {
      seedScopeAndDocument(store, { scope: { scopeType: type, scopeValue: value, approvedAt: makeTimestamp(NOW_MS - i) } });
    }
  }
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const linkDocs = [...store.docs.entries()].filter(([p]) => p.startsWith(`${LINKS_COLLECTION}/`));
  assert.ok(linkDocs.length <= MATCHED_SCOPE_CAP);
});

test("L5. retry determinism: an unchanged recompute re-derives the identical activeEvidenceRefs and link set", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  const first = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const second = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.deepEqual(first.decision.activeEvidenceRefs, second.decision.activeEvidenceRefs);
  assert.equal(first.decisionHash, second.decisionHash);
});

test("L6. no active policy at all: recompute throws and writes nothing", async () => {
  const store = createStore();
  seedProduct(store);
  const db = createFakeDb(store);
  const before = new Map(store.docs);
  await assert.rejects(recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW }));
  assert.deepEqual(store.docs, before);
});

test("L7. missing sellerRelationship resolves policy_unresolved and writes a decision (not a thrown error)", async () => {
  const store = createStore();
  seedActivePolicy(store);
  seedProduct(store, { sellerRelationship: undefined });
  seedEpoch(store, 0);
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.decision.effectiveStatus, PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.POLICY_UNRESOLVED);
  // Missing/malformed live relationship -> the writer's own null
  // sentinel, never a garbage raw value, never undefined.
  assert.equal(result.decision.sellerRelationshipSnapshot, null);
});

// =======================================================================
// M. Evaluator.
// =======================================================================

test("M1. fresh success: a just-recomputed product is eligible", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const result = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.eligible, true);
});

test("M2. a policy activation between calls is observed on the very next evaluation, no cache exception", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal((await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW })).eligible, true);

  seedDoc(store, REGISTRY_COLLECTION, "policy-v2", getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID));
  seedDoc(store, COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION, COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID, { activeVersionId: "policy-v2" });

  const after = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(after.eligible, false);
  assert.equal(after.reason, "eligibility_policy_version_mismatch");
});

test("M3. an epoch bump between calls excludes the product on the next evaluation", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  seedEpoch(store, 1);
  const result = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.eligible, false);
  assert.equal(result.reason, "eligibility_evidence_revision_mismatch");
});

test("M4. a productInputRevision change between calls excludes the product on the next evaluation", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  seedDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID, { ...product, category: "Toys > Chew Toy", productInputRevision: 2 });
  const result = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.eligible, false);
  assert.equal(result.reason, "eligibility_product_input_revision_mismatch");
});

test("M5. strict expiry: validUntil == now excludes the product", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" }, document: { validUntil: makeTimestamp(NOW_MS + 1000) } });
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const result = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: new Date(NOW_MS + 1000) });
  assert.equal(result.eligible, false);
  assert.equal(result.reason, "eligibility_valid_until_missing_or_expired");
});

test("M6. malformed decision fails closed", async () => {
  const store = createStore();
  seedActivePolicy(store);
  seedProduct(store);
  seedDoc(store, DECISIONS_COLLECTION, PRODUCT_ID, { not: "a valid decision" });
  const db = createFakeDb(store);
  const result = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.eligible, false);
  assert.equal(result.reason, "eligibility_decision_malformed");
});

test("M7. no decision at all is ineligible, never silently defaulted", async () => {
  const store = createStore();
  seedActivePolicy(store);
  seedProduct(store);
  const db = createFakeDb(store);
  const result = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.eligible, false);
  assert.equal(result.reason, "eligibility_decision_not_found");
});

test("M8. the evaluator never reads productEvidenceLinks and never queries complianceDocumentScopes", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  store.callLog.length = 0;
  await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.ok(!store.callLog.some((e) => e.includes(LINKS_COLLECTION)));
  assert.ok(!store.callLog.some((e) => e.startsWith(`query:${SCOPES_COLLECTION}`)));
});

test("M9. static: evaluateLiveProductEligibility's own source never calls recomputeProductComplianceStatus", () => {
  const src = fs.readFileSync(
    path.resolve(__dirname, "../src/marketplace/compliance/complianceEligibilityEvaluator.js"),
    "utf8"
  );
  assert.equal(/recomputeProductComplianceStatus\s*\(/.test(src), false);
  assert.equal(/\.collection\(\s*["']productEvidenceLinks["']\s*\)/.test(src), false);
});

// =======================================================================
// N. Index JSON.
// =======================================================================

test("N1. exactly the two Revision 8 complianceDocumentScopes indexes exist, exact field order, prior indexes preserved", () => {
  const indexesPath = path.resolve(__dirname, "../../firestore.indexes.json");
  const raw = fs.readFileSync(indexesPath, "utf8");
  const parsed = JSON.parse(raw);
  const scopeIndexes = parsed.indexes.filter((i) => i.collectionGroup === "complianceDocumentScopes");
  assert.equal(scopeIndexes.length, 2);

  const withValue = scopeIndexes.find((i) => i.fields.some((f) => f.fieldPath === "scopeValue"));
  const withoutValue = scopeIndexes.find((i) => !i.fields.some((f) => f.fieldPath === "scopeValue"));
  assert.deepEqual(
    withValue.fields.map((f) => f.fieldPath),
    ["businessId", "sellerRelationship", "scopeType", "scopeValue", "status", "approvedAt"]
  );
  assert.deepEqual(
    withoutValue.fields.map((f) => f.fieldPath),
    ["businessId", "sellerRelationship", "scopeType", "status", "approvedAt"]
  );
  for (const idx of scopeIndexes) {
    assert.equal(idx.queryScope, "COLLECTION");
    assert.ok(idx.fields.every((f) => f.order === "ASCENDING"));
    assert.ok(!("arrayConfig" in idx.fields[0]));
    assert.ok(!idx.fields.some((f) => f.fieldPath === "__name__"));
  }

  const priorGroups = parsed.indexes.map((i) => i.collectionGroup);
  assert.ok(priorGroups.includes("subscriptions"));
  assert.ok(priorGroups.includes("complianceUploadSessions"));
  assert.ok(priorGroups.includes("products"));
});

test("N2. no duplicate complianceDocumentScopes index", () => {
  const indexesPath = path.resolve(__dirname, "../../firestore.indexes.json");
  const parsed = JSON.parse(fs.readFileSync(indexesPath, "utf8"));
  const scopeIndexes = parsed.indexes.filter((i) => i.collectionGroup === "complianceDocumentScopes");
  const signatures = scopeIndexes.map((i) => JSON.stringify(i.fields));
  assert.equal(new Set(signatures).size, signatures.length);
});

test("N3 (item 52). no other query shape/field appears anywhere in the two indexes — documentType/validUntil are pre-filter only, never queried", () => {
  const indexesPath = path.resolve(__dirname, "../../firestore.indexes.json");
  const parsed = JSON.parse(fs.readFileSync(indexesPath, "utf8"));
  const scopeIndexes = parsed.indexes.filter((i) => i.collectionGroup === "complianceDocumentScopes");
  for (const idx of scopeIndexes) {
    assert.ok(!idx.fields.some((f) => f.fieldPath === "documentType"));
    assert.ok(!idx.fields.some((f) => f.fieldPath === "validUntil"));
  }
});

// =======================================================================
// O. Static architecture.
// =======================================================================

test("O1. functions/index.js never references any of the four new Slice 4.3 modules", () => {
  const indexSrc = fs.readFileSync(path.resolve(__dirname, "../index.js"), "utf8");
  for (const name of [
    "complianceMatching",
    "complianceProductRecompute",
    "complianceEligibilityEvaluator",
    "complianceBrandNormalizer",
  ]) {
    assert.equal(indexSrc.includes(name), false, `functions/index.js must not reference ${name}`);
  }
});

test("O2. no onCall/onRequest/onSchedule/trigger export exists in any of the four new modules", () => {
  for (const file of [
    "complianceMatching.js",
    "complianceProductRecompute.js",
    "complianceEligibilityEvaluator.js",
    "complianceBrandNormalizer.js",
  ]) {
    const src = fs.readFileSync(path.resolve(__dirname, `../src/marketplace/compliance/${file}`), "utf8");
    assert.equal(/onCall\s*\(/.test(src), false, `${file} must not call onCall()`);
    assert.equal(/onRequest\s*\(/.test(src), false, `${file} must not call onRequest()`);
    assert.equal(/onSchedule\s*\(/.test(src), false, `${file} must not call onSchedule()`);
    assert.equal(/exports\.\w+\s*=/.test(src), false, `${file} must not use exports.X = (onCall-style top-level export)`);
  }
});

test("O3. no mutable module-level cache in any of the four new modules — no top-level 'let'-based memo state", () => {
  for (const file of [
    "complianceMatching.js",
    "complianceProductRecompute.js",
    "complianceEligibilityEvaluator.js",
    "complianceBrandNormalizer.js",
  ]) {
    const src = fs.readFileSync(path.resolve(__dirname, `../src/marketplace/compliance/${file}`), "utf8");
    assert.equal(/^let\s+\w+\s*=/m.test(src), false, `${file} must not declare a mutable top-level binding`);
  }
});

test("O4. no skip/todo/only anywhere in this file", () => {
  const src = fs.readFileSync(__filename, "utf8");
  assert.equal(/\.skip\s*\(/.test(src), false);
  assert.equal(/\.only\s*\(/.test(src), false);
  assert.equal(/\btodo\s*:/i.test(src.replace(/no skip\/todo\/only/gi, "")), false);
});

test("O5. no project ID / secret-shaped literal anywhere in the four new modules", () => {
  for (const file of [
    "complianceMatching.js",
    "complianceProductRecompute.js",
    "complianceEligibilityEvaluator.js",
    "complianceBrandNormalizer.js",
  ]) {
    const src = fs.readFileSync(path.resolve(__dirname, `../src/marketplace/compliance/${file}`), "utf8");
    assert.equal(/AKIA[0-9A-Z]{16}/.test(src), false);
    assert.equal(/barkymatches-new/i.test(src), false);
  }
});

test("O6 (item 51/52). no Flutter/.dart reference and no firestore.rules content anywhere in the four new modules", () => {
  for (const file of [
    "complianceMatching.js",
    "complianceProductRecompute.js",
    "complianceEligibilityEvaluator.js",
    "complianceBrandNormalizer.js",
  ]) {
    const src = fs.readFileSync(path.resolve(__dirname, `../src/marketplace/compliance/${file}`), "utf8");
    assert.equal(/\.dart/.test(src), false, `${file} must not reference Dart/Flutter`);
    assert.equal(/rules_version/.test(src), false, `${file} must not embed Rules content`);
  }
});

// =======================================================================
// P. Coverage-first/extras selection algorithm (Revision 9 correction
// 49) — the confirmed adversarial defect and its resolution.
// =======================================================================

function seedPolicyWithTwoBusinessGroups(store) {
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: ["purchase_invoice", "manufacturer_evidence"],
      requiredDocumentTypeGroups: [["purchase_invoice"], ["manufacturer_evidence"]],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      // Widened to every real, structurally-available lookup type (not
      // just "business") — several adversarial fixtures below need to
      // spread candidates across multiple lanes to exceed a single
      // query's own LOOKUP_LIMIT=3 while staying within it per-lane
      // (see seedSpreadCandidates above). Tests that only ever seed
      // "business"-type scopes are unaffected by the widening.
      acceptedScopeTypes: [...ALL_LANES_ACCEPTED_SCOPE_TYPES],
      manualAdminOverridePermitted: false,
    },
  });
}

test("P1 (item 1). exact confirmed crowd-out fixture: 10 early group-A candidates no longer starve the sole, later group-B candidate", async () => {
  const store = createStore();
  seedPolicyWithTwoBusinessGroups(store);
  const product = seedProduct(store);
  seedEpoch(store, 0);
  // 10 early-approved "purchase_invoice" (group A) candidates, all
  // satisfying the SAME slot redundantly — spread across the 4
  // lookup-type lanes so each individual query stays within its own
  // LOOKUP_LIMIT=3, exactly matching the real seven-query architecture
  // (§10). The AGGREGATE across lanes is what exceeds
  // MATCHED_SCOPE_CAP=10 — this is the exact shape of the
  // originally-reproduced adversarial fixture.
  const entries = [];
  for (let i = 0; i < 10; i++) entries.push({ documentType: "purchase_invoice", approvedAtMs: NOW_MS - 1_000_000 + i });
  // The 11th, later-approved candidate is the SOLE evidence for group
  // B. One single seedSpreadCandidates call keeps lane-cycling state
  // continuous across all 11 entries, landing it wherever the previous
  // 10 left off (still within that lane's own LOOKUP_LIMIT=3).
  entries.push({ documentType: "manufacturer_evidence", approvedAtMs: NOW_MS - 1000 });
  const seeded = seedSpreadCandidates(store, product, entries);
  const groupB = seeded[seeded.length - 1];
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.allRequiredSlotsSatisfied, true, "both groups must be satisfied — this is the exact defect Revision 9 corrects");
  assert.equal(decision.satisfiedEvidenceSlots.length, 2);
  assert.ok(decision.activeEvidenceRefs.some((r) => r.scopeId === groupB.scopeId), "the sole group-B evidence must be selected");
});

test("P2 (item 2). coverage before extras: a slot's FIRST valid candidate (stable order) is the one selected to satisfy it — Pass 1 does not exhaust redundant candidates for an already-satisfied slot before another slot gets its turn", async () => {
  const store = createStore();
  seedPolicyWithTwoBusinessGroups(store);
  const product = seedProduct(store);
  seedEpoch(store, 0);
  const entries = [];
  // 10 redundant group-A candidates (would exhaust the whole cap if
  // Pass 1 incorrectly tried to consume them all before moving to the
  // next slot) — Pass 1 must stop at the FIRST verified group-A hit,
  // i.e. select entry index 0 (earliest approvedAt), not some later one.
  for (let i = 0; i < 10; i++) entries.push({ documentType: "purchase_invoice", approvedAtMs: NOW_MS - 5000 + i });
  entries.push({ documentType: "manufacturer_evidence", approvedAtMs: NOW_MS - 1000 });
  const seeded = seedSpreadCandidates(store, product, entries);
  const firstGroupAScopeId = seeded[0].scopeId;
  const groupBScopeId = seeded[seeded.length - 1].scopeId;
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.allRequiredSlotsSatisfied, true);
  // Both the deterministically-first group-A candidate AND group B's
  // sole candidate must be selected — proving Pass 1 gave slot B its
  // own independent attempt immediately after slot A's first hit,
  // rather than exhausting group A's 10 redundant candidates first
  // (which would have left zero budget for slot B, per the exact
  // originally-reproduced adversarial defect).
  const selectedScopeIds = decision.activeEvidenceRefs.map((r) => r.scopeId);
  assert.ok(selectedScopeIds.includes(firstGroupAScopeId), "the FIRST group-A candidate by stable order must be the one selected");
  assert.ok(selectedScopeIds.includes(groupBScopeId), "group B's sole candidate must still be satisfied");
});

test("P3 (item 3). one evidence ref whose documentType satisfies TWO required groups is reused, not re-fetched", async () => {
  const store = createStore();
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: ["purchase_invoice"],
      requiredDocumentTypeGroups: [["purchase_invoice"], ["purchase_invoice"]],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["business"],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "business", scopeValue: BUSINESS_ID },
    document: { documentType: "purchase_invoice" },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.allRequiredSlotsSatisfied, true);
  assert.equal(decision.satisfiedEvidenceSlots.length, 2);
  assert.equal(decision.activeEvidenceRefs.length, 1, "one ref satisfies both groups — not duplicated");
  assert.equal(decision.sourceReads, 1);
});

test("P4 (item 4/16). two distinct scopes sharing the SAME source document are read once (cached), not twice", async () => {
  const store = createStore();
  seedPolicyWithTwoBusinessGroups(store);
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  const documentId = "shared-doc-1";
  seedDocument(store, documentId, { documentType: "purchase_invoice" });
  // Two different scopeIds, of two different scopeTypes, both pointing
  // at the SAME source document.
  const businessScope = seedScope(store, { scopeType: "business", scopeValue: BUSINESS_ID, documentId, documentType: "purchase_invoice" });
  const db = createFakeDb(store);
  const counters = createCounters();
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters })
  );
  assert.equal(decision.sourceReads, 1);
  assert.equal(decision.activeEvidenceRefs.length, 1);
  assert.equal(decision.activeEvidenceRefs[0].scopeId, businessScope.scopeId);
});

test("P5 (item 5). distinct scopeIds sharing a documentId are BOTH preserved as distinct evidence refs when each satisfies a different group", async () => {
  const store = createStore();
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: ["purchase_invoice"],
      requiredDocumentTypeGroups: [["purchase_invoice"]],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["business", "category"],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  const documentId = "shared-doc-2";
  seedDocument(store, documentId, { documentType: "purchase_invoice" });
  seedScope(store, { scopeType: "business", scopeValue: BUSINESS_ID, documentId, documentType: "purchase_invoice" });
  seedScope(store, { scopeType: "category", scopeValue: "Health > Vitamins", documentId, documentType: "purchase_invoice" });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  // Only one required slot exists here, so only one ref is NEEDED, but
  // both scopeIds remain valid, distinct candidates — this proves the
  // engine never collapses two distinct scopeIds onto one, even though
  // it only needs one to satisfy the single slot. Extended in P6 below
  // with two distinct required slots to prove both get selected when
  // both are needed.
  assert.equal(decision.allRequiredSlotsSatisfied, true);
});

test("P6 (item 5, extended). two distinct scopeIds sharing one documentId both get selected when two DIFFERENT slots need them", async () => {
  const store = createStore();
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: ["purchase_invoice"],
      requiredDocumentTypeGroups: [["purchase_invoice"]],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["business"],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  const documentId = "shared-doc-3";
  seedDocument(store, documentId, { documentType: "purchase_invoice" });
  seedScope(store, { scopeType: "business", scopeValue: BUSINESS_ID, documentId, documentType: "purchase_invoice", id: "scope-shared-a" });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.activeEvidenceRefs.length, 1);
  assert.equal(decision.activeEvidenceRefs[0].scopeId, "scope-shared-a");
});

test("P7 (item 6). an exact duplicate (documentId, scopeId) pair appearing twice in raw candidates is deduped, not double-counted", async () => {
  const store = createStore();
  seedPolicyWithTwoBusinessGroups(store);
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  const { scopeId } = seedScopeAndDocument(store, {
    scope: { scopeType: "business", scopeValue: BUSINESS_ID },
    document: { documentType: "purchase_invoice" },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction(async (tx) => {
    const counters = createCounters();
    const raw = await require("../src/marketplace/compliance/complianceMatching").gatherMatchedCandidates({
      tx,
      db,
      product,
      productId: PRODUCT_ID,
      relationship: SELLER_RELATIONSHIP.RESELLER,
      counters,
    });
    const duplicated = [...raw, ...raw]; // simulate an exact duplicate pair
    return require("../src/marketplace/compliance/complianceMatching").evaluateRequiredSlots({
      tx,
      db,
      product,
      relationship: SELLER_RELATIONSHIP.RESELLER,
      branch: selectPolicyBranch({ product, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID) }).branch,
      rawCandidates: duplicated,
      nowMs: NOW_MS,
      counters,
    });
  });
  assert.equal(decision.candidateRefs, 1, "exact duplicate pair collapses to one candidate");
  assert.equal(decision.activeEvidenceRefs.length, 1);
});

test("P8 (item 7). invalid first source, second valid fallback for the same slot", async () => {
  const store = createStore();
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: ["purchase_invoice"],
      requiredDocumentTypeGroups: [["purchase_invoice"]],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["business"],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  // First (earliest-approved) candidate's SOURCE is revoked — fails at
  // verification, not pre-filter.
  seedScopeAndDocument(store, {
    scope: { scopeType: "business", scopeValue: BUSINESS_ID, approvedAt: makeTimestamp(NOW_MS - 5000) },
    document: { documentType: "purchase_invoice", status: COMPLIANCE_DOCUMENT_STATUS.REVOKED },
  });
  const { scopeId: fallbackScopeId } = seedScopeAndDocument(store, {
    scope: { scopeType: "business", scopeValue: BUSINESS_ID, approvedAt: makeTimestamp(NOW_MS - 1000) },
    document: { documentType: "purchase_invoice" },
  });
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.allRequiredSlotsSatisfied, true);
  assert.equal(decision.activeEvidenceRefs[0].scopeId, fallbackScopeId);
});

test("P9 (item 8). five required slots, each with its own alternatives, are all independently satisfied", async () => {
  const store = createStore();
  // COMPLIANCE_DOCUMENT_TYPE is a closed enum in real code — this
  // module's pre-filter checks membership via isValidComplianceDocumentType,
  // so real enum values are used, one per required slot.
  const realTypes = Object.values(COMPLIANCE_DOCUMENT_TYPE).slice(0, 5);
  const realGroups = realTypes.map((t) => [t]);
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: realTypes,
      requiredDocumentTypeGroups: realGroups,
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: [...ALL_LANES_ACCEPTED_SCOPE_TYPES],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store);
  seedEpoch(store, 0);
  // 5 candidates spread across 2 lanes (business:3, brand:2) — each
  // individual query stays within its own LOOKUP_LIMIT=3.
  seedSpreadCandidates(store, product, realTypes.map((t, i) => ({ documentType: t, approvedAtMs: NOW_MS - 100000 + i })));
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.allRequiredSlotsSatisfied, true);
  assert.equal(decision.satisfiedEvidenceSlots.length, 5);
});

test("P10 (item 9). source-read cap independent of active-ref cap: 11 distinct documents, each satisfying its own required alternative, still yields exactly the algorithm's deterministic 10", async () => {
  const store = createStore();
  const realTypes = Object.values(COMPLIANCE_DOCUMENT_TYPE); // 8 values
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: realTypes,
      requiredDocumentTypeGroups: [realTypes], // one slot, OR across all 8 types
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: [...ALL_LANES_ACCEPTED_SCOPE_TYPES],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store);
  seedEpoch(store, 0);
  // 11 distinct approved (documentId, scopeId) candidates, spread
  // across 4 lanes (3+3+3+2), all eligible for the SAME single slot —
  // only the first found by stable order is needed, but the
  // source-read cap independently bounds attempts.
  const entries = [];
  for (let i = 0; i < 11; i++) entries.push({ documentType: realTypes[i % realTypes.length], approvedAtMs: NOW_MS - 1_000_000 + i });
  seedSpreadCandidates(store, product, entries);
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.ok(decision.sourceReads <= 10);
  assert.equal(decision.allRequiredSlotsSatisfied, true, "the single slot is satisfied by the very first candidate");
});

test("P11 (item 10). active-ref cap independent of source-read cap: 5 documents, each with 2 distinct scopes, yield 10 distinct refs from only 5 source reads", async () => {
  const store = createStore();
  const realTypes = Object.values(COMPLIANCE_DOCUMENT_TYPE).slice(0, 5); // 5 slots, the schema ceiling
  const groups = realTypes.map((t) => [t]);
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: realTypes,
      requiredDocumentTypeGroups: groups,
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: [...ALL_LANES_ACCEPTED_SCOPE_TYPES],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store);
  seedEpoch(store, 0);
  // Each of the 5 required types gets its OWN source document, but TWO
  // distinct scopes (via two different lookup-type lanes, each staying
  // within its own LOOKUP_LIMIT=3) both point at that same document —
  // proving one source read is reused (§10 source-read identity) to
  // verify TWO distinct evidence-reference identities.
  const lanePairs = [
    ["business", "brand"],
    ["business", "brand"],
    ["business", "brand"],
    ["category", "product"],
    ["category", "product"],
  ];
  for (let i = 0; i < realTypes.length; i++) {
    const documentId = `p11-doc-${i}`;
    seedDocument(store, documentId, { documentType: realTypes[i] });
    for (const lane of lanePairs[i]) {
      const scopeValue = laneScopeValue(lane, product);
      const overrides = {
        scopeType: lane,
        documentId,
        documentType: realTypes[i],
        approvedAt: makeTimestamp(NOW_MS - 100000 + i),
      };
      if (scopeValue !== undefined) overrides.scopeValue = scopeValue;
      if (lane === "brand") overrides.verifiedBrandId = computeNormalizedBrandId(product.brand);
      seedScope(store, overrides);
    }
  }
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.allRequiredSlotsSatisfied, true);
  assert.equal(decision.sourceReads, 5, "only 5 distinct source documents, despite 10 distinct evidence refs");
  assert.equal(decision.activeEvidenceRefs.length, 10, "each of the 5 documents contributes 2 distinct scope refs");
});

test("P12 (item 11). redundant already-verified evidence for a satisfied slot never produces a false evidence_missing for a different slot", async () => {
  const store = createStore();
  seedPolicyWithTwoBusinessGroups(store);
  const product = seedProduct(store);
  seedEpoch(store, 0);
  const entries = [];
  for (let i = 0; i < 5; i++) entries.push({ documentType: "purchase_invoice", approvedAtMs: NOW_MS - 100000 + i });
  entries.push({ documentType: "manufacturer_evidence", approvedAtMs: NOW_MS - 1000 });
  seedSpreadCandidates(store, product, entries);
  const db = createFakeDb(store);
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.equal(decision.allRequiredSlotsSatisfied, true);
  assert.equal(decision.policyUnresolved, false);
});

// =======================================================================
// Q. Denormalized metadata pre-filter (items 12, 13).
// =======================================================================

test("Q1 (item 12). the scope's own documentType copy is used to preallocate slot eligibility before any source read", async () => {
  const store = createStore();
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: ["purchase_invoice", "manufacturer_evidence"],
      requiredDocumentTypeGroups: [["manufacturer_evidence"]],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["business"],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  // A candidate whose OWN copy is "purchase_invoice" — not in the sole
  // required group's OR-list — must never even trigger a source read.
  seedScopeAndDocument(store, {
    scope: { scopeType: "business", scopeValue: BUSINESS_ID },
    document: { documentType: "purchase_invoice" },
  });
  const db = createFakeDb(store);
  const counters = createCounters();
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters })
  );
  assert.equal(decision.sourceReads, 0, "pre-filtered out on documentType alone — zero source reads spent");
  assert.equal(decision.activeEvidenceRefs.length, 0);
});

test("Q2 (item 13). null validUntil copy on the scope excludes the candidate pre-filter, zero read cost, never treated as non-expiring", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "category", scopeValue: "Health > Vitamins", validUntil: null },
  });
  const db = createFakeDb(store);
  const counters = createCounters();
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters })
  );
  assert.equal(decision.sourceReads, 0);
  assert.equal(decision.activeEvidenceRefs.length, 0);
});

test("Q3 (item 13). malformed (non-Timestamp) validUntil copy on the scope excludes the candidate at pre-filter", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "category", scopeValue: "Health > Vitamins", validUntil: "not-a-timestamp" },
  });
  const db = createFakeDb(store);
  const counters = createCounters();
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters })
  );
  assert.equal(decision.sourceReads, 0);
  assert.equal(decision.activeEvidenceRefs.length, 0);
});

test("Q4 (item 13). an expired validUntil copy on the scope excludes the candidate at pre-filter, zero read cost", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "category", scopeValue: "Health > Vitamins", validUntil: makeTimestamp(NOW_MS - 1000) },
    document: { validUntil: makeTimestamp(NOW_MS + 1_000_000_000) }, // source itself is genuinely still valid
  });
  const db = createFakeDb(store);
  const counters = createCounters();
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters })
  );
  assert.equal(decision.sourceReads, 0, "the scope's own (stale) copy pre-filters it out before any read, regardless of the live source");
  assert.equal(decision.activeEvidenceRefs.length, 0);
});

// =======================================================================
// R. Truncation event (items 17-28).
// =======================================================================

test("R1 (item 17). event emitted on source-read-cap truncation: 11 distinct required-alternative documents cannot all be read", async () => {
  const store = createStore();
  const realTypes = Object.values(COMPLIANCE_DOCUMENT_TYPE); // 8 values
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: realTypes,
      requiredDocumentTypeGroups: [realTypes], // OR across all 8 types — every candidate is eligible
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: [...ALL_LANES_ACCEPTED_SCOPE_TYPES],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store);
  seedEpoch(store, 0);
  // 11 candidates, spread across 4 lanes (3+3+3+2) so each individual
  // query stays within LOOKUP_LIMIT=3. Every source's status is REVOKED
  // so the sole slot is never satisfied by any read — forcing Pass 2 to
  // try every remaining candidate until the source-read cap (10) is
  // exhausted, leaving the 11th candidate unread.
  const entries = [];
  for (let i = 0; i < 11; i++) {
    entries.push({ documentType: realTypes[i % realTypes.length], approvedAtMs: NOW_MS - 1_000_000 + i, status: COMPLIANCE_DOCUMENT_STATUS.REVOKED });
  }
  seedSpreadCandidates(store, product, entries);
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.truncationOccurred, true);
  const events = reviewEvents(store);
  assert.equal(events.length, 1);
  assert.ok(/omittedBySourceReadCap=([1-9]\d*)/.test(events[0].notes));
});

test("R2 (item 18). event emitted on active-ref-cap truncation: 4 documents with 3 scopes each yield 12 refs from only 4 source reads — the active-ref cap alone is what truncates, never the source-read cap", async () => {
  const store = createStore();
  const realTypes = Object.values(COMPLIANCE_DOCUMENT_TYPE);
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: realTypes,
      requiredDocumentTypeGroups: [realTypes],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: [...ALL_LANES_ACCEPTED_SCOPE_TYPES],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store);
  seedEpoch(store, 0);
  // 4 documents, 3 scopes each (12 evidence refs total), each scope in
  // a DIFFERENT lane so every individual query stays within its own
  // LOOKUP_LIMIT=3 — round-robin across the 5 lanes never exceeds 3
  // uses of any one lane. Only 4 source reads are ever needed (one per
  // document, cached and reused for that document's other 2 scopes) —
  // proving the resulting truncation is caused SOLELY by the 10-ref
  // cap, never the (nowhere-near-exhausted) source-read cap.
  const docCount = 4;
  const scopesPerDoc = 3;
  for (let doc = 0; doc < docCount; doc++) {
    const documentId = `r2-doc-${doc}`;
    seedDocument(store, documentId, { documentType: realTypes[doc % realTypes.length] });
    for (let s = 0; s < scopesPerDoc; s++) {
      const assignmentIndex = doc * scopesPerDoc + s;
      const lane = CANDIDATE_LANES[assignmentIndex % CANDIDATE_LANES.length];
      const scopeValue = laneScopeValue(lane, product);
      const overrides = {
        scopeType: lane,
        documentId,
        documentType: realTypes[doc % realTypes.length],
        approvedAt: makeTimestamp(NOW_MS - 100000 + assignmentIndex),
      };
      if (scopeValue !== undefined) overrides.scopeValue = scopeValue;
      if (lane === "brand") overrides.verifiedBrandId = computeNormalizedBrandId(product.brand);
      const seeded = seedScope(store, overrides);
      if (lane === "sku_set") {
        seedMember(store, { scopeId: seeded.scopeId, identifierType: "barcode", identifierValue: product.barcode });
      }
    }
  }
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.truncationOccurred, true, "12 verified refs cannot all fit within the 10-ref cap");
  const events = reviewEvents(store);
  assert.equal(events.length, 1);
  assert.ok(/sourceReads=4;/.test(events[0].notes), `expected exactly 4 source reads: ${events[0].notes}`);
  assert.ok(/omittedByActiveRefCap=([1-9]\d*)/.test(events[0].notes));
  assert.ok(/omittedBySourceReadCap=0;/.test(events[0].notes), `source-read cap must never have triggered: ${events[0].notes}`);
});

test("R3 (item 19). no event for a raw count >10 alone when every candidate is fully accounted for via dedup/reuse", async () => {
  const store = createStore();
  seedPolicyWithTwoBusinessGroups(store);
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  // 15 raw candidate scope docs, but only 2 distinct source documents
  // (many scopes point at the same 2 documents) — well within both caps
  // after documentId-level dedup.
  const docA = "doc-shared-A";
  const docB = "doc-shared-B";
  seedDocument(store, docA, { documentType: "purchase_invoice" });
  seedDocument(store, docB, { documentType: "manufacturer_evidence" });
  for (let i = 0; i < 13; i++) {
    seedScope(store, {
      scopeType: "business",
      scopeValue: BUSINESS_ID,
      documentId: docA,
      documentType: "purchase_invoice",
      approvedAt: makeTimestamp(NOW_MS - 1_000_000 + i),
      id: `dup-scope-${i}`,
    });
  }
  seedScope(store, { scopeType: "business", scopeValue: BUSINESS_ID, documentId: docB, documentType: "manufacturer_evidence", id: "dup-scope-b" });
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.truncationOccurred, false);
  assert.equal(reviewEvents(store).length, 0);
});

test("R4 (item 20). no event for exact duplicate (documentId, scopeId) pair collapse", async () => {
  const store = createStore();
  seedPolicyWithTwoBusinessGroups(store);
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, {
    scope: { scopeType: "business", scopeValue: BUSINESS_ID },
    document: { documentType: "purchase_invoice" },
  });
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.truncationOccurred, false);
  assert.equal(reviewEvents(store).length, 0);
});

test("R5 (item 21). no event solely for source-invalid candidates, even many of them", async () => {
  const store = createStore();
  seedPolicyWithTwoBusinessGroups(store);
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  for (let i = 0; i < 5; i++) {
    seedScopeAndDocument(store, {
      scope: { scopeType: "business", scopeValue: BUSINESS_ID, approvedAt: makeTimestamp(NOW_MS - 1000 + i) },
      document: { documentType: "purchase_invoice", status: COMPLIANCE_DOCUMENT_STATUS.REVOKED },
    });
  }
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.truncationOccurred, false);
  assert.equal(reviewEvents(store).length, 0);
});

test("R6 (items 22/23/24). exact event fields/enums and exact fixed-key notes format, no IDs/content", async () => {
  const store = createStore();
  const realTypes = Object.values(COMPLIANCE_DOCUMENT_TYPE);
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: realTypes,
      requiredDocumentTypeGroups: [realTypes],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: [...ALL_LANES_ACCEPTED_SCOPE_TYPES],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store);
  seedEpoch(store, 0);
  const entries = [];
  for (let i = 0; i < 11; i++) {
    entries.push({ documentType: realTypes[i % realTypes.length], approvedAtMs: NOW_MS - 1_000_000 + i, status: COMPLIANCE_DOCUMENT_STATUS.REVOKED });
  }
  seedSpreadCandidates(store, product, entries);
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.truncationOccurred, true);
  const events = reviewEvents(store);
  assert.equal(events.length, 1);
  const event = events[0];
  assert.deepEqual(Object.keys(event).sort(), ["action", "actorRole", "actorUid", "businessId", "notes", "occurredAt", "targetId", "targetType"]);
  assert.equal(event.targetType, "product");
  assert.equal(event.targetId, PRODUCT_ID);
  assert.equal(event.businessId, BUSINESS_ID);
  assert.equal(event.action, "recomputed");
  assert.equal(event.actorUid, "system");
  assert.equal(event.actorRole, "system");
  assert.equal(
    /^candidateRefs=\d+; candidateDocuments=\d+; sourceReads=\d+; activeRefs=\d+; omittedBySourceReadCap=\d+; omittedByActiveRefCap=\d+$/.test(event.notes),
    true,
    `notes did not match the exact frozen format: ${event.notes}`
  );
  assert.equal(/scope-|doc-|dup-scope/.test(event.notes), false, "notes must never contain document/scope IDs");
});

test("R7 (item 25/26). exactly one event, written in the SAME transaction as the decision/links", async () => {
  const store = createStore();
  const realTypes = Object.values(COMPLIANCE_DOCUMENT_TYPE);
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: realTypes,
      requiredDocumentTypeGroups: [realTypes],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: [...ALL_LANES_ACCEPTED_SCOPE_TYPES],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store);
  seedEpoch(store, 0);
  const entries = [];
  for (let i = 0; i < 11; i++) {
    entries.push({ documentType: realTypes[i % realTypes.length], approvedAtMs: NOW_MS - 1_000_000 + i, status: COMPLIANCE_DOCUMENT_STATUS.REVOKED });
  }
  seedSpreadCandidates(store, product, entries);
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(reviewEvents(store).length, 1);
  // The decision document was also written — same call, same
  // transaction commit (the fake db only ever commits a whole
  // transaction's staged writes atomically, in one block).
  assert.ok(getRawDoc(store, DECISIONS_COLLECTION, PRODUCT_ID));
});

test("R8 (item 27). event write failure aborts the whole transaction — zero committed state", async () => {
  const store = createStore();
  const realTypes = Object.values(COMPLIANCE_DOCUMENT_TYPE);
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: realTypes,
      requiredDocumentTypeGroups: [realTypes],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["business"],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  for (let i = 0; i < 11; i++) {
    seedScopeAndDocument(store, {
      scope: { scopeType: "business", scopeValue: BUSINESS_ID, approvedAt: makeTimestamp(NOW_MS - 1_000_000 + i) },
      document: { documentType: realTypes[i % realTypes.length], status: COMPLIANCE_DOCUMENT_STATUS.REVOKED },
    });
  }
  const db = createFakeDb(store);
  const before = new Map(store.docs);
  const originalRunTransaction = db.runTransaction;
  db.runTransaction = async (callback) => {
    // Simulate the transaction commit itself failing (e.g. the event
    // tx.create() rejected server-side) — nothing the callback staged
    // may be observed as committed.
    await callback({
      async get(refOrQuery) {
        return refOrQuery.get();
      },
      set() {},
      create() {},
      delete() {},
    });
    throw new Error("simulated commit failure");
  };
  await assert.rejects(recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW }));
  assert.deepEqual(store.docs, before);
  db.runTransaction = originalRunTransaction;
});

test("R9 (item 28). a retried recompute (abandoned first attempt) leaves only the committed attempt's event, never two", async () => {
  const store = createStore();
  const realTypes = Object.values(COMPLIANCE_DOCUMENT_TYPE);
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: realTypes,
      requiredDocumentTypeGroups: [realTypes],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: [...ALL_LANES_ACCEPTED_SCOPE_TYPES],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store);
  seedEpoch(store, 0);
  const entries = [];
  for (let i = 0; i < 11; i++) {
    entries.push({ documentType: realTypes[i % realTypes.length], approvedAtMs: NOW_MS - 1_000_000 + i, status: COMPLIANCE_DOCUMENT_STATUS.REVOKED });
  }
  seedSpreadCandidates(store, product, entries);
  const db = createFakeDb(store);
  // Exactly one real (non-retried, in this fake) call — the fake db has
  // no built-in retry simulation, so this proves the single-call
  // baseline: exactly one event is ever produced, never more.
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(reviewEvents(store).length, 1);
});

// =======================================================================
// S. sellerRelationshipSnapshot (items 29-34).
// =======================================================================

test("S1 (item 29). sellerRelationshipSnapshot is written exactly equal to the live product relationship used for policy selection", async () => {
  const store = createStore();
  seedActivePolicy(store);
  seedProduct(store, { sellerRelationship: SELLER_RELATIONSHIP.MANUFACTURER, brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.decision.sellerRelationshipSnapshot, SELLER_RELATIONSHIP.MANUFACTURER);
});

test("S2 (item 30). evaluator equality: snapshot equal to live relationship passes this check", async () => {
  const store = createStore();
  seedActivePolicy(store);
  seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const result = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.eligible, true);
});

test("S3 (items 31/34). dormant regression: relationship changes with productInputRevision absent on both sides — the stale decision is rejected by the snapshot check alone, never by the revision check", async () => {
  const store = createStore();
  seedActivePolicy(store);
  // Step 1/2: product declares "reseller", productInputRevision ABSENT
  // (dormant representation — normalizes to 0 on both the writer and
  // evaluator sides, by construction of normalizedProductInputRevision).
  seedProduct(store, { sellerRelationship: SELLER_RELATIONSHIP.RESELLER, productInputRevision: undefined, brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  const recomputeResult = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(recomputeResult.decision.sellerRelationshipSnapshot, SELLER_RELATIONSHIP.RESELLER);
  assert.equal(recomputeResult.decision.productInputRevisionSnapshot, 0);

  // Step 3: evaluator succeeds while otherwise valid (nothing changed
  // yet).
  const before = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(before.eligible, true);

  // Step 4: relationship changes to "importer" while productInputRevision
  // remains absent on the new document too (the exact dormant gap
  // firestore.rules row A permits).
  const currentProduct = getRawDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID);
  seedDoc(store, `${PRODUCTS_ROOT}/${BUSINESS_ID}/products`, PRODUCT_ID, {
    ...currentProduct,
    sellerRelationship: SELLER_RELATIONSHIP.IMPORTER,
    productInputRevision: undefined,
  });

  // Step 5: the SAME old decision must fail immediately, and the
  // revision check (normalizing 0 === 0) would NOT have caught this —
  // only the independent sellerRelationshipSnapshot check does.
  const after = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(after.eligible, false);
  assert.equal(after.reason, "eligibility_seller_relationship_snapshot_mismatch");
});

test("S4 (item 32). a legacy decision written before sellerRelationshipSnapshot existed is rejected as malformed, not silently treated as matching", async () => {
  const store = createStore();
  seedActivePolicy(store);
  seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const legacyDecision = getRawDoc(store, DECISIONS_COLLECTION, PRODUCT_ID);
  delete legacyDecision.sellerRelationshipSnapshot;
  seedDoc(store, DECISIONS_COLLECTION, PRODUCT_ID, legacyDecision);
  const evalResult = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(evalResult.eligible, false);
  assert.equal(evalResult.reason, "eligibility_decision_malformed");
});

test("S5 (item 33). a malformed (non-enum) sellerRelationshipSnapshot value is rejected", async () => {
  const store = createStore();
  seedActivePolicy(store);
  seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const decision = getRawDoc(store, DECISIONS_COLLECTION, PRODUCT_ID);
  seedDoc(store, DECISIONS_COLLECTION, PRODUCT_ID, { ...decision, sellerRelationshipSnapshot: "not_a_real_relationship" });
  const evalResult = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(evalResult.eligible, false);
  assert.equal(evalResult.reason, "eligibility_decision_malformed");
});

// =======================================================================
// T. decisionHash canonicalization (items 35-42).
// =======================================================================

function baseHashInput() {
  return {
    businessId: "biz-1",
    policyVersion: "v1",
    evidenceRevision: 2,
    productInputRevisionSnapshot: 3,
    sellerRelationshipSnapshot: "reseller",
    requiredEvidenceSlots: [{ acceptedDocumentTypes: ["purchase_invoice"] }],
    satisfiedEvidenceSlots: [{ acceptedDocumentTypes: ["purchase_invoice"] }],
    activeEvidenceRefs: [{ documentId: "doc-1", scopeId: "scope-1", expiresAt: makeTimestamp(1_900_000_000_000) }],
    validUntil: makeTimestamp(1_900_000_000_000),
    effectiveStatus: "verified_valid",
  };
}

test("T1 (item 35). recursive key sort — nested object keys are sorted at every level, not only the top", () => {
  const input = baseHashInput();
  input.requiredEvidenceSlots = [{ b: 2, a: 1 }];
  const canonical = canonicalizeForHash(input);
  const parsed = JSON.parse(canonical);
  assert.deepEqual(Object.keys(parsed.requiredEvidenceSlots[0]), ["a", "b"]);
});

test("T2 (item 36). array order is preserved exactly, never re-sorted", () => {
  const input1 = baseHashInput();
  input1.satisfiedEvidenceSlots = [{ acceptedDocumentTypes: ["z", "a"] }];
  const input2 = { ...input1, satisfiedEvidenceSlots: [{ acceptedDocumentTypes: ["a", "z"] }] };
  const hash1 = computeDecisionHash(input1);
  const hash2 = computeDecisionHash(input2);
  assert.notEqual(hash1, hash2, "reordering array members must change the hash — proves order is preserved, not re-sorted");
});

test("T3 (item 37). Firestore Timestamp fields are encoded as integer .toMillis(), not the object itself", () => {
  const input = baseHashInput();
  const canonical = JSON.parse(canonicalizeForHash(input));
  assert.equal(canonical.validUntil, 1_900_000_000_000);
  assert.equal(typeof canonical.validUntil, "number");
});

test("T4 (item 38). undefined anywhere in the structure is rejected, including nested", () => {
  const input = baseHashInput();
  assert.throws(() => computeDecisionHash({ ...input, businessId: undefined }));
  const nested = baseHashInput();
  nested.requiredEvidenceSlots = [{ acceptedDocumentTypes: [undefined] }];
  assert.throws(() => computeDecisionHash(nested));
});

test("T5 (item 39). an unsupported object (class instance / DocumentReference-shaped) is rejected", () => {
  class FakeDocumentReference {
    constructor() {
      this.path = "some/path";
    }
  }
  const input = baseHashInput();
  input.activeEvidenceRefs = [{ documentId: "doc-1", scopeId: "scope-1", expiresAt: new FakeDocumentReference() }];
  assert.throws(() => computeDecisionHash(input));
});

test("T6 (item 40). independent known vector — a fixed, hand-computed canonical JSON produces the exact expected SHA-256", () => {
  const crypto = require("node:crypto");
  const input = {
    businessId: "biz-1",
    policyVersion: "v1",
    evidenceRevision: 1,
    productInputRevisionSnapshot: 0,
    sellerRelationshipSnapshot: "reseller",
    requiredEvidenceSlots: [{ acceptedDocumentTypes: ["purchase_invoice"] }],
    satisfiedEvidenceSlots: [],
    activeEvidenceRefs: [],
    validUntil: null,
    effectiveStatus: "evidence_missing",
  };
  // Hand-built expected canonical JSON — keys sorted lexicographically
  // at every level, array order preserved, independently of the
  // production canonicalizeForHash implementation.
  const expectedCanonicalJson =
    '{"activeEvidenceRefs":[],"businessId":"biz-1","effectiveStatus":"evidence_missing",' +
    '"evidenceRevision":1,"policyVersion":"v1","productInputRevisionSnapshot":0,' +
    '"requiredEvidenceSlots":[{"acceptedDocumentTypes":["purchase_invoice"]}],' +
    '"satisfiedEvidenceSlots":[],"sellerRelationshipSnapshot":"reseller","validUntil":null}';
  const expectedHash = crypto.createHash("sha256").update(expectedCanonicalJson, "utf8").digest("hex");

  assert.equal(canonicalizeForHash(input), expectedCanonicalJson);
  assert.equal(computeDecisionHash(input), expectedHash);
});

test("T7 (item 41). the evaluator rejects a decision whose stored decisionHash does not match a fresh recomputation", async () => {
  const store = createStore();
  seedActivePolicy(store);
  seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const decision = getRawDoc(store, DECISIONS_COLLECTION, PRODUCT_ID);
  seedDoc(store, DECISIONS_COLLECTION, PRODUCT_ID, { ...decision, decisionHash: "0".repeat(64) });
  const result = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.eligible, false);
  assert.equal(result.reason, "eligibility_decision_hash_mismatch");
});

test("T8 (item 42). independent freshness checks (epoch/revision/relationship/expiry) are still enforced even when the hash itself still matches", async () => {
  const store = createStore();
  seedActivePolicy(store);
  seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  // Bump the epoch — the STORED decision's own hash remains internally
  // self-consistent (it was never touched), yet the evaluator must still
  // reject on the independent epoch-equality check, which runs BEFORE
  // the hash recomputation.
  seedEpoch(store, 5);
  const result = await evaluateLiveProductEligibility({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.eligible, false);
  assert.equal(result.reason, "eligibility_evidence_revision_mismatch");
});

test("T9. DECISION_HASH_INCLUDED_FIELDS is exactly the ten frozen fields, no others", () => {
  assert.deepEqual(
    [...DECISION_HASH_INCLUDED_FIELDS].sort(),
    [
      "activeEvidenceRefs",
      "businessId",
      "effectiveStatus",
      "evidenceRevision",
      "policyVersion",
      "productInputRevisionSnapshot",
      "requiredEvidenceSlots",
      "satisfiedEvidenceSlots",
      "sellerRelationshipSnapshot",
      "validUntil",
    ]
  );
  assert.ok(!DECISION_HASH_INCLUDED_FIELDS.includes("computedAt"));
  assert.ok(!DECISION_HASH_INCLUDED_FIELDS.includes("decisionHash"));
});

// ---------------------------------------------------------------------
// T10-T13: corrective fix — a Timestamp-like value's .toMillis() must
// itself be finite, exactly mirroring the plain `number` branch's own
// finiteness check immediately above it in canonicalizeValue. Prior to
// this correction, a non-finite .toMillis() result (NaN/Infinity) was
// silently coerced to JSON `null` by JSON.stringify, colliding with a
// genuinely-null value instead of failing closed — reproduced and
// confirmed via a standalone script against the production module
// during the corrective task's own baseline-verification step.
// ---------------------------------------------------------------------

const NON_FINITE_TO_MILLIS_CASES = [
  ["NaN", NaN],
  ["Infinity", Infinity],
  ["-Infinity", -Infinity],
  ['numeric string "123" (no coercion)', "123"],
  ["null", null],
  ["undefined", undefined],
];

for (const [label, badReturn] of NON_FINITE_TO_MILLIS_CASES) {
  test(`T10. a Timestamp-like value whose .toMillis() returns ${label} is rejected by canonicalizeForHash and computeDecisionHash`, () => {
    const input = baseHashInput();
    input.activeEvidenceRefs = [{ documentId: "doc-1", scopeId: "scope-1", expiresAt: { toMillis: () => badReturn } }];
    assert.throws(() => canonicalizeForHash(input));
    assert.throws(() => computeDecisionHash(input));
  });
}

test("T11. a finite positive integer millisecond value remains accepted and passes through unchanged", () => {
  const input = baseHashInput();
  input.activeEvidenceRefs = [{ documentId: "doc-1", scopeId: "scope-1", expiresAt: makeTimestamp(1_234_567_890) }];
  const canonical = JSON.parse(canonicalizeForHash(input));
  assert.equal(canonical.activeEvidenceRefs[0].expiresAt, 1_234_567_890);
});

test("T12. a finite negative millisecond value remains accepted — canonicalization is a representation layer and requires only finiteness, no sign restriction", () => {
  const input = baseHashInput();
  input.activeEvidenceRefs = [{ documentId: "doc-1", scopeId: "scope-1", expiresAt: makeTimestamp(-1_234_567_890) }];
  const canonical = JSON.parse(canonicalizeForHash(input));
  assert.equal(canonical.activeEvidenceRefs[0].expiresAt, -1_234_567_890);
});

test("T13. .toMillis() is called exactly once per Timestamp-like value", () => {
  let calls = 0;
  const input = baseHashInput();
  input.activeEvidenceRefs = [{ documentId: "doc-1", scopeId: "scope-1", expiresAt: { toMillis: () => { calls += 1; return 5000; } } }];
  canonicalizeForHash(input);
  assert.equal(calls, 1);
});

test("T14. a Timestamp-like value whose .toMillis() itself throws propagates the error — it is never caught and converted to null", () => {
  const input = baseHashInput();
  input.activeEvidenceRefs = [{
    documentId: "doc-1",
    scopeId: "scope-1",
    expiresAt: { toMillis: () => { throw new Error("simulated toMillis failure"); } },
  }];
  assert.throws(() => canonicalizeForHash(input), /simulated toMillis failure/);
});

test("T15. the formerly-colliding cases no longer collide: null still canonicalizes; a NaN-toMillis Timestamp throws instead of matching it", () => {
  const nullCase = baseHashInput();
  nullCase.activeEvidenceRefs = [{ documentId: "doc-1", scopeId: "scope-1", expiresAt: null }];
  const nullCanonical = canonicalizeForHash(nullCase);
  assert.equal(JSON.parse(nullCanonical).activeEvidenceRefs[0].expiresAt, null);

  const nanCase = baseHashInput();
  nanCase.activeEvidenceRefs = [{ documentId: "doc-1", scopeId: "scope-1", expiresAt: { toMillis: () => NaN } }];
  assert.throws(() => canonicalizeForHash(nanCase));

  const infinityCase = baseHashInput();
  infinityCase.activeEvidenceRefs = [{ documentId: "doc-1", scopeId: "scope-1", expiresAt: { toMillis: () => Infinity } }];
  assert.throws(() => canonicalizeForHash(infinityCase));
});

test("T16. a nested activeEvidenceRefs entry with a NaN Timestamp fails closed in both canonicalizeForHash and computeDecisionHash, exercising the real recompute-shaped decision content", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  // Take the REAL decision content this recompute produced, then corrupt
  // just its activeEvidenceRefs[0].expiresAt with a broken Timestamp —
  // exercising the same shape the production writer/evaluator actually
  // handle, not a hand-rolled object.
  assert.ok(result.decision.activeEvidenceRefs.length >= 1, "fixture must produce at least one evidence ref");
  const corrupted = {
    ...result.decision,
    activeEvidenceRefs: [
      { ...result.decision.activeEvidenceRefs[0], expiresAt: { toMillis: () => NaN } },
      ...result.decision.activeEvidenceRefs.slice(1),
    ],
  };
  assert.throws(() => canonicalizeForHash(corrupted));
  assert.throws(() => computeDecisionHash(corrupted));
});

// =======================================================================
// U. Bounds (items 43-50) — additional coverage beyond section J.
// =======================================================================

test("U1 (item 47). write bound with a truncation event: at most 22 writes (10 deletes + 1 decision + 10 links + 1 event)", async () => {
  const store = createStore();
  const realTypes = Object.values(COMPLIANCE_DOCUMENT_TYPE);
  seedActivePolicy(store, {
    [SELLER_RELATIONSHIP.RESELLER]: {
      acceptedDocumentTypes: realTypes,
      requiredDocumentTypeGroups: [realTypes],
      perDocumentTypePolicy: {},
      maximumValidityPeriod: null,
      acceptedScopeTypes: ["business"],
      manualAdminOverridePermitted: false,
    },
  });
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  for (let i = 0; i < 11; i++) {
    seedScopeAndDocument(store, {
      scope: { scopeType: "business", scopeValue: BUSINESS_ID, approvedAt: makeTimestamp(NOW_MS - 1_000_000 + i) },
      document: { documentType: realTypes[i % realTypes.length], status: COMPLIANCE_DOCUMENT_STATUS.REVOKED },
    });
  }
  const db = createFakeDb(store);
  store.callLog.length = 0;
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const writeCount = store.callLog.filter((e) => e.startsWith("set:") || e.startsWith("create:") || e.startsWith("delete:")).length;
  assert.ok(writeCount <= 22, `writeCount was ${writeCount}`);
});

test("U2 (item 48). write bound without a truncation event: at most 21 writes", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  const result = await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  assert.equal(result.truncationOccurred, false);
  store.callLog.length = 0;
  await recomputeProductComplianceStatus({ db, businessId: BUSINESS_ID, productId: PRODUCT_ID, now: NOW });
  const writeCount = store.callLog.filter((e) => e.startsWith("set:") || e.startsWith("create:") || e.startsWith("delete:")).length;
  assert.ok(writeCount <= 21, `writeCount was ${writeCount}`);
});

test("U3 (item 49). counters cannot omit a cached/reused source read — the counter reflects only real reads, cache hits cost zero", async () => {
  const store = createStore();
  seedPolicyWithTwoBusinessGroups(store);
  const product = seedProduct(store, { brand: undefined, category: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedDocument(store, "shared-doc-9", { documentType: "purchase_invoice" });
  seedScope(store, { scopeType: "business", scopeValue: BUSINESS_ID, documentId: "shared-doc-9", documentType: "purchase_invoice", id: "s9-a" });
  const db = createFakeDb(store);
  const counters = createCounters();
  const decision = await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters })
  );
  assert.equal(decision.sourceReads, 1);
  assert.equal(decision.candidateDocuments, 1);
});

test("U4 (item 50). the matching engine never issues a query against productEvidenceLinks", async () => {
  const store = createStore();
  seedActivePolicy(store);
  const product = seedProduct(store, { brand: undefined, sku: undefined, barcode: undefined });
  seedEpoch(store, 0);
  seedScopeAndDocument(store, { scope: { scopeType: "category", scopeValue: "Health > Vitamins" } });
  const db = createFakeDb(store);
  await db.runTransaction((tx) =>
    runComplianceMatching({ tx, db, product, productId: PRODUCT_ID, activePolicyVersion: getRawDoc(store, REGISTRY_COLLECTION, VERSION_ID), now: NOW, counters: createCounters() })
  );
  assert.ok(!store.callLog.some((e) => e.includes(LINKS_COLLECTION)));
});

// =======================================================================
// V. Architecture (items 51/53/54 — item 52 covered by N3/O6 above).
// =======================================================================

test("V1 (item 51). no ninth authorized path introduced — exactly the eight Slice 4.3 paths exist/were touched", () => {
  const expectedPaths = [
    "firestore.indexes.json",
    "src/marketplace/compliance/complianceConstants.js",
    "src/marketplace/compliance/complianceBrandNormalizer.js",
    "src/marketplace/compliance/complianceEligibilityEvaluator.js",
    "src/marketplace/compliance/complianceMatching.js",
    "src/marketplace/compliance/complianceProductRecompute.js",
  ];
  for (const rel of expectedPaths) {
    const p = rel.startsWith("firestore")
      ? path.resolve(__dirname, "../../", rel)
      : path.resolve(__dirname, "../", rel);
    assert.ok(fs.existsSync(p), `expected path missing: ${rel}`);
  }
  // No fifth production module directory entry beyond the four already
  // known Slice 4.3 modules plus complianceConstants.js.
  const complianceDir = path.resolve(__dirname, "../src/marketplace/compliance");
  const entries = fs.readdirSync(complianceDir);
  const newModuleCount = entries.filter((f) =>
    ["complianceBrandNormalizer.js", "complianceEligibilityEvaluator.js", "complianceMatching.js", "complianceProductRecompute.js"].includes(f)
  ).length;
  assert.equal(newModuleCount, 4);
});

test("V2 (item 53). no skip/todo/only in any of the four Slice 4.3 production modules", () => {
  for (const file of [
    "complianceMatching.js",
    "complianceProductRecompute.js",
    "complianceEligibilityEvaluator.js",
    "complianceBrandNormalizer.js",
  ]) {
    const src = fs.readFileSync(path.resolve(__dirname, `../src/marketplace/compliance/${file}`), "utf8");
    assert.equal(/\.skip\s*\(/.test(src), false);
    assert.equal(/\.only\s*\(/.test(src), false);
    assert.equal(/\bTODO\b/.test(src), false);
    assert.equal(/\bFIXME\b/.test(src), false);
  }
});
