const {GoogleAuth} = require("google-auth-library");
const {
  AppStoreServerAPIClient,
  Environment,
  SignedDataVerifier,
} = require("@apple/app-store-server-library");
const {mobileProductPlan} = require("./mobileIapCore");

const GOOGLE_SCOPE = "https://www.googleapis.com/auth/androidpublisher";
const GOOGLE_API_ROOT = "https://androidpublisher.googleapis.com/androidpublisher/v3";

function required(value, name) {
  if (!value || !String(value).trim()) throw new Error(`${name} is not configured`);
  return String(value).trim();
}

function appleEnvironment(value) {
  return String(value || "production").toLowerCase() === "sandbox"
    ? Environment.SANDBOX
    : Environment.PRODUCTION;
}

function decodeAppleRoots(value) {
  const pem = required(value, "APPLE_ROOT_CA_BUNDLE");
  return pem.split(/(?=-----BEGIN CERTIFICATE-----)/g)
    .map((part) => part.trim())
    .filter(Boolean)
    .map((part) => Buffer.from(
      part.replace(/-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----|\s+/g, ""),
      "base64"
    ));
}

function createAppleVerifier(config, environmentOverride) {
  const environment = environmentOverride || appleEnvironment(config.environment);
  const bundleId = required(config.bundleId, "APPLE_BUNDLE_ID");
  const api = new AppStoreServerAPIClient(
    required(config.privateKey, "APPLE_IAP_PRIVATE_KEY"),
    required(config.keyId, "APPLE_IAP_KEY_ID"),
    required(config.issuerId, "APPLE_IAP_ISSUER_ID"),
    bundleId,
    environment
  );
  const verifier = new SignedDataVerifier(
    decodeAppleRoots(config.rootCertificates),
    true,
    environment,
    bundleId,
    environment === Environment.PRODUCTION
      ? Number(required(config.appAppleId, "APPLE_APP_ID"))
      : undefined
  );
  return {api, verifier, environment};
}

function isJws(value) {
  return typeof value === "string" && value.split(".").length === 3;
}

function appleEnvironmentName(environment) {
  return environment === Environment.SANDBOX ? "sandbox" : "production";
}

function appleEnvironmentCandidates(config) {
  const preferred = appleEnvironment(config.environment);
  const alternate = preferred === Environment.SANDBOX
    ? Environment.PRODUCTION
    : Environment.SANDBOX;
  return [preferred, alternate];
}

function validateAppleTransaction(transaction, config, verifierEnvironment) {
  if (!transaction.bundleId || transaction.bundleId !== config.bundleId) {
    throw new Error("Apple bundle identifier mismatch");
  }
  const plan = mobileProductPlan(transaction.productId);
  if (!plan || transaction.type !== "Auto-Renewable Subscription") {
    throw new Error("Apple product is not an allowed auto-renewable subscription");
  }
  const expectedEnvironment = appleEnvironmentName(verifierEnvironment);
  if (String(transaction.environment || "").toLowerCase() !== expectedEnvironment) {
    throw new Error("Apple environment mismatch");
  }
  const expiresAt = new Date(Number(transaction.expiresDate));
  if (!Number.isFinite(expiresAt.getTime())) throw new Error("Invalid Apple expiration");
  const eventAt = new Date(Number(transaction.signedDate || transaction.purchaseDate));
  if (!Number.isFinite(eventAt.getTime())) {
    throw new Error("Apple transaction ordering data is missing");
  }
  const revoked = Boolean(transaction.revocationDate);
  const expired = expiresAt.getTime() <= Date.now();
  console.info("APPLE_IAP_TRANSACTION_VALIDATED", {
    environment: expectedEnvironment,
    productId: transaction.productId,
    bundleIdValid: true,
    transactionIdPresent: Boolean(transaction.transactionId),
    originalTransactionIdPresent: Boolean(transaction.originalTransactionId),
    expirationDate: expiresAt.toISOString(),
    status: revoked ? "revoked" : expired ? "expired" : "active",
  });
  return {
    store: "app_store",
    productId: transaction.productId,
    identity: transaction.originalTransactionId || transaction.transactionId,
    transactionId: transaction.transactionId,
    originalTransactionId: transaction.originalTransactionId,
    expiresAt,
    eventAt,
    status: revoked ? "revoked" : expired ? "expired" : "active",
    revoked,
    refunded: revoked,
    autoRenew: true,
    environment: transaction.environment,
    appAccountToken: transaction.appAccountToken || null,
    plan,
  };
}

async function verifyApplePurchase({
  transactionId,
  verificationData,
  productIdHint,
  config,
  clients,
}) {
  const id = transactionId ? String(transactionId).trim() : "";
  const payload = verificationData ? String(verificationData).trim() : "";
  const created = clients
    ? {
      ...clients,
      environment: clients.environment || appleEnvironment(config.environment),
    }
    : null;
  const candidateInputs = created ? [created] : appleEnvironmentCandidates(config);
  console.info("APPLE_IAP_VERIFY_START", {
    configuredEnvironment: String(config.environment || "auto").toLowerCase(),
    transactionId: id || null,
    productIdReceived: productIdHint ? String(productIdHint) : null,
    verificationPayloadPresent: Boolean(payload),
    verificationPayloadLength: payload.length,
    verificationPayloadFormat: isJws(payload)
      ? "jws"
      : payload ? "legacy-or-unknown" : "missing",
  });

  if (isJws(payload)) {
    // StoreKit 2 exposes jwsRepresentation as serverVerificationData. Verify
    // it cryptographically; never decode or trust the client payload alone.
    let lastError;
    for (const input of candidateInputs) {
      let candidate;
      try {
        candidate = created ? input : createAppleVerifier(config, input);
      } catch (error) {
        lastError = error;
        console.error("APPLE_IAP_VERIFIER_CONFIG_ERROR", {
          environment: appleEnvironmentName(input),
          error: error?.message || String(error),
        });
        continue;
      }
      const environment = appleEnvironmentName(candidate.environment);
      try {
        const transaction = await candidate.verifier.verifyAndDecodeTransaction(payload);
        console.info("APPLE_IAP_VERIFY_MODE", {
          mode: "StoreKit2 JWS",
          environment,
        });
        return validateAppleTransaction(transaction, config, candidate.environment);
      } catch (error) {
        lastError = error;
        console.warn("APPLE_IAP_JWS_VERIFY_FAILED", {
          environment,
          error: error?.message || String(error),
        });
      }
    }
    throw lastError || new Error("Apple signed transaction verification failed");
  } else {
    const transactionIdValue = required(id, "Apple transactionId");
    let lastError;
    for (const input of candidateInputs) {
      let candidate;
      try {
        candidate = created ? input : createAppleVerifier(config, input);
      } catch (error) {
        lastError = error;
        console.error("APPLE_IAP_VERIFIER_CONFIG_ERROR", {
          environment: appleEnvironmentName(input),
          error: error?.message || String(error),
        });
        continue;
      }
      const environment = appleEnvironmentName(candidate.environment);
      if (!candidate.api) {
        lastError = new Error("Apple verification API client is unavailable");
        continue;
      }
      try {
        const response = await candidate.api.getTransactionInfo(transactionIdValue);
        console.info("APPLE_IAP_API_RESPONSE", {
          mode: "API fallback",
          environment,
          status: response?.status ?? response?.statusCode ?? response?.httpStatusCode ?? "unknown",
          signedTransactionInfoPresent: Boolean(response?.signedTransactionInfo),
        });
        const signedTransactionInfo = required(
          response?.signedTransactionInfo,
          "Apple signedTransactionInfo"
        );
        const transaction = await candidate.verifier.verifyAndDecodeTransaction(
          signedTransactionInfo
        );
        return validateAppleTransaction(transaction, config, candidate.environment);
      } catch (error) {
        lastError = error;
        console.error("APPLE_IAP_API_ERROR", {
          mode: "API fallback",
          environment,
          status: error?.status ?? error?.statusCode ?? error?.httpStatusCode ?? "unknown",
          transactionId: transactionIdValue,
          error: error?.message || String(error),
        });
      }
    }
    throw lastError || new Error("Apple transaction verification failed");
  }
}

function createGoogleClient(serviceAccountJson) {
  const credentials = typeof serviceAccountJson === "string"
    ? JSON.parse(serviceAccountJson)
    : serviceAccountJson;
  if (!credentials || !credentials.client_email || !credentials.private_key) {
    throw new Error("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is not configured");
  }
  return new GoogleAuth({credentials, scopes: [GOOGLE_SCOPE]});
}

async function googleRequest({auth, method, url, body}) {
  const client = await auth.getClient();
  const response = await client.request({method, url, data: body});
  return response.data;
}

async function verifyGooglePurchase({purchaseToken, config, auth}) {
  const token = required(purchaseToken, "Google purchaseToken");
  const packageName = required(config.packageName, "GOOGLE_PLAY_PACKAGE_NAME");
  const googleAuth = auth || createGoogleClient(config.serviceAccountJson);
  const url = `${GOOGLE_API_ROOT}/applications/${encodeURIComponent(packageName)}` +
    `/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`;
  const purchase = await googleRequest({auth: googleAuth, method: "GET", url});
  if (!purchase || purchase.packageName && purchase.packageName !== packageName) {
    throw new Error("Google package identifier mismatch");
  }
  const lineItem = Array.isArray(purchase.lineItems) ? purchase.lineItems[0] : null;
  const productId = lineItem?.productId;
  const plan = mobileProductPlan(productId);
  if (!plan) throw new Error("Google product is not allowlisted");
  const expiresAt = new Date(lineItem.expiryTime);
  if (!Number.isFinite(expiresAt.getTime())) throw new Error("Invalid Google expiration");
  // A canceled Play subscription remains entitled until its verified expiry;
  // account hold/paused states do not. Expiry is always store-derived.
  const active = [
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_CANCELED",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  ].includes(purchase.subscriptionState) && expiresAt.getTime() > Date.now();
  const revoked = ["SUBSCRIPTION_STATE_EXPIRED"].includes(
    purchase.subscriptionState
  );
  return {
    store: "google_play",
    productId,
    identity: token,
    purchaseToken: token,
    transactionId: purchase.latestOrderId || null,
    originalTransactionId: purchase.linkedPurchaseToken || token,
    expiresAt,
    status: active ? "active" : "expired",
    revoked,
    refunded: revoked,
    autoRenew: Boolean(lineItem.autoRenewingPlan),
    packageName,
    acknowledgementState: purchase.acknowledgementState,
    obfuscatedExternalAccountId:
      purchase.externalAccountIdentifiers?.obfuscatedExternalAccountId || null,
    plan,
  };
}

async function acknowledgeGooglePurchase({purchaseToken, config, auth}) {
  const packageName = required(config.packageName, "GOOGLE_PLAY_PACKAGE_NAME");
  const subscriptionId = required(config.productId, "Google productId");
  const token = required(purchaseToken, "Google purchaseToken");
  const googleAuth = auth || createGoogleClient(config.serviceAccountJson);
  const url = `${GOOGLE_API_ROOT}/applications/${encodeURIComponent(packageName)}` +
    `/purchases/subscriptions/${encodeURIComponent(subscriptionId)}` +
    `/tokens/${encodeURIComponent(token)}:acknowledge`;
  return googleRequest({auth: googleAuth, method: "POST", url, body: {}});
}

module.exports = {
  createAppleVerifier,
  verifyApplePurchase,
  createGoogleClient,
  verifyGooglePurchase,
  acknowledgeGooglePurchase,
};
