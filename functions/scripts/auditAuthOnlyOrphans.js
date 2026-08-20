"use strict";

/**
 * Safe, admin-only audit for Firebase Auth users missing a users/{uid}
 * Firestore profile (the class of bug fixed by ensureUserProfile — see
 * functions/user/ensureUserProfileCore.js and firestore.rules'
 * isLegacyIsPremiumFalseCreate()).
 *
 * DEFAULT MODE IS DRY RUN. It only reads Firebase Auth (paged) and reads
 * users/{uid} for each Auth user. It makes NO writes and prints NO tokens,
 * card data, or full email addresses.
 *
 * Usage:
 *   node scripts/auditAuthOnlyOrphans.js
 *     Dry run. Pages through all Auth users, reports orphans (Auth exists,
 *     users/{uid} does not), with counts by provider and by creation date
 *     (UTC day). Prints only: uid, provider ids, Auth creation time, and a
 *     redacted email (first character + domain, e.g. "s***@gmail.com").
 *
 *   node scripts/auditAuthOnlyOrphans.js --repair uid1,uid2,uid3
 *     Repair mode. ONLY provisions the exact uids explicitly listed —
 *     never a broad/bulk repair. Each uid must appear in the dry-run
 *     orphan list; anything else is refused. Uses the same trusted,
 *     idempotent ensureUserProfile() helper the production Cloud Function
 *     uses, so the created schema is identical and it never grants an
 *     entitlement or overwrites an existing document.
 *
 *   Repair mode additionally requires the environment variable
 *   AUDIT_ORPHAN_REPAIR_AUTHORIZED=yes to be set, as a separate explicit
 *   authorization step beyond just passing --repair — this script must
 *   never be capable of mutating production data via a single flag alone.
 *
 * This script does not execute repair mode by default and was not run in
 * repair mode as part of introducing it. Run the dry run only after code
 * review, and only if you have independently confirmed it performs no
 * writes.
 */

const admin = require("firebase-admin");
const { ensureUserProfile } = require("../user/ensureUserProfileCore");

function redactEmail(email) {
  if (!email) return "(no email)";
  const at = email.indexOf("@");
  if (at <= 0) return "(unparseable)";
  return `${email[0]}***${email.slice(at)}`;
}

function utcDay(isoString) {
  return String(isoString || "").slice(0, 10); // YYYY-MM-DD
}

async function listAllAuthUsers() {
  const users = [];
  let pageToken;
  do {
    const page = await admin.auth().listUsers(1000, pageToken);
    users.push(...page.users);
    pageToken = page.pageToken;
  } while (pageToken);
  return users;
}

async function findOrphans({ db }) {
  const authUsers = await listAllAuthUsers();
  const orphans = [];
  const providerCounts = {};
  const dateCounts = {};

  // Batch-read users/{uid} in chunks to avoid one request per user.
  const CHUNK = 300;
  for (let i = 0; i < authUsers.length; i += CHUNK) {
    const chunk = authUsers.slice(i, i + CHUNK);
    const refs = chunk.map((u) => db.collection("users").doc(u.uid));
    const snaps = await db.getAll(...refs);
    for (let j = 0; j < chunk.length; j += 1) {
      const authUser = chunk[j];
      const providerIds = (authUser.providerData || []).map(
        (p) => p.providerId
      );
      const day = utcDay(authUser.metadata.creationTime);
      if (!snaps[j].exists) {
        orphans.push({
          uid: authUser.uid,
          providerIds,
          creationTime: authUser.metadata.creationTime,
          emailRedacted: redactEmail(authUser.email),
        });
        for (const p of providerIds.length ? providerIds : ["(none)"]) {
          providerCounts[p] = (providerCounts[p] || 0) + 1;
        }
        dateCounts[day] = (dateCounts[day] || 0) + 1;
      }
    }
  }

  return {
    totalAuthUsers: authUsers.length,
    orphanCount: orphans.length,
    orphans,
    providerCounts,
    dateCounts,
  };
}

async function repairExplicitUids({ db, uids, knownOrphanUids }) {
  const results = [];
  for (const uid of uids) {
    if (!knownOrphanUids.has(uid)) {
      results.push({
        uid,
        skipped: true,
        reason: "not in the current dry-run orphan list — refusing to guess",
      });
      continue;
    }
    const authUser = await admin.auth().getUser(uid);
    const result = await ensureUserProfile({
      db,
      authUser,
      now: admin.firestore.FieldValue.serverTimestamp(),
      logger: console,
    });
    results.push({ uid, created: result.created });
  }
  return results;
}

async function main() {
  admin.initializeApp({ projectId: "barkymatches-new" });
  const db = admin.firestore();

  const args = process.argv.slice(2);
  const repairIndex = args.indexOf("--repair");
  const isRepairMode = repairIndex !== -1;

  console.log("=== Auth-only orphan audit (barkymatches-new) ===");
  console.log(`mode: ${isRepairMode ? "REPAIR (explicit allowlist only)" : "DRY RUN"}`);

  const report = await findOrphans({ db });

  console.log(`\nTotal Auth users scanned: ${report.totalAuthUsers}`);
  console.log(`Orphan Auth users (no users/{uid} profile): ${report.orphanCount}`);
  console.log("\nBy provider:");
  for (const [provider, count] of Object.entries(report.providerCounts)) {
    console.log(`  ${provider}: ${count}`);
  }
  console.log("\nBy creation date (UTC day):");
  for (const [day, count] of Object.entries(report.dateCounts).sort()) {
    console.log(`  ${day}: ${count}`);
  }
  console.log("\nOrphan detail (uid, providers, creation time, redacted email):");
  for (const o of report.orphans) {
    console.log(
      `  ${o.uid}  [${o.providerIds.join(",") || "none"}]  ${o.creationTime}  ${o.emailRedacted}`
    );
  }

  if (!isRepairMode) {
    console.log("\nDry run complete. No writes were made.");
    return;
  }

  if (process.env.AUDIT_ORPHAN_REPAIR_AUTHORIZED !== "yes") {
    console.log(
      "\nREPAIR REFUSED: set AUDIT_ORPHAN_REPAIR_AUTHORIZED=yes as a separate, " +
        "explicit authorization step in addition to --repair. No writes were made."
    );
    return;
  }

  const requestedUids = String(args[repairIndex + 1] || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);

  if (requestedUids.length === 0) {
    console.log("\nREPAIR REFUSED: --repair requires a comma-separated uid list. No writes were made.");
    return;
  }

  const knownOrphanUids = new Set(report.orphans.map((o) => o.uid));
  console.log(`\nRepairing ${requestedUids.length} explicitly-listed uid(s)...`);
  const results = await repairExplicitUids({
    db,
    uids: requestedUids,
    knownOrphanUids,
  });
  for (const r of results) {
    console.log(`  ${r.uid}: ${r.skipped ? `SKIPPED (${r.reason})` : `created=${r.created}`}`);
  }
}

module.exports = { findOrphans, repairExplicitUids, redactEmail, utcDay };

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("AUDIT FAILED:", error.message);
      process.exit(1);
    });
}
