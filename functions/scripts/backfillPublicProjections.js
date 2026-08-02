const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const {
  buildUserPublicProjection,
  buildBusinessPublicProjection,
  publicProjectionChanged,
  loadCanonicalServices,
  resolveServiceAuthority,
} = require("../src/publicProjections");

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

const PAGE_SIZE = 200;
const COLLECTIONS = {
  users: {
    source: "users",
    target: "users_public",
    builder: buildUserPublicProjection,
  },
  businesses: {
    source: "businesses",
    target: "businesses_public",
    builder: async (businessId, source, currentProjection, database) => {
      const canonicalServices = await loadCanonicalServices(database, businessId);
      const serviceAuthority = resolveServiceAuthority({
        event: { params: {} },
        currentProjection,
        canonicalServices,
        source,
      });
      return buildBusinessPublicProjection(
        businessId,
        source,
        serviceAuthority
      );
    },
  },
};

function parseArgs(argv) {
  const args = {};
  for (const value of argv) {
    if (!value.startsWith("--")) continue;
    const [key, ...rest] = value.slice(2).split("=");
    args[key] = rest.join("=") || true;
  }
  return args;
}

function checkpointPath(args) {
  return typeof args["checkpoint-file"] === "string"
    ? path.resolve(args["checkpoint-file"])
    : null;
}

function loadCheckpoint(file) {
  if (!file || !fs.existsSync(file)) return {};
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function saveCheckpoint(file, checkpoint) {
  if (!file) return;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temporary = `${file}.tmp`;
  fs.writeFileSync(temporary, JSON.stringify(checkpoint, null, 2));
  fs.renameSync(temporary, file);
}

function emptyStats() {
  return {
    scanned: 0,
    created: 0,
    updated: 0,
    skipped: 0,
    deletedOrphans: 0,
    failed: 0,
    resumeCursor: null,
  };
}

async function backfillCollection(name, options, checkpoint, database = db) {
  const config = COLLECTIONS[name];
  const stats = emptyStats();
  const collectionCheckpoint = checkpoint[name] || {};
  let cursor = collectionCheckpoint.cursor || options.resumeCursor || null;

  if (collectionCheckpoint.complete && !options.dryRun) {
    console.log(`${name}: already complete at cursor=${cursor || "<start>"}`);
    stats.resumeCursor = cursor;
    return stats;
  }

  while (true) {
    let query = database.collection(config.source)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = database.batch();
    let pendingOperations = 0;
    const pageLastId = snapshot.docs[snapshot.docs.length - 1].id;

    for (const doc of snapshot.docs) {
      stats.scanned += 1;
      let projection;
      try {
        const targetRef = database.collection(config.target).doc(doc.id);
        const target = await targetRef.get();
        projection = await config.builder(
          doc.id,
          doc.data() || {},
          target.exists ? target.data() || {} : null,
          database
        );

        if (projection == null) {
          if (target.exists) {
            stats.updated += 1;
            if (!options.dryRun) {
              batch.delete(targetRef);
              pendingOperations += 1;
            }
          } else {
            stats.skipped += 1;
          }
        } else if (!target.exists) {
          stats.created += 1;
          if (!options.dryRun) {
            batch.set(targetRef, projection);
            pendingOperations += 1;
          }
        } else if (publicProjectionChanged(target.data(), projection)) {
          stats.updated += 1;
          if (!options.dryRun) {
            batch.set(targetRef, projection);
            pendingOperations += 1;
          }
        } else {
          stats.skipped += 1;
        }
      } catch (error) {
        stats.failed += 1;
        console.error(`${name}: failed id=${doc.id}`, error);
        throw error;
      }
    }

    if (!options.dryRun && pendingOperations > 0) await batch.commit();
    cursor = pageLastId;
    stats.resumeCursor = cursor;
    checkpoint[name] = { cursor, complete: false };
    if (!options.dryRun) saveCheckpoint(options.checkpointFile, checkpoint);
    console.log(`${name}: scanned=${stats.scanned} cursor=${cursor}`);
  }

  stats.resumeCursor = cursor;
  checkpoint[name] = { cursor, complete: true };
  if (!options.dryRun) saveCheckpoint(options.checkpointFile, checkpoint);
  return stats;
}

async function cleanupOrphans(name, options, stats, database = db) {
  if (!options.cleanupOrphans) return;
  const config = COLLECTIONS[name];
  let cursor = null;

  while (true) {
    let query = database.collection(config.target)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = database.batch();
    let pendingOperations = 0;
    for (const targetDoc of snapshot.docs) {
      const sourceDoc = await database.collection(config.source).doc(targetDoc.id).get();
      const projection = sourceDoc.exists
        ? await config.builder(
            targetDoc.id,
            sourceDoc.data() || {},
            targetDoc.data() || {},
            database
          )
        : null;
      if (!sourceDoc.exists || projection == null) {
        stats.deletedOrphans += 1;
        if (!options.dryRun) {
          batch.delete(targetDoc.ref);
          pendingOperations += 1;
        }
      }
    }
    if (!options.dryRun && pendingOperations > 0) await batch.commit();
    cursor = snapshot.docs[snapshot.docs.length - 1].id;
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help === true) {
    console.log([
      "Usage: node scripts/backfillPublicProjections.js",
      "  --collection=all|users|businesses",
      "  --checkpoint-file=/path/checkpoint.json",
      "  --resume-cursor=DOCUMENT_ID (requires one collection)",
      "  --dry-run",
      "  --cleanup-orphans",
    ].join("\n"));
    return;
  }
  const selected = args.collection && args.collection !== "all"
    ? [args.collection]
    : Object.keys(COLLECTIONS);
  const invalid = selected.filter((name) => !COLLECTIONS[name]);
  if (invalid.length > 0) throw new Error(`Unknown collection: ${invalid.join(", ")}`);
  if (typeof args["resume-cursor"] === "string" && selected.length !== 1) {
    throw new Error("--resume-cursor requires --collection=users or --collection=businesses");
  }

  const options = {
    dryRun: args["dry-run"] === true,
    cleanupOrphans: args["cleanup-orphans"] === true,
    checkpointFile: checkpointPath(args),
    resumeCursor: typeof args["resume-cursor"] === "string"
      ? args["resume-cursor"]
      : null,
  };
  const checkpoint = loadCheckpoint(options.checkpointFile);
  const result = { options, collections: {} };

  for (const name of selected) {
    const stats = await backfillCollection(name, options, checkpoint, db);
    await cleanupOrphans(name, options, stats, db);
    result.collections[name] = stats;
  }

  console.log(JSON.stringify(result, null, 2));
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = {
  backfillCollection,
  cleanupOrphans,
  parseArgs,
};
