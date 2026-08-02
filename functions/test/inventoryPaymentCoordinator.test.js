"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { reserveInventory } = require("../src/inventory/inventoryTransactions");
const {
  commitVerifiedMarketplaceInventory,
} = require("../src/inventory/inventoryPaymentCoordinator");
const {
  claimPaymentCallback,
  completePaymentCallback,
} = require("../src/inventory/paymentCallbackClaims");
const { reservationRef } = require("../src/inventory/inventoryRepository");

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
if (emulatorAvailable && !admin.apps.length) admin.initializeApp({ projectId: "demo-petsupo-m4" });
const db = emulatorAvailable ? admin.firestore() : null;
let sequence = 0;

function requireEmulator(name, fn) {
  return test(name, { skip: !emulatorAvailable }, fn);
}

function identity(label) {
  sequence += 1;
  return {
    rootOrderId: `m4-root-${label}-${sequence}`,
    sellerOrderId: `m4-seller-${label}-${sequence}`,
    lineId: `m4-line-${label}-${sequence}`,
    businessId: `m4-business-${label}-${sequence}`,
    productId: `m4-product-${label}-${sequence}`,
  };
}

async function seedReservedLine(line) {
  const batch = db.batch();
  batch.set(db.collection("orders").doc(line.rootOrderId), {
    buyerUid: "m4-buyer",
    sellerOrderIds: [line.sellerOrderId],
    inventoryStatus: "reserved",
    inventorySchemaVersion: 1,
    inventoryOperationVersion: 1,
    inventoryLineSet: [{
      ...line,
      quantity: 1,
      unitPrice: 10,
      totalPrice: 10,
      currency: "TRY",
    }],
    pricing: { grandTotal: 10, currency: "TRY" },
  });
  batch.set(db.collection("sellerOrders").doc(line.sellerOrderId), {
    rootOrderId: line.rootOrderId,
    inventoryLines: [{
      ...line,
      quantity: 1,
      unitPrice: 10,
      totalPrice: 10,
      currency: "TRY",
      buyerUid: "m4-buyer",
      inventoryStatus: "reserved",
    }],
    inventoryStatus: "reserved",
    inventorySchemaVersion: 1,
    inventoryOperationVersion: 1,
  });
  batch.set(
    db.collection("businesses").doc(line.businessId).collection("products").doc(line.productId),
    { stock: 1, reservedStock: 0 }
  );
  await batch.commit();
  await reserveInventory({ db, identity: { ...line, buyerUid: "m4-buyer" }, quantity: 1 });
}

requireEmulator("verified payment commits inventory exactly once", async () => {
  const line = identity("success");
  await seedReservedLine(line);
  const first = await commitVerifiedMarketplaceInventory({
    db,
    orderId: line.rootOrderId,
    provider: "isbank",
    paymentId: "isbank-payment-1",
    amount: 10,
    currency: "TRY",
  });
  const second = await commitVerifiedMarketplaceInventory({
    db,
    orderId: line.rootOrderId,
    provider: "isbank",
    paymentId: "isbank-payment-1",
    amount: 10,
    currency: "TRY",
  });
  assert.equal(first.status, "committed");
  assert.equal(second.status, "committed");
  const product = await db.collection("businesses").doc(line.businessId).collection("products").doc(line.productId).get();
  assert.equal(product.data().stock, 0);
  assert.equal(product.data().reservedStock, 0);
  assert.equal((await db.collection("inventoryMovements").get()).size, 2);
});

requireEmulator("callback claims serialize duplicate provider success", async () => {
  const first = await claimPaymentCallback({
    db,
    provider: "iyzico",
    orderId: "m4-claim-order",
    paymentId: "iyzico-payment-1",
    providerEventId: "iyzico-event-1",
    amount: 10,
    currency: "TRY",
  });
  const second = await claimPaymentCallback({
    db,
    provider: "iyzico",
    orderId: "m4-claim-order",
    paymentId: "iyzico-payment-1",
    providerEventId: "iyzico-event-1",
    amount: 10,
    currency: "TRY",
  });
  assert.equal(first.status, "claimed");
  assert.equal(second.status, "processing");
  await completePaymentCallback({
    ref: first.ref,
    ownerToken: first.ownerToken,
    result: { status: "committed" },
  });
  const duplicate = await claimPaymentCallback({
    db,
    provider: "iyzico",
    orderId: "m4-claim-order",
    paymentId: "iyzico-payment-1",
    providerEventId: "iyzico-event-1",
    amount: 10,
    currency: "TRY",
  });
  assert.equal(duplicate.status, "already_processed");
});

requireEmulator("missing product becomes manual review", async () => {
  const line = identity("recovery");
  await seedReservedLine(line);
  const productRef = db.collection("businesses").doc(line.businessId).collection("products").doc(line.productId);
  await productRef.delete();
  const failed = await commitVerifiedMarketplaceInventory({
    db,
    orderId: line.rootOrderId,
    provider: "iyzico",
    paymentId: "iyzico-payment-recovery",
    amount: 10,
    currency: "TRY",
  });
  assert.equal(failed.status, "manual_review");
  await productRef.set({ stock: 1, reservedStock: 1 });
  const recovered = await commitVerifiedMarketplaceInventory({
    db,
    orderId: line.rootOrderId,
    provider: "iyzico",
    paymentId: "iyzico-payment-recovery",
    amount: 10,
    currency: "TRY",
  });
  assert.equal(recovered.status, "committed");
  assert.equal((await db.collection("businesses").doc(line.businessId).collection("products").doc(line.productId).get()).data().stock, 0);
});

requireEmulator("payment amount mismatch is manual review and corrected retry commits", async () => {
  const line = identity("amount-mismatch");
  await seedReservedLine(line);
  const mismatch = await commitVerifiedMarketplaceInventory({
    db,
    orderId: line.rootOrderId,
    provider: "iyzico",
    paymentId: "iyzico-payment-amount",
    amount: 9,
    currency: "TRY",
  });
  assert.equal(mismatch.status, "manual_review");
  assert.equal((await db.collection("businesses").doc(line.businessId).collection("products").doc(line.productId).get()).data().stock, 1);
  const corrected = await commitVerifiedMarketplaceInventory({
    db,
    orderId: line.rootOrderId,
    provider: "iyzico",
    paymentId: "iyzico-payment-amount",
    amount: 10,
    currency: "TRY",
  });
  assert.equal(corrected.status, "committed");
});

requireEmulator("payment currency mismatch is manual review", async () => {
  const line = identity("currency-mismatch");
  await seedReservedLine(line);
  const mismatch = await commitVerifiedMarketplaceInventory({
    db,
    orderId: line.rootOrderId,
    provider: "iyzico",
    paymentId: "iyzico-payment-currency",
    amount: 10,
    currency: "USD",
  });
  assert.equal(mismatch.status, "manual_review");
  const product = await db.collection("businesses").doc(line.businessId).collection("products").doc(line.productId).get();
  assert.equal(product.data().stock, 1);
  assert.equal(product.data().reservedStock, 1);
});

for (const [name, mutateEvidence] of [
  ["corrupted movement evidence", async (line) => {
    const snapshot = await db.collection("inventoryMovements").get();
    const movement = snapshot.docs.find((doc) =>
      doc.data().lineId === line.lineId && doc.data().operationType === "commit"
    );
    await movement.ref.set({ quantity: 99 }, { merge: true });
  }],
  ["corrupted event evidence", async (line) => {
    const snapshot = await db.collection("inventoryEvents").get();
    const event = snapshot.docs.find((doc) =>
      doc.data().aggregate?.rootOrderId === line.rootOrderId &&
      doc.data().eventName === "InventoryCommitted"
    );
    await event.ref.set({ operationId: "wrong-operation" }, { merge: true });
  }],
  ["unsupported reservation version", async (line) => {
    await reservationRef(db, line).set({ reservationSchemaVersion: 999 }, { merge: true });
  }],
]) {
  requireEmulator(`manual review is preserved for ${name}`, async () => {
    const line = identity(`manual-${name.replace(/\s+/g, "-")}`);
    await seedReservedLine(line);
    if (name.includes("evidence")) {
      const committed = await commitVerifiedMarketplaceInventory({
        db,
        orderId: line.rootOrderId,
        provider: "iyzico",
        paymentId: `manual-payment-${name}`,
        amount: 10,
        currency: "TRY",
      });
      assert.equal(committed.status, "committed");
    }
    await mutateEvidence(line);
    const result = await commitVerifiedMarketplaceInventory({
      db,
      orderId: line.rootOrderId,
      provider: "iyzico",
      paymentId: `manual-payment-${name}`,
      amount: 10,
      currency: "TRY",
    });
    assert.equal(result.status, "manual_review");
    const root = await db.collection("orders").doc(line.rootOrderId).get();
    assert.equal(root.data().inventoryStatus, "manual_review");
    assert.equal(root.data().financeEligibility, "blocked");
    const retry = await commitVerifiedMarketplaceInventory({
      db,
      orderId: line.rootOrderId,
      provider: "iyzico",
      paymentId: `manual-payment-${name}`,
      amount: 10,
      currency: "TRY",
    });
    assert.equal(retry.status, "manual_review");
  });
}

for (const [name, mutate] of [
  ["missing line", (lines) => lines.slice(0, 0)],
  ["duplicate line", (lines) => [...lines, lines[0]]],
  ["extra line", (lines) => [...lines, { ...lines[0], lineId: `${lines[0].lineId}-extra` }]],
  ["corrupted quantity", (lines) => lines.map((line) => ({ ...line, quantity: 2 }))],
  ["corrupted product", (lines) => lines.map((line) => ({ ...line, productId: `${line.productId}-wrong` }))],
  ["corrupted seller order", (lines) => lines.map((line) => ({ ...line, sellerOrderId: `${line.sellerOrderId}-wrong` }))],
  ["corrupted line id", (lines) => lines.map((line) => ({ ...line, lineId: `${line.lineId}-wrong` }))],
]) {
  requireEmulator(`canonical line validation rejects ${name}`, async () => {
    const line = identity(`line-${name.replace(/\s+/g, "-")}`);
    await seedReservedLine(line);
    const sellerRef = db.collection("sellerOrders").doc(line.sellerOrderId);
    const sellerSnap = await sellerRef.get();
    await sellerRef.set({ inventoryLines: mutate(sellerSnap.data().inventoryLines) }, { merge: true });
    const result = await commitVerifiedMarketplaceInventory({
      db,
      orderId: line.rootOrderId,
      provider: "isbank",
      paymentId: `isbank-payment-${name}`,
      amount: 10,
      currency: "TRY",
    });
    assert.equal(result.status, "manual_review");
    const product = await db.collection("businesses").doc(line.businessId).collection("products").doc(line.productId).get();
    assert.equal(product.data().stock, 1);
    assert.equal(product.data().reservedStock, 1);
  });
}

requireEmulator("callback claims bind amount, currency, payment identity and event history", async () => {
  const first = await claimPaymentCallback({
    db,
    provider: "isbank",
    orderId: "m4-claim-evidence",
    paymentId: "payment-a",
    providerEventId: "event-a",
    amount: 10,
    currency: "TRY",
  });
  const duplicate = await claimPaymentCallback({
    db,
    provider: "isbank",
    orderId: "m4-claim-evidence",
    paymentId: "payment-a",
    providerEventId: "event-b",
    amount: 10,
    currency: "TRY",
  });
  assert.equal(duplicate.status, "processing");
  await completePaymentCallback({
    ref: first.ref,
    ownerToken: first.ownerToken,
    result: { status: "committed" },
  });
  const differentPayment = await assert.rejects(
    () => claimPaymentCallback({
      db,
      provider: "isbank",
      orderId: "m4-claim-evidence",
      paymentId: "payment-b",
      providerEventId: "event-c",
      amount: 10,
      currency: "TRY",
    }),
    (errorValue) => errorValue.code === "payment_identity_conflict"
  );
  assert.equal(differentPayment, undefined);
  const conflicts = await db.collection("paymentIdentityConflicts").get();
  assert.equal(conflicts.size, 1);
  assert.equal(conflicts.docs[0].data().originalPaymentId, "payment-a");
  assert.equal(conflicts.docs[0].data().conflictingPaymentId, "payment-b");
  assert.equal(conflicts.docs[0].data().status, "manual_review");
  assert.ok(conflicts.docs[0].data().operationId);
  const repeatedConflict = await assert.rejects(
    () => claimPaymentCallback({
      db,
      provider: "isbank",
      orderId: "m4-claim-evidence",
      paymentId: "payment-b",
      providerEventId: "event-c",
      amount: 10,
      currency: "TRY",
    }),
    (errorValue) => errorValue.code === "payment_identity_conflict"
  );
  assert.equal(repeatedConflict, undefined);
  assert.equal((await db.collection("paymentIdentityConflicts").get()).size, 1);
  const claimSnap = await first.ref.get();
  assert.deepEqual(claimSnap.data().providerEventIds.sort(), ["event-a", "event-b"]);
});
