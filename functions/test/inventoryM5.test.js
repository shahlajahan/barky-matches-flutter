"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { canonicalLineIdentity } = require("../src/inventory/inventoryIdentity");
const { reserveInventory } = require("../src/inventory/inventoryTransactions");
const {
  releaseMarketplaceInventory,
  m5FeatureEnabled,
} = require("../src/inventory/inventoryReleaseCoordinator");
const {
  processExpiredInventoryReservations,
} = require("../src/inventory/inventoryExpiryScheduler");

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = "demo-petsupo-inventory";
if (emulatorAvailable && !admin.apps.length) admin.initializeApp({ projectId });
const db = emulatorAvailable ? admin.firestore() : null;
let sequence = 0;

function requireEmulator(name, fn) {
  return test(name, { skip: !emulatorAvailable }, fn);
}

function line() {
  sequence += 1;
  return canonicalLineIdentity({
    rootOrderId: `m5-order-${sequence}`,
    sellerOrderId: `m5-seller-${sequence}`,
    lineId: `m5-line-${sequence}`,
    businessId: `m5-business-${sequence}`,
    productId: `m5-product-${sequence}`,
  });
}

async function seedManagedLine(identity, { stock = 2, expiresAt } = {}) {
  const canonical = {
    ...identity,
    quantity: 1,
    unitPrice: 10,
    totalPrice: 10,
    currency: "TRY",
  };
  await db.collection("businesses").doc(identity.businessId)
    .collection("products").doc(identity.productId)
    .set({ stock, inventorySchemaVersion: 1 });
  await db.collection("orders").doc(identity.rootOrderId).set({
    buyerUid: "m5-buyer",
    sellerOrderIds: [identity.sellerOrderId],
    inventorySchemaVersion: 1,
    inventoryOperationVersion: 1,
    inventoryStatus: "not_started",
    financeEligibility: "blocked",
    providerPaymentStatus: "pending",
    pricing: { grandTotal: 10, currency: "TRY" },
    inventoryLineSet: [canonical],
  });
  await db.collection("sellerOrders").doc(identity.sellerOrderId).set({
    rootOrderId: identity.rootOrderId,
    sellerOrderId: identity.sellerOrderId,
    businessId: identity.businessId,
    inventorySchemaVersion: 1,
    inventoryOperationVersion: 1,
    inventoryStatus: "not_started",
    financeEligibility: "blocked",
    inventoryLines: [{ ...canonical, inventoryStatus: "not_started" }],
  });
  return canonical;
}

function enableReleaseFlag() {
  process.env.INVENTORY_FAILURE_RELEASE_ENABLED = "true";
  process.env.M5_CANARY_BUYERS = "m5-buyer";
}

requireEmulator("M5 releases all active reservations and is idempotent", async () => {
  enableReleaseFlag();
  const identity = line();
  await seedManagedLine(identity);
  await reserveInventory({ db, identity, quantity: 1 });
  const first = await releaseMarketplaceInventory({
    db,
    orderId: identity.rootOrderId,
    reason: "payment_failure",
    buyerUid: "m5-buyer",
  });
  const second = await releaseMarketplaceInventory({
    db,
    orderId: identity.rootOrderId,
    reason: "payment_failure",
    buyerUid: "m5-buyer",
  });
  assert.equal(first.status, "released");
  assert.equal(second.status, "released");
  const product = (await db.collection("businesses").doc(identity.businessId)
    .collection("products").doc(identity.productId).get()).data();
  assert.equal(product.reservedStock, 0);
});

requireEmulator("M5 never releases verified success", async () => {
  enableReleaseFlag();
  const identity = line();
  await seedManagedLine(identity);
  await reserveInventory({ db, identity, quantity: 1 });
  await db.collection("orders").doc(identity.rootOrderId).update({
    providerPaymentStatus: "verified_success",
  });
  const result = await releaseMarketplaceInventory({
    db,
    orderId: identity.rootOrderId,
    reason: "late_failure",
    buyerUid: "m5-buyer",
  });
  assert.equal(result.status, "manual_review");
  const product = (await db.collection("businesses").doc(identity.businessId)
    .collection("products").doc(identity.productId).get()).data();
  assert.equal(product.reservedStock, 1);
});

requireEmulator("M5 expiry worker remains dormant unless explicitly enabled", async () => {
  delete process.env.INVENTORY_EXPIRY_SCHEDULER_ENABLED;
  delete process.env.INVENTORY_M5_SCHEDULER_CANARY;
  const result = await processExpiredInventoryReservations({ db });
  assert.equal(result.status, "disabled");
});

test("M5 feature flags are disabled without a canary allow-list", () => {
  process.env.INVENTORY_FAILURE_RELEASE_ENABLED = "true";
  delete process.env.M5_CANARY_BUYERS;
  delete process.env.M5_CANARY_BUSINESSES;
  assert.equal(m5FeatureEnabled("failure_release", { buyerUid: "m5-buyer" }), false);
});
