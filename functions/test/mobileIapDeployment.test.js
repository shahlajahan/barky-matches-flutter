"use strict";

const assert = require("node:assert/strict");
const {test} = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const functions = require("../index");
const {verifyApplePurchase, verifyGooglePurchase} =
  require("../subscription/mobileStoreVerifiers");
const {handleAppleNotification} = require("../subscription/mobileIapLifecycle");
const {Environment} = require("@apple/app-store-server-library");
const {
  appleNotificationEnvironmentCandidates,
} = require("../subscription/mobileIapLifecycle");
const {ownershipKey} = require("../subscription/mobileIapCore");

function secretNames(functionName) {
  return (functions[functionName].__endpoint.secretEnvironmentVariables || [])
    .map(({key}) => key);
}

test("Apple activation and notifications have no Google secret binding", () => {
  assert.deepEqual(secretNames("activateSubscription"), [
    "APPLE_IAP_ISSUER_ID",
    "APPLE_IAP_KEY_ID",
    "APPLE_IAP_PRIVATE_KEY",
    "APPLE_ROOT_CA_BUNDLE",
  ]);
  assert.deepEqual(secretNames("appleSubscriptionNotifications"), [
    "APPLE_IAP_ISSUER_ID",
    "APPLE_IAP_KEY_ID",
    "APPLE_IAP_PRIVATE_KEY",
    "APPLE_ROOT_CA_BUNDLE",
  ]);
});

test("Apple reconciliation is independently deployable and defers Google", () => {
  assert.deepEqual(secretNames("reconcileMobileSubscriptions"), [
    "APPLE_IAP_ISSUER_ID",
    "APPLE_IAP_KEY_ID",
    "APPLE_IAP_PRIVATE_KEY",
    "APPLE_ROOT_CA_BUNDLE",
  ]);
  const source = fs.readFileSync(path.join(__dirname, "..", "index.js"), "utf8");
  assert.match(source, /googlePlay:\s*\{\s*status:\s*["']deferred["']/);
  assert.deepEqual(secretNames("reconcileGoogleSubscriptions"), [
    "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON",
  ]);
});

test("Apple verification does not need Google credentials", async () => {
  const result = await verifyApplePurchase({
    transactionId: "apple-client-id",
    config: {bundleId: "com.petsupo.app", environment: "production"},
    clients: {
      api: {getTransactionInfo: async () => ({signedTransactionInfo: "signed"})},
      verifier: {
        verifyAndDecodeTransaction: async () => ({
          bundleId: "com.petsupo.app",
          productId: "barky_premium_monthly",
          type: "Auto-Renewable Subscription",
          transactionId: "apple-verified-id",
          originalTransactionId: "apple-original-id",
          expiresDate: String(Date.now() + 86400000),
          signedDate: Date.now(),
          environment: "Production",
        }),
      },
    },
  });
  assert.equal(result.plan, "premium");
});

test("Apple notification handling does not need Google credentials", async () => {
  const data = new Map();
  const ref = (path) => ({
    get: async () => ({exists: data.has(path), data: () => data.get(path)}),
    set: async (value, options = {}) => {
      data.set(path, options.merge ? {...(data.get(path) || {}), ...value} : value);
    },
  });
  const db = {
    collection: (name) => ({doc: (id) => ref(`${name}/${id}`)}),
    runTransaction: async (callback) => callback({
      get: async (documentRef) => documentRef.get(),
      set: (documentRef, value, options) => documentRef.set(value, options),
    }),
  };
  data.set(`mobileSubscriptionPurchases/${ownershipKey(
    "app_store", "apple-original-id"
  )}`, {uid: "user-a"});

  const transaction = {
    bundleId: "com.petsupo.app",
    productId: "barky_premium_monthly",
    type: "Auto-Renewable Subscription",
    transactionId: "apple-verified-id",
    originalTransactionId: "apple-original-id",
    expiresDate: String(Date.now() + 86400000),
    signedDate: Date.now(),
    environment: "Production",
  };
  const result = await handleAppleNotification({
    db,
    signedPayload: "signed-notification",
    config: {bundleId: "com.petsupo.app", environment: "production"},
    clients: {
      api: {getTransactionInfo: async () => ({signedTransactionInfo: "signed"})},
      verifier: {
        verifyAndDecodeNotification: async () => ({
          notificationUUID: "notification-1",
          notificationType: "DID_RENEW",
          signedDate: String(Date.now()),
          data: {signedTransactionInfo: "signed"},
        }),
        verifyAndDecodeTransaction: async () => transaction,
      },
    },
  });
  assert.equal(result.plan, "premium");
  assert.equal(data.get("users/user-a").subscriptionPlan, "premium");
});

test("Apple notification verification tries Sandbox after configured Production", async () => {
  assert.deepEqual(
    appleNotificationEnvironmentCandidates({environment: "production"}),
    ["production", "sandbox"]
  );
  assert.deepEqual(
    appleNotificationEnvironmentCandidates({environment: "sandbox"}),
    ["sandbox", "production"]
  );

  const data = new Map();
  const ref = (path) => ({
    get: async () => ({exists: data.has(path), data: () => data.get(path)}),
    set: async (value, options = {}) => {
      data.set(path, options.merge ? {...(data.get(path) || {}), ...value} : value);
    },
  });
  const db = {
    collection: (name) => ({doc: (id) => ref(`${name}/${id}`)}),
    runTransaction: async (callback) => callback({
      get: async (documentRef) => documentRef.get(),
      set: (documentRef, value, options) => documentRef.set(value, options),
    }),
  };
  data.set(`mobileSubscriptionPurchases/${ownershipKey(
    "app_store", "apple-sandbox-original"
  )}`, {uid: "user-a"});

  const transaction = {
    bundleId: "com.petsupo.app",
    productId: "barky_premium_monthly",
    type: "Auto-Renewable Subscription",
    transactionId: "apple-sandbox-transaction",
    originalTransactionId: "apple-sandbox-original",
    expiresDate: String(Date.now() + 86400000),
    signedDate: Date.now(),
    environment: "Sandbox",
  };
  const result = await handleAppleNotification({
    db,
    signedPayload: "signed-notification",
    config: {bundleId: "com.petsupo.app", environment: "production"},
    verifierFactory: (config) => ({
      environment: config.environment === "sandbox"
        ? Environment.SANDBOX
        : Environment.PRODUCTION,
      api: {getTransactionInfo: async () => ({signedTransactionInfo: "signed"})},
      verifier: {
        verifyAndDecodeNotification: async () => {
          if (config.environment === "production") {
            const error = new Error("sandbox notification");
            error.status = 4;
            throw error;
          }
          return {
            notificationUUID: "sandbox-notification",
            notificationType: "DID_RENEW",
            signedDate: String(Date.now()),
            data: {signedTransactionInfo: "signed"},
          };
        },
        verifyAndDecodeTransaction: async () => transaction,
      },
    }),
  });
  assert.equal(result.plan, "premium");
  assert.equal(data.get("subscriptions/user-a").plan, "premium");
});

test("out-of-order Apple notifications cannot regress a newer entitlement", async () => {
  const data = new Map();
  const ref = (path) => ({
    get: async () => ({exists: data.has(path), data: () => data.get(path)}),
    set: async (value, options = {}) => {
      data.set(path, options.merge ? {...(data.get(path) || {}), ...value} : value);
    },
  });
  const db = {
    collection: (name) => ({doc: (id) => ref(`${name}/${id}`)}),
    runTransaction: async (callback) => callback({
      get: async (documentRef) => documentRef.get(),
      set: (documentRef, value, options) => documentRef.set(value, options),
    }),
  };
  const original = "apple-notification-original";
  data.set(`mobileSubscriptionPurchases/${ownershipKey(
    "app_store", original
  )}`, {uid: "user-a"});
  const transactions = {
    newer: {
      bundleId: "com.petsupo.app",
      productId: "barky_gold_monthly",
      type: "Auto-Renewable Subscription",
      transactionId: "gold-t2",
      originalTransactionId: original,
      signedDate: 2000,
      expiresDate: String(Date.now() + 86400000),
      environment: "Production",
    },
    older: {
      bundleId: "com.petsupo.app",
      productId: "barky_premium_monthly",
      type: "Auto-Renewable Subscription",
      transactionId: "premium-t1",
      originalTransactionId: original,
      signedDate: 1000,
      expiresDate: String(Date.now() + 86400000),
      environment: "Production",
    },
  };
  const clients = {
    api: {getTransactionInfo: async () => ({signedTransactionInfo: "unused"})},
    verifier: {
      verifyAndDecodeNotification: async (payload) => ({
        notificationUUID: `notification-${payload}`,
        notificationType: "DID_RENEW",
        signedDate: payload === "newer" ? 2000 : 1000,
        data: {signedTransactionInfo: payload},
      }),
      verifyAndDecodeTransaction: async (signed) => transactions[signed],
    },
  };
  await handleAppleNotification({
    db,
    signedPayload: "newer",
    config: {bundleId: "com.petsupo.app", environment: "production"},
    clients,
  });
  await handleAppleNotification({
    db,
    signedPayload: "older",
    config: {bundleId: "com.petsupo.app", environment: "production"},
    clients,
  });
  assert.equal(data.get("subscriptions/user-a").plan, "gold");
  assert.equal(data.get("subscriptions/user-a").mobile.transactionId, "gold-t2");
});

test("Google verification fails closed without its service-account credential", async () => {
  await assert.rejects(
    verifyGooglePurchase({
      purchaseToken: "token",
      config: {packageName: "com.petsupo.app"},
    }),
    /GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not configured/
  );
});
