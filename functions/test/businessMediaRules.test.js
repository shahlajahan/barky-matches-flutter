"use strict";

// `businesses/{id}.businessMedia` is the canonical logo/cover/gallery map.
// Firestore Rules cannot reach Cloud Storage, so they can never prove that a
// referenced object exists in this business's namespace with a permitted type
// and size — which is exactly what would be needed to stop an owner writing an
// arbitrary external URL into a public media field. The field is therefore
// server-owned: only the finalizeBusinessMedia callable (Admin SDK, which
// bypasses Rules by construction) may write it.
//
// These tests prove the client-SDK side of that boundary, for every actor
// including an authenticated admin, and prove that the legacy display fields
// other sectors still write were NOT narrowed by the same change.

const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc, updateDoc, deleteField } = require("firebase/firestore");

const rules = fs.readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8");

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let testEnv;

function rulesTest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || `business-media-rules-${Date.now()}`,
    firestore: { rules },
  });
  return testEnv;
}

const OWNER = "owner-1";
const BIZ = "biz-1";

const MEDIA_VALUE = {
  logo: {
    path: `business_gallery/${BIZ}/logo_1.jpg`,
    url:
      "https://firebasestorage.googleapis.com/v0/b/demo/o/" +
      encodeURIComponent(`business_gallery/${BIZ}/logo_1.jpg`) +
      "?alt=media&token=t",
  },
  gallery: [],
  revision: 1,
};

async function seed({ withMedia = false } = {}) {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "businesses", BIZ), {
      ownerUid: OWNER,
      status: "approved",
      published: true,
      sectors: ["petshop"],
      profile: { displayName: "Shop" },
      marketplaceBusinessGenerationId: "gen-1",
      ...(withMedia ? { businessMedia: MEDIA_VALUE } : {}),
    });
  });
}

function ownerDb() {
  return testEnv.authenticatedContext(OWNER).firestore();
}
function adminDb() {
  return testEnv.authenticatedContext("admin-1", { role: "admin" }).firestore();
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

// ── 47. the client cannot inject canonical media ───────────────────────────

rulesTest("47a. the owner cannot create businessMedia through the client SDK", async () => {
  await seed();
  await assertFails(
    updateDoc(doc(ownerDb(), "businesses", BIZ), { businessMedia: MEDIA_VALUE })
  );
});

rulesTest("47b. the owner cannot modify existing businessMedia", async () => {
  await seed({ withMedia: true });
  await assertFails(
    updateDoc(doc(ownerDb(), "businesses", BIZ), {
      businessMedia: {
        ...MEDIA_VALUE,
        logo: { path: "x", url: "https://evil.example.com/logo.png" },
      },
    })
  );
});

rulesTest("47c. the owner cannot inject an external URL as canonical media", async () => {
  await seed();
  for (const injected of [
    { logo: { path: "p", url: "https://evil.example.com/a.jpg" }, gallery: [] },
    { gallery: [{ path: "p", url: "https://evil.example.com/a.jpg" }] },
    { cover: { path: `business_cover/${BIZ}/cover_1.jpg`, url: "https://evil.example.com/c.jpg" } },
  ]) {
    await assertFails(
      updateDoc(doc(ownerDb(), "businesses", BIZ), { businessMedia: injected })
    );
  }
});

rulesTest("47d. a nested/dotted path write cannot bypass the deny", async () => {
  await seed({ withMedia: true });
  // Dotted field paths still surface in diff().affectedKeys() as the root key.
  await assertFails(
    updateDoc(doc(ownerDb(), "businesses", BIZ), {
      "businessMedia.logo.url": "https://evil.example.com/a.jpg",
    })
  );
  await assertFails(
    updateDoc(doc(ownerDb(), "businesses", BIZ), {
      "businessMedia.gallery": [{ path: "p", url: "https://evil.example.com/a.jpg" }],
    })
  );
});

rulesTest("47e. the owner cannot delete businessMedia", async () => {
  await seed({ withMedia: true });
  await assertFails(
    updateDoc(doc(ownerDb(), "businesses", BIZ), { businessMedia: deleteField() })
  );
});

rulesTest("47f. a client-SDK admin is bound identically", async () => {
  await seed({ withMedia: true });
  await assertFails(
    updateDoc(doc(adminDb(), "businesses", BIZ), { businessMedia: MEDIA_VALUE })
  );
  await assertFails(
    updateDoc(doc(adminDb(), "businesses", BIZ), { businessMedia: deleteField() })
  );
  await assertFails(
    updateDoc(doc(adminDb(), "businesses", BIZ), {
      "businessMedia.logo.url": "https://evil.example.com/a.jpg",
    })
  );
});

rulesTest("47g. businessMedia cannot be smuggled in at create time", async () => {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
  await assertFails(
    setDoc(doc(ownerDb(), "businesses", "new-biz"), {
      ownerUid: OWNER,
      status: "pending",
      published: false,
      businessMedia: MEDIA_VALUE,
    })
  );
  // The same create without the server-owned field is unaffected.
  await assertSucceeds(
    setDoc(doc(ownerDb(), "businesses", "new-biz-2"), {
      ownerUid: OWNER,
      status: "pending",
      published: false,
    })
  );
});

// ── the change must not narrow anything else ───────────────────────────────

rulesTest("47h. the owner can still update ordinary business fields", async () => {
  await seed();
  await assertSucceeds(
    updateDoc(doc(ownerDb(), "businesses", BIZ), {
      profile: { displayName: "Renamed" },
      contact: { phone: "123" },
      sectorData: { petshop: { shopName: "Renamed" } },
    })
  );
});

rulesTest("47i. legacy display media fields are NOT narrowed by this change", async () => {
  // Vet / Groomy / Pet Hotel dashboards still write these directly. Narrowing
  // them here would break those surfaces, so they stay owner-writable and are
  // treated only as a read-only public fallback.
  await seed();
  await assertSucceeds(
    updateDoc(doc(ownerDb(), "businesses", BIZ), {
      coverImageUrl: "https://example.com/c.jpg",
      images: ["https://example.com/1.jpg"],
      videos: [],
    })
  );
});

rulesTest("47j. previously protected server-owned fields remain protected", async () => {
  await seed();
  // Every value below must genuinely differ from the seeded document: an
  // identical write produces an empty diff().affectedKeys() and is allowed
  // precisely because it changes nothing.
  for (const patch of [
    { status: "rejected" },
    { published: false },
    { ownerUid: "someone-else" },
    { verification: { isVerified: true } },
    { marketplaceSellerActivation: { active: true } },
    { pilotActiveProductCount: 5 },
    { marketplaceBusinessGenerationId: "gen-2" },
  ]) {
    await assertFails(updateDoc(doc(ownerDb(), "businesses", BIZ), patch));
  }
});

rulesTest("47k. a non-owner cannot write media or anything else", async () => {
  await seed({ withMedia: true });
  const other = testEnv.authenticatedContext("intruder").firestore();
  await assertFails(updateDoc(doc(other, "businesses", BIZ), { businessMedia: MEDIA_VALUE }));
  await assertFails(
    updateDoc(doc(other, "businesses", BIZ), { profile: { displayName: "hacked" } })
  );
});

rulesTest("47l. businesses_public remains read-only to every client", async () => {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "businesses_public", BIZ), {
      businessId: BIZ,
      businessMedia: { gallery: [] },
    });
  });
  await assertFails(
    updateDoc(doc(ownerDb(), "businesses_public", BIZ), {
      businessMedia: { logo: { path: "p", url: "https://evil.example.com/a.jpg" }, gallery: [] },
    })
  );
  await assertFails(
    updateDoc(doc(adminDb(), "businesses_public", BIZ), { businessMedia: { gallery: [] } })
  );
});
