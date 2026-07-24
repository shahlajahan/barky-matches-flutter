"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
  path.resolve(__dirname, "../index.js"),
  "utf8"
);

test("callback has access to the Resend secret", () => {
  const callback = source.match(
    /exports\.isbank3DPayHostingCallback[\s\S]*?async \(req, res\)/
  );
  assert.ok(callback);
  assert.match(callback[0], /secrets:\s*\[[\s\S]*?resendApiKey/);
});

test("paid callback retry re-runs only idempotent post-payment effects", () => {
  const alreadyPaid = source.match(
    /if \(existingProvider === "isbank" && existingPaymentStatus === "paid"\)[\s\S]*?Callback already processed/
  );
  assert.ok(alreadyPaid);
  assert.match(alreadyPaid[0], /reconcilePaidMarketplaceCart\(orderId\)/);
  assert.match(alreadyPaid[0], /sendExternalOrderNotifications/);
  assert.doesNotMatch(alreadyPaid[0], /status:\s*"pending"/);
});

test("email dispatch happens after the paid completion transaction", () => {
  const finalizer = source.match(
    /async function finalizeIsbankPaidOrder[\s\S]*?async function markIsbankPaymentFailed/
  );
  assert.ok(finalizer);
  const completionIndex = finalizer[0].indexOf(
    'const completionResult = await db.runTransaction'
  );
  const emailIndex = finalizer[0].indexOf(
    'await sendExternalOrderNotifications'
  );
  assert.ok(completionIndex >= 0);
  assert.ok(emailIndex > completionIndex);
});

test("notification ledger prevents a second sent dispatch", () => {
  const claim = source.match(
    /async function claimExternalNotificationDispatch[\s\S]*?async function markExternalNotificationDispatch/
  );
  assert.ok(claim);
  assert.match(
    claim[0],
    /existing\?\.state === "sent"[\s\S]*?shouldSend:\s*false/
  );
});

test("email failure is caught after payment has been committed", () => {
  const finalizer = source.match(
    /const completionResult = await db\.runTransaction[\s\S]*?return completionResult;/
  );
  assert.ok(finalizer);
  assert.match(
    finalizer[0],
    /catch \(error\)[\s\S]*?isbank_confirmation_email_dispatch_failed/
  );
  assert.doesNotMatch(
    finalizer[0],
    /isbank_confirmation_email_dispatch_failed[\s\S]*?paymentStatus:\s*"pending"/
  );
});
