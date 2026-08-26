"use strict";

// Petsupo Marketplace P1-A compliance foundation — Slice 4.5 (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §8/§10.1/§13.1/§16, Revision 11 corrections 55/56 and Revision 12
// corrections 57/58/59): `getMarketplaceProductList`/
// `getMarketplaceProductDetail` — the server-mediated, bounded, live-
// eligibility-aware public Marketplace catalog endpoints.
//
// Plain internal CommonJS module only — no onCall/onRequest/onSchedule
// registration here (functions/index.js owns the thin dormant wiring),
// no module-level mutable cache, no direct environment/project literal,
// no writes of any kind. Reuses the already-committed, unmodified
// `evaluateLiveProductEligibility` (complianceEligibilityEvaluator.js) as
// the single authoritative eligibility check — no `tx`/`productSnapshot`
// argument is ever supplied from this dormant, non-transactional path
// (§8/§10.1). Never calls `recomputeProductComplianceStatus` and never
// reads `productEvidenceLinks`/`complianceDocumentScopes` directly.
//
// Exported behind a single, shared, disabled-by-default feature flag
// (§10.1: "Slice 4.5 exports both callables behind a disabled-by-default
// feature flag" — singular, shared, mirroring
// `PRODUCT_MODERATION_REVIEW_ENABLED`'s own established convention). The
// flag is injected as a plain boolean `featureEnabled` parameter by the
// caller (`functions/index.js`), exactly like `reviewProductModeration`'s
// own `featureEnabled` injection — this module never reads
// `defineString`/`process.env` directly. Checked as the literal first
// line of both operations, before auth inspection, request validation,
// cursor decoding, any Firestore read, and any evaluator call.

const { HttpsError } = require("firebase-functions/v2/https");
const { FieldPath } = require("firebase-admin/firestore");
const {
  evaluateLiveProductEligibility,
} = require("../compliance/complianceEligibilityEvaluator");

const PRODUCTS_COLLECTION = "businesses";

// §10.1 "Slice 4.5 public product projection contract" / "public string/
// URL length bounds" — every exact numeric bound this module enforces,
// named once here rather than scattered as magic numbers.
const PAGE_SIZE_DEFAULT = 20;
const PAGE_SIZE_MIN = 1;
const PAGE_SIZE_MAX = 20;
const FETCH_LIMIT_MULTIPLIER = 3; // limit(pageSize * 3), <= 60
const EXAMINE_CAP_MULTIPLIER = 6; // pageSize * 6, <= 120
const MAX_FETCHES = 2;
const CURSOR_MAX_ENCODED_LENGTH = 256;
const CURSOR_VERSION = 1;

const LIST_REQUEST_ALLOWED_FIELDS = Object.freeze(["pageSize", "cursor"]);
const DETAIL_REQUEST_ALLOWED_FIELDS = Object.freeze(["businessId", "productId"]);

const STR_MAX = Object.freeze({
  businessId: 256,
  productId: 256,
  name: 200,
  category: 200,
  description: 5000,
  brand: 200,
  originCity: 200,
  businessName: 200,
  shippingMode: 64,
  shippingPayer: 64,
  deliveryType: 64,
  businessLogo: 2048,
});

const CARRIER_CODE_MAX_LENGTH = 64;
const CARRIER_CODE_MAX_COUNT = 50;
const MEDIA_TYPE_MAX_LENGTH = 64;
const MEDIA_URL_MAX_LENGTH = 2048;
const SOURCE_MEDIA_MAX_LENGTH = 20;
const LIST_MEDIA_CAP = 1;
const DETAIL_MEDIA_CAP = 20;
const CURRENCY_ALLOWED = Object.freeze(["TRY", "USD", "EUR"]);

// §10.1: `lastPath` must match exactly four path segments,
// `businesses/{non-empty businessId}/products/{non-empty productId}` — no
// leading/trailing slash, no empty segment, no control character.
const NESTED_PRODUCT_PATH_RE = /^businesses\/([^/\x00-\x1f]+)\/products\/([^/\x00-\x1f]+)$/;

function invalidRequest() {
  return new HttpsError("invalid-argument", "Invalid request");
}

function featureDisabled() {
  return new HttpsError("failed-precondition", "This feature is not yet enabled.");
}

function productDetailRef(db, businessId, productId) {
  return db.collection(PRODUCTS_COLLECTION).doc(businessId).collection("products").doc(productId);
}

// =====================================================================
// Request validation
// =====================================================================

function assertPlainRequestObject(data) {
  const payload = data || {};
  if (typeof payload !== "object" || Array.isArray(payload)) {
    throw invalidRequest();
  }
  return payload;
}

function assertAllowedKeys(payload, allowedFields) {
  if (!Object.keys(payload).every((key) => allowedFields.includes(key))) {
    throw invalidRequest();
  }
}

// Exported for direct, deterministic unit testing of every pageSize edge
// case without exercising the full callable.
function validatePageSize(payload) {
  if (!Object.prototype.hasOwnProperty.call(payload, "pageSize") || payload.pageSize === undefined) {
    return PAGE_SIZE_DEFAULT;
  }
  const value = payload.pageSize;
  // Number.isInteger alone excludes floats, NaN, Infinity, -Infinity,
  // strings, booleans, arrays, objects, and null — never Number()/
  // parseInt()/parseFloat(), never truthiness coercion.
  if (!Number.isInteger(value) || value < PAGE_SIZE_MIN || value > PAGE_SIZE_MAX) {
    throw invalidRequest();
  }
  return value;
}

function assertNonEmptyIdentifier(value, maxLength) {
  if (typeof value !== "string" || value.length === 0 || value.length > maxLength) {
    throw invalidRequest();
  }
  return value;
}

// =====================================================================
// Cursor codec — §10.1 "Slice 4.5 public-catalog ordering and cursor
// contract"
// =====================================================================

function encodeCursor(lastPath) {
  const json = JSON.stringify({ v: CURSOR_VERSION, lastPath });
  return Buffer.from(json, "utf8").toString("base64url");
}

// Returns `null` when no cursor was supplied (first page); returns the
// validated `lastPath` string on success; throws `invalid-argument` on
// any malformed input. Never echoes the supplied cursor or any decoded
// fragment back to the caller.
function decodeCursor(cursor) {
  // §10.1: "the request cursor is either absent/null (first page)..." —
  // an explicit `null` is treated identically to an absent key, never
  // rejected as an invalid type.
  if (cursor === undefined || cursor === null) return null;
  if (typeof cursor !== "string" || cursor.length === 0 || cursor.length > CURSOR_MAX_ENCODED_LENGTH) {
    throw invalidRequest();
  }
  if (!/^[A-Za-z0-9_-]+$/.test(cursor)) {
    throw invalidRequest();
  }

  let buf;
  try {
    buf = Buffer.from(cursor, "base64url");
  } catch (err) {
    throw invalidRequest();
  }
  // Round-trip check: Buffer's base64url decode is lenient with certain
  // malformed inputs in some Node versions — re-encoding must reproduce
  // the exact supplied string, or the input is rejected.
  if (buf.toString("base64url") !== cursor) {
    throw invalidRequest();
  }

  const text = buf.toString("utf8");
  // UTF-8 fidelity check: Buffer#toString('utf8') silently substitutes
  // invalid byte sequences with U+FFFD rather than throwing — re-encoding
  // the decoded string must reproduce the exact original bytes, or the
  // input contained invalid UTF-8 and is rejected.
  if (!Buffer.from(text, "utf8").equals(buf)) {
    throw invalidRequest();
  }

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (err) {
    throw invalidRequest();
  }
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw invalidRequest();
  }
  const keys = Object.keys(parsed);
  if (keys.length !== 2 || !keys.includes("v") || !keys.includes("lastPath")) {
    throw invalidRequest();
  }
  if (parsed.v !== CURSOR_VERSION) {
    throw invalidRequest();
  }
  if (typeof parsed.lastPath !== "string") {
    throw invalidRequest();
  }
  if (!NESTED_PRODUCT_PATH_RE.test(parsed.lastPath)) {
    throw invalidRequest();
  }
  return parsed.lastPath;
}

// =====================================================================
// Positive public projection — §10.1 "Slice 4.5 public product
// projection contract" (Revision 12 correction 57). Exactly 29 keys, a
// positive allowlist only — never `{...productData}` with keys deleted
// afterward.
// =====================================================================

function isNonEmptyTrimmedString(value, maxLength) {
  return typeof value === "string" && value.length <= maxLength && value.trim().length > 0;
}

function nullableString(value, maxLength) {
  return isNonEmptyTrimmedString(value, maxLength) ? value : null;
}

function nullableNumber(value) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : null;
}

function nullableInteger(value) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 ? value : null;
}

function nullableBoolean(value) {
  return typeof value === "boolean" ? value : null;
}

function projectDescription(value) {
  return typeof value === "string" && value.length <= STR_MAX.description ? value : "";
}

function projectDeliveryType(value) {
  return isNonEmptyTrimmedString(value, STR_MAX.deliveryType) ? value : "cargo";
}

// §10.1 correction 57, item 2b — currency's own conditional default,
// distinct from both the hide-product tier and the ordinary default
// tier: absent/null -> "TRY"; exactly "TRY"/"USD"/"EUR" -> unchanged;
// anything else -> hide the whole product. Never trimmed, never
// case-normalized, never coerced.
function projectCurrency(value) {
  if (value === undefined || value === null) return { ok: true, value: "TRY" };
  if (typeof value === "string" && CURRENCY_ALLOWED.includes(value)) {
    return { ok: true, value };
  }
  return { ok: false, value: null };
}

function projectCarrierCodes(raw) {
  if (!Array.isArray(raw)) return [];
  const seen = new Set();
  const result = [];
  for (const entry of raw) {
    if (typeof entry !== "string" || entry.length === 0 || entry.length > CARRIER_CODE_MAX_LENGTH) {
      continue;
    }
    if (seen.has(entry)) continue;
    seen.add(entry);
    result.push(entry);
    if (result.length >= CARRIER_CODE_MAX_COUNT) break;
  }
  return result;
}

function projectMediaUrl(value) {
  if (typeof value !== "string" || value.length === 0 || value.length > MEDIA_URL_MAX_LENGTH) {
    return null;
  }
  return value;
}

// A stored media entry is projected only when its `type` is exactly
// "image"/"video", its `status` is exactly "ready", and it retains at
// least one usable URL after validation — otherwise the entire entry is
// dropped (never a partial/placeholder entry). `status` itself is never
// included in the output.
function projectMediaEntry(raw) {
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return null;
  const type = raw.type;
  if (
    typeof type !== "string" ||
    type.length > MEDIA_TYPE_MAX_LENGTH ||
    (type !== "image" && type !== "video")
  ) {
    return null;
  }
  if (raw.status !== "ready") return null;

  const originalUrl = projectMediaUrl(raw.originalUrl);
  const playbackUrl = projectMediaUrl(raw.playbackUrl);
  const thumbnailUrl = projectMediaUrl(raw.thumbnailUrl);
  if (originalUrl === null && playbackUrl === null && thumbnailUrl === null) {
    return null;
  }
  return { type, originalUrl, playbackUrl, thumbnailUrl };
}

// Scans in stored source order, skipping invalid entries without
// consuming the cap; stops immediately once `cap` valid entries have
// been collected — for `LIST_MEDIA_CAP` (1) this means a second valid
// entry is never even examined.
function projectMedia(sourceMedia, cap) {
  const result = [];
  for (const raw of sourceMedia) {
    const entry = projectMediaEntry(raw);
    if (entry === null) continue;
    result.push(entry);
    if (result.length >= cap) break;
  }
  return result;
}

// Returns the exact 29-key `PublicProductListItem`/`PublicProductDetail`
// object, or `null` when any hide-product-tier condition is hit (the
// caller decides how to translate `null` into omission/not-found).
// `mediaCap` is the only difference between the two named shapes.
function projectPublicProduct(rawData, docPath, mediaCap) {
  if (rawData === null || typeof rawData !== "object" || Array.isArray(rawData)) {
    return null;
  }

  const pathMatch = NESTED_PRODUCT_PATH_RE.exec(docPath);
  if (!pathMatch) return null;
  const businessId = pathMatch[1];
  const productId = pathMatch[2];
  if (businessId.length > STR_MAX.businessId || productId.length > STR_MAX.productId) {
    return null;
  }

  if (!isNonEmptyTrimmedString(rawData.name, STR_MAX.name)) return null;
  if (!isNonEmptyTrimmedString(rawData.category, STR_MAX.category)) return null;
  if (!(typeof rawData.price === "number" && Number.isFinite(rawData.price) && rawData.price >= 0)) {
    return null;
  }
  if (!(typeof rawData.stock === "number" && Number.isInteger(rawData.stock) && rawData.stock >= 0)) {
    return null;
  }

  const sourceMedia = rawData.media;
  if (!Array.isArray(sourceMedia) || sourceMedia.length > SOURCE_MEDIA_MAX_LENGTH) {
    return null;
  }

  const currency = projectCurrency(rawData.currency);
  if (!currency.ok) return null;

  return {
    businessId,
    productId,
    name: rawData.name,
    description: projectDescription(rawData.description),
    category: rawData.category,
    brand: nullableString(rawData.brand, STR_MAX.brand),
    media: projectMedia(sourceMedia, mediaCap),
    price: rawData.price,
    salePrice: nullableNumber(rawData.salePrice),
    currency: currency.value,
    kdvRate: nullableNumber(rawData.kdvRate),
    taxIncluded: nullableBoolean(rawData.taxIncluded),
    stock: rawData.stock,
    shippingMode: nullableString(rawData.shippingMode, STR_MAX.shippingMode),
    shippingPayer: nullableString(rawData.shippingPayer, STR_MAX.shippingPayer),
    shippingFee: nullableNumber(rawData.shippingFee),
    freeShippingThreshold: nullableNumber(rawData.freeShippingThreshold),
    allowFreeShipping: typeof rawData.allowFreeShipping === "boolean" ? rawData.allowFreeShipping : false,
    allowedCarrierCodes: projectCarrierCodes(rawData.allowedCarrierCodes),
    originCity: nullableString(rawData.originCity, STR_MAX.originCity),
    maxDeliveryDays: nullableInteger(rawData.maxDeliveryDays),
    deliveryType: projectDeliveryType(rawData.deliveryType),
    weightKg: nullableNumber(rawData.weightKg),
    lengthCm: nullableNumber(rawData.lengthCm),
    widthCm: nullableNumber(rawData.widthCm),
    heightCm: nullableNumber(rawData.heightCm),
    fixedDesi: nullableNumber(rawData.fixedDesi),
    businessName: nullableString(rawData.businessName, STR_MAX.businessName),
    businessLogo: nullableString(rawData.businessLogo, STR_MAX.businessLogo),
  };
}

// =====================================================================
// getMarketplaceProductList — §10.1 "Slice 4.5 public-catalog ordering
// and cursor contract" / "bounded list algorithm" / "list error and
// per-candidate filtering contract"
// =====================================================================

async function getMarketplaceProductList({
  db,
  data,
  featureEnabled,
  now = new Date(),
  evaluator = evaluateLiveProductEligibility,
}) {
  if (featureEnabled !== true) {
    throw featureDisabled();
  }

  const payload = assertPlainRequestObject(data);
  assertAllowedKeys(payload, LIST_REQUEST_ALLOWED_FIELDS);
  const pageSize = validatePageSize(payload);
  const cursorLastPath = decodeCursor(payload.cursor);

  const fetchLimit = pageSize * FETCH_LIMIT_MULTIPLIER;
  const examineCap = pageSize * EXAMINE_CAP_MULTIPLIER;

  const items = [];
  let examinedCount = 0;
  let lastExaminedPath = null;
  let fetchCount = 0;
  let exhausted = false;
  let startAfterRef = cursorLastPath !== null ? db.doc(cursorLastPath) : null;

  while (items.length < pageSize && fetchCount < MAX_FETCHES && examinedCount < examineCap && !exhausted) {
    let query = db
      .collectionGroup("products")
      .where("isActive", "==", true)
      .where("moderationStatus", "==", "approved")
      .orderBy(FieldPath.documentId(), "asc");
    if (startAfterRef !== null) {
      query = query.startAfter(startAfterRef);
    }
    query = query.limit(fetchLimit);

    let snapshot;
    try {
      snapshot = await query.get();
    } catch (err) {
      throw new HttpsError("internal", "Unable to load products");
    }
    fetchCount += 1;

    const docs = snapshot.docs;
    // A short fetch (fewer documents than the requested limit) proves no
    // further document exists past this fetched batch — but, on its own,
    // it says nothing about whether every document *inside* this batch was
    // actually examined. Recording it here, and only combining it with
    // `batchFullyExamined` (below, once the per-candidate loop has run),
    // is what closes the candidate-loss defect a prior implementation had:
    // treating `shortFetch` alone as proof of exhaustion let the early-stop
    // rule (`pageSize` reached, or the examine cap reached) discard
    // already-fetched, never-examined, potentially-eligible documents by
    // marking the whole request exhausted before they were ever looked at.
    const shortFetch = docs.length < fetchLimit;

    let examinedInBatch = 0;
    for (const doc of docs) {
      if (items.length >= pageSize || examinedCount >= examineCap) break;
      examinedInBatch += 1;
      examinedCount += 1;
      lastExaminedPath = doc.ref.path;

      let projected;
      try {
        projected = projectPublicProduct(doc.data(), doc.ref.path, LIST_MEDIA_CAP);
      } catch (err) {
        projected = null;
      }
      if (projected === null) continue;

      let result;
      try {
        result = await evaluator({
          db,
          businessId: projected.businessId,
          productId: projected.productId,
          now,
        });
      } catch (err) {
        continue;
      }
      if (!result || result.eligible !== true) continue;

      items.push(projected);
    }

    // True public-pagination exhaustion requires both halves: no further
    // document exists past this batch (shortFetch — trivially true for a
    // zero-document batch too, since 0 < fetchLimit always holds), AND no
    // unexamined document remains inside this already-fetched batch
    // (batchFullyExamined). If the per-candidate loop broke early (page
    // filled, or the examine cap was reached) before reaching the end of
    // a short batch, `batchFullyExamined` is false and exhaustion is
    // correctly withheld — the unexamined suffix remains reachable via
    // `nextCursor` on a later invocation, never silently discarded.
    const batchFullyExamined = examinedInBatch === docs.length;
    if (shortFetch && batchFullyExamined) {
      exhausted = true;
    } else if (docs.length > 0) {
      startAfterRef = docs[docs.length - 1].ref;
    }
  }

  const nextCursor = lastExaminedPath !== null && !exhausted ? encodeCursor(lastExaminedPath) : null;

  return { items, nextCursor };
}

// =====================================================================
// getMarketplaceProductDetail — §10.1 "Slice 4.5 detail request/absence/
// error contract" (Revision 12 correction 58)
// =====================================================================

async function getMarketplaceProductDetail({
  db,
  data,
  featureEnabled,
  now = new Date(),
  evaluator = evaluateLiveProductEligibility,
}) {
  if (featureEnabled !== true) {
    throw featureDisabled();
  }

  const payload = assertPlainRequestObject(data);
  assertAllowedKeys(payload, DETAIL_REQUEST_ALLOWED_FIELDS);
  const businessId = assertNonEmptyIdentifier(payload.businessId, STR_MAX.businessId);
  const productId = assertNonEmptyIdentifier(payload.productId, STR_MAX.productId);

  let snap;
  try {
    snap = await productDetailRef(db, businessId, productId).get();
  } catch (err) {
    throw new HttpsError("internal", "Unable to load product");
  }

  if (!snap.exists) {
    throw new HttpsError("not-found", "Product not found");
  }

  const rawData = snap.data();
  if (!rawData || typeof rawData !== "object" || rawData.businessId !== businessId) {
    throw new HttpsError("not-found", "Product not found");
  }
  if (rawData.isActive !== true || rawData.moderationStatus !== "approved") {
    throw new HttpsError("not-found", "Product not found");
  }

  const projected = projectPublicProduct(rawData, snap.ref.path, DETAIL_MEDIA_CAP);
  if (projected === null) {
    throw new HttpsError("not-found", "Product not found");
  }

  let result;
  try {
    result = await evaluator({ db, businessId, productId, now });
  } catch (err) {
    throw new HttpsError("internal", "Unable to load product");
  }
  if (!result || result.eligible !== true) {
    throw new HttpsError("not-found", "Product not found");
  }

  return { item: projected };
}

module.exports = {
  getMarketplaceProductList,
  getMarketplaceProductDetail,
  // Test-only exports for direct, deterministic unit testing of pure
  // mechanical helpers — never database references, mutable state, or
  // evaluator internals.
  encodeCursor,
  decodeCursor,
  validatePageSize,
  projectPublicProduct,
};
