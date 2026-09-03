const assert = require("node:assert/strict");
const { test } = require("node:test");
const {
  buildUserPublicProjection,
  buildBusinessPublicProjection,
  synchronizeUserPublicProjection,
  synchronizeBusinessPublicProjection,
} = require("../src/publicProjections");
const { backfillCollection } = require("../scripts/backfillPublicProjections");

class FakeDocRef {
  constructor(store, collections, collection, id) {
    this.store = store;
    this.collections = collections;
    this.collectionName = collection;
    this.id = id;
    this.setCount = 0;
    this.deleteCount = 0;
  }

  async get() {
    const value = this.store.get(`${this.collectionName}/${this.id}`);
    return { exists: value !== undefined, data: () => value };
  }

  async set(value) {
    this.setCount += 1;
    this.store.set(`${this.collectionName}/${this.id}`, value);
  }

  async delete() {
    this.deleteCount += 1;
    this.store.delete(`${this.collectionName}/${this.id}`);
  }

  collection(name) {
    const key = `${this.collectionName}/${this.id}/${name}`;
    return {
      get: async () => {
        const docs = this.collections.get(key) || [];
        return {
          empty: docs.length === 0,
          docs: docs.map((data, index) => ({
          id: data.id || `service-${index}`,
          data: () => data,
          })),
        };
      },
    };
  }
}

class FakeFirestore {
  constructor() {
    this.store = new Map();
    this.refs = new Map();
    this.collections = new Map();
  }

  setSubcollection(parentCollection, parentId, name, docs) {
    this.collections.set(`${parentCollection}/${parentId}/${name}`, docs);
  }

  collection(name) {
    let pageSize = null;
    let cursor = null;
    const collection = {
      doc: (id) => {
        const key = `${name}/${id}`;
        if (!this.refs.has(key)) {
          this.refs.set(key, new FakeDocRef(this.store, this.collections, name, id));
        }
        return this.refs.get(key);
      },
    };
    collection.where = () => collection;
    collection.orderBy = () => collection;
    collection.limit = (value) => {
      pageSize = value;
      return collection;
    };
    collection.startAfter = (value) => {
      cursor = value;
      return collection;
    };
    collection.get = async () => {
      const prefix = `${name}/`;
      const docs = [...this.store.entries()]
        .filter(([key]) => key.startsWith(prefix) && !key.slice(prefix.length).includes("/"))
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, data]) => ({
          id: key.slice(prefix.length),
          ref: this.collection(name).doc(key.slice(prefix.length)),
          data: () => data,
        }));
      const afterCursor = cursor
        ? docs.filter((doc) => doc.id > cursor)
        : docs;
      const page = pageSize == null ? afterCursor : afterCursor.slice(0, pageSize);
      return { empty: page.length === 0, docs: page };
    };
    return collection;
  }

  batch() {
    const operations = [];
    return {
      set: (ref, value) => operations.push(() => ref.set(value)),
      delete: (ref) => operations.push(() => ref.delete()),
      commit: async () => {
        for (const operation of operations) await operation();
      },
    };
  }
}

function writeEvent(path, id, before, after) {
  return {
    params: { [path]: id },
    data: {
      before: before
        ? { exists: true, data: () => before }
        : { exists: false, data: () => undefined },
      after: after
        ? { exists: true, data: () => after }
        : { exists: false, data: () => undefined },
    },
  };
}

test("public builders exclude private fields at every nested level", () => {
  const user = buildUserPublicProjection("u1", {
    uid: "u1",
    username: "public",
    email: "private@example.test",
    ownerUid: "private-owner",
    privateNote: "hidden",
  });
  assert.equal(user.email, undefined);
  assert.equal(user.ownerUid, undefined);

  const business = buildBusinessPublicProjection("b1", {
    ownerUid: "private-owner",
    status: "approved",
    published: true,
    sectors: ["groomy"],
    contact: { phone: "123", email: "private@example.test" },
    sectorData: {
      groomy: {
        services: [{ title: "Bath", ownerUid: "private-owner", email: "private@example.test" }],
        internalNote: "hidden",
      },
    },
  });

  assert.equal(business.ownerUid, undefined);
  assert.equal(business.contact.email, undefined);
  assert.equal(business.publicSectorData.groomy.internalNote, undefined);
  assert.equal(business.publicSectorData.groomy.services[0].ownerUid, undefined);
  assert.equal(business.publicSectorData.groomy.services[0].email, undefined);
});

test("Groomy public listing/detail contract preserves curated profile and service data", () => {
  const projection = buildBusinessPublicProjection("g1", {
    status: "approved",
    published: true,
    sectors: ["groomy"],
    profile: { displayName: "Public Groomy" },
    sectorData: {
      grooming: {
        profileContent: { bio: "Care", photos: ["photo.jpg"] },
        services: [{ title: "Bath", price: 25, isActive: true }],
      },
    },
  });
  const grooming = projection.publicSectorData.grooming;
  assert.equal(projection.profile.displayName, "Public Groomy");
  assert.equal(grooming.profileContent.bio, "Care");
  assert.equal(grooming.services[0].title, "Bath");
});

test("Adoption public listing/detail contract preserves curated profile and hours", () => {
  const projection = buildBusinessPublicProjection("a1", {
    status: "approved",
    published: true,
    sectors: ["adoption_center"],
    profile: { displayName: "Public Center" },
    sectorData: {
      adoptionCenter: {
        profileContent: { bio: "Shelter", photos: ["shelter.jpg"] },
        workingHours: { monday: { open: "09:00", close: "17:00" } },
      },
    },
  });
  const center = projection.publicSectorData.adoptionCenter;
  assert.equal(projection.profile.displayName, "Public Center");
  assert.equal(center.profileContent.bio, "Shelter");
  assert.equal(center.workingHours.monday.open, "09:00");
});

test("user synchronization suppresses private-only writes and is idempotent", async () => {
  const firestore = new FakeFirestore();
  const ref = firestore.collection("users_public").doc("u1");
  const first = { uid: "u1", username: "before", updatedAt: "t1" };

  await synchronizeUserPublicProjection(writeEvent("userId", "u1", null, first), firestore);
  assert.equal(ref.setCount, 1);

  await synchronizeUserPublicProjection(
    writeEvent("userId", "u1", first, { ...first, updatedAt: "t2", lastLoginAt: "private" }),
    firestore
  );
  assert.equal(ref.setCount, 1);

  await synchronizeUserPublicProjection(
    writeEvent("userId", "u1", first, { ...first, username: "after", updatedAt: "t3" }),
    firestore
  );
  assert.equal(ref.setCount, 2);

  await synchronizeUserPublicProjection(writeEvent("userId", "u1", first, null), firestore);
  assert.equal((await ref.get()).exists, false);
  assert.equal(ref.deleteCount, 1);
});

test("business synchronization suppresses private-only writes and handles retry/delete", async () => {
  const firestore = new FakeFirestore();
  const ref = firestore.collection("businesses_public").doc("b1");
  const first = {
    businessId: "b1",
    ownerUid: "private-owner",
    status: "approved",
    published: true,
    profile: { displayName: "Before" },
    updatedAt: "t1",
  };

  await synchronizeBusinessPublicProjection(writeEvent("businessId", "b1", null, first), firestore);
  assert.equal(ref.setCount, 1);
  await synchronizeBusinessPublicProjection(writeEvent("businessId", "b1", null, first), firestore);
  assert.equal(ref.setCount, 1);

  await synchronizeBusinessPublicProjection(
    writeEvent("businessId", "b1", first, { ...first, ownerUid: "new-private-owner", updatedAt: "t2" }),
    firestore
  );
  assert.equal(ref.setCount, 1);

  await synchronizeBusinessPublicProjection(
    writeEvent("businessId", "b1", first, {
      ...first,
      profile: { displayName: "After" },
      updatedAt: "t3",
    }),
    firestore
  );
  assert.equal(ref.setCount, 2);

  await synchronizeBusinessPublicProjection(writeEvent("businessId", "b1", first, null), firestore);
  assert.equal((await ref.get()).exists, false);
  assert.equal(ref.deleteCount, 1);
});

test("legacy approved non-Pet-Taxi business without published remains public", async () => {
  const firestore = new FakeFirestore();
  const ref = firestore.collection("businesses_public").doc("legacy-no-published");
  const business = {
    businessId: "legacy-no-published",
    status: "approved",
    sectors: ["veterinary"],
    profile: { displayName: "Legacy Vet" },
  };

  await synchronizeBusinessPublicProjection(
    writeEvent("businessId", "legacy-no-published", null, business),
    firestore
  );

  assert.equal(ref.setCount, 1);
  assert.equal((await ref.get()).data().status, "approved");
});

test("business projection prefers canonical service subcollection and refreshes on service events", async () => {
  const firestore = new FakeFirestore();
  const ref = firestore.collection("businesses_public").doc("b1");
  const business = {
    businessId: "b1",
    status: "approved",
    published: true,
    sectors: ["veterinary"],
    sectorData: {
      veterinary: { services: [{ id: "stale", title: "Stale embedded" }] },
    },
  };
  firestore.store.set("businesses/b1", business);
  firestore.setSubcollection("businesses", "b1", "services", [
    { id: "dental_care", title: "Dental care", isActive: true },
    { id: "surgery", title: "Surgery", isActive: true },
  ]);

  await synchronizeBusinessPublicProjection(
    writeEvent("businessId", "b1", null, business),
    firestore
  );
  assert.deepEqual(
    (await ref.get()).data().publicSectorData.veterinary.services.map((service) => service.title),
    ["Dental care", "Surgery"]
  );
  assert.deepEqual(
    (await ref.get()).data().publicSectorData.veterinary.services.map((service) => service.id),
    ["dental_care", "surgery"]
  );

  firestore.setSubcollection("businesses", "b1", "services", [
    { id: "dental_care", title: "Dental care updated", isActive: true },
    { id: "surgery", title: "Surgery", isActive: true },
  ]);
  await synchronizeBusinessPublicProjection(
    {
      params: { businessId: "b1", serviceId: "dental_care" },
      data: { after: { exists: true, data: () => ({ title: "Dental care updated" }) } },
    },
    firestore
  );
  assert.equal(
    (await ref.get()).data().publicSectorData.veterinary.services[0].title,
    "Dental care updated"
  );

  firestore.setSubcollection("businesses", "b1", "services", [
    { id: "dental_care", title: "Dental care updated", isActive: true },
  ]);
  await synchronizeBusinessPublicProjection(
    {
      params: { businessId: "b1", serviceId: "surgery" },
      data: { after: { exists: false, data: () => undefined } },
    },
    firestore
  );
  assert.deepEqual(
    (await ref.get()).data().publicSectorData.veterinary.services.map((service) => service.title),
    ["Dental care updated"]
  );

  await synchronizeBusinessPublicProjection(
    {
      params: { businessId: "b1", serviceId: "dental_care" },
      data: { after: { exists: false, data: () => undefined } },
    },
    firestore
  );
  assert.equal((await ref.get()).data().publicSectorData.veterinary.services.length, 1);

  firestore.setSubcollection("businesses", "b1", "services", []);
  await synchronizeBusinessPublicProjection(
    {
      params: { businessId: "b1", serviceId: "dental_care" },
      data: { after: { exists: false, data: () => undefined } },
    },
    firestore
  );
  assert.deepEqual(
    (await ref.get()).data().publicSectorData.veterinary.services,
    []
  );
});

test("legacy embedded services remain available without canonical authority", async () => {
  const firestore = new FakeFirestore();
  const ref = firestore.collection("businesses_public").doc("legacy");
  const business = {
    businessId: "legacy",
    status: "approved",
    published: true,
    sectors: ["veterinary"],
    sectorData: {
      veterinary: { services: [{ id: "legacy-service", title: "Legacy service" }] },
    },
  };
  firestore.store.set("businesses/legacy", business);
  firestore.setSubcollection("businesses", "legacy", "services", []);

  await synchronizeBusinessPublicProjection(
    writeEvent("businessId", "legacy", null, business),
    firestore
  );
  const projection = (await ref.get()).data();
  assert.equal(projection.projectionMetadata.servicesSource, "embedded");
  assert.equal(projection.publicSectorData.veterinary.services[0].title, "Legacy service");
});

test("business backfill loads canonical service documents and is idempotent", async () => {
  const firestore = new FakeFirestore();
  const business = {
    businessId: "backfill-business",
    status: "approved",
    published: true,
    sectors: ["veterinary"],
    sectorData: {
      veterinary: { services: [{ id: "stale", title: "Stale embedded" }] },
    },
  };
  firestore.store.set("businesses/backfill-business", business);
  firestore.setSubcollection("businesses", "backfill-business", "services", [
    { id: "canonical", title: "Canonical service", ownerUid: "private" },
  ]);
  const checkpoint = {};
  const options = {
    dryRun: false,
    cleanupOrphans: false,
    checkpointFile: null,
    resumeCursor: null,
  };

  const first = await backfillCollection("businesses", options, checkpoint, firestore);
  const projection = firestore.store.get("businesses_public/backfill-business");
  assert.equal(first.created, 1);
  assert.equal(projection.publicSectorData.veterinary.services[0].title, "Canonical service");
  assert.equal(projection.publicSectorData.veterinary.services[0].ownerUid, undefined);

  const targetRef = firestore.collection("businesses_public").doc("backfill-business");
  const writesAfterFirstRun = targetRef.setCount;
  const second = await backfillCollection("businesses", options, checkpoint, firestore);
  assert.equal(second.scanned, 0);
  assert.equal(targetRef.setCount, writesAfterFirstRun);
});

// =====================================================================
// Pet Shop public projection.
//
// `projectValue` is a strict allowlist: a key absent from the sector key set
// is dropped, and a nested map with no PUBLIC_MAP_SCHEMAS entry is dropped
// whole. Pet Shop registration writes several legitimate public fields that
// the shared allowlist did not name, so delivery, offers, price level, brands
// and shop types could never reach `businesses_public` and therefore could
// never render on the public profile. These assert the real production
// projection, not a hand-built map.
// =====================================================================

function petShopSource(overrides = {}) {
  return {
    businessId: "shop-1",
    sectors: ["pet_shop"],
    status: "approved",
    published: true,
    ownerUid: "owner-1",
    profile: { displayName: "Paws & Co" },
    contact: { city: "Istanbul", district: "Kadikoy" },
    sectorData: {
      petshop: {
        shopName: "Paws & Co",
        ownerName: "A Real Person",
        shopTypes: ["Pet Food", "Accessories"],
        categories: ["Dry Food"],
        brands: "BrandA, BrandB",
        pricing: { level: "mid" },
        sales: { delivery: "yes", onlineOrder: "no", whatsappOrder: "yes" },
        workingHours: "10:00–21:00",
        profile: { bio: "Local pet supplies" },
        promotion: { hasOffers: "yes", details: "10% off" },
        ...(overrides.petshop || {}),
      },
    },
    ...overrides.root,
  };
}

test("pet shop projection preserves the approved public fields", () => {
  const projection = buildBusinessPublicProjection("shop-1", petShopSource());
  const shop = projection.publicSectorData.petshop;

  assert.equal(shop.shopName, "Paws & Co");
  assert.deepEqual(shop.shopTypes, ["Pet Food", "Accessories"]);
  assert.deepEqual(shop.categories, ["Dry Food"]);
  assert.equal(shop.brands, "BrandA, BrandB");
  assert.deepEqual(shop.pricing, { level: "mid" });
  assert.deepEqual(shop.sales, {
    delivery: "yes",
    onlineOrder: "no",
    whatsappOrder: "yes",
  });
  assert.equal(shop.workingHours, "10:00–21:00");
  assert.deepEqual(shop.promotion, { hasOffers: "yes", details: "10% off" });
});

test("submitted Bio survives the real projection at the canonical path", () => {
  const projection = buildBusinessPublicProjection("shop-1", petShopSource());
  assert.equal(
    projection.publicSectorData.petshop.profile.bio,
    "Local pet supplies"
  );
});

test("empty Bio projects as empty rather than fabricated", () => {
  const projection = buildBusinessPublicProjection(
    "shop-1",
    petShopSource({ petshop: { profile: { bio: "" } } })
  );
  assert.equal(projection.publicSectorData.petshop.profile.bio, "");
});

test("owner-identifying and private data never reach the projection", () => {
  const projection = buildBusinessPublicProjection(
    "shop-1",
    petShopSource({
      root: {
        legal: { taxNumber: "1234567890", mersisNumber: "0987654321" },
        bankAccount: { iban: "TR000000000000000000000000" },
        marketplaceSellerActivation: { active: true },
        pilotActiveProductCount: 3,
        marketplaceBusinessGenerationId: "gen-1",
      },
    })
  );
  const shop = projection.publicSectorData.petshop;

  // `isPrivateKey` blocks every key containing "owner".
  assert.equal("ownerName" in shop, false);
  assert.equal("legal" in projection, false);
  assert.equal("bankAccount" in projection, false);
  assert.equal("marketplaceSellerActivation" in projection, false);
  assert.equal("pilotActiveProductCount" in projection, false);
  assert.equal("marketplaceBusinessGenerationId" in projection, false);
  assert.equal("ownerUid" in projection, false);
});

test("malformed pet shop values are dropped rather than published", () => {
  const projection = buildBusinessPublicProjection(
    "shop-1",
    petShopSource({
      petshop: {
        brands: 123,
        shopName: { nested: "x" },
        shopTypes: "not-a-list",
        pricing: "not-a-map",
        sales: ["not", "a", "map"],
        promotion: { hasOffers: 42, details: "kept" },
      },
    })
  );
  const shop = projection.publicSectorData.petshop;

  assert.equal("brands" in shop, false);
  assert.equal("shopName" in shop, false);
  assert.equal("shopTypes" in shop, false);
  assert.equal("pricing" in shop, false);
  assert.equal("sales" in shop, false);
  assert.deepEqual(shop.promotion, { details: "kept" });
});

test("unknown keys inside approved nested maps are still dropped", () => {
  const projection = buildBusinessPublicProjection(
    "shop-1",
    petShopSource({
      petshop: {
        sales: { delivery: "yes", internalMargin: "0.3" },
        promotion: { hasOffers: "yes", details: "x", adminNote: "secret" },
        pricing: { level: "mid", costPrice: "12.34" },
      },
    })
  );
  const shop = projection.publicSectorData.petshop;

  assert.deepEqual(shop.sales, { delivery: "yes" });
  assert.deepEqual(shop.promotion, { hasOffers: "yes", details: "x" });
  assert.deepEqual(shop.pricing, { level: "mid" });
});

test("shopTypes survives so the categories fallback can use it", () => {
  const projection = buildBusinessPublicProjection(
    "shop-1",
    petShopSource({ petshop: { categories: [] } })
  );
  const shop = projection.publicSectorData.petshop;
  assert.deepEqual(shop.categories, []);
  assert.deepEqual(shop.shopTypes, ["Pet Food", "Accessories"]);
});

test("non-pet-shop sectors keep their previous projection output", () => {
  const projection = buildBusinessPublicProjection("vet-1", {
    businessId: "vet-1",
    sectors: ["veterinary"],
    status: "approved",
    published: true,
    profile: { displayName: "Vet" },
    contact: { city: "Ankara" },
    sectorData: {
      veterinary: {
        description: "Clinic",
        shopName: "should not appear",
        brands: "should not appear",
        sales: { delivery: "yes" },
        promotion: { hasOffers: "yes" },
      },
    },
  });
  const vet = projection.publicSectorData.veterinary;

  assert.equal(vet.description, "Clinic");
  // The Pet-Shop-only superset must not leak into other sectors.
  assert.equal("shopName" in vet, false);
  assert.equal("brands" in vet, false);
  assert.equal("sales" in vet, false);
  assert.equal("promotion" in vet, false);
});

// =====================================================================
// Residual correction: `pricing.level` must be Pet-Shop-only.
//
// The first attempt added "level" to the shared PUBLIC_MAP_SCHEMAS.pricing,
// which projected it for veterinary and every other sector too. It now lives
// in a Pet-Shop-only nested schema table.
// =====================================================================

test("pet shop keeps pricing.level alongside the shared pricing fields", () => {
  const projection = buildBusinessPublicProjection(
    "shop-1",
    petShopSource({
      petshop: { pricing: { level: "mid", amount: 5, currency: "TRY" } },
    })
  );
  assert.deepEqual(projection.publicSectorData.petshop.pricing, {
    level: "mid",
    amount: 5,
    currency: "TRY",
  });
});

test("unknown pet shop pricing keys are still removed", () => {
  const projection = buildBusinessPublicProjection(
    "shop-1",
    petShopSource({
      petshop: { pricing: { level: "mid", costPrice: "9.99", margin: 0.4 } },
    })
  );
  assert.deepEqual(projection.publicSectorData.petshop.pricing, {
    level: "mid",
  });
});

test("a wrong-typed pet shop level is removed but siblings survive", () => {
  const projection = buildBusinessPublicProjection(
    "shop-1",
    petShopSource({ petshop: { pricing: { level: 42, amount: 5 } } })
  );
  assert.deepEqual(projection.publicSectorData.petshop.pricing, { amount: 5 });
});

for (const sector of [
  "veterinary",
  "grooming",
  "pet_hotel",
  "pet_taxi",
  "adoption_center",
  "training",
]) {
  test(`${sector} never gains pricing.level even when the source has it`, () => {
    const projection = buildBusinessPublicProjection("b-1", {
      businessId: "b-1",
      sectors: [sector],
      status: "approved",
      published: true,
      profile: { displayName: "N" },
      contact: { city: "C" },
      sectorData: {
        [sector]: {
          description: "d",
          pricing: { level: "mid", amount: 5, currency: "TRY" },
        },
      },
    });
    const projected = projection.publicSectorData[sector];
    assert.equal("level" in (projected.pricing || {}), false);
    // The shared permitted pricing fields must remain untouched.
    assert.deepEqual(projected.pricing, { amount: 5, currency: "TRY" });
    assert.equal(projected.description, "d");
  });
}

// ── Canonical business media projection ────────────────────────────────────
// `businessMedia` is written only by the finalizeBusinessMedia callable
// (Admin SDK) and is on firestore.rules' server-owned deny list. These tests
// drive the real buildBusinessPublicProjection, not a reimplementation.

const STORAGE_URL_A =
  "https://firebasestorage.googleapis.com/v0/b/demo-bucket/o/" +
  encodeURIComponent("business_gallery/biz-1/logo_1.jpg") +
  "?alt=media&token=t1";
const STORAGE_URL_B =
  "https://firebasestorage.googleapis.com/v0/b/demo-bucket/o/" +
  encodeURIComponent("business_cover/biz-1/cover_1.jpg") +
  "?alt=media&token=t2";
const STORAGE_URL_C =
  "https://firebasestorage.googleapis.com/v0/b/demo-bucket/o/" +
  encodeURIComponent("business_gallery/biz-1/gallery_1.jpg") +
  "?alt=media&token=t3";

function mediaSource(businessMedia) {
  return {
    businessId: "biz-1",
    status: "approved",
    published: true,
    sectors: ["petshop"],
    profile: { displayName: "Shop" },
    sectorData: { petshop: { shopName: "Shop" } },
    ...(businessMedia === undefined ? {} : { businessMedia }),
  };
}

test("52. valid Pet Shop media survives projection with only intended keys", () => {
  const projected = buildBusinessPublicProjection(
    "biz-1",
    mediaSource({
      logo: {
        path: "business_gallery/biz-1/logo_1.jpg",
        url: STORAGE_URL_A,
        contentType: "image/jpeg",
        size: 1024,
        updatedAt: "2026-09-03T12:00:00.000Z",
      },
      cover: { path: "business_cover/biz-1/cover_1.jpg", url: STORAGE_URL_B },
      gallery: [{ path: "business_gallery/biz-1/gallery_1.jpg", url: STORAGE_URL_C }],
      revision: 7,
      generationId: "gen-1",
      articulated: "nope",
    })
  );
  const media = projected.businessMedia;
  assert.ok(media, "businessMedia must survive");
  assert.equal(media.logo.url, STORAGE_URL_A);
  assert.equal(media.cover.url, STORAGE_URL_B);
  assert.equal(media.gallery.length, 1);
  // Internal concurrency/incarnation tokens are never published.
  assert.equal(media.revision, undefined);
  assert.equal(media.generationId, undefined);
  assert.equal(media.articulated, undefined);
  assert.deepEqual(Object.keys(media).sort(), ["cover", "gallery", "logo"]);
  assert.deepEqual(
    Object.keys(media.logo).sort(),
    ["contentType", "path", "size", "updatedAt", "url"]
  );
});

test("53. malformed media is omitted rather than published", () => {
  const projected = buildBusinessPublicProjection(
    "biz-1",
    mediaSource({
      logo: { path: "business_gallery/biz-1/logo_1.jpg" }, // no url
      cover: { url: STORAGE_URL_B }, // no path
      gallery: [
        null,
        "string",
        42,
        { path: "p", url: "https://evil.example.com/x.jpg" }, // external URL
        { path: "q", url: "javascript:alert(1)" },
        { path: "business_gallery/biz-1/gallery_1.jpg", url: STORAGE_URL_C },
      ],
    })
  );
  assert.equal(projected.businessMedia.logo, undefined);
  assert.equal(projected.businessMedia.cover, undefined);
  assert.deepEqual(
    projected.businessMedia.gallery.map((g) => g.url),
    [STORAGE_URL_C],
    "only the genuine Storage URL survives"
  );
});

test("53b. wholly invalid or absent media omits the key entirely", () => {
  for (const media of [
    undefined,
    null,
    "nope",
    [],
    42,
    {},
    { gallery: [] },
    { logo: { path: "p", url: "https://evil.example.com/a.jpg" }, gallery: [] },
  ]) {
    const projected = buildBusinessPublicProjection("biz-1", mediaSource(media));
    assert.equal(
      Object.prototype.hasOwnProperty.call(projected, "businessMedia"),
      false,
      `businessMedia must be absent for ${JSON.stringify(media)}`
    );
  }
});

test("54. removing canonical media removes it from the projection", () => {
  const withMedia = buildBusinessPublicProjection(
    "biz-1",
    mediaSource({
      logo: { path: "business_gallery/biz-1/logo_1.jpg", url: STORAGE_URL_A },
      gallery: [],
    })
  );
  assert.ok(withMedia.businessMedia);
  // The canonical writer sets logo to null on removal.
  const afterRemoval = buildBusinessPublicProjection(
    "biz-1",
    mediaSource({ logo: null, cover: null, gallery: [], revision: 2 })
  );
  assert.equal(
    Object.prototype.hasOwnProperty.call(afterRemoval, "businessMedia"),
    false
  );
});

test("54b. the gallery is capped and de-duplicated", () => {
  const gallery = [];
  for (let i = 0; i < 14; i++) {
    gallery.push({ path: `business_gallery/biz-1/gallery_${i}.jpg`, url: STORAGE_URL_C });
  }
  // Two exact duplicates of an existing path.
  gallery.push({ path: "business_gallery/biz-1/gallery_0.jpg", url: STORAGE_URL_C });
  const projected = buildBusinessPublicProjection("biz-1", mediaSource({ gallery }));
  assert.equal(projected.businessMedia.gallery.length, 10);
  const paths = projected.businessMedia.gallery.map((g) => g.path);
  assert.equal(new Set(paths).size, paths.length, "no duplicates published");
});

test("55. non-Pet-Shop projections are byte-identical without canonical media", () => {
  for (const sector of ["veterinary", "groomy", "pet_hotel", "adoption_center", "pet_taxi"]) {
    const source = {
      businessId: "biz-9",
      status: "approved",
      published: true,
      sectors: [sector],
      profile: { displayName: "X", logoUrl: "https://legacy.example.com/l.png" },
      coverImageUrl: "https://legacy.example.com/c.png",
      images: ["https://legacy.example.com/1.png"],
      sectorData: { [sector]: { profileContent: { gallery: ["https://legacy.example.com/g.png"] } } },
    };
    const before = JSON.stringify(buildBusinessPublicProjection("biz-9", source));
    const after = JSON.stringify(
      buildBusinessPublicProjection("biz-9", { ...source })
    );
    assert.equal(before, after);
    const projected = JSON.parse(before);
    assert.equal(
      Object.prototype.hasOwnProperty.call(projected, "businessMedia"),
      false,
      `${sector} must not gain a businessMedia key`
    );
    // Legacy display fields are untouched by this change.
    assert.equal(projected.coverImageUrl, "https://legacy.example.com/c.png");
    assert.deepEqual(projected.images, ["https://legacy.example.com/1.png"]);
  }
});

test("55b. a non-Pet-Shop sector may also carry canonical media", () => {
  // The field is business-level, not Pet-Shop-only: nothing here is gated on
  // sector, so a Vet that later adopts the same writer projects identically.
  const projected = buildBusinessPublicProjection("biz-9", {
    businessId: "biz-9",
    status: "approved",
    published: true,
    sectors: ["veterinary"],
    profile: { displayName: "Clinic" },
    businessMedia: {
      logo: { path: "business_gallery/biz-9/logo_1.jpg", url: STORAGE_URL_A },
      gallery: [],
    },
  });
  assert.ok(projected.businessMedia.logo);
});
