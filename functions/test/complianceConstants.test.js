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
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_DOCUMENT_SERVER_OWNED_FIELDS,
  COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS,
  COMPLIANCE_DOCUMENT_ALLOWED_FIELDS,
  COMPLIANCE_SCOPE_TYPE,
  COMPLIANCE_SCOPE_STATUS,
  COMPLIANCE_SCOPE_MEMBER_IDENTIFIER_TYPE,
  COMPLIANCE_SCOPE_MEMBER_STATUS,
  COMPLIANCE_REVIEW_EVENT_TARGET_TYPE,
  COMPLIANCE_REVIEW_EVENT_ACTION,
  COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE,
  COMPLIANCE_POLICY_REGISTRY_STATUS,
  PRODUCT_COMPLIANCE_EFFECTIVE_STATUS,
  PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES,
  PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS,
  PRODUCT_COMPLIANCE_DECISION_MAX_REQUIRED_SLOTS,
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

test("compliancePolicyRegistry status is draft/active/inactive, only one ever active by convention", () => {
  assert.deepEqual(allEnumValues(COMPLIANCE_POLICY_REGISTRY_STATUS).sort(), [
    "active",
    "draft",
    "inactive",
  ]);
  assert.equal(isValidCompliancePolicyRegistryStatus("inactive"), true);
  assert.equal(isValidCompliancePolicyRegistryStatus("archived"), false);
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
