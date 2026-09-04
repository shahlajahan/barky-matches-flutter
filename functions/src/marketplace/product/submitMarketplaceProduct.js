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
// Revision 34 §6 — the SAME canonical classifier the deletion path uses, so
// submission and cleanup can never disagree about what a legitimate product
// media reference is.
const { classifyMediaReference } = require("./productCleanup");

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

// Revision 34 §5 — the draft-submission category allowlist, kept
// byte-identical to `isKnownSafeProductCategory()` in firestore.rules. This
// is the DRAFT-submission set and is deliberately wider than §21.12's four
// pilot classes: narrowing publication to those classes is Revision 30
// slice 7 and must not be smuggled in here. This is presentation/draft
// metadata and is never the authoritative `pilotProductClass`.
const KNOWN_SAFE_PRODUCT_CATEGORIES = Object.freeze([
  "Food > Dry Food", "Food > Wet Food", "Food > Treats",
  "Accessories > Collar", "Accessories > Leash", "Accessories > Clothing",
  "Health > Vitamins",
  "Toys > Chew Toy", "Toys > Interactive",
]);

const MAX_MEDIA_ENTRIES = 20;
const MAX_NAME_LENGTH = 200;
const MAX_DESCRIPTION_LENGTH = 5000;

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

  assertValidDraftValues(data.draft);

  return { businessId, sku, sellerRelationship: data.sellerRelationship, draft: data.draft };
}

// Revision 34 §5 — value validation ported from firestore.rules.
//
// The Admin SDK bypasses Rules by construction, so once direct client create
// is denied this callable becomes the ONLY create path and must enforce an
// equal-or-stricter contract than the Rules it replaces. Each check below
// mirrors `hasSafeProductIntegrityOnCreate()` exactly; the additional length
// and finiteness bounds are strictly stricter, never weaker.
function assertValidDraftValues(draft) {
  const invalid = (message) =>
    fail("invalid-argument", message, SUBMIT_REASON.INVALID_PRODUCT_DATA);

  // name: string, non-empty after trimming, bounded.
  if (typeof draft.name !== "string") throw invalid("name must be a string");
  if (draft.name.trim().length === 0) throw invalid("name is required");
  if (draft.name.length > MAX_NAME_LENGTH) throw invalid("name is too long");

  // description: optional, but typed and bounded when present.
  if (draft.description !== undefined) {
    if (typeof draft.description !== "string") throw invalid("description must be a string");
    if (draft.description.length > MAX_DESCRIPTION_LENGTH) {
      throw invalid("description is too long");
    }
  }

  // price: a finite number strictly greater than zero. NaN and +/-Infinity
  // are rejected explicitly — Rules' `is number` admits neither, and JSON
  // cannot carry them, but a malformed client could still attempt them.
  if (typeof draft.price !== "number" || !Number.isFinite(draft.price)) {
    throw invalid("price must be a finite number");
  }
  if (draft.price <= 0) throw invalid("price must be greater than zero");

  // stock: an integer of at least 1.
  if (typeof draft.stock !== "number" || !Number.isInteger(draft.stock)) {
    throw invalid("stock must be an integer");
  }
  if (draft.stock < 1) throw invalid("stock must be at least 1");

  // category: a known draft-submission category, never free text.
  if (typeof draft.category !== "string" || !KNOWN_SAFE_PRODUCT_CATEGORIES.includes(draft.category)) {
    throw invalid("category is not a permitted draft category");
  }

  // media: a bounded list of well-shaped entries.
  if (!Array.isArray(draft.media)) throw invalid("media must be a list");
  if (draft.media.length > MAX_MEDIA_ENTRIES) throw invalid("too many media entries");
  for (const entry of draft.media) {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
      throw invalid("each media entry must be an object");
    }
    for (const field of ["originalUrl", "playbackUrl", "thumbnailUrl", "type", "status"]) {
      if (entry[field] !== undefined && entry[field] !== null && typeof entry[field] !== "string") {
        throw invalid("media entry fields must be strings");
      }
    }
  }

  // Numeric shipping/dimension fields: typed and non-negative when present.
  for (const field of [
    "salePrice", "wholesalePrice", "kdvRate", "shippingFee",
    "freeShippingThreshold", "weightKg", "lengthCm", "widthCm", "heightCm",
    "fixedDesi",
  ]) {
    const value = draft[field];
    if (value === undefined || value === null) continue;
    if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
      throw invalid(`${field} must be a finite non-negative number`);
    }
  }
  for (const field of ["stock", "minStock", "preparationDays", "maxDeliveryDays", "returnWindowDays"]) {
    const value = draft[field];
    if (value === undefined || value === null) continue;
    if (typeof value !== "number" || !Number.isInteger(value) || value < 0) {
      throw invalid(`${field} must be a non-negative integer`);
    }
  }
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
async function submitMarketplaceProduct({
  db,
  auth,
  data,
  submissionFlagValue,
  bucketName = null,
  logger = console,
}) {
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

  // Revision 34 §6 — a client-supplied download URL is never authoritative
  // product media. Every reference must resolve, through the same classifier
  // the deletion path uses, to an object in the expected bucket under this
  // business's own `products_raw/{businessId}/` prefix: no external host, no
  // other bucket, no cross-business prefix, no traversal, no malformed value.
  // This runs BEFORE the transaction, so a rejected submission never writes a
  // product document; the client is responsible for removing the objects it
  // uploaded for the failed attempt, which it already does.
  //
  // Limitation, stated precisely: the object path is Business-scoped, so this
  // proves the media belongs to THIS BUSINESS. It does not prove exclusive
  // ownership by this product, and nothing here claims that it does.
  for (const entry of draft.media || []) {
    for (const field of ["originalUrl", "playbackUrl", "thumbnailUrl"]) {
      const value = entry[field];
      if (value === undefined || value === null) continue;
      const verdict = classifyMediaReference({ url: value, businessId, bucketName });
      if (!verdict.deletable) {
        logger.warn("marketplace_submit_media_rejected", { reason: verdict.reason });
        throw fail(
          "invalid-argument",
          "product media is not a valid reference for this business",
          SUBMIT_REASON.INVALID_PRODUCT_DATA
        );
      }
    }
  }

  const businessRef = db.collection(BUSINESSES_COLLECTION).doc(businessId);
  const productRef = businessRef.collection(PRODUCTS_SUBCOLLECTION).doc(productId);

  return db.runTransaction(async (tx) => {
    const businessSnap = await tx.get(businessRef);
    const businessData = businessSnap.exists ? businessSnap.data() || {} : null;

    // Revision 34 §7 — a non-admin caller must not be able to learn whether
    // an arbitrary businessId exists. A missing business, a business owned by
    // someone else, and a missing or malformed `ownerUid` are therefore
    // externally indistinguishable: identical gRPC code, identical message,
    // identical reasonCode. Ownership is re-derived server-side and never
    // inferred from the request or from `auth.uid === businessId`.
    const ownerUid = businessData && businessData.ownerUid;
    if (!businessData || typeof ownerUid !== "string" || ownerUid !== auth.uid) {
      // Structured, identifier-free log so the distinction stays available
      // to operators without ever reaching the caller.
      logger.warn("marketplace_submit_owner_check_failed", {
        reason: !businessData ? "business_absent" : "not_owner",
      });
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
  assertValidDraftValues,
  KNOWN_SAFE_PRODUCT_CATEGORIES,
  MAX_MEDIA_ENTRIES,
  isSubmissionEnabled,
  SUBMIT_REASON,
  SELLER_RELATIONSHIP_VALUES,
  SERVER_OWNED_SUBMIT_FIELDS,
  SELLER_SUBMITTABLE_FIELDS,
  REQUEST_ALLOWED_FIELDS,
  normalizeSku,
  isValidSellerRelationshipValue,
};
