"use strict";

function firstText(...values) {
  for (const value of values) {
    const text = value === undefined || value === null ? "" : String(value).trim();
    if (text) return text;
  }
  return "";
}

function isValidHttpsUrl(value) {
  const text = value === undefined || value === null ? "" : String(value).trim();
  if (!text.startsWith("https://")) return false;
  try {
    const url = new URL(text);
    return url.protocol === "https:" && Boolean(url.host);
  } catch (_) {
    return false;
  }
}

function firstHttpsText(...values) {
  for (const value of values) {
    const text = value === undefined || value === null ? "" : String(value).trim();
    if (isValidHttpsUrl(text)) return text;
  }
  return null;
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

  return firstHttpsText(
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

function publicBusinessDisplayImage({publicBusiness = {}, sector}) {
  const publicData = asMap(publicBusiness);
  const profile = asMap(publicData.profile);
  const sectorData = asMap(publicData.publicSectorData);
  const sectorProfiles = sectorKeys(sector)
    .map((key) => asMap(sectorData[key]))
    .filter((value) => Object.keys(value).length > 0);
  const nestedProfiles = sectorProfiles.map((value) => asMap(value.profileContent));
  const clinicPhotos = nestedProfiles.flatMap((value) =>
    Array.isArray(value.clinicPhotoUrls) ? [value.clinicPhotoUrls[0]] : []
  );

  return firstHttpsText(
    ...sectorProfiles.flatMap((value) => [value.logoUrl, value.clinicLogoUrl]),
    ...nestedProfiles.flatMap((value) => [
      value.logoUrl,
      value.clinicLogoUrl,
      value.coverImageUrl,
    ]),
    ...clinicPhotos,
    profile.logoUrl,
    profile.coverUrl,
    publicData.coverImageUrl,
  );
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
  const logoUrl = publicBusiness
    ? publicBusinessLogo({publicBusiness: displayBusiness, sector})
    : firstHttpsText(profile.logoUrl, profile.coverUrl, displayBusiness.logoUrl, displayBusiness.coverImageUrl);
  const displayImageUrl = publicBusiness
    ? publicBusinessDisplayImage({publicBusiness: displayBusiness, sector})
    : logoUrl;
  return {
    businessName,
    serviceTitle,
    location: [district, city].filter(Boolean).join(", "),
    price: service.price ?? null,
    currency: service.currency || "TRY",
    // Kept logo-only for compatibility. Cover/gallery media belongs in the
    // explicitly named displayImageUrl field.
    logoUrl,
    displayImageUrl,
  };
}

module.exports = {
  firstText,
  firstHttpsText,
  isValidHttpsUrl,
  publicBusinessLogo,
  publicBusinessDisplayImage,
  serviceDisplayFields,
};
