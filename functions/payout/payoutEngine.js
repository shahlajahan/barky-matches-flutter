const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

const {
  getPayoutSectorAdapter,
  getPayoutSectorAdapterByCollection,
} = require("./sectorAdapters");
const {
  financialEventData,
  newFinancialEventRef,
  createFinancialEvent,
} = require("./financialEvents");
const { payableFromRecord } = require("./payableContract");
const {
  PAYOUT_INDEX_COLLECTION,
  buildPayoutIndexId,
  allowedSourceCollections,
  projectPayoutIndexInTransaction,
} = require("./payoutIndex");
const {
  FINANCE_LEDGER_COLLECTION,
  ledgerEntryId,
  ledgerEntry,
} = require("../finance/financeLedger");

// Payout Engine V2, Milestone 1 (see docs/architecture/payout-engine-v2.md
// and docs/architecture/TASK.md): this file is a generalized extraction of
// the Pet Shop payout logic that used to live directly in functions/index.js
// as markSellerPayoutReady, markSellerPayoutPaid, applyRefundToSellerPayout,
// assertSellerOrderPayoutApprovable, assertSellerBankAccountValid, and
// migrateMalformedPayoutFields. This milestone is a pure refactor: every
// write shape, field name, error message, and code path below is
// byte-for-byte identical in behavior to the code it replaces when called
// with sector: "petshop" — only the collection name and a handful of
// per-record field lookups (businessId/shopId, sellerUid) are now resolved
// through the sector adapter (functions/payout/adapters/petshopPayoutAdapter.js)
// instead of being hardcoded.

const TURKISH_IBAN_REGEX = /^TR\d{24}$/;

function normalizeLower(value) {
  return String(value || "").trim().toLowerCase();
}

function roundMoney(value) {
  return Number((Number(value) || 0).toFixed(2));
}

function createRefundLedgerEntries({
  transaction,
  db,
  adapter,
  payableId,
  businessId,
  rootOrderId,
  refundEventId,
  reversal,
  actor,
  reason,
}) {
  const common = {
    sourceCollection: adapter.collection,
    sourceDocumentId: payableId,
    businessId,
    rootOrderId,
    currency: reversal.currency || "TRY",
    actor,
    reason: reason || "refund_reconciliation",
  };
  const entries = [
    {
      ...common,
      eventType: "customer_refund",
      amount: reversal.customerRefundAmount,
      direction: "debit",
      idempotencyKey: `${refundEventId}:customer`,
    },
    {
      ...common,
      eventType: "commission_reversed",
      amount: reversal.commissionReversalAmount,
      direction: "debit",
      idempotencyKey: `${refundEventId}:commission`,
    },
    {
      ...common,
      eventType: "seller_liability_reversed",
      amount: reversal.sellerPayoutReversalAmount,
      direction: "debit",
      idempotencyKey: `${refundEventId}:seller`,
    },
  ];
  entries.forEach((entry) => {
    const id = ledgerEntryId(entry);
    transaction.create(
      db.collection(FINANCE_LEDGER_COLLECTION).doc(id),
      ledgerEntry(entry)
    );
  });
}

function calculateRefundReversal({
  record,
  customerRefundAmount,
  refundedCommissionBase,
  isFullRefund = false,
}) {
  const financial = record?.financial || {};
  const pricing = record?.pricing || {};
  const payout = record?.payout || {};
  const prior = financial.refundReconciliation || {};
  const originalCustomerCharge = roundMoney(
    financial.grossAmount ??
      pricing.grandTotal ??
      record?.payment?.grossAmount ??
      0
  );
  const originalCommission = roundMoney(financial.commissionAmount);
  const originalSellerReceivable = roundMoney(
    financial.businessNetAmount ??
      financial.businessReceivable ??
      payout.amount ??
      Math.max(0, originalCustomerCharge - originalCommission)
  );
  const originalCommissionBase = roundMoney(
    pricing.subtotal ?? financial.commissionBaseAmount ?? originalCustomerCharge
  );
  const priorCustomerRefunded = roundMoney(prior.customerRefundedAmount);
  const priorCommissionReversed = roundMoney(prior.commissionReversedAmount);
  const priorSellerReversed = roundMoney(
    prior.sellerReceivableReversedAmount
  );
  const refundableCustomerBalance = roundMoney(
    Math.max(0, originalCustomerCharge - priorCustomerRefunded)
  );
  const normalizedCustomerRefund = roundMoney(
    Math.min(
      Math.max(0, Number(customerRefundAmount) || 0),
      refundableCustomerBalance
    )
  );
  const remainingCommission = roundMoney(
    Math.max(0, originalCommission - priorCommissionReversed)
  );
  const remainingSellerReceivable = roundMoney(
    Math.max(0, originalSellerReceivable - priorSellerReversed)
  );

  let commissionReversalAmount;
  if (isFullRefund) {
    commissionReversalAmount = remainingCommission;
  } else {
    const commissionBase = roundMoney(
      Math.min(
        Math.max(0, Number(refundedCommissionBase) || 0),
        originalCommissionBase
      )
    );
    commissionReversalAmount =
      originalCommissionBase > 0
        ? roundMoney(
            Math.min(
              remainingCommission,
              (originalCommission * commissionBase) / originalCommissionBase
            )
          )
        : 0;
  }

  const sellerPayoutReversalAmount = roundMoney(
    Math.min(
      remainingSellerReceivable,
      Math.max(0, normalizedCustomerRefund - commissionReversalAmount)
    )
  );
  const customerRefundedAmount = roundMoney(
    priorCustomerRefunded + normalizedCustomerRefund
  );
  const commissionReversedAmount = roundMoney(
    priorCommissionReversed + commissionReversalAmount
  );
  const sellerReceivableReversedAmount = roundMoney(
    priorSellerReversed + sellerPayoutReversalAmount
  );

  return {
    originalCustomerCharge,
    originalCommission,
    originalSellerReceivable,
    customerRefundAmount: normalizedCustomerRefund,
    commissionReversalAmount,
    sellerPayoutReversalAmount,
    customerRefundedAmount,
    commissionReversedAmount,
    sellerReceivableReversedAmount,
    remainingCustomerBalance: roundMoney(
      Math.max(0, originalCustomerCharge - customerRefundedAmount)
    ),
    remainingPlatformRevenue: roundMoney(
      Math.max(0, originalCommission - commissionReversedAmount)
    ),
    remainingBusinessReceivable: roundMoney(
      Math.max(0, originalSellerReceivable - sellerReceivableReversedAmount)
    ),
    isFullRefund,
  };
}

// ------------------------------------------------------------------
// P0 hotfix (Phase 1.1): one-time, idempotent repair for a prior bug
// where these payout writes used dotted keys like "payout.status" with
// transaction.set(ref, {...}, {merge:true}), which treats a dotted
// string key as one literal top-level field name, never as a
// payout.status path — the real nested `payout` object was therefore
// never actually updated. If any of these literal fields are present on
// a record, fold their values into a real nested `payout` map (literal
// values win over stale nested ones, since they reflect the last
// attempted state change) and return the merge patch plus the literal
// keys to delete. A Firestore transaction can only write a given
// document once, so callers must merge this into the single
// transaction.set() call they already make, not issue it as a separate
// write.
// ------------------------------------------------------------------
const MALFORMED_PAYOUT_KEYS = [
  "payout.status",
  "payout.previousStatus",
  "payout.readyAt",
  "payout.paidAt",
  "payout.reference",
  "payout.note",
  "payout.recoveryRequiredAt",
  "payout.recoveryReason",
  "payout.outstandingDebt",
  "payout.relatedReturnIds",
  "payout.holdAt",
  "payout.holdReason",
  "payout.updatedAt",
];

function migrateMalformedPayoutFields(record) {
  const malformedKeysPresent = MALFORMED_PAYOUT_KEYS.filter((key) =>
    Object.prototype.hasOwnProperty.call(record, key)
  );

  if (malformedKeysPresent.length === 0) {
    return null;
  }

  const existingPayout =
    record.payout && typeof record.payout === "object" ? record.payout : {};
  const migratedPayout = { ...existingPayout };
  const deletes = {};

  for (const key of malformedKeysPresent) {
    const fieldName = key.slice("payout.".length);
    migratedPayout[fieldName] = record[key];
    deletes[key] = admin.firestore.FieldValue.delete();
  }

  return { migratedPayout, deletes, migratedKeys: malformedKeysPresent };
}

// The sector-agnostic half of the original payout approval guard:
// a payout already on hold or flagged for debt recovery can never be
// approved further, regardless of sector.
function assertPayoutNotBlocked(payout) {
  const status = normalizeLower(payout?.status);

  if (status === "recovery_required") {
    throw new HttpsError(
      "failed-precondition",
      "This payout requires manual debt recovery before it can be approved. A refund was issued after the business was already paid."
    );
  }

  if (status === "hold") {
    throw new HttpsError(
      "failed-precondition",
      "This payout is on hold pending refund reconciliation and cannot be approved yet."
    );
  }
}

// Unchanged from the original assertSellerBankAccountValid, except the
// businessId is now resolved by the caller via the sector adapter instead
// of being derived inline from a sellerOrder-shaped object.
async function assertBankAccountValid({ transaction, db, businessId }) {
  if (!businessId) {
    throw new HttpsError(
      "failed-precondition",
      "This payable record has no associated business; cannot verify bank account information."
    );
  }

  const businessRef = db.collection("businesses").doc(String(businessId));
  const businessSnap = transaction
    ? await transaction.get(businessRef)
    : await businessRef.get();
  const business = businessSnap.exists ? businessSnap.data() || {} : {};
  const payment = business.payment || {};
  const accountHolder = String(payment.accountHolder || "").trim();
  const iban = String(payment.iban || "").trim();

  if (!accountHolder || !TURKISH_IBAN_REGEX.test(iban)) {
    throw new HttpsError(
      "failed-precondition",
      "This business has not saved valid bank account information yet. Add an account holder name and a valid IBAN in Settings → Bank Account before this payout can be marked ready."
    );
  }
}

async function markPayoutReady({ db, sector, payableId, payoutIndexId, actor }) {
  const adapter = sector ? getPayoutSectorAdapter(sector) : null;
  const legacyPayableId = String(payableId || "").trim();
  const requestedIndexId = String(
    payoutIndexId || (adapter && legacyPayableId
      ? buildPayoutIndexId(adapter.collection, legacyPayableId)
      : "")
  ).trim();
  if (!requestedIndexId) {
    throw new HttpsError("invalid-argument", "payoutIndexId is required.");
  }
  const indexRef = db.collection(PAYOUT_INDEX_COLLECTION).doc(requestedIndexId);
  const eventRef = newFinancialEventRef(db);

  const result = await db.runTransaction(async (transaction) => {
    const indexSnap = await transaction.get(indexRef);
    const indexData = indexSnap.exists ? indexSnap.data() || {} : null;
    const sourceCollection = indexData?.sourceCollection || adapter?.collection;
    const sourceDocumentId = indexData?.sourceDocumentId || legacyPayableId;
    if (!allowedSourceCollections().has(sourceCollection) || !sourceDocumentId) {
      throw new HttpsError("not-found", "Payout index entry not found.");
    }
    if (adapter && sourceCollection !== adapter.collection) {
      throw new HttpsError("failed-precondition", "Payout index sector mismatch.");
    }
    const resolvedAdapter = getPayoutSectorAdapterByCollection(sourceCollection);
    const recordRef = db.collection(sourceCollection).doc(String(sourceDocumentId));
    const snap = await transaction.get(recordRef);

    if (!snap.exists) {
      throw new HttpsError("not-found", "Payable record not found.");
    }

    const record = snap.data() || {};
    const migration = migrateMalformedPayoutFields(record);
    const legacyPayout = migration
      ? migration.migratedPayout
      : record.payout || {};
    const effectiveRecord = migration
      ? { ...record, payout: legacyPayout }
      : record;
    const payable = payableFromRecord({ adapter: resolvedAdapter, record: effectiveRecord });
    const effectivePayout = payable.payout;
    const currentPayoutStatus = effectivePayout.status || "unknown";

    // A repeated ready command is a true no-op. In particular, do not
    // refresh timestamps or append a second financial event.
    if (normalizeLower(currentPayoutStatus) === "ready") {
      return { transitioned: false };
    }

    if (currentPayoutStatus === "paid") {
      throw new HttpsError(
        "failed-precondition",
        "This payout is already paid."
      );
    }

    assertPayoutNotBlocked(effectivePayout);

    if (resolvedAdapter.assertNoBlockingEvents) {
      await resolvedAdapter.assertNoBlockingEvents({
        transaction,
        db,
        payableId: sourceDocumentId,
        record: effectiveRecord,
      });
    }

    await assertBankAccountValid({
      transaction,
      db,
      businessId: payable.businessId,
    });

    transaction.set(
      recordRef,
      {
        ...(migration ? migration.deletes : {}),
        payout: {
          ...effectivePayout,
          status: "ready",
          readyAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    createFinancialEvent(
      transaction,
      eventRef,
      financialEventData({
        eventType: "payout_ready",
        sourceCollection: resolvedAdapter.collection,
        sourceDocument: sourceDocumentId,
        sector: resolvedAdapter.sector,
        businessId: payable.businessId,
        actor,
        previousState: currentPayoutStatus,
        newState: "ready",
        amount: effectivePayout.amount,
        currency: effectivePayout.currency,
        reason: "payout_marked_ready",
        metadata: {},
      })
    );

    projectPayoutIndexInTransaction({
      transaction,
      indexRef,
      sourceCollection: resolvedAdapter.collection,
      sourceDocumentId,
      existingProjection: indexData,
      record: {
        ...effectiveRecord,
        payout: {
          ...effectivePayout,
          status: "ready",
        },
      },
    });

    return { transitioned: true };
  });

  return {
    success: true,
    payableId: legacyPayableId || requestedIndexId,
    payoutStatus: "ready",
    transitioned: result.transitioned,
  };
}

async function markPayoutPaid({
  db,
  sector,
  payableId,
  payoutIndexId,
  reference,
  note,
  actor,
}) {
  const adapter = sector ? getPayoutSectorAdapter(sector) : null;
  const legacyPayableId = String(payableId || "").trim();
  const requestedIndexId = String(
    payoutIndexId || (adapter && legacyPayableId
      ? buildPayoutIndexId(adapter.collection, legacyPayableId)
      : "")
  ).trim();
  if (!requestedIndexId) {
    throw new HttpsError("invalid-argument", "payoutIndexId is required.");
  }
  const indexRef = db.collection(PAYOUT_INDEX_COLLECTION).doc(requestedIndexId);
  const eventRef = newFinancialEventRef(db);

  await db.runTransaction(async (transaction) => {
    const indexSnap = await transaction.get(indexRef);
    const indexData = indexSnap.exists ? indexSnap.data() || {} : null;
    const sourceCollection = indexData?.sourceCollection || adapter?.collection;
    const sourceDocumentId = indexData?.sourceDocumentId || legacyPayableId;
    if (!allowedSourceCollections().has(sourceCollection) || !sourceDocumentId) {
      throw new HttpsError("not-found", "Payout index entry not found.");
    }
    if (adapter && sourceCollection !== adapter.collection) {
      throw new HttpsError("failed-precondition", "Payout index sector mismatch.");
    }
    const resolvedAdapter = getPayoutSectorAdapterByCollection(sourceCollection);
    const recordRef = db.collection(sourceCollection).doc(String(sourceDocumentId));
    const snap = await transaction.get(recordRef);

    if (!snap.exists) {
      throw new HttpsError("not-found", "Payable record not found.");
    }

    const record = snap.data() || {};
    const migration = migrateMalformedPayoutFields(record);
    const legacyPayout = migration
      ? migration.migratedPayout
      : record.payout || {};
    const effectiveRecord = migration
      ? { ...record, payout: legacyPayout }
      : record;
    const payable = payableFromRecord({ adapter: resolvedAdapter, record: effectiveRecord });
    const effectivePayout = payable.payout;
    const payoutStatus = effectivePayout.status || "unknown";

    if (payoutStatus !== "ready") {
      throw new HttpsError(
        "failed-precondition",
        `This payout is currently "${payoutStatus}". Only Ready payouts can be marked as Paid.`
      );
    }

    assertPayoutNotBlocked(effectivePayout);

    if (resolvedAdapter.assertNoBlockingEvents) {
      await resolvedAdapter.assertNoBlockingEvents({
        transaction,
        db,
        payableId: sourceDocumentId,
        record: effectiveRecord,
      });
    }

    transaction.set(
      recordRef,
      {
        ...(migration ? migration.deletes : {}),
        payout: {
          ...effectivePayout,
          status: "paid",
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
          reference,
          note: note || null,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    createFinancialEvent(
      transaction,
      eventRef,
      financialEventData({
        eventType: "payout_paid",
        sourceCollection: resolvedAdapter.collection,
        sourceDocument: sourceDocumentId,
        sector: resolvedAdapter.sector,
        businessId: payable.businessId,
        actor,
        previousState: payoutStatus,
        newState: "paid",
        amount: effectivePayout.amount,
        currency: effectivePayout.currency,
        reason: "payout_marked_paid",
        metadata: {
          reference,
          note: note || null,
        },
      })
    );

    projectPayoutIndexInTransaction({
      transaction,
      indexRef,
      sourceCollection: resolvedAdapter.collection,
      sourceDocumentId,
      existingProjection: indexData,
      record: {
        ...effectiveRecord,
        payout: {
          ...effectivePayout,
          status: "paid",
          reference,
          note: note || null,
        },
      },
    });
  });

  return {
    success: true,
    payableId: legacyPayableId || requestedIndexId,
    payoutIndexId: requestedIndexId,
    payoutStatus: "paid",
    reference,
  };
}

async function applyRefundToPayout({
  db,
  sector,
  payableId,
  refundEventId,
  refundAmount,
  refundedCommissionBase,
  isFullRefund = false,
  rootOrderId = null,
  reason,
  actor,
}) {
  if (!payableId) {
    return { applied: false, reason: "missing_payableId" };
  }

  const adapter = getPayoutSectorAdapter(sector);
  const recordRef = db.collection(adapter.collection).doc(payableId);
  // Deterministic id keyed on refundEventId: a given refund event can
  // only ever be applied once (enforced upstream by the transactional
  // claim in the caller, e.g. triggerOrderReturnRefund), so this makes
  // debt recording idempotent even if this function is ever invoked
  // twice for the same refund.
  const debtRef = db.collection(adapter.debtCollection).doc(refundEventId);
  const eventRef = newFinancialEventRef(db);
  const indexRef = db
    .collection(PAYOUT_INDEX_COLLECTION)
    .doc(buildPayoutIndexId(adapter.collection, payableId));

  return db.runTransaction(async (transaction) => {
    const snap = await transaction.get(recordRef);
    const reservedIndexSnap = await transaction.get(indexRef);

    if (!snap.exists) {
      return { applied: false, reason: "sellerOrder_not_found" };
    }

    const record = snap.data() || {};
    const migration = migrateMalformedPayoutFields(record);
    const effectiveRecord = migration
      ? { ...record, payout: migration.migratedPayout }
      : record;
    const payable = payableFromRecord({ adapter, record: effectiveRecord });
    const payout = payable.payout;
    const payoutStatus = normalizeLower(payout.status || "pending");
    const debtSnap =
      payoutStatus === "paid" || payoutStatus === "recovery_required"
        ? await transaction.get(debtRef)
        : null;
    const now = admin.firestore.FieldValue.serverTimestamp();
    // See migrateMalformedPayoutFields: when migration is active, a
    // transform sentinel (arrayUnion/increment) applied in this same
    // write would compute against the real nested field's current
    // server value (never actually written under the bug), silently
    // discarding the historical value we just folded in from the
    // malformed literal field. So during migration only, compute the
    // resulting value in JS as a plain value instead of a transform.
    const priorRelatedReturnIds = Array.isArray(payout.relatedReturnIds)
      ? payout.relatedReturnIds
      : [];
    if (priorRelatedReturnIds.includes(refundEventId)) {
      return { applied: false, reason: "refund_already_applied" };
    }
    const relatedReturnIdsField = migration
      ? Array.from(new Set([...priorRelatedReturnIds, refundEventId]))
      : admin.firestore.FieldValue.arrayUnion(refundEventId);
    const priorOutstandingDebt =
      typeof payout.outstandingDebt === "number" ? payout.outstandingDebt : 0;
    const reservedIndex = reservedIndexSnap.exists
      ? reservedIndexSnap.data() || {}
      : {};
    const reservedBatchId = String(reservedIndex.batchId || "").trim();
    if (reservedBatchId) {
      const batchRef = db.collection("payoutBatches").doc(reservedBatchId);
      const batchSnap = await transaction.get(batchRef);
      const batch = batchSnap.exists ? batchSnap.data() || {} : {};
      const batchItemId = String(reservedIndex.batchItemId || "").trim();
      const isMutableBatch = batch.status === "draft" && !batch.frozenAt;
      const itemRef = batchItemId
        ? batchRef.collection("items").doc(batchItemId)
        : null;
      const itemSnap =
        isMutableBatch && itemRef ? await transaction.get(itemRef) : null;
      if (isMutableBatch && itemSnap?.exists) {
        const item = itemSnap.data() || {};
        const grossAmount = Number(reservedIndex.grossAmount || 0);
        const commissionAmount = Number(reservedIndex.commissionAmount || 0);
        const netAmount = Number(reservedIndex.amount || 0);
        const remainingCount = Math.max(0, Number(item.payoutCount || 1) - 1);
        if (remainingCount === 0) {
          transaction.delete(itemRef);
        } else {
          transaction.update(itemRef, {
            payoutCount: remainingCount,
            grossTotal: roundMoney(Number(item.grossTotal || 0) - grossAmount),
            commissionTotal: roundMoney(
              Number(item.commissionTotal || 0) - commissionAmount
            ),
            netTotal: roundMoney(Number(item.netTotal || 0) - netAmount),
            payoutIndexIds: admin.firestore.FieldValue.arrayRemove(indexRef.id),
            sourceDocumentIds: admin.firestore.FieldValue.arrayRemove(payableId),
            updatedAt: now,
          });
        }
        transaction.update(batchRef, {
          sellerCount: Math.max(
            0,
            Number(batch.sellerCount || 1) - (remainingCount === 0 ? 1 : 0)
          ),
          unpaidItemCount: Math.max(
            0,
            Number(batch.unpaidItemCount || 1) -
              (remainingCount === 0 ? 1 : 0)
          ),
          payoutRecordCount: Math.max(
            0,
            Number(batch.payoutRecordCount || 1) - 1
          ),
          grossTotal: roundMoney(Number(batch.grossTotal || 0) - grossAmount),
          commissionTotal: roundMoney(
            Number(batch.commissionTotal || 0) - commissionAmount
          ),
          netTotal: roundMoney(Number(batch.netTotal || 0) - netAmount),
          recalculatedAt: now,
          recalculationReason: "refund_or_reversal",
          updatedAt: now,
        });
        transaction.update(indexRef, {
          batchId: admin.firestore.FieldValue.delete(),
          batchItemId: admin.firestore.FieldValue.delete(),
          batchNumber: admin.firestore.FieldValue.delete(),
          batchStatus: admin.firestore.FieldValue.delete(),
          reservedAt: admin.firestore.FieldValue.delete(),
          reservedBy: admin.firestore.FieldValue.delete(),
        });
      } else {
        transaction.set(batchRef, {
          status: "invalidated",
          invalidatedAt: now,
          invalidatedByPayoutIndexId: indexRef.id,
          invalidationReason: "refund_or_reversal",
          updatedAt: now,
        }, { merge: true });
      }
    }
    const reversal = calculateRefundReversal({
      record: effectiveRecord,
      customerRefundAmount: refundAmount,
      refundedCommissionBase,
      isFullRefund,
    });
    const reconciliation = {
      version: 1,
      originalCustomerCharge: reversal.originalCustomerCharge,
      originalCommission: reversal.originalCommission,
      originalSellerReceivable: reversal.originalSellerReceivable,
      customerRefundedAmount: reversal.customerRefundedAmount,
      commissionReversedAmount: reversal.commissionReversedAmount,
      sellerReceivableReversedAmount:
        reversal.sellerReceivableReversedAmount,
      remainingCustomerBalance: reversal.remainingCustomerBalance,
      remainingPlatformRevenue: reversal.remainingPlatformRevenue,
      remainingBusinessReceivable: reversal.remainingBusinessReceivable,
      lastRefundEventId: refundEventId,
      lastRefundAmount: reversal.customerRefundAmount,
      lastCommissionReversalAmount: reversal.commissionReversalAmount,
      lastSellerPayoutReversalAmount:
        reversal.sellerPayoutReversalAmount,
      lastRefundWasFull: reversal.isFullRefund,
      reconciledAt: now,
    };
    const settlementReconciliation = {
      status: "completed",
      refundEventId,
      customerRefundAmount: reversal.customerRefundAmount,
      commissionReversalAmount: reversal.commissionReversalAmount,
      sellerPayoutReversalAmount: reversal.sellerPayoutReversalAmount,
      remainingPlatformRevenue: reversal.remainingPlatformRevenue,
      remainingBusinessReceivable: reversal.remainingBusinessReceivable,
      reconciledAt: now,
    };
    const eventMetadata = {
      refundEventId,
      rootOrderId: rootOrderId || record.rootOrderId || null,
      originalCustomerCharge: reversal.originalCustomerCharge,
      originalCommission: reversal.originalCommission,
      originalSellerReceivable: reversal.originalSellerReceivable,
      customerRefundAmount: reversal.customerRefundAmount,
      commissionReversalAmount: reversal.commissionReversalAmount,
      sellerPayoutReversalAmount: reversal.sellerPayoutReversalAmount,
      remainingCustomerBalance: reversal.remainingCustomerBalance,
      remainingPlatformRevenue: reversal.remainingPlatformRevenue,
      remainingBusinessReceivable: reversal.remainingBusinessReceivable,
      fullRefund: reversal.isFullRefund,
      payoutAmountBeforeReversal: payout.amount ?? null,
    };

    // "paid" is the first refund-after-payout on this record: it
    // transitions payout.status into recovery_required. "recovery_required"
    // is every subsequent refund-after-payout on the *same* record (e.g.
    // two separate returns both refunded after payout) — it must be
    // handled the same way (its own deterministic debt record, debt
    // accumulated), and must NEVER be downgraded back to "hold" by
    // falling through to the default branch below.
    if (payoutStatus === "paid" || payoutStatus === "recovery_required") {
      createRefundLedgerEntries({
        transaction,
        db,
        adapter,
        payableId,
        businessId: payable.businessId,
        rootOrderId: rootOrderId || record.rootOrderId || null,
        refundEventId,
        reversal: { ...reversal, currency: payout.currency },
        actor,
        reason,
      });

      if (!debtSnap.exists) {
        transaction.set(debtRef, {
          sellerDebt: reversal.sellerPayoutReversalAmount,
          refundAmount: reversal.customerRefundAmount,
          commissionReversalAmount: reversal.commissionReversalAmount,
          reason: reason || "refund_after_payout",
          createdAt: now,
          sellerOrderId: payableId,
          returnId: refundEventId,
          // Additional linkage/bookkeeping fields — required to ever query
          // or later deduct this debt; not part of the recovery logic
          // itself (which remains manual / a later phase).
          sellerUid: payable.recoveryOwnerId,
          businessId: payable.businessId,
          status: "outstanding",
          recovered: false,
          recoveredAmount: 0,
          updatedAt: now,
        });
      }

      transaction.set(
        recordRef,
        {
          ...(migration ? migration.deletes : {}),
          payout: {
            ...payout,
            status: "recovery_required",
            // Preserve the original pre-recovery status (e.g. "paid") and
            // the original recovery reason/timestamp across repeated
            // calls — only set them the first time this record enters
            // recovery_required, never overwrite them on subsequent
            // refunds.
            previousStatus: payout.previousStatus || payout.status || null,
            recoveryRequiredAt: payout.recoveryRequiredAt || now,
            recoveryReason:
              payout.recoveryReason || reason || "refund_after_payout",
            updatedAt: now,
            relatedReturnIds: relatedReturnIdsField,
            outstandingDebt: migration
              ? priorOutstandingDebt + reversal.sellerPayoutReversalAmount
              : admin.firestore.FieldValue.increment(
                  reversal.sellerPayoutReversalAmount
                ),
          },
          financial: {
            ...effectiveRecord.financial,
            refundReconciliation: reconciliation,
          },
          settlement: {
            ...(effectiveRecord.settlement || {}),
            refundReconciliation: settlementReconciliation,
          },
          updatedAt: now,
        },
        { merge: true }
      );

      createFinancialEvent(
        transaction,
        eventRef,
        financialEventData({
          eventType: "payout_refund_applied",
          sourceCollection: adapter.collection,
          sourceDocument: payableId,
          sector,
          businessId: payable.businessId,
          actor,
          previousState: payoutStatus,
          newState: "recovery_required",
          amount: reversal.customerRefundAmount,
          currency: payout.currency,
          reason: reason || "refund_after_payout",
          metadata: {
            ...eventMetadata,
            debtId: debtRef.id,
          },
        })
      );
      projectPayoutIndexInTransaction({
        transaction,
        indexRef,
        sourceCollection: adapter.collection,
        sourceDocumentId: payableId,
        existingProjection: reservedIndex,
        record: {
          ...effectiveRecord,
          financial: {
            ...effectiveRecord.financial,
            refundReconciliation: reconciliation,
          },
          settlement: {
            ...(effectiveRecord.settlement || {}),
            refundReconciliation: settlementReconciliation,
          },
          payout: {
            ...payout,
            status: "recovery_required",
          },
        },
      });

      return {
        applied: true,
        case:
          payoutStatus === "paid"
            ? "recovery_required"
            : "recovery_required_debt_added",
        debtId: debtRef.id,
      };
    }

    // pending / ready / hold / unknown -> hold. "hold" is the existing
    // canonical non-payable state and is excluded from Pending/Ready payout
    // actions. The amount is reduced by the seller-side reversal instead of
    // leaving the original liability active.
    createRefundLedgerEntries({
      transaction,
      db,
      adapter,
      payableId,
      businessId: payable.businessId,
      rootOrderId: rootOrderId || record.rootOrderId || null,
      refundEventId,
      reversal: { ...reversal, currency: payout.currency },
      actor,
      reason,
    });
    const adjustedPayout = {
      ...payout,
      amount: reversal.remainingBusinessReceivable,
      status: "hold",
      previousStatus: payout.previousStatus || payout.status || "pending",
      holdAt: payout.holdAt || now,
      holdReason: payout.holdReason || reason || "refund_pending_or_completed",
      updatedAt: now,
      relatedReturnIds: relatedReturnIdsField,
    };
    transaction.set(
      recordRef,
      {
        ...(migration ? migration.deletes : {}),
        payout: adjustedPayout,
        financial: {
          ...effectiveRecord.financial,
          refundReconciliation: reconciliation,
        },
        settlement: {
          ...(effectiveRecord.settlement || {}),
          refundReconciliation: settlementReconciliation,
        },
        updatedAt: now,
      },
      { merge: true }
    );

    createFinancialEvent(
      transaction,
      eventRef,
      financialEventData({
        eventType: "payout_refund_applied",
        sourceCollection: adapter.collection,
        sourceDocument: payableId,
        sector,
        businessId: payable.businessId,
        actor,
        previousState: payout.status || "pending",
        newState: "hold",
        amount: reversal.customerRefundAmount,
        currency: payout.currency,
        reason: reason || "refund_pending_or_completed",
        metadata: eventMetadata,
      })
    );
    projectPayoutIndexInTransaction({
      transaction,
      indexRef,
      sourceCollection: adapter.collection,
      sourceDocumentId: payableId,
      existingProjection: reservedIndex,
      record: {
        ...effectiveRecord,
        financial: {
          ...effectiveRecord.financial,
          refundReconciliation: reconciliation,
        },
        settlement: {
          ...(effectiveRecord.settlement || {}),
          refundReconciliation: settlementReconciliation,
        },
        payout: adjustedPayout,
      },
    });

    return {
      applied: true,
      case:
        payoutStatus === "ready"
          ? "reverted_to_hold"
          : payoutStatus === "hold"
            ? "hold_reconciled"
            : "held",
      reversal,
    };
  });
}

module.exports = {
  migrateMalformedPayoutFields,
  assertPayoutNotBlocked,
  assertBankAccountValid,
  markPayoutReady,
  markPayoutPaid,
  applyRefundToPayout,
  calculateRefundReversal,
};
