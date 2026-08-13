"use strict";

const admin = require("firebase-admin");
const {
  normalizeKnownAdminGrant,
  normalizeStatus,
} = require("../subscription/adminSubscriptionCore");
const {
  buildEffectiveSubscription,
  userMirrorFromEffective,
} = require("../subscription/entitlementCore");

function args(argv) {
  const values = new Set(argv.slice(2));
  const uidArg = argv.slice(2).find((value) => !value.startsWith("--"));
  return {
    uid: uidArg || null,
    all: values.has("--all"),
    apply: values.has("--apply"),
    confirmProduction: values.has("--confirm-production"),
    normalizeKnownAdminGrant: values.has("--normalize-known-admin-grant"),
  };
}

async function repairOne(db, uid, apply, normalizeGrant) {
  const subscriptionRef = db.collection("subscriptions").doc(uid);
  const userRef = db.collection("users").doc(uid);
  const [subscriptionSnap, userSnap] = await Promise.all([
    subscriptionRef.get(),
    userRef.get(),
  ]);
  if (!subscriptionSnap.exists) {
    console.log(JSON.stringify({uid, skipped: "subscription_missing"}));
    return;
  }
  const before = {
    subscription: subscriptionSnap.data() || {},
    user: userSnap.exists ? userSnap.data() || {} : {},
  };
  const current = before.subscription;
  let nextSubscription = {
    ...current,
    userId: uid,
    status: normalizeStatus(current.status),
  };
  if (normalizeGrant) {
    if (nextSubscription.plan !== "gold" || nextSubscription.status !== "active") {
      throw new Error("Known admin grant normalization requires active Gold");
    }
    nextSubscription = normalizeKnownAdminGrant({uid, current: nextSubscription});
  }
  const effective = buildEffectiveSubscription({
    current,
    sourceUpdates: nextSubscription.source
      ? {[nextSubscription.source]: nextSubscription}
      : {},
  });
  const canonical = {...effective, userId: uid};
  const after = {
    subscription: canonical,
    user: userMirrorFromEffective(effective),
  };
  console.log(JSON.stringify({uid, before, after, mode: apply ? "apply" : "dry-run"}));
  if (!apply) return;
  await db.runTransaction(async (transaction) => {
    transaction.set(subscriptionRef, {
      ...canonical,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    transaction.set(userRef, after.user, {merge: true});
  });
}

async function main() {
  const options = args(process.argv);
  if (!options.uid && !options.all) {
    throw new Error("Provide one UID or --all");
  }
  if (options.uid && options.all) throw new Error("UID and --all are mutually exclusive");
  const emulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
  if (options.apply && !emulator && !options.confirmProduction) {
    throw new Error("Refusing production write without --confirm-production");
  }
  if (!admin.apps.length) admin.initializeApp();
  const db = admin.firestore();
  const uids = options.uid ? [options.uid] :
    (await db.collection("subscriptions").get()).docs.map((doc) => doc.id);
  for (const uid of uids) {
    await repairOne(db, uid, options.apply, options.normalizeKnownAdminGrant);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message || error);
    process.exitCode = 1;
  });
}

module.exports = {args, repairOne};
