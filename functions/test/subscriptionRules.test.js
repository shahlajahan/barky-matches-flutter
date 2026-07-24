"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);
const subscriptionMatch = rules.match(
  /match\s+\/subscriptions\/\{subscriptionId\}\s*\{([\s\S]*?)\n\s*\}/
);

test("subscription owners retain read access", () => {
  assert.ok(subscriptionMatch);
  assert.match(
    subscriptionMatch[1],
    /allow read: if isAdmin\(\) \|\| isSubscriptionOwner\(resource\.data\)/
  );
});

test("premium, gold, expiration, and delete writes are backend/admin only", () => {
  assert.ok(subscriptionMatch);
  assert.match(
    subscriptionMatch[1],
    /allow create, update, delete: if isAdmin\(\)/
  );
  assert.doesNotMatch(
    subscriptionMatch[1],
    /create.*isSubscriptionOwner|update.*isSubscriptionOwner|delete.*isSubscriptionOwner/
  );
});
