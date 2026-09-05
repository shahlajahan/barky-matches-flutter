"use strict";

// Marketplace Revision 47 §0.45 (Slice 7F-2) — the canonical, server-owned
// basket bounds. Closes Revision 45 UNRESOLVED-3.
//
// WHY BOUNDS ARE NEEDED. `createMarketplaceOrderV2` accepted an unbounded
// `items` array. Every line costs transactional reads (product, business,
// policy pointer, policy version, business epoch, compliance decision) and,
// once the frozen M3 reservation becomes mandatory, further reads and writes
// (product, reservation, and the movement/event evidence pair). An unbounded
// basket therefore lets a single caller drive unbounded work inside one
// Firestore transaction, and a transaction that exceeds the platform write
// limit fails as a whole — turning an oversized request into a checkout
// outage rather than a rejected request.
//
// DERIVATION — none of these numbers is arbitrary.
//
//   MAX_DISTINCT_PRODUCTS = 20 is taken from the repository's own already
//   frozen bound: `BATCH_MAX_ITEMS` in marketplaceListing.js (and its Flutter
//   mirror `maxBatchProducts`). A cart cannot hold more products than the
//   hydration callable can serve in one request, so the two contracts stay
//   consistent by construction.
//
//   MAX_BUSINESSES = 5 bounds the seller-order projections and the
//   per-business reads a single checkout can fan out to.
//
//   MAX_QUANTITY_PER_PRODUCT = 20 and MAX_TOTAL_UNITS = 100 bound the units a
//   single order can carry. They are deliberately chosen so the backend bound
//   does NOT depend on any payment-provider item-count limit, since no such
//   provider fact is recorded in this repository (Revision 45 UNRESOLVED-2
//   records the same absence for session lifetime).
//
//   MAX_SUBMITTED_LINES = 50 bounds the RAW array before anything is read,
//   and is deliberately larger than MAX_DISTINCT_PRODUCTS so that a client
//   which splits one product across several lines is rejected by the
//   distinct-product rule with a precise reason, rather than by a blunt
//   payload check.
//
// WORST-CASE COST at these limits, with mandatory reservation enabled:
//   reads  = 20 products x (6 eligibility + 6 reservation) = 240
//   writes = 1 root order + 5 seller orders + 20 x 4 line writes = 86
// Against the documented Firestore limit of 500 writes per transaction that
// is roughly 17%, leaving about a 5.8x margin. NOTE: that 500 figure is the
// long-standing published Firestore limit but was NOT re-verified against
// live documentation while writing this contract; the margin is large enough
// that the chosen bounds remain safe even if the true limit were several
// times smaller.
//
// REVISIT THESE VALUES IF: the per-line read or write count grows; a provider
// item-count limit is established below MAX_TOTAL_UNITS; the checkout
// transaction gains further per-line documents; or the Pilot moves beyond the
// Pharos-only scope these bounds were sized for.

const { HttpsError } = require("firebase-functions/v2/https");

/// The frozen bounds. Integers, immutable, and unreachable from any client
/// input or environment variable — there is deliberately no override.
const BASKET_LIMITS = Object.freeze({
  MAX_SUBMITTED_LINES: 50,
  MAX_DISTINCT_PRODUCTS: 20,
  MAX_QUANTITY_PER_PRODUCT: 20,
  MAX_TOTAL_UNITS: 100,
  MAX_BUSINESSES: 5,
});

// A misconfigured bound must fail closed at load time rather than silently
// admitting an unbounded basket.
for (const [name, value] of Object.entries(BASKET_LIMITS)) {
  if (!Number.isInteger(value) || value < 1) {
    throw new Error(`basketLimits: ${name} must be a positive integer`);
  }
}
if (BASKET_LIMITS.MAX_DISTINCT_PRODUCTS > BASKET_LIMITS.MAX_SUBMITTED_LINES) {
  throw new Error("basketLimits: distinct products cannot exceed submitted lines");
}
if (BASKET_LIMITS.MAX_TOTAL_UNITS < BASKET_LIMITS.MAX_QUANTITY_PER_PRODUCT) {
  throw new Error("basketLimits: total units cannot be below a single line's cap");
}

/// Stable, non-sensitive rejection codes. They name the bound that was
/// exceeded and disclose nothing about inventory, compliance or another
/// seller's state.
const BASKET_REJECTION = Object.freeze({
  ITEMS_MISSING: "items_missing",
  ITEMS_NOT_A_LIST: "items_not_a_list",
  BASKET_EMPTY: "basket_empty",
  TOO_MANY_LINES: "too_many_lines",
  ITEM_MALFORMED: "item_malformed",
  QUANTITY_INVALID: "quantity_invalid",
  QUANTITY_TOO_LARGE: "quantity_too_large",
  TOO_MANY_PRODUCTS: "too_many_products",
  TOO_MANY_UNITS: "too_many_units",
  TOO_MANY_BUSINESSES: "too_many_businesses",
});

function reject(code) {
  return new HttpsError(
    "invalid-argument",
    "This basket cannot be checked out.",
    { reasonCode: code }
  );
}

/// A strictly positive integer quantity.
///
/// Deliberately strict: the previous path used `Math.max(1, Math.floor(...))`,
/// which silently turned 0, -5 and 0.5 into 1 — accepting a malformed basket
/// instead of refusing it. A string, NaN, Infinity or fraction is now a
/// rejection, not a coercion.
function isValidQuantity(value) {
  return (
    typeof value === "number" &&
    Number.isFinite(value) &&
    Number.isInteger(value) &&
    value >= 1
  );
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

/// Validates and normalizes a submitted basket.
///
/// Runs entirely on the request payload — it performs NO database access, so
/// it can and must be called before any product, business or compliance read.
/// Returns normalized lines in a canonical order.
///
/// Duplicate policy, frozen: lines naming the same canonical
/// (businessId, productId) are MERGED by summing their quantities, then the
/// merged quantity is checked against the per-product cap. Merging rather than
/// rejecting matches the frozen checkout fingerprint, which hashes one entry
/// per canonical product — so two equivalent baskets expressed differently
/// produce the same fingerprint and the same reservation, and a duplicate can
/// never be used to exceed a cap or to reserve twice.
///
/// Canonical order is `businessId` then `productId`, both ascending, so the
/// fingerprint of an equivalent basket does not depend on submission order.
function validateAndNormalizeBasket(rawItems) {
  if (rawItems === undefined || rawItems === null) {
    throw reject(BASKET_REJECTION.ITEMS_MISSING);
  }
  if (!Array.isArray(rawItems)) {
    throw reject(BASKET_REJECTION.ITEMS_NOT_A_LIST);
  }
  if (rawItems.length === 0) {
    throw reject(BASKET_REJECTION.BASKET_EMPTY);
  }
  // The raw bound is checked FIRST, before any per-item work, so an oversized
  // payload costs one length comparison rather than a loop.
  if (rawItems.length > BASKET_LIMITS.MAX_SUBMITTED_LINES) {
    throw reject(BASKET_REJECTION.TOO_MANY_LINES);
  }

  const merged = new Map();
  for (const rawItem of rawItems) {
    if (!rawItem || typeof rawItem !== "object" || Array.isArray(rawItem)) {
      throw reject(BASKET_REJECTION.ITEM_MALFORMED);
    }
    const businessId = isNonEmptyString(rawItem.shopId)
      ? rawItem.shopId.trim()
      : isNonEmptyString(rawItem.businessId)
        ? rawItem.businessId.trim()
        : null;
    const productId = isNonEmptyString(rawItem.productId)
      ? rawItem.productId.trim()
      : null;
    if (!businessId || !productId) {
      throw reject(BASKET_REJECTION.ITEM_MALFORMED);
    }
    if (!isValidQuantity(rawItem.quantity)) {
      throw reject(BASKET_REJECTION.QUANTITY_INVALID);
    }
    if (rawItem.quantity > BASKET_LIMITS.MAX_QUANTITY_PER_PRODUCT) {
      throw reject(BASKET_REJECTION.QUANTITY_TOO_LARGE);
    }

    const key = `${businessId} ${productId}`;
    const existing = merged.get(key);
    if (existing) {
      existing.quantity += rawItem.quantity;
      // The MERGED quantity is capped too, so splitting a product across
      // lines cannot exceed the per-product bound.
      if (existing.quantity > BASKET_LIMITS.MAX_QUANTITY_PER_PRODUCT) {
        throw reject(BASKET_REJECTION.QUANTITY_TOO_LARGE);
      }
    } else {
      merged.set(key, {
        businessId,
        productId,
        quantity: rawItem.quantity,
        rawItem,
      });
    }
  }

  if (merged.size > BASKET_LIMITS.MAX_DISTINCT_PRODUCTS) {
    throw reject(BASKET_REJECTION.TOO_MANY_PRODUCTS);
  }

  const lines = [...merged.values()].sort((a, b) =>
    a.businessId === b.businessId
      ? a.productId.localeCompare(b.productId)
      : a.businessId.localeCompare(b.businessId)
  );

  const totalUnits = lines.reduce((sum, line) => sum + line.quantity, 0);
  if (totalUnits > BASKET_LIMITS.MAX_TOTAL_UNITS) {
    throw reject(BASKET_REJECTION.TOO_MANY_UNITS);
  }

  const businessIds = [...new Set(lines.map((line) => line.businessId))];
  if (businessIds.length > BASKET_LIMITS.MAX_BUSINESSES) {
    throw reject(BASKET_REJECTION.TOO_MANY_BUSINESSES);
  }

  return { lines, totalUnits, businessIds };
}

module.exports = {
  BASKET_LIMITS,
  BASKET_REJECTION,
  isValidQuantity,
  validateAndNormalizeBasket,
};
