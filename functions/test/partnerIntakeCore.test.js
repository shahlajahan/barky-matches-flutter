"use strict";

const assert = require("node:assert/strict");
const {test} = require("node:test");
const {
  CATEGORY_SECTORS,
  normalizePartnerIntake,
} = require("../business/partnerIntakeCore");

const base = {
  source: "partner_email",
  campaign: "partner_outreach_2026",
  content: "welcome_email",
};

test("supported partner categories normalize to bounded acquisition metadata", () => {
  for (const [partnerCategory, initialSector] of Object.entries(CATEGORY_SECTORS)) {
    const sectors = initialSector == null ? ["pet_shop"] : [initialSector];
    const normalized = normalizePartnerIntake(
      {...base, partnerCategory, ...(initialSector == null ? {} : {initialSector})},
      sectors
    );
    assert.deepEqual(normalized, {
      source: "partner_email",
      campaign: "partner_outreach_2026",
      content: "welcome_email",
      partnerCategory,
      intakeMode: "partner_application",
    });
  }
});

test("missing partner intake keeps ordinary registration in Gold-gated mode", () => {
  assert.equal(normalizePartnerIntake(null, ["veterinary"]), null);
});

test("unknown or tampered acquisition fields are rejected", () => {
  assert.throws(
    () => normalizePartnerIntake({...base, partnerCategory: "veteriner", email: "a@example.com"}, ["veterinary"]),
    /partner-intake-extra-field/
  );
  assert.throws(
    () => normalizePartnerIntake({...base, source: "newsletter", partnerCategory: "veteriner"}, ["veterinary"]),
    /partner-intake-source/
  );
  assert.throws(
    () => normalizePartnerIntake({...base, campaign: "other", partnerCategory: "veteriner"}, ["veterinary"]),
    /partner-intake-campaign/
  );
  assert.throws(
    () => normalizePartnerIntake({...base, content: "other", partnerCategory: "veteriner"}, ["veterinary"]),
    /partner-intake-content/
  );
  assert.throws(
    () => normalizePartnerIntake({...base, partnerCategory: "unknown"}, ["veterinary"]),
    /partner-intake-category/
  );
});

test("invalid category and sector pairs are rejected", () => {
  assert.throws(
    () => normalizePartnerIntake(
      {...base, partnerCategory: "veteriner", initialSector: "pet_shop"},
      ["pet_shop"]
    ),
    /partner-intake-sector-pair/
  );
  assert.throws(
    () => normalizePartnerIntake(
      {...base, partnerCategory: "veteriner", initialSector: "veterinary"},
      ["pet_shop"]
    ),
    /partner-intake-sector-not-submitted/
  );
  assert.throws(
    () => normalizePartnerIntake(
      {...base, partnerCategory: "general", initialSector: "veterinary"},
      ["veterinary"]
    ),
    /partner-intake-sector-pair/
  );
});
