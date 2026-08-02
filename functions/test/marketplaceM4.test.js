"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const indexSource = fs.readFileSync(path.resolve(__dirname, "../index.js"), "utf8");
const inventorySource = fs.readFileSync(
  path.resolve(__dirname, "../src/inventory/inventoryPaymentCoordinator.js"),
  "utf8"
);
const claimsSource = fs.readFileSync(
  path.resolve(__dirname, "../src/inventory/paymentCallbackClaims.js"),
  "utf8"
);

test("M4 wires both marketplace payment paths through durable callback claims", () => {
  assert.match(indexSource, /provider: "isbank"[\s\S]*claimPaymentCallback/);
  assert.match(indexSource, /provider: "iyzico"[\s\S]*claimPaymentCallback/);
  assert.match(claimsSource, /paymentCallbackClaims/);
  assert.match(claimsSource, /status: "processing"/);
  assert.match(claimsSource, /status === "completed"/);
  assert.match(indexSource, /providerEventId:/);
  assert.match(indexSource, /amount:/);
  assert.match(indexSource, /currency:/);
  assert.match(claimsSource, /providerEventIds/);
});

test("M4 commits only through the provider-independent inventory coordinator", () => {
  assert.match(inventorySource, /commitInventory\(/);
  assert.match(indexSource, /commitVerifiedMarketplaceInventory/);
  assert.match(inventorySource, /status: "commit_pending"/);
  assert.doesNotMatch(indexSource, /stock\s*:\s*admin\.firestore\.FieldValue\.increment/);
  assert.doesNotMatch(indexSource, /reservedStock\s*:\s*admin\.firestore\.FieldValue\.increment/);
});

test("M4 requires an explicit inventory marker and immutable line set", () => {
  assert.match(inventorySource, /inventorySchemaVersion/);
  assert.match(inventorySource, /inventoryLineSet/);
  assert.match(inventorySource, /canonical_line_set_conflict/);
  assert.match(inventorySource, /payment_evidence_conflict/);
  assert.match(indexSource, /inventoryLineSet:/);
});

test("M4 defers managed settlement until after commit", () => {
  assert.match(indexSource, /deferMarketplacePaymentState/);
  assert.match(indexSource, /settleCommittedMarketplaceSellerOrders/);
  const commit = indexSource.indexOf("commitVerifiedMarketplaceInventory");
  const settlement = indexSource.indexOf("settleCommittedMarketplaceSellerOrders", commit);
  assert.ok(commit >= 0);
  assert.ok(settlement > commit);
});

test("M4 preserves terminal verified payment state", () => {
  assert.match(indexSource, /hasVerifiedProviderPayment/);
  assert.match(indexSource, /isbank_late_failure_ignored_after_verified_success/);
  assert.match(indexSource, /if \(!success\)[\s\S]*hasVerifiedProviderPayment\(latestOrderData\)/);
  assert.match(indexSource, /latest\.settlementStatus === "settlement_pending"/);
});

test("M4 preserves settlement recovery and deterministic settlement identity", () => {
  assert.match(indexSource, /settlement_pending/);
  assert.match(indexSource, /markPaymentCallbackSettlementPending/);
  assert.match(indexSource, /markMarketplaceSettlementCompleted/);
  assert.match(indexSource, /operationId: `marketplace-settlement-/);
});

test("M4 records durable second-payment conflicts", () => {
  assert.match(claimsSource, /paymentIdentityConflicts/);
  assert.match(claimsSource, /originalPaymentId/);
  assert.match(claimsSource, /conflictingPaymentId/);
  assert.match(claimsSource, /detectedAt/);
});

test("M4 payment paths do not add return restoration; M5 scheduler is separate", () => {
  const marketplacePayment = indexSource.match(
    /exports\.(?:isbank3DPayHostingCallback|verifyPaymentByOrderId)[\s\S]*?exports\./
  );
  assert.ok(marketplacePayment);
  assert.doesNotMatch(marketplacePayment[0], /restoreReturnedInventory/);
  assert.match(indexSource, /exports\.recoverMarketplaceInventoryM5 = onSchedule/);
});
