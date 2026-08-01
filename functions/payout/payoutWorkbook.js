"use strict";

const ExcelJS = require("exceljs");

const PAYMENT_HEADERS = [
  "Row Number",
  "Batch Number",
  "Payment Date",
  "Sector",
  "Seller / Business Name",
  "Legal Name",
  "Account Holder Name",
  "IBAN",
  "Bank Name",
  "Tax Number",
  "Email",
  "Phone",
  "Currency",
  "Included Record Count",
  "Gross Total",
  "Commission Total",
  "Net Payment Amount",
  "Payment Description",
  "Payment Reference",
  "Status",
];

const DETAIL_HEADERS = [
  "Batch Number",
  "Seller Business ID",
  "Seller Name",
  "Sector",
  "Source Collection",
  "Source Document ID",
  "Root Order ID",
  "Order Number",
  "Successful Payment Date",
  "Eligibility Date",
  "Gross Amount",
  "Commission Amount",
  "Net Payout Amount",
  "Currency",
  "Settlement Status",
  "Payout Status",
  "Created Date",
  "Updated Date",
];

const EXCEPTION_HEADERS = [
  "Batch Number",
  "Business ID",
  "Seller Name",
  "Sector",
  "Source Collection",
  "Source Document ID",
  "Amount",
  "Currency",
  "Exception Reason",
  "Recommended Action",
];

function asDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value.toMillis === "function") return new Date(value.toMillis());
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function styleSheet(sheet, monetaryColumns, dateColumns) {
  sheet.views = [{ state: "frozen", ySplit: 1 }];
  sheet.autoFilter = {
    from: { row: 1, column: 1 },
    to: { row: 1, column: sheet.columnCount },
  };
  sheet.getRow(1).height = 28;
  sheet.getRow(1).eachCell((cell) => {
    cell.font = { bold: true, color: { argb: "FFFFFFFF" } };
    cell.fill = {
      type: "pattern",
      pattern: "solid",
      fgColor: { argb: "FF17324D" },
    };
    cell.alignment = { vertical: "middle", horizontal: "center" };
  });
  monetaryColumns.forEach((column) => {
    sheet.getColumn(column).numFmt = '#,##0.00;[Red](#,##0.00);-';
  });
  dateColumns.forEach((column) => {
    sheet.getColumn(column).numFmt = "yyyy-mm-dd";
  });
  sheet.columns.forEach((column) => {
    let width = 12;
    column.eachCell({ includeEmpty: false }, (cell) => {
      width = Math.max(width, Math.min(42, String(cell.value ?? "").length + 2));
    });
    column.width = width;
  });
}

async function buildPayoutBatchWorkbook({
  batch,
  items,
  details,
  exceptions = [],
}) {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = "Petsupo Payout Operations";
  workbook.title = `Payout Batch ${batch.batchNumber}`;
  workbook.subject = `Accounting Period ${batch.accountingPeriodId || "legacy"}`;
  workbook.created = new Date();
  workbook.modified = new Date();

  const instructions = workbook.addWorksheet("Payment Instructions");
  instructions.addRow(PAYMENT_HEADERS);
  items.forEach((item, index) => {
    instructions.addRow([
      index + 1,
      batch.batchNumber,
      asDate(batch.paymentDate || batch.exportedAt || new Date()),
      item.sector,
      item.businessName,
      item.legalBusinessName,
      item.accountHolderName,
      item.iban,
      item.bankName,
      item.taxNumber,
      item.contactEmail,
      item.contactPhone,
      item.currency,
      item.payoutCount,
      Number(item.grossTotal),
      Number(item.commissionTotal),
      Number(item.netTotal),
      `Petsupo seller payout ${batch.batchNumber}`,
      item.paymentReference || `${batch.batchNumber}-${item.businessId}`,
      item.status,
    ]);
  });
  const instructionTotalRow = instructions.addRow([
    null,
    "TOTAL",
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    batch.currency,
    items.reduce((sum, item) => sum + Number(item.payoutCount || 0), 0),
    { formula: `SUM(O2:O${items.length + 1})` },
    { formula: `SUM(P2:P${items.length + 1})` },
    { formula: `SUM(Q2:Q${items.length + 1})` },
    null,
    null,
    batch.status,
  ]);
  instructionTotalRow.font = { bold: true };
  instructionTotalRow.border = {
    top: { style: "double", color: { argb: "FF17324D" } },
  };
  styleSheet(instructions, [15, 16, 17], [3]);

  const detailSheet = workbook.addWorksheet("Payout Details");
  detailSheet.addRow(DETAIL_HEADERS);
  details.forEach((detail) => {
    detailSheet.addRow([
      batch.batchNumber,
      detail.businessId,
      detail.businessName,
      detail.sector,
      detail.sourceCollection,
      detail.sourceDocumentId,
      detail.rootOrderId,
      detail.orderNumber,
      asDate(detail.successfulPaymentAt),
      asDate(detail.eligibilityDate),
      Number(detail.grossAmount),
      Number(detail.commissionAmount),
      Number(detail.amount),
      detail.currency,
      detail.settlementStatus,
      detail.payoutStatus,
      asDate(detail.sourceCreatedAt),
      asDate(detail.sourceUpdatedAt),
    ]);
  });
  const detailTotalRow = detailSheet.addRow([
    "TOTAL",
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    { formula: `SUM(K2:K${details.length + 1})` },
    { formula: `SUM(L2:L${details.length + 1})` },
    { formula: `SUM(M2:M${details.length + 1})` },
  ]);
  detailTotalRow.font = { bold: true };
  detailTotalRow.border = {
    top: { style: "double", color: { argb: "FF17324D" } },
  };
  styleSheet(detailSheet, [11, 12, 13], [9, 10, 17, 18]);

  const exceptionSheet = workbook.addWorksheet("Exceptions");
  exceptionSheet.addRow(EXCEPTION_HEADERS);
  exceptions.forEach((exception) => {
    exceptionSheet.addRow([
      batch.batchNumber,
      exception.businessId,
      exception.businessName,
      exception.sector,
      exception.sourceCollection,
      exception.sourceDocumentId,
      Number(exception.amount),
      exception.currency,
      exception.reason,
      exception.recommendedAction,
    ]);
  });
  styleSheet(exceptionSheet, [7], []);

  return Buffer.from(await workbook.xlsx.writeBuffer());
}

module.exports = {
  PAYMENT_HEADERS,
  DETAIL_HEADERS,
  EXCEPTION_HEADERS,
  buildPayoutBatchWorkbook,
};
