"use strict";

const ExcelJS = require("exceljs");

const MONEY_FORMAT = '#,##0.00;[Red](#,##0.00);-';
const DATE_FORMAT = "yyyy-mm-dd";
const DATE_TIME_FORMAT = "yyyy-mm-dd hh:mm";
const COLORS = {
  navy: "FF17324D",
  blue: "FFE8F0F7",
  paleBlue: "FFF4F8FB",
  border: "FFD6E0E8",
  white: "FFFFFFFF",
  text: "FF1F2933",
};

function asDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value.toMillis === "function") return new Date(value.toMillis());
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function nonEmpty(value) {
  return value !== null && value !== undefined && String(value).trim() !== "";
}

function humanReadableGeneratedBy(value) {
  if (value && typeof value === "object") {
    const candidate = value.displayName || value.fullName || value.email;
    return nonEmpty(candidate) ? String(candidate) : "System";
  }
  const text = String(value || "").trim();
  if (!text || /^[A-Za-z0-9_-]{20,}$/.test(text)) return "System";
  return text;
}

function localTimestamp(value) {
  const date = asDate(value);
  if (!date) return "";
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Istanbul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(date).reduce((result, part) => {
    result[part.type] = part.value;
    return result;
  }, {});
  return `${parts.year}-${parts.month}-${parts.day} ${parts.hour}:${parts.minute} TRT`;
}

function dateOnly(value) {
  const date = asDate(value);
  if (!date) return "";
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Istanbul",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function presentationLabels(report) {
  const turkish = report.languageLabel === "Türkçe";
  return turkish
    ? { all: "Tümü", allDates: "Tüm Tarihler", status: "Durum", sector: "Sektör", selected: "Seçili" }
    : { all: "All", allDates: "All Dates", status: "Status", sector: "Sector", selected: "Selected" };
}

function currencyLabel(report) {
  const currencies = new Set((report.transactions || [])
    .map((transaction) => String(transaction.currency || "").trim().toUpperCase())
    .filter(Boolean));
  if (currencies.size === 1) return Array.from(currencies)[0];
  const requested = String(report.currency || "").trim().toUpperCase();
  if (requested && requested !== "ALL") return requested;
  return "Multi Currency";
}

function readableFilters(report) {
  const labels = presentationLabels(report);
  const raw = String(report.filtersLabel || "");
  const statusMatch = raw.match(/statuses\s*=\s*([^,]+)/i);
  const sectorMatch = raw.match(/sector\s*=\s*([^,]+)/i);
  const statusCount = Number.parseInt(statusMatch?.[1] || "", 10);
  const transactionStatuses = Array.from(new Set((report.transactions || [])
    .map((transaction) => transaction.payoutStatus)
    .filter(Boolean)));
  const status = statusCount >= 9 || !statusMatch
    ? labels.all
    : transactionStatuses.length
      ? transactionStatuses.join(", ")
      : `${labels.selected} (${statusCount})`;
  const sector = String(sectorMatch?.[1] || "").trim().toLowerCase();
  const sectorNames = { petshop: "Petshop", vet: "Vet", groomy: "Groomy", hotel: "Hotel", taxi: "Taxi" };
  return `${labels.status}:\n${status}\n${labels.sector}:\n${sector === "all" || !sector ? labels.all : sectorNames[sector] || sector}`;
}

function readableDateRange(report) {
  const labels = presentationLabels(report);
  const raw = String(report.dateRangeLabel || "").trim().toLowerCase();
  if (!raw || raw === "all" || raw === "all records") return labels.allDates;
  const dates = (report.transactions || []).map((transaction) => asDate(transaction.paymentDate)).filter(Boolean).sort((a, b) => a - b);
  if (dates.length) return `${dateOnly(dates[0])}\n↓\n${dateOnly(dates[dates.length - 1])}`;
  return raw.replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function sourceValue(transaction, names) {
  const index = transaction.index || {};
  for (const name of names) {
    if (nonEmpty(index[name])) return index[name];
    if (nonEmpty(transaction[name])) return transaction[name];
  }
  return null;
}

function optionalSellerFields(report) {
  const turkish = report.languageLabel === "Türkçe";
  const candidates = [
    { key: "bankBranch", header: turkish ? "Şube" : "Bank Branch", names: ["bankBranch", "bankBranchName", "branchName"] },
    { key: "ibanVerified", header: turkish ? "IBAN Doğrulandı" : "IBAN Verified", names: ["ibanVerified", "ibanValidationStatus", "bankValidationStatus"] },
    { key: "paymentNote", header: turkish ? "Ödeme Notu" : "Payment Note", names: ["paymentNote", "paymentNotes"] },
    { key: "taxOffice", header: turkish ? "Vergi Dairesi" : "Tax Office", names: ["taxOffice"] },
  ];
  return candidates.filter((candidate) => (report.transactions || []).some((transaction) => nonEmpty(sourceValue(transaction, candidate.names))));
}

function sellerTransactions(report, seller) {
  return (report.transactions || []).filter((transaction) =>
    transaction.businessName === seller.businessName || transaction.sellerName === seller.businessName
  );
}

function isMaskedIban(value) {
  return /[*•…]/.test(String(value || ""));
}

function fullIbanForSeller(report, seller) {
  const candidates = sellerTransactions(report, seller).flatMap((transaction) => [
    transaction.index?.iban,
    transaction.iban,
  ]).concat(seller.iban);
  return candidates.map((value) => String(value || "").trim()).find((value) => nonEmpty(value) && !isMaskedIban(value)) || "";
}

function optionalSellerValue(transactions, field) {
  const value = transactions.map((transaction) => sourceValue(transaction, field.names)).find(nonEmpty);
  if (field.key !== "ibanVerified") return value || "";
  if (typeof value === "boolean") return value ? "Yes" : "No";
  return String(value).toLowerCase() === "valid" || String(value).toLowerCase() === "true" ? "Yes" : "No";
}

function styleTable(sheet, { money = [], dates = [], headerRow = 1 } = {}) {
  sheet.views = [{ state: "frozen", ySplit: headerRow }];
  sheet.showGridLines = false;
  const lastColumn = sheet.columnCount;
  if (lastColumn > 0 && sheet.rowCount >= headerRow) {
    sheet.autoFilter = {
      from: { row: headerRow, column: 1 },
      to: { row: sheet.rowCount, column: lastColumn },
    };
  }
  sheet.getRow(headerRow).height = 32;
  sheet.getRow(headerRow).eachCell((cell) => {
    cell.font = { bold: true, color: { argb: COLORS.white } };
    cell.fill = { type: "pattern", pattern: "solid", fgColor: { argb: COLORS.navy } };
    cell.alignment = { vertical: "middle", horizontal: "center", wrapText: true };
  });
  money.forEach((column) => { sheet.getColumn(column).numFmt = MONEY_FORMAT; });
  dates.forEach((column) => { sheet.getColumn(column).numFmt = DATE_TIME_FORMAT; });
  sheet.columns.forEach((column) => {
    let width = 12;
    column.eachCell({ includeEmpty: false }, (cell) => {
      width = Math.max(width, Math.min(42, String(cell.value ?? "").length + 2));
    });
    column.width = width;
  });
  for (let row = headerRow + 1; row <= sheet.rowCount; row += 1) {
    if (row % 2 === 0) {
      sheet.getRow(row).fill = { type: "pattern", pattern: "solid", fgColor: { argb: COLORS.paleBlue } };
    }
    sheet.getRow(row).alignment = { vertical: "top", wrapText: true };
  }
  sheet.getRow(headerRow).border = { bottom: { style: "medium", color: { argb: COLORS.navy } } };
  sheet.pageSetup = { orientation: "landscape", fitToPage: true, fitToWidth: 1, fitToHeight: 0, paperSize: 9 };
  sheet.headerFooter.oddFooter = "&L Petsupo&C Finance Report&RPage &P of &N";
}

function addTitle(sheet, title, report) {
  sheet.mergeCells("A1:H1");
  sheet.getCell("A1").value = title;
  sheet.showGridLines = false;
  sheet.getCell("A1").font = { bold: true, size: 22, color: { argb: COLORS.navy } };
  sheet.getCell("A1").alignment = { vertical: "middle" };
  sheet.getRow(1).height = 32;
  const values = [
    ["Company", report.companyName],
    ["Report language", report.languageLabel],
    ["Generated at", localTimestamp(report.generatedAt)],
    ["Generated by", humanReadableGeneratedBy(report.generatedBy)],
    ["Date range", readableDateRange(report)],
    ["Filters", readableFilters(report)],
    ["Currency", currencyLabel(report)],
    ["Report version", report.reportVersion],
  ];
  values.forEach(([label, value], index) => {
    sheet.getCell(index + 2, 1).value = label;
    sheet.getCell(index + 2, 1).font = { bold: true, color: { argb: COLORS.text } };
    sheet.getCell(index + 2, 1).fill = { type: "pattern", pattern: "solid", fgColor: { argb: COLORS.blue } };
    sheet.getCell(index + 2, 2).value = value;
    sheet.getCell(index + 2, 2).alignment = { vertical: "top", wrapText: true };
  });
  sheet.getColumn(1).width = 28;
  sheet.getColumn(2).width = 42;
  sheet.getRow(7).height = 62;
  sheet.getRow(8).height = 32;
}

function addSummary(sheet, report, labels) {
  const start = 12;
  const reportCurrency = currencyLabel(report);
  sheet.mergeCells(start, 1, start, 4);
  sheet.getCell(start, 1).value = labels.summary;
  sheet.getCell(start, 1).font = { bold: true, size: 15, color: { argb: COLORS.white } };
  sheet.getCell(start, 1).fill = { type: "pattern", pattern: "solid", fgColor: { argb: COLORS.navy } };
  sheet.getRow(start).height = 26;
  const rows = [
    [labels.totalCustomerPayments, report.totals.customerPaid, reportCurrency],
    [labels.totalCommission, report.totals.commission, reportCurrency],
    [labels.totalSellerPayable, report.totals.sellerNet, reportCurrency],
    [labels.waitingAmount, report.totals.waiting, reportCurrency],
    [labels.eligibleAmount, report.totals.eligible, reportCurrency],
    [labels.blockedAmount, report.totals.blocked, reportCurrency],
    [labels.requiresRepairAmount, report.totals.requiresRepair, reportCurrency],
    [labels.batchedAmount, report.totals.batched, reportCurrency],
    [labels.processingAmount, report.totals.processing, reportCurrency],
    [labels.paidAmount, report.totals.paid, reportCurrency],
    [labels.refundedAmount, report.totals.refunded, reportCurrency],
    [labels.sellers, report.sellers.length, ""],
    [labels.transactions, report.transactions.length, ""],
    [labels.nextPayout, asDate(report.nextPayoutDate), ""],
  ];
  rows.forEach(([label, value, currency], index) => {
    const row = sheet.getRow(start + 1 + index);
    row.getCell(1).value = label;
    row.getCell(2).value = typeof value === "number" ? value : value;
    row.getCell(3).value = currency;
    row.getCell(1).font = { bold: true };
    row.getCell(1).fill = { type: "pattern", pattern: "solid", fgColor: { argb: COLORS.blue } };
    row.getCell(2).alignment = { horizontal: "right", vertical: "middle" };
    row.getCell(3).alignment = { horizontal: "center", vertical: "middle" };
    row.height = 22;
    if (typeof value === "number" && currency) row.getCell(2).numFmt = MONEY_FORMAT;
    if (value instanceof Date) row.getCell(2).numFmt = DATE_FORMAT;
  });
  sheet.getColumn(3).width = 14;
  for (let rowIndex = start + 1; rowIndex <= start + rows.length; rowIndex += 1) {
    sheet.getRow(rowIndex).border = { bottom: { style: "thin", color: { argb: COLORS.border } } };
  }
}

function addSellerSheet(workbook, report, labels) {
  const sheet = workbook.addWorksheet(labels.sellersSheet);
  const optionalFields = optionalSellerFields(report);
  const headers = [
    labels.seller, labels.legalName, labels.sector, labels.taxId, labels.accountHolder,
    labels.bank, labels.iban, labels.currency, labels.customerPaid, labels.commission,
    labels.sellerNet, labels.waiting, labels.eligible, labels.blocked, labels.batched,
    labels.paid, labels.oldestUnpaid, labels.nextEligibility, labels.daysRemaining,
    labels.expectedPayout, labels.lastPayout, labels.status, labels.reason,
  ].concat(optionalFields.map((field) => field.header));
  sheet.addRow(headers);
  report.sellers.forEach((seller) => {
    const values = [
      seller.businessName, seller.legalBusinessName, seller.sector, seller.taxId,
      seller.accountHolderName, seller.bankName, fullIbanForSeller(report, seller), seller.currency,
      seller.customerPaid, seller.commission, seller.sellerNet, seller.waiting,
      seller.eligible, seller.blocked, seller.batched, seller.paid,
      asDate(seller.oldestUnpaid), asDate(seller.nextEligibility), seller.daysRemaining,
      asDate(seller.expectedPayout), asDate(seller.lastPayout), seller.status, seller.reason,
    ];
    values.push(...optionalFields.map((field) => optionalSellerValue(sellerTransactions(report, seller), field)));
    sheet.addRow(values);
  });
  styleTable(sheet, { money: [9, 10, 11, 12, 13, 14, 15, 16], dates: [17, 18, 20, 21] });
  return sheet;
}

function addTransactionSheet(workbook, report, labels) {
  const sheet = workbook.addWorksheet(labels.transactionsSheet);
  const headers = [
    labels.seller, labels.sector, labels.reference, labels.paymentDate, labels.service,
    labels.customerPaid, labels.commission, labels.sellerNet, labels.currency,
    labels.financialStatus, labels.settlementStatus, labels.payoutStatus,
    labels.eligibilityStatus, labels.eligibleDate, labels.expectedPaymentDate,
    labels.daysRemaining, labels.batchNumber || "Batch Number", labels.paidDate, labels.paymentReference,
    labels.blockingReason, labels.requiredAction,
  ];
  sheet.addRow(headers);
  report.transactions.forEach((transaction) => sheet.addRow([
    transaction.sellerName, transaction.sector, transaction.reference,
    asDate(transaction.paymentDate), transaction.service, transaction.customerPaid,
    transaction.commissionDisplay, transaction.sellerNetDisplay, transaction.currency,
    transaction.financialStatus, transaction.settlementStatus, transaction.payoutStatus,
    transaction.eligibilityStatus, asDate(transaction.eligibleDate),
    transaction.expectedPaymentDisplay, transaction.daysRemaining, transaction.batchNumber,
    asDate(transaction.paidDate), transaction.paymentReference, transaction.blockingReason,
    transaction.requiredAction,
  ]));
  styleTable(sheet, { money: [6, 7, 8], dates: [4, 14, 18] });
  return sheet;
}

function addDeveloperMetadataSheet(workbook, report) {
  const sheet = workbook.addWorksheet("Developer Metadata");
  sheet.addRow(["Transaction Reference", "Seller", "Source Collection", "Source Document ID", "Payout Index ID"]);
  (report.transactions || []).forEach((transaction) => sheet.addRow([
    transaction.reference,
    transaction.sellerName,
    transaction.sourceCollection,
    transaction.sourceDocumentId,
    transaction.payoutIndexId,
  ]));
  styleTable(sheet);
  sheet.getColumn(1).width = 28;
  sheet.getColumn(2).width = 28;
  sheet.getColumn(3).width = 24;
  sheet.getColumn(4).width = 34;
  sheet.getColumn(5).width = 38;
  return sheet;
}

function addBankTransferSheet(workbook, report) {
  const sheet = workbook.addWorksheet("Bank Transfer");
  sheet.addRow(["Account Holder", "Bank", "Full IBAN", "Currency", "Amount", "Payment Reference", "Transfer Description"]);
  const usedReferences = new Map();
  (report.sellers || []).forEach((seller) => {
    const transactions = sellerTransactions(report, seller);
    const first = transactions[0] || {};
    const fullIban = fullIbanForSeller(report, seller);
    const readyAmount = Number(seller.eligible);
    const paymentReference = transactions
      .map((transaction) => transaction.paymentReference)
      .find(nonEmpty);
    const requiredBankValues = [
      seller.accountHolderName,
      fullIban,
      seller.bankName,
      readyAmount,
      seller.currency,
    ];
    if (!requiredBankValues.every(nonEmpty) || !(readyAmount > 0)) return;
    const batchReference = transactions
      .map((transaction) => transaction.batchNumber || transaction.index?.batchNumber || transaction.index?.batchId)
      .find((value) => nonEmpty(value) && String(value).toLowerCase() !== "eft");
    const storedReference = nonEmpty(paymentReference) && String(paymentReference).toLowerCase() !== "eft"
      ? paymentReference
      : null;
    const generatedReference = `PAYOUT-${dateOnly(report.generatedAt).replace(/-/g, "")}-${String(usedReferences.size + 1).padStart(4, "0")}`;
    const baseReference = String(batchReference || storedReference || generatedReference).trim();
    const occurrence = (usedReferences.get(baseReference) || 0) + 1;
    usedReferences.set(baseReference, occurrence);
    const uniqueReference = occurrence === 1 ? baseReference : `${baseReference}-${occurrence}`;
    const descriptionSource = first.service || seller.businessName || "Seller payout";
    sheet.addRow([
      seller.accountHolderName,
      seller.bankName,
      fullIban,
      seller.currency,
      readyAmount,
      uniqueReference,
      `Payout for ${descriptionSource}`,
    ]);
  });
  styleTable(sheet, { money: [5] });
  sheet.getColumn(1).width = 28;
  sheet.getColumn(2).width = 24;
  sheet.getColumn(3).width = 32;
  sheet.getColumn(4).width = 12;
  sheet.getColumn(5).width = 16;
  sheet.getColumn(6).width = 24;
  sheet.getColumn(7).width = 36;
  return sheet;
}

async function buildFinancePayablesReportWorkbook({ report, language }) {
  const labels = report.labels;
  const workbook = new ExcelJS.Workbook();
  workbook.creator = "Petsupo Finance Operations";
  workbook.title = labels.title;
  workbook.subject = labels.subtitle;
  workbook.created = new Date();
  workbook.modified = new Date();

  const summary = workbook.addWorksheet(labels.summarySheet);
  addTitle(summary, labels.title, report);
  addSummary(summary, report, labels);
  summary.getColumn(1).width = 32;
  summary.getColumn(2).width = 42;
  summary.pageSetup = { orientation: "portrait", fitToPage: true, fitToWidth: 1, fitToHeight: 1, paperSize: 9 };
  summary.headerFooter.oddFooter = labels.footer;

  addSellerSheet(workbook, report, labels);
  addTransactionSheet(workbook, report, labels);

  const notes = workbook.addWorksheet(labels.notesSheet);
  notes.showGridLines = false;
  notes.addRow([labels.notesHeading]);
  notes.getRow(1).font = { bold: true, size: 14, color: { argb: COLORS.navy } };
  report.notes.forEach((note) => notes.addRow([note]));
  notes.addRow(["--------------------------------"]);
  notes.addRow(["This report was automatically generated by Petsupo Finance OS."]);
  notes.addRow(["Confidential – Internal Use Only."]);
  notes.addRow(["--------------------------------"]);
  notes.getColumn(1).width = 110;
  notes.getColumn(1).alignment = { wrapText: true, vertical: "top" };
  notes.pageSetup = { orientation: "portrait", fitToPage: true, fitToWidth: 1, fitToHeight: 1, paperSize: 9 };

  addBankTransferSheet(workbook, report);
  addDeveloperMetadataSheet(workbook, report);

  return Buffer.from(await workbook.xlsx.writeBuffer());
}

module.exports = { buildFinancePayablesReportWorkbook };
