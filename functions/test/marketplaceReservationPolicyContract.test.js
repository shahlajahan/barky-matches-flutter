"use strict";

// Marketplace Revision 45 §0.43 — contract tests for the frozen stock
// reservation, idempotency and release policy.
//
// This revision is documentation-only, so these tests do two jobs and keep
// them clearly apart:
//
//   1. they pin the FROZEN TEXT — that every decision the next slice needs is
//      actually written down, and that each unresolved item is named and
//      fail-closed; and
//   2. they check that text against the REAL implementation constants and
//      transactions, so the contract cannot describe semantics the code does
//      not have.
//
// Follows the existing plan-contract convention of
// `marketplacePublicVisibilityContract.test.js` and
// `pilotProductTaxonomyContract.test.js`.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const REPO = path.resolve(__dirname, "..", "..");
const read = (rel) => fs.readFileSync(path.join(REPO, rel), "utf8");

const plan = read(
  "docs/plans/marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md"
);

/// The revision under test, isolated so a match cannot be satisfied by
/// unrelated prose elsewhere in a 6,000-line document.
const REV45 = (() => {
  const start = plan.indexOf("### 0.43 Revision 45 change log");
  assert.ok(start > 0, "Revision 45 §0.43 must exist");
  const next = plan.indexOf("\n## ", start);
  return plan.slice(start, next === -1 ? plan.length : next);
})();

const constants = require("../src/inventory/inventoryConstants");
const transactionsSource = read(
  "functions/src/inventory/inventoryTransactions.js"
);
const coordinatorSource = read(
  "functions/src/inventory/inventoryCheckoutCoordinator.js"
);
const releaseSource = read(
  "functions/src/inventory/inventoryReleaseCoordinator.js"
);
const rulesSource = read("firestore.rules");

// =====================================================================
// One inventory formula, and it matches the code
// =====================================================================

test("exactly one inventory formula is frozen, and the code computes it", () => {
  assert.match(
    REV45,
    /`availableStock`\s*\|\s*\*\*`stock − reservedStock`\*\*/,
    "availableStock must be frozen as stock minus reservedStock"
  );
  // The reserve path must gate on that same expression.
  assert.match(
    transactionsSource,
    /if \(stock - reservedStock < quantity\)/,
    "the reserve transaction must gate on stock - reservedStock"
  );
  // And availableStock must not be a stored field anywhere.
  assert.match(REV45, /derived, never stored/);
});

test("stock and reservedStock have unambiguous, non-overlapping meanings", () => {
  assert.match(REV45, /\*\*physical on-hand quantity\*\*\. NOT decremented at reservation/);
  assert.match(REV45, /quantity held by currently-open reservations/);

  // Reserve touches reservedStock only.
  assert.match(transactionsSource, /const afterReservedStock = reservedStock \+ quantity;/);
  // Commit decrements BOTH.
  assert.match(transactionsSource, /const afterStock = stock - quantity;\n\s*const afterReservedStock = reservedStock - quantity;/);
});

test("the invariants are frozen and enforced in-transaction, never clamped", () => {
  for (const clause of [
    "non-negative integers",
    "`stock >= reservedStock`",
    "fails closed",
  ]) {
    assert.ok(REV45.includes(clause), `the contract must freeze: ${clause}`);
  }
  assert.match(REV45, /manualReview: true.*rather than clamping/s);
  // The code raises rather than clamps.
  assert.match(transactionsSource, /inventory_invariant_violation/);
  assert.match(transactionsSource, /"stock cannot be less than reservedStock"/);
});

// =====================================================================
// Reservation lifecycle
// =====================================================================

test("every reservation state in the code is accounted for in the contract", () => {
  const states = Object.values(constants.RESERVATION_STATUS);
  assert.equal(states.length, 6);

  // Scoped to the ENUMERATION sentence, not the whole revision: a state that
  // merely appears somewhere in the transition prose is not the same as one
  // the contract declares part of the closed set.
  const enumeration = REV45.slice(
    REV45.indexOf("The states are exactly the six `RESERVATION_STATUS` values"),
    REV45.indexOf("The permitted transitions are")
  );
  assert.ok(enumeration.length > 60, "the enumeration sentence must exist");
  for (const state of states) {
    assert.ok(
      enumeration.includes(`\`${state}\``),
      `state ${state} must be enumerated in the closed set`
    );
  }

  // And the transitions must cover every non-initial state as a destination.
  const transitions = REV45.slice(
    REV45.indexOf("The permitted transitions are"),
    REV45.indexOf("are **terminal**")
  );
  for (const state of states.filter((s) => s !== "reserving")) {
    assert.ok(
      transitions.includes(`\`${state}\``),
      `state ${state} must appear as a transition endpoint`
    );
  }
});

test("terminal states are named, and release/commit are mutually exclusive", () => {
  assert.match(REV45, /are \*\*terminal\*\*/);
  assert.match(REV45, /Release and commit are mutually exclusive/);
  // The code refuses to release anything that is not currently reserved,
  // which is what makes that exclusion real.
  assert.match(
    transactionsSource,
    /reservation_not_releasable/,
    "release must refuse a non-reserved reservation"
  );
  assert.match(transactionsSource, /"Only reserved inventory can be released"/);
});

test("every operation is idempotent through a deterministic operation id", () => {
  assert.match(REV45, /deterministic `operationId`/);
  assert.match(REV45, /retry is safe at every level/);
  assert.match(transactionsSource, /operationId/);
});

// =====================================================================
// TTL and clock authority
// =====================================================================

test("the TTL is frozen and equals the implemented lease", () => {
  assert.equal(constants.DEFAULT_RESERVATION_LEASE_MS, 15 * 60 * 1000);
  assert.match(REV45, /\*\*15 minutes\*\*/);
  assert.match(REV45, /beginning when the reservation is created/);
  assert.match(REV45, /\*\*Firestore server clock\*\*.*never a client clock/s);
});

test("the unresolved provider fact is named, and its consequence is fail-closed", () => {
  assert.match(REV45, /UNRESOLVED-2 — provider session lifetime/);
  assert.match(REV45, /records \*\*no\*\* İş Bankası or iyzico session\/callback expiry fact/);
  assert.match(REV45, /none was invented and no provider was contacted/);
  // A late success must not silently re-reserve or auto-refund.
  assert.match(REV45, /\*\*No automatic re-reservation and no automatic refund\.\*\*/);
  assert.match(REV45, /manual_review/);
  assert.match(releaseSource, /recordLatePaymentAfterExpiry/);
  assert.match(releaseSource, /inventoryLatePaymentRecoveries/);
});

// =====================================================================
// Idempotency
// =====================================================================

test("idempotency is customer-scoped by construction", () => {
  assert.match(REV45, /idempotency is customer-scoped by construction/);
  assert.match(REV45, /the same raw key used by two customers is two independent attempts/);
  // The attempt document id embeds the buyer.
  assert.match(
    coordinatorSource,
    /function attemptDocumentId\(buyerUid, checkoutAttemptId\)/
  );
  assert.match(coordinatorSource, /encodeURIComponent\(buyerUid\)/);
});

test("the intent fingerprint inputs are frozen and match the implementation", () => {
  for (const field of ["businessId", "productId", "quantity", "unitPrice", "carrier"]) {
    assert.ok(
      REV45.includes(`\`${field}\``),
      `the fingerprint must freeze the input ${field}`
    );
  }
  assert.match(REV45, /plus request `currency` and computed `amount`/);
  // Exclusions are explicit, not accidental.
  assert.match(REV45, /\*\*deliberately excluded\*\*/);
  // The real fingerprint uses exactly those item fields.
  const fn = coordinatorSource.slice(
    coordinatorSource.indexOf("function checkoutFingerprint"),
    coordinatorSource.indexOf("function attemptDocumentId")
  );
  for (const field of ["businessId", "productId", "quantity", "unitPrice", "carrier"]) {
    assert.ok(fn.includes(field), `checkoutFingerprint must hash ${field}`);
  }
  for (const excluded of ["address", "billing", "legal", "provider"]) {
    assert.ok(
      !fn.includes(excluded),
      `checkoutFingerprint must not hash ${excluded}`
    );
  }
});

test("same key with a different intent is a conflict, and one attempt yields one order", () => {
  assert.match(REV45, /same key \+ different fingerprint is an \*\*idempotency conflict\*\*/);
  assert.match(
    REV45,
    /\*\*One successful logical attempt ⇒ at most one canonical order tree and one net reservation effect\.\*\*/
  );
  assert.match(REV45, /the client never chooses order ownership|never chooses order ownership/);
});

// =====================================================================
// Refund is not restock
// =====================================================================

test("refund, return and restock are frozen as three separate things", () => {
  assert.match(
    REV45,
    /\*\*A financial refund is never a physical restock\*\*/
  );
  assert.match(REV45, /this revision authorizes no automatic restock anywhere/);
  // The restock transaction demands physical receipt and an explicit flag.
  assert.match(
    transactionsSource,
    /line\.physicallyReceived !== true \|\| typeof line\.restockable !== "boolean"/
  );
});

test("the cancellation/refund/return matrix covers every frozen scenario", () => {
  for (const scenario of [
    "Payment failed, cancelled, or expired",
    "Cancelled after payment, before fulfilment",
    "Full or partial monetary refund",
    "Return requested / approved",
    "Damaged, lost, chargeback",
  ]) {
    assert.ok(REV45.includes(scenario), `the matrix must cover: ${scenario}`);
  }
});

// =====================================================================
// Payment sequencing and multi-business
// =====================================================================

test("external payment calls are excluded from the transaction, and the sequence is frozen", () => {
  assert.match(
    REV45,
    /External payment calls must never occur inside a Firestore transaction/
  );
  for (const step of [
    "claim the attempt",
    "commit the pending order tree",
    "create the external payment session",
    "finalize through the idempotent callback",
  ]) {
    assert.ok(REV45.includes(step), `the sequence must include: ${step}`);
  }
  // Marketplace and subscription checkout must not be conflated.
  assert.match(REV45, /web-subscription\*\* checkout are separate paths/);
});

test("multi-business behaviour is explicit and mixed currency fails closed", () => {
  assert.match(REV45, /One attempt may contain several businesses/);
  assert.match(REV45, /\*\*all-or-nothing\*\*/);
  assert.match(REV45, /\*\*Mixed currency fails closed\.\*\*/);
  assert.match(REV45, /UNRESOLVED-3/);
});

// =====================================================================
// Rules authority and the rollout target
// =====================================================================

test("the Rules authority position is frozen and matches the current file", () => {
  assert.match(REV45, /`create\/update\/delete: if false`/);
  // Orders really are closed (Revision 44).
  const orders = rulesSource.slice(
    rulesSource.indexOf("match /orders/{orderId}"),
    rulesSource.indexOf("match /sellerOrders/{sellerOrderId}")
  );
  assert.match(orders, /allow create: if false;/);
  // reservedStock really is server-owned.
  assert.ok(rulesSource.includes("reservedStock"));
  // The implicit-deny gap is recorded as something the next slice must close.
  assert.match(REV45, /\*\*no `match` block at all\*\*/);
  assert.match(REV45, /correct but implicit/);
});

test("the rollout target leaves no silent unprotected default path", () => {
  assert.match(REV45, /\*\*M3 unconditional for every new Marketplace order\*\*/);
  assert.match(REV45, /no silent unprotected default path/);
  // Ordering matters: release before reserve.
  assert.match(REV45, /enable the M5 release\/expiry workers first/);
  assert.match(
    REV45,
    /disabling M3 must never orphan an existing reservation/
  );
});

test("the implementation slices are ordered, bounded and prerequisite-linked", () => {
  for (let n = 1; n <= 9; n += 1) {
    assert.ok(REV45.includes(`7F-${n}`), `slice 7F-${n} must be listed`);
  }
  assert.match(REV45, /Each is bounded to one commit/);
});

// =====================================================================
// Every unresolved item is named and fail-closed
// =====================================================================

test("all three unresolved items are named, and each fails closed", () => {
  for (const item of ["UNRESOLVED-1", "UNRESOLVED-2", "UNRESOLVED-3"]) {
    assert.ok(REV45.includes(item), `${item} must be named`);
  }
  // UNRESOLVED-1: an untracked product cannot be sold rather than being sold unchecked.
  assert.match(REV45, /\*\*fails closed\*\* \(cannot be reserved, therefore cannot be sold\)/);
  assert.match(REV45, /remain owner\/provider decisions and are fail-closed until settled/);
});

test("the revision does not describe dormant M3 behaviour as active Production behaviour", () => {
  assert.match(REV45, /\*\*It is documentation-only\*\*/);
  assert.match(REV45, /M3\/M5 stay disabled/);
  assert.match(REV45, /The Marketplace remains Pre-pilot/);
  assert.match(REV45, /\*\*M\. This revision is documentation-only\.\*\*/);
});

test("historical revisions are not rewritten — Revision 44 §G survives in place", () => {
  const rev44 = plan.slice(
    plan.indexOf("### 0.42 Revision 44 change log"),
    plan.indexOf("### 0.43 Revision 45 change log")
  );
  assert.ok(rev44.length > 1000, "Revision 44 must remain present");
  assert.ok(
    rev44.includes("**G. NOT closed — precise blockers.**"),
    "Revision 44's own unresolved list must remain readable in place"
  );
  // And Revision 45 supersedes it by explicit reference rather than edit.
  assert.match(REV45, /Revision 44 §G1\/§G2\/§G3 recorded/);
});
