"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  normalizeOptionalBusinessLogo,
  sanitizeBusinessSectorLogoFields,
} = require("../src/business/logo_fields");
const {serviceDisplayFields} = require("../src/promotion/service_projection_fields");

test("missing business logo remains null rather than becoming a UI fallback", () => {
  const result = sanitizeBusinessSectorLogoFields({
    veterinary: {profileContent: {clinicLogoUrl: null}},
  });
  assert.equal(result.veterinary.profileContent.clinicLogoUrl, null);
  assert.equal(normalizeOptionalBusinessLogo(""), null);
});

test("bundled PetSupo UI logo paths are not persisted as business identity", () => {
  assert.equal(normalizeOptionalBusinessLogo("assets/image/logo.png"), null);
  assert.equal(normalizeOptionalBusinessLogo("./assets/image/logo.png"), null);
});

test("real uploaded logo URL is preserved", () => {
  const url = "https://firebasestorage.googleapis.com/v0/b/test/o/vet-logo.jpg";
  const result = sanitizeBusinessSectorLogoFields({
    veterinary: {profileContent: {clinicLogoUrl: url}},
  });
  assert.equal(result.veterinary.profileContent.clinicLogoUrl, url);
});

test("Groomer legacy logo fields receive the same null-or-real normalization", () => {
  const result = sanitizeBusinessSectorLogoFields({
    groomer: {
      profileContent: {
        clinicLogoUrl: "assets/image/logo.png",
        logoUrl: "https://cdn.test/groomer-logo.jpg",
      },
    },
  });
  assert.equal(result.groomer.profileContent.clinicLogoUrl, null);
  assert.equal(result.groomer.profileContent.logoUrl, "https://cdn.test/groomer-logo.jpg");
});

test("projection copies only the canonical real logo and keeps null null", () => {
  const realUrl = "https://cdn.test/vet-logo.jpg";
  const real = serviceDisplayFields({
    publicBusiness: {
      profile: {displayName: "Vet A", logoUrl: null},
      publicSectorData: {
        veterinary: {profileContent: {clinicLogoUrl: realUrl}},
      },
    },
    service: {title: "Laboratory"},
    sector: "VET",
  });
  const missing = serviceDisplayFields({
    publicBusiness: {
      profile: {displayName: "Vet B", logoUrl: null},
      publicSectorData: {veterinary: {profileContent: {clinicLogoUrl: null}}},
    },
    service: {title: "Laboratory"},
    sector: "VET",
  });
  assert.equal(real.logoUrl, realUrl);
  assert.equal(missing.logoUrl, null);
});
