"use strict";

const admin = require("firebase-admin");
const crypto = require("node:crypto");
const {
  aggregatePayoutRecords,
  payoutValidationReasons,
  cents,
} = require("./payoutAggregation");
const { getFinanceExporter } = require("../finance/exporters");
const {
  getExecutionProvider,
} = require("../finance/executionProviders");
const {
  financialEventData,
  newFinancialEventRef,
  createFinancialEvent,
} = require("./financialEvents");
const {
  FINANCE_LEDGER_COLLECTION,
  ledgerEntryId,
  ledgerEntry,
} = require("../finance/financeLedger");

const ACTIVE_BATCH_STATUSES = new Set([
  "draft",
  "finance_review",
  "approved",
  "exported",
  "processing",
  "partially_paid",
]);

function timestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) ? parsed : Number(value) || 0;
}

function indexRecord(snapshot) {
  const data = snapshot.data() || {};
  return {
    id: snapshot.id,
    indexId: snapshot.id,
    ...data,
    sourceCreatedMillis: timestampMillis(
      data.sourceCreatedAt || data.sourceUpdatedAt
    ),
  };
}

function assertValidAggregate(group) {
  if (!group.isValid) {
    const error = new Error(
      `Payout aggregate is invalid: ${group.validationReasons.join(",")}`
    );
    error.code = "failed-precondition";
    error.details = {
      businessId: group.businessId,
      reasons: group.validationReasons,
    };
    throw error;
  }
}

function batchItemId(group) {
  return crypto
    .createHash("sha256")
    .update(group.key)
    .digest("hex")
    .slice(0, 32);
}

function frozenBatchChecksum({ batch, items }) {
  const canonical = {
    batchNumber: batch.batchNumber,
    batchVersion: Number(batch.version || 1),
    projectionVersion: Number(batch.projectionVersion || 3),
    snapshotTimestamp: timestampMillis(
      batch.snapshotTimestamp || batch.frozenAt
    ),
    currency: batch.currency,
    accountingPeriodId: batch.accountingPeriodId,
    sellerCount: batch.sellerCount,
    payoutRecordCount: batch.payoutRecordCount,
    grossTotal: cents(batch.grossTotal),
    commissionTotal: cents(batch.commissionTotal),
    netTotal: cents(batch.netTotal),
    items: [...items]
      .map((item) => ({
        businessId: item.businessId,
        iban: item.iban,
        accountHolderName: item.accountHolderName,
        bankName: item.bankName,
        grossTotal: cents(item.grossTotal),
        commissionTotal: cents(item.commissionTotal),
        netTotal: cents(item.netTotal),
        payoutIndexIds: [...(item.payoutIndexIds || [])].sort(),
      }))
      .sort((a, b) => a.businessId.localeCompare(b.businessId)),
  };
  return crypto
    .createHash("sha256")
    .update(JSON.stringify(canonical))
    .digest("hex");
}

function defaultWeeklyAccountingPeriod(nowMillis, currency) {
  const offset = 3 * 60 * 60 * 1000;
  const local = new Date(nowMillis + offset);
  const isoWeekday = local.getUTCDay() || 7;
  const localMondayUtc = Date.UTC(
    local.getUTCFullYear(),
    local.getUTCMonth(),
    local.getUTCDate() - (isoWeekday - 1)
  );
  const startMillis = localMondayUtc - offset;
  const endMillis = startMillis + 7 * 86400000;
  const dateKey = new Date(localMondayUtc).toISOString().slice(0, 10);
  return {
    id: `weekly_${dateKey}_${currency}`,
    type: "weekly",
    currency,
    periodStart: admin.firestore.Timestamp.fromMillis(startMillis),
    periodEnd: admin.firestore.Timestamp.fromMillis(endMillis),
  };
}

function createBatchLedgerEntry(transaction, db, data) {
  const id = ledgerEntryId(data);
  transaction.create(
    db.collection(FINANCE_LEDGER_COLLECTION).doc(id),
    ledgerEntry(data)
  );
}

async function createPayoutBatch({
  db,
  adminUid,
  payoutIndexIds,
  accountingPeriodId = null,
  periodStart = null,
  periodEnd = null,
  notes = null,
}) {
  const ids = Array.from(
    new Set((Array.isArray(payoutIndexIds) ? payoutIndexIds : [])
      .map((id) => String(id || "").trim())
      .filter(Boolean))
  );
  if (ids.length === 0 || ids.length > 450) {
    const error = new Error("Select between 1 and 450 payout records.");
    error.code = "invalid-argument";
    throw error;
  }

  const batchRef = db.collection("payoutBatches").doc();
  const counterRef = db.collection("counters").doc("payoutBatches");
  const now = admin.firestore.FieldValue.serverTimestamp();

  return db.runTransaction(async (transaction) => {
    const indexRefs = ids.map((id) => db.collection("payoutIndex").doc(id));
    const snapshots = await transaction.getAll(...indexRefs);
    if (snapshots.some((snapshot) => !snapshot.exists)) {
      const error = new Error("One or more payout records no longer exist.");
      error.code = "failed-precondition";
      throw error;
    }
    const records = snapshots.map(indexRecord);
    records.forEach((record) => {
      const reasons = payoutValidationReasons(record);
      if (reasons.length > 0) {
        const error = new Error(
          `Payout ${record.indexId} is not eligible: ${reasons.join(",")}`
        );
        error.code = "failed-precondition";
        error.details = { payoutIndexId: record.indexId, reasons };
        throw error;
      }
    });

    const groups = aggregatePayoutRecords(records);
    groups.forEach(assertValidAggregate);
    const currencies = new Set(groups.map((group) => group.currency));
    if (currencies.size !== 1) {
      const error = new Error("A payout batch must contain one currency.");
      error.code = "failed-precondition";
      throw error;
    }

    const counterSnap = await transaction.get(counterRef);
    const defaultPeriod = defaultWeeklyAccountingPeriod(
      Date.now(),
      groups[0].currency
    );
    const periodRef = db
      .collection("accountingPeriods")
      .doc(String(accountingPeriodId || defaultPeriod.id));
    const periodSnap = await transaction.get(periodRef);
    if (accountingPeriodId && !periodSnap.exists) {
      const error = new Error("Accounting period not found.");
      error.code = "not-found";
      throw error;
    }
    const period = periodSnap.exists ? periodSnap.data() || {} : defaultPeriod;
    if (
      period.status === "closed" ||
      period.status === "locked" ||
      String(period.currency || groups[0].currency).toUpperCase() !==
        groups[0].currency
    ) {
      const error = new Error(
        "The selected accounting period is closed or has a different currency."
      );
      error.code = "failed-precondition";
      throw error;
    }
    const sequence = Number(counterSnap.data()?.nextNumber || 1);
    const year = new Date().getUTCFullYear();
    const batchNumber = `PB-${year}-${String(sequence).padStart(6, "0")}`;
    const grossCents = groups.reduce((sum, group) => sum + group.grossCents, 0);
    const commissionCents = groups.reduce(
      (sum, group) => sum + group.commissionCents,
      0
    );
    const netCents = groups.reduce((sum, group) => sum + group.netCents, 0);

    transaction.set(counterRef, { nextNumber: sequence + 1 }, { merge: true });
    if (!periodSnap.exists) {
      transaction.create(periodRef, {
        ...defaultPeriod,
        id: periodRef.id,
        status: "open",
        createdAt: now,
        createdBy: "system",
        updatedAt: now,
      });
    }
    transaction.create(batchRef, {
      batchNumber,
      createdAt: now,
      createdBy: adminUid,
      accountingPeriodId: periodRef.id,
      accountingPeriodType: period.type || "weekly",
      periodStart: periodStart || period.periodStart,
      periodEnd: periodEnd || period.periodEnd,
      currency: groups[0].currency,
      status: "draft",
      sellerCount: groups.length,
      unpaidItemCount: groups.length,
      payoutRecordCount: records.length,
      grossTotal: grossCents / 100,
      commissionTotal: commissionCents / 100,
      netTotal: netCents / 100,
      exportVersion: 1,
      version: 1,
      projectionVersion: 3,
      parentBatchId: null,
      frozenAt: null,
      approvedBy: null,
      approvedAt: null,
      approvalNotes: null,
      exportFileName: null,
      notes: String(notes || "").trim() || null,
      updatedAt: now,
    });

    groups.forEach((group) => {
      const itemId = batchItemId(group);
      transaction.create(batchRef.collection("items").doc(itemId), {
        aggregateKey: group.key,
        businessId: group.businessId,
        sector: group.sector,
        businessName: group.businessName,
        legalBusinessName: group.legalBusinessName,
        accountHolderName: group.accountHolderName,
        iban: group.iban,
        bankName: group.bankName,
        taxNumber: group.taxNumber,
        contactEmail: group.contactEmail,
        contactPhone: group.contactPhone,
        currency: group.currency,
        payoutCount: group.payoutCount,
        grossTotal: group.grossTotal,
        commissionTotal: group.commissionTotal,
        netTotal: group.netTotal,
        payoutIndexIds: group.payoutIndexIds,
        sourceDocumentIds: group.sourceDocumentIds,
        periodStart: group.earliestSourceMillis
          ? admin.firestore.Timestamp.fromMillis(group.earliestSourceMillis)
          : null,
        periodEnd: group.latestSourceMillis
          ? admin.firestore.Timestamp.fromMillis(group.latestSourceMillis)
          : null,
        status: "draft",
        validationReasons: [],
        paymentReference: null,
        paidAt: null,
        failureReason: null,
        createdAt: now,
        updatedAt: now,
      });
    });

    const itemIdByPayoutIndexId = new Map();
    groups.forEach((group) => {
      const itemId = batchItemId(group);
      group.payoutIndexIds.forEach((id) =>
        itemIdByPayoutIndexId.set(id, itemId)
      );
    });
    snapshots.forEach((snapshot) => {
      transaction.update(snapshot.ref, {
        batchId: batchRef.id,
        batchItemId: itemIdByPayoutIndexId.get(snapshot.id),
        batchNumber,
        accountingPeriodId: periodRef.id,
        batchStatus: "draft",
        eligibilityStatus: "batched",
        reservedAt: now,
        reservedBy: adminUid,
        updatedAt: now,
      });
    });
    createBatchLedgerEntry(transaction, db, {
      eventType: "payout_batch_reserved",
      sourceCollection: "payoutBatches",
      sourceDocumentId: batchRef.id,
      businessId: null,
      batchId: batchRef.id,
      amount: netCents / 100,
      currency: groups[0].currency,
      direction: "memo",
      actor: { type: "user", id: adminUid },
      reason: "eligible_liabilities_reserved",
      idempotencyKey: "batch_reserved_v1",
      metadata: {
        payoutIndexIds: ids,
        sellerCount: groups.length,
        accountingPeriodId: periodRef.id,
      },
    });

    return {
      batchId: batchRef.id,
      batchNumber,
      sellerCount: groups.length,
      payoutRecordCount: records.length,
      netTotal: netCents / 100,
    };
  });
}

async function submitPayoutBatchForReview({ db, adminUid, batchId }) {
  const batchRef = db.collection("payoutBatches").doc(batchId);
  const itemsSnap = await batchRef.collection("items").get();
  return db.runTransaction(async (transaction) => {
    const batchSnap = await transaction.get(batchRef);
    if (!batchSnap.exists) {
      const error = new Error("Payout batch not found.");
      error.code = "not-found";
      throw error;
    }
    const batch = batchSnap.data() || {};
    if (batch.status !== "draft") {
      const error = new Error("Only draft batches can enter finance review.");
      error.code = "failed-precondition";
      throw error;
    }
    const itemSnaps = await transaction.getAll(
      ...itemsSnap.docs.map((doc) => doc.ref)
    );
    const items = itemSnaps.map((doc) => ({ id: doc.id, ...doc.data() }));
    if (items.length === 0) {
      const error = new Error("Cannot freeze an empty payout batch.");
      error.code = "failed-precondition";
      throw error;
    }
    const snapshotTimestamp = admin.firestore.Timestamp.now();
    const reviewVersion = Number(batch.reviewVersion || 0) + 1;
    const checksum = frozenBatchChecksum({
      batch: { ...batch, snapshotTimestamp },
      items,
    });
    const now = admin.firestore.FieldValue.serverTimestamp();
    transaction.update(batchRef, {
      status: "finance_review",
      frozenAt: now,
      frozenBy: adminUid,
      frozenChecksum: checksum,
      snapshotHash: checksum,
      snapshotTimestamp,
      reviewVersion,
      updatedAt: now,
    });
    itemSnaps.forEach((item) =>
      transaction.update(item.ref, {
        status: "finance_review",
        frozenAt: now,
        updatedAt: now,
      })
    );
    createBatchLedgerEntry(transaction, db, {
      eventType: "payout_batch_frozen",
      sourceCollection: "payoutBatches",
      sourceDocumentId: batchId,
      batchId,
      amount: Number(batch.netTotal || 0),
      currency: batch.currency,
      direction: "memo",
      actor: { type: "user", id: adminUid },
      reason: "submitted_for_finance_review",
      idempotencyKey: `batch_frozen_v${reviewVersion}`,
      metadata: {
        accountingPeriodId: batch.accountingPeriodId || null,
        snapshotHash: checksum,
      },
    });
    return { batchId, status: "finance_review", checksum };
  });
}

async function approvePayoutBatch({
  db,
  adminUid,
  batchId,
  approvalNotes = null,
}) {
  const batchRef = db.collection("payoutBatches").doc(batchId);
  return db.runTransaction(async (transaction) => {
    const batchSnap = await transaction.get(batchRef);
    if (!batchSnap.exists) {
      const error = new Error("Payout batch not found.");
      error.code = "not-found";
      throw error;
    }
    const batch = batchSnap.data() || {};
    if (batch.status !== "finance_review" || !batch.frozenChecksum) {
      const error = new Error("Batch must be frozen in Finance Review.");
      error.code = "failed-precondition";
      throw error;
    }
    const now = admin.firestore.FieldValue.serverTimestamp();
    transaction.update(batchRef, {
      status: "approved",
      approvedBy: adminUid,
      approvedAt: now,
      approvalNotes: String(approvalNotes || "").trim() || null,
      updatedAt: now,
    });
    createBatchLedgerEntry(transaction, db, {
      eventType: "payout_batch_approved",
      sourceCollection: "payoutBatches",
      sourceDocumentId: batchId,
      batchId,
      amount: Number(batch.netTotal || 0),
      currency: batch.currency,
      direction: "memo",
      actor: { type: "user", id: adminUid },
      reason: "finance_approval",
      idempotencyKey: `batch_approved_v${Number(batch.reviewVersion || 1)}`,
      metadata: { approvalNotes: String(approvalNotes || "").trim() || null },
    });
    return { batchId, status: "approved" };
  });
}

async function rejectPayoutBatch({
  db,
  adminUid,
  batchId,
  approvalNotes,
}) {
  const notes = String(approvalNotes || "").trim();
  if (!notes) {
    const error = new Error("Rejection notes are required.");
    error.code = "invalid-argument";
    throw error;
  }
  const batchRef = db.collection("payoutBatches").doc(batchId);
  return db.runTransaction(async (transaction) => {
    const batchSnap = await transaction.get(batchRef);
    if (!batchSnap.exists) {
      const error = new Error("Payout batch not found.");
      error.code = "not-found";
      throw error;
    }
    const batch = batchSnap.data() || {};
    if (batch.status !== "finance_review") {
      const error = new Error("Only Finance Review batches can be rejected.");
      error.code = "failed-precondition";
      throw error;
    }
    const now = admin.firestore.FieldValue.serverTimestamp();
    transaction.update(batchRef, {
      status: "draft",
      rejectedBy: adminUid,
      rejectedAt: now,
      approvalNotes: notes,
      requiresNewVersionForContentChanges: true,
      updatedAt: now,
    });
    createBatchLedgerEntry(transaction, db, {
      eventType: "payout_batch_rejected",
      sourceCollection: "payoutBatches",
      sourceDocumentId: batchId,
      batchId,
      amount: Number(batch.netTotal || 0),
      currency: batch.currency,
      direction: "memo",
      actor: { type: "user", id: adminUid },
      reason: "finance_rejection",
      idempotencyKey: `batch_rejected_v${Number(batch.reviewVersion || 1)}`,
      metadata: { approvalNotes: notes },
    });
    return { batchId, status: "draft", frozen: true };
  });
}

async function createPayoutBatchVersion({
  db,
  adminUid,
  batchId,
  payoutIndexIds = null,
  notes = null,
}) {
  const oldRef = db.collection("payoutBatches").doc(batchId);
  const oldItemsSnap = await oldRef.collection("items").get();
  const oldSnap = await oldRef.get();
  if (!oldSnap.exists) {
    const error = new Error("Payout batch not found.");
    error.code = "not-found";
    throw error;
  }
  const oldBatch = oldSnap.data() || {};
  if (
    !["draft", "invalidated"].includes(oldBatch.status) ||
    !oldBatch.frozenAt
  ) {
    const error = new Error("Only frozen Draft or Invalidated batches can be versioned.");
    error.code = "failed-precondition";
    throw error;
  }
  const originalIds = Array.from(
    new Set(
      oldItemsSnap.docs.flatMap((doc) => doc.data()?.payoutIndexIds || [])
    )
  );
  const selectedIds = payoutIndexIds
    ? Array.from(
      new Set(
        payoutIndexIds
          .map((id) => String(id || "").trim())
          .filter((id) => originalIds.includes(id))
      )
    )
    : originalIds;
  if (selectedIds.length === 0) {
    const error = new Error("A new batch version requires payable records.");
    error.code = "failed-precondition";
    throw error;
  }
  const newRef = db.collection("payoutBatches").doc();
  const now = admin.firestore.FieldValue.serverTimestamp();
  return db.runTransaction(async (transaction) => {
    const indexRefs = originalIds.map((id) =>
      db.collection("payoutIndex").doc(id)
    );
    const indexSnaps = await transaction.getAll(...indexRefs);
    const selectedSet = new Set(selectedIds);
    const selectedRecords = indexSnaps
      .filter((snap) => selectedSet.has(snap.id))
      .map(indexRecord);
    selectedRecords.forEach((record) => {
      const reasons = payoutValidationReasons(record, {
        allowReservedBatchId: batchId,
      });
      if (reasons.length > 0 || record.batchId !== batchId) {
        const error = new Error(`Record ${record.indexId} is no longer payable.`);
        error.code = "failed-precondition";
        throw error;
      }
    });
    const groups = aggregatePayoutRecords(selectedRecords, {
      allowReservedBatchId: batchId,
    });
    groups.forEach(assertValidAggregate);
    if (new Set(groups.map((group) => group.currency)).size !== 1) {
      const error = new Error("A payout batch version must contain one currency.");
      error.code = "failed-precondition";
      throw error;
    }
    const grossCents = groups.reduce((sum, group) => sum + group.grossCents, 0);
    const commissionCents = groups.reduce(
      (sum, group) => sum + group.commissionCents,
      0
    );
    const netCents = groups.reduce((sum, group) => sum + group.netCents, 0);
    const version = Number(oldBatch.version || 1) + 1;
    const batchNumber = `${oldBatch.batchNumber}-V${version}`;
    transaction.create(newRef, {
      ...oldBatch,
      batchNumber,
      version,
      parentBatchId: batchId,
      status: "draft",
      createdAt: now,
      createdBy: adminUid,
      updatedAt: now,
      sellerCount: groups.length,
      unpaidItemCount: groups.length,
      payoutRecordCount: selectedRecords.length,
      grossTotal: grossCents / 100,
      commissionTotal: commissionCents / 100,
      netTotal: netCents / 100,
      notes: String(notes || "").trim() || oldBatch.notes || null,
      frozenAt: null,
      frozenBy: null,
      frozenChecksum: null,
      snapshotHash: null,
      snapshotTimestamp: null,
      reviewVersion: 0,
      approvedAt: null,
      approvedBy: null,
      approvalNotes: null,
      exportedAt: null,
      exportFileName: null,
      invalidatedAt: null,
      invalidationReason: null,
      paidAt: null,
      supersedesBatchId: batchId,
    });
    groups.forEach((group) => {
      const itemId = batchItemId(group);
      transaction.create(newRef.collection("items").doc(itemId), {
        aggregateKey: group.key,
        businessId: group.businessId,
        sector: group.sector,
        businessName: group.businessName,
        legalBusinessName: group.legalBusinessName,
        accountHolderName: group.accountHolderName,
        iban: group.iban,
        bankName: group.bankName,
        taxNumber: group.taxNumber,
        contactEmail: group.contactEmail,
        contactPhone: group.contactPhone,
        currency: group.currency,
        payoutCount: group.payoutCount,
        grossTotal: group.grossTotal,
        commissionTotal: group.commissionTotal,
        netTotal: group.netTotal,
        payoutIndexIds: group.payoutIndexIds,
        sourceDocumentIds: group.sourceDocumentIds,
        status: "draft",
        createdAt: now,
        updatedAt: now,
      });
      group.payoutIndexIds.forEach((id) => {
        const snapshot = indexSnaps.find((snap) => snap.id === id);
        transaction.update(snapshot.ref, {
          batchId: newRef.id,
          batchItemId: itemId,
          batchNumber,
          batchStatus: "draft",
          updatedAt: now,
        });
      });
    });
    indexSnaps
      .filter((snap) => !selectedSet.has(snap.id))
      .forEach((snapshot) => {
        transaction.update(snapshot.ref, {
          batchId: admin.firestore.FieldValue.delete(),
          batchItemId: admin.firestore.FieldValue.delete(),
          batchNumber: admin.firestore.FieldValue.delete(),
          batchStatus: admin.firestore.FieldValue.delete(),
          eligibilityStatus: "eligible",
          updatedAt: now,
        });
      });
    transaction.update(oldRef, {
      status: "superseded",
      supersededByBatchId: newRef.id,
      supersededAt: now,
      updatedAt: now,
    });
    return {
      batchId: newRef.id,
      batchNumber,
      version,
      status: "draft",
    };
  });
}

async function exportPayoutBatch({
  db,
  bucket,
  adminUid,
  batchId,
  format = "xlsx",
}) {
  const batchRef = db.collection("payoutBatches").doc(batchId);
  const [batchSnap, itemsSnap] = await Promise.all([
    batchRef.get(),
    batchRef.collection("items").get(),
  ]);
  if (!batchSnap.exists) {
    const error = new Error("Payout batch not found.");
    error.code = "not-found";
    throw error;
  }
  const batch = { id: batchSnap.id, ...batchSnap.data() };
  if (!new Set(["approved", "exported"]).has(batch.status)) {
    const error = new Error("Only approved frozen batches can be exported.");
    error.code = "failed-precondition";
    throw error;
  }
  const items = itemsSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  if (items.length === 0) {
    const error = new Error("Payout batch has no seller items.");
    error.code = "failed-precondition";
    throw error;
  }

  const allIndexIds = items.flatMap((item) => item.payoutIndexIds || []);
  const indexSnaps = await db.getAll(
    ...allIndexIds.map((id) => db.collection("payoutIndex").doc(id))
  );
  const records = indexSnaps.map(indexRecord);
  const invalid = records
    .map((record) => ({
      record,
      reasons: payoutValidationReasons(record, {
        allowReservedBatchId: batchId,
        useFrozenBankSnapshot: true,
      }),
    }))
    .filter((entry) => entry.reasons.length > 0);
  if (invalid.length > 0) {
    const error = new Error("Batch contains ineligible payout records.");
    error.code = "failed-precondition";
    error.details = invalid.map((entry) => ({
      payoutIndexId: entry.record.indexId,
      businessId: entry.record.businessId,
      reasons: entry.reasons,
    }));
    throw error;
  }

  const expectedNetCents = records.reduce(
    (sum, record) => sum + cents(record.amount),
    0
  );
  if (expectedNetCents !== cents(batch.netTotal)) {
    const error = new Error("Batch totals no longer match payout records.");
    error.code = "failed-precondition";
    throw error;
  }

  const recordById = new Map(records.map((record) => [record.indexId, record]));
  const workbookItems = items.map((item) => {
    const frozenIban = String(item.iban || "").replace(/\s+/g, "").toUpperCase();
    if (
      !item.accountHolderName ||
      !item.bankName ||
      !/^TR\d{24}$/.test(frozenIban)
    ) {
      const error = new Error(
        `Frozen bank snapshot is invalid for ${item.businessId}.`
      );
      error.code = "failed-precondition";
      throw error;
    }
    const itemRecords = (item.payoutIndexIds || []).map((id) =>
      recordById.get(id)
    );
    const netCents = itemRecords.reduce(
      (sum, record) => sum + cents(record?.amount || 0),
      0
    );
    if (
      itemRecords.some(
        (record) =>
          !record ||
          record.businessId !== item.businessId ||
          record.currency !== item.currency
      ) ||
      cents(item.netTotal) !== netCents
    ) {
      const error = new Error(
        `Seller totals changed for ${item.businessId}.`
      );
      error.code = "failed-precondition";
      throw error;
    }
    return item;
  });
  const exporter = getFinanceExporter(format);
  const buffer = await exporter.build({
    batch,
    items: workbookItems,
    details: records,
  });
  const exportDate = new Date().toISOString().slice(0, 10);
  const fileName =
    `petsupo_payout_batch_${batch.batchNumber}_${exportDate}.${exporter.extension}`;
  const storagePath = `payout-exports/${batchId}/${fileName}`;
  const sha256 = crypto.createHash("sha256").update(buffer).digest("hex");
  await bucket.file(storagePath).save(buffer, {
    contentType: exporter.contentType,
    resumable: false,
    metadata: {
      metadata: { batchId, batchNumber: batch.batchNumber, sha256 },
    },
  });

  const exportedAt = admin.firestore.FieldValue.serverTimestamp();
  const eventRef = newFinancialEventRef(db);
  await db.runTransaction(async (transaction) => {
    const freshBatch = await transaction.get(batchRef);
    if (!freshBatch.exists) throw new Error("Payout batch not found.");
    const current = freshBatch.data() || {};
    if (
      !new Set(["approved", "exported"]).has(current.status) ||
      current.frozenChecksum !== batch.frozenChecksum
    ) {
      const error = new Error("Batch changed during export.");
      error.code = "failed-precondition";
      throw error;
    }
    const freshIndexSnaps = await transaction.getAll(
      ...allIndexIds.map((id) => db.collection("payoutIndex").doc(id))
    );
    const freshRecords = freshIndexSnaps.map(indexRecord);
    const freshInvalid = freshRecords.filter(
      (record) =>
        payoutValidationReasons(record, {
          allowReservedBatchId: batchId,
          useFrozenBankSnapshot: true,
        }).length > 0 ||
        record.batchId !== batchId
    );
    const freshNetCents = freshRecords.reduce(
      (sum, record) => sum + cents(record.amount),
      0
    );
    if (
      freshIndexSnaps.some((snapshot) => !snapshot.exists) ||
      freshInvalid.length > 0 ||
      freshNetCents !== cents(current.netTotal)
    ) {
      const error = new Error(
        "Batch payout records changed during export validation."
      );
      error.code = "failed-precondition";
      throw error;
    }
    const exportVersion = Number(current.exportVersion || 0) + 1;
    transaction.update(batchRef, {
      status: "exported",
      exportVersion,
      exportFileName: fileName,
      exportStoragePath: storagePath,
      exportSha256: sha256,
      exportByteLength: buffer.length,
      exportedAt,
      exportedBy: adminUid,
      exportFormat: exporter.format,
      updatedAt: exportedAt,
    });
    itemsSnap.docs.forEach((itemDoc) => {
      transaction.update(itemDoc.ref, {
        status: "exported",
        updatedAt: exportedAt,
      });
    });
    freshIndexSnaps.forEach((indexSnap) => {
      transaction.update(indexSnap.ref, {
        batchStatus: "exported",
        updatedAt: exportedAt,
      });
    });
    createFinancialEvent(
      transaction,
      eventRef,
      financialEventData({
        eventType: "payout_batch_exported",
        sourceCollection: "payoutBatches",
        sourceDocument: batchId,
        sector: "aggregate",
        businessId: null,
        actor: { type: "user", id: adminUid },
        previousState: current.status,
        newState: "exported",
        amount: Number(current.netTotal),
        currency: current.currency,
        reason: "payment_instruction_exported",
        metadata: {
          batchNumber: current.batchNumber,
          sellerCount: current.sellerCount,
          payoutRecordCount: current.payoutRecordCount,
          exportFileName: fileName,
          sha256,
        },
      })
    );
    createBatchLedgerEntry(transaction, db, {
      eventType: "payout_batch_exported",
      sourceCollection: "payoutBatches",
      sourceDocumentId: batchId,
      businessId: null,
      batchId,
      amount: Number(current.netTotal),
      currency: current.currency,
      direction: "memo",
      actor: { type: "user", id: adminUid },
      reason: "payment_instruction_exported",
          idempotencyKey: `export_v${exportVersion}`,
      metadata: { fileName, sha256, format: exporter.format },
    });
  });

  const [downloadUrl] = await bucket.file(storagePath).getSignedUrl({
    version: "v4",
    action: "read",
    expires: Date.now() + 15 * 60 * 1000,
    responseDisposition: `attachment; filename="${fileName}"`,
    responseType: exporter.contentType,
  });

  return {
    batchId,
    batchNumber: batch.batchNumber,
    fileName,
    contentType:
      exporter.contentType,
    byteLength: buffer.length,
    sha256,
    storagePath,
    downloadUrl,
    generatedAt: new Date().toISOString(),
    generatedBy: adminUid,
    status: "exported",
  };
}

async function downloadPayoutBatchExport({ db, bucket, batchId, adminUid = null }) {
  const batchSnap = await db.collection("payoutBatches").doc(batchId).get();
  if (!batchSnap.exists) {
    const error = new Error("Payout batch not found.");
    error.code = "not-found";
    throw error;
  }
  const batch = batchSnap.data() || {};
  if (!batch.exportStoragePath || !batch.exportFileName) {
    const error = new Error("This batch has no generated export.");
    error.code = "failed-precondition";
    throw error;
  }
  const file = bucket.file(batch.exportStoragePath);
  const [metadata] = await file.getMetadata();
  const [downloadUrl] = await file.getSignedUrl({
    version: "v4",
    action: "read",
    expires: Date.now() + 15 * 60 * 1000,
    responseDisposition: `attachment; filename="${batch.exportFileName}"`,
    responseType:
      metadata.contentType ||
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
  return {
    batchId,
    batchNumber: batch.batchNumber,
    fileName: batch.exportFileName,
    contentType:
      metadata.contentType ||
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    byteLength: Number(metadata.size || batch.exportByteLength || 0),
    storagePath: batch.exportStoragePath,
    downloadUrl,
    generatedAt: batch.exportedAt || null,
    generatedBy: batch.exportedBy || adminUid || null,
    status: batch.status,
  };
}

async function markPayoutBatchProcessing({
  db,
  adminUid,
  batchId,
  executionProvider = "manual_eft",
}) {
  const provider = getExecutionProvider(executionProvider);
  const batchRef = db.collection("payoutBatches").doc(batchId);
  return db.runTransaction(async (transaction) => {
    const batchSnap = await transaction.get(batchRef);
    if (!batchSnap.exists) {
      const error = new Error("Payout batch not found.");
      error.code = "not-found";
      throw error;
    }
    const batch = batchSnap.data() || {};
    if (batch.status === "processing") {
      return { batchId, status: "processing", idempotent: true };
    }
    if (batch.status !== "exported") {
      const error = new Error("Only exported batches can enter processing.");
      error.code = "failed-precondition";
      throw error;
    }
    const now = admin.firestore.FieldValue.serverTimestamp();
    transaction.update(batchRef, {
      status: "processing",
      processingAt: now,
      processingBy: adminUid,
      executionProvider: provider.id,
      updatedAt: now,
    });
    createBatchLedgerEntry(transaction, db, {
      eventType: "payout_batch_processing",
      sourceCollection: "payoutBatches",
      sourceDocumentId: batchId,
      batchId,
      amount: Number(batch.netTotal || 0),
      currency: batch.currency,
      direction: "memo",
      actor: { type: "user", id: adminUid },
      reason: "execution_started",
      idempotencyKey: "batch_processing_v1",
    });
    return { batchId, status: "processing", idempotent: false };
  });
}

async function cancelPayoutBatch({ db, adminUid, batchId, reason }) {
  const normalizedReason = String(reason || "").trim();
  if (!normalizedReason) {
    const error = new Error("Cancellation reason is required.");
    error.code = "invalid-argument";
    throw error;
  }
  const batchRef = db.collection("payoutBatches").doc(batchId);
  const itemsSnap = await batchRef.collection("items").get();
  const payoutIndexIds = Array.from(
    new Set(itemsSnap.docs.flatMap((doc) => doc.data()?.payoutIndexIds || []))
  );
  return db.runTransaction(async (transaction) => {
    const batchSnap = await transaction.get(batchRef);
    if (!batchSnap.exists) {
      const error = new Error("Payout batch not found.");
      error.code = "not-found";
      throw error;
    }
    const batch = batchSnap.data() || {};
    if (batch.status === "cancelled") {
      return { batchId, status: "cancelled", idempotent: true };
    }
    if (!["draft", "finance_review", "approved"].includes(batch.status)) {
      const error = new Error(
        "Exported, processing, paid, and superseded batches cannot be cancelled."
      );
      error.code = "failed-precondition";
      throw error;
    }
    const indexRefs = payoutIndexIds.map((id) =>
      db.collection("payoutIndex").doc(id)
    );
    const indexSnaps =
      indexRefs.length > 0 ? await transaction.getAll(...indexRefs) : [];
    const now = admin.firestore.FieldValue.serverTimestamp();
    indexSnaps.forEach((snapshot) => {
      const record = snapshot.data() || {};
      if (record.batchId !== batchId) return;
      transaction.update(snapshot.ref, {
        batchId: admin.firestore.FieldValue.delete(),
        batchItemId: admin.firestore.FieldValue.delete(),
        batchNumber: admin.firestore.FieldValue.delete(),
        batchStatus: admin.firestore.FieldValue.delete(),
        reservedAt: admin.firestore.FieldValue.delete(),
        reservedBy: admin.firestore.FieldValue.delete(),
        eligibilityStatus: "eligible",
        updatedAt: now,
      });
    });
    itemsSnap.docs.forEach((item) =>
      transaction.update(item.ref, {
        status: "cancelled",
        cancelledAt: now,
        updatedAt: now,
      })
    );
    transaction.update(batchRef, {
      status: "cancelled",
      cancelledAt: now,
      cancelledBy: adminUid,
      cancellationReason: normalizedReason,
      updatedAt: now,
    });
    createBatchLedgerEntry(transaction, db, {
      eventType: "payout_batch_cancelled",
      sourceCollection: "payoutBatches",
      sourceDocumentId: batchId,
      batchId,
      amount: Number(batch.netTotal || 0),
      currency: batch.currency,
      direction: "memo",
      actor: { type: "user", id: adminUid },
      reason: normalizedReason,
      idempotencyKey: "batch_cancelled_v1",
    });
    return { batchId, status: "cancelled", idempotent: false };
  });
}

async function updatePayoutBatchReferences({
  db,
  adminUid,
  batchId,
  accountingReference,
  erpReference,
  bankTransferReference,
  notes,
}) {
  const batchRef = db.collection("payoutBatches").doc(batchId);
  const snapshot = await batchRef.get();
  if (!snapshot.exists) {
    const error = new Error("Payout batch not found.");
    error.code = "not-found";
    throw error;
  }
  const batch = snapshot.data() || {};
  if (["cancelled", "superseded"].includes(batch.status)) {
    const error = new Error("References cannot be changed on this batch.");
    error.code = "failed-precondition";
    throw error;
  }
  await batchRef.update({
    accountingReference: String(accountingReference || "").trim() || null,
    erpReference: String(erpReference || "").trim() || null,
    bankTransferReference:
      String(bankTransferReference || "").trim() || null,
    notes: String(notes || "").trim() || null,
    referencesUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    referencesUpdatedBy: adminUid,
  });
  return { batchId, updated: true };
}

async function markPayoutBatchItemPaid({
  db,
  adminUid,
  batchId,
  itemId,
  paymentReference,
  paymentDate,
  note = null,
}) {
  const reference = String(paymentReference || "").trim();
  if (!reference) {
    const error = new Error("paymentReference is required.");
    error.code = "invalid-argument";
    throw error;
  }
  const batchRef = db.collection("payoutBatches").doc(batchId);
  const itemRef = batchRef.collection("items").doc(itemId);
  const eventRef = newFinancialEventRef(db);
  const now = admin.firestore.FieldValue.serverTimestamp();

  return db.runTransaction(async (transaction) => {
    const [batchSnap, itemSnap] = await Promise.all([
      transaction.get(batchRef),
      transaction.get(itemRef),
    ]);
    if (!batchSnap.exists || !itemSnap.exists) {
      const error = new Error("Payout batch item not found.");
      error.code = "not-found";
      throw error;
    }
    const batch = batchSnap.data() || {};
    const item = itemSnap.data() || {};
    if (item.status === "paid") {
      return { idempotent: true, status: "paid" };
    }
    if (
      !["exported", "processing", "partially_paid", "failed"].includes(
        batch.status
      )
    ) {
      const error = new Error("Batch must be exported before payment.");
      error.code = "failed-precondition";
      throw error;
    }
    const indexIds = item.payoutIndexIds || [];
    const indexRefs = indexIds.map((id) => db.collection("payoutIndex").doc(id));
    const indexSnaps = await transaction.getAll(...indexRefs);
    if (
      indexSnaps.some(
        (snapshot) =>
          !snapshot.exists ||
          snapshot.data()?.batchId !== batchId ||
          payoutValidationReasons(indexRecord(snapshot), {
            allowReservedBatchId: batchId,
            useFrozenBankSnapshot: true,
          }).length > 0
      )
    ) {
      const error = new Error("A reserved payout is no longer payable.");
      error.code = "failed-precondition";
      throw error;
    }
    const sourceRefs = indexSnaps.map((snapshot) => {
      const data = snapshot.data();
      return db.collection(data.sourceCollection).doc(data.sourceDocumentId);
    });
    const sourceSnaps = await transaction.getAll(...sourceRefs);
    if (sourceSnaps.some((snapshot) => !snapshot.exists)) {
      const error = new Error("A payout source record is missing.");
      error.code = "failed-precondition";
      throw error;
    }
    if (
      sourceSnaps.some((snapshot) => {
        const source = snapshot.data() || {};
        const status = String(source.status || "").toLowerCase();
        const payoutStatus = String(source.payout?.status || "").toLowerCase();
        return (
          status.includes("refund") ||
          status.includes("cancel") ||
          ["reversed", "voided", "hold", "recovery_required"].includes(
            payoutStatus
          )
        );
      })
    ) {
      const error = new Error("A payout source was refunded or reversed.");
      error.code = "failed-precondition";
      throw error;
    }

    sourceSnaps.forEach((sourceSnap, index) => {
      const source = sourceSnap.data() || {};
      transaction.set(
        sourceSnap.ref,
        {
          payout: {
            ...(source.payout || {}),
            status: "paid",
            paidAt: now,
            reference,
            note: String(note || "").trim() || null,
            updatedAt: now,
          },
          updatedAt: now,
        },
        { merge: true }
      );
      transaction.update(indexSnaps[index].ref, {
        payoutStatus: "paid",
        eligibilityStatus: "paid",
        batchStatus: "paid",
        paymentReference: reference,
        paidAt: now,
        updatedAt: now,
      });
    });
    transaction.update(itemRef, {
      status: "paid",
      paymentReference: reference,
      paymentDate: paymentDate
        ? admin.firestore.Timestamp.fromDate(new Date(paymentDate))
        : now,
      paidAt: now,
      paidBy: adminUid,
      note: String(note || "").trim() || null,
      updatedAt: now,
    });
    const unpaidItemCount = Math.max(
      0,
      Number(batch.unpaidItemCount || batch.sellerCount || 1) - 1
    );
    transaction.update(batchRef, {
      status: unpaidItemCount === 0 ? "paid" : "partially_paid",
      unpaidItemCount,
      failedItemCount:
        item.status === "failed"
          ? Math.max(0, Number(batch.failedItemCount || 1) - 1)
          : Number(batch.failedItemCount || 0),
      paidAt: unpaidItemCount === 0 ? now : null,
      updatedAt: now,
    });
    createFinancialEvent(
      transaction,
      eventRef,
      financialEventData({
        eventType: "payout_batch_item_paid",
        sourceCollection: "payoutBatches",
        sourceDocument: batchId,
        sector: "aggregate",
        businessId: item.businessId,
        actor: { type: "user", id: adminUid },
        previousState: item.status,
        newState: "paid",
        amount: Number(item.netTotal),
        currency: item.currency,
        reason: "bank_transfer_completed",
        metadata: {
          batchNumber: batch.batchNumber,
          batchItemId: itemId,
          paymentReference: reference,
          payoutIndexIds: indexIds,
        },
      })
    );
    createBatchLedgerEntry(transaction, db, {
      eventType: "payout_batch_item_paid",
      sourceCollection: "payoutBatches",
      sourceDocumentId: batchId,
      businessId: item.businessId,
      batchId,
      amount: Number(item.netTotal),
      currency: item.currency,
      direction: "debit",
      actor: { type: "user", id: adminUid },
      reason: "seller_liability_paid",
      reference,
      idempotencyKey: `item_paid:${itemId}`,
      metadata: { payoutIndexIds: indexIds },
    });
    return {
      idempotent: false,
      status: "paid",
      batchStatus: unpaidItemCount === 0 ? "paid" : "partially_paid",
    };
  });
}

async function markPayoutBatchItemFailed({
  db,
  adminUid,
  batchId,
  itemId,
  failureReason,
}) {
  const reason = String(failureReason || "").trim();
  if (!reason) {
    const error = new Error("failureReason is required.");
    error.code = "invalid-argument";
    throw error;
  }
  const batchRef = db.collection("payoutBatches").doc(batchId);
  const itemRef = batchRef.collection("items").doc(itemId);
  return db.runTransaction(async (transaction) => {
    const [batchSnap, itemSnap] = await Promise.all([
      transaction.get(batchRef),
      transaction.get(itemRef),
    ]);
    if (!batchSnap.exists || !itemSnap.exists) {
      const error = new Error("Payout batch item not found.");
      error.code = "not-found";
      throw error;
    }
    const batch = batchSnap.data() || {};
    const item = itemSnap.data() || {};
    if (item.status === "paid") {
      const error = new Error("Paid seller items cannot be marked failed.");
      error.code = "failed-precondition";
      throw error;
    }
    if (item.status === "failed" && item.failureReason === reason) {
      return { status: "failed", idempotent: true };
    }
    if (!["exported", "processing", "partially_paid", "failed"].includes(
      batch.status
    )) {
      const error = new Error("Batch is not in payment execution.");
      error.code = "failed-precondition";
      throw error;
    }
    const now = admin.firestore.FieldValue.serverTimestamp();
    const indexRefs = (item.payoutIndexIds || []).map((id) =>
      db.collection("payoutIndex").doc(id)
    );
    const indexSnaps =
      indexRefs.length > 0 ? await transaction.getAll(...indexRefs) : [];
    transaction.update(itemRef, {
      status: "failed",
      failureReason: reason,
      failedAt: now,
      failedBy: adminUid,
      updatedAt: now,
    });
    indexSnaps.forEach((snapshot) => {
      if (snapshot.exists && snapshot.data()?.batchId === batchId) {
        transaction.update(snapshot.ref, {
          batchStatus: "failed",
          updatedAt: now,
        });
      }
    });
    const paidItemCount =
      Number(batch.sellerCount || 0) - Number(batch.unpaidItemCount || 0);
    transaction.update(batchRef, {
      status: paidItemCount > 0 ? "partially_paid" : "failed",
      failedItemCount: admin.firestore.FieldValue.increment(
        item.status === "failed" ? 0 : 1
      ),
      lastFailureReason: reason,
      updatedAt: now,
    });
    createBatchLedgerEntry(transaction, db, {
      eventType: "payout_batch_item_failed",
      sourceCollection: "payoutBatches",
      sourceDocumentId: `${batchId}/${itemId}`,
      businessId: item.businessId,
      batchId,
      amount: Number(item.netTotal || 0),
      currency: item.currency || batch.currency,
      direction: "memo",
      actor: { type: "user", id: adminUid },
      reason,
      idempotencyKey: `item_failed:${itemId}:${reason}`,
    });
    return { status: "failed", idempotent: false };
  });
}

async function markPayoutBatchPaid({
  db,
  adminUid,
  batchId,
  paymentReference,
  paymentDate,
  note = null,
}) {
  const itemsSnap = await db
    .collection("payoutBatches")
    .doc(batchId)
    .collection("items")
    .get();
  const results = [];
  for (const itemDoc of itemsSnap.docs) {
    if (itemDoc.data()?.status === "paid") {
      results.push({ itemId: itemDoc.id, idempotent: true });
      continue;
    }
    const result = await markPayoutBatchItemPaid({
      db,
      adminUid,
      batchId,
      itemId: itemDoc.id,
      paymentReference,
      paymentDate,
      note,
    });
    results.push({ itemId: itemDoc.id, ...result });
  }
  return { batchId, sellerItemCount: results.length, results };
}

module.exports = {
  ACTIVE_BATCH_STATUSES,
  createPayoutBatch,
  submitPayoutBatchForReview,
  approvePayoutBatch,
  rejectPayoutBatch,
  createPayoutBatchVersion,
  exportPayoutBatch,
  downloadPayoutBatchExport,
  markPayoutBatchProcessing,
  cancelPayoutBatch,
  updatePayoutBatchReferences,
  markPayoutBatchItemPaid,
  markPayoutBatchItemFailed,
  markPayoutBatchPaid,
  assertValidAggregate,
  frozenBatchChecksum,
};
