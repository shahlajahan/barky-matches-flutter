"use strict";

const crypto = require("crypto");
const admin = require("firebase-admin");
const { buildFinancePayablesReportWorkbook } = require("./financePayablesReportWorkbook");

const REPORT_VERSION = "1.0";
const VALID_SECTORS = new Set(["petshop", "vet", "groomy", "hotel", "taxi"]);
const VALID_STATUSES = new Set([
  "waiting", "eligible", "blocked", "requires_repair", "batched", "processing",
  "paid", "refunded", "cancelled",
]);

const TEXT = {
  tr: {
    title: "Petsupo Ödeme Raporu",
    subtitle: "Ödeme Talimatları / Hakediş Özeti",
    languageLabel: "Türkçe",
    summarySheet: "Özet",
    sellersSheet: "Hakediş Özeti",
    transactionsSheet: "İşlem Detayları",
    notesSheet: "Açıklamalar",
    notesHeading: "Açıklamalar ve Muhasebe Notları",
    footer: "&L Petsupo&C Finans Raporu&RPage &P of &N",
    summary: "Finansal Özet",
    totalCustomerPayments: "Toplam müşteri ödemesi",
    totalCommission: "Toplam platform komisyonu",
    totalSellerPayable: "Toplam satıcı hakedişi",
    waitingAmount: "Bekleyen tutar",
    eligibleAmount: "Ödemeye hazır tutar",
    blockedAmount: "Engelli tutar",
    requiresRepairAmount: "Finansal inceleme gerekli tutar",
    batchedAmount: "Ödeme grubuna alınan tutar",
    processingAmount: "İşlenen tutar",
    paidAmount: "Ödenen tutar",
    refundedAmount: "İade edilen tutar",
    sellers: "Satıcı sayısı",
    transactions: "Kaynak işlem sayısı",
    nextPayout: "Yaklaşan ödeme tarihi",
    seller: "Satıcı / İşletme adı", legalName: "Yasal işletme adı", sector: "Sektör",
    taxId: "Vergi No", accountHolder: "Hesap sahibi", bank: "Banka", iban: "IBAN",
    currency: "Para birimi", customerPaid: "Müşteri ödemesi", commission: "Platform komisyonu",
    sellerNet: "Satıcı hakedişi", waiting: "Bekleme tutarı", eligible: "Hazır tutar",
    blocked: "Engelli tutar", batched: "Gruplanan tutar", paid: "Ödenen tutar",
    oldestUnpaid: "En eski ödenmemiş işlem", nextEligibility: "Uygunluk tarihi",
    daysRemaining: "Kalan gün", expectedPayout: "Beklenen ödeme tarihi", lastPayout: "Son ödeme tarihi",
    status: "Durum", reason: "Neden / Notlar", reference: "Sipariş / Rezervasyon referansı",
    paymentDate: "Müşteri ödeme tarihi", service: "Hizmet / Ürün", financialStatus: "Finansal durum",
    settlementStatus: "Mutabakat durumu", payoutStatus: "Ödeme durumu", eligibilityStatus: "Uygunluk durumu",
    eligibleDate: "Uygunluk tarihi", expectedPaymentDate: "Beklenen ödeme tarihi",
    paidDate: "Ödeme tarihi", paymentReference: "Ödeme referansı", blockingReason: "Engelleme nedeni",
    requiredAction: "Gerekli işlem", sourceCollection: "Kaynak koleksiyon", sourceDocumentId: "Kaynak belge ID",
    payoutIndexId: "Payout index ID",
    statusLabels: {
      verified: "Doğrulandı",
      waiting: "Bekleme Süresinde", eligible: "Ödemeye Hazır", blocked: "Ödeme Engelli",
      requires_repair: "Finansal İnceleme Gerekli", batched: "Ödeme Grubuna Alındı",
      processing: "İşleniyor", paid: "Ödendi", refunded: "İade Edildi", cancelled: "İptal Edildi",
    },
    unknown: "BİLİNMİYOR", notCalculated: "HESAPLANMADI", unavailable: "KULLANILAMAZ",
    ready: "Ödemeye hazır", waitingReason: "21 günlük bekleme süresi", repair: "Finansal snapshot onarılmalı",
    blockedBank: "Eksik banka bilgileri", settlement: "Mutabakat tamamlanmadı", paidOn: "Ödendi",
    requiredRepair: "Finansal snapshot onarımı", noAction: "İşlem gerekmiyor",
  },
  en: {
    title: "Petsupo Payout Report",
    subtitle: "Seller Payables and Payout Status Report",
    languageLabel: "English",
    summarySheet: "Summary", sellersSheet: "Seller Payables", transactionsSheet: "Transaction Details",
    notesSheet: "Notes", notesHeading: "Explanations and Accounting Notes", footer: "&L Petsupo&C Finance Report&RPage &P of &N",
    summary: "Financial Summary", totalCustomerPayments: "Total customer payments", totalCommission: "Total platform commission",
    totalSellerPayable: "Total seller payable", waitingAmount: "Waiting amount", eligibleAmount: "Eligible amount",
    blockedAmount: "Blocked amount", requiresRepairAmount: "Requires-repair amount", batchedAmount: "Batched amount",
    processingAmount: "Processing amount", paidAmount: "Paid amount", refundedAmount: "Refunded amount",
    sellers: "Number of sellers", transactions: "Number of source transactions", nextPayout: "Next upcoming payout date",
    seller: "Seller / Business Name", legalName: "Legal Business Name", sector: "Sector", taxId: "Tax ID",
    accountHolder: "Account Holder", bank: "Bank Name", iban: "IBAN", currency: "Currency", customerPaid: "Customer Paid",
    commission: "Platform Commission", sellerNet: "Seller Net", waiting: "Waiting Amount", eligible: "Eligible Amount",
    blocked: "Blocked Amount", batched: "Batched Amount", paid: "Paid Amount", oldestUnpaid: "Oldest Unpaid Transaction",
    nextEligibility: "Next Eligibility Date", daysRemaining: "Days Remaining", expectedPayout: "Expected Payout Date",
    lastPayout: "Last Payout Date", status: "Status", reason: "Reason / Notes", reference: "Order / Booking Reference",
    paymentDate: "Customer Payment Date", service: "Service / Product", financialStatus: "Financial Status",
    settlementStatus: "Settlement Status", payoutStatus: "Payout Status", eligibilityStatus: "Eligibility Status",
    eligibleDate: "Eligible Date", expectedPaymentDate: "Expected Payment Date", paidDate: "Paid Date",
    paymentReference: "Payment Reference", blockingReason: "Blocking Reason", requiredAction: "Required Action",
    sourceCollection: "Source Collection", sourceDocumentId: "Source Document ID", payoutIndexId: "Payout Index ID",
    statusLabels: { verified: "Verified", waiting: "Waiting", eligible: "Ready for payout", blocked: "Blocked", requires_repair: "Requires repair", batched: "Batched", processing: "Processing", paid: "Paid", refunded: "Refunded", cancelled: "Cancelled" },
    unknown: "UNKNOWN", notCalculated: "NOT CALCULATED", unavailable: "UNAVAILABLE", ready: "Ready for payment now",
    waitingReason: "21-day waiting period", repair: "Financial snapshot requires repair", blockedBank: "Missing bank information",
    settlement: "Settlement is incomplete", paidOn: "Paid", requiredRepair: "Repair financial snapshot", noAction: "No action required",
  },
};

function errorText(error) {
  return String(error?.message || error || "Unknown error");
}

function classifyStorageFailure(error, operation, storagePath) {
  const message = errorText(error);
  const normalized = message.toLowerCase();
  let code = "STORAGE_OPERATION_FAILED";
  let retryable = true;
  let publicCode = "failed-precondition";
  if (normalized.includes("billing") && (normalized.includes("disabled") || normalized.includes("closed"))) {
    code = "STORAGE_BILLING_DISABLED";
    retryable = false;
  } else if (String(error?.code) === "404" || normalized.includes("not found") || normalized.includes("no such object")) {
    code = "STORAGE_OBJECT_MISSING";
    publicCode = "not-found";
    retryable = false;
  } else if (String(error?.code) === "403" || normalized.includes("permission") || normalized.includes("forbidden")) {
    code = "STORAGE_PERMISSION_DENIED";
    publicCode = "permission-denied";
    retryable = false;
  } else if (normalized.includes("invalid") && normalized.includes("path")) {
    code = "STORAGE_INVALID_PATH";
    publicCode = "invalid-argument";
    retryable = false;
  } else if (operation === "signed_url") {
    code = "STORAGE_SIGNED_URL_FAILED";
  } else if (operation === "metadata") {
    code = "FINANCE_REPORT_METADATA_MISSING";
    retryable = false;
  }
  const details = {
    code,
    operation,
    storagePath: storagePath || null,
    message: message,
    technicalDetails: {
      originalCode: error?.code ?? null,
      originalName: error?.name ?? null,
      originalErrors: error?.errors ?? null,
      requestId: storageRequestId(error),
    },
    retryable,
  };
  console.error("[FinanceReport] storage failure", {
    ...details,
    originalStack: error?.stack || null,
  });
  const wrapped = new Error(details.message);
  wrapped.code = publicCode;
  wrapped.details = details;
  return wrapped;
}

function storageRequestId(error) {
  const candidates = [
    error?.response?.headers?.['x-goog-request-id'],
    error?.headers?.['x-goog-request-id'],
    error?.response?.headers?.get?.('x-goog-request-id'),
  ];
  return candidates.find((value) => value) || null;
}

function isStaleBillingClosedError(error) {
  const message = errorText(error).toLowerCase();
  return (
    String(error?.code) === '403' &&
    message.includes('billing account') &&
    message.includes('disabled') &&
    message.includes('closed')
  );
}

function reportSizeFailure(reportId, fileSize) {
  const error = new Error('This report is too large for temporary inline delivery. Storage service access is required.');
  error.code = 'failed-precondition';
  error.details = {
    code: 'FINANCE_REPORT_TEMPORARY_FALLBACK_SIZE_LIMIT',
    reportId,
    fileSize,
    maximumBytes: 5 * 1024 * 1024,
    retryable: true,
  };
  return error;
}

function reportMetadataFailure(message, details = {}) {
  const error = new Error(message);
  error.code = "failed-precondition";
  error.details = {
    code: "FINANCE_REPORT_METADATA_MISSING",
    operation: "metadata",
    message,
    technicalDetails: details,
    retryable: false,
  };
  console.error("[FinanceReport] metadata failure", {
    ...error.details,
    originalStack: new Error().stack,
  });
  return error;
}

function dateValue(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value.toMillis === "function") return new Date(value.toMillis());
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function numberOrNull(value) {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function maskIban(iban) {
  const value = String(iban || "").replace(/\s+/g, "").toUpperCase();
  if (value.length < 8) return value ? `${value.slice(0, 4)}********` : "";
  return `${value.slice(0, 4)}${"*".repeat(Math.max(4, value.length - 8))}${value.slice(-4)}`;
}

function normalizedStatus(index) {
  const source = `${index.sourceStatus || ""} ${index.refundStatus || ""}`.toLowerCase();
  if (source.includes("refund")) return "refunded";
  if (source.includes("cancel") || ["reversed", "voided"].includes(index.sourceStatus)) return "cancelled";
  if (index.commissionDataQuality !== "verified_snapshot" || index.financialStatus === "requires_repair") return "requires_repair";
  if (["processing"].includes(index.batchStatus)) return "processing";
  if (index.batchId) return "batched";
  if (index.payoutStatus === "paid" || index.paidAt) return "paid";
  if (index.settlementStatus !== "completed" || ["hold", "recovery_required"].includes(index.payoutStatus)) return "blocked";
  if (index.eligibilityStatus === "eligible") return "eligible";
  if (index.eligibilityStatus === "waiting_period") return "waiting";
  return "blocked";
}

function sellerReason(records, labels) {
  const reasons = new Set(records.flatMap((record) => record.blockingReasons || []));
  return Array.from(reasons).join(", ") || labels.noAction;
}

function labelStatus(status, labels) { return labels.statusLabels[status] || status; }

function filterReportInput(index, filters) {
  const statuses = new Set((filters.statuses || []).map(String).filter((status) => VALID_STATUSES.has(status)));
  const sectors = new Set((filters.sectors || []).map(String).filter((sector) => VALID_SECTORS.has(sector)));
  const currency = String(filters.currency || "all").toUpperCase();
  const start = dateValue(filters.start);
  const end = dateValue(filters.end);
  const status = normalizedStatus(index);
  const paymentDate = dateValue(index.successfulPaymentAt || index.sourceCreatedAt);
  if (statuses.size && !statuses.has(status)) return false;
  if (sectors.size && !sectors.has(String(index.sector || "").toLowerCase())) return false;
  if (filters.businessId && String(index.businessId || "") !== String(filters.businessId)) return false;
  if (currency !== "ALL" && String(index.currency || "TRY").toUpperCase() !== currency) return false;
  if (start && (!paymentDate || paymentDate < start)) return false;
  if (end && (!paymentDate || paymentDate > end)) return false;
  return true;
}

async function sourceRecords(db, indexes) {
  const refs = indexes.map((index) => db.collection(index.sourceCollection).doc(index.sourceDocumentId));
  const result = new Map();
  for (let offset = 0; offset < refs.length; offset += 400) {
    const snapshots = await db.getAll(...refs.slice(offset, offset + 400));
    snapshots.forEach((snapshot) => result.set(`${snapshot.ref.parent.id}/${snapshot.id}`, snapshot.exists ? snapshot.data() || {} : {}));
  }
  return result;
}

function buildTransaction(index, source, labels, fullIban) {
  const status = normalizedStatus(index);
  const verified = index.commissionDataQuality === "verified_snapshot";
  const gross = numberOrNull(index.grossAmount) ?? 0;
  const commission = verified ? numberOrNull(index.commissionAmount) : null;
  const net = verified ? numberOrNull(index.amount) : null;
  const paymentDate = dateValue(index.successfulPaymentAt || index.sourceCreatedAt);
  const eligibleDate = dateValue(index.eligibilityDate);
  const paidDate = dateValue(index.paidAt);
  const daysRemaining = eligibleDate ? Math.max(0, Math.ceil((eligibleDate.getTime() - Date.now()) / 86400000)) : null;
  const blockingReasons = [];
  if (!verified) blockingReasons.push(labels.repair);
  if (index.settlementStatus !== "completed") blockingReasons.push(labels.settlement);
  if (index.bankValidationStatus !== "valid") blockingReasons.push(labels.blockedBank);
  if (status === "waiting") blockingReasons.push(labels.waitingReason);
  const reference = index.sourceNumber || index.orderNumber || index.rootOrderId || index.sourceDocumentId;
  const service = source.serviceName || source.serviceTitle || source.productName || source.service?.name || source.product?.name || "";
  return {
    index,
    status,
    sellerName: index.businessName || index.businessId || "",
    sector: index.sector || "",
    reference,
    paymentDate,
    service,
    customerPaid: gross,
    commission,
    sellerNet: net,
    commissionDisplay: commission === null ? labels.unknown : commission,
    sellerNetDisplay: net === null ? labels.notCalculated : net,
    currency: String(index.currency || "TRY").toUpperCase(),
    financialStatus: labelStatus(index.financialStatus === "requires_repair" ? "requires_repair" : verified ? "verified" : "requires_repair", labels),
    settlementStatus: index.settlementStatus || "",
    payoutStatus: labelStatus(status, labels),
    eligibilityStatus: index.eligibilityStatus || "",
    eligibleDate,
    expectedPaymentDisplay: status === "waiting" ? eligibleDate : status === "eligible" ? labels.ready : status === "paid" ? `${labels.paidOn} ${paidDate ? paidDate.toISOString().slice(0, 10) : ""}` : labels.unavailable,
    daysRemaining,
    batchNumber: index.batchNumber || index.batchId || "",
    paidDate,
    paymentReference: index.paymentReference || "",
    blockingReason: blockingReasons.join(", ") || labels.noAction,
    requiredAction: verified ? labels.noAction : labels.requiredRepair,
    sourceCollection: index.sourceCollection,
    sourceDocumentId: index.sourceDocumentId,
    payoutIndexId: index.indexId || "",
    businessId: index.businessId || "",
    businessName: index.businessName || index.businessId || "",
    legalBusinessName: index.legalBusinessName || index.businessName || "",
    accountHolderName: index.accountHolderName || "",
    bankName: index.bankName || "",
    iban: fullIban ? index.iban || "" : maskIban(index.iban),
    taxId: index.taxNumber || "",
    bankValidationStatus: index.bankValidationStatus || "",
  };
}

function buildReport({ indexes, sources, labels, filters, generatedBy, fullIban }) {
  const transactions = indexes.map((index) => buildTransaction(index, sources.get(`${index.sourceCollection}/${index.sourceDocumentId}`) || {}, labels, fullIban));
  const totals = { customerPaid: 0, commission: 0, sellerNet: 0, waiting: 0, eligible: 0, blocked: 0, requiresRepair: 0, batched: 0, processing: 0, paid: 0, refunded: 0 };
  const groups = new Map();
  transactions.forEach((transaction) => {
    totals.customerPaid += transaction.customerPaid;
    if (transaction.commission !== null) totals.commission += transaction.commission;
    if (transaction.sellerNet !== null) totals.sellerNet += transaction.sellerNet;
    if (transaction.sellerNet !== null) {
      const totalKey = transaction.status === "requires_repair" ? "requiresRepair" : transaction.status;
      totals[totalKey] = (totals[totalKey] || 0) + transaction.sellerNet;
    } else if (transaction.status === "requires_repair") {
      totals.requiresRepair += transaction.customerPaid;
    }
    const key = transaction.businessId || transaction.businessName;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(transaction);
  });
  const sellers = Array.from(groups.values()).map((records) => {
    const first = records[0];
    const amount = (status) => records.filter((record) => record.status === status && record.sellerNet !== null).reduce((sum, record) => sum + record.sellerNet, 0);
    const unpaid = records.filter((record) => record.status !== "paid");
    const dates = unpaid.map((record) => record.paymentDate).filter(Boolean).sort((a, b) => a - b);
    const next = records.map((record) => record.eligibleDate).filter(Boolean).sort((a, b) => a - b)[0] || null;
    const last = records.map((record) => record.paidDate).filter(Boolean).sort((a, b) => b - a)[0] || null;
    const status = records.some((record) => record.status === "requires_repair") ? "requires_repair" : records.some((record) => record.status === "blocked") ? "blocked" : records.some((record) => record.status === "waiting") ? "waiting" : records.some((record) => record.status === "eligible") ? "eligible" : records.every((record) => record.status === "paid") ? "paid" : "batched";
    return {
      businessName: first.businessName, legalBusinessName: first.legalBusinessName, sector: first.sector, taxId: first.taxId,
      accountHolderName: first.accountHolderName, bankName: first.bankName, iban: first.iban, currency: first.currency,
      customerPaid: records.reduce((sum, record) => sum + record.customerPaid, 0), commission: records.reduce((sum, record) => sum + (record.commission || 0), 0),
      sellerNet: records.reduce((sum, record) => sum + (record.sellerNet || 0), 0), waiting: amount("waiting"), eligible: amount("eligible"), blocked: amount("blocked"),
      batched: amount("batched"), paid: amount("paid"), oldestUnpaid: dates[0] || null, nextEligibility: next, daysRemaining: next ? Math.max(0, Math.ceil((next - Date.now()) / 86400000)) : null,
      expectedPayout: next, lastPayout: last, status: labelStatus(status, labels), reason: sellerReason(records, labels),
    };
  });
  const nextPayoutDate = transactions.map((record) => record.status === "waiting" ? record.eligibleDate : record.status === "eligible" ? new Date() : null).filter(Boolean).sort((a, b) => a - b)[0] || null;
  return { labels, languageLabel: labels.languageLabel, companyName: "Petsupo", generatedAt: new Date(), generatedBy, reportVersion: REPORT_VERSION, dateRangeLabel: filters.dateRangeLabel || "All records", filtersLabel: filters.filtersLabel || "All records", currencyLabel: filters.currency || "All currencies", currency: filters.currency || "TRY", totals, sellers, transactions, nextPayoutDate, notes: [labels.subtitle, labels.repair, labels.waitingReason] };
}

async function buildFinancePayablesReportBuffer({ db, reportData, file, language, fullIban }) {
  const filters = reportData.filters || {};
  const all = (await db.collection('payoutIndex').get()).docs.map((doc) => ({ indexId: doc.id, ...doc.data() }));
  const selected = all.filter((index) => filterReportInput(index, filters));
  const sources = await sourceRecords(db, selected);
  const report = buildReport({
    indexes: selected,
    sources,
    labels: TEXT[language],
    filters,
    generatedBy: reportData.generatedBy || '',
    fullIban,
  });
  return buildFinancePayablesReportWorkbook({ report, language });
}

async function generateFinancePayablesReports({ db, bucket, adminUid, filters = {}, fullIban = true }) {
  const all = (await db.collection("payoutIndex").get()).docs.map((doc) => ({ indexId: doc.id, ...doc.data() }));
  const selected = all.filter((index) => filterReportInput(index, filters));
  const sources = await sourceRecords(db, selected);
  const requestedLanguages = filters.languages?.length ? filters.languages : ["tr", "en"];
  const requestedTypes = filters.documentTypes?.length ? filters.documentTypes : ["accountant", "internal"];
  const reportId = `finance-report-${Date.now()}-${crypto.randomBytes(4).toString("hex")}`;
  const today = new Date().toISOString().slice(0, 10);
  const files = [];
  for (const language of requestedLanguages) {
    if (!TEXT[language]) continue;
    if ((language === "tr" && !requestedTypes.includes("accountant")) || (language === "en" && !requestedTypes.includes("internal"))) continue;
    const labels = TEXT[language];
    const report = buildReport({ indexes: selected, sources, labels, filters, generatedBy: adminUid, fullIban });
    const buffer = await buildFinancePayablesReportWorkbook({ report, language });
    const fileName = language === "tr" ? `Petsupo_Odeme_Raporu_TR_${today}.xlsx` : `Petsupo_Payout_Report_EN_${today}.xlsx`;
    const storagePath = `finance-reports/${reportId}/${fileName}`;
    const checksum = crypto.createHash("sha256").update(buffer).digest("hex");
    try {
      await bucket.file(storagePath).save(buffer, { resumable: false, contentType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", metadata: { metadata: { reportId, generatedBy: adminUid, checksum, language } } });
    } catch (error) {
      throw classifyStorageFailure(error, "upload", storagePath);
    }
    files.push({ reportId, language, documentType: language === "tr" ? "accountant" : "internal", fileName, storagePath, fileSize: buffer.length, checksum, generatedAt: new Date().toISOString(), report });
  }
  try {
    await db.collection("financeReportRuns").doc(reportId).set({ reportId, generatedBy: adminUid, generatedAt: admin.firestore.FieldValue.serverTimestamp(), filters, fullIban, files: files.map(({ report, ...file }) => file), recordCount: selected.length, reportVersion: REPORT_VERSION });
  } catch (error) {
    console.error("[FinanceReport] report metadata write failed", {
      reportId,
      originalMessage: errorText(error),
      originalCode: error?.code ?? null,
      originalStack: error?.stack || null,
    });
    throw reportMetadataFailure("Finance report metadata could not be saved.", {
      originalCode: error?.code ?? null,
      originalMessage: errorText(error),
    });
  }
  return { reportId, files: files.map(({ report, ...file }) => file), totals: files[0]?.report.totals || {}, sellerCount: files[0]?.report.sellers.length || 0, transactionCount: selected.length };
}

async function downloadFinancePayablesReport({ db, bucket, adminUid, reportId, language, fullIban = false, authorization = {} }) {
  const reportSnap = await db.collection("financeReportRuns").doc(reportId).get();
  if (!reportSnap.exists) { const error = new Error("Finance report not found."); error.code = "not-found"; throw error; }
  const reportData = reportSnap.data() || {};
  const file = (reportData.files || []).find((item) => item.language === language) || reportData.files?.[0];
  if (!file?.storagePath || !file?.fileName || !file?.checksum) {
    throw reportMetadataFailure("Finance report file metadata is incomplete.", {
      reportId,
      language,
      file,
    });
  }
  if (reportData.fullIban !== false && !fullIban) {
    console.info('[FinanceAuth] finance report download denied', {
      uid: adminUid,
      resolvedRole: authorization.role || null,
      isAdmin: authorization.isAdmin === true,
      hasFinanceView: authorization.hasFinanceView === true,
      hasFinanceOperate: authorization.hasFinanceOperate === true,
      requestedReportId: reportId,
      reportFullIban: reportData.fullIban ?? null,
      generatedBy: reportData.generatedBy || null,
      authorizationDecision: 'deny',
      denialReason: 'full_iban_requires_finance_operate',
    });
    const error = new Error('Finance operation permission is required to download this report.');
    error.code = 'permission-denied';
    error.details = {
      code: 'FINANCE_REPORT_FULL_IBAN_REQUIRES_OPERATE',
      message: 'You can view Finance reports, but this report contains unmasked bank information and requires Finance Operations permission.',
      reportId,
      generatedBy: reportData.generatedBy || null,
    };
    throw error;
  }
  const storageFile = bucket.file(file.storagePath);
  try {
    await storageFile.getMetadata();
  } catch (error) {
    if (isStaleBillingClosedError(error)) {
      return buildInlineFinanceReport({ db, reportSnap, reportData, file, language, adminUid, fullIban, originalError: error });
    }
    throw classifyStorageFailure(error, "object_lookup", file.storagePath);
  }
  let url;
  try {
    [url] = await storageFile.getSignedUrl({ version: "v4", action: "read", expires: Date.now() + 15 * 60 * 1000, responseDisposition: `attachment; filename="${file.fileName}"`, responseType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" });
  } catch (error) {
    if (isStaleBillingClosedError(error)) {
      return buildInlineFinanceReport({ db, reportSnap, reportData, file, language, adminUid, fullIban, originalError: error });
    }
    throw classifyStorageFailure(error, "signed_url", file.storagePath);
  }
  try {
    await reportSnap.ref.collection("downloads").add({ downloadedBy: adminUid, downloadedAt: admin.firestore.FieldValue.serverTimestamp(), language: file.language, storagePath: file.storagePath, checksum: file.checksum });
  } catch (error) {
    console.error("[FinanceReport] download audit write failed", {
      reportId,
      storagePath: file.storagePath,
      originalMessage: errorText(error),
      originalCode: error?.code ?? null,
      originalStack: error?.stack || null,
    });
  }
  return { ...file, url };
}

async function buildInlineFinanceReport({ db, reportSnap, reportData, file, language, adminUid, fullIban, originalError }) {
  const declaredSize = Number(file.fileSize);
  if (Number.isFinite(declaredSize) && declaredSize > 5 * 1024 * 1024) {
    throw reportSizeFailure(reportData.reportId, declaredSize);
  }
  let buffer;
  try {
    buffer = await buildFinancePayablesReportBuffer({ db, reportData, file, language, fullIban });
  } catch (error) {
    console.error('[FinanceReport] inline fallback generation failed', {
      reportId: reportData.reportId,
      fileSize: declaredSize,
      actor: adminUid,
      originalStorageRequestId: storageRequestId(originalError),
      originalStorageError: errorText(originalError),
      fallbackError: errorText(error),
      fallbackStack: error?.stack || null,
    });
    throw error;
  }
  if (buffer.length > 5 * 1024 * 1024) {
    throw reportSizeFailure(reportData.reportId, buffer.length);
  }
  const checksum = crypto.createHash('sha256').update(buffer).digest('hex');
  console.warn('[FinanceReport] temporary inline fallback used', {
    reportId: reportData.reportId,
    fileSize: buffer.length,
    actor: adminUid,
    originalStorageRequestId: storageRequestId(originalError),
    originalStorageError: errorText(originalError),
  });
  try {
    await reportSnap.ref.collection('downloads').add({
      downloadedBy: adminUid,
      downloadedAt: admin.firestore.FieldValue.serverTimestamp(),
      language: file.language,
      storagePath: file.storagePath,
      checksum,
      deliveryMode: 'inline_base64',
      temporaryFallback: true,
    });
  } catch (error) {
    console.error('[FinanceReport] inline fallback audit write failed', {
      reportId: reportData.reportId,
      originalMessage: errorText(error),
      originalStack: error?.stack || null,
    });
  }
  return {
    ...file,
    fileSize: buffer.length,
    checksum,
    url: null,
    deliveryMode: 'inline_base64',
    temporaryFallback: true,
    bytesBase64: buffer.toString('base64'),
  };
}

module.exports = {
  generateFinancePayablesReports,
  downloadFinancePayablesReport,
  buildFinancePayablesReportBuffer,
  buildReport,
  normalizedStatus,
  classifyStorageFailure,
  isStaleBillingClosedError,
  TEXT,
  REPORT_VERSION,
};
