"use strict";

const assert = require("node:assert/strict");
const {test} = require("node:test");
const {
  hasValidGoldEntitlement,
  loadValidGoldEntitlement,
} = require("../subscription/businessEntitlementAuthorization");

const now = new Date("2026-01-01T00:00:00.000Z");
const future = new Date("2026-02-01T00:00:00.000Z");
const past = new Date("2025-12-01T00:00:00.000Z");

function gold(source) {
  return {
    plan: "gold",
    status: "active",
    source,
    expiresAt: future,
  };
}

test("future Gold from supported sources authorizes registration", () => {
  for (const source of ["admin_grant", "web_isbank", "app_store", "play_store"]) {
    assert.equal(hasValidGoldEntitlement(gold(source), now), true, source);
  }
});

test("expired Gold cannot authorize registration", () => {
  assert.equal(hasValidGoldEntitlement({...gold("app_store"), expiresAt: past}, now), false);
  assert.equal(hasValidGoldEntitlement({...gold("app_store"), status: "expired"}, now), false);
});

test("Premium, normal, and missing subscriptions cannot authorize registration", () => {
  assert.equal(hasValidGoldEntitlement({...gold("app_store"), plan: "premium"}, now), false);
  assert.equal(hasValidGoldEntitlement({plan: "normal", status: "active"}, now), false);
  assert.equal(hasValidGoldEntitlement({}, now), false);
});

test("registration authorization reads the canonical subscription document", async () => {
  const data = gold("admin_grant");
  const db = {
    collection: (name) => ({
      doc: (uid) => ({
        get: async () => ({
          exists: name === "subscriptions" && uid === "user-a",
          data: () => data,
        }),
      }),
    }),
  };
  assert.equal(await loadValidGoldEntitlement({db, uid: "user-a", now}), true);
  assert.equal(await loadValidGoldEntitlement({db, uid: "user-b", now}), false);
});
