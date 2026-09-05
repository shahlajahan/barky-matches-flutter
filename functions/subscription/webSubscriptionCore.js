"use strict";

const ALLOWED_PLANS = new Set(["premium", "gold"]);
const TERM_DAYS = 30;
const {buildSubscriptionCatalog} = require("./subscriptionCatalog");

function normalizePlan(planId) {
  return String(planId || "").trim().toLowerCase();
}

function resolvePlan(planId) {
  const plan = normalizePlan(planId);
  if (!ALLOWED_PLANS.has(plan)) {
    throw new Error("unsupported-plan");
  }
  return plan;
}

function resolveCatalog({ premiumAmount, goldAmount, currency }) {
  const normalizedCurrency = String(currency || "").trim().toUpperCase();
  if (normalizedCurrency !== "TRY") throw new Error("unsupported-currency");
  for (const [planId, rawAmount] of Object.entries({premium: premiumAmount, gold: goldAmount})) {
    if (!Number.isFinite(Number(rawAmount)) || Number(rawAmount) <= 0) {
      throw new Error(`missing-price:${planId}`);
    }
  }
  return buildSubscriptionCatalog({premiumAmount, goldAmount, currency: normalizedCurrency});
}

/// Server-authoritative authorization of a web-subscription payment.
///
/// WHY THIS EXISTS. Firestore Rules permit a signed-in user to CREATE its own
/// `orders` document with an arbitrary `orderType`, `planId` and
/// `pricing.grandTotal`. That user owns the document, so it passes the order
/// ownership gate, and the İş Bank callback compares the paid amount against
/// `orderData.pricing.grandTotal` — the user's own number. A one-kuruş payment
/// could therefore buy a full subscription.
///
/// The order's stored total is authoritative only for orders a server creator
/// wrote from the catalogue. This function refuses to consult it at all: the
/// entitlement is authorized against the server-owned catalogue instead.
///
/// Pure and side-effect free by construction, so it can decide before the
/// caller performs any write. Returns a verdict rather than throwing, so the
/// caller maps it onto its own result contract.
///
/// `normalizeAmount` and `canonicalizeCurrency` are injected rather than
/// reimplemented: the caller passes the same İş Bank money helpers the
/// promotion and marketplace callbacks already use, so there is exactly one
/// money-normalization convention.
function authorizeWebSubscriptionPayment({
  orderId,
  uid,
  planId,
  callbackAmount,
  callbackCurrency,
  catalog,
  normalizeAmount,
  canonicalizeCurrency,
  orderIdMatchesIdentity,
}) {
  if (typeof normalizeAmount !== "function" || typeof canonicalizeCurrency !== "function") {
    return { ok: false, reason: "validator_misconfigured" };
  }
  if (!uid || !planId) {
    return { ok: false, reason: "owner_missing" };
  }

  // Identity binding: the deterministic order id must encode this uid and
  // this plan. Not an authorization boundary on its own — the owner hash is a
  // SHA-256 of a non-secret uid — but it rejects a forged or re-pointed id and
  // an order whose stored `planId` disagrees with its own id.
  if (typeof orderIdMatchesIdentity === "function") {
    if (!orderIdMatchesIdentity(orderId, uid, planId)) {
      return { ok: false, reason: "order_identity_mismatch" };
    }
  }

  const canonicalPlan = catalog && catalog[planId];
  if (!canonicalPlan) {
    return { ok: false, reason: "catalog_unavailable" };
  }

  // Fixed two-decimal strings, never a floating-point comparison. A missing,
  // malformed, NaN, non-finite or negative amount normalizes to the empty
  // string and is refused; zero cannot match because a catalogue price is
  // required to be greater than zero.
  const paidAmount = normalizeAmount(callbackAmount);
  const expectedAmount = normalizeAmount(canonicalPlan.amount);
  if (!paidAmount || !expectedAmount) {
    return { ok: false, reason: "amount_missing_or_malformed" };
  }
  if (paidAmount !== expectedAmount) {
    // Covers underpayment AND overpayment: the entitlement is granted only
    // for the exact canonical price.
    return { ok: false, reason: "amount_mismatch" };
  }

  const paidCurrency = canonicalizeCurrency(callbackCurrency);
  const expectedCurrency = canonicalizeCurrency(canonicalPlan.currency);
  if (!paidCurrency || !expectedCurrency || paidCurrency !== expectedCurrency) {
    return { ok: false, reason: "currency_mismatch" };
  }

  return { ok: true, reason: null, amount: expectedAmount, currency: expectedCurrency };
}

function isApprovedCallback({ response, procReturnCode, mdStatus, hashValid }) {
  return (
    hashValid === true &&
    String(response || "").trim().toLowerCase() === "approved" &&
    String(procReturnCode || "").trim() === "00" &&
    String(mdStatus || "").trim() === "1"
  );
}

function entitlementWindow({
  now,
  currentPlan,
  currentStatus,
  currentExpiresAt,
  purchasedPlan,
}) {
  const verifiedAt = new Date(now);
  const currentExpiry = currentExpiresAt
    ? new Date(currentExpiresAt)
    : null;
  const extendsCurrent =
    currentPlan === purchasedPlan &&
    currentStatus === "active" &&
    currentExpiry instanceof Date &&
    !Number.isNaN(currentExpiry.getTime()) &&
    currentExpiry.getTime() > verifiedAt.getTime();
  const startsAt = extendsCurrent ? currentExpiry : verifiedAt;
  return {
    startsAt,
    expiresAt: new Date(
      startsAt.getTime() + TERM_DAYS * 24 * 60 * 60 * 1000
    ),
  };
}

module.exports = {
  ALLOWED_PLANS,
  TERM_DAYS,
  authorizeWebSubscriptionPayment,
  entitlementWindow,
  isApprovedCallback,
  resolveCatalog,
  resolvePlan,
};
