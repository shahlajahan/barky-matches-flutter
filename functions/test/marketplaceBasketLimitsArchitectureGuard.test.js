"use strict";

// Marketplace Revision 47 §0.45 (Slice 7F-2) — durable guards for the bounded
// basket.
//
// These pin STRUCTURE, not behaviour: that the bound is enforced before any
// database read, that there is exactly one canonical source of the numbers,
// and that no alternate order-creation path or client constant can exceed it.
// A behavioural test can pass while the ordering silently degrades — for
// example if a future edit moved validation below the product lookup — so
// these exist alongside the behavioural suite, not instead of it.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const REPO = path.resolve(__dirname, "..", "..");
const read = (rel) => fs.readFileSync(path.join(REPO, rel), "utf8");

/// Comments stripped: a comment must neither satisfy a guard nor trip one.
function executable(source) {
  return source
    .split("\n")
    .map((line) => {
      const idx = line.indexOf("//");
      return idx === -1 ? line : line.slice(0, idx);
    })
    .join("\n");
}

const indexSource = read("functions/index.js");
const limitsSource = read("functions/src/marketplace/orders/basketLimits.js");
const { BASKET_LIMITS } = require("../src/marketplace/orders/basketLimits");

/// The body of `createMarketplaceOrderV2`, comments removed.
function checkoutBody() {
  const code = executable(indexSource);
  const start = code.indexOf("exports.createMarketplaceOrderV2 = onCall(");
  assert.ok(start > 0, "createMarketplaceOrderV2 must exist");
  const end = code.indexOf("\nexports.", start + 10);
  return code.slice(start, end === -1 ? code.length : end);
}

test("validation runs BEFORE any product, business or shipping read", () => {
  const body = checkoutBody();
  const validateAt = body.indexOf("validateAndNormalizeBasket(");
  assert.ok(validateAt > 0, "the checkout must call the basket validator");

  // Every database entry point in this callable must come after it.
  for (const readToken of [
    '.collection("businesses")',
    '.collection("products")',
    '.collection("shipping_configs")',
    "db.runTransaction(",
  ]) {
    const at = body.indexOf(readToken);
    if (at === -1) continue;
    assert.ok(
      validateAt < at,
      `basket validation must precede ${readToken} (validate@${validateAt}, read@${at})`
    );
  }
});

test("no unbounded iteration over the raw payload precedes the bound", () => {
  const body = checkoutBody();
  const validateAt = body.indexOf("validateAndNormalizeBasket(");
  const prelude = body.slice(0, validateAt);
  // A loop, map or Promise.all over the client array before the length check
  // would reintroduce unbounded work.
  for (const pattern of [
    /for\s*\(\s*const\s+\w+\s+of\s+rawItems\s*\)/,
    /rawItems\s*\.\s*(map|forEach|filter|reduce|find)\s*\(/,
    /Promise\.all\s*\(\s*rawItems/,
  ]) {
    assert.doesNotMatch(
      prelude,
      pattern,
      `no iteration over the raw payload may precede the bound: ${pattern}`
    );
  }
});

test("the checkout consumes NORMALIZED lines, not the raw payload", () => {
  const body = checkoutBody();
  // The per-item loop must iterate the validator's output, so duplicates are
  // already merged and every quantity is already known valid.
  assert.match(
    body,
    /for \(const line of normalizedBasket\.lines\)/,
    "the item loop must iterate the normalized lines"
  );
  assert.doesNotMatch(
    body,
    /for \(const rawItem of rawItems\)/,
    "the raw payload must no longer be iterated directly"
  );
  // The old silent coercion must be gone.
  assert.doesNotMatch(
    body,
    /Math\.max\(1,\s*Math\.floor\(asNumber\(rawItem\.quantity/,
    "quantity must not be coerced; it is validated"
  );
});

test("the bounds live in exactly one place — no magic numbers elsewhere", () => {
  // The canonical module is the only backend declaration.
  assert.match(limitsSource, /const BASKET_LIMITS = Object\.freeze\(\{/);
  const otherDeclarations = executable(indexSource).match(
    /MAX_(SUBMITTED_LINES|DISTINCT_PRODUCTS|QUANTITY_PER_PRODUCT|TOTAL_UNITS|BUSINESSES)\s*[:=]\s*\d/g
  );
  assert.equal(
    otherDeclarations,
    null,
    "index.js must not redeclare any basket bound"
  );
});

test("the bounds cannot be raised by client input or environment", () => {
  const code = executable(limitsSource);
  assert.doesNotMatch(
    code,
    /process\.env/,
    "no environment variable may override a basket bound"
  );
  assert.match(code, /Object\.freeze\(\{/, "the bounds must be frozen");
  // A misconfigured bound must fail closed at load.
  assert.match(code, /throw new Error\(`basketLimits:/);
});

test("the validator performs no database access, so it is safe before reads", () => {
  const code = executable(limitsSource);
  for (const token of ["collection(", "runTransaction", "firestore(", "admin.", "getFirestore"]) {
    assert.ok(!code.includes(token), `the validator must not reference ${token}`);
  }
});

test("no alternate order-creation callable bypasses the bound", () => {
  const code = executable(indexSource);
  // Every exported callable whose name creates a Marketplace order must go
  // through the validator. Other sectors create their own order types and are
  // out of this contract's scope.
  const marketplaceOrderCreators = [...code.matchAll(/exports\.(createMarketplaceOrder\w*)\s*=/g)]
    .map((m) => m[1]);
  assert.ok(
    marketplaceOrderCreators.includes("createMarketplaceOrderV2"),
    "the canonical creator must exist"
  );
  for (const name of marketplaceOrderCreators) {
    const start = code.indexOf(`exports.${name} =`);
    const end = code.indexOf("\nexports.", start + 10);
    const body = code.slice(start, end === -1 ? code.length : end);
    assert.match(
      body,
      /validateAndNormalizeBasket\(/,
      `${name} must enforce the basket bound`
    );
  }
});

test("the failure path does not fall back to a legacy direct order writer", () => {
  const body = checkoutBody();
  // A rejection must throw, never route into an alternate writer.
  assert.doesNotMatch(body, /db\.batch\(\)/);
  assert.doesNotMatch(body, /batch\.commit\(\)/);
  // And the client-side legacy writer is gone entirely (Slice 7E).
  const orderService = read("lib/services/order_service.dart");
  assert.ok(!orderService.includes("FirebaseFirestore"));
});

test("the Flutter mirror is never more permissive than the backend", () => {
  const mirror = read("lib/models/marketplace_basket_limits.dart");
  const dartValue = (name) => {
    const m = mirror.match(new RegExp(`${name}\\s*=\\s*(\\d+);`));
    assert.ok(m, `${name} must be declared in the Flutter mirror`);
    return Number(m[1]);
  };
  const pairs = [
    ["maxSubmittedLines", BASKET_LIMITS.MAX_SUBMITTED_LINES],
    ["maxDistinctProducts", BASKET_LIMITS.MAX_DISTINCT_PRODUCTS],
    ["maxQuantityPerProduct", BASKET_LIMITS.MAX_QUANTITY_PER_PRODUCT],
    ["maxTotalUnits", BASKET_LIMITS.MAX_TOTAL_UNITS],
    ["maxBusinesses", BASKET_LIMITS.MAX_BUSINESSES],
  ];
  for (const [dartName, backendValue] of pairs) {
    assert.ok(
      dartValue(dartName) <= backendValue,
      `Flutter ${dartName} must not exceed the backend bound`
    );
  }
});

test("the Flutter cart routes every mutation through one guard", () => {
  const cart = executable(read("lib/ui/petshop/all_products_page.dart"));
  assert.match(cart, /String\? _basketGuardMessage\(/, "the guard must exist");
  // Both mutation entry points consult it.
  const addAt = cart.indexOf("void _addToBasket(");
  const changeAt = cart.indexOf("void _changeQuantity(");
  assert.ok(addAt > 0 && changeAt > 0);
  for (const [label, start] of [["_addToBasket", addAt], ["_changeQuantity", changeAt]]) {
    const body = cart.slice(start, start + 1600);
    assert.match(
      body,
      /_basketGuardMessage\(/,
      `${label} must consult the basket guard`
    );
  }
  // The guard must precede the state mutation in the add path.
  const addBody = cart.slice(addAt, changeAt > addAt ? changeAt : addAt + 2000);
  const guardAt = addBody.indexOf("_basketGuardMessage(");
  const setStateAt = addBody.indexOf("setState(");
  assert.ok(
    guardAt > 0 && setStateAt > guardAt,
    "the guard must run before the cart is mutated"
  );
});

test("the M3 reservation path will consume validated lines", () => {
  // The frozen M3 line builder is fed from the same normalized items, so
  // enabling reservation later cannot reintroduce unvalidated quantities.
  const body = checkoutBody();
  const normalizeAt = body.indexOf("validateAndNormalizeBasket(");
  const m3At = body.indexOf("buildCanonicalLines(");
  if (m3At !== -1) {
    assert.ok(
      normalizeAt < m3At,
      "M3 canonical lines must be built after basket validation"
    );
  }
});

test("the guards are non-vacuous: planted regressions are detected", () => {
  const plantedRawLoop = "for (const rawItem of rawItems) { await db.collection('products'); }";
  assert.match(plantedRawLoop, /for\s*\(\s*const\s+\w+\s+of\s+rawItems\s*\)/);

  const plantedCoercion =
    "const quantity = Math.max(1, Math.floor(asNumber(rawItem.quantity, 1)));";
  assert.match(
    plantedCoercion,
    /Math\.max\(1,\s*Math\.floor\(asNumber\(rawItem\.quantity/
  );

  const plantedEnvOverride = 'const MAX = Number(process.env.BASKET_MAX || 50);';
  assert.match(plantedEnvOverride, /process\.env/);
});
