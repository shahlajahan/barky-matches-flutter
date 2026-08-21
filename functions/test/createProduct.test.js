"use strict";

// Marketplace product compliance audit, P0 remediation
// (docs/audits/marketplace_add_product_compliance_audit_2026-08-20.md,
// finding F-01). createProduct previously had no auth check at all and
// spread the raw caller payload into an unrelated, disconnected top-level
// `products` collection. It is disabled rather than repaired in P0 — a
// safe server-side creation path belongs with the P1 compliance-document
// review workflow. These tests prove it can no longer create a document
// for any caller, authenticated or not.

const assert = require("node:assert/strict");
const { test } = require("node:test");
const functions = require("../index");

test("createProduct rejects unauthenticated callers", async () => {
  await assert.rejects(
    functions.createProduct.run({
      auth: null,
      data: { sku: "abc", businessId: "biz-1" },
    }),
    (error) => {
      assert.equal(error.code, "unauthenticated");
      return true;
    }
  );
});

test("createProduct rejects authenticated callers too (disabled, not just unauthenticated)", async () => {
  await assert.rejects(
    functions.createProduct.run({
      auth: { uid: "seller-1" },
      data: { sku: "abc", businessId: "biz-1" },
    }),
    (error) => {
      assert.equal(error.code, "failed-precondition");
      return true;
    }
  );
});

test("createProduct rejects an attempt to spread arbitrary status/ownership fields", async () => {
  await assert.rejects(
    functions.createProduct.run({
      auth: { uid: "attacker" },
      data: {
        sku: "abc",
        businessId: "someone-elses-business",
        isActive: true,
        moderationStatus: "approved",
        stock: -999,
      },
    }),
    (error) => {
      assert.equal(error.code, "failed-precondition");
      return true;
    }
  );
});
