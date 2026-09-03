"use strict";

// business_gallery/ cross-sector repair. The path previously had NO matching
// rule in storage.rules and fell through to the global deny-all, so every
// existing Vet / Groomy / Pet Hotel dashboard gallery upload — and the shared
// ImageUploadService used by all of them — was rejected in production.
//
// These tests prove the restored rule is narrowly scoped: authenticated
// canonical business owner only (resolved from businesses/{id}.ownerUid, never
// from request.auth.uid == businessId), pre-vetted content types only, size
// capped, single-business namespace, and still closed to registration-time
// uploads made before the business document exists.
//
// ADMIN SDK BOUNDARY (matrix item 44): the Firebase Admin SDK bypasses Storage
// Rules entirely by construction — it is not a Rules principal and cannot be
// emulated through a client Rules test. It is therefore asserted structurally
// (no rule here grants or can grant it anything) rather than behaviourally.
// What IS tested below is the *client-SDK* admin custom claim, which is a
// Rules principal.

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

// Same constraint documented in marketplaceProductStorageRules.test.js:
// storage.rules' isBusinessOwner() performs a cross-service firestore.get(),
// which resolves against the emulator's own --single_project_mode project.
// A dynamic projectId would therefore never match and every ownership lookup
// would fail for the whole run.
const PROJECT_ID =
  process.env.GCLOUD_PROJECT || `business-gallery-storage-rules-${Date.now()}`;

async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: firestoreRules },
    storage: { rules: storageRules },
  });
  return testEnv;
}

// Synthetic fixtures only, seeded with Rules disabled so that Firestore Rules
// are never weakened just to establish ownership state.
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

// Writes an object bypassing Rules, so delete/overwrite/read cases start from
// a real pre-existing object rather than from a create the rule also governs.
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

function ownerStorage(uid) {
  return testEnv.authenticatedContext(uid).storage();
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

// ───────────────────────────────────────────────────────────
// ALLOWED — canonical owner, valid object
// ───────────────────────────────────────────────────────────

rulesTest("1. owner uploads a valid JPEG", async () => {
  await defaultSeed();
  await assertSucceeds(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("2. owner uploads a valid PNG", async () => {
  await defaultSeed();
  await assertSucceeds(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.png"), png, {
      contentType: "image/png",
    })
  );
});

rulesTest("3. owner uploads a valid WebP", async () => {
  await defaultSeed();
  await assertSucceeds(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.webp"), webp, {
      contentType: "image/webp",
    })
  );
});

rulesTest("4. owner uploads a valid HEIC (in the frozen contract)", async () => {
  await defaultSeed();
  await assertSucceeds(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.heic"), heic, {
      contentType: "image/heic",
    })
  );
});

rulesTest("5. uppercase extensions are accepted (camera-roll names)", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  await assertSucceeds(
    uploadBytes(ref(storage, "business_gallery/biz-1/A.JPG"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertSucceeds(
    uploadBytes(ref(storage, "business_gallery/biz-1/B.JpEg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertSucceeds(
    uploadBytes(ref(storage, "business_gallery/biz-1/C.PNG"), png, {
      contentType: "image/png",
    })
  );
});

rulesTest("6. owner reads their own object", async () => {
  await defaultSeed();
  await seedObject("business_gallery/biz-1/a.jpg", jpeg, "image/jpeg");
  await assertSucceeds(
    getBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"))
  );
});

rulesTest("7. owner replaces their own image with another valid image", async () => {
  await defaultSeed();
  await seedObject("business_gallery/biz-1/a.jpg", jpeg, "image/jpeg");
  await assertSucceeds(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("8. owner deletes their own image", async () => {
  await defaultSeed();
  await seedObject("business_gallery/biz-1/a.jpg", jpeg, "image/jpeg");
  await assertSucceeds(
    deleteObject(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"))
  );
});

rulesTest("9. two businesses manage their own namespaces independently", async () => {
  await defaultSeed();
  await assertSucceeds(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertSucceeds(
    uploadBytes(ref(ownerStorage("owner-2"), "business_gallery/biz-2/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("9b. owner uploads valid video to the videos/ subpath", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  await assertSucceeds(
    uploadBytes(ref(storage, "business_gallery/biz-1/videos/a.mp4"), mp4, {
      contentType: "video/mp4",
    })
  );
  await assertSucceeds(
    uploadBytes(ref(storage, "business_gallery/biz-1/videos/b.mov"), mp4, {
      contentType: "video/quicktime",
    })
  );
  await assertSucceeds(
    uploadBytes(ref(storage, "business_gallery/biz-1/videos/c.hevc"), mp4, {
      contentType: "video/hevc",
    })
  );
});

// ───────────────────────────────────────────────────────────
// DENIED — authentication and ownership
// ───────────────────────────────────────────────────────────

rulesTest("10. unauthenticated upload is denied", async () => {
  await defaultSeed();
  const storage = testEnv.unauthenticatedContext().storage();
  await assertFails(
    uploadBytes(ref(storage, "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("11. unauthenticated read is denied (not a public path)", async () => {
  await defaultSeed();
  await seedObject("business_gallery/biz-1/a.jpg", jpeg, "image/jpeg");
  const storage = testEnv.unauthenticatedContext().storage();
  await assertFails(getBytes(ref(storage, "business_gallery/biz-1/a.jpg")));
});

rulesTest("12. unauthenticated delete is denied", async () => {
  await defaultSeed();
  await seedObject("business_gallery/biz-1/a.jpg", jpeg, "image/jpeg");
  const storage = testEnv.unauthenticatedContext().storage();
  await assertFails(deleteObject(ref(storage, "business_gallery/biz-1/a.jpg")));
});

rulesTest("13. user A cannot upload into business B's namespace", async () => {
  await defaultSeed();
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-2/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("14. user A cannot overwrite business B's object", async () => {
  await defaultSeed();
  await seedObject("business_gallery/biz-2/a.jpg", jpeg, "image/jpeg");
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-2/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("15. user A cannot delete business B's object", async () => {
  await defaultSeed();
  await seedObject("business_gallery/biz-2/a.jpg", jpeg, "image/jpeg");
  await assertFails(
    deleteObject(ref(ownerStorage("owner-1"), "business_gallery/biz-2/a.jpg"))
  );
});

rulesTest("16. upload for a nonexistent business is denied", async () => {
  await defaultSeed();
  await assertFails(
    uploadBytes(
      ref(ownerStorage("owner-1"), "business_gallery/no-such-biz/a.jpg"),
      jpeg,
      { contentType: "image/jpeg" }
    )
  );
});

rulesTest("17. upload is denied when ownerUid is missing", async () => {
  await seed({ "biz-1": { name: "no owner field" } });
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("18. upload is denied when ownerUid is null", async () => {
  await seed({ "biz-1": { ownerUid: null } });
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("19. upload is denied when ownerUid has the wrong type", async () => {
  await seed({ "biz-1": { ownerUid: 12345 } });
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await seed({ "biz-1": { ownerUid: { uid: "owner-1" } } });
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("20. upload is denied when ownerUid belongs to another user", async () => {
  await seed({ "biz-1": { ownerUid: "someone-else" } });
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("20b. ownership is NOT inferred from auth.uid == businessId", async () => {
  // registerBusiness happens to create businesses/{uid}, but that equivalence
  // must never be the authorization: with no business document, a user whose
  // uid equals the businessId is still denied.
  await seed({});
  await assertFails(
    uploadBytes(ref(ownerStorage("biz-1"), "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("21. client-SDK admin that is not the owner cannot upload", async () => {
  await defaultSeed();
  const storage = testEnv
    .authenticatedContext("admin-1", { role: "admin" })
    .storage();
  await assertFails(
    uploadBytes(ref(storage, "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  // Admin read/delete IS permitted — this mirrors the already-frozen
  // products/ and products_raw/ policy in the same file (moderation
  // takedown), and is asserted here so the asymmetry is deliberate and
  // visible rather than incidental.
  await seedObject("business_gallery/biz-1/b.jpg", jpeg, "image/jpeg");
  await assertSucceeds(
    deleteObject(ref(storage, "business_gallery/biz-1/b.jpg"))
  );
});

// ───────────────────────────────────────────────────────────
// DENIED — object integrity
// ───────────────────────────────────────────────────────────

rulesTest("22. text/plain is denied", async () => {
  await defaultSeed();
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.txt"), jpeg, {
      contentType: "text/plain",
    })
  );
});

rulesTest("23. application/pdf is denied", async () => {
  await defaultSeed();
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.pdf"), jpeg, {
      contentType: "application/pdf",
    })
  );
});

rulesTest("24. video on the image path is denied", async () => {
  await defaultSeed();
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.mp4"), mp4, {
      contentType: "video/mp4",
    })
  );
});

rulesTest("24b. an image on the videos/ path is denied", async () => {
  await defaultSeed();
  await assertFails(
    uploadBytes(
      ref(ownerStorage("owner-1"), "business_gallery/biz-1/videos/a.jpg"),
      jpeg,
      { contentType: "image/jpeg" }
    )
  );
});

rulesTest("25. executable/binary payloads are denied", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  await assertFails(
    uploadBytes(ref(storage, "business_gallery/biz-1/a.exe"), jpeg, {
      contentType: "application/octet-stream",
    })
  );
  await assertFails(
    uploadBytes(ref(storage, "business_gallery/biz-1/a.sh"), jpeg, {
      contentType: "application/x-sh",
    })
  );
  // The exact failure mode the shared uploader had before this repair:
  // correct .jpg name, but an undeclared type arriving as octet-stream.
  await assertFails(
    uploadBytes(ref(storage, "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "application/octet-stream",
    })
  );
});

rulesTest("26. an oversized image is denied", async () => {
  await defaultSeed();
  const tooBig = new Uint8Array(10 * 1024 * 1024 + 1);
  tooBig.set(jpeg);
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/big.jpg"), tooBig, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("26b. an empty object is denied", async () => {
  await defaultSeed();
  await assertFails(
    uploadBytes(
      ref(ownerStorage("owner-1"), "business_gallery/biz-1/empty.jpg"),
      new Uint8Array(0),
      { contentType: "image/jpeg" }
    )
  );
});

rulesTest("27. a valid extension with an invalid MIME is denied", async () => {
  await defaultSeed();
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "text/html",
    })
  );
});

rulesTest("28. a valid MIME with a forbidden extension is denied", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  await assertFails(
    uploadBytes(ref(storage, "business_gallery/biz-1/a.txt"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertFails(
    uploadBytes(ref(storage, "business_gallery/biz-1/a.svg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("29. an extensionless file is denied", async () => {
  await defaultSeed();
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/photo"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("30. malformed filenames are denied", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  for (const name of ["a.jpg.txt", "a.jpg.", ".jpg.", "jpg"]) {
    await assertFails(
      uploadBytes(ref(storage, `business_gallery/biz-1/${name}`), jpeg, {
        contentType: "image/jpeg",
      })
    );
  }
});

rulesTest("31. an unexpected nested subdirectory is denied", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  // Only the flat path and the single videos/ segment are matched; anything
  // deeper matches no rule and falls through to the deny-all.
  for (const p of [
    "business_gallery/biz-1/nested/a.jpg",
    "business_gallery/biz-1/a/b/c.jpg",
    "business_gallery/biz-1/videos/nested/a.mp4",
  ]) {
    await assertFails(
      uploadBytes(ref(storage, p), jpeg, { contentType: "image/jpeg" })
    );
  }
});

rulesTest("32. businessId path decoys are denied", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  for (const p of [
    "business_gallery/biz-2/biz-1/a.jpg",
    "business_gallery/biz-1x/a.jpg",
    "business_gallery/videos/a.mp4",
    "business_gallery/a.jpg",
  ]) {
    await assertFails(
      uploadBytes(ref(storage, p), jpeg, { contentType: "image/jpeg" })
    );
  }
});

rulesTest("33. writing outside business_gallery is denied", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  for (const p of [
    "business_gallery_evil/biz-1/a.jpg",
    "business_galleryX/biz-1/a.jpg",
    "unknown_root/biz-1/a.jpg",
  ]) {
    await assertFails(
      uploadBytes(ref(storage, p), jpeg, { contentType: "image/jpeg" })
    );
  }
});

rulesTest("34. legal/compliance paths remain unreachable", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  for (const p of [
    "compliance_docs/biz-1/a.pdf",
    "compliance_quarantine/biz-1/s1/a.pdf",
  ]) {
    await assertFails(
      uploadBytes(ref(storage, p), jpeg, { contentType: "application/pdf" })
    );
  }
});

rulesTest("35. updating a valid image into an invalid MIME is denied", async () => {
  await defaultSeed();
  await seedObject("business_gallery/biz-1/a.jpg", jpeg, "image/jpeg");
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "text/plain",
    })
  );
});

rulesTest("36. updating a valid image into oversized content is denied", async () => {
  await defaultSeed();
  await seedObject("business_gallery/biz-1/a.jpg", jpeg, "image/jpeg");
  const tooBig = new Uint8Array(10 * 1024 * 1024 + 1);
  tooBig.set(jpeg);
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"), tooBig, {
      contentType: "image/jpeg",
    })
  );
});

// ───────────────────────────────────────────────────────────
// BOUNDARY / REGRESSION
// ───────────────────────────────────────────────────────────

rulesTest("37. existing products path behavior is unchanged", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  await assertSucceeds(
    uploadBytes(ref(storage, "products/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertFails(
    uploadBytes(ref(storage, "products/biz-2/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  // products/ still rejects video, as its own audit requires.
  await assertFails(
    uploadBytes(ref(storage, "products/biz-1/a.mp4"), mp4, {
      contentType: "video/mp4",
    })
  );
});

rulesTest("38. existing compliance deny behavior is unchanged", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  await assertFails(
    uploadBytes(ref(storage, "compliance_docs/biz-1/a.pdf"), jpeg, {
      contentType: "application/pdf",
    })
  );
  await assertFails(getBytes(ref(storage, "compliance_docs/biz-1/a.pdf")));
});

rulesTest("39. the final catch-all still denies unknown paths", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  await assertFails(
    uploadBytes(ref(storage, "totally_unknown/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertFails(getBytes(ref(storage, "totally_unknown/a.jpg")));
});

rulesTest("40. no rule permits a pre-business registration upload", async () => {
  // The business document does not exist yet — this is the registration-time
  // case, deliberately still denied.
  await seed({});
  const storage = ownerStorage("owner-1");
  await assertFails(
    uploadBytes(ref(storage, "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertFails(
    uploadBytes(ref(storage, "business_gallery/owner-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("41. deleting the business makes owner writes fail closed", async () => {
  await defaultSeed();
  const storage = ownerStorage("owner-1");
  await assertSucceeds(
    uploadBytes(ref(storage, "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await deleteDoc(doc(context.firestore(), "businesses", "biz-1"));
  });
  await assertFails(
    uploadBytes(ref(storage, "business_gallery/biz-1/b.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("42. a recreated business ID under a new owner locks out the previous owner", async () => {
  await defaultSeed();
  await assertSucceeds(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  // Same document id, different canonical owner.
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "businesses", "biz-1"), {
      ownerUid: "owner-2",
    });
  });
  await assertFails(
    uploadBytes(ref(ownerStorage("owner-1"), "business_gallery/biz-1/b.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
  await assertSucceeds(
    uploadBytes(ref(ownerStorage("owner-2"), "business_gallery/biz-1/c.jpg"), jpeg, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("43. a previous owner cannot delete after ownership changes", async () => {
  await defaultSeed();
  await seedObject("business_gallery/biz-1/a.jpg", jpeg, "image/jpeg");
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "businesses", "biz-1"), {
      ownerUid: "owner-2",
    });
  });
  await assertFails(
    deleteObject(ref(ownerStorage("owner-1"), "business_gallery/biz-1/a.jpg"))
  );
  await assertSucceeds(
    deleteObject(ref(ownerStorage("owner-2"), "business_gallery/biz-1/a.jpg"))
  );
});

// 44. Admin SDK boundary — structural, not behavioural. Asserted here as a
// property of the rules text itself: no rule in storage.rules grants access
// on the basis of anything other than a Rules principal, and the Admin SDK is
// not one. This is a documentation guard, not an emulation attempt.
test("44. business_gallery grants nothing outside Rules principals", () => {
  const block = storageRules.slice(
    storageRules.indexOf("match /business_gallery/")
  );
  const gallery = block.slice(0, block.indexOf("// Marketplace P1-A"));
  assert.ok(
    gallery.includes("isBusinessOwner(businessId)"),
    "ownership must be resolved through the canonical business document"
  );
  assert.ok(
    !/request\.auth\.uid\s*==\s*businessId/.test(gallery),
    "ownership must never be inferred from auth.uid == businessId"
  );
  assert.ok(
    !gallery.includes("request.resource.metadata"),
    "client custom metadata must never participate in authorization"
  );
  assert.ok(
    !/allow read:\s*if true/.test(gallery),
    "no unauthenticated public-read rule may be introduced here"
  );
});
