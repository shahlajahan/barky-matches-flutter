"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = fs.readFileSync(
  path.resolve(__dirname, "../index.js"),
  "utf8"
);

function cancellationSource() {
  const match = source.match(
    /exports\.cancelSellerOrderBeforeShipment = onCall\([\s\S]*?\n\);\n\n\nfunction extractInvoiceNumber/
  );
  assert.ok(match, "cancellation callable must exist");
  return match[0];
}

test("pre-shipment cancellation accepts only paid, confirmed, and preparing", () => {
  const callable = cancellationSource();
  assert.match(
    callable,
    /const eligibleStatuses = \[\s*"paid",\s*"confirmed",\s*"preparing",/
  );
  assert.match(callable, /freshData\.shipping\?\.shippedAt/);
  assert.match(
    callable,
    /Order can no longer be cancelled because shipment has started/
  );
});

test("cancellation and shipment claims are transactionally serialized", () => {
  const callable = cancellationSource();
  assert.match(callable, /db\.runTransaction\(async \(transaction\)/);
  assert.match(callable, /transaction\.get\(sellerOrderRef\)/);

  const shipment = source.match(
    /exports\.updateSellerOrderStatusV2 = onCall\([\s\S]*?exports\.cancelSellerOrderBeforeShipment/
  );
  assert.ok(shipment);
  assert.match(shipment[0], /db\.runTransaction\(async \(transaction\)/);
  assert.match(shipment[0], /freshShipping\.shippedAt/);
});

test("cancellation stores audit fields and an idempotent refund state", () => {
  const callable = cancellationSource();
  for (const field of [
    "cancellationRequestedAt",
    "cancelledAt",
    "cancelledBy",
    "cancelReason",
    "cancellationType",
    "cancellationRefund",
  ]) {
    assert.match(callable, new RegExp(field));
  }
  assert.match(callable, /freshStatus === "cancelled"/);
  assert.match(callable, /refundStatus === "refunded"/);
});

test("cancellation reuses refund providers and emits notifications", () => {
  const callable = cancellationSource();
  assert.match(callable, /refundWithIyzipay\(/);
  assert.match(callable, /refundWithIsbank\(/);
  assert.match(callable, /order_cancelled_before_shipment/);
  assert.match(callable, /order_cancellation_refund_processing/);
  assert.match(callable, /order_cancellation_refunded/);
});

test("seller cancellation notification requires an Auth UID", () => {
  const callable = cancellationSource();
  assert.match(
    callable,
    /const sellerRecipientUid =\s*initialOrder\.sellerUid \|\| initialOrder\.sellerSnapshot\?\.ownerUid \|\| null;/
  );
  assert.match(callable, /if \(sellerRecipientUid\) \{[\s\S]*?recipientUserId: sellerRecipientUid/);
  assert.doesNotMatch(
    callable,
    /order_cancelled_before_shipment[\s\S]*?initialOrder\.shopId/
  );
  assert.match(callable, /missing_seller_auth_uid/);
  assert.match(callable, /await Promise\.allSettled\(notificationPromises\)/);
  assert.match(callable, /let gatewaySucceeded = false;/);
});

test("completed cancellation refunds buyer gross and reconciles payout", () => {
  const callable = cancellationSource();
  assert.match(callable, /initialOrder\?\.pricing\?\.grandTotal/);
  assert.doesNotMatch(
    callable,
    /refundAmount\s*=\s*[\s\S]{0,180}(businessNetAmount|sellerNetAmount|businessReceivable|payout\?\.amount)/
  );
  assert.match(callable, /applyRefundToSellerPayout\(\{/);
  assert.match(callable, /returnId: `cancel_\$\{sellerOrderId\}`/);
  assert.match(callable, /isFullRefund: true/);
  assert.match(callable, /pre_shipment_cancellation_refund/);
  assert.match(
    callable,
    /claimResult\.status === "alreadyRefunded"[\s\S]*?applyRefundToSellerPayout/
  );
  assert.match(callable, /writeCanonicalCancellationRefund\(\{/);
  assert.doesNotMatch(callable, /"cancellationRefund\.status"\s*:/);
  assert.doesNotMatch(callable, /"cancellationRefund\.amount"\s*:/);
  assert.doesNotMatch(callable, /"cancellationRefund\.completedAt"\s*:/);
});

test("all cancellation refund lifecycle updates use one nested canonical state", () => {
  const callable = cancellationSource();
  assert.match(callable, /refundPatch:\s*\{[\s\S]*status:\s*"refunded"/);
  assert.match(callable, /refundPatch:\s*\{[\s\S]*status:\s*"refund_failed"/);
  assert.match(
    callable,
    /gatewaySucceeded && !refundPersisted[\s\S]*?refundPatch:\s*\{[\s\S]*status:\s*"refunded"/
  );
  assert.doesNotMatch(callable, /"cancellationRefund\.[^"]+"\s*:/);
});

test("existing return workflow remains separate", () => {
  assert.match(source, /exports\.createOrderReturnRequest = onCall\(/);
  assert.match(source, /exports\.triggerOrderReturnRefund = onCall\(/);
  assert.doesNotMatch(
    cancellationSource(),
    /createOrderReturnRequest|triggerOrderReturnRefund/
  );
});
