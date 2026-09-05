"use strict";

// Marketplace Revision 38 §0.36 (Slice 7B) — the frozen public visibility
// contract, as executable data.
//
// This module holds NO logic and performs NO reads. It exists so the public
// catalogue path, its tests and any future reviewer read the same frozen
// contract from one place, rather than from prose that code can silently
// drift away from.
//
// WHY CALLABLE-ONLY. `moderationStatus`/`isActive` are persisted product
// state. They converge toward compliance truth through the recompute and
// invalidation sweeps, but between an evidence revocation, a policy change, a
// business-generation change or a decision invalidation and the sweep that
// propagates it, they still read "approved and active". Revision 30 §H named
// that interval. A Firestore Rules predicate over product fields cannot close
// it, and neither can denormalized mirrors: expiry alone is checkable against
// request time, revocation and policy drift are not.

/// The frozen public projection — exactly these 29 keys, no others.
/// Revision 38 §0.36 E.
const PUBLIC_PRODUCT_FIELDS = Object.freeze([
  "allowFreeShipping",
  "allowedCarrierCodes",
  "brand",
  "businessId",
  "businessLogo",
  "businessName",
  "category",
  "currency",
  "deliveryType",
  "description",
  "fixedDesi",
  "freeShippingThreshold",
  "heightCm",
  "kdvRate",
  "lengthCm",
  "maxDeliveryDays",
  "media",
  "name",
  "originCity",
  "price",
  "productId",
  "salePrice",
  "shippingFee",
  "shippingMode",
  "shippingPayer",
  "stock",
  "taxIncluded",
  "weightKg",
  "widthCm",
]);

/// Every key a public media entry may carry. `status` is deliberately absent:
/// it is an internal transcode state, never public.
const PUBLIC_MEDIA_FIELDS = Object.freeze([
  "type",
  "originalUrl",
  "playbackUrl",
  "thumbnailUrl",
]);

/// Field names that must NEVER appear in a public response. Not an exhaustive
/// denylist — the projection allowlist above is the security boundary — but a
/// regression tripwire for the categories most likely to be added by mistake.
const PUBLIC_FORBIDDEN_FIELDS = Object.freeze([
  "ownerUid",
  "sellerRelationship",
  "pilotProductApproval",
  "pilotProductClass",
  "pilotProductClassifiedByUid",
  "pilotProductClassificationRevision",
  "marketplaceBusinessGenerationId",
  "moderationStatus",
  "isActive",
  "productInputRevision",
  "storagePath",
  "contentHash",
  "decisionHash",
  "policyVersion",
  "evidenceRevision",
  "activeEvidenceRefs",
  "effectiveStatus",
  "validUntil",
  "rejectionReason",
  "adminNotes",
  "scanStatus",
  "sku",
]);

/// The twelve conditions of Revision 38 §0.36 A, in order, each tagged with
/// where it is enforced. `evaluator` means `evaluateLiveProductEligibility`
/// subsumes it; `catalog` means the public catalogue path must assert it
/// itself because the evaluator does not.
///
/// Conditions 3, 4, 6 and 9 are `catalog` for a specific reason: the evaluator
/// checks the pilot class only for snapshot EQUALITY, so an unclassified
/// product (a `null` live class matching a `null` snapshot) passes it — and
/// would be publicly listed if the catalogue did not assert class validity
/// separately.
const PUBLIC_VISIBILITY_CONDITIONS = Object.freeze([
  Object.freeze({ id: 1, condition: "product_exists", enforcedBy: "catalog" }),
  Object.freeze({ id: 2, condition: "business_exists", enforcedBy: "catalog" }),
  Object.freeze({ id: 3, condition: "business_approved_and_marketplace_eligible", enforcedBy: "catalog" }),
  Object.freeze({ id: 4, condition: "seller_activation_valid", enforcedBy: "catalog" }),
  Object.freeze({ id: 5, condition: "product_business_id_matches", enforcedBy: "both" }),
  Object.freeze({ id: 6, condition: "live_business_generation_matches", enforcedBy: "catalog" }),
  Object.freeze({ id: 7, condition: "moderation_status_approved", enforcedBy: "catalog" }),
  Object.freeze({ id: 8, condition: "is_active_true", enforcedBy: "catalog" }),
  Object.freeze({ id: 9, condition: "pilot_product_class_valid", enforcedBy: "catalog" }),
  Object.freeze({ id: 10, condition: "compliance_decision_exists", enforcedBy: "evaluator" }),
  Object.freeze({ id: 11, condition: "decision_binding_matches", enforcedBy: "evaluator" }),
  Object.freeze({ id: 12, condition: "live_eligibility_predicate", enforcedBy: "evaluator" }),
]);

module.exports = {
  PUBLIC_PRODUCT_FIELDS,
  PUBLIC_MEDIA_FIELDS,
  PUBLIC_FORBIDDEN_FIELDS,
  PUBLIC_VISIBILITY_CONDITIONS,
};
