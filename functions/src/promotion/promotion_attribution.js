"use strict";

const crypto = require("crypto");
const admin = require("firebase-admin");

const {canonicalServiceTargetId} = require("./promotion_engine");

const ATTRIBUTION_POLICY_VERSION = "m9_same_flow_v1";
// This is an anti-stale same-flow safeguard, not an approved marketing
// attribution window. No long-lived last-click policy is implied.
const SAME_FLOW_MAX_AGE_MS = 30 * 60 * 1000;
const ATTRIBUTIONS = "promotion_attributions";
const RECONCILIATION_CASES = "promotion_reconciliation_cases";
const STATS = "promotion_campaign_stats";
const EVENTS = "promotion_events";
const ACTIVE_TARGETS = new Set(["PET", "PRODUCT", "SERVICE"]);
const COMMERCIAL_ATTRIBUTION_POLICY_VERSION = "petsupo_same_flow_v1";
const TECHNICAL_CORRELATION_POLICY_VERSION = "m9_same_flow_v1";
const RECONCILIATION_HEALTH = Object.freeze({
  converged: "CONVERGED",
  pending: "PENDING",
  ambiguous: "AMBIGUOUS",
  failed: "FAILED",
});
const FINANCIAL_METRICS_STATUS = Object.freeze({
  available: "AVAILABLE",
  provisional: "PROVISIONAL",
  unavailable: "UNAVAILABLE",
});

const asText = (value, field, {allowSlash = false, optional = false} = {}) => {
  if (optional && (value === undefined || value === null || value === "")) return null;
  if (typeof value !== "string" || !value.trim()) throw new Error(`${field} is required`);
  const result = value.trim();
  if (!allowSlash && result.includes("/")) throw new Error(`${field} is invalid`);
  return result;
};

const millis = (value) => {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = new Date(value).getTime();
  return Number.isFinite(parsed) ? parsed : null;
};

const timestamp = (value, fallback = new Date()) => {
  const ms = millis(value) ?? fallback.getTime();
  return admin.firestore.Timestamp.fromMillis(ms);
};

const money = (value) => {
  const amount = Number(value);
  return Number.isFinite(amount) && amount >= 0 ? Number(amount.toFixed(2)) : null;
};

const normalized = (value) => String(value || "").trim().toLowerCase();

function attributionId(campaignId, sourceType, sourceId) {
  return crypto.createHash("sha256")
    .update(`${campaignId}|${sourceType}|${sourceId}`)
    .digest("hex");
}

function reconciliationCaseId(sourceType, sourceId) {
  return crypto.createHash("sha256")
    .update(`${sourceType}|${sourceId}`)
    .digest("hex");
}

function sourceStatus({paid, refundedAmount, grossAmount, valid = true}) {
  if (!valid) return "invalid";
  if (!paid) return "qualified";
  if (refundedAmount >= grossAmount && grossAmount > 0) return "reversed";
  if (refundedAmount > 0) return "partially_reversed";
  return "financial";
}

function sourceFinancialState({
  paid,
  refundedAmount = 0,
  grossAmount = 0,
  valid = true,
  currency,
  sourceType,
  sourceId,
  targetType,
  targetId,
  ownerUid,
  businessId,
  actorUid,
  occurredAt,
  sourceState,
}) {
  const gross = money(grossAmount);
  const refunded = money(refundedAmount) ?? 0;
  if (gross === null || refunded > gross || !currency) {
    return {sourceType, sourceId, targetType, targetId, valid: false, status: "invalid"};
  }
  return {
    sourceType,
    sourceId,
    targetType,
    targetId,
    ownerUid: ownerUid || null,
    businessId: businessId || null,
    actorUid: actorUid || null,
    occurredAt,
    sourceState: sourceState || null,
    valid,
    paid: Boolean(paid),
    status: sourceStatus({paid, refundedAmount: refunded, grossAmount: gross, valid}),
    grossAmount: gross,
    refundedAmount: refunded,
    netAttributedRevenue: Number(Math.max(0, gross - refunded).toFixed(2)),
    currency: String(currency).trim().toUpperCase(),
  };
}

function productLines(data = {}) {
  const values = Array.isArray(data.items) && data.items.length
    ? data.items
    : Array.isArray(data.inventoryLines) ? data.inventoryLines : [];
  return values.filter((item) => item && (item.productId || item.id));
}

async function productOrderSources({db, sellerOrderId}) {
  const sellerId = asText(sellerOrderId, "sellerOrderId");
  const sellerSnap = await db.collection("sellerOrders").doc(sellerId).get();
  if (!sellerSnap.exists) return [];
  const seller = sellerSnap.data() || {};
  const rootId = seller.rootOrderId || seller.orderId;
  const rootSnap = rootId ? await db.collection("orders").doc(String(rootId)).get() : null;
  const root = rootSnap?.exists ? rootSnap.data() || {} : {};
  const paymentStatus = normalized(seller.paymentStatus || seller.payment?.status);
  const rootPaymentStatus = normalized(root.paymentStatus || root.payment?.status);
  const paid = [paymentStatus, rootPaymentStatus].includes("paid") &&
    (normalized(seller.status) === "paid" || normalized(root.status) === "paid");
  const buyerUid = seller.buyerUid || seller.userId || root.buyerUid || root.userId || null;
  const currency = seller.payment?.currency || seller.currency || root.payment?.currency ||
    root.pricing?.currency || "TRY";
  const businessId = seller.businessId || seller.shopId || null;
  const businessSnap = businessId ? await db.collection("businesses").doc(String(businessId)).get() : null;
  const ownerUid = businessSnap?.exists
    ? businessSnap.data()?.ownerUid || businessSnap.data()?.uid || null
    : seller.ownerUid || null;
  const refundsByProduct = new Map();
  let refundReconciliationPending = false;
  if (seller.cancellationRefund?.status === "refunded") {
  }
  if (sellerId) {
    const returnsSnap = await db.collection("order_returns").where("sellerOrderId", "==", sellerId).limit(100).get();
    for (const returnDoc of returnsSnap.docs) {
      const returnData = returnDoc.data() || {};
      if (normalized(returnData.status) !== "refunded") continue;
      const returnItems = Array.isArray(returnData.returnItems) ? returnData.returnItems : [];
      if (!returnItems.length) {
        refundReconciliationPending = true;
        continue;
      }
      for (const returnItem of returnItems) {
        const productId = String(returnItem.productId || returnItem.id || "").trim();
        const itemAmount = money(returnItem.refundAmount ?? returnItem.amount ?? returnItem.totalPrice);
        if (!productId || itemAmount === null) {
          refundReconciliationPending = true;
          continue;
        }
        refundsByProduct.set(productId, (refundsByProduct.get(productId) || 0) + itemAmount);
      }
    }
  }
  const paidAt = seller.paidAt || seller.payment?.paidAt || root.paidAt || root.payment?.paidAt || seller.updatedAt || new Date();
  return productLines(seller).map((item, index) => {
    const productId = String(item.productId || item.id || "").trim();
    const lineId = String(item.lineId || item.inventoryLineId || productId || index).trim();
    const quantity = Math.max(1, Number(item.quantity || 1));
    const gross = money(item.totalPrice ?? item.lineTotal ?? item.subtotal ??
      (Number(item.unitPrice ?? item.price) * quantity));
    let itemRefund = refundsByProduct.get(productId) || 0;
    const lines = productLines(seller);
    if (seller.cancellationRefund?.status === "refunded" && lines.length === 1) {
      itemRefund += money(seller.cancellationRefund.amount) || 0;
    } else if (seller.cancellationRefund?.status === "refunded" && lines.length > 1) {
      refundReconciliationPending = true;
    }
    if (itemRefund > (gross || 0)) itemRefund = gross || 0;
    const source = sourceFinancialState({
      sourceType: "PRODUCT_ORDER_ITEM",
      sourceId: `${sellerId}::${lineId}`,
      targetType: "PRODUCT",
      targetId: productId,
      ownerUid,
      businessId,
      actorUid: buyerUid,
      occurredAt: paidAt,
      sourceState: seller.status || null,
      paid,
      refundedAmount: itemRefund,
      grossAmount: gross,
      currency: item.currency || currency,
      valid: Boolean(rootSnap?.exists && businessId && productId && gross !== null),
    });
    if (refundReconciliationPending) source.refundReconciliationPending = true;
    return source;
  });
}

async function appointmentSource({db, collectionName, appointmentId}) {
  const id = asText(appointmentId, "appointmentId");
  const snap = await db.collection(collectionName).doc(id).get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  const targetType = "SERVICE";
  const sector = collectionName === "vet_appointments" ? "VET" : "GROOMER";
  const businessId = data.businessId || data.groomyId || null;
  const serviceId = data.serviceId || null;
  const targetId = businessId && serviceId
    ? canonicalServiceTargetId(sector, String(businessId), String(serviceId))
    : null;
  const financial = data.financial || {};
  const gross = money(financial.grossAmount ?? financial.finalPrice);
  const paid = normalized(data.paymentStatus) === "paid" &&
    normalized(data.payment?.finalizationStatus) === "completed" &&
    normalized(data.financialStatus) === "verified" && gross !== null;
  const refundStatus = normalized(data.paymentStatus) === "refunded" ||
    normalized(data.refundStatus) === "refunded" ||
    normalized(data.refundDetails?.status) === "refunded";
  const refundedAmount = refundStatus
    ? money(data.refundDetails?.refundAmount ?? data.refundAmount ?? gross) || 0
    : 0;
  const businessSnap = businessId ? await db.collection("businesses").doc(String(businessId)).get() : null;
  const ownerUid = businessSnap?.exists
    ? businessSnap.data()?.ownerUid || businessSnap.data()?.uid || null
    : null;
  return sourceFinancialState({
    sourceType: collectionName === "vet_appointments" ? "VET_APPOINTMENT" : "GROOMY_APPOINTMENT",
    sourceId: id,
    targetType,
    targetId,
    ownerUid,
    businessId,
    actorUid: data.userId || data.buyerUid || null,
    occurredAt: data.paidAt || data.payment?.finalizationCompletedAt || data.updatedAt || data.createdAt || new Date(),
    sourceState: data.status || null,
    paid,
    refundedAmount,
    grossAmount: gross,
    currency: financial.currency || data.currency || data.payment?.currency || "TRY",
    valid: Boolean(targetId && businessId && serviceId && businessSnap?.exists),
  });
}

async function resolvePromotionSources({db, sourceType, sourceId}) {
  if (sourceType === "PRODUCT_ORDER") return productOrderSources({db, sellerOrderId: sourceId});
  if (sourceType === "VET_APPOINTMENT") return [await appointmentSource({db, collectionName: "vet_appointments", appointmentId: sourceId})].filter(Boolean);
  if (sourceType === "GROOMY_APPOINTMENT") return [await appointmentSource({db, collectionName: "groomy_appointments", appointmentId: sourceId})].filter(Boolean);
  throw new Error(`Unsupported Promotion source type: ${sourceType}`);
}

async function findInteraction({db, source, nowMs}) {
  if (!source.actorUid || !source.targetId) return {status: "no_interaction"};
  const snap = await db.collection(EVENTS)
    .where("targetId", "==", source.targetId)
    .limit(100)
    .get();
  const candidates = snap.docs.filter((doc) => {
    const event = doc.data() || {};
    const eventMs = millis(event.occurredAt);
    return ["CLICK", "DETAIL_VIEW"].includes(event.eventType) &&
      event.targetType === source.targetType &&
      event.actorUid === source.actorUid &&
      eventMs !== null && eventMs <= nowMs && nowMs - eventMs <= SAME_FLOW_MAX_AGE_MS;
  });
  if (!candidates.length) return {status: "no_interaction"};
  const byCampaign = new Map();
  for (const doc of candidates) {
    const event = doc.data() || {};
    const current = byCampaign.get(event.campaignId);
    if (!current || millis(current.data().occurredAt) < millis(event.occurredAt)) {
      byCampaign.set(event.campaignId, doc);
    }
  }
  if (byCampaign.size !== 1) return {status: "ambiguous", candidates: [...byCampaign.keys()]};
  const eventDoc = [...byCampaign.values()][0];
  return {status: "matched", eventDoc, event: eventDoc.data() || {}};
}

async function loadAndValidateCampaign({db, source, campaignId, interaction}) {
  if (!campaignId || !ACTIVE_TARGETS.has(source.targetType)) return null;
  const snap = await db.collection("promotion_campaigns").doc(campaignId).get();
  if (!snap.exists) return null;
  const campaign = snap.data() || {};
  if (campaign.targetType !== source.targetType || campaign.targetId !== source.targetId) return null;
  if (campaign.ownerUid !== source.ownerUid || (campaign.businessId || null) !== (source.businessId || null)) return null;
  if (!["active", "expired"].includes(normalized(campaign.status))) return null;
  const eventMs = millis(interaction.event.occurredAt);
  const startsMs = millis(campaign.startsAt);
  const expiresMs = millis(campaign.expiresAt);
  if (eventMs === null || startsMs === null || expiresMs === null || eventMs < startsMs || eventMs >= expiresMs) return null;
  if (String(campaign.currency || "").toUpperCase() !== source.currency) {
    return {rejection: "currency_mismatch", campaignId, campaign};
  }
  return {campaign, campaignId, interaction};
}

function desiredAttribution({source, campaign, interaction, now}) {
  const status = source.status;
  const financiallyConverted = ["financial", "partially_reversed"].includes(status);
  const reconciliationStatus = healthForSource(source);
  return {
    attributionId: attributionId(campaign.campaignId, source.sourceType, source.sourceId),
    campaignId: campaign.campaignId,
    targetType: source.targetType,
    targetId: source.targetId,
    conversionType: source.targetType === "PRODUCT" ? "PRODUCT_ORDER" : "SERVICE_BOOKING",
    sourceType: source.sourceType,
    sourceId: source.sourceId,
    ownerUid: source.ownerUid,
    businessId: source.businessId || null,
    interactionEventId: interaction.eventDoc.id,
    placement: interaction.event.placement || null,
    qualifiedAt: timestamp(interaction.event.occurredAt),
    financiallyConvertedAt: ["financial", "partially_reversed"].includes(status)
      ? timestamp(source.occurredAt)
      : null,
    grossRevenue: source.grossAmount,
    refundedAmount: source.refundedAmount,
    // Qualified-but-unpaid orders/bookings must never contribute revenue.
    // A reversed source retains its audit amount, but contributes zero net
    // revenue and zero financial conversions through the delta below.
    netAttributedRevenue: financiallyConverted ? source.netAttributedRevenue : 0,
    currency: source.currency,
    status,
    reconciliationStatus,
    financialMetricsStatus: financialStatusFor({targetType: source.targetType, health: reconciliationStatus}),
    // Preserve the M9 field for historical compatibility. The explicit
    // commercial policy is separate from the technical correlation TTL.
    attributionPolicyVersion: ATTRIBUTION_POLICY_VERSION,
    commercialAttributionPolicyVersion: COMMERCIAL_ATTRIBUTION_POLICY_VERSION,
    technicalCorrelationPolicyVersion: TECHNICAL_CORRELATION_POLICY_VERSION,
    technicalCorrelationTtlMinutes: SAME_FLOW_MAX_AGE_MS / 60000,
    sourceState: source.sourceState || null,
    createdAt: now,
    updatedAt: now,
  };
}

function caseStatusForResult(result) {
  if (result?.reconciliationStatus) return result.reconciliationStatus;
  if (result?.status === "ambiguous") return RECONCILIATION_HEALTH.ambiguous;
  if (["no_interaction", "reconciliation_pending", "campaign_mismatch"].includes(result?.status)) {
    return RECONCILIATION_HEALTH.pending;
  }
  if (result?.status === "currency_mismatch") return RECONCILIATION_HEALTH.failed;
  if (result?.status === "invalid_source") return RECONCILIATION_HEALTH.failed;
  return RECONCILIATION_HEALTH.failed;
}

async function writeReconciliationCase({db, source, sourceType, sourceId, result, now}) {
  const status = caseStatusForResult(result);
  const ref = db.collection(RECONCILIATION_CASES).doc(reconciliationCaseId(sourceType, sourceId));
  const safeErrorCategory = result?.status === "currency_mismatch"
    ? "CURRENCY_MISMATCH"
    : result?.status === "campaign_mismatch"
    ? "CAMPAIGN_OR_CURRENCY_MISMATCH"
    : result?.status === "ambiguous"
      ? "AMBIGUOUS_ATTRIBUTION"
      : result?.status === "reconciliation_pending"
        ? "REFUND_ALLOCATION_PENDING"
        : result?.status === "no_interaction"
          ? "NO_VALID_SAME_FLOW_INTERACTION"
          : "RECONCILIATION_RETRYABLE_FAILURE";
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    const previousAttempts = existing.exists ? Number(existing.data()?.attemptCount || 0) : 0;
    tx.set(ref, {
      caseId: ref.id,
      sourceType,
      sourceId,
      targetType: source?.targetType || null,
      targetId: source?.targetId || null,
      businessId: source?.businessId || null,
      status,
      campaignIds: result?.candidates?.length
        ? result.candidates
        : (result?.campaignId ? [result.campaignId] : []),
      errorCategory: safeErrorCategory,
      attemptCount: previousAttempts + 1,
      lastAttemptAt: now,
      updatedAt: now,
    }, {merge: true});
    if (result?.status === "currency_mismatch" && result.campaignId) {
      const statsRef = db.collection(STATS).doc(result.campaignId);
      tx.set(statsRef, {
        campaignId: result.campaignId,
        financialMetricsStatus: FINANCIAL_METRICS_STATUS.unavailable,
        reconciliationStatus: RECONCILIATION_HEALTH.failed,
        currencyMismatch: true,
        updatedAt: now,
      }, {merge: true});
    }
  });
}

function financialCount(status) {
  return ["financial", "partially_reversed"].includes(status) ? 1 : 0;
}

function healthForSource(source) {
  if (!source || !source.valid) return RECONCILIATION_HEALTH.failed;
  if (source.refundReconciliationPending) return RECONCILIATION_HEALTH.ambiguous;
  return source.status === "qualified"
    ? RECONCILIATION_HEALTH.pending
    : RECONCILIATION_HEALTH.converged;
}

function financialStatusFor({targetType, health}) {
  if (targetType === "PET") return FINANCIAL_METRICS_STATUS.unavailable;
  return health === RECONCILIATION_HEALTH.converged
    ? FINANCIAL_METRICS_STATUS.available
    : FINANCIAL_METRICS_STATUS.provisional;
}

async function reconcileOne({db, source, now = new Date()}) {
  if (!source || !source.valid || source.targetType === "PET") return {status: "invalid_source"};
  const nowMs = millis(now);
  if (source.refundReconciliationPending) {
    const interaction = await findInteraction({
      db,
      source,
      nowMs: millis(source.occurredAt) ?? nowMs,
    });
    return {
      status: "reconciliation_pending",
      reconciliationStatus: RECONCILIATION_HEALTH.ambiguous,
      campaignId: interaction.event?.campaignId || null,
      candidates: interaction.candidates || [],
    };
  }
  const interaction = await findInteraction({
    db,
    source,
    nowMs: millis(source.occurredAt) ?? nowMs,
  });
  if (interaction.status !== "matched") return interaction;
  const linked = await loadAndValidateCampaign({
    db, source, campaignId: interaction.event.campaignId, interaction,
  });
  if (linked?.rejection === "currency_mismatch") return {
    status: "currency_mismatch",
    reconciliationStatus: RECONCILIATION_HEALTH.failed,
    campaignId: linked.campaignId,
  };
  if (!linked) return {status: "campaign_mismatch"};
  const desired = desiredAttribution({source, campaign: linked.campaign, interaction, now: timestamp(now)});
  const reconciliationHealth = healthForSource(source);
  const attributionRef = db.collection(ATTRIBUTIONS).doc(desired.attributionId);
  const statsRef = db.collection(STATS).doc(desired.campaignId);
  await db.runTransaction(async (tx) => {
    const [oldSnap, statsSnap] = await Promise.all([tx.get(attributionRef), tx.get(statsRef)]);
    const old = oldSnap.exists ? oldSnap.data() || {} : null;
    const stats = statsSnap.exists ? statsSnap.data() || {} : {};
    if (stats.currency && String(stats.currency).toUpperCase() !== desired.currency) {
      throw new Error("Promotion campaign stats currency mismatch");
    }
    const oldQualified = old && old.status !== "invalid" ? 1 : 0;
    const oldFinancial = old ? financialCount(old.status) : 0;
    const oldRevenue = money(old?.netAttributedRevenue) || 0;
    const oldRefunded = money(old?.refundedAmount) || 0;
    const currentQualified = Math.max(0, Number(stats.qualifiedConversions || 0));
    const currentFinancial = Math.max(0, Number(stats.financialConversions || 0));
    const currentRevenue = Math.max(0, Number(stats.attributedRevenue || 0));
    const currentRefunded = Math.max(0, Number(stats.refundedRevenue || 0));
    const nextQualified = Math.max(0, currentQualified + (desired.status === "invalid" ? 0 : 1 - oldQualified));
    const nextFinancial = Math.max(0, currentFinancial + financialCount(desired.status) - oldFinancial);
    const nextRevenue = Math.max(0, Number((currentRevenue + desired.netAttributedRevenue - oldRevenue).toFixed(2)));
    const nextRefunded = Math.max(0, Number((currentRefunded + desired.refundedAmount - oldRefunded).toFixed(2)));
    const nextStatus = desired.status;
    tx.set(attributionRef, desired, {merge: true});
    tx.set(statsRef, {
      campaignId: desired.campaignId,
      targetType: desired.targetType,
      targetId: desired.targetId,
      ownerUid: desired.ownerUid,
      businessId: desired.businessId,
      currency: desired.currency,
      qualifiedConversions: nextQualified,
      financialConversions: nextFinancial,
      attributedRevenue: nextRevenue,
      refundedRevenue: nextRefunded,
      currencyMismatch: false,
      revenueAttributionStatus: "server_attributed",
      lastReconciledAt: desired.updatedAt,
      updatedAt: desired.updatedAt,
      lastAttributionStatus: nextStatus,
      reconciliationStatus: reconciliationHealth,
      financialMetricsStatus: financialStatusFor({
        targetType: desired.targetType,
        health: reconciliationHealth,
      }),
    }, {merge: true});
  });
  return {
    status: desired.status,
    reconciliationStatus: reconciliationHealth,
    attributionId: desired.attributionId,
    campaignId: desired.campaignId,
  };
}

async function reconcilePromotionConversion({db, sourceType, sourceId, sourceResolver, now = new Date()}) {
  const sources = sourceResolver
    ? await sourceResolver({db, sourceType, sourceId})
    : await resolvePromotionSources({db, sourceType, sourceId});
  const results = [];
  for (const source of sources || []) {
    const result = await reconcileOne({db, source, now});
    results.push(result);
    // Health cases are operational metadata only. A failure to write one must
    // never change the underlying domain transaction or attribution result.
    await writeReconciliationCase({
      db, source, sourceType, sourceId: source.sourceId || sourceId,
      result, now: timestamp(now),
    }).catch(() => {});
  }
  return {sourceType, sourceId, results};
}

async function readPromotionReconciliationHealth({db, limit = 500}) {
  const boundedLimit = Math.min(500, Math.max(1, Number(limit) || 500));
  const summary = {};
  const campaignSet = new Set();
  let oldestUnresolvedAt = null;
  let lastReconciliationAttempt = null;
  for (const status of Object.values(RECONCILIATION_HEALTH)) {
    const snap = await db.collection(RECONCILIATION_CASES)
      .where("status", "==", status)
      .limit(boundedLimit)
      .get();
    summary[status.toLowerCase()] = snap.size;
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      for (const campaignId of data.campaignIds || []) {
        if (campaignSet.size < 100) campaignSet.add(campaignId);
      }
      const attemptMs = millis(data.lastAttemptAt);
      if (attemptMs !== null) {
        if (!lastReconciliationAttempt || attemptMs > lastReconciliationAttempt.getTime()) {
          lastReconciliationAttempt = new Date(attemptMs);
        }
        if (status !== RECONCILIATION_HEALTH.converged &&
            (!oldestUnresolvedAt || attemptMs < oldestUnresolvedAt.getTime())) {
          oldestUnresolvedAt = new Date(attemptMs);
        }
      }
    }
  }
  return {
    policyVersion: COMMERCIAL_ATTRIBUTION_POLICY_VERSION,
    technicalCorrelationPolicyVersion: TECHNICAL_CORRELATION_POLICY_VERSION,
    technicalCorrelationTtlMinutes: SAME_FLOW_MAX_AGE_MS / 60000,
    pendingCount: summary.pending || 0,
    failedCount: summary.failed || 0,
    ambiguousCount: summary.ambiguous || 0,
    convergedCount: summary.converged || 0,
    oldestUnresolvedAt: oldestUnresolvedAt ? timestamp(oldestUnresolvedAt) : null,
    lastReconciliationAttempt: lastReconciliationAttempt ? timestamp(lastReconciliationAttempt) : null,
    affectedCampaigns: [...campaignSet],
    bounded: true,
    limit: boundedLimit,
  };
}

/**
 * Rebuilds only the financial/qualified counters for one campaign from the
 * trusted attribution ledger. Exposure telemetry is intentionally untouched.
 * This is bounded by the caller's campaign scope and is safe to repeat.
 */
async function repairPromotionCampaignStats({db, campaignId, now = new Date()}) {
  const id = asText(campaignId, "campaignId");
  const campaignSnap = await db.collection("promotion_campaigns").doc(id).get();
  if (!campaignSnap.exists) return {status: "not_found", campaignId: id};
  const campaign = campaignSnap.data() || {};
  const attributionSnap = await db.collection(ATTRIBUTIONS)
    .where("campaignId", "==", id)
    .limit(500)
    .get();
  let qualifiedConversions = 0;
  let financialConversions = 0;
  let attributedRevenue = 0;
  let refundedRevenue = 0;
  let hasPending = false;
  let hasAmbiguous = false;
  let hasFailed = false;
  for (const doc of attributionSnap.docs) {
    const attribution = doc.data() || {};
    if (attribution.currency && campaign.currency &&
        String(attribution.currency).toUpperCase() !== String(campaign.currency).toUpperCase()) {
      hasFailed = true;
      continue;
    }
    if (attribution.status !== "invalid") qualifiedConversions += 1;
    financialConversions += financialCount(attribution.status);
    attributedRevenue += money(attribution.netAttributedRevenue) || 0;
    refundedRevenue += money(attribution.refundedAmount) || 0;
    if (attribution.reconciliationStatus === RECONCILIATION_HEALTH.pending) hasPending = true;
    if (attribution.reconciliationStatus === RECONCILIATION_HEALTH.ambiguous) hasAmbiguous = true;
    if (attribution.reconciliationStatus === RECONCILIATION_HEALTH.failed) hasFailed = true;
  }
  const reconciliationStatus = hasFailed
    ? RECONCILIATION_HEALTH.failed
    : hasAmbiguous
      ? RECONCILIATION_HEALTH.ambiguous
      : hasPending
        ? RECONCILIATION_HEALTH.pending
        : RECONCILIATION_HEALTH.converged;
  const financialMetricsStatus = campaign.targetType === "PET"
    ? FINANCIAL_METRICS_STATUS.unavailable
    : financialStatusFor({targetType: campaign.targetType, health: reconciliationStatus});
  const repairedAt = timestamp(now);
  await db.runTransaction(async (tx) => {
    const statsRef = db.collection(STATS).doc(id);
    const statsSnap = await tx.get(statsRef);
    const stats = statsSnap.exists ? statsSnap.data() || {} : {};
    if (stats.currency && campaign.currency &&
        String(stats.currency).toUpperCase() !== String(campaign.currency).toUpperCase()) {
      throw new Error("Promotion campaign stats currency mismatch");
    }
    tx.set(statsRef, {
      campaignId: id,
      targetType: campaign.targetType,
      targetId: campaign.targetId,
      ownerUid: campaign.ownerUid || null,
      businessId: campaign.businessId || null,
      currency: campaign.currency || null,
      qualifiedConversions,
      financialConversions,
      attributedRevenue: Number(attributedRevenue.toFixed(2)),
      refundedRevenue: Number(refundedRevenue.toFixed(2)),
      revenueAttributionStatus: attributionSnap.empty ? "server_attribution_pending" : "server_attributed",
      reconciliationStatus,
      financialMetricsStatus,
      lastReconciledAt: repairedAt,
      updatedAt: repairedAt,
      lastAttributionStatus: "stats_repair",
    }, {merge: true});
  });
  return {
    status: "repaired",
    campaignId: id,
    attributionCount: attributionSnap.size,
    reconciliationStatus,
    financialMetricsStatus,
    qualifiedConversions,
    financialConversions,
    attributedRevenue: Number(attributedRevenue.toFixed(2)),
    refundedRevenue: Number(refundedRevenue.toFixed(2)),
  };
}

module.exports = {
  ATTRIBUTION_POLICY_VERSION,
  SAME_FLOW_MAX_AGE_MS,
  ATTRIBUTIONS,
  RECONCILIATION_CASES,
  COMMERCIAL_ATTRIBUTION_POLICY_VERSION,
  TECHNICAL_CORRELATION_POLICY_VERSION,
  RECONCILIATION_HEALTH,
  FINANCIAL_METRICS_STATUS,
  resolvePromotionSources,
  reconcilePromotionConversion,
  reconcileOne,
  repairPromotionCampaignStats,
  readPromotionReconciliationHealth,
  attributionId,
};
