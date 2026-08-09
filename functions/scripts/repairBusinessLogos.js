"use strict";

const admin = require("firebase-admin");
const {synchronizeBusinessPublicProjection} = require("../src/publicProjections");

const CONFIRMATION = "I_UNDERSTAND_BUSINESS_LOGO_REPAIR";

function parseArgs(argv) {
  const args = new Map();
  for (const arg of argv) {
    if (!arg.startsWith("--")) continue;
    const separator = arg.indexOf("=");
    args.set(
      separator < 0 ? arg.slice(2) : arg.slice(2, separator),
      separator < 0 ? true : arg.slice(separator + 1),
    );
  }
  return args;
}

function projectIdFromEnvironment() {
  try {
    const config = process.env.FIREBASE_CONFIG
      ? JSON.parse(process.env.FIREBASE_CONFIG)
      : {};
    return config.projectId || process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || null;
  } catch (_) {
    throw new Error("FIREBASE_CONFIG must be valid JSON");
  }
}

function requireProject(args) {
  const expected = String(args.get("project") || "").trim();
  const actual = projectIdFromEnvironment();
  if (!expected) throw new Error("--project=PROJECT_ID is required");
  if (!actual) throw new Error("Firebase project identity is unavailable");
  if (expected !== actual) throw new Error(`Project mismatch: expected ${expected}, got ${actual}`);
  return actual;
}

function parseBusinessIds(args) {
  const raw = String(args.get("business-id") || "").trim();
  const ids = raw.split(",").map((value) => value.trim()).filter(Boolean);
  if (ids.length === 0) throw new Error("--business-id=BUSINESS_ID is required");
  return [...new Set(ids)];
}

function parseAction(args) {
  const clear = args.get("clear") === true;
  const setUrl = String(args.get("set-logo-url") || "").trim();
  if ((clear ? 1 : 0) + (setUrl ? 1 : 0) !== 1) {
    throw new Error("Choose exactly one of --clear or --set-logo-url=HTTPS_URL");
  }
  if (setUrl && !/^https:\/\//i.test(setUrl)) {
    throw new Error("--set-logo-url must be an HTTPS URL");
  }
  return clear ? {type: "clear", logoUrl: null} : {type: "set", logoUrl: setUrl};
}

async function inspectBusiness({db, businessId, action}) {
  const ref = db.collection("businesses").doc(businessId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error(`Business not found: ${businessId}`);
  const data = snap.data() || {};
  const current = data.sectorData?.veterinary?.profileContent?.clinicLogoUrl ?? null;
  return {
    businessId,
    currentLogoPresent: Boolean(String(current || "").trim()),
    action: action.type,
    replacementLogoPresent: Boolean(action.logoUrl),
  };
}

async function applyRepair({db, businessId, action}) {
  const ref = db.collection("businesses").doc(businessId);
  const snap = await ref.get();
  if (!snap.exists) throw new Error(`Business not found: ${businessId}`);
  const data = snap.data() || {};
  const sectorData = {...(data.sectorData || {})};
  const veterinary = {...(sectorData.veterinary || {})};
  const profileContent = {...(veterinary.profileContent || {})};
  profileContent.clinicLogoUrl = action.logoUrl;
  veterinary.profileContent = profileContent;
  sectorData.veterinary = veterinary;
  await ref.update({sectorData});

  const after = await ref.get();
  await synchronizeBusinessPublicProjection(
    {params: {businessId}, data: {after}},
    db,
  );
  return {businessId, repaired: true, action: action.type};
}

async function main(argv = process.argv.slice(2)) {
  const args = parseArgs(argv);
  const projectId = requireProject(args);
  const businessIds = parseBusinessIds(args);
  const action = parseAction(args);
  const apply = args.get("apply") === true;
  if (apply && process.env.BUSINESS_LOGO_REPAIR_CONFIRMATION !== CONFIRMATION) {
    throw new Error(`Set BUSINESS_LOGO_REPAIR_CONFIRMATION=${CONFIRMATION} for --apply`);
  }
  if (!admin.apps.length) admin.initializeApp({projectId});
  const db = admin.firestore();
  const inspected = [];
  for (const businessId of businessIds) inspected.push(await inspectBusiness({db, businessId, action}));
  const repaired = [];
  if (apply) {
    for (const businessId of businessIds) repaired.push(await applyRepair({db, businessId, action}));
  }
  const result = {projectId, apply, action: action.type, businessIds, inspected, repaired};
  console.log(JSON.stringify(result, null, 2));
  return result;
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message || String(error));
    process.exitCode = 1;
  });
}

module.exports = {main, parseArgs, parseAction, requireProject};
