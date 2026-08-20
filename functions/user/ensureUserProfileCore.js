"use strict";

/**
 * Server-owned, idempotent users/{uid} provisioning.
 *
 * Fixes the class of bug where Firebase Authentication succeeds but the
 * corresponding users/{uid} profile document is never created (originally:
 * the client's self-create payload included a protected field and was
 * rejected by Firestore Rules; more generally: any client-side failure
 * between Auth success and the Firestore write). This mirrors the same
 * canonical free-user schema as buildSocialProfileCreationData() in
 * lib/services/social_auth_service.dart — kept in sync by hand, since the
 * two run in different languages/runtimes.
 *
 * Every identity value is derived from the Firebase Auth record for the
 * *caller's own* uid — never from client-supplied request data — so a
 * caller cannot provision another uid or inject entitlement/role/claims
 * fields.
 */

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function fallbackUsername(displayName, email) {
  const trimmedName = String(displayName || "").trim();
  if (trimmedName) return trimmedName;
  const normalized = normalizeEmail(email);
  const atIndex = normalized.indexOf("@");
  if (atIndex > 0) return normalized.slice(0, atIndex);
  return "User";
}

function primaryAuthProvider(providerIds) {
  // Prefer a real federated provider over the synthetic "password" id only
  // when both are somehow present; otherwise first-listed wins. In practice
  // Auth users have exactly one relevant provider at creation time.
  if (providerIds.includes("google.com")) return "google.com";
  if (providerIds.includes("apple.com")) return "apple.com";
  if (providerIds.includes("password")) return "password";
  return providerIds[0] || "unknown";
}

/**
 * Pure function: builds the canonical free-user document from an Auth user
 * record. No Firestore access — makes this trivially unit-testable.
 */
function buildCanonicalProfileFromAuthUser({ authUser, serverTimestamp }) {
  const providerIds = (authUser.providerData || []).map((p) => p.providerId);
  const email = authUser.email || "";
  const provider = primaryAuthProvider(providerIds);
  return {
    uid: authUser.uid,
    username: fallbackUsername(authUser.displayName, email),
    email: normalizeEmail(email),
    phone: "",
    city: "",
    district: "",
    photoUrl: String(authUser.photoURL || "").trim(),
    // Deliberately no isPremium/subscriptionPlan/subscriptionStatus/
    // subscription/role/entitlement/claims fields: this function never
    // grants an entitlement. A freshly-created profile is implicitly
    // free/normal by the absence of these fields, exactly matching the
    // Flutter client's canonical creation payload.
    emailVerified: authUser.emailVerified === true,
    profileCompleted: false,
    authProvider: provider,
    authProviders: providerIds.length ? providerIds : [provider],
    createdAt: serverTimestamp,
    updatedAt: serverTimestamp,
    lastLoginAt: serverTimestamp,
  };
}

/**
 * Create-only provisioning. Returns { uid, created }.
 *
 * `db` must be an Admin SDK Firestore instance (bypasses Security Rules —
 * this is the trusted server-side path). `authUser` must be the Auth record
 * for the *same* uid the caller is authenticated as; callers are
 * responsible for that binding (see the onCall wrapper).
 */
async function ensureUserProfile({ db, authUser, now, logger }) {
  const uid = authUser.uid;
  const ref = db.collection("users").doc(uid);
  const serverTimestamp = now;

  try {
    const profile = buildCanonicalProfileFromAuthUser({
      authUser,
      serverTimestamp,
    });
    // .create() is a precondition write: it fails atomically (ALREADY_EXISTS)
    // if the document exists or is created concurrently — never overwrites.
    await ref.create(profile);
    if (logger) {
      logger.info("ENSURE_USER_PROFILE_CREATED", { uid });
    }
    return { uid, created: true };
  } catch (error) {
    const alreadyExists =
      error && (error.code === 6 || error.code === "already-exists");
    if (!alreadyExists) throw error;
    if (logger) {
      logger.info("ENSURE_USER_PROFILE_ALREADY_EXISTS", { uid });
    }
    return { uid, created: false };
  }
}

module.exports = {
  normalizeEmail,
  fallbackUsername,
  primaryAuthProvider,
  buildCanonicalProfileFromAuthUser,
  ensureUserProfile,
};
