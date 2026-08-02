"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  permissionsForUser,
  FINANCE_PERMISSION,
  resolveFinanceAuthorization,
} = require("../finance/financePermissions");
const {
  cents,
  ledgerEntryId,
  ledgerEntry,
} = require("../finance/financeLedger");
const {
  summarizeFinanceRecords,
} = require("../finance/financeSummaryProjector");
const {
  buildCanonicalFinancialSnapshot,
} = require("../commission/paymentFinancialSnapshot");
const {
  aggregatePayoutRecords,
} = require("../payout/payoutAggregation");
const {
  frozenBatchChecksum,
} = require("../payout/payoutBatchService");
const {
  getFinanceExporter,
} = require("../finance/exporters");
const {
  getExecutionProvider,
} = require("../finance/executionProviders");
const {
  sanitizeFilters,
} = require("../finance/savedFinanceFilters");

test("finance roles enforce viewer/operator/manager separation", () => {
  assert.deepEqual(
    [...permissionsForUser({ role: "finance_viewer" })],
    [FINANCE_PERMISSION.VIEW]
  );
  assert.equal(
    permissionsForUser({ role: "finance_operator" }).has(
      FINANCE_PERMISSION.APPROVE
    ),
    false
  );
  assert.equal(
    permissionsForUser({ role: "finance_manager" }).has(
      FINANCE_PERMISSION.MANAGE
    ),
    true
  );
  assert.equal(
    permissionsForUser({ role: "admin" }).has(FINANCE_PERMISSION.VIEW),
    true
  );
  assert.equal(
    permissionsForUser({ role: "admin" }).has(FINANCE_PERMISSION.OPERATE),
    false
  );
  assert.equal(
    permissionsForUser(
      { role: "admin" },
      { financePermissions: [FINANCE_PERMISSION.OPERATE] }
    ).has(FINANCE_PERMISSION.OPERATE),
    true
  );
});

test("finance authorization resolves Admin view separately from explicit operation", async () => {
  const db = {
    collection: () => ({
      doc: () => ({
        get: async () => ({ exists: true, data: () => ({ role: "admin" }) }),
      }),
    }),
  };
  const admin = await resolveFinanceAuthorization(db, {
    auth: { uid: "admin-1", token: {} },
  });
  assert.equal(admin.isAdmin, true);
  assert.equal(admin.hasFinanceView, true);
  assert.equal(admin.hasFinanceOperate, false);

  const operator = await resolveFinanceAuthorization(db, {
    auth: {
      uid: "admin-1",
      token: { financePermissions: [FINANCE_PERMISSION.OPERATE] },
    },
  });
  assert.equal(operator.hasFinanceOperate, true);
});

test("ledger IDs are deterministic and money is integer cents", () => {
  const data = {
    eventType: "manual_adjustment",
    sourceCollection: "financeAdjustments",
    sourceDocumentId: "a-1",
    businessId: "b-1",
    amount: 4.455,
    currency: "try",
    direction: "credit",
    idempotencyKey: "a-1",
  };
  assert.equal(ledgerEntryId(data), ledgerEntryId({ ...data }));
  assert.equal(cents(4.455), 446);
  const entry = ledgerEntry(data);
  assert.equal(entry.amountCents, 446);
  assert.equal(entry.currency, "TRY");
});

test("canonical summaries isolate waiting, eligible, hold and paid values", () => {
  const now = Date.parse("2026-07-30T09:00:00Z");
  const summary = summarizeFinanceRecords(
    [
      {
        eligibilityStatus: "waiting_period",
        commissionDataQuality: "verified_snapshot",
        settlementStatus: "completed",
        amount: 10,
        successfulPaymentAt: new Date("2026-07-20T09:00:00Z"),
        eligibilityDate: new Date("2026-08-10T21:00:00Z"),
      },
      {
        eligibilityStatus: "eligible",
        commissionDataQuality: "verified_snapshot",
        settlementStatus: "completed",
        amount: 20,
        grossAmount: 25,
        commissionAmount: 5,
      },
      { eligibilityStatus: "on_hold", amount: 7, commissionDataQuality: "verified_snapshot" },
      {
        eligibilityStatus: "paid",
        commissionDataQuality: "verified_snapshot",
        amount: 8,
        paidAt: new Date("2026-07-29T09:00:00Z"),
        paymentReference: "BANK-1",
      },
    ],
    { nowMillis: now }
  );
  assert.deepEqual(summary.waiting, { count: 1, amount: 10 });
  assert.deepEqual(summary.available, { count: 1, amount: 20 });
  assert.deepEqual(summary.onHold, { count: 1, amount: 7 });
  assert.equal(summary.eligibleGrossAmount, 25);
  assert.equal(summary.eligibleCommissionAmount, 5);
  assert.equal(summary.daysRemaining, 12);
  assert.equal(summary.payoutHistory[0].reference, "BANK-1");
});

test("revenue projection uses paid gross snapshots, not payout buckets", () => {
  const summary = summarizeFinanceRecords([
    { successfulPaymentAt: new Date(), sourceStatus: "paid", grossAmount: 100, commissionAmount: 12, amount: 88, eligibilityStatus: "waiting_period", commissionDataQuality: "verified_snapshot" },
    { successfulPaymentAt: new Date(), sourceStatus: "paid", grossAmount: 50, commissionAmount: 6, amount: 44, eligibilityStatus: "eligible", commissionDataQuality: "verified_snapshot" },
    { successfulPaymentAt: null, sourceStatus: "pending", grossAmount: 999, commissionAmount: 99, amount: 900, eligibilityStatus: "waiting_period", commissionDataQuality: "verified_snapshot" },
  ]);
  assert.equal(summary.revenue.grossSales, 150);
  assert.equal(summary.revenue.platformFee, 18);
  assert.equal(summary.revenue.netRevenue, 132);
  assert.equal(summary.revenue.paidRecordCount, 2);
  assert.equal(summary.revenue.averageTicket, 75);
  assert.equal(summary.revenue.trend.length, 1);
  assert.equal(summary.revenue.trend[0].grossRevenue, 150);
  assert.equal(summary.revenue.trend[0].platformFee, 18);
  assert.equal(summary.revenue.trend[0].netRevenue, 132);
  assert.equal(summary.revenue.trend[0].paymentCount, 2);
});

test("commission-unknown records are exception-only and excluded from forecasts", () => {
  const summary = summarizeFinanceRecords([
    {
      eligibilityStatus: "waiting_period",
      commissionDataQuality: "ambiguous_legacy",
      settlementStatus: "completed",
      amount: 290.90,
      grossAmount: 300,
      commissionAmount: 0,
      eligibilityDate: new Date("2026-08-05T00:00:00Z"),
      successfulPaymentAt: new Date("2026-07-20T00:00:00Z"),
    },
  ], { nowMillis: Date.parse("2026-07-30T00:00:00Z") });
  assert.deepEqual(summary.waiting, { count: 0, amount: 0 });
  assert.deepEqual(summary.available, { count: 0, amount: 0 });
  assert.deepEqual(summary.commissionUnknown, { count: 1, amount: 290.9 });
  assert.equal(summary.amountBecomingEligibleNext, 0);
  assert.equal(summary.countBecomingEligibleNext, 0);
  assert.equal(summary.exceptions.length, 1);
  assert.equal(summary.revenue.grossSales, 0);
});

test("canonical snapshot preserves rule identity for every monetized sector", () => {
  for (const sector of ["petshop", "vet", "groomy", "hotel", "taxi"]) {
    const snapshot = buildCanonicalFinancialSnapshot({
      currency: "TRY",
      financial: {
        finalPrice: 100,
        grossAmount: 100,
        commissionAmount: 12,
        businessNetAmount: 88,
        sellerNetAmount: 88,
        commissionType: "percentage",
        commissionRate: 12,
        ruleSnapshot: { ruleId: `${sector}_default`, configVersion: 1 },
      },
      calculationInputs: { sector },
    });
    assert.equal(snapshot.commissionDataQuality, "verified_snapshot");
    assert.equal(snapshot.grossAmount, 100);
    assert.equal(snapshot.commissionAmount, 12);
    assert.equal(snapshot.sellerNetAmount, 88);
    assert.equal(snapshot.commissionRuleId, `${sector}_default`);
    assert.equal(snapshot.commissionRuleVersion, "1");
    assert.equal(snapshot.pricingRuleVersion, "1");
    assert.equal(snapshot.commissionCalculationVersion, "1");
    assert.equal(snapshot.currency, "TRY");
  }
});

test("explicit zero commission remains verified only with rule evidence", () => {
  const valid = buildCanonicalFinancialSnapshot({
    currency: "TRY",
    financial: {
      finalPrice: 100,
      grossAmount: 100,
      commissionAmount: 0,
      businessNetAmount: 100,
      sellerNetAmount: 100,
      commissionModel: "zero",
      commissionRate: 0,
      commissionFixedAmount: 0,
      ruleSnapshot: { ruleId: "zero_rule", configVersion: 2 },
    },
  });
  assert.equal(valid.commissionDataQuality, "verified_snapshot");
  const unknown = buildCanonicalFinancialSnapshot({
    currency: "TRY",
    financial: {
      finalPrice: 100,
      grossAmount: 100,
      commissionAmount: 0,
      businessNetAmount: 100,
      sellerNetAmount: 100,
    },
  });
  assert.equal(unknown.commissionDataQuality, "commission_unknown");
});

test("null commission amounts cannot become verified zero values", () => {
  const snapshot = buildCanonicalFinancialSnapshot({
    currency: "TRY",
    financial: {
      finalPrice: 100,
      grossAmount: 100,
      commissionAmount: null,
      businessNetAmount: 100,
      sellerNetAmount: 100,
      commissionModel: "zero",
      commissionRate: 0,
      commissionFixedAmount: 0,
      ruleSnapshot: { ruleId: "zero_rule", configVersion: 2 },
    },
  });
  assert.equal(snapshot.commissionAmount, 0);
  assert.equal(snapshot.commissionDataQuality, "commission_unknown");
});

test("seller aggregation isolates currencies and legal recipients", () => {
  const base = {
    businessId: "b-1",
    businessName: "Seller",
    accountHolderName: "Seller Ltd",
    iban: "TR123456789012345678901234",
    bankName: "Bank",
    payoutStatus: "pending",
    settlementStatus: "completed",
    eligibilityStatus: "eligible",
    amount: 10,
  };
  const groups = aggregatePayoutRecords([
    { ...base, id: "try", currency: "TRY" },
    { ...base, id: "eur", currency: "EUR" },
    { ...base, id: "other", currency: "TRY", accountHolderName: "Other Ltd" },
  ]);
  assert.equal(groups.length, 3);
});

test("frozen snapshot hash covers money, records, bank and version", () => {
  const batch = {
    batchNumber: "PB-1",
    version: 1,
    projectionVersion: 3,
    snapshotTimestamp: new Date("2026-07-30T00:00:00Z"),
    currency: "TRY",
    sellerCount: 1,
    payoutRecordCount: 1,
    grossTotal: 100,
    commissionTotal: 12,
    netTotal: 88,
  };
  const item = {
    businessId: "b-1",
    iban: "TR123456789012345678901234",
    accountHolderName: "Seller",
    bankName: "Bank",
    grossTotal: 100,
    commissionTotal: 12,
    netTotal: 88,
    payoutIndexIds: ["p-1"],
  };
  const hash = frozenBatchChecksum({ batch, items: [item] });
  assert.notEqual(
    hash,
    frozenBatchChecksum({
      batch,
      items: [{ ...item, iban: "TR999999999999999999999999" }],
    })
  );
  assert.notEqual(
    hash,
    frozenBatchChecksum({ batch: { ...batch, version: 2 }, items: [item] })
  );
});

test("export and execution providers are independently pluggable", () => {
  assert.equal(getFinanceExporter("xlsx").extension, "xlsx");
  assert.equal(getExecutionProvider("manual_eft").requiresExport, true);
  assert.throws(() => getFinanceExporter("pdf"), /Unsupported/);
});

test("saved finance filters reject arbitrary fields", () => {
  assert.deepEqual(
    sanitizeFilters({
      sector: "petshop",
      minimumAmount: 100,
      adminOverride: true,
    }),
    { sector: "petshop", minimumAmount: 100 }
  );
});

test("batch service contains approval, immutable freeze, periods and retry-safe transitions", () => {
  const source = fs.readFileSync(
    path.resolve(__dirname, "../payout/payoutBatchService.js"),
    "utf8"
  );
  assert.match(source, /status: "finance_review"/);
  assert.match(source, /approvedBy: adminUid/);
  assert.match(source, /snapshotHash: checksum/);
  assert.match(source, /accountingPeriodId: periodRef\.id/);
  assert.match(source, /Only frozen Draft or Invalidated batches can be versioned/);
  assert.match(source, /if \(item\.status === "paid"\)/);
  assert.match(source, /async function markPayoutBatchItemFailed/);
  assert.match(source, /failedItemCount/);
});
