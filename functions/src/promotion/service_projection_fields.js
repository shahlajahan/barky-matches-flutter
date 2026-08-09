"use strict";

function firstText(...values) {
  for (const value of values) {
    const text = value === undefined || value === null ? "" : String(value).trim();
    if (text) return text;
  }
  return "";
}

function asMap(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

function sectorKeys(sector) {
  const normalized = String(sector || "").trim().toUpperCase();
  if (normalized === "VET") return ["veterinarian", "veterinary", "vet"];
  if (normalized === "GROOMER") return ["groomy", "groomer", "grooming"];
  return [];
}

function publicBusinessLogo({publicBusiness = {}, sector}) {
  const publicData = asMap(publicBusiness);
  const profile = asMap(publicData.profile);
  const sectorData = asMap(publicData.publicSectorData);
  const sectorProfiles = sectorKeys(sector)
    .map((key) => asMap(sectorData[key]))
    .filter((value) => Object.keys(value).length > 0);
  const nestedProfiles = sectorProfiles.flatMap((value) => [
    asMap(value.profileContent),
    asMap(value.profile),
    asMap(value.media),
  ]);

  return firstText(
    ...sectorProfiles.flatMap((value) => [
      value.logoUrl,
      value.clinicLogoUrl,
    ]),
    ...nestedProfiles.flatMap((value) => [
      value.logoUrl,
      value.clinicLogoUrl,
    ]),
    profile.logoUrl,
    profile.coverUrl,
    publicData.coverImageUrl,
  ) || null;
}

function serviceDisplayFields({
  business = {},
  publicBusiness = null,
  service = {},
  sector,
}) {
  const displayBusiness = asMap(publicBusiness || business);
  const profile = asMap(displayBusiness.profile);
  const contact = asMap(displayBusiness.contact);
  const serviceTitle = firstText(service.title, service.name, service.serviceName, "Service");
  const businessName = firstText(
    profile.displayName,
    profile.businessName,
    displayBusiness.businessName,
    displayBusiness.name,
    "Business",
  );
  const district = firstText(contact.district);
  const city = firstText(contact.city);
  return {
    businessName,
    serviceTitle,
    location: [district, city].filter(Boolean).join(", "),
    price: service.price ?? null,
    currency: service.currency || "TRY",
    logoUrl: publicBusiness
      ? publicBusinessLogo({publicBusiness: displayBusiness, sector})
      : firstText(profile.logoUrl, profile.coverUrl, displayBusiness.logoUrl, displayBusiness.coverImageUrl) || null,
  };
}

module.exports = {
  firstText,
  publicBusinessLogo,
  serviceDisplayFields,
};
