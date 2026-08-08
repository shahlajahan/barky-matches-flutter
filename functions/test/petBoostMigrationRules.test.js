"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

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
        body: JSON.stringify({email: `${label}@example.test`, password: "Password123!", returnSecureToken: true}),
      },
    );
    assert.equal(response.ok, true);
    return response.json();
  }

  function value(data) {
    return Object.fromEntries(Object.entries(data).map(([key, item]) => {
      if (typeof item === "boolean") return [key, {booleanValue: item}];
      if (typeof item === "number") return [key, {integerValue: item}];
      return [key, {stringValue: item}];
    }));
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

  test("legacy Pet Boost fields are not forgeable while profile edits remain allowed", async () => {
    const owner = await auth("pet-boost-rules-owner");
    await db.collection("dogs").doc("rules-dog").set({
      ownerId: owner.localId,
      ownerProfile: {name: "Old"},
      isSponsored: false,
      boostScore: 0,
      boostExpiresAt: "2026-08-01T00:00:00Z",
      sponsorshipType: "",
    });

    const forged = await patch("dogs/rules-dog", {
      isSponsored: true,
      boostScore: 999,
      boostExpiresAt: "2099-01-01T00:00:00Z",
      sponsorshipType: "forged",
    }, owner.idToken);
    assert.equal(forged.status, 403);

    const normal = await patch("dogs/rules-dog", {
      ownerProfile: "updated",
      updatedAt: "2026-08-08T12:00:00Z",
    }, owner.idToken);
    assert.equal(normal.status, 200);

    const projection = await create("promotion_active?documentId=client-created", {
      targetType: "PET",
    }, owner.idToken);
    assert.equal(projection.status, 403);
  });
}
