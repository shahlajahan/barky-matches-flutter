"use strict";

// Marketplace Revision 44 §0.42 (Slice 7E) — Rules closure for direct client
// order creation.
//
// These run against the REAL `firestore.rules` through the Rules emulator,
// so what is proven is the deployed security boundary, not a Dart or JS
// approximation of it.
//
// The property: no client-SDK actor — buyer, seller, stranger, unauthenticated
// caller or admin — may create, mutate or delete a canonical Marketplace order
// or a seller order projection. Every legitimate order-creating journey in the
// app already goes through a trusted server callable, whose Admin SDK bypasses
// Rules entirely, so closing this removes an attack surface without removing a
// capability.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  setDoc,
  updateDoc,
  deleteDoc,
  getDoc,
} = require("firebase/firestore");

const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);

const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function rulesTest(name, fn) {
  test(name, { skip: !hasEmulator }, fn);
}

let testEnv = null;
async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: `marketplace-order-rules-${Date.now()}`,
    firestore: { rules },
  });
  return testEnv;
}
test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

/// A well-formed order payload that names the caller as the buyer — the exact
/// shape the old rule accepted.
function orderPayload(overrides = {}) {
  return {
    orderId: "order-1",
    userId: "buyer-1",
    buyerUid: "buyer-1",
    businessId: "biz-1",
    status: "pending",
    paymentStatus: "pending",
    currency: "TRY",
    pricing: { currency: "TRY", subtotal: 100, grandTotal: 100 },
    ...overrides,
  };
}

async function seedServerOrder(id = "order-1", data = {}) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "orders", id), orderPayload(data));
  });
}

async function seedServerSellerOrder(id = "sorder-1", data = {}) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "sellerOrders", id), {
      sellerOrderId: id,
      rootOrderId: "order-1",
      buyerUid: "buyer-1",
      businessId: "biz-1",
      status: "pending",
      ...data,
    });
  });
}

// =====================================================================
// 25 — direct order creation is denied for every client actor
// =====================================================================

rulesTest("25. a buyer cannot create their own order document", async () => {
  const db = (await env()).authenticatedContext("buyer-1").firestore();
  await assertFails(setDoc(doc(db, "orders", "order-1"), orderPayload()));
});

rulesTest("25b. every buyer-identity spelling is denied", async () => {
  const rulesEnv = await env();
  const db = rulesEnv
    .authenticatedContext("buyer-1", { email: "buyer@example.com" })
    .firestore();
  // The old rule accepted any of these three claims.
  const shapes = [
    { userId: "buyer-1", buyerUid: null },
    { userId: null, buyerUid: "buyer-1" },
    { userId: null, buyerUid: null, buyerEmail: "buyer@example.com" },
  ];
  for (let i = 0; i < shapes.length; i += 1) {
    await assertFails(
      setDoc(doc(db, "orders", `order-shape-${i}`), orderPayload(shapes[i]))
    );
  }
});

rulesTest("25c. the pet_taxi carve-out no longer permits a client create", async () => {
  const db = (await env()).authenticatedContext("buyer-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "orders", "taxi-1"),
      orderPayload({ type: "pet_taxi", status: "pending", paymentStatus: "pending" })
    )
  );
});

rulesTest("25d. a stranger and an unauthenticated caller are denied", async () => {
  const rulesEnv = await env();
  await assertFails(
    setDoc(
      doc(rulesEnv.authenticatedContext("mallory").firestore(), "orders", "o-x"),
      orderPayload()
    )
  );
  await assertFails(
    setDoc(
      doc(rulesEnv.unauthenticatedContext().firestore(), "orders", "o-y"),
      orderPayload()
    )
  );
});

rulesTest("28. an ADMIN using the client SDK cannot create an order either", async () => {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users", "admin-1"), { role: "admin" });
  });
  const db = rulesEnv.authenticatedContext("admin-1").firestore();
  await assertFails(setDoc(doc(db, "orders", "admin-made"), orderPayload()));
  // Privileged order mutation belongs to the trusted callables, whose Admin
  // SDK bypasses Rules — not to a console session.
  await seedServerOrder("order-admin");
  await assertFails(
    updateDoc(doc(db, "orders", "order-admin"), { paymentStatus: "paid" })
  );
});

// =====================================================================
// 26 — seller order projections stay server-only
// =====================================================================

rulesTest("26. no client actor can create a seller order projection", async () => {
  const rulesEnv = await env();
  for (const context of [
    rulesEnv.authenticatedContext("buyer-1"),
    rulesEnv.authenticatedContext("seller-1"),
    rulesEnv.unauthenticatedContext(),
  ]) {
    await assertFails(
      setDoc(doc(context.firestore(), "sellerOrders", "s-new"), {
        sellerOrderId: "s-new",
        businessId: "biz-1",
        buyerUid: "buyer-1",
      })
    );
  }
});

// =====================================================================
// 27 — privileged-field mutation and terminal-state reopening are denied
// =====================================================================

rulesTest("27. privileged field injection on an existing order is denied", async () => {
  await seedServerOrder("order-priv");
  const db = (await env()).authenticatedContext("buyer-1").firestore();
  const mutations = [
    { paymentStatus: "paid" },
    { status: "delivered" },
    { "pricing.grandTotal": 1 },
    { buyerUid: "someone-else" },
    { businessId: "another-biz" },
    { createdAt: new Date() },
    { entitlementApplied: true },
    { orderType: "web_subscription" },
    { planId: "gold" },
  ];
  for (const patch of mutations) {
    await assertFails(
      updateDoc(doc(db, "orders", "order-priv"), patch),
      JSON.stringify(patch)
    );
  }
});

rulesTest("27b. a client cannot delete an order, nor upsert over one", async () => {
  await seedServerOrder("order-del");
  const db = (await env()).authenticatedContext("buyer-1").firestore();
  await assertFails(deleteDoc(doc(db, "orders", "order-del")));
  // set() over an existing document is an update, and is equally denied.
  await assertFails(
    setDoc(doc(db, "orders", "order-del"), orderPayload({ paymentStatus: "paid" }))
  );
});

rulesTest("27c. a seller cannot mutate the seller order projection directly", async () => {
  await seedServerSellerOrder("s-1");
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "businesses", "biz-1"), {
      ownerUid: "seller-1",
    });
  });
  const db = rulesEnv.authenticatedContext("seller-1").firestore();
  // Legitimate fulfilment goes through `updateSellerOrderStatusV2`, not here.
  await assertFails(updateDoc(doc(db, "sellerOrders", "s-1"), { status: "shipped" }));
  await assertFails(deleteDoc(doc(db, "sellerOrders", "s-1")));
});

// =====================================================================
// The closure must not break legitimate READS — a vacuity check
// =====================================================================

rulesTest("29. the buyer and the seller can still READ their own orders", async () => {
  // If everything were denied this suite would pass vacuously. The read path
  // that Seller fulfilment and buyer order history depend on must still work.
  await seedServerOrder("order-read");
  await seedServerSellerOrder("s-read");
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "businesses", "biz-1"), {
      ownerUid: "seller-1",
    });
  });

  await assertSucceeds(
    getDoc(
      doc(rulesEnv.authenticatedContext("buyer-1").firestore(), "orders", "order-read")
    )
  );
  await assertSucceeds(
    getDoc(
      doc(
        rulesEnv.authenticatedContext("seller-1").firestore(),
        "sellerOrders",
        "s-read"
      )
    )
  );
  // And a stranger still cannot read them.
  await assertFails(
    getDoc(
      doc(rulesEnv.authenticatedContext("mallory").firestore(), "orders", "order-read")
    )
  );
});

rulesTest("the rules source itself carries no client order-create branch", () => {
  const executable = rules
    .split("\n")
    .map((line) => {
      const idx = line.indexOf("//");
      return idx === -1 ? line : line.slice(0, idx);
    })
    .join("\n");
  const ordersBlock = executable.slice(
    executable.indexOf("match /orders/{orderId}"),
    executable.indexOf("match /sellerOrders/{sellerOrderId}")
  );
  assert.ok(ordersBlock.length > 0, "the orders block must exist");
  assert.match(ordersBlock, /allow create: if false;/);
  assert.match(ordersBlock, /allow update, delete: if false;/);
  // The old permissive predicate must be gone entirely.
  assert.doesNotMatch(ordersBlock, /request\.resource\.data\.buyerUid == request\.auth\.uid/);
  assert.doesNotMatch(ordersBlock, /pet_taxi/);
});
