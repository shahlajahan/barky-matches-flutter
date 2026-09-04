// Marketplace Revision 31 prerequisite 1 (docs/plans/marketplace_p1a_
// compliance_review_implementation_plan_2026-08-21.md §0.28 L(1), §0.29 E):
// the server-authoritative seller product submission path.
//
// Why this exists. The legacy client path ran its own Firestore
// transaction and, in the create branch, began with a `tx.get()` of the
// not-yet-existing target product to detect an SKU collision. The
// products `allow read` rule dereferences `resource.data` in every one of
// its branches, and `resource` is null for a document that does not
// exist, so that read was denied for every first-ever product — the
// collision pre-check succeeded only in the collision case. This module
// moves uniqueness enforcement to the Admin SDK, which is not subject to
// Rules, so no client is ever granted a non-existent-document read and no
// product ID can be probed for existence from a client.
//
// What this module deliberately does NOT do. It never approves, activates,
// classifies or publishes anything. `pilotProductClass` (Revision 31 §C)
// is server/admin-owned and is never written here; the created document is
// always an unpublished draft. Final evidence and publication enforcement
// remains Revision 30 §J slice 7 and is not implemented here.
const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

const { SELLER_RELATIONSHIP } = require("../compliance/complianceConstants");

const BUSINESSES_COLLECTION = "businesses";
const PRODUCTS_SUBCOLLECTION = "products";

// Stable, machine-readable reason codes. Every failure this module can
// produce carries exactly one of these in the HttpsError details, so the
// client never has to parse a message string and never has to collapse a
// known failure into a generic error.
const SUBMIT_REASON = Object.freeze({
  MARKETPLACE_DISABLED: "marketplace_disabled",
  SELLER_ACTIVATION_REQUIRED: "seller_activation_required",
  INVALID_SELLER_RELATIONSHIP: "invalid_seller_relationship",
  INVALID_PRODUCT_DATA: "invalid_product_data",
  DUPLICATE_SKU: "duplicate_sku",
  PERMISSION_DENIED: "permission_denied",
  UPLOAD_FAILED: "upload_failed",
  PRODUCT_SUBMISSION_FAILED: "product_submission_failed",
  // Revision 33: the deterministic ID is occupied by a product bound to a
  // previous business generation whose authoritative cleanup has not
  // completed. Never an ordinary duplicate, never an overwrite.
  PREVIOUS_GENERATION_CLEANUP_PENDING: "previous_generation_cleanup_pending",
});

// Revision 33 §B — the submission gate. Deliberately NOT
// MARKETPLACE_LISTING_ENABLED, which gates the public customer catalogue:
// opening seller submission must never open the storefront. Deny-by-default
// in the strictest sense — only the exact string "true" enables it, so
// absent, empty, "TRUE", "1", "yes" and any unknown value all disable.
function isSubmissionEnabled(rawFlagValue) {
  return rawFlagValue === "true";
}

// Revision 30 §B / Revision 31 §C — bound to the already-frozen source
// vocabulary; this module introduces no parallel enum of its own.
const SELLER_RELATIONSHIP_VALUES = Object.freeze(Object.values(SELLER_RELATIONSHIP));

// Fields the server alone owns. A draft carrying any of these is rejected
// outright rather than sanitized, so a seller can never learn which of
// them exist by observing which are silently dropped.
const SERVER_OWNED_SUBMIT_FIELDS = Object.freeze([
  "isActive",
  "moderationStatus",
  "productInputRevision",
  "createdAt",
  "updatedAt",
  "businessId",
  "sku",
  "productId",
  "marketplaceBusinessGenerationId",
  "pilotProductApproval",
  "pilotProductClass",
  "complianceEffectiveStatus",
  "complianceValidUntil",
  "evidenceRevision",
  "complianceUpdatedAt",
  "complianceReasonCode",
  "reservedStock",
  "inventorySchemaVersion",
  "inventoryOperationVersion",
  "inventoryUpdatedAt",
  "reviewedBy",
  "reviewedAt",
]);

// The commercial fields a seller may submit on a draft. Mirrors
// firestore.rules' own `productAllowedFields()` minus every entry in
// SERVER_OWNED_SUBMIT_FIELDS above.
const SELLER_SUBMITTABLE_FIELDS = Object.freeze([
  "allowFreeShipping", "allowPickup", "allowReturns", "allowSameDay",
  "allowedCarrierCodes", "barcode", "brand", "businessLogo", "businessName",
  "category", "currency", "deliveryType", "description", "excludedCities",
  "fixedDesi", "freeShippingThreshold", "hasContractedReturnCarrier",
  "hasSmartPricing", "heightCm", "isFragile", "isOversize", "isPerishable",
  "isShippable", "kdvRate", "lengthCm", "marginPercent", "markupPercent",
  "maxDeliveryDays", "media", "minStock", "name", "originCity",
  "preparationDays", "price", "pricePosition", "returnCarrierCode",
  "returnShippingPayer", "returnWindowDays", "salePrice", "sellerRelationship",
  "shippingFee", "shippingMode", "shippingPayer", "shippingProfile",
  "shippingSnapshot", "stock", "suggestedMaxPrice", "suggestedMinPrice",
  "suggestedPrice", "taxIncluded", "weightKg", "wholesalePrice", "widthCm",
]);

const REQUEST_ALLOWED_FIELDS = Object.freeze([
  "businessId",
  "sku",
  "sellerRelationship",
  "draft",
]);

function fail(httpsCode, message, reasonCode) {
  return new HttpsError(httpsCode, message, { reasonCode });
}

function assertPlainObject(value, message, reasonCode) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw fail("invalid-argument", message, reasonCode);
  }
}

function assertNonEmptyString(value, message, reasonCode) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw fail("invalid-argument", message, reasonCode);
  }
  return value.trim();
}

// Strict membership. No trimming, no case folding, no display-label
// tolerance — a value is either exactly one of the six frozen identifiers
// or it is rejected (Revision 30 §B, §15 items 985-987).
function isValidSellerRelationshipValue(value) {
  return typeof value === "string" && SELLER_RELATIONSHIP_VALUES.includes(value);
}

// Mirrors the client's own SKU cleaning so a seller cannot reach a
// different document ID than the one the UI showed them.
function normalizeSku(rawSku) {
  const sku = assertNonEmptyString(
    rawSku,
    "sku is required",
    SUBMIT_REASON.INVALID_PRODUCT_DATA
  );
  const cleaned = sku
    .toUpperCase()
    .replace(/ /g, "-")
    .replace(/[^A-Z0-9\-_]/g, "");
  if (cleaned.length < 4) {
    throw fail("invalid-argument", "sku is invalid", SUBMIT_REASON.INVALID_PRODUCT_DATA);
  }
  return cleaned;
}

function validateRequest(data) {
  assertPlainObject(data, "Request must be an object", SUBMIT_REASON.INVALID_PRODUCT_DATA);
  for (const key of Object.keys(data)) {
    if (!REQUEST_ALLOWED_FIELDS.includes(key)) {
      throw fail(
        "invalid-argument",
        "Request contains an unsupported field",
        SUBMIT_REASON.INVALID_PRODUCT_DATA
      );
    }
  }
  const businessId = assertNonEmptyString(
    data.businessId,
    "businessId is required",
    SUBMIT_REASON.INVALID_PRODUCT_DATA
  );
  const sku = normalizeSku(data.sku);

  if (!isValidSellerRelationshipValue(data.sellerRelationship)) {
    throw fail(
      "invalid-argument",
      "sellerRelationship is invalid",
      SUBMIT_REASON.INVALID_SELLER_RELATIONSHIP
    );
  }

  assertPlainObject(data.draft, "draft is required", SUBMIT_REASON.INVALID_PRODUCT_DATA);

  for (const key of Object.keys(data.draft)) {
    if (SERVER_OWNED_SUBMIT_FIELDS.includes(key)) {
      throw fail(
        "permission-denied",
        "draft contains a server-owned field",
        SUBMIT_REASON.PERMISSION_DENIED
      );
    }
    if (!SELLER_SUBMITTABLE_FIELDS.includes(key)) {
      throw fail(
        "invalid-argument",
        "draft contains an unsupported field",
        SUBMIT_REASON.INVALID_PRODUCT_DATA
      );
    }
  }

  return { businessId, sku, sellerRelationship: data.sellerRelationship, draft: data.draft };
}

function isCurrentlyActiveSeller(businessData) {
  const activation = businessData && businessData.marketplaceSellerActivation;
  return Boolean(
    activation &&
      typeof activation === "object" &&
      !Array.isArray(activation) &&
      activation.active === true
  );
}

/**
 * Server-authoritative seller product submission.
 *
 * Creates exactly one unpublished draft product, or reports an explicit
 * duplicate. Never approves, activates, classifies or publishes.
 */
async function submitMarketplaceProduct({ db, auth, data, submissionFlagValue }) {
  if (!isSubmissionEnabled(submissionFlagValue)) {
    throw fail(
      "failed-precondition",
      "Marketplace is not enabled",
      SUBMIT_REASON.MARKETPLACE_DISABLED
    );
  }
  if (!auth || !auth.uid) {
    throw fail("unauthenticated", "Login required", SUBMIT_REASON.PERMISSION_DENIED);
  }

  const { businessId, sku, sellerRelationship, draft } = validateRequest(data);
  const productId = `${businessId}_${sku}`;

  const businessRef = db.collection(BUSINESSES_COLLECTION).doc(businessId);
  const productRef = businessRef.collection(PRODUCTS_SUBCOLLECTION).doc(productId);

  return db.runTransaction(async (tx) => {
    const businessSnap = await tx.get(businessRef);
    if (!businessSnap.exists) {
      throw fail("not-found", "Business not found", SUBMIT_REASON.PERMISSION_DENIED);
    }
    const businessData = businessSnap.data() || {};

    // Canonical ownership, re-derived server-side. Never inferred from the
    // request, and never from `auth.uid === businessId`.
    if (businessData.ownerUid !== auth.uid) {
      throw fail(
        "permission-denied",
        "You are not the owner of this business",
        SUBMIT_REASON.PERMISSION_DENIED
      );
    }

    if (!isCurrentlyActiveSeller(businessData)) {
      throw fail(
        "failed-precondition",
        "Marketplace seller activation is required",
        SUBMIT_REASON.SELLER_ACTIVATION_REQUIRED
      );
    }

    const generationId = businessData.marketplaceBusinessGenerationId;
    if (typeof generationId !== "string" || generationId.length === 0) {
      throw fail(
        "failed-precondition",
        "Business generation binding is missing",
        SUBMIT_REASON.PRODUCT_SUBMISSION_FAILED
      );
    }

    // Uniqueness, enforced inside the transaction by the Admin SDK. Two
    // concurrent identical submissions contend on this same document; the
    // loser re-runs, observes the winner's write, and reports a duplicate.
    //
    // Revision 33: uniqueness is scoped to the CURRENT business generation.
    // The document ID stays deterministic — `${businessId}_${sku}`, never
    // generation-scoped, per Revision 19's rejection of an opaque or
    // recomposed product identity — so an occupied ID must be classified,
    // not blindly reported as a duplicate. A product left behind by an
    // earlier generation of a recreated same-ID business is never reused,
    // overwritten, reactivated or adopted: it fails closed, distinctly, so
    // an admin can complete the outstanding authoritative cleanup.
    const existing = await tx.get(productRef);
    if (existing.exists) {
      const existingGeneration = (existing.data() || {})
        .marketplaceBusinessGenerationId;
      const sameGeneration =
        typeof existingGeneration === "string" &&
        existingGeneration.length > 0 &&
        existingGeneration === generationId;
      if (sameGeneration) {
        throw fail(
          "already-exists",
          "SKU already exists",
          SUBMIT_REASON.DUPLICATE_SKU
        );
      }
      // Absent, malformed, or mismatched binding — all treated identically
      // and fail closed. A missing binding is not evidence of belonging to
      // this generation; it is evidence that ownership cannot be proven.
      throw fail(
        "failed-precondition",
        "A product from a previous business generation still occupies this SKU",
        SUBMIT_REASON.PREVIOUS_GENERATION_CLEANUP_PENDING
      );
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const payload = {
      ...draft,
      businessId,
      sku,
      productId,
      sellerRelationship,
      marketplaceBusinessGenerationId: generationId,
      // Server-owned publication state. A seller-submitted product is
      // always an unpublished draft awaiting review; nothing in this path
      // can produce any other state.
      isActive: false,
      moderationStatus: "pending_review",
      productInputRevision: 0,
      createdAt: now,
      updatedAt: now,
    };

    tx.create(productRef, payload);

    return { businessId, productId, sku, created: true };
  });
}

module.exports = {
  submitMarketplaceProduct,
  isSubmissionEnabled,
  SUBMIT_REASON,
  SELLER_RELATIONSHIP_VALUES,
  SERVER_OWNED_SUBMIT_FIELDS,
  SELLER_SUBMITTABLE_FIELDS,
  REQUEST_ALLOWED_FIELDS,
  normalizeSku,
  isValidSellerRelationshipValue,
};
