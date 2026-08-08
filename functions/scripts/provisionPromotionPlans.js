"use strict";

const admin = require("firebase-admin");

const PLAN_DEFINITIONS = Object.freeze([
  ["pet_24h_v1", "PET", 24, 29],
  ["pet_3d_v1", "PET", 72, 69],
  ["pet_7d_v1", "PET", 168, 129],
  ["product_24h_v1", "PRODUCT", 24, 39],
  ["product_3d_v1", "PRODUCT", 72, 89],
  ["product_7d_v1", "PRODUCT", 168, 169],
  ["service_24h_v1", "SERVICE", 24, 49],
  ["service_3d_v1", "SERVICE", 72, 119],
  ["service_7d_v1", "SERVICE", 168, 219],
  ["business_24h_v1", "BUSINESS", 24, 0],
  ["business_3d_v1", "BUSINESS", 72, 0],
  ["business_7d_v1", "BUSINESS", 168, 0],
]);

function buildPromotionPlans() {
  return PLAN_DEFINITIONS.map(([planId, targetType, durationHours, price], index) => ({
    planId,
    targetType,
    durationHours,
    price,
    currency: "TRY",
    pricingModel: "FIXED_DURATION",
    pricingVersion: 1,
    rankingLift: 40,
    enabled: targetType !== "BUSINESS",
    displayOrder: index,
    maxConcurrentPerOwner: 1,
    maxConcurrentPerBusiness: 1,
  }));
}

function validatePromotionPlans(plans) {
  const ids = new Set();
  for (const plan of plans) {
    if (ids.has(plan.planId)) throw new Error(`Duplicate Promotion plan ID: ${plan.planId}`);
    ids.add(plan.planId);
    if (!Number.isFinite(plan.price) || plan.price < 0) throw new Error(`Invalid price: ${plan.planId}`);
    if (plan.targetType === "BUSINESS" && plan.enabled) {
      throw new Error("BUSINESS Promotion plans must remain disabled");
    }
    if (plan.currency !== "TRY" || plan.pricingModel !== "FIXED_DURATION" || plan.pricingVersion !== 1) {
      throw new Error(`Invalid V1 commercial terms: ${plan.planId}`);
    }
  }
  return true;
}

function projectIdFromEnvironment() {
  try {
    const config = process.env.FIREBASE_CONFIG ? JSON.parse(process.env.FIREBASE_CONFIG) : {};
    return config.projectId || process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || null;
  } catch (_) {
    throw new Error("FIREBASE_CONFIG must be valid JSON");
  }
}

async function provisionPromotionPlans({db, apply = false, expectedProjectId = null}) {
  const plans = buildPromotionPlans();
  validatePromotionPlans(plans);
  const projectId = projectIdFromEnvironment();
  if (!projectId) throw new Error("A Firebase project ID is required");
  if (expectedProjectId && projectId !== expectedProjectId) {
    throw new Error(`Project mismatch: expected ${expectedProjectId}, got ${projectId}`);
  }
  const result = {projectId, apply, created: 0, unchanged: 0, mismatched: 0};
  for (const plan of plans) {
    const ref = db.collection("promotion_plans").doc(plan.planId);
    const snap = await ref.get();
    if (!snap.exists) {
      if (apply) await ref.create(plan);
      result.created += 1;
      continue;
    }
    const existing = snap.data() || {};
    const same = Object.keys(plan).every((key) => existing[key] === plan[key]);
    if (same) result.unchanged += 1;
    else result.mismatched += 1;
  }
  if (result.mismatched > 0) throw new Error("Existing Promotion plan differs; refusing overwrite");
  return result;
}

if (require.main === module) {
  const apply = process.argv.includes("--apply");
  const expectedProjectId = process.argv.find((arg) => arg.startsWith("--project="))?.split("=")[1] || null;
  if (apply && process.env.PROMOTION_PLAN_PROVISION_CONFIRM !== "I_UNDERSTAND") {
    throw new Error("Apply requires PROMOTION_PLAN_PROVISION_CONFIRM=I_UNDERSTAND");
  }
  if (!admin.apps.length) admin.initializeApp({projectId: projectIdFromEnvironment() || undefined});
  provisionPromotionPlans({db: admin.firestore(), apply, expectedProjectId})
    .then((result) => console.log(JSON.stringify(result, null, 2)))
    .catch((error) => {
      console.error(error.message);
      process.exitCode = 1;
    });
}

module.exports = {buildPromotionPlans, validatePromotionPlans, provisionPromotionPlans};
