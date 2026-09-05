"use strict";

// Marketplace Revision 46 §0.44 (Slice 7F-1) — the POSITIVE half of the
// explicit-denial slice.
//
// `marketplaceInventoryInternalRules.test.js` proves that no client-SDK actor
// can touch the server-internal inventory collections. That proof would be
// worthless if the trusted server path had also been broken — a Rules file
// that denies everyone, including the code that owns the data, is not
// security, it is an outage.
//
// Firestore Rules never apply to the Admin SDK, so this cannot be shown with
// a Rules test. It is shown by driving the REAL runtime modules
// (`reserveInventory`, `releaseInventory`, `claimCheckoutAttempt`) against the
// emulator through the Admin SDK, exactly as production does, and observing
// that the internal documents are still created, read and updated.
//
// It activates nothing: these modules are called directly, so no feature flag
// is read and M3/M5 remain disabled.

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test, after } = require("node:test");

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
}
const db = admin.firestore();

const {
  reserveInventory,
  releaseInventory,
} = require("../src/inventory/inventoryTransactions");
const {
  claimCheckoutAttempt,
  CHECKOUT_ATTEMPT_COLLECTION,
  CHECKOUT_ATTEMPT_STATUS,
} = require("../src/inventory/inventoryCheckoutCoordinator");
const {
  INVENTORY_COLLECTIONS,
  RESERVATION_STATUS,
} = require("../src/inventory/inventoryConstants");
const { reservationRef } = require("../src/inventory/inventoryRepository");

const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function itest(name, fn) {
  test(name, { skip: !hasEmulator }, fn);
}

const RUN = Math.random().toString(36).slice(2, 8);
let seq = 0;
const created = { orders: [], sellerOrders: [], businesses: [], attempts: [] };

function identity(label) {
  seq += 1;
  const suffix = `${label}-${RUN}-${seq}`;
  return {
    rootOrderId: `7f1-order-${suffix}`,
    sellerOrderId: `7f1-sorder-${suffix}`,
    lineId: `7f1-line-${suffix}`,
    businessId: `7f1-biz-${suffix}`,
    productId: `7f1-prod-${suffix}`,
  };
}

async function seedLine(line, stock = 3) {
  created.orders.push(line.rootOrderId);
  created.sellerOrders.push(line.sellerOrderId);
  created.businesses.push({ businessId: line.businessId, productId: line.productId });
  const batch = db.batch();
  batch.set(db.collection("orders").doc(line.rootOrderId), {
    buyerUid: "7f1-buyer",
    sellerOrderIds: [line.sellerOrderId],
    inventoryStatus: "not_started",
    inventorySchemaVersion: 1,
    inventoryOperationVersion: 1,
    inventoryLineSet: [{ ...line, quantity: 1, unitPrice: 10, totalPrice: 10, currency: "TRY" }],
    pricing: { grandTotal: 10, currency: "TRY" },
  });
  batch.set(db.collection("sellerOrders").doc(line.sellerOrderId), {
    rootOrderId: line.rootOrderId,
    inventoryLines: [{
      ...line, quantity: 1, unitPrice: 10, totalPrice: 10,
      currency: "TRY", buyerUid: "7f1-buyer", inventoryStatus: "not_started",
    }],
    inventoryStatus: "not_started",
    inventorySchemaVersion: 1,
    inventoryOperationVersion: 1,
  });
  batch.set(
    db.collection("businesses").doc(line.businessId)
      .collection("products").doc(line.productId),
    { stock, reservedStock: 0 }
  );
  await batch.commit();
}

after(async () => {
  if (!hasEmulator) return;
  await Promise.allSettled([
    ...created.orders.map((id) => db.collection("orders").doc(id).delete()),
    ...created.sellerOrders.map((id) => db.collection("sellerOrders").doc(id).delete()),
    ...created.businesses.map(({ businessId, productId }) =>
      db.collection("businesses").doc(businessId)
        .collection("products").doc(productId).delete()),
    ...created.businesses.map(({ businessId }) =>
      db.collection("businesses").doc(businessId).delete()),
    ...created.attempts.map((id) =>
      db.collection(CHECKOUT_ATTEMPT_COLLECTION).doc(id).delete()),
  ]);
});

// =====================================================================
// The trusted path still owns its collections
// =====================================================================

itest("TRUSTED: reserveInventory still creates and reads its reservation record", async () => {
  const line = identity("reserve");
  await seedLine(line);

  const result = await reserveInventory({
    db,
    identity: { ...line, buyerUid: "7f1-buyer" },
    quantity: 1,
  });
  assert.ok(result, "the runtime reservation must succeed");

  // The internal document the Rules now deny to every client is present and
  // readable by the trusted server.
  const snap = await reservationRef(db, line).get();
  assert.equal(snap.exists, true, "the reservation document must exist");
  assert.equal(snap.data().status, RESERVATION_STATUS.RESERVED);

  // And the stock effect landed on the product, per the frozen formula:
  // reserve raises reservedStock and leaves stock alone.
  const product = (
    await db.collection("businesses").doc(line.businessId)
      .collection("products").doc(line.productId).get()
  ).data();
  assert.equal(product.stock, 3, "reserve must not decrement stock");
  assert.equal(product.reservedStock, 1, "reserve must raise reservedStock");
});

itest("TRUSTED: the append-only movement and event trails are still written", async () => {
  const line = identity("trails");
  await seedLine(line);
  await reserveInventory({ db, identity: { ...line, buyerUid: "7f1-buyer" }, quantity: 1 });

  // The two trails carry the line identity differently: movements store it
  // flat, events nest it under `aggregate`. Both are queried by their own
  // real shape rather than a guessed common field.
  const movements = await db
    .collection(INVENTORY_COLLECTIONS.MOVEMENTS)
    .where("orderId", "==", line.rootOrderId)
    .get();
  assert.ok(
    movements.size > 0,
    "inventoryMovements must still receive the trusted write"
  );

  const events = await db
    .collection(INVENTORY_COLLECTIONS.EVENTS)
    .where("aggregate.rootOrderId", "==", line.rootOrderId)
    .get();
  assert.ok(
    events.size > 0,
    "inventoryEvents must still receive the trusted write"
  );
});

itest("TRUSTED: releaseInventory still updates the reservation it owns", async () => {
  const line = identity("release");
  await seedLine(line);
  await reserveInventory({ db, identity: { ...line, buyerUid: "7f1-buyer" }, quantity: 1 });

  await releaseInventory({
    db,
    identity: { ...line, buyerUid: "7f1-buyer" },
    quantity: 1,
    reason: "payment_failure",
  });

  const snap = await reservationRef(db, line).get();
  assert.equal(
    snap.data().status,
    RESERVATION_STATUS.RELEASED,
    "the trusted server must still be able to move the reservation to a terminal state"
  );
  const product = (
    await db.collection("businesses").doc(line.businessId)
      .collection("products").doc(line.productId).get()
  ).data();
  assert.equal(product.reservedStock, 0, "release must lower reservedStock");
  assert.equal(product.stock, 3, "release must not change stock");
});

itest("TRUSTED: claimCheckoutAttempt still creates and re-reads its idempotency record", async () => {
  const buyerUid = `7f1-buyer-${RUN}`;
  const checkoutAttemptId = `attempt-${RUN}`;
  const attemptDocId = `${encodeURIComponent(buyerUid)}__${encodeURIComponent(checkoutAttemptId)}`;
  created.attempts.push(attemptDocId);

  const args = {
    db,
    buyerUid,
    checkoutAttemptId,
    cartFingerprint: "fingerprint-abc",
    amount: 10,
    currency: "TRY",
    rootOrderId: `7f1-order-attempt-${RUN}`,
  };

  const first = await claimCheckoutAttempt(args);
  assert.ok(first, "the trusted server must be able to claim an attempt");

  const snap = await db.collection(CHECKOUT_ATTEMPT_COLLECTION).doc(attemptDocId).get();
  assert.equal(snap.exists, true, "the attempt document must exist");
  assert.equal(snap.data().buyerUid, buyerUid);

  // Re-claiming the same intent is the idempotent path, and it still reads
  // the record the Rules deny to clients.
  const second = await claimCheckoutAttempt(args);
  assert.ok(second, "an identical re-claim must still resolve");
  // `claimCheckoutAttempt` returns a CLAIM outcome, which is a different
  // vocabulary from the stored CHECKOUT_ATTEMPT_STATUS the document carries.
  // What matters here is only that the trusted path can still re-read and
  // re-resolve its own record; the idempotency semantics themselves are the
  // coordinator suite's subject, not this slice's.
  assert.equal(typeof second.status, "string");
  assert.ok(second.status.length > 0, "a claim outcome must be reported");
  const reread = await db.collection(CHECKOUT_ATTEMPT_COLLECTION).doc(attemptDocId).get();
  assert.equal(reread.exists, true, "the attempt must still be re-readable");
  assert.ok(
    Object.values(CHECKOUT_ATTEMPT_STATUS).includes(reread.data().status),
    `stored attempt status must be a known value: ${reread.data().status}`
  );
});

itest("the positive proof did not activate M3 or M5", () => {
  // These modules were called directly; no flag was read or set. If a future
  // edit made this suite depend on an enabled flag, that would be a scope
  // violation, not a passing test.
  assert.notEqual(
    String(process.env.M3_INVENTORY_RESERVATION_ENABLED).toLowerCase(),
    "true",
    "M3 must remain disabled"
  );
  for (const flag of [
    "INVENTORY_FAILURE_RELEASE_ENABLED",
    "INVENTORY_CANCELLATION_RELEASE_ENABLED",
    "INVENTORY_EXPIRY_SCHEDULER_ENABLED",
    "INVENTORY_LEASE_RECOVERY_ENABLED",
    "LATE_PAYMENT_RECOVERY_ENABLED",
  ]) {
    assert.notEqual(
      String(process.env[flag]).toLowerCase(),
      "true",
      `${flag} must remain disabled`
    );
  }
});
