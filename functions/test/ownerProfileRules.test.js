"use strict";

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
    projectId: `owner-profile-rules-${Date.now()}`,
    firestore: { rules },
  });

  return testEnv;
}

async function resetSeed() {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", "owner-1"), {
      displayName: "Existing Owner",
      email: "owner@example.com",
      phone: "+905550000000",
      role: "user",
      isPremium: true,
      subscription: { plan: "premium" },
      createdAt: "created",
      notificationSettings: { email: true },
    });
    await setDoc(doc(db, "users", "other-1"), {
      displayName: "Other Owner",
      email: "other@example.com",
      role: "user",
    });
    await setDoc(doc(db, "dogs", "dog-1"), {
      ownerId: "owner-1",
      name: "Miso",
      ownerProfile: {
        ownerName: "Existing Owner",
        email: "owner@example.com",
      },
      createdAt: "created",
      medical: { allergies: "none" },
    });
    await setDoc(doc(db, "dogs", "other-dog"), {
      ownerId: "other-1",
      name: "Other Dog",
    });
  });
}

function ownerProfileDogUpdate() {
  return {
    "ownerProfile.ownerName": "Ada Lovelace",
    "ownerProfile.ownerPhone": "+905551112233",
    "ownerProfile.emergencyContact": "",
    "ownerProfile.emergencyPhone": "",
    "ownerProfile.city": "Istanbul",
    "ownerProfile.district": "Kadikoy",
    "ownerProfile.address": "Moda Cd. 1",
    ownerProfileUpdatedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

rulesTest("authenticated owner can read their own profile", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertSucceeds(getDoc(doc(db, "users", "owner-1")));
});

rulesTest("authenticated owner can update approved editable user fields", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertSucceeds(
    setDoc(
      doc(db, "users", "owner-1"),
      {
        displayName: "Ada Lovelace",
        phone: "+905551112233",
        city: "Istanbul",
        district: "Kadikoy",
        address: "Moda Cd. 1",
        emergencyContact: "",
        emergencyPhone: "",
        profileVersion: 1,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    )
  );
});

rulesTest("authenticated owner can update dog owner profile snapshot fields", async () => {
  await resetSeed();
  const rulesEnv = await env();
  const db = rulesEnv.authenticatedContext("owner-1").firestore();
  await assertSucceeds(
    updateDoc(doc(db, "dogs", "dog-1"), ownerProfileDogUpdate())
  );

  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const snap = await getDoc(doc(context.firestore(), "dogs", "dog-1"));
    const data = snap.data();
    assert.equal(data.ownerProfile.ownerPhone, "+905551112233");
    assert.equal(data.ownerProfile.city, "Istanbul");
    assert.equal(data.ownerProfile.district, "Kadikoy");
    assert.equal(data.ownerProfile.address, "Moda Cd. 1");
    assert.equal(data.ownerProfile.email, "owner@example.com");
    assert.deepEqual(data.medical, { allergies: "none" });
    assert.equal(data.createdAt, "created");
  });
});

rulesTest("optional empty emergency contact fields are allowed on dog snapshot", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertSucceeds(
    updateDoc(
      doc(db, "dogs", "dog-1"),
      {
        "ownerProfile.emergencyContact": "",
        "ownerProfile.emergencyPhone": "",
        ownerProfileUpdatedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }
    )
  );
});

rulesTest("saving the same owner profile form multiple times remains stable", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertSucceeds(
    updateDoc(doc(db, "dogs", "dog-1"), ownerProfileDogUpdate())
  );
  await assertSucceeds(
    updateDoc(doc(db, "dogs", "dog-1"), ownerProfileDogUpdate())
  );
});

rulesTest("a user cannot read or update another user's private owner profile", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertFails(getDoc(doc(db, "users", "other-1")));
  await assertFails(
    setDoc(doc(db, "users", "other-1"), { city: "Istanbul" }, { merge: true })
  );
});

rulesTest("a user cannot update another user's dog owner profile snapshot", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertFails(
    updateDoc(doc(db, "dogs", "other-dog"), ownerProfileDogUpdate())
  );
});

rulesTest("unauthenticated reads and writes remain denied", async () => {
  await resetSeed();
  const db = (await env()).unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, "users", "owner-1")));
  await assertFails(
    setDoc(doc(db, "users", "owner-1"), { city: "Istanbul" }, { merge: true })
  );
});

rulesTest("protected user fields cannot be changed by the document owner", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  for (const protectedUpdate of [
    { uid: "other-1" },
    { role: "admin" },
    { admin: true },
    { isAdmin: true },
    { isPremium: false },
    { subscription: { plan: "free" } },
    { ownerId: "other-1" },
  ]) {
    await assertFails(
      setDoc(doc(db, "users", "owner-1"), protectedUpdate, { merge: true })
    );
  }
});

rulesTest("unapproved dog ownerProfile fields are denied", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("owner-1").firestore();
  await assertFails(
    updateDoc(
      doc(db, "dogs", "dog-1"),
      {
        "ownerProfile.email": "changed@example.com",
        ownerProfileUpdatedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }
    )
  );
});
