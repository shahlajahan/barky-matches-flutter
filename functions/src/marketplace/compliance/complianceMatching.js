"use strict";

// Petsupo Marketplace P1-A compliance foundation — Slice 4.3 (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §10/§13.1, Revision 6 correction 35, extended Revision 7 corrections
// 39/41/42, corrected per Revision 9 correction 49): the bounded matching
// engine — policy-branch selection, the seven relationship-filtered
// complianceDocumentScopes candidate queries, sku_set member resolution,
// the coverage-first/extras candidate-selection algorithm, source-
// document verification, and the deterministic productEvidenceLinks ID
// formula. Consumed only by complianceProductRecompute.js's
// `recomputeProductComplianceStatus` — not wired into functions/index.js,
// no onCall/HTTP/trigger entry point exists for this module.
//
// Every read this module issues goes through the caller's own `tx`
// (Firestore Transaction) — this module never opens its own transaction
// and never writes anything. All accounting (queries / point reads /
// returned documents) is tracked on the caller-supplied `counters`
// object so the ≤8-operation / ≤42-read bound (§10) can be asserted
// directly against real numbers, not inferred.
//
// Revision 9 correction 49 — the prior global `(approvedAt, documentId)`
// cross-type cap-selection is replaced entirely by a coverage-first/
// extras algorithm: every required slot gets an independent, ordered
// attempt at the ≤10-unique-source-read budget BEFORE any slot's
// redundant evidence can consume it. Two distinct identities are never
// conflated: source-read identity (`documentId`, ≤10 unique reads,
// cached and reused across every scope candidate referencing it) and
// evidence-reference identity (`(documentId, scopeId)` pair, ≤10 unique
// refs). Revision 9 correction 50 — truncation accounting is tracked
// throughout selection so the caller can emit the frozen
// complianceReviewEvents truncation event.

const crypto = require("node:crypto");

const {
  COMPLIANCE_SCOPE_TYPE,
  COMPLIANCE_SCOPE_STATUS,
  COMPLIANCE_DOCUMENT_STATUS,
  COMPLIANCE_SCOPE_MEMBER_STATUS,
  COMPLIANCE_SCOPE_MEMBER_IDENTIFIER_TYPE,
  LOOKUP_LIMIT,
  MATCHED_SCOPE_CAP,
} = require("./complianceConstants");
const { isValidSellerRelationship, isValidComplianceDocumentType } = require("./complianceValidators");
const { computeNormalizedBrandId } = require("./complianceBrandNormalizer");
const { deriveScopeMemberId } = require("./complianceDocumentOperations");

const SCOPES_COLLECTION = "complianceDocumentScopes";
const DOCUMENTS_COLLECTION = "complianceDocuments";
const MEMBERS_SUBCOLLECTION = "members";

// Both caps are the same frozen constant (§4/§10: "This cap is shared,
// by rule, with productEvidenceLinks's own per-product cap... the two
// are never sized independently") — MATCHED_SCOPE_CAP serves as both the
// unique-source-read cap and the unique-evidence-reference cap.
const SOURCE_READ_CAP = MATCHED_SCOPE_CAP;
const ACTIVE_REF_CAP = MATCHED_SCOPE_CAP;

// ---------------------------------------------------------------------
// Exact deterministic productEvidenceLinks ID formula (§4). Random or
// auto-generated IDs are forbidden — this is a pure function of
// {productId, documentId, scopeId}, matching this codebase's established
// domain-separated composite-key convention, but using a literal `\n`
// (U+000A) field delimiter, not `:` — Firestore document IDs are not
// structurally guaranteed delimiter-free, so a component containing the
// delimiter itself must be rejected outright, never silently coerced.
// ---------------------------------------------------------------------

const LINK_ID_DOMAIN_TAG = "compliance_evidence_link";
const LINK_ID_DELIMITER = "\n";

function assertNoDelimiter(value, label) {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`deriveEvidenceLinkId: ${label} must be a non-empty string`);
  }
  if (value.includes(LINK_ID_DELIMITER)) {
    throw new Error(`deriveEvidenceLinkId: ${label} must not contain the delimiter character`);
  }
}

function deriveEvidenceLinkId({ productId, documentId, scopeId }) {
  assertNoDelimiter(productId, "productId");
  assertNoDelimiter(documentId, "documentId");
  assertNoDelimiter(scopeId, "scopeId");
  const canonical = [LINK_ID_DOMAIN_TAG, productId, documentId, scopeId].join(LINK_ID_DELIMITER);
  return crypto.createHash("sha256").update(canonical, "utf8").digest("hex");
}

// ---------------------------------------------------------------------
// Policy selection (§10 "Policy selection", Revision 7 correction 39).
// `product.sellerRelationship` selects EXACTLY one key into
// `activePolicyVersion.sellerRelationship[key]` — never a second,
// category-derived key, never an AND/OR/strongest-policy combination.
// ---------------------------------------------------------------------

const POLICY_SELECTION_REASON = Object.freeze({
  OK: "policy_selection_ok",
  MISSING_RELATIONSHIP: "policy_selection_missing_relationship",
  MALFORMED_RELATIONSHIP: "policy_selection_malformed_relationship",
  BRANCH_ABSENT: "policy_selection_branch_absent",
  BRANCH_INVALID: "policy_selection_branch_invalid",
});

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

// Defense-in-depth structural check only — resolveActivePolicy already
// runs the full authoritative validator (requireActivationEligible:
// true) before ever returning a version, so an `active` version's own
// branch is structurally impossible to be malformed. Checked anyway,
// since trusting an impossibility is more expensive than checking it.
function isStructurallyValidBranch(branch) {
  return (
    isPlainObject(branch) &&
    Array.isArray(branch.requiredDocumentTypeGroups) &&
    branch.requiredDocumentTypeGroups.length >= 1 &&
    branch.requiredDocumentTypeGroups.length <= 5 &&
    Array.isArray(branch.acceptedScopeTypes) &&
    branch.acceptedScopeTypes.length >= 1
  );
}

// `category` never selects a policy branch (Revision 7 correction 39) —
// this function never reads `product.category` at all, by construction.
function selectPolicyBranch({ product, activePolicyVersion }) {
  const relationship = product && product.sellerRelationship;
  if (relationship === undefined || relationship === null) {
    return { ok: false, reason: POLICY_SELECTION_REASON.MISSING_RELATIONSHIP };
  }
  if (!isValidSellerRelationship(relationship)) {
    return { ok: false, reason: POLICY_SELECTION_REASON.MALFORMED_RELATIONSHIP };
  }
  const relationshipMap =
    activePolicyVersion && isPlainObject(activePolicyVersion.sellerRelationship)
      ? activePolicyVersion.sellerRelationship
      : {};
  if (!(relationship in relationshipMap)) {
    return { ok: false, reason: POLICY_SELECTION_REASON.BRANCH_ABSENT };
  }
  const branch = relationshipMap[relationship];
  if (!isStructurallyValidBranch(branch)) {
    return { ok: false, reason: POLICY_SELECTION_REASON.BRANCH_INVALID };
  }
  return { ok: true, reason: POLICY_SELECTION_REASON.OK, relationship, branch };
}

// ---------------------------------------------------------------------
// Structurally-available scope types — every one of the 7 lookup types
// EXCEPT `supplier`/`product_family`, whose matched product-side value
// (`supplierId`/`familyId`) does not exist on any product schema today
// (§10, §19). These two lookup types are never queried; the plan states
// this explicitly, not merely as an optimization.
// ---------------------------------------------------------------------

const ALWAYS_UNAVAILABLE_SCOPE_TYPES = Object.freeze([
  COMPLIANCE_SCOPE_TYPE.SUPPLIER,
  COMPLIANCE_SCOPE_TYPE.PRODUCT_FAMILY,
]);

const STRUCTURALLY_AVAILABLE_SCOPE_TYPES = Object.freeze(
  Object.values(COMPLIANCE_SCOPE_TYPE).filter((t) => !ALWAYS_UNAVAILABLE_SCOPE_TYPES.includes(t))
);

// ---------------------------------------------------------------------
// A candidate query counts as one "operation" and, once `.get()` runs,
// bills exactly `docs.length` reads (never more than LOOKUP_LIMIT, since
// every query below carries an explicit `.limit(LOOKUP_LIMIT)`) — even
// a zero-result query still bills at least 1, per Firestore's own
// billing rule; that minimum is accounted separately by the caller
// summing `1` per query issued, not derived from `docs.length` alone.
// ---------------------------------------------------------------------

async function runScopeCandidateQuery({ tx, db, businessId, sellerRelationship, scopeType, scopeValue, counters }) {
  let query = db
    .collection(SCOPES_COLLECTION)
    .where("businessId", "==", businessId)
    .where("sellerRelationship", "==", sellerRelationship)
    .where("scopeType", "==", scopeType)
    .where("status", "==", COMPLIANCE_SCOPE_STATUS.APPROVED);
  if (scopeValue !== undefined) {
    query = query.where("scopeValue", "==", scopeValue);
  }
  // Deterministic tie-break: approvedAt ASC, then document ID ASC. The
  // document-ID tie-break is Firestore's own implicit final sort key
  // (matching the last explicit orderBy's direction) — no explicit
  // FieldPath.documentId() orderBy call is needed, mirroring §14's own
  // "__name__ needs no explicit entry" index note exactly.
  query = query.orderBy("approvedAt", "asc").limit(LOOKUP_LIMIT);

  counters.operations += 1;
  counters.queries += 1;
  const snap = await tx.get(query);
  counters.pointReads += 1; // Firestore bills a query at least 1 read even on zero results.
  const docs = snap.docs || [];
  if (docs.length > 0) {
    counters.pointReads += docs.length - 1 >= 0 ? docs.length - 1 : 0;
  }
  counters.returnedDocuments += docs.length;
  return docs.map((d) => ({ id: d.id, data: d.data() }));
}

// Product-side matching value per lookup type. Returns `undefined` when
// structurally unavailable (never issue the query) or when the input
// itself is absent/empty (also never issue the query — an equality
// filter against a missing value is never a legal Firestore query, §10
// "Null/missing product-input handling").
function scopeValueForLookupType({ scopeType, product, productId }) {
  switch (scopeType) {
    case COMPLIANCE_SCOPE_TYPE.BUSINESS:
      return typeof product.businessId === "string" && product.businessId.length > 0
        ? product.businessId
        : undefined;
    case COMPLIANCE_SCOPE_TYPE.SUPPLIER:
    case COMPLIANCE_SCOPE_TYPE.PRODUCT_FAMILY:
      return undefined; // Structurally unavailable on every product today.
    case COMPLIANCE_SCOPE_TYPE.BRAND:
      return typeof product.brand === "string" && product.brand.length > 0
        ? computeNormalizedBrandId(product.brand)
        : undefined;
    case COMPLIANCE_SCOPE_TYPE.CATEGORY:
      return typeof product.category === "string" && product.category.length > 0
        ? product.category
        : undefined;
    case COMPLIANCE_SCOPE_TYPE.PRODUCT:
      return typeof productId === "string" && productId.length > 0 ? productId : undefined;
    default:
      return undefined;
  }
}

// The six non-sku_set lookups (rows 1-6). sku_set (row 7) is handled
// separately below since it has no scopeValue filter at all.
const SCOPE_TYPES_WITH_VALUE_FILTER = Object.freeze([
  COMPLIANCE_SCOPE_TYPE.BUSINESS,
  COMPLIANCE_SCOPE_TYPE.SUPPLIER,
  COMPLIANCE_SCOPE_TYPE.BRAND,
  COMPLIANCE_SCOPE_TYPE.CATEGORY,
  COMPLIANCE_SCOPE_TYPE.PRODUCT_FAMILY,
  COMPLIANCE_SCOPE_TYPE.PRODUCT,
]);

function isUsableIdentifier(value) {
  return typeof value === "string" && value.length > 0;
}

// ---------------------------------------------------------------------
// Row 7/8: sku_set candidates + member resolution. The candidate query
// itself always runs (it has no product-side value to be "unavailable")
// — one operation, billed like any other query. Member resolution is a
// SEPARATE, combined operation (§10: "one combined sku_set member-
// resolution operation... not an eighth query") — up to 2 point reads
// per candidate (barcode, sku), each a deterministic point read by known
// ID, never a query/list.
// ---------------------------------------------------------------------

async function runSkuSetLookup({ tx, db, businessId, sellerRelationship, product, counters }) {
  const candidates = await runScopeCandidateQuery({
    tx,
    db,
    businessId,
    sellerRelationship,
    scopeType: COMPLIANCE_SCOPE_TYPE.SKU_SET,
    scopeValue: undefined,
    counters,
  });

  if (candidates.length === 0) {
    return [];
  }

  const identifiers = [];
  if (isUsableIdentifier(product.barcode)) {
    identifiers.push({ type: COMPLIANCE_SCOPE_MEMBER_IDENTIFIER_TYPE.BARCODE, value: product.barcode });
  }
  if (isUsableIdentifier(product.sku)) {
    identifiers.push({ type: COMPLIANCE_SCOPE_MEMBER_IDENTIFIER_TYPE.SKU, value: product.sku });
  }

  if (identifiers.length === 0) {
    // The candidate query above still counted as its own operation; no
    // member-resolution operation is issued at all when there is
    // nothing to look up by.
    return [];
  }

  counters.operations += 1; // The combined member-resolution operation, counted once.

  const matched = [];
  for (const candidate of candidates) {
    for (const identifier of identifiers) {
      const memberId = deriveScopeMemberId({
        scopeId: candidate.id,
        identifierType: identifier.type,
        identifierValue: identifier.value,
      });
      const memberRef = db
        .collection(SCOPES_COLLECTION)
        .doc(candidate.id)
        .collection(MEMBERS_SUBCOLLECTION)
        .doc(memberId);
      const snap = await tx.get(memberRef);
      counters.pointReads += 1;
      if (!snap.exists) continue;
      counters.returnedDocuments += 1;
      const memberData = snap.data();
      if (memberData && memberData.status === COMPLIANCE_SCOPE_MEMBER_STATUS.ACTIVE) {
        matched.push(candidate);
        break; // One matching identifier is enough to match this scope.
      }
    }
  }
  return matched;
}

// ---------------------------------------------------------------------
// Brand's authoritative gate (§10): scopeValue-based candidate narrowing
// is never the match itself — only a candidate whose admin-set
// `verifiedBrandId` equals the product's own normalizedBrandId actually
// matches. Applied in-memory, on the already-bounded (≤LOOKUP_LIMIT)
// candidate set only — never a filter that could discard a candidate
// before the query's own limit(), and never a second query.
// ---------------------------------------------------------------------

function filterBrandCandidatesByVerifiedId(candidates, product) {
  const expected = computeNormalizedBrandId(product.brand);
  return candidates.filter((c) => c.data.verifiedBrandId === expected);
}

// ---------------------------------------------------------------------
// Gather all seven lookups' matched candidates, tagged with the scope
// type that produced them (`matchedVia`). Returns a flat list, NOT yet
// pre-filtered, grouped, or source-verified. Each candidate carries its
// own denormalized `documentType`/`validUntil`/`sellerRelationship`/
// `approvedAt` on `.data` (§4, Revision 9 correction 49) — no extra read
// spent, since the seven queries already fetch the full scope document.
// ---------------------------------------------------------------------

async function gatherMatchedCandidates({ tx, db, product, productId, relationship, counters }) {
  const matched = [];

  for (const scopeType of SCOPE_TYPES_WITH_VALUE_FILTER) {
    const scopeValue = scopeValueForLookupType({ scopeType, product, productId });
    if (scopeValue === undefined) continue; // Structurally unavailable input — never queried.
    let candidates = await runScopeCandidateQuery({
      tx,
      db,
      businessId: product.businessId,
      sellerRelationship: relationship,
      scopeType,
      scopeValue,
      counters,
    });
    if (scopeType === COMPLIANCE_SCOPE_TYPE.BRAND) {
      candidates = filterBrandCandidatesByVerifiedId(candidates, product);
    }
    for (const c of candidates) {
      matched.push({ ...c, matchedVia: scopeType });
    }
  }

  const skuMatches = await runSkuSetLookup({
    tx,
    db,
    businessId: product.businessId,
    sellerRelationship: relationship,
    product,
    counters,
  });
  for (const c of skuMatches) {
    matched.push({ ...c, matchedVia: COMPLIANCE_SCOPE_TYPE.SKU_SET });
  }

  return matched;
}

// ---------------------------------------------------------------------
// Candidate identities (§10, Revision 9 correction 49): a "ref" is keyed
// by (documentId, scopeId); a "group" is keyed by documentId alone and
// retains every unique scope member. `refKey` is the canonical string
// key used for both the evidence-reference dedupe Set and the per-
// candidate disposition map.
// ---------------------------------------------------------------------

function refKey(documentId, scopeId) {
  return `${documentId}\n${scopeId}`;
}

function toMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (typeof value === "number") return value;
  return NaN;
}

// Stable global ordering (§10): (approvedAt ASC, documentId ASC,
// scopeId ASC) — the existing (approvedAt ASC, documentId ASC) tie-
// break, extended with scopeId to resolve one documentId contributing
// multiple scope members.
function compareCandidatesStable(a, b) {
  const aMs = toMillis(a.raw.data.approvedAt);
  const bMs = toMillis(b.raw.data.approvedAt);
  const aSafe = Number.isFinite(aMs) ? aMs : 0;
  const bSafe = Number.isFinite(bMs) ? bMs : 0;
  if (aSafe !== bSafe) return aSafe - bSafe;
  if (a.documentId !== b.documentId) return a.documentId < b.documentId ? -1 : 1;
  if (a.scopeId !== b.scopeId) return a.scopeId < b.scopeId ? -1 : 1;
  return 0;
}

// ---------------------------------------------------------------------
// Pre-filter (§10 "Matched-scope selection... Pre-filter, using only
// denormalized, immutable scope fields — no read spent"). A candidate
// surviving this step is not yet trusted — it is only worth spending a
// source-document read on. Every check here uses ONLY fields already
// returned by the seven queries (§4's denormalized documentType/
// validUntil/sellerRelationship copies) — zero additional reads.
//
// A null/missing/malformed validUntil never passes (never means
// non-expiring, §4/§10) — this is a fail-CLOSED pre-filter, not a
// permissive default.
// ---------------------------------------------------------------------

function preFilterAndGroup({ rawCandidates, branch, requiredEvidenceSlots, relationship, nowMs }) {
  const acceptedScopeTypes = new Set(branch.acceptedScopeTypes);
  const seenKeys = new Set();
  const filtered = [];

  for (const raw of rawCandidates) {
    const data = raw.data;
    const documentId = data.documentId;
    const scopeId = raw.id;
    if (typeof documentId !== "string" || documentId.length === 0) continue;

    // Defense-in-depth re-check of a condition the query itself already
    // enforces (`sellerRelationship == product.sellerRelationship`,
    // §10) — cheap, zero extra read, and closes the gap for any future
    // caller that might reuse this function against unfiltered input.
    if (data.sellerRelationship !== relationship) continue;

    // matchedVia/scopeType must belong to the resolved branch's own
    // acceptedScopeTypes.
    if (!acceptedScopeTypes.has(raw.matchedVia)) continue;

    // documentType must be a valid enum value and belong to at least one
    // required slot's OR-list.
    if (!isValidComplianceDocumentType(data.documentType)) continue;
    const eligibleSlotIndices = [];
    requiredEvidenceSlots.forEach((slot, i) => {
      if (slot.acceptedDocumentTypes.includes(data.documentType)) eligibleSlotIndices.push(i);
    });
    if (eligibleSlotIndices.length === 0) continue;

    // validUntil must be Timestamp-like and strictly > now — a missing/
    // malformed/expired copy never passes, never means non-expiring.
    const validUntilMs = toMillis(data.validUntil);
    if (!Number.isFinite(validUntilMs) || !(validUntilMs > nowMs)) continue;

    const key = refKey(documentId, scopeId);
    if (seenKeys.has(key)) continue; // Exact duplicate (documentId, scopeId) pair — deduped, not truncation.
    seenKeys.add(key);

    filtered.push({ raw, documentId, scopeId, matchedVia: raw.matchedVia, eligibleSlotIndices });
  }

  filtered.sort(compareCandidatesStable);

  const groups = new Map(); // documentId -> filtered-candidate[]
  for (const f of filtered) {
    const list = groups.get(f.documentId) || [];
    list.push(f);
    groups.set(f.documentId, list);
  }

  return { filtered, groups };
}

// ---------------------------------------------------------------------
// Source-document verification (§10, Revision 7 correction 42, extended
// Revision 9 correction 49). For one unique `documentId`, read the
// source once and verify — at zero extra read cost — existence, tenant,
// status, the full product/scope/source sellerRelationship triple-
// equality, strict validUntil > now, AND (Revision 9 correction 49) that
// the source's documentType/validUntil equal EVERY grouped scope's own
// denormalized copy. Any disagreement — between scopes in the group, or
// between any scope and the freshly-read source — treats every scope
// candidate in that group as malformed: none may satisfy a slot, and
// none is silently repaired (§10, exact frozen text).
// ---------------------------------------------------------------------

async function verifyOneSource({ tx, db, documentId, group, product, relationship, nowMs, counters }) {
  const docRef = db.collection(DOCUMENTS_COLLECTION).doc(documentId);
  const snap = await tx.get(docRef);
  counters.pointReads += 1;
  if (!snap.exists) return { verified: false, source: null }; // Dangling documentId — fails closed.
  counters.returnedDocuments += 1;
  const source = snap.data();
  if (!isPlainObject(source)) return { verified: false, source: null };
  if (source.businessId !== product.businessId) return { verified: false, source: null };
  if (source.status !== COMPLIANCE_DOCUMENT_STATUS.APPROVED) return { verified: false, source: null };
  // Full triple-equality: product <-> source document <-> scope.
  if (source.sellerRelationship !== relationship) return { verified: false, source: null };
  const sourceValidUntilMs = toMillis(source.validUntil);
  if (!Number.isFinite(sourceValidUntilMs) || !(sourceValidUntilMs > nowMs)) {
    return { verified: false, source: null }; // Strictly greater.
  }

  // Every grouped scope's own denormalized copy must agree with the
  // source (and, transitively, with each other) — a single disagreement
  // invalidates the WHOLE group, not just the offending scope (§10,
  // exact frozen text: "every scope candidate in that group is treated
  // as malformed: none may satisfy a slot, and none is silently
  // repaired").
  const allCopiesConsistent = group.every((g) => {
    const gData = g.raw.data;
    if (gData.sellerRelationship !== relationship) return false;
    if (gData.sellerRelationship !== source.sellerRelationship) return false;
    if (gData.documentType !== source.documentType) return false;
    const gValidUntilMs = toMillis(gData.validUntil);
    if (!Number.isFinite(gValidUntilMs) || gValidUntilMs !== sourceValidUntilMs) return false;
    return true;
  });

  return { verified: allCopiesConsistent, source: allCopiesConsistent ? source : null };
}

// ---------------------------------------------------------------------
// Coverage-first/extras selection (§10 "Matched-scope selection...
// Pass 1 — coverage" / "Pass 2 — extras", Revision 9 correction 49).
//
// Pass 1: for each required slot, in the policy's own declared order,
// attempt its own eligible candidates in stable order until satisfied
// or budget-exhausted, then STOP for that slot — this is exactly what
// prevents redundant evidence for one slot from crowding out the read
// budget a different, still-unsatisfied slot needs (the confirmed
// Slice 4.3 defect this correction resolves).
//
// Pass 2: sweep every remaining, not-yet-resolved candidate in global
// stable order, adding verified refs while budget remains.
//
// Every (documentId, scopeId) candidate ends this function with exactly
// one recorded disposition — 'selected', 'source_invalid',
// 'omitted_source_read_cap', or 'omitted_active_ref_cap' — which is what
// makes the truncation counts (§10 "Truncation event contract") exact.
// ---------------------------------------------------------------------

async function selectCoverageFirstExtras({
  tx,
  db,
  product,
  relationship,
  branch,
  requiredEvidenceSlots,
  filtered,
  groups,
  nowMs,
  counters,
}) {
  const sourceCache = new Map(); // documentId -> {verified, source}
  const dispositions = new Map(); // refKey -> 'selected' | 'source_invalid' | 'omitted_source_read_cap' | 'omitted_active_ref_cap'
  const selectedRefs = new Map(); // refKey -> {documentId, scopeId, expiresAt, matchedVia}
  const satisfiedSlots = new Array(requiredEvidenceSlots.length).fill(false);
  let sourceReadCount = 0;

  // Returns the cached/verified result for `documentId`, performing at
  // most one real read per unique documentId ever, across both passes.
  // Returns `undefined` (never attempted) when the source-read cap is
  // already exhausted and this documentId has never been read before.
  async function resolveSource(documentId) {
    if (sourceCache.has(documentId)) return sourceCache.get(documentId);
    if (sourceReadCount >= SOURCE_READ_CAP) return undefined;
    const group = groups.get(documentId);
    const result = await verifyOneSource({ tx, db, documentId, group, product, relationship, nowMs, counters });
    sourceReadCount += 1;
    sourceCache.set(documentId, result);
    return result;
  }

  function markCompatibleSlotsSatisfied(source, matchedVia, skipIndex) {
    for (let j = 0; j < requiredEvidenceSlots.length; j++) {
      if (j === skipIndex || satisfiedSlots[j]) continue;
      if (
        requiredEvidenceSlots[j].acceptedDocumentTypes.includes(source.documentType) &&
        branch.acceptedScopeTypes.includes(matchedVia)
      ) {
        satisfiedSlots[j] = true;
      }
    }
  }

  async function attempt(candidate, slotIndex) {
    const key = refKey(candidate.documentId, candidate.scopeId);
    if (dispositions.has(key)) return; // Already resolved (either pass) — no re-verification.

    const result = await resolveSource(candidate.documentId);
    if (result === undefined) {
      dispositions.set(key, "omitted_source_read_cap");
      return;
    }
    if (!result.verified) {
      dispositions.set(key, "source_invalid");
      return;
    }
    if (selectedRefs.size >= ACTIVE_REF_CAP) {
      dispositions.set(key, "omitted_active_ref_cap");
      return;
    }
    selectedRefs.set(key, {
      documentId: candidate.documentId,
      scopeId: candidate.scopeId,
      expiresAt: result.source.validUntil,
      matchedVia: candidate.matchedVia,
    });
    dispositions.set(key, "selected");
    if (slotIndex !== undefined && !satisfiedSlots[slotIndex]) {
      satisfiedSlots[slotIndex] = true;
    }
    markCompatibleSlotsSatisfied(result.source, candidate.matchedVia, slotIndex);
  }

  // --- Pass 1 — coverage. ---
  for (let i = 0; i < requiredEvidenceSlots.length; i++) {
    if (satisfiedSlots[i]) continue;
    const slotCandidates = filtered.filter((f) => f.eligibleSlotIndices.includes(i));
    for (const candidate of slotCandidates) {
      if (satisfiedSlots[i]) break;
      await attempt(candidate, i);
    }
  }

  // --- Pass 2 — extras. ---
  for (const candidate of filtered) {
    await attempt(candidate, undefined);
  }

  let omittedBySourceReadCap = 0;
  let omittedByActiveRefCap = 0;
  for (const disposition of dispositions.values()) {
    if (disposition === "omitted_source_read_cap") omittedBySourceReadCap += 1;
    if (disposition === "omitted_active_ref_cap") omittedByActiveRefCap += 1;
  }

  const activeEvidenceRefs = [...selectedRefs.values()];
  const satisfiedEvidenceSlots = requiredEvidenceSlots.filter((_, i) => satisfiedSlots[i]);
  const allSatisfied = satisfiedSlots.every(Boolean);

  return {
    activeEvidenceRefs,
    satisfiedEvidenceSlots,
    allSatisfied,
    candidateRefs: filtered.length,
    candidateDocuments: groups.size,
    sourceReads: sourceReadCount,
    activeRefs: activeEvidenceRefs.length,
    omittedBySourceReadCap,
    omittedByActiveRefCap,
    truncationOccurred: omittedBySourceReadCap > 0 || omittedByActiveRefCap > 0,
  };
}

// ---------------------------------------------------------------------
// AND-of-OR evidence-requirement evaluation entry point (§4). Each outer
// entry of `requiredDocumentTypeGroups` is one required slot. A required
// group whose acceptedScopeTypes (relationship-wide) has no intersection
// with any structurally-available scope type can NEVER be satisfied by
// any evidence, ever — an ops gap, not a seller gap (§10 "Null/missing
// product-input handling"; §4 "resolves as policy_unresolved... never as
// evidence_missing"). Since the overall requirement is AND across every
// group, one structurally-unsatisfiable group makes the WHOLE decision
// policy_unresolved, regardless of whether other groups already have
// evidence. `manualAdminOverridePermitted` is never consulted here — it
// governs a separate document-review action, never product-eligibility
// (§4's own non-bypass invariant).
// ---------------------------------------------------------------------

async function evaluateRequiredSlots({ tx, db, product, relationship, branch, rawCandidates, nowMs, counters }) {
  const requiredEvidenceSlots = branch.requiredDocumentTypeGroups.map((group) => ({
    acceptedDocumentTypes: [...group],
  }));

  const { filtered, groups } = preFilterAndGroup({
    rawCandidates,
    branch,
    requiredEvidenceSlots,
    relationship,
    nowMs,
  });

  const selection = await selectCoverageFirstExtras({
    tx,
    db,
    product,
    relationship,
    branch,
    requiredEvidenceSlots,
    filtered,
    groups,
    nowMs,
    counters,
  });

  const structurallyUnresolvable = branch.acceptedScopeTypes.every(
    (t) => !STRUCTURALLY_AVAILABLE_SCOPE_TYPES.includes(t)
  );

  return {
    requiredEvidenceSlots,
    satisfiedEvidenceSlots: selection.satisfiedEvidenceSlots,
    activeEvidenceRefs: selection.activeEvidenceRefs,
    allSatisfied: selection.allSatisfied,
    structurallyUnresolvable,
    candidateRefs: selection.candidateRefs,
    candidateDocuments: selection.candidateDocuments,
    sourceReads: selection.sourceReads,
    activeRefs: selection.activeRefs,
    omittedBySourceReadCap: selection.omittedBySourceReadCap,
    omittedByActiveRefCap: selection.omittedByActiveRefCap,
    truncationOccurred: selection.truncationOccurred,
  };
}

// ---------------------------------------------------------------------
// Top-level entry point, called once per recompute from inside the
// caller's own transaction. Does not itself decide the final
// `effectiveStatus` (verified_valid vs evidence_missing vs
// policy_unresolved, etc.) — that composition, plus expiry-threshold
// logic, belongs to complianceProductRecompute.js, which has the full
// decision-building context this module does not need. Also does not
// write the truncation event itself — it only returns the exact counts
// (`candidateRefs`/`candidateDocuments`/`sourceReads`/`activeRefs`/
// `omittedBySourceReadCap`/`omittedByActiveRefCap`/`truncationOccurred`)
// the caller needs to build it, inside the same transaction (§10
// "Truncation event contract").
// ---------------------------------------------------------------------

function createCounters() {
  return { operations: 0, queries: 0, pointReads: 0, returnedDocuments: 0 };
}

async function runComplianceMatching({ tx, db, product, productId, activePolicyVersion, now, counters }) {
  const c = counters || createCounters();
  const nowMs = now instanceof Date ? now.getTime() : Number(now);

  const selection = selectPolicyBranch({ product, activePolicyVersion });
  if (!selection.ok) {
    return {
      policyUnresolved: true,
      policySelectionReason: selection.reason,
      requiredEvidenceSlots: [],
      satisfiedEvidenceSlots: [],
      activeEvidenceRefs: [],
      matchedLinks: [],
      candidateRefs: 0,
      candidateDocuments: 0,
      sourceReads: 0,
      activeRefs: 0,
      omittedBySourceReadCap: 0,
      omittedByActiveRefCap: 0,
      truncationOccurred: false,
      counters: c,
    };
  }

  const rawCandidates = await gatherMatchedCandidates({
    tx,
    db,
    product,
    productId,
    relationship: selection.relationship,
    counters: c,
  });

  const evaluation = await evaluateRequiredSlots({
    tx,
    db,
    product,
    relationship: selection.relationship,
    branch: selection.branch,
    rawCandidates,
    nowMs,
    counters: c,
  });

  const matchedLinks = evaluation.activeEvidenceRefs.map((ref) => ({
    documentId: ref.documentId,
    scopeId: ref.scopeId,
    matchedVia: ref.matchedVia,
  }));

  return {
    policyUnresolved: evaluation.structurallyUnresolvable,
    policySelectionReason: POLICY_SELECTION_REASON.OK,
    requiredEvidenceSlots: evaluation.requiredEvidenceSlots,
    satisfiedEvidenceSlots: evaluation.satisfiedEvidenceSlots,
    allRequiredSlotsSatisfied: evaluation.allSatisfied,
    activeEvidenceRefs: evaluation.activeEvidenceRefs,
    matchedLinks,
    candidateRefs: evaluation.candidateRefs,
    candidateDocuments: evaluation.candidateDocuments,
    sourceReads: evaluation.sourceReads,
    activeRefs: evaluation.activeRefs,
    omittedBySourceReadCap: evaluation.omittedBySourceReadCap,
    omittedByActiveRefCap: evaluation.omittedByActiveRefCap,
    truncationOccurred: evaluation.truncationOccurred,
    counters: c,
  };
}

module.exports = {
  LOOKUP_LIMIT,
  MATCHED_SCOPE_CAP,
  SOURCE_READ_CAP,
  ACTIVE_REF_CAP,
  POLICY_SELECTION_REASON,
  STRUCTURALLY_AVAILABLE_SCOPE_TYPES,

  deriveEvidenceLinkId,
  selectPolicyBranch,
  scopeValueForLookupType,
  runScopeCandidateQuery,
  runSkuSetLookup,
  gatherMatchedCandidates,
  preFilterAndGroup,
  evaluateRequiredSlots,
  runComplianceMatching,
  createCounters,
};
