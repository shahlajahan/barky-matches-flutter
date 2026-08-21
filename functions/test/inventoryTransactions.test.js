"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {
  applyStockAdjustment,
  commitInventory,
  expireAndReleaseInventory,
  releaseInventory,
  reserveInventory,
  restoreReturnedInventory,
  validateTransientLease,
} = require("../src/inventory/inventoryTransactions");
const {
  buildMovementId,
  buildOperationId,
  buildReservationId,
  canonicalLineIdentity,
} = require("../src/inventory/inventoryIdentity");

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = "demo-petsupo-inventory";

if (emulatorAvailable && !admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = emulatorAvailable ? admin.firestore() : null;
let sequence = 0;

function identity(label = "line") {
  sequence += 1;
  return canonicalLineIdentity({
    rootOrderId: `order-${label}-${sequence}`,
    sellerOrderId: `seller-${label}-${sequence}`,
    lineId: `line-${label}-${sequence}`,
    businessId: `business-${label}-${sequence}`,
    productId: `product-${label}-${sequence}`,
  });
}

async function seedLine(line, { stock = 2, paymentId = "payment-1", version, lineQuantity = 1 } = {}) {
  const productRef = db
    .collection("businesses")
    .doc(line.businessId)
    .collection("products")
    .doc(line.productId);
  await productRef.set({
    stock,
    ...(version == null ? {} : { inventorySchemaVersion: version }),
  });
  await db.collection("orders").doc(line.rootOrderId).set({
    paymentState: "verified_success",
    paymentProvider: "isbank",
    paymentId,
    sellerOrderIds: [line.sellerOrderId],
  });
  await db.collection("sellerOrders").doc(line.sellerOrderId).set({
    rootOrderId: line.rootOrderId,
    businessId: line.businessId,
    inventoryLines: [{
      lineId: line.lineId,
      businessId: line.businessId,
      productId: line.productId,
      quantity: lineQuantity,
    }],
    payment: {
      state: "verified_success",
      provider: "isbank",
      paymentId,
    },
  });
  return productRef;
}

function futureLease(now = Date.now()) {
  return admin.firestore.Timestamp.fromMillis(now + 60 * 60 * 1000);
}

function pastTimestamp(now = Date.now()) {
  return admin.firestore.Timestamp.fromMillis(now - 60 * 60 * 1000);
}

async function seedReturn(line, returnId, {
  quantity = 1,
  physicallyReceived = true,
  restockable = true,
} = {}) {
  await db.collection("order_returns").doc(returnId).set({
    returnId,
    rootOrderId: line.rootOrderId,
    sellerOrderId: line.sellerOrderId,
    businessId: line.businessId,
    status: physicallyReceived ? "received" : "approved",
    returnItems: [{
      lineId: line.lineId,
      businessId: line.businessId,
      productId: line.productId,
      quantity,
      physicallyReceived,
      restockable,
    }],
  });
}

function requireEmulator(name, fn) {
  return test(name, { skip: !emulatorAvailable }, fn);
}

requireEmulator("only one of two concurrent reservations succeeds", async () => {
  const lineA = identity("race-a");
  const lineB = identity("race-b");
  const productRef = await seedLine(lineA, { stock: 1 });
  await db
    .collection("businesses")
    .doc(lineB.businessId)
    .collection("products")
    .doc(lineB.productId)
    .delete();
  // Both lines intentionally target the same authoritative product.
  const shared = { ...lineB, businessId: lineA.businessId, productId: lineA.productId };
  const results = await Promise.allSettled([
    reserveInventory({ identity: lineA, quantity: 1, leaseExpiresAt: futureLease() }),
    reserveInventory({ identity: shared, quantity: 1, leaseExpiresAt: futureLease() }),
  ]);
  assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
  assert.equal(results.filter((result) => result.status === "rejected").length, 1);
  const product = (await productRef.get()).data();
  assert.equal(product.stock, 1);
  assert.equal(product.reservedStock, 1);
});

// Marketplace product compliance audit, P0 gap review (docs/audits/
// marketplace_add_product_compliance_audit_2026-08-20.md, item 3): the
// two-attempt race above proves the general mechanism, but does not by
// itself demonstrate the contract at a wider fan-out. This test issues
// 5 concurrent reservation attempts (1 unit each) against a product with
// stock=2 and explicitly asserts the inventory invariant that must hold
// after every settle, however many attempts race: available
// (stock - reservedStock) is never negative, exactly `stock` worth of
// attempts succeed, and every remaining attempt is rejected with
// insufficient_stock rather than silently overselling.
requireEmulator(
  "available stock cannot go negative under 5-way concurrent reservation",
  async () => {
    const seed = identity("fanout-race-seed");
    const productRef = await seedLine(seed, { stock: 2 });
    const attempts = Array.from({ length: 5 }, (_, i) =>
      identity(`fanout-race-${i}`)
    ).map((line) => ({
      ...line,
      businessId: seed.businessId,
      productId: seed.productId,
    }));
    for (const line of attempts) {
      await db.collection("orders").doc(line.rootOrderId).set({
        paymentState: "verified_success",
        paymentProvider: "isbank",
        paymentId: `payment-${line.rootOrderId}`,
        sellerOrderIds: [line.sellerOrderId],
      });
      await db.collection("sellerOrders").doc(line.sellerOrderId).set({
        rootOrderId: line.rootOrderId,
        businessId: line.businessId,
        inventoryLines: [
          {
            lineId: line.lineId,
            businessId: line.businessId,
            productId: line.productId,
            quantity: 1,
          },
        ],
        payment: {
          state: "verified_success",
          provider: "isbank",
          paymentId: `payment-${line.rootOrderId}`,
        },
      });
    }

    const results = await Promise.allSettled(
      attempts.map((line) =>
        reserveInventory({
          identity: line,
          quantity: 1,
          leaseExpiresAt: futureLease(),
        })
      )
    );

    const succeeded = results.filter((r) => r.status === "fulfilled");
    const rejected = results.filter((r) => r.status === "rejected");
    assert.equal(
      succeeded.length,
      2,
      "exactly `stock` reservations must succeed, never more"
    );
    assert.equal(rejected.length, 3);
    for (const failure of rejected) {
      assert.equal(failure.reason.code, "insufficient_stock");
    }

    const product = (await productRef.get()).data();
    assert.equal(product.stock, 2, "stock is untouched by reservation alone");
    assert.equal(product.reservedStock, 2);
    assert.ok(
      product.stock - product.reservedStock >= 0,
      "available stock (stock - reservedStock) must never go negative"
    );
  }
);

requireEmulator("duplicate reserve changes reservedStock once", async () => {
  const line = identity("duplicate-reserve");
  const productRef = await seedLine(line, { stock: 3, lineQuantity: 2 });
  const options = { identity: line, quantity: 2, leaseExpiresAt: futureLease() };
  const first = await reserveInventory(options);
  const second = await reserveInventory(options);
  assert.equal(first.status, "reserved");
  assert.equal(second.status, "already_reserved");
  assert.equal((await productRef.get()).data().reservedStock, 2);
  const event = (await db.collection("inventoryEvents").doc(first.eventId).get()).data();
  assert.equal(event.eventName, "InventoryReserved");
  assert.equal(event.eventVersion, 1);
  assert.equal(event.schemaVersion, 1);
  assert.equal(event.producerVersion, "inventory-m1-m2-v1");
  assert.equal(event.status, "pending");
  assert.equal(event.retryCount, 0);
  assert.equal(event.aggregate.lineId, line.lineId);
});

requireEmulator("rejects a non-canonical caller-supplied operation id", async () => {
  const line = identity("operation-id");
  await seedLine(line, { stock: 1 });
  await assert.rejects(
    reserveInventory({
      identity: line,
      quantity: 1,
      operationId: "reused-operation-id",
      leaseExpiresAt: futureLease(),
    }),
    (error) => error.code === "operation_identity_conflict" && error.manualReview === true
  );
});

requireEmulator("partial evidence is never accepted as an idempotent result", async () => {
  const line = identity("partial-evidence");
  await seedLine(line, { stock: 1 });
  const first = await reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() });
  await db.collection("inventoryEvents").doc(first.eventId).delete();
  await assert.rejects(
    reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() }),
    (error) => error.code === "operation_evidence_conflict" && error.manualReview === true
  );
});

requireEmulator("mismatched evidence identity and quantity require manual review", async () => {
  const line = identity("mismatched-evidence");
  await seedLine(line, { stock: 2 });
  const first = await reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() });
  await db.collection("inventoryMovements").doc(first.movementId).update({ quantity: 2 });
  await assert.rejects(
    reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() }),
    (error) => error.code === "operation_evidence_conflict" && error.manualReview === true
  );
});

requireEmulator("canonical order and seller line are required before reservation", async () => {
  const line = identity("canonical-docs");
  const productRef = await seedLine(line, { stock: 1 });
  await db.collection("sellerOrders").doc(line.sellerOrderId).delete();
  await assert.rejects(
    reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() }),
    (error) => error.code === "seller_order_not_found" && error.manualReview === true
  );
  assert.equal((await productRef.get()).data().reservedStock, undefined);
});

requireEmulator("canonical seller line identity cannot be substituted", async () => {
  const line = identity("canonical-line-mismatch");
  const productRef = await seedLine(line, { stock: 1 });
  await db.collection("sellerOrders").doc(line.sellerOrderId).update({
    inventoryLines: [{
      lineId: "different-line",
      businessId: line.businessId,
      productId: line.productId,
      quantity: 1,
    }],
  });
  await assert.rejects(
    reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() }),
    (error) => error.code === "seller_order_line_not_found" && error.manualReview === true
  );
  assert.equal((await productRef.get()).data().reservedStock, undefined);
});

requireEmulator("duplicate commit changes stock once", async () => {
  const line = identity("duplicate-commit");
  const productRef = await seedLine(line, { stock: 2, paymentId: "payment-commit" });
  await reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() });
  const payment = {
    state: "verified_success",
    provider: "isbank",
    paymentId: "payment-commit",
  };
  const first = await commitInventory({ identity: line, payment });
  const second = await commitInventory({ identity: line, payment });
  assert.equal(first.status, "committed");
  assert.equal(second.status, "already_committed");
  assert.deepEqual((await productRef.get()).data(), {
    stock: 1,
    reservedStock: 0,
    inventorySchemaVersion: 1,
    inventoryOperationVersion: 1,
    inventoryUpdatedAt: (await productRef.get()).data().inventoryUpdatedAt,
  });
});

requireEmulator("duplicate release changes reservedStock once", async () => {
  const line = identity("duplicate-release");
  const productRef = await seedLine(line, { stock: 2 });
  await reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() });
  const first = await releaseInventory({ identity: line, reason: "cancelled" });
  const second = await releaseInventory({ identity: line, reason: "cancelled" });
  assert.equal(first.status, "released");
  assert.match(second.status, /already_released|already_expired/);
  assert.equal((await productRef.get()).data().reservedStock, 0);
});

requireEmulator("commit versus release race has one terminal stock effect", async () => {
  const line = identity("commit-release-race");
  const productRef = await seedLine(line, { stock: 1, paymentId: "payment-race" });
  await reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() });
  const [commitResult, releaseResult] = await Promise.allSettled([
    commitInventory({
      identity: line,
      payment: { state: "verified_success", provider: "isbank", paymentId: "payment-race" },
    }),
    releaseInventory({ identity: line, reason: "cancelled" }),
  ]);
  const successful = [commitResult, releaseResult]
    .filter((result) => result.status === "fulfilled")
    .map((result) => result.value.status);
  assert.ok(successful.includes("committed") || successful.includes("released"));
  assert.ok(
    successful.every((status) =>
      ["committed", "released", "already_committed", "already_released"].includes(status)
    )
  );
  const product = (await productRef.get()).data();
  assert.equal(product.reservedStock, 0);
  assert.ok(product.stock === 0 || product.stock === 1);
});

requireEmulator("expiry releases reserved stock in the same transaction", async () => {
  const line = identity("expiry");
  const productRef = await seedLine(line, { stock: 1 });
  const now = admin.firestore.Timestamp.fromMillis(1000000);
  const expiry = admin.firestore.Timestamp.fromMillis(1100000);
  await reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: expiry, now });
  const result = await expireAndReleaseInventory({ identity: line, now: admin.firestore.Timestamp.fromMillis(1200000) });
  assert.equal(result.status, "expired");
  const reservation = (await db.collection("inventoryReservations").doc(buildReservationId(line)).get()).data();
  assert.equal(reservation.status, "expired");
  assert.equal((await productRef.get()).data().reservedStock, 0);
});

test("live lease cannot be stolen and stale lease can be reclaimed", () => {
  assert.throws(
    () =>
      validateTransientLease({
        status: "reserving",
        startedAt: admin.firestore.Timestamp.fromMillis(500),
        leaseExpiresAt: admin.firestore.Timestamp.fromMillis(2000),
        now: admin.firestore.Timestamp.fromMillis(1000),
        operationId: "op-1",
        currentOperationId: "op-1",
      }),
    (error) => error.code === "lease_active"
  );
  assert.deepEqual(
    validateTransientLease({
      status: "reserving",
      startedAt: admin.firestore.Timestamp.fromMillis(500),
      leaseExpiresAt: admin.firestore.Timestamp.fromMillis(1000),
      now: admin.firestore.Timestamp.fromMillis(2000),
      operationId: "op-1",
      currentOperationId: "op-1",
    }),
    { reclaimable: true, status: "reserving", operationId: "op-1", nextAttempt: 2 }
  );
});

requireEmulator("stock mutations cannot make stock less than reservedStock", async () => {
  const line = identity("invariant");
  const productRef = await seedLine(line, { stock: 2 });
  await reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() });
  await assert.rejects(
    applyStockAdjustment({
      identity: line,
      adjustmentId: "bad-decrease",
      delta: -2,
      actor: "admin-1",
      reason: "count correction",
      sourceEvidence: "count-sheet-1",
    }),
    (error) => error.code === "inventory_invariant_violation" && error.manualReview === true
  );
  assert.equal((await productRef.get()).data().stock, 2);
});

requireEmulator("concurrent partial returns cannot over-restore", async () => {
  const line = identity("returns");
  const productRef = await seedLine(line, { stock: 2, paymentId: "payment-return", lineQuantity: 2 });
  await reserveInventory({ identity: line, quantity: 2, leaseExpiresAt: futureLease() });
  await commitInventory({
    identity: line,
    payment: { state: "verified_success", provider: "isbank", paymentId: "payment-return" },
  });
  await seedReturn(line, "return-a", { quantity: 2 });
  await seedReturn(line, "return-b", { quantity: 2 });
  const results = await Promise.allSettled([
    restoreReturnedInventory({ identity: line, returnId: "return-a", quantity: 2 }),
    restoreReturnedInventory({ identity: line, returnId: "return-b", quantity: 2 }),
  ]);
  assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
  assert.equal((await productRef.get()).data().stock, 2);
  const reservation = (await db.collection("inventoryReservations").doc(buildReservationId(line)).get()).data();
  assert.equal(reservation.restoredQuantity, 2);
});

requireEmulator("non-restockable quantity cannot later be restocked", async () => {
  const line = identity("processed-return");
  const productRef = await seedLine(line, { stock: 1, paymentId: "payment-processed", lineQuantity: 1 });
  await reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() });
  await commitInventory({
    identity: line,
    payment: { state: "verified_success", provider: "isbank", paymentId: "payment-processed" },
  });
  await seedReturn(line, "return-damaged-processed", { quantity: 1, restockable: false });
  await restoreReturnedInventory({ identity: line, returnId: "return-damaged-processed", quantity: 1 });
  await seedReturn(line, "return-restock-after-damage", { quantity: 1, restockable: true });
  await assert.rejects(
    restoreReturnedInventory({ identity: line, returnId: "return-restock-after-damage", quantity: 1 }),
    (error) => error.code === "return_quantity_exceeded" && error.manualReview === true
  );
  assert.equal((await productRef.get()).data().stock, 0);
});

requireEmulator("stale committing and releasing leases advance attempts", async () => {
  const reserveLine = identity("stale-reserve");
  await seedLine(reserveLine, { stock: 1 });
  const reserveOperation = buildOperationId(reserveLine, "reserve");
  await db.collection("inventoryReservations").doc(buildReservationId(reserveLine)).set({
    rootOrderId: reserveLine.rootOrderId,
    orderId: reserveLine.rootOrderId,
    sellerOrderId: reserveLine.sellerOrderId,
    lineId: reserveLine.lineId,
    businessId: reserveLine.businessId,
    productId: reserveLine.productId,
    quantity: 1,
    status: "reserving",
    reservationSchemaVersion: 1,
    operationVersion: 1,
    lastOperationId: reserveOperation,
    startedAt: pastTimestamp(),
    leaseExpiresAt: pastTimestamp(),
    expiresAt: pastTimestamp(),
    attempt: 2,
  });
  const reserved = await reserveInventory({ identity: reserveLine, quantity: 1, leaseExpiresAt: futureLease() });
  assert.equal(reserved.status, "reserved");
  assert.equal(
    (await db.collection("inventoryReservations").doc(buildReservationId(reserveLine)).get()).data().attempt,
    3
  );

  const commitLine = identity("stale-commit");
  await seedLine(commitLine, { stock: 1, paymentId: "payment-stale-commit" });
  await reserveInventory({ identity: commitLine, quantity: 1, leaseExpiresAt: futureLease() });
  const commitOperation = buildOperationId(commitLine, "commit");
  await db.collection("inventoryReservations").doc(buildReservationId(commitLine)).update({
    status: "reserved",
    inventoryCommitState: "committing",
    lastOperationId: commitOperation,
    leaseExpiresAt: pastTimestamp(),
    attempt: 1,
  });
  const committed = await commitInventory({
    identity: commitLine,
    payment: { state: "verified_success", provider: "isbank", paymentId: "payment-stale-commit" },
  });
  assert.equal(committed.status, "committed");
  assert.equal(
    (await db.collection("inventoryReservations").doc(buildReservationId(commitLine)).get()).data().attempt,
    2
  );

  const releaseLine = identity("stale-release");
  await seedLine(releaseLine, { stock: 1 });
  await reserveInventory({ identity: releaseLine, quantity: 1, leaseExpiresAt: futureLease() });
  const releaseOperation = buildOperationId(releaseLine, "release");
  await db.collection("inventoryReservations").doc(buildReservationId(releaseLine)).update({
    status: "releasing",
    lastOperationId: releaseOperation,
    leaseExpiresAt: pastTimestamp(),
    attempt: 3,
  });
  const released = await releaseInventory({ identity: releaseLine });
  assert.equal(released.status, "released");
  assert.equal(
    (await db.collection("inventoryReservations").doc(buildReservationId(releaseLine)).get()).data().attempt,
    4
  );
});

requireEmulator("durable reservation movement and event versions are validated", async () => {
  const cases = [
    ["reservationSchemaVersion", "inventoryReservations", "reservation"],
    ["movementSchemaVersion", "inventoryMovements", "movement"],
    ["eventVersion", "inventoryEvents", "event"],
    ["schemaVersion", "inventoryEvents", "event"],
    ["producerVersion", "inventoryEvents", "event"],
  ];
  for (const [field, collection, kind] of cases) {
    const line = identity(`version-${field}`);
    await seedLine(line, { stock: 1 });
    const reserved = await reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() });
    const ref = kind === "reservation"
      ? db.collection(collection).doc(buildReservationId(line))
      : db.collection(collection).doc(kind === "movement" ? reserved.movementId : reserved.eventId);
    await ref.update({ [field]: field === "producerVersion" ? "future-producer" : 99 });
    const operation = kind === "reservation"
      ? releaseInventory({ identity: line })
      : reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() });
    await assert.rejects(
      operation,
      (error) => ["unsupported_version", "missing_version"].includes(error.code) && error.manualReview === true
    );
  }
});

requireEmulator("non-restockable return does not change stock", async () => {
  const line = identity("damaged-return");
  const productRef = await seedLine(line, { stock: 1, paymentId: "payment-damaged", lineQuantity: 1 });
  await reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() });
  await commitInventory({
    identity: line,
    payment: { state: "verified_success", provider: "isbank", paymentId: "payment-damaged" },
  });
  await seedReturn(line, "return-damaged", { quantity: 1, restockable: false });
  const result = await restoreReturnedInventory({
    identity: line,
    returnId: "return-damaged",
    quantity: 1,
  });
  assert.equal(result.status, "not_restored");
  const product = (await productRef.get()).data();
  assert.equal(product.stock, 0);
  const reservation = (await db.collection("inventoryReservations").doc(buildReservationId(line)).get()).data();
  assert.equal(reservation.restoredQuantity, 0);
});

requireEmulator("refund-only state does not change inventory", async () => {
  const line = identity("refund-only");
  const productRef = await seedLine(line, { stock: 1 });
  await seedReturn(line, "refund-only", { quantity: 1, physicallyReceived: false });
  await assert.rejects(
    restoreReturnedInventory({
      identity: line,
      returnId: "refund-only",
      quantity: 1,
    }),
    (error) => error.code === "return_line_not_found"
  );
  assert.equal((await productRef.get()).data().stock, 1);
});

requireEmulator("duplicate stock adjustment is a no-op", async () => {
  const line = identity("adjustment");
  const productRef = await seedLine(line, { stock: 1 });
  const options = {
    identity: line,
    adjustmentId: "adjust-1",
    delta: 2,
    actor: "admin-1",
    reason: "supplier correction",
    sourceEvidence: "supplier-note-1",
  };
  const first = await applyStockAdjustment(options);
  const second = await applyStockAdjustment(options);
  assert.equal(first.status, "adjusted");
  assert.equal(second.status, "already_adjusted");
  assert.equal((await productRef.get()).data().stock, 3);
});

requireEmulator("unsupported schema returns safe manual-review error", async () => {
  const line = identity("version");
  const productRef = await seedLine(line, { stock: 1, version: 99 });
  await assert.rejects(
    reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() }),
    (error) => error.code === "unsupported_version" && error.manualReview === true
  );
  assert.equal((await productRef.get()).data().reservedStock, undefined);
});

test("deterministic identities include every canonical line component", () => {
  const line = canonicalLineIdentity({
    orderId: "order-1",
    sellerOrderId: "seller-1",
    lineId: "line-1",
    businessId: "business-1",
    productId: "product-1",
  });
  const operation = buildOperationId(line, "reserve");
  const reservation = buildReservationId(line);
  const movement = buildMovementId(line, operation);
  for (const value of [operation, reservation, movement]) {
    for (const component of Object.values(line)) assert.ok(value.includes(component));
  }
});

requireEmulator("transaction retry remains idempotent for concurrent duplicate commits", async () => {
  const line = identity("retry");
  const productRef = await seedLine(line, { stock: 1, paymentId: "payment-retry" });
  await reserveInventory({ identity: line, quantity: 1, leaseExpiresAt: futureLease() });
  const payment = { state: "verified_success", provider: "isbank", paymentId: "payment-retry" };
  const results = await Promise.allSettled([
    commitInventory({ identity: line, payment }),
    commitInventory({ identity: line, payment }),
  ]);
  assert.equal(results.filter((result) => result.status === "fulfilled").length, 2);
  assert.equal((await productRef.get()).data().stock, 0);
  assert.equal((await productRef.get()).data().reservedStock, 0);
});
