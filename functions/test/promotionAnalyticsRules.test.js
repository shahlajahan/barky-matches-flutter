"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  test("Promotion analytics Rules emulator coverage", {skip: "run with Firestore and Auth emulators"}, () => {});
} else {
  const projectId = process.env.FIREBASE_PROJECT_ID || "demo-petsupo";
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;
  const base = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents`;
  if (!admin.apps.length) admin.initializeApp({projectId});
  const db = admin.firestore();

  async function user(label) {
    const response = await fetch(`http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=test-key`, {
      method: "POST", headers: {"content-type": "application/json"},
      body: JSON.stringify({email: `${label}@m8.test`, password: "Password123!", returnSecureToken: true}),
    });
    assert.equal(response.ok, true);
    return response.json();
  }
  const value = (v) => typeof v === "number" ? {doubleValue: v} : {stringValue: v};
  async function request(path, method, token, fields = {}) {
    return fetch(`${base}/${path}`, {
      method,
      headers: {"content-type": "application/json", Authorization: `Bearer ${token}`},
      body: method === "GET" ? undefined : JSON.stringify({fields: Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, value(v)]))}),
    });
  }

  test("analytics raw events and aggregates are not client-writable; owner stats read is safe", async () => {
    const [owner, other] = await Promise.all([user("analytics-owner"), user("analytics-other")]);
    await db.collection("promotion_campaign_stats").doc("m8-rules-campaign").set({ownerUid: owner.localId, impressions: 2});
    assert.equal((await request("promotion_campaign_stats/m8-rules-campaign", "GET", owner.idToken)).status, 200);
    assert.equal((await request("promotion_campaign_stats/m8-rules-campaign", "GET", other.idToken)).status, 403);
    assert.equal((await request("promotion_campaign_stats/m8-rules-campaign", "PATCH", owner.idToken, {impressions: 999})).status, 403);
    assert.equal((await request("promotion_events?documentId=client-event", "POST", owner.idToken, {campaignId: "m8-rules-campaign", eventType: "CLICK"})).status, 403);
    assert.equal((await request("promotion_attributions?documentId=client-attribution", "POST", owner.idToken, {campaignId: "m8-rules-campaign", attributedRevenue: 999})).status, 403);
    assert.equal((await request("promotion_attributions/client-attribution", "GET", other.idToken)).status, 403);
    assert.equal((await request("promotion_reconciliation_cases?documentId=client-case", "POST", owner.idToken, {status: "CONVERGED"})).status, 403);
    assert.equal((await request("promotion_reconciliation_cases/client-case", "GET", owner.idToken)).status, 403);
  });
}
