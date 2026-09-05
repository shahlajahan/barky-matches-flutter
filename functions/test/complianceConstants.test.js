"use strict";

// Pure unit tests for the P1-A compliance foundation (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// Slice 1). No Firestore emulator, no Admin SDK, no network — every test
// here exercises plain JS constants/validators only.

const test = require("node:test");
const assert = require("node:assert/strict");

const constants = require("../src/marketplace/compliance/complianceConstants");
const validators = require("../src/marketplace/compliance/complianceValidators");

const {
  STOCK_AUTHORITY_TYPE,
  STOCK_AUTHORITY_TYPE_REACHABLE_IN_P1A,
  BUSINESS_INVENTORY_POLICY_STATUS,
  BUSINESS_INVENTORY_POLICY_STATUS_REACHABLE_IN_P1A,
  COMPLIANCE_UPLOAD_SESSION_STATUS,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES,
  COMPLIANCE_DOCUMENT_TYPE,
  SELLER_RELATIONSHIP,
  PILOT_PRODUCT_CLASS,
  PILOT_PRODUCT_CLASS_VALUES,
  isValidPilotProductClass,
  PILOT_CLASSIFICATION_MAX_REASON_LENGTH,
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_DOCUMENT_SERVER_OWNED_FIELDS,
  COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS,
  COMPLIANCE_DOCUMENT_ALLOWED_FIELDS,
  COMPLIANCE_SCOPE_TYPE,
  COMPLIANCE_SCOPE_STATUS,
  COMPLIANCE_SCOPE_ALLOWED_FIELDS,
  COMPLIANCE_SCOPE_MEMBER_IDENTIFIER_TYPE,
  COMPLIANCE_SCOPE_MEMBER_STATUS,
  COMPLIANCE_REVIEW_EVENT_TARGET_TYPE,
  COMPLIANCE_REVIEW_EVENT_ACTION,
  COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE,
  COMPLIANCE_POLICY_REGISTRY_STATUS,
  COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION,
  COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID,
  COMPLIANCE_POLICY_REGISTRY_POINTER_ALLOWED_FIELDS,
  PRODUCT_COMPLIANCE_EFFECTIVE_STATUS,
  PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES,
  PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS,
  PRODUCT_COMPLIANCE_DECISION_MAX_REQUIRED_SLOTS,
  PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS,
  COMPLIANCE_EVIDENCE_LINK_MATCH_TYPE,
  PRODUCT_EVIDENCE_LINK_ALLOWED_FIELDS,
  LOOKUP_LIMIT,
  MATCHED_SCOPE_CAP,
} = constants;

const {
  isEnumMember,
  hasOnlyAllowedKeys,
  changedKeysExcludeProtectedFields,
  isValidStockAuthorityType,
  isStockAuthorityTypeReachableInP1A,
  isValidBusinessInventoryPolicyStatus,
  isBusinessInventoryPolicyStatusReachableInP1A,
  hasOnlyAllowedBusinessInventoryPolicyFields,
  isValidComplianceUploadSessionStatus,
  isAllowedComplianceUploadMimeType,
  isValidComplianceDocumentType,
  isValidSellerRelationship,
  isValidComplianceDocumentStatus,
  hasOnlyAllowedComplianceDocumentFields,
  isServerOwnedComplianceDocumentField,
  isImmutableComplianceDocumentField,
  isSafeComplianceDocumentSellerUpdate,
  isValidComplianceScopeType,
  isValidComplianceScopeStatus,
  hasOnlyAllowedComplianceScopeFields,
  isValidComplianceScopeMemberIdentifierType,
  isValidComplianceScopeMemberStatus,
  isValidComplianceReviewEventTargetType,
  isValidComplianceReviewEventAction,
  isValidComplianceReviewEventActorRole,
  isValidCompliancePolicyRegistryStatus,
  isValidProductComplianceEffectiveStatus,
  isProductComplianceEligibleStatus,
  isWithinActiveEvidenceRefsBound,
  isWithinRequiredEvidenceSlotsBound,
  hasOnlyAllowedProductComplianceDecisionFields,
} = validators;

function allEnumValues(enumObject) {
  return Object.values(enumObject);
}

// ---------------------------------------------------------------------
// Generic helpers
// ---------------------------------------------------------------------

test("hasOnlyAllowedKeys accepts an exact-subset payload and rejects an extra key", () => {
  assert.equal(hasOnlyAllowedKeys({ a: 1, b: 2 }, ["a", "b", "c"]), true);
  assert.equal(hasOnlyAllowedKeys({ a: 1, z: 99 }, ["a", "b", "c"]), false);
  assert.equal(hasOnlyAllowedKeys({}, ["a"]), true);
  assert.equal(hasOnlyAllowedKeys(null, ["a"]), false);
  assert.equal(hasOnlyAllowedKeys([1, 2], ["a"]), false);
});

test("isEnumMember only accepts declared string values", () => {
  const fixture = Object.freeze({ A: "a", B: "b" });
  assert.equal(isEnumMember("a", fixture), true);
  assert.equal(isEnumMember("c", fixture), false);
  assert.equal(isEnumMember(1, fixture), false);
  assert.equal(isEnumMember(undefined, fixture), false);
});

test("changedKeysExcludeProtectedFields detects an actual field change, not mere presence", () => {
  const before = { name: "A", reservedField: 1 };
  const after = { name: "B", reservedField: 1 };
  // Only `name` changed; `reservedField` is present in both but unchanged.
  assert.equal(
    changedKeysExcludeProtectedFields(before, after, ["reservedField"]),
    true
  );
  const afterTampered = { name: "B", reservedField: 2 };
  assert.equal(
    changedKeysExcludeProtectedFields(before, afterTampered, ["reservedField"]),
    false
  );
});

// ---------------------------------------------------------------------
// businessInventoryPolicies
// ---------------------------------------------------------------------

test("STOCK_AUTHORITY_TYPE has 5 unique values; only 2 are P1-A reachable", () => {
  const values = allEnumValues(STOCK_AUTHORITY_TYPE);
  assert.equal(values.length, 5);
  assert.equal(new Set(values).size, 5);
  assert.deepEqual(STOCK_AUTHORITY_TYPE_REACHABLE_IN_P1A, ["manual", "petsupo"]);
  for (const value of values) {
    assert.equal(isValidStockAuthorityType(value), true);
  }
  assert.equal(isValidStockAuthorityType("not_a_real_mode"), false);
  assert.equal(isStockAuthorityTypeReachableInP1A("manual"), true);
  assert.equal(isStockAuthorityTypeReachableInP1A("seller_erp"), false);
});

test("BUSINESS_INVENTORY_POLICY_STATUS: only 'active' is P1-A reachable", () => {
  assert.equal(isValidBusinessInventoryPolicyStatus("active"), true);
  assert.equal(isValidBusinessInventoryPolicyStatus("transition_paused"), true);
  assert.equal(isValidBusinessInventoryPolicyStatus("not_a_status"), false);
  assert.deepEqual(BUSINESS_INVENTORY_POLICY_STATUS_REACHABLE_IN_P1A, ["active"]);
  assert.equal(isBusinessInventoryPolicyStatusReachableInP1A("active"), true);
  assert.equal(
    isBusinessInventoryPolicyStatusReachableInP1A("transition_paused"),
    false
  );
});

test("businessInventoryPolicies allowed-field payload check", () => {
  assert.equal(
    hasOnlyAllowedBusinessInventoryPolicyFields({
      businessId: "biz-1",
      stockAuthorityType: STOCK_AUTHORITY_TYPE.MANUAL,
      status: BUSINESS_INVENTORY_POLICY_STATUS.ACTIVE,
      defaultSafetyStock: 0,
    }),
    true
  );
  assert.equal(
    hasOnlyAllowedBusinessInventoryPolicyFields({
      businessId: "biz-1",
      authorityConnectionId: "should-not-exist-yet",
      channel: "trendyol",
    }),
    false
  );
});

// ---------------------------------------------------------------------
// complianceUploadSessions
// ---------------------------------------------------------------------

test("COMPLIANCE_UPLOAD_SESSION_STATUS has 12 unique values (Slice 2's full state machine)", () => {
  // Updated from Slice 1's 7-value placeholder to Slice 2's full,
  // explicit state machine (docs/plans/marketplace_p1a_compliance_
  // review_implementation_plan_2026-08-21.md, security decision) — this
  // is the single enum every later file reuses, per "do not duplicate
  // state enums in multiple files"; see complianceUploadUnit.test.js for
  // the transition-table coverage.
  const values = allEnumValues(COMPLIANCE_UPLOAD_SESSION_STATUS);
  assert.equal(values.length, 12);
  assert.equal(new Set(values).size, 12);
  for (const value of values) {
    assert.equal(isValidComplianceUploadSessionStatus(value), true);
  }
  assert.equal(isValidComplianceUploadSessionStatus("bogus"), false);
  assert.equal(isValidComplianceUploadSessionStatus("issued"), false, "the retired Slice 1 placeholder name must not remain valid");
});

test("only PDF/JPEG/PNG are allowed upload MIME types", () => {
  assert.deepEqual(COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES, [
    "application/pdf",
    "image/jpeg",
    "image/png",
  ]);
  assert.equal(isAllowedComplianceUploadMimeType("application/pdf"), true);
  assert.equal(isAllowedComplianceUploadMimeType("image/webp"), false);
  assert.equal(isAllowedComplianceUploadMimeType("image/svg+xml"), false);
  assert.equal(isAllowedComplianceUploadMimeType("text/html"), false);
  assert.equal(isAllowedComplianceUploadMimeType("video/mp4"), false);
});

// ---------------------------------------------------------------------
// complianceDocuments
// ---------------------------------------------------------------------

test("COMPLIANCE_DOCUMENT_TYPE has the 8 documented evidence types", () => {
  assert.equal(allEnumValues(COMPLIANCE_DOCUMENT_TYPE).length, 8);
  assert.equal(isValidComplianceDocumentType("purchase_invoice"), true);
  assert.equal(isValidComplianceDocumentType("medical_prescription"), false);
});

test("SELLER_RELATIONSHIP has exactly the 6 documented relationships", () => {
  assert.deepEqual(allEnumValues(SELLER_RELATIONSHIP).sort(), [
    "authorized_dealer",
    "authorized_distributor",
    "brand_owner",
    "importer",
    "manufacturer",
    "reseller",
  ]);
  assert.equal(isValidSellerRelationship("brand_owner"), true);
  assert.equal(isValidSellerRelationship("random_partner"), false);
});

test("COMPLIANCE_DOCUMENT_STATUS excludes session-only states", () => {
  const values = allEnumValues(COMPLIANCE_DOCUMENT_STATUS);
  for (const sessionOnlyState of ["uploaded", "validating", "scan_pending", "issued"]) {
    assert.equal(values.includes(sessionOnlyState), false);
  }
  assert.equal(isValidComplianceDocumentStatus("clean"), true);
  assert.equal(isValidComplianceDocumentStatus("pending_review"), true);
  assert.equal(isValidComplianceDocumentStatus("uploaded"), false);
});

test("complianceDocuments allowed-field list is exactly immutable + server-owned, no duplicates, no overlap", () => {
  const combined = COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS.concat(
    COMPLIANCE_DOCUMENT_SERVER_OWNED_FIELDS
  );
  assert.deepEqual([...COMPLIANCE_DOCUMENT_ALLOWED_FIELDS].sort(), [...combined].sort());
  assert.equal(new Set(COMPLIANCE_DOCUMENT_ALLOWED_FIELDS).size, combined.length);
  const overlap = COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS.filter((f) =>
    COMPLIANCE_DOCUMENT_SERVER_OWNED_FIELDS.includes(f)
  );
  assert.deepEqual(overlap, []);
});

test("every complianceDocuments field is classified as immutable or server-owned, never neither", () => {
  for (const field of COMPLIANCE_DOCUMENT_ALLOWED_FIELDS) {
    const classifiedSomehow =
      isImmutableComplianceDocumentField(field) ||
      isServerOwnedComplianceDocumentField(field);
    assert.equal(classifiedSomehow, true, `field "${field}" is unclassified`);
  }
});

test("hasOnlyAllowedComplianceDocumentFields rejects an unknown/legacy field", () => {
  assert.equal(
    hasOnlyAllowedComplianceDocumentFields({
      businessId: "biz-1",
      status: "clean",
    }),
    true
  );
  assert.equal(
    hasOnlyAllowedComplianceDocumentFields({
      businessId: "biz-1",
      normalizedBrandId: "should-not-exist-on-this-collection",
    }),
    false
  );
});

test("isSafeComplianceDocumentSellerUpdate: no field on this collection is ever seller-mutable", () => {
  const before = { businessId: "biz-1", status: "clean" };
  // Changing the immutable businessId is unsafe...
  assert.equal(
    isSafeComplianceDocumentSellerUpdate(before, { businessId: "biz-2", status: "clean" }),
    false
  );
  // ...and so is changing the server-owned status.
  assert.equal(
    isSafeComplianceDocumentSellerUpdate(before, { businessId: "biz-1", status: "approved" }),
    false
  );
  // A no-op "update" (nothing actually changed) is trivially safe.
  assert.equal(isSafeComplianceDocumentSellerUpdate(before, { ...before }), true);
});

// ---------------------------------------------------------------------
// complianceDocumentScopes / members
// ---------------------------------------------------------------------

test("COMPLIANCE_SCOPE_TYPE has exactly the 7 documented scope types", () => {
  assert.deepEqual(allEnumValues(COMPLIANCE_SCOPE_TYPE).sort(), [
    "brand",
    "business",
    "category",
    "product",
    "product_family",
    "sku_set",
    "supplier",
  ]);
  assert.equal(isValidComplianceScopeType("brand"), true);
  assert.equal(isValidComplianceScopeType("region"), false);
});

test("COMPLIANCE_SCOPE_STATUS has exactly 3 values", () => {
  assert.equal(allEnumValues(COMPLIANCE_SCOPE_STATUS).length, 3);
  assert.equal(isValidComplianceScopeStatus("approved"), true);
  assert.equal(isValidComplianceScopeStatus("active"), false);
});

// Revision 7 correction 40/45 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §4/§13.1): sellerRelationship
// is denormalized onto every scope from its immutable source document.
// This proves the schema itself, not the writer (complianceDocumentOperations.js,
// tested separately, emulator-backed) — sellerRelationship appears exactly
// once, every other field is unchanged, and the exact prior list (Revision
// 6 and earlier) is updated here intentionally, not silently.
test("COMPLIANCE_SCOPE_ALLOWED_FIELDS contains sellerRelationship exactly once, alongside every pre-existing field unchanged", () => {
  const occurrences = COMPLIANCE_SCOPE_ALLOWED_FIELDS.filter((f) => f === "sellerRelationship");
  assert.equal(occurrences.length, 1);
  assert.ok(Object.isFrozen(COMPLIANCE_SCOPE_ALLOWED_FIELDS));
});

test("COMPLIANCE_SCOPE_ALLOWED_FIELDS contains documentType and validUntil exactly once each (Revision 9 correction 49), every prior field preserved", () => {
  for (const field of ["documentType", "validUntil"]) {
    const occurrences = COMPLIANCE_SCOPE_ALLOWED_FIELDS.filter((f) => f === field);
    assert.equal(occurrences.length, 1, `${field} must appear exactly once`);
  }
  assert.deepEqual(COMPLIANCE_SCOPE_ALLOWED_FIELDS.slice().sort(), [
    "businessId",
    "createdAt",
    "createdBy",
    "documentId",
    "documentType",
    "memberCount",
    "reviewedAt",
    "reviewedBy",
    "scopeType",
    "scopeValue",
    "sellerRelationship",
    "status",
    "validUntil",
    "verifiedBrandId",
  ]);
  assert.ok(Object.isFrozen(COMPLIANCE_SCOPE_ALLOWED_FIELDS));
});

test("hasOnlyAllowedComplianceScopeFields accepts a stored scope carrying documentType/validUntil and rejects an unknown field alongside them", () => {
  const validScope = {
    documentId: "doc-1",
    businessId: "biz-1",
    scopeType: "brand",
    scopeValue: "Acme",
    sellerRelationship: "reseller",
    documentType: "purchase_invoice",
    validUntil: { toMillis: () => 1_800_000_000_000 },
    memberCount: 0,
    status: "pending_review",
  };
  assert.equal(hasOnlyAllowedComplianceScopeFields(validScope), true);
  assert.equal(hasOnlyAllowedComplianceScopeFields({ ...validScope, notAllowed: true }), false);
});

test("valid COMPLIANCE_DOCUMENT_TYPE values are each accepted by isValidComplianceDocumentType, unaffected by the scope-schema correction", () => {
  for (const value of Object.values(COMPLIANCE_DOCUMENT_TYPE)) {
    assert.equal(isValidComplianceDocumentType(value), true);
  }
  assert.equal(isValidComplianceDocumentType("not_a_real_type"), false);
  assert.equal(isValidComplianceDocumentType(null), false);
  assert.equal(isValidComplianceDocumentType(undefined), false);
});

test("hasOnlyAllowedComplianceScopeFields accepts a stored scope document carrying sellerRelationship and rejects one with an unknown field", () => {
  const validScope = {
    documentId: "doc-1",
    businessId: "biz-1",
    scopeType: "brand",
    scopeValue: "Acme",
    sellerRelationship: "authorized_distributor",
    memberCount: 0,
    status: "pending_review",
    createdAt: null,
    createdBy: "seller-1",
    reviewedBy: null,
    reviewedAt: null,
    verifiedBrandId: null,
  };
  assert.equal(hasOnlyAllowedComplianceScopeFields(validScope), true);
  assert.equal(
    hasOnlyAllowedComplianceScopeFields({ ...validScope, unexpectedField: "x" }),
    false
  );
  // A scope carrying a valid sellerRelationship value from every one of
  // the 6 enum members remains structurally acceptable — the field-set
  // check is schema-shape only, not a value-domain check (that is
  // isValidSellerRelationship's job, already exercised elsewhere in this
  // file).
  for (const relationship of allEnumValues(SELLER_RELATIONSHIP)) {
    assert.equal(
      hasOnlyAllowedComplianceScopeFields({ ...validScope, sellerRelationship: relationship }),
      true
    );
  }
});

test("scope member identifier type is barcode or sku only", () => {
  assert.deepEqual(allEnumValues(COMPLIANCE_SCOPE_MEMBER_IDENTIFIER_TYPE).sort(), [
    "barcode",
    "sku",
  ]);
  assert.equal(isValidComplianceScopeMemberIdentifierType("barcode"), true);
  assert.equal(isValidComplianceScopeMemberIdentifierType("gtin"), false);
});

test("scope member status has exactly the 4 documented per-member states", () => {
  assert.deepEqual(allEnumValues(COMPLIANCE_SCOPE_MEMBER_STATUS).sort(), [
    "active",
    "pending_review",
    "rejected",
    "revoked",
  ]);
  assert.equal(isValidComplianceScopeMemberStatus("active"), true);
  assert.equal(isValidComplianceScopeMemberStatus("approved"), false);
});

// ---------------------------------------------------------------------
// complianceReviewEvents
// ---------------------------------------------------------------------

test("complianceReviewEvents target type covers document/scope/scope_member_batch/product", () => {
  assert.deepEqual(allEnumValues(COMPLIANCE_REVIEW_EVENT_TARGET_TYPE).sort(), [
    "document",
    "product",
    "scope",
    "scope_member_batch",
  ]);
  assert.equal(isValidComplianceReviewEventTargetType("product"), true);
  assert.equal(isValidComplianceReviewEventTargetType("business"), false);
});

test("complianceReviewEvents action/actorRole enums are valid", () => {
  assert.equal(allEnumValues(COMPLIANCE_REVIEW_EVENT_ACTION).length, 8);
  assert.equal(isValidComplianceReviewEventAction("approved"), true);
  assert.equal(isValidComplianceReviewEventAction("deleted"), false);
  assert.deepEqual(allEnumValues(COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE).sort(), [
    "admin",
    "seller",
    "system",
  ]);
  assert.equal(isValidComplianceReviewEventActorRole("system"), true);
  assert.equal(isValidComplianceReviewEventActorRole("bot"), false);
});

// ---------------------------------------------------------------------
// compliancePolicyRegistry
// ---------------------------------------------------------------------

test("compliancePolicyRegistry status is draft/active/inactive/retired, only one ever active by convention", () => {
  // `retired` added Slice 4.1 (master plan Revision 3 correction 17) —
  // additive only; `draft`/`active`/`inactive` are unchanged from Slice 1.
  assert.deepEqual(allEnumValues(COMPLIANCE_POLICY_REGISTRY_STATUS).sort(), [
    "active",
    "draft",
    "inactive",
    "retired",
  ]);
  assert.equal(isValidCompliancePolicyRegistryStatus("draft"), true);
  assert.equal(isValidCompliancePolicyRegistryStatus("active"), true);
  assert.equal(isValidCompliancePolicyRegistryStatus("inactive"), true);
  assert.equal(isValidCompliancePolicyRegistryStatus("retired"), true);
  assert.equal(isValidCompliancePolicyRegistryStatus("archived"), false);
});

test("inactive and retired are distinct values — neither substitutes for the other", () => {
  // `inactive`: a version never named by the pointer (dormant placeholder,
  // correction 8). `retired`: a version that WAS active and was
  // superseded by a successful activation (correction 17). Conflating
  // them would misrepresent registry history.
  assert.notEqual(COMPLIANCE_POLICY_REGISTRY_STATUS.INACTIVE, COMPLIANCE_POLICY_REGISTRY_STATUS.RETIRED);
  assert.equal(COMPLIANCE_POLICY_REGISTRY_STATUS.INACTIVE, "inactive");
  assert.equal(COMPLIANCE_POLICY_REGISTRY_STATUS.RETIRED, "retired");
});

test("compliancePolicyRegistry status enum did not lose any prior Slice 1 value", () => {
  const values = new Set(allEnumValues(COMPLIANCE_POLICY_REGISTRY_STATUS));
  for (const priorValue of ["draft", "active", "inactive"]) {
    assert.equal(values.has(priorValue), true, `${priorValue} must still be present`);
  }
});

// ---------------------------------------------------------------------
// compliancePolicyRegistryPointer/current (Slice 4.1)
// ---------------------------------------------------------------------

test("compliancePolicyRegistryPointer collection/doc-id/allowed-fields match the committed plan exactly", () => {
  assert.equal(COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION, "compliancePolicyRegistryPointer");
  assert.equal(COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID, "current");
  assert.deepEqual(COMPLIANCE_POLICY_REGISTRY_POINTER_ALLOWED_FIELDS, ["activeVersionId"]);
});

// ---------------------------------------------------------------------
// productComplianceDecisions / product compliance status
// ---------------------------------------------------------------------

test("PRODUCT_COMPLIANCE_EFFECTIVE_STATUS has 13 unique values", () => {
  const values = allEnumValues(PRODUCT_COMPLIANCE_EFFECTIVE_STATUS);
  assert.equal(values.length, 13);
  assert.equal(new Set(values).size, 13);
  for (const value of values) {
    assert.equal(isValidProductComplianceEffectiveStatus(value), true);
  }
});

test("exactly 2 statuses are checkout/visibility eligible; every other status fails closed", () => {
  assert.deepEqual(PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES, [
    "verified_valid",
    "verified_expiring_soon",
  ]);
  const allStatuses = allEnumValues(PRODUCT_COMPLIANCE_EFFECTIVE_STATUS);
  const eligible = allStatuses.filter((s) => isProductComplianceEligibleStatus(s));
  const failClosed = allStatuses.filter((s) => !isProductComplianceEligibleStatus(s));
  assert.deepEqual(eligible.sort(), ["verified_expiring_soon", "verified_valid"]);
  assert.equal(failClosed.length, 11);
  // Explicitly prove every individually-named fail-closed status from the
  // plan's §5.5 table is NOT eligible — not just "the majority."
  for (const mustFailClosed of [
    "expired_grace",
    "expired_blocked",
    "revoked",
    "rejected",
    "policy_unresolved",
    "unreadable",
    "evidence_missing",
    "calculating",
    "stale",
    "error",
    "unknown",
  ]) {
    assert.equal(
      isProductComplianceEligibleStatus(mustFailClosed),
      false,
      `"${mustFailClosed}" must fail closed`
    );
  }
});

test("isProductComplianceEligibleStatus rejects an unrecognized future status too (positive allowlist, not a negative check)", () => {
  // The defect this Slice 1 constant exists to prevent: a negative
  // `!= 'evidence_missing'` check would incorrectly pass a brand-new,
  // never-enumerated status value. The positive allowlist does not.
  assert.equal(isProductComplianceEligibleStatus("some_future_status_nobody_added_yet"), false);
});

test("active evidence refs bound is exactly 10; required-slots bound is exactly 5", () => {
  assert.equal(PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS, 10);
  assert.equal(PRODUCT_COMPLIANCE_DECISION_MAX_REQUIRED_SLOTS, 5);
  assert.equal(isWithinActiveEvidenceRefsBound(new Array(10).fill({})), true);
  assert.equal(isWithinActiveEvidenceRefsBound(new Array(11).fill({})), false);
  assert.equal(isWithinActiveEvidenceRefsBound([]), true);
  assert.equal(isWithinActiveEvidenceRefsBound("not-an-array"), false);
  assert.equal(isWithinRequiredEvidenceSlotsBound(new Array(5).fill({})), true);
  assert.equal(isWithinRequiredEvidenceSlotsBound(new Array(6).fill({})), false);
});

test("hasOnlyAllowedProductComplianceDecisionFields rejects an out-of-schema field", () => {
  assert.equal(
    hasOnlyAllowedProductComplianceDecisionFields({
      businessId: "biz-1",
      effectiveStatus: "verified_valid",
      activeEvidenceRefs: [],
    }),
    true
  );
  assert.equal(
    hasOnlyAllowedProductComplianceDecisionFields({
      businessId: "biz-1",
      productEvidenceLinksSnapshot: ["unbounded", "scan", "not", "allowed", "here"],
    }),
    false
  );
});

// ---------------------------------------------------------------------
// Slice 4.3 (Revision 6 correction 35, Revision 8): LOOKUP_LIMIT/
// MATCHED_SCOPE_CAP, the corrected productEvidenceLinks schema, and the
// productComplianceDecisions allowlist's pre-existing
// productInputRevisionSnapshot gap.
// ---------------------------------------------------------------------

test("LOOKUP_LIMIT is exactly 3 and MATCHED_SCOPE_CAP is exactly 10", () => {
  assert.equal(LOOKUP_LIMIT, 3);
  assert.equal(MATCHED_SCOPE_CAP, 10);
});

test("PRODUCT_EVIDENCE_LINK_ALLOWED_FIELDS is exactly the six frozen fields, no more", () => {
  assert.deepEqual(
    [...PRODUCT_EVIDENCE_LINK_ALLOWED_FIELDS].sort(),
    ["businessId", "documentId", "linkedAt", "matchedVia", "productId", "scopeId"]
  );
  assert.equal(Object.isFrozen(PRODUCT_EVIDENCE_LINK_ALLOWED_FIELDS), true);
});

test("PRODUCT_EVIDENCE_LINK_ALLOWED_FIELDS no longer contains linkedBy, scopeType, or matchReasonCode", () => {
  for (const obsolete of ["linkedBy", "scopeType", "matchReasonCode"]) {
    assert.equal(PRODUCT_EVIDENCE_LINK_ALLOWED_FIELDS.includes(obsolete), false, `${obsolete} must be removed`);
  }
});

test("COMPLIANCE_EVIDENCE_LINK_MATCH_TYPE is preserved, aliasing COMPLIANCE_SCOPE_TYPE's 7 values unchanged", () => {
  assert.deepEqual(COMPLIANCE_EVIDENCE_LINK_MATCH_TYPE, COMPLIANCE_SCOPE_TYPE);
});

test("PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS includes productInputRevisionSnapshot (pre-existing schema gap corrected)", () => {
  assert.ok(PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS.includes("productInputRevisionSnapshot"));
  assert.equal(
    hasOnlyAllowedProductComplianceDecisionFields({
      businessId: "biz-1",
      productInputRevisionSnapshot: 3,
      effectiveStatus: "verified_valid",
    }),
    true
  );
});

// ---------------------------------------------------------------------
// Revision 9 correction 51 (master plan §4/§10.1) —
// sellerRelationshipSnapshot added to productComplianceDecisions,
// independent of productInputRevisionSnapshot.
// ---------------------------------------------------------------------

test("PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS contains sellerRelationshipSnapshot exactly once, in Revision 9 order immediately after productInputRevisionSnapshot", () => {
  const fields = PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS;
  assert.equal(fields.filter((f) => f === "sellerRelationshipSnapshot").length, 1);
  const revisionIndex = fields.indexOf("productInputRevisionSnapshot");
  const snapshotIndex = fields.indexOf("sellerRelationshipSnapshot");
  assert.equal(snapshotIndex, revisionIndex + 1);
});

// Marketplace Revision 31 §C / Revision 35 §0.33 (Slice 7A) — the frozen
// pilot classification vocabulary.

test("PILOT_PRODUCT_CLASS is exactly the four frozen identifiers, frozen and byte-exact", () => {
  assert.deepEqual(Object.keys(PILOT_PRODUCT_CLASS).sort(), [
    "NON_BIOCIDAL_LITTER",
    "NON_MEDICINAL_TREATS",
    "SEALED_DRY_FOOD",
    "SEALED_WET_FOOD",
  ]);
  assert.deepEqual([...PILOT_PRODUCT_CLASS_VALUES].sort(), [
    "non_biocidal_litter",
    "non_medicinal_treats",
    "sealed_dry_food",
    "sealed_wet_food",
  ]);
  assert.equal(Object.isFrozen(PILOT_PRODUCT_CLASS), true);
  assert.equal(Object.isFrozen(PILOT_PRODUCT_CLASS_VALUES), true);
});

test("isValidPilotProductClass accepts exactly the four values and coerces nothing into validity", () => {
  for (const value of PILOT_PRODUCT_CLASS_VALUES) {
    assert.equal(isValidPilotProductClass(value), true, value);
  }
  const rejected = [
    undefined, null, "", "   ", 0, 1, true, false, [], {},
    // Casing, spacing and separator variants of a real value.
    "SEALED_DRY_FOOD", "Sealed_Dry_Food", " sealed_dry_food", "sealed_dry_food ",
    "sealed-dry-food", "sealeddryfood", "sealed_dry_foods", "dry_food",
    // The approval-category vocabulary, which is a different closed set and
    // must never be interchangeable with this one.
    "food", "treats", "litter", "toys", "collars_leads", "beds", "bowls",
    "grooming_tools",
    // A seller's own draft `category` string.
    "Food > Dry Food", "Health > Vitamins",
    // The families the pilot deliberately excludes.
    "medicinal_treats", "biocidal_litter", "vitamins", "supplements",
    "prescription_food", "flea_and_tick", "pesticide",
  ];
  for (const value of rejected) {
    assert.equal(isValidPilotProductClass(value), false, String(value));
  }
});

test("PILOT_CLASSIFICATION_MAX_REASON_LENGTH is a positive integer bound", () => {
  assert.equal(Number.isInteger(PILOT_CLASSIFICATION_MAX_REASON_LENGTH), true);
  assert.ok(PILOT_CLASSIFICATION_MAX_REASON_LENGTH > 0);
});

test("PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS is exactly the 13 fields (12 Revision 9 + Revision 35's pilotProductClassSnapshot), no alias, no extra field", () => {
  // Marketplace Revision 35 §0.33 E1 — the class a decision was computed
  // under joins the closed set immediately after sellerRelationshipSnapshot,
  // for the same reason and by the same mechanism: it is a bound
  // decisionHash input that the evaluator re-verifies against live state.
  assert.deepEqual(
    [...PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS],
    [
      "businessId",
      "policyVersion",
      "evidenceRevision",
      "productInputRevisionSnapshot",
      "sellerRelationshipSnapshot",
      "pilotProductClassSnapshot",
      "requiredEvidenceSlots",
      "satisfiedEvidenceSlots",
      "activeEvidenceRefs",
      "computedAt",
      "validUntil",
      "effectiveStatus",
      "decisionHash",
    ]
  );
  assert.equal(Object.isFrozen(PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS), true);
});

test("hasOnlyAllowedProductComplianceDecisionFields accepts a decision carrying sellerRelationshipSnapshot alongside productInputRevisionSnapshot and rejects an unknown field", () => {
  const validDecision = {
    businessId: "biz-1",
    policyVersion: "v1",
    evidenceRevision: 2,
    productInputRevisionSnapshot: 3,
    sellerRelationshipSnapshot: "reseller",
    requiredEvidenceSlots: [],
    satisfiedEvidenceSlots: [],
    activeEvidenceRefs: [],
    computedAt: { toMillis: () => 1_800_000_000_000 },
    validUntil: null,
    effectiveStatus: "verified_valid",
    decisionHash: "a".repeat(64),
  };
  assert.equal(hasOnlyAllowedProductComplianceDecisionFields(validDecision), true);
  assert.equal(
    hasOnlyAllowedProductComplianceDecisionFields({ ...validDecision, unknownField: "x" }),
    false
  );
});

test("SELLER_RELATIONSHIP and COMPLIANCE_SCOPE_TYPE remain exactly the six/seven documented values, unchanged by Slice 4.3", () => {
  assert.deepEqual(
    Object.values(SELLER_RELATIONSHIP).sort(),
    ["authorized_dealer", "authorized_distributor", "brand_owner", "importer", "manufacturer", "reseller"]
  );
  assert.equal(Object.values(COMPLIANCE_SCOPE_TYPE).length, 7);
});

test("COMPLIANCE_SCOPE_ALLOWED_FIELDS still carries sellerRelationship, unaffected by the Slice 4.3 correction", () => {
  assert.ok(constants.COMPLIANCE_SCOPE_ALLOWED_FIELDS.includes("sellerRelationship"));
});

// ---------------------------------------------------------------------
// Cross-collection sanity: no P1-C-only vocabulary leaked into P1-A
// constants (channel names, connector fields, external-order concepts).
// ---------------------------------------------------------------------

test("no P1-C connector/channel vocabulary appears anywhere in the exported constants", () => {
  const serialized = JSON.stringify(constants);
  for (const forbidden of [
    "trendyol",
    "hepsiburada",
    "n11",
    "channelConnections",
    "externalListings",
    "externalDemandHolds",
    "externalPendingHold",
    "stockAuthorityFeedMode",
  ]) {
    assert.equal(
      serialized.toLowerCase().includes(forbidden.toLowerCase()),
      false,
      `forbidden P1-C term "${forbidden}" found in complianceConstants.js`
    );
  }
});
