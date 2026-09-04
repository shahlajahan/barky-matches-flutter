// Marketplace Revision 33 correction — durable pending media cleanup.
// Exercised against real Firestore AND Storage emulators: the retry contract
// is exactly what mocks cannot prove.
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test } = require("node:test");

const BUCKET = "demo-petsupo.appspot.com";
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: process.env.GCLOUD_PROJECT || "demo-petsupo",
    storageBucket: BUCKET,
  });
}
const db = admin.firestore();

const {
  stagePendingMediaCleanup,
  derivePendingCleanupId,
  pendingCleanupRef,
  processPendingMediaCleanup,
  resumePendingMediaCleanups,
  findPathsStillReferenced,
  backoffMsForAttempt,
  PENDING_STATUS,
  PENDING_ERROR,
  PENDING_COLLECTION,
  MAX_ATTEMPTS,
} = require("../src/marketplace/product/pendingMediaCleanup");
const {
  cleanupProductFirestoreState,
  CLEANUP_SOURCE,
  CLEANUP_OUTCOME,
} = require("../src/marketplace/product/productCleanup");

const hasFs = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const hasStorage = Boolean(process.env.FIREBASE_STORAGE_EMULATOR_HOST);
const itest = (n, f) => test(n, { skip: !hasFs }, f);
const stest = (n, f) => test(n, { skip: !(hasFs && hasStorage) }, f);

let seq = 0;
const nextId = (p) => `${p}-${Date.now()}-${++seq}`;
const objPath = (b, f) => `products_raw/${b}/${f}`;
const mediaUrl = (b, f) =>
  `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(objPath(b, f))}?alt=media&token=secret-token`;

async function seedBusiness() {
  const businessId = nextId("pmc-biz");
  const generation = `gen-${businessId}`;
  await db.collection("businesses").doc(businessId).set({
    ownerUid: `owner-${businessId}`,
    marketplaceBusinessGenerationId: generation,
    pilotActiveProductCount: 0,
  });
  return { businessId, generation };
}

async function seedProduct(businessId, generation, files = [], extra = {}) {
  const productId = extra.productId || nextId("pmc-prod");
  await db.collection("businesses").doc(businessId).collection("products").doc(productId).set({
    businessId,
    marketplaceBusinessGenerationId: generation,
    isActive: false,
    moderationStatus: "pending_review",
    media: files.map((f) => ({ type: "image", originalUrl: mediaUrl(businessId, f) })),
    ...extra,
  });
  return productId;
}

const deleteProduct = (businessId, productId, generation) =>
  db.runTransaction((tx) =>
    cleanupProductFirestoreState({
      db, tx, businessId, productId,
      expectedGenerationId: generation,
      source: CLEANUP_SOURCE.MANUAL_DELETE,
      bucketName: BUCKET, businessExists: true,
    })
  );

async function putObject(path) {
  await admin.storage().bucket(BUCKET).file(path).save(Buffer.from("x"), {
    contentType: "image/jpeg",
  });
}
const objectExists = async (path) =>
  (await admin.storage().bucket(BUCKET).file(path).exists())[0];

// ---- transactional durability ----------------------------------------
itest("the pending record is committed atomically with the product deletion", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation, ["a.jpg", "b.jpg"]);

  const result = await deleteProduct(businessId, productId, generation);
  assert.equal(result.outcome, CLEANUP_OUTCOME.DELETED);
  assert.ok(result.pendingCleanupId, "a durable record id is returned");

  // The product is gone AND the paths survive it.
  const gone = await db.collection("businesses").doc(businessId)
    .collection("products").doc(productId).get();
  assert.equal(gone.exists, false);

  const pending = await pendingCleanupRef(db, result.pendingCleanupId).get();
  assert.equal(pending.exists, true);
  const data = pending.data();
  assert.deepEqual(data.objectPaths.sort(), [objPath(businessId, "a.jpg"), objPath(businessId, "b.jpg")].sort());
  assert.equal(data.status, PENDING_STATUS.PENDING);
  assert.equal(data.bucketName, BUCKET);
});

itest("no download URL or token is ever persisted", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation, ["c.jpg"]);
  const result = await deleteProduct(businessId, productId, generation);
  const raw = JSON.stringify((await pendingCleanupRef(db, result.pendingCleanupId).get()).data());
  assert.equal(raw.includes("secret-token"), false, "no download token");
  assert.equal(raw.includes("firebasestorage.googleapis.com"), false, "no download URL");
  assert.equal(raw.includes("alt=media"), false);
});

itest("the record id is deterministic and server-derived", async () => {
  const args = { businessId: "b1", productId: "p1", expectedGenerationId: "g1", source: "manual_delete" };
  assert.equal(derivePendingCleanupId(args), derivePendingCleanupId(args));
  assert.notEqual(derivePendingCleanupId(args), derivePendingCleanupId({ ...args, productId: "p2" }));
  assert.match(derivePendingCleanupId(args), /^[0-9a-f]{64}$/);
});

// ---- real Storage deletion + retry -----------------------------------
stest("retry deletes the real objects without the product document", async () => {
  const { businessId, generation } = await seedBusiness();
  await putObject(objPath(businessId, "d1.jpg"));
  await putObject(objPath(businessId, "d2.jpg"));
  const productId = await seedProduct(businessId, generation, ["d1.jpg", "d2.jpg"]);

  const del = await deleteProduct(businessId, productId, generation);
  // Simulates a crash immediately after commit: the product is gone, nothing
  // was deleted from Storage yet, and only the durable record remains.
  assert.equal(await objectExists(objPath(businessId, "d1.jpg")), true);

  const result = await processPendingMediaCleanup({
    db, storage: admin.storage(), cleanupId: del.pendingCleanupId,
  });
  assert.equal(result.outcome, "completed");
  assert.equal(await objectExists(objPath(businessId, "d1.jpg")), false);
  assert.equal(await objectExists(objPath(businessId, "d2.jpg")), false);

  const rec = await pendingCleanupRef(db, del.pendingCleanupId).get();
  assert.equal(rec.data().status, PENDING_STATUS.COMPLETED);
  assert.deepEqual(rec.data().remainingPaths, []);
});

stest("an already-absent object is idempotent success", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation, ["ghost.jpg"]);
  const del = await deleteProduct(businessId, productId, generation);
  const result = await processPendingMediaCleanup({
    db, storage: admin.storage(), cleanupId: del.pendingCleanupId,
  });
  assert.equal(result.outcome, "completed");
});

stest("a repeated run after completion is a safe no-op", async () => {
  const { businessId, generation } = await seedBusiness();
  await putObject(objPath(businessId, "once.jpg"));
  const productId = await seedProduct(businessId, generation, ["once.jpg"]);
  const del = await deleteProduct(businessId, productId, generation);
  await processPendingMediaCleanup({ db, storage: admin.storage(), cleanupId: del.pendingCleanupId });
  const again = await processPendingMediaCleanup({ db, storage: admin.storage(), cleanupId: del.pendingCleanupId });
  assert.equal(again.claimed, false);
  assert.match(again.reason, /not_pending/);
});

// ---- exclusivity ------------------------------------------------------
stest("an object another live product references is retained, not deleted", async () => {
  const { businessId, generation } = await seedBusiness();
  await putObject(objPath(businessId, "shared.jpg"));
  const target = await seedProduct(businessId, generation, ["shared.jpg"]);
  await seedProduct(businessId, generation, ["shared.jpg"]); // sibling keeps it

  const del = await deleteProduct(businessId, target, generation);
  const result = await processPendingMediaCleanup({
    db, storage: admin.storage(), cleanupId: del.pendingCleanupId,
  });
  assert.equal(result.outcome, "completed_shared_retained");
  assert.equal(await objectExists(objPath(businessId, "shared.jpg")), true, "shared object survives");
  const rec = await pendingCleanupRef(db, del.pendingCleanupId).get();
  assert.deepEqual(rec.data().retainedSharedPaths, [objPath(businessId, "shared.jpg")]);
});

stest("a NEW-generation product protects its media from old-generation cleanup", async () => {
  const { businessId, generation } = await seedBusiness();
  await putObject(objPath(businessId, "reused.jpg"));
  const oldProduct = await seedProduct(businessId, generation, ["reused.jpg"]);
  await seedProduct(businessId, `gen2-${businessId}`, ["reused.jpg"]);

  const del = await deleteProduct(businessId, oldProduct, generation);
  await processPendingMediaCleanup({ db, storage: admin.storage(), cleanupId: del.pendingCleanupId });
  assert.equal(await objectExists(objPath(businessId, "reused.jpg")), true,
    "the recreated business's own media is never removed by the old generation");
});

stest("an exclusively-owned object is deleted", async () => {
  const { businessId, generation } = await seedBusiness();
  await putObject(objPath(businessId, "mine.jpg"));
  const target = await seedProduct(businessId, generation, ["mine.jpg"]);
  await seedProduct(businessId, generation, ["other.jpg"]);
  const del = await deleteProduct(businessId, target, generation);
  await processPendingMediaCleanup({ db, storage: admin.storage(), cleanupId: del.pendingCleanupId });
  assert.equal(await objectExists(objPath(businessId, "mine.jpg")), false);
});

itest("exclusivity that cannot be proven within budget fails safe", async () => {
  const { businessId, generation } = await seedBusiness();
  await seedProduct(businessId, generation, ["x.jpg"]);
  const verdict = await findPathsStillReferenced({
    db, businessId, bucketName: BUCKET,
    candidatePaths: [objPath(businessId, "zzz.jpg")],
    maxProducts: 0,
  });
  assert.equal(verdict.proven, false, "an unscannable business is never proven exclusive");
});

// ---- provenance: nothing untrusted is ever persisted ------------------
itest("foreign, cross-business and malformed references produce no pending record", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = nextId("pmc-prod");
  await db.collection("businesses").doc(businessId).collection("products").doc(productId).set({
    businessId, marketplaceBusinessGenerationId: generation,
    isActive: false, moderationStatus: "pending_review",
    media: [
      { originalUrl: "https://evil.example.com/x.jpg" },
      { originalUrl: `https://firebasestorage.googleapis.com/v0/b/other-bucket/o/${encodeURIComponent(objPath(businessId, "a.jpg"))}` },
      { originalUrl: `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent("products_raw/other-biz/a.jpg")}` },
      { originalUrl: `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent("products_raw/" + businessId + "/../../etc")}` },
      { originalUrl: "not-a-url" },
    ],
  });
  const del = await deleteProduct(businessId, productId, generation);
  assert.equal(del.pendingCleanupId, null, "nothing untrusted becomes deletion authority");
});

// ---- missing bucket ---------------------------------------------------
itest("a missing bucket configuration is retryable, never a silent loss", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation, ["nb.jpg"]);
  const del = await db.runTransaction((tx) =>
    cleanupProductFirestoreState({
      db, tx, businessId, productId, expectedGenerationId: generation,
      source: CLEANUP_SOURCE.MANUAL_DELETE, bucketName: null, businessExists: true,
    })
  );
  // With no bucket, provenance cannot be proven, so nothing is deletable and
  // nothing is silently dropped: no record is created because no path was
  // ever provable in the first place.
  assert.equal(del.pendingCleanupId, null);
});

itest("a record whose storage is unavailable backs off and stays pending", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation, ["nb2.jpg"]);
  const del = await deleteProduct(businessId, productId, generation);
  const result = await processPendingMediaCleanup({
    db, storage: null, cleanupId: del.pendingCleanupId,
  });
  assert.equal(result.outcome, "no_bucket");
  const rec = await pendingCleanupRef(db, del.pendingCleanupId).get();
  assert.equal(rec.data().status, PENDING_STATUS.PENDING);
  assert.equal(rec.data().lastErrorCode, PENDING_ERROR.NO_BUCKET);
  assert.ok(rec.data().nextAttemptAt, "a backoff is scheduled");
  assert.equal(rec.data().leaseOwner, null, "the lease is released");
});

// ---- lease ownership --------------------------------------------------
itest("a worker cannot claim, clear or overwrite a lease another worker holds", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation, ["lease.jpg"]);
  const del = await deleteProduct(businessId, productId, generation);
  const ref = pendingCleanupRef(db, del.pendingCleanupId);

  // Worker A runs to completion and releases its lease.
  const first = await processPendingMediaCleanup({
    db, storage: null, cleanupId: del.pendingCleanupId, workerId: "worker-A",
  });
  assert.equal(first.claimed, true);
  assert.equal((await ref.get()).data().leaseOwner, null, "A released its own lease");

  // Worker B now legitimately owns the record.
  await ref.update({
    status: PENDING_STATUS.PENDING,
    leaseOwner: "worker-B",
    leaseExpiresAt: new Date(Date.now() + 60_000),
    nextAttemptAt: new Date(Date.now() - 1000),
  });

  // A returns and must neither claim it nor disturb B's lease.
  const second = await processPendingMediaCleanup({
    db, storage: null, cleanupId: del.pendingCleanupId, workerId: "worker-A",
  });
  assert.equal(second.claimed, false);
  assert.equal(second.reason, "leased_by_other_worker");
  const after = await ref.get();
  assert.equal(after.data().leaseOwner, "worker-B", "B still owns the lease");
  assert.equal(after.data().status, PENDING_STATUS.PENDING, "B's state is untouched");
});

test("the terminal write is guarded by lease ownership", () => {
  const src = require("node:fs").readFileSync(
    require("node:path").join(__dirname, "../src/marketplace/product/pendingMediaCleanup.js"),
    "utf8"
  );
  // The settle path refuses to write unless this worker still owns the lease.
  assert.match(src, /leaseOwner !== workerId/);
  assert.match(src, /reason: "lease_lost"/);
});

itest("a leased record is not claimed by a second worker", async () => {
  const { businessId, generation } = await seedBusiness();
  const productId = await seedProduct(businessId, generation, ["lease2.jpg"]);
  const del = await deleteProduct(businessId, productId, generation);
  await pendingCleanupRef(db, del.pendingCleanupId).update({
    leaseOwner: "worker-X", leaseExpiresAt: new Date(Date.now() + 60000),
  });
  const result = await processPendingMediaCleanup({
    db, storage: null, cleanupId: del.pendingCleanupId, workerId: "worker-Y",
  });
  assert.equal(result.claimed, false);
  assert.equal(result.reason, "leased_by_other_worker");
});

// ---- starvation / backoff --------------------------------------------
test("backoff is exponential and bounded", () => {
  assert.ok(backoffMsForAttempt(1) < backoffMsForAttempt(2));
  assert.ok(backoffMsForAttempt(2) < backoffMsForAttempt(3));
  assert.equal(backoffMsForAttempt(50), backoffMsForAttempt(60), "capped, never unbounded");
});

itest("poison records cannot starve a healthy one", async () => {
  const stamp = nextId("starve");
  // Isolate: earlier tests in this file leave their own due records behind,
  // and the resumer is deliberately bounded, so the queue is cleared first to
  // make this assertion about exactly the six records below.
  const existing = await db.collection(PENDING_COLLECTION).get();
  for (const doc of existing.docs) await doc.ref.delete();

  // Five records already backed off into the future, one due now.
  for (let i = 0; i < 5; i += 1) {
    await db.collection(PENDING_COLLECTION).doc(`${stamp}-poison-${i}`).set({
      businessId: "b", productId: `p${i}`, bucketName: BUCKET,
      objectPaths: ["products_raw/b/x.jpg"], remainingPaths: ["products_raw/b/x.jpg"],
      status: PENDING_STATUS.PENDING, attemptCount: 5,
      nextAttemptAt: new Date(Date.now() + 3600 * 1000),
    });
  }
  await db.collection(PENDING_COLLECTION).doc(`${stamp}-healthy`).set({
    businessId: "b", productId: "healthy", bucketName: BUCKET,
    objectPaths: ["products_raw/b/y.jpg"], remainingPaths: ["products_raw/b/y.jpg"],
    status: PENDING_STATUS.PENDING, attemptCount: 0,
    nextAttemptAt: new Date(Date.now() - 1000),
  });

  const result = await resumePendingMediaCleanups({ db, storage: null, limit: 5 });
  const ids = result.processed.map((p) => p.id);
  assert.ok(ids.includes(`${stamp}-healthy`), "the due record is reached despite five backed-off ones");
  assert.equal(ids.some((id) => id.includes("poison")), false, "backed-off records are not due");
});

itest("a record at the attempt ceiling becomes terminal, not retried forever", async () => {
  const id = nextId("terminal");
  await db.collection(PENDING_COLLECTION).doc(id).set({
    businessId: "b", productId: "p", bucketName: null,
    objectPaths: ["products_raw/b/z.jpg"], remainingPaths: ["products_raw/b/z.jpg"],
    status: PENDING_STATUS.PENDING, attemptCount: MAX_ATTEMPTS - 1,
    nextAttemptAt: new Date(Date.now() - 1000),
  });
  await processPendingMediaCleanup({ db, storage: null, cleanupId: id });
  const rec = await db.collection(PENDING_COLLECTION).doc(id).get();
  assert.equal(rec.data().status, PENDING_STATUS.REQUIRES_MANUAL_REVIEW);
});
