"use strict";

// Canonical business media finalization (functions/src/business/businessMedia.js).
//
// The whole point of this callable is that Firestore Rules cannot prove a
// Storage object's existence, namespace, type or size — so these tests drive
// the real implementation against fake db/storage doubles and assert the
// proofs it performs, plus the ordering guarantee that matters most: the old
// image is only deleted after the canonical transition commits.

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  finalizeBusinessMedia,
  deleteOwnedObjectQuietly,
  normalizeStoredMedia,
  BusinessMediaError,
  GALLERY_MAX_ITEMS,
} = require("../src/business/businessMedia");

const BUCKET = "test-bucket";
const OWNER = "owner-1";
const BIZ = "biz-1";

function logoPath(id = BIZ, stamp = 1000) {
  return `business_gallery/${id}/logo_${stamp}.jpg`;
}
function coverPath(id = BIZ, stamp = 1000) {
  return `business_cover/${id}/cover_${stamp}.jpg`;
}
function galleryPath(id = BIZ, stamp = 1000) {
  return `business_gallery/${id}/gallery_${stamp}.jpg`;
}

/** Minimal Firestore double with real transaction semantics for our usage. */
function makeDb(businesses) {
  const store = new Map(Object.entries(businesses));
  const api = {
    deleted: [],
    collection(name) {
      assert.equal(name, "businesses");
      return {
        doc(id) {
          return {
            id,
            get: async () => ({
              exists: store.has(id),
              data: () => (store.has(id) ? { ...store.get(id) } : undefined),
            }),
            __set(patch, options) {
              const prev = store.get(id) || {};
              store.set(id, options && options.merge ? { ...prev, ...patch } : { ...patch });
            },
          };
        },
      };
    },
    async runTransaction(fn) {
      return fn({
        get: async (ref) => ({
          exists: store.has(ref.id),
          data: () => (store.has(ref.id) ? { ...store.get(ref.id) } : undefined),
        }),
        set: (ref, patch, options) => ref.__set(patch, options),
      });
    },
    read(id) {
      return store.get(id);
    },
  };
  return api;
}

/** Minimal Storage double. `objects` maps objectPath -> metadata. */
function makeStorage(objects, { failDelete = false } = {}) {
  const deleted = [];
  const setMetadataCalls = [];
  return {
    deleted,
    setMetadataCalls,
    bucket(name) {
      assert.equal(name, BUCKET);
      return {
        name,
        file(path) {
          return {
            async getMetadata() {
              if (!objects[path]) {
                const err = new Error("not found");
                err.code = 404;
                throw err;
              }
              return [objects[path]];
            },
            async setMetadata(patch) {
              setMetadataCalls.push({ path, patch });
              objects[path] = {
                ...objects[path],
                metadata: { ...(objects[path].metadata || {}), ...(patch.metadata || {}) },
              };
            },
            async delete() {
              if (failDelete) throw new Error("delete failed");
              if (!objects[path]) throw new Error("missing");
              delete objects[path];
              deleted.push(path);
            },
          };
        },
      };
    },
  };
}

function imageMeta({ size = 1024, contentType = "image/jpeg", token = "tok-1" } = {}) {
  return {
    size: String(size),
    contentType,
    metadata: token ? { firebaseStorageDownloadTokens: token } : {},
  };
}

const baseBusiness = {
  ownerUid: OWNER,
  status: "approved",
  published: true,
  sectors: ["petshop"],
  marketplaceBusinessGenerationId: "gen-1",
};

function run(overrides = {}) {
  const {
    businesses = { [BIZ]: { ...baseBusiness } },
    objects = {},
    auth = { uid: OWNER },
    data,
    storageOptions,
  } = overrides;
  const db = makeDb(businesses);
  const storage = makeStorage(objects, storageOptions || {});
  return {
    db,
    storage,
    promise: finalizeBusinessMedia({
      db,
      storage,
      auth,
      data,
      bucketName: BUCKET,
      uuid: () => "generated-token",
      now: () => new Date("2026-09-03T12:00:00.000Z"),
    }),
  };
}

async function expectFailure(overrides, expectedCode) {
  const { promise } = run(overrides);
  await assert.rejects(
    promise,
    (error) => {
      assert.ok(error instanceof BusinessMediaError, `expected BusinessMediaError, got ${error}`);
      assert.equal(error.code, expectedCode);
      return true;
    }
  );
}

// ── authorization ──────────────────────────────────────────────────────────

test("26. unauthenticated calls are denied", async () => {
  await expectFailure(
    { auth: null, data: { businessId: BIZ, role: "logo", action: "set", objectPath: logoPath() } },
    "unauthenticated"
  );
});

test("27. a non-owner is denied", async () => {
  await expectFailure(
    {
      auth: { uid: "someone-else" },
      objects: { [logoPath()]: imageMeta() },
      data: { businessId: BIZ, role: "logo", action: "set", objectPath: logoPath() },
    },
    "permission-denied"
  );
});

test("28. a missing business is denied", async () => {
  await expectFailure(
    {
      businesses: {},
      data: { businessId: BIZ, role: "logo", action: "set", objectPath: logoPath() },
    },
    "not-found"
  );
});

test("29. malformed ownership fails closed", async () => {
  for (const ownerUid of [null, undefined, 12345, { uid: OWNER }, ["owner-1"], ""]) {
    await expectFailure(
      {
        businesses: { [BIZ]: { ...baseBusiness, ownerUid } },
        objects: { [logoPath()]: imageMeta() },
        data: { businessId: BIZ, role: "logo", action: "set", objectPath: logoPath() },
      },
      "permission-denied"
    );
  }
});

test("27b. a client-supplied ownerUid is never trusted", async () => {
  await expectFailure(
    {
      auth: { uid: "attacker" },
      objects: { [logoPath()]: imageMeta() },
      data: {
        businessId: BIZ,
        role: "logo",
        action: "set",
        objectPath: logoPath(),
        ownerUid: "attacker",
      },
    },
    "permission-denied"
  );
});

// ── object provenance ──────────────────────────────────────────────────────

test("30. an object outside this business's namespace is denied", async () => {
  for (const path of [
    "business_gallery/biz-2/logo_1000.jpg",
    "business_cover/biz-2/cover_1000.jpg",
    "products/biz-1/logo_1000.jpg",
    "compliance_docs/biz-1/logo_1000.jpg",
    "business_gallery/biz-1/nested/logo_1000.jpg",
    "business_gallery/biz-1x/logo_1000.jpg",
  ]) {
    await expectFailure(
      {
        objects: { [path]: imageMeta() },
        data: { businessId: BIZ, role: "logo", action: "set", objectPath: path },
      },
      "invalid-argument"
    );
  }
});

test("31. an arbitrary external URL is never accepted as a path", async () => {
  for (const path of [
    "https://evil.example.com/logo.jpg",
    "https://firebasestorage.googleapis.com/v0/b/other/o/x.jpg",
    "gs://other-bucket/business_gallery/biz-1/logo_1000.jpg",
    "//evil.example.com/x.jpg",
  ]) {
    await expectFailure(
      { data: { businessId: BIZ, role: "logo", action: "set", objectPath: path } },
      "invalid-argument"
    );
  }
});

test("32. a missing Storage object is denied", async () => {
  await expectFailure(
    { objects: {}, data: { businessId: BIZ, role: "logo", action: "set", objectPath: logoPath() } },
    "not-found"
  );
});

test("33. a disallowed content type is denied", async () => {
  for (const contentType of [
    "text/plain",
    "application/pdf",
    "image/svg+xml",
    "image/gif",
    "video/mp4",
    "application/octet-stream",
  ]) {
    await expectFailure(
      {
        objects: { [logoPath()]: imageMeta({ contentType }) },
        data: { businessId: BIZ, role: "logo", action: "set", objectPath: logoPath() },
      },
      "invalid-argument"
    );
  }
});

test("34. an oversized or empty object is denied", async () => {
  await expectFailure(
    {
      objects: { [logoPath()]: imageMeta({ size: 10 * 1024 * 1024 + 1 }) },
      data: { businessId: BIZ, role: "logo", action: "set", objectPath: logoPath() },
    },
    "invalid-argument"
  );
  await expectFailure(
    {
      objects: { [logoPath()]: imageMeta({ size: 0 }) },
      data: { businessId: BIZ, role: "logo", action: "set", objectPath: logoPath() },
    },
    "invalid-argument"
  );
});

test("35. role confusion between logo, cover and gallery is denied", async () => {
  // A real, owned, valid gallery object cannot be finalized as the logo.
  await expectFailure(
    {
      objects: { [galleryPath()]: imageMeta() },
      data: { businessId: BIZ, role: "logo", action: "set", objectPath: galleryPath() },
    },
    "invalid-argument"
  );
  // ...nor a logo object as a gallery entry, nor a cover object as a logo.
  await expectFailure(
    {
      objects: { [logoPath()]: imageMeta() },
      data: { businessId: BIZ, role: "gallery", action: "set", objectPath: logoPath() },
    },
    "invalid-argument"
  );
  await expectFailure(
    {
      objects: { [coverPath()]: imageMeta() },
      data: { businessId: BIZ, role: "logo", action: "set", objectPath: coverPath() },
    },
    "invalid-argument"
  );
});

test("36. a generation mismatch is denied", async () => {
  await expectFailure(
    {
      objects: { [logoPath()]: imageMeta() },
      data: {
        businessId: BIZ,
        role: "logo",
        action: "set",
        objectPath: logoPath(),
        expectedGenerationId: "gen-OLD",
      },
    },
    "failed-precondition"
  );
});

// ── happy paths ────────────────────────────────────────────────────────────

test("37. a valid logo is finalized and the URL is server-derived", async () => {
  const objects = { [logoPath()]: imageMeta({ token: "tok-abc" }) };
  const { db, promise } = run({
    objects,
    data: { businessId: BIZ, role: "logo", action: "set", objectPath: logoPath() },
  });
  const result = await promise;
  assert.equal(result.status, "ok");
  assert.equal(result.revision, 1);
  const stored = db.read(BIZ).businessMedia;
  assert.equal(stored.logo.path, logoPath());
  assert.equal(
    stored.logo.url,
    `https://firebasestorage.googleapis.com/v0/b/${BUCKET}` +
      `/o/${encodeURIComponent(logoPath())}?alt=media&token=tok-abc`
  );
  assert.equal(stored.logo.contentType, "image/jpeg");
  assert.equal(stored.generationId, "gen-1");
});

test("37b. an object without a download token gets one issued server-side", async () => {
  const objects = { [logoPath()]: imageMeta({ token: null }) };
  const { db, storage, promise } = run({
    objects,
    data: { businessId: BIZ, role: "logo", action: "set", objectPath: logoPath() },
  });
  await promise;
  assert.equal(storage.setMetadataCalls.length, 1);
  assert.match(db.read(BIZ).businessMedia.logo.url, /token=generated-token$/);
});

test("38. a valid cover is finalized", async () => {
  const objects = { [coverPath()]: imageMeta() };
  const { db, promise } = run({
    objects,
    data: { businessId: BIZ, role: "cover", action: "set", objectPath: coverPath() },
  });
  await promise;
  assert.equal(db.read(BIZ).businessMedia.cover.path, coverPath());
  assert.equal(db.read(BIZ).businessMedia.logo, null);
});

test("39. a valid gallery image is appended in order", async () => {
  const objects = {
    [galleryPath(BIZ, 1)]: imageMeta(),
    [galleryPath(BIZ, 2)]: imageMeta(),
  };
  const db = makeDb({ [BIZ]: { ...baseBusiness } });
  const storage = makeStorage(objects);
  const common = { db, storage, auth: { uid: OWNER }, bucketName: BUCKET, uuid: () => "t" };
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "gallery", action: "set", objectPath: galleryPath(BIZ, 1) },
  });
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "gallery", action: "set", objectPath: galleryPath(BIZ, 2) },
  });
  const gallery = db.read(BIZ).businessMedia.gallery;
  assert.deepEqual(
    gallery.map((g) => g.path),
    [galleryPath(BIZ, 1), galleryPath(BIZ, 2)]
  );
  assert.equal(db.read(BIZ).businessMedia.revision, 2);
});

test("40. the gallery cap is enforced", async () => {
  const objects = {};
  const existing = [];
  for (let i = 0; i < GALLERY_MAX_ITEMS; i++) {
    const p = galleryPath(BIZ, 100 + i);
    objects[p] = imageMeta();
    existing.push({ path: p, url: "https://firebasestorage.googleapis.com/v0/b/b/o/x", size: 1 });
  }
  const overflow = galleryPath(BIZ, 999);
  objects[overflow] = imageMeta();
  await expectFailure(
    {
      businesses: {
        [BIZ]: { ...baseBusiness, businessMedia: { gallery: existing, revision: 3 } },
      },
      objects,
      data: { businessId: BIZ, role: "gallery", action: "set", objectPath: overflow },
    },
    "failed-precondition"
  );
});

test("41. a duplicate gallery path does not create a second entry", async () => {
  const p = galleryPath();
  const objects = { [p]: imageMeta() };
  const db = makeDb({ [BIZ]: { ...baseBusiness } });
  const storage = makeStorage(objects);
  const common = { db, storage, auth: { uid: OWNER }, bucketName: BUCKET, uuid: () => "t" };
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "gallery", action: "set", objectPath: p },
  });
  const second = await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "gallery", action: "set", objectPath: p },
  });
  assert.equal(second.status, "unchanged");
  assert.equal(db.read(BIZ).businessMedia.gallery.length, 1);
});

test("42. removal clears the canonical reference and deletes only that object", async () => {
  const p = logoPath();
  const objects = { [p]: imageMeta(), [coverPath()]: imageMeta() };
  const db = makeDb({ [BIZ]: { ...baseBusiness } });
  const storage = makeStorage(objects);
  const common = { db, storage, auth: { uid: OWNER }, bucketName: BUCKET, uuid: () => "t" };
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "logo", action: "set", objectPath: p },
  });
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "logo", action: "remove" },
  });
  assert.equal(db.read(BIZ).businessMedia.logo, null);
  assert.deepEqual(storage.deleted, [p]);
  assert.ok(objects[coverPath()], "unrelated object untouched");
});

test("43. cleanup refuses a path outside this business's namespace", async () => {
  const foreign = "business_gallery/biz-2/logo_1.jpg";
  const objects = { [foreign]: imageMeta() };
  const storage = makeStorage(objects);
  const removed = await deleteOwnedObjectQuietly({
    storage,
    bucketName: BUCKET,
    businessId: BIZ,
    path: foreign,
  });
  assert.equal(removed, false);
  assert.ok(objects[foreign], "another business's object must survive");
  assert.deepEqual(storage.deleted, []);
});

test("44. retrying a completed operation is idempotent", async () => {
  const p = logoPath();
  const objects = { [p]: imageMeta() };
  const db = makeDb({ [BIZ]: { ...baseBusiness } });
  const storage = makeStorage(objects);
  const common = { db, storage, auth: { uid: OWNER }, bucketName: BUCKET, uuid: () => "t" };
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "logo", action: "set", objectPath: p },
  });
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "logo", action: "set", objectPath: p },
  });
  assert.equal(db.read(BIZ).businessMedia.logo.path, p);
  // The object was never deleted, because it did not replace itself.
  assert.deepEqual(storage.deleted, []);
  assert.ok(objects[p]);
});

test("45. a stale revision is rejected", async () => {
  const p = logoPath();
  await expectFailure(
    {
      businesses: { [BIZ]: { ...baseBusiness, businessMedia: { revision: 4, gallery: [] } } },
      objects: { [p]: imageMeta() },
      data: {
        businessId: BIZ,
        role: "logo",
        action: "set",
        objectPath: p,
        expectedRevision: 2,
      },
    },
    "failed-precondition"
  );
});

test("46. unrelated business fields are preserved exactly", async () => {
  const p = logoPath();
  const before = {
    ...baseBusiness,
    profile: { displayName: "Shop" },
    subscription: { plan: "gold" },
    marketplaceSellerActivation: { active: true },
    pilotActiveProductCount: 3,
    sectorData: { petshop: { shopName: "Shop" } },
  };
  const { db, promise } = run({
    businesses: { [BIZ]: before },
    objects: { [p]: imageMeta() },
    data: { businessId: BIZ, role: "logo", action: "set", objectPath: p },
  });
  await promise;
  const after = db.read(BIZ);
  for (const key of [
    "ownerUid",
    "status",
    "published",
    "sectors",
    "profile",
    "subscription",
    "marketplaceSellerActivation",
    "pilotActiveProductCount",
    "marketplaceBusinessGenerationId",
    "sectorData",
  ]) {
    assert.deepEqual(after[key], before[key], `${key} must be unchanged`);
  }
});

// ── ordering, concurrency and replacement ──────────────────────────────────

test("R1. replacement deletes the old object only after the commit", async () => {
  const first = logoPath(BIZ, 1);
  const second = logoPath(BIZ, 2);
  const objects = { [first]: imageMeta(), [second]: imageMeta() };
  const db = makeDb({ [BIZ]: { ...baseBusiness } });
  const storage = makeStorage(objects);
  const common = { db, storage, auth: { uid: OWNER }, bucketName: BUCKET, uuid: () => "t" };
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "logo", action: "set", objectPath: first },
  });
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "logo", action: "set", objectPath: second },
  });
  assert.equal(db.read(BIZ).businessMedia.logo.path, second);
  assert.deepEqual(storage.deleted, [first], "old object deleted after the new one committed");
});

test("R2. a failed finalization leaves the previous image usable", async () => {
  const good = logoPath(BIZ, 1);
  const objects = { [good]: imageMeta() };
  const db = makeDb({ [BIZ]: { ...baseBusiness } });
  const storage = makeStorage(objects);
  const common = { db, storage, auth: { uid: OWNER }, bucketName: BUCKET, uuid: () => "t" };
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "logo", action: "set", objectPath: good },
  });
  // A later attempt whose object never uploaded.
  await assert.rejects(
    finalizeBusinessMedia({
      ...common,
      data: { businessId: BIZ, role: "logo", action: "set", objectPath: logoPath(BIZ, 2) },
    })
  );
  assert.equal(db.read(BIZ).businessMedia.logo.path, good);
  assert.ok(objects[good], "the previous object is still present");
});

test("R3. a cleanup failure does not fail the committed transition", async () => {
  const first = logoPath(BIZ, 1);
  const second = logoPath(BIZ, 2);
  const objects = { [first]: imageMeta(), [second]: imageMeta() };
  const db = makeDb({ [BIZ]: { ...baseBusiness } });
  const storage = makeStorage(objects, { failDelete: true });
  const common = { db, storage, auth: { uid: OWNER }, bucketName: BUCKET, uuid: () => "t" };
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "logo", action: "set", objectPath: first },
  });
  const result = await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "logo", action: "set", objectPath: second },
  });
  assert.equal(result.status, "ok");
  assert.equal(db.read(BIZ).businessMedia.logo.path, second);
  // The orphan remains; it is a bounded storage cost, never a correctness bug.
  assert.ok(objects[first]);
});

test("R4. reorder preserves exactly the same set of images", async () => {
  const a = galleryPath(BIZ, 1);
  const b = galleryPath(BIZ, 2);
  const objects = { [a]: imageMeta(), [b]: imageMeta() };
  const db = makeDb({ [BIZ]: { ...baseBusiness } });
  const storage = makeStorage(objects);
  const common = { db, storage, auth: { uid: OWNER }, bucketName: BUCKET, uuid: () => "t" };
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "gallery", action: "set", objectPath: a },
  });
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "gallery", action: "set", objectPath: b },
  });
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "gallery", action: "reorder", order: [b, a] },
  });
  assert.deepEqual(
    db.read(BIZ).businessMedia.gallery.map((g) => g.path),
    [b, a]
  );
  assert.deepEqual(storage.deleted, [], "reorder never deletes");
});

test("R5. reorder rejects an injected or incomplete ordering", async () => {
  const a = galleryPath(BIZ, 1);
  const foreign = "business_gallery/biz-2/gallery_9.jpg";
  const objects = { [a]: imageMeta() };
  const db = makeDb({ [BIZ]: { ...baseBusiness } });
  const storage = makeStorage(objects);
  const common = { db, storage, auth: { uid: OWNER }, bucketName: BUCKET, uuid: () => "t" };
  await finalizeBusinessMedia({
    ...common,
    data: { businessId: BIZ, role: "gallery", action: "set", objectPath: a },
  });
  for (const order of [[foreign], [a, a], [], [a, foreign]]) {
    await assert.rejects(
      finalizeBusinessMedia({
        ...common,
        data: { businessId: BIZ, role: "gallery", action: "reorder", order },
      }),
      (e) => e instanceof BusinessMediaError
    );
  }
  assert.deepEqual(
    db.read(BIZ).businessMedia.gallery.map((g) => g.path),
    [a]
  );
});

test("R6. malformed stored media normalizes to a safe empty state", () => {
  for (const bad of [null, undefined, "x", 42, [], { gallery: "no" }]) {
    const n = normalizeStoredMedia(bad);
    assert.equal(n.logo, null);
    assert.equal(n.cover, null);
    assert.deepEqual(n.gallery, []);
    assert.equal(n.revision, 0);
  }
  const partial = normalizeStoredMedia({
    logo: { path: "p" }, // no url -> dropped
    cover: { path: "business_cover/biz-1/cover_1.jpg", url: "https://x/y" },
    gallery: [{ path: "a", url: "u" }, "nope", null, { url: "only" }],
    revision: -3,
  });
  assert.equal(partial.logo, null);
  assert.ok(partial.cover);
  assert.equal(partial.gallery.length, 1);
  assert.equal(partial.revision, 0);
});

test("R7. an unknown role or action is rejected before any read", async () => {
  for (const data of [
    { businessId: BIZ, role: "banner", action: "set", objectPath: logoPath() },
    { businessId: BIZ, role: "logo", action: "purge" },
    { businessId: BIZ, role: "logo", action: "reorder", order: [] },
    { businessId: "", role: "logo", action: "set", objectPath: logoPath() },
    { businessId: "a/b", role: "logo", action: "set", objectPath: logoPath() },
  ]) {
    await expectFailure({ data }, "invalid-argument");
  }
});
