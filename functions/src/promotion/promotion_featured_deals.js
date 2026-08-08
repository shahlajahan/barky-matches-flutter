"use strict";

const crypto = require("crypto");
const admin = require("firebase-admin");

const {parseCanonicalServiceTargetId} = require("./promotion_engine");

const MAX_CANDIDATES = 100;
const MAX_FEATURED_DEALS = 6;
const ROTATION_SLOT_SECONDS = 20;
const ENABLED_SECTORS = new Set(["VET", "GROOMER"]);

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = new Date(value).getTime();
  return Number.isFinite(parsed) ? parsed : null;
}

function isEligibleServiceProjection(projection, nowMs) {
  if (!projection || projection.targetType !== "SERVICE") return false;
  if (projection.featuredDealEligible !== true) return false;
  if (!ENABLED_SECTORS.has(String(projection.sector || "").toUpperCase())) return false;
  const target = parseCanonicalServiceTargetId(projection.targetId);
  if (!target || target.sector !== String(projection.sector).toUpperCase()) return false;
  const startsAt = timestampMillis(projection.startsAt);
  const expiresAt = timestampMillis(projection.expiresAt);
  return startsAt !== null && expiresAt !== null && startsAt <= nowMs && nowMs < expiresAt;
}

function rotationSlot(nowMs) {
  return Math.floor(nowMs / (ROTATION_SLOT_SECONDS * 1000));
}

function rotationCursor(slot) {
  const digest = crypto.createHash("sha256").update(`featured:${slot}`).digest("hex");
  return `promotion_${digest.slice(0, 40)}`;
}

function fairRank(slot, campaignId) {
  return crypto.createHash("sha256")
    .update(`${slot}:${campaignId}`)
    .digest("hex");
}

function selectFeaturedServiceDeals(projections, {slot, limit = MAX_FEATURED_DEALS} = {}) {
  // Equivalent campaigns are ranked by a hash of campaign identity and the
  // rotating server slot. This avoids newest/alphabetical/rating priority and
  // makes the same slot deterministic while changing exposure across slots.
  const boundedLimit = Math.min(MAX_FEATURED_DEALS, Math.max(1, Number(limit) || MAX_FEATURED_DEALS));
  return [...projections]
    .filter((projection) => projection && projection.campaignId)
    .sort((a, b) => {
      const rank = fairRank(slot, a.campaignId).localeCompare(fairRank(slot, b.campaignId));
      return rank || String(a.campaignId).localeCompare(String(b.campaignId));
    })
    .slice(0, boundedLimit);
}

async function readRotationWindow(baseQuery, cursor, limit = MAX_CANDIDATES) {
  const boundedLimit = Math.max(1, Number(limit) || MAX_CANDIDATES);
  const startSnapshot = await baseQuery.startAt(cursor).limit(boundedLimit).get();
  const startDocs = [...startSnapshot.docs];
  if (startDocs.length >= boundedLimit) return startDocs;

  // Complete the window by wrapping to the beginning of the same ordered
  // query. This makes every campaign equally reachable without scanning the
  // collection: each slot examines at most `boundedLimit` projections.
  const prefixSnapshot = await baseQuery
    .endBefore(cursor)
    .limit(boundedLimit - startDocs.length)
    .get();
  return [...startDocs, ...prefixSnapshot.docs].slice(0, boundedLimit);
}

function firstText(...values) {
  for (const value of values) {
    const text = value === undefined || value === null ? "" : String(value).trim();
    if (text) return text;
  }
  return "";
}

function serviceDisplayFields({business = {}, service = {}}) {
  const profile = business.profile && typeof business.profile === "object" ? business.profile : {};
  const contact = business.contact && typeof business.contact === "object" ? business.contact : {};
  const serviceTitle = firstText(service.title, service.name, service.serviceName, "Service");
  const businessName = firstText(profile.displayName, profile.businessName, business.businessName, business.name, "Business");
  const district = firstText(contact.district);
  const city = firstText(contact.city);
  return {
    businessName,
    serviceTitle,
    location: [district, city].filter(Boolean).join(", "),
    price: service.price ?? null,
    currency: service.currency || "TRY",
    logoUrl: firstText(profile.logoUrl, profile.coverUrl, business.logoUrl, business.coverImageUrl) || null,
  };
}

function isPublicBusiness(data = {}) {
  return data.status === "approved" &&
    data.published !== false &&
    data.isActive !== false &&
    data.isSuspended !== true &&
    data.suspended !== true;
}

async function readFeaturedServiceDeals({db, now = new Date(), limit = MAX_FEATURED_DEALS}) {
  const nowMs = timestampMillis(now);
  if (nowMs === null) throw new Error("Featured deal time is invalid");
  const slot = rotationSlot(nowMs);
  const cursor = rotationCursor(slot);
  const base = db.collection("promotion_active")
    .where("targetType", "==", "SERVICE")
    .where("featuredDealEligible", "==", true)
    .orderBy("campaignId");
  const docs = await readRotationWindow(base, cursor, MAX_CANDIDATES);

  const eligible = [];
  for (const doc of docs) {
    const projection = {campaignId: doc.id, ...(doc.data() || {})};
    if (!isEligibleServiceProjection(projection, nowMs)) continue;
    eligible.push({
      campaignId: projection.campaignId,
      targetType: "SERVICE",
      targetId: projection.targetId,
      sector: projection.sector,
      businessId: projection.businessId,
      serviceId: projection.serviceId,
      serviceTitle: projection.serviceTitle,
      businessName: projection.businessName,
      location: projection.location || "",
      price: projection.price ?? null,
      currency: projection.currency || "TRY",
      logoUrl: projection.logoUrl || null,
      publicLabel: projection.publicLabel || "Promoted",
      startsAt: projection.startsAt || null,
      expiresAt: projection.expiresAt || null,
    });
  }

  return {
    deals: selectFeaturedServiceDeals(eligible, {slot, limit}),
    bounded: true,
    candidateLimit: MAX_CANDIDATES,
    dealLimit: Math.min(MAX_FEATURED_DEALS, Math.max(1, Number(limit) || MAX_FEATURED_DEALS)),
    rotationSlot: slot,
  };
}

async function synchronizeServicePromotionProjections({
  db,
  businessId,
  business,
  services = [],
}) {
  const normalizedBusinessId = String(businessId || "").trim();
  if (!normalizedBusinessId) return {updated: 0};
  const active = await db.collection("promotion_active")
    .where("businessId", "==", normalizedBusinessId)
    .get();
  if (active.empty) return {updated: 0};

  const servicesById = new Map(
    services.map((service) => [String(service.id || ""), service])
  );
  const batch = db.batch();
  let updated = 0;
  for (const doc of active.docs) {
    const projection = {campaignId: doc.id, ...(doc.data() || {})};
    if (projection.targetType !== "SERVICE") continue;
    const target = parseCanonicalServiceTargetId(projection.targetId);
    if (!target || target.businessId !== normalizedBusinessId) continue;
    const service = servicesById.get(target.serviceId);
    const eligible = Boolean(
      business &&
      isPublicBusiness(business) &&
      service &&
      service.isActive === true &&
      service.isHidden !== true &&
      service.moderationStatus !== "removed" &&
      service.published !== false &&
      (!service.businessId || String(service.businessId) === normalizedBusinessId)
    );
    const fields = eligible ? serviceDisplayFields({business, service}) : {};
    batch.update(doc.ref, {
      featuredDealEligible: eligible,
      ...fields,
      projectionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    updated += 1;
  }
  if (updated > 0) await batch.commit();
  return {updated};
}

module.exports = {
  MAX_CANDIDATES,
  MAX_FEATURED_DEALS,
  ROTATION_SLOT_SECONDS,
  isEligibleServiceProjection,
  rotationSlot,
  rotationCursor,
  readRotationWindow,
  selectFeaturedServiceDeals,
  readFeaturedServiceDeals,
  serviceDisplayFields,
  synchronizeServicePromotionProjections,
};
