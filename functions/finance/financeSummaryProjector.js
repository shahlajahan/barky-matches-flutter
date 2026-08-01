"use strict";

const admin = require("firebase-admin");
const { cents } = require("./financeLedger");
const { timestampMillis } = require("./financeEligibility");

function emptyBucket() {
  return { count: 0, amountCents: 0 };
}

function add(bucket, amount) {
  bucket.count += 1;
  bucket.amountCents += cents(amount || 0);
}

function money(centsValue) {
  return centsValue / 100;
}

function istanbulDayStartMillis(value) {
  const offset = 3 * 60 * 60 * 1000;
  const local = new Date(value + offset);
  return (
    Date.UTC(
      local.getUTCFullYear(),
      local.getUTCMonth(),
      local.getUTCDate()
    ) - offset
  );
}

function toDateKey(value) {
  const millis = timestampMillis(value);
  return millis === null ? null : new Date(millis).toISOString().slice(0, 10);
}

function isVerifiedFinanceRecord(record) {
  const quality = String(record.commissionDataQuality || "commission_unknown");
  return !["missing_snapshot", "ambiguous_legacy", "commission_unknown"]
    .includes(quality);
}

function isForecastEligibleRecord(record) {
  const status = String(record.eligibilityStatus || "").toLowerCase();
  const settlement = String(record.settlementStatus || "").toLowerCase();
  return isVerifiedFinanceRecord(record) &&
    ["waiting_period", "eligible"].includes(status) &&
    ["completed", "settled"].includes(settlement) &&
    !["refunded", "cancelled", "reversed", "voided"].includes(
      String(record.sourceStatus || "").toLowerCase()
    );
}

function summarizeFinanceRecords(records, { nowMillis = Date.now() } = {}) {
  const buckets = {
    available: emptyBucket(),
    waiting: emptyBucket(),
    batched: emptyBucket(),
    paid: emptyBucket(),
    blocked: emptyBucket(),
    onHold: emptyBucket(),
    commissionUnknown: emptyBucket(),
    reversed: emptyBucket(),
  };
  const aging = {
    days0To7: emptyBucket(),
    days8To14: emptyBucket(),
    days15To21: emptyBucket(),
    overdue: emptyBucket(),
    blocked: emptyBucket(),
  };
  const waitingSchedule = new Map();
  const eligibleRecords = [];
  const exceptionRecords = [];
  const payoutHistoryByReference = new Map();
  let oldestWaitingMillis = null;
  let nextEligibilityMillis = null;
  let totalEarningsCents = 0;
  let paidThisMonthCents = 0;
  let lastPayout = null;
  let eligibleGrossCents = 0;
  let eligibleCommissionCents = 0;
  let grossSalesCents = 0;
  let platformFeeCents = 0;
  let paidRecordCount = 0;
  const monthStart = new Date(
    new Date(nowMillis).getUTCFullYear(),
    new Date(nowMillis).getUTCMonth(),
    1
  ).getTime();

  for (const record of records) {
    const status = String(record.eligibilityStatus || "").toLowerCase();
    const amount = Number(record.amount || 0);
    const paymentMillis = timestampMillis(record.successfulPaymentAt);
    const eligibilityMillis = timestampMillis(record.eligibilityDate);
    const commissionQuality = String(record.commissionDataQuality || "commission_unknown");
    if (["missing_snapshot", "ambiguous_legacy", "commission_unknown"].includes(commissionQuality)) {
      add(buckets.commissionUnknown, amount);
      exceptionRecords.push({
        reasonCodes: ["commission_unknown"],
        amount,
        sourceNumber: record.sourceNumber || record.orderNumber || record.sourceDocumentId || null,
        sourceType: record.sourceCollection || null,
      });
      continue;
    }
    const refundStatus = String(record.refundStatus || "").toLowerCase();
    const isRecognizedRevenue = Boolean(record.successfulPaymentAt) &&
      !["refunded", "cancelled", "reversed"].includes(refundStatus) &&
      !["refunded", "cancelled", "reversed"].includes(String(record.sourceStatus || "").toLowerCase());
    if (isRecognizedRevenue) {
      grossSalesCents += cents(record.grossAmount || 0);
      platformFeeCents += cents(record.commissionAmount || 0);
      paidRecordCount += 1;
    }
    if (
      record.successfulPaymentAt &&
      ["waiting_period", "eligible", "batched", "paid"].includes(status)
    ) {
      totalEarningsCents += cents(amount);
    }
    if (status === "eligible" && isForecastEligibleRecord(record)) {
      add(buckets.available, amount);
      eligibleGrossCents += cents(record.grossAmount || 0);
      eligibleCommissionCents += cents(record.commissionAmount || 0);
      add(aging.overdue, amount);
      eligibleRecords.push({
        sourceNumber: record.sourceNumber || record.orderNumber || null,
        sourceType: record.sourceCollection || null,
        grossAmount: Number(record.grossAmount || 0),
        commissionAmount: Number(record.commissionAmount || 0),
        netAmount: amount,
        eligibilityDate: record.eligibilityDate || null,
      });
    } else if (status === "waiting_period" && isForecastEligibleRecord(record)) {
      add(buckets.waiting, amount);
      if (
        paymentMillis !== null &&
        (oldestWaitingMillis === null || paymentMillis < oldestWaitingMillis)
      ) {
        oldestWaitingMillis = paymentMillis;
      }
      if (
        eligibilityMillis !== null &&
        (nextEligibilityMillis === null ||
          eligibilityMillis < nextEligibilityMillis)
      ) {
        nextEligibilityMillis = eligibilityMillis;
      }
      if (paymentMillis !== null) {
        const ageDays = Math.max(
          0,
          Math.floor((nowMillis - paymentMillis) / 86400000)
        );
        if (ageDays <= 7) add(aging.days0To7, amount);
        else if (ageDays <= 14) add(aging.days8To14, amount);
        else add(aging.days15To21, amount);
      }
      const dateKey = toDateKey(record.eligibilityDate);
      if (dateKey) {
        const schedule = waitingSchedule.get(dateKey) || emptyBucket();
        add(schedule, amount);
        waitingSchedule.set(dateKey, schedule);
      }
    } else if (status === "batched") {
      add(buckets.batched, amount);
    } else if (status === "paid") {
      add(buckets.paid, amount);
      const paidMillis = timestampMillis(record.paidAt);
      if (paidMillis !== null && paidMillis >= monthStart) {
        paidThisMonthCents += cents(amount);
      }
      if (!lastPayout || (paidMillis || 0) > (lastPayout.paidAtMillis || 0)) {
        lastPayout = {
          amount: money(cents(amount)),
          paidAtMillis: paidMillis,
          reference: record.paymentReference || null,
          batchNumber: record.batchNumber || null,
        };
      }
      const historyKey =
        record.batchId ||
        record.paymentReference ||
        `paid_${paidMillis || "legacy"}`;
      const history = payoutHistoryByReference.get(historyKey) || {
        amountCents: 0,
        paidAtMillis: paidMillis,
        reference: record.paymentReference || null,
        batchNumber: record.batchNumber || null,
        bankSuffix: String(record.iban || "").slice(-4),
        recordCount: 0,
        status: "paid",
      };
      history.amountCents += cents(amount);
      history.recordCount += 1;
      payoutHistoryByReference.set(historyKey, history);
    } else if (status === "on_hold") {
      add(buckets.onHold, amount);
      add(aging.blocked, amount);
      exceptionRecords.push({
        reasonCodes: record.eligibilityReasonCodes || ["on_hold"],
        amount,
        sourceNumber: record.sourceNumber || null,
      });
    } else if (status === "blocked") {
      add(buckets.blocked, amount);
      add(aging.blocked, amount);
      exceptionRecords.push({
        reasonCodes: record.eligibilityReasonCodes || ["blocked"],
        amount,
        sourceNumber: record.sourceNumber || null,
      });
    } else if (status === "reversed" || status === "cancelled") {
      add(buckets.reversed, amount);
    }
  }

  function present(bucket) {
    return { count: bucket.count, amount: money(bucket.amountCents) };
  }
  const nextKey =
    nextEligibilityMillis === null
      ? null
      : new Date(nextEligibilityMillis).toISOString().slice(0, 10);
  const nextBucket = nextKey ? waitingSchedule.get(nextKey) : null;
  return {
    available: present(buckets.available),
    eligibleGrossAmount: money(eligibleGrossCents),
    eligibleCommissionAmount: money(eligibleCommissionCents),
    waiting: present(buckets.waiting),
    batched: present(buckets.batched),
    paid: present(buckets.paid),
    blocked: present(buckets.blocked),
    onHold: present(buckets.onHold),
    commissionUnknown: present(buckets.commissionUnknown),
    reversed: present(buckets.reversed),
    paidThisMonth: money(paidThisMonthCents),
    totalEarnings: money(totalEarningsCents),
    nextEligibilityDate:
      nextEligibilityMillis === null
        ? null
        : admin.firestore.Timestamp.fromMillis(nextEligibilityMillis),
    daysRemaining:
      nextEligibilityMillis === null
        ? 0
        : Math.max(
          0,
          Math.ceil(
            (nextEligibilityMillis - istanbulDayStartMillis(nowMillis)) /
                86400000
          )
        ),
    amountBecomingEligibleNext: nextBucket
      ? money(nextBucket.amountCents)
      : 0,
    countBecomingEligibleNext: nextBucket?.count || 0,
    oldestWaitingPaymentAt:
      oldestWaitingMillis === null
        ? null
        : admin.firestore.Timestamp.fromMillis(oldestWaitingMillis),
    aging: Object.fromEntries(
      Object.entries(aging).map(([key, value]) => [key, present(value)])
    ),
    waitingSchedule: Array.from(waitingSchedule.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, bucket]) => ({ date, ...present(bucket) })),
    eligibleRecords: eligibleRecords.slice(0, 50),
    payoutHistory: Array.from(payoutHistoryByReference.values())
      .sort((a, b) => (b.paidAtMillis || 0) - (a.paidAtMillis || 0))
      .slice(0, 50)
      .map((entry) => ({
        amount: money(entry.amountCents),
        paidAtMillis: entry.paidAtMillis,
        reference: entry.reference,
        batchNumber: entry.batchNumber,
        bankSuffix: entry.bankSuffix,
        recordCount: entry.recordCount,
        status: entry.status,
      })),
    exceptions: exceptionRecords.slice(0, 50),
    lastPayout,
    revenue: {
      grossSales: money(grossSalesCents),
      platformFee: money(platformFeeCents),
      adjustments: 0,
      netRevenue: money(grossSalesCents - platformFeeCents),
      paidRecordCount,
      averageTicket: paidRecordCount
        ? money(Math.round(grossSalesCents / paidRecordCount))
        : 0,
    },
  };
}

async function rebuildSellerFinanceSummary({ db, businessId }) {
  const [payoutSnap, ledgerSnap] = await Promise.all([
    db.collection("payoutIndex").where("businessId", "==", businessId).get(),
    db.collection("financeLedger").where("businessId", "==", businessId).get(),
  ]);
  const records = payoutSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const recordsByCurrency = new Map();
  records.forEach((record) => {
    const currency = String(record.currency || "TRY").toUpperCase();
    const list = recordsByCurrency.get(currency) || [];
    list.push(record);
    recordsByCurrency.set(currency, list);
  });
  const primaryCurrency = recordsByCurrency.has("TRY")
    ? "TRY"
    : recordsByCurrency.keys().next().value || "TRY";
  const primaryRecords = recordsByCurrency.get(primaryCurrency) || [];
  const summary = summarizeFinanceRecords(primaryRecords);
  const adjustmentCents = ledgerSnap.docs.reduce((total, doc) => {
    const entry = doc.data() || {};
    if (entry.eventType !== "manual_adjustment" && entry.eventType !== "adjustment") {
      return total;
    }
    const amount = Number(entry.amountCents || 0);
    return total + (entry.direction === "debit" ? -Math.abs(amount) : amount);
  }, 0);
  summary.revenue.adjustments = money(adjustmentCents);
  summary.revenue.netRevenue = money(
    cents(summary.revenue.grossSales) -
      cents(summary.revenue.platformFee) +
      adjustmentCents
  );
  const first = primaryRecords[0] || records[0] || {};
  await db.collection("sellerFinanceSummaries").doc(businessId).set(
    {
      businessId,
      businessName: first.businessName || null,
      sector: first.sector || null,
      currency: primaryCurrency,
      bankValidationStatus: first.bankValidationStatus || "missing",
      ...summary,
      projectionVersion: 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  const aggregateWrites = Array.from(recordsByCurrency.entries()).map(
    async ([currency, currencyRecords]) => {
      const projection = summarizeFinanceRecords(currencyRecords);
      projection.revenue.adjustments = summary.revenue.adjustments;
      projection.revenue.netRevenue = money(
        cents(projection.revenue.grossSales) -
          cents(projection.revenue.platformFee) +
          cents(projection.revenue.adjustments)
      );
      const snapshot = currencyRecords[0] || {};
      const aggregateId = `${businessId}__${currency}`;
      await db.collection("financeSellerAggregates").doc(aggregateId).set(
        {
          businessId,
          currency,
          sector: snapshot.sector || null,
          businessName: snapshot.businessName || null,
          legalBusinessName: snapshot.legalBusinessName || null,
          accountHolderName: snapshot.accountHolderName || null,
          iban: snapshot.iban || null,
          bankName: snapshot.bankName || null,
          taxNumber: snapshot.taxNumber || null,
          contactEmail: snapshot.contactEmail || null,
          contactPhone: snapshot.contactPhone || null,
          bankValidationStatus: snapshot.bankValidationStatus || "missing",
          ...projection,
          eligiblePayoutIndexIds: currencyRecords
            .filter((record) => record.eligibilityStatus === "eligible")
            .map((record) => record.id),
          projectionVersion: 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
  );
  await Promise.all(aggregateWrites);
  return summary;
}

async function rebuildAdminFinanceOverview({ db }) {
  const [payoutSnap, batchesSnap, ledgerSnap] = await Promise.all([
    db.collection("payoutIndex").get(),
    db.collection("payoutBatches").get(),
    db.collection("financeLedger").get(),
  ]);
  const records = payoutSnap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
  const summary = summarizeFinanceRecords(records);
  const batches = batchesSnap.docs.map((doc) => doc.data() || {});
  const now = new Date();
  const todayStart = istanbulDayStartMillis(now.getTime());
  const weekStart =
    todayStart - ((now.getUTCDay() || 7) - 1) * 86400000;
  const monthStart = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1);
  let paidTodayCents = 0;
  let paidThisWeekCents = 0;
  for (const record of records) {
    if (!isVerifiedFinanceRecord(record)) continue;
    const paidMillis = timestampMillis(record.paidAt);
    if (paidMillis === null) continue;
    if (paidMillis >= todayStart) paidTodayCents += cents(record.amount || 0);
    if (paidMillis >= weekStart) paidThisWeekCents += cents(record.amount || 0);
  }
  let todaySalesCents = 0;
  let todayCommissionCents = 0;
  let todayRefundsCents = 0;
  let monthlyPlatformRevenueCents = 0;
  for (const ledgerDoc of ledgerSnap.docs) {
    const entry = ledgerDoc.data() || {};
    const occurredAt = timestampMillis(entry.occurredAt);
    if (occurredAt === null) continue;
    const amountCents = Number(entry.amountCents || 0);
    if (
      entry.eventType === "customer_payment_verified" &&
      occurredAt >= todayStart
    ) {
      todaySalesCents += amountCents;
    }
    if (entry.eventType === "platform_commission_recognized") {
      if (occurredAt >= todayStart) todayCommissionCents += amountCents;
      if (occurredAt >= monthStart) monthlyPlatformRevenueCents += amountCents;
    }
    if (
      ["customer_refund", "refund_completed"].includes(entry.eventType) &&
      occurredAt >= todayStart
    ) {
      todayRefundsCents += amountCents;
    }
    if (
      entry.eventType === "commission_reversed" &&
      occurredAt >= monthStart
    ) {
      monthlyPlatformRevenueCents -= amountCents;
    }
  }
  const todayEligibleCents = records
    .filter((record) => {
      const millis = timestampMillis(record.eligibilityDate);
      return (
        millis !== null &&
        millis >= todayStart &&
        millis < todayStart + 86400000 &&
        record.eligibilityStatus === "eligible" &&
        isForecastEligibleRecord(record)
      );
    })
    .reduce((total, record) => total + cents(record.amount || 0), 0);
  const tomorrowStart = todayStart + 86400000;
  const inDays = (record, days) => {
    const millis = timestampMillis(record.eligibilityDate);
    return (
      record.eligibilityStatus === "waiting_period" &&
      isForecastEligibleRecord(record) &&
      millis !== null &&
      millis >= tomorrowStart &&
      millis < tomorrowStart + days * 86400000
    );
  };
  const waitingAmount = (predicate) =>
    records
      .filter(predicate)
      .reduce((total, record) => total + cents(record.amount || 0), 0);
  const tomorrowBecomingEligibleCents = waitingAmount((record) =>
    inDays(record, 1)
  );
  const next7DaysCents = waitingAmount((record) => inDays(record, 7));
  const next30DaysCents = waitingAmount((record) => inDays(record, 30));
  const overview = {
    ...summary,
    eligibleSellerCount: new Set(
      records
        .filter((record) => record.eligibilityStatus === "eligible" && isForecastEligibleRecord(record))
        .map((record) => record.businessId)
    ).size,
    waitingSellerCount: new Set(
      records
        .filter((record) => record.eligibilityStatus === "waiting_period" && isForecastEligibleRecord(record))
        .map((record) => record.businessId)
    ).size,
    exceptionCount: records.filter((record) =>
      ["blocked", "on_hold", "reversed", "cancelled"].includes(
        record.eligibilityStatus
      ) || !isVerifiedFinanceRecord(record)
    ).length,
    draftBatchCount: batches.filter((batch) => batch.status === "draft").length,
    exportedBatchCount: batches.filter(
      (batch) => batch.status === "exported"
    ).length,
    paidToday: money(paidTodayCents),
    paidThisWeek: money(paidThisWeekCents),
    todaySales: money(todaySalesCents),
    todayCommission: money(todayCommissionCents),
    todayRefunds: money(todayRefundsCents),
    todayEligible: money(todayEligibleCents),
    todayPaid: money(paidTodayCents),
    outstandingLiability: money(
      summary.available.amount * 100 +
        summary.waiting.amount * 100 +
        summary.batched.amount * 100
    ),
    monthlyPlatformRevenue: money(monthlyPlatformRevenueCents),
    tomorrowBecomingEligible: money(tomorrowBecomingEligibleCents),
    next7DaysBecomingEligible: money(next7DaysCents),
    next30DaysBecomingEligible: money(next30DaysCents),
    estimatedPayable: money(
      cents(summary.available.amount) + next30DaysCents
    ),
    projectionVersion: 1,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.collection("financeOperations").doc("overview").set(overview);
  return overview;
}

module.exports = {
  summarizeFinanceRecords,
  rebuildSellerFinanceSummary,
  rebuildAdminFinanceOverview,
};
