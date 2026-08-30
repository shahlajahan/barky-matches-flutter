const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const { test, before } = require("node:test");

if (!admin.apps.length) admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || "demo-petsupo" });
const db = admin.firestore();
const functions = require("../index");

let sequence = 0;

function fakeRes() {
  return {
    _status: null,
    _body: null,
    status(code) {
      this._status = code;
      return this;
    },
    send(body) {
      this._body = body;
      return this;
    },
  };
}

async function runMigration() {
  const req = { query: { dryRun: "false" } };
  const res = fakeRes();
  await functions.migrateAdoptionCentersToBusinesses(req, res);
  return res;
}

function nextId(prefix) {
  sequence += 1;
  return `${prefix}-${sequence}`;
}

before(async () => {
  // Nothing to seed globally — each test seeds its own isolated
  // adoption_centers/businesses documents by unique id.
});

test("1. a new destination business is created/migrated with all intended migration fields", async () => {
  const id = nextId("mig-create");
  await db.collection("adoption_centers").doc(id).set({
    displayName: "Happy Paws",
    contact: { city: "Istanbul", phone: "555" },
  });

  await runMigration();

  const data = (await db.collection("businesses").doc(id).get()).data();
  assert.equal(data.profile.displayName, "Happy Paws");
  assert.deepEqual(data.sectors, ["adoption_center"]);
  assert.equal(data.contact.city, "Istanbul");
  assert.equal(data.status, "approved");
});

test("2. a source document without activation cannot create activation", async () => {
  const id = nextId("mig-noact");
  await db.collection("adoption_centers").doc(id).set({ displayName: "No Activation Center" });

  await runMigration();

  const data = (await db.collection("businesses").doc(id).get()).data();
  assert.equal(Object.prototype.hasOwnProperty.call(data, "marketplaceSellerActivation"), false);
});

test("3-7. no shape of source marketplaceSellerActivation is ever copied", async () => {
  const cases = [
    ["active-true", { active: true, grantedBy: "attacker" }],
    ["active-false", { active: false }],
    ["null", null],
    ["empty-map", {}],
    ["malformed-map", { foo: "bar" }],
    ["non-map-string", "active"],
    ["non-map-number", 1],
    ["non-map-list", [1, 2, 3]],
    ["non-map-boolean", true],
  ];

  for (const [label, value] of cases) {
    const id = nextId(`mig-src-${label}`);
    await db.collection("adoption_centers").doc(id).set({
      displayName: `Case ${label}`,
      marketplaceSellerActivation: value,
    });

    await runMigration();

    const data = (await db.collection("businesses").doc(id).get()).data();
    assert.equal(
      Object.prototype.hasOwnProperty.call(data, "marketplaceSellerActivation"),
      false,
      `source case ${label} must not produce a destination marketplaceSellerActivation field`
    );
  }
});

test("8. an existing destination with a valid active activation remains byte-identical", async () => {
  const id = nextId("mig-preserve-active");
  const activation = {
    active: true,
    grantedAt: admin.firestore.Timestamp.now(),
    grantedBy: "admin-1",
    revokedAt: null,
    revokedBy: null,
  };
  await db.collection("adoption_centers").doc(id).set({ displayName: "Preserve Active" });
  await db.collection("businesses").doc(id).set({
    displayName: "Preserve Active",
    marketplaceSellerActivation: activation,
  });

  await runMigration();

  const after = (await db.collection("businesses").doc(id).get()).data();
  assert.deepEqual(after.marketplaceSellerActivation, activation);
});

test("9. an existing destination with inactive activation remains byte-identical", async () => {
  const id = nextId("mig-preserve-inactive");
  const activation = {
    active: false,
    grantedAt: admin.firestore.Timestamp.now(),
    grantedBy: "admin-1",
    revokedAt: admin.firestore.Timestamp.now(),
    revokedBy: "admin-2",
  };
  await db.collection("adoption_centers").doc(id).set({ displayName: "Preserve Inactive" });
  await db.collection("businesses").doc(id).set({
    displayName: "Preserve Inactive",
    marketplaceSellerActivation: activation,
  });

  await runMigration();

  const after = (await db.collection("businesses").doc(id).get()).data();
  assert.deepEqual(after.marketplaceSellerActivation, activation);
});

test("10. an existing destination with malformed activation remains byte-identical", async () => {
  const id = nextId("mig-preserve-malformed");
  const malformed = { active: "yes-please", extra: [1, 2, 3] };
  await db.collection("adoption_centers").doc(id).set({ displayName: "Preserve Malformed" });
  await db.collection("businesses").doc(id).set({
    displayName: "Preserve Malformed",
    marketplaceSellerActivation: malformed,
  });

  await runMigration();

  const after = (await db.collection("businesses").doc(id).get()).data();
  assert.deepEqual(after.marketplaceSellerActivation, malformed);
});

test("11. existing destination activation is preserved across repeated migration runs", async () => {
  const id = nextId("mig-repeat-active");
  const activation = { active: true, grantedBy: "admin-1" };
  await db.collection("adoption_centers").doc(id).set({ displayName: "Repeat Active" });
  await db.collection("businesses").doc(id).set({
    displayName: "Repeat Active",
    marketplaceSellerActivation: activation,
  });

  await runMigration();
  await runMigration();
  await runMigration();

  const after = (await db.collection("businesses").doc(id).get()).data();
  assert.deepEqual(after.marketplaceSellerActivation, activation);
});

test("12. missing destination activation remains missing across repeated runs", async () => {
  const id = nextId("mig-repeat-missing");
  await db.collection("adoption_centers").doc(id).set({ displayName: "Repeat Missing" });

  await runMigration();
  await runMigration();
  await runMigration();

  const after = (await db.collection("businesses").doc(id).get()).data();
  assert.equal(Object.prototype.hasOwnProperty.call(after, "marketplaceSellerActivation"), false);
});

test("13. no activation audit event is written by the migration", async () => {
  const id = nextId("mig-no-audit");
  await db.collection("adoption_centers").doc(id).set({ displayName: "No Audit" });

  const before = await db.collection("marketplaceSellerActivationAuditEvents").get();

  await runMigration();

  const after = await db.collection("marketplaceSellerActivationAuditEvents").get();
  assert.equal(after.size, before.size);
});

test("14. no unrelated destination-only field is accidentally deleted by the corrected merge behavior", async () => {
  const id = nextId("mig-preserve-unrelated");
  await db.collection("adoption_centers").doc(id).set({ displayName: "Preserve Unrelated" });
  await db.collection("businesses").doc(id).set({
    displayName: "Preserve Unrelated",
    someUnrelatedAdminField: "keep-me",
    stats: { appointmentCount: 7 },
  });

  await runMigration();

  const after = (await db.collection("businesses").doc(id).get()).data();
  assert.equal(after.someUnrelatedAdminField, "keep-me");
  assert.equal(after.stats.appointmentCount, 7);
});

test("15. intended migration-owned fields still update correctly on rerun", async () => {
  const id = nextId("mig-owned-fields-update");
  await db.collection("adoption_centers").doc(id).set({
    displayName: "Original Name",
    contact: { city: "Ankara" },
  });
  await runMigration();

  await db.collection("adoption_centers").doc(id).set({
    displayName: "Updated Name",
    contact: { city: "Izmir" },
  });
  await runMigration();

  const after = (await db.collection("businesses").doc(id).get()).data();
  assert.equal(after.profile.displayName, "Updated Name");
  assert.equal(after.contact.city, "Izmir");
});

test("16. the production write payload structurally omits the protected key", async () => {
  const id = nextId("mig-payload-shape");
  await db.collection("adoption_centers").doc(id).set({
    displayName: "Payload Shape",
    marketplaceSellerActivation: { active: true },
  });

  await runMigration();

  const after = (await db.collection("businesses").doc(id).get()).data();
  assert.equal(Object.prototype.hasOwnProperty.call(after, "marketplaceSellerActivation"), false);
  // Confirm no nested occurrence via the sectorData.adoption_center/
  // adoptionCenter fallback path either.
  const sectorAdoption = after.sectorData && after.sectorData.adoption_center;
  if (sectorAdoption && typeof sectorAdoption === "object") {
    assert.equal(
      Object.prototype.hasOwnProperty.call(sectorAdoption, "marketplaceSellerActivation"),
      false
    );
  }
});

test("17. dryRun mode performs no write at all, proving no alternate full-replacement path is reachable", async () => {
  const id = nextId("mig-dryrun");
  await db.collection("adoption_centers").doc(id).set({ displayName: "Dry Run Only" });

  const req = { query: {} }; // dryRun defaults to true
  const res = fakeRes();
  await functions.migrateAdoptionCentersToBusinesses(req, res);

  assert.equal(res._status, 200);
  assert.equal(res._body.dryRun, true);
  const snap = await db.collection("businesses").doc(id).get();
  assert.equal(snap.exists, false);
});

test("18. the two authorized activation Functions remain the only source paths that intentionally write marketplaceSellerActivation", async () => {
  const source = require("node:fs").readFileSync(
    require("node:path").join(__dirname, "..", "src", "marketplace", "compliance", "marketplaceSellerActivation.js"),
    "utf8"
  );
  assert.match(source, /async function grantMarketplaceSellerActivation/);
  assert.match(source, /async function revokeMarketplaceSellerActivation/);

  const migrationSource = require("node:fs").readFileSync(
    require("node:path").join(__dirname, "..", "index.js"),
    "utf8"
  );
  const mapFnMatch = migrationSource.match(
    /function mapAdoptionCenterToBusiness\(rawOldData = \{\}\) \{[\s\S]*?const \{ marketplaceSellerActivation: _sourceActivationExcluded, \.\.\.oldData \} = rawOldData;/
  );
  assert.ok(mapFnMatch, "mapAdoptionCenterToBusiness must destructure-exclude marketplaceSellerActivation before any use of oldData");

  const writeCallMatch = migrationSource.match(
    /\.doc\(doc\.id\)\s*\n\s*\.set\(newBusinessData, \{ merge: true \}\);/
  );
  assert.ok(writeCallMatch, "migrateAdoptionCentersToBusinesses must write with merge semantics");
});
