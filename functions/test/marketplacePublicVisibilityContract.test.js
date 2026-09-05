"use strict";

// Marketplace Revision 38 §0.36 (Slice 7B) — contract tests for the frozen
// public visibility contract. Pure constants; no emulator, no reads.

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const {
  PUBLIC_PRODUCT_FIELDS,
  PUBLIC_MEDIA_FIELDS,
  PUBLIC_FORBIDDEN_FIELDS,
  PUBLIC_VISIBILITY_CONDITIONS,
} = require("../src/marketplace/publicCatalog/marketplacePublicVisibility");
const {
  projectPublicProduct,
} = require("../src/marketplace/publicCatalog/marketplaceListing");

test("the public projection allowlist is exactly the 29 frozen fields, sorted and frozen", () => {
  assert.equal(PUBLIC_PRODUCT_FIELDS.length, 29);
  assert.deepEqual([...PUBLIC_PRODUCT_FIELDS], [...PUBLIC_PRODUCT_FIELDS].sort());
  assert.equal(Object.isFrozen(PUBLIC_PRODUCT_FIELDS), true);
  assert.deepEqual([...PUBLIC_PRODUCT_FIELDS], [
    "allowFreeShipping", "allowedCarrierCodes", "brand", "businessId",
    "businessLogo", "businessName", "category", "currency", "deliveryType",
    "description", "fixedDesi", "freeShippingThreshold", "heightCm", "kdvRate",
    "lengthCm", "maxDeliveryDays", "media", "name", "originCity", "price",
    "productId", "salePrice", "shippingFee", "shippingMode", "shippingPayer",
    "stock", "taxIncluded", "weightKg", "widthCm",
  ]);
});

test("the frozen allowlist matches what the live projection actually emits", () => {
  // The contract and the implementation must not drift apart. This is the
  // whole reason the allowlist exists as data rather than as prose.
  const emitted = projectPublicProduct(
    {
      businessId: "b", productId: "p", name: "n", description: "d",
      category: "c", brand: "br", media: [], price: 1, salePrice: null,
      currency: "TRY", kdvRate: 10, taxIncluded: true, stock: 1,
      shippingMode: "m", shippingPayer: "s", shippingFee: 0,
      freeShippingThreshold: 0, allowFreeShipping: true, allowedCarrierCodes: [],
      originCity: "x", maxDeliveryDays: 3, deliveryType: "t", weightKg: 1,
      lengthCm: 1, widthCm: 1, heightCm: 1, fixedDesi: 1,
      businessName: "bn", businessLogo: "bl",
    },
    "businesses/b/products/p",
    1
  );
  assert.notEqual(emitted, null);
  assert.deepEqual(Object.keys(emitted).sort(), [...PUBLIC_PRODUCT_FIELDS]);
});

test("no forbidden field is reachable through the public projection", () => {
  // Every forbidden name is fed to the projection; none may survive.
  const hostile = {
    businessId: "b", productId: "p", name: "n", category: "c",
    media: [], price: 1, stock: 1,
  };
  for (const forbidden of PUBLIC_FORBIDDEN_FIELDS) {
    hostile[forbidden] = "LEAKED";
  }
  const emitted = projectPublicProduct(hostile, "businesses/b/products/p", 1);
  assert.notEqual(emitted, null);
  const serialized = JSON.stringify(emitted);
  for (const forbidden of PUBLIC_FORBIDDEN_FIELDS) {
    assert.equal(
      Object.prototype.hasOwnProperty.call(emitted, forbidden),
      false,
      `${forbidden} must never be projected`
    );
  }
  assert.equal(serialized.includes("LEAKED"), false, "no forbidden value may leak");
});

test("a public media entry carries exactly the four frozen keys, never the internal status", () => {
  assert.deepEqual([...PUBLIC_MEDIA_FIELDS], [
    "type", "originalUrl", "playbackUrl", "thumbnailUrl",
  ]);
  const emitted = projectPublicProduct(
    {
      businessId: "b", productId: "p", name: "n", category: "c", price: 1, stock: 1,
      media: [
        {
          type: "image",
          status: "ready",
          originalUrl: "https://example.test/o.jpg",
          playbackUrl: null,
          thumbnailUrl: "https://example.test/t.jpg",
          scanStatus: "clean",
          storagePath: "marketplace/secret/path.jpg",
        },
      ],
    },
    "businesses/b/products/p",
    5
  );
  assert.equal(emitted.media.length, 1);
  assert.deepEqual(Object.keys(emitted.media[0]).sort(), [...PUBLIC_MEDIA_FIELDS].sort());
  const serialized = JSON.stringify(emitted.media);
  assert.equal(serialized.includes("storagePath"), false);
  assert.equal(serialized.includes("marketplace/secret"), false);
  assert.equal(serialized.includes("scanStatus"), false);
});

test("the twelve frozen visibility conditions are complete, ordered and attributed", () => {
  assert.equal(PUBLIC_VISIBILITY_CONDITIONS.length, 12);
  assert.deepEqual(
    PUBLIC_VISIBILITY_CONDITIONS.map((c) => c.id),
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
  );
  for (const c of PUBLIC_VISIBILITY_CONDITIONS) {
    assert.ok(["catalog", "evaluator", "both"].includes(c.enforcedBy), c.condition);
    assert.equal(Object.isFrozen(c), true);
  }
});

test("the four conditions the evaluator does NOT subsume are attributed to the catalogue path", () => {
  // This is the substantive finding Revision 38 §0.36 A records: business
  // eligibility, seller activation, live generation and CLASS VALIDITY are
  // not covered by `evaluateLiveProductEligibility`. In particular an
  // unclassified product passes its snapshot-equality check, because a null
  // live class matches a null snapshot.
  const byCondition = Object.fromEntries(
    PUBLIC_VISIBILITY_CONDITIONS.map((c) => [c.condition, c.enforcedBy])
  );
  assert.equal(byCondition.business_approved_and_marketplace_eligible, "catalog");
  assert.equal(byCondition.seller_activation_valid, "catalog");
  assert.equal(byCondition.live_business_generation_matches, "catalog");
  assert.equal(byCondition.pilot_product_class_valid, "catalog");
  assert.equal(byCondition.live_eligibility_predicate, "evaluator");
});

test("the frozen contract is recorded in the master plan as Revision 38 §0.36", () => {
  const plan = fs.readFileSync(
    path.join(
      __dirname, "..", "..", "docs", "plans",
      "marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md"
    ),
    "utf8"
  );
  assert.ok(plan.includes("### 0.36 Revision 38 change log"));
  assert.ok(plan.includes("Callable-only public product discovery"));
  // The contract's own numbers must appear in the prose that freezes them.
  assert.ok(plan.includes("closed allowlist of exactly 29 fields"));
  // And the flags must still be recorded as unset.
  assert.ok(plan.includes("MARKETPLACE_LISTING_ENABLED"));
});

test("the contract module is pure data — it performs no reads and holds no logic", () => {
  const source = fs.readFileSync(
    path.join(
      __dirname, "..", "src", "marketplace", "publicCatalog",
      "marketplacePublicVisibility.js"
    ),
    "utf8"
  );
  for (const forbidden of ["require(", "firestore", ".get(", "async ", "function "]) {
    assert.equal(
      source.includes(forbidden),
      false,
      `the frozen contract module must contain no ${forbidden}`
    );
  }
});
