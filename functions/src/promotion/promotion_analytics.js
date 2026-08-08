"use strict";

const crypto = require("crypto");
const admin = require("firebase-admin");

const EVENT_TYPES = Object.freeze({
  impression: "IMPRESSION",
  click: "CLICK",
  detailView: "DETAIL_VIEW",
});

const PLACEMENTS = Object.freeze({
  pet: "playmate_discovery",
  product: "marketplace_product_list",
  vet: "vet_service_list",
  groomer: "groomy_service_list",
});

const CLIENT_EVENT_TYPES = new Set(Object.values(EVENT_TYPES));
const ENABLED_SERVICE_SECTORS = new Set(["VET", "GROOMER"]);
const EVENT_COLLECTION = "promotion_events";
const STATS_COLLECTION = "promotion_campaign_stats";
const MAX_OCCURRED_SKEW_MS = 24 * 60 * 60 * 1000;

const asString = (value, field, {optional = false, max = 256, allowSlash = false} = {}) => {
  if (optional && (value === undefined || value === null || value === "")) return null;
  if (typeof value !== "string" || value.trim() === "") throw new Error(`${field} is required`);
  const result = value.trim();
  if (result.length > max || (!allowSlash && result.includes("/"))) throw new Error(`${field} is invalid`);
  return result;
};

const asTimestamp = (value, field) => {
  if (value && typeof value.toMillis === "function") return value;
  if (value instanceof Date) return admin.firestore.Timestamp.fromDate(value);
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new Error(`${field} is invalid`);
  return admin.firestore.Timestamp.fromDate(date);
};

const isEnabledTarget = (targetType, sector) => {
  if (["PET", "PRODUCT"].includes(targetType)) return true;
  return targetType === "SERVICE" && ENABLED_SERVICE_SECTORS.has(String(sector || "").toUpperCase());
};

function placementFor(targetType, sector) {
  if (targetType === "PET") return PLACEMENTS.pet;
  if (targetType === "PRODUCT") return PLACEMENTS.product;
  if (targetType === "SERVICE" && String(sector || "").toUpperCase() === "VET") return PLACEMENTS.vet;
  if (targetType === "SERVICE" && String(sector || "").toUpperCase() === "GROOMER") return PLACEMENTS.groomer;
  return null;
}

function eventDedupeId({eventId, campaignId, targetId, eventType, placement, actorUid, sessionId}) {
  const supplied = asString(eventId, "eventId", {max: 180, allowSlash: true});
  return crypto.createHash("sha256")
    .update([supplied, campaignId, targetId, eventType, placement, actorUid || "anonymous", sessionId || ""].join("|"))
    .digest("hex");
}

function counterFor(eventType) {
  if (eventType === EVENT_TYPES.impression) return "impressions";
  if (eventType === EVENT_TYPES.click) return "clicks";
  if (eventType === EVENT_TYPES.detailView) return "detailViews";
  return null;
}

function safeMetadata(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const result = {};
  for (const key of ["position", "surfaceVersion", "sessionWindow"]) {
    if (typeof value[key] === "string" && value[key].length <= 80) result[key] = value[key];
  }
  return result;
}

async function ingestPromotionEvent({db, authUid = null, data = {}, now = new Date()}) {
  const eventType = asString(data.eventType, "eventType").toUpperCase();
  if (!CLIENT_EVENT_TYPES.has(eventType)) throw new Error("Event type is not client-ingestible");
  const campaignId = asString(data.campaignId, "campaignId");
  const targetType = asString(data.targetType, "targetType").toUpperCase();
  const targetId = asString(data.targetId, "targetId", {max: 512, allowSlash: true});
  const placement = asString(data.placement, "placement");
  const sessionId = asString(data.sessionId, "sessionId", {optional: true, max: 160});
  if (!authUid && !sessionId) throw new Error("Authentication or sessionId is required");
  if (Object.prototype.hasOwnProperty.call(data, "revenue") ||
      Object.prototype.hasOwnProperty.call(data, "spend") ||
      Object.prototype.hasOwnProperty.call(data, "amount")) {
    throw new Error("Financial values are server-authoritative");
  }

  const nowTimestamp = asTimestamp(now, "now");
  const occurredAt = asTimestamp(data.occurredAt || nowTimestamp, "occurredAt");
  if (Math.abs(occurredAt.toMillis() - nowTimestamp.toMillis()) > MAX_OCCURRED_SKEW_MS) {
    throw new Error("Event timestamp is outside the accepted window");
  }

  const projectionRef = db.collection("promotion_active").doc(campaignId);
  const projectionSnap = await projectionRef.get();
  if (!projectionSnap.exists) throw new Error("Active promotion projection not found");
  const projection = projectionSnap.data() || {};
  if (projection.targetType !== targetType || projection.targetId !== targetId) {
    throw new Error("Promotion campaign target mismatch");
  }
  if (!isEnabledTarget(targetType, projection.sector)) throw new Error("Promotion target is not analytics-enabled");
  const expectedPlacement = placementFor(targetType, projection.sector);
  if (placement !== expectedPlacement) throw new Error("Promotion placement is invalid");
  const startsAt = projection.startsAt;
  const expiresAt = projection.expiresAt;
  if (!startsAt || !expiresAt || nowTimestamp.toMillis() < startsAt.toMillis() || nowTimestamp.toMillis() >= expiresAt.toMillis()) {
    throw new Error("Promotion is not active at event time");
  }
  const eventId = eventDedupeId({
    eventId: data.eventId,
    campaignId,
    targetId,
    eventType,
    placement,
    actorUid: authUid,
    sessionId,
  });
  const eventRef = db.collection(EVENT_COLLECTION).doc(eventId);
  const statsRef = db.collection(STATS_COLLECTION).doc(campaignId);
  const counter = counterFor(eventType);
  let duplicate = false;
  await db.runTransaction(async (tx) => {
    const existing = await tx.get(eventRef);
    if (existing.exists) {
      duplicate = true;
      return;
    }
    tx.create(eventRef, {
      eventId,
      eventType,
      source: "client",
      trust: "telemetry",
      campaignId,
      targetType,
      targetId,
      ownerUid: projection.ownerUid || null,
      businessId: projection.businessId || null,
      sector: projection.sector || null,
      placement,
      sessionId,
      actorUid: authUid || null,
      occurredAt,
      receivedAt: nowTimestamp,
      metadata: safeMetadata(data.metadata),
    });
    tx.set(statsRef, {
      campaignId,
      targetType,
      targetId,
      ownerUid: projection.ownerUid || null,
      businessId: projection.businessId || null,
      sector: projection.sector || null,
      [counter]: admin.firestore.FieldValue.increment(1),
      updatedAt: nowTimestamp,
    }, {merge: true});
  });
  return {accepted: !duplicate, duplicate, eventId, campaignId, eventType};
}

function revenueCapability(targetType, stats = {}) {
  if (targetType === "PET") return "not_applicable";
  return stats.financialMetricsStatus === "AVAILABLE" &&
      stats.revenueAttributionStatus === "server_attributed"
    ? "server_attributed"
    : "server_attribution_pending";
}

async function readPromotionCampaignStats({db, uid, campaignId}) {
  const normalizedUid = asString(uid, "uid");
  const id = asString(campaignId, "campaignId");
  const campaignSnap = await db.collection("promotion_campaigns").doc(id).get();
  if (!campaignSnap.exists) throw new Error("Promotion campaign not found");
  const campaign = campaignSnap.data() || {};
  if (campaign.ownerUid !== normalizedUid) throw new Error("Not authorized to read promotion campaign stats");
  const statsSnap = await db.collection(STATS_COLLECTION).doc(id).get();
  const stats = statsSnap.exists ? statsSnap.data() || {} : {};
  const impressions = Number(stats.impressions || 0);
  const clicks = Number(stats.clicks || 0);
  const detailViews = Number(stats.detailViews || 0);
  const attributedRevenue = Number(stats.attributedRevenue || 0);
  const refundedRevenue = Number(stats.refundedRevenue || 0);
  const spend = Number(campaign.price || 0);
  const capability = revenueCapability(campaign.targetType, stats);
  const financialMetricsStatus = campaign.targetType === "PET"
    ? "UNAVAILABLE"
    : stats.currencyMismatch === true
      ? "UNAVAILABLE"
    : stats.financialMetricsStatus || "PROVISIONAL";
  return {
    campaignId: id,
    targetType: campaign.targetType,
    targetId: campaign.targetId,
    sector: campaign.sector || null,
    impressions,
    clicks,
    detailViews,
    qualifiedConversions: Number(stats.qualifiedConversions || 0),
    financialConversions: Number(stats.financialConversions || 0),
    attributedRevenue,
    refundedRevenue,
    currency: campaign.currency || null,
    spend,
    pricingVersion: campaign.pricingVersion || null,
    planId: campaign.planId || null,
    durationHours: Number(campaign.durationHours || 0) || null,
    startsAt: campaign.startsAt || null,
    expiresAt: campaign.expiresAt || null,
    campaignStatus: campaign.status || null,
    updatedAt: stats.updatedAt || null,
    revenueCapability: capability,
    financialMetricsStatus,
    reconciliationStatus: stats.reconciliationStatus || "PENDING",
    lastReconciledAt: stats.lastReconciledAt || null,
    netAttributedRevenue: attributedRevenue,
    ctr: impressions > 0 ? clicks / impressions : null,
    conversionRate: clicks > 0 ? Number(stats.qualifiedConversions || 0) / clicks : null,
    roas: capability !== "server_attributed" || spend <= 0
      ? null
      : attributedRevenue / spend,
  };
}

module.exports = {
  EVENT_TYPES,
  PLACEMENTS,
  EVENT_COLLECTION,
  STATS_COLLECTION,
  ingestPromotionEvent,
  readPromotionCampaignStats,
  placementFor,
  isEnabledTarget,
};
