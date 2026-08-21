"use strict";

const SOURCE = "partner_email";
const CAMPAIGN = "partner_outreach_2026";
const CONTENT = "welcome_email";
const INTAKE_MODE = "partner_application";

const CATEGORY_SECTORS = Object.freeze({
  general: null,
  veteriner: "veterinary",
  pet_otel: "pet_hotel",
  pet_taksi: "pet_taxi",
  groomer: "groomer",
  pet_shop: "pet_shop",
  sahiplendirme: "adoption_center",
});

const ALLOWED_KEYS = new Set([
  "source",
  "campaign",
  "content",
  "partnerCategory",
  "initialSector",
]);

function normalizePartnerIntake(input, sectors = []) {
  if (input == null) return null;
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new Error("partner-intake-invalid");
  }

  for (const key of Object.keys(input)) {
    if (!ALLOWED_KEYS.has(key)) {
      throw new Error("partner-intake-extra-field");
    }
  }

  const source = String(input.source || "");
  const campaign = String(input.campaign || "");
  const content = String(input.content || "");
  const partnerCategory = String(input.partnerCategory || "");
  const initialSector = input.initialSector == null
    ? null
    : String(input.initialSector);

  if (source !== SOURCE) throw new Error("partner-intake-source");
  if (campaign !== CAMPAIGN) throw new Error("partner-intake-campaign");
  if (content !== CONTENT) throw new Error("partner-intake-content");
  if (!Object.prototype.hasOwnProperty.call(CATEGORY_SECTORS, partnerCategory)) {
    throw new Error("partner-intake-category");
  }

  const expectedSector = CATEGORY_SECTORS[partnerCategory];
  if (initialSector !== expectedSector) {
    throw new Error("partner-intake-sector-pair");
  }

  if (expectedSector !== null && !sectors.includes(expectedSector)) {
    throw new Error("partner-intake-sector-not-submitted");
  }

  return {
    source: SOURCE,
    campaign: CAMPAIGN,
    content: CONTENT,
    partnerCategory,
    intakeMode: INTAKE_MODE,
  };
}

module.exports = {
  CAMPAIGN,
  CATEGORY_SECTORS,
  CONTENT,
  INTAKE_MODE,
  SOURCE,
  normalizePartnerIntake,
};
