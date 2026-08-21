"use strict";

// P1-A Slice 1 — Storage Rules foundation tests (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §9/§16). compliance_docs/ and compliance_quarantine/ are fully
// deny-by-default in Slice 1 — no upload path, no read path, for anyone,
// under any identity. Slice 2 introduces the server-issued
// upload-session boundary and its Storage create rule as one atomic
// unit; this file proves nothing has been pre-authorized ahead of that.
//
// Neither compliance_docs/ nor compliance_quarantine/'s rule calls
// firestore.get() (unlike hasAllowedProductImage()'s isBusinessOwner()
// check), so this file has no cross-service dependency and does not need
// the GCLOUD_PROJECT-matching fix marketplaceProductStorageRules.test.js
// required — a plain, unique per-run project ID is sufficient here.

const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc } = require("firebase/firestore");
const { ref, uploadBytes, getBytes } = require("firebase/storage");

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

async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: `p1a-slice1-storage-${Date.now()}`,
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
    await setDoc(doc(context.firestore(), "users", "admin-1"), {
      role: "admin",
    });
  });
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

const validPdfBytes = new Uint8Array([0x25, 0x50, 0x44, 0x46, 1, 2, 3, 4]); // "%PDF"

const PREFIXES = ["compliance_docs", "compliance_quarantine"];

for (const prefix of PREFIXES) {
  const objectPath = `${prefix}/biz-1/doc-1/evidence.pdf`;

  rulesTest(`${prefix}: owner upload fails`, async () => {
    await resetSeed();
    const storage = (await env()).authenticatedContext("seller-1").storage();
    await assertFails(
      uploadBytes(ref(storage, objectPath), validPdfBytes, {
        contentType: "application/pdf",
      })
    );
  });

  rulesTest(`${prefix}: admin client upload fails`, async () => {
    await resetSeed();
    const storage = (await env()).authenticatedContext("admin-1").storage();
    await assertFails(
      uploadBytes(ref(storage, objectPath), validPdfBytes, {
        contentType: "application/pdf",
      })
    );
  });

  rulesTest(`${prefix}: unauthenticated upload fails`, async () => {
    await resetSeed();
    const storage = (await env()).unauthenticatedContext().storage();
    await assertFails(
      uploadBytes(ref(storage, objectPath), validPdfBytes, {
        contentType: "application/pdf",
      })
    );
  });

  rulesTest(`${prefix}: owner read fails`, async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(ref(context.storage(), objectPath), validPdfBytes, {
        contentType: "application/pdf",
      });
    });
    const storage = rulesEnv.authenticatedContext("seller-1").storage();
    await assertFails(getBytes(ref(storage, objectPath)));
  });

  rulesTest(`${prefix}: public (unauthenticated) read fails`, async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(ref(context.storage(), objectPath), validPdfBytes, {
        contentType: "application/pdf",
      });
    });
    const storage = rulesEnv.unauthenticatedContext().storage();
    await assertFails(getBytes(ref(storage, objectPath)));
  });

  rulesTest(`${prefix}: cross-business read fails`, async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(ref(context.storage(), objectPath), validPdfBytes, {
        contentType: "application/pdf",
      });
    });
    const storage = rulesEnv.authenticatedContext("seller-2").storage();
    await assertFails(getBytes(ref(storage, objectPath)));
  });

  rulesTest(`${prefix}: cross-business write fails`, async () => {
    await resetSeed();
    const storage = (await env()).authenticatedContext("seller-2").storage();
    await assertFails(
      uploadBytes(ref(storage, objectPath), validPdfBytes, {
        contentType: "application/pdf",
      })
    );
  });

  rulesTest(`${prefix}: overwrite fails`, async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(ref(context.storage(), objectPath), validPdfBytes, {
        contentType: "application/pdf",
      });
    });
    const storage = rulesEnv.authenticatedContext("seller-1").storage();
    await assertFails(
      uploadBytes(ref(storage, objectPath), validPdfBytes, {
        contentType: "application/pdf",
      })
    );
  });

  rulesTest(`${prefix}: delete fails`, async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await uploadBytes(ref(context.storage(), objectPath), validPdfBytes, {
        contentType: "application/pdf",
      });
    });
    const { deleteObject } = require("firebase/storage");
    const storage = rulesEnv.authenticatedContext("seller-1").storage();
    await assertFails(deleteObject(ref(storage, objectPath)));
  });
}
