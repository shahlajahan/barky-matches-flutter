"use strict";

// Petsupo Marketplace P1-A compliance foundation — Revision 28 (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §10.1 "Pilot Product Approval contract", §13.1, §17 step 21d2):
// `approvePilotProduct`/`revokePilotProductApproval` (admin-only) and
// `unpublishPilotProductForRevision` (seller-authorized) — the sole
// paths by which a product document's `pilotProductApproval` object,
// `isActive`, and (alongside `reviewProductModeration`, permanently
// blocked) `moderationStatus` may ever be written for a pilot product,
// and the sole (business-level) writers of `pilotActiveProductCount`
// besides the shared `deactivateAllPilotProducts` helper's two other
// call sites (`marketplaceSellerActivation.js`'s revocation cascade,
// `functions/index.js`'s account-deletion cascade and business-deletion
// trigger). Every client-SDK write to any of these fields is denied by
// `firestore.rules` — only these Admin-SDK/`assertCallerOwnsBusiness`-
// gated operations may perform it.
//
// Mirrors `marketplaceSellerActivation.js`'s own exact shape:
// `requireAdmin()`/`assertCallerOwnsBusiness()` before any write, a
// strict request-field allowlist, one Firestore transaction reading
// fresh state and committing the state write plus its own audit event
// together, and an `{ ..., idempotent }` response distinguishing a real
// transition from a no-op replay. Never trusts any client-supplied
// identity, timestamp, or state beyond the request's own
// `businessId`/`productId` and (for `approvePilotProduct`) the admin's
// own attested `allowedPilotCategory`/`reviewedContentFingerprint`/
// `attestNoProhibitedClaim` — everything else is read fresh, inside the
// same transaction that commits.

const crypto = require("node:crypto");
const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

const { requireAdmin } = require("../../moderation/adminAuth");
const {
  PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES,
} = require("./complianceConstants");
const { assertCallerOwnsBusiness } = require("./complianceUploadSessions");

const BUSINESSES_COLLECTION = "businesses";
const AUDIT_EVENTS_COLLECTION = "pilotProductApprovalAuditEvents";
const PILOT_PRODUCT_ACTIVE_LIMIT = 5;

// §10.1 "allowedPilotCategory, exact closed 8-value enum" — verified
// against §21.12's own text, not broadened. Harnesses have no enum
// value at all.
const ALLOWED_PILOT_CATEGORIES = Object.freeze([
  "food",
  "treats",
  "litter",
  "toys",
  "collars_leads",
  "beds",
  "bowls",
  "grooming_tools",
]);

// §10.1 schema — closed `reasonCode` enum.
const REASON_CODE = Object.freeze({
  APPROVED: "pilot_approved",
  REVOKED_ADMIN_MANUAL: "pilot_revoked_admin_manual",
  REVOKED_CONTENT_CHANGED: "pilot_revoked_content_changed",
  REVOKED_SELLER_DEACTIVATED: "pilot_revoked_seller_deactivated",
  REVOKED_BUSINESS_DELETED: "pilot_revoked_business_deleted",
});

// Reason codes an admin's own `revokePilotProductApproval` call may
// choose between — never the two cascade-only system reasons, never
// `pilot_approved` itself.
const ADMIN_REVOKE_REASON_CODES = Object.freeze([
  REASON_CODE.REVOKED_ADMIN_MANUAL,
  REASON_CODE.REVOKED_CONTENT_CHANGED,
]);

// §10.1 "Frozen bound-field set, corrected" — kept byte-identical to
// `firestore.rules`' own `pilotApprovalBoundFields()`, per the plan's
// own "exact correspondence" requirement. `sku`/`businessId`/`createdAt`
// deliberately excluded — each already immutable via its own separate
// predicate.
function pilotApprovalBoundFields() {
  return [
    "name",
    "description",
    "price",
    "currency",
    "media",
    "category",
    "brand",
    "barcode",
    "salePrice",
    "kdvRate",
    "sellerRelationship",
  ];
}

const DECISIONS_COLLECTION = "productComplianceDecisions";

function businessRef(db, businessId) {
  return db.collection(BUSINESSES_COLLECTION).doc(businessId);
}

function decisionRef(db, productId) {
  return db.collection(DECISIONS_COLLECTION).doc(productId);
}

// Marketplace Revision 30 §H (Slice 6) — the decision half of the approval
// gate. Fail closed on every non-affirmative outcome; a decision that cannot
// be proven current and provenance-complete is not a decision.
//
// Deliberately NOT here: seller activation (already enforced above), the
// operative pilot-category narrowing, and the Rules-side derivation. Those
// are Revision 30 §J slice 7 and are not pulled forward.
function assertUsableComplianceDecision({ decision, businessId, product, now }) {
  const deny = (reasonCode) => {
    throw new HttpsError(
      "failed-precondition",
      "Product is not eligible for pilot approval",
      { reasonCode }
    );
  };

  if (!decision || typeof decision !== "object" || Array.isArray(decision)) {
    deny("compliance-decision-missing");
  }
  // Provenance must be complete and well-formed — a decision missing its own
  // identity cannot be bound into a fingerprint at all.
  if (
    typeof decision.decisionHash !== "string" ||
    decision.decisionHash.length === 0 ||
    typeof decision.policyVersion !== "string" ||
    decision.policyVersion.length === 0 ||
    typeof decision.evidenceRevision !== "number" ||
    !Number.isInteger(decision.evidenceRevision) ||
    !Array.isArray(decision.activeEvidenceRefs)
  ) {
    deny("compliance-decision-malformed");
  }
  // The decision must belong to THIS business — never another's.
  if (decision.businessId !== businessId) {
    deny("compliance-decision-business-mismatch");
  }
  // Positive allowlist. Unknown, unresolved, incomplete and negative
  // statuses all land outside it.
  if (!PRODUCT_COMPLIANCE_ELIGIBLE_STATUSES.includes(decision.effectiveStatus)) {
    deny("compliance-decision-not-eligible");
  }
  // A decision with no active evidence is never eligible, whatever its
  // status field claims.
  if (decision.activeEvidenceRefs.length === 0) {
    deny("compliance-decision-no-evidence");
  }
  // Expiry is evaluated against SERVER time, inside this transaction.
  const validUntilMs = millisOrNull(decision.validUntil);
  if (!Number.isFinite(validUntilMs) || !(validUntilMs > now)) {
    deny("compliance-decision-expired");
  }
  // §F — the decision must have been computed for the product's own current
  // generation. A recreated business cannot inherit an earlier decision.
  const productGeneration = product ? product.marketplaceBusinessGenerationId : undefined;
  if (
    typeof productGeneration !== "string" ||
    productGeneration.length === 0
  ) {
    deny("compliance-decision-generation-unprovable");
  }
}

function productRef(db, businessId, productId) {
  return db
    .collection(BUSINESSES_COLLECTION)
    .doc(businessId)
    .collection("products")
    .doc(productId);
}

function assertNonEmptyString(value, fieldName) {
  if (typeof value !== "string" || value.length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required`);
  }
  return value;
}

function assertValidRequestShape(data, allowedFields) {
  const payload = data || {};
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    throw new HttpsError("invalid-argument", "Request must be an object");
  }
  if (!Object.keys(payload).every((key) => allowedFields.includes(key))) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  return payload;
}

// §10.1 "Critical technical constraint... structural, not a hash
// comparison" — the server-side fingerprint IS the hash comparison,
// computed here with full Node.js crypto access. Canonical: every
// object's own keys sorted at every nesting level (never touching
// array element order, which is itself meaningful for `media`).
function canonicalStringify(value) {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalStringify).join(",")}]`;
  }
  if (value && typeof value === "object") {
    const keys = Object.keys(value).sort();
    return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalStringify(value[k])}`).join(",")}}`;
  }
  return JSON.stringify(value === undefined ? null : value);
}

function computeContentFingerprint(product) {
  const picked = {};
  for (const key of pilotApprovalBoundFields()) {
    if (Object.prototype.hasOwnProperty.call(product, key)) {
      picked[key] = product[key];
    }
  }
  return crypto.createHash("sha256").update(canonicalStringify(picked)).digest("hex");
}

// Marketplace Revision 30 §H / §J Slice 6 — the approval fingerprint's
// evidence half.
//
// §H, verbatim: "the fingerprint's bound-field set is extended to include the
// effective evidence decision and its revision, so any evidence change
// invalidates a prior approval exactly as a content change does".
//
// Only fields §H names are bound; no additional business policy is invented:
//   decisionHash      — the decision's own canonical identity
//   policyVersion     — which policy produced it
//   evidenceRevision  — the business compliance epoch it was computed against
//   effectiveStatus   — so a status flip alone invalidates
//   validUntil        — the compliance validity boundary
//   evidenceDigest    — a canonical digest of the active evidence references
//
// ORDERING. `activeEvidenceRefs` is a set in meaning, not a sequence: the same
// two documents matched in either order are the SAME evidence and must not
// produce two fingerprints. Each ref is reduced to `documentId|scopeId` and the
// list is sorted before hashing. This is deliberately unlike `media`, whose
// array order is real product content and is preserved by canonicalStringify.
function canonicalEvidenceDigest(activeEvidenceRefs) {
  if (!Array.isArray(activeEvidenceRefs)) return null;
  const parts = activeEvidenceRefs
    .filter((r) => r && typeof r.documentId === "string" && typeof r.scopeId === "string")
    .map((r) => `${r.documentId}|${r.scopeId}`)
    .sort();
  // A ref list that contained malformed entries is not silently narrowed to
  // its well-formed subset: the count is bound too, so dropping one changes
  // the digest.
  return crypto
    .createHash("sha256")
    .update(canonicalStringify({ count: activeEvidenceRefs.length, refs: parts }))
    .digest("hex");
}

function computeApprovalFingerprint(product, decision) {
  const content = computeContentFingerprint(product);
  const bound = {
    content,
    // Identity of the product/business the approval is for, so a fingerprint
    // can never be replayed against another product or a recreated business.
    businessId: product ? product.businessId : null,
    marketplaceBusinessGenerationId: product
      ? product.marketplaceBusinessGenerationId
      : null,
    decisionHash: decision ? decision.decisionHash : null,
    policyVersion: decision ? decision.policyVersion : null,
    evidenceRevision: decision ? decision.evidenceRevision : null,
    effectiveStatus: decision ? decision.effectiveStatus : null,
    validUntil: decision ? millisOrNull(decision.validUntil) : null,
    evidenceDigest: decision ? canonicalEvidenceDigest(decision.activeEvidenceRefs) : null,
  };
  return crypto.createHash("sha256").update(canonicalStringify(bound)).digest("hex");
}

// Timestamps must reduce to a stable scalar: two Firestore Timestamp objects
// for the same instant must not hash differently.
function millisOrNull(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  return null;
}

function isValidGenerationId(value) {
  return typeof value === "string" && value.length > 0;
}

// §10.1 "What pilotActiveProductCount == 0 mechanically proves" /
// "Business creation and legacy behavior" — absence-safe, integer-only.
function readCounter(businessData) {
  const raw = businessData ? businessData.pilotActiveProductCount : undefined;
  if (raw === undefined) return 0;
  if (typeof raw !== "number" || !Number.isInteger(raw)) return null; // malformed sentinel
  return raw;
}

function isCurrentlyActivePilotApproval(productData) {
  const approval = productData && productData.pilotProductApproval;
  return Boolean(
    approval &&
      typeof approval === "object" &&
      !Array.isArray(approval) &&
      approval.active === true
  );
}

function buildAuditEventPayload({
  businessId,
  productId,
  action,
  adminUid,
  resultingActiveState,
  reasonCode,
}) {
  return {
    businessId,
    productId,
    action,
    adminUid: adminUid || null,
    occurredAt: admin.firestore.FieldValue.serverTimestamp(),
    resultingActiveState,
    reasonCode,
  };
}

// §10.1 "Shared cascade/cleanup helper, exact" — given an already-open
// transaction, deactivates every currently-active pilot product under
// `businessId` and resets its counter to 0. Exported for reuse by
// `marketplaceSellerActivation.js`'s revocation cascade and
// `functions/index.js`'s account-deletion cascade / business-deletion
// trigger — the *exact same* logic, extracted once, never duplicated.
async function deactivateAllPilotProducts(tx, db, businessId, { reasonCode }) {
  const bizRef = businessRef(db, businessId);
  // Read the business document's own existence *before* staging any
  // write below (all transaction reads must precede all writes). The
  // three call sites of this helper differ on exactly this point: the
  // seller-revocation cascade and the account-deletion merged
  // transaction both call this while the business document still
  // exists; the safety-net `deactivatePilotProductsOnBusinessDeleted`
  // trigger calls it *after* the business document is already gone —
  // `tx.update()` on an absent document throws at commit, so the
  // counter-reset write below is conditioned on this read.
  const bizSnap = await tx.get(bizRef);

  const productsQuery = db
    .collection(BUSINESSES_COLLECTION)
    .doc(businessId)
    .collection("products")
    .where("pilotProductApproval.active", "==", true);
  const activeSnap = await tx.get(productsQuery);

  for (const doc of activeSnap.docs) {
    tx.update(doc.ref, {
      "pilotProductApproval.active": false,
      "pilotProductApproval.revokedAt": admin.firestore.FieldValue.serverTimestamp(),
      "pilotProductApproval.revokedBy": null,
      "pilotProductApproval.revokedByKind": "system",
      "pilotProductApproval.reasonCode": reasonCode,
      isActive: false,
      moderationStatus: "pending_review",
    });
    const eventRef = db.collection(AUDIT_EVENTS_COLLECTION).doc();
    tx.create(
      eventRef,
      buildAuditEventPayload({
        businessId,
        productId: doc.id,
        action: "cascade_revoke",
        adminUid: null,
        resultingActiveState: false,
        reasonCode,
      })
    );
  }

  if (bizSnap.exists) {
    tx.update(bizRef, { pilotActiveProductCount: 0 });
  }

  return activeSnap.docs.length;
}

const APPROVE_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "productId",
  "allowedPilotCategory",
  "reviewedContentFingerprint",
  "attestNoProhibitedClaim",
]);

async function approvePilotProduct({ db, auth, data }) {
  const adminUid = await requireAdmin(db, { auth });
  const payload = assertValidRequestShape(data, APPROVE_ALLOWED_FIELDS);
  const businessId = assertNonEmptyString(payload.businessId, "businessId");
  const productId = assertNonEmptyString(payload.productId, "productId");
  if (!ALLOWED_PILOT_CATEGORIES.includes(payload.allowedPilotCategory)) {
    throw new HttpsError("invalid-argument", "allowedPilotCategory is invalid");
  }
  const reviewedContentFingerprint = assertNonEmptyString(
    payload.reviewedContentFingerprint,
    "reviewedContentFingerprint"
  );
  if (payload.attestNoProhibitedClaim !== true) {
    throw new HttpsError("invalid-argument", "attestNoProhibitedClaim must be true");
  }

  const result = await db.runTransaction(async (tx) => {
    const bizRef = businessRef(db, businessId);
    const bizSnap = await tx.get(bizRef);
    if (!bizSnap.exists) {
      throw new HttpsError("not-found", "Business not found");
    }
    const businessData = bizSnap.data();

    const prodRef = productRef(db, businessId, productId);
    const prodSnap = await tx.get(prodRef);
    if (!prodSnap.exists) {
      throw new HttpsError("not-found", "Product not found");
    }
    const product = prodSnap.data() || {};
    if (product.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Product does not belong to the specified business");
    }

    const activation = businessData.marketplaceSellerActivation;
    const sellerActive = Boolean(
      activation &&
        typeof activation === "object" &&
        !Array.isArray(activation) &&
        activation.active === true
    );
    if (!sellerActive) {
      throw new HttpsError("failed-precondition", "Seller is not active", {
        reasonCode: "seller-not-active",
      });
    }

    // Marketplace Revision 30 §H / §J Slice 6 — the effective compliance
    // decision, read INSIDE this transaction so it joins the read set. A
    // concurrent change to the decision therefore aborts and retries this
    // approval against fresh canonical state; a stale admin screen can never
    // approve against a decision that has already moved on.
    //
    // Nothing about the decision is accepted from the caller. The request
    // schema carries no decision id, hash, revision or policy version, and
    // the values used below are read here, not asserted.
    const decisionSnap = await tx.get(decisionRef(db, productId));
    const decision = decisionSnap.exists ? decisionSnap.data() : null;

    // Idempotent replay: already active with an unchanged fingerprint —
    // no write of any kind, skipped entirely before the limit check.
    const alreadyActive = isCurrentlyActivePilotApproval(product);
    const liveFingerprint = computeApprovalFingerprint(product, decision);
    if (alreadyActive && product.pilotProductApproval.reviewedContentFingerprint === liveFingerprint) {
      return { active: true, idempotent: true };
    }

    // §H — a positive, current, provenance-complete decision is required
    // before any approval. Fail closed on missing, non-positive, unresolved,
    // malformed, stale or expired. This is the decision half of §H's gate;
    // the remaining §H conditions and the Rules half are Slice 7.
    assertUsableComplianceDecision({ decision, businessId, product, now: Date.now() });

    if (product.moderationStatus !== "pending_review") {
      throw new HttpsError("failed-precondition", "Product is not eligible for pilot approval", {
        reasonCode: "invalid-transition",
      });
    }

    const counter = readCounter(businessData);
    if (counter === null) {
      throw new HttpsError("failed-precondition", "Counter state is malformed", {
        reasonCode: "counter-malformed",
      });
    }
    if (counter >= PILOT_PRODUCT_ACTIVE_LIMIT) {
      throw new HttpsError("resource-exhausted", "Active pilot product limit reached", {
        reasonCode: "limit-exceeded",
      });
    }

    if (!isValidGenerationId(businessData.marketplaceBusinessGenerationId)) {
      throw new HttpsError("failed-precondition", "Business generation is not initialized", {
        reasonCode: "generation-not-initialized",
      });
    }
    if (product.marketplaceBusinessGenerationId !== businessData.marketplaceBusinessGenerationId) {
      throw new HttpsError("failed-precondition", "Product generation is stale", {
        reasonCode: "stale-generation",
      });
    }

    if (reviewedContentFingerprint !== liveFingerprint) {
      throw new HttpsError("failed-precondition", "Reviewed content is stale", {
        reasonCode: "stale-content",
      });
    }

    tx.update(prodRef, {
      pilotProductApproval: {
        schemaVersion: 1,
        active: true,
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
        approvedBy: adminUid,
        revokedAt: null,
        revokedBy: null,
        revokedByKind: null,
        allowedPilotCategory: payload.allowedPilotCategory,
        reviewedContentFingerprint,
        reviewedProductRevision:
          typeof product.productInputRevision === "number" ? product.productInputRevision : 0,
        reasonCode: REASON_CODE.APPROVED,
      },
      isActive: true,
      moderationStatus: "approved",
    });
    tx.update(bizRef, { pilotActiveProductCount: admin.firestore.FieldValue.increment(1) });
    const eventRef = db.collection(AUDIT_EVENTS_COLLECTION).doc();
    tx.create(
      eventRef,
      buildAuditEventPayload({
        businessId,
        productId,
        action: "approve",
        adminUid,
        resultingActiveState: true,
        reasonCode: REASON_CODE.APPROVED,
      })
    );

    return { active: true, idempotent: false };
  });

  return { businessId, productId, ...result };
}

const REVOKE_ALLOWED_FIELDS = Object.freeze(["businessId", "productId", "reasonCode"]);

async function revokePilotProductApproval({ db, auth, data }) {
  const adminUid = await requireAdmin(db, { auth });
  const payload = assertValidRequestShape(data, REVOKE_ALLOWED_FIELDS);
  const businessId = assertNonEmptyString(payload.businessId, "businessId");
  const productId = assertNonEmptyString(payload.productId, "productId");
  if (!ADMIN_REVOKE_REASON_CODES.includes(payload.reasonCode)) {
    throw new HttpsError("invalid-argument", "reasonCode is invalid");
  }

  const result = await db.runTransaction(async (tx) => {
    const bizRef = businessRef(db, businessId);
    const bizSnap = await tx.get(bizRef);
    if (!bizSnap.exists) {
      throw new HttpsError("not-found", "Business not found");
    }

    const prodRef = productRef(db, businessId, productId);
    const prodSnap = await tx.get(prodRef);
    if (!prodSnap.exists) {
      throw new HttpsError("not-found", "Product not found");
    }
    const product = prodSnap.data() || {};
    if (product.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Product does not belong to the specified business");
    }

    if (!isCurrentlyActivePilotApproval(product)) {
      return { active: false, idempotent: true };
    }

    tx.update(prodRef, {
      "pilotProductApproval.active": false,
      "pilotProductApproval.revokedAt": admin.firestore.FieldValue.serverTimestamp(),
      "pilotProductApproval.revokedBy": adminUid,
      "pilotProductApproval.revokedByKind": "admin",
      "pilotProductApproval.reasonCode": payload.reasonCode,
      isActive: false,
      moderationStatus: "pending_review",
    });
    tx.update(bizRef, { pilotActiveProductCount: admin.firestore.FieldValue.increment(-1) });
    const eventRef = db.collection(AUDIT_EVENTS_COLLECTION).doc();
    tx.create(
      eventRef,
      buildAuditEventPayload({
        businessId,
        productId,
        action: "revoke",
        adminUid,
        resultingActiveState: false,
        reasonCode: payload.reasonCode,
      })
    );

    return { active: false, idempotent: false };
  });

  return { businessId, productId, ...result };
}

const UNPUBLISH_ALLOWED_FIELDS = Object.freeze(["businessId", "productId"]);

async function unpublishPilotProductForRevision({ db, auth, data }) {
  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Login required");
  }
  const payload = assertValidRequestShape(data, UNPUBLISH_ALLOWED_FIELDS);
  const businessId = assertNonEmptyString(payload.businessId, "businessId");
  const productId = assertNonEmptyString(payload.productId, "productId");

  const result = await db.runTransaction(async (tx) => {
    await assertCallerOwnsBusiness({ db, businessId, uid: auth.uid, tx });

    const prodRef = productRef(db, businessId, productId);
    const prodSnap = await tx.get(prodRef);
    if (!prodSnap.exists) {
      throw new HttpsError("not-found", "Product not found");
    }
    const product = prodSnap.data() || {};
    if (product.businessId !== businessId) {
      throw new HttpsError("permission-denied", "Product does not belong to the specified business");
    }

    if (!isCurrentlyActivePilotApproval(product)) {
      return { active: false, idempotent: true };
    }

    tx.update(prodRef, {
      "pilotProductApproval.active": false,
      "pilotProductApproval.revokedAt": admin.firestore.FieldValue.serverTimestamp(),
      "pilotProductApproval.revokedBy": null,
      "pilotProductApproval.revokedByKind": "seller_self_revision",
      "pilotProductApproval.reasonCode": REASON_CODE.REVOKED_CONTENT_CHANGED,
      isActive: false,
      moderationStatus: "pending_review",
    });
    tx.update(businessRef(db, businessId), {
      pilotActiveProductCount: admin.firestore.FieldValue.increment(-1),
    });
    const eventRef = db.collection(AUDIT_EVENTS_COLLECTION).doc();
    tx.create(
      eventRef,
      buildAuditEventPayload({
        businessId,
        productId,
        action: "unpublish_for_revision",
        adminUid: null,
        resultingActiveState: false,
        reasonCode: REASON_CODE.REVOKED_CONTENT_CHANGED,
      })
    );

    return { active: false, idempotent: false };
  });

  return { businessId, productId, ...result };
}

module.exports = {
  approvePilotProduct,
  revokePilotProductApproval,
  unpublishPilotProductForRevision,
  deactivateAllPilotProducts,
  pilotApprovalBoundFields,
  computeContentFingerprint,
  computeApprovalFingerprint,
  canonicalEvidenceDigest,
  ALLOWED_PILOT_CATEGORIES,
  REASON_CODE,
  AUDIT_EVENTS_COLLECTION,
  PILOT_PRODUCT_ACTIVE_LIMIT,
};
