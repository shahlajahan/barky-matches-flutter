"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

const projectId = process.env.FIREBASE_PROJECT_ID || "demo-petsupo";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const firestoreBase = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents`;

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  test("promotion Rules emulator coverage", {skip: "run with Firestore and Auth emulators"}, () => {});
} else {
  if (!admin.apps.length) admin.initializeApp({projectId});
  const db = admin.firestore();

  function authHeaders(idToken) {
    return idToken ? {Authorization: `Bearer ${idToken}`} : {};
  }

  async function createAuthUser(label) {
    const response = await fetch(
      `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=test-key`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({
          email: `${label}@example.test`,
          password: "Password123!",
          returnSecureToken: true,
        }),
      }
    );
    const body = await response.text();
    assert.equal(response.ok, true, body);
    return JSON.parse(body);
  }

  async function createAnonymousUser() {
    const response = await fetch(
      `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=test-key`,
      {
        method: "POST",
        headers: {"content-type": "application/json"},
        body: JSON.stringify({returnSecureToken: true}),
      }
    );
    const body = await response.text();
    assert.equal(response.ok, true, body);
    return JSON.parse(body);
  }

  function toFirestoreValue(value) {
    if (value === null) return {nullValue: null};
    if (typeof value === "boolean") return {booleanValue: value};
    if (typeof value === "number") return {doubleValue: value};
    return {stringValue: value};
  }

  async function createDocument(path, fields, idToken) {
    return fetch(`${firestoreBase}/${path}`, {
      method: "POST",
      headers: {"content-type": "application/json", ...authHeaders(idToken)},
      body: JSON.stringify({
        fields: Object.fromEntries(
          Object.entries(fields).map(([key, value]) => [key, toFirestoreValue(value)])
        ),
      }),
    });
  }

  async function patchDocument(path, fields, idToken) {
    const updateMask = Object.keys(fields)
      .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
      .join("&");
    return fetch(`${firestoreBase}/${path}?${updateMask}`, {
      method: "PATCH",
      headers: {"content-type": "application/json", ...authHeaders(idToken)},
      body: JSON.stringify({
        fields: Object.fromEntries(
          Object.entries(fields).map(([key, value]) => [key, toFirestoreValue(value)])
        ),
      }),
    });
  }

  async function readDocument(path, idToken) {
    return fetch(`${firestoreBase}/${path}`, {headers: authHeaders(idToken)});
  }

  test("promotion Rules keep plans/projections backend-owned and allow safe reads", async () => {
    const [owner, other, anonymous] = await Promise.all([
      createAuthUser("promotion-owner"),
      createAuthUser("promotion-other"),
      createAnonymousUser(),
    ]);
    await db.collection("promotion_plans").doc("pet_24h_v1").set({
      targetType: "PET",
      pricingModel: "FIXED_DURATION",
      durationHours: 24,
      price: 29,
      currency: "TRY",
      enabled: true,
      pricingVersion: 1,
      rankingLift: 10,
      displayOrder: 1,
      maxConcurrentPerOwner: 1,
      maxConcurrentPerBusiness: 1,
    });
    await db.collection("promotion_active").doc("campaign-1").set({
      targetType: "PET",
      targetId: "dog-1",
      campaignId: "campaign-1",
      startsAt: "2026-08-08T10:00:00Z",
      expiresAt: "2026-08-09T10:00:00Z",
      rankingWeight: 10,
    });
    await db.collection("promotion_campaigns").doc("campaign-1").set({
      campaignId: "campaign-1",
      targetType: "PET",
      targetId: "dog-1",
      ownerUid: owner.localId,
      pricingModel: "FIXED_DURATION",
      planId: "pet_24h_v1",
      pricingVersion: 1,
      durationHours: 24,
      currency: "TRY",
      price: 29,
      status: "active",
      paymentStatus: "paid",
      rankingWeight: 10,
      startsAt: "2026-08-08T10:00:00Z",
      expiresAt: "2026-08-09T10:00:00Z",
      version: 1,
    });

    assert.equal((await readDocument("promotion_plans/pet_24h_v1", owner.idToken)).status, 200);
    assert.equal((await readDocument("promotion_active/campaign-1", owner.idToken)).status, 200);
    assert.equal((await readDocument("promotion_plans/pet_24h_v1", anonymous.idToken)).status, 200);
    assert.equal((await readDocument("promotion_active/campaign-1", anonymous.idToken)).status, 200);
    assert.equal((await readDocument("promotion_campaigns/campaign-1")).status, 403);
    assert.equal((await readDocument("promotion_plans/pet_24h_v1", other.idToken)).status, 200);
    assert.equal((await readDocument("promotion_active/campaign-1", other.idToken)).status, 200);
    assert.equal((await readDocument("promotion_campaigns/campaign-1", owner.idToken)).status, 200);
    assert.equal((await readDocument("promotion_campaigns/campaign-1", other.idToken)).status, 403);

    assert.equal(
      (await createDocument("promotion_plans?documentId=fake", {
        targetType: "PET", pricingModel: "FIXED_DURATION", durationHours: 24,
        price: 1, currency: "TRY", enabled: true, pricingVersion: 1,
        rankingLift: 999, displayOrder: 1, maxConcurrentPerOwner: 1,
        maxConcurrentPerBusiness: 1,
      }, owner.idToken)).status,
      403
    );
    assert.equal(
      (await patchDocument("promotion_active/campaign-1", {rankingWeight: 999}, owner.idToken)).status,
      403
    );
    assert.equal(
      (await patchDocument("promotion_campaigns/campaign-1", {status: "active"}, owner.idToken)).status,
      403
    );
    assert.equal(
      (await createDocument("promotion_active?documentId=client-created", {
        campaignId: "client-created", targetType: "PET", targetId: "dog-1",
      }, owner.idToken)).status,
      403
    );
    assert.equal(
      (await createDocument("promotion_campaigns?documentId=anonymous-created", {
        campaignId: "anonymous-created", targetType: "PET", targetId: "dog-1", status: "active",
      })).status,
      403
    );
  });

  test("ordinary users cannot create or mutate authoritative campaign fields", async () => {
    const owner = await createAuthUser("promotion-campaign-owner");
    const campaign = {
      campaignId: "campaign-owner-1",
      targetType: "PET",
      targetId: "dog-1",
      ownerUid: owner.localId,
      pricingModel: "FIXED_DURATION",
      planId: "pet_24h_v1",
      pricingVersion: 1,
      durationHours: 24,
      currency: "TRY",
      price: 29,
      status: "active",
      rankingWeight: 10,
      startsAt: "2026-08-08T10:00:00Z",
      expiresAt: "2026-08-09T10:00:00Z",
      version: 1,
    };
    assert.equal(
      (await createDocument("promotion_campaigns?documentId=campaign-owner-1", campaign, owner.idToken)).status,
      403
    );
    await db.collection("promotion_campaigns").doc("campaign-owner-1").set(campaign);
    for (const [field, value] of [
      ["price", 1],
      ["pricingVersion", 99],
      ["paymentStatus", "paid"],
      ["rankingWeight", 999],
      ["startsAt", "2026-08-08T10:00:00Z"],
      ["expiresAt", "2027-08-08T10:00:00Z"],
    ]) {
      assert.equal(
        (await patchDocument("promotion_campaigns/campaign-owner-1", {[field]: value}, owner.idToken)).status,
        403,
        `client must not modify ${field}`,
      );
    }
  });
}
