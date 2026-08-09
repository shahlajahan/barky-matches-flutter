"use strict";

/**
 * Business identity fields must never contain a bundled UI asset.
 * Missing identity media remains null so customer-facing widgets can choose
 * their own presentation fallback.
 */
function normalizeOptionalBusinessLogo(value) {
  if (value === undefined || value === null) return null;
  const text = String(value).trim();
  if (!text) return null;

  const normalized = text.replace(/^\.?\//, "").toLowerCase();
  if (
    normalized === "assets/image/logo.png" ||
    normalized === "assets/image/logo.webp" ||
    normalized === "assets/image/logo.jpg"
  ) {
    return null;
  }
  return text;
}

function sanitizeBusinessSectorLogoFields(sectorData = {}) {
  if (!sectorData || typeof sectorData !== "object" || Array.isArray(sectorData)) {
    return sectorData;
  }

  const next = {...sectorData};
  for (const key of [
    "veterinary",
    "veterinarian",
    "vet",
    "groomy",
    "groomer",
    "grooming",
  ]) {
    const sector = next[key];
    if (!sector || typeof sector !== "object" || Array.isArray(sector)) continue;
    const profileContent = sector.profileContent;
    if (!profileContent || typeof profileContent !== "object" || Array.isArray(profileContent)) continue;
    next[key] = {
      ...sector,
      profileContent: {
        ...profileContent,
        clinicLogoUrl: normalizeOptionalBusinessLogo(profileContent.clinicLogoUrl),
        logoUrl: normalizeOptionalBusinessLogo(profileContent.logoUrl),
        logo: normalizeOptionalBusinessLogo(profileContent.logo),
      },
    };
  }
  return next;
}

module.exports = {
  normalizeOptionalBusinessLogo,
  sanitizeBusinessSectorLogoFields,
};
