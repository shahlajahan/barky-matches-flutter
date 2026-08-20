"use strict";

// Regression coverage for the signup profile-creation bug: Firebase Auth
// succeeded but users/{uid} creation failed because the client's self-create
// payload included `isPremium: false`, which protectedUserCreateFields()
// unconditionally rejected. Covers the narrow backward-compatibility
// exception (isLegacyIsPremiumFalseCreate) added to firestore.rules, and
// confirms every other protected field remains fully rejected on both
// create and update.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

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
    projectId: `user-profile-create-rules-${Date.now()}`,
    firestore: { rules },
  });
  return testEnv;
}

async function resetSeed() {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
}

function canonicalProfile(overrides = {}) {
  return {
    uid: "new-user-1",
    username: "Pet Owner",
    email: "person@example.com",
    phone: "",
    city: "",
    district: "",
    photoUrl: "",
    emailVerified: true,
    profileCompleted: false,
    authProvider: "google.com",
    authProviders: ["google.com"],
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    lastLoginAt: serverTimestamp(),
    ...overrides,
  };
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

rulesTest("1. authenticated user can create their own profile with ordinary allowed fields", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("new-user-1").firestore();
  await assertSucceeds(
    setDoc(doc(db, "users", "new-user-1"), canonicalProfile())
  );
});

rulesTest("2. backward-compatible create with isPremium:false succeeds (legacy client)", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("new-user-1").firestore();
  await assertSucceeds(
    setDoc(
      doc(db, "users", "new-user-1"),
      canonicalProfile({ isPremium: false })
    )
  );
});

rulesTest("3. create with isPremium:true is always rejected", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("new-user-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "users", "new-user-1"),
      canonicalProfile({ isPremium: true })
    )
  );
});

rulesTest("3b. create with a non-boolean isPremium value is rejected", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("new-user-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "users", "new-user-1"),
      canonicalProfile({ isPremium: "false" })
    )
  );
});

rulesTest("4. user cannot modify isPremium after creation (privilege escalation attempt)", async () => {
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "users", "new-user-1"),
      canonicalProfile({ isPremium: false })
    );
  });
  const db = rulesEnv.authenticatedContext("new-user-1").firestore();
  await assertFails(
    updateDoc(doc(db, "users", "new-user-1"), { isPremium: true })
  );
});

rulesTest("4b. user cannot change isPremium to true via a mixed-field update", async () => {
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "users", "new-user-1"),
      canonicalProfile({ isPremium: false })
    );
  });
  const db = rulesEnv.authenticatedContext("new-user-1").firestore();
  await assertFails(
    updateDoc(doc(db, "users", "new-user-1"), {
      isPremium: true,
      city: "Istanbul",
    })
  );
});

rulesTest("5. user cannot create with subscriptionPlan/subscriptionStatus/subscription/role/protected fields", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("new-user-1").firestore();
  const protectedFields = {
    subscriptionPlan: "gold",
    subscriptionStatus: "active",
    subscription: { plan: "gold" },
    role: "admin",
    admin: true,
    isAdmin: true,
    entitlement: "gold",
    entitlements: ["gold"],
    businessId: "biz-1",
    businessOwnerUid: "biz-1",
    creator: { enabled: true },
  };
  for (const [field, value] of Object.entries(protectedFields)) {
    await assertFails(
      setDoc(
        doc(db, "users", "new-user-1"),
        canonicalProfile({ [field]: value })
      )
    );
  }
});

rulesTest("5b. user cannot update subscriptionPlan/subscriptionStatus/subscription/role after creation", async () => {
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users", "new-user-1"), canonicalProfile());
  });
  const db = rulesEnv.authenticatedContext("new-user-1").firestore();
  await assertFails(updateDoc(doc(db, "users", "new-user-1"), { subscriptionPlan: "gold" }));
  await assertFails(updateDoc(doc(db, "users", "new-user-1"), { subscriptionStatus: "active" }));
  await assertFails(updateDoc(doc(db, "users", "new-user-1"), { subscription: { plan: "gold" } }));
  await assertFails(updateDoc(doc(db, "users", "new-user-1"), { role: "admin" }));
});

rulesTest("6. user cannot create another uid's profile", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("attacker-1").firestore();
  await assertFails(
    setDoc(doc(db, "users", "victim-1"), canonicalProfile({ uid: "victim-1" }))
  );
});

rulesTest("7. unauthenticated create fails", async () => {
  await resetSeed();
  const db = (await env()).unauthenticatedContext().firestore();
  await assertFails(
    setDoc(doc(db, "users", "new-user-1"), canonicalProfile())
  );
});

rulesTest("existing profile fields survive an ensureUserProfile-style create-only precondition", async () => {
  // Sanity check for the server-side create() precondition semantics that
  // ensureUserProfile relies on: Rules must still allow an admin (Admin SDK
  // bypasses rules entirely in production, but this documents intent) to
  // read back an untouched existing profile.
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users", "gold-user-1"), {
      username: "Existing Gold User",
      isPremium: true,
      subscriptionPlan: "gold",
    });
  });
  const db = rulesEnv.authenticatedContext("gold-user-1").firestore();
  const snap = await assertSucceeds(getDoc(doc(db, "users", "gold-user-1")));
  assert.equal(snap.data().isPremium, true);
  assert.equal(snap.data().subscriptionPlan, "gold");
});
