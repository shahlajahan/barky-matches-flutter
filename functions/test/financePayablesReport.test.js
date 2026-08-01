"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  buildReport,
  normalizedStatus,
  classifyStorageFailure,
  downloadFinancePayablesReport,
  isStaleBillingClosedError,
  TEXT,
} = require("../finance/financePayablesReport");

test("finance report separates verified and repair-required records", () => {
  const indexes = [
    {
      indexId: "sellerOrders__waiting",
      sourceCollection: "sellerOrders",
      sourceDocumentId: "waiting",
      businessId: "peteriumvet",
      businessName: "peteriumvet",
      sector: "vet",
      grossAmount: 180,
      commissionAmount: 160,
      amount: 20,
      currency: "TRY",
      commissionDataQuality: "verified_snapshot",
      settlementStatus: "completed",
      payoutStatus: "pending",
      eligibilityStatus: "waiting_period",
      eligibilityDate: new Date("2026-08-18"),
    },
    {
      indexId: "sellerOrders__unknown",
      sourceCollection: "sellerOrders",
      sourceDocumentId: "unknown",
      businessId: "repair-seller",
      businessName: "Repair Seller",
      sector: "petshop",
      grossAmount: 50,
      amount: 50,
      currency: "TRY",
      commissionDataQuality: "missing_snapshot",
      settlementStatus: "completed",
      payoutStatus: "pending",
      eligibilityStatus: "waiting_period",
    },
  ];
  const report = buildReport({
    indexes,
    sources: new Map(),
    labels: TEXT.en,
    filters: { currency: "TRY" },
    generatedBy: "admin-1",
    fullIban: false,
  });

  assert.equal(report.transactions.length, 2);
  assert.equal(report.sellers.length, 2);
  assert.equal(report.transactions[0].sellerNet, 20);
  assert.equal(report.transactions[1].sellerNet, null);
  assert.equal(report.transactions[1].commissionDisplay, "UNKNOWN");
  assert.equal(report.transactions[1].sellerNetDisplay, "NOT CALCULATED");
  assert.equal(report.totals.customerPaid, 230);
  assert.equal(report.totals.commission, 160);
  assert.equal(report.totals.sellerNet, 20);
});

test("finance report status precedence keeps paid and repair records distinct", () => {
  assert.equal(
    normalizedStatus({
      commissionDataQuality: "missing_snapshot",
      payoutStatus: "paid",
      sourceStatus: "paid",
    }),
    "requires_repair",
  );
  assert.equal(
    normalizedStatus({
      commissionDataQuality: "missing_snapshot",
      payoutStatus: "pending",
      settlementStatus: "completed",
    }),
    "requires_repair",
  );
});

test("finance report storage failures expose structured causes", () => {
  const error = classifyStorageFailure(
    new Error("The billing account for the owning project is disabled in state closed"),
    "upload",
    "finance-reports/report/file.xlsx",
  );
  assert.equal(error.code, "failed-precondition");
  assert.equal(error.details.code, "STORAGE_BILLING_DISABLED");
  assert.equal(error.details.retryable, false);
  assert.match(error.details.message, /billing account/i);
});

function fakeReportDb({ index = {}, source = {} } = {}) {
  const reportData = {
    reportId: "report-1",
    generatedBy: "operator-1",
    fullIban: false,
    filters: { currency: "TRY" },
    files: [{
      reportId: "report-1",
      language: "en",
      fileName: "report.xlsx",
      storagePath: "finance-reports/report-1/report.xlsx",
      fileSize: 1024,
      checksum: "stored-checksum",
    }],
  };
  const reportRef = {
    collection: () => ({ add: async () => {} }),
  };
  const collections = {
    financeReportRuns: {
      doc: () => ({ get: async () => ({ exists: true, data: () => reportData, ref: reportRef }) }),
    },
    payoutIndex: {
      get: async () => ({ docs: [{ id: "sellerOrders__order-1", data: () => index }] }),
    },
    sellerOrders: { doc: () => ({}) },
  };
  return {
    collection: (name) => collections[name],
    getAll: async (...refs) => refs.map((ref) => ({
      ref: { parent: { id: "sellerOrders" }, id: "order-1" },
      exists: true,
      data: () => source,
    })),
  };
}

function fakeBucket({ staleBilling = false, signedUrl = "https://example.test/report" } = {}) {
  return {
    file: () => ({
      getMetadata: async () => {
        if (staleBilling) {
          const error = new Error("The billing account for the owning project is disabled in state closed");
          error.code = 403;
          throw error;
        }
        return [{}];
      },
      getSignedUrl: async () => [signedUrl],
    }),
  };
}

const verifiedIndex = {
  sourceCollection: "sellerOrders",
  sourceDocumentId: "order-1",
  businessId: "seller-1",
  businessName: "Seller One",
  sector: "petshop",
  grossAmount: 10,
  commissionAmount: 1,
  amount: 9,
  currency: "TRY",
  commissionDataQuality: "verified_snapshot",
  settlementStatus: "completed",
  payoutStatus: "pending",
  eligibilityStatus: "eligible",
};

test("finance report uses signed URL when Storage is healthy", async () => {
  const result = await downloadFinancePayablesReport({
    db: fakeReportDb({ index: verifiedIndex }),
    bucket: fakeBucket(),
    adminUid: "operator-1",
    reportId: "report-1",
    language: "en",
  });
  assert.equal(result.deliveryMode, undefined);
  assert.equal(result.url, "https://example.test/report");
});

test("finance report falls back to inline bytes for stale billing 403", async () => {
  assert.equal(
    isStaleBillingClosedError(Object.assign(new Error("The billing account for the owning project is disabled in state closed"), { code: 403 })),
    true,
  );
  const result = await downloadFinancePayablesReport({
    db: fakeReportDb({ index: verifiedIndex }),
    bucket: fakeBucket({ staleBilling: true }),
    adminUid: "operator-1",
    reportId: "report-1",
    language: "en",
  });
  assert.equal(result.deliveryMode, "inline_base64");
  assert.equal(result.temporaryFallback, true);
  assert.ok(result.bytesBase64.length > 0);
  assert.equal(result.url, null);
});

test("finance report rejects inline fallback above 5 MB", async () => {
  const db = fakeReportDb({ index: verifiedIndex });
  const originalGet = db.collection("financeReportRuns").doc().get;
  db.collection("financeReportRuns").doc = () => ({
    get: async () => {
      const snapshot = await originalGet();
      const data = snapshot.data();
      data.files[0].fileSize = 5 * 1024 * 1024 + 1;
      return { ...snapshot, data: () => data };
    },
  });
  await assert.rejects(
    () => downloadFinancePayablesReport({
      db,
      bucket: fakeBucket({ staleBilling: true }),
      adminUid: "operator-1",
      reportId: "report-1",
      language: "en",
    }),
    (error) => error.details?.code === "FINANCE_REPORT_TEMPORARY_FALLBACK_SIZE_LIMIT",
  );
});

test("full IBAN report requires Finance operate permission", async () => {
  const db = fakeReportDb({ index: verifiedIndex });
  const originalGet = db.collection("financeReportRuns").doc().get;
  db.collection("financeReportRuns").doc = () => ({
    get: async () => {
      const snapshot = await originalGet();
      const data = snapshot.data();
      data.fullIban = true;
      return { ...snapshot, data: () => data };
    },
  });
  await assert.rejects(
    () => downloadFinancePayablesReport({
      db,
      bucket: fakeBucket(),
      adminUid: "viewer-1",
      reportId: "report-1",
      language: "en",
      fullIban: false,
    }),
    (error) => error.code === "permission-denied",
  );
});
