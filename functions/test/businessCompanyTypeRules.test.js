"use strict";

// Defense-in-depth coverage: a client-side direct create of businesses/{id}
// or business_requests/{id} with a tampered/unsupported legal.companyType
// must be rejected by Firestore Rules, even though the primary enforcement
// point is the trusted registerBusiness Cloud Function (Admin SDK, bypasses
// Rules). See isValidOrAbsentCompanyType() in firestore.rules and
// functions/business/businessDocumentRequirements.js for the canonical
// enum values.

const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc, serverTimestamp } = require("firebase/firestore");

const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let testEnv;

function rulesTest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: `business-companytype-rules-${Date.now()}`,
    firestore: { rules },
  });
  return testEnv;
}

async function resetSeed() {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
}

function businessDoc(overrides = {}) {
  return {
    ownerUid: "owner-1",
    status: "pending",
    published: false,
    profile: { displayName: "Test Business" },
    ...overrides,
  };
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

rulesTest("businesses create accepts a valid companyType", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertSucceeds(
    setDoc(
      doc(db, "businesses", "owner-1"),
      businessDoc({ legal: { companyType: "sole_proprietorship" } })
    )
  );
});

rulesTest("businesses create accepts an absent companyType (legacy/other country)", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertSucceeds(
    setDoc(doc(db, "businesses", "owner-1"), businessDoc({ legal: { taxNumber: "1234567890" } }))
  );
});

rulesTest("businesses create rejects a tampered/unsupported companyType", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses", "owner-1"),
      businessDoc({ legal: { companyType: "definitely_not_a_real_type" } })
    )
  );
});

rulesTest("businesses create rejects a null-injected companyType posing as a string", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses", "owner-1"),
      businessDoc({ legal: { companyType: 12345 } })
    )
  );
});

rulesTest("business_requests create accepts a valid companyType", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertSucceeds(
    setDoc(doc(db, "business_requests", "req-1"), {
      uid: "owner-1",
      status: "pending",
      createdAt: serverTimestamp(),
      legal: { companyType: "limited_company" },
    })
  );
});

rulesTest("business_requests create rejects a tampered companyType", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertFails(
    setDoc(doc(db, "business_requests", "req-1"), {
      uid: "owner-1",
      status: "pending",
      createdAt: serverTimestamp(),
      legal: { companyType: "sahis" },
    })
  );
});

rulesTest("business_requests create still rejects a non-owner regardless of companyType", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("attacker-1").firestore();
  await assertFails(
    setDoc(doc(db, "business_requests", "req-1"), {
      uid: "owner-1",
      status: "pending",
      createdAt: serverTimestamp(),
      legal: { companyType: "sole_proprietorship" },
    })
  );
});
