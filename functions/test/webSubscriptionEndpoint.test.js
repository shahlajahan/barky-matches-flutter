"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
  path.resolve(__dirname, "../index.js"),
  "utf8"
);

test("checkout and catalog require Firebase Authentication", () => {
  const checkout = source.match(
    /exports\.createWebSubscriptionCheckout[\s\S]*?exports\.readWebSubscriptionPaymentStatus/
  );
  assert.ok(checkout);
  assert.match(checkout[0], /if \(!uid\)[\s\S]*?"unauthenticated"/);

  const catalog = source.match(
    /exports\.getWebSubscriptionCatalog[\s\S]*?exports\.createWebSubscriptionCheckout/
  );
  assert.ok(catalog);
  assert.match(catalog[0], /if \(!request\.auth\?\.uid\)[\s\S]*?"unauthenticated"/);
});

test("Flutter cannot submit amount, currency, user, or expiration", () => {
  const checkout = source.match(
    /exports\.createWebSubscriptionCheckout[\s\S]*?async function finalizeWebSubscriptionPayment/
  );
  assert.ok(checkout);
  assert.match(checkout[0], /request\.data\?\.planId/);
  assert.doesNotMatch(checkout[0], /request\.data\?\.(amount|currency|userId|expiresAt)/);
  assert.match(checkout[0], /webSubscriptionCatalog\(\)\[planId\]/);
});

test("paid callbacks are idempotent before extending entitlement", () => {
  const finalizer = source.match(
    /async function finalizeWebSubscriptionPayment[\s\S]*?exports\.readWebSubscriptionPaymentStatus/
  );
  assert.ok(finalizer);
  assert.match(
    finalizer[0],
    /paymentStatus\) === "paid"[\s\S]*?finalizationStatus === "completed"[\s\S]*?alreadyProcessed/
  );
  assert.match(finalizer[0], /db\.runTransaction/);
});
