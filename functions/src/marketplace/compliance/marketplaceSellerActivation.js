"use strict";

// Petsupo Marketplace P1-A compliance foundation — Step 21c2 (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §10.1 "Marketplace seller-activation gate contract", §13.1, §17):
// `grantMarketplaceSellerActivation`/`revokeMarketplaceSellerActivation`
// — the sole, admin-only paths by which a business document's
// `marketplaceSellerActivation` object may ever be written. Every
// client-SDK write to this key is denied by `firestore.rules`
// (`canOwnerUpdateBusinessDocument()`'s protected-key list) — only
// these two Admin-SDK callables may perform it.
//
// Mirrors `productModeration.js`'s own already-established shape
// exactly: `requireAdmin()` before any read, a strict request-field
// allowlist, one Firestore transaction reading fresh state and
// committing the state write plus its own audit event together, and an
// `{ ..., idempotent }` response distinguishing a real transition from
// a no-op replay. Never trusts any client-supplied identity, timestamp,
// or state — only the request's own `businessId` identifies the
// target; `grantedBy`/`revokedBy` are always the authenticated admin's
// own UID, never accepted from the request payload.
//
// The immutable audit log is a new, narrow, dedicated collection
// (`marketplaceSellerActivationAuditEvents`), not a reuse of the
// existing `complianceReviewEvents` collection — that collection's own
// `targetType`/`action` enum vocabulary (`complianceConstants.js`) is
// scoped to product-compliance-document review, a different domain
// than business-level Marketplace seller authorization; reusing it
// would require extending a shared, product-compliance-specific enum
// with business-activation-specific values, exactly the "overloading an
// existing field's meaning" pattern this same gate's own source audit
// already rejected once (§10.1, §0.24). The new collection mirrors
// `complianceReviewEvents`' own exact security posture instead:
// admin-read-only, no client write of any kind (`firestore.rules`).

const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

const { requireAdmin } = require("../../moderation/adminAuth");

const BUSINESSES_COLLECTION = "businesses";
const AUDIT_EVENTS_COLLECTION = "marketplaceSellerActivationAuditEvents";

const REQUEST_ALLOWED_FIELDS = Object.freeze(["businessId"]);

const MARKETPLACE_SELLER_ACTIVATION_ACTION = Object.freeze({
  GRANT: "grant",
  REVOKE: "revoke",
});

function assertNonEmptyString(value, fieldName) {
  if (typeof value !== "string" || value.length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required`);
  }
  return value;
}

function businessRef(db, businessId) {
  return db.collection(BUSINESSES_COLLECTION).doc(businessId);
}

function validateRequest(data) {
  const payload = data || {};
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  if (!Object.keys(payload).every((key) => REQUEST_ALLOWED_FIELDS.includes(key))) {
    throw new HttpsError("invalid-argument", "Request contains an unrecognized field");
  }
  return assertNonEmptyString(payload.businessId, "businessId");
}

// Absent/malformed is treated as "not currently active" for this
// idempotency-comparison purpose only — never itself a Rules-relevant
// value; the Rules layer's own `hasActiveMarketplaceSellerActivation()`
// is the sole authorization mechanism, this is only how the two
// operations below decide whether a write is a real transition.
function isCurrentlyActive(businessData) {
  const activation = businessData && businessData.marketplaceSellerActivation;
  return Boolean(
    activation &&
      typeof activation === "object" &&
      !Array.isArray(activation) &&
      activation.active === true
  );
}

function buildAuditEventPayload({ businessId, action, adminUid, resultingActiveState }) {
  return {
    businessId,
    action,
    adminUid,
    occurredAt: admin.firestore.FieldValue.serverTimestamp(),
    resultingActiveState,
  };
}

async function grantMarketplaceSellerActivation({ db, auth, data }) {
  const adminUid = await requireAdmin(db, { auth });
  const businessId = validateRequest(data);

  const result = await db.runTransaction(async (tx) => {
    const ref = businessRef(db, businessId);
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Business not found");
    }
    const businessData = snapshot.data();

    // --- Idempotent replay: already active. No write of any kind —
    //     no state-object write, no new audit record (§10.1 "Exact
    //     idempotency contract"). ---
    if (isCurrentlyActive(businessData)) {
      return { active: true, idempotent: true };
    }

    // --- Real transition: write the complete current-state object and
    //     exactly one immutable audit event, together, in this same
    //     transaction — committed together or neither. ---
    tx.update(ref, {
      marketplaceSellerActivation: {
        active: true,
        grantedAt: admin.firestore.FieldValue.serverTimestamp(),
        grantedBy: adminUid,
        revokedAt: null,
        revokedBy: null,
      },
    });
    const eventRef = db.collection(AUDIT_EVENTS_COLLECTION).doc();
    tx.create(
      eventRef,
      buildAuditEventPayload({
        businessId,
        action: MARKETPLACE_SELLER_ACTIVATION_ACTION.GRANT,
        adminUid,
        resultingActiveState: true,
      })
    );

    return { active: true, idempotent: false };
  });

  return { businessId, ...result };
}

async function revokeMarketplaceSellerActivation({ db, auth, data }) {
  const adminUid = await requireAdmin(db, { auth });
  const businessId = validateRequest(data);

  const result = await db.runTransaction(async (tx) => {
    const ref = businessRef(db, businessId);
    const snapshot = await tx.get(ref);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Business not found");
    }
    const businessData = snapshot.data();

    // --- Idempotent replay: already inactive (including the absent/
    //     malformed fail-closed-equivalent case). No write of any
    //     kind. ---
    if (!isCurrentlyActive(businessData)) {
      return { active: false, idempotent: true };
    }

    // --- Real transition: preserve the most recent grantedAt/
    //     grantedBy from the fresh in-transaction read; every prior
    //     grant/revoke event, including this one's own now-superseded
    //     grant, remains permanently present in the separate immutable
    //     audit log, untouched by this overwrite. ---
    const existingActivation = businessData.marketplaceSellerActivation;
    tx.update(ref, {
      marketplaceSellerActivation: {
        active: false,
        grantedAt: existingActivation.grantedAt,
        grantedBy: existingActivation.grantedBy,
        revokedAt: admin.firestore.FieldValue.serverTimestamp(),
        revokedBy: adminUid,
      },
    });
    const eventRef = db.collection(AUDIT_EVENTS_COLLECTION).doc();
    tx.create(
      eventRef,
      buildAuditEventPayload({
        businessId,
        action: MARKETPLACE_SELLER_ACTIVATION_ACTION.REVOKE,
        adminUid,
        resultingActiveState: false,
      })
    );

    return { active: false, idempotent: false };
  });

  return { businessId, ...result };
}

module.exports = {
  grantMarketplaceSellerActivation,
  revokeMarketplaceSellerActivation,
  REQUEST_ALLOWED_FIELDS,
  MARKETPLACE_SELLER_ACTIVATION_ACTION,
  AUDIT_EVENTS_COLLECTION,
  BUSINESSES_COLLECTION,
};
