"use strict";

// =====================================================================
// BEHAVIOURAL coverage for the web-subscription finalization boundary.
//
// The sibling suite `webSubscriptionPaymentAuthorization.test.js` proves the
// eight validation RULES behaviourally, but it could only pin the WIRING
// between `finalizeWebSubscriptionPayment` and
// `authorizeWebSubscriptionPayment` with a source-text assertion, because the
// finalizer is module-private and its only production caller requires a valid
// İş Bank HMAC.
//
// This suite closes that gap. It drives the REAL finalizer — the same function
// object the callback calls, reached through a non-deployed test seam — inside
// a REAL Firestore transaction against the emulator, and asserts on the
// resulting documents rather than on source text.
//
// Requires the Firestore emulator; skipped otherwise.
// =====================================================================

const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const hasFs = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const itest = hasFs ? test : test.skip;

// The catalogue is resolved from server-owned params at callback time. These
// must be set before `index.js` reads them.
const PREMIUM_AMOUNT = "149.90";
const GOLD_AMOUNT = "299.90";
process.env.WEB_SUBSCRIPTION_PREMIUM_AMOUNT = PREMIUM_AMOUNT;
process.env.WEB_SUBSCRIPTION_GOLD_AMOUNT = GOLD_AMOUNT;
process.env.WEB_SUBSCRIPTION_CURRENCY = "TRY";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-petsupo";

let admin = null;
let finalize = null;
let db = null;
if (hasFs) {
  const mod = require("../index");
  finalize = mod.testOnlyFinalizeWebSubscriptionPayment;
  admin = require("firebase-admin");
  db = admin.firestore();
}

// ---------------------------------------------------------------------
// Fixture helpers. These deliberately reimplement NOTHING from the payment
// path: the order id below is built independently so that a mutation of the
// production id derivation breaks these tests instead of moving with them.
// ---------------------------------------------------------------------

const BUCKET_MS = 5 * 60 * 1000;

function deterministicOrderId(uid, planId, atMs) {
  const bucket = Math.floor(atMs / BUCKET_MS);
  const ownerHash = crypto
    .createHash("sha256")
    .update(String(uid))
    .digest("hex")
    .slice(0, 20);
  return `websub_${ownerHash}_${planId}_${bucket}`;
}

let seq = 0;
function freshUid(label) {
  seq += 1;
  return `finalizer-${label}-${Date.now()}-${seq}`;
}

/// Writes exactly the shape a CLIENT can create under current Firestore Rules:
/// its own `orders` document, with an `orderType`, `planId` and
/// `pricing.grandTotal` of its own choosing.
async function seedOrder({ uid, planId, grandTotal, currency = "TRY", orderId, extra }) {
  const ref = db.collection("orders").doc(orderId);
  await ref.set({
    orderId,
    orderType: "web_subscription",
    buyerUid: uid,
    userId: uid,
    planId,
    status: "pending",
    paymentStatus: "pending",
    pricing: { grandTotal, currency },
    ...(extra || {}),
  });
  return ref;
}

/// Sentinel pre-existing state, so a refusal can be proven to have changed
/// NOTHING rather than merely to have created nothing.
async function seedExistingState(uid) {
  await db.collection("subscriptions").doc(uid).set({
    userId: uid,
    tier: "free",
    status: "none",
    sentinel: "untouched",
  });
  await db.collection("users").doc(uid).set({
    subscriptionTier: "free",
    subscriptionStatus: "none",
    sentinel: "untouched",
  });
}

async function readState(uid, orderRef) {
  const [sub, user, order] = await Promise.all([
    db.collection("subscriptions").doc(uid).get(),
    db.collection("users").doc(uid).get(),
    orderRef.get(),
  ]);
  return {
    sub: sub.exists ? sub.data() : null,
    user: user.exists ? user.data() : null,
    order: order.exists ? order.data() : null,
  };
}

async function cleanup(uid, orderRef) {
  await Promise.all([
    db.collection("subscriptions").doc(uid).delete(),
    db.collection("users").doc(uid).delete(),
    orderRef ? orderRef.delete() : Promise.resolve(),
  ]);
}

/// Asserts that a refusal left every protected surface untouched (item B).
function assertNothingMutated(before, after, label) {
  assert.deepEqual(
    after.sub,
    before.sub,
    `${label}: subscriptions/{uid} must be unchanged`
  );
  assert.deepEqual(
    after.user,
    before.user,
    `${label}: the users/{uid} subscription mirror must be unchanged`
  );
  assert.equal(
    after.order.paymentStatus,
    "pending",
    `${label}: order paymentStatus must be unchanged`
  );
  assert.equal(
    after.order.status,
    "pending",
    `${label}: order status must be unchanged`
  );
  assert.equal(
    after.order.payment?.finalizationStatus,
    undefined,
    `${label}: order payment.finalizationStatus must not be written`
  );
  assert.equal(
    after.order.entitlementApplied,
    undefined,
    `${label}: no entitlement success record may be written`
  );
  assert.equal(
    after.order.entitlementExpiresAt,
    undefined,
    `${label}: no entitlement expiry may be written`
  );
  assert.equal(
    after.order.paidAt,
    undefined,
    `${label}: no paid-at success record may be written`
  );
}

/// Sentinel returned by a scenario that was disturbed by a CONCURRENT SUITE.
///
/// The full `node --test test/*.test.js` sweep runs ~130 files in parallel
/// against one shared emulator, and several other suites clear the `orders`
/// collection wholesale. That deletes this suite's fixture mid-scenario, which
/// the finalizer correctly reports as `missing`. That is environmental
/// interference, not a defect, so the scenario is retried on a fresh fixture.
///
/// A genuine regression that produced `missing` would be disturbed on every
/// attempt and still fail. No security assertion is relaxed.
const INTERFERED = Symbol("external-fixture-wipe");

async function withRetryOnExternalWipe(label, scenario, attempts = 4) {
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    if ((await scenario()) !== INTERFERED) return;
  }
  assert.fail(
    `${label}: the order fixture was deleted by a concurrent suite on all ` +
      `${attempts} attempts; the scenario never ran undisturbed`
  );
}

// =====================================================================
// A + B — the exploit, and the untouched-state proof
// =====================================================================

itest(
  "A/B. EXPLOIT: a client-shaped order with a forged 0.01 grandTotal cannot activate Premium, and mutates nothing",
  async () => {
    const uid = freshUid("exploit-premium");
    const orderId = deterministicOrderId(uid, "premium", Date.now());
    // The attacker sets its own total to one kuruş and genuinely pays it, so
    // the callback amount matches the stored total exactly. Before this
    // repair, that comparison was the only amount check.
    const orderRef = await seedOrder({ uid, planId: "premium", grandTotal: 0.01, orderId });
    await seedExistingState(uid);
    const before = await readState(uid, orderRef);

    const result = await finalize({
      orderRef,
      orderId,
      callbackAmount: "0.01",
      callbackCurrency: "TRY",
      callbackMetadata: { authCode: "A1" },
    });

    assert.equal(result.status, "failed", "a one-kuruş payment must not be finalized");
    assert.equal(result.reason, "amount_mismatch");
    assert.equal(result.expiresAt, undefined, "no entitlement window may be returned");

    const after = await readState(uid, orderRef);
    assertNothingMutated(before, after, "forged premium total");
    assert.notEqual(after.sub.tier, "premium", "Premium must not be granted");
    assert.equal(after.sub.sentinel, "untouched");
    assert.equal(after.user.subscriptionTier, "free");

    await cleanup(uid, orderRef);
  }
);

itest(
  "A. EXPLOIT: the same forged-total attack against Gold is refused",
  async () => {
    const uid = freshUid("exploit-gold");
    const orderId = deterministicOrderId(uid, "gold", Date.now());
    const orderRef = await seedOrder({ uid, planId: "gold", grandTotal: 1, orderId });
    await seedExistingState(uid);
    const before = await readState(uid, orderRef);

    const result = await finalize({
      orderRef,
      orderId,
      callbackAmount: "1.00",
      callbackCurrency: "TRY",
      callbackMetadata: {},
    });

    assert.equal(result.status, "failed");
    assert.equal(result.reason, "amount_mismatch");
    const after = await readState(uid, orderRef);
    assertNothingMutated(before, after, "forged gold total");
    assert.notEqual(after.sub.tier, "gold");
    await cleanup(uid, orderRef);
  }
);

itest(
  "A. EXPLOIT: paying the PREMIUM price for a GOLD plan is refused",
  async () => {
    const uid = freshUid("exploit-crossplan");
    const orderId = deterministicOrderId(uid, "gold", Date.now());
    const orderRef = await seedOrder({
      uid,
      planId: "gold",
      grandTotal: Number(PREMIUM_AMOUNT),
      orderId,
    });
    await seedExistingState(uid);
    const before = await readState(uid, orderRef);

    const result = await finalize({
      orderRef,
      orderId,
      callbackAmount: PREMIUM_AMOUNT,
      callbackCurrency: "TRY",
      callbackMetadata: {},
    });

    assert.equal(result.status, "failed");
    assert.equal(result.reason, "amount_mismatch");
    assertNothingMutated(before, await readState(uid, orderRef), "cross-plan price");
    await cleanup(uid, orderRef);
  }
);

// =====================================================================
// C — the legitimate path still works
// =====================================================================

itest(
  "C. a server-shaped order paid at the exact canonical catalogue price is finalized",
  async () => {
    const uid = freshUid("valid-premium");
    const orderId = deterministicOrderId(uid, "premium", Date.now());
    const orderRef = await seedOrder({
      uid,
      planId: "premium",
      grandTotal: Number(PREMIUM_AMOUNT),
      orderId,
    });
    await seedExistingState(uid);

    const result = await finalize({
      orderRef,
      orderId,
      callbackAmount: PREMIUM_AMOUNT,
      callbackCurrency: "TRY",
      callbackMetadata: { authCode: "OK1", transId: "T1" },
    });

    assert.equal(result.status, "completed", "the honest buyer must still be served");
    assert.ok(result.expiresAt instanceof Date);
    assert.ok(result.expiresAt.getTime() > Date.now(), "entitlement must be in the future");

    const after = await readState(uid, orderRef);
    assert.equal(after.sub.sources.web_isbank.plan, "premium");
    assert.equal(after.sub.sources.web_isbank.status, "active");
    assert.equal(after.sub.sources.web_isbank.lastPaymentOrderId, orderId);
    assert.ok(after.user, "the users/{uid} mirror must be written");
    assert.equal(after.order.paymentStatus, "paid");
    assert.equal(after.order.status, "paid");
    assert.equal(after.order.entitlementApplied, true);
    assert.equal(after.order.payment.finalizationStatus, "completed");
    assert.equal(after.order.payment.callbackValidated, true);
    assert.equal(after.order.payment.authCode, "OK1", "callback metadata must be recorded");

    await cleanup(uid, orderRef);
  }
);

itest(
  "C. the canonical GOLD price is finalized, proving the catalogue is consulted per plan",
  async () => {
    const uid = freshUid("valid-gold");
    const orderId = deterministicOrderId(uid, "gold", Date.now());
    const orderRef = await seedOrder({
      uid,
      planId: "gold",
      grandTotal: Number(GOLD_AMOUNT),
      orderId,
    });

    const result = await finalize({
      orderRef,
      orderId,
      callbackAmount: GOLD_AMOUNT,
      callbackCurrency: "TRY",
      callbackMetadata: {},
    });

    assert.equal(result.status, "completed");
    const after = await readState(uid, orderRef);
    assert.equal(after.sub.sources.web_isbank.plan, "gold");
    await cleanup(uid, orderRef);
  }
);

itest(
  "C. the İş Bank numeric currency code 949 is accepted as TRY",
  async () => {
    const uid = freshUid("valid-949");
    const orderId = deterministicOrderId(uid, "premium", Date.now());
    const orderRef = await seedOrder({
      uid,
      planId: "premium",
      grandTotal: Number(PREMIUM_AMOUNT),
      orderId,
    });

    const result = await finalize({
      orderRef,
      orderId,
      callbackAmount: PREMIUM_AMOUNT,
      callbackCurrency: "949",
      callbackMetadata: {},
    });

    assert.equal(result.status, "completed", "the provider's numeric TRY code must work");
    await cleanup(uid, orderRef);
  }
);

// =====================================================================
// D — every refusal class fails before mutation
// =====================================================================

itest("D. underpayment, overpayment and wrong currency all fail before mutation", async () => {
  const cases = [
    ["underpayment", "149.89", "TRY", "amount_mismatch"],
    ["one-kurus underpayment", "149.89", "TRY", "amount_mismatch"],
    ["overpayment", "149.91", "TRY", "amount_mismatch"],
    ["zero", "0", "TRY", "amount_mismatch"],
    ["negative", "-149.90", "TRY", "amount_missing_or_malformed"],
    ["malformed", "not-a-number", "TRY", "amount_missing_or_malformed"],
    ["wrong currency", "149.90", "USD", "currency_mismatch"],
    ["empty currency", "149.90", "", "currency_mismatch"],
  ];

  for (const [label, amount, currency, expectedReason] of cases) {
    const uid = freshUid(`refuse-${label.replace(/\W+/g, "-")}`);
    const orderId = deterministicOrderId(uid, "premium", Date.now());
    const orderRef = await seedOrder({
      uid,
      planId: "premium",
      grandTotal: Number(PREMIUM_AMOUNT),
      orderId,
    });
    await seedExistingState(uid);
    const before = await readState(uid, orderRef);

    const result = await finalize({
      orderRef,
      orderId,
      callbackAmount: amount,
      callbackCurrency: currency,
      callbackMetadata: {},
    });

    assert.equal(result.status, "failed", `${label} must be refused`);
    assert.equal(result.reason, expectedReason, `${label} reason`);
    assertNothingMutated(before, await readState(uid, orderRef), label);
    await cleanup(uid, orderRef);
  }
});

itest("D. a wrong order identity fails before mutation", async () => {
  const uid = freshUid("refuse-identity");
  const victim = freshUid("victim");
  const identityCases = [
    ["arbitrary id", "websub_deadbeef_premium_1"],
    ["another user's deterministic id", deterministicOrderId(victim, "premium", Date.now())],
    ["plan disagreeing with the id", deterministicOrderId(uid, "gold", Date.now())],
    ["wrong prefix", deterministicOrderId(uid, "premium", Date.now()).replace("websub_", "order_")],
    ["truncated id", "websub_abc_premium"],
  ];

  for (const [label, orderId] of identityCases) {
    const orderRef = await seedOrder({
      uid,
      planId: "premium",
      grandTotal: Number(PREMIUM_AMOUNT),
      orderId,
    });
    await seedExistingState(uid);
    const before = await readState(uid, orderRef);

    const result = await finalize({
      orderRef,
      orderId,
      callbackAmount: PREMIUM_AMOUNT,
      callbackCurrency: "TRY",
      callbackMetadata: {},
    });

    assert.equal(result.status, "failed", `${label} must be refused`);
    assert.equal(result.reason, "order_identity_mismatch", `${label} reason`);
    assert.ok(
      !JSON.stringify(result).includes(victim),
      `${label}: a refusal must not disclose another user's identity`
    );
    assertNothingMutated(before, await readState(uid, orderRef), label);
    await cleanup(uid, orderRef);
  }
});

itest("D. an unknown plan fails before mutation", async () => {
  const uid = freshUid("refuse-plan");
  const orderId = deterministicOrderId(uid, "platinum", Date.now());
  const orderRef = await seedOrder({
    uid,
    planId: "platinum",
    grandTotal: Number(PREMIUM_AMOUNT),
    orderId,
  });
  await seedExistingState(uid);
  const before = await readState(uid, orderRef);

  // `requireWebSubscriptionPlan` rejects an unlisted plan by throwing, which
  // aborts the transaction before any write.
  await assert.rejects(
    () =>
      finalize({
        orderRef,
        orderId,
        callbackAmount: PREMIUM_AMOUNT,
        callbackCurrency: "TRY",
        callbackMetadata: {},
      }),
    /plan/i,
    "an unlisted plan must be rejected"
  );

  assertNothingMutated(before, await readState(uid, orderRef), "unknown plan");
  await cleanup(uid, orderRef);
});

itest("D. an order with no owner fails before mutation", async () => {
  const uid = freshUid("refuse-owner");
  const orderId = deterministicOrderId(uid, "premium", Date.now());
  const orderRef = db.collection("orders").doc(orderId);
  await orderRef.set({
    orderId,
    orderType: "web_subscription",
    planId: "premium",
    status: "pending",
    paymentStatus: "pending",
    pricing: { grandTotal: Number(PREMIUM_AMOUNT), currency: "TRY" },
  });

  const result = await finalize({
    orderRef,
    orderId,
    callbackAmount: PREMIUM_AMOUNT,
    callbackCurrency: "TRY",
    callbackMetadata: {},
  });

  assert.equal(result.status, "failed");
  assert.equal(result.reason, "owner_missing");
  const after = (await orderRef.get()).data();
  assert.equal(after.paymentStatus, "pending");
  assert.equal(after.payment?.finalizationStatus, undefined);
  await orderRef.delete();
});

itest("D. a non-subscription order is not finalized by this path", async () => {
  const uid = freshUid("refuse-type");
  const orderId = deterministicOrderId(uid, "premium", Date.now());
  const orderRef = db.collection("orders").doc(orderId);
  await orderRef.set({
    orderId,
    orderType: "marketplace",
    buyerUid: uid,
    planId: "premium",
    paymentStatus: "pending",
    pricing: { grandTotal: Number(PREMIUM_AMOUNT), currency: "TRY" },
  });

  const result = await finalize({
    orderRef,
    orderId,
    callbackAmount: PREMIUM_AMOUNT,
    callbackCurrency: "TRY",
    callbackMetadata: {},
  });

  assert.equal(result.status, "not_subscription");
  const subSnap = await db.collection("subscriptions").doc(uid).get();
  assert.equal(subSnap.exists, false, "no entitlement may be created");
  await orderRef.delete();
});

itest("D. a missing order is not finalized", async () => {
  const uid = freshUid("refuse-missing");
  const orderId = deterministicOrderId(uid, "premium", Date.now());
  const orderRef = db.collection("orders").doc(orderId);
  const result = await finalize({
    orderRef,
    orderId,
    callbackAmount: PREMIUM_AMOUNT,
    callbackCurrency: "TRY",
    callbackMetadata: {},
  });
  assert.equal(result.status, "missing");
  assert.equal((await db.collection("subscriptions").doc(uid).get()).exists, false);
});

itest("D. an unresolvable catalogue fails CLOSED, before mutation", async () => {
  // The catalogue is resolved from server-owned params at callback time. If it
  // cannot be resolved, the entitlement must be refused — never granted on the
  // strength of anything carried on the order.
  const badCatalogues = [
    ["non-TRY currency", { WEB_SUBSCRIPTION_CURRENCY: "USD" }],
    ["missing premium price", { WEB_SUBSCRIPTION_PREMIUM_AMOUNT: "" }],
    ["malformed premium price", { WEB_SUBSCRIPTION_PREMIUM_AMOUNT: "free" }],
    ["zero premium price", { WEB_SUBSCRIPTION_PREMIUM_AMOUNT: "0" }],
  ];

  for (const [label, overrides] of badCatalogues) {
    const uid = freshUid(`catalog-${label.replace(/\W+/g, "-")}`);
    const orderId = deterministicOrderId(uid, "premium", Date.now());
    const orderRef = await seedOrder({
      uid,
      planId: "premium",
      grandTotal: Number(PREMIUM_AMOUNT),
      orderId,
    });
    await seedExistingState(uid);
    const before = await readState(uid, orderRef);

    const saved = {};
    for (const key of Object.keys(overrides)) {
      saved[key] = process.env[key];
      process.env[key] = overrides[key];
    }
    let result;
    try {
      // The callback amount is exactly what the (now unresolvable) catalogue
      // would otherwise have demanded, so only fail-closed behaviour can
      // refuse it.
      result = await finalize({
        orderRef,
        orderId,
        callbackAmount: PREMIUM_AMOUNT,
        callbackCurrency: "TRY",
        callbackMetadata: {},
      });
    } finally {
      for (const key of Object.keys(saved)) {
        if (saved[key] === undefined) delete process.env[key];
        else process.env[key] = saved[key];
      }
    }

    assert.equal(result.status, "failed", `${label} must refuse the entitlement`);
    assert.equal(result.reason, "catalog_unavailable", `${label} reason`);
    assertNothingMutated(before, await readState(uid, orderRef), label);
    await cleanup(uid, orderRef);
  }

  // The restored catalogue still works, proving the override was the cause.
  const uid = freshUid("catalog-restored");
  const orderId = deterministicOrderId(uid, "premium", Date.now());
  const orderRef = await seedOrder({
    uid,
    planId: "premium",
    grandTotal: Number(PREMIUM_AMOUNT),
    orderId,
  });
  const ok = await finalize({
    orderRef,
    orderId,
    callbackAmount: PREMIUM_AMOUNT,
    callbackCurrency: "TRY",
    callbackMetadata: {},
  });
  assert.equal(ok.status, "completed", "the catalogue must be restored");
  await cleanup(uid, orderRef);
});

// =====================================================================
// E — refusal does not poison a later legitimate payment
// =====================================================================

itest("E. a refused callback followed by a valid callback succeeds correctly", async () => {
  await withRetryOnExternalWipe("E", async () => {
    const uid = freshUid("recover");
    const orderId = deterministicOrderId(uid, "premium", Date.now());
    const orderRef = await seedOrder({
      uid,
      planId: "premium",
      grandTotal: 0.01,
      orderId,
    });
    await seedExistingState(uid);
    const before = await readState(uid, orderRef);

    const refused = await finalize({
      orderRef,
      orderId,
      callbackAmount: "0.01",
      callbackCurrency: "TRY",
      callbackMetadata: {},
    });
    if (refused.status === "missing") {
      await cleanup(uid, orderRef);
      return INTERFERED;
    }
    assert.equal(refused.status, "failed");
    assertNothingMutated(before, await readState(uid, orderRef), "first refusal");

    // The same order, now genuinely paid at the catalogue price.
    const accepted = await finalize({
      orderRef,
      orderId,
      callbackAmount: PREMIUM_AMOUNT,
      callbackCurrency: "TRY",
      callbackMetadata: { authCode: "R1" },
    });
    if (accepted.status === "missing") {
      await cleanup(uid, orderRef);
      return INTERFERED;
    }

    assert.equal(accepted.status, "completed", "the refusal must not have poisoned the order");
    const after = await readState(uid, orderRef);
    assert.equal(after.order.paymentStatus, "paid");
    assert.equal(after.order.payment.finalizationStatus, "completed");
    assert.equal(after.sub.sources.web_isbank.plan, "premium");
    await cleanup(uid, orderRef);
    return null;
  });
});

// =====================================================================
// F — concurrency
// =====================================================================

itest("F. two concurrent valid finalizations produce exactly one entitlement outcome", async () => {
  await withRetryOnExternalWipe("F", async () => {
    const uid = freshUid("concurrent");
    const orderId = deterministicOrderId(uid, "premium", Date.now());
    const orderRef = await seedOrder({
      uid,
      planId: "premium",
      grandTotal: Number(PREMIUM_AMOUNT),
      orderId,
    });

    const call = () =>
      finalize({
        orderRef,
        orderId,
        callbackAmount: PREMIUM_AMOUNT,
        callbackCurrency: "TRY",
        callbackMetadata: {},
      });

    const results = await Promise.all([call(), call()]);
    if (results.some((r) => r.status === "missing")) {
      await cleanup(uid, orderRef);
      return INTERFERED;
    }

    const completed = results.filter((r) => r.status === "completed");
    const statuses = results.map((r) => r.status).join(", ");

    // The security invariant: concurrency must never produce two grants.
    assert.equal(
      completed.length,
      1,
      `exactly one finalization may grant the entitlement (observed: ${statuses})`
    );
    assert.equal(
      results.filter((r) => r.status === "alreadyProcessed").length,
      1,
      `the loser must observe the idempotent result (observed: ${statuses})`
    );

    const after = await readState(uid, orderRef);
    const stored = after.sub.sources.web_isbank.expiresAt.toDate().getTime();
    assert.equal(
      stored,
      completed[0].expiresAt.getTime(),
      "the stored entitlement must be the single granted window, not a doubled one"
    );
    await cleanup(uid, orderRef);
    return null;
  });
});

// =====================================================================
// G — replay
// =====================================================================

itest("G. a replay after completion is idempotent and does not extend the entitlement", async () => {
  await withRetryOnExternalWipe("G", async () => {
    const uid = freshUid("replay");
    const orderId = deterministicOrderId(uid, "premium", Date.now());
    const orderRef = await seedOrder({
      uid,
      planId: "premium",
      grandTotal: Number(PREMIUM_AMOUNT),
      orderId,
    });

    const first = await finalize({
      orderRef,
      orderId,
      callbackAmount: PREMIUM_AMOUNT,
      callbackCurrency: "TRY",
      callbackMetadata: {},
    });
    if (first.status === "missing") {
      await cleanup(uid, orderRef);
      return INTERFERED;
    }
    assert.equal(first.status, "completed");
    const afterFirst = await readState(uid, orderRef);
    const firstExpiry = afterFirst.sub.sources.web_isbank.expiresAt.toDate().getTime();

    for (let i = 0; i < 3; i += 1) {
      const replay = await finalize({
        orderRef,
        orderId,
        callbackAmount: PREMIUM_AMOUNT,
        callbackCurrency: "TRY",
        callbackMetadata: {},
      });
      if (replay.status === "missing") {
        await cleanup(uid, orderRef);
        return INTERFERED;
      }
      assert.equal(replay.status, "alreadyProcessed", `replay ${i + 1} must be idempotent`);
      assert.equal(replay.expiresAt, undefined, "a replay must not report a new window");
    }

    const afterReplays = await readState(uid, orderRef);
    assert.equal(
      afterReplays.sub.sources.web_isbank.expiresAt.toDate().getTime(),
      firstExpiry,
      "replays must not extend the entitlement"
    );
    await cleanup(uid, orderRef);
    return null;
  });
});

itest("G. a replayed callback carrying a forged amount is still only idempotent", async () => {
  await withRetryOnExternalWipe("G-forged-replay", async () => {
    const uid = freshUid("replay-forged");
    const orderId = deterministicOrderId(uid, "premium", Date.now());
    const orderRef = await seedOrder({
      uid,
      planId: "premium",
      grandTotal: Number(PREMIUM_AMOUNT),
      orderId,
    });

    const first = await finalize({
      orderRef, orderId,
      callbackAmount: PREMIUM_AMOUNT, callbackCurrency: "TRY", callbackMetadata: {},
    });
    if (first.status === "missing") {
      await cleanup(uid, orderRef);
      return INTERFERED;
    }
    assert.equal(first.status, "completed");
    const expiry = (await readState(uid, orderRef)).sub.sources.web_isbank.expiresAt
      .toDate()
      .getTime();

    const replay = await finalize({
      orderRef,
      orderId,
      callbackAmount: "0.01",
      callbackCurrency: "TRY",
      callbackMetadata: {},
    });
    if (replay.status === "missing") {
      await cleanup(uid, orderRef);
      return INTERFERED;
    }
    assert.equal(replay.status, "alreadyProcessed");
    assert.equal(
      (await readState(uid, orderRef)).sub.sources.web_isbank.expiresAt.toDate().getTime(),
      expiry,
      "a forged replay must not alter the entitlement"
    );
    await cleanup(uid, orderRef);
    return null;
  });
});

// =====================================================================
// H — the seam is the production finalizer, not a copy
// =====================================================================

itest("H. the test seam is the SAME function object the production callback calls", () => {
  assert.equal(typeof finalize, "function", "the seam must be exported");
  assert.equal(
    finalize.name,
    "finalizeWebSubscriptionPayment",
    "the seam must be the production function itself, not a wrapper or a copy"
  );
});

test("H. the seam is not a deployed Cloud Function", () => {
  // Firebase deployment discovery only deploys exports carrying `__endpoint`.
  const mod = require("../index");
  const seam = mod.testOnlyFinalizeWebSubscriptionPayment;
  assert.equal(seam.__endpoint, undefined, "the seam must not be deployable");
  assert.equal(seam.__trigger, undefined, "the seam must not be deployable");
});

// ---------------------------------------------------------------------
// SOURCE-TEXT assertion — explicitly labelled as such.
//
// Everything above is behavioural. This single assertion covers the one
// residual link that cannot be executed without a valid İş Bank HMAC: that
// `isbank3DPayHostingCallback` reaches the finalizer proven above. It pins the
// call site by name; the identity of that name is proven behaviourally by
// test H.
// ---------------------------------------------------------------------

test("H. SOURCE-TEXT: the İş Bank callback still routes web_subscription orders to this finalizer", () => {
  const source = fs.readFileSync(path.resolve(__dirname, "../index.js"), "utf8");

  const callback = source.match(
    /exports\.isbank3DPayHostingCallback[\s\S]*?^\);/m
  );
  assert.ok(callback, "the callback must exist");
  const branch = callback[0].match(
    /if \(orderData\.orderType === "web_subscription"\)[\s\S]*?ISBANK_FINALIZATION_ERROR/
  );
  assert.ok(branch, "the callback must branch on the web_subscription order type");
  assert.match(
    branch[0],
    /await finalizeWebSubscriptionPayment\(\{/,
    "the callback must call the finalizer this suite drives"
  );
  assert.match(branch[0], /orderRef,/);
  assert.match(branch[0], /callbackAmount,/);

  // The seam aliases that exact declared function.
  assert.match(
    source,
    /exports\.testOnlyFinalizeWebSubscriptionPayment = finalizeWebSubscriptionPayment;/,
    "the seam must alias the production function without wrapping it"
  );

  // HMAC validation is untouched: the callback still authenticates before
  // reaching any finalization branch.
  const hashIndex = callback[0].indexOf("const hashValid = calculatedHashValid;");
  const rejectIndex = callback[0].indexOf("if (!hashValid) {");
  const branchIndex = callback[0].indexOf('orderData.orderType === "web_subscription"');
  assert.ok(hashIndex >= 0, "the callback must still validate the provider hash");
  assert.ok(rejectIndex > hashIndex, "an invalid hash must still be rejected");
  assert.ok(
    rejectIndex < branchIndex,
    "HMAC rejection must still precede subscription finalization"
  );
});
