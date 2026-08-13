const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {normalizeStatus} = require("../subscription/adminSubscriptionCore");
const {
  buildEffectiveSubscription,
  userMirrorFromEffective,
} = require("../subscription/entitlementCore");

if (!admin.apps.length) admin.initializeApp();

function firestoreDate(value) {
  if (value && typeof value.toDate === "function") {
    const date = value.toDate();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
  }
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }
  return null;
}

function withoutUndefined(value) {
  if (Array.isArray(value)) return value.map(withoutUndefined);
  if (!value || typeof value !== "object") return value;
  return Object.fromEntries(
    Object.entries(value)
      .filter(([, entry]) => entry !== undefined)
      .map(([key, entry]) => [key, withoutUndefined(entry)])
  );
}

async function expireSubscriptionCandidate({db, subscriptionRef, now = new Date()}) {
  let expired = false;
  await db.runTransaction(async (transaction) => {
    const fresh = await transaction.get(subscriptionRef);
    if (!fresh.exists) return;

    const current = fresh.data() || {};
    const freshExpiresAt = firestoreDate(current.expiresAt);
    if (
      normalizeStatus(current.status) !== "active" ||
      !freshExpiresAt ||
      freshExpiresAt.getTime() >= now.getTime()
    ) {
      return;
    }

    const uid = subscriptionRef.id;
    const userRef = db.collection("users").doc(uid);
    const source = current.source || "legacy";
    const sourceCurrent = current.sources?.[source] || current;
    const effective = buildEffectiveSubscription({
      current,
      sourceUpdates: {
        [source]: {...sourceCurrent, status: "expired"},
      },
      now,
    });
    const next = {
      ...effective,
      userId: uid,
      status: effective.plan === "normal" ? "expired" : "active",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    const userMirror = withoutUndefined(userMirrorFromEffective(effective, now));
    if (effective.plan === "normal") {
      userMirror.subscriptionStatus = "expired";
      userMirror.subscription = {
        ...(userMirror.subscription || {}),
        status: "expired",
      };
    }
    transaction.set(subscriptionRef, withoutUndefined(next), {merge: true});
    transaction.set(userRef, userMirror, {merge: true});
    expired = true;
  });
  return expired;
}

const expireSubscriptions = onSchedule(
  {schedule: "every 60 minutes", region: "europe-west3"},
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const snapshot = await db.collection("subscriptions")
      .where("status", "==", "active")
      .where("expiresAt", "<", now)
      .get();

    let updated = 0;
    for (const doc of snapshot.docs) {
      if (await expireSubscriptionCandidate({
        db,
        subscriptionRef: doc.ref,
        now: now.toDate(),
      })) updated += 1;
    }
    console.log(`Expired subscriptions synchronized: ${updated}`);
  }
);

module.exports = {expireSubscriptionCandidate, expireSubscriptions};
