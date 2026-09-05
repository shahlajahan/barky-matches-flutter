"use strict";

// Web-subscription server-authoritative payment amount repair.
//
// THE EXPLOIT THIS CLOSES. Firestore Rules permit a signed-in user to CREATE
// its own `orders` document with an arbitrary `orderType`, `planId` and
// `pricing.grandTotal`. That user owns the document, so it passes the order
// ownership gate added in 28832ba; `createIsbank3DPayHostingCheckout` then
// signs a bank form for the stored (self-chosen) total; a genuine tiny payment
// produces an authentic callback; and `finalizeWebSubscriptionPayment`
// previously granted a full subscription because the only amount check in the
// chain compared the paid amount against that same self-chosen number.
//
// These are BEHAVIOURAL tests of the decision function that now authorizes the
// entitlement: real inputs, real catalogue, real money helpers, real verdicts.
// They are not source-text assertions.

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const webSubscriptionCore = require("../subscription/webSubscriptionCore");
const { buildSubscriptionCatalog } = require("../subscription/subscriptionCatalog");

const hasFs = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const itest = (n, f) => test(n, { skip: !hasFs }, f);

// ---------------------------------------------------------------------
// The production money helpers, reproduced here EXACTLY as index.js defines
// them, so the tests exercise the same normalization the callbacks use.
// (They are module-private in index.js; these are byte-equivalent copies and
// are asserted against index.js's own source below so they cannot drift.)
// ---------------------------------------------------------------------
function normalizeIsbankValue(value) {
  if (value === undefined || value === null) return "";
  return String(value).trim();
}
function normalizeIsbankAmount(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount < 0) return "";
  return amount.toFixed(2);
}
function canonicalizeIsbankCurrency(value) {
  const normalized = normalizeIsbankValue(value);
  if (normalized === "949" || normalized === "TRY") return "TRY";
  return "";
}

const crypto = require("node:crypto");
function webSubscriptionOrderId(uid, planId, now = Date.now()) {
  const fiveMinuteBucket = Math.floor(now / (5 * 60 * 1000));
  const ownerHash = crypto.createHash("sha256").update(String(uid)).digest("hex").slice(0, 20);
  return `websub_${ownerHash}_${planId}_${fiveMinuteBucket}`;
}
function orderIdMatchesIdentity(orderId, uid, planId) {
  const parts = String(orderId || "").split("_");
  if (parts.length !== 4) return false;
  if (parts[0] !== "websub") return false;
  const bucket = Number(parts[3]);
  if (!Number.isInteger(bucket) || bucket < 0) return false;
  return webSubscriptionOrderId(uid, planId, bucket * 5 * 60 * 1000) === orderId;
}

// The canonical catalogue, built by the same builder production uses.
const CATALOG = buildSubscriptionCatalog({
  premiumAmount: "149.90",
  goldAmount: "299.90",
  currency: "TRY",
});

const BUYER = "buyer-alice";
const VALID_ORDER_ID = webSubscriptionOrderId(BUYER, "gold");

function authorize(overrides = {}) {
  return webSubscriptionCore.authorizeWebSubscriptionPayment({
    orderId: VALID_ORDER_ID,
    uid: BUYER,
    planId: "gold",
    callbackAmount: "299.90",
    callbackCurrency: "TRY",
    catalog: CATALOG,
    normalizeAmount: normalizeIsbankAmount,
    canonicalizeCurrency: canonicalizeIsbankCurrency,
    orderIdMatchesIdentity,
    ...overrides,
  });
}

// =====================================================================
// Phase 4 — the exploit regression
// =====================================================================

test("EXPLOIT. a client-forged order with a tiny total cannot authorize an entitlement, even when the callback amount matches that forged total", () => {
  // Exactly the audited chain: the attacker owns the order, so ownership
  // passes; the bank genuinely captured 0.01; and the callback amount equals
  // the order's stored `pricing.grandTotal`. Every pre-fix check is satisfied.
  const forgedOrder = {
    orderType: "web_subscription",
    buyerUid: BUYER,
    userId: BUYER,
    planId: "gold",
    pricing: { grandTotal: 0.01, currency: "TRY" },
  };

  const verdict = authorize({
    // The attacker can even construct a well-formed deterministic id for
    // their own uid and plan, so identity binding alone would not stop this.
    orderId: webSubscriptionOrderId(BUYER, "gold"),
    callbackAmount: String(forgedOrder.pricing.grandTotal),
    callbackCurrency: "TRY",
  });

  assert.equal(verdict.ok, false, "a 0.01 payment must not authorize a gold subscription");
  assert.equal(verdict.reason, "amount_mismatch");
  // The verdict never echoes the forged total back as if it were canonical.
  assert.notEqual(verdict.amount, "0.01");
});

test("EXPLOIT (pre-fix behaviour reproduced). comparing against the ORDER total instead of the catalogue would have accepted it", () => {
  // This is what the code did before the repair: expected = order.pricing
  // .grandTotal. Demonstrates the vulnerability is real and that the fix's
  // choice of authority — catalogue, not order — is the load-bearing change.
  const forgedStoredTotal = 0.01;
  const preFixExpected = normalizeIsbankAmount(forgedStoredTotal);
  const callbackPaid = normalizeIsbankAmount("0.01");
  assert.equal(preFixExpected, callbackPaid, "pre-fix comparison passes — the exploit");

  const postFixExpected = normalizeIsbankAmount(CATALOG.gold.amount);
  assert.notEqual(postFixExpected, callbackPaid, "post-fix comparison refuses it");
});

// =====================================================================
// Phase 5 — positive and adversarial
// =====================================================================

test("1. a valid server-created order paying the exact canonical amount succeeds", () => {
  const verdict = authorize();
  assert.equal(verdict.ok, true, verdict.reason || "");
  assert.equal(verdict.amount, "299.90");
  assert.equal(verdict.currency, "TRY");
});

test("1b. every catalogue plan authorizes at its own exact price and no other", () => {
  for (const planId of ["premium", "gold"]) {
    const orderId = webSubscriptionOrderId(BUYER, planId);
    const own = authorize({
      planId, orderId, callbackAmount: String(CATALOG[planId].amount),
    });
    assert.equal(own.ok, true, `${planId} at its own price: ${own.reason || ""}`);

    const otherPlan = planId === "gold" ? "premium" : "gold";
    const cross = authorize({
      planId, orderId, callbackAmount: String(CATALOG[otherPlan].amount),
    });
    assert.equal(cross.ok, false, `${planId} must not accept ${otherPlan}'s price`);
    assert.equal(cross.reason, "amount_mismatch");
  }
});

test("2. underpayment is denied", () => {
  for (const paid of ["0.01", "1", "299.89", "0.00"]) {
    const v = authorize({ callbackAmount: paid });
    assert.equal(v.ok, false, paid);
    assert.equal(v.reason, "amount_mismatch", paid);
  }
});

test("2b. the comparison granularity is exactly one kuruş — the established two-decimal convention", () => {
  // `normalizeIsbankAmount` is `toFixed(2)`, the same normalization the
  // promotion and marketplace callbacks already use, so amounts are compared
  // at kuruş granularity and a sub-kuruş difference rounds into the canonical
  // value. This is pinned deliberately rather than left implicit: the bank
  // settles in kuruş, so a sub-kuruş discrepancy is not representable in a
  // real capture, and this is NOT a loose floating-point comparison — both
  // sides are normalized to a fixed two-decimal string before comparing.
  assert.equal(authorize({ callbackAmount: "299.8999" }).ok, true, "rounds to 299.90");
  assert.equal(authorize({ callbackAmount: "299.9049" }).ok, true, "rounds to 299.90");
  // One full kuruş either side is refused.
  assert.equal(authorize({ callbackAmount: "299.89" }).reason, "amount_mismatch");
  assert.equal(authorize({ callbackAmount: "299.91" }).reason, "amount_mismatch");
});

test("3. overpayment is denied — the entitlement is granted only at the exact price", () => {
  for (const paid of ["299.91", "300", "999999"]) {
    const v = authorize({ callbackAmount: paid });
    assert.equal(v.ok, false, paid);
    assert.equal(v.reason, "amount_mismatch", paid);
  }
});

test("4/5. a wrong or missing currency is denied", () => {
  for (const cur of ["USD", "EUR", "", null, undefined, "TR", "0"]) {
    const v = authorize({ callbackCurrency: cur });
    assert.equal(v.ok, false, String(cur));
    assert.equal(v.reason, "currency_mismatch", String(cur));
  }
  // The İş Bank numeric code for TRY remains accepted — the canonical
  // convention, not a looser one.
  assert.equal(authorize({ callbackCurrency: "949" }).ok, true);
});

test("6/7/8. malformed, zero and negative amounts all fail closed", () => {
  // The security property is that NONE of these authorize an entitlement.
  // The reason differs by input class, and both classes are pinned:
  //  - genuinely unrepresentable values normalize to "" -> missing/malformed
  //  - values that normalize to a real amount (including "" and null, which
  //    Number() coerces to 0) are refused by the price comparison instead.
  const malformed = [undefined, "abc", NaN, Infinity, -Infinity, "-1", -0.01, {}];
  for (const paid of malformed) {
    const v = authorize({ callbackAmount: paid });
    assert.equal(v.ok, false, String(paid));
    assert.equal(v.reason, "amount_missing_or_malformed", String(paid));
  }
  const coercedToZero = ["", null, 0, "0", "0.00"];
  for (const paid of coercedToZero) {
    const v = authorize({ callbackAmount: paid });
    assert.equal(v.ok, false, String(paid));
    assert.equal(v.reason, "amount_mismatch", String(paid));
  }
});

test("9. a wrong deterministic order id is denied", () => {
  for (const bad of [
    "forged-1",
    "websub_deadbeef_gold_1",
    webSubscriptionOrderId("someone-else", "gold"),
    webSubscriptionOrderId(BUYER, "gold").replace(/_\d+$/, "_notanumber"),
    "",
    null,
  ]) {
    const v = authorize({ orderId: bad });
    assert.equal(v.ok, false, String(bad));
    assert.equal(v.reason, "order_identity_mismatch", String(bad));
  }
});

test("10. another user's order id is denied, and the verdict leaks nothing about it", () => {
  const victimOrderId = webSubscriptionOrderId("victim-bob", "gold");
  const v = authorize({ orderId: victimOrderId });
  assert.equal(v.ok, false);
  assert.equal(v.reason, "order_identity_mismatch");
  const serialized = JSON.stringify(v);
  assert.equal(serialized.includes("victim-bob"), false);
  assert.equal(serialized.includes(victimOrderId), false);
});

test("11. an order whose stored planId disagrees with its own id is denied", () => {
  // The id encodes `premium`; the order claims `gold`.
  const premiumId = webSubscriptionOrderId(BUYER, "premium");
  const v = authorize({ orderId: premiumId, planId: "gold", callbackAmount: "299.90" });
  assert.equal(v.ok, false);
  assert.equal(v.reason, "order_identity_mismatch");
});

test("12. an unknown plan is denied by the catalogue", () => {
  const v = authorize({
    planId: "platinum",
    orderId: webSubscriptionOrderId(BUYER, "platinum"),
  });
  assert.equal(v.ok, false);
  assert.equal(v.reason, "catalog_unavailable");
});

test("13. an unresolvable catalogue fails closed — never falls back to the order", () => {
  for (const cat of [null, undefined, {}, { premium: CATALOG.premium }]) {
    const v = authorize({ catalog: cat });
    assert.equal(v.ok, false, JSON.stringify(cat));
    assert.equal(v.reason, "catalog_unavailable", JSON.stringify(cat));
  }
});

test("17. a missing owner or plan is refused before any catalogue or amount work", () => {
  for (const bad of [{ uid: "" }, { uid: null }, { planId: "" }, { planId: null }]) {
    const v = authorize(bad);
    assert.equal(v.ok, false, JSON.stringify(bad));
    assert.equal(v.reason, "owner_missing", JSON.stringify(bad));
  }
});

test("17b. a misconfigured validator fails closed rather than authorizing", () => {
  assert.equal(authorize({ normalizeAmount: null }).reason, "validator_misconfigured");
  assert.equal(authorize({ canonicalizeCurrency: undefined }).reason, "validator_misconfigured");
});

test("the validator is pure — identical inputs give identical verdicts and it holds no state", () => {
  const a = authorize();
  const b = authorize();
  assert.deepEqual(a, b);
  // And it never mutates the catalogue it was handed.
  const before = JSON.stringify(CATALOG);
  authorize({ callbackAmount: "1" });
  assert.equal(JSON.stringify(CATALOG), before);
});

// =====================================================================
// The money helpers used above are the production ones (drift guard).
// This IS a source-text assertion and is labelled as such: it exists only to
// prove the copies above have not diverged from index.js.
// =====================================================================
test("SOURCE-TEXT drift guard: the money helpers copied into this test match index.js", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const source = fs.readFileSync(path.resolve(__dirname, "../index.js"), "utf8");
  assert.match(source, /function normalizeIsbankAmount\(value\) \{\s*const amount = Number\(value\);\s*if \(!Number\.isFinite\(amount\) \|\| amount < 0\) return "";\s*return amount\.toFixed\(2\);/);
  assert.match(source, /normalized === "949" \|\| normalized === "TRY"/);
  assert.match(source, /const fiveMinuteBucket = Math\.floor\(now \/ \(5 \* 60 \* 1000\)\);/);
  // And the finalizer delegates to the shared validator before writing.
  //
  // KNOWN LIMITATION, stated plainly: this is a SOURCE-TEXT assertion, not a
  // behavioural one. `finalizeWebSubscriptionPayment` is module-private and
  // the only path that reaches it — the İş Bank callback — requires a valid
  // provider HMAC that cannot be reproduced in a test without duplicating
  // three private hash helpers. The eight validation rules themselves ARE
  // proven behaviourally above; what this pins is only that the finalizer
  // still consults them and still returns before its first write. Making this
  // behavioural requires extracting the finalizer behind a dependency-injected
  // seam, which is a larger change than this repair.
  const finalizer = source.match(/async function finalizeWebSubscriptionPayment[\s\S]*?exports\.readWebSubscriptionPaymentStatus/);
  assert.ok(finalizer);
  const body = finalizer[0];
  const gateAt = body.indexOf("authorizeWebSubscriptionPayment");
  const firstWriteAt = body.indexOf("transaction.set(");
  assert.ok(gateAt > -1, "the finalizer must consult the shared validator");
  assert.ok(firstWriteAt > gateAt, "no write may precede the authorization verdict");
  // The verdict must actually be acted on — not merely computed.
  assert.match(
    body,
    /if \(!authorization\.ok\) \{\s*return \{ status: "failed", reason: authorization\.reason \};\s*\}/,
    "the finalizer must return on a refused verdict, before any write"
  );
  const actAt = body.indexOf("if (!authorization.ok)");
  assert.ok(actAt > gateAt && actAt < firstWriteAt, "the refusal must sit between the verdict and the first write");
  // And the catalogue must be resolved from the server-owned source.
  assert.match(body, /catalog = webSubscriptionCatalog\(\);/, "the catalogue must be resolved server-side");
  // The order's own stored total must never be an ARGUMENT to the
  // authorization call. (It legitimately appears later, recorded on the
  // subscription source for audit — a record, not an authority — so the slice
  // is deliberately bounded to the call's own arguments.)
  const authorizeCallArgs = body.slice(gateAt, actAt);
  assert.doesNotMatch(
    authorizeCallArgs,
    /pricing/,
    "the stored order total must not feed the authorization"
  );
  assert.match(authorizeCallArgs, /catalog,/, "the catalogue must be the price authority");
});

// =====================================================================
// Phase 6 — cross-domain regression through the shared ownership boundary
// =====================================================================

const { assessOrderOwnership } = require("../src/marketplace/orders/orderOwnership");

itest("CROSS-DOMAIN. a Pet Taxi order (server-created, non-Marketplace) keeps its owner and denies a stranger", async () => {
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
  }
  const db = admin.firestore();
  const orderId = `xdomain-taxi-${Date.now()}`;
  // Exactly the shape `createPetTaxiOrder` writes: buyerUid only, no userId.
  await db.collection("orders").doc(orderId).set({
    orderId,
    type: "pet_taxi",
    buyerUid: "taxi-owner",
    bookingId: "booking-1",
    status: "pending",
    paymentStatus: "pending",
    pricing: { grandTotal: 250, currency: "TRY" },
  });

  const stored = (await db.collection("orders").doc(orderId).get()).data();

  const owner = assessOrderOwnership({ orderData: stored, callerUid: "taxi-owner", orderExists: true });
  assert.equal(owner.owner, true, "the legitimate Pet Taxi payer must still pass the ownership gate");

  const stranger = assessOrderOwnership({ orderData: stored, callerUid: "mallory", orderExists: true });
  assert.equal(stranger.owner, false, "a foreign user must be denied");
  assert.equal(stranger.buyerUid, null, "a denial must not disclose the real buyer");

  // The subscription-specific amount validation does not touch this domain:
  // it is reached only from the web_subscription callback branch.
  assert.notEqual(stored.orderType, "web_subscription");
  await db.collection("orders").doc(orderId).delete();
});

itest("CROSS-DOMAIN. an appointment order (buyerUid) and a legacy userId-only order both keep their owners", async () => {
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
  }
  const db = admin.firestore();
  const cases = [
    ["appointment", { type: "appointment", buyerUid: "appt-owner" }, "appt-owner"],
    ["legacy userId-only", { userId: "legacy-owner" }, "legacy-owner"],
    ["both fields agreeing (web subscription)", { orderType: "web_subscription", buyerUid: "sub-owner", userId: "sub-owner" }, "sub-owner"],
  ];
  for (const [label, shape, ownerUid] of cases) {
    const orderId = `xdomain-${label.replace(/\W+/g, "-")}-${Date.now()}`;
    await db.collection("orders").doc(orderId).set({ orderId, ...shape });
    const stored = (await db.collection("orders").doc(orderId).get()).data();
    assert.equal(
      assessOrderOwnership({ orderData: stored, callerUid: ownerUid, orderExists: true }).owner,
      true,
      `${label}: legitimate owner must pass`
    );
    assert.equal(
      assessOrderOwnership({ orderData: stored, callerUid: "mallory", orderExists: true }).owner,
      false,
      `${label}: stranger must be denied`
    );
    await db.collection("orders").doc(orderId).delete();
  }
});
