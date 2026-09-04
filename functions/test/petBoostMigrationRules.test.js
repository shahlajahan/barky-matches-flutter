"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

// Pet Boost migration Rules coverage.
//
// STALE FIXTURE REPAIRED (2026-09-04). The "normal profile edit is still
// allowed" half of this file previously sent:
//
//   ownerProfile: "updated"          // a STRING
//
// and expected HTTP 200. That fixture was written on 2026-08-08 (37a28df)
// and became invalid on 2026-08-16, when fb94323 added the canonical type
// constraint to `isOwnerProfileSnapshotUpdate()` in firestore.rules:
//
//   && (!('ownerProfile' in request.resource.data)
//       || request.resource.data.ownerProfile is map)
//
// `ownerProfile` is a MAP and must remain one; the same commit also bounded
// which of its keys an owner may change (`ownerProfileEditableFields()`).
// The denial this file was reporting is therefore CORRECT Rules behaviour on
// a malformed update, not an over-restriction — the test fixture was stale.
// The rule is not weakened here.
//
// The repair: the ordinary-edit proof now sends a well-formed map touching
// only an editable key, so it genuinely exercises the allow path; the
// malformed string update is retained as an explicit DENIAL proof; and the
// forged-boost-field protections are unchanged.

const fs = require("node:fs");
const path = require("node:path");

// Source contract, always executed (no emulator required).
//
// The behavioural denial below is defence-in-depth: with the `is map` clause
// removed, a string `ownerProfile` is still denied because
// `changedOwnerProfileKeysAreAllowed()` calls `.diff()` on it and an erroring
// predicate denies. That is good, but it means a behavioural test alone
// cannot detect the removal of the specific clause this file cites as the
// canonical contract. This assertion pins it.
test("ownerProfile's map type constraint is present in firestore.rules", () => {
  const rules = fs
    .readFileSync(path.resolve(__dirname, "../../firestore.rules"), "utf8")
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/^[ \t]*\/\/.*$/gm, "");
  const snapshot = rules.match(
    /function isOwnerProfileSnapshotUpdate\(\)[\s\S]*?\n    \}/
  );
  assert.ok(snapshot, "isOwnerProfileSnapshotUpdate() not found");
  assert.match(snapshot[0], /request\.resource\.data\.ownerProfile is map/);
  // And the editable-key bound is still applied on both the changed and the
  // newly-created path, so a map alone is not sufficient authority.
  assert.match(snapshot[0], /changedOwnerProfileKeysAreAllowed\(\)/);
  assert.match(snapshot[0], /createdOwnerProfileKeysAreAllowed\(\)/);
});

const projectId = process.env.FIREBASE_PROJECT_ID || "demo-petsupo";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const base = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents`;

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  test("Pet Boost migration Rules coverage", {skip: "run with Firestore and Auth emulators"}, () => {});
} else {
  if (!admin.apps.length) admin.initializeApp({projectId});
  const db = admin.firestore();

  async function auth(label) {
    const response = await fetch(
      `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=test-key`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({email: `${label}-${Date.now()}@example.test`, password: "Password123!", returnSecureToken: true}),
      },
    );
    assert.equal(response.ok, true);
    return response.json();
  }

  // Encodes a JS value as a Firestore REST typed value. Extended for
  // mapValue so a well-formed `ownerProfile` map can be sent — the previous
  // helper could only produce strings, which is how the stale fixture came
  // to violate the `is map` contract in the first place.
  function typed(item) {
    if (typeof item === "boolean") return {booleanValue: item};
    if (typeof item === "number") return {integerValue: item};
    if (item && typeof item === "object" && !Array.isArray(item)) {
      return {mapValue: {fields: value(item)}};
    }
    return {stringValue: item};
  }

  function value(data) {
    return Object.fromEntries(
      Object.entries(data).map(([key, item]) => [key, typed(item)]),
    );
  }

  async function patch(path, data, token) {
    const mask = Object.keys(data).map((key) => `updateMask.fieldPaths=${key}`).join("&");
    return fetch(`${base}/${path}?${mask}`, {
      method: "PATCH",
      headers: {"content-type": "application/json", Authorization: `Bearer ${token}`},
      body: JSON.stringify({fields: value(data)}),
    });
  }

  async function create(path, data, token) {
    return fetch(`${base}/${path}`, {
      method: "POST",
      headers: {"content-type": "application/json", Authorization: `Bearer ${token}`},
      body: JSON.stringify({fields: value(data)}),
    });
  }

  // Fixture setup through the Admin SDK (bypasses Rules by construction).
  // `ownerProfile` is seeded as a MAP keyed by an editable field, matching
  // the canonical contract the Rules enforce.
  async function seedDog(dogId, ownerId) {
    await db.collection("dogs").doc(dogId).set({
      ownerId,
      name: "Old Name",
      ownerProfile: {ownerName: "Old Owner"},
      isSponsored: false,
      boostScore: 0,
      boostExpiresAt: "2026-08-01T00:00:00Z",
      sponsorshipType: "",
    });
  }

  test("legacy Pet Boost fields are not forgeable by the pet owner", async () => {
    const owner = await auth("pet-boost-rules-forge");
    await seedDog("rules-dog-forge", owner.localId);

    const forged = await patch("dogs/rules-dog-forge", {
      isSponsored: true,
      boostScore: 999,
      boostExpiresAt: "2099-01-01T00:00:00Z",
      sponsorshipType: "forged",
    }, owner.idToken);
    assert.equal(forged.status, 403);

    // Each boost field is independently protected, not merely rejected as a
    // batch — a single-field forge must fail on its own.
    for (const field of [
      {isSponsored: true},
      {boostScore: 999},
      {boostExpiresAt: "2099-01-01T00:00:00Z"},
      {sponsorshipType: "forged"},
    ]) {
      const single = await patch("dogs/rules-dog-forge", field, owner.idToken);
      assert.equal(
        single.status,
        403,
        `forging ${Object.keys(field)[0]} alone must be denied`,
      );
    }

    // Nothing was persisted by any of the denied attempts.
    const after = await db.collection("dogs").doc("rules-dog-forge").get();
    assert.equal(after.data().isSponsored, false);
    assert.equal(after.data().boostScore, 0);
    assert.equal(after.data().sponsorshipType, "");
  });

  test("an ordinary owner profile snapshot update is still allowed", async () => {
    const owner = await auth("pet-boost-rules-profile");
    await seedDog("rules-dog-profile", owner.localId);

    // Well-formed: ownerProfile stays a map and only an editable key changes.
    const normal = await patch("dogs/rules-dog-profile", {
      ownerProfile: {ownerName: "New Owner"},
      updatedAt: "2026-08-08T12:00:00Z",
    }, owner.idToken);
    assert.equal(normal.status, 200);

    const after = await db.collection("dogs").doc("rules-dog-profile").get();
    assert.deepEqual(after.data().ownerProfile, {ownerName: "New Owner"});
  });

  test("an ordinary allowlisted pet field edit is still allowed", async () => {
    const owner = await auth("pet-boost-rules-field");
    await seedDog("rules-dog-field", owner.localId);

    const renamed = await patch("dogs/rules-dog-field", {
      name: "New Name",
    }, owner.idToken);
    assert.equal(renamed.status, 200);

    const after = await db.collection("dogs").doc("rules-dog-field").get();
    assert.equal(after.data().name, "New Name");
  });

  test("ownerProfile must remain a map — a malformed update is denied", async () => {
    const owner = await auth("pet-boost-rules-malformed");
    await seedDog("rules-dog-malformed", owner.localId);

    // The exact shape the stale fixture used. firestore.rules requires
    // `request.resource.data.ownerProfile is map`, so this is denied, and
    // that denial is the correct contract rather than an over-restriction.
    const malformed = await patch("dogs/rules-dog-malformed", {
      ownerProfile: "updated",
      updatedAt: "2026-08-08T12:00:00Z",
    }, owner.idToken);
    assert.equal(malformed.status, 403);

    // A map carrying a NON-editable key is denied too, so the repaired
    // allow-path proof above cannot be satisfied by an over-broad rule.
    const outOfScope = await patch("dogs/rules-dog-malformed", {
      ownerProfile: {role: "admin"},
    }, owner.idToken);
    assert.equal(outOfScope.status, 403);

    const after = await db.collection("dogs").doc("rules-dog-malformed").get();
    assert.deepEqual(after.data().ownerProfile, {ownerName: "Old Owner"});
  });

  test("clients cannot write the promotion projection directly", async () => {
    const owner = await auth("pet-boost-rules-projection");
    const projection = await create("promotion_active?documentId=client-created", {
      targetType: "PET",
    }, owner.idToken);
    assert.equal(projection.status, 403);
  });
}
