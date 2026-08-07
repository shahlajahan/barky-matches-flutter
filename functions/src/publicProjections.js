const admin = require("firebase-admin");
const {
  filterSectorDataByCanonicalSectors,
  isPetTaxiBusiness,
} = require("./businessSectorMembership");

const PUBLIC_USER_KEYS = [
  "uid",
  "username",
  "displayName",
  "name",
  "photoUrl",
  "profileImageUrl",
  "avatarUrl",
  "profilePhotoUrl",
  "city",
  "district",
  "bio",
  "description",
  "publicProfile",
  "isPremium",
];

const PUBLIC_BUSINESS_KEYS = [
  "businessId",
  "sectors",
  "status",
  "isActive",
  "published",
  "profile",
  "coverImageUrl",
  "coverImage",
  "images",
  "clinicPhotoUrls",
  "maxCapacity",
  "contact",
  "verification",
  "rating",
  "reviewCount",
  "reviewsCount",
  "isPartner",
  "isVerified",
  "is24h",
  "isEmergency",
  "publicSectorData",
  "createdAt",
];

const PUBLIC_PROFILE_KEYS = [
  "displayName",
  "businessName",
  "name",
  "description",
  "bio",
  "logoUrl",
  "coverUrl",
  "coverImageUrl",
  "categories",
  "tags",
  "rating",
  "reviewCount",
  "reviewsCount",
];

const PUBLIC_CONTACT_KEYS = [
  "phone",
  "whatsapp",
  "city",
  "district",
  "address",
  "addressLine",
  "location",
  "instagram",
  "website",
];

const PUBLIC_VERIFICATION_KEYS = ["level", "isVerified", "verifiedAt"];

const PUBLIC_SECTOR_KEYS = new Set([
  "displayName",
  "businessName",
  "name",
  "title",
  "id",
  "description",
  "publicDescription",
  "bio",
  "specialties",
  "categories",
  "tags",
  "services",
  "offeredServices",
  "serviceTypes",
  "pricing",
  "price",
  "priceRange",
  "packages",
  "duration",
  "durationMin",
  "workingHours",
  "workingHoursMap",
  "availability",
  "capacity",
  "maxCapacity",
  "roomTypes",
  "rooms",
  "serviceCatalog",
  "preVisitForm",
  "preVisitFormSettings",
  "preVisitQuestions",
  "profileContent",
  "profile",
  "content",
  "media",
  "operationalDetails",
  "socialMedia",
  "gallery",
  "photos",
  "images",
  "imageUrls",
  "logoUrl",
  "coverUrl",
  "coverImageUrl",
  "coverImage",
  "clinicLogoUrl",
  "clinicPhotoUrls",
  "vehicle",
  "driver",
  "currentLocation",
  "location",
  "isAvailable",
  "available",
  "online",
  "rating",
  "reviewCount",
  "reviewsCount",
  "is24h",
  "isEmergency",
  "enabled",
  "questions",
  "options",
  "required",
  "type",
  "label",
  "helpText",
  "value",
  "open",
  "close",
  "isOpen",
  "start",
  "end",
  "lat",
  "lng",
  "source",
  "updatedAt",
  "plateNumber",
  "vehicleType",
  "model",
  "brand",
  "color",
  "year",
  "fullName",
  "photoUrl",
  "petName",
  "species",
  "status",
  "sortOrder",
  "isActive",
  "amount",
  "currency",
  "unit",
  "min",
  "max",
  "featuredVet",
  "featuredGroomer",
  "amenities",
  "adoptionCenter",
  "adoption_center",
  "adoption",
  "pet_hotel",
  "petHotel",
  "hotel",
  "pet_taxi",
  "petTaxi",
  "taxi",
  "groomy",
  "groomer",
  "grooming",
  "veterinary",
  "vet",
  "veterinarian",
  "petshop",
  "pet_shop",
  "seller",
  "store",
]);

const PUBLIC_DAY_KEYS = new Set([
  "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
  "mon", "tue", "wed", "thu", "fri", "sat", "sun",
]);

const PUBLIC_MAP_SCHEMAS = {
  adoptionCenter: PUBLIC_SECTOR_KEYS,
  adoption_center: PUBLIC_SECTOR_KEYS,
  adoption: PUBLIC_SECTOR_KEYS,
  pet_hotel: PUBLIC_SECTOR_KEYS,
  petHotel: PUBLIC_SECTOR_KEYS,
  hotel: PUBLIC_SECTOR_KEYS,
  pet_taxi: PUBLIC_SECTOR_KEYS,
  petTaxi: PUBLIC_SECTOR_KEYS,
  taxi: PUBLIC_SECTOR_KEYS,
  groomy: PUBLIC_SECTOR_KEYS,
  groomer: PUBLIC_SECTOR_KEYS,
  grooming: PUBLIC_SECTOR_KEYS,
  veterinary: PUBLIC_SECTOR_KEYS,
  vet: PUBLIC_SECTOR_KEYS,
  veterinarian: PUBLIC_SECTOR_KEYS,
  petshop: PUBLIC_SECTOR_KEYS,
  pet_shop: PUBLIC_SECTOR_KEYS,
  seller: PUBLIC_SECTOR_KEYS,
  store: PUBLIC_SECTOR_KEYS,
  profile: new Set([
    "displayName", "businessName", "name", "description", "bio", "logoUrl",
    "coverUrl", "coverImageUrl", "categories", "tags", "rating",
    "reviewCount", "reviewsCount", "specialties", "businessType", "type",
  ]),
  contact: new Set([
    "phone", "whatsapp", "city", "district", "address", "addressLine",
    "location", "instagram", "website",
  ]),
  verification: new Set(["level", "isVerified", "verifiedAt"]),
  profileContent: new Set([
    "displayName", "description", "bio", "specialties", "services", "workingHours",
    "workingHoursMap", "socialMedia", "clinicLogoUrl", "clinicPhotoUrls",
    "coverImageUrl", "photos", "images", "gallery", "logoUrl", "coverUrl",
  ]),
  content: new Set([
    "displayName", "description", "bio", "photos", "images", "gallery", "logoUrl",
    "coverUrl",
  ]),
  media: new Set(["photos", "images", "gallery", "logoUrl", "coverUrl", "coverImage"]),
  operationalDetails: new Set([
    "isOpen", "isAvailable", "available", "workingHours", "workingHoursMap",
    "capacity", "maxCapacity",
  ]),
  socialMedia: new Set(["instagram", "website"]),
  vehicle: new Set([
    "plateNumber", "vehicleType", "model", "brand", "color", "year",
  ]),
  driver: new Set(["fullName", "name", "photoUrl"]),
  currentLocation: new Set(["lat", "lng", "source", "updatedAt"]),
  location: new Set(["lat", "lng"]),
  workingHoursMap: new Set(["open", "close", "isOpen", "start", "end", "value"]),
  services: new Set([
    "displayName", "name", "title", "description", "offeredServices", "services",
    "price", "priceRange", "pricing", "duration", "durationMin", "currency",
    "isActive", "sortOrder", "categories", "tags",
  ]),
  serviceCatalog: new Set([
    "displayName", "name", "title", "description", "price", "priceRange",
    "pricing", "duration", "durationMin", "currency", "isActive", "sortOrder",
  ]),
  pricing: new Set(["amount", "currency", "unit", "min", "max", "price"]),
  packages: new Set([
    "displayName", "name", "title", "description", "price", "priceRange",
    "pricing", "duration", "durationMin", "currency", "isActive", "sortOrder",
  ]),
  rooms: new Set([
    "displayName", "name", "title", "description", "capacity", "maxCapacity",
    "price", "priceRange", "pricing", "isActive", "sortOrder", "images",
  ]),
  preVisitForm: new Set([
    "enabled", "enabledServiceIds", "questions", "preVisitForms",
  ]),
  preVisitFormSettings: new Set([
    "enabled", "enabledServiceIds", "questions", "preVisitForms",
  ]),
  questions: new Set([
    "id", "title", "label", "type", "required", "options", "helpText",
  ]),
  availability: new Set([
    "isAvailable", "available", "online", "capacity", "maxCapacity", "rooms",
  ]),
  workingHours: new Set(["open", "close", "isOpen", "start", "end", "value"]),
};

const PRIVATE_KEY_PARTS = [
  "private",
  "secret",
  "password",
  "token",
  "iban",
  "payment",
  "bank",
  "legal",
  "tax",
  "mersis",
  "finance",
  "payout",
  "commission",
  "moderation",
  "risk",
  "internal",
  "staff",
  "patient",
  "medical",
  "document",
  "owner",
  "admin",
  "email",
  "uid",
];

function isPrivateKey(key) {
  const normalized = String(key).toLowerCase();
  return PRIVATE_KEY_PARTS.some((part) => normalized.includes(part));
}

function projectValue(value, { keys = PUBLIC_SECTOR_KEYS, allowDayKeys = false } = {}) {
  if (
    (admin.firestore.Timestamp && value instanceof admin.firestore.Timestamp) ||
    (admin.firestore.GeoPoint && value instanceof admin.firestore.GeoPoint) ||
    (admin.firestore.DocumentReference &&
      value instanceof admin.firestore.DocumentReference)
  ) {
    return value;
  }
  if (Array.isArray(value)) {
    return value.map((item) =>
      item && typeof item === "object"
        ? projectValue(item, { keys, allowDayKeys })
        : item
    );
  }
  if (!value || typeof value !== "object") return value;

  const result = {};
  for (const [key, child] of Object.entries(value)) {
    if (isPrivateKey(key)) continue;
    const allowed = keys.has(key) || (allowDayKeys && PUBLIC_DAY_KEYS.has(key));
    if (!allowed) continue;

    const childKeys = PUBLIC_MAP_SCHEMAS[key];
    if (child && typeof child === "object" && !Array.isArray(child) && !childKeys) {
      if (allowDayKeys && PUBLIC_DAY_KEYS.has(key)) {
        result[key] = projectValue(child, {
          keys: PUBLIC_MAP_SCHEMAS.workingHours,
        });
      }
      continue;
    }
    result[key] = Array.isArray(child)
      ? child.map((item) =>
          item && typeof item === "object"
            ? projectValue(item, { keys: childKeys || PUBLIC_SECTOR_KEYS })
            : item
        )
      : child && typeof child === "object"
      ? projectValue(child, {
          keys: childKeys,
          allowDayKeys: key === "workingHours" || key === "workingHoursMap",
        })
      : child;
  }
  return result;
}

function pick(source, keys, options = {}) {
  const result = {};
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(source, key)) {
      const schema = PUBLIC_MAP_SCHEMAS[key];
      result[key] = projectValue(source[key], {
        keys: schema || options.keys || PUBLIC_SECTOR_KEYS,
        allowDayKeys: key === "workingHours" || key === "workingHoursMap",
      });
    }
  }
  return result;
}

function publicValuesEqual(left, right) {
  if (left === right) return true;
  if (left == null || right == null) return left == null && right == null;
  if (left instanceof admin.firestore.Timestamp && right instanceof admin.firestore.Timestamp) {
    return left.isEqual(right);
  }
  if (left instanceof admin.firestore.GeoPoint && right instanceof admin.firestore.GeoPoint) {
    return left.latitude === right.latitude && left.longitude === right.longitude;
  }
  if (Array.isArray(left) || Array.isArray(right)) {
    return Array.isArray(left) && Array.isArray(right) &&
      left.length === right.length && left.every((item, index) => publicValuesEqual(item, right[index]));
  }
  if (typeof left === "object" || typeof right === "object") {
    if (typeof left !== "object" || typeof right !== "object") return false;
    const leftKeys = Object.keys(left).filter((key) => key !== "sourceUpdatedAt");
    const rightKeys = Object.keys(right).filter((key) => key !== "sourceUpdatedAt");
    return leftKeys.length === rightKeys.length &&
      leftKeys.every((key) => Object.prototype.hasOwnProperty.call(right, key) && publicValuesEqual(left[key], right[key]));
  }
  return false;
}

function publicProjectionChanged(current, next) {
  return !publicValuesEqual(current || {}, next || {});
}

/*
 * The old implementation copied arbitrary keys after entering a known map.
 * Keep the projection intentionally schema-driven: a new public field must be
 * added to one of the allowlists above before it can leave the canonical doc.
 */

/* REMOVE legacy implementation below. */

function buildUserPublicProjection(userId, source = {}) {
  if (source.profileVisible === false) return null;
  return {
    ...pick(source, PUBLIC_USER_KEYS, { allowUnknownMapKeys: false }),
    uid: String(source.uid || userId),
    projectionVersion: 1,
    sourceUpdatedAt: source.updatedAt || null,
  };
}

const CANONICAL_SERVICES_SOURCE = "canonical";
const EMBEDDED_SERVICES_SOURCE = "embedded";

function buildBusinessPublicProjection(businessId, source = {}, serviceProjection = null) {
  const normalizedServices = normalizeServiceProjection(serviceProjection);
  const sourceWithServices = applyCanonicalServices(
    source,
    normalizedServices.services,
    normalizedServices.authoritative
  );
  const profile = pick(sourceWithServices.profile || {}, PUBLIC_PROFILE_KEYS, {
    allowUnknownMapKeys: false,
  });
  const contact = pick(sourceWithServices.contact || {}, PUBLIC_CONTACT_KEYS, {
    allowUnknownMapKeys: false,
  });
  const verification = pick(
    sourceWithServices.verification || {},
    PUBLIC_VERIFICATION_KEYS,
    { allowUnknownMapKeys: false }
  );
  const rawSectorData = filterSectorDataByCanonicalSectors(
    sourceWithServices.sectorData || {},
    sourceWithServices.sectors
  );
  const publicSectorData = {};
  if (rawSectorData && typeof rawSectorData === "object") {
    for (const [sector, value] of Object.entries(rawSectorData)) {
      if (!value || typeof value !== "object") continue;
      publicSectorData[sector] = projectValue(value, {
        allowUnknownMapKeys: false,
      });
    }
  }

  const projection = {
    ...pick(sourceWithServices, PUBLIC_BUSINESS_KEYS, { allowUnknownMapKeys: false }),
    businessId: String(sourceWithServices.businessId || businessId),
    profile,
    contact,
    verification,
    publicSectorData,
    projectionVersion: 1,
    sourceUpdatedAt: sourceWithServices.updatedAt || null,
  };
  if (normalizedServices.authoritative) {
    projection.projectionMetadata = {
      servicesSource: CANONICAL_SERVICES_SOURCE,
    };
  } else if (normalizedServices.source === EMBEDDED_SERVICES_SOURCE) {
    projection.projectionMetadata = {
      servicesSource: EMBEDDED_SERVICES_SOURCE,
    };
  }
  return projection;
}

function normalizeServiceProjection(serviceProjection) {
  if (Array.isArray(serviceProjection)) {
    return {
      services: serviceProjection,
      authoritative: serviceProjection.length > 0,
      source: serviceProjection.length > 0 ? CANONICAL_SERVICES_SOURCE : null,
    };
  }
  if (!serviceProjection || typeof serviceProjection !== "object") {
    return { services: null, authoritative: false, source: null };
  }
  return {
    services: Array.isArray(serviceProjection.services)
      ? serviceProjection.services
      : null,
    authoritative: serviceProjection.authoritative === true,
    source: serviceProjection.source || null,
  };
}

function applyCanonicalServices(source, canonicalServices, authoritative) {
  if (!authoritative || !Array.isArray(canonicalServices)) {
    return source;
  }

  const sectorData = source.sectorData;
  if (!sectorData || typeof sectorData !== "object") return source;

  const nextSectorData = { ...sectorData };
  for (const [sector, value] of Object.entries(sectorData)) {
    if (!value || typeof value !== "object" || Array.isArray(value)) continue;
    if (
      !("services" in value) &&
      !["vet", "veterinary", "veterinarian", "groomy", "groomer", "grooming"].includes(sector)
    ) continue;
    nextSectorData[sector] = { ...value, services: canonicalServices };
  }

  return { ...source, sectorData: nextSectorData };
}

async function loadCanonicalServices(database, businessId) {
  const snapshot = await database
    .collection("businesses")
    .doc(businessId)
    .collection("services")
    .get();
  return {
    services: snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })),
    hasDocuments: !snapshot.empty,
  };
}

async function synchronizeUserPublicProjection(event, firestore) {
  const database = firestore || admin.firestore();
  const userId = String(event.params.userId);
  const ref = database.collection("users_public").doc(userId);
  const after = event.data?.after;
  if (!after || !after.exists || after.data()?.profileVisible === false) {
    if ((await ref.get()).exists) await ref.delete();
    return;
  }
  const next = buildUserPublicProjection(userId, after.data() || {});
  const current = await ref.get();
  if (!current.exists || publicProjectionChanged(current.data(), next)) {
    await ref.set(next);
  }
}

async function synchronizeBusinessPublicProjection(event, firestore) {
  const database = firestore || admin.firestore();
  const businessId = String(event.params.businessId);
  const ref = database.collection("businesses_public").doc(businessId);
  const after = event.params.serviceId
    ? await database.collection("businesses").doc(businessId).get()
    : event.data?.after;
  const businessData = after?.data() || {};
  // `published` was introduced after existing approved businesses were
  // created. Missing is therefore the legacy public value for every sector
  // except Pet Taxi, which was intentionally introduced as unpublished.
  const isPetTaxi = isPetTaxiBusiness(businessData);
  const isPublished = businessData.published === true ||
    (businessData.published == null && !isPetTaxi);
  if (!after || !after.exists || businessData.status !== "approved" || !isPublished) {
    if ((await ref.get()).exists) await ref.delete();
    return;
  }
  const current = await ref.get();
  const currentData = current.exists ? current.data() || {} : {};
  const canonicalServices = await loadCanonicalServices(database, businessId);
  const serviceAuthority = resolveServiceAuthority({
    event,
    currentProjection: currentData,
    canonicalServices,
    source: after.data() || {},
  });
  const next = buildBusinessPublicProjection(
    businessId,
    after.data() || {},
    serviceAuthority
  );
  if (!current.exists || publicProjectionChanged(current.data(), next)) {
    await ref.set(next);
  }
}

function resolveServiceAuthority({ event, currentProjection, canonicalServices, source }) {
  if (canonicalServices.hasDocuments || event.params.serviceId) {
    return {
      services: canonicalServices.services,
      authoritative: true,
      source: CANONICAL_SERVICES_SOURCE,
    };
  }
  const previousSource = currentProjection?.projectionMetadata?.servicesSource;
  if (previousSource === CANONICAL_SERVICES_SOURCE) {
    return {
      services: [],
      authoritative: true,
      source: CANONICAL_SERVICES_SOURCE,
    };
  }
  if (previousSource === EMBEDDED_SERVICES_SOURCE) {
    return { services: null, authoritative: false, source: EMBEDDED_SERVICES_SOURCE };
  }
  return {
    services: null,
    authoritative: false,
    source: hasEmbeddedServices(source)
      ? EMBEDDED_SERVICES_SOURCE
      : null,
  };
}

function hasEmbeddedServices(source) {
  const sectorData = source?.sectorData;
  if (!sectorData || typeof sectorData !== "object") return false;
  return Object.values(sectorData).some(
    (sector) => sector && typeof sector === "object" && Array.isArray(sector.services)
  );
}

module.exports = {
  buildUserPublicProjection,
  buildBusinessPublicProjection,
  publicProjectionChanged,
  loadCanonicalServices,
  resolveServiceAuthority,
  synchronizeUserPublicProjection,
  synchronizeBusinessPublicProjection,
};
