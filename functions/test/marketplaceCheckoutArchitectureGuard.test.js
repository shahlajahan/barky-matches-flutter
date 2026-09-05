"use strict";

// Marketplace Revision 44 §0.42 (Slice 7E) — durable guards for the checkout
// acceptance boundary.
//
// These pin ARCHITECTURE, not behaviour: that acceptance-critical reads and
// writes share one transaction, that the canonical eligibility predicate is
// invoked inside it, and that no client can author a canonical order. A
// behavioural test can pass while the boundary silently degrades — for
// example if a future edit moved the order write back outside the
// transaction — so these exist alongside the behavioural suite, not instead
// of it.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const REPO = path.resolve(__dirname, "..", "..");
const read = (rel) => fs.readFileSync(path.join(REPO, rel), "utf8");

const indexSource = read("functions/index.js");
const guardSource = read(
  "functions/src/marketplace/orders/atomicCheckoutGuard.js"
);
const rulesSource = read("firestore.rules");

/// Comments are stripped before every structural check: a comment must
/// neither satisfy a guard nor trip one.
function executable(source) {
  return source
    .split("\n")
    .map((line) => {
      const idx = line.indexOf("//");
      return idx === -1 ? line : line.slice(0, idx);
    })
    .join("\n");
}

/// The body of `createMarketplaceOrderV2`, comments removed.
function checkoutBody() {
  const code = executable(indexSource);
  const start = code.indexOf("exports.createMarketplaceOrderV2 = onCall(");
  assert.ok(start > 0, "createMarketplaceOrderV2 must exist");
  const end = code.indexOf("\nexports.", start + 10);
  return code.slice(start, end === -1 ? code.length : end);
}

test("the canonical checkout commit boundary is a transaction, not a batch", () => {
  const body = checkoutBody();
  // The order tree must not be committed with a write batch again. This is
  // the exact defect Revision 39 §0.37 E recorded.
  assert.doesNotMatch(
    body,
    /db\.batch\(\)/,
    "createMarketplaceOrderV2 must not open a write batch"
  );
  assert.doesNotMatch(
    body,
    /batch\.commit\(\)/,
    "the checkout must not commit through a batch"
  );
  assert.doesNotMatch(body, /batch\.set\(/);
  assert.match(
    body,
    /db\.runTransaction\(/,
    "acceptance must happen inside a transaction"
  );
});

test("the eligibility gate is invoked INSIDE the checkout transaction, before any write", () => {
  const body = checkoutBody();
  // Locate the transaction that performs the order writes.
  const txIndex = body.lastIndexOf("db.runTransaction(");
  assert.ok(txIndex > 0, "a transaction must exist");
  const txBlock = body.slice(txIndex);

  const gateIndex = txBlock.indexOf("assertCheckoutItemsAcceptable(");
  const rootWriteIndex = txBlock.indexOf("tx.set(rootOrderRef");
  const sellerWriteIndex = txBlock.indexOf("tx.set(sellerOrderRefs[i]");

  assert.ok(gateIndex > 0, "the acceptance gate must be called in the transaction");
  assert.ok(rootWriteIndex > 0, "the root order must be written in the transaction");
  assert.ok(sellerWriteIndex > 0, "seller orders must be written in the transaction");
  assert.ok(
    gateIndex < rootWriteIndex,
    "eligibility must be evaluated BEFORE the order is written"
  );
  assert.ok(gateIndex < sellerWriteIndex);

  // The transaction handle must be handed to the gate — a gate called
  // without it would read outside the transaction's snapshot.
  const gateCall = txBlock.slice(gateIndex, rootWriteIndex);
  assert.match(gateCall, /\btx,/, "the gate must receive the transaction");
});

test("the order and seller-order writes share the checkout transaction", () => {
  const body = checkoutBody();
  const txIndex = body.lastIndexOf("db.runTransaction(");
  const txBlock = body.slice(txIndex);
  // No accepted order may be written outside the transaction.
  const outside = body.slice(0, txIndex);
  assert.doesNotMatch(outside, /rootOrderRef\.set\(/);
  assert.doesNotMatch(outside, /sellerOrderRefs\[i\]\.set\(/);
  assert.match(txBlock, /tx\.set\(rootOrderRef/);
  assert.match(txBlock, /tx\.set\(sellerOrderRefs\[i\]/);
});

test("the gate delegates to the ONE canonical eligibility predicate", () => {
  // Discovery and checkout must not drift: the gate must not carry its own
  // copy of the eligibility rules.
  assert.match(
    guardSource,
    /require\("\.\.\/publicCatalog\/marketplaceProductVisibility"\)/,
    "the gate must use the shared visibility predicate"
  );
  const code = executable(guardSource);
  assert.match(code, /assessProductVisibility/);
  // It must not re-implement any eligibility condition locally.
  for (const reimplementation of [
    "decisionHash",
    "evidenceRevision",
    "pilotProductApproval",
    "moderationStatus",
    "isActive",
    "policyVersion",
  ]) {
    assert.ok(
      !code.includes(reimplementation),
      `the gate must not re-derive ${reimplementation}; the evaluator owns it`
    );
  }
});

test("the gate refuses to run without a transaction", () => {
  const code = executable(guardSource);
  assert.match(
    code,
    /if \(!tx\) \{/,
    "a missing transaction must be a hard error, not a silent non-transactional read"
  );
});

test("client price is not authoritative — the stored price comes from the product", () => {
  const code = executable(guardSource);
  // The accepted line's price is derived from the transactionally-read
  // product, never from the request.
  assert.match(
    code,
    /authoritativeUnitPrice = normalizeMoney\(\s*product\.salePrice \|\| product\.price\s*\)/,
    "price must be derived from the product document"
  );
  assert.match(
    code,
    /unitPrice: authoritativeUnitPrice/,
    "the returned price must be the authoritative one"
  );
  // A disagreement is a refusal, never a silent reprice.
  assert.match(code, /CHECKOUT_REJECTION\.PRICE_CHANGED/);
});

test("Firestore Rules deny every client-SDK order write", () => {
  const code = executable(rulesSource);
  const orders = code.slice(
    code.indexOf("match /orders/{orderId}"),
    code.indexOf("match /sellerOrders/{sellerOrderId}")
  );
  assert.ok(orders.length > 0);
  assert.match(orders, /allow create: if false;/);
  assert.match(orders, /allow update, delete: if false;/);

  const sellerOrders = code.slice(code.indexOf("match /sellerOrders/{sellerOrderId}"));
  assert.match(sellerOrders.slice(0, 400), /allow create, update, delete: if false;/);
});

test("no Flutter code creates a canonical order document", () => {
  // The whole client tree, not a named list, so a new file is covered the
  // moment it exists.
  const offenders = [];
  const walk = (dir) => {
    for (const entry of fs.readdirSync(path.join(REPO, dir), { withFileTypes: true })) {
      const rel = `${dir}/${entry.name}`;
      if (entry.isDirectory()) walk(rel);
      else if (entry.name.endsWith(".dart")) {
        const code = executable(read(rel));
        // A write to an orders/sellerOrders document from the client.
        const writePattern =
          /collection\(\s*['"](orders|sellerOrders)['"]\s*\)[\s\S]{0,160}?\.(set|add)\(/;
        if (writePattern.test(code)) offenders.push(rel);
      }
    }
  };
  walk("lib");
  assert.deepEqual(
    offenders,
    [],
    "Flutter must create orders only through the trusted callables:\n" +
      offenders.join("\n")
  );
});

test("the Flutter order service reaches orders only through callables", () => {
  const code = executable(read("lib/services/order_service.dart"));
  assert.ok(
    !code.includes("FirebaseFirestore"),
    "OrderService must not touch Firestore at all"
  );
  assert.match(code, /httpsCallable\('createMarketplaceOrderV2'\)/);
});

test("the guards are non-vacuous: planted regressions are detected", () => {
  // Proves the patterns match the shapes this slice removed, so the checks
  // above cannot pass merely because nothing matches anything.
  const plantedBatch = "const batch = db.batch(); batch.set(x, {}); await batch.commit();";
  assert.match(plantedBatch, /db\.batch\(\)/);
  assert.match(plantedBatch, /batch\.commit\(\)/);

  const plantedFlutterWrite =
    "await FirebaseFirestore.instance.collection('orders').doc().set({'a': 1});";
  assert.match(
    plantedFlutterWrite,
    /collection\(\s*['"](orders|sellerOrders)['"]\s*\)[\s\S]{0,160}?\.(set|add)\(/
  );

  const plantedPermissiveRule = "allow create: if isSignedIn();";
  assert.doesNotMatch(plantedPermissiveRule, /allow create: if false;/);
});
