"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  VALID_COMPANY_TYPES,
  isValidCompanyType,
  requiredTurkeyDocuments,
} = require("../business/businessDocumentRequirements");

test("VALID_COMPANY_TYPES matches the confirmed canonical convention", () => {
  assert.deepEqual(VALID_COMPANY_TYPES, [
    "sole_proprietorship",
    "limited_company",
    "joint_stock_company",
  ]);
});

test("isValidCompanyType accepts only the canonical values", () => {
  assert.equal(isValidCompanyType("sole_proprietorship"), true);
  assert.equal(isValidCompanyType("limited_company"), true);
  assert.equal(isValidCompanyType("joint_stock_company"), true);
  assert.equal(isValidCompanyType("anonim"), false);
  assert.equal(isValidCompanyType(""), false);
  assert.equal(isValidCompanyType(null), false);
  assert.equal(isValidCompanyType(undefined), false);
  assert.equal(isValidCompanyType("SOLE_PROPRIETORSHIP"), false);
  assert.equal(isValidCompanyType({ $ne: null }), false);
});

test("sole proprietorship does not require trade registry or MERSIS", () => {
  const req = requiredTurkeyDocuments("sole_proprietorship");
  assert.equal(req.requiresTaxPlate, true);
  assert.equal(req.requiresTradeRegistryGazette, false);
  assert.equal(req.requiresSignatureDocument, true);
  assert.equal(req.requiresMersisNumber, false);
});

test("limited company preserves the existing full requirement set", () => {
  const req = requiredTurkeyDocuments("limited_company");
  assert.equal(req.requiresTaxPlate, true);
  assert.equal(req.requiresTradeRegistryGazette, true);
  assert.equal(req.requiresSignatureDocument, true);
  assert.equal(req.requiresMersisNumber, true);
});

test("joint stock company mirrors limited company's corporate requirements", () => {
  const limited = requiredTurkeyDocuments("limited_company");
  const anonim = requiredTurkeyDocuments("joint_stock_company");
  assert.deepEqual(anonim, limited);
});

test("null/unrecognized company type fails safe to the full corporate requirement set", () => {
  assert.deepEqual(requiredTurkeyDocuments(null), requiredTurkeyDocuments("limited_company"));
  assert.deepEqual(
    requiredTurkeyDocuments("tampered_value"),
    requiredTurkeyDocuments("limited_company")
  );
});
