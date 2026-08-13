const crypto = require("crypto");
const {
  buildEffectiveSubscription,
  userMirrorFromEffective,
} = require("./entitlementCore");

const MOBILE_PRODUCTS = Object.freeze({
  barky_premium_monthly: "premium",
  barky_gold_monthly: "gold",
});

const MOBILE_SOURCES = Object.freeze({
  app_store: "app_store",
  google_play: "play_store",
});

function mobileProductPlan(productId) {
  return MOBILE_PRODUCTS[productId] || null;
}

function ownershipKey(store, identity) {
  return crypto
    .createHash("sha256")
    .update(`${store}:${identity}`, "utf8")
    .digest("hex");
}

function accountBindingToken(uid) {
  const bytes = crypto.createHash("sha256").update(String(uid), "utf8").digest();
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-` +
    `${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

function asDate(value) {
  if (value && typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "number") return new Date(value);
  if (typeof value === "string") return new Date(value);
  return null;
}

function isActiveStoreEntitlement(verified, now = new Date()) {
  const expiresAt = asDate(verified.expiresAt);
  return Boolean(
    verified.status === "active" &&
    expiresAt &&
    Number.isFinite(expiresAt.getTime()) &&
    expiresAt.getTime() > now.getTime() &&
    !verified.revoked &&
    !verified.refunded
  );
}

// Kept injectable so unit tests never need a live Firestore clock.
let adminTimestamp = () => new Date();
function setMobileIapClock(clock) {
  adminTimestamp = clock;
}

function normalizeDate(value) {
  const date = asDate(value);
  return date && Number.isFinite(date.getTime()) ? date : null;
}

function isStaleSourceUpdate(incoming, existing) {
  if (!existing) return false;
  const incomingEventAt = normalizeDate(incoming.eventAt);
  const existingEventAt = normalizeDate(existing.eventAt);
  if (!incomingEventAt || !existingEventAt) return Boolean(existingEventAt);
  if (incomingEventAt.getTime() < existingEventAt.getTime()) return true;
  if (incomingEventAt.getTime() > existingEventAt.getTime()) return false;

  // Equal Apple signed timestamps are only safe to replay when they identify
  // the same verified transaction. Do not let an unrelated state replace it.
  return incoming.transactionId !== existing.transactionId ||
    incoming.originalTransactionId !== existing.originalTransactionId ||
    incoming.productId !== existing.productId;
}

async function synchronizeMobileEntitlement({
  db,
  uid,
  verified,
  now = new Date(),
}) {
  if (!db || !uid || !verified || !MOBILE_SOURCES[verified.store]) {
    throw new Error("Invalid mobile entitlement synchronization request");
  }
  const plan = mobileProductPlan(verified.productId);
  console.info("SYNC_MOBILE_ENTITLEMENT", {
    uid,
    productId: verified.productId,
    plan,
    status: verified.status,
    expiresAt: verified.expiresAt,
    identity: verified.identity,
  });
  if (!plan || !verified.identity) throw new Error("Unrecognized mobile purchase");

  const source = MOBILE_SOURCES[verified.store];
  const ownershipRef = db.collection("mobileSubscriptionPurchases")
    .doc(ownershipKey(verified.store, verified.identity));
  const subscriptionRef = db.collection("subscriptions").doc(uid);
  const userRef = db.collection("users").doc(uid);
  const active = isActiveStoreEntitlement(verified, now);
  const status = active ? "active" : "expired";

  return db.runTransaction(async (transaction) => {
    const [ownershipSnap, subscriptionSnap] = await Promise.all([
      transaction.get(ownershipRef),
      transaction.get(subscriptionRef),
    ]);
    const ownership = ownershipSnap.exists ? ownershipSnap.data() || {} : {};
    if (ownership.uid && ownership.uid !== uid) {
      const error = new Error("Mobile purchase belongs to another account");
      error.code = "purchase-already-owned";
      throw error;
    }

    const current = subscriptionSnap.exists ? subscriptionSnap.data() || {} : {};
    const sourceRecord = {
      uid,
      store: verified.store,
      source,
      productId: verified.productId,
      identity: verified.identity,
      transactionId: verified.transactionId || null,
      originalTransactionId: verified.originalTransactionId || null,
      purchaseToken: verified.purchaseToken || null,
      eventAt: verified.eventAt || null,
      updatedAt: adminTimestamp(),
    };
    // Keep each provider independent, then derive one effective entitlement.
    const mobile = {
      store: verified.store,
      source,
      plan,
      status,
      expiresAt: verified.expiresAt,
      eventAt: verified.eventAt || null,
      productId: verified.productId,
      transactionId: verified.transactionId || null,
      originalTransactionId: verified.originalTransactionId || null,
      autoRenew: verified.autoRenew !== false,
      verifiedAt: adminTimestamp(),
    };
    const existingSource = current.sources?.[source] ||
      (current.mobile?.source === source ? current.mobile : null);
    const stale = verified.store === "app_store" &&
      isStaleSourceUpdate(mobile, existingSource);
    const sourceUpdate = stale ? existingSource : mobile;
    if (stale) {
      console.info("MOBILE_ENTITLEMENT_STALE_IGNORED", {
        uid,
        store: verified.store,
        incomingTransactionId: verified.transactionId || null,
        existingTransactionId: existingSource?.transactionId || null,
        incomingEventAt: verified.eventAt || null,
        existingEventAt: existingSource?.eventAt || null,
      });
    }
    if (!stale) {
      transaction.set(ownershipRef, {
        ...sourceRecord,
        createdAt: ownership.createdAt || adminTimestamp(),
      }, { merge: true });
    }
    const effective = buildEffectiveSubscription({
      current,
      sourceUpdates: { [source]: sourceUpdate },
      now,
    });
    const canonical = {
      ...effective,
      userId: uid,
      mobile: sourceUpdate,
      updatedAt: adminTimestamp(),
    };
    transaction.set(subscriptionRef, canonical, { merge: true });
    transaction.set(userRef, userMirrorFromEffective(effective, now), { merge: true });

    return {
      uid,
      plan: effective.plan,
      status: effective.status,
      source: effective.source,
      expiresAt: effective.expiresAt,
      verifiedPlan: plan,
      verifiedStatus: status,
      alreadyOwnedByCaller: Boolean(ownership.uid),
      staleIgnored: stale,
    };
  });
}

module.exports = {
  MOBILE_PRODUCTS,
  mobileProductPlan,
  ownershipKey,
  accountBindingToken,
  isActiveStoreEntitlement,
  synchronizeMobileEntitlement,
  setMobileIapClock,
};
