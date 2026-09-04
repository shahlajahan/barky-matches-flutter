// Marketplace Revision 33 §A(5)/§B — the single authoritative cleanup
// primitive shared by manual product deletion and the business-deletion
// cascade.
//
// Why one primitive. Revision 33 frees a deterministic product ID
// (`${businessId}_${normalizedSku}`) by deleting the product document after
// its owned state is cleaned. Two callers need that: the seller/admin
// callable `deleteMarketplaceProduct`, and the business-deletion cascade.
// They must not drift, and one deployed callable must never invoke another
// over HTTP, so the shared logic lives here as a plain internal module both
// require directly.
//
// What this module deliberately does NOT do: it never approves, publishes,
// reactivates or classifies anything; it never deletes an order, receipt or
// financial record; and it never deletes a compliance document that other
// products may also rely on — only the target product's own link into it.
const admin = require("firebase-admin");

const { deriveEvidenceLinkId } = require("../compliance/complianceMatching");
const {
  PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS,
} = require("../compliance/complianceConstants");

/**
 * Raised when a product's compliance decision is structurally unusable.
 * Both callers fail closed on it: the manual callable maps it to its own
 * frozen `malformed_decision_state` HttpsError, and the cascade counts the
 * product as a failure and leaves its document in place (non-public).
 */
class MalformedDecisionStateError extends Error {
  constructor() {
    super("Decision state is malformed");
    this.name = "MalformedDecisionStateError";
  }
}

const BUSINESSES_COLLECTION = "businesses";
const PRODUCTS_SUBCOLLECTION = "products";
const DECISIONS_COLLECTION = "productComplianceDecisions";
const LINKS_COLLECTION = "productEvidenceLinks";
const PILOT_AUDIT_COLLECTION = "pilotProductApprovalAuditEvents";
const CLEANUP_AUDIT_COLLECTION = "marketplaceProductCleanupAuditEvents";

// Storage prefix products are uploaded under (add_product_page.dart's
// `_uploadMedia`). Nothing outside this prefix is ever deletable by this
// module, regardless of what a product document claims.
const PRODUCT_MEDIA_PREFIX = "products_raw";
const FIREBASE_STORAGE_HOST = "firebasestorage.googleapis.com";

const CLEANUP_SOURCE = Object.freeze({
  MANUAL_DELETE: "manual_delete",
  BUSINESS_DELETION_CASCADE: "business_deletion_cascade",
});

const CLEANUP_OUTCOME = Object.freeze({
  DELETED: "deleted",
  ALREADY_ABSENT: "already_absent",
  SKIPPED_BUSINESS_MISMATCH: "skipped_business_mismatch",
  SKIPPED_GENERATION_MISMATCH: "skipped_generation_mismatch",
});

// Why a media reference was kept instead of deleted. Preserved references
// are recorded for admin remediation — never followed, never guessed at.
const MEDIA_PRESERVED_REASON = Object.freeze({
  NOT_A_STRING: "not_a_string",
  UNPARSEABLE_URL: "unparseable_url",
  FOREIGN_HOST: "foreign_host",
  FOREIGN_BUCKET: "foreign_bucket",
  UNEXPECTED_PATH: "unexpected_path",
  OTHER_BUSINESS_PREFIX: "other_business_prefix",
});

// Lazily required: pendingMediaCleanup.js imports this module for its own
// canonical media classifier, so a top-level require here would be circular.
function stagePendingMediaCleanup(args) {
  return require("./pendingMediaCleanup").stagePendingMediaCleanup(args);
}

function productRef(db, businessId, productId) {
  return db
    .collection(BUSINESSES_COLLECTION)
    .doc(businessId)
    .collection(PRODUCTS_SUBCOLLECTION)
    .doc(productId);
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.length > 0;
}

/**
 * Classifies one media URL as deletable or preserved.
 *
 * A product's `media` array is a seller-writable field, so a URL inside it
 * is client-supplied data, never deletion authority. A reference becomes
 * deletable only when the URL is a genuine Firebase Storage download URL,
 * for the expected bucket, whose decoded object path lies under this
 * business's own `products_raw/{businessId}/` prefix. Anything else —
 * external host, another bucket, another business's prefix, a malformed or
 * non-string value — is preserved and recorded, never followed.
 */
function classifyMediaReference({ url, businessId, bucketName }) {
  if (!isNonEmptyString(url)) {
    return { deletable: false, reason: MEDIA_PRESERVED_REASON.NOT_A_STRING };
  }
  let parsed;
  try {
    parsed = new URL(url);
  } catch (_) {
    return { deletable: false, reason: MEDIA_PRESERVED_REASON.UNPARSEABLE_URL };
  }
  if (parsed.host !== FIREBASE_STORAGE_HOST) {
    return { deletable: false, reason: MEDIA_PRESERVED_REASON.FOREIGN_HOST };
  }
  // Expected shape: /v0/b/{bucket}/o/{percent-encoded object path}
  const match = /^\/v0\/b\/([^/]+)\/o\/(.+)$/.exec(parsed.pathname);
  if (!match) {
    return { deletable: false, reason: MEDIA_PRESERVED_REASON.UNEXPECTED_PATH };
  }
  const [, urlBucket, encodedPath] = match;
  if (!isNonEmptyString(bucketName) || urlBucket !== bucketName) {
    return { deletable: false, reason: MEDIA_PRESERVED_REASON.FOREIGN_BUCKET };
  }
  let objectPath;
  try {
    objectPath = decodeURIComponent(encodedPath);
  } catch (_) {
    return { deletable: false, reason: MEDIA_PRESERVED_REASON.UNPARSEABLE_URL };
  }
  // Reject traversal and any path outside this business's own prefix.
  if (objectPath.includes("..")) {
    return { deletable: false, reason: MEDIA_PRESERVED_REASON.UNEXPECTED_PATH };
  }
  const expectedPrefix = `${PRODUCT_MEDIA_PREFIX}/${businessId}/`;
  if (!objectPath.startsWith(expectedPrefix)) {
    return {
      deletable: false,
      reason: objectPath.startsWith(`${PRODUCT_MEDIA_PREFIX}/`)
        ? MEDIA_PRESERVED_REASON.OTHER_BUSINESS_PREFIX
        : MEDIA_PRESERVED_REASON.UNEXPECTED_PATH,
    };
  }
  return { deletable: true, objectPath };
}

/**
 * Resolves every media reference on a product into deletable object paths
 * and preserved references. Pure: performs no I/O.
 */
function resolveProductMediaObjects({ product, businessId, bucketName }) {
  const deletable = [];
  const preserved = [];
  const seen = new Set();
  const media = product && Array.isArray(product.media) ? product.media : [];
  for (const entry of media) {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
      preserved.push({ reason: MEDIA_PRESERVED_REASON.NOT_A_STRING });
      continue;
    }
    for (const field of ["originalUrl", "playbackUrl", "thumbnailUrl"]) {
      const value = entry[field];
      if (value === undefined || value === null) continue;
      const verdict = classifyMediaReference({ url: value, businessId, bucketName });
      if (verdict.deletable) {
        if (!seen.has(verdict.objectPath)) {
          seen.add(verdict.objectPath);
          deletable.push(verdict.objectPath);
        }
      } else {
        preserved.push({ field, reason: verdict.reason });
      }
    }
  }
  return { deletable, preserved };
}

/**
 * Derives the evidence-link documents this product owns, failing closed on
 * any structural malformation.
 *
 * Ported unchanged in behaviour from `productDeletion.js`'s own
 * `deriveLinkRefsOrFailClosed` so the manual callable and the cascade share
 * one derivation and cannot drift: a decision belonging to another business,
 * a non-array or oversized ref list, a ref missing `documentId`/`scopeId`, a
 * duplicate `(documentId, scopeId)` pair, or an underivable link ID each
 * abort rather than delete an incomplete set.
 */
function deriveEvidenceLinkRefsOrFailClosed({ db, productId, businessId, decision }) {
  if (decision.businessId !== businessId) throw new MalformedDecisionStateError();
  const refs = decision.activeEvidenceRefs;
  if (!Array.isArray(refs)) throw new MalformedDecisionStateError();
  if (refs.length > PRODUCT_COMPLIANCE_DECISION_MAX_ACTIVE_EVIDENCE_REFS) {
    throw new MalformedDecisionStateError();
  }
  const seen = new Set();
  const refsToDelete = [];
  for (const ref of refs) {
    if (
      !ref ||
      typeof ref !== "object" ||
      typeof ref.documentId !== "string" ||
      ref.documentId.length === 0 ||
      typeof ref.scopeId !== "string" ||
      ref.scopeId.length === 0
    ) {
      throw new MalformedDecisionStateError();
    }
    const dedupeKey = `${ref.documentId}::${ref.scopeId}`;
    if (seen.has(dedupeKey)) throw new MalformedDecisionStateError();
    seen.add(dedupeKey);
    let linkId;
    try {
      linkId = deriveEvidenceLinkId({
        productId,
        documentId: ref.documentId,
        scopeId: ref.scopeId,
      });
    } catch (_) {
      throw new MalformedDecisionStateError();
    }
    refsToDelete.push(db.collection(LINKS_COLLECTION).doc(linkId));
  }
  return refsToDelete;
}

/**
 * The authoritative Firestore half of product cleanup.
 *
 * Runs in one transaction: proves ownership, removes the product's own
 * evidence links and compliance decision, settles pilot approval counters
 * and audit, deletes the product document (freeing the deterministic ID),
 * and writes a cleanup audit record. Returns the media references the
 * caller must then remove from Storage, which cannot join this transaction.
 *
 * `expectedGenerationId`:
 *   - a non-empty string  → the product's own `marketplaceBusinessGenerationId`
 *     must match exactly, else the product is SKIPPED, never deleted;
 *   - `null`              → generation verification is not applicable (the
 *     owning business carries no generation binding at all — legacy or
 *     pre-Revision-28 data). Recorded in the audit as unverified.
 * The value is always derived server-side; a client can never choose it.
 */
async function cleanupProductFirestoreState({
  db,
  tx,
  businessId,
  productId,
  expectedGenerationId,
  source,
  actorUid = null,
  bucketName = null,
  businessExists = false,
  now = admin.firestore.FieldValue.serverTimestamp(),
}) {
  const productDocRef = productRef(db, businessId, productId);
  const productSnap = await tx.get(productDocRef);
  if (!productSnap.exists) {
    return { outcome: CLEANUP_OUTCOME.ALREADY_ABSENT, media: { deletable: [], preserved: [] } };
  }
  const product = productSnap.data() || {};

  // Never delete a document merely because of where it sits. Ownership is
  // proven from the product's own canonical binding.
  if (product.businessId !== businessId) {
    return {
      outcome: CLEANUP_OUTCOME.SKIPPED_BUSINESS_MISMATCH,
      media: { deletable: [], preserved: [] },
    };
  }
  const generationVerified = isNonEmptyString(expectedGenerationId);
  if (generationVerified) {
    const bound = product.marketplaceBusinessGenerationId;
    if (!isNonEmptyString(bound) || bound !== expectedGenerationId) {
      return {
        outcome: CLEANUP_OUTCOME.SKIPPED_GENERATION_MISMATCH,
        media: { deletable: [], preserved: [] },
      };
    }
  }

  const decisionDocRef = db.collection(DECISIONS_COLLECTION).doc(productId);
  const decisionSnap = await tx.get(decisionDocRef);

  // Only this product's own links are removed. A shared compliance
  // document, and any scope other products also match, is left untouched:
  // the link is the product's edge into shared evidence, and only the edge
  // is cut.
  const linkRefs = decisionSnap.exists
    ? deriveEvidenceLinkRefsOrFailClosed({
        db,
        productId,
        businessId,
        decision: decisionSnap.data() || {},
      })
    : [];

  const pilotApproval = product.pilotProductApproval;
  const hadActivePilotApproval = Boolean(
    pilotApproval &&
      typeof pilotApproval === "object" &&
      !Array.isArray(pilotApproval) &&
      pilotApproval.active === true
  );

  const mediaPlan = resolveProductMediaObjects({ product, businessId, bucketName });

  // ---- writes (all reads above) ----
  for (const ref of linkRefs) tx.delete(ref);
  if (decisionSnap.exists) tx.delete(decisionDocRef);

  if (hadActivePilotApproval) {
    // `businessExists` is supplied by the caller rather than read here: the
    // manual path already proved existence with its ownership read, and the
    // cascade runs after the business document is gone. Avoiding a read
    // keeps the transaction inside its frozen ≤4-read budget on every path,
    // and `tx.update` on an absent document would throw at commit.
    if (businessExists) {
      tx.update(db.collection(BUSINESSES_COLLECTION).doc(businessId), {
        pilotActiveProductCount: admin.firestore.FieldValue.increment(-1),
      });
    }
    tx.create(db.collection(PILOT_AUDIT_COLLECTION).doc(), {
      businessId,
      productId,
      action: "cascade_revoke",
      adminUid: null,
      occurredAt: now,
      resultingActiveState: false,
      reasonCode: "pilot_revoked_business_deleted",
    });
  }

  tx.delete(productDocRef);

  // Revision 33 correction — durability. The exact canonical object paths are
  // persisted in THIS transaction, so the pending-cleanup record and the
  // product deletion commit together or not at all. Storage removal is then a
  // resumable job that never depends on the product document again; a crash
  // immediately after this commit loses nothing.
  const pendingCleanupId =
    mediaPlan.deletable.length > 0
      ? stagePendingMediaCleanup({
          db,
          tx,
          businessId,
          productId,
          expectedGenerationId: generationVerified ? expectedGenerationId : null,
          bucketName,
          objectPaths: mediaPlan.deletable,
          source,
        })
      : null;

  tx.create(db.collection(CLEANUP_AUDIT_COLLECTION).doc(), {
    businessId,
    productId,
    source,
    actorUid,
    expectedGenerationId: generationVerified ? expectedGenerationId : null,
    generationVerified,
    linksRemoved: linkRefs.length,
    decisionRemoved: decisionSnap.exists,
    hadActivePilotApproval,
    mediaDeletableCount: mediaPlan.deletable.length,
    pendingCleanupId,
    // Reasons only — never a URL, token or signed link.
    mediaPreservedReasons: mediaPlan.preserved.map((entry) => entry.reason),
    occurredAt: now,
  });

  return { outcome: CLEANUP_OUTCOME.DELETED, media: mediaPlan, pendingCleanupId };
}

/**
 * The Storage half. Firestore and Storage cannot share a transaction, so
 * this runs after the Firestore commit and is deliberately best-effort and
 * idempotent: an object already gone is a success, and a failure never
 * resurrects the product document. Leftover objects are reported so the
 * caller can record an admin-remediable condition.
 */
async function deleteProductMediaObjects({ storage, bucketName, objectPaths, logger = console }) {
  const deleted = [];
  const failed = [];
  if (!storage || !isNonEmptyString(bucketName)) {
    return { deleted, failed: objectPaths.map((p) => ({ objectPath: p, reason: "no_storage" })) };
  }
  const bucket = storage.bucket(bucketName);
  for (const objectPath of objectPaths) {
    try {
      await bucket.file(objectPath).delete({ ignoreNotFound: true });
      deleted.push(objectPath);
    } catch (error) {
      // Never log the object path with a token; the path itself is safe.
      logger.warn("marketplace_product_media_delete_failed", {
        code: (error && error.code) || "unknown",
      });
      failed.push({ objectPath, reason: "delete_failed" });
    }
  }
  return { deleted, failed };
}

module.exports = {
  cleanupProductFirestoreState,
  deriveEvidenceLinkRefsOrFailClosed,
  MalformedDecisionStateError,
  deleteProductMediaObjects,
  resolveProductMediaObjects,
  classifyMediaReference,
  CLEANUP_SOURCE,
  CLEANUP_OUTCOME,
  MEDIA_PRESERVED_REASON,
  PRODUCT_MEDIA_PREFIX,
  CLEANUP_AUDIT_COLLECTION,
};
