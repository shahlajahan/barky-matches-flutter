"use strict";

// Petsupo Marketplace P1-A compliance foundation — pure schema/constants
// only (docs/plans/marketplace_p1a_compliance_review_implementation_plan_
// 2026-08-21.md, Slice 1). No exports.*, no Cloud Function, no trigger,
// no Admin SDK call anywhere in this file — every value here is a plain
// JS literal, safe to import from a Rules-adjacent test or a future
// server operation without granting either any capability on its own.
//
// Everything P1-C-only (channel names, connector capabilities, stock
// authority feed modes, external listing/order fields) is deliberately
// absent. `STOCK_AUTHORITY_TYPE` below includes all 5 values from the
// architecture's `businessInventoryPolicies.stockAuthorityType` field
// definition because that is the field's full declared type domain, not
// because any P1-C connector behavior is implemented — only `manual`/
// `petsupo` are reachable through any P1-A code path.

const COMPLIANCE_SCHEMA_VERSION = 1;

// ---------------------------------------------------------------------
// businessInventoryPolicies/{businessId}
// ---------------------------------------------------------------------

const STOCK_AUTHORITY_TYPE = Object.freeze({
  MANUAL: "manual",
  PETSUPO: "petsupo",
  SELLER_ERP: "seller_erp",
  EXISTING_INTEGRATOR: "existing_integrator",
  EXTERNAL_CHANNEL: "external_channel",
});

// Only these two are reachable via any P1-A code path (no onboarding
// callable exists yet in Slice 1; this documents the eventual Slice 2+
// constraint so it can be enforced the moment a writer exists).
const STOCK_AUTHORITY_TYPE_REACHABLE_IN_P1A = Object.freeze([
  STOCK_AUTHORITY_TYPE.MANUAL,
  STOCK_AUTHORITY_TYPE.PETSUPO,
]);

const BUSINESS_INVENTORY_POLICY_STATUS = Object.freeze({
  ACTIVE: "active",
  TRANSITION_VALIDATING: "transition_validating",
  TRANSITION_PAUSED: "transition_paused",
  TRANSITION_BASELINE_ESTABLISHED: "transition_baseline_established",
  SUSPENDED: "suspended",
});

// Only reachable in P1-A — no authority-transition workflow exists until
// P1-C, so this is the sole status any P1-A-created document may hold.
const BUSINESS_INVENTORY_POLICY_STATUS_REACHABLE_IN_P1A = Object.freeze([
  BUSINESS_INVENTORY_POLICY_STATUS.ACTIVE,
]);

const BUSINESS_INVENTORY_POLICY_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "stockAuthorityType",
  "authorityConnectionId",
  "status",
  "defaultSafetyStock",
  "version",
  "updatedBy",
  "updatedAt",
  "effectiveAt",
]);

// ---------------------------------------------------------------------
// complianceUploadSessions/{sessionId}
// ---------------------------------------------------------------------

const COMPLIANCE_UPLOAD_SESSION_STATUS = Object.freeze({
  ISSUED: "issued",
  UPLOADED: "uploaded",
  VALIDATING: "validating",
  SCAN_PENDING: "scan_pending",
  CLEAN: "clean",
  FAILED: "failed",
  EXPIRED: "expired",
});

const COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES = Object.freeze([
  "application/pdf",
  "image/jpeg",
  "image/png",
]);

const COMPLIANCE_UPLOAD_SESSION_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "documentId",
  "objectPath",
  "documentType",
  "sellerRelationship",
  "allowedMimeTypes",
  "maxSizeBytes",
  "status",
  "issuedBy",
  "issuedAt",
  "expiresAt",
  "finalizedAt",
  "contentHash",
  "sizeBytes",
  "scanResultRef",
]);

// Proposed defaults (docs/plans/... §4, §20) — not yet read by any
// running code in Slice 1; documented here as the single source later
// slices must use rather than re-deriving their own numbers.
const COMPLIANCE_UPLOAD_SESSION_DEFAULT_EXPIRY_MINUTES = 15;
const COMPLIANCE_UPLOAD_ORPHAN_RETENTION_DAYS = 7;

// ---------------------------------------------------------------------
// complianceDocuments/{documentId}
// ---------------------------------------------------------------------

const COMPLIANCE_DOCUMENT_TYPE = Object.freeze({
  PURCHASE_INVOICE: "purchase_invoice",
  SUPPLIER_AGREEMENT: "supplier_agreement",
  AUTHORIZATION_LETTER: "authorization_letter",
  DEALERSHIP_DISTRIBUTION_AGREEMENT: "dealership_distribution_agreement",
  TRADEMARK_EVIDENCE: "trademark_evidence",
  MANUFACTURER_EVIDENCE: "manufacturer_evidence",
  IMPORTER_EVIDENCE: "importer_evidence",
  CATEGORY_COMPLIANCE_EVIDENCE: "category_compliance_evidence",
});

const SELLER_RELATIONSHIP = Object.freeze({
  BRAND_OWNER: "brand_owner",
  MANUFACTURER: "manufacturer",
  AUTHORIZED_DISTRIBUTOR: "authorized_distributor",
  AUTHORIZED_DEALER: "authorized_dealer",
  IMPORTER: "importer",
  RESELLER: "reseller",
});

// Session-level states (uploaded/validating/scan_pending) are
// deliberately absent — a complianceDocuments record is never created
// until its session reaches CLEAN (docs/plans/... §4/§5.0, correction 1).
const COMPLIANCE_DOCUMENT_STATUS = Object.freeze({
  CLEAN: "clean",
  PENDING_REVIEW: "pending_review",
  APPROVED: "approved",
  REJECTED: "rejected",
  REVOKED: "revoked",
  EXPIRED: "expired",
  SUPERSEDED: "superseded",
});

// Fields no seller write may ever set or change — every write to this
// collection happens exclusively through Admin SDK server operations
// introduced in later slices. Slice 1 ships no writer of this collection
// at all; this classification documents the contract those future
// operations (and their Rules) must honor, mirroring the P0.1-established
// pattern (f2048cf): server-owned fields belong in the closed allowed-
// field schema, never in a separate "must be absent" blacklist.
const COMPLIANCE_DOCUMENT_SERVER_OWNED_FIELDS = Object.freeze([
  "status",
  "reviewedBy",
  "reviewedAt",
  "rejectionReason",
  "infoRequestNote",
  "revokedBy",
  "revokedAt",
  "revocationReason",
  "supersededByDocumentId",
]);

// Set once at creation (by the Slice 2 scan-result handler, from the
// owning session) and never changed again by anyone, including admin.
const COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS = Object.freeze([
  "businessId",
  "sessionId",
  "documentType",
  "sellerRelationship",
  "storagePath",
  "originalFilename",
  "contentHash",
  "sizeBytes",
  "version",
  "supersedesDocumentId",
  "issuedAt",
  "validFrom",
  "validUntil",
  "uploadedBy",
  "uploadedAt",
]);

const COMPLIANCE_DOCUMENT_ALLOWED_FIELDS = Object.freeze([
  ...COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS,
  ...COMPLIANCE_DOCUMENT_SERVER_OWNED_FIELDS,
]);

// ---------------------------------------------------------------------
// complianceDocumentScopes/{scopeId}
// ---------------------------------------------------------------------

const COMPLIANCE_SCOPE_TYPE = Object.freeze({
  BUSINESS: "business",
  SUPPLIER: "supplier",
  BRAND: "brand",
  CATEGORY: "category",
  PRODUCT_FAMILY: "product_family",
  SKU_SET: "sku_set",
  PRODUCT: "product",
});

const COMPLIANCE_SCOPE_STATUS = Object.freeze({
  PENDING_REVIEW: "pending_review",
  APPROVED: "approved",
  REJECTED: "rejected",
});

const COMPLIANCE_SCOPE_ALLOWED_FIELDS = Object.freeze([
  "documentId",
  "businessId",
  "scopeType",
  "scopeValue",
  "memberCount",
  "status",
  "createdAt",
  "createdBy",
  "reviewedBy",
  "reviewedAt",
  "verifiedBrandId",
]);

// ---------------------------------------------------------------------
// complianceDocumentScopes/{scopeId}/members/{memberId}
// ---------------------------------------------------------------------

const COMPLIANCE_SCOPE_MEMBER_IDENTIFIER_TYPE = Object.freeze({
  BARCODE: "barcode",
  SKU: "sku",
});

const COMPLIANCE_SCOPE_MEMBER_STATUS = Object.freeze({
  PENDING_REVIEW: "pending_review",
  ACTIVE: "active",
  REVOKED: "revoked",
  REJECTED: "rejected",
});

const COMPLIANCE_SCOPE_MEMBER_ALLOWED_FIELDS = Object.freeze([
  "identifierType",
  "identifierValue",
  "status",
  "addedAt",
  "addedBy",
  "reviewedBy",
  "reviewedAt",
  "revokedAt",
  "revokedBy",
]);

// ---------------------------------------------------------------------
// productEvidenceLinks/{linkId}
// ---------------------------------------------------------------------

// Every link's matchedVia value is one of the scope types it was
// discovered through.
const COMPLIANCE_EVIDENCE_LINK_MATCH_TYPE = COMPLIANCE_SCOPE_TYPE;

const PRODUCT_EVIDENCE_LINK_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "productId",
  "documentId",
  "scopeId",
  "matchedVia",
  "linkedAt",
  "linkedBy",
]);

// ---------------------------------------------------------------------
// complianceReviewEvents/{eventId}
// ---------------------------------------------------------------------

const COMPLIANCE_REVIEW_EVENT_TARGET_TYPE = Object.freeze({
  DOCUMENT: "document",
  SCOPE: "scope",
  SCOPE_MEMBER_BATCH: "scope_member_batch",
  PRODUCT: "product",
});

const COMPLIANCE_REVIEW_EVENT_ACTION = Object.freeze({
  SUBMITTED: "submitted",
  APPROVED: "approved",
  REJECTED: "rejected",
  INFO_REQUESTED: "info_requested",
  REVOKED: "revoked",
  SUPERSEDED: "superseded",
  EXPIRED: "expired",
  RECOMPUTED: "recomputed",
});

const COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE = Object.freeze({
  SELLER: "seller",
  ADMIN: "admin",
  SYSTEM: "system",
});

// Append-only — this list exists for future server operations to build
// the exact write payload against; no Rules-allowed client write exists
// for this collection at all (Slice 1 or later).
const COMPLIANCE_REVIEW_EVENT_ALLOWED_FIELDS = Object.freeze([
  "targetType",
  "targetId",
  "businessId",
  "action",
  "actorUid",
  "actorRole",
  "occurredAt",
  "notes",
]);

// ---------------------------------------------------------------------
// compliancePolicyRegistry/{registryVersion}
// ---------------------------------------------------------------------

const COMPLIANCE_POLICY_REGISTRY_STATUS = Object.freeze({
  DRAFT: "draft",
  ACTIVE: "active",
  INACTIVE: "inactive",
});

const COMPLIANCE_POLICY_REGISTRY_ALLOWED_FIELDS = Object.freeze([
  "sellerRelationship",
  "status",
  "effectiveFrom",
  "createdBy",
  "createdAt",
  "changeNote",
]);

// ---------------------------------------------------------------------
// productComplianceDecisions/{productId}
// ---------------------------------------------------------------------

const PRODUCT_COMPLIANCE_EFFECTIVE_STATUS = Object.freeze({
  VERIFIED_VALID: "verified_valid",
  VERIFIED_EXPIRING_SOON: "verified_expiring_soon",
  EXPIRED_GRACE: "expired_grace",
  EXPIRED_BLOCKED: "expired_blocked",
  REVOKED: "revoked",
  REJECTED: "rejected",
  POLICY_UNRESOLVED: "policy_unresolved",
  UNREADABLE: "unreadable",
  EVIDENCE_MISSING: "evidence_missing",
  CALCULATING: "calculating",
  STALE: "stale",
  ERROR: "error",
  UNKNOWN: "unknown",
});

// The exact positive allowlist (docs/plans/... §5.5/§11, correction 5):
// the ONLY two statuses that ever permit public visibility, add-to-cart,
// reservation, or payment confirmation. Every other value in
// PRODUCT_COMPLIANCE_EFFECTIVE_STATUS fails closed by construction of
// this allowlist, not by a remembered exclusion list.
const PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES = Object.freeze([
  PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.VERIFIED_VALID,
  PRODUCT_COMPLIANCE_EFFECTIVE_STATUS.VERIFIED_EXPIRING_SOON,
]);

// The explicit bound (docs/plans/... §4/§6, correction 6) — checkout
// must never scan an unbounded set of evidence links.
const PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS = 10;

// Maximum required-evidence "slots" a single decision may declare
// (docs/plans/... §4 — "array, max 5 entries").
const PRODUCT_COMPLIANCE_DECISION_MAX_REQUIRED_SLOTS = 5;

const PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "policyVersion",
  "evidenceRevision",
  "requiredEvidenceSlots",
  "satisfiedEvidenceSlots",
  "activeEvidenceRefs",
  "computedAt",
  "validUntil",
  "effectiveStatus",
  "decisionHash",
]);

module.exports = {
  COMPLIANCE_SCHEMA_VERSION,

  STOCK_AUTHORITY_TYPE,
  STOCK_AUTHORITY_TYPE_REACHABLE_IN_P1A,
  BUSINESS_INVENTORY_POLICY_STATUS,
  BUSINESS_INVENTORY_POLICY_STATUS_REACHABLE_IN_P1A,
  BUSINESS_INVENTORY_POLICY_ALLOWED_FIELDS,

  COMPLIANCE_UPLOAD_SESSION_STATUS,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_FIELDS,
  COMPLIANCE_UPLOAD_SESSION_DEFAULT_EXPIRY_MINUTES,
  COMPLIANCE_UPLOAD_ORPHAN_RETENTION_DAYS,

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

  COMPLIANCE_EVIDENCE_LINK_MATCH_TYPE,
  PRODUCT_EVIDENCE_LINK_ALLOWED_FIELDS,

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
};
