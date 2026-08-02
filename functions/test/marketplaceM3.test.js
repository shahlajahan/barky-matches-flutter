"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const indexSource = fs.readFileSync(path.resolve(__dirname, "../index.js"), "utf8");
const coordinatorSource = fs.readFileSync(
  path.resolve(__dirname, "../src/inventory/inventoryCheckoutCoordinator.js"),
  "utf8"
);

test("M3 is disabled unless explicitly enabled with a canary allow-list", () => {
  assert.match(coordinatorSource, /M3_INVENTORY_RESERVATION_ENABLED/);
  assert.match(coordinatorSource, /if \(buyers\.length === 0 && businesses\.length === 0\) return false/);
  assert.match(coordinatorSource, /!== "true"\)/);
});

test("checkout creates canonical lines and coordinates before returning", () => {
  assert.match(indexSource, /buildCanonicalLines/);
  assert.match(indexSource, /inventoryLines: shopItems\.map/);
  assert.match(indexSource, /await coordinateCheckoutReservations/);
  assert.match(indexSource, /await batch\.commit\(\);[\s\S]*await updateAttempt\(m3Claim\.ref/);
});

test("M3 does not wire payment commit, returns, or a scheduler", () => {
  const checkout = indexSource.match(
    /exports\.createMarketplaceOrderV2[\s\S]*?exports\.markMarketplaceCheckoutFailed/
  );
  assert.ok(checkout);
  assert.doesNotMatch(checkout[0], /commitInventory/);
  assert.doesNotMatch(checkout[0], /restoreReturnedInventory/);
  assert.doesNotMatch(checkout[0], /onSchedule/);
});

test("M3 keeps the existing response fields", () => {
  const checkout = indexSource.match(
    /exports\.createMarketplaceOrderV2[\s\S]*?exports\.markMarketplaceCheckoutFailed/
  );
  assert.ok(checkout);
  assert.match(checkout[0], /orderId/);
  assert.match(checkout[0], /orderNumber/);
  assert.match(checkout[0], /sellerOrderIds/);
  assert.match(checkout[0], /sellerCount/);
});

