"use strict";

// Marketplace product compliance audit, P0 remediation
// (docs/audits/marketplace_add_product_compliance_audit_2026-08-20.md,
// finding F-08). products/ and products_raw/ previously had no matching
// Storage rule at all and fell through to a global deny-all. These tests
// prove the new rule is narrowly scoped: authenticated business owner
// only, pre-vetted content types only, size-capped.

const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc } = require("firebase/firestore");
const { ref, uploadBytes } = require("firebase/storage");

const firestoreRules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);
const storageRules = fs.readFileSync(
  path.resolve(__dirname, "../../storage.rules"),
  "utf8"
);

const hasEmulators = Boolean(
  process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_STORAGE_EMULATOR_HOST
);
let testEnv;

function rulesTest(name, fn) {
  test(name, { skip: !hasEmulators }, fn);
}

// P0 gap review item 6: root cause of the "valid authorized product
// image upload" test failing unpredictably. `firebase emulators:exec
// --project X` starts the Firestore emulator in --single_project_mode
// locked to X (confirmed by inspecting the running emulator process).
// storage.rules' isBusinessOwner() calls firestore.get() cross-service —
// that call is resolved against the *emulator's own* locked project,
// not whatever project rules-unit-testing happens to create. A dynamic,
// timestamp-suffixed projectId here therefore silently never matches,
// so every isBusinessOwner() lookup returns "Null value error" for the
// entire run — it isn't a warm-up race (a 20s/80-attempt retry loop
// never once succeeded) and it isn't test-suite contention (it
// reproduced 100% of the time in complete isolation). Firestore-only
// rules tests never hit this because rules-unit-testing manages
// same-service project isolation itself, independent of
// --single_project_mode; only the Storage-to-Firestore bridge is
// affected. The fix is to use the exact project the emulator was
// launched with (GCLOUD_PROJECT, set by `emulators:exec --project`) so
// the two agree.
const PROJECT_ID =
  process.env.GCLOUD_PROJECT || `marketplace-product-storage-rules-${Date.now()}`;

async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: firestoreRules },
    storage: { rules: storageRules },
  });
  return testEnv;
}

async function resetSeed() {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
  await rulesEnv.clearStorage();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "businesses", "biz-1"), {
      ownerUid: "seller-1",
    });
    await setDoc(doc(context.firestore(), "businesses", "biz-2"), {
      ownerUid: "seller-2",
    });
  });
}

const validJpegBytes = new Uint8Array([0xff, 0xd8, 0xff, 0xdb, 1, 2, 3, 4]);

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

rulesTest("16. valid authorized product image upload succeeds", async () => {
  await resetSeed();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertSucceeds(
    uploadBytes(ref(storage, "products/biz-1/photo.jpg"), validJpegBytes, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest("13a. unauthenticated upload fails", async () => {
  await resetSeed();
  const storage = (await env()).unauthenticatedContext().storage();
  await assertFails(
    uploadBytes(ref(storage, "products/biz-1/photo.jpg"), validJpegBytes, {
      contentType: "image/jpeg",
    })
  );
});

rulesTest(
  "13b. a different seller cannot upload into another business's path",
  async () => {
    await resetSeed();
    const storage = (await env()).authenticatedContext("seller-2").storage();
    await assertFails(
      uploadBytes(ref(storage, "products/biz-1/photo.jpg"), validJpegBytes, {
        contentType: "image/jpeg",
      })
    );
  }
);

rulesTest(
  "13c. a different seller cannot read another business's product image",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(
        ref(context.storage(), "products/biz-1/photo.jpg"),
        validJpegBytes,
        { contentType: "image/jpeg" }
      );
    });
    const { getBytes } = require("firebase/storage");
    const storage = rulesEnv.authenticatedContext("seller-2").storage();
    await assertFails(
      getBytes(ref(storage, "products/biz-1/photo.jpg"))
    );
  }
);

rulesTest("14a. unsupported content type (SVG) fails", async () => {
  await resetSeed();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  const svg = new TextEncoder().encode(
    "<svg onload=\"alert(1)\"></svg>"
  );
  await assertFails(
    uploadBytes(ref(storage, "products/biz-1/photo.svg"), svg, {
      contentType: "image/svg+xml",
    })
  );
});

rulesTest("14b. unsupported content type (HTML) fails", async () => {
  await resetSeed();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  const html = new TextEncoder().encode("<html></html>");
  await assertFails(
    uploadBytes(ref(storage, "products/biz-1/photo.html"), html, {
      contentType: "text/html",
    })
  );
});

rulesTest("15. oversized image fails", async () => {
  await resetSeed();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  const tooLarge = new Uint8Array(105 * 1024 * 1024); // > 100MB cap
  await assertFails(
    uploadBytes(ref(storage, "products/biz-1/big.jpg"), tooLarge, {
      contentType: "image/jpeg",
    })
  );
});

// P0 final correction item 3: hasAllowedProductImage()'s extension check
// previously rejected uppercase extensions (Photo.JPG) even with a valid
// contentType, since the regex only listed lowercase alternatives. Fixed
// with explicit per-letter character classes rather than an inline (?i)
// flag. These tests are the actual proof the fix works against the real
// RE2 engine Firebase Storage Rules run on, not an assumption about flag
// support.
rulesTest(
  "17a. uppercase .JPG extension with matching content type succeeds",
  async () => {
    await resetSeed();
    const storage = (await env()).authenticatedContext("seller-1").storage();
    await assertSucceeds(
      uploadBytes(ref(storage, "products/biz-1/Photo.JPG"), validJpegBytes, {
        contentType: "image/jpeg",
      })
    );
  }
);

rulesTest(
  "17b. uppercase .PNG extension with matching content type succeeds",
  async () => {
    await resetSeed();
    const storage = (await env()).authenticatedContext("seller-1").storage();
    const validPngBytes = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 1, 2, 3, 4]);
    await assertSucceeds(
      uploadBytes(ref(storage, "products/biz-1/Photo.PNG"), validPngBytes, {
        contentType: "image/png",
      })
    );
  }
);

rulesTest("17c. uppercase .SVG extension still fails", async () => {
  await resetSeed();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  const svg = new TextEncoder().encode("<svg onload=\"alert(1)\"></svg>");
  await assertFails(
    uploadBytes(ref(storage, "products/biz-1/Photo.SVG"), svg, {
      contentType: "image/svg+xml",
    })
  );
});

rulesTest("17d. uppercase .HTML extension still fails", async () => {
  await resetSeed();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  const html = new TextEncoder().encode("<html></html>");
  await assertFails(
    uploadBytes(ref(storage, "products/biz-1/Photo.HTML"), html, {
      contentType: "text/html",
    })
  );
});

rulesTest(
  "17e. uppercase extension does not bypass cross-business isolation",
  async () => {
    await resetSeed();
    const storage = (await env()).authenticatedContext("seller-2").storage();
    await assertFails(
      uploadBytes(ref(storage, "products/biz-1/Photo.JPG"), validJpegBytes, {
        contentType: "image/jpeg",
      })
    );
  }
);

rulesTest(
  "17f. oversized image with uppercase extension still fails",
  async () => {
    await resetSeed();
    const storage = (await env()).authenticatedContext("seller-1").storage();
    const tooLarge = new Uint8Array(11 * 1024 * 1024); // > 10MB product cap
    await assertFails(
      uploadBytes(ref(storage, "products/biz-1/Big.JPG"), tooLarge, {
        contentType: "image/jpeg",
      })
    );
  }
);

rulesTest("products_raw path follows the same authorization", async () => {
  await resetSeed();
  const storage = (await env()).authenticatedContext("seller-2").storage();
  await assertFails(
    uploadBytes(
      ref(storage, "products_raw/biz-1/abc_photo.jpg"),
      validJpegBytes,
      { contentType: "image/jpeg" }
    )
  );
});
