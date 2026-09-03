"use strict";

// Canonical business media (logo / cover / gallery) — authoritative writer.
//
// WHY A CALLABLE AND NOT FIRESTORE RULES
// Firestore Rules can check the *shape* of a write, but they cannot reach
// across to Cloud Storage. They therefore cannot prove that a referenced
// object exists, that it lives in this business's namespace as an object
// rather than as a lookalike string, or that its content type and size are
// within the permitted envelope. Today a business owner can write any
// string — including an arbitrary external URL — into the legacy media
// fields (`profile.logoUrl`, `coverImageUrl`, `images`, ...), because
// `canOwnerUpdateBusinessDocument()` only denies a fixed list of
// server-owned keys. This module introduces a single canonical map,
// `businesses/{businessId}.businessMedia`, which firestore.rules adds to
// that server-owned deny list, so the ONLY writer is this Admin SDK path.
//
// The legacy fields are deliberately left alone: other sectors still write
// and read them, and the public Pet Shop surfaces keep them as a read-only
// display fallback. New writes go to `businessMedia` only.
//
// TRUST BOUNDARY
// Nothing about ownership, provenance or the resulting public URL is taken
// from the caller. `ownerUid` is re-read from the canonical business
// document; the object is verified against Cloud Storage; and the download
// URL is *derived by this function* from the verified object's own
// metadata. A client-supplied URL is never accepted, and a client-supplied
// path is only ever used after it is proven to match this business's own
// role-specific naming contract.

const CANONICAL_MEDIA_FIELD = "businessMedia";

const MEDIA_ROLES = Object.freeze(["logo", "cover", "gallery"]);

const GALLERY_MAX_ITEMS = 10;

// Mirrors storage.rules' hasAllowedBusinessImage(): the deployed rule is
// what actually gates the upload, and this is the server-side restatement
// of the same envelope. Kept deliberately identical — if these ever
// diverge, the stricter of the two wins and uploads fail closed.
const ALLOWED_CONTENT_TYPES = Object.freeze([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
]);

const MAX_OBJECT_BYTES = 10 * 1024 * 1024;

// Role -> exact object-path contract. The `videos/` subpath is deliberately
// unreachable here (no role maps to it), and logo/gallery are separated by
// a mandatory filename prefix even though they share a Storage namespace —
// without that prefix a caller could finalize a gallery object as the logo
// (role confusion). The trailing token is a millisecond timestamp, so a
// replacement never reuses an object name and no device or CDN can serve a
// stale image from a previously-cached URL.
const ROLE_PATH_PATTERNS = Object.freeze({
  logo: (businessId) =>
    new RegExp(`^business_gallery/${escapeForRegExp(businessId)}/logo_\\d{1,20}\\.jpg$`),
  gallery: (businessId) =>
    new RegExp(`^business_gallery/${escapeForRegExp(businessId)}/gallery_\\d{1,20}\\.jpg$`),
  cover: (businessId) =>
    new RegExp(`^business_cover/${escapeForRegExp(businessId)}/cover_\\d{1,20}\\.jpg$`),
});

function escapeForRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

class BusinessMediaError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
    this.name = "BusinessMediaError";
  }
}

function fail(code, message) {
  throw new BusinessMediaError(code, message);
}

function isPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function nonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

/**
 * Normalizes whatever is currently stored, so a malformed or hand-written
 * legacy value can never crash the writer or leak through. Anything that
 * is not exactly the expected shape is dropped rather than repaired.
 */
function normalizeStoredMedia(stored) {
  const safe = isPlainObject(stored) ? stored : {};
  return {
    logo: normalizeStoredItem(safe.logo),
    cover: normalizeStoredItem(safe.cover),
    gallery: Array.isArray(safe.gallery)
      ? safe.gallery.map(normalizeStoredItem).filter(Boolean).slice(0, GALLERY_MAX_ITEMS)
      : [],
    revision: Number.isInteger(safe.revision) && safe.revision >= 0 ? safe.revision : 0,
    generationId: nonEmptyString(safe.generationId) ? safe.generationId : null,
  };
}

function normalizeStoredItem(item) {
  if (!isPlainObject(item)) return null;
  if (!nonEmptyString(item.path) || !nonEmptyString(item.url)) return null;
  return {
    path: item.path,
    url: item.url,
    contentType: nonEmptyString(item.contentType) ? item.contentType : null,
    size: Number.isFinite(item.size) ? item.size : null,
    updatedAt: item.updatedAt ?? null,
  };
}

/**
 * Verifies the uploaded object really exists in this project's bucket, in
 * this business's namespace, with a permitted type and size — then derives
 * the public download URL from the object's own metadata.
 *
 * The download token is read from the object rather than accepted from the
 * caller. If Firebase has not assigned one (an Admin SDK upload, say), one
 * is generated here and written to the object's metadata, so the resulting
 * URL is always something this function established.
 */
async function verifyAndDescribeObject({ storage, bucketName, objectPath, role, businessId, uuid }) {
  const pattern = ROLE_PATH_PATTERNS[role](businessId);
  if (!pattern.test(objectPath)) {
    fail(
      "invalid-argument",
      "The object path does not match this business's contract for this media role."
    );
  }

  const bucket = storage.bucket(bucketName);
  const file = bucket.file(objectPath);

  let metadata;
  try {
    const [meta] = await file.getMetadata();
    metadata = meta;
  } catch (error) {
    fail("not-found", "The uploaded image could not be found.");
  }

  const contentType = metadata && metadata.contentType;
  if (!ALLOWED_CONTENT_TYPES.includes(contentType)) {
    fail("invalid-argument", "That image format is not supported.");
  }

  const size = Number(metadata && metadata.size);
  if (!Number.isFinite(size) || size <= 0) {
    fail("invalid-argument", "The uploaded image is empty.");
  }
  if (size > MAX_OBJECT_BYTES) {
    fail("invalid-argument", "The image is too large.");
  }

  let token = null;
  const declaredTokens =
    metadata && metadata.metadata && metadata.metadata.firebaseStorageDownloadTokens;
  if (nonEmptyString(declaredTokens)) {
    token = String(declaredTokens).split(",")[0].trim() || null;
  }
  if (!token) {
    token = uuid();
    await file.setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
  }

  return {
    path: objectPath,
    url:
      `https://firebasestorage.googleapis.com/v0/b/${bucketName}` +
      `/o/${encodeURIComponent(objectPath)}?alt=media&token=${token}`,
    contentType,
    size,
  };
}

/**
 * Deletes an object this function itself recorded as canonical.
 *
 * Deletion authority comes exclusively from the stored canonical path — never
 * from a caller-supplied URL or path — and the path is re-checked against this
 * business's role contract before the delete, so a stale or tampered stored
 * value can still never reach another business's namespace. Failures are
 * swallowed: the canonical transition has already committed, and a leftover
 * object is a bounded storage cost, never a correctness or security problem.
 */
async function deleteOwnedObjectQuietly({ storage, bucketName, businessId, path, logger }) {
  if (!nonEmptyString(path)) return false;
  const matchesSomeRole = MEDIA_ROLES.some((role) =>
    ROLE_PATH_PATTERNS[role](businessId).test(path)
  );
  if (!matchesSomeRole) {
    if (logger) logger.warn("businessMedia: refusing to delete out-of-contract object path");
    return false;
  }
  try {
    await storage.bucket(bucketName).file(path).delete();
    return true;
  } catch (error) {
    if (logger) logger.warn("businessMedia: orphaned object left in place after cleanup failure");
    return false;
  }
}

/**
 * The single authoritative entry point.
 *
 * Every mutation is expressed as: verify caller -> verify object -> commit a
 * transaction that re-checks ownership, generation and revision -> only then
 * delete whatever object the transition replaced. The old image therefore
 * stays usable if anything before the commit fails.
 */
async function finalizeBusinessMedia({
  db,
  storage,
  auth,
  data,
  bucketName,
  uuid,
  now = () => new Date(),
  logger = null,
}) {
  if (!auth || !nonEmptyString(auth.uid)) {
    fail("unauthenticated", "You must be signed in.");
  }
  if (!isPlainObject(data)) {
    fail("invalid-argument", "Malformed request.");
  }

  const businessId = data.businessId;
  if (!nonEmptyString(businessId) || businessId.includes("/")) {
    fail("invalid-argument", "Malformed request.");
  }

  const role = data.role;
  if (!MEDIA_ROLES.includes(role)) {
    fail("invalid-argument", "Malformed request.");
  }

  const action = data.action;
  if (action !== "set" && action !== "remove" && action !== "reorder") {
    fail("invalid-argument", "Malformed request.");
  }
  if (action === "reorder" && role !== "gallery") {
    fail("invalid-argument", "Malformed request.");
  }

  const businessRef = db.collection("businesses").doc(businessId);
  const snapshot = await businessRef.get();
  if (!snapshot.exists) {
    fail("not-found", "This business no longer exists.");
  }
  const business = snapshot.data() || {};

  // Ownership is re-derived from the canonical document. A caller-supplied
  // ownerUid is never read, and a non-string/absent ownerUid fails closed.
  if (!nonEmptyString(business.ownerUid) || business.ownerUid !== auth.uid) {
    fail("permission-denied", "You do not manage this business.");
  }

  const currentGenerationId = nonEmptyString(business.marketplaceBusinessGenerationId)
    ? business.marketplaceBusinessGenerationId
    : null;
  if (
    data.expectedGenerationId !== undefined &&
    data.expectedGenerationId !== null &&
    data.expectedGenerationId !== currentGenerationId
  ) {
    fail("failed-precondition", "This business changed. Reload and try again.");
  }

  const stored = normalizeStoredMedia(business[CANONICAL_MEDIA_FIELD]);
  if (
    data.expectedRevision !== undefined &&
    data.expectedRevision !== null &&
    data.expectedRevision !== stored.revision
  ) {
    fail("failed-precondition", "Someone else updated this media. Reload and try again.");
  }

  // Object verification happens before the transaction so a bad upload never
  // opens a transaction, and so the old canonical state is still intact when
  // we fail.
  let described = null;
  if (action === "set") {
    described = await verifyAndDescribeObject({
      storage,
      bucketName,
      objectPath: data.objectPath,
      role,
      businessId,
      uuid,
    });
    if (role === "gallery") {
      if (stored.gallery.some((item) => item.path === described.path)) {
        // Idempotent retry: the object is already canonical, so report success
        // without appending a duplicate entry.
        return { status: "unchanged", revision: stored.revision, media: stored };
      }
      if (stored.gallery.length >= GALLERY_MAX_ITEMS) {
        fail("failed-precondition", "Gallery is full.");
      }
    }
  }

  let removalPaths = [];
  let committed = null;

  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(businessRef);
    if (!fresh.exists) {
      fail("not-found", "This business no longer exists.");
    }
    const freshData = fresh.data() || {};
    if (!nonEmptyString(freshData.ownerUid) || freshData.ownerUid !== auth.uid) {
      fail("permission-denied", "You do not manage this business.");
    }
    const freshGeneration = nonEmptyString(freshData.marketplaceBusinessGenerationId)
      ? freshData.marketplaceBusinessGenerationId
      : null;
    if (freshGeneration !== currentGenerationId) {
      fail("failed-precondition", "This business changed. Reload and try again.");
    }

    const current = normalizeStoredMedia(freshData[CANONICAL_MEDIA_FIELD]);
    if (
      data.expectedRevision !== undefined &&
      data.expectedRevision !== null &&
      data.expectedRevision !== current.revision
    ) {
      fail("failed-precondition", "Someone else updated this media. Reload and try again.");
    }

    const timestamp = now().toISOString();
    const next = {
      logo: current.logo,
      cover: current.cover,
      gallery: [...current.gallery],
      revision: current.revision + 1,
      generationId: freshGeneration,
    };
    const replaced = [];

    if (action === "set" && (role === "logo" || role === "cover")) {
      if (current[role] && current[role].path !== described.path) {
        replaced.push(current[role].path);
      }
      next[role] = { ...described, updatedAt: timestamp };
    } else if (action === "set" && role === "gallery") {
      if (current.gallery.some((item) => item.path === described.path)) {
        fail("already-exists", "That photo is already in the gallery.");
      }
      if (current.gallery.length >= GALLERY_MAX_ITEMS) {
        fail("failed-precondition", "Gallery is full.");
      }
      next.gallery = [...current.gallery, { ...described, updatedAt: timestamp }];
    } else if (action === "remove" && (role === "logo" || role === "cover")) {
      if (!current[role]) {
        return; // Already absent: idempotent no-op, transaction writes nothing.
      }
      replaced.push(current[role].path);
      next[role] = null;
    } else if (action === "remove" && role === "gallery") {
      const targetPath = data.objectPath;
      if (!nonEmptyString(targetPath)) {
        fail("invalid-argument", "Malformed request.");
      }
      const match = current.gallery.find((item) => item.path === targetPath);
      if (!match) {
        return; // Already removed: idempotent no-op.
      }
      replaced.push(match.path);
      next.gallery = current.gallery.filter((item) => item.path !== targetPath);
    } else if (action === "reorder") {
      const order = Array.isArray(data.order) ? data.order : null;
      if (!order || order.length !== current.gallery.length) {
        fail("invalid-argument", "Malformed request.");
      }
      const seen = new Set();
      const reordered = [];
      for (const path of order) {
        if (!nonEmptyString(path) || seen.has(path)) {
          fail("invalid-argument", "Malformed request.");
        }
        seen.add(path);
        const item = current.gallery.find((entry) => entry.path === path);
        if (!item) {
          fail("failed-precondition", "This gallery changed. Reload and try again.");
        }
        reordered.push(item);
      }
      next.gallery = reordered;
    }

    // Only the canonical media field and the document's own updatedAt are
    // written. Status, published, sectors, ownerUid, seller activation,
    // generation id, products and subscription state are never part of this
    // update, and firestore.rules independently forbids a client from
    // writing any of them.
    tx.set(
      businessRef,
      { [CANONICAL_MEDIA_FIELD]: next, mediaUpdatedAt: timestamp },
      { merge: true }
    );

    removalPaths = replaced;
    committed = next;
  });

  if (!committed) {
    return { status: "unchanged", revision: stored.revision, media: stored };
  }

  // Strictly after a successful canonical transition.
  for (const path of removalPaths) {
    await deleteOwnedObjectQuietly({ storage, bucketName, businessId, path, logger });
  }

  return { status: "ok", revision: committed.revision, media: committed };
}

module.exports = {
  finalizeBusinessMedia,
  normalizeStoredMedia,
  verifyAndDescribeObject,
  deleteOwnedObjectQuietly,
  BusinessMediaError,
  CANONICAL_MEDIA_FIELD,
  MEDIA_ROLES,
  GALLERY_MAX_ITEMS,
  ALLOWED_CONTENT_TYPES,
  MAX_OBJECT_BYTES,
  ROLE_PATH_PATTERNS,
};
