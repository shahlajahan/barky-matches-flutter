"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const ExcelJS = require("exceljs");
const {
  buildPayoutBatchWorkbook,
} = require("../payout/payoutWorkbook");

test("XLSX contains one instruction per seller and one detail row per payout", async () => {
  const batch = {
    batchNumber: "PB-2026-000012",
    currency: "TRY",
    status: "draft",
  };
  const items = [
    {
      businessId: "business-1",
      businessName: "Şirin Patiler",
      legalBusinessName: "Şirin Patiler Ltd.",
      accountHolderName: "Şirin Patiler Ltd.",
      iban: "TR123456789012345678901234",
      bankName: "Türkiye İş Bankası",
      taxNumber: "1234567890",
      contactEmail: "mali@example.com",
      contactPhone: "+905001112233",
      currency: "TRY",
      payoutCount: 2,
      grossTotal: 15.15,
      commissionTotal: 0.6,
      netTotal: 14.55,
      status: "draft",
    },
    {
      businessId: "business-2",
      businessName: "Koray Pet",
      legalBusinessName: "Koray Pet",
      accountHolderName: "Koray Pet",
      iban: "TR987654321098765432109876",
      bankName: "Ziraat Bankası",
      taxNumber: "0987654321",
      contactEmail: "koray@example.com",
      contactPhone: "+905009998877",
      currency: "TRY",
      payoutCount: 1,
      grossTotal: 10.1,
      commissionTotal: 0,
      netTotal: 10.1,
      status: "draft",
    },
  ];
  const details = [
    {
      businessId: "business-1",
      businessName: "Şirin Patiler",
      sourceCollection: "sellerOrders",
      sourceDocumentId: "so-1",
      rootOrderId: "root-1",
      orderNumber: "BM-1",
      grossAmount: 5.05,
      commissionAmount: 0.6,
      amount: 4.45,
      currency: "TRY",
      settlementStatus: "completed",
      payoutStatus: "pending",
      sourceCreatedAt: new Date("2026-07-29"),
      sourceUpdatedAt: new Date("2026-07-30"),
    },
    {
      businessId: "business-1",
      businessName: "Şirin Patiler",
      sourceCollection: "sellerOrders",
      sourceDocumentId: "so-2",
      grossAmount: 10.1,
      commissionAmount: 0,
      amount: 10.1,
      currency: "TRY",
      settlementStatus: "completed",
      payoutStatus: "pending",
    },
    {
      businessId: "business-2",
      businessName: "Koray Pet",
      sourceCollection: "sellerOrders",
      sourceDocumentId: "so-3",
      grossAmount: 10.1,
      commissionAmount: 0,
      amount: 10.1,
      currency: "TRY",
      settlementStatus: "completed",
      payoutStatus: "pending",
    },
  ];

  const bytes = await buildPayoutBatchWorkbook({
    batch,
    items,
    details,
    exceptions: [{
      businessId: "b-2",
      businessName: "Unknown Seller",
      sector: "petshop",
      sourceCollection: "sellerOrders",
      sourceDocumentId: "unknown-1",
      amount: 5.05,
      currency: "TRY",
      reason: "commission_unknown",
      recommendedAction: "Review commission snapshot",
    }],
  });
  const parsed = new ExcelJS.Workbook();
  await parsed.xlsx.load(bytes);
  const instructions = parsed.getWorksheet("Payment Instructions");
  const detailSheet = parsed.getWorksheet("Payout Details");
  const exceptionSheet = parsed.getWorksheet("Exceptions");

  assert.ok(instructions);
  assert.ok(detailSheet);
  assert.ok(exceptionSheet);
  assert.equal(instructions.rowCount, 4);
  assert.equal(detailSheet.rowCount, 5);
  assert.equal(exceptionSheet.rowCount, 2);
  assert.equal(instructions.getCell("E2").value, "Şirin Patiler");
  assert.equal(instructions.getCell("Q2").value, 14.55);
  assert.equal(detailSheet.getCell("F2").value, "so-1");
  assert.equal(detailSheet.getCell("M2").value, 4.45);
  assert.equal(instructions.views[0].state, "frozen");
  assert.ok(instructions.autoFilter);
  assert.equal(instructions.getCell("Q2").numFmt, '#,##0.00;[Red](#,##0.00);-');
});
