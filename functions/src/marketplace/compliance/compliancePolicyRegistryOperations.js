"use strict";

// Petsupo Marketplace P1-A compliance foundation — Slice 4.1 (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §4/§13.1/§16, Revision 4): the complete policy-registry contract —
// create, resolve, bootstrap, and subsequent activation (never "CRUD" —
// no delete, no generic update exists or should exist here). This module
// exports plain internal functions only — NOT wired into
// functions/index.js, no onCall/HTTP/trigger/scheduled/task-queue entry
// point of any kind exists for it. Deploying the code that CONTAINS
// these functions changes nothing, because nothing can reach them.
//
// Five internal exports, matching the master plan's §4 contract exactly:
//   createCompliancePolicyVersion           — the sole writer of new
//                                              compliancePolicyRegistry
//                                              version documents.
//                                              Create-only; never
//                                              active/retired at
//                                              creation.
//   resolveActivePolicy                     — fresh, non-transactional
//                                              pointer -> version
//                                              resolution, full deep
//                                              validation on every call,
//                                              fail-closed on any
//                                              anomaly.
//   bootstrapCompliancePolicyRegistry       — the ONLY operation
//                                              permitted to create
//                                              compliancePolicyRegistryPointer
//                                              /current, and only when
//                                              it does not yet exist.
//                                              Distinct from
//                                              activatePolicyVersion;
//                                              never weakens its
//                                              anomaly check.
//   activatePolicyVersion                   — subsequent-activation-
//                                              only; requires a
//                                              pre-existing pointer;
//                                              never handles an empty
//                                              registry.
//   validateCompliancePolicyVersionDocument — the one authoritative,
//                                              pure, side-effect-free
//                                              validator, reused
//                                              identically by all four
//                                              operations above. No
//                                              operation ever relies on
//                                              an earlier validation
//                                              result.
//
// CORE INVARIANTS (repeated here because they are the entire point of
// this slice):
//   - compliancePolicyRegistryPointer/current.activeVersionId is the
//     SOLE authoritative selector of "what policy version is active."
//   - The pointer AND the exact version document it names are both read
//     fresh on every single authoritative call — no TTL cache, no
//     module-level mutable state, no fallback to a previously resolved
//     value or a previously computed validation verdict (Revision 4
//     correction 27 retracts the version-content caching permission
//     Revision 3 granted).
//   - NEVER a query for status=='active' as the resolution mechanism —
//     that query exists ONLY as the bounded anomaly check inside
//     bootstrap/activation.
//   - Every version document, once created, is immutable except for its
//     own `status` field, which only bootstrap/activation ever change.
//     No delete, no generic update.

const crypto = require("node:crypto");
const { HttpsError } = require("firebase-functions/v2/https");

const {
  COMPLIANCE_POLICY_REGISTRY_STATUS,
  COMPLIANCE_POLICY_REGISTRY_ALLOWED_FIELDS,
  COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION,
  COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID,
  COMPLIANCE_DOCUMENT_TYPE,
  COMPLIANCE_SCOPE_TYPE,
  SELLER_RELATIONSHIP,
} = require("./complianceConstants");

// No existing `_COLLECTION` constant for compliancePolicyRegistry itself
// — matching complianceDocumentOperations.js's own established
// convention of using the raw literal collection name directly for
// collections with no such constant.
const REGISTRY_COLLECTION = "compliancePolicyRegistry";

const RELATIONSHIP_ENTRY_ALLOWED_FIELDS = Object.freeze([
  "acceptedDocumentTypes",
  "requiredDocumentTypeGroups",
  "perDocumentTypePolicy",
  "maximumValidityPeriod",
  "acceptedScopeTypes",
  "manualAdminOverridePermitted",
]);

// Tied exactly to the already-frozen productComplianceDecisions.
// requiredEvidenceSlots cap (master plan §4) — one policy requirement
// group maps to exactly one decision slot, so the registry can never
// legally hold more groups than the decision schema can represent.
const REQUIRED_DOCUMENT_TYPE_GROUPS_MAX_OUTER_LENGTH = 5;

const CREATED_BY_MAX_LENGTH = 128;
const CHANGE_NOTE_MAX_LENGTH = 2000;

// Structural/overflow-defense ceiling only — no tighter business-
// meaningful ceiling exists anywhere in this repository's conventions
// to derive one from (master plan §4's own stated reasoning).
const COMPLIANCE_POLICY_MAXIMUM_VALIDITY_PERIOD_MS_CEILING = Number.MAX_SAFE_INTEGER;

const DOCUMENT_TYPE_VALUES = new Set(Object.values(COMPLIANCE_DOCUMENT_TYPE));
const SCOPE_TYPE_VALUES = new Set(Object.values(COMPLIANCE_SCOPE_TYPE));
const SELLER_RELATIONSHIP_VALUES = new Set(Object.values(SELLER_RELATIONSHIP));

// ---------------------------------------------------------------------
// Version-ID shape validation — unchanged from the prior slice pass.
// Registry version IDs are untrusted input (a caller-supplied string
// for activatePolicyVersion's/bootstrapCompliancePolicyRegistry's
// target, and Firestore-stored data for the pointer's own
// activeVersionId, which must be treated as untrusted too since a
// corrupted/hand-edited document could contain anything). Bounded,
// non-empty, allowlisted Firestore-document-ID shape — never used to
// construct an arbitrary collection path beyond
// `REGISTRY_COLLECTION/{id}`.
// ---------------------------------------------------------------------

const REGISTRY_VERSION_ID_MAX_LENGTH = 128;

// Must start AND end with an alphanumeric character (rejects leading/
// trailing "-"/"_", a normalization/ambiguity hazard), body restricted
// to alphanumeric/"-"/"_" only. This single allowlist pattern rejects,
// by construction rather than by a separate denylist: "/" (path
// traversal / arbitrary sub-path), "." and ".." (not in the character
// class at all), every control character, and anything exceeding the
// length bound.
const REGISTRY_VERSION_ID_PATTERN = /^[A-Za-z0-9](?:[A-Za-z0-9_-]{0,126}[A-Za-z0-9])?$/;

function isValidRegistryVersionId(value) {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= REGISTRY_VERSION_ID_MAX_LENGTH &&
    REGISTRY_VERSION_ID_PATTERN.test(value)
  );
}

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasExactKeys(obj, allowedKeys) {
  const keys = Object.keys(obj);
  if (keys.length !== allowedKeys.length) return false;
  const allowedSet = new Set(allowedKeys);
  return keys.every((k) => allowedSet.has(k));
}

function isBoundedNonEmptyString(value, maxLength) {
  return typeof value === "string" && value.length > 0 && value.length <= maxLength;
}

// Accepts anything exposing a callable `.toMillis()` returning a finite
// number — the one representation this whole module ever compares
// against, never a raw Date vs. Timestamp mix.
function timestampToMillisOrNaN(value) {
  if (value === null || typeof value !== "object" || typeof value.toMillis !== "function") {
    return NaN;
  }
  try {
    const ms = value.toMillis();
    return typeof ms === "number" && Number.isFinite(ms) ? ms : NaN;
  } catch (err) {
    return NaN;
  }
}

// Normalizes a trusted `now` input (Date, raw epoch-ms number, or
// Timestamp-like value) to a single plain epoch-millisecond number,
// exactly once, at the top of every time-aware call — every subsequent
// comparison in this module is a plain-number comparison, never an
// implicit Date-vs-Timestamp mix.
function normalizeToEpochMs(value) {
  if (typeof value === "number") return value;
  if (value instanceof Date) return value.getTime();
  return timestampToMillisOrNaN(value);
}

// Stable, machine-readable reason slugs. Every fail-closed HttpsError
// thrown by this module, and every `{valid:false, reason}` returned by
// the pure validator, uses exactly one of these — followed by nothing
// else sensitive (no policy content, no document data). Tests assert
// against these values, not full prose. Four of them
// (`*_INVALID_PREFIX`) are combined with the shared validator's own
// returned reason as `${PREFIX}:${validatorReason}`, so the caller
// context and the precise underlying defect are both visible without
// four divergent reason catalogs.
const REASON = Object.freeze({
  // Pointer-level.
  POINTER_READ_FAILED: "policy_pointer_read_failed",
  POINTER_MISSING: "policy_pointer_missing",
  POINTER_MALFORMED: "policy_pointer_malformed",
  POINTER_ACTIVE_VERSION_ID_INVALID: "policy_pointer_active_version_id_invalid",

  // Version-document existence-level (distinct from deep content
  // validation, which is the shared validator's own job).
  VERSION_READ_FAILED: "policy_version_read_failed",
  VERSION_DANGLING: "policy_version_dangling",

  // validateCompliancePolicyVersionDocument's own reason catalog —
  // returned as `reason`, never thrown directly by the validator
  // itself (it has no side effects and never throws for an ordinary
  // validation failure).
  DOCUMENT_NOT_OBJECT: "policy_document_not_object",
  DOCUMENT_MISSING_FIELD: "policy_document_missing_field",
  DOCUMENT_UNKNOWN_FIELD: "policy_document_unknown_field",
  DOCUMENT_STATUS_INVALID: "policy_document_status_invalid",
  DOCUMENT_STATUS_NOT_ALLOWED: "policy_document_status_not_allowed",
  DOCUMENT_EFFECTIVE_FROM_INVALID: "policy_document_effective_from_invalid",
  DOCUMENT_CREATED_BY_INVALID: "policy_document_created_by_invalid",
  DOCUMENT_CREATED_AT_INVALID: "policy_document_created_at_invalid",
  DOCUMENT_CHANGE_NOTE_INVALID: "policy_document_change_note_invalid",
  DOCUMENT_CREATED_AT_FUTURE: "policy_document_created_at_future",
  EFFECTIVE_FROM_FUTURE: "policy_content_effective_from_future",

  CONTENT_NOT_OBJECT: "policy_content_not_object",
  CONTENT_UNKNOWN_RELATIONSHIP_KEY: "policy_content_unknown_relationship_key",
  CONTENT_NO_RELATIONSHIP_CONFIGURED: "policy_content_no_relationship_configured",
  CONTENT_RELATIONSHIP_ENTRY_NOT_OBJECT: "policy_content_relationship_entry_not_object",
  CONTENT_RELATIONSHIP_ENTRY_UNKNOWN_KEY: "policy_content_relationship_entry_unknown_key",
  CONTENT_RELATIONSHIP_ENTRY_MISSING_FIELD: "policy_content_relationship_entry_missing_field",
  CONTENT_ACCEPTED_DOCUMENT_TYPES_INVALID: "policy_content_accepted_document_types_invalid",
  CONTENT_REQUIRED_GROUPS_INVALID: "policy_content_required_document_type_groups_invalid",
  CONTENT_REQUIRED_GROUP_EMPTY: "policy_content_required_document_type_group_empty",
  CONTENT_REQUIRED_GROUP_MEMBER_INVALID: "policy_content_required_document_type_group_member_invalid",
  CONTENT_REQUIRED_GROUPS_DUPLICATE: "policy_content_required_document_type_groups_duplicate",
  CONTENT_REQUIRED_NOT_ACCEPTED: "policy_content_required_not_accepted",
  CONTENT_PER_DOCUMENT_TYPE_POLICY_INVALID: "policy_content_per_document_type_policy_invalid",
  CONTENT_PER_DOCUMENT_TYPE_POLICY_ENTRY_INVALID: "policy_content_per_document_type_policy_entry_invalid",
  CONTENT_MAXIMUM_VALIDITY_PERIOD_INVALID: "policy_content_maximum_validity_period_invalid",
  CONTENT_ACCEPTED_SCOPE_TYPES_INVALID: "policy_content_accepted_scope_types_invalid",
  CONTENT_ACCEPTED_SCOPE_TYPES_EMPTY: "policy_content_accepted_scope_types_empty",
  CONTENT_MANUAL_OVERRIDE_FLAG_INVALID: "policy_content_manual_override_flag_invalid",

  // Creation.
  CREATION_INITIAL_STATUS_INVALID: "policy_creation_initial_status_invalid",
  CREATION_INVALID_PREFIX: "policy_creation_invalid",
  CREATION_VERSION_ID_GENERATION_INVALID: "policy_creation_version_id_generation_invalid",
  CREATION_WRITE_FAILED: "policy_creation_write_failed",

  // Bootstrap.
  BOOTSTRAP_TARGET_VERSION_ID_INVALID: "policy_bootstrap_target_version_id_invalid",
  BOOTSTRAP_POINTER_ALREADY_EXISTS: "policy_bootstrap_pointer_already_exists",
  BOOTSTRAP_POINTER_READ_FAILED: "policy_bootstrap_pointer_read_failed",
  BOOTSTRAP_TARGET_MISSING: "policy_bootstrap_target_missing",
  BOOTSTRAP_TARGET_INVALID_PREFIX: "policy_bootstrap_target_invalid",
  BOOTSTRAP_ANOMALY_QUERY_FAILED: "policy_bootstrap_anomaly_query_failed",
  BOOTSTRAP_ANOMALY_ACTIVE_COUNT_NONZERO: "policy_bootstrap_anomaly_active_count_nonzero",

  // Ordinary activation.
  ACTIVATION_TARGET_VERSION_ID_INVALID: "policy_activation_target_version_id_invalid",
  ACTIVATION_TARGET_MISSING: "policy_activation_target_missing",
  ACTIVATION_TARGET_EQUALS_CURRENT: "policy_activation_target_equals_current",
  ACTIVATION_TARGET_INVALID_PREFIX: "policy_activation_target_invalid",
  ACTIVATION_CURRENT_INVALID_PREFIX: "policy_activation_current_invalid",
  ACTIVATION_ANOMALY_QUERY_FAILED: "policy_activation_anomaly_query_failed",
  ACTIVATION_ANOMALY_COUNT_MISMATCH: "policy_activation_anomaly_count_mismatch",
  ACTIVATION_ANOMALY_ID_MISMATCH: "policy_activation_anomaly_id_mismatch",
  ACTIVATION_ANOMALY_RESULT_MALFORMED: "policy_activation_anomaly_result_malformed",

  // Resolver.
  RESOLVE_ACTIVE_INVALID_PREFIX: "policy_resolve_active_invalid",
});

function failClosed(reason) {
  // Every fail-closed path in this module: a generic, non-sensitive,
  // stable-prefixed message. "failed-precondition" for every structural/
  // state anomaly (matches complianceDocumentOperations.js's own
  // convention for state-machine violations); read/query-adapter
  // failures use "unavailable" instead, since those are transient
  // infrastructure conditions, not a state anomaly.
  throw new HttpsError("failed-precondition", reason);
}

function unavailable(reason) {
  throw new HttpsError("unavailable", reason);
}

// ---------------------------------------------------------------------
// Pointer snapshot validator — the pointer has its own small, separate
// schema (unaffected by Revision 4's version-document changes); kept as
// its own helper, reused by resolveActivePolicy, activatePolicyVersion,
// and bootstrapCompliancePolicyRegistry.
// ---------------------------------------------------------------------

function validatePointerSnapshot(snap) {
  if (!snap.exists) {
    failClosed(REASON.POINTER_MISSING);
  }
  const data = snap.data();
  if (!isPlainObject(data)) {
    failClosed(REASON.POINTER_MALFORMED);
  }
  if (!isValidRegistryVersionId(data.activeVersionId)) {
    failClosed(REASON.POINTER_ACTIVE_VERSION_ID_INVALID);
  }
  return { activeVersionId: data.activeVersionId };
}

// ---------------------------------------------------------------------
// requiredDocumentTypeGroups — outer array = AND, inner array = OR.
// Outer length bounded [1, 5] UNCONDITIONALLY, for any relationship
// entry that is actually present — this is not gated by
// `requireActivationEligible`. The only status-gated exception in this
// whole schema is whether the TOP-LEVEL `sellerRelationship` map may be
// `{}` (checked in validateSellerRelationship, below); once any
// relationship key is present, its entry must always be fully valid,
// including a non-empty, ≤5-group requirement — even inside an
// `inactive` document. Each inner group non-empty, unique members,
// every member ∈ the relationship's own `acceptedDocumentTypes`.
// Duplicate groups rejected after canonicalization (sorted-member
// comparison), so the same alternatives listed in a different order are
// still caught.
// ---------------------------------------------------------------------

function validateRequiredDocumentTypeGroups(groups, acceptedSet) {
  if (
    !Array.isArray(groups) ||
    groups.length < 1 ||
    groups.length > REQUIRED_DOCUMENT_TYPE_GROUPS_MAX_OUTER_LENGTH
  ) {
    return REASON.CONTENT_REQUIRED_GROUPS_INVALID;
  }
  const canonicalSeen = new Set();
  for (const group of groups) {
    if (!Array.isArray(group) || group.length === 0) {
      return REASON.CONTENT_REQUIRED_GROUP_EMPTY;
    }
    const seenInGroup = new Set();
    for (const member of group) {
      if (typeof member !== "string" || !DOCUMENT_TYPE_VALUES.has(member) || seenInGroup.has(member)) {
        return REASON.CONTENT_REQUIRED_GROUP_MEMBER_INVALID;
      }
      seenInGroup.add(member);
      if (!acceptedSet.has(member)) {
        return REASON.CONTENT_REQUIRED_NOT_ACCEPTED;
      }
    }
    const canonicalKey = [...group].sort().join(" ");
    if (canonicalSeen.has(canonicalKey)) {
      return REASON.CONTENT_REQUIRED_GROUPS_DUPLICATE;
    }
    canonicalSeen.add(canonicalKey);
  }
  return null;
}

// ---------------------------------------------------------------------
// One relationship entry (§4's nested sellerRelationship schema) — the
// full structural check, INCLUDING every "must be non-empty/meaningful"
// business rule (non-empty requiredDocumentTypeGroups, non-empty
// acceptedScopeTypes), ALWAYS runs unconditionally on whatever is
// present, regardless of status. `requireActivationEligible` is never
// threaded into this function or the one below it — it has exactly one
// job, gating only whether the TOP-LEVEL `sellerRelationship` map may
// be empty (validateSellerRelationship). Once a relationship key is
// present, its entry is validated identically whether the containing
// document is `draft`, `active`, `inactive`, or `retired`.
// ---------------------------------------------------------------------

function validateRelationshipEntry(entry) {
  if (!isPlainObject(entry)) {
    return REASON.CONTENT_RELATIONSHIP_ENTRY_NOT_OBJECT;
  }
  if (!hasExactKeys(entry, RELATIONSHIP_ENTRY_ALLOWED_FIELDS)) {
    const allowed = new Set(RELATIONSHIP_ENTRY_ALLOWED_FIELDS);
    for (const k of Object.keys(entry)) {
      if (!allowed.has(k)) return REASON.CONTENT_RELATIONSHIP_ENTRY_UNKNOWN_KEY;
    }
    return REASON.CONTENT_RELATIONSHIP_ENTRY_MISSING_FIELD;
  }

  const {
    acceptedDocumentTypes,
    requiredDocumentTypeGroups,
    perDocumentTypePolicy,
    maximumValidityPeriod,
    acceptedScopeTypes,
    manualAdminOverridePermitted,
  } = entry;

  if (!Array.isArray(acceptedDocumentTypes)) {
    return REASON.CONTENT_ACCEPTED_DOCUMENT_TYPES_INVALID;
  }
  const acceptedSet = new Set();
  for (const t of acceptedDocumentTypes) {
    if (typeof t !== "string" || !DOCUMENT_TYPE_VALUES.has(t) || acceptedSet.has(t)) {
      return REASON.CONTENT_ACCEPTED_DOCUMENT_TYPES_INVALID;
    }
    acceptedSet.add(t);
  }

  const groupsReason = validateRequiredDocumentTypeGroups(requiredDocumentTypeGroups, acceptedSet);
  if (groupsReason) return groupsReason;

  if (!isPlainObject(perDocumentTypePolicy)) {
    return REASON.CONTENT_PER_DOCUMENT_TYPE_POLICY_INVALID;
  }
  for (const [key, value] of Object.entries(perDocumentTypePolicy)) {
    if (!acceptedSet.has(key)) {
      return REASON.CONTENT_PER_DOCUMENT_TYPE_POLICY_INVALID;
    }
    if (
      !isPlainObject(value) ||
      !hasExactKeys(value, ["validUntilRequired", "issueDateRequired"]) ||
      typeof value.validUntilRequired !== "boolean" ||
      typeof value.issueDateRequired !== "boolean"
    ) {
      return REASON.CONTENT_PER_DOCUMENT_TYPE_POLICY_ENTRY_INVALID;
    }
  }

  if (
    maximumValidityPeriod !== null &&
    !(
      Number.isSafeInteger(maximumValidityPeriod) &&
      maximumValidityPeriod > 0 &&
      maximumValidityPeriod <= COMPLIANCE_POLICY_MAXIMUM_VALIDITY_PERIOD_MS_CEILING
    )
  ) {
    return REASON.CONTENT_MAXIMUM_VALIDITY_PERIOD_INVALID;
  }

  if (!Array.isArray(acceptedScopeTypes)) {
    return REASON.CONTENT_ACCEPTED_SCOPE_TYPES_INVALID;
  }
  const scopeSet = new Set();
  for (const s of acceptedScopeTypes) {
    if (typeof s !== "string" || !SCOPE_TYPE_VALUES.has(s) || scopeSet.has(s)) {
      return REASON.CONTENT_ACCEPTED_SCOPE_TYPES_INVALID;
    }
    scopeSet.add(s);
  }
  if (acceptedScopeTypes.length === 0) {
    return REASON.CONTENT_ACCEPTED_SCOPE_TYPES_EMPTY;
  }

  if (typeof manualAdminOverridePermitted !== "boolean") {
    return REASON.CONTENT_MANUAL_OVERRIDE_FLAG_INVALID;
  }

  return null;
}

// `requireActivationEligible`'s ONE job, exercised nowhere else: gating
// whether the top-level map may have zero keys. It is deliberately never
// passed down into `validateRelationshipEntry` — a present relationship
// entry is validated identically regardless of status, so an `inactive`
// document cannot use a present-but-empty entry (e.g. all-empty arrays)
// to sidestep the same rules a `draft`/`active` document must satisfy.
// The only inactive-specific relaxation in this entire schema is that
// the map itself may be `{}`.
function validateSellerRelationship(sellerRelationship, requireActivationEligible) {
  if (!isPlainObject(sellerRelationship)) {
    return REASON.CONTENT_NOT_OBJECT;
  }
  const keys = Object.keys(sellerRelationship);
  for (const k of keys) {
    if (!SELLER_RELATIONSHIP_VALUES.has(k)) {
      return REASON.CONTENT_UNKNOWN_RELATIONSHIP_KEY;
    }
  }
  for (const k of keys) {
    const reason = validateRelationshipEntry(sellerRelationship[k]);
    if (reason) return reason;
  }
  if (requireActivationEligible && keys.length === 0) {
    return REASON.CONTENT_NO_RELATIONSHIP_CONFIGURED;
  }
  return null;
}

// ---------------------------------------------------------------------
// The one authoritative validator (Revision 4 correction 26). Pure,
// side-effect-free — no Firestore access, no throwing for an ordinary
// validation failure, no framework dependency. Reused identically by
// all four operations below; never a divergent reimplementation.
// ---------------------------------------------------------------------

function validateCompliancePolicyVersionDocument(version, options = {}) {
  const { allowedStatuses, requireActivationEligible = false, nowMs } = options;

  if (!isPlainObject(version)) {
    return { valid: false, reason: REASON.DOCUMENT_NOT_OBJECT };
  }
  if (!hasExactKeys(version, COMPLIANCE_POLICY_REGISTRY_ALLOWED_FIELDS)) {
    const allowed = new Set(COMPLIANCE_POLICY_REGISTRY_ALLOWED_FIELDS);
    for (const k of Object.keys(version)) {
      if (!allowed.has(k)) return { valid: false, reason: REASON.DOCUMENT_UNKNOWN_FIELD };
    }
    return { valid: false, reason: REASON.DOCUMENT_MISSING_FIELD };
  }

  const { sellerRelationship, status, effectiveFrom, createdBy, createdAt, changeNote } = version;

  const statusValues = new Set(Object.values(COMPLIANCE_POLICY_REGISTRY_STATUS));
  if (typeof status !== "string" || !statusValues.has(status)) {
    return { valid: false, reason: REASON.DOCUMENT_STATUS_INVALID };
  }
  if (Array.isArray(allowedStatuses) && !allowedStatuses.includes(status)) {
    return { valid: false, reason: REASON.DOCUMENT_STATUS_NOT_ALLOWED };
  }

  const effectiveFromMs = timestampToMillisOrNaN(effectiveFrom);
  if (!Number.isFinite(effectiveFromMs)) {
    return { valid: false, reason: REASON.DOCUMENT_EFFECTIVE_FROM_INVALID };
  }

  if (!isBoundedNonEmptyString(createdBy, CREATED_BY_MAX_LENGTH)) {
    return { valid: false, reason: REASON.DOCUMENT_CREATED_BY_INVALID };
  }

  const createdAtMs = timestampToMillisOrNaN(createdAt);
  if (!Number.isFinite(createdAtMs)) {
    return { valid: false, reason: REASON.DOCUMENT_CREATED_AT_INVALID };
  }

  if (!isBoundedNonEmptyString(changeNote, CHANGE_NOTE_MAX_LENGTH)) {
    return { valid: false, reason: REASON.DOCUMENT_CHANGE_NOTE_INVALID };
  }

  const relationshipReason = validateSellerRelationship(sellerRelationship, requireActivationEligible);
  if (relationshipReason) {
    return { valid: false, reason: relationshipReason };
  }

  if (typeof nowMs === "number") {
    if (!(effectiveFromMs <= nowMs)) {
      return { valid: false, reason: REASON.EFFECTIVE_FROM_FUTURE };
    }
    if (!(createdAtMs <= nowMs)) {
      return { valid: false, reason: REASON.DOCUMENT_CREATED_AT_FUTURE };
    }
  }

  return { valid: true };
}

// ---------------------------------------------------------------------
// A. createCompliancePolicyVersion (Revision 4 correction 21) — the
//    sole writer of new compliancePolicyRegistry documents. Create-only:
//    an existing document is never overwritten (the underlying write is
//    a Firestore create-only call, not set/update). initialStatus is
//    allowlisted to exactly draft|inactive — never active/retired at
//    creation. versionId and createdAt are generated by the operation
//    itself, never caller-suppliable.
// ---------------------------------------------------------------------

// Lazily required so this module never touches firebase-admin unless a
// caller declines to inject its own Timestamp-compatible factory —
// every test in this repository injects one, so this default path is
// only ever exercised by a real, future deployment.
function defaultTimestampFromMillis(ms) {
  const admin = require("firebase-admin");
  return admin.firestore.Timestamp.fromMillis(ms);
}

async function createCompliancePolicyVersion({
  db,
  sellerRelationship,
  effectiveFrom,
  changeNote,
  initialStatus,
  createdBy,
  now = new Date(),
  generateVersionId = () => crypto.randomUUID(),
  timestampFromMillis = defaultTimestampFromMillis,
}) {
  if (
    initialStatus !== COMPLIANCE_POLICY_REGISTRY_STATUS.DRAFT &&
    initialStatus !== COMPLIANCE_POLICY_REGISTRY_STATUS.INACTIVE
  ) {
    throw new HttpsError("invalid-argument", REASON.CREATION_INITIAL_STATUS_INVALID);
  }

  const nowMs = normalizeToEpochMs(now);
  if (!Number.isFinite(nowMs)) {
    throw new HttpsError("invalid-argument", `${REASON.CREATION_INVALID_PREFIX}:now_invalid`);
  }

  const createdAt = timestampFromMillis(nowMs);
  if (!Number.isFinite(timestampToMillisOrNaN(createdAt))) {
    throw new HttpsError("internal", `${REASON.CREATION_INVALID_PREFIX}:created_at_generation_failed`);
  }

  let versionId;
  try {
    versionId = generateVersionId();
  } catch (err) {
    throw new HttpsError("internal", REASON.CREATION_VERSION_ID_GENERATION_INVALID);
  }
  if (!isValidRegistryVersionId(versionId)) {
    throw new HttpsError("internal", REASON.CREATION_VERSION_ID_GENERATION_INVALID);
  }

  const candidate = {
    sellerRelationship,
    status: initialStatus,
    effectiveFrom,
    createdBy,
    createdAt,
    changeNote,
  };

  const result = validateCompliancePolicyVersionDocument(candidate, {
    allowedStatuses: [initialStatus],
    requireActivationEligible: initialStatus === COMPLIANCE_POLICY_REGISTRY_STATUS.DRAFT,
    // No nowMs: future-dated drafts are legal at creation (master plan
    // §4); createdAt was just generated as "now" and cannot itself be
    // future relative to that same instant.
  });
  if (!result.valid) {
    throw new HttpsError("invalid-argument", `${REASON.CREATION_INVALID_PREFIX}:${result.reason}`);
  }

  const versionRef = db.collection(REGISTRY_COLLECTION).doc(versionId);
  try {
    await versionRef.create(candidate);
  } catch (err) {
    throw new HttpsError("aborted", REASON.CREATION_WRITE_FAILED);
  }

  return { versionId, status: initialStatus };
}

// ---------------------------------------------------------------------
// B. resolveActivePolicy — fresh, non-transactional resolution of "the
//    active policy version," per the master plan's own reader contract.
//    Full deep validation (Revision 4 correction 26) runs on every
//    single call against a version document read fresh in that same
//    call — never a cached verdict, never cached bytes.
// ---------------------------------------------------------------------

async function resolveActivePolicy({ db, now = new Date() }) {
  const nowMs = normalizeToEpochMs(now);

  const pointerRef = db
    .collection(COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION)
    .doc(COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID);

  let pointerSnap;
  try {
    pointerSnap = await pointerRef.get();
  } catch (err) {
    unavailable(REASON.POINTER_READ_FAILED);
  }
  const { activeVersionId } = validatePointerSnapshot(pointerSnap);

  const versionRef = db.collection(REGISTRY_COLLECTION).doc(activeVersionId);
  let versionSnap;
  try {
    versionSnap = await versionRef.get();
  } catch (err) {
    unavailable(REASON.VERSION_READ_FAILED);
  }
  if (!versionSnap.exists) {
    failClosed(REASON.VERSION_DANGLING);
  }
  const versionData = versionSnap.data();

  const result = validateCompliancePolicyVersionDocument(versionData, {
    allowedStatuses: [COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE],
    requireActivationEligible: true,
    nowMs,
  });
  if (!result.valid) {
    failClosed(`${REASON.RESOLVE_ACTIVE_INVALID_PREFIX}:${result.reason}`);
  }

  return {
    activeVersionId,
    version: versionData,
    pointerRef,
    versionRef,
  };
}

// ---------------------------------------------------------------------
// C. bootstrapCompliancePolicyRegistry (Revision 4 correction 22) — the
//    ONLY operation permitted to create compliancePolicyRegistryPointer
//    /current, and only when it does not yet exist. Distinct from
//    activatePolicyVersion; never weakens its anomaly check; never
//    auto-creates the target; never repairs anomalies silently.
// ---------------------------------------------------------------------

async function bootstrapCompliancePolicyRegistry({ db, targetVersionId, now = new Date() }) {
  if (!isValidRegistryVersionId(targetVersionId)) {
    throw new HttpsError("invalid-argument", REASON.BOOTSTRAP_TARGET_VERSION_ID_INVALID);
  }
  const nowMs = normalizeToEpochMs(now);

  const pointerRef = db
    .collection(COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION)
    .doc(COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID);
  const targetRef = db.collection(REGISTRY_COLLECTION).doc(targetVersionId);

  return db.runTransaction(async (tx) => {
    // ---- READS + VALIDATION (nothing is written until every one of
    // these has passed) ----

    let pointerSnap;
    try {
      pointerSnap = await tx.get(pointerRef);
    } catch (err) {
      unavailable(REASON.BOOTSTRAP_POINTER_READ_FAILED);
    }
    if (pointerSnap.exists) {
      failClosed(REASON.BOOTSTRAP_POINTER_ALREADY_EXISTS);
    }

    let targetVersionSnap;
    let anomalySnap;
    try {
      [targetVersionSnap, anomalySnap] = await Promise.all([
        tx.get(targetRef),
        tx.get(
          db
            .collection(REGISTRY_COLLECTION)
            .where("status", "==", COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE)
            .limit(2)
        ),
      ]);
    } catch (err) {
      unavailable(REASON.BOOTSTRAP_ANOMALY_QUERY_FAILED);
    }

    // Bounded anomaly check — for bootstrap the required invariant is
    // ZERO active versions (there is no pointer yet to legitimately
    // name one). limit(2), not limit(1), for consistency with ordinary
    // activation's identical anomaly-check shape — functionally either
    // bound distinguishes zero from nonzero, but sharing one bound
    // means this module has exactly one anomaly-query shape to reason
    // about, at negligible extra cost in the vanishingly rare
    // anomalous case.
    const anomalyDocs = anomalySnap.docs || [];
    if (anomalyDocs.length !== 0) {
      failClosed(`${REASON.BOOTSTRAP_ANOMALY_ACTIVE_COUNT_NONZERO}:${anomalyDocs.length}`);
    }

    if (!targetVersionSnap.exists) {
      failClosed(REASON.BOOTSTRAP_TARGET_MISSING);
    }
    const targetVersionData = targetVersionSnap.data();
    const targetResult = validateCompliancePolicyVersionDocument(targetVersionData, {
      allowedStatuses: [COMPLIANCE_POLICY_REGISTRY_STATUS.DRAFT],
      requireActivationEligible: true,
      nowMs,
    });
    if (!targetResult.valid) {
      failClosed(`${REASON.BOOTSTRAP_TARGET_INVALID_PREFIX}:${targetResult.reason}`);
    }

    // ---- WRITES — only reached once every read/validation above has
    // passed. Exactly two documents. `tx.create` for the pointer, never
    // set/merge/update — this is what makes "exactly one concurrent
    // bootstrap attempt may succeed" a Firestore-enforced guarantee: a
    // second, concurrent transaction's tx.create on the same
    // now-existing pointer fails at commit time, triggering Firestore's
    // own automatic retry, which then correctly observes the pointer
    // already exists and fails closed via BOOTSTRAP_POINTER_ALREADY_EXISTS
    // on that retry. ----

    tx.update(targetRef, { status: COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE });
    tx.create(pointerRef, { activeVersionId: targetVersionId });

    return { activeVersionId: targetVersionId };
  });
}

// ---------------------------------------------------------------------
// D. activatePolicyVersion — subsequent-activation-only, unchanged in
//    shape from Revision 3, strengthened in Revision 4 correction 26:
//    both the stored current-active version and the stored target are
//    now fully deep-validated before any write. A malformed current
//    version aborts the entire activation with zero writes, rather than
//    being retired and silently replaced.
// ---------------------------------------------------------------------

async function activatePolicyVersion({ db, targetVersionId, now = new Date() }) {
  if (!isValidRegistryVersionId(targetVersionId)) {
    throw new HttpsError("invalid-argument", REASON.ACTIVATION_TARGET_VERSION_ID_INVALID);
  }
  const nowMs = normalizeToEpochMs(now);

  const pointerRef = db
    .collection(COMPLIANCE_POLICY_REGISTRY_POINTER_COLLECTION)
    .doc(COMPLIANCE_POLICY_REGISTRY_POINTER_DOC_ID);
  const targetRef = db.collection(REGISTRY_COLLECTION).doc(targetVersionId);

  return db.runTransaction(async (tx) => {
    // ---- READS + VALIDATION (nothing is written until every one of
    // these has passed) ----

    let pointerSnap;
    try {
      pointerSnap = await tx.get(pointerRef);
    } catch (err) {
      unavailable(REASON.POINTER_READ_FAILED);
    }
    const { activeVersionId: currentVersionId } = validatePointerSnapshot(pointerSnap);

    const currentVersionRef = db.collection(REGISTRY_COLLECTION).doc(currentVersionId);

    let currentVersionSnap;
    let targetVersionSnap;
    let anomalySnap;
    try {
      [currentVersionSnap, targetVersionSnap, anomalySnap] = await Promise.all([
        tx.get(currentVersionRef),
        tx.get(targetRef),
        tx.get(
          db
            .collection(REGISTRY_COLLECTION)
            .where("status", "==", COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE)
            .limit(2)
        ),
      ]);
    } catch (err) {
      unavailable(REASON.ACTIVATION_ANOMALY_QUERY_FAILED);
    }

    // Currently-referenced ("outgoing") version must exist and pass the
    // complete authoritative validator — not merely a status check —
    // before this transaction may retire it. A malformed current-active
    // version aborts here, with zero writes; it is never silently
    // retired and replaced.
    if (!currentVersionSnap.exists) {
      failClosed(REASON.VERSION_DANGLING);
    }
    const currentVersionData = currentVersionSnap.data();
    const currentResult = validateCompliancePolicyVersionDocument(currentVersionData, {
      allowedStatuses: [COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE],
      requireActivationEligible: true,
      nowMs,
    });
    if (!currentResult.valid) {
      failClosed(`${REASON.ACTIVATION_CURRENT_INVALID_PREFIX}:${currentResult.reason}`);
    }

    // Target must exist and differ from the current active version,
    // checked BEFORE running the full validator, so a target that
    // happens to equal the current active version (whose status is
    // necessarily `active`, not `draft`) is reported with the more
    // specific ACTIVATION_TARGET_EQUALS_CURRENT reason rather than a
    // generic status-not-allowed one. Since target === current at that
    // point is provably the same, already-validated document, this
    // ordering is always safe.
    if (!targetVersionSnap.exists) {
      failClosed(REASON.ACTIVATION_TARGET_MISSING);
    }
    if (targetVersionId === currentVersionId) {
      failClosed(REASON.ACTIVATION_TARGET_EQUALS_CURRENT);
    }
    const targetVersionData = targetVersionSnap.data();
    const targetResult = validateCompliancePolicyVersionDocument(targetVersionData, {
      allowedStatuses: [COMPLIANCE_POLICY_REGISTRY_STATUS.DRAFT],
      requireActivationEligible: true,
      nowMs,
    });
    if (!targetResult.valid) {
      // Explicitly covers `inactive`: an inactive (dormant/never-
      // activated) version is NOT treated as draft-equivalent — the
      // committed plan defines no transition from `inactive` into an
      // activatable state, so none is invented here. The shared
      // validator's own `allowedStatuses: ['draft']` check rejects it
      // with DOCUMENT_STATUS_NOT_ALLOWED, wrapped below.
      failClosed(`${REASON.ACTIVATION_TARGET_INVALID_PREFIX}:${targetResult.reason}`);
    }

    // Bounded anomaly check (§4): exactly one `active`-status version
    // must exist, and its ID must equal the pointer's own
    // activeVersionId — the concrete mechanism behind "only one version
    // may ever be active." Any disagreement aborts with zero writes.
    const anomalyDocs = anomalySnap.docs || [];
    if (anomalyDocs.length !== 1) {
      failClosed(`${REASON.ACTIVATION_ANOMALY_COUNT_MISMATCH}:${anomalyDocs.length}`);
    }
    const anomalyDoc = anomalyDocs[0];
    if (anomalyDoc.id !== currentVersionId) {
      failClosed(REASON.ACTIVATION_ANOMALY_ID_MISMATCH);
    }
    const anomalyData = typeof anomalyDoc.data === "function" ? anomalyDoc.data() : undefined;
    if (!isPlainObject(anomalyData) || anomalyData.status !== COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE) {
      failClosed(REASON.ACTIVATION_ANOMALY_RESULT_MALFORMED);
    }

    // ---- WRITES — only reached once every read/validation above has
    // passed. Exactly three documents, exactly one field each, no other
    // content touched (immutable policy content is provably untouched:
    // this transaction never reads OR writes `sellerRelationship`,
    // `effectiveFrom`, `createdBy`, `createdAt`, or `changeNote` on
    // either version document). ----

    tx.update(currentVersionRef, { status: COMPLIANCE_POLICY_REGISTRY_STATUS.RETIRED });
    tx.update(targetRef, { status: COMPLIANCE_POLICY_REGISTRY_STATUS.ACTIVE });
    tx.update(pointerRef, { activeVersionId: targetVersionId });

    return {
      previousActiveVersionId: currentVersionId,
      activeVersionId: targetVersionId,
    };
  });
}

module.exports = {
  createCompliancePolicyVersion,
  resolveActivePolicy,
  bootstrapCompliancePolicyRegistry,
  activatePolicyVersion,
  validateCompliancePolicyVersionDocument,
  // Exported for tests only.
  isValidRegistryVersionId,
  REASON,
};
