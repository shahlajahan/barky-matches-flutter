"use strict";

// Petsupo Marketplace P1-A compliance foundation — pure validator
// functions over complianceConstants.js. No exports.*, no Cloud
// Function, no trigger, no Admin SDK call, no Firestore access of any
// kind — every function here takes plain JS values and returns a plain
// JS value (docs/plans/marketplace_p1a_compliance_review_implementation_
// plan_2026-08-21.md, Slice 1). Later slices' server operations are
// expected to import these rather than re-deriving equivalent checks.

const crypto = require("node:crypto");
const {
  STOCK_AUTHORITY_TYPE,
  STOCK_AUTHORITY_TYPE_REACHABLE_IN_P1A,
  BUSINESS_INVENTORY_POLICY_STATUS,
  BUSINESS_INVENTORY_POLICY_STATUS_REACHABLE_IN_P1A,
  BUSINESS_INVENTORY_POLICY_ALLOWED_FIELDS,
  COMPLIANCE_UPLOAD_SESSION_STATUS,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_TRANSITIONS,
  COMPLIANCE_UPLOAD_SESSION_TERMINAL_STATUSES,
  COMPLIANCE_UPLOAD_SESSION_UPLOAD_ELIGIBLE_STATUS,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES,
  COMPLIANCE_UPLOAD_SESSION_MIME_TO_EXTENSION,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_FIELDS,
  COMPLIANCE_UPLOAD_SESSION_REQUEST_ALLOWED_FIELDS,
  COMPLIANCE_QUARANTINE_PATH_PREFIX,
  COMPLIANCE_DOCS_PATH_PREFIX,
  COMPLIANCE_DOCUMENT_TYPE,
  SELLER_RELATIONSHIP,
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_DOCUMENT_SERVER_OWNED_FIELDS,
  COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS,
  COMPLIANCE_DOCUMENT_ALLOWED_FIELDS,
  COMPLIANCE_DOCUMENT_ALLOWED_TRANSITIONS,
  COMPLIANCE_DOCUMENT_TERMINAL_STATUSES,
  COMPLIANCE_SCOPE_CREATION_ELIGIBLE_DOCUMENT_STATUSES,
  COMPLIANCE_SCOPE_TYPE,
  COMPLIANCE_SCOPE_STATUS,
  COMPLIANCE_SCOPE_ALLOWED_FIELDS,
  COMPLIANCE_SCOPE_ALLOWED_TRANSITIONS,
  COMPLIANCE_SCOPE_TERMINAL_STATUSES,
  COMPLIANCE_SCOPE_MEMBER_LIFECYCLE_ELIGIBLE_SCOPE_STATUSES,
  COMPLIANCE_SCOPE_MEMBER_REJECTION_ELIGIBLE_SCOPE_STATUSES,
  COMPLIANCE_SCOPE_MEMBER_IDENTIFIER_TYPE,
  COMPLIANCE_SCOPE_MEMBER_STATUS,
  COMPLIANCE_SCOPE_MEMBER_ALLOWED_FIELDS,
  COMPLIANCE_SCOPE_MEMBER_ALLOWED_TRANSITIONS,
  COMPLIANCE_SCOPE_MEMBER_TERMINAL_STATUSES,
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

function hasOnlyAllowedComplianceUploadSessionRequestFields(payload) {
  return hasOnlyAllowedKeys(payload, COMPLIANCE_UPLOAD_SESSION_REQUEST_ALLOWED_FIELDS);
}

// Single source of truth for "is this status transition allowed" — used
// by createComplianceUploadSession, the finalize pipeline, and the scan
// orchestrator alike, so the transition table in complianceConstants.js
// is enforced identically everywhere rather than re-checked ad hoc.
function isAllowedComplianceUploadSessionTransition(fromStatus, toStatus) {
  const allowedNext = COMPLIANCE_UPLOAD_SESSION_ALLOWED_TRANSITIONS[fromStatus];
  return Array.isArray(allowedNext) && allowedNext.includes(toStatus);
}

function isTerminalComplianceUploadSessionStatus(status) {
  return COMPLIANCE_UPLOAD_SESSION_TERMINAL_STATUSES.includes(status);
}

function isComplianceUploadSessionUploadEligible(session) {
  return (
    session != null &&
    session.status === COMPLIANCE_UPLOAD_SESSION_UPLOAD_ELIGIBLE_STATUS
  );
}

// Server-generated quarantine object path — the single builder every
// caller (session creation, Storage Rules documentation/tests, the
// finalize pipeline) must use, so the path shape can never drift between
// them. Deliberately takes no client-supplied segment.
function buildComplianceQuarantineObjectPath({ businessId, sessionId, objectId }) {
  return `${COMPLIANCE_QUARANTINE_PATH_PREFIX}/${businessId}/${sessionId}/${objectId}`;
}

function buildComplianceDocsObjectPath({ businessId, documentId, objectId }) {
  return `${COMPLIANCE_DOCS_PATH_PREFIX}/${businessId}/${documentId}/${objectId}`;
}

// Deterministic, extension-free-of-client-input object ID: a
// cryptographically unpredictable token plus a server-chosen extension
// derived only from the already-validated MIME type, never from the
// client's original filename (prevents path/extension tricks by
// construction, not by sanitizing an untrusted value).
function buildComplianceUploadObjectId(randomToken, mimeType) {
  const extension = COMPLIANCE_UPLOAD_SESSION_MIME_TO_EXTENSION[mimeType];
  if (!extension) {
    throw new Error(`No server-chosen extension for MIME type "${mimeType}"`);
  }
  return `${randomToken}.${extension}`;
}

// Slice 2.1 correction (part G) — server-side canary allowlist for
// compliance upload session creation. `rawAllowlist` is the exact
// deploy-time string configured via defineString(
// "COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS") — the same repository
// convention already used for CLAMAV_CLOUD_RUN_URL/_AUDIENCE (a plain
// Functions params value, never a Firestore document a client could
// read or write, never a request field a caller supplies or influences
// in any way). A comma-separated list of exact businessId values;
// absence, an empty string, or a value that parses to zero entries all
// mean "allow nobody" — deny-by-default is the only possible outcome of
// a missing/malformed/unset config, never an accidental allow-all.
function parseComplianceUploadCanaryAllowlist(rawAllowlist) {
  if (typeof rawAllowlist !== "string") return [];
  return rawAllowlist
    .split(",")
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

function isComplianceUploadCanaryEnabledForBusiness(businessId, rawAllowlist) {
  if (typeof businessId !== "string" || businessId.length === 0) return false;
  const allowlist = parseComplianceUploadCanaryAllowlist(rawAllowlist);
  return allowlist.includes(businessId);
}

// Immutable request fields an idempotent retry must match exactly against
// the originally-stored session (Slice 2 correction, finding C/D). Deliberately
// excludes issuedBy/businessId here — those are checked separately by the
// caller against auth/request context, not against the stored session's own
// copy of themselves (which would be a tautology).
const COMPLIANCE_UPLOAD_SESSION_IDEMPOTENCY_COMPARISON_FIELDS = Object.freeze([
  "originalFilename",
  "declaredMimeType",
  "declaredSizeBytes",
  "documentType",
]);

// True only if every immutable field of a retried request matches the
// originally-stored session exactly. A stricter, non-boolean-blind check
// than "does a session exist for this key" — a retry with the same
// clientIdempotencyKey but different file metadata must never silently
// reuse the original session (docs/plans/... Slice 2 security decision;
// Slice 2 correction, finding C).
function doesRequestMatchStoredSession(storedSession, normalizedRequest) {
  if (!storedSession || !normalizedRequest) return false;
  return COMPLIANCE_UPLOAD_SESSION_IDEMPOTENCY_COMPARISON_FIELDS.every(
    (field) => storedSession[field] === normalizedRequest[field]
  );
}

// ---------------------------------------------------------------------
// Upload session quota (Slice 2 correction, finding B)
// ---------------------------------------------------------------------

// UTC calendar-day bucket key, e.g. "2026-08-21" — the daily quota resets
// naturally at UTC midnight simply because a new key starts being used;
// no explicit reset job exists or is needed.
function getUtcDateKey(date) {
  const d = date instanceof Date ? date : new Date(date);
  return d.toISOString().slice(0, 10);
}

// Deterministic, collision-free scope id for a (businessId, uid) pair —
// same composite-key-hash convention as deriveSessionId in
// complianceUploadSessions.js, so cross-tenant collision is not possible.
function buildComplianceUploadQuotaScopeId({ businessId, uid }) {
  return crypto
    .createHash("sha256")
    .update(`compliance_upload_quota_scope:${businessId}:${uid}`)
    .digest("hex");
}

function buildComplianceUploadQuotaDailyDocId({ businessId, uid, utcDateKey }) {
  return crypto
    .createHash("sha256")
    .update(`compliance_upload_quota_daily:${businessId}:${uid}:${utcDateKey}`)
    .digest("hex");
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

// Slice 3 — same single-source-of-truth convention as
// isAllowedComplianceUploadSessionTransition.
function isAllowedComplianceDocumentTransition(fromStatus, toStatus) {
  const allowedNext = COMPLIANCE_DOCUMENT_ALLOWED_TRANSITIONS[fromStatus];
  return Array.isArray(allowedNext) && allowedNext.includes(toStatus);
}

function isTerminalComplianceDocumentStatus(status) {
  return COMPLIANCE_DOCUMENT_TERMINAL_STATUSES.includes(status);
}

// Slice 3 correction (TOCTOU finding) — the positive allowlist
// addComplianceScope's own transaction re-checks fresh via tx.get.
function isDocumentEligibleForScopeCreation(status) {
  return COMPLIANCE_SCOPE_CREATION_ELIGIBLE_DOCUMENT_STATUSES.includes(status);
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

function isAllowedComplianceScopeTransition(fromStatus, toStatus) {
  const allowedNext = COMPLIANCE_SCOPE_ALLOWED_TRANSITIONS[fromStatus];
  return Array.isArray(allowedNext) && allowedNext.includes(toStatus);
}

function isTerminalComplianceScopeStatus(status) {
  return COMPLIANCE_SCOPE_TERMINAL_STATUSES.includes(status);
}

// Slice 3 correction (adversarial review, Correction A/B) — the positive
// allowlist addComplianceScopeMembers and reviewComplianceScopeMembers's
// `approve` decision both re-check fresh, inside their own
// transactions, against the PARENT scope's status. Never a
// `!== 'rejected'` negative check. NEVER used for `reject` — see
// isScopeEligibleForMemberRejection below.
function isScopeEligibleForMemberLifecycle(status) {
  return COMPLIANCE_SCOPE_MEMBER_LIFECYCLE_ELIGIBLE_SCOPE_STATUSES.includes(status);
}

// Second adversarial-review pass — the decision-specific, wider
// allowlist for reviewComplianceScopeMembers's `reject` decision only.
// Rejecting never grants trust, so it remains legal even beneath an
// already-`rejected` parent scope (closing the "stranded pending
// member" defect) — while approval remains gated exclusively by
// isScopeEligibleForMemberLifecycle above, unchanged and unwidened.
function isScopeEligibleForMemberRejection(status) {
  return COMPLIANCE_SCOPE_MEMBER_REJECTION_ELIGIBLE_SCOPE_STATUSES.includes(status);
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

function isAllowedComplianceScopeMemberTransition(fromStatus, toStatus) {
  const allowedNext = COMPLIANCE_SCOPE_MEMBER_ALLOWED_TRANSITIONS[fromStatus];
  return Array.isArray(allowedNext) && allowedNext.includes(toStatus);
}

function isTerminalComplianceScopeMemberStatus(status) {
  return COMPLIANCE_SCOPE_MEMBER_TERMINAL_STATUSES.includes(status);
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
  hasOnlyAllowedComplianceUploadSessionRequestFields,
  isAllowedComplianceUploadSessionTransition,
  isTerminalComplianceUploadSessionStatus,
  isComplianceUploadSessionUploadEligible,
  buildComplianceQuarantineObjectPath,
  buildComplianceDocsObjectPath,
  buildComplianceUploadObjectId,
  parseComplianceUploadCanaryAllowlist,
  isComplianceUploadCanaryEnabledForBusiness,
  doesRequestMatchStoredSession,
  getUtcDateKey,
  buildComplianceUploadQuotaScopeId,
  buildComplianceUploadQuotaDailyDocId,

  isValidComplianceDocumentType,
  isValidSellerRelationship,
  isValidComplianceDocumentStatus,
  hasOnlyAllowedComplianceDocumentFields,
  isServerOwnedComplianceDocumentField,
  isImmutableComplianceDocumentField,
  isSafeComplianceDocumentSellerUpdate,
  isAllowedComplianceDocumentTransition,
  isTerminalComplianceDocumentStatus,
  isDocumentEligibleForScopeCreation,

  isValidComplianceScopeType,
  isValidComplianceScopeStatus,
  hasOnlyAllowedComplianceScopeFields,
  isAllowedComplianceScopeTransition,
  isTerminalComplianceScopeStatus,
  isScopeEligibleForMemberLifecycle,
  isScopeEligibleForMemberRejection,

  isValidComplianceScopeMemberIdentifierType,
  isValidComplianceScopeMemberStatus,
  hasOnlyAllowedComplianceScopeMemberFields,
  isAllowedComplianceScopeMemberTransition,
  isTerminalComplianceScopeMemberStatus,

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
