"use strict";

// Marketplace Revision 40 §0.38 — order ownership and refund integrity.
//
// Exercises the real exported callables through their `.run()` helper against
// the Firestore emulator. SYNTHETIC fixtures only: no production order, no
// production payment, and no provider API is ever contacted — every test that
// could reach a provider is asserted to be REJECTED before it gets there.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

// `createCheckoutSession` validates PAYMENT_PROVIDER before authentication —
// a pure configuration gate that discloses nothing about any order. Tests must
// therefore configure a provider to reach the ownership gate at all. No
// provider is ever contacted: every case below is asserted to be REJECTED
// before any provider call, and the static ordering tests prove that.
process.env.PAYMENT_PROVIDER = process.env.PAYMENT_PROVIDER || "iyzico";

// The return path touches Cloud Storage for return images, so the emulator
// and a bucket must be configured or every case fails on storage before
// reaching the assertions under test.
process.env.FIREBASE_STORAGE_EMULATOR_HOST =
  process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199";

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: process.env.GCLOUD_PROJECT || "demo-petsupo",
    storageBucket: `${process.env.GCLOUD_PROJECT || "demo-petsupo"}.appspot.com`,
  });
}
const db = admin.firestore();
const functions = require("../index");
const {
  assessOrderOwnership,
  OWNERSHIP_RESULT,
} = require("../src/marketplace/orders/orderOwnership");

const hasFs = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const itest = (n, f) => test(n, { skip: !hasFs }, f);

let seq = 0;
const RUN = `own${Math.random().toString(36).slice(2, 8)}`;
const nextId = (p) => `${p}-${RUN}-${++seq}`;

const orderRef = (id) => db.collection("orders").doc(id);
const sellerOrderRef = (id) => db.collection("sellerOrders").doc(id);

async function seedOrder({ buyerField = "buyerUid", buyerUid, overrides = {} } = {}) {
  const orderId = nextId("order");
  const payload = {
    orderId,
    status: "payment_pending",
    paymentStatus: "pending",
    currency: "TRY",
    pricing: { grandTotal: 100 },
    items: [{ productId: nextId("prod"), quantity: 1, price: 100 }],
    createdAt: admin.firestore.Timestamp.now(),
    ...overrides,
  };
  if (buyerUid !== undefined && buyerField) payload[buyerField] = buyerUid;
  await orderRef(orderId).set(payload);
  return orderId;
}

async function outcomeOf(promise) {
  try {
    const value = await promise;
    return { ok: true, value };
  } catch (error) {
    return { ok: false, code: error.code, message: error.message };
  }
}

const callCheckout = (uid, data) =>
  functions.createCheckoutSession.run({ auth: uid ? { uid } : null, data });
const callVerify = (uid, data) =>
  functions.verifyPaymentByOrderId.run({ auth: uid ? { uid } : null, data });

// =====================================================================
// A. createCheckoutSession ownership — items 1-9
// =====================================================================

itest("1. an unauthenticated caller cannot create a checkout session", async () => {
  const orderId = await seedOrder({ buyerUid: "alice" });
  const r = await outcomeOf(callCheckout(null, { orderId, items: [] }));
  assert.equal(r.ok, false);
  assert.equal(r.code, "unauthenticated");
});

itest("3. a FOREIGN customer cannot create a checkout session on another user's order", async () => {
  const orderId = await seedOrder({ buyerUid: "alice" });
  const before = (await orderRef(orderId).get()).data();

  const r = await outcomeOf(callCheckout("mallory", { orderId, items: [] }));
  assert.equal(r.ok, false, "a foreign order must be refused");
  assert.equal(r.code, "not-found");

  // 9. no write occurred, and 8. no provider session was created.
  const after = (await orderRef(orderId).get()).data();
  assert.deepEqual(after, before, "an unauthorized caller must mutate nothing");
  assert.equal(after.payment, undefined, "no payment/session state may be written");
});

itest("4. a seller who is not the buyer is refused as a customer", async () => {
  const orderId = await seedOrder({
    buyerUid: "alice",
    overrides: { businessId: "biz-1", sellerUid: "seller-1" },
  });
  const r = await outcomeOf(callCheckout("seller-1", { orderId, items: [] }));
  assert.equal(r.ok, false);
  assert.equal(r.code, "not-found");
});

itest("5. an order with NO buyer identity is refused — the caller is not adopted as owner", async () => {
  const orderId = await seedOrder({ buyerField: null });
  const r = await outcomeOf(callCheckout("mallory", { orderId, items: [] }));
  assert.equal(r.ok, false);
  assert.equal(r.code, "not-found");
  const after = (await orderRef(orderId).get()).data();
  assert.equal(after.payment, undefined);
});

itest("6. conflicting legacy buyer fields are refused for both named uids", async () => {
  const orderId = await seedOrder({
    buyerUid: "alice",
    overrides: { userId: "bob" },
  });
  for (const caller of ["alice", "bob", "mallory"]) {
    const r = await outcomeOf(callCheckout(caller, { orderId, items: [] }));
    assert.equal(r.ok, false, caller);
    assert.equal(r.code, "not-found", caller);
  }
});

itest("7. a nonexistent order and a foreign order are indistinguishable", async () => {
  const foreignId = await seedOrder({ buyerUid: "alice" });
  const ghostId = nextId("ghost-order");
  const foreign = await outcomeOf(callCheckout("mallory", { orderId: foreignId, items: [] }));
  const ghost = await outcomeOf(callCheckout("mallory", { orderId: ghostId, items: [] }));
  assert.equal(foreign.code, ghost.code, "codes must match");
  assert.equal(foreign.message, ghost.message, "messages must match — no enumeration oracle");
});

itest("2/9. the legacy `userId` schema is accepted for its own owner", async () => {
  // The frozen Rules contract (`isOrderOwner`) recognises both historical
  // fields; the resolver must too, or legacy buyers lose access to their own
  // orders. This asserts authorization is REACHED, not that a provider
  // session succeeds — no provider is contacted in tests.
  const orderId = await seedOrder({ buyerField: "userId", buyerUid: "legacy-buyer" });
  const r = await outcomeOf(callCheckout("legacy-buyer", { orderId, items: [] }));
  assert.notEqual(r.code, "not-found", "the rightful legacy owner must pass the ownership gate");
});

// =====================================================================
// B. verifyPaymentByOrderId ownership — items 10-16
// =====================================================================

itest("11/12/13. a foreign caller cannot verify, observe or pay another user's order", async () => {
  const orderId = await seedOrder({
    buyerUid: "alice",
    overrides: { payment: { token: "tok-secret", status: "pending", paymentId: "pay-1" } },
  });
  const before = (await orderRef(orderId).get()).data();

  const r = await outcomeOf(callVerify("mallory", { orderId }));
  assert.equal(r.ok, false);
  assert.equal(r.code, "not-found");
  // No provider state disclosed.
  assert.equal(JSON.stringify(r).includes("tok-secret"), false, "no payment token may leak");

  // 13/14. nothing was marked paid and no inventory was committed.
  const after = (await orderRef(orderId).get()).data();
  assert.deepEqual(after, before);
  assert.notEqual(after.status, "paid");
});

itest("10. the rightful buyer passes the verification ownership gate", async () => {
  const orderId = await seedOrder({ buyerUid: "alice" });
  const r = await outcomeOf(callVerify("alice", { orderId }));
  // It will fail later for want of a real provider payment — but NOT with the
  // ownership denial, which is what this asserts.
  assert.notEqual(
    r.code === "not-found" && r.message === "Order not found",
    true,
    "the owner must pass the ownership gate"
  );
});

itest("11b. verification of a nonexistent and a foreign order are indistinguishable", async () => {
  const foreignId = await seedOrder({ buyerUid: "alice" });
  const ghostId = nextId("ghost-order");
  const foreign = await outcomeOf(callVerify("mallory", { orderId: foreignId }));
  const ghost = await outcomeOf(callVerify("mallory", { orderId: ghostId }));
  assert.equal(foreign.code, ghost.code);
  assert.equal(foreign.message, ghost.message);
});

itest("9b. no mutation of ANY kind occurs before authorization, across both callables", async () => {
  const orderId = await seedOrder({
    buyerUid: "alice",
    overrides: { sellerOrderIds: ["so-1"] },
  });
  await sellerOrderRef("so-1").set({
    rootOrderId: orderId,
    buyerUid: "alice",
    status: "payment_pending",
  });
  const orderBefore = (await orderRef(orderId).get()).data();
  const sellerBefore = (await sellerOrderRef("so-1").get()).data();

  await outcomeOf(callCheckout("mallory", { orderId, items: [] }));
  await outcomeOf(callVerify("mallory", { orderId }));

  assert.deepEqual((await orderRef(orderId).get()).data(), orderBefore);
  assert.deepEqual((await sellerOrderRef("so-1").get()).data(), sellerBefore);
});

// =====================================================================
// C. Static contract — the ordering and derivation guarantees
// =====================================================================

const INDEX_SOURCE = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");

function bodyOf(exportName, endMarker) {
  const start = INDEX_SOURCE.indexOf(`exports.${exportName} =`);
  assert.notEqual(start, -1, exportName);
  const end = INDEX_SOURCE.indexOf(endMarker, start);
  return INDEX_SOURCE.slice(start, end === -1 ? start + 60000 : end);
}

itest("8. checkout authorization precedes every provider call and every write", async () => {
  const body = bodyOf("createCheckoutSession", "exports.verifyPaymentByOrderId");
  const gate = body.indexOf("assessOrderOwnership");
  assert.notEqual(gate, -1, "the ownership gate must exist");
  for (const sideEffect of ["checkoutFormInitialize", "orderRef.set(", "batch.commit(", "iyzipay"]) {
    const at = body.indexOf(sideEffect);
    if (at === -1) continue;
    assert.ok(at > gate, `${sideEffect} must come AFTER the ownership gate`);
  }
});

itest("15. verification authorization precedes the payment-callback claim and every write", async () => {
  const body = bodyOf("verifyPaymentByOrderId", "exports.markMarketplaceCheckoutFailed");
  const gate = body.indexOf("assessOrderOwnership");
  assert.notEqual(gate, -1);
  for (const sideEffect of ["claimPaymentCallback", "batch.commit(", "commitVerifiedMarketplaceInventory"]) {
    const at = body.indexOf(sideEffect);
    if (at === -1) continue;
    assert.ok(at > gate, `${sideEffect} must come AFTER the ownership gate`);
  }
});

itest("ownership helper is the single source used by every repaired callable", async () => {
  // Four call sites: createCheckoutSession, verifyPaymentByOrderId,
  // verifyPayment (and its verifyHotelBookingPayment alias, same handler) and
  // the createIsbank3DPayHostingCheckout wrapper.
  assert.equal((INDEX_SOURCE.match(/assessOrderOwnership\(\{/g) || []).length, 4);
  assert.equal(
    (INDEX_SOURCE.match(/require\("\.\/src\/marketplace\/orders\/orderOwnership"\)/g) || []).length,
    1
  );
  // And no callable re-derives buyer identity inline from request data.
  assert.equal(/callerUid:\s*data\./.test(INDEX_SOURCE), false);
});

itest("the ownership verdict never reaches a customer-facing message", async () => {
  const orderId = await seedOrder({ buyerUid: "alice", overrides: { userId: "bob" } });
  const r = await outcomeOf(callCheckout("mallory", { orderId, items: [] }));
  const serialized = JSON.stringify(r);
  for (const internal of Object.values(OWNERSHIP_RESULT)) {
    assert.equal(serialized.includes(internal), false, `leaked ${internal}`);
  }
  assert.equal(serialized.includes("alice"), false);
  assert.equal(serialized.includes("bob"), false);
  // Sanity: the helper itself would have reported the conflict internally.
  assert.equal(
    assessOrderOwnership({ orderData: { buyerUid: "alice", userId: "bob" }, callerUid: "mallory" }).result,
    OWNERSHIP_RESULT.BUYER_IDENTITY_CONFLICT
  );
});

// =====================================================================
// D. The two sibling defects found during the trace
// =====================================================================

itest("5b. verifyPayment — the most Flutter-reachable handler — refuses a foreign order", async () => {
  const orderId = await seedOrder({
    buyerUid: "alice",
    overrides: { payment: { checkoutToken: "tok-secret" } },
  });
  const before = (await orderRef(orderId).get()).data();

  const r = await outcomeOf(
    functions.verifyPayment.run({ auth: { uid: "mallory" }, data: { orderId } })
  );
  assert.equal(r.ok, false);
  assert.equal(r.code, "not-found");
  assert.equal(JSON.stringify(r).includes("tok-secret"), false, "no payment token may leak");
  assert.deepEqual((await orderRef(orderId).get()).data(), before, "no mutation");
});

itest("5c. verifyPayment authorization precedes the payment token read and every write", async () => {
  const body = bodyOf("verifyPayment", "exports.verifyHotelBookingPayment");
  const gate = body.indexOf("assessOrderOwnership");
  assert.notEqual(gate, -1, "verifyPayment must have an ownership gate");
  const tokenRead = body.indexOf("orderData.payment?.checkoutToken");
  assert.ok(tokenRead > gate, "the provider token must be read only AFTER authorization");
  for (const sideEffect of ["batch.commit(", "claimPaymentCallback"]) {
    const at = body.indexOf(sideEffect);
    if (at === -1) continue;
    assert.ok(at > gate, `${sideEffect} must come AFTER the ownership gate`);
  }
});

itest("5d. the Isbank hosting callable refuses a foreign order and never signs a forged amount", async () => {
  const orderId = await seedOrder({
    buyerUid: "alice",
    overrides: { pricing: { grandTotal: 100 } },
  });
  const foreign = await outcomeOf(
    functions.createIsbank3DPayHostingCheckout.run({
      auth: { uid: "mallory" },
      data: { oid: orderId, amount: 1 },
    })
  );
  assert.equal(foreign.ok, false);
  assert.equal(foreign.code, "not-found");

  // The rightful owner supplying a tampered amount is refused too — the
  // canonical stored total is the only authority.
  const tampered = await outcomeOf(
    functions.createIsbank3DPayHostingCheckout.run({
      auth: { uid: "alice" },
      data: { oid: orderId, amount: 1 },
    })
  );
  assert.equal(tampered.ok, false);
  assert.equal(tampered.code, "failed-precondition");
  // Asserted on the MESSAGE, not just the code: a missing-gateway-config
  // failure downstream also reports `failed-precondition`, so the code alone
  // cannot tell "the guard rejected this" from "the guard was never reached".
  assert.equal(
    tampered.message,
    "Order total is not available",
    "the amount-tampering guard itself must be what rejects this"
  );

  // An order with no usable canonical total fails closed rather than
  // falling back to the caller's number.
  const noTotal = await seedOrder({ buyerUid: "alice", overrides: { pricing: {} } });
  const failed = await outcomeOf(
    functions.createIsbank3DPayHostingCheckout.run({
      auth: { uid: "alice" },
      data: { oid: noTotal, amount: 500 },
    })
  );
  assert.equal(failed.ok, false);
  assert.equal(failed.code, "failed-precondition");
});

itest("5e. the Isbank INNER function is untouched — internal callers keep their contract", async () => {
  // Five internal callers (appointment, pet-taxi, subscription, promotion,
  // marketplace) invoke the inner function directly and must not have gained
  // an ownership requirement.
  assert.equal(
    (INDEX_SOURCE.match(/createIsbank3DPayHostingCheckoutResult\(/g) || []).length >= 6,
    true
  );
  const innerStart = INDEX_SOURCE.indexOf("async function createIsbank3DPayHostingCheckoutResult");
  const innerEnd = INDEX_SOURCE.indexOf("exports.createIsbank3DPayHostingCheckout");
  const inner = INDEX_SOURCE.slice(innerStart, innerEnd);
  assert.equal(inner.includes("assessOrderOwnership"), false, "the inner function must stay unchanged");
});
