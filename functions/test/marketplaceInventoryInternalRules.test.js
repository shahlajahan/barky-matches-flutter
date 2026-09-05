"use strict";

// Marketplace Revision 46 §0.44 (Slice 7F-1) — client denial for the
// server-internal inventory, idempotency and recovery collections.
//
// Two distinct jobs, kept apart:
//
//   1. a COVERAGE GUARD that derives the authoritative collection names from
//      the runtime modules themselves and fails if any lacks an explicit
//      Rules boundary — so a collection added or renamed in one layer only
//      cannot slip through; and
//   2. ADVERSARIAL behavioural tests that run every actor and operation
//      against the real `firestore.rules` in the Rules emulator.
//
// Rules never apply to the Admin SDK, so these prove client denial only. The
// positive trusted-server path is proven separately in
// `marketplaceInventoryInternalTrustedWrite.test.js`.

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
  collection,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
} = require("firebase/firestore");

const REPO = path.resolve(__dirname, "..", "..");
const rules = fs.readFileSync(path.join(REPO, "firestore.rules"), "utf8");

const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
function rulesTest(name, fn) {
  test(name, { skip: !hasEmulator }, fn);
}

let testEnv = null;
async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: `mp-inventory-internal-rules-${Date.now()}`,
    firestore: { rules },
  });
  return testEnv;
}
test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

// =====================================================================
// The authoritative inventory, derived from runtime code
// =====================================================================

const {
  INVENTORY_COLLECTIONS,
} = require("../src/inventory/inventoryConstants");
const {
  CHECKOUT_ATTEMPT_COLLECTION,
} = require("../src/inventory/inventoryCheckoutCoordinator");
const {
  COLLECTION: PAYMENT_CALLBACK_CLAIM_COLLECTION,
} = require("../src/inventory/paymentCallbackClaims");

const releaseSource = fs.readFileSync(
  path.join(REPO, "functions/src/inventory/inventoryReleaseCoordinator.js"),
  "utf8"
);
const claimsSource = fs.readFileSync(
  path.join(REPO, "functions/src/inventory/paymentCallbackClaims.js"),
  "utf8"
);
const schedulerSource = fs.readFileSync(
  path.join(REPO, "functions/src/inventory/inventoryExpiryScheduler.js"),
  "utf8"
);
const checkoutCoordinatorSource = fs.readFileSync(
  path.join(REPO, "functions/src/inventory/inventoryCheckoutCoordinator.js"),
  "utf8"
);
const transactionsSource = fs.readFileSync(
  path.join(REPO, "functions/src/inventory/inventoryTransactions.js"),
  "utf8"
);

/// Collection names written inline as `collection("name")`.
function literalCollections(source) {
  return [...source.matchAll(/collection\(\s*"([A-Za-z][A-Za-z0-9_]*)"\s*\)/g)]
    .map((m) => m[1]);
}

/// Collection names bound to a module constant — `const X_COLLECTION = "name"`
/// — and then used as `collection(X_COLLECTION)`. These are invisible to
/// [literalCollections], which is exactly how a collection can be dropped
/// from the inventory below without anything noticing. Both forms are
/// extracted so the guard sees every name the runtime can actually reach.
function constantCollections(source) {
  const names = [];
  for (const m of source.matchAll(
    /const\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([A-Za-z][A-Za-z0-9_]*)"/g
  )) {
    const [, constName, value] = m;
    // A collection-name constant, however it is spelled — including the bare
    // `COLLECTION` that `paymentCallbackClaims.js` uses.
    if (!/COLLECTION/.test(constName)) continue;
    // Only count it if the module actually opens a collection with it.
    if (new RegExp(`collection\\(\\s*${constName}\\s*\\)`).test(source)) {
      names.push(value);
    }
  }
  return names;
}

/// Every collection name an owning module can reach, by either form.
function reachableCollections(source) {
  return [...new Set([...literalCollections(source), ...constantCollections(source)])];
}

/// Every server-internal collection this slice must close, and the runtime
/// origin that proves the name. Non-internal collections that these modules
/// also touch (orders, sellerOrders, products, businesses, order_returns)
/// have their own Rules and are deliberately excluded.
const INTERNAL_COLLECTIONS = Object.freeze([
  { name: INVENTORY_COLLECTIONS.RESERVATIONS, origin: "INVENTORY_COLLECTIONS.RESERVATIONS" },
  { name: INVENTORY_COLLECTIONS.MOVEMENTS, origin: "INVENTORY_COLLECTIONS.MOVEMENTS" },
  { name: INVENTORY_COLLECTIONS.EVENTS, origin: "INVENTORY_COLLECTIONS.EVENTS" },
  { name: CHECKOUT_ATTEMPT_COLLECTION, origin: "CHECKOUT_ATTEMPT_COLLECTION" },
  { name: PAYMENT_CALLBACK_CLAIM_COLLECTION, origin: "paymentCallbackClaims.COLLECTION" },
  { name: "paymentIdentityConflicts", origin: "paymentCallbackClaims CONFLICT_COLLECTION" },
  { name: "inventoryLatePaymentRecoveries", origin: "inventoryReleaseCoordinator literal" },
  { name: "inventoryRecoveryCheckpoints", origin: "inventoryExpiryScheduler literal" },
]);

/// Collections these modules touch that are NOT server-internal.
const EXTERNALLY_GOVERNED = new Set([
  "orders",
  "sellerOrders",
  "products",
  "businesses",
  "order_returns",
]);

/// Rules text with comments stripped: a comment must never satisfy a check.
const executableRules = rules
  .split("\n")
  .map((line) => {
    const idx = line.indexOf("//");
    return idx === -1 ? line : line.slice(0, idx);
  })
  .join("\n");

// =====================================================================
// Phase 4 — coverage guard
// =====================================================================

test("every runtime-declared internal collection has an explicit Rules match", () => {
  for (const { name, origin } of INTERNAL_COLLECTIONS) {
    assert.ok(name, `${origin} must resolve to a collection name`);
    const pattern = new RegExp(`match /${name}/\\{[A-Za-z]+\\}\\s*\\{`);
    assert.match(
      executableRules,
      pattern,
      `${name} (${origin}) must have an explicit match block in firestore.rules`
    );
  }
});

test("each internal match denies read, create, update and delete", () => {
  for (const { name } of INTERNAL_COLLECTIONS) {
    const start = executableRules.indexOf(`match /${name}/`);
    assert.ok(start > 0, name);
    // The block runs to the start of the next top-level match.
    const rest = executableRules.slice(start);
    const block = rest.slice(0, rest.indexOf("\n    match /", 1) + 1 || rest.length);
    assert.match(
      block,
      /allow read, create, update, delete: if false;/,
      `${name} must deny every client operation`
    );
    assert.doesNotMatch(
      block,
      /isAdmin\(\)|isSignedIn\(\)|request\.auth/,
      `${name} must have no actor exception of any kind`
    );
  }
});

test("each internal match denies every nested path", () => {
  for (const { name } of INTERNAL_COLLECTIONS) {
    const start = executableRules.indexOf(`match /${name}/`);
    const rest = executableRules.slice(start);
    const block = rest.slice(0, rest.indexOf("\n    match /", 1) + 1 || rest.length);
    assert.match(
      block,
      /match \/\{document=\*\*\} \{ allow read, write: if false; \}/,
      `${name} must deny nested documents and subcollections`
    );
  }
});

test("every collection each owning module can reach is accounted for", () => {
  // Anything a module reaches that is neither externally governed nor in the
  // internal list means the inventory above is incomplete. Both the literal
  // and the constant-bound forms are checked, so removing an entry from
  // INTERNAL_COLLECTIONS fails here even when the name never appears inline.
  const declared = new Set(INTERNAL_COLLECTIONS.map((c) => c.name));
  const modules = [
    ["inventoryReleaseCoordinator", releaseSource],
    ["paymentCallbackClaims", claimsSource],
    ["inventoryExpiryScheduler", schedulerSource],
    ["inventoryCheckoutCoordinator", checkoutCoordinatorSource],
    ["inventoryTransactions", transactionsSource],
  ];
  let sawConstantBound = false;
  for (const [label, source] of modules) {
    if (constantCollections(source).length > 0) sawConstantBound = true;
    for (const name of reachableCollections(source)) {
      assert.ok(
        declared.has(name) || EXTERNALLY_GOVERNED.has(name),
        `${label} reaches "${name}", which is neither declared internal nor externally governed`
      );
    }
  }
  // The constant-bound extractor must actually be finding something, or this
  // check would silently degrade to the literal-only version it replaced.
  assert.ok(
    sawConstantBound,
    "the constant-bound extractor must find at least one collection"
  );
});

test("every INVENTORY_COLLECTIONS value is declared internal and covered", () => {
  // These three names come from an imported constant object rather than from
  // any module's own source text, so the source cross-check above cannot see
  // them. Adding a fourth ledger collection to INVENTORY_COLLECTIONS without
  // a Rules block must fail here.
  const declared = new Set(INTERNAL_COLLECTIONS.map((c) => c.name));
  const values = Object.values(INVENTORY_COLLECTIONS);
  assert.ok(values.length >= 3, "the ledger must declare its collections");
  for (const name of values) {
    assert.ok(
      declared.has(name),
      `INVENTORY_COLLECTIONS value "${name}" must be declared in INTERNAL_COLLECTIONS`
    );
    assert.match(
      executableRules,
      new RegExp(`match /${name}/\\{[A-Za-z]+\\}\\s*\\{`),
      `INVENTORY_COLLECTIONS value "${name}" must have an explicit Rules match`
    );
  }
});

test("no root-level recursive catch-all exists that could re-open these paths", () => {
  // Firestore Rules are OR-based: an explicit deny does not override an allow
  // from another matching rule. The denials above are only sufficient while
  // no broader match also covers these root collections.
  const rootCatchAll = /\n\s{4}match \/\{[A-Za-z]+=\*\*\}\s*\{/;
  assert.doesNotMatch(
    executableRules,
    rootCatchAll,
    "a root-level recursive match would OR-combine with these denials"
  );
  // And no root match may name a wildcard collection segment.
  const rootWildcardCollection = /\n\s{4}match \/\{[A-Za-z]+\}\/\{[A-Za-z]+\}\s*\{/;
  assert.doesNotMatch(executableRules, rootWildcardCollection);
});

// =====================================================================
// Phase 5 — adversarial behaviour, every actor × every operation
// =====================================================================

/// Payloads that attempt to fabricate or alter authoritative state.
function hostilePayload(collectionName) {
  return {
    buyerUid: "attacker",
    businessId: "biz-1",
    productId: "prod-1",
    marketplaceBusinessGenerationId: "forged-generation",
    checkoutAttemptId: "attempt-1",
    fingerprint: "forged-fingerprint",
    rootOrderId: "order-1",
    sellerOrderId: "sorder-1",
    status: "reserved",
    quantity: 999,
    stock: 999,
    reservedStock: 0,
    released: true,
    committed: true,
    paymentStatus: "verified_success",
    claimStatus: "completed",
    expiresAt: new Date(Date.now() + 86400000),
    manualReview: false,
    lastExpiresAt: new Date(0),
    lastReservationId: "skip-everything",
    createdAt: new Date(0),
    updatedAt: new Date(0),
    __source: collectionName,
  };
}

async function actors() {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", "admin-1"), { role: "admin" });
    await setDoc(doc(db, "businesses", "biz-1"), { ownerUid: "seller-1" });
  });
  return [
    ["unauthenticated", rulesEnv.unauthenticatedContext().firestore()],
    ["customer", rulesEnv.authenticatedContext("customer-1").firestore()],
    ["seller", rulesEnv.authenticatedContext("seller-1").firestore()],
    [
      "business owner",
      rulesEnv.authenticatedContext("seller-1", { businessId: "biz-1" }).firestore(),
    ],
    [
      "admin custom claim",
      rulesEnv
        .authenticatedContext("admin-1", { admin: true, role: "admin" })
        .firestore(),
    ],
  ];
}

/// Seeds a document through the Admin-equivalent bypass so read/update/delete
/// are tested against something that actually exists — otherwise a denial
/// could be indistinguishable from "not found".
async function seedInternalDoc(collectionName, docId) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), collectionName, docId), {
      seeded: true,
      status: "reserved",
    });
    await setDoc(
      doc(context.firestore(), collectionName, docId, "members", "m1"),
      { seeded: true }
    );
  });
}

for (const { name } of INTERNAL_COLLECTIONS) {
  rulesTest(`${name}: every client actor is denied every operation`, async () => {
    const docId = "existing-1";
    await seedInternalDoc(name, docId);
    const payload = hostilePayload(name);

    for (const [label, db] of await actors()) {
      // Direct get
      await assertFails(getDoc(doc(db, name, docId)));
      // List / query
      await assertFails(getDocs(collection(db, name)));
      // Create
      await assertFails(setDoc(doc(db, name, "forged-1"), payload));
      // Update (set-over and update alike)
      await assertFails(updateDoc(doc(db, name, docId), { status: "released" }));
      await assertFails(setDoc(doc(db, name, docId), payload));
      // Delete — deleting a recovery record or a sweep cursor is itself an
      // attack, not merely a nuisance.
      await assertFails(deleteDoc(doc(db, name, docId)));

      assert.ok(label, label);
    }
  });

  rulesTest(`${name}: nested documents and subcollections are denied too`, async () => {
    const docId = "existing-1";
    await seedInternalDoc(name, docId);
    for (const [, db] of await actors()) {
      await assertFails(getDoc(doc(db, name, docId, "members", "m1")));
      await assertFails(getDocs(collection(db, name, docId, "members")));
      await assertFails(
        setDoc(doc(db, name, docId, "members", "forged"), { forged: true })
      );
      await assertFails(
        updateDoc(doc(db, name, docId, "members", "m1"), { seeded: false })
      );
      await assertFails(deleteDoc(doc(db, name, docId, "members", "m1")));
    }
  });
}

// =====================================================================
// The harness itself must not be universally broken
// =====================================================================

rulesTest("VACUITY CHECK: the same actors can still perform a legitimate read", async () => {
  // If every operation failed for every actor regardless of Rules, the suite
  // above would pass while proving nothing. A known-allowed read must succeed
  // through the very same harness and contexts.
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users", "customer-1"), {
      displayName: "Customer",
    });
  });
  await assertSucceeds(
    getDoc(
      doc(rulesEnv.authenticatedContext("customer-1").firestore(), "users", "customer-1")
    )
  );
});

rulesTest("VACUITY CHECK: seeding through the bypass genuinely created the documents", async () => {
  // Proves the denials above were evaluated against existing documents, not
  // against absent paths.
  const rulesEnv = await env();
  await seedInternalDoc(INVENTORY_COLLECTIONS.RESERVATIONS, "vacuity-1");
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const snap = await getDoc(
      doc(context.firestore(), INVENTORY_COLLECTIONS.RESERVATIONS, "vacuity-1")
    );
    assert.equal(snap.exists(), true, "the seeded reservation must exist");
    const nested = await getDoc(
      doc(
        context.firestore(),
        INVENTORY_COLLECTIONS.RESERVATIONS,
        "vacuity-1",
        "members",
        "m1"
      )
    );
    assert.equal(nested.exists(), true, "the seeded nested document must exist");
  });
});
