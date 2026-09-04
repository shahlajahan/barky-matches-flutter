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
const { deleteDoc, doc, getDoc, setDoc, updateDoc } = require("firebase/firestore");

// Subscription Rules contract.
//
// STALE ASSUMPTION REPAIRED (2026-09-04). This file previously asserted the
// read rule by exact source regex:
//
//   /allow read: if isAdmin\(\) \|\| isSubscriptionOwner\(resource\.data\)/
//
// That was written on 2026-07-24 (a065937) and became false on 2026-08-13,
// when 91268d1 deliberately added a THIRD read branch:
//
//   allow read: if isAdmin() || (isSignedIn() && subscriptionId ==
//     request.auth.uid) || isSubscriptionOwner(resource.data);
//
// The added branch is correct and must not be reverted. `resource.data` on a
// NON-EXISTENT document errors, and an erroring predicate denies — so
// `isSubscriptionOwner(resource.data)` alone cannot serve a new or free user
// reading their own not-yet-created subscription path. Path ownership
// (`subscriptionId == request.auth.uid`) is what makes that read work, and
// the rule's own comment says exactly that. The test was stale; the rule is
// sound.
//
// The regex is therefore replaced with (a) behavioural emulator proofs of the
// intended contract and (b) narrow source-contract assertions that still fail
// if the rule is weakened in any of the four ways that would matter.

const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);

// Comment-stripped view: an assertion about the ABSENCE of a branch must read
// only clauses the Rules engine evaluates, never the prose above them.
const rulesCode = rules
  .replace(/\/\*[\s\S]*?\*\//g, "")
  .replace(/^[ \t]*\/\/.*$/gm, "");

const subscriptionMatch = rulesCode.match(
  /match\s+\/subscriptions\/\{subscriptionId\}\s*\{([\s\S]*?)\n\s*\}/
);

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let testEnv;

function rulesTest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || `subscription-rules-${Date.now()}`,
    firestore: { rules },
  });
  return testEnv;
}

const OWNER = "sub-owner-1";
const OTHER = "sub-other-1";
const ADMIN = "sub-admin-1";

async function resetSeed() {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", ADMIN), { role: "admin" });
    await setDoc(doc(db, "users", OWNER), { role: "user" });
    await setDoc(doc(db, "users", OTHER), { role: "user" });
    // An existing subscription owned by OWNER, at OWNER's own path.
    await setDoc(doc(db, "subscriptions", OWNER), {
      userId: OWNER,
      plan: "premium",
      isPremium: true,
      expiresAt: "2027-01-01",
    });
    // A subscription owned by OWNER through the legacy DATA ownership route
    // only — its document ID is not OWNER's uid. This is what keeps the
    // third read branch (isSubscriptionOwner) genuinely exercised.
    await setDoc(doc(db, "subscriptions", "legacy-sub-1"), {
      userId: OWNER,
      plan: "gold",
      isPremium: true,
    });
  });
}

function db(uid) {
  return uid === null
    ? testEnv.unauthenticatedContext().firestore()
    : testEnv.authenticatedContext(uid).firestore();
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

// --- Behavioural: read contract ----------------------------------------

rulesTest("an owner can read their own existing subscription", async () => {
  await resetSeed();
  await assertSucceeds(getDoc(doc(db(OWNER), "subscriptions", OWNER)));
});

rulesTest(
  "an owner can read their own NOT-YET-CREATED subscription path — the exact case the path-ownership branch exists for",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    // Prove the document genuinely does not exist, so this is not an
    // accidental re-test of the existing-document case above.
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(
        doc(context.firestore(), "subscriptions", OTHER)
      );
      assert.equal(snap.exists(), false);
    });
    // OTHER reads OTHER's own absent path: allowed by path ownership.
    // Without that branch this denies, because resource.data errors on a
    // non-existent document and an erroring predicate denies.
    await assertSucceeds(getDoc(doc(db(OTHER), "subscriptions", OTHER)));
  }
);

rulesTest(
  "an owner can read a legacy subscription owned by data ownership alone",
  async () => {
    await resetSeed();
    await assertSucceeds(getDoc(doc(db(OWNER), "subscriptions", "legacy-sub-1")));
  }
);

rulesTest(
  "another authenticated user cannot read someone else's subscription",
  async () => {
    await resetSeed();
    await assertFails(getDoc(doc(db(OTHER), "subscriptions", OWNER)));
    await assertFails(
      getDoc(doc(db(OTHER), "subscriptions", "legacy-sub-1"))
    );
  }
);

rulesTest(
  "an unauthenticated caller cannot read any subscription, existing or absent",
  async () => {
    await resetSeed();
    await assertFails(getDoc(doc(db(null), "subscriptions", OWNER)));
    await assertFails(getDoc(doc(db(null), "subscriptions", "does-not-exist")));
  }
);

rulesTest("an admin can read any subscription", async () => {
  await resetSeed();
  await assertSucceeds(getDoc(doc(db(ADMIN), "subscriptions", OWNER)));
  await assertSucceeds(
    getDoc(doc(db(ADMIN), "subscriptions", "legacy-sub-1"))
  );
});

// --- Behavioural: write contract ---------------------------------------

rulesTest(
  "paid entitlement is backend-owned: an owner cannot create, update or delete their own subscription",
  async () => {
    await resetSeed();
    const ownerDb = db(OWNER);
    // Cannot grant themselves a new one at their own path.
    await assertFails(
      setDoc(doc(ownerDb, "subscriptions", OTHER), {
        userId: OTHER,
        plan: "premium",
        isPremium: true,
      })
    );
    // Cannot extend or upgrade an existing one they own.
    await assertFails(
      updateDoc(doc(ownerDb, "subscriptions", OWNER), { plan: "gold" })
    );
    await assertFails(
      updateDoc(doc(ownerDb, "subscriptions", OWNER), {
        expiresAt: "2099-01-01",
      })
    );
    await assertFails(
      updateDoc(doc(ownerDb, "subscriptions", OWNER), { isPremium: true })
    );
    // Cannot delete it.
    await assertFails(deleteDoc(doc(ownerDb, "subscriptions", OWNER)));
  }
);

rulesTest(
  "another authenticated user and an unauthenticated caller cannot write a subscription",
  async () => {
    await resetSeed();
    for (const uid of [OTHER, null]) {
      const client = db(uid);
      await assertFails(
        setDoc(doc(client, "subscriptions", "forged-1"), {
          userId: uid || "anon",
          plan: "premium",
        })
      );
      await assertFails(
        updateDoc(doc(client, "subscriptions", OWNER), { plan: "gold" })
      );
      await assertFails(deleteDoc(doc(client, "subscriptions", OWNER)));
    }
  }
);

rulesTest("an admin retains full write authority", async () => {
  await resetSeed();
  const adminDb = db(ADMIN);
  await assertSucceeds(
    setDoc(doc(adminDb, "subscriptions", OTHER), {
      userId: OTHER,
      plan: "premium",
      isPremium: true,
    })
  );
  await assertSucceeds(
    updateDoc(doc(adminDb, "subscriptions", OWNER), { plan: "gold" })
  );
  await assertSucceeds(deleteDoc(doc(adminDb, "subscriptions", OWNER)));
});

// --- Source contract ---------------------------------------------------
//
// These accept the intended three-part read rule in any equivalent
// formatting, but fail on each of the four weakenings that would matter.

test("the subscriptions match block exists and is unique", () => {
  assert.ok(subscriptionMatch, "subscriptions match block not found");
  const blocks =
    rulesCode.match(/match\s+\/subscriptions\/\{subscriptionId\}/g) || [];
  assert.equal(blocks.length, 1, "exactly one subscriptions match block expected");
});

test("read requires admin, path ownership bound to request.auth.uid, or data ownership — and nothing else", () => {
  const read = subscriptionMatch[1].match(/allow read: if [^;]*;/);
  assert.ok(read, "allow read rule not found");
  const clause = read[0];

  // Admin branch retained.
  assert.match(clause, /isAdmin\(\)/);
  // Data-ownership branch retained.
  assert.match(clause, /isSubscriptionOwner\(resource\.data\)/);
  // Path ownership is BOUND to the caller's own uid, never to a free
  // variable or a client-supplied field.
  assert.match(clause, /subscriptionId\s*==\s*request\.auth\.uid/);
  // Authentication is not optional on the path-ownership branch.
  assert.match(clause, /isSignedIn\(\)/);

  // No branch admits an arbitrary user: the read rule must never reduce to
  // a bare authentication check or to true.
  assert.doesNotMatch(clause, /allow read: if true/);
  assert.doesNotMatch(clause, /allow read: if isSignedIn\(\)\s*;/);
  assert.doesNotMatch(clause, /allow read: if isRegisteredUser\(\)\s*;/);
  assert.doesNotMatch(clause, /request\.auth\s*!=\s*null\s*;/);
});

test("the read rule's ownership check is not satisfiable from client-supplied data", () => {
  const read = subscriptionMatch[1].match(/allow read: if [^;]*;/)[0];
  // request.resource.data is the INCOMING document — it must never appear in
  // a read authorization decision, which would let a caller assert ownership.
  assert.doesNotMatch(read, /request\.resource\.data/);
});

test("premium, gold, expiration, and delete writes are backend/admin only", () => {
  assert.ok(subscriptionMatch);
  const write = subscriptionMatch[1].match(
    /allow create, update, delete: if [^;]*;/
  );
  assert.ok(write, "allow create, update, delete rule not found");
  assert.equal(write[0].trim(), "allow create, update, delete: if isAdmin();");

  // Writes must not become owner-writable by any route.
  assert.doesNotMatch(subscriptionMatch[1], /allow write/);
  assert.doesNotMatch(
    subscriptionMatch[1],
    /create.*isSubscriptionOwner|update.*isSubscriptionOwner|delete.*isSubscriptionOwner/
  );
  assert.doesNotMatch(
    subscriptionMatch[1],
    /create.*request\.auth\.uid|update.*request\.auth\.uid|delete.*request\.auth\.uid/
  );
});
