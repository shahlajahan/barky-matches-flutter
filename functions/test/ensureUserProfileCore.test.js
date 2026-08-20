"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeEmail,
  fallbackUsername,
  primaryAuthProvider,
  buildCanonicalProfileFromAuthUser,
  ensureUserProfile,
} = require("../user/ensureUserProfileCore");

// Minimal in-memory Firestore double supporting exactly what
// ensureUserProfileCore needs: collection().doc().create(), matching real
// Firestore's create-only precondition semantics (rejects with code 6 /
// "already-exists" if the document is already present).
class FakeDoc {
  constructor(store, path) {
    this._store = store;
    this._path = path;
  }

  async create(data) {
    if (this._store.has(this._path)) {
      const error = new Error("6 ALREADY_EXISTS: Document already exists");
      error.code = 6;
      throw error;
    }
    this._store.set(this._path, data);
    return { writeTime: new Date() };
  }

  async get() {
    const data = this._store.get(this._path);
    return { exists: this._store.has(this._path), data: () => data };
  }
}

class FakeFirestore {
  constructor() {
    this._store = new Map();
  }

  collection(name) {
    return {
      doc: (id) => new FakeDoc(this._store, `${name}/${id}`),
    };
  }
}

function authUser(overrides = {}) {
  return {
    uid: "uid-1",
    email: "Person@Example.com",
    displayName: "Pet Owner",
    photoURL: "https://example.com/photo.jpg",
    emailVerified: true,
    providerData: [{ providerId: "google.com" }],
    ...overrides,
  };
}

test("normalizeEmail lowercases and trims", () => {
  assert.equal(normalizeEmail("  Person@Example.com  "), "person@example.com");
  assert.equal(normalizeEmail(null), "");
});

test("fallbackUsername prefers displayName, falls back to email local-part", () => {
  assert.equal(fallbackUsername("Pet Owner", "x@example.com"), "Pet Owner");
  assert.equal(fallbackUsername("", "seker2798@gmail.com"), "seker2798");
  assert.equal(fallbackUsername(null, ""), "User");
});

test("primaryAuthProvider prefers a real federated provider", () => {
  assert.equal(primaryAuthProvider(["google.com"]), "google.com");
  assert.equal(primaryAuthProvider(["apple.com"]), "apple.com");
  assert.equal(primaryAuthProvider(["password"]), "password");
  assert.equal(primaryAuthProvider([]), "unknown");
});

test("canonical profile never includes an entitlement/role/claims field", () => {
  const profile = buildCanonicalProfileFromAuthUser({
    authUser: authUser(),
    serverTimestamp: "SERVER_TIME",
  });
  const forbidden = [
    "isPremium",
    "subscription",
    "subscriptions",
    "subscriptionPlan",
    "subscriptionStatus",
    "role",
    "admin",
    "isAdmin",
    "entitlement",
    "entitlements",
    "creator",
    "businessId",
    "businessOwnerUid",
  ];
  for (const field of forbidden) {
    assert.equal(
      Object.prototype.hasOwnProperty.call(profile, field),
      false,
      `${field} must never be written by ensureUserProfile`
    );
  }
});

test("canonical profile derives identity only from the Auth record", () => {
  const profile = buildCanonicalProfileFromAuthUser({
    authUser: authUser(),
    serverTimestamp: "SERVER_TIME",
  });
  assert.equal(profile.uid, "uid-1");
  assert.equal(profile.username, "Pet Owner");
  assert.equal(profile.email, "person@example.com");
  assert.equal(profile.photoUrl, "https://example.com/photo.jpg");
  assert.equal(profile.emailVerified, true);
  assert.equal(profile.profileCompleted, false);
  assert.equal(profile.authProvider, "google.com");
  assert.deepEqual(profile.authProviders, ["google.com"]);
  assert.equal(profile.createdAt, "SERVER_TIME");
  assert.equal(profile.updatedAt, "SERVER_TIME");
  assert.equal(profile.lastLoginAt, "SERVER_TIME");
});

test("Apple private-relay / missing display name uses the email local-part safely", () => {
  const profile = buildCanonicalProfileFromAuthUser({
    authUser: authUser({
      displayName: null,
      photoURL: null,
      email: "abc123@privaterelay.appleid.com",
      providerData: [{ providerId: "apple.com" }],
    }),
    serverTimestamp: "SERVER_TIME",
  });
  assert.equal(profile.username, "abc123");
  assert.equal(profile.photoUrl, "");
  assert.equal(profile.authProvider, "apple.com");
});

test("ensureUserProfile creates a missing profile exactly once", async () => {
  const db = new FakeFirestore();
  const result = await ensureUserProfile({
    db,
    authUser: authUser(),
    now: "SERVER_TIME",
  });
  assert.equal(result.created, true);
  assert.equal(result.uid, "uid-1");

  const readback = await db.collection("users").doc("uid-1").get();
  assert.equal(readback.exists, true);
  assert.equal(readback.data().email, "person@example.com");
});

test("ensureUserProfile is idempotent and never overwrites an existing profile", async () => {
  const db = new FakeFirestore();
  await db.collection("users").doc("uid-1").create({
    username: "Custom Existing Name",
    email: "person@example.com",
    isPremium: true, // simulates a real Gold user — must survive untouched
  });

  const result = await ensureUserProfile({
    db,
    authUser: authUser(),
    now: "SERVER_TIME",
  });
  assert.equal(result.created, false);

  const readback = await db.collection("users").doc("uid-1").get();
  assert.equal(readback.data().username, "Custom Existing Name");
  assert.equal(readback.data().isPremium, true);
});

test("repeated calls converge to a single created profile (no duplicate writes)", async () => {
  const db = new FakeFirestore();
  const first = await ensureUserProfile({ db, authUser: authUser(), now: "T1" });
  const second = await ensureUserProfile({ db, authUser: authUser(), now: "T2" });
  assert.equal(first.created, true);
  assert.equal(second.created, false);
  const readback = await db.collection("users").doc("uid-1").get();
  assert.equal(readback.data().createdAt, "T1");
});
