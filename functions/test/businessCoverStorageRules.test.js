"use strict";

// business_cover/ repair. Like business_gallery/ before it, this prefix had NO
// matching rule in storage.rules and fell through to the global deny-all, so
// the Vet dashboard's "change cover image" action was rejected in production
// (vet_gallery_management_page.dart's _changeCoverImage).
//
// The contract is deliberately identical to the flat business_gallery/ image
// path — canonical business owner only, one still image per object, one path
// segment — so these tests concentrate on the properties that could differ:
// that the namespace really is per-business, that video cannot reach it, that
// nesting is impossible, and that adding it changed nothing about the
// neighbouring gallery, product, compliance and catch-all behaviour.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc, deleteDoc } = require("firebase/firestore");
const {
  ref,
  uploadBytes,
  getBytes,
  deleteObject,
} = require("firebase/storage");

const firestoreRules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);
const storageRules = fs.readFileSync(
  path.resolve(__dirname, "../../storage.rules"),
  "utf8"
);

const hasEmulators = Boolean(
  process.env.FIRESTORE_EMULATOR_HOST &&
    process.env.FIREBASE_STORAGE_EMULATOR_HOST
);
let testEnv;

function rulesTest(name, fn) {
  test(name, { skip: !hasEmulators }, fn);
}

// See marketplaceProductStorageRules.test.js: storage.rules' isBusinessOwner()
// makes a cross-service firestore.get(), which resolves against the emulator's
// own --single_project_mode project, so the project id must match the one the
// emulator was launched with.
const PROJECT_ID =
  process.env.GCLOUD_PROJECT || `business-cover-storage-rules-${Date.now()}`;

async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: firestoreRules },
    storage: { rules: storageRules },
  });
  return testEnv;
}

// Synthetic fixtures only, seeded with Rules disabled so Firestore Rules are
// never weakened to establish ownership state.
async function seed(businesses) {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
  await rulesEnv.clearStorage();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    for (const [id, data] of Object.entries(businesses)) {
      await setDoc(doc(context.firestore(), "businesses", id), data);
    }
  });
}

async function defaultSeed() {
  await seed({
    "biz-1": { ownerUid: "owner-1" },
    "biz-2": { ownerUid: "owner-2" },
  });
}

async function seedObject(objectPath, bytes, contentType) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), objectPath), bytes, {
      contentType,
    });
  });
}

const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xdb, 1, 2, 3, 4]);
const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 1, 2, 3, 4]);
const webp = new Uint8Array([0x52, 0x49, 0x46, 0x46, 1, 2, 3, 4]);
const heic = new Uint8Array([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70]);
const mp4 = new Uint8Array([0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 1, 2]);

function as(uid, claims) {
  return testEnv.authenticatedContext(uid, claims).storage();
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

// ───────────────────────────────────────────────────────────
// ALLOWED
// ───────────────────────────────────────────────────────────

rulesTest("C1. owner uploads a cover image in every accepted format", async () => {
  await defaultSeed();
  const storage = as("owner-1");
  await assertSucceeds(
    uploadBytes(ref(storage, "business_cover/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertSucceeds(
    uploadBytes(ref(storage, "business_cover/biz-1/b.png"), png, {
      contentType: "image/png",
    })
  );
  await assertSucceeds(
    uploadBytes(ref(storage, "business_cover/biz-1/c.webp"), webp, {
      contentType: "image/webp",
    })
  );
  await assertSucceeds(
    uploadBytes(ref(storage, "business_cover/biz-1/d.heic"), heic, {
      contentType: "image/heic",
    })
  );
});

rulesTest("C2. uppercase extensions are accepted", async () => {
  await defaultSeed();
  await assertSucceeds(
    uploadBytes(ref(as("owner-1"), "business_cover/biz-1/A.JPG"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("C3. the cover is replaceable in place", async () => {
  // The whole point of the feature: changing the cover must not require
  // deleting the business or the previous object first.
  await defaultSeed();
  await seedObject("business_cover/biz-1/a.jpg", jpeg, "image/jpeg");
  await assertSucceeds(
    uploadBytes(ref(as("owner-1"), "business_cover/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("C4. owner reads and deletes their own cover", async () => {
  await defaultSeed();
  await seedObject("business_cover/biz-1/a.jpg", jpeg, "image/jpeg");
  await assertSucceeds(
    getBytes(ref(as("owner-1"), "business_cover/biz-1/a.jpg"))
  );
  await assertSucceeds(
    deleteObject(ref(as("owner-1"), "business_cover/biz-1/a.jpg"))
  );
});

rulesTest("C5. two businesses hold independent cover namespaces", async () => {
  await defaultSeed();
  await assertSucceeds(
    uploadBytes(ref(as("owner-1"), "business_cover/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertSucceeds(
    uploadBytes(ref(as("owner-2"), "business_cover/biz-2/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

// ───────────────────────────────────────────────────────────
// DENIED — authentication and ownership
// ───────────────────────────────────────────────────────────

rulesTest("C6. unauthenticated read/write/delete are denied", async () => {
  await defaultSeed();
  await seedObject("business_cover/biz-1/a.jpg", jpeg, "image/jpeg");
  const storage = testEnv.unauthenticatedContext().storage();
  await assertFails(
    uploadBytes(ref(storage, "business_cover/biz-1/b.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertFails(getBytes(ref(storage, "business_cover/biz-1/a.jpg")));
  await assertFails(deleteObject(ref(storage, "business_cover/biz-1/a.jpg")));
});

rulesTest("C7. cross-business create, overwrite and delete are denied", async () => {
  await defaultSeed();
  await seedObject("business_cover/biz-2/a.jpg", jpeg, "image/jpeg");
  const storage = as("owner-1");
  await assertFails(
    uploadBytes(ref(storage, "business_cover/biz-2/new.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertFails(
    uploadBytes(ref(storage, "business_cover/biz-2/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertFails(
    deleteObject(ref(storage, "business_cover/biz-2/a.jpg"))
  );
});

rulesTest("C8. malformed or absent ownership fails closed", async () => {
  for (const business of [
    undefined, // no document at all
    { name: "no owner field" },
    { ownerUid: null },
    { ownerUid: 12345 },
    { ownerUid: { uid: "owner-1" } },
    { ownerUid: ["owner-1"] },
    { ownerUid: "someone-else" },
  ]) {
    await seed(business === undefined ? {} : { "biz-1": business });
    await assertFails(
      uploadBytes(ref(as("owner-1"), "business_cover/biz-1/a.jpg"), jpeg, {
        contentType: "image/jpeg",
      }),
      `ownership fixture: ${JSON.stringify(business)}`
    );
  }
});

rulesTest("C9. ownership is not inferred from auth.uid == businessId", async () => {
  await seed({});
  await assertFails(
    uploadBytes(ref(as("biz-1"), "business_cover/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("C10. a client-SDK admin that is not the owner cannot upload", async () => {
  await defaultSeed();
  const admin = as("admin-1", { role: "admin" });
  await assertFails(
    uploadBytes(ref(admin, "business_cover/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  // Admin read/delete IS allowed, mirroring products/ and business_gallery/.
  await seedObject("business_cover/biz-1/b.jpg", jpeg, "image/jpeg");
  await assertSucceeds(deleteObject(ref(admin, "business_cover/biz-1/b.jpg")));
});

rulesTest("C11. registration-time upload is still denied", async () => {
  await seed({});
  await assertFails(
    uploadBytes(ref(as("owner-1"), "business_cover/owner-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("C12. losing ownership closes write and delete access", async () => {
  await defaultSeed();
  await seedObject("business_cover/biz-1/a.jpg", jpeg, "image/jpeg");
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "businesses", "biz-1"), {
      ownerUid: "owner-2",
    });
  });
  await assertFails(
    uploadBytes(ref(as("owner-1"), "business_cover/biz-1/b.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertFails(
    deleteObject(ref(as("owner-1"), "business_cover/biz-1/a.jpg"))
  );
  await assertSucceeds(
    uploadBytes(ref(as("owner-2"), "business_cover/biz-1/c.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("C13. deleting the business closes the namespace", async () => {
  await defaultSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await deleteDoc(doc(context.firestore(), "businesses", "biz-1"));
  });
  await assertFails(
    uploadBytes(ref(as("owner-1"), "business_cover/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

// ───────────────────────────────────────────────────────────
// DENIED — object integrity
// ───────────────────────────────────────────────────────────

rulesTest("C14. non-image content types are denied", async () => {
  await defaultSeed();
  const storage = as("owner-1");
  for (const [name, type] of [
    ["a.txt", "text/plain"],
    ["a.pdf", "application/pdf"],
    ["a.html", "text/html"],
    ["a.svg", "image/svg+xml"],
    ["a.gif", "image/gif"],
    ["a.exe", "application/octet-stream"],
  ]) {
    await assertFails(
      uploadBytes(ref(storage, `business_cover/biz-1/${name}`), jpeg, {
        contentType: type,
      }),
      `${name} / ${type}`
    );
  }
});

rulesTest("C15. video cannot be written to the cover path", async () => {
  // business_gallery/ has a videos/ subpath; business_cover/ has none, and
  // hasAllowedBusinessImage() declares no video type.
  await defaultSeed();
  const storage = as("owner-1");
  await assertFails(
    uploadBytes(ref(storage, "business_cover/biz-1/a.mp4"), mp4, {
      contentType: "video/mp4",
    })
  );
  await assertFails(
    uploadBytes(ref(storage, "business_cover/biz-1/videos/a.mp4"), mp4, {
      contentType: "video/mp4",
    })
  );
});

rulesTest("C16. MIME and extension must agree in both directions", async () => {
  await defaultSeed();
  const storage = as("owner-1");
  // Valid extension, invalid declared type.
  await assertFails(
    uploadBytes(ref(storage, "business_cover/biz-1/a.jpg"), jpeg, {
      contentType: "text/plain",
    })
  );
  // Valid declared type, forbidden extension.
  await assertFails(
    uploadBytes(ref(storage, "business_cover/biz-1/a.txt"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  // The exact pre-repair failure mode: correct name, undeclared type.
  await assertFails(
    uploadBytes(ref(storage, "business_cover/biz-1/a.jpg"), jpeg, {
      contentType: "application/octet-stream",
    })
  );
});

rulesTest("C17. empty, oversized and malformed objects are denied", async () => {
  await defaultSeed();
  const storage = as("owner-1");
  await assertFails(
    uploadBytes(
      ref(storage, "business_cover/biz-1/empty.jpg"),
      new Uint8Array(0),
      { contentType: "image/jpeg" }
    )
  );
  const tooBig = new Uint8Array(10 * 1024 * 1024 + 1);
  tooBig.set(jpeg);
  await assertFails(
    uploadBytes(ref(storage, "business_cover/biz-1/big.jpg"), tooBig, {
      contentType: "image/jpeg",
    })
  );
  for (const name of ["cover", "a.jpg.txt", "a.jpg.", ".jpg.", "jpg"]) {
    await assertFails(
      uploadBytes(ref(storage, `business_cover/biz-1/${name}`), jpeg, {
        contentType: "image/jpeg",
      }),
      name
    );
  }
});

rulesTest("C18. nesting and namespace decoys are denied", async () => {
  await defaultSeed();
  const storage = as("owner-1");
  for (const p of [
    "business_cover/biz-1/nested/a.jpg",
    "business_cover/biz-1/a/b/c.jpg",
    "business_cover/biz-2/biz-1/a.jpg",
    "business_cover/biz-1x/a.jpg",
    "business_cover/a.jpg",
    "business_coverX/biz-1/a.jpg",
    "business_cover_evil/biz-1/a.jpg",
  ]) {
    await assertFails(
      uploadBytes(ref(storage, p), jpeg, { contentType: "image/jpeg" }),
      p
    );
  }
});

// ───────────────────────────────────────────────────────────
// BOUNDARY / REGRESSION
// ───────────────────────────────────────────────────────────

rulesTest("C19. business_gallery behaviour is unchanged", async () => {
  await defaultSeed();
  const storage = as("owner-1");
  await assertSucceeds(
    uploadBytes(ref(storage, "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertSucceeds(
    uploadBytes(ref(storage, "business_gallery/biz-1/videos/a.mp4"), mp4, {
      contentType: "video/mp4",
    })
  );
  await assertFails(
    uploadBytes(ref(storage, "business_gallery/biz-2/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("C20. products, compliance and catch-all are unchanged", async () => {
  await defaultSeed();
  const storage = as("owner-1");
  await assertSucceeds(
    uploadBytes(ref(storage, "products/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertFails(
    uploadBytes(ref(storage, "compliance_docs/biz-1/a.pdf"), jpeg, {
      contentType: "application/pdf",
    })
  );
  await assertFails(
    uploadBytes(ref(storage, "totally_unknown/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

// Structural guard, mirroring the business_gallery suite: the Admin SDK is not
// a Rules principal and cannot be emulated through a client Rules test, so the
// property asserted here is about the rules text itself.
test("C21. business_cover grants nothing outside Rules principals", () => {
  const start = storageRules.indexOf("match /business_cover/");
  assert.ok(start > 0, "business_cover match block must exist");
  const block = storageRules.slice(start);
  const cover = block.slice(0, block.indexOf("}\n\n"));
  assert.ok(
    cover.includes("isBusinessOwner(businessId)"),
    "ownership must resolve through the canonical business document"
  );
  assert.ok(
    !/request\.auth\.uid\s*==\s*businessId/.test(cover),
    "ownership must never be inferred from auth.uid == businessId"
  );
  assert.ok(
    !cover.includes("request.resource.metadata"),
    "client custom metadata must never participate in authorization"
  );
  assert.ok(
    !/allow (read|write)[^;]*:\s*if true/.test(cover),
    "no unauthenticated public rule may be introduced here"
  );
  assert.ok(
    !/hasAllowedBusinessGalleryVideo|hasAllowedMedia/.test(cover),
    "the cover path must not accept video"
  );
});
