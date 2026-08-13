const {
  verifyApplePurchase,
  createAppleVerifier,
  verifyGooglePurchase,
  acknowledgeGooglePurchase,
} = require("./mobileStoreVerifiers");
const {
  ownershipKey,
  synchronizeMobileEntitlement,
} = require("./mobileIapCore");
const crypto = require("crypto");

function appleConfigFrom(config) {
  return {
    issuerId: config.issuerId,
    keyId: config.keyId,
    privateKey: config.privateKey,
    rootCertificates: config.rootCertificates,
    environment: config.environment,
    bundleId: config.bundleId,
    appAppleId: config.appAppleId,
  };
}

function appleNotificationEnvironmentCandidates(config) {
  const preferred = String(config.environment || "production").toLowerCase() ===
    "sandbox" ? "sandbox" : "production";
  return [preferred, preferred === "sandbox" ? "production" : "sandbox"];
}

async function claimAppleNotification({db, notificationId, ownerUid, signedDate}) {
  const notificationRef = db.collection("mobileSubscriptionNotifications")
    .doc(ownershipKey("app_store_notification", notificationId));
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(notificationRef);
    if (snapshot.exists) return false;
    transaction.set(notificationRef, {
      store: "app_store",
      notificationId,
      ownerUid,
      signedDate: signedDate || null,
      createdAt: new Date(),
    });
    return true;
  });
}

async function handleAppleNotification({
  db,
  signedPayload,
  config,
  clients,
  verifierFactory,
}) {
  const candidates = clients
    ? [clients]
    : appleNotificationEnvironmentCandidates(config).map((environment) => {
      const candidateConfig = {...config, environment};
      return verifierFactory
        ? verifierFactory(appleConfigFrom(candidateConfig))
        : createAppleVerifier(appleConfigFrom(candidateConfig));
    });
  let created;
  let notification;
  let lastError;
  for (const candidate of candidates) {
    try {
      notification = await candidate.verifier.verifyAndDecodeNotification(
        signedPayload
      );
      created = candidate;
      break;
    } catch (error) {
      lastError = error;
    }
  }
  if (!created || !notification) throw lastError || new Error(
    "Apple notification verification failed"
  );
  const {verifier} = created;
  const signed = notification.data?.signedTransactionInfo;
  if (!signed) return {ignored: true, reason: "no transaction"};

  const transaction = await verifier.verifyAndDecodeTransaction(signed);
  const identity = transaction.originalTransactionId || transaction.transactionId;
  if (!identity) return {ignored: true, reason: "no transaction identity"};
  const ownershipSnap = await db.collection("mobileSubscriptionPurchases")
    .doc(ownershipKey("app_store", identity)).get();
  if (!ownershipSnap.exists) {
    return {ignored: true, reason: "purchase is not linked yet"};
  }
  const ownerUid = ownershipSnap.data()?.uid;
  if (!ownerUid) return {ignored: true, reason: "ownership record is invalid"};

  const notificationId = notification.notificationUUID || crypto
    .createHash("sha256").update(signedPayload, "utf8").digest("hex");
  const claimed = await claimAppleNotification({
    db,
    notificationId,
    ownerUid,
    signedDate: notification.signedDate,
  });
  if (!claimed) return {alreadyProcessed: true, notificationId};

  const terminal = new Set([
    "EXPIRED",
    "GRACE_PERIOD_EXPIRED",
    "REVOKE",
    "REFUND",
    "REFUND_DECLINED",
  ]);
  const verified = await verifyApplePurchase({
    transactionId: transaction.transactionId,
    config,
    clients: {
      api: {getTransactionInfo: async () => ({signedTransactionInfo: signed})},
      verifier,
      environment: created.environment,
    },
  });
  verified.eventAt = notification.signedDate
    ? new Date(Number(notification.signedDate))
    : null;
  if (terminal.has(String(notification.notificationType))) {
    verified.status = "expired";
    verified.revoked = true;
    verified.refunded = true;
  }
  return synchronizeMobileEntitlement({db, uid: ownerUid, verified});
}

function decodePubSubMessage(requestBody) {
  const encoded = requestBody?.message?.data;
  if (!encoded) throw new Error("Pub/Sub message data is required");
  return JSON.parse(Buffer.from(encoded, "base64").toString("utf8"));
}

async function handleGoogleNotification({db, requestBody, config}) {
  const message = decodePubSubMessage(requestBody);
  if (message.packageName !== config.packageName) {
    throw new Error("Google package identifier mismatch");
  }
  const notification = message.subscriptionNotification;
  if (!notification?.purchaseToken) return {ignored: true, reason: "not a subscription"};
  const ownershipSnap = await db.collection("mobileSubscriptionPurchases")
    .doc(ownershipKey("google_play", notification.purchaseToken)).get();
  if (!ownershipSnap.exists) {
    return {ignored: true, reason: "purchase is not linked yet"};
  }
  const ownerUid = ownershipSnap.data()?.uid;
  const verified = await verifyGooglePurchase({
    purchaseToken: notification.purchaseToken,
    config,
  });
  const result = await synchronizeMobileEntitlement({
    db,
    uid: ownerUid,
    verified,
  });
  if (
    verified.status === "active" &&
    verified.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING"
  ) {
    await acknowledgeGooglePurchase({purchaseToken: verified.purchaseToken, config: {
      ...config,
      productId: verified.productId,
    }});
  }
  return result;
}

async function reconcileMobilePurchase({db, ownership, configs}) {
  const config = ownership.store === "app_store" ? configs.apple : configs.google;
  const verified = ownership.store === "app_store"
    ? await verifyApplePurchase({
      transactionId: ownership.transactionId || ownership.identity,
      config,
    })
    : await verifyGooglePurchase({
      purchaseToken: ownership.purchaseToken || ownership.identity,
      config,
    });
  return synchronizeMobileEntitlement({db, uid: ownership.uid, verified});
}

module.exports = {
  appleNotificationEnvironmentCandidates,
  claimAppleNotification,
  handleAppleNotification,
  handleGoogleNotification,
  reconcileMobilePurchase,
};
