"use strict";

const admin = require("firebase-admin");
const {
  PAYOUT_INDEX_COLLECTION,
  buildPayoutIndexId,
  normalizePayoutIndexRecord,
  projectPayoutIndex,
} = require("../payout/payoutIndex");
const { PAYOUT_SECTOR_ADAPTERS } = require("../payout/sectorAdapters");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

function args(argv) {
  const result = { dryRun: false, pageSize: 100, resume: {} };
  for (let i = 2; i < argv.length; i += 1) {
    const value = argv[i];
    if (value === "--dry-run") result.dryRun = true;
    else if (value === "--page-size") result.pageSize = Math.max(1, Number(argv[++i] || 100));
    else if (value === "--resume") result.resume = JSON.parse(argv[++i] || "{}");
  }
  return result;
}

async function run(options = args(process.argv)) {
  const businessCache = new Map();
  const report = {
    dryRun: options.dryRun === true,
    perSector: {},
    totals: {
      created: 0,
      updated: 0,
      skipped: 0,
      invalid: 0,
      failed: 0,
      ambiguousPaymentTimestamp: 0,
      waiting: 0,
      eligible: 0,
      blocked: 0,
      reasonCounts: {},
      samples: [],
    },
    resume: {},
  };

  for (const adapter of Object.values(PAYOUT_SECTOR_ADAPTERS)) {
    const sectorReport = {
      created: 0,
      updated: 0,
      skipped: 0,
      invalid: 0,
      failed: 0,
      ambiguousPaymentTimestamp: 0,
      waiting: 0,
      eligible: 0,
      blocked: 0,
      reasonCounts: {},
      samples: [],
    };
    report.perSector[adapter.sector] = sectorReport;
    let query = db.collection(adapter.collection).orderBy(admin.firestore.FieldPath.documentId()).limit(options.pageSize);
    const resumeId = options.resume?.[adapter.sector];
    if (resumeId) query = query.startAfter(resumeId);

    while (true) {
      const snap = await query.get();
      if (snap.empty) break;
      for (const doc of snap.docs) {
        const indexId = buildPayoutIndexId(adapter.collection, doc.id);
        try {
          const record = doc.data() || {};
          const businessId = adapter.getBusinessId(record);
          let businessData = null;
          if (businessId) {
            const key = String(businessId);
            if (!businessCache.has(key)) {
              const businessSnap = await db.collection("businesses").doc(key).get();
              businessCache.set(
                key,
                businessSnap.exists ? businessSnap.data() || {} : null
              );
            }
            businessData = businessCache.get(key);
          }
          const projection = normalizePayoutIndexRecord({
            sourceCollection: adapter.collection,
            sourceDocumentId: doc.id,
            record,
            business: businessData,
          });
          if (!projection.successfulPaymentAt) {
            sectorReport.ambiguousPaymentTimestamp += 1;
          }
          if (projection.eligibilityStatus === "waiting_period") {
            sectorReport.waiting += 1;
          } else if (projection.eligibilityStatus === "eligible") {
            sectorReport.eligible += 1;
          } else if (
            ["blocked", "on_hold", "reversed", "cancelled"].includes(
              projection.eligibilityStatus
            )
          ) {
            sectorReport.blocked += 1;
          }
          if (options.dryRun) {
            sectorReport.skipped += 1;
          } else {
            const indexRef = db.collection(PAYOUT_INDEX_COLLECTION).doc(indexId);
            const existing = await indexRef.get();
            await projectPayoutIndex({
              db,
              sourceCollection: adapter.collection,
              sourceDocumentId: doc.id,
              record,
            });
            sectorReport[existing.exists ? "updated" : "created"] += 1;
          }
        } catch (error) {
          const code = String(error.code || "UNEXPECTED_ERROR");
          const expectedInvalid =
            code.startsWith("INVALID_") ||
            code.startsWith("MISSING_") ||
            code.startsWith("UNSUPPORTED_") ||
            code === "ZERO_PAYOUT_AMOUNT";
          if (expectedInvalid) sectorReport.invalid += 1;
          else sectorReport.failed += 1;
          sectorReport.reasonCounts[code] =
            Number(sectorReport.reasonCounts[code] || 0) + 1;
          if (sectorReport.samples.length < 20) {
            sectorReport.samples.push({
              sourceDocumentId: doc.id,
              code,
              message: String(error.message || "").slice(0, 240),
            });
          }
        }
        report.resume[adapter.sector] = doc.id;
      }
      if (snap.size < options.pageSize) break;
      query = db.collection(adapter.collection)
        .orderBy(admin.firestore.FieldPath.documentId())
        .startAfter(snap.docs[snap.docs.length - 1])
        .limit(options.pageSize);
    }
    for (const key of Object.keys(report.totals)) {
      if (typeof report.totals[key] === "number") {
        report.totals[key] += sectorReport[key];
      }
    }
    for (const [code, count] of Object.entries(sectorReport.reasonCounts)) {
      report.totals.reasonCounts[code] =
        Number(report.totals.reasonCounts[code] || 0) + count;
    }
    report.totals.samples.push(
      ...sectorReport.samples.slice(0, Math.max(0, 20 - report.totals.samples.length))
    );
  }
  return report;
}

if (require.main === module) {
  run().then((report) => {
    console.log(JSON.stringify(report, null, 2));
  }).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = { run };
