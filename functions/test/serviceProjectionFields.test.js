"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {serviceDisplayFields} = require("../src/promotion/service_projection_fields");

const service = {title: "Laboratory", isActive: true, price: 1200, currency: "TRY"};

test("VET uses the canonical public veterinarian clinic logo", () => {
  const fields = serviceDisplayFields({
    business: {profile: {logoUrl: null}},
    publicBusiness: {
      profile: {displayName: "Vet A", logoUrl: null},
      contact: {city: "Istanbul", district: "Beylikduzu"},
      publicSectorData: {
        veterinarian: {clinicLogoUrl: "https://cdn.test/vet-logo.jpg"},
      },
    },
    service,
    sector: "VET",
  });

  assert.equal(fields.logoUrl, "https://cdn.test/vet-logo.jpg");
  assert.equal(fields.displayImageUrl, "https://cdn.test/vet-logo.jpg");
  assert.equal(fields.serviceTitle, "Laboratory");
});

test("SERVICE display image falls back to the sector cover image", () => {
  const fields = serviceDisplayFields({
    publicBusiness: {
      profile: {displayName: "Vet A", logoUrl: null},
      publicSectorData: {
        veterinary: {
          profileContent: {
            clinicLogoUrl: null,
            coverImageUrl: "https://cdn.test/cover.jpg",
            clinicPhotoUrls: ["https://cdn.test/photo.jpg"],
          },
        },
      },
    },
    service,
    sector: "VET",
  });
  assert.equal(fields.logoUrl, null);
  assert.equal(fields.displayImageUrl, "https://cdn.test/cover.jpg");
});

test("SERVICE display image falls back to the first clinic photo", () => {
  const fields = serviceDisplayFields({
    publicBusiness: {
      profile: {displayName: "Vet A", logoUrl: null},
      publicSectorData: {
        veterinary: {profileContent: {
          clinicLogoUrl: null,
          clinicPhotoUrls: ["https://cdn.test/photo.jpg"],
        }},
      },
    },
    service,
    sector: "VET",
  });
  assert.equal(fields.displayImageUrl, "https://cdn.test/photo.jpg");
});

test("display image rejects bundled UI assets and invalid URLs", () => {
  const fields = serviceDisplayFields({
    publicBusiness: {
      profile: {displayName: "Vet A", logoUrl: "assets/image/logo.png"},
      publicSectorData: {veterinary: {profileContent: {
        coverImageUrl: "http://cdn.test/cover.jpg",
        clinicPhotoUrls: ["assets/image/logo.png"],
      }}},
    },
    service,
    sector: "VET",
  });
  assert.equal(fields.displayImageUrl, null);
});

test("GROOMER resolves logo fields from the canonical public sector projection", () => {
  const fields = serviceDisplayFields({
    publicBusiness: {
      profile: {displayName: "Groomy A"},
      publicSectorData: {
        groomy: {profileContent: {logoUrl: "https://cdn.test/groomy-logo.jpg"}},
      },
    },
    service,
    sector: "GROOMER",
  });

  assert.equal(fields.logoUrl, "https://cdn.test/groomy-logo.jpg");
});

test("business without a public logo retains null fallback behavior", () => {
  const fields = serviceDisplayFields({
    publicBusiness: {
      profile: {displayName: "Business Without Logo"},
      publicSectorData: {veterinarian: {profileContent: {bio: "Care"}}},
    },
    service,
    sector: "VET",
  });

  assert.equal(fields.logoUrl, null);
});
