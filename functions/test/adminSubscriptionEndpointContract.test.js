"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");

function adminUpdateSubscriptionSource() {
  const source = fs.readFileSync("index.js", "utf8");
  const start = source.indexOf("exports.adminUpdateSubscription = onCall(");
  assert.notEqual(start, -1);
  const end = source.indexOf("\n\nexports.activateSubscription", start);
  assert.notEqual(end, -1);
  return source.slice(start, end);
}

test("adminUpdateSubscription is admin-only and rejects nonexistent users", () => {
  const source = adminUpdateSubscriptionSource();
  assert.match(source, /await requireAdmin\(database, request\)/);
  assert.match(
    source,
    /if \(!userSnap\.exists\) \{\s*throw new HttpsError\("not-found", "Target user does not exist\."\);/s
  );
  assert.ok(
    source.indexOf("if (!userSnap.exists)") <
      source.indexOf("transaction.set(subscriptionRef")
  );
});

test("adminUpdateSubscription writes consistent merge projections", () => {
  const source = adminUpdateSubscriptionSource();
  assert.match(source, /sourceUpdates: \{admin_grant: next\}/);
  assert.match(source, /transaction\.set\(subscriptionRef, canonical, \{ merge: true \}\)/);
  assert.match(source, /transaction\.set\(userRef, userEntitlements, \{ merge: true \}\)/);
});
