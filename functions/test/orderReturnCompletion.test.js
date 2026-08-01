"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
  path.resolve(__dirname, "../index.js"),
  "utf8"
);

test("buyer ship-back starts the seller inspection deadline", () => {
  assert.match(source, /status: "waiting_for_seller_confirmation"/);
  assert.match(source, /buyerShippedAt,/);
  assert.match(source, /sellerConfirmationDeadlineAt,/);
  assert.match(source, /Date\.now\(\) \+ 5 \* 24 \* 60 \* 60 \* 1000/);
});

test("seller confirmation records inspection completion", () => {
  assert.match(
    source,
    /sellerInspectionCompletedAt:\s*\n?\s*admin\.firestore\.FieldValue\.serverTimestamp\(\)/
  );
  assert.match(
    source,
    /"waiting_for_seller_confirmation",\s*\n?\s*\]\.includes\(currentStatus\)/
  );
});

test("dispute requires a standard reason and blocks normal refund statuses", () => {
  assert.match(source, /exports\.reportOrderReturnProblem = onCall/);
  assert.match(source, /status: "dispute"/);
  assert.match(source, /disputeReasonCode,/);
  assert.match(source, /disputedAt,/);
  const refundCallable = source.match(
    /exports\.triggerOrderReturnRefund = onCall\([\s\S]*?\/\/ Backward-compatible aliases/
  );
  assert.ok(refundCallable);
  assert.match(refundCallable[0], /"received_by_seller"/);
  assert.match(refundCallable[0], /"auto_received"/);
  assert.match(refundCallable[0], /"refund_failed"/);
  assert.match(refundCallable[0], /Return must be received before refund/);
});

test("scheduler transactionally auto-completes overdue waiting returns", () => {
  assert.match(source, /exports\.autoCompleteOverdueOrderReturns = onSchedule/);
  assert.match(source, /schedule: "every 6 hours"/);
  assert.match(source, /where\("sellerConfirmationDeadlineAt", "<", now\)/);
  assert.match(source, /await db\.runTransaction/);
  assert.match(source, /status: "auto_received"/);
  assert.match(source, /autoReceived: true/);
  assert.match(source, /autoReceivedAt,/);
});

test("auto-received returns reuse the existing refund callable", () => {
  const refundCallable = source.match(
    /exports\.triggerOrderReturnRefund = onCall\([\s\S]*?\/\/ Backward-compatible aliases/
  );
  assert.ok(refundCallable);
  assert.match(refundCallable[0], /"auto_received"/);
  assert.match(refundCallable[0], /refundWithIyzipay/);
  assert.match(refundCallable[0], /refundWithIsbank/);
});

test("seller and buyer lifecycle notifications are emitted", () => {
  assert.match(source, /type: "order_return_shipped_back"/);
  assert.match(source, /type: "order_return_received"/);
  assert.match(source, /type: "order_return_disputed"/);
  assert.match(source, /type: "order_return_auto_received"/);
});
