const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const {
  canonicalSectors,
  normalizeSector,
  isPetTaxiBusiness,
} = require("../src/businessSectorMembership");
const {
  hasInvalidPetTaxiContamination,
  needsPublishedBackfill,
  plannedPublishedValue,
} = require("../src/businessPublication");

const SUPPORTED_PUBLIC_SECTORS = new Set([
  "vet",
  "groomy",
  "pet_shop",
  "pet_hotel",
  "adoption_center",
  "training",
  "pet_taxi",
]);

function parseArgs(argv) {
  const args = {};
  for (const value of argv) {
    if (!value.startsWith("--")) continue;
    const [key, ...rest] = value.slice(2).split("=");
    args[key] = rest.join("=") || true;
  }
  return args;
}

function encodeBackupValue(value) {
  if (value instanceof admin.firestore.Timestamp) {
    return {
      __type: "timestamp",
      seconds: value.seconds,
      nanoseconds: value.nanoseconds,
    };
  }
  if (value instanceof admin.firestore.GeoPoint) {
    return {
      __type: "geopoint",
      latitude: value.latitude,
      longitude: value.longitude,
    };
  }
  if (value instanceof admin.firestore.DocumentReference) {
    return { __type: "reference", path: value.path };
  }
  if (Array.isArray(value)) return value.map(encodeBackupValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, child]) => [key, encodeBackupValue(child)])
    );
  }
  return value;
}

function classifyBusiness(doc, database) {
  const data = doc.data() || {};
  const rawSectors = Array.isArray(data.sectors) ? data.sectors : [];
  const normalizedSectors = rawSectors
    .map(normalizeSector)
    .filter(Boolean);
  const sectorsValid = rawSectors.length > 0 &&
    rawSectors.every((sector) => normalizeSector(sector) != null) &&
    normalizedSectors.every((sector) => SUPPORTED_PUBLIC_SECTORS.has(sector));

  if (!needsPublishedBackfill(data)) return null;

  const publicRef = database.collection("businesses_public").doc(doc.id);
  const contaminationCleanupRequired = hasInvalidPetTaxiContamination(data);

  return {
    id: doc.id,
    name: data.profile?.displayName || data.profile?.businessName || data.name || null,
    sectors: rawSectors,
    normalizedSectors: [...canonicalSectors(rawSectors)],
    currentStatus: data.status,
    currentPublished: Object.prototype.hasOwnProperty.call(data, "published")
      ? data.published
      : "<missing>",
    plannedPublished: sectorsValid ? plannedPublishedValue(data) : null,
    publicPath: publicRef.path,
    contaminationCleanupRequired,
    sectorsValid,
    manualReviewReason: sectorsValid
      ? null
      : "invalid_or_missing_canonical_sectors",
    data,
    publicRef,
  };
}

function backupPath(args) {
  if (typeof args["backup-file"] !== "string") {
    throw new Error("--apply requires --backup-file=/path/to/backup.json");
  }
  return path.resolve(args["backup-file"]);
}

async function run({
  argv = process.argv.slice(2),
  database,
  synchronizeProjection,
} = {}) {
  const args = parseArgs(argv);
  const apply = args.apply === true;
  const db = database || admin.firestore();
  const snapshot = await db.collection("businesses").get();
  const candidates = [];
  const skipped = [];

  for (const doc of snapshot.docs) {
    const candidate = classifyBusiness(doc, db);
    if (!candidate) continue;
    const publicSnap = await candidate.publicRef.get();
    candidate.publicExists = publicSnap.exists;
    if (candidate.manualReviewReason) {
      skipped.push(candidate);
      continue;
    }
    candidates.push(candidate);
  }

  const toReport = (candidate) => ({
    id: candidate.id,
    name: candidate.name,
    sectors: candidate.sectors,
    currentStatus: candidate.currentStatus,
    currentPublished: candidate.currentPublished,
    plannedPublished: candidate.plannedPublished,
    publicExists: candidate.publicExists,
    publicPath: candidate.publicPath,
    contaminationCleanupRequired: candidate.contaminationCleanupRequired,
    sectorsValid: candidate.sectorsValid,
    manualReviewReason: candidate.manualReviewReason,
  });
  const report = candidates.map(toReport);
  const skippedReport = skipped.map(toReport);

  console.log(JSON.stringify({
    mode: apply ? "apply" : "dry-run",
    candidateCount: candidates.length,
    skippedCount: skipped.length,
    candidates: report,
    skipped: skippedReport,
  }, null, 2));

  const invalid = candidates.filter((candidate) =>
    candidate.plannedPublished == null ||
    candidate.contaminationCleanupRequired
  );
  if (apply && invalid.length > 0) {
    throw new Error(
      `Refusing to apply: ${invalid.length} candidate(s) require manual review or contamination cleanup.`
    );
  }
  if (!apply) {
    return {
      mode: "dry-run",
      candidateCount: candidates.length,
      report,
      skipped: skippedReport,
    };
  }

  const destination = backupPath(args);
  if (fs.existsSync(destination)) {
    throw new Error(`Refusing to overwrite existing backup: ${destination}`);
  }
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, JSON.stringify({
    createdAt: new Date().toISOString(),
    documents: candidates.map((candidate) => ({
      id: candidate.id,
      path: `businesses/${candidate.id}`,
      data: encodeBackupValue(candidate.data),
    })),
  }, null, 2));

  for (const candidate of candidates) {
    await db.collection("businesses").doc(candidate.id).update({
      published: candidate.plannedPublished,
    });
  }

  const resynchronize = synchronizeProjection ||
    require("../src/publicProjections").synchronizeBusinessPublicProjection;
  for (const candidate of candidates) {
    const after = await db.collection("businesses").doc(candidate.id).get();
    await resynchronize({
      params: { businessId: candidate.id },
      data: { after },
    }, db);
  }

  return {
    mode: "apply",
    candidateCount: candidates.length,
    backupFile: destination,
    report,
    skipped: skippedReport,
  };
}

if (require.main === module) {
  if (!admin.apps.length) admin.initializeApp();
  run().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = {
  classifyBusiness,
  encodeBackupValue,
  parseArgs,
  run,
};
