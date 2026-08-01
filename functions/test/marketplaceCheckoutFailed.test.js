"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
  path.resolve(__dirname, "../index.js"),
  "utf8"
);

function extractFunction() {
  const match = source.match(
    /exports\.markMarketplaceCheckoutFailed[\s\S]*?\n\);\n/
  );
  assert.ok(match, "markMarketplaceCheckoutFailed export not found");
  return match[0];
}

test("rejects unauthenticated requests", () => {
  const fn = extractFunction();
  assert.match(fn, /if \(!auth\?\.uid\)[\s\S]*?"unauthenticated"/);
});

test("rejects a caller who does not own the order (wrong buyer)", () => {
  const fn = extractFunction();
  assert.match(
    fn,
    /buyerUid !== auth\.uid[\s\S]*?"permission-denied"/
  );
});

test("reads buyer identity from buyerUid with a userId fallback", () => {
  const fn = extractFunction();
  assert.match(
    fn,
    /const buyerUid = orderData\.buyerUid \|\| orderData\.userId \|\| null;/
  );
});

test("never downgrades an already-paid order", () => {
  const fn = extractFunction();
  assert.match(
    fn,
    /isAlreadyPaid =\s*\n?\s*currentStatus === "paid" \|\| currentPaymentStatus === "paid"/
  );
  assert.match(
    fn,
    /if \(isAlreadyPaid\) {\s*\n\s*return { skipped: true, updatedSellerOrderCount: 0 };/
  );
  assert.match(fn, /marketplace_checkout_failed_mark_skipped_paid/);
});

test("marks a pending order payment_failed with the expected fields", () => {
  const fn = extractFunction();
  const rootWrite = fn.match(
    /transaction\.set\(\s*orderRef,[\s\S]*?{ merge: true }\s*\);/
  );
  assert.ok(rootWrite, "root order write not found");
  assert.match(rootWrite[0], /status: "payment_failed"/);
  assert.match(rootWrite[0], /paymentStatus: "failed"/);
  assert.match(rootWrite[0], /status: "failed",\s*\n\s*failureReason: reason,/);
  assert.match(rootWrite[0], /failedAt: now,/);
  assert.match(rootWrite[0], /updatedAt: now,/);
  // The write must be a genuinely nested `payment` object under
  // {merge:true}, never a dotted "payment.status" key (the class of bug
  // fixed earlier in the payout engine for the same Firestore SDK
  // semantics: set(data, {merge:true}) treats dotted string keys as
  // literal field names, not nested paths).
  assert.doesNotMatch(fn, /"payment\.status"/);
  assert.doesNotMatch(fn, /"payment\.failureReason"/);
  assert.doesNotMatch(fn, /"payment\.failedAt"/);
});

test("finds associated seller orders via rootOrderId and skips already-paid ones", () => {
  const fn = extractFunction();
  assert.match(
    fn,
    /collection\("sellerOrders"\)\s*\n\s*\.where\("rootOrderId", "==", orderId\)/
  );
  assert.match(fn, /if \(sellerIsPaid\) continue;/);
  const sellerWrite = fn.match(
    /transaction\.set\(\s*doc\.ref,[\s\S]*?{ merge: true }\s*\);/
  );
  assert.ok(sellerWrite, "seller order write not found");
  assert.match(sellerWrite[0], /status: "payment_failed"/);
  assert.match(sellerWrite[0], /paymentStatus: "failed"/);
});

test("reads and writes happen inside a single transaction (idempotent, atomic)", () => {
  const fn = extractFunction();
  assert.match(fn, /db\.runTransaction\(async \(transaction\) => {/);
  // Both reads (order + seller orders query) must appear before any
  // transaction.set call, per Firestore's read-before-write rule.
  const firstSet = fn.indexOf("transaction.set(");
  const sellerOrdersRead = fn.indexOf(
    'const sellerOrdersSnap = await transaction.get(sellerOrdersQuery);'
  );
  assert.ok(sellerOrdersRead >= 0);
  assert.ok(firstSet > sellerOrdersRead);
});

test("never deletes the cart, orders, or seller orders", () => {
  const fn = extractFunction();
  assert.doesNotMatch(fn, /\.delete\(/);
  assert.doesNotMatch(fn, /collection\("users"\)/);
  assert.doesNotMatch(fn, /collection\("cart"\)/);
});

test("logs the three required lifecycle events", () => {
  const fn = extractFunction();
  assert.match(fn, /marketplace_checkout_failed_mark_started/);
  assert.match(fn, /marketplace_checkout_failed_mark_completed/);
  assert.match(fn, /marketplace_checkout_failed_mark_skipped_paid/);
});

test("normalizes the reason with a bounded fallback", () => {
  const helper = source.match(
    /function normalizeCheckoutFailureReason\([\s\S]*?\n}/
  );
  assert.ok(helper);
  assert.match(helper[0], /reason \? reason\.slice\(0, 200\) : "unknown"/);
});

test("checkout_page.dart calls markMarketplaceCheckoutFailed only on isbank_cancel and verified failure, not on paid", () => {
  const checkoutPageSource = fs.readFileSync(
    path.resolve(__dirname, "../../lib/ui/checkout/checkout_page.dart"),
    "utf8"
  );

  assert.match(
    checkoutPageSource,
    /checkoutResult == 'isbank_cancel'\) {\s*\n\s*await _markMarketplaceCheckoutFailed\(orderId, reason: 'isbank_cancel'\);/
  );
  assert.match(
    checkoutPageSource,
    /else if \(failed\) {\s*\n\s*await _markMarketplaceCheckoutFailed\(\s*\n\s*orderId,\s*\n\s*reason: 'isbank_verification_failed',/
  );

  // The `paid` success branch must not call the failure marker.
  const paidBranch = checkoutPageSource.match(
    /if \(paid\) {[\s\S]*?} else if \(failed\)/
  );
  assert.ok(paidBranch);
  assert.doesNotMatch(paidBranch[0], /_markMarketplaceCheckoutFailed/);
});
