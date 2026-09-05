"use strict";

// Marketplace Revision 40 §0.38 — the canonical customer order-ownership
// resolver. Pure logic; no emulator, no reads.

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const {
  assessOrderOwnership,
  resolveCanonicalBuyerUid,
  BUYER_IDENTITY_FIELDS,
  OWNERSHIP_RESULT,
} = require("../src/marketplace/orders/orderOwnership");

const own = (orderData, callerUid, orderExists = true) =>
  assessOrderOwnership({ orderData, callerUid, orderExists });

test("the buyer-identity field set is exactly the two frozen fields, in precedence order", () => {
  assert.deepEqual([...BUYER_IDENTITY_FIELDS], ["buyerUid", "userId"]);
  assert.equal(Object.isFrozen(BUYER_IDENTITY_FIELDS), true);
});

test("the canonical buyer is recognised through either historical field", () => {
  assert.equal(own({ buyerUid: "alice" }, "alice").owner, true);
  assert.equal(own({ userId: "alice" }, "alice").owner, true);
  assert.equal(own({ buyerUid: "alice", userId: "alice" }, "alice").owner, true);
  assert.equal(own({ buyerUid: "alice" }, "alice").buyerUid, "alice");
});

test("a foreign caller is denied for every field shape", () => {
  for (const order of [
    { buyerUid: "alice" },
    { userId: "alice" },
    { buyerUid: "alice", userId: "alice" },
  ]) {
    const verdict = own(order, "mallory");
    assert.equal(verdict.owner, false);
    assert.equal(verdict.result, OWNERSHIP_RESULT.NOT_OWNER);
    assert.equal(verdict.buyerUid, null, "a denial must not disclose the real buyer");
  }
});

test("an order with NO buyer identity is denied — the caller is never adopted as owner", () => {
  // This is the specific bug shape found in production code:
  // `orderData.buyerUid || orderData.userId || auth.uid` silently makes the
  // caller the owner of an unowned document.
  const verdict = own({ total: 100 }, "alice");
  assert.equal(verdict.owner, false);
  assert.equal(verdict.result, OWNERSHIP_RESULT.BUYER_IDENTITY_MISSING);
});

test("a wrong-typed buyer identity is malformed state, never treated as absent", () => {
  for (const bad of [42, true, {}, [], ""]) {
    const verdict = own({ buyerUid: bad }, "alice");
    assert.equal(verdict.owner, false, String(bad));
    assert.equal(verdict.result, OWNERSHIP_RESULT.BUYER_IDENTITY_MALFORMED, String(bad));
  }
});

test("conflicting historical buyer fields fail closed for BOTH named uids", () => {
  // Rules' own `isOrderOwner` ORs the two fields, so such a document is
  // readable by both. This resolver is deliberately stricter: a document
  // naming two different buyers has no single canonical owner.
  const conflicted = { buyerUid: "alice", userId: "bob" };
  for (const caller of ["alice", "bob", "mallory"]) {
    const verdict = own(conflicted, caller);
    assert.equal(verdict.owner, false, caller);
    assert.equal(verdict.result, OWNERSHIP_RESULT.BUYER_IDENTITY_CONFLICT, caller);
  }
});

test("null/undefined identity values are skipped, not treated as malformed", () => {
  assert.equal(own({ buyerUid: null, userId: "alice" }, "alice").owner, true);
  assert.equal(own({ buyerUid: undefined, userId: "alice" }, "alice").owner, true);
  assert.equal(own({ buyerUid: null, userId: null }, "alice").result, OWNERSHIP_RESULT.BUYER_IDENTITY_MISSING);
});

test("a missing order is denied without consulting identity at all", () => {
  const verdict = own({ buyerUid: "alice" }, "alice", false);
  assert.equal(verdict.owner, false);
  assert.equal(verdict.result, OWNERSHIP_RESULT.ORDER_MISSING);
});

test("a malformed order document is denied", () => {
  for (const bad of [null, undefined, "string", 42, []]) {
    const verdict = own(bad, "alice");
    assert.equal(verdict.owner, false, String(bad));
    assert.ok(
      [OWNERSHIP_RESULT.ORDER_MALFORMED, OWNERSHIP_RESULT.BUYER_IDENTITY_MISSING].includes(verdict.result)
    );
  }
});

test("a missing or malformed caller uid is denied", () => {
  for (const bad of [null, undefined, "", 42, {}]) {
    assert.equal(own({ buyerUid: "alice" }, bad).owner, false, String(bad));
  }
});

test("no verdict ever discloses the real buyer of a foreign or malformed order", () => {
  const cases = [
    [{ buyerUid: "alice" }, "mallory"],
    [{ buyerUid: "alice", userId: "bob" }, "mallory"],
    [{}, "mallory"],
    [{ buyerUid: 42 }, "mallory"],
  ];
  for (const [order, caller] of cases) {
    const serialized = JSON.stringify(own(order, caller));
    assert.equal(serialized.includes("alice"), false, serialized);
    assert.equal(serialized.includes("bob"), false, serialized);
  }
});

test("resolveCanonicalBuyerUid reports which field supplied the identity", () => {
  assert.equal(resolveCanonicalBuyerUid({ buyerUid: "a" }).field, "buyerUid");
  assert.equal(resolveCanonicalBuyerUid({ userId: "a" }).field, "userId");
  // Precedence only decides the reported field name; the conflict case is
  // already excluded, so it can never decide which uid wins.
  assert.equal(resolveCanonicalBuyerUid({ buyerUid: "a", userId: "a" }).field, "buyerUid");
});

test("the helper never reads buyer identity from request data — it has no such parameter", () => {
  const source = fs.readFileSync(
    path.join(__dirname, "..", "src", "marketplace", "orders", "orderOwnership.js"),
    "utf8"
  );
  const executable = source
    .split("\n")
    .filter((l) => !l.trim().startsWith("//"))
    .join("\n");
  for (const forbidden of ["request.data", "auth.uid"]) {
    assert.equal(executable.includes(forbidden), false, `must not reference ${forbidden}`);
  }
  // And it performs no reads and no writes of its own.
  for (const forbidden of ["firestore", ".get(", ".set(", ".update(", "runTransaction"]) {
    assert.equal(executable.includes(forbidden), false, `must not contain ${forbidden}`);
  }
});
