"use strict";

const assert = require("node:assert/strict");
const {test} = require("node:test");
const {
  mobileProductPlan,
  accountBindingToken,
  isActiveStoreEntitlement,
  synchronizeMobileEntitlement,
} = require("../subscription/mobileIapCore");
const {
  verifyApplePurchase,
  verifyGooglePurchase,
} = require("../subscription/mobileStoreVerifiers");
const {buildEffectiveSubscription} = require("../subscription/entitlementCore");
const {claimAppleNotification} = require("../subscription/mobileIapLifecycle");

function fakeDb(initial = {}) {
  const data = new Map(Object.entries(initial));
  const ref = (path) => ({
    path,
    get: async () => ({
      exists: data.has(path),
      data: () => data.get(path),
    }),
    set: async (value, options = {}) => {
      data.set(path, options.merge ? {...(data.get(path) || {}), ...value} : value);
    },
  });
  return {
    collection: (name) => ({
      doc: (id) => ref(`${name}/${id}`),
    }),
    runTransaction: async (fn) => fn({
      get: async (documentRef) => documentRef.get(),
      set: (documentRef, value, options) => documentRef.set(value, options),
    }),
    data,
  };
}

const activeApple = (overrides = {}) => ({
  store: "app_store",
  productId: "barky_premium_monthly",
  identity: "apple-original-1",
  transactionId: "apple-tx-2",
  originalTransactionId: "apple-original-1",
  expiresAt: new Date(Date.now() + 86400000),
  eventAt: new Date(Date.now() - 1000),
  status: "active",
  autoRenew: true,
  ...overrides,
});

test("only allowlisted mobile products map to canonical plans", () => {
  assert.equal(mobileProductPlan("barky_premium_monthly"), "premium");
  assert.equal(mobileProductPlan("barky_gold_monthly"), "gold");
  assert.equal(mobileProductPlan("gold"), null);
});

test("account binding is deterministic and UUID-shaped", () => {
  const token = accountBindingToken("user-a");
  assert.match(token, /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.equal(token, accountBindingToken("user-a"));
  assert.notEqual(token, accountBindingToken("user-b"));
});

test("active entitlement requires a future store expiration", () => {
  assert.equal(isActiveStoreEntitlement(activeApple()), true);
  assert.equal(isActiveStoreEntitlement(activeApple({expiresAt: new Date(0)})), false);
  assert.equal(isActiveStoreEntitlement(activeApple({refunded: true})), false);
});

test("verified Premium Apple purchase writes canonical mirrors", async () => {
  const db = fakeDb();
  const result = await synchronizeMobileEntitlement({
    db,
    uid: "user-a",
    verified: activeApple(),
  });
  assert.equal(result.plan, "premium");
  assert.equal(db.data.get("subscriptions/user-a").plan, "premium");
  assert.equal(db.data.get("users/user-a").subscriptionPlan, "premium");
  assert.equal(db.data.get("users/user-a").isPremium, true);
});

test("verified Gold Google purchase writes Play provenance", async () => {
  const db = fakeDb();
  await synchronizeMobileEntitlement({
    db,
    uid: "user-a",
    verified: activeApple({
      store: "google_play",
      productId: "barky_gold_monthly",
      identity: "play-token-1",
      purchaseToken: "play-token-1",
    }),
  });
  const subscription = db.data.get("subscriptions/user-a");
  assert.equal(subscription.plan, "gold");
  assert.equal(subscription.source, "play_store");
  assert.equal(
    db.data.get("mobileSubscriptionPurchases/" +
      require("../subscription/mobileIapCore").ownershipKey(
        "google_play", "play-token-1"
      )).purchaseToken,
    "play-token-1"
  );
});

test("purchase ownership prevents replay by another Firebase user", async () => {
  const db = fakeDb();
  await synchronizeMobileEntitlement({db, uid: "user-a", verified: activeApple()});
  await assert.rejects(
    synchronizeMobileEntitlement({db, uid: "user-b", verified: activeApple()}),
    (error) => error.code === "purchase-already-owned"
  );
});

test("same owner retry is idempotent and does not extend expiration", async () => {
  const db = fakeDb();
  const expiration = new Date(Date.now() + 3600000);
  await synchronizeMobileEntitlement({
    db,
    uid: "user-a",
    verified: activeApple({expiresAt: expiration}),
  });
  const first = db.data.get("subscriptions/user-a").expiresAt;
  await synchronizeMobileEntitlement({
    db,
    uid: "user-a",
    verified: activeApple({expiresAt: expiration}),
  });
  assert.equal(first.getTime(), expiration.getTime());
  assert.equal(db.data.get("subscriptions/user-a").expiresAt.getTime(),
    expiration.getTime());
});

test("duplicate Apple transaction is a safe no-op", async () => {
  const db = fakeDb();
  const transaction = activeApple({
    eventAt: new Date(Date.now() - 5000),
  });
  await synchronizeMobileEntitlement({db, uid: "user-a", verified: transaction});
  const first = db.data.get("subscriptions/user-a");
  const result = await synchronizeMobileEntitlement({
    db,
    uid: "user-a",
    verified: {...transaction},
  });
  const second = db.data.get("subscriptions/user-a");
  assert.equal(result.staleIgnored, false);
  assert.equal(second.plan, first.plan);
  assert.equal(second.mobile.transactionId, first.mobile.transactionId);
});

test("stale Premium after newer Gold cannot downgrade the Apple entitlement", async () => {
  const db = fakeDb();
  const original = "apple-original-upgrade";
  const premium = activeApple({
    identity: original,
    originalTransactionId: original,
    transactionId: "apple-premium-t1",
    eventAt: new Date(Date.now() - 86400000),
  });
  const gold = activeApple({
    identity: original,
    originalTransactionId: original,
    transactionId: "apple-gold-t2",
    productId: "barky_gold_monthly",
    eventAt: new Date(Date.now() - 3600000),
  });
  await synchronizeMobileEntitlement({db, uid: "user-a", verified: premium});
  await synchronizeMobileEntitlement({db, uid: "user-a", verified: gold});
  const result = await synchronizeMobileEntitlement({
    db, uid: "user-a", verified: premium,
  });
  const subscription = db.data.get("subscriptions/user-a");
  assert.equal(result.staleIgnored, true);
  assert.equal(subscription.plan, "gold");
  assert.equal(subscription.mobile.productId, "barky_gold_monthly");
  assert.equal(subscription.mobile.transactionId, "apple-gold-t2");
});

test("duplicate newer Gold remains active and a newer verified state wins", async () => {
  const db = fakeDb();
  const firstGold = activeApple({
    identity: "apple-original-gold",
    originalTransactionId: "apple-original-gold",
    transactionId: "apple-gold-t2",
    productId: "barky_gold_monthly",
    eventAt: new Date(Date.now() - 2000),
  });
  await synchronizeMobileEntitlement({db, uid: "user-a", verified: firstGold});
  const duplicate = await synchronizeMobileEntitlement({
    db, uid: "user-a", verified: {...firstGold},
  });
  assert.equal(duplicate.staleIgnored, false);
  assert.equal(db.data.get("subscriptions/user-a").plan, "gold");

  const newerGold = {
    ...firstGold,
    transactionId: "apple-gold-renewal-t3",
    eventAt: new Date(Date.now() - 1000),
    expiresAt: new Date(Date.now() + 172800000),
  };
  const newer = await synchronizeMobileEntitlement({
    db, uid: "user-a", verified: newerGold,
  });
  assert.equal(newer.staleIgnored, false);
  assert.equal(db.data.get("subscriptions/user-a").mobile.transactionId,
    "apple-gold-renewal-t3");
});

test("newer verified expiration and revocation can still remove access", async () => {
  const db = fakeDb();
  const active = activeApple({
    identity: "apple-original-terminal",
    originalTransactionId: "apple-original-terminal",
    transactionId: "apple-gold-active",
    productId: "barky_gold_monthly",
    eventAt: new Date(Date.now() - 2000),
  });
  await synchronizeMobileEntitlement({db, uid: "user-a", verified: active});
  const revoked = {
    ...active,
    transactionId: "apple-gold-revoked",
    eventAt: new Date(Date.now() - 1000),
    expiresAt: new Date(Date.now() - 1000),
    status: "revoked",
    revoked: true,
    refunded: true,
  };
  const result = await synchronizeMobileEntitlement({
    db, uid: "user-a", verified: revoked,
  });
  const subscription = db.data.get("subscriptions/user-a");
  assert.equal(result.staleIgnored, false);
  assert.equal(subscription.plan, "normal");
  assert.equal(subscription.isPremium, undefined);
  assert.equal(db.data.get("users/user-a").isPremium, false);
});

test("an out-of-order mobile event cannot regress the newer source state", async () => {
  const db = fakeDb();
  const newerEvent = new Date(Date.now() - 1000);
  const laterExpiry = new Date(Date.now() + 86400000);
  await synchronizeMobileEntitlement({
    db,
    uid: "user-a",
    verified: activeApple({
      eventAt: newerEvent,
      expiresAt: laterExpiry,
    }),
  });
  await synchronizeMobileEntitlement({
    db,
    uid: "user-a",
    verified: activeApple({
      eventAt: new Date(newerEvent.getTime() - 86400000),
      expiresAt: new Date(Date.now() - 1000),
      status: "expired",
      revoked: true,
      refunded: true,
    }),
  });
  const subscription = db.data.get("subscriptions/user-a");
  assert.equal(subscription.plan, "premium");
  assert.equal(subscription.status, "active");
  assert.equal(subscription.expiresAt.getTime(), laterExpiry.getTime());
});

test("active admin grant is preserved while mobile provenance is recorded", async () => {
  const db = fakeDb({
    "subscriptions/user-a": {
      source: "admin_grant",
      plan: "gold",
      status: "active",
      expiresAt: new Date(Date.now() + 86400000),
    },
  });
  await synchronizeMobileEntitlement({db, uid: "user-a", verified: activeApple()});
  assert.equal(db.data.get("subscriptions/user-a").source, "admin_grant");
  assert.equal(db.data.get("subscriptions/user-a").mobile.plan, "premium");
});

test("expired Apple does not remove a still-valid web entitlement", () => {
  const now = new Date();
  const effective = buildEffectiveSubscription({
    now,
    current: {
      sources: {
        web_isbank: {
          source: "web_isbank", plan: "premium", status: "active",
          expiresAt: new Date(now.getTime() + 86400000),
        },
        app_store: {
          source: "app_store", plan: "gold", status: "expired",
          expiresAt: new Date(now.getTime() - 1000),
        },
      },
    },
  });
  assert.equal(effective.source, "web_isbank");
  assert.equal(effective.plan, "premium");
});

test("active Apple remains effective when the web source is expired", () => {
  const now = new Date();
  const effective = buildEffectiveSubscription({
    now,
    current: {sources: {
      web_isbank: {
        source: "web_isbank", plan: "gold", status: "active",
        expiresAt: new Date(now.getTime() - 1000),
      },
      app_store: {
        source: "app_store", plan: "premium", status: "active",
        expiresAt: new Date(now.getTime() + 86400000),
      },
    }},
  });
  assert.equal(effective.source, "app_store");
  assert.equal(effective.plan, "premium");
});

test("revoked Apple does not remove a still-valid admin Gold grant", () => {
  const now = new Date();
  const effective = buildEffectiveSubscription({
    now,
    current: {sources: {
      admin_grant: {
        source: "admin_grant", plan: "gold", status: "active",
        expiresAt: new Date(now.getTime() + 86400000),
      },
      app_store: {
        source: "app_store", plan: "gold", status: "expired",
        expiresAt: new Date(now.getTime() - 1000), revoked: true,
      },
    }},
  });
  assert.equal(effective.source, "admin_grant");
  assert.equal(effective.plan, "gold");
});

test("Gold wins deterministically over Premium across active sources", () => {
  const now = new Date();
  const effective = buildEffectiveSubscription({
    now,
    current: {sources: {
      web_isbank: {source: "web_isbank", plan: "gold", status: "active", expiresAt: new Date(now.getTime() + 1000)},
      app_store: {source: "app_store", plan: "premium", status: "active", expiresAt: new Date(now.getTime() + 86400000)},
    }},
  });
  assert.equal(effective.source, "web_isbank");
  assert.equal(effective.plan, "gold");
});

test("active paid state without expiry fails closed", () => {
  const effective = buildEffectiveSubscription({
    current: {plan: "gold", status: "active", source: "app_store"},
  });
  assert.equal(effective.plan, "normal");
  assert.equal(effective.source, "free");
});

test("duplicate Apple notification is claimed exactly once", async () => {
  const db = fakeDb();
  const first = await claimAppleNotification({
    db, notificationId: "notification-1", ownerUid: "user-a", signedDate: 1,
  });
  const second = await claimAppleNotification({
    db, notificationId: "notification-1", ownerUid: "user-a", signedDate: 1,
  });
  assert.equal(first, true);
  assert.equal(second, false);
});

test("Apple verification derives product and expiration from verified JWS", async () => {
  const result = await verifyApplePurchase({
    transactionId: "client-supplied-id",
    config: {bundleId: "com.petsupo.app", environment: "sandbox"},
    clients: {
      api: {getTransactionInfo: async () => ({signedTransactionInfo: "signed"})},
      verifier: {
        verifyAndDecodeTransaction: async () => ({
          bundleId: "com.petsupo.app",
          productId: "barky_gold_monthly",
          type: "Auto-Renewable Subscription",
          transactionId: "verified-tx",
          originalTransactionId: "verified-original",
          expiresDate: String(Date.now() + 86400000),
          signedDate: Date.now(),
          environment: "Sandbox",
        }),
      },
    },
  });
  assert.equal(result.plan, "gold");
  assert.equal(result.transactionId, "verified-tx");
});

test("Apple StoreKit 2 signed transaction data is verified without receipt API lookup", async () => {
  let apiCalls = 0;
  const result = await verifyApplePurchase({
    transactionId: "storekit-transaction-id",
    verificationData: "header.payload.signature",
    config: {bundleId: "com.petsupo.app", environment: "sandbox"},
    clients: {
      api: {getTransactionInfo: async () => {
        apiCalls += 1;
        return {signedTransactionInfo: "unused"};
      }},
      verifier: {
        verifyAndDecodeTransaction: async (signed) => {
          assert.equal(signed, "header.payload.signature");
          return {
            bundleId: "com.petsupo.app",
            productId: "barky_premium_monthly",
            type: "Auto-Renewable Subscription",
            transactionId: "storekit-transaction-id",
            originalTransactionId: "storekit-original-id",
            expiresDate: String(Date.now() + 86400000),
            signedDate: Date.now(),
            environment: "Sandbox",
          };
        },
      },
    },
  });
  assert.equal(result.plan, "premium");
  assert.equal(apiCalls, 0);
});

test("Apple production StoreKit 2 JWS derives an active Premium entitlement", async () => {
  const result = await verifyApplePurchase({
    verificationData: "production.header.signature",
    config: {bundleId: "com.petsupo.app", environment: "production"},
    clients: {
      verifier: {
        verifyAndDecodeTransaction: async () => ({
          bundleId: "com.petsupo.app",
          productId: "barky_premium_monthly",
          type: "Auto-Renewable Subscription",
          transactionId: "production-tx",
          originalTransactionId: "production-original",
          expiresDate: String(Date.now() + 86400000),
          signedDate: Date.now(),
          environment: "Production",
        }),
      },
    },
  });
  assert.equal(result.environment, "Production");
  assert.equal(result.status, "active");
});

test("Apple verification rejects environment, expired, and revoked transactions", async () => {
  const verify = (transaction) => verifyApplePurchase({
    verificationData: "header.payload.signature",
    config: {bundleId: "com.petsupo.app", environment: "sandbox"},
    clients: {
      verifier: {verifyAndDecodeTransaction: async () => transaction},
    },
  });
  const base = {
    bundleId: "com.petsupo.app",
    productId: "barky_gold_monthly",
    type: "Auto-Renewable Subscription",
    transactionId: "tx",
    originalTransactionId: "original",
    signedDate: Date.now(),
  };
  await assert.rejects(verify({
    ...base,
    expiresDate: String(Date.now() + 86400000),
    environment: "Production",
  }), /environment mismatch/);
  const expired = await verify({
    ...base,
    expiresDate: String(Date.now() - 1000),
    environment: "Sandbox",
  });
  assert.equal(expired.status, "expired");
  const revoked = await verify({
    ...base,
    expiresDate: String(Date.now() + 86400000),
    environment: "Sandbox",
    revocationDate: String(Date.now()),
  });
  assert.equal(revoked.status, "revoked");
});

test("Apple verification rejects bundle and unknown products", async () => {
  await assert.rejects(verifyApplePurchase({
    transactionId: "id",
    config: {bundleId: "expected"},
    clients: {
      api: {getTransactionInfo: async () => ({signedTransactionInfo: "signed"})},
      verifier: {verifyAndDecodeTransaction: async () => ({
        bundleId: "wrong", productId: "barky_gold_monthly",
      })},
    },
  }));
  await assert.rejects(verifyApplePurchase({
    transactionId: "id",
    config: {bundleId: "expected"},
    clients: {
      api: {getTransactionInfo: async () => ({signedTransactionInfo: "signed"})},
      verifier: {verifyAndDecodeTransaction: async () => ({
        bundleId: "expected", productId: "unknown",
        type: "Auto-Renewable Subscription",
      })},
    },
  }));
});

test("Google verification derives plan from verified Play line item", async () => {
  const result = await verifyGooglePurchase({
    purchaseToken: "token",
    config: {packageName: "com.petsupo.app"},
    auth: {getClient: async () => ({request: async () => ({data: {
      packageName: "com.petsupo.app",
      subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
      acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
      latestOrderId: "order-1",
      lineItems: [{
        productId: "barky_premium_monthly",
        expiryTime: new Date(Date.now() + 86400000).toISOString(),
        autoRenewingPlan: {},
      }],
    }})})},
  });
  assert.equal(result.plan, "premium");
  assert.equal(result.purchaseToken, "token");
});

test("Google verification rejects unknown products and package mismatch", async () => {
  const auth = (data) => ({getClient: async () => ({request: async () => ({data})})});
  await assert.rejects(verifyGooglePurchase({
    purchaseToken: "token",
    config: {packageName: "com.petsupo.app"},
    auth: auth({packageName: "other", lineItems: []}),
  }));
  await assert.rejects(verifyGooglePurchase({
    purchaseToken: "token",
    config: {packageName: "com.petsupo.app"},
    auth: auth({packageName: "com.petsupo.app", lineItems: [{
      productId: "unknown", expiryTime: new Date(Date.now() + 86400000).toISOString(),
    }]}),
  }));
});
