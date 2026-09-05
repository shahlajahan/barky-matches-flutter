"use strict";

// Marketplace Revision 44 §0.42 (Slice 7E) — the acceptance gate that runs
// INSIDE the checkout transaction.
//
// THE BLOCKER THIS CLOSES. Revision 39 §0.37 E recorded that no purchase path
// performed any publication or compliance check, and that
// `createMarketplaceOrderV2` read products non-transactionally before
// committing the order tree with `batch.commit()`. A product could therefore
// be unpublished, reclassified, have its evidence expire, its approval
// revoked or its business generation rotated between discovery and purchase,
// and still be sold.
//
// WHAT THIS IS. One function, called inside `db.runTransaction`, that
// re-reads every acceptance-critical record through the SAME canonical
// predicate public discovery uses — `assessProductVisibility`, which itself
// delegates to `evaluateLiveProductEligibility`. There is deliberately no
// second predicate here: discovery and checkout cannot drift because they
// call the same code.
//
// WHAT THIS IS NOT. It is not an inventory reservation and does not claim to
// be. Stock authority is the frozen M3/M5 model, which is disabled by
// default; when it is disabled there is no stock to reserve and this gate
// says nothing about stock. It also does not make payment safe — the payment
// contract is unchanged and separately enforced.

const { HttpsError } = require("firebase-functions/v2/https");
const {
  assessProductVisibility,
} = require("../publicCatalog/marketplaceProductVisibility");

/// Stable, non-leaking refusal codes. A customer is never told WHY a product
/// is compliance-ineligible — that would disclose the seller's evidence,
/// approval or classification state to a stranger. "Unavailable" is the only
/// public fact.
const CHECKOUT_REJECTION = Object.freeze({
  ITEM_UNAVAILABLE: "item_unavailable",
  PRICE_CHANGED: "price_changed",
  CURRENCY_MISMATCH: "currency_mismatch",
  BUSINESS_MISMATCH: "business_mismatch",
});

function rejection(code, productId) {
  return new HttpsError(
    "failed-precondition",
    "One or more items are no longer available at the offered price.",
    { reasonCode: code, productId: productId || null }
  );
}

function normalizeMoney(value) {
  const numeric = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(numeric) || numeric <= 0) return null;
  // The repository's existing money representation for Marketplace order
  // lines is a 2-decimal TRY amount. This normalizes for COMPARISON only —
  // the stored value is always the one read from the product inside the
  // transaction, never a client number and never a re-rounded one.
  return Number(numeric.toFixed(2));
}

/// Re-validates every checkout item against authoritative state read inside
/// [tx], and returns the server-derived unit price and currency for each.
///
/// Throws an `HttpsError` on the first failure — no partial acceptance, and
/// no order is created for a basket containing an unavailable item.
///
/// `items` are the server-normalized lines (businessId, productId, quantity,
/// unitPrice) computed before the transaction. Their prices are treated as
/// PROPOSALS: if the authoritative product now disagrees, the checkout is
/// rejected rather than silently repriced, so a customer is never charged an
/// amount they were not shown.
async function assertCheckoutItemsAcceptable({
  db,
  tx,
  items,
  currency,
  visibilityAssessor = assessProductVisibility,
}) {
  if (!db) throw new Error("assertCheckoutItemsAcceptable: db is required");
  if (!tx) {
    // A caller that forgets the transaction would silently reintroduce the
    // exact TOCTOU defect this module exists to close.
    throw new Error("assertCheckoutItemsAcceptable: tx is required");
  }
  if (!Array.isArray(items) || items.length === 0) {
    throw new HttpsError("invalid-argument", "Items are required.");
  }

  const accepted = [];
  for (const item of items) {
    const businessId = String(item.businessId || item.shopId || "").trim();
    const productId = String(item.productId || "").trim();
    if (!businessId || !productId) {
      throw rejection(CHECKOUT_REJECTION.ITEM_UNAVAILABLE, productId);
    }

    // THE canonical predicate, evaluated transactionally. Everything it
    // covers — existence, business binding, soft delete, moderation,
    // isActive, pilot class validity, business existence/publishability,
    // seller activation, generation match, and the full live compliance
    // evaluation (decision, decisionHash, policy epoch, evidence, approval
    // fingerprint) — is therefore re-checked at acceptance time.
    const assessment = await visibilityAssessor({
      db,
      businessId,
      productId,
      tx,
    });
    if (!assessment || assessment.visible !== true || !assessment.product) {
      throw rejection(CHECKOUT_REJECTION.ITEM_UNAVAILABLE, productId);
    }

    const product = assessment.product;
    if (String(product.businessId || "") !== businessId) {
      throw rejection(CHECKOUT_REJECTION.BUSINESS_MISMATCH, productId);
    }

    // Price is re-derived from the transactionally-read product, using the
    // same precedence the order path already uses.
    const authoritativeUnitPrice = normalizeMoney(
      product.salePrice || product.price
    );
    if (authoritativeUnitPrice === null) {
      throw rejection(CHECKOUT_REJECTION.ITEM_UNAVAILABLE, productId);
    }

    const offeredUnitPrice = normalizeMoney(item.unitPrice ?? item.price);
    if (offeredUnitPrice === null || offeredUnitPrice !== authoritativeUnitPrice) {
      // The price moved between the pre-transaction read and acceptance.
      // Rejecting is the honest outcome: silently charging the new amount
      // would bill a total the customer never saw.
      throw rejection(CHECKOUT_REJECTION.PRICE_CHANGED, productId);
    }

    const productCurrency = String(product.currency || "TRY").toUpperCase();
    if (productCurrency !== String(currency || "TRY").toUpperCase()) {
      throw rejection(CHECKOUT_REJECTION.CURRENCY_MISMATCH, productId);
    }

    accepted.push({
      businessId,
      productId,
      unitPrice: authoritativeUnitPrice,
      currency: productCurrency,
      marketplaceBusinessGenerationId:
        product.marketplaceBusinessGenerationId || null,
      pilotProductClass: product.pilotProductClass || null,
    });
  }

  return accepted;
}

module.exports = {
  CHECKOUT_REJECTION,
  assertCheckoutItemsAcceptable,
};
