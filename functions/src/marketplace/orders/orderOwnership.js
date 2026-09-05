"use strict";

// Marketplace Revision 40 §0.38 — canonical customer order ownership.
//
// THE DEFECT THIS CLOSES. `createCheckoutSession` and `verifyPaymentByOrderId`
// each accept an `orderId` from any signed-in caller and never compare that
// caller against the stored order's buyer. Between them they can create a
// payable provider session on, and mark as paid, an order belonging to someone
// else. Four sibling callables — `readPaymentStatusByOrderId`,
// `markMarketplaceCheckoutFailed`, `cancelSellerOrderBeforeShipment`,
// `reconcileVerifiedPaidCart` — already enforce ownership correctly, which is
// what makes the two omissions look like oversights rather than design.
//
// WHY A RESOLVER RATHER THAN AN INLINE COMPARISON. Order documents carry TWO
// historical buyer-identity fields. `firestore.rules`' own frozen
// `isOrderOwner(data)` reads exactly `data.userId` and `data.buyerUid`, and
// several server paths additionally fall back to `auth.uid` when both are
// absent — which silently ADOPTS the caller as the owner of an unowned
// document. That fallback is the bug, not the contract, and it is not
// reproduced here.
//
// Ownership is derived ONLY from the stored canonical order. No buyer identity
// is ever accepted from request data.

/// The exact, closed set of buyer-identity fields a real order document may
/// carry, in precedence order. Adding a third field is a schema decision that
/// belongs in the plan, not in a callable.
const BUYER_IDENTITY_FIELDS = Object.freeze(["buyerUid", "userId"]);

/// Internal outcomes. These name WHY authorization failed so server logs and
/// tests can be precise; they are never returned to a caller, because
/// "does this order exist" and "does it belong to someone else" must be
/// indistinguishable from the outside.
const OWNERSHIP_RESULT = Object.freeze({
  OWNER: "ownership_owner",
  ORDER_MISSING: "ownership_order_missing",
  ORDER_MALFORMED: "ownership_order_malformed",
  BUYER_IDENTITY_MISSING: "ownership_buyer_identity_missing",
  BUYER_IDENTITY_MALFORMED: "ownership_buyer_identity_malformed",
  BUYER_IDENTITY_CONFLICT: "ownership_buyer_identity_conflict",
  NOT_OWNER: "ownership_not_owner",
});

function isNonEmptyString(value) {
  return typeof value === "string" && value.length > 0;
}

/// Resolves the single canonical buyer uid of an order document.
///
/// Rules' `isOrderOwner` ORs the two fields, so a document carrying two
/// DIFFERENT uids is readable by both of them. This resolver deliberately
/// fails closed on that conflict instead: a document that names two different
/// buyers has no single canonical owner, and guessing one of them is exactly
/// the kind of silent choice that turns an authorization helper into a
/// vulnerability. Failing closed is strictly stricter than Rules, never
/// looser, so it can only ever deny where Rules would have allowed.
function resolveCanonicalBuyerUid(orderData) {
  if (!orderData || typeof orderData !== "object" || Array.isArray(orderData)) {
    return { uid: null, result: OWNERSHIP_RESULT.ORDER_MALFORMED };
  }

  const present = [];
  for (const field of BUYER_IDENTITY_FIELDS) {
    const value = orderData[field];
    if (value === undefined || value === null) continue;
    // A present-but-wrong-typed identity is malformed state, never an
    // absent one: treating a number or an object as "no owner" would let the
    // missing-identity path decide instead.
    if (!isNonEmptyString(value)) {
      return { uid: null, result: OWNERSHIP_RESULT.BUYER_IDENTITY_MALFORMED };
    }
    present.push({ field, value });
  }

  if (present.length === 0) {
    return { uid: null, result: OWNERSHIP_RESULT.BUYER_IDENTITY_MISSING };
  }
  const distinct = new Set(present.map((entry) => entry.value));
  if (distinct.size > 1) {
    return { uid: null, result: OWNERSHIP_RESULT.BUYER_IDENTITY_CONFLICT };
  }
  // Precedence is `buyerUid` then `userId`; with the conflict case already
  // excluded they necessarily agree, so precedence only decides which field
  // name is reported, never which uid wins.
  return { uid: present[0].value, result: OWNERSHIP_RESULT.OWNER, field: present[0].field };
}

/// Assesses whether `callerUid` is the canonical buyer of `orderData`.
///
/// Returns a structured verdict rather than throwing, so each callable maps it
/// onto its own frozen error surface — and so a caller can log the precise
/// internal reason while returning an indistinguishable response.
function assessOrderOwnership({ orderData, callerUid, orderExists = true }) {
  if (!isNonEmptyString(callerUid)) {
    return { owner: false, result: OWNERSHIP_RESULT.NOT_OWNER, buyerUid: null };
  }
  if (orderExists !== true) {
    return { owner: false, result: OWNERSHIP_RESULT.ORDER_MISSING, buyerUid: null };
  }
  const resolved = resolveCanonicalBuyerUid(orderData);
  if (resolved.result !== OWNERSHIP_RESULT.OWNER) {
    return { owner: false, result: resolved.result, buyerUid: null };
  }
  if (resolved.uid !== callerUid) {
    return { owner: false, result: OWNERSHIP_RESULT.NOT_OWNER, buyerUid: null };
  }
  return { owner: true, result: OWNERSHIP_RESULT.OWNER, buyerUid: resolved.uid };
}

module.exports = {
  assessOrderOwnership,
  resolveCanonicalBuyerUid,
  BUYER_IDENTITY_FIELDS,
  OWNERSHIP_RESULT,
};
