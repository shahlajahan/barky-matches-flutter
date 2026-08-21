"use strict";

// Petsupo Marketplace P1-A compliance foundation — pure validator
// functions over complianceConstants.js. No exports.*, no Cloud
// Function, no trigger, no Admin SDK call, no Firestore access of any
// kind — every function here takes plain JS values and returns a plain
// JS value (docs/plans/marketplace_p1a_compliance_review_implementation_
// plan_2026-08-21.md, Slice 1). Later slices' server operations are
// expected to import these rather than re-deriving equivalent checks.

const {
  STOCK_AUTHORITY_TYPE,
  STOCK_AUTHORITY_TYPE_REACHABLE_IN_P1A,
  BUSINESS_INVENTORY_POLICY_STATUS,
  BUSINESS_INVENTORY_POLICY_STATUS_REACHABLE_IN_P1A,
  BUSINESS_INVENTORY_POLICY_ALLOWED_FIELDS,
  COMPLIANCE_UPLOAD_SESSION_STATUS,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_FIELDS,
  COMPLIANCE_DOCUMENT_TYPE,
  SELLER_RELATIONSHIP,
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_DOCUMENT_SERVER_OWNED_FIELDS,
  COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS,
  COMPLIANCE_DOCUMENT_ALLOWED_FIELDS,
  COMPLIANCE_SCOPE_TYPE,
  COMPLIANCE_SCOPE_STATUS,
  COMPLIANCE_SCOPE_ALLOWED_FIELDS,
  COMPLIANCE_SCOPE_MEMBER_IDENTIFIER_TYPE,
  COMPLIANCE_SCOPE_MEMBER_STATUS,
  COMPLIANCE_SCOPE_MEMBER_ALLOWED_FIELDS,
  COMPLIANCE_REVIEW_EVENT_TARGET_TYPE,
  COMPLIANCE_REVIEW_EVENT_ACTION,
  COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE,
  COMPLIANCE_REVIEW_EVENT_ALLOWED_FIELDS,
  COMPLIANCE_POLICY_REGISTRY_STATUS,
  COMPLIANCE_POLICY_REGISTRY_ALLOWED_FIELDS,
  PRODUCT_COMPLIANCE_EFFECTIVE_STATUS,
  PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES,
  PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS,
  PRODUCT_COMPLIANCE_DECISION_MAX_REQUIRED_SLOTS,
  PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS,
} = require("./complianceConstants");

function isEnumMember(value, enumObject) {
  return typeof value === "string" && Object.values(enumObject).includes(value);
}

function hasOnlyAllowedKeys(payload, allowedFields) {
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    return false;
  }
  const allowed = new Set(allowedFields);
  return Object.keys(payload).every((key) => allowed.has(key));
}

// Mirrors the Firestore Rules "diff().affectedKeys()" check in plain JS:
// given the field(s) that actually changed between two documents, is the
// change confined to fields that are NOT in the protected set?
function changedKeysExcludeProtectedFields(beforeDoc, afterDoc, protectedFields) {
  const protectedSet = new Set(protectedFields);
  const beforeKeys = new Set(Object.keys(beforeDoc || {}));
  const afterKeys = new Set(Object.keys(afterDoc || {}));
  const changed = new Set();
  for (const key of afterKeys) {
    if (!beforeKeys.has(key) || beforeDoc[key] !== afterDoc[key]) {
      changed.add(key);
    }
  }
  for (const key of beforeKeys) {
    if (!afterKeys.has(key)) {
      changed.add(key);
    }
  }
  for (const key of changed) {
    if (protectedSet.has(key)) {
      return false;
    }
  }
  return true;
}

// ---------------------------------------------------------------------
// businessInventoryPolicies
// ---------------------------------------------------------------------

function isValidStockAuthorityType(value) {
  return isEnumMember(value, STOCK_AUTHORITY_TYPE);
}

function isStockAuthorityTypeReachableInP1A(value) {
  return STOCK_AUTHORITY_TYPE_REACHABLE_IN_P1A.includes(value);
}

function isValidBusinessInventoryPolicyStatus(value) {
  return isEnumMember(value, BUSINESS_INVENTORY_POLICY_STATUS);
}

function isBusinessInventoryPolicyStatusReachableInP1A(value) {
  return BUSINESS_INVENTORY_POLICY_STATUS_REACHABLE_IN_P1A.includes(value);
}

function hasOnlyAllowedBusinessInventoryPolicyFields(payload) {
  return hasOnlyAllowedKeys(payload, BUSINESS_INVENTORY_POLICY_ALLOWED_FIELDS);
}

// ---------------------------------------------------------------------
// complianceUploadSessions
// ---------------------------------------------------------------------

function isValidComplianceUploadSessionStatus(value) {
  return isEnumMember(value, COMPLIANCE_UPLOAD_SESSION_STATUS);
}

function isAllowedComplianceUploadMimeType(value) {
  return (
    typeof value === "string" &&
    COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES.includes(value)
  );
}

function hasOnlyAllowedComplianceUploadSessionFields(payload) {
  return hasOnlyAllowedKeys(payload, COMPLIANCE_UPLOAD_SESSION_ALLOWED_FIELDS);
}

// ---------------------------------------------------------------------
// complianceDocuments
// ---------------------------------------------------------------------

function isValidComplianceDocumentType(value) {
  return isEnumMember(value, COMPLIANCE_DOCUMENT_TYPE);
}

function isValidSellerRelationship(value) {
  return isEnumMember(value, SELLER_RELATIONSHIP);
}

function isValidComplianceDocumentStatus(value) {
  return isEnumMember(value, COMPLIANCE_DOCUMENT_STATUS);
}

function hasOnlyAllowedComplianceDocumentFields(payload) {
  return hasOnlyAllowedKeys(payload, COMPLIANCE_DOCUMENT_ALLOWED_FIELDS);
}

function isServerOwnedComplianceDocumentField(fieldName) {
  return COMPLIANCE_DOCUMENT_SERVER_OWNED_FIELDS.includes(fieldName);
}

function isImmutableComplianceDocumentField(fieldName) {
  return COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS.includes(fieldName);
}

// A seller-initiated update may never touch a server-owned OR an
// immutable field — every complianceDocuments field is one or the other,
// so this is equivalent to "no field may change under a seller write."
// Kept as a named function (rather than inlined at each call site) so
// later slices share one definition of "what counts as a disallowed
// change" instead of re-deriving it.
function isSafeComplianceDocumentSellerUpdate(beforeDoc, afterDoc) {
  return changedKeysExcludeProtectedFields(
    beforeDoc,
    afterDoc,
    COMPLIANCE_DOCUMENT_SERVER_OWNED_FIELDS.concat(COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS)
  );
}

// ---------------------------------------------------------------------
// complianceDocumentScopes
// ---------------------------------------------------------------------

function isValidComplianceScopeType(value) {
  return isEnumMember(value, COMPLIANCE_SCOPE_TYPE);
}

function isValidComplianceScopeStatus(value) {
  return isEnumMember(value, COMPLIANCE_SCOPE_STATUS);
}

function hasOnlyAllowedComplianceScopeFields(payload) {
  return hasOnlyAllowedKeys(payload, COMPLIANCE_SCOPE_ALLOWED_FIELDS);
}

// ---------------------------------------------------------------------
// complianceDocumentScopes/{scopeId}/members
// ---------------------------------------------------------------------

function isValidComplianceScopeMemberIdentifierType(value) {
  return isEnumMember(value, COMPLIANCE_SCOPE_MEMBER_IDENTIFIER_TYPE);
}

function isValidComplianceScopeMemberStatus(value) {
  return isEnumMember(value, COMPLIANCE_SCOPE_MEMBER_STATUS);
}

function hasOnlyAllowedComplianceScopeMemberFields(payload) {
  return hasOnlyAllowedKeys(payload, COMPLIANCE_SCOPE_MEMBER_ALLOWED_FIELDS);
}

// ---------------------------------------------------------------------
// complianceReviewEvents
// ---------------------------------------------------------------------

function isValidComplianceReviewEventTargetType(value) {
  return isEnumMember(value, COMPLIANCE_REVIEW_EVENT_TARGET_TYPE);
}

function isValidComplianceReviewEventAction(value) {
  return isEnumMember(value, COMPLIANCE_REVIEW_EVENT_ACTION);
}

function isValidComplianceReviewEventActorRole(value) {
  return isEnumMember(value, COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE);
}

function hasOnlyAllowedComplianceReviewEventFields(payload) {
  return hasOnlyAllowedKeys(payload, COMPLIANCE_REVIEW_EVENT_ALLOWED_FIELDS);
}

// ---------------------------------------------------------------------
// compliancePolicyRegistry
// ---------------------------------------------------------------------

function isValidCompliancePolicyRegistryStatus(value) {
  return isEnumMember(value, COMPLIANCE_POLICY_REGISTRY_STATUS);
}

function hasOnlyAllowedCompliancePolicyRegistryFields(payload) {
  return hasOnlyAllowedKeys(payload, COMPLIANCE_POLICY_REGISTRY_ALLOWED_FIELDS);
}

// ---------------------------------------------------------------------
// productComplianceDecisions
// ---------------------------------------------------------------------

function isValidProductComplianceEffectiveStatus(value) {
  return isEnumMember(value, PRODUCT_COMPLIANCE_EFFECTIVE_STATUS);
}

// The single positive-allowlist check every eligibility surface must use
// (docs/plans/... §5.5/§11, correction 5) — never a negative/"!=" check.
function isProductComplianceEligibleStatus(value) {
  return PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES.includes(value);
}

function isWithinActiveEvidenceRefsBound(activeEvidenceRefs) {
  return (
    Array.isArray(activeEvidenceRefs) &&
    activeEvidenceRefs.length <= PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS
  );
}

function isWithinRequiredEvidenceSlotsBound(requiredEvidenceSlots) {
  return (
    Array.isArray(requiredEvidenceSlots) &&
    requiredEvidenceSlots.length <= PRODUCT_COMPLIANCE_DECISION_MAX_REQUIRED_SLOTS
  );
}

function hasOnlyAllowedProductComplianceDecisionFields(payload) {
  return hasOnlyAllowedKeys(payload, PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS);
}

module.exports = {
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
  hasOnlyAllowedComplianceUploadSessionFields,

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
  hasOnlyAllowedComplianceScopeMemberFields,

  isValidComplianceReviewEventTargetType,
  isValidComplianceReviewEventAction,
  isValidComplianceReviewEventActorRole,
  hasOnlyAllowedComplianceReviewEventFields,

  isValidCompliancePolicyRegistryStatus,
  hasOnlyAllowedCompliancePolicyRegistryFields,

  isValidProductComplianceEffectiveStatus,
  isProductComplianceEligibleStatus,
  isWithinActiveEvidenceRefsBound,
  isWithinRequiredEvidenceSlotsBound,
  hasOnlyAllowedProductComplianceDecisionFields,
};
