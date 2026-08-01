"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const {
  FINANCIAL_STATUS,
  isVerifiedFinancial,
  financialStatusFor,
} = require("../finance/paymentIntegrity");

test("financial state is separate from provider payment state", () => {
  assert.equal(FINANCIAL_STATUS.PENDING, "pending");
  assert.equal(FINANCIAL_STATUS.VERIFIED, "verified");
  assert.equal(FINANCIAL_STATUS.REQUIRES_REPAIR, "requires_repair");
  assert.equal(
    financialStatusFor({ commissionDataQuality: "verified_snapshot" }),
    FINANCIAL_STATUS.VERIFIED
  );
  assert.equal(
    financialStatusFor({ commissionDataQuality: "commission_unknown" }),
    FINANCIAL_STATUS.REQUIRES_REPAIR
  );
  assert.equal(
    isVerifiedFinancial({ financialStatus: FINANCIAL_STATUS.REQUIRES_REPAIR }),
    false
  );
});

test("payment finalizers persist paid state before financial validation", () => {
  const source = fs.readFileSync(
    path.resolve(__dirname, "../index.js"),
    "utf8"
  );
  const taxi = source.match(
    /exports\.verifyPetTaxiPayment = onCall\([\s\S]*?\n\);/
  )?.[0];
  assert.ok(taxi);
  assert.match(taxi, /paymentStatus: "paid"/);
  assert.match(taxi, /financialStatus: FINANCIAL_STATUS\.PENDING/);
  assert.match(taxi, /financialStatus: financial/);
  assert.match(taxi, /FINANCIAL_REPAIR_REQUIRED/);
  assert.match(taxi, /if \(!financialError\)/);

  const settlement = fs.readFileSync(
    path.resolve(__dirname, "../settlement/settlementFinalizer.js"),
    "utf8"
  );
  assert.match(settlement, /financialRepairRequired/);
  assert.match(settlement, /FINANCIAL_REPAIR_REQUIRED/);
});
