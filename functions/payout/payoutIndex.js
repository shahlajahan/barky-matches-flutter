"use strict";

const admin = require("firebase-admin");
const {
  getPayoutSectorAdapterByCollection,
} = require("./sectorAdapters");
const {
  evaluatePayoutEligibility,
} = require("../finance/financeEligibility");
const { appendLedgerEntries } = require("../finance/financeLedger");

const PAYOUT_INDEX_COLLECTION = "payoutIndex";
const PROJECTION_VERSION = 7;
const INDEXABLE_PAYOUT_STATUSES = new Set([
  "pending",
  "ready",
  "paid",
  "hold",
  "recovery_required",
]);
const INDEXABLE_SETTLEMENT_STATUSES = new Set([
  "not_started",
  "processing",
  "completed",
  "failed",
  "blocked",
  "awaiting_invoice",
]);

function allowedSourceCollections() {
  return new Set([
    "sellerOrders",
    "vet_appointments",
    "groomy_appointments",
    "hotel_bookings",
    "pet_taxi_bookings",
  ]);
}

function buildPayoutIndexId(sourceCollection, sourceDocumentId) {
  const collection = String(sourceCollection || "").trim();
  const documentId = String(sourceDocumentId || "").trim();
  if (!allowedSourceCollections().has(collection) || !documentId) {
    throw new Error("Invalid payout index source identity.");
  }
  return `${collection}__${documentId}`;
}

function millis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : Number(value) || 0;
}

function finiteMoney(value) {
  if (value === null || value === undefined || value === "") return null;
  const number = typeof value === "string" ? Number(value.trim()) : Number(value);
  return Number.isFinite(number) ? number : null;
}

function validateIndexablePayoutContract({
  sourceCollection,
  sourceDocumentId,
  record,
}) {
  if (!allowedSourceCollections().has(sourceCollection)) {
    return { valid: false, reason: "UNSUPPORTED_SOURCE_COLLECTION" };
  }
  if (!sourceDocumentId) return { valid: false, reason: "MISSING_SOURCE_DOCUMENT" };

  const adapter = getPayoutSectorAdapterByCollection(sourceCollection);
  const existingPayout = record?.payout;
  if (!existingPayout || typeof existingPayout !== "object") {
    return { valid: false, reason: "MISSING_PAYOUT_CONTRACT" };
  }
  const rawAmount = finiteMoney(existingPayout.amount);
  if (rawAmount === null || rawAmount < 0) {
    return { valid: false, reason: "INVALID_PAYOUT_AMOUNT" };
  }
  let payout;
  try {
    payout = adapter.normalizePayout({
      record,
      financial: record?.financial,
      existingPayout,
    });
  } catch (error) {
    return { valid: false, reason: error.code || "INVALID_PAYOUT_CONTRACT" };
  }
  const amount = finiteMoney(payout.amount);
  if (amount === null || amount < 0) {
    return { valid: false, reason: "INVALID_PAYOUT_AMOUNT" };
  }
  if (payout.version !== 1 || payout.sector !== adapter.sector) {
    return { valid: false, reason: "INVALID_PAYOUT_CONTRACT_VERSION" };
  }
  const payoutStatus = String(payout.status || "pending").trim().toLowerCase();
  if (!INDEXABLE_PAYOUT_STATUSES.has(payoutStatus)) {
    return { valid: false, reason: "INVALID_PAYOUT_STATUS" };
  }
  const settlementStatus = String(
    record?.settlement?.status || "not_started"
  ).trim().toLowerCase();
  if (!INDEXABLE_SETTLEMENT_STATUSES.has(settlementStatus)) {
    return { valid: false, reason: "INVALID_SETTLEMENT_STATUS" };
  }
  const businessId = adapter.getBusinessId(record);
  if (!businessId) return { valid: false, reason: "MISSING_BUSINESS_ID" };

  return {
    valid: true,
    adapter,
    payout,
    payoutStatus,
    settlementStatus,
    businessId: String(businessId),
    amount,
  };
}

function normalizePayoutIndexRecord({
  sourceCollection,
  sourceDocumentId,
  record,
  business = null,
  existingProjection = null,
  projectedAt = admin.firestore.FieldValue.serverTimestamp(),
  sourceUpdatedAt = record?.updatedAt || projectedAt,
}) {
  const validation = validateIndexablePayoutContract({
    sourceCollection,
    sourceDocumentId,
    record,
  });
  if (!validation.valid) {
    const error = new Error(`Payout contract is not indexable: ${validation.reason}`);
    error.code = validation.reason;
    throw error;
  }

  const id = buildPayoutIndexId(sourceCollection, sourceDocumentId);
  const payout = validation.payout;
  const settlement = record.settlement || {};
  const businessData = business || {};
  const payment = businessData.payment || {};
  const profile = businessData.profile || {};
  const legal = businessData.legal || {};
  const contact = businessData.contact || {};
  const sellerSnapshot = record.sellerSnapshot || {};
  const financial = record.financial || {};
  const pricing = record.pricing || {};
  const businessName =
    profile.displayName ||
    profile.businessName ||
    businessData.businessName ||
    businessData.name ||
    sellerSnapshot.businessName ||
    existingProjection?.businessName ||
    null;
  const legalBusinessName =
    legal.businessName ||
    legal.companyName ||
    payment.billingInfo?.legalBusinessName ||
    existingProjection?.legalBusinessName ||
    businessName;
  const iban = String(payment.iban || existingProjection?.iban || "")
    .replace(/\s+/g, "")
    .toUpperCase();
  const accountHolderName = String(
    payment.accountHolder || existingProjection?.accountHolderName || ""
  ).trim();
  const bankName = String(
    payment.bankName || existingProjection?.bankName || ""
  ).trim();
  const taxNumber =
    legal.taxNumber ||
    sellerSnapshot.taxNumber ||
    businessData.taxNumber ||
    existingProjection?.taxNumber ||
    null;
  const contactEmail =
    contact.email || businessData.email || existingProjection?.contactEmail || null;
  const contactPhone =
    contact.phone || businessData.phone || existingProjection?.contactPhone || null;
  const normalizedIban = iban.replace(/\s+/g, "").toUpperCase();
  const bankValidationStatus =
    !accountHolderName || !normalizedIban || !bankName
      ? "missing"
      : /^TR\d{24}$/.test(normalizedIban)
        ? "valid"
        : "invalid";
  const eligibility = evaluatePayoutEligibility({
    record,
    batchId: existingProjection?.batchId || null,
  });
  const searchTokens = Array.from(new Set([
    validation.businessId.toLowerCase(),
    String(sourceDocumentId).toLowerCase(),
    validation.adapter.sector,
    businessName,
    legalBusinessName,
    accountHolderName,
    iban,
    bankName,
    taxNumber,
    contactEmail,
    contactPhone,
    record.orderNumber,
    record.rootOrderId,
  ].filter(Boolean)));
  return {
    sourceCollection,
    sourceDocumentId: String(sourceDocumentId),
    sector: validation.adapter.sector,
    businessId: validation.businessId,
    payoutStatus: validation.payoutStatus,
    paidAt: payout.paidAt || existingProjection?.paidAt || null,
    paymentReference:
      payout.reference || existingProjection?.paymentReference || null,
    settlementStatus: validation.settlementStatus,
    settlementFailureCode: settlement.failureCode || null,
    settlementFailureMessage: settlement.failureMessage || null,
    sourceStatus: String(record.status || "").trim().toLowerCase(),
    refundStatus: String(
      record.refundStatus || record.refund?.status || ""
    ).trim().toLowerCase(),
    disputeStatus: String(
      record.disputeStatus || record.dispute?.status || ""
    ).trim().toLowerCase(),
    rootOrderId: record.rootOrderId || record.orderId || null,
    orderNumber: record.orderNumber || null,
    sourceNumber:
      record.orderNumber ||
      record.bookingNumber ||
      record.appointmentNumber ||
      record.rideNumber ||
      record.referenceNumber ||
      null,
    // Appointment snapshots historically stored the customer-paid amount as
    // `finalPrice`, while marketplace orders use `grossAmount`/pricing. Keep
    // the projection contract canonical without recalculating commission.
    grossAmount: finiteMoney(
      financial.grossAmount ??
      financial.finalPrice ??
      pricing.grandTotal ??
      record.payment?.grossAmount ??
      record.payment?.amount
    ) || 0,
    commissionAmount: finiteMoney(
      financial.commissionAmount ??
      financial.platformRevenue ??
      pricing.commissionAmount
    ) || 0,
    commissionDataQuality: (() => {
      const commission = finiteMoney(
        financial.commissionAmount ??
        financial.platformRevenue ??
        pricing.commissionAmount
      );
      if (commission === null) return "missing_snapshot";
      // A zero amount without a persisted rate/rule is not evidence that no
      // fee was due. Keep the historical amount intact, but surface it as an
      // ambiguous legacy snapshot rather than silently treating it as a
      // verified zero.
      if (
        commission === 0 &&
        finiteMoney(financial.commissionRate) === null &&
        !financial.ruleSnapshot?.commissionRate
      ) {
        return "ambiguous_legacy";
      }
      return "verified_snapshot";
    })(),
    amount: validation.amount,
    currency: String(payout.currency || record.financial?.currency || "TRY").toUpperCase(),
    payoutContractVersion: payout.version,
    sourceUpdatedAt,
    projectedAt,
    projectionVersion: PROJECTION_VERSION,
    successfulPaymentAt: eligibility.successfulPaymentAtMillis
      ? admin.firestore.Timestamp.fromMillis(
        eligibility.successfulPaymentAtMillis
      )
      : null,
    successfulPaymentSource: eligibility.successfulPaymentSource,
    eligibilityDate: eligibility.eligibilityDateMillis
      ? admin.firestore.Timestamp.fromMillis(eligibility.eligibilityDateMillis)
      : null,
    eligibilityStatus: eligibility.status,
    eligibilityReasonCodes: eligibility.reasonCodes,
    searchTokens,
    businessName,
    legalBusinessName,
    accountHolderName,
    iban,
    bankName,
    bankValidationStatus,
    taxNumber,
    contactEmail,
    contactPhone,
    sellerOwnerUid:
      businessData.ownerUid ||
      sellerSnapshot.ownerUid ||
      record.sellerUid ||
      existingProjection?.sellerOwnerUid ||
      null,
    sourceCreatedAt:
      record.createdAt || record.paidAt || record.payment?.paidAt || sourceUpdatedAt,
    updatedAt: projectedAt,
    indexable: true,
    indexId: id,
  };
}

function isStaleProjection(existing, incoming) {
  if (!existing) return false;
  const existingProjectionVersion = Number(existing.projectionVersion || 0);
  const incomingProjectionVersion = Number(incoming.projectionVersion || 0);
  if (existingProjectionVersion > incomingProjectionVersion) {
    return true;
  }
  if (existingProjectionVersion < incomingProjectionVersion) return false;
  if (Number(existing.payoutContractVersion || 0) > Number(incoming.payoutContractVersion || 0)) {
    return true;
  }
  const existingSource = millis(existing.sourceUpdatedAt);
  const incomingSource = millis(incoming.sourceUpdatedAt);
  if (existingSource > incomingSource) return true;
  if (existingSource === incomingSource && millis(existing.projectedAt) > millis(incoming.projectedAt)) {
    return true;
  }
  return false;
}

async function projectPayoutIndex({ db, sourceCollection, sourceDocumentId, record }) {
  const indexId = buildPayoutIndexId(sourceCollection, sourceDocumentId);
  const indexRef = db.collection(PAYOUT_INDEX_COLLECTION).doc(indexId);
  const adapter = getPayoutSectorAdapterByCollection(sourceCollection);
  const businessId = adapter.getBusinessId(record);
  const businessSnap = businessId
    ? await db.collection("businesses").doc(String(businessId)).get()
    : null;
  let skipped = false;
  await db.runTransaction(async (transaction) => {
    const existingSnap = await transaction.get(indexRef);
    const existing = existingSnap.exists ? existingSnap.data() || {} : null;
    const projection = normalizePayoutIndexRecord({
      sourceCollection,
      sourceDocumentId,
      record,
      business: businessSnap?.exists ? businessSnap.data() || {} : null,
      existingProjection: existing,
    });
    if (isStaleProjection(existing, projection)) {
      skipped = true;
      return;
    }
    const ledgerEntries = [];
    if (
      projection.successfulPaymentAt
    ) {
      const common = {
        sourceCollection,
        sourceDocumentId,
        businessId: projection.businessId,
        rootOrderId: projection.rootOrderId,
        currency: projection.currency,
        actor: { type: "system", id: "payout_projection" },
        occurredAt: projection.successfulPaymentAt,
      };
      ledgerEntries.push(
        {
          ...common,
          eventType: "customer_payment_verified",
          amount: projection.grossAmount,
          direction: "credit",
          reason: "verified_payment_projection",
          idempotencyKey: "verified_payment_v1",
        },
        {
          ...common,
          eventType: "platform_commission_recognized",
          amount: projection.commissionAmount,
          direction: "credit",
          reason: "frozen_financial_snapshot",
          idempotencyKey: "commission_v1",
        },
        {
          ...common,
          eventType: "seller_liability_recognized",
          amount: projection.amount,
          direction: "credit",
          reason: "settlement_completed",
          idempotencyKey: "seller_liability_v1",
        },
      );
    }
    if (
      existing?.eligibilityStatus === "waiting_period" &&
      projection.eligibilityStatus === "eligible"
    ) {
      ledgerEntries.push({
        eventType: "payout_eligibility_reached",
        sourceCollection,
        sourceDocumentId,
        businessId: projection.businessId,
        rootOrderId: projection.rootOrderId,
        amount: projection.amount,
        currency: projection.currency,
        direction: "memo",
        actor: { type: "system", id: "eligibility_scheduler" },
        reason: "twenty_one_day_period_completed",
        idempotencyKey: "eligibility_reached_v1",
        occurredAt: projection.eligibilityDate,
      });
    }
    if (ledgerEntries.length > 0) {
      await appendLedgerEntries(transaction, db, ledgerEntries);
    }
    transaction.set(indexRef, projection, { merge: true });
  });
  return { indexId, skipped };
}

function projectPayoutIndexInTransaction({
  transaction,
  indexRef,
  sourceCollection,
  sourceDocumentId,
  record,
  existingProjection = null,
}) {
  const projection = normalizePayoutIndexRecord({
    sourceCollection,
    sourceDocumentId,
    record,
    existingProjection,
    projectedAt: admin.firestore.FieldValue.serverTimestamp(),
    sourceUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  transaction.set(indexRef, projection, { merge: true });
  return projection;
}

module.exports = {
  PAYOUT_INDEX_COLLECTION,
  PROJECTION_VERSION,
  INDEXABLE_PAYOUT_STATUSES,
  INDEXABLE_SETTLEMENT_STATUSES,
  allowedSourceCollections,
  buildPayoutIndexId,
  validateIndexablePayoutContract,
  normalizePayoutIndexRecord,
  isStaleProjection,
  projectPayoutIndex,
  projectPayoutIndexInTransaction,
};
