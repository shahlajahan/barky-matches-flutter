"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {
  buildCanonicalLines,
  buildCheckoutResponse,
  buildM3OrderIds,
  claimCheckoutAttempt,
  coordinateCheckoutReservations,
  checkoutFingerprint,
  initialM3LegacyPaymentState,
  resumeCheckoutCompensation,
  resumeCheckoutAttempt,
  updateAttempt,
  validateExistingCheckoutTree,
} = require("../src/inventory/inventoryCheckoutCoordinator");

const emulatorAvailable = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const projectId = "demo-petsupo-m3";
if (emulatorAvailable && !admin.apps.length) admin.initializeApp({ projectId });
const db = emulatorAvailable ? admin.firestore() : null;
let sequence = 0;

function requireEmulator(name, fn) {
  return test(name, { skip: !emulatorAvailable }, fn);
}

function attemptId(label) {
  sequence += 1;
  return `attempt-${label}-${sequence}`;
}

test("M3 resume responses use the original checkout contract", () => {
  assert.deepEqual(
    buildCheckoutResponse({
      rootOrderId: "root-1",
      orderNumber: "BM-2026-000001",
      sellerOrderIds: ["seller-1"],
    }),
    {
      ok: true,
      orderId: "root-1",
      orderNumber: "BM-2026-000001",
      sellerOrderIds: ["seller-1"],
      sellerCount: 1,
      inventoryStatus: "reserved",
    }
  );
});

test("legacy reserved claim results are normalized on resume", async () => {
  const response = await resumeCheckoutAttempt({
    claim: {
      status: "already_reserved",
      rootOrderId: "root-legacy",
      orderNumber: "BM-2026-000002",
      result: { status: "reserved", rootOrderId: "root-legacy" },
    },
    sellerOrderIds: ["seller-legacy"],
    orderNumber: "BM-2026-000002",
  });
  assert.equal(response.ok, true);
  assert.equal(response.orderId, "root-legacy");
  assert.equal(response.orderNumber, "BM-2026-000002");
  assert.equal(response.sellerCount, 1);
});

test("M3 ignores a client supplied paid state before verification", () => {
  assert.deepEqual(
    initialM3LegacyPaymentState({ m3Enabled: true, paymentStatus: "paid" }),
    { orderStatus: "pending_payment", paymentStatus: "pending" }
  );
  assert.deepEqual(
    initialM3LegacyPaymentState({ m3Enabled: false, paymentStatus: "paid" }),
    { orderStatus: "paid", paymentStatus: "paid" }
  );
});

test("resume validation rejects an incomplete canonical order tree", () => {
  const line = {
    rootOrderId: "root-1",
    sellerOrderId: "seller-1",
    lineId: "line-1",
    businessId: "business-1",
    productId: "product-1",
    quantity: 1,
  };
  const snapshot = (id, exists, data) => ({ id, exists, data: () => data });
  assert.throws(
    () => validateExistingCheckoutTree({
      rootSnapshot: snapshot("root-1", true, { sellerOrderIds: ["seller-1"] }),
      sellerOrderSnapshots: new Map([
        ["seller-1", snapshot("seller-1", true, { rootOrderId: "root-1", inventoryLines: [] })],
      ]),
      expectedSellerOrderIds: ["seller-1"],
      expectedLines: [line],
    }),
    (value) => value.code === "canonical_order_tree_incomplete"
  );
});

async function seedOrderTree({ buyerUid, rootOrderId, sellerOrderIds, lines }) {
  const batch = db.batch();
  batch.set(db.collection("orders").doc(rootOrderId), {
    buyerUid,
    sellerOrderIds,
    status: "pending_payment",
  });
  const bySeller = new Map();
  for (const line of lines) {
    const group = bySeller.get(line.sellerOrderId) || [];
    group.push(line);
    bySeller.set(line.sellerOrderId, group);
  }
  for (const [sellerOrderId, sellerLines] of bySeller) {
    batch.set(db.collection("sellerOrders").doc(sellerOrderId), {
      rootOrderId,
      inventoryLines: sellerLines,
      items: sellerLines,
      inventoryStatus: "not_started",
    });
  }
  await batch.commit();
}

async function seedProducts(lines, stocks) {
  const batch = db.batch();
  lines.forEach((line, index) => {
    batch.set(
      db
        .collection("businesses")
        .doc(line.businessId)
        .collection("products")
        .doc(line.productId),
      { stock: stocks[index], reservedStock: 0 }
    );
  });
  await batch.commit();
}

requireEmulator("M3 creates stable canonical identities before reservation", async () => {
  const buyerUid = "buyer-stable";
  const checkoutAttemptId = attemptId("stable");
  const ids = buildM3OrderIds({
    buyerUid,
    checkoutAttemptId,
    businessIds: ["business-stable"],
  });
  const sellerOrderId = ids.sellerOrderIds.get("business-stable");
  const lines = buildCanonicalLines({
    rootOrderId: ids.rootOrderId,
    sellerOrderIds: ids.sellerOrderIds,
    items: [{ businessId: "business-stable", productId: "product-stable", quantity: 1, price: 10 }],
  });
  await seedProducts(lines, [1]);
  await seedOrderTree({ buyerUid, rootOrderId: ids.rootOrderId, sellerOrderIds: [sellerOrderId], lines });

  const claim = await claimCheckoutAttempt({
    db,
    buyerUid,
    checkoutAttemptId,
    cartFingerprint: checkoutFingerprint({ items: lines, currency: "TRY", amount: 10 }),
    amount: 10,
    currency: "TRY",
    rootOrderId: ids.rootOrderId,
  });
  const result = await coordinateCheckoutReservations({
    db,
    attemptRef: claim.ref,
    attemptId: checkoutAttemptId,
    rootOrderId: ids.rootOrderId,
    sellerOrderIds: [sellerOrderId],
    lines: lines.map((line) => ({ ...line, buyerUid })),
  });
  assert.equal(result.status, "reserved");
  assert.ok(lines[0].lineId);
  assert.equal((await db.collection("inventoryReservations").get()).size, 1);
});

requireEmulator("same checkout attempt is leased and cannot create another tree", async () => {
  const buyerUid = "buyer-idempotent";
  const checkoutAttemptId = attemptId("idempotent");
  const rootOrderId = "m3-root-idempotent";
  const first = await claimCheckoutAttempt({
    db,
    buyerUid,
    checkoutAttemptId,
    cartFingerprint: "fingerprint-a",
    amount: 10,
    currency: "TRY",
    rootOrderId,
  });
  const second = await claimCheckoutAttempt({
    db,
    buyerUid,
    checkoutAttemptId,
    cartFingerprint: "fingerprint-a",
    amount: 10,
    currency: "TRY",
    rootOrderId,
  });
  assert.equal(first.rootOrderId, second.rootOrderId);
  assert.equal(second.status, "in_progress");
  await assert.rejects(
    claimCheckoutAttempt({
      db,
      buyerUid,
      checkoutAttemptId,
      cartFingerprint: "fingerprint-b",
      amount: 10,
      currency: "TRY",
      rootOrderId,
    }),
    (error) => error.code === "checkout_attempt_conflict"
  );
});

requireEmulator("multi-line failure compensates earlier reservations", async () => {
  const buyerUid = "buyer-compensation";
  const checkoutAttemptId = attemptId("compensation");
  const ids = buildM3OrderIds({
    buyerUid,
    checkoutAttemptId,
    businessIds: ["business-a", "business-b"],
  });
  const lines = buildCanonicalLines({
    rootOrderId: ids.rootOrderId,
    sellerOrderIds: ids.sellerOrderIds,
    items: [
      { businessId: "business-a", productId: "product-a", quantity: 1, price: 10 },
      { businessId: "business-b", productId: "product-b", quantity: 1, price: 10 },
    ],
  });
  await seedProducts(lines, [1, 0]);
  await seedOrderTree({
    buyerUid,
    rootOrderId: ids.rootOrderId,
    sellerOrderIds: [...ids.sellerOrderIds.values()],
    lines,
  });
  const claim = await claimCheckoutAttempt({
    db,
    buyerUid,
    checkoutAttemptId,
    cartFingerprint: "fingerprint-compensation",
    amount: 20,
    currency: "TRY",
    rootOrderId: ids.rootOrderId,
  });
  await assert.rejects(
    coordinateCheckoutReservations({
      db,
      attemptRef: claim.ref,
      attemptId: checkoutAttemptId,
      rootOrderId: ids.rootOrderId,
      sellerOrderIds: [...ids.sellerOrderIds.values()],
      lines: lines.map((line) => ({ ...line, buyerUid })),
    }),
    (error) => ["insufficient_stock", "inventory_conflict"].includes(error.code)
  );
  const product = await db
    .collection("businesses")
    .doc("business-a")
    .collection("products")
    .doc("product-a")
    .get();
  assert.equal(product.data().reservedStock, 0);
});

requireEmulator("two checkout attempts compete through the coordinator", async () => {
  const sharedBusinessId = "business-race";
  const sharedProductId = "product-race";
  const attempts = ["buyer-race-a", "buyer-race-b"].map((buyerUid) => {
    const checkoutAttemptId = attemptId(buyerUid);
    const ids = buildM3OrderIds({
      buyerUid,
      checkoutAttemptId,
      businessIds: [sharedBusinessId],
    });
    const lines = buildCanonicalLines({
      rootOrderId: ids.rootOrderId,
      sellerOrderIds: ids.sellerOrderIds,
      items: [{ businessId: sharedBusinessId, productId: sharedProductId, quantity: 1, price: 10 }],
    });
    return { buyerUid, checkoutAttemptId, ids, lines };
  });
  await db
    .collection("businesses")
    .doc(sharedBusinessId)
    .collection("products")
    .doc(sharedProductId)
    .set({ stock: 1, reservedStock: 0 });
  for (const attempt of attempts) {
    await seedOrderTree({
      buyerUid: attempt.buyerUid,
      rootOrderId: attempt.ids.rootOrderId,
      sellerOrderIds: [...attempt.ids.sellerOrderIds.values()],
      lines: attempt.lines,
    });
  }
  const claims = await Promise.all(
    attempts.map((attempt) =>
      claimCheckoutAttempt({
        db,
        buyerUid: attempt.buyerUid,
        checkoutAttemptId: attempt.checkoutAttemptId,
        cartFingerprint: attempt.checkoutAttemptId,
        amount: 10,
        currency: "TRY",
        rootOrderId: attempt.ids.rootOrderId,
      })
    )
  );
  const results = await Promise.allSettled(
    attempts.map((attempt, index) =>
      coordinateCheckoutReservations({
        db,
        attemptRef: claims[index].ref,
        rootOrderId: attempt.ids.rootOrderId,
        sellerOrderIds: [...attempt.ids.sellerOrderIds.values()],
        lines: attempt.lines.map((line) => ({ ...line, buyerUid: attempt.buyerUid })),
      })
    )
  );
  assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
  assert.equal(results.filter((result) => result.status === "rejected").length, 1);
  const product = await db
    .collection("businesses")
    .doc(sharedBusinessId)
    .collection("products")
    .doc(sharedProductId)
    .get();
  assert.equal(product.data().reservedStock, 1);
});

requireEmulator("compensation_pending can be retried with the same release operation", async () => {
  const buyerUid = "buyer-compensation-retry";
  const checkoutAttemptId = attemptId("compensation-retry");
  const ids = buildM3OrderIds({ buyerUid, checkoutAttemptId, businessIds: ["business-retry"] });
  const [line] = buildCanonicalLines({
    rootOrderId: ids.rootOrderId,
    sellerOrderIds: ids.sellerOrderIds,
    items: [{ businessId: "business-retry", productId: "product-retry", quantity: 1, price: 10 }],
  });
  const sellerOrderId = ids.sellerOrderIds.get("business-retry");
  await seedProducts([line], [1]);
  await seedOrderTree({ buyerUid, rootOrderId: ids.rootOrderId, sellerOrderIds: [sellerOrderId], lines: [line] });
  const claim = await claimCheckoutAttempt({
    db,
    buyerUid,
    checkoutAttemptId,
    cartFingerprint: "retry-fingerprint",
    amount: 10,
    currency: "TRY",
    rootOrderId: ids.rootOrderId,
  });
  await coordinateCheckoutReservations({
    db,
    attemptRef: claim.ref,
    rootOrderId: ids.rootOrderId,
    sellerOrderIds: [sellerOrderId],
    lines: [{ ...line, buyerUid }],
  });
  await updateAttempt(claim.ref, {
    status: "compensation_pending",
    result: { status: "compensation_pending", reservedLineIds: [line.lineId] },
  });
  await db.collection("businesses").doc(line.businessId).collection("products").doc(line.productId).delete();
  await assert.rejects(
    resumeCheckoutCompensation({
      db,
      claim: { ...claim, status: "compensation_pending", result: { reservedLineIds: [line.lineId] } },
      lines: [{ ...line, buyerUid }],
      sellerOrderIds: [sellerOrderId],
    }),
    (value) => value.code === "compensation_pending"
  );
  await db.collection("businesses").doc(line.businessId).collection("products").doc(line.productId).set({ stock: 1, reservedStock: 1 });
  await assert.rejects(
    resumeCheckoutCompensation({
      db,
      claim: { ...claim, status: "compensation_pending", result: { reservedLineIds: [line.lineId] } },
      lines: [{ ...line, buyerUid }],
      sellerOrderIds: [sellerOrderId],
    }),
    (value) => value.code === "item_unavailable"
  );
  const product = await db.collection("businesses").doc(line.businessId).collection("products").doc(line.productId).get();
  assert.equal(product.data().reservedStock, 0);
  const reservation = await db.collection("inventoryReservations").doc(
    [line.rootOrderId, line.sellerOrderId, line.lineId, line.businessId, line.productId].join("__")
  ).get();
  assert.equal(reservation.data().status, "released");
  const movementCount = (await db.collection("inventoryMovements").get()).size;
  await assert.rejects(
    resumeCheckoutCompensation({
      db,
      claim: { ...claim, status: "compensation_pending", result: { reservedLineIds: [line.lineId] } },
      lines: [{ ...line, buyerUid }],
      sellerOrderIds: [sellerOrderId],
    }),
    (value) => value.code === "item_unavailable"
  );
  assert.equal((await db.collection("inventoryMovements").get()).size, movementCount);
});
