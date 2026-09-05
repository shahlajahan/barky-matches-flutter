"use strict";

// Marketplace Revision 38 §0.36 / Revision 39 §0.37 (Slice 7B-C1) — the ONE
// canonical live product-visibility predicate.
//
// Revision 38 froze twelve conditions for public retrievability and recorded
// that `evaluateLiveProductEligibility` subsumes only some of them. Before
// this module those remaining conditions lived inline inside
// `marketplaceListing.js`, which was fine while list and detail were the only
// consumers. Batch hydration and — far more importantly — checkout now need
// exactly the same predicate, and checkout needs it INSIDE its own
// transaction. Duplicating it would be the same class of defect Revision 37
// closed for approval: the strict predicate on the advisory side and a weaker
// one on the authoritative side.
//
// So: one function, one set of conditions, two read modes.
//
// TRANSACTION-BOUND USE. When `tx` is supplied every authoritative read —
// product, business, and (through the evaluator) decision, policy pointer,
// policy version and business epoch — is issued via `tx.get`, joining the
// caller's read set. That is what lets checkout validate and reserve in one
// atomic boundary instead of performing a non-transactional pre-check and
// then writing, which would leave a TOCTOU window between "eligible" and
// "reserved".

const {
  evaluateLiveProductEligibility,
} = require("../compliance/complianceEligibilityEvaluator");
const {
  isValidPilotProductClass,
} = require("../compliance/complianceConstants");

const BUSINESSES_COLLECTION = "businesses";

// The only business status from which a product may be publicly served or
// purchased. An unknown or absent status fails closed.
const BUSINESS_PUBLISHABLE_STATUSES = Object.freeze(["approved"]);

/// Internal, non-customer-facing reasons. These name WHY a product is not
/// available so that server logs and tests can be precise; they are never
/// returned to a customer, because "which compliance gate did I fail" is
/// exactly the enumeration oracle Revision 38 §0.36 forbids.
const VISIBILITY_REASON = Object.freeze({
  PRODUCT_NOT_FOUND: "visibility_product_not_found",
  BUSINESS_NOT_FOUND: "visibility_business_not_found",
  PRODUCT_BUSINESS_MISMATCH: "visibility_product_business_mismatch",
  PRODUCT_DELETED: "visibility_product_deleted",
  BUSINESS_NOT_PUBLISHABLE: "visibility_business_not_publishable",
  SELLER_NOT_ACTIVE: "visibility_seller_not_active",
  GENERATION_MISMATCH: "visibility_generation_mismatch",
  CLASS_INVALID: "visibility_pilot_class_invalid",
  NOT_ACTIVE: "visibility_not_active",
  NOT_APPROVED: "visibility_not_approved",
  NOT_LIVE_ELIGIBLE: "visibility_not_live_eligible",
  MALFORMED_IDENTITY: "visibility_malformed_identity",
  // An evaluator that THREW, as distinct from one that answered "ineligible".
  // The difference matters at the boundary: a list or batch caller skips the
  // candidate either way, but the single-product detail contract maps an
  // infrastructure failure to `internal` and a genuine absence to
  // `not-found`. Collapsing the two would turn an outage into a silent
  // "product does not exist".
  EVALUATOR_FAILED: "visibility_evaluator_failed",
});

function unavailable(reason) {
  return { visible: false, reason, product: null, business: null };
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.length > 0;
}

function productRef(db, businessId, productId) {
  return db
    .collection(BUSINESSES_COLLECTION)
    .doc(businessId)
    .collection("products")
    .doc(productId);
}

/// Reads a business once per distinct id per request.
///
/// The cache is a prefixed plain object rather than a Map or
/// `Object.create(null)`: `cache.set(...)` and `Object.create(...)` both trip
/// the catalogue module's frozen "no write call of any kind" static guard, and
/// weakening a security guard to accommodate a cache is the wrong trade. The
/// `b:` prefix additionally means a business id of `__proto__` or
/// `constructor` can never collide with an object-prototype key.
async function readBusiness({ db, businessId, tx, businessCache }) {
  const cache = businessCache || {};
  const cacheKey = `b:${businessId}`;
  if (!Object.prototype.hasOwnProperty.call(cache, cacheKey)) {
    let snap = null;
    try {
      const ref = db.collection(BUSINESSES_COLLECTION).doc(businessId);
      snap = await (tx ? tx.get(ref) : ref.get());
    } catch (err) {
      snap = null;
    }
    cache[cacheKey] = snap && snap.exists ? snap.data() || {} : null;
  }
  return cache[cacheKey];
}

/// Answers Revision 38 §0.36 A conditions 1-12 for one product.
///
/// `productSnapshot` may be supplied by a caller that has ALREADY read the
/// product inside its own transaction, so checkout does not read the same
/// document twice. It must be the canonical document at
/// `businesses/{businessId}/products/{productId}`; identity is re-checked
/// here regardless of who supplied it.
async function assessProductVisibility({
  db,
  businessId,
  productId,
  now = new Date(),
  tx,
  businessCache,
  productData,
  evaluator = evaluateLiveProductEligibility,
}) {
  if (!isNonEmptyString(businessId) || !isNonEmptyString(productId)) {
    return unavailable(VISIBILITY_REASON.MALFORMED_IDENTITY);
  }

  // 1. the product exists.
  let product = productData;
  if (product === undefined) {
    let snap = null;
    try {
      const ref = productRef(db, businessId, productId);
      snap = await (tx ? tx.get(ref) : ref.get());
    } catch (err) {
      return unavailable(VISIBILITY_REASON.PRODUCT_NOT_FOUND);
    }
    if (!snap || !snap.exists) return unavailable(VISIBILITY_REASON.PRODUCT_NOT_FOUND);
    product = snap.data();
  }
  if (!product || typeof product !== "object" || Array.isArray(product)) {
    return unavailable(VISIBILITY_REASON.PRODUCT_NOT_FOUND);
  }

  // 5. the product belongs to the business it was addressed through.
  if (product.businessId !== businessId) {
    return unavailable(VISIBILITY_REASON.PRODUCT_BUSINESS_MISMATCH);
  }

  // A soft-deleted product is never available, however approved it looks.
  if (product.deletedAt !== undefined && product.deletedAt !== null) {
    return unavailable(VISIBILITY_REASON.PRODUCT_DELETED);
  }

  // 7/8. publication state.
  if (product.moderationStatus !== "approved") {
    return unavailable(VISIBILITY_REASON.NOT_APPROVED);
  }
  if (product.isActive !== true) {
    return unavailable(VISIBILITY_REASON.NOT_ACTIVE);
  }

  // 9. class validity. This is the condition most easily missed: the
  // evaluator compares the class only for snapshot EQUALITY, so an
  // UNCLASSIFIED product — a null live class matching a null recorded
  // snapshot — passes it and would otherwise be served and sold.
  if (!isValidPilotProductClass(product.pilotProductClass)) {
    return unavailable(VISIBILITY_REASON.CLASS_INVALID);
  }

  // 2. the owning business exists.
  const business = await readBusiness({ db, businessId, tx, businessCache });
  if (business === null) return unavailable(VISIBILITY_REASON.BUSINESS_NOT_FOUND);

  // 3. approved and Marketplace-eligible.
  if (!BUSINESS_PUBLISHABLE_STATUSES.includes(business.status)) {
    return unavailable(VISIBILITY_REASON.BUSINESS_NOT_PUBLISHABLE);
  }

  // 4. seller activation currently valid.
  const activation = business.marketplaceSellerActivation;
  const sellerActive = Boolean(
    activation &&
      typeof activation === "object" &&
      !Array.isArray(activation) &&
      activation.active === true
  );
  if (!sellerActive) return unavailable(VISIBILITY_REASON.SELLER_NOT_ACTIVE);

  // 6. the product's generation equals the LIVE business generation, so a
  // product left behind by a previous generation of a same-id business is
  // never served or sold.
  const liveGeneration = business.marketplaceBusinessGenerationId;
  if (!isNonEmptyString(liveGeneration)) {
    return unavailable(VISIBILITY_REASON.GENERATION_MISMATCH);
  }
  if (product.marketplaceBusinessGenerationId !== liveGeneration) {
    return unavailable(VISIBILITY_REASON.GENERATION_MISMATCH);
  }

  // 10/11/12. the canonical live-eligibility predicate — never a second,
  // weaker copy. `productSnapshot` is deliberately NOT forwarded: that
  // parameter makes the evaluator THROW on a contract failure, whereas
  // letting it perform its own (transaction-bound, when `tx` is present)
  // read yields a clean ineligible result this path can report.
  let eligibility;
  try {
    eligibility = await evaluator({ db, businessId, productId, now, tx });
  } catch (err) {
    return unavailable(VISIBILITY_REASON.EVALUATOR_FAILED);
  }
  if (!eligibility || typeof eligibility !== "object" || eligibility.eligible !== true) {
    return unavailable(VISIBILITY_REASON.NOT_LIVE_ELIGIBLE);
  }

  return { visible: true, reason: null, product, business };
}

module.exports = {
  assessProductVisibility,
  VISIBILITY_REASON,
  BUSINESS_PUBLISHABLE_STATUSES,
};
