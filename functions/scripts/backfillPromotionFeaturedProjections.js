"use strict";

const admin = require("firebase-admin");

const {
  isEligibleServiceTarget,
  serviceDisplayFields,
} = require("../src/promotion/promotion_featured_deals");
const {parseCanonicalServiceTargetId} = require("../src/promotion/promotion_engine");

const CONFIRMATION = "I_UNDERSTAND";
const DEFAULT_PAGE_SIZE = 200;
const MAX_PAGE_SIZE = 500;
const REQUIRED_DISPLAY_FIELDS = [
  "businessName",
  "serviceTitle",
  "serviceId",
  "location",
  "price",
  "currency",
  "logoUrl",
  "projectionUpdatedAt",
];

function projectIdFromEnvironment() {
  try {
    const config = process.env.FIREBASE_CONFIG ? JSON.parse(process.env.FIREBASE_CONFIG) : {};
    return config.projectId || process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || null;
  } catch (_) {
    throw new Error("FIREBASE_CONFIG must be valid JSON");
  }
}

function parseArgs(argv) {
  const args = new Map();
  for (const arg of argv) {
    if (!arg.startsWith("--")) continue;
    const separator = arg.indexOf("=");
    if (separator < 0) args.set(arg.slice(2), true);
    else args.set(arg.slice(2, separator), arg.slice(separator + 1));
  }
  return args;
}

function timestampMillis(value) {
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  const parsed = new Date(value).getTime();
  return Number.isFinite(parsed) ? parsed : null;
}

function isExpired(projection, nowMs) {
  const expiresAt = timestampMillis(projection.expiresAt);
  return expiresAt !== null && expiresAt <= nowMs;
}

function hasCompleteProjection(projection) {
  if (typeof projection.featuredDealEligible !== "boolean") return false;
  return REQUIRED_DISPLAY_FIELDS.every((field) =>
    Object.prototype.hasOwnProperty.call(projection, field)
  );
}

function projectionMatches(projection, fields) {
  return Object.entries(fields).every(([field, value]) => {
    if (field === "projectionUpdatedAt") return true;
    return projection[field] === value;
  });
}

function projectIdOrThrow(args) {
  const expectedProjectId = String(args.get("project") || "").trim();
  if (!expectedProjectId) throw new Error("--project=PROJECT_ID is required");
  const actualProjectId = projectIdFromEnvironment();
  if (!actualProjectId) throw new Error("Firebase project identity is unavailable");
  if (actualProjectId !== expectedProjectId) {
    throw new Error(`Project mismatch: expected ${expectedProjectId}, got ${actualProjectId}`);
  }
  return actualProjectId;
}

function emptyResult({projectId, apply, pageSize, startAfter}) {
  return {
    projectId,
    apply,
    pageSize,
    startAfter: startAfter || null,
    scanned: 0,
    eligible: 0,
    updated: 0,
    unchanged: 0,
    invalidated: 0,
    expired: 0,
    skipped: 0,
    failed: 0,
    missingFeaturedDealEligible: 0,
    missingDisplayMetadata: 0,
  };
}

async function backfillPromotionFeaturedProjections({
  db,
  projectId,
  apply = false,
  pageSize = DEFAULT_PAGE_SIZE,
  startAfter = null,
  now = new Date(),
}) {
  const boundedPageSize = Math.min(MAX_PAGE_SIZE, Math.max(1, Number(pageSize) || DEFAULT_PAGE_SIZE));
  const result = emptyResult({projectId, apply, pageSize: boundedPageSize, startAfter});
  const nowMs = timestampMillis(now);
  if (nowMs === null) throw new Error("Backfill time is invalid");

  let query = db.collection("promotion_active")
    .where("targetType", "==", "SERVICE")
    .orderBy("campaignId")
    .limit(boundedPageSize);
  if (startAfter) query = query.startAfter(String(startAfter));
  const snapshot = await query.get();
  result.scanned = snapshot.size;
  result.nextStartAfter = snapshot.empty ? null : snapshot.docs[snapshot.docs.length - 1].id;

  const candidates = [];
  for (const doc of snapshot.docs) {
    const projection = {campaignId: doc.id, ...(doc.data() || {})};
    if (typeof projection.featuredDealEligible !== "boolean") {
      result.missingFeaturedDealEligible += 1;
    }
    if (REQUIRED_DISPLAY_FIELDS.some((field) =>
      !Object.prototype.hasOwnProperty.call(projection, field))) {
      result.missingDisplayMetadata += 1;
    }
    if (isExpired(projection, nowMs)) {
      result.expired += 1;
      continue;
    }
    candidates.push({doc, projection});
  }

  const byBusiness = new Map();
  for (const candidate of candidates) {
    const target = parseCanonicalServiceTargetId(candidate.projection.targetId);
    const businessId = target?.businessId || null;
    if (!businessId) {
      candidate.invalid = true;
      continue;
    }
    if (!byBusiness.has(businessId)) byBusiness.set(businessId, []);
    byBusiness.get(businessId).push({...candidate, target});
  }

  const updates = [];
  for (const [businessId, businessCandidates] of byBusiness.entries()) {
    try {
      const businessSnap = await db.collection("businesses").doc(businessId).get();
      const servicesSnap = businessSnap.exists
        ? await db.collection("businesses").doc(businessId).collection("services").get()
        : {docs: []};
      const services = new Map(servicesSnap.docs.map((doc) => [doc.id, doc.data() || {}]));
      const business = businessSnap.exists ? businessSnap.data() || {} : null;
      for (const candidate of businessCandidates) {
        const service = services.get(candidate.target.serviceId);
        const eligible = isEligibleServiceTarget({business, service, businessId});
        const displayFields = eligible
          ? {...serviceDisplayFields({business, service}), serviceId: candidate.target.serviceId}
          : {};
        const desiredFields = {featuredDealEligible: eligible, ...displayFields};
        if (eligible) result.eligible += 1;
        else result.invalidated += 1;
        if (projectionMatches(candidate.projection, desiredFields)) {
          result.unchanged += 1;
          continue;
        }
        updates.push({
          ref: candidate.doc.ref,
          fields: {
            ...desiredFields,
            projectionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          eligible,
        });
      }
    } catch (error) {
      result.failed += businessCandidates.length;
      console.error(JSON.stringify({
        event: "promotion_projection_backfill_business_failed",
        businessId,
        reason: error.message || String(error),
      }));
    }
  }

  for (const candidate of candidates.filter((item) => item.invalid)) {
    result.invalidated += 1;
    if (candidate.projection.featuredDealEligible === false) {
      result.unchanged += 1;
      continue;
    }
    updates.push({
      ref: candidate.doc.ref,
      fields: {
        featuredDealEligible: false,
        projectionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      eligible: false,
    });
  }

  result.skipped = candidates.length - updates.length - result.failed;

  if (apply && updates.length > 0) {
    const batch = db.batch();
    for (const update of updates) batch.update(update.ref, update.fields);
    await batch.commit();
    result.updated = updates.length;
  }
  if (!apply) result.updated = 0;
  return result;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const apply = args.get("apply") === true;
  const projectId = projectIdOrThrow(args);
  if (apply && process.env.PROMOTION_PROJECTION_BACKFILL_CONFIRM !== CONFIRMATION) {
    throw new Error(`Apply requires PROMOTION_PROJECTION_BACKFILL_CONFIRM=${CONFIRMATION}`);
  }
  if (!admin.apps.length) admin.initializeApp({projectId});
  const result = await backfillPromotionFeaturedProjections({
    db: admin.firestore(),
    projectId,
    apply,
    pageSize: args.get("page-size") || DEFAULT_PAGE_SIZE,
    startAfter: args.get("start-after") || null,
  });
  console.log(JSON.stringify(result, null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = {
  backfillPromotionFeaturedProjections,
  hasCompleteProjection,
  isExpired,
  parseArgs,
};
