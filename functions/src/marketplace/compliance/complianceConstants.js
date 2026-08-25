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

// Slice 2 correction: the Slice 1 draft used a 7-value placeholder enum
// (issued/uploaded/validating/scan_pending/clean/failed/expired). Slice 2
// implements the full, explicit state machine docs/plans/...'s security
// decision requires — this REPLACES the Slice 1 enum in place (single
// source of truth, per "do not duplicate state enums in multiple
// files"), it does not add a second, parallel enum anywhere.
//
// Slice 2 correction (adversarial review 2026-08-21, finding F —
// "critical, no crash recovery"): the original one-shot CLEAN status
// let a clean verdict be persisted only *after* the Storage object had
// already been copy-then-deleted, so a crash between the Storage
// promotion and the Firestore transaction stranded the session forever.
// CLEAN is replaced with PROMOTION_PENDING: a clean scanner verdict is
// now persisted FIRST (binding bucket/objectPath/generation/hash/size/
// mime/engine version/signature version/documentId/destinationPath to
// the session, still fully unusable for evidence/approval), and only
// THEN does a separate, idempotent, resumable promotion step run. A
// crash at any point leaves the session in a well-defined, reconciler-
// recoverable state (see complianceUploadReconciliation.js) instead of a
// stuck one.
const COMPLIANCE_UPLOAD_SESSION_STATUS = Object.freeze({
  CREATED: "created",
  UPLOAD_AUTHORIZED: "upload_authorized",
  UPLOADED: "uploaded",
  VALIDATING: "validating",
  SCAN_PENDING: "scan_pending",
  PROMOTION_PENDING: "promotion_pending",
  EXPIRED: "expired",
  VALIDATION_FAILED: "validation_failed",
  SCAN_FAILED: "scan_failed",
  INFECTED: "infected",
  CANCELLED: "cancelled",
  CONSUMED: "consumed",
});

// Explicit allowed-transition table (docs/plans/... Slice 2 security
// decision: "Define and enforce allowed transitions. A consumed or
// expired session must never authorize another upload."). Every status
// not listed as a key has no outgoing transitions — i.e. is terminal.
// `created` is a logical pre-state only: this implementation's
// createComplianceUploadSession performs every check before writing
// anything and persists the session directly at `upload_authorized` (see
// complianceUploadSessions.js) — `created` is never itself observed as a
// persisted Firestore value, but is kept in the enum/table for schema
// completeness and to keep the transition graph literally correct.
const COMPLIANCE_UPLOAD_SESSION_ALLOWED_TRANSITIONS = Object.freeze({
  created: Object.freeze(["upload_authorized"]),
  upload_authorized: Object.freeze(["uploaded", "expired", "cancelled"]),
  uploaded: Object.freeze(["validating"]),
  validating: Object.freeze(["scan_pending", "validation_failed"]),
  scan_pending: Object.freeze(["promotion_pending", "scan_failed", "infected"]),
  promotion_pending: Object.freeze(["consumed", "scan_failed"]),
});

// Terminal states — present for completeness/iteration, no outgoing
// transitions exist for any of these in the table above.
const COMPLIANCE_UPLOAD_SESSION_TERMINAL_STATUSES = Object.freeze([
  "expired",
  "validation_failed",
  "scan_failed",
  "infected",
  "cancelled",
  "consumed",
]);

// The only status from which a Storage upload may ever be authorized.
const COMPLIANCE_UPLOAD_SESSION_UPLOAD_ELIGIBLE_STATUS = "upload_authorized";

const COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES = Object.freeze([
  "application/pdf",
  "image/jpeg",
  "image/png",
]);

// Server-chosen extension for each allowed MIME type — used to build the
// server-generated objectId so no client-supplied filename or extension
// ever reaches the actual Storage path (docs/plans/... Slice 2 security
// decision: "Prevent filename/path traversal... case or extension
// tricks"). Deliberately not a client input.
const COMPLIANCE_UPLOAD_SESSION_MIME_TO_EXTENSION = Object.freeze({
  "application/pdf": "pdf",
  "image/jpeg": "jpg",
  "image/png": "png",
});

const COMPLIANCE_UPLOAD_SESSION_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "sessionId",
  "documentId",
  "objectId",
  "objectPath",
  "destinationPath",
  "originalFilename",
  "declaredMimeType",
  "declaredSizeBytes",
  "documentType",
  "sellerRelationship",
  "clientIdempotencyKey",
  "allowedMimeTypes",
  "maxSizeBytes",
  "status",
  "issuedBy",
  "issuedAt",
  "expiresAt",
  "uploadedAt",
  "uploadedGeneration",
  "finalizedAt",
  "contentHash",
  "actualContentType",
  "actualSizeBytes",
  "validationFailureReason",
  "scanAttempts",
  "scanVerdict",
  "scanEngineVersion",
  "scanSignatureVersion",
  "scannedAt",
  "scanFailureReason",
  "promotedGeneration",
  "promotedAt",
  "consumedAt",
  "consumedByDocumentId",
  // Reconciliation lease fields (Slice 2 correction, finding B) — every
  // value here is server-owned; no client request field ever sets one
  // (see COMPLIANCE_UPLOAD_SESSION_REQUEST_ALLOWED_FIELDS below, which
  // does not include any of them).
  "leaseOwner",
  "leaseExpiresAt",
  "reconciliationAttempts",
  "lastReconciledAt",
  "updatedAt",
]);

// Fields a client's createComplianceUploadSession request may supply —
// deliberately much narrower than the full document schema above. Every
// other field on the document is server-generated (docs/plans/... Slice
// 2 security decision: "Never accept a caller-provided Storage path,
// document status, scan status, reviewer field, approval field, hash
// result, or server timestamp"). `businessId` is a routing/authorization
// pointer re-verified server-side against businesses/{businessId}, not
// blindly trusted metadata.
const COMPLIANCE_UPLOAD_SESSION_REQUEST_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "originalFilename",
  "declaredMimeType",
  "declaredSizeBytes",
  "documentType",
  "clientIdempotencyKey",
]);

// Proposed defaults (docs/plans/... §4, §20).
const COMPLIANCE_UPLOAD_SESSION_DEFAULT_EXPIRY_MINUTES = 15;
const COMPLIANCE_UPLOAD_ORPHAN_RETENTION_DAYS = 7;
const COMPLIANCE_UPLOAD_SESSION_MAX_SIZE_BYTES = 15 * 1024 * 1024; // 15MB
const COMPLIANCE_UPLOAD_SESSION_MAX_ORIGINAL_FILENAME_LENGTH = 200;

// ---------------------------------------------------------------------
// Malware scanning boundary
// ---------------------------------------------------------------------

const MALWARE_SCAN_VERDICT = Object.freeze({
  CLEAN: "clean",
  INFECTED: "infected",
  ERROR: "error",
});

// Bounded attempt policy — used by complianceScanOrchestration.js. A scan
// that has not produced a CLEAN or INFECTED verdict after this many total
// attempts transitions to scan_failed; it never falls back to clean
// (docs/plans/... Slice 2 security decision: "fail-closed ClamAV/Cloud
// Run integration boundary").
//
// Slice 2.1 correction (deployment-readiness audit 2026-08-21, part A):
// the original design performed all MALWARE_SCAN_MAX_ATTEMPTS attempts,
// with sleep-based backoff between them, INSIDE a single orchestration
// invocation — 3 x 60s (the corrected per-attempt timeout) plus 2 x
// backoff could exceed the Storage-trigger Function's own timeout
// budget, which is unsafe arithmetic. orchestrateComplianceScan now
// performs exactly ONE scanner HTTP attempt per invocation; the bounded
// attempt budget is still enforced (via the session's own persisted
// scanAttempts counter), but spent ACROSS separate invocations — a
// later Eventarc redelivery or, authoritatively, the scheduled
// reconciler's periodic resume of a stale scan_pending session — never
// within one invocation's own sleep loop. MALWARE_SCAN_RETRY_BACKOFF_MS
// is retired along with the in-process retry loop it existed for; the
// natural spacing between separate invocations (the reconciler's own
// 5-minute sweep cadence) is now what stands in its place.
const MALWARE_SCAN_MAX_ATTEMPTS = 3;
const MALWARE_SCAN_TIMEOUT_MS = 60000;

// Versioned scanner request/response contract (Slice 2 correction,
// finding H). Bumping this is a breaking change to the not-yet-built
// Cloud Run service's contract; the adapter sends it on every request
// and the response is rejected (fail-closed, never "clean") if the
// service echoes back anything else or omits it.
const COMPLIANCE_SCANNER_CONTRACT_VERSION = 1;

// Slice 2.1 (scanner contract hardening, part B) — the maximum age a
// scanner's baked-in signature set may have at decision time. A response
// bound to signatures older than this is treated identically to a
// malformed response: fail closed, never "clean" — this is the ONLY
// place this number is defined; both the deployed scanner's own
// self-check (services/compliance-scanner) and the Functions-side
// response verification (complianceScanner.js) must independently
// enforce it, but neither invents its own value.
const COMPLIANCE_SIGNATURE_MAX_AGE_MS = 48 * 60 * 60 * 1000; // 48 hours

// ---------------------------------------------------------------------
// Reconciliation / lease policy (Slice 2 correction, finding F/B) — a
// crashed worker must never permanently own a session. A lease is only
// ever reclaimed after it has expired; staleness thresholds below are
// deliberately longer than any single realistic attempt (validation
// download, one scan call, one Storage copy) so a live, still-working
// invocation is never preempted by the reconciler racing it.
// ---------------------------------------------------------------------

const COMPLIANCE_RECONCILIATION_LEASE_DURATION_MS = 5 * 60 * 1000; // 5 min
const COMPLIANCE_RECONCILIATION_MAX_ATTEMPTS = 5;
const COMPLIANCE_RECONCILIATION_PAGE_SIZE = 50;

// Slice 2.1 correction (part A) — a per-sweep wall-clock budget. The
// reconciler's onSchedule export has timeoutSeconds: 300; a single
// scan_pending resume can now legitimately take up to
// MALWARE_SCAN_TIMEOUT_MS (60s) plus Storage/Firestore overhead, so
// processing a full COMPLIANCE_RECONCILIATION_PAGE_SIZE (50) worth of
// scan_pending candidates serially could take far longer than the
// Function's own timeout. reconcileStateOnce() checks elapsed time
// against this budget between items and stops (leaving the remainder for
// the next scheduled run, unclaimed and therefore safe to pick up again)
// rather than let the Function itself time out mid-item. Set comfortably
// below the 300s Function timeout to leave room for the final
// quarantine-duplicate cleanup sub-sweep and function overhead.
const COMPLIANCE_RECONCILIATION_SWEEP_DEADLINE_MS = 240 * 1000; // 240s

// How long a session may sit in each intermediate state before the
// reconciler will attempt to resume (or, past the attempt budget, fail
// closed) it. Deliberately uniform and generous — none of these steps is
// expected to legitimately take this long even under retry/backoff.
const COMPLIANCE_UPLOADED_STALE_MS = 10 * 60 * 1000;
const COMPLIANCE_VALIDATING_STALE_MS = 10 * 60 * 1000;
const COMPLIANCE_SCAN_PENDING_STALE_MS = 10 * 60 * 1000;
const COMPLIANCE_PROMOTION_PENDING_STALE_MS = 10 * 60 * 1000;

const COMPLIANCE_CLEANUP_PAGE_SIZE = 200;

// ---------------------------------------------------------------------
// Upload session quota (Slice 2 correction, finding B — "no abuse/cost
// controls"). Scoped to (businessId, uid) — a business's own owner, not
// a global cap — so one seller's volume never throttles another.
// Conservative initial policy per docs/plans/... adversarial-review
// correction request: high enough that a legitimate seller uploading
// one document per product is never blocked (a seller would need >50
// distinct compliance documents in a single UTC day, or >10 concurrently
// mid-flight, to hit these), low enough to bound abuse cost. Revisit
// once real seller upload volume is observed; these are deliberately
// conservative starting values, not a measured ceiling.
// ---------------------------------------------------------------------

const COMPLIANCE_MAX_ACTIVE_UPLOAD_SESSIONS_PER_SCOPE = 10;
const COMPLIANCE_MAX_UPLOAD_SESSIONS_PER_SCOPE_PER_UTC_DAY = 50;
const COMPLIANCE_MAX_UPLOAD_BYTES_PER_SCOPE_PER_UTC_DAY = 300 * 1024 * 1024; // 300MB

const COMPLIANCE_UPLOAD_QUOTA_SCOPE_COLLECTION = "complianceUploadQuotaScopes";
const COMPLIANCE_UPLOAD_QUOTA_DAILY_COLLECTION = "complianceUploadQuotaDaily";

const COMPLIANCE_UPLOAD_QUOTA_SCOPE_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "uid",
  "activeSessionCount",
  "updatedAt",
]);

const COMPLIANCE_UPLOAD_QUOTA_DAILY_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "uid",
  "utcDateKey",
  "createdSessionCount",
  "declaredBytesCreated",
  "updatedAt",
]);

// Closed metadata map written on every promoted compliance_docs/ object —
// deliberately never a superset of source/quarantine metadata (Slice 2
// correction, finding H): a copy() call by default forwards the source
// object's custom metadata, which could otherwise carry forward a rogue
// firebaseStorageDownloadTokens key or arbitrary client-set value. The
// promotion step always passes exactly this key set as the destination's
// metadata, never the source's.
const COMPLIANCE_DOCS_METADATA_KEYS = Object.freeze([
  "businessId",
  "documentId",
  "sessionId",
]);

// Magic-byte / file-signature constants, expressed as arrays of expected
// leading byte values, for the finalize-time structural check (Storage
// Rules cannot inspect file bytes; this is the server-side check that
// does). PDF also requires a "%%EOF" marker to appear in the file, a
// lightweight structural check beyond the header alone — this is not a
// full PDF parse, and is documented as such rather than overclaimed.
const COMPLIANCE_FILE_SIGNATURES = Object.freeze({
  "application/pdf": Object.freeze({
    magicBytes: Object.freeze([0x25, 0x50, 0x44, 0x46]), // "%PDF"
  }),
  "image/jpeg": Object.freeze({
    magicBytes: Object.freeze([0xff, 0xd8, 0xff]),
  }),
  "image/png": Object.freeze({
    magicBytes: Object.freeze([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  }),
});

// ---------------------------------------------------------------------
// Storage path prefixes
// ---------------------------------------------------------------------

const COMPLIANCE_QUARANTINE_PATH_PREFIX = "compliance_quarantine";
const COMPLIANCE_DOCS_PATH_PREFIX = "compliance_docs";

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

// Session-level states (uploaded/validating/scan_pending/
// promotion_pending) are deliberately absent — a complianceDocuments
// record is never created until its session's promotion step commits it
// in the same transaction that marks the session CONSUMED (docs/plans/...
// §4/§5.0, correction 1; Slice 2 correction, finding A — no earlier
// placeholder document is ever created for a not-yet-promoted session).
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

// Slice 3 — explicit allowed-transition table, same convention as
// COMPLIANCE_UPLOAD_SESSION_ALLOWED_TRANSITIONS above (single source of
// truth; every status not listed as a key is terminal). `clean` is the
// status the Slice 2 scan-result handler creates a document at;
// `pending_review -> pending_review` (requestComplianceInformation) is
// deliberately NOT modeled here — it never changes `status`, so it is
// checked by complianceDocumentOperations.js as a direct status
// equality, not through this transition table. `rejected` has no
// outgoing transition: COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS locks
// sellerRelationship/issuedAt/validFrom/validUntil the instant
// submitComplianceDocument first sets them, so a rejected document can
// never be corrected and resubmitted in place — a seller must upload a
// fresh document (a new Slice 2 session) instead.
const COMPLIANCE_DOCUMENT_ALLOWED_TRANSITIONS = Object.freeze({
  clean: Object.freeze(["pending_review"]),
  pending_review: Object.freeze(["approved", "rejected"]),
  approved: Object.freeze(["revoked", "superseded"]),
});

const COMPLIANCE_DOCUMENT_TERMINAL_STATUSES = Object.freeze([
  "rejected",
  "revoked",
  "expired",
  "superseded",
]);

// Slice 3 correction (adversarial review, TOCTOU finding) — the single
// positive allowlist of document statuses `addComplianceScope` may act
// against, re-checked fresh inside its own transaction (never a plain
// pre-transaction read alone). A positive allowlist, not a `!==`
// negative check, so an unknown/future status value fails closed by
// construction rather than by remembering to exclude it.
const COMPLIANCE_SCOPE_CREATION_ELIGIBLE_DOCUMENT_STATUSES = Object.freeze(["approved"]);

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

// `sellerRelationship` (master plan Revision 7 correction 40, docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md
// §4/§13.1): denormalized server-side onto every scope from its source
// `complianceDocuments.sellerRelationship` at `addComplianceScope`
// creation time — never a client-suppliable field, never touched by
// `reviewComplianceScope` or any other Slice 3 operation once set. No
// separate "immutable fields" constant exists for this collection (unlike
// `complianceDocuments`' `COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS` split) —
// immutability here is enforced by which fields the module's write paths
// actually touch, the same established convention already governing
// `documentId`/`businessId`/`scopeType`/`scopeValue`/`createdAt`/
// `createdBy` in this same list.
//
// `documentType`/`validUntil` (master plan Revision 9 correction 49, same
// document/§13.1 third prerequisite Slice 3 sub-pass): denormalized
// server-side onto every scope from the source `complianceDocuments`
// record at `addComplianceScope` creation time, exactly like
// `sellerRelationship` above — never client-suppliable, never touched by
// `reviewComplianceScope` or any other operation once set. Both source
// fields are already immutable (`COMPLIANCE_DOCUMENT_IMMUTABLE_FIELDS`),
// so these copies can never drift. Exist solely so the future Slice 4.3
// matching engine can pre-filter candidates before spending a bounded
// source-document read — the source document remains the sole authority;
// these copies are never trusted for final eligibility.
const COMPLIANCE_SCOPE_ALLOWED_FIELDS = Object.freeze([
  "documentId",
  "businessId",
  "scopeType",
  "scopeValue",
  "sellerRelationship",
  "documentType",
  "validUntil",
  "memberCount",
  "status",
  "createdAt",
  "createdBy",
  "reviewedBy",
  "reviewedAt",
  "verifiedBrandId",
]);

// Slice 3 — reviewComplianceScope's sole transition. No further
// transition out of approved/rejected exists in Slice 3 (no scope-level
// "revoke" operation is documented anywhere in the master plan's §8
// operation table, unlike documents and members — a scope's own status
// enum has only 3 values, with no `revoked` member at all).
const COMPLIANCE_SCOPE_ALLOWED_TRANSITIONS = Object.freeze({
  pending_review: Object.freeze(["approved", "rejected"]),
});

const COMPLIANCE_SCOPE_TERMINAL_STATUSES = Object.freeze(["approved", "rejected"]);

// Slice 3 correction (adversarial review, Correction A/B) — the
// positive allowlist of scope statuses under which member records may
// be added (addComplianceScopeMembers), or APPROVED
// (reviewComplianceScopeMembers's `approve` decision only — see the
// separate rejection-eligible allowlist immediately below for the
// `reject` decision). `rejected` — and any unknown/future status — is
// excluded by construction (positive allowlist, not a
// `!== 'rejected'` negative check): **no member may become `active`
// beneath a rejected scope, without exception** — this is the one
// invariant that must never be relaxed. reviewComplianceScopeMembers
// re-reads the parent scope fresh inside its own transaction to
// enforce this, never trusting a pre-transaction read alone.
const COMPLIANCE_SCOPE_MEMBER_LIFECYCLE_ELIGIBLE_SCOPE_STATUSES = Object.freeze([
  "pending_review",
  "approved",
]);

// Slice 3 correction (second adversarial review pass, explicit product
// decision) — a decision-specific, WIDER allowlist for
// reviewComplianceScopeMembers's `reject` decision only. Rejecting a
// member never grants trust (it only ever narrows what's active), so a
// pending member beneath an already-`rejected` parent scope may still
// be explicitly rejected — closing the "permanently stranded at
// pending_review, no legal exit" defect found by adversarial review —
// without introducing any new state, transition, or automatic cascade.
// `rejected` is the ONLY addition versus the allowlist above; any
// other unknown/future status still fails closed for both decisions.
// Never used for `approve` — see COMPLIANCE_SCOPE_MEMBER_LIFECYCLE_
// ELIGIBLE_SCOPE_STATUSES above, which remains the sole gate for that
// decision and is deliberately NOT widened.
const COMPLIANCE_SCOPE_MEMBER_REJECTION_ELIGIBLE_SCOPE_STATUSES = Object.freeze([
  "pending_review",
  "approved",
  "rejected",
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

// Slice 3 — reviewComplianceScopeMembers's sole transition.
// `active -> revoked` is deliberately NOT included: no named member-
// revocation operation exists anywhere in the master plan's §8
// operation table (only addComplianceScope/addComplianceScopeMembers/
// reviewComplianceScopeMembers are listed for the member lifecycle), so
// Slice 3 leaves `revoked` a defined-but-unreachable enum value here,
// exactly like COMPLIANCE_UPLOAD_SESSION's `created` pre-state — the
// revokedAt/revokedBy fields already reserved in
// COMPLIANCE_SCOPE_MEMBER_ALLOWED_FIELDS remain for a later slice to
// wire an explicit revoke operation against, not invented here.
const COMPLIANCE_SCOPE_MEMBER_ALLOWED_TRANSITIONS = Object.freeze({
  pending_review: Object.freeze(["active", "rejected"]),
});

const COMPLIANCE_SCOPE_MEMBER_TERMINAL_STATUSES = Object.freeze([
  "active",
  "rejected",
  "revoked",
]);

// ---------------------------------------------------------------------
// productEvidenceLinks/{linkId}
// ---------------------------------------------------------------------

// Every link's matchedVia value is one of the scope types it was
// discovered through.
const COMPLIANCE_EVIDENCE_LINK_MATCH_TYPE = COMPLIANCE_SCOPE_TYPE;

// Revision 6 correction 34 (master plan §4): the field-name contradiction
// between the original Revision 3 correction 16 table (`scopeType`/
// `matchReasonCode`) and this already-shipped constant is resolved in
// favor of the single, non-redundant `matchedVia` field — `scopeType`/
// `matchReasonCode` are provably redundant with it (§10's seven lookup
// types map 1:1 onto scopeType by construction) and are never added.
// `linkedBy` is removed: this collection has exactly one system writer
// (`recomputeProductComplianceStatus`) by design, so a "written by"
// field is a compile-time constant with no diagnostic value. No
// migration/backfill needed for either removal — this collection has
// never had a writer, so no document exists under either field set.
const PRODUCT_EVIDENCE_LINK_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "productId",
  "documentId",
  "scopeId",
  "matchedVia",
  "linkedAt",
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

// `RETIRED` added (Slice 4.1, master plan Revision 3 correction 17):
// distinct from `INACTIVE`. `inactive` is a version that was never named
// by the pointer at all (a dormant placeholder/test version, correction
// 8) — preserved unchanged. `retired` is a version that WAS previously
// named `active` by the pointer and has since been superseded by a
// successful activation of a different version — only the activation
// transaction (compliancePolicyRegistryOperations.js) ever writes it.
// The two are never interchangeable and neither may substitute for the
// other.
const COMPLIANCE_POLICY_REGISTRY_STATUS = Object.freeze({
  DRAFT: "draft",
  ACTIVE: "active",
  INACTIVE: "inactive",
  RETIRED: "retired",
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
// compliancePolicyRegistryPointer/current (Slice 4.1, master plan
// Revision 3 correction 17) — singleton document; the SOLE authoritative
// source of which compliancePolicyRegistry version is active. No reader
// may ever resolve "the active policy" by querying compliancePolicyRegistry
// for status=='active' — only by reading this document's activeVersionId.
// Written only by compliancePolicyRegistryOperations.js's activation
// transaction. Deliberately minimal: only the field the committed plan
// actually specifies (§4) — no timestamps, audit fields, or Slice 4.2+
// content are added speculatively here.
// ---------------------------------------------------------------------

const COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION = "compliancePolicyRegistryPointer";
const COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID = "current";

const COMPLIANCE_POLICY_REGISTRY_POINTER_ALLOWED_FIELDS = Object.freeze(["activeVersionId"]);

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

// ---------------------------------------------------------------------
// complianceMatching.js (Slice 4.3, master plan §10, Revision 6
// correction 35 / Revision 7 correction 41-42) — the two frozen bounds
// the seven-query matching engine and source-document verification are
// built around. LOOKUP_LIMIT caps every one of the seven
// complianceDocumentScopes candidate queries; MATCHED_SCOPE_CAP caps how
// many matched scopes' source documents are resolved/verified in one
// recompute. Together with the four initial point reads (product,
// pointer, version, epoch), the sku_set member point-reads (≤2 per
// candidate), and the prior-decision read, these two bounds are what
// make the ≤42-billed-read / ≤8-operation ceiling (§10) exact and
// reproducible rather than merely a description.
// ---------------------------------------------------------------------

const LOOKUP_LIMIT = 3;
const MATCHED_SCOPE_CAP = 10;

// Slice 4.3 correction: `productInputRevisionSnapshot` (master plan §4,
// "NEW, Revision 3") was added to the productComplianceDecisions schema
// table before this constant existed, but this constant was never
// updated to include it — a pre-existing gap, not a Revision 8 change.
// Corrected here since it is required for
// hasOnlyAllowedProductComplianceDecisionFields to accept the real
// schema recomputeProductComplianceStatus (Slice 4.3) writes.
// `sellerRelationshipSnapshot` (Revision 9 correction 51, master plan §4/
// §10.1) — added alongside productInputRevisionSnapshot, independent of
// it: closes the dormant-window gap where a product's sellerRelationship
// can change while productInputRevision stays absent on both sides
// (firestore.rules row A), which revision-equality alone cannot detect.
const PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "policyVersion",
  "evidenceRevision",
  "productInputRevisionSnapshot",
  "sellerRelationshipSnapshot",
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
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_TRANSITIONS,
  COMPLIANCE_UPLOAD_SESSION_TERMINAL_STATUSES,
  COMPLIANCE_UPLOAD_SESSION_UPLOAD_ELIGIBLE_STATUS,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_MIME_TYPES,
  COMPLIANCE_UPLOAD_SESSION_MIME_TO_EXTENSION,
  COMPLIANCE_UPLOAD_SESSION_ALLOWED_FIELDS,
  COMPLIANCE_UPLOAD_SESSION_REQUEST_ALLOWED_FIELDS,
  COMPLIANCE_UPLOAD_SESSION_DEFAULT_EXPIRY_MINUTES,
  COMPLIANCE_UPLOAD_ORPHAN_RETENTION_DAYS,
  COMPLIANCE_UPLOAD_SESSION_MAX_SIZE_BYTES,
  COMPLIANCE_UPLOAD_SESSION_MAX_ORIGINAL_FILENAME_LENGTH,

  MALWARE_SCAN_VERDICT,
  MALWARE_SCAN_MAX_ATTEMPTS,
  MALWARE_SCAN_TIMEOUT_MS,
  COMPLIANCE_FILE_SIGNATURES,
  COMPLIANCE_SCANNER_CONTRACT_VERSION,
  COMPLIANCE_SIGNATURE_MAX_AGE_MS,

  COMPLIANCE_RECONCILIATION_LEASE_DURATION_MS,
  COMPLIANCE_RECONCILIATION_MAX_ATTEMPTS,
  COMPLIANCE_RECONCILIATION_PAGE_SIZE,
  COMPLIANCE_RECONCILIATION_SWEEP_DEADLINE_MS,
  COMPLIANCE_UPLOADED_STALE_MS,
  COMPLIANCE_VALIDATING_STALE_MS,
  COMPLIANCE_SCAN_PENDING_STALE_MS,
  COMPLIANCE_PROMOTION_PENDING_STALE_MS,
  COMPLIANCE_CLEANUP_PAGE_SIZE,

  COMPLIANCE_MAX_ACTIVE_UPLOAD_SESSIONS_PER_SCOPE,
  COMPLIANCE_MAX_UPLOAD_SESSIONS_PER_SCOPE_PER_UTC_DAY,
  COMPLIANCE_MAX_UPLOAD_BYTES_PER_SCOPE_PER_UTC_DAY,
  COMPLIANCE_UPLOAD_QUOTA_SCOPE_COLLECTION,
  COMPLIANCE_UPLOAD_QUOTA_DAILY_COLLECTION,
  COMPLIANCE_UPLOAD_QUOTA_SCOPE_ALLOWED_FIELDS,
  COMPLIANCE_UPLOAD_QUOTA_DAILY_ALLOWED_FIELDS,
  COMPLIANCE_DOCS_METADATA_KEYS,

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

  COMPLIANCE_EVIDENCE_LINK_MATCH_TYPE,
  PRODUCT_EVIDENCE_LINK_ALLOWED_FIELDS,

  COMPLIANCE_REVIEW_EVENT_TARGET_TYPE,
  COMPLIANCE_REVIEW_EVENT_ACTION,
  COMPLIANCE_REVIEW_EVENT_ACTOR_ROLE,
  COMPLIANCE_REVIEW_EVENT_ALLOWED_FIELDS,

  COMPLIANCE_POLICY_REGISTRY_STATUS,
  COMPLIANCE_POLICY_REGISTRY_ALLOWED_FIELDS,

  COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION,
  COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID,
  COMPLIANCE_POLICY_REGISTRY_POINTER_ALLOWED_FIELDS,

  PRODUCT_COMPLIANCE_EFFECTIVE_STATUS,
  PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES,
  PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS,
  PRODUCT_COMPLIANCE_DECISION_MAX_REQUIRED_SLOTS,
  PRODUCT_COMPLIANCE_DECISION_ALLOWED_FIELDS,

  LOOKUP_LIMIT,
  MATCHED_SCOPE_CAP,
};
