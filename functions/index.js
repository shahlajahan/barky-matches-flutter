
// Updated on 2025-10-24 at 13:30 +03 by Grok

/* ===============================
 * Firebase Functions v2 Imports
 * =============================== */
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const {
  onDocumentCreated,
  onDocumentWritten,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { logger } = require("firebase-functions/v2");
const { Storage } = require("@google-cloud/storage");
const ffmpeg = require("fluent-ffmpeg");
const ffmpegInstaller = require("@ffmpeg-installer/ffmpeg");
const crypto = require("crypto");
const path = require("path");
const os = require("os");
const fs = require("fs");
const Iyzipay = require("iyzipay");

const admin = require("firebase-admin");
const vision = require("@google-cloud/vision");

const revenue = require("./revenue");

ffmpeg.setFfmpegPath(ffmpegInstaller.path);
const storage = new Storage();
const { defineSecret } = require("firebase-functions/params");

const IYZICO_API_KEY = defineSecret("IYZICO_API_KEY");
const IYZICO_SECRET_KEY = defineSecret("IYZICO_SECRET_KEY");

const { Resend } = require("resend");

const resendApiKey = defineSecret("RESEND_API_KEY");



if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

function normalizeTurkishText(value) {
  if (!value) return "";

  return String(value)
    .trim()
    .toLowerCase()
    .replaceAll("ı", "i")
    .replaceAll("İ", "i")
    .replaceAll("ş", "s")
    .replaceAll("Ş", "s")
    .replaceAll("ğ", "g")
    .replaceAll("Ğ", "g")
    .replaceAll("ü", "u")
    .replaceAll("Ü", "u")
    .replaceAll("ö", "o")
    .replaceAll("Ö", "o")
    .replaceAll("ç", "c")
    .replaceAll("Ç", "c")
    .replace(/\s+/g, " ");
}

function addHoursToIso(hours) {
  const d = new Date();
  d.setHours(d.getHours() + hours);
  return d.toISOString();
}

function toMillisSafe(value) {
  if (!value) return null;

  if (typeof value.toMillis === "function") {
    return value.toMillis();
  }

  if (value instanceof Date) {
    return value.getTime();
  }

  if (typeof value === "string") {
    const parsed = new Date(value).getTime();
    return Number.isNaN(parsed) ? null : parsed;
  }

  return null;
}

function detectInvoiceType(billingSnapshot = {}) {
  const companyName = normalizeText(billingSnapshot.companyName);
  const taxNumber = normalizeText(billingSnapshot.taxNumber);
  const taxOffice = normalizeText(billingSnapshot.taxOffice);

  if (companyName || taxNumber || taxOffice) {
    return "company";
  }

  return "individual";
}

function detectInvoiceSystem(invoiceType) {
  if (invoiceType === "company") {
    return "eArsiv"; // later: switch to eFatura after GİB integration
  }

  return "eArsiv";
}

function validateInvoiceData({ billingSnapshot = {}, sellerSnapshot = {} }) {
  const issues = [];

  const invoiceType = detectInvoiceType(billingSnapshot);

  if (!normalizeText(sellerSnapshot.taxNumber)) {
    issues.push("seller_tax_number_not_found");
  }

  if (invoiceType === "individual") {
    if (!normalizeText(billingSnapshot.identityNumber)) {
      issues.push("buyer_identity_not_found");
    }
  }

  if (invoiceType === "company") {
    if (!normalizeText(billingSnapshot.companyName)) {
      issues.push("buyer_company_name_not_found");
    }

    if (!normalizeText(billingSnapshot.taxNumber)) {
      issues.push("buyer_tax_number_not_found");
    }

    if (!normalizeText(billingSnapshot.taxOffice)) {
      issues.push("buyer_tax_office_not_found");
    }
  }

  return issues;
}

function asNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function normalizeText(value) {
  return String(value || "").trim();
}

function normalizeLower(value) {
  return String(value || "").trim().toLowerCase();
}

function normalizeCarrier(value) {
  return String(value || "").trim().toLowerCase();
}

function calcDesi(lengthCm, widthCm, heightCm) {
  const length = asNumber(lengthCm);
  const width = asNumber(widthCm);
  const height = asNumber(heightCm);

  if (length <= 0 || width <= 0 || height <= 0) return 0;
  return Number(((length * width * height) / 3000).toFixed(2));
}

function roundMoney(value) {
  return Number(asNumber(value).toFixed(2));
}

function groupItemsByBusiness(items) {
  const grouped = new Map();

  for (const item of items) {
    const businessId = String(item.shopId || item.businessId || "").trim();
    if (!businessId) continue;

    const bucket = grouped.get(businessId) || [];
    bucket.push(item);
    grouped.set(businessId, bucket);
  }

  return grouped;
}

function buildTrackingUrl(carrier, code) {
  if (!carrier || !code) return null;

  const c = String(carrier).toLowerCase();
  const trackingCode = encodeURIComponent(String(code));

  if (c.includes("aras")) {
    return `https://kargotakip.araskargo.com.tr/mainpage.aspx?code=${trackingCode}`;
  }
  if (c.includes("yurtici")) {
    return `https://www.yurticikargo.com/tr/online-servisler/gonderi-sorgula?code=${trackingCode}`;
  }
  if (c.includes("mng")) {
    return `https://www.mngkargo.com.tr/gonderi-takip?code=${trackingCode}`;
  }
  if (c.includes("ptt")) {
    return `https://gonderitakip.ptt.gov.tr/Track/Verify?q=${trackingCode}`;
  }
  if (c.includes("hepsijet")) {
    return `https://www.hepsijet.com/gonderi-takibi/${trackingCode}`;
  }
  if (c.includes("sendeo")) {
    return `https://sendeo.com.tr/tracking/${trackingCode}`;
  }
  if (c.includes("dhl")) {
    return `https://www.dhl.com/global-en/home/tracking.html?tracking-id=${trackingCode}`;
  }

  return null;
}

function computeRootStatusFromSellerStatuses(statuses) {
  const cleaned = statuses.map((s) => normalizeLower(s));

  if (cleaned.length === 0) return "pending_payment";
  if (cleaned.every((s) => s === "cancelled")) return "cancelled";
  if (cleaned.every((s) => s === "failed")) return "failed";
  if (cleaned.every((s) => s === "delivered")) return "delivered";
  if (cleaned.some((s) => s === "shipped")) return "partially_shipped";
  if (cleaned.some((s) => s === "preparing")) return "preparing";
  if (cleaned.some((s) => s === "confirmed")) return "confirmed";
  if (cleaned.some((s) => s === "paid")) return "paid";
  if (cleaned.some((s) => s === "pending_payment")) return "pending_payment";

  return "paid";
}

async function createNotification(db, payload) {
  await db.collection("notifications").add({
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...payload,
  });
}

function calculateShippingForItem({ item, config, selectedCarrier }) {
  const quantity = Math.max(1, asNumber(item.quantity, 1));
  const weightKg = asNumber(item.weightKg, 0);
  const lengthCm = asNumber(item.lengthCm, 0);
  const widthCm = asNumber(item.widthCm, 0);
  const heightCm = asNumber(item.heightCm, 0);

  const desi = calcDesi(lengthCm, widthCm, heightCm);

  const basePrice = asNumber(config.basePrice, 0);
  const pricePerKg = asNumber(config.pricePerKg, 0);
  const pricePerDesi = asNumber(config.pricePerDesi, 0);
  const freeShippingThreshold = asNumber(config.freeShippingThreshold, 0);

  const itemUnitPrice = asNumber(item.price, 0);
  const itemSubtotal = roundMoney(itemUnitPrice * quantity);

  if (freeShippingThreshold > 0 && itemSubtotal >= freeShippingThreshold) {
    return {
      shippingFeeTotal: 0,
      desi,
      chargeableWeightKg: weightKg,
      carrierApplied: selectedCarrier || null,
    };
  }

  let shippingOneUnit = basePrice;

  if (weightKg > 1) {
    shippingOneUnit += (weightKg - 1) * pricePerKg;
  }

  if (desi > 1) {
    shippingOneUnit += (desi - 1) * pricePerDesi;
  }

  const shippingFeeTotal = roundMoney(shippingOneUnit * quantity);

  return {
    shippingFeeTotal,
    desi,
    chargeableWeightKg: weightKg,
    carrierApplied: selectedCarrier || null,
  };
}

async function getProductSnapshotOrThrow(db, productId) {
  const directRef = db.collection("products").doc(productId);
  const directSnap = await directRef.get();

  if (directSnap.exists) {
    return { ref: directRef, data: directSnap.data() || {} };
  }
  logger.info("🔎 PRODUCT QUERY START", {
    productId,
  });
  const cg = await db

    .collectionGroup("products")
    .where("productId", "==", productId)
    .limit(1)
    .get();

  logger.info("📦 PRODUCT QUERY RESULT", {
    productId,
    size: cg.size,
  });

  if (!cg.empty) {
    const doc = cg.docs[0];
    return { ref: doc.ref, data: doc.data() || {} };
  }

  throw new HttpsError("not-found", `Product not found: ${productId}`);
}
// =====================================================
// ADMIN SEARCH INDEX HELPERS
// =====================================================

function buildSearchDoc({
  entityType,
  entityId,
  title,
  subtitle,
  status,
  keywords = [],
  extra = {}
}) {

  return {
    entityType,
    entityId,
    title,
    subtitle,
    status,
    keywords: keywords.filter(Boolean),
    extra,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  };

}

async function upsertIndex(id, data) {

  await admin.firestore()
    .collection("admin_search_index")
    .doc(id)
    .set(data, { merge: true });

}
const client = new vision.ImageAnnotatorClient();

/* ===============================
 * 🔥 ABSOLUTE DEBUG PING
 * =============================== */
exports.ping = onRequest(
  {
    region: "europe-west3",
    invoker: "public",
  },
  (req, res) => {
    console.log("🔥🔥🔥 PING HIT 🔥🔥🔥");
    res.status(200).send("pong");
  }
);

async function safeSendPush({ token, payload, userId }) {
  if (!token) {
    console.log("⚠️ No FCM token provided");
    return;
  }

  console.log("📦 FULL PAYLOAD:", JSON.stringify(payload, null, 2));
  payload.apns = {
    headers: {
      "apns-priority": "10",
    },
    payload: {
      aps: {
        alert: payload.notification,
        sound: "default",
        badge: 1,
      },
    },
  };

  try {
    const messageId = await admin.messaging().send({
      token,
      ...payload,
    });

    console.log("📨 Push sent OK");
    console.log("📨 SENT MESSAGE ID:", messageId);

  } catch (error) {
    console.error("🔥 FCM ERROR:", error.code);
    console.error("🔥 FULL ERROR:", error);

    if (
      error.code === "messaging/registration-token-not-registered" ||
      error.code === "messaging/invalid-registration-token"
    ) {
      console.log("🧹 Removing invalid FCM token...");

      await admin.firestore()
        .collection("users")
        .doc(userId)
        .update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
    }
  }
}

/* =====================================================
 * 🐶 ADOPTION REQUEST TRIGGER
 * ===================================================== */

exports.onAdoptionRequestCreated = onDocumentCreated(
  {
    region: "europe-west3",
    document: "adoption_requests/{requestId}",
  },
  async (event) => {
    try {
      const data = event.data?.data();
      if (!data) return;

      const requestId = event.params.requestId;
      const targetOwnerId = data.targetOwnerId;
      const requesterName = data.requesterName || "Someone";
      const targetType = data.targetType || "dog";

      const db = admin.firestore();

      /* ----------------------------------------------------
       * 1️⃣ CREATE FIRESTORE IN-APP NOTIFICATION
       * -------------------------------------------------- */
      await db.collection("notifications").add({
        recipientUserId: targetOwnerId,
        title: "New Adoption Request 🐾",
        body: `${requesterName} sent an adoption request`,
        type: "adoption_request",
        requestId: requestId,
        targetType: targetType,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      /* ----------------------------------------------------
       * 2️⃣ GET OWNER FCM TOKEN
       * -------------------------------------------------- */
      const ownerDoc = await db
        .collection("users")
        .doc(targetOwnerId)
        .get();

      const token = ownerDoc.data()?.fcmToken;

      /* ----------------------------------------------------
       * 3️⃣ SEND PUSH (SAFE)
       * -------------------------------------------------- */
      await safeSendPush({
        token,
        userId: targetOwnerId,
        payload: {
          notification: {
            title: "New Adoption Request 🐾",
            body: `${requesterName} sent an adoption request`,
          },
          data: {
            type: "adoption_request",
            requestId: requestId,
          },
          android: { priority: "high" },
          apns: {
            headers: { "apns-priority": "10" },
            payload: {
              aps: {
                alert: {
                  title: "New Adoption Request 🐾",
                  body: `${requesterName} sent an adoption request`,
                },
                sound: "default",
                badge: 1,
              },
            },
          },
        },
      });

      console.log("✅ Adoption request push sent:", requestId);

    } catch (err) {
      console.error("❌ onAdoptionRequestCreated error:", err);
    }
  }
);

/* ===============================
 * 🔥 DEBUG: Direct FCM sendToDevice test
 * =============================== */
exports.testSendToDevice = onRequest(
  {
    region: "europe-west3",
    invoker: "public",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "POST only" });
    }

    const { token } = req.body;

    if (!token) {
      return res.status(400).json({ error: "FCM token is required" });
    }

    try {
      const message = {
        token,
        notification: {
          title: "Test Push ✅",
          body: "This is a direct sendToDevice test",
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      return res.json({ success: true, response });
    } catch (err) {
      console.error("FCM ERROR:", err);
      return res.status(500).json({
        error: err.message,
        code: err.code,
      });
    }
  }
);



const IS_DEV =
  process.env.FUNCTIONS_EMULATOR === "true" ||
  process.env.NODE_ENV !== "production";


function toPlainError(err) {
  if (!err) return { message: "Unknown error" };
  return {
    message: err.message || String(err),
    code: err.code,
    name: err.name,
    stack: err.stack ? String(err.stack).split("\n").slice(0, 5).join("\n") : undefined,
  };
}



exports.createPlayDateRequest = onCall(
  {
    region: "europe-west3",
    enforceAppCheck: false, // بعداً true کن
  },
  async (request) => {
    console.log("🔥🔥🔥 FUNCTION ENTERED 🔥🔥🔥");
    console.log("AUTH RAW:", request.auth);
    console.log("DATA RAW:", request.data);

    try {
      logger.info("🟢 createPlayDateRequest HIT", {
        hasAuth: !!request.auth,
        uid: request.auth?.uid,
        dataKeys: Object.keys(request.data || {}),
      });

      /* ----------------------------------------------------
       * 🔐 AUTH
       * -------------------------------------------------- */
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
      }

      const authUid = request.auth.uid;

      /* ----------------------------------------------------
       * 📦 PAYLOAD
       * -------------------------------------------------- */
      const {
        clientRequestId,
        requesterUserId,
        requestedUserId,
        requesterDogId,
        requestedDogId,
        requesterDogName,
        requestedDogName,
        scheduledDateTime,
        locationText,
        locationLat,
        locationLng,
        isPresetPark,
      } = request.data || {};

      /* ----------------------------------------------------
       * 🛑 VALIDATION
       * -------------------------------------------------- */
      if (
        !requesterUserId ||
        !requestedUserId ||
        !requesterDogId ||
        !requestedDogId ||
        !requesterDogName ||
        !requestedDogName ||
        !scheduledDateTime
      ) {
        throw new HttpsError(
          "invalid-argument",
          "Missing required playdate fields"
        );
      }

      // 🔐 امنیت مهم
      if (authUid !== requesterUserId) {
        throw new HttpsError(
          "permission-denied",
          "You can only create requests for yourself"
        );
      }

      const db = admin.firestore();

      /* ----------------------------------------------------
       * 🕒 TIME VALIDATION (FIXED 🔥)
       * -------------------------------------------------- */
      const scheduled = new Date(scheduledDateTime);

      if (isNaN(scheduled.getTime())) {
        throw new HttpsError(
          "invalid-argument",
          "Invalid scheduledDateTime format"
        );
      }

      const now = Date.now(); // ✅ FIX

      if (scheduled.getTime() < now + 15 * 60 * 1000) {
        throw new HttpsError(
          "failed-precondition",
          "Playdate must be at least 15 minutes in the future"
        );
      }

      /* ----------------------------------------------------
       * 🚫 DUPLICATE PROTECTION (خیلی مهم برای UX)
       * -------------------------------------------------- */
      /* ----------------------------------------------------
 * 🧠 SMART DUPLICATE PROTECTION (DOG + TIME BASED)
 * -------------------------------------------------- */

      // ⏱ بازه زمانی (±1 ساعت)
      const timeWindowStart = new Date(
        scheduled.getTime() - 60 * 60 * 1000
      );

      const timeWindowEnd = new Date(
        scheduled.getTime() + 60 * 60 * 1000
      );
      console.log("🧪 INDEX DEBUG:");
      console.log({
        requesterDogId,
        requestedDogId,
        status: ["pending", "accepted"],
        start: timeWindowStart,
        end: timeWindowEnd,
      });
      // 🔁 حالت 1: requester → requested
      const q1 = await db
        .collection("playDateRequests")
        .where("requesterDogId", "==", requesterDogId)
        .where("requestedDogId", "==", requestedDogId)
        .where("status", "==", "pending")
        .where(
          "scheduledDateTime",
          ">=",
          admin.firestore.Timestamp.fromDate(timeWindowStart)
        )
        .where(
          "scheduledDateTime",
          "<=",
          admin.firestore.Timestamp.fromDate(timeWindowEnd)
        )
        .limit(1)
        .get();

      // 🔁 حالت 2: برعکس (خیلی مهم)
      const q2 = await db
        .collection("playDateRequests")
        .where("requesterDogId", "==", requestedDogId)
        .where("requestedDogId", "==", requesterDogId)
        .where("status", "==", "pending")
        .where(
          "scheduledDateTime",
          ">=",
          admin.firestore.Timestamp.fromDate(timeWindowStart)
        )
        .where(
          "scheduledDateTime",
          "<=",
          admin.firestore.Timestamp.fromDate(timeWindowEnd)
        )
        .limit(1)
        .get();

      // 🚫 فقط اگر واقعا conflict داشت
      if (!q1.empty || !q2.empty) {
        return {
          success: false,
          reason: "time_conflict",
        };
      }

      /* ----------------------------------------------------
       * 1️⃣ CREATE PLAYDATE REQUEST
       * -------------------------------------------------- */
      console.log("📝 Creating Firestore document...");

      const requestRef = await db.collection("playDateRequests").add({
        requesterUserId,
        requestedUserId,
        requesterDogId,
        requestedDogId,
        requesterDogName,
        requestedDogName,

        scheduledDateTime:
          admin.firestore.Timestamp.fromDate(scheduled),

        location: {
          text: locationText || null,
          lat: typeof locationLat === "number" ? locationLat : null,
          lng: typeof locationLng === "number" ? locationLng : null,
          preset: !!isPresetPark,
        },

        status: "pending",
        clientRequestId: clientRequestId || null,

        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info("🧾 playDateRequest created", {
        requestId: requestRef.id,
      });

      /* ----------------------------------------------------
       * 2️⃣ CREATE IN-APP NOTIFICATION
       * -------------------------------------------------- */
      const existingNotification = await db
        .collection("notifications")
        .where("requestId", "==", requestRef.id)
        .where("type", "==", "playdaterequest")
        .limit(1)
        .get();

      if (existingNotification.empty) {
        await db.collection("notifications").add({
          recipientUserId: requestedUserId,
          title: "New Playdate Request 🐶",
          body: `${requesterDogName} wants a playdate with ${requestedDogName}`,
          type: "playdaterequest",
          requestId: requestRef.id,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logger.info("🔔 Firestore notification created");
      }

      /* ----------------------------------------------------
       * 3️⃣ PUSH NOTIFICATION
       * -------------------------------------------------- */
      const recipientDoc = await db
        .collection("users")
        .doc(requestedUserId)
        .get();

      const recipientFcmToken =
        recipientDoc.exists
          ? recipientDoc.data()?.fcmToken
          : null;

      if (recipientFcmToken) {
        try {
          await safeSendPush({
            token: recipientFcmToken,
            userId: requestedUserId,
            payload: {
              notification: {
                title: "New Playdate Request 🐶",
                body: `${requesterDogName} wants a playdate with ${requestedDogName}`,
              },
              data: {
                type: "playdate_request",
                requestId: requestRef.id,
              },
              android: { priority: "high" },
              apns: {
                headers: { "apns-priority": "10" },
                payload: {
                  aps: {
                    alert: {
                      title: "New Playdate Request 🐶",
                      body: `${requesterDogName} wants a playdate with ${requestedDogName}`,
                    },
                    sound: "default",
                    badge: 1,
                    "interruption-level": "time-sensitive",
                  },
                },
              },
            },
          });

          console.log("📨 Push sent OK");
        } catch (pushErr) {
          console.error("⚠️ PUSH FAILED BUT REQUEST CREATED");
          console.error(pushErr);
        }
      }

      /* ----------------------------------------------------
       * ✅ DONE
       * -------------------------------------------------- */
      return {
        success: true,
        requestId: requestRef.id,
      };

    } catch (err) {
      console.error("💥💥💥 FULL ERROR OBJECT 💥💥💥");
      console.error(err);
      console.error("STACK:", err.stack);

      if (err instanceof HttpsError) {
        throw err;
      }

      throw new HttpsError(
        "internal",
        "CREATE_PLAYDATE_REQUEST_FAILED",
        toPlainError(err)
      );
    }
  }
);
exports.sendVerificationCode = onRequest(
  {
    region: "europe-west3",
    invoker: "public",
    secrets: [resendApiKey],
  },
  async (req, res) => {
    try {
      const resend = new Resend(resendApiKey.value());

      const email = String(req.query.email || req.body?.email || "")
        .trim()
        .toLowerCase();

      if (!email) {
        return res.status(400).json({ error: "Email required" });
      }

      const emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
      if (!emailRegex.test(email)) {
        return res.status(400).json({ error: "Invalid email" });
      }

      const otpRef = db.collection("email_otps").doc(email);
      const existing = await otpRef.get();

      const now = Date.now();

      if (existing.exists) {
        const data = existing.data() || {};
        const lastSentAt = Number(data.lastSentAt || 0);

        if (now - lastSentAt < 60 * 1000) {
          return res.status(429).json({
            error: "Please wait before requesting another code",
          });
        }
      }

      const code = Math.floor(100000 + Math.random() * 900000).toString();
      const displayCode = `${code.substring(0, 3)} ${code.substring(3)}`;

      const codeHash = crypto
        .createHash("sha256")
        .update(code)
        .digest("hex");

      const requestId = crypto.randomUUID();

      await otpRef.set({
        email,
        requestId,
        codeHash,
        attempts: 0,
        lastSentAt: now,
        expiresAt: now + 5 * 60 * 1000,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const html = `
        <div style="font-family: Arial, sans-serif; background:#f6f7fb; padding:24px;">
          <div style="max-width:520px; margin:auto; background:#ffffff; border-radius:14px; padding:28px; text-align:center; box-shadow:0 4px 20px rgba(0,0,0,0.05);">

            <h2 style="margin-bottom:10px;">🐶 PetSupo</h2>

            <p style="color:#666;">Hey there 👋</p>

            <p style="color:#444; font-size:15px;">
              I'm <strong>Mia</strong> 🐾<br/>
              I'm super excited you're joining our pack!
            </p>

            <p style="margin-top:20px; color:#333;">
              Use the code below to verify your email:
            </p>

            <div style="font-size:32px; font-weight:bold; margin:18px 0; letter-spacing:6px; color:#111;">
              ${displayCode}
            </div>

            <p style="color:#888; font-size:13px;">
              This code will expire in 5 minutes.
            </p>

            <a href="https://petsupo.com"
              style="display:inline-block; margin-top:20px; background:#ff6b8a; color:white; padding:12px 24px; border-radius:8px; text-decoration:none; font-weight:bold;">
              Open PetSupo
            </a>

            <hr style="margin:26px 0; border:none; border-top:1px solid #eee;" />

            <p style="color:#aaa; font-size:12px;">
              If you didn’t request this, you can safely ignore this email.
            </p>

            <p style="margin-top:16px; font-size:13px; color:#555;">
              🐕 With tail wags,<br/>
              <strong>Mia</strong><br/>
              PetSupo Team
            </p>

          </div>
        </div>
      `;

      await resend.emails.send({
        from: "PetSupo 🐾 <no-reply@petsupo.com>",
        to: email,
        subject: "🐾 Mia is waiting! Here's your PetSupo code",
        html,
      });

      return res.status(200).json({
        success: true,
        requestId,
      });
    } catch (e) {
      console.error("sendVerificationCode ERROR:", e);
      return res.status(500).json({ error: e.message });
    }
  }
);

exports.sendPasswordResetCustom = onRequest(
  {
    region: "europe-west3",
    invoker: "public",
    secrets: [resendApiKey],
  },
  async (req, res) => {
    try {
      const resend = new Resend(resendApiKey.value());

      const email = String(req.query.email || req.body?.email || "")
        .trim()
        .toLowerCase();

      if (!email) {
        return res.status(400).json({ error: "Email required" });
      }

      const emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
      if (!emailRegex.test(email)) {
        return res.status(400).json({ error: "Invalid email" });
      }

      // 🔥 Firebase reset link
      const link = await admin.auth().generatePasswordResetLink(email);

      const html = `
        <div style="font-family: Arial; background:#f6f7fb; padding:24px;">
          <div style="max-width:520px; margin:auto; background:#fff; border-radius:14px; padding:28px; text-align:center;">

            <h2>🐶 PetSupo</h2>

            <p>Hey 👋</p>

            <p style="color:#444;">
              Forgot your password? No worries!
            </p>

            <a href="${link}"
              style="display:inline-block; margin-top:20px; background:#ff6b8a; color:white; padding:12px 24px; border-radius:8px; text-decoration:none; font-weight:bold;">
              Reset Password
            </a>

            <p style="margin-top:20px; font-size:12px; color:#888;">
              If you didn’t request this, ignore this email.
            </p>

            <p style="margin-top:16px;">
              🐕 PetSupo Team
            </p>

          </div>
        </div>
      `;

      await resend.emails.send({
        from: "PetSupo 🐾 <no-reply@petsupo.com>",
        to: email,
        subject: "Reset your PetSupo password",
        html,
      });

      return res.status(200).json({ success: true });
    } catch (e) {
      console.error("sendPasswordResetCustom ERROR:", e);
      return res.status(500).json({ error: e.message });
    }
  }
);

exports.verifyEmailCode = onRequest(
  {
    region: "europe-west3",
    invoker: "public",
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).json({ error: "Method not allowed" });
      }

      const email = String(req.body?.email || "").trim().toLowerCase();
      const code = String(req.body?.code || "").replace(/\s/g, "").trim();
      const userId = String(req.body?.userId || "").trim();
      const requestId = String(req.body?.requestId || "").trim();

      if (!email || !code || !userId || !requestId) {
        return res.status(400).json({
          success: false,
          error: "Missing required fields",
        });
      }

      if (!/^\d{6}$/.test(code)) {
        return res.status(400).json({
          success: false,
          error: "Invalid code format",
        });
      }

      const otpRef = db.collection("email_otps").doc(email);
      const otpSnap = await otpRef.get();

      if (!otpSnap.exists) {
        return res.status(400).json({
          success: false,
          error: "Code expired or not found",
        });
      }

      const data = otpSnap.data() || {};
      const now = Date.now();

      if (Number(data.expiresAt || 0) < now) {
        await otpRef.delete();

        return res.status(400).json({
          success: false,
          error: "Code expired",
        });
      }

      if (String(data.requestId || "") !== requestId) {
        return res.status(400).json({
          success: false,
          error: "Invalid verification session",
        });
      }

      if (Number(data.attempts || 0) >= 5) {
        return res.status(429).json({
          success: false,
          error: "Too many attempts. Please request a new code.",
        });
      }

      const inputHash = crypto
        .createHash("sha256")
        .update(code)
        .digest("hex");

      if (inputHash !== data.codeHash) {
        await otpRef.update({
          attempts: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return res.status(400).json({
          success: false,
          error: "Invalid verification code",
        });
      }

      const userRecord = await admin.auth().getUser(userId);

      if (userRecord.email?.toLowerCase() !== email) {
        return res.status(403).json({
          success: false,
          error: "Email does not belong to this user",
        });
      }

      await admin.auth().updateUser(userId, {
        emailVerified: true,
      });

      await db.collection("users").doc(userId).set(
        {
          email,
          emailVerified: true,
          emailVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      await otpRef.delete();

      return res.status(200).json({
        success: true,
      });
    } catch (e) {
      console.error("verifyEmailCode ERROR:", e);
      return res.status(500).json({
        success: false,
        error: e.message,
      });
    }
  }
);

exports.cleanupExpiredEmailOtps = onSchedule(
  {
    schedule: "every 10 minutes",
    region: "europe-west3",
  },
  async () => {
    const now = Date.now();

    const snap = await db
      .collection("email_otps")
      .where("expiresAt", "<", now)
      .limit(300)
      .get();

    if (snap.empty) {
      console.log("cleanupExpiredEmailOtps: no expired OTPs");
      return;
    }

    const batch = db.batch();

    snap.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    console.log(`cleanupExpiredEmailOtps: deleted ${snap.size} expired OTPs`);
  }
);

exports.verifyEmailCode = onRequest(
  {
    region: "europe-west3",
    invoker: "public",
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).json({ error: "POST only" });
      }

      const email = String(req.body.email || "").trim().toLowerCase();
      const code = String(req.body.code || "").trim();

      if (!email || !code) {
        return res.status(400).json({ error: "Email and code required" });
      }

      const otpRef = db.collection("email_otps").doc(email);
      const otpSnap = await otpRef.get();

      if (!otpSnap.exists) {
        return res.status(404).json({ error: "Code not found" });
      }

      const otpData = otpSnap.data() || {};

      if (Date.now() > Number(otpData.expiresAt || 0)) {
        await otpRef.delete();
        return res.status(410).json({ error: "Code expired" });
      }

      if (Number(otpData.attempts || 0) >= 5) {
        await otpRef.delete();
        return res.status(403).json({ error: "Too many attempts" });
      }

      const codeHash = crypto
        .createHash("sha256")
        .update(code)
        .digest("hex");

      if (codeHash !== otpData.codeHash) {
        await otpRef.update({
          attempts: admin.firestore.FieldValue.increment(1),
        });

        return res.status(400).json({ error: "Invalid code" });
      }

      const usersSnap = await db
        .collection("users")
        .where("email", "==", email)
        .limit(1)
        .get();

      if (!usersSnap.empty) {
        await usersSnap.docs[0].ref.set(
          {
            emailVerified: true,
            emailVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }

      await otpRef.delete();

      return res.status(200).json({ success: true });
    } catch (e) {
      console.error("verifyEmailCode ERROR:", e);
      return res.status(500).json({ error: e.message });
    }
  }
);

exports.acceptPlayDateRequestHttp = onRequest(
  { region: "europe-west3" },
  async (req, res) => {
    console.log("🟢 HIT acceptPlayDateRequest");

    try {
      if (req.method !== "POST") {
        return res.status(405).json({ error: "POST only" });
      }

      /* ----------------------------------------------------
       * 🔐 AUTH
       * -------------------------------------------------- */
      const authHeader = req.headers.authorization || "";
      if (!authHeader.startsWith("Bearer ")) {
        return res.status(401).json({ error: "Missing auth token" });
      }

      const decoded = await admin
        .auth()
        .verifyIdToken(authHeader.replace("Bearer ", ""));
      const currentUserId = decoded.uid;

      /* ----------------------------------------------------
       * 📦 PAYLOAD (حداقلی و امن)
       * -------------------------------------------------- */
      const { requestId, requesterUserId, requestedUserId } = req.body || {};

      console.log("🟣 Payload:", {
        requestId,
        requesterUserId,
        requestedUserId,
        currentUserId,
      });

      if (!requestId || !requesterUserId || !requestedUserId) {
        return res.status(400).json({ error: "Missing required fields" });
      }

      if (
        currentUserId !== requesterUserId &&
        currentUserId !== requestedUserId
      ) {
        return res.status(403).json({ error: "Not authorized" });
      }

      /* ----------------------------------------------------
       * 🔎 LOAD REQUEST
       * -------------------------------------------------- */
      const db = admin.firestore();
      const requestRef = db.collection("playDateRequests").doc(requestId);
      const requestSnap = await requestRef.get();

      if (!requestSnap.exists) {
        return res.status(404).json({ error: "Request not found" });
      }

      const requestData = requestSnap.data();

      /* ----------------------------------------------------
       * 🐶 LOAD DOG NAMES (SOURCE OF TRUTH)
       * -------------------------------------------------- */
      const requesterDogId = requestData.requesterDogId;
      const requestedDogId = requestData.requestedDogId;

      const [reqDogSnap, resDogSnap] = await Promise.all([
        db.collection("dogs").doc(requesterDogId).get(),
        db.collection("dogs").doc(requestedDogId).get(),
      ]);

      const requesterDogName =
        reqDogSnap.data()?.name || "Your dog";
      const requestedDogName =
        resDogSnap.data()?.name || "The other dog";

      /* ----------------------------------------------------
       * ✅ UPDATE STATUS
       * -------------------------------------------------- */
      await requestRef.update({
        status: "accepted",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      /* ----------------------------------------------------
       * 🔔 FIRESTORE NOTIFICATION
       * -------------------------------------------------- */

      await db.collection("notifications").add({
        recipientUserId: requesterUserId,
        title: "Playdate Accepted 🐾",
        body: `${requestedDogName} accepted your playdate request.`,
        type: "playdate_response",
        requestId: requestId,
        status: "accepted",
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });



      /* ----------------------------------------------------
 * 📲 PUSH NOTIFICATION (SAFE)
 * -------------------------------------------------- */
      const userDoc = await db.collection("users").doc(requesterUserId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      await safeSendPush({
        token: fcmToken,
        userId: requesterUserId,
        payload: {
          notification: {
            title: "Playdate Accepted 🐾",
            body: `${requestedDogName} accepted your playdate request.`,
          },
          data: {
            type: "playdate_response",
            status: "accepted",
            requestId: requestId,
          },
          android: { priority: "high" },
          apns: {
            headers: { "apns-priority": "10" },
            payload: {
              aps: {
                alert: {
                  title: "Playdate Accepted 🐾",
                  body: `${requestedDogName} accepted your playdate request.`,
                },
                sound: "default",
                badge: 1,
                "interruption-level": "time-sensitive",
              },
            },
          },

        },
      });


      /* ----------------------------------------------------
       * ⏰ OPTIONAL REMINDER
       * -------------------------------------------------- */


      console.log("✅ ACCEPT DONE");
      return res.status(200).json({ success: true });
    } catch (err) {
      console.error("❌ ACCEPT ERROR", err);
      return res.status(500).json({ error: err.message });
    }
  }
);

exports.playdateReminderScheduler = onSchedule(
  {
    region: "europe-west3",
    schedule: "every 5 minutes",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const snap = await admin.firestore()
      .collection("playdate_reminders")
      .where("status", "==", "pending")
      .where("fireAt", "<=", now)
      .limit(20)
      .get();

    if (snap.empty) return;

    const batch = admin.firestore().batch();

    for (const doc of snap.docs) {
      const data = doc.data();

      // 🔔 ارسال Push
      await sendPlaydateReminderPush({
        userId: data.userId,
        requestId: data.requestId,
        minutesBefore: data.minutesBefore,
      });

      // 🧹 mark as sent
      batch.update(doc.ref, {
        status: "sent",
        firedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
);

async function sendPlaydateReminderPush({
  userId,
  requestId,
  minutesBefore,
}) {
  const db = admin.firestore();

  const userDoc = await db
    .collection("users")
    .doc(userId)
    .get();

  const token = userDoc.data()?.fcmToken;

  // ✅ 1️⃣ CREATE FIRESTORE NOTIFICATION

  await db.collection("notifications").add({
    recipientUserId: userId,
    title: "🐾 Playdate Reminder",
    body: `Your playdate is in ${minutesBefore} minutes`,
    type: "playdate_reminder",
    requestId: requestId,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // ✅ 2️⃣ SAFE PUSH
  await safeSendPush({
    token,
    userId,
    payload: {
      notification: {
        title: "🐾 Playdate Reminder",
        body: `Your playdate is in ${minutesBefore} minutes`,
      },
      data: {
        type: "playdate_reminder",
        requestId,
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "high_importance_channel",
        },
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: {
          aps: {
            alert: {
              title: "🐾 Playdate Reminder",
              body: `Your playdate is in ${minutesBefore} minutes`,
            },
            sound: "default",
            badge: 1,
            "interruption-level": "time-sensitive",
          },
        },
      },

    },
  });
}



exports.rejectPlayDateRequestHttp = onRequest(
  { region: "europe-west3" },
  async (req, res) => {
    console.log("🟢 HIT rejectPlayDateRequest");

    try {
      if (req.method !== "POST") {
        return res.status(405).json({ error: "POST only" });
      }

      /* ----------------------------------------------------
       * 🔐 AUTH
       * -------------------------------------------------- */
      const authHeader = req.headers.authorization || "";
      if (!authHeader.startsWith("Bearer ")) {
        return res.status(401).json({ error: "Missing auth token" });
      }

      const decoded = await admin
        .auth()
        .verifyIdToken(authHeader.replace("Bearer ", ""));
      const currentUserId = decoded.uid;

      /* ----------------------------------------------------
       * 📦 PAYLOAD
       * -------------------------------------------------- */
      const { requestId, requesterUserId, requestedUserId } = req.body || {};

      if (!requestId || !requesterUserId || !requestedUserId) {
        return res.status(400).json({ error: "Missing required fields" });
      }

      if (
        currentUserId !== requesterUserId &&
        currentUserId !== requestedUserId
      ) {
        return res.status(403).json({ error: "Not authorized" });
      }

      /* ----------------------------------------------------
       * 🔎 LOAD REQUEST
       * -------------------------------------------------- */
      const db = admin.firestore();
      const ref = db.collection("playDateRequests").doc(requestId);
      const snap = await ref.get();

      if (!snap.exists) {
        return res.status(200).json({ success: true });
      }

      const data = snap.data();

      /* ----------------------------------------------------
       * 🐶 DOG NAMES
       * -------------------------------------------------- */
      const [reqDogSnap, resDogSnap] = await Promise.all([
        db.collection("dogs").doc(data.requesterDogId).get(),
        db.collection("dogs").doc(data.requestedDogId).get(),
      ]);

      const requestedDogName =
        resDogSnap.data()?.name || "The other dog";

      /* ----------------------------------------------------
       * ❌ UPDATE STATUS
       * -------------------------------------------------- */
      await ref.update({
        status: "rejected",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      /* ----------------------------------------------------
       * 🔔 FIRESTORE NOTIFICATION
       * -------------------------------------------------- */
      await db.collection("notifications").add({
        recipientUserId: requesterUserId,
        title: "Playdate Rejected ❌",
        body: `${requestedDogName} rejected your playdate request.`,
        type: "playdate_response",
        requestId: requestId,
        status: "rejected",
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      /* ----------------------------------------------------
 * 📲 PUSH (SAFE)
 * -------------------------------------------------- */
      const userDoc = await db.collection("users").doc(requesterUserId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      await safeSendPush({
        token: fcmToken,
        userId: requesterUserId,
        payload: {
          notification: {
            title: "Playdate Rejected ❌",
            body: `${requestedDogName} rejected your playdate request.`,
          },
          data: {
            type: "playdate_response",
            status: "rejected",
            requestId: requestId,
          },
          android: { priority: "high" },
          apns: {
            headers: { "apns-priority": "10" },
            payload: {
              aps: {
                alert: {
                  title: "Playdate Rejected ❌",
                  body: `${requestedDogName} rejected your playdate request.`,
                },
                sound: "default",
                badge: 1,
              },
            },
          },

        },
      });


      console.log("✅ REJECT DONE");
      return res.status(200).json({ success: true });
    } catch (err) {
      console.error("❌ REJECT ERROR", err);
      return res.status(500).json({ error: err.message });
    }
  }
);


exports.createPlaydateReminder = onCall(
  { region: "europe-west3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const { requestId, minutesBefore } = request.data || {};
    if (!requestId || ![30, 60].includes(minutesBefore)) {
      throw new HttpsError("invalid-argument", "Invalid reminder payload");
    }

    const db = admin.firestore();

    const playdateSnap = await db
      .collection("playDateRequests")
      .doc(requestId)
      .get();

    if (!playdateSnap.exists) {
      throw new HttpsError("not-found", "Playdate not found");
    }

    const data = playdateSnap.data();
    if (!data.scheduledDateTime) {
      throw new HttpsError("failed-precondition", "Playdate not scheduled");
    }

    const scheduled = data.scheduledDateTime.toDate();
    const fireAt = new Date(
      scheduled.getTime() - minutesBefore * 60 * 1000
    );

    if (fireAt <= new Date()) {
      throw new HttpsError(
        "failed-precondition",
        "Reminder time already passed"
      );
    }

    // ✅ کلیدی
    const reminderId = `${requestId}_${request.auth.uid}_${minutesBefore}`;


    await db
      .collection("playdate_reminders")
      .doc(reminderId)
      .set({
        requestId,
        userId: request.auth.uid, // 🔑
        minutesBefore,
        fireAt: admin.firestore.Timestamp.fromDate(fireAt),
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });


    return { success: true };
  }
);


exports.fixDogIds = onRequest({ region: "europe-west3" }, async (req, res) => {
  if (!req.app) {
    console.error("App Check token missing or invalid");
    return res.status(401).json({ error: "Unauthorized: App Check token is required" });
  }
  const db = admin.firestore();
  try {
    const dogs = await db.collection("dogs").get();
    const batch = db.batch();
    let count = 0;
    for (const doc of dogs.docs) {
      const data = doc.data();
      const dogId = doc.id;
      const ownerId = data.ownerId;
      const parts = dogId.split("_");
      if (parts.length < 2) {
        console.warn(`Invalid dogId format for doc ${dogId}`);
        continue;
      }
      const name = parts.slice(0, -1).join("_");
      const storedUid = parts[parts.length - 1];
      const correctedUid = ownerId;
      const correctedDogId = `${name}_${correctedUid}`;
      if (dogId !== correctedDogId || ownerId !== correctedUid) {
        batch.set(db.collection("dogs").doc(correctedDogId), {
          ...data,
          ownerId: correctedUid,
        });
        batch.delete(doc.ref);
        count++;
      }
    }
    await batch.commit();
    console.log(`Successfully updated ${count} dog documents`);
    return res.status(200).json({ success: true, message: `Updated ${count} documents` });
  } catch (error) {
    console.error("Error updating dog IDs:", toPlainError(error));
    return res.status(500).json({ error: "Failed to update dog IDs" });
  }
});

exports.restorePlayDateRequestUIDs = onRequest({ region: "europe-west3" }, async (req, res) => {
  if (!req.app) {
    console.error("App Check token missing or invalid");
    return res.status(401).json({ error: "Unauthorized: App Check token is required" });
  }
  const db = admin.firestore();
  try {
    const requests = await db.collection("playDateRequests").get();
    const batch = db.batch();
    let count = 0;
    for (const doc of requests.docs) {
      const data = doc.data();
      const requesterUserId = data.requesterUserId;
      const requestedUserId = data.requestedUserId;
      batch.update(doc.ref, {
        requesterUserId: requesterUserId,
        requestedUserId: requestedUserId,
        "requesterDog.ownerId": requesterUserId,
        "requestedDog.ownerId": requestedUserId,
      });
      count++;
    }
    await batch.commit();
    console.log(`Successfully processed ${count} playDateRequests for UID restoration`);
    return res.status(200).json({ success: true, message: `Processed ${count} documents` });
  } catch (error) {
    console.error("Error restoring UIDs:", toPlainError(error));
    return res.status(500).json({ error: "Failed to restore UIDs" });
  }
});

exports.fixPlayDateRequestStatus = onRequest({ region: "europe-west3" }, async (req, res) => {
  if (!req.app) {
    console.error("App Check token missing or invalid");
    return res.status(401).json({ error: "Unauthorized: App Check token is required" });
  }
  const db = admin.firestore();
  try {
    const requests = await db.collection("playDateRequests").get();
    const batch = db.batch();
    let count = 0;
    for (const doc of requests.docs) {
      const data = doc.data();
      if (data.status && data.status.toLowerCase() !== data.status) {
        batch.update(doc.ref, {
          status: data.status.toLowerCase(),
        });
        count++;
      }
    }
    await batch.commit();
    console.log(`Successfully updated ${count} playDateRequests with lowercase status`);
    return res.status(200).json({ success: true, message: `Updated ${count} documents` });
  } catch (error) {
    console.error("Error updating status:", toPlainError(error));
    return res.status(500).json({ error: "Failed to update status" });
  }
});

exports.fixPlayDateRequestTimestamps = onRequest({ region: "europe-west3" }, async (req, res) => {
  if (!req.app) {
    console.error("App Check token missing or invalid");
    return res.status(401).json({ error: "Unauthorized: App Check token is required" });
  }
  const db = admin.firestore();
  try {
    const requests = await db.collection("playDateRequests").get();
    const batch = db.batch();
    let count = 0;
    for (const doc of requests.docs) {
      const data = doc.data();
      const updates = {};
      if (typeof data.scheduledDateTime === "string") {
        try {
          updates.scheduledDateTime = admin.firestore.Timestamp.fromDate(new Date(data.scheduledDateTime));
        } catch (e) {
          console.warn(`Invalid scheduledDateTime format for doc ${doc.id}: ${data.scheduledDateTime}`);
        }
      }
      if (typeof data.requestDate === "string") {
        try {
          updates.requestDate = admin.firestore.Timestamp.fromDate(new Date(data.requestDate));
        } catch (e) {
          console.warn(`Invalid requestDate format for doc ${doc.id}: ${data.requestDate}`);
        }
      }
      if (Object.keys(updates).length > 0) {
        batch.update(doc.ref, updates);
        count++;
      }
    }
    await batch.commit();
    console.log(`Successfully updated ${count} playDateRequests with Timestamp fields`);
    return res.status(200).json({ success: true, message: `Updated ${count} documents` });
  } catch (error) {
    console.error("Error updating timestamps:", toPlainError(error));
    return res.status(500).json({ error: "Failed to update timestamps" });
  }
});

// ⚠️ LEGACY – DO NOT USE FROM CLIENT

exports.updatePlayDateRequestStatusV2 = onCall(
  { region: "europe-west3", cors: true },
  async (request) => {
    try {
      const { requestId, status, requesterUserId, requestedUserId } = request.data || {};

      if (!requestId || !status || !requesterUserId || !requestedUserId) {
        logger.error("Missing required fields", { requestId, status, requesterUserId, requestedUserId });
        throw new HttpsError("invalid-argument", "Missing required fields.");
      }

      const db = admin.firestore();
      const requestRef = db.collection("playDateRequests").doc(requestId);
      const requestDoc = await requestRef.get();
      if (!requestDoc.exists) {
        logger.error("Request not found", { requestId });
        throw new HttpsError("not-found", "Request not found");

      }
      const requestData = requestDoc.data();
      const currentUserId = request.auth?.uid;
      if (!currentUserId || (currentUserId !== requesterUserId && currentUserId !== requestedUserId)) {
        logger.error("User not authorized to update this request", { currentUserId, requesterUserId, requestedUserId });
        throw new HttpsError("permission-denied", "User not authorized to update this request");
      }

      let transactionAttempt = 0;
      const maxAttempts = 3;
      while (transactionAttempt < maxAttempts) {
        try {
          await admin.firestore().runTransaction(async (transaction) => {
            const doc = await transaction.get(requestRef);
            if (!doc.exists) {
              throw new HttpsError("not-found", "Document not found during transaction");
            }
            transaction.update(requestRef, { status });
            if (status === "rejected") {
              transaction.delete(requestRef);
            }
          });
          break;
        } catch (transactionError) {
          transactionAttempt++;
          if (transactionAttempt === maxAttempts) {
            logger.error("Transaction failed after maximum attempts", { message: transactionError.message, stack: transactionError.stack });
            throw new HttpsError("aborted", "Transaction failed after maximum attempts");
          }
          await new Promise(resolve => setTimeout(resolve, 500));
        }
      }

      if (status === "accepted") {
        const scheduledDateTime = requestData.scheduledDateTime.toDate();
        const reminderTime = new Date(scheduledDateTime.getTime() - 2 * 60 * 60 * 1000);
        const currentTime = new Date();
        if (reminderTime > currentTime) {
          await db.collection("scheduled_notifications").add({
            to: requesterUserId,
            title: "Reminder: Upcoming Playdate!",
            body: "You have a playdate in 2 hours.",
            scheduledAt: admin.firestore.Timestamp.fromDate(reminderTime),
          });
          await db.collection("scheduled_notifications").add({
            to: requestedUserId,
            title: "Reminder: Upcoming Playdate!",
            body: "You have a playdate in 2 hours.",
            scheduledAt: admin.firestore.Timestamp.fromDate(reminderTime),
          });
        } else if (scheduledDateTime < currentTime) {
          await requestRef.delete();
          logger.info("Auto-deleted expired accepted request:", { requestId });
        }
      }

      logger.info("Request updated successfully for ID:", { requestId, status });
      return { success: true, message: `Request marked as ${status}` };
    } catch (err) {
      logger.error("updatePlayDateRequestStatusV2 failed", { message: err.message, stack: err.stack });
      throw new HttpsError("internal", "Something went wrong.");
    }
  }
);

// ⚠️ LEGACY – ADMIN / DEBUG ONLY

exports.updatePlayDateStatus = onRequest({ region: "europe-west3" }, async (req, res) => {
  if (!req.app) {
    console.error("App Check token missing or invalid");
    return res.status(401).json({ error: "Unauthorized: App Check token is required" });
  }
  const db = admin.firestore();
  const { requestId, status } = req.body || {};
  if (!requestId || !status) {
    console.error("Missing requestId or status");
    return res.status(400).json({ error: "Request ID and status are required" });
  }
  if (!["accepted", "rejected"].includes(status)) {
    console.error("Invalid status:", status);
    return res.status(400).json({ error: "Invalid status" });
  }
  try {
    const requestRef = db.collection("playDateRequests").doc(requestId);
    const requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      console.error("Request not found:", requestId);
      return res.status(404).json({ error: "Request not found" });
    }
    await requestRef.update({ status });
    if (status === "rejected") {
      await requestRef.delete();
    }
    console.log(`Successfully updated status to ${status} for request ${requestId}`);
    return res.status(200).json({ success: true, message: `Request marked as ${status}` });
  } catch (error) {
    console.error("Error updating status:", toPlainError(error));
    return res.status(500).json({ error: "Failed to update status" });
  }
});

exports.cleanupDuplicateDogs = onRequest({ region: "europe-west3" }, async (req, res) => {
  if (!req.app) {
    console.error("App Check token missing or invalid");
    return res.status(401).json({ error: "Unauthorized: App Check token is required" });
  }
  const db = admin.firestore();
  try {
    const dogs = await db.collection("dogs").get();
    const dogMap = new Map();
    const batch = db.batch();
    let deletedCount = 0;

    for (const doc of dogs.docs) {
      const data = doc.data();
      const docId = doc.id;
      const ownerId = data.ownerId;
      const name = data.name;
      const key = `${ownerId}:${name}`;

      if (!dogMap.has(key)) {
        dogMap.set(key, { id: docId, data, timestamp: data.createdAt || admin.firestore.FieldValue.serverTimestamp() });
        console.log(`Keeping dog: ${docId}, name: ${name}, ownerId: ${ownerId}`);
      } else {
        const existing = dogMap.get(key);
        const existingTimestamp = existing.timestamp ? existing.timestamp.toMillis() : 0;
        const currentTimestamp = data.createdAt ? data.createdAt.toMillis() : 0;

        if (currentTimestamp > existingTimestamp) {
          batch.delete(db.collection("dogs").doc(existing.id));
          dogMap.set(key, { id: docId, data, timestamp: data.createdAt || admin.firestore.FieldValue.serverTimestamp() });
          console.log(`Replacing older dog: ${existing.id} with ${docId}, name: ${name}, ownerId: ${ownerId}`);
        } else {
          batch.delete(doc.ref);
          console.log(`Deleting duplicate dog: ${docId}, name: ${name}, ownerId: ${ownerId}`);
        }
        deletedCount++;
      }
    }

    await batch.commit();
    console.log(`Successfully deleted ${deletedCount} duplicate dogs`);
    return res.status(200).json({
      success: true,
      message: `Deleted ${deletedCount} duplicate dogs`,
      keptDocuments: Array.from(dogMap.values()).map(entry => ({ id: entry.id, name: entry.data.name, ownerId: entry.data.ownerId }))
    });
  } catch (error) {
    console.error("Error cleaning up duplicate dogs:", toPlainError(error));
    return res.status(500).json({ error: "Failed to clean up duplicate dogs" });
  }
});

exports.checkDuplicateDogs = onRequest({ region: "europe-west3" }, async (req, res) => {
  if (!req.app) {
    console.error("App Check token missing or invalid");
    return res.status(401).json({ error: "Unauthorized: App Check token is required" });
  }
  const db = admin.firestore();
  try {
    const dogs = await db.collection("dogs").get();
    const dogMap = new Map();
    const duplicates = [];

    for (const doc of dogs.docs) {
      const data = doc.data();
      const docId = doc.id;
      const ownerId = data.ownerId;
      const name = data.name;
      const key = `${ownerId}:${name}`;

      if (dogMap.has(key)) {
        duplicates.push({
          id: docId,
          name: data.name,
          ownerId: data.ownerId,
          createdAt: data.createdAt ? data.createdAt.toDate().toISOString() : 'Unknown'
        });
        const existing = dogMap.get(key);
        duplicates.push({
          id: existing.id,
          name: existing.data.name,
          ownerId: existing.data.ownerId,
          createdAt: existing.data.createdAt ? existing.data.createdAt.toDate().toISOString() : 'Unknown'
        });
      } else {
        dogMap.set(key, { id: docId, data, createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp() });
      }
    }

    console.log(`Found ${duplicates.length} duplicate dogs`);
    return res.status(200).json({
      success: true,
      message: `Found ${duplicates.length} duplicate dogs`,
      duplicates
    });
  } catch (error) {
    console.error("Error checking duplicate dogs:", toPlainError(error));
    return res.status(500).json({ error: "Failed to check duplicate dogs" });
  }
});

exports.sendDislikeNotification = onCall(
  { region: "europe-west3" },
  async (request) => {

    const { dogId, userId } = request.data;

    if (!dogId || !userId) {
      throw new HttpsError('invalid-argument', 'dogId and userId are required');
    }

    const db = admin.firestore();

    const dogDoc = await db.collection('dogs').doc(dogId).get();
    if (!dogDoc.exists) {
      throw new HttpsError('not-found', 'Dog not found');
    }

    const dogData = dogDoc.data();
    const dogOwnerId = dogData.ownerId;
    const dogName = dogData.name;

    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new HttpsError('not-found', 'User not found');
    }

    const userName = userDoc.data().username || 'User';

    const ownerDoc = await db.collection('users').doc(dogOwnerId).get();
    if (!ownerDoc.exists) {
      throw new HttpsError('not-found', 'Owner not found');
    }

    const ownerFcmToken = ownerDoc.data().fcmToken;

    await safeSendPush({
      token: ownerFcmToken,
      userId: dogOwnerId,
      payload: {
        notification: {
          title: 'Dog Disliked',
          body: `${userName} disliked your dog ${dogName}!`,
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'high_importance_channel',
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              alert: {
                title: "Dog Disliked",
                body: `${userName} disliked your dog ${dogName}!`,
              },
              sound: "default",
              badge: 1,
            },
          },
        },

      },
    });

    return { success: true };
  }
);



exports.sendLostFoundNotificationHttp = onRequest(
  { region: "europe-west3" },
  async (req, res) => {
    try {
      /* ----------------------------------------------------
       * 1️⃣ METHOD CHECK
       * -------------------------------------------------- */
      if (req.method !== "POST") {
        return res.status(405).json({ error: "POST only" });
      }

      /* ----------------------------------------------------
       * 2️⃣ AUTH CHECK (Bearer)
       * -------------------------------------------------- */
      const authHeader = req.headers.authorization || "";
      if (!authHeader.startsWith("Bearer ")) {
        return res.status(401).json({ error: "Missing auth token" });
      }

      const idToken = authHeader.replace("Bearer ", "");
      const decoded = await admin.auth().verifyIdToken(idToken);
      const currentUserId = decoded.uid;

      /* ----------------------------------------------------
       * 3️⃣ PAYLOAD VALIDATION
       * -------------------------------------------------- */
      const { title, body, lostDogId, foundDogId } = req.body || {};

      if (!title || !body || (!lostDogId && !foundDogId)) {
        return res.status(400).json({
          error:
            "title, body, and at least one of lostDogId or foundDogId required",
        });
      }

      const type = lostDogId ? "lost_dog" : "found_dog";

      const db = admin.firestore();

      /* ----------------------------------------------------
       * 4️⃣ SEND TOPIC PUSH (FAST)
       * -------------------------------------------------- */
      const pushPayload = {
        topic: "all_users",

        notification: {
          title,
          body,
        },

        data: {
          type,
          ...(lostDogId && { lostDogId: String(lostDogId) }),
          ...(foundDogId && { foundDogId: String(foundDogId) }),
          senderUid: currentUserId,
        },

        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: "high_importance_channel",
          },
        },

        apns: {
          headers: {
            "apns-priority": "10",
            "apns-push-type": "alert",
          },
          payload: {
            aps: {
              alert: { title, body },
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      await admin.messaging().send(pushPayload);

      /* ----------------------------------------------------
       * 5️⃣ CREATE USER-SPECIFIC IN-APP NOTIFICATIONS
       * -------------------------------------------------- */

      const usersSnap = await db.collection("users").limit(500).get();

      const batch = db.batch();

      const now = admin.firestore.FieldValue.serverTimestamp();

      usersSnap.forEach((userDoc) => {
        const notifRef = db.collection("notifications").doc();

        batch.set(notifRef, {
          title,
          body,
          type,
          ...(lostDogId && { lostDogId: String(lostDogId) }),
          ...(foundDogId && { foundDogId: String(foundDogId) }),

          recipientUserId: userDoc.id,   // ✅ IMPORTANT
          senderUid: currentUserId,

          isRead: false,
          createdAt: now,
        });
      });

      await batch.commit();

      /* ----------------------------------------------------
       * 6️⃣ SUCCESS
       * -------------------------------------------------- */
      return res.status(200).json({ success: true });

    } catch (err) {
      console.error("sendLostFoundNotificationHttp error:", err);
      return res.status(500).json({
        error: err.message || String(err),
      });
    }
  }
);

exports.sendNotification = onCall(
  { region: "europe-west3", cors: true, enforceAppCheck: false },
  async (request) => {
    const { title, body, lostDogId, foundDogId } = request.data || {};

    if (!title || !body || (!lostDogId && !foundDogId)) {
      logger.warn("sendNotification invalid payload", {
        title,
        body,
        lostDogId,
        foundDogId,
      });
      return { success: false, reason: "invalid-payload" };
    }

    const currentUserId = request.auth?.uid;

    // 🔐 FAIL-SAFE AUTH (NO THROW)
    if (!currentUserId) {
      logger.warn("sendNotification called without auth");
      return { success: false, reason: "unauthenticated" };
    }

    const db = admin.firestore();

    const payload = {
      notification: {
        title,
        body,
      },
      topic: "all_users",
      data: {
        type: lostDogId ? "lost_dog" : "found_dog",
        ...(lostDogId && { lostDogId: lostDogId.toString() }),
        ...(foundDogId && { foundDogId: foundDogId.toString() }),
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
      },
    };

    try {
      await admin.messaging().send(payload);
    } catch (pushError) {
      logger.error("Topic push failed", toPlainError(pushError));
      return { success: false, reason: "push-failed" };
    }

    try {
      await db.collection("notifications").add({
        title,
        body,
        type: lostDogId ? "lost_dog" : "found_dog",
        ...(lostDogId && { lostDogId: lostDogId.toString() }),
        ...(foundDogId && { foundDogId: foundDogId.toString() }),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        isRead: false,
        recipientUserId: null,
      });
    } catch (firestoreError) {
      logger.error(
        "Firestore notification save failed",
        toPlainError(firestoreError)
      );
      // still don't throw
    }

    return { success: true };
  }
);
/* ----------------------------------------------------
* 📲 SAFE REJECT PUSH
* -------------------------------------------------- */
/*
const requesterUserDoc = await db
  .collection("users")
  .doc(requesterUserId)
  .get();

const requesterFcmToken = requesterUserDoc.data()?.fcmToken;

await safeSendPush({
  token: requesterFcmToken,
  userId: requesterUserId,
  payload: {
    notification: {
      title: "Playdate Rejected ❌",
      body: `${requestedDogName} rejected your playdate request.`,
    },
    data: {
      type: "playdate_response",
      status: "rejected",
      requestId,
    },
    apns: {
      headers: { "apns-priority": "10" },
      payload: {
        aps: { sound: "default" },
      },
    },
    android: {
      priority: "high",
    },
  },
});




logger.info("Notification saved to Firestore", { lostDogId, foundDogId });
logger.info("Notification sent successfully", { title, body, lostDogId, foundDogId });

return { success: true, message: "Notification sent successfully" };
  } catch (err) {
  logger.error("sendNotification failed", { message: err.message, stack: err.stack });
  logger.info("Error details", { error: toPlainError(err) });
  throw new HttpsError("internal", "Failed to send notification", err.message);
}
});
*/



exports.cleanupExpiredRequests = onSchedule({
  schedule: 'every 24 hours',
  region: 'europe-west3'
}, async (context) => {
  const db = admin.firestore();
  const currentTime = admin.firestore.Timestamp.now();
  logger.info("Starting cleanup of expired requests", { currentTime: currentTime.toDate(), runtimeTrigger: "nodejs20" });
  const isActiveCleanup = true;
  if (isActiveCleanup) {
    logger.info("Active cleanup condition met, proceeding with deletion");
  } else {
    logger.info("Cleanup skipped due to inactive condition");
    return null;
  }
  try {
    const snapshot = await db.collection("playDateRequests")
      .where('scheduledDateTime', '<', currentTime)
      .where('status', '==', 'pending')
      .get();
    const batch = db.batch();
    let deletedCount = 0;

    snapshot.forEach(doc => {
      const requestData = doc.data();
      batch.delete(doc.ref);
      logger.info("Deleted expired request:", {
        requestId: doc.id,
        scheduledDateTime: requestData.scheduledDateTime?.toDate(),
        status: requestData.status,
        runtimeTrigger: "nodejs20"
      });
      deletedCount++;
    });

    await batch.commit();
    logger.info(`Successfully deleted ${deletedCount} expired requests`, { deletedCount, runtimeTrigger: "nodejs20" });
    return null;
  } catch (error) {
    logger.error("Error cleaning up expired requests:", toPlainError(error));
    throw new Error("Failed to clean up expired requests");
  }


});

/* =====================================================
 * 🏢 REGISTER BUSINESS (ADOPTION CENTER) - UNIFIED
 * ===================================================== */

exports.registerBusiness = onCall(
  {
    region: "europe-west3",
    enforceAppCheck: false,
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
      }

      const uid = request.auth.uid;
      const db = admin.firestore();

      const { sectors, draft, lat, lng } = request.data || {};

      // =========================
      // VALIDATION
      // =========================
      if (!sectors || !Array.isArray(sectors) || sectors.length === 0 || !draft) {
        throw new HttpsError("invalid-argument", "Missing sectors or draft");
      }

      const profile = draft.profile || {};
      const contact = draft.contact || {};
      const legal = draft.legal || {};

      if (!profile.displayName || !contact.city || !contact.district) {
        throw new HttpsError(
          "invalid-argument",
          "displayName, city and district are required"
        );
      }

      if (!lat || !lng) {
        throw new HttpsError(
          "invalid-argument",
          "Location coordinates required"
        );
      }

      // =========================
      // PREVENT DUPLICATE
      // =========================
      const existingRequest = await db
        .collection("business_requests")
        .where("uid", "==", uid)
        .where("status", "in", ["pending", "under_review"])
        .limit(1)
        .get();

      if (!existingRequest.empty) {
        throw new HttpsError(
          "already-exists",
          "You already have a pending business request"
        );
      }

      const existingBusiness = await db
        .collection("businesses")
        .doc(uid)
        .get();

      if (existingBusiness.exists) {
        throw new HttpsError(
          "already-exists",
          "User already has a business"
        );
      }



      // =========================
      // OCR VALIDATION (TR)
      // =========================
      let riskFlags = [];

      if (request.data.countryCode === "TR") {
        if (!legal.taxNumber || !legal.mersisNumber) {
          throw new HttpsError(
            "invalid-argument",
            "Tax Number and MERSIS required"
          );
        }

        const draftSnap = await db
          .collection("businessDrafts")
          .doc(uid)
          .get();

        if (!draftSnap.exists) {
          throw new HttpsError(
            "failed-precondition",
            "OCR verification required"
          );
        }

        const ocr = draftSnap.data()?.verification?.ocr;

        if (!ocr) {
          throw new HttpsError(
            "failed-precondition",
            "OCR not completed"
          );
        }

        if (ocr.extractedTaxNumber !== legal.taxNumber) {
          throw new HttpsError(
            "permission-denied",
            "Tax number mismatch with OCR"
          );
        }

        if (
          ocr.extractedMersisNumber &&
          ocr.extractedMersisNumber !== legal.mersisNumber
        ) {
          throw new HttpsError(
            "permission-denied",
            "MERSIS mismatch with OCR"
          );
        }

        if (!legal.mersisNumber.startsWith(legal.taxNumber)) {
          riskFlags.push("mersis_prefix_mismatch");
        }
      }

      console.log("🔥 SECTORS:", sectors);
      console.log("🔥 SECTOR DATA:", draft.sectorData);

      // =========================
      // CREATE BUSINESS (PENDING)
      // =========================
      const businessRef = db.collection("businesses").doc(uid);

      const businessDoc = {
        sectors,
        sectorData: draft.sectorData || {},
        ownerUid: uid,
        status: "pending", // 🔥 مهم — هنوز تایید نشده

        verification: {
          level: "basic",
          isVerified: false,
          verifiedAt: null,
          verifiedBy: null,
          notes: null,
          ocrVerified: true,
        },

        profile: {
          displayName: profile.displayName.trim(),
          description: profile.description?.trim() || "",
          logoUrl: profile.logoUrl || null,
          coverUrl: profile.coverUrl || null,
          categories: [],
          tags: [],
        },

        contact: {
          phone: contact.phone || null,
          whatsapp: contact.whatsapp || null,
          email: contact.email || null,
          instagram: contact.instagram || null,
          website: contact.website || null,
          city: contact.city.trim(),
          district: contact.district.trim(),
          addressLine: contact.addressLine || "",
          location: { lat, lng },
        },

        legal: {
          taxNumber: legal.taxNumber,
          mersisNumber: legal.mersisNumber,
          documents: [],
          disclaimerAcceptedAt:
            admin.firestore.FieldValue.serverTimestamp(),
        },

        trust: {
          reportCount: 0,
          moderationNotes: null,
          riskFlags,
        },

        subscription: {
          plan: "free",
          status: "active",
          startedAt: null,
          expiresAt: null,
        },

        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      // 🔥 SAVE BUSINESS
      await businessRef.set(businessDoc);

      // =========================
      // CREATE REQUEST (FOR ADMIN)
      // =========================
      const requestRef = await db.collection("business_requests").add({
        uid,
        businessId: businessRef.id, // 🔥🔥🔥 مهم‌ترین خط
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),

        sectors,

        profile: {
          displayName: profile.displayName.trim(),
          description: profile.description?.trim() || "",
          logoUrl: profile.logoUrl || null,
          coverUrl: profile.coverUrl || null,
        },

        contact: {
          phone: contact.phone || null,
          whatsapp: contact.whatsapp || null,
          email: contact.email || null,
          instagram: contact.instagram || null,
          website: contact.website || null,
          city: contact.city.trim(),
          district: contact.district.trim(),
          addressLine: contact.addressLine || "",
          location: { lat, lng },
        },

        legal: {
          taxNumber: legal.taxNumber,
          mersisNumber: legal.mersisNumber,
        },

        sectorData: draft.sectorData || {},
      });

      // =========================
      // UPDATE USER
      // =========================
      await db.collection("users").doc(uid).set(
        {
          business: {
            requestId: requestRef.id,
            status: "pending",
            sectors,
            isVerified: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true }
      );

      // =========================
      // DONE
      // =========================
      return {
        success: true,
        requestId: requestRef.id,
      };

    } catch (err) {
      console.error("❌ registerBusiness error:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", "REGISTER_BUSINESS_FAILED");
    }
  }
);

/* =====================================================
 * 🏢 ADMIN RESOLVE BUSINESS REQUEST - UNIFIED
 * ===================================================== */

exports.resolveBusinessRequest = onCall(
  { region: "europe-west3" },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
      }

      const adminUid = request.auth.uid;
      const db = admin.firestore();

      // 🔐 admin check
      const adminDoc = await db.collection("users").doc(adminUid).get();
      if (!adminDoc.exists || adminDoc.data()?.role !== "admin") {
        throw new HttpsError("permission-denied", "Admin only");
      }

      const { requestId, action, reason } = request.data || {};

      if (!requestId || !["approved", "rejected"].includes(action)) {
        throw new HttpsError("invalid-argument", "Invalid payload");
      }

      const reqRef = db.collection("business_requests").doc(requestId);
      const reqSnap = await reqRef.get();

      if (!reqSnap.exists) {
        throw new HttpsError("not-found", "Request not found");
      }

      const reqData = reqSnap.data() || {};

      // ✅ FIX: NEW STRUCTURE
      const ownerUid = reqData.uid;
      const businessId = reqData.businessId;

      if (!ownerUid || !businessId) {
        throw new HttpsError(
          "failed-precondition",
          "Missing uid or businessId"
        );
      }

      const bizRef = db.collection("businesses").doc(businessId);
      const userRef = db.collection("users").doc(ownerUid);

      await db.runTransaction(async (tx) => {

        // 1️⃣ update request
        tx.update(reqRef, {
          status: action,
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
          resolvedBy: adminUid,
          ...(action === "rejected" ? { reason: reason || null } : {}),
        });

        if (action === "approved") {
          // ✅ update existing business (NOT create new)
          tx.update(bizRef, {
            status: "approved",

            "verification.isVerified": true,
            "verification.verifiedAt":
              admin.firestore.FieldValue.serverTimestamp(),
            "verification.verifiedBy": adminUid,

            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // update user
          tx.set(
            userRef,
            {
              business: {
                businessId: bizRef.id,
                status: "approved",
                isVerified: true,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
            },
            { merge: true }
          );
        }

        if (action === "rejected") {
          tx.set(
            userRef,
            {
              business: {
                status: "rejected",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
            },
            { merge: true }
          );
        }

        // 3️⃣ ADMIN LOG
        const logRef = db.collection("admin_logs").doc();

        tx.set(logRef, {
          entityType: "business",
          entityId: businessId,
          action,
          performedBy: adminUid,
          reason: reason || null,
          metadata: { requestId },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      // 🔔 notification
      await db.collection("notifications").add({
        recipientUserId: ownerUid,
        title:
          action === "approved"
            ? "Your Business is Approved ✅"
            : "Your Business was Rejected ❌",
        body:
          action === "approved"
            ? "You can now access your dashboard."
            : (reason || "Please contact support."),
        type: "business_resolution",
        status: action,
        requestId,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true };

    } catch (err) {
      console.error("resolveBusinessRequest error:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", "BUSINESS_RESOLUTION_FAILED");
    }
  }
);
exports.migrateAdoptionCentersToBusinesses = onRequest(
  {
    region: "europe-west3",
    invoker: "public",
  },
  async (req, res) => {
    const dryRun = req.query.dryRun !== "false"; // default = true

    try {
      const snapshot = await admin
        .firestore()
        .collection("adoption_centers")
        .get();

      console.log(`🔍 Found ${snapshot.size} adoption_centers`);

      let migratedCount = 0;

      for (const doc of snapshot.docs) {
        const oldData = doc.data();
        const newBusinessData = mapAdoptionCenterToBusiness(oldData);

        // ✅ اینجا باید اضافه شود
        newBusinessData.updatedAt = admin.firestore.FieldValue.serverTimestamp();

        if (!dryRun) {
          await admin
            .firestore()
            .collection("businesses")
            .doc(doc.id)
            .set(newBusinessData);
          migratedCount++;
        }
      }

      res.status(200).send({
        dryRun,
        totalFound: snapshot.size,
        migratedCount,
      });
    } catch (error) {
      console.error("❌ Migration error:", error);
      res.status(500).send(error.toString());
    }
  }
);

exports.ocrBusinessDoc = onObjectFinalized(
  {
    region: "europe-west3",
    bucket: "barkymatches-new.firebasestorage.app",
  },
  async (event) => {

    const filePath = event.data.name;
    if (!filePath || !filePath.startsWith("business_docs/")) return;

    const bucketName = event.data.bucket;
    const fileUri = `gs://${bucketName}/${filePath}`;

    // 🔥 FIX 1 — extract uid safely
    const parts = filePath.split("/");
    if (parts.length < 2) {
      console.log("Invalid file path structure");
      return;
    }

    const uid = parts[1]; // ✅ now defined safely

    let result;

    try {
      [result] = await client.textDetection(fileUri);
    } catch (err) {
      console.error("Vision OCR failed:", err);
      return;
    }

    const detections = result.textAnnotations;
    if (!detections || detections.length === 0) return;

    const fullText = detections[0].description;

    // 🔥 VKN
    const vknMatch = fullText.match(/\b\d{10}\b/);
    const extractedTaxNumber = vknMatch ? vknMatch[0] : null;

    // 🔥 MERSIS (label first, fallback second)
    let mersisMatch = fullText.match(/MERS[İI]S\s*(NO|NUMARASI)?[:\s]*([0-9]{16})/i);

    let extractedMersisNumber = null;

    if (mersisMatch && mersisMatch[2]) {
      extractedMersisNumber = mersisMatch[2];
    } else {
      const fallback = fullText.match(/\b\d{16}\b/);
      extractedMersisNumber = fallback ? fallback[0] : null;
    }

    await admin.firestore()
      .collection("businessDrafts")
      .doc(uid)
      .set({
        verification: {
          status: "ocr_extracted",
          ocr: {
            extractedTaxNumber,
            extractedMersisNumber,
            rawText: fullText,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }
        }
      }, { merge: true });

    console.log("OCR SUCCESS → UID:", uid);
  }
);

exports.updateBusinessAdminNotes = onCall(
  { region: "europe-west3" },
  async (request) => {

    const uid = request.auth?.uid;
    if (!uid) {
      throw new Error("UNAUTHENTICATED");
    }

    const db = admin.firestore();

    // 🔎 Check user role
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists || userSnap.data().role !== "admin") {
      throw new Error("PERMISSION_DENIED");
    }

    const { businessId, notes } = request.data;

    if (!businessId) {
      throw new Error("businessId is required");
    }

    await db.collection("businesses").doc(businessId).update({
      "trust.moderationNotes": notes ?? "",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  }
);

exports.suspendBusiness = onCall(
  { region: "europe-west3" },
  async (request) => {
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "Login required");

      const adminUid = request.auth.uid;
      const db = admin.firestore();

      const adminDoc = await db.collection("users").doc(adminUid).get();
      if (!adminDoc.exists || adminDoc.data()?.role !== "admin") {
        throw new HttpsError("permission-denied", "Admin only");
      }

      const { businessId, reason } = request.data || {};
      if (!businessId) throw new HttpsError("invalid-argument", "businessId required");

      const bizRef = db.collection("businesses").doc(String(businessId));

      await db.runTransaction(async (tx) => {
        const bizSnap = await tx.get(bizRef);
        if (!bizSnap.exists) throw new HttpsError("not-found", "Business not found");

        const bizData = bizSnap.data() || {};
        const prevStatus = bizData.status || "approved"; // fallback

        // 1) update business status
        tx.set(
          bizRef,
          {
            status: "suspended",
            statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            statusUpdatedBy: adminUid,
            suspension: {
              isActive: true,
              reason: reason || "Suspended by admin",
              suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
              suspendedBy: adminUid,
              prevStatus,
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        // 2) admin log
        tx.set(db.collection("admin_logs").doc(), {
          type: "business_suspend",
          businessId: String(businessId),
          by: adminUid,
          reason: reason || null,
          prevStatus,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // 3) optional: suspension history record
        tx.set(db.collection("business_suspensions").doc(), {
          businessId: String(businessId),
          reason: reason || "Suspended by admin",
          suspendedBy: adminUid,
          suspendedAt: admin.firestore.FieldValue.serverTimestamp(),
          restoredAt: null,
          restoredBy: null,
          prevStatus,
          isActive: true,
        });
      });

      return { success: true };
    } catch (err) {
      console.error("suspendBusiness error:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", "SUSPEND_FAILED", toPlainError(err));
    }
  }
);

exports.restoreBusiness = onCall(
  { region: "europe-west3" },
  async (request) => {
    try {
      if (!request.auth) throw new HttpsError("unauthenticated", "Login required");

      const adminUid = request.auth.uid;
      const db = admin.firestore();

      const adminDoc = await db.collection("users").doc(adminUid).get();
      if (!adminDoc.exists || adminDoc.data()?.role !== "admin") {
        throw new HttpsError("permission-denied", "Admin only");
      }

      const { businessId } = request.data || {};
      if (!businessId) throw new HttpsError("invalid-argument", "businessId required");

      const bizRef = db.collection("businesses").doc(String(businessId));

      await db.runTransaction(async (tx) => {
        const bizSnap = await tx.get(bizRef);
        if (!bizSnap.exists) throw new HttpsError("not-found", "Business not found");

        const bizData = bizSnap.data() || {};
        const prevStatus = bizData.suspension?.prevStatus || "approved";

        tx.set(
          bizRef,
          {
            status: prevStatus,
            statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            statusUpdatedBy: adminUid,
            suspension: {
              ...(bizData.suspension || {}),
              isActive: false,
              restoredAt: admin.firestore.FieldValue.serverTimestamp(),
              restoredBy: adminUid,
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        tx.set(db.collection("admin_logs").doc(), {
          type: "business_restore",
          businessId: String(businessId),
          by: adminUid,
          restoredTo: prevStatus,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // optional: mark latest active suspension history record inactive
        // (اگر خواستی دقیقش کنیم بعداً با query + batch)
      });

      return { success: true };
    } catch (err) {
      console.error("restoreBusiness error:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", "RESTORE_FAILED", toPlainError(err));
    }
  }
);

exports.expireSubscriptions =
  require("./src/expireSubscriptions").expireSubscriptions;


// =====================================================
// CREATE REPORT
// =====================================================

exports.createReport = onCall(
  { region: "europe-west3" },
  async (request) => {

    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const db = admin.firestore();

    const reporterId = request.auth.uid;
    const {
      type,
      targetId,
      targetOwnerId,
      reasonCode,
      reasonText,
      message
    } = request.data || {};
    if (!type || !targetId || !reasonCode) {
      throw new HttpsError("invalid-argument", "Missing parameters");
    }

    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);
    const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    // -------------------------------------------------
    // DUPLICATE PROTECTION
    // -------------------------------------------------

    const duplicate = await db.collection("reports")
      .where("reportedBy", "==", reporterId)
      .where("type", "==", type)
      .where("targetId", "==", targetId)
      .where("createdAt", ">", twentyFourHoursAgo)
      .limit(1)
      .get();

    if (!duplicate.empty) {
      throw new HttpsError("already-exists", "You already reported this item");
    }

    // -------------------------------------------------
    // RATE LIMIT
    // -------------------------------------------------

    const recentReports = await db.collection("reports")
      .where("reportedBy", "==", reporterId)
      .where("createdAt", ">", oneHourAgo)
      .get();

    if (recentReports.size >= 10) {
      throw new HttpsError("resource-exhausted", "Too many reports");
    }

    // -------------------------------------------------
    // TRUST SCORE WEIGHT
    // -------------------------------------------------

    let reportWeight = 1;

    try {

      const userDoc =
        await db.collection("users").doc(reporterId).get();

      const trustScore =
        userDoc.data()?.trustScore ?? 1;

      reportWeight = trustScore;

    } catch (e) {

      console.log("Trust score fallback", e);
      reportWeight = 1;

    }

    // -------------------------------------------------
    // CREATE REPORT
    // -------------------------------------------------

    const reportRef = db.collection("reports").doc();

    await reportRef.set({
      reportId: reportRef.id,
      type,
      targetId,
      targetOwnerId: targetOwnerId || null,

      reasonCode,
      reasonText: reasonText || "",
      message: message || "",

      reportedBy: reporterId,

      status: "pending",

      weight: reportWeight,

      source: "user",

      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()

    });



    // -------------------------------------------------
    // ANALYTICS
    // -------------------------------------------------

    const statsRef =
      db.collection("admin_stats").doc("moderation");

    await statsRef.set({

      reportsToday:
        admin.firestore.FieldValue.increment(1),

      reportsTotal:
        admin.firestore.FieldValue.increment(1),

      lastReportAt:
        admin.firestore.FieldValue.serverTimestamp()

    }, { merge: true });

    // -------------------------------------------------
    // AUTO MODERATION
    // -------------------------------------------------
    console.log("📢 NEW REPORT CREATED");
    console.log("TYPE:", type);
    console.log("TARGET:", targetId);
    console.log("REPORTER:", reporterId);
    console.log("WEIGHT:", reportWeight);
    await ensureModerationTarget(type, targetId, targetOwnerId);

    await ensureModerationCase(type, targetId, targetOwnerId);

    await recalcModerationTarget(type, targetId);

    await recalcModerationCase(type, targetId);

    await syncModerationTargetToContent(type, targetId);

    await detectMassReporting(type, targetId);

    return { success: true };

  }
);



// =====================================================
// REVIEW REPORT (ADMIN)
// =====================================================

exports.reviewReport = onCall(
  { region: "europe-west3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const db = admin.firestore();
    const { reportId, action } = request.data || {};

    if (!reportId || !action) {
      throw new HttpsError("invalid-argument", "Missing parameters");
    }

    if (action !== "approved" && action !== "rejected") {
      throw new HttpsError("invalid-argument", "Invalid action");
    }

    const reportRef = db.collection("reports").doc(reportId);
    const reportDoc = await reportRef.get();

    if (!reportDoc.exists) {
      throw new HttpsError("not-found", "Report not found");
    }

    const reportData = reportDoc.data() || {};
    const type = reportData.type;
    const targetId = reportData.targetId;
    const targetOwnerId = reportData.targetOwnerId || null;

    if (!type || !targetId) {
      throw new HttpsError("failed-precondition", "Missing target data");
    }

    const key = `${type}_${targetId}`;
    const moderationRef = db.collection("moderation_targets").doc(key);

    // مطمئن شو target moderation doc وجود دارد
    await ensureModerationTarget(type, targetId, targetOwnerId);

    // 1) update report status
    await reportRef.update({
      status: action,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewedBy: request.auth.uid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2) apply admin decision
    await moderationRef.set({
      lastAdminAction: {
        action,
        by: request.auth.uid,
        at: admin.firestore.FieldValue.serverTimestamp(),
        reportId,
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });



    // 3) resync moderation
    await recalcModerationTarget(type, targetId);
    await recalcModerationCase(type, targetId);
    await syncModerationTargetToContent(type, targetId);
    await detectMassReporting(type, targetId);

    // 4) analytics
    const statsRef = db.collection("admin_stats").doc("moderation");

    if (action === "approved") {
      await statsRef.set({
        reportsApproved: admin.firestore.FieldValue.increment(1),
      }, { merge: true });
    }

    if (action === "rejected") {
      await statsRef.set({
        reportsRejected: admin.firestore.FieldValue.increment(1),
      }, { merge: true });
    }

    return { success: true };
  }
);

// =====================================================
// MASS REPORT DETECTION
// =====================================================

async function detectMassReporting(type, targetId) {

  const db = admin.firestore();

  const tenMinutesAgo =
    new Date(Date.now() - 10 * 60 * 1000);

  const reportsSnapshot =
    await db.collection("reports")
      .where("type", "==", type)
      .where("targetId", "==", targetId)
      .where("createdAt", ">", tenMinutesAgo)
      .get();

  const count = reportsSnapshot.size;

  if (count >= 5) {

    await db.collection("admin_stats")
      .doc("moderation")
      .set({

        suspiciousReportClusters:
          admin.firestore.FieldValue.increment(1),

        lastSuspiciousCluster:
          admin.firestore.FieldValue.serverTimestamp()

      }, { merge: true });

  }

  if (count >= 10) {

    const existingFlag =
      await db.collection("admin_flags")
        .where("type", "==", "mass_reporting_attack")
        .where("targetId", "==", targetId)
        .limit(1)
        .get();

    if (existingFlag.empty) {

      await db.collection("admin_flags").add({
        type: "mass_reporting_attack",
        targetKey: `${type}_${targetId}`,
        targetId,
        targetType: type,
        reportsCount: count,
        status: "open",
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      await db.collection("admin_stats")
        .doc("moderation")
        .set({

          massReportingAttacks:
            admin.firestore.FieldValue.increment(1)

        }, { merge: true });

    }

  }

}

async function ensureModerationTarget(type, targetId, ownerId) {
  const db = admin.firestore();

  const key = `${type}_${targetId}`;
  const ref = db.collection("moderation_targets").doc(key);
  const snap = await ref.get();

  if (!snap.exists) {
    await ref.set({
      targetKey: key,
      targetType: type,
      targetId,
      targetOwnerId: ownerId || null,

      autoStatus: "active",
      adminStatus: "none",
      effectiveStatus: "active",

      pendingReportCount: 0,
      approvedReportCount: 0,
      rejectedReportCount: 0,

      pendingWeight: 0,
      riskScore: 0,

      requiresAdminReview: false,
      isHidden: false,

      lastReportAt: null,
      lastCaseId: null,

      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

async function ensureModerationCase(type, targetId, ownerId) {
  const db = admin.firestore();

  const key = `${type}_${targetId}`;

  const existingCaseSnap = await db
    .collection("moderation_cases")
    .where("targetKey", "==", key)
    .where("status", "in", ["open", "investigating"])
    .limit(1)
    .get();

  if (!existingCaseSnap.empty) {
    const caseRef = existingCaseSnap.docs[0].ref;

    await caseRef.set({
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastActivityAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return existingCaseSnap.docs[0].id;
  }

  const caseRef = db.collection("moderation_cases").doc();

  await caseRef.set({
    caseId: caseRef.id,

    targetKey: key,
    targetType: type,
    targetId,
    targetOwnerId: ownerId || null,

    reportCount: 0,
    uniqueReporterCount: 0,
    riskScore: 0,

    priority: "low",
    priorityRank: 1,

    queueStatus: "pending_review",
    status: "open",

    latestReasonCodes: [],
    summary: "",

    assignedAdmin: null,

    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastActivityAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return caseRef.id;
}

async function recalcModerationCase(type, targetId) {
  const db = admin.firestore();
  const key = `${type}_${targetId}`;

  const caseSnap = await db
    .collection("moderation_cases")
    .where("targetKey", "==", key)
    .where("status", "in", ["open", "investigating"])
    .limit(1)
    .get();

  if (caseSnap.empty) return;

  const caseRef = caseSnap.docs[0].ref;

  const reportsSnap = await db
    .collection("reports")
    .where("type", "==", type)
    .where("targetId", "==", targetId)
    .where("status", "in", ["pending", "approved"])
    .get();

  let reportCount = 0;
  let riskScore = 0;
  const reporterSet = new Set();
  const reasonCount = {};

  reportsSnap.forEach((doc) => {
    const data = doc.data();

    reportCount++;
    riskScore += data.weight || 1;

    if (data.reportedBy) {
      reporterSet.add(data.reportedBy);
    }

    const reason = data.reasonCode || "other";
    reasonCount[reason] = (reasonCount[reason] || 0) + 1;
  });

  const sortedReasons = Object.entries(reasonCount)
    .sort((a, b) => b[1] - a[1])
    .map(([reason]) => reason);

  let priority = "low";
  let priorityRank = 1;

  if (riskScore >= 5) {
    priority = "medium";
    priorityRank = 2;
  }

  if (riskScore >= 10) {
    priority = "high";
    priorityRank = 3;
  }

  if (riskScore >= 20) {
    priority = "critical";
    priorityRank = 4;
  }

  await caseRef.set({
    reportCount,
    uniqueReporterCount: reporterSet.size,
    riskScore,
    latestReasonCodes: sortedReasons.slice(0, 5),
    summary: sortedReasons.length
      ? `Top reasons: ${sortedReasons.slice(0, 3).join(", ")}`
      : "",
    priority,
    priorityRank,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    lastActivityAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

async function recalcModerationTarget(type, targetId) {
  const db = admin.firestore();

  const key = `${type}_${targetId}`;
  const targetRef = db.collection("moderation_targets").doc(key);

  const allReports = await db.collection("reports")
    .where("type", "==", type)
    .where("targetId", "==", targetId)
    .get();

  let pendingCount = 0;
  let approvedCount = 0;
  let rejectedCount = 0;

  let pendingWeight = 0;
  let approvedWeight = 0;

  let latestCreatedAt = null;

  allReports.forEach((doc) => {
    const data = doc.data();
    const status = data.status || "pending";
    const weight = data.weight || 1;

    if (status === "pending") {
      pendingCount++;
      pendingWeight += weight;
    }

    if (status === "approved") {
      approvedCount++;
      approvedWeight += weight;
    }

    if (status === "rejected") {
      rejectedCount++;
    }

    if (data.createdAt) {
      if (!latestCreatedAt || data.createdAt.toMillis() > latestCreatedAt.toMillis()) {
        latestCreatedAt = data.createdAt;
      }
    }
  });

  const riskScore = pendingWeight + approvedWeight;

  let autoStatus = "active";

  if (riskScore >= 5) {
    autoStatus = "flagged";
  }

  if (riskScore >= 10) {
    autoStatus = "restricted";
  }

  if (riskScore >= 20) {
    autoStatus = "hidden";
  }

  const requiresAdminReview = riskScore >= 25;

  await targetRef.set({
    pendingReportCount: pendingCount,
    approvedReportCount: approvedCount,
    rejectedReportCount: rejectedCount,

    pendingWeight,
    riskScore,
    autoStatus,
    requiresAdminReview,
    lastReportAt: latestCreatedAt || admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
}

function getModerationCollection(type) {
  switch (type) {
    case "dog":
      return "dogs";

    case "business":
      return "businesses";

    case "user":
      return "users";

    case "chat":
      return "chats";

    case "lost_dog":
      return "lost_dogs";

    case "found_dog":
      return "found_dogs";

    case "adoption":
      return "adoption_centers";

    default:
      throw new Error(`Unknown moderation type: ${type}`);
  }
}

async function syncModerationTargetToContent(type, targetId) {
  const db = admin.firestore();

  const key = `${type}_${targetId}`;

  const targetSnap = await db.collection("moderation_targets")
    .doc(key)
    .get();

  if (!targetSnap.exists) return;

  const data = targetSnap.data();

  const effectiveStatus = computeEffectiveStatus(
    data.autoStatus,
    data.adminStatus
  );

  const isHidden =
    effectiveStatus === "hidden" ||
    effectiveStatus === "suspended" ||
    effectiveStatus === "confirmed_violation";

  const collectionName = getModerationCollection(type);

  await db.collection(collectionName)
    .doc(targetId)
    .set({
      isHidden: admin.firestore.FieldValue.delete(),
      moderation: {
        effectiveStatus,
        isHidden,
        pendingReportCount: data.pendingReportCount || 0,
        approvedReportCount: data.approvedReportCount || 0,
        rejectedReportCount: data.rejectedReportCount || 0,
        riskScore: data.riskScore || 0,
        requiresAdminReview: data.requiresAdminReview || false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    }, { merge: true });

  await db.collection("moderation_targets")
    .doc(key)
    .set({
      effectiveStatus,
      isHidden,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}

function computeEffectiveStatus(autoStatus, adminStatus) {
  if (adminStatus === "suspended") return "suspended";
  if (adminStatus === "confirmed_violation") return "confirmed_violation";
  if (adminStatus === "clean") return "clean";
  if (adminStatus === "restored") return "active";

  if (autoStatus === "hidden") return "hidden";
  if (autoStatus === "restricted") return "restricted";
  if (autoStatus === "flagged") return "flagged";

  return "active";
}

exports.reviewModerationCase = onCall(
  { region: "europe-west3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const db = admin.firestore();
    const { caseId, action, reason } = request.data || {};

    if (!caseId || !action) {
      throw new HttpsError("invalid-argument", "Missing parameters");
    }

    const caseRef = db.collection("moderation_cases").doc(caseId);
    const caseDoc = await caseRef.get();

    if (!caseDoc.exists) {
      throw new HttpsError("not-found", "Case not found");
    }

    const caseData = caseDoc.data();
    const type = caseData.targetType;
    const targetId = caseData.targetId;
    const targetKey = caseData.targetKey;

    const moderationRef = db.collection("moderation_targets").doc(targetKey);

    let adminStatus = "none";
    let caseStatus = "resolved";
    let queueStatus = "closed";

    if (action === "confirm_violation") adminStatus = "confirmed_violation";
    if (action === "clean") adminStatus = "clean";
    if (action === "suspend") adminStatus = "suspended";
    if (action === "restore") adminStatus = "restored";

    await moderationRef.set({
      adminStatus,
      lastAdminAction: {
        action,
        by: request.auth.uid,
        reason: reason || "",
        at: admin.firestore.FieldValue.serverTimestamp(),
        caseId,
      },
      lastCaseId: caseId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await caseRef.set({
      status: caseStatus,
      queueStatus,
      decision: action,
      decisionReason: reason || "",
      assignedAdmin: request.auth.uid,
      closedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    await recalcModerationTarget(type, targetId);
    await recalcModerationCase(type, targetId);
    await syncModerationTargetToContent(type, targetId);

    await db.collection("admin_logs").add({
      action: "case_reviewed",
      entityType: type,
      entityId: targetId,
      performedBy: request.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      reason: reason || "",
      metadata: {
        caseId,
        decision: action,
        targetType: type,
        targetId,
      }
    });

    return { success: true };
  }
);

exports.createComplaint = onCall(
  {
    region: "europe-west3",
  },
  async (request) => {
    const db = admin.firestore();
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "User must be logged in."
      );
    }

    const {
      targetType,
      targetId,
      category,
      title,
      description,
      severity,
      priority,
      reporterSnapshot,
      targetSnapshot,
      attachments
    } = request.data || {};

    if (!targetType || !targetId) {
      throw new HttpsError(
        "invalid-argument",
        "targetType and targetId required."
      );
    }

    if (!category) {
      throw new HttpsError(
        "invalid-argument",
        "category required."
      );
    }

    if (!description || description.length < 5) {
      throw new HttpsError(
        "invalid-argument",
        "description too short."
      );
    }

    // جلوگیری از complaint تکراری
    const duplicateSnapshot = await db
      .collection("complaints")
      .where("createdBy", "==", uid)
      .where("targetId", "==", targetId)
      .where(
        "status",
        "in",
        ["open", "under_review", "waiting_user", "escalated"]
      )
      .limit(1)
      .get();

    if (!duplicateSnapshot.empty) {
      throw new HttpsError(
        "already-exists",
        "You already have an open complaint for this item."
      );
    }

    const complaintRef = db.collection("complaints").doc();

    const now = admin.firestore.FieldValue.serverTimestamp();

    // ایجاد complaint
    await complaintRef.set({
      complaintId: complaintRef.id,
      createdBy: uid,
      createdAt: now,
      updatedAt: now,

      targetType,
      targetId,

      category,
      severity: severity || "medium",
      priority: priority || "normal",

      title: title || "",
      description,

      status: "open",

      assignedAdminId: null,
      assignedAt: null,

      reporterSnapshot: reporterSnapshot || null,
      targetSnapshot: targetSnapshot || null,

      evidenceCount: attachments ? attachments.length : 0,

      messageCount: 1,
      lastMessageAt: now,

      lastAdminActionAt: null,

      resolutionType: null,
      resolutionSummary: null,

      linkedReportIds: [],
      linkedEntityIds: [],

      fraudFlags: [],

      isArchived: false
    });

    // پیام اولیه complaint
    await complaintRef.collection("messages").add({
      senderType: "user",
      senderId: uid,
      text: description,
      attachments: attachments || [],
      createdAt: now,
      isInternalNote: false
    });

    // آمار admin
    await db
      .collection("admin_stats")
      .doc("complaints")
      .set(
        {
          totalOpen: admin.firestore.FieldValue.increment(1),
          complaintsToday: admin.firestore.FieldValue.increment(1),
          lastComplaintAt: now
        },
        { merge: true }
      );

    return {
      success: true,
      complaintId: complaintRef.id
    };
  }
);

exports.reviewComplaint = onCall(async (request) => {
  const db = admin.firestore();
  const adminUid = request.auth?.uid;

  if (!adminUid) {
    throw new HttpsError("unauthenticated", "Admin must be logged in.");
  }

  const {
    complaintId,
    action,
    note,
  } = request.data || {};

  if (!complaintId || !action) {
    throw new HttpsError(
      "invalid-argument",
      "complaintId and action required"
    );
  }

  const complaintRef = db
    .collection("complaints")
    .doc(complaintId);

  const complaintDoc = await complaintRef.get();

  if (!complaintDoc.exists) {
    throw new HttpsError("not-found", "Complaint not found");
  }

  const complaint = complaintDoc.data();

  const now = admin.firestore.FieldValue.serverTimestamp();

  let newStatus = complaint.status;

  if (action === "resolve") {
    newStatus = "resolved";
  }

  if (action === "dismiss") {
    newStatus = "dismissed";
  }

  if (action === "escalate") {
    newStatus = "escalated";
  }

  if (action === "review") {
    newStatus = "under_review";
  }

  await complaintRef.update({
    status: newStatus,
    updatedAt: now,
    lastAdminActionAt: now,
    assignedAdminId: adminUid
  });

  // action log

  await complaintRef
    .collection("actions")
    .add({
      action: action,
      adminId: adminUid,
      note: note || "",
      createdAt: now
    });

  // update stats

  if (action === "resolve") {

    await db
      .collection("admin_stats")
      .doc("complaints")
      .set({
        totalOpen: admin.firestore.FieldValue.increment(-1),
        totalResolved: admin.firestore.FieldValue.increment(1)
      }, { merge: true });

  }

  if (action === "dismiss") {

    await db
      .collection("admin_stats")
      .doc("complaints")
      .set({
        totalOpen: admin.firestore.FieldValue.increment(-1),
        totalDismissed: admin.firestore.FieldValue.increment(1)
      }, { merge: true });

  }

  return {
    success: true,
    newStatus: newStatus
  };

});
exports.updateAdminDashboardStats = onSchedule(
  {
    region: "europe-west3",
    schedule: "every 5 minutes"
  },
  async () => {

    const db = admin.firestore();

    const businesses = await db.collection("businesses").get();

    let approved = 0;
    let rejected = 0;
    let suspended = 0;
    let risk = 0;

    businesses.forEach(doc => {

      const data = doc.data();

      if (data.status === "approved") approved++;
      if (data.status === "rejected") rejected++;
      if (data.status === "suspended") suspended++;

      const flags = data.trust?.riskFlags;

      if (flags && flags.length > 0) risk++;

    });

    await db.collection("admin_stats")
      .doc("dashboard")
      .set({

        businessesTotal: businesses.size,
        businessesApproved: approved,
        businessesRejected: rejected,
        businessesSuspended: suspended,
        riskFlags: risk,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()

      });

  }
);


exports.indexComplaint = onDocumentWritten(
  {
    region: "europe-west3",
    document: "complaints/{complaintId}"
  },
  async (event) => {

    const complaintId = event.params.complaintId;
    const c = event.data?.after?.data();

    if (!c) return;

    const doc = buildSearchDoc({
      entityType: "complaint",
      entityId: complaintId,
      title: `Complaint ${complaintId}`,
      subtitle: `${c.category || ""} ${c.targetType || ""}`,
      status: c.status || "open",
      keywords: [
        c.category,
        c.severity,
        c.targetType
      ],
      extra: {
        targetId: c.targetId
      }
    });

    await upsertIndex(`complaint_${complaintId}`, doc);

  });

exports.updatePlatformMetrics =
  require("./src/admin/updatePlatformMetrics")
    .updatePlatformMetrics;

exports.updateMetrics =
  require("./src/metrics/updateMetrics")
    .updateMetrics;

exports.metricsScheduler =
  require("./src/admin/updatePlatformMetrics")
    .metricsScheduler;

exports.onSubscriptionChanged = revenue.onSubscriptionChanged;
exports.onBusinessChanged = revenue.onBusinessChanged;
exports.reconcileRevenueScheduled = revenue.reconcileRevenueScheduled;
exports.submitUserFeedback =
  require("./src/feedback/submitUserFeedback")
    .submitUserFeedback;

exports.updateFeedbackStatus =
  require("./src/feedback/updateFeedbackStatus")
    .updateFeedbackStatus;

exports.syncPrivacyToDogs = onDocumentUpdated(
  {
    region: "europe-west3",
    document: "users/{uid}",
  },
  async (event) => {
    const uid = event.params.uid;
    const afterData = event.data?.after?.data();

    if (!afterData) return;

    const ownerProfileVisible = afterData.profileVisible ?? true;
    const dogProfileVisible = afterData.dogProfileVisible ?? true;

    const dogsSnap = await admin
      .firestore()
      .collection("dogs")
      .where("ownerId", "==", uid)
      .get();

    if (dogsSnap.empty) {
      console.log(`No dogs found for owner ${uid}`);
      return;
    }

    const batch = admin.firestore().batch();

    dogsSnap.docs.forEach((doc) => {
      batch.set(
        doc.ref,
        {
          ownerProfileVisible,
          dogProfileVisible,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });

    await batch.commit();

    console.log(
      `✅ Synced privacy to ${dogsSnap.size} dog(s) for user ${uid}`
    );
  }
);

exports.generateVetTips = onCall(async (req) => {
  const location = req.data.location;
  const language = req.data.language;

  const prompt = `
  Give 5 short veterinary tips for dog owners.
  Location: ${location}
  Language: ${language}
  Max 10 words each.
  `;

  // call OpenAI / Gemini
});

function computeReviewRank(data) {
  const likes = Number(data.likes || 0);
  const rating = Number(data.rating || 0);

  const stats = data.reviewerStats || {};
  const reviewerScore = Number(stats.trustScore || 0);

  // ⏱ زمان
  const createdAt = data.createdAt?.toMillis?.() || Date.now();
  const ageHours = Math.max(1, (Date.now() - createdAt) / (1000 * 60 * 60));

  // 🔥 1. RECENCY
  const recencyScore = Math.max(0, 5 - ageHours * 0.1);

  // 🔥 2. VELOCITY
  const velocityScore = likes / ageHours;

  // 📝 TEXT QUALITY
  const textLength = data.text?.length || 0;
  const textQualityScore = textLength > 50 ? 2 : 0;

  // 🚨 PENALTY
  let penalty = 0;

  // 🔥 ANTI-SPAM
  if (likes > 50 && ageHours < 1) {
    penalty += 30;
  }

  // 🧠 FINAL SCORE
  const rankScore =
    (likes * 4) +
    (rating * 2) +
    (reviewerScore * 1.5) +
    recencyScore +
    velocityScore +
    textQualityScore -
    penalty;

  return Number(rankScore.toFixed(1));
}

exports.onReviewCreated = onDocumentCreated(
  {
    document: "reviews_test/{reviewId}",
    region: "europe-west3",
  },
  async (event) => {
    const review = event.data.data();
    const rankScore = computeReviewRank(review);

    const vetId = review.vetId;
    const rating = review.rating;

    const ref = admin.firestore().collection("businesses").doc(vetId);

    await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(ref);

      if (!snap.exists) return;

      const data = snap.data();

      let count = data.reviewsCount || 0;
      let avg = data.avgRating || 0;
      let ratingCounts = data.ratingCounts || {};

      // update counts
      ratingCounts[rating] = (ratingCounts[rating] || 0) + 1;

      // update avg
      const newCount = count + 1;
      const newAvg = ((avg * count) + rating) / newCount;

      tx.update(ref, {
        reviewsCount: newCount,
        avgRating: newAvg,
        ratingCounts: ratingCounts,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await event.data.ref.set(
      {
        rankScore,
      },
      { merge: true }
    );
  }
);

exports.updateReviewRank = onDocumentUpdated(
  {
    document: "reviews/{reviewId}",
    region: "europe-west3",
  },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (!after) return null;



    const reviewRef = event.data.after.ref;

    try {
      const stats = after.reviewerStats || {};

      // ✅ TRUST SCORE (stable)
      const trustScore = Number(
        computeTrustScore(stats).toFixed(1)
      );

      // ✅ RANK SCORE
      const computedScore = computeReviewRank({
        ...after,
        reviewerStats: {
          ...stats,
          trustScore,
        },
      });

      const newScore = Number(computedScore.toFixed(1));
      const oldScore = Number((after.rankScore ?? 0).toFixed(1));
      const oldTrust = Number(
        (after.reviewerStats?.trustScore ?? 0).toFixed(1)
      );

      // 🔥 HASH
      const newHash = `${newScore}_${trustScore}`;
      const oldHash = after?.rankingMeta?.hash;

      // 🛑 1. اگر قبلاً همین مقدار ست شده → STOP
      if (newHash === oldHash) {
        console.log("🛑 HARD STOP: same hash");
        return null;
      }

      // 🛑 2. اگر مقدار واقعی تغییری نکرده → STOP
      if (
        newScore === oldScore &&
        trustScore === oldTrust
      ) {
        console.log("🛑 HARD STOP: exact same values");
        return null;
      }

      // ✅ UPDATE
      await reviewRef.update({
        "reviewerStats.trustScore": trustScore,
        rankScore: newScore,
        "rankingMeta.hash": newHash,
        "rankingMeta.lastRankedAt":
          admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log("✅ rankScore updated:", newScore);

    } catch (e) {
      console.error("🔥 ERROR updating rank:", e);
    }

    return null;
  }
);



function computeTrustScore(stats = {}) {
  const reviewsCount = Number(stats.reviewsCount || 0);
  const totalLikes = Number(stats.totalLikes || 0);
  const isVerified = Boolean(stats.isVerified || false);

  let score = 0;

  score += reviewsCount * 2;
  score += totalLikes * 3;
  if (isVerified) score += 10;

  return Number(score.toFixed(1));
}

exports.migrateServices = onRequest(async (req, res) => {
  const db = admin.firestore();

  const businesses = await db.collection("businesses").get();

  for (const doc of businesses.docs) {
    const data = doc.data();

    console.log("Running migration...");
    console.log("Business:", doc.id);

    const services =
      data.sectorData?.veterinary?.services?.offeredServices ||
      data.services?.offeredServices || // 🔥 FIX
      [];

    console.log("Services found:", services);

    if (!Array.isArray(services) || services.length === 0) {
      console.log("❌ No services → skipping");
      continue;
    }

    for (let i = 0; i < services.length; i++) {
      const name = services[i];

      console.log("Creating service:", name);

      await doc.ref.collection("services").add({
        title: name,
        price: 0,
        currency: "TRY",
        durationMin: 30,
        description: "",
        isActive: true,
        sortOrder: i + 1,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  res.send("Migration done");
});


function addHours(date, hours) {
  return new Date(date.getTime() + hours * 60 * 60 * 1000);
}

function getInvoiceUploadDeadline(status = "payment_pending") {
  const now = new Date();

  // فعلاً rule ساده:
  // seller باید بعد از آماده‌سازی / ارسال در بازه مشخص فاکتور را آپلود کند
  // فعلاً برای foundation از payment_pending شروع می‌کنیم
  // بعداً می‌بریم روی shipped / delivered / preparing
  if (status === "payment_pending") {
    return addHours(now, 72); // 72 saat
  }

  return addHours(now, 72);
}

function buildInitialInvoiceObject({
  billingSnapshot,
  sellerSnapshot,
  pricing,
  nowIso,
}) {
  const safeBilling = billingSnapshot || {};
  const safeSeller = sellerSnapshot || {};

  const invoiceType = detectInvoiceType(safeBilling);
  const invoiceSystem = detectInvoiceSystem(invoiceType);

  const validationIssues = validateInvoiceData({
    billingSnapshot: safeBilling,
    sellerSnapshot: safeSeller,
  });

  return {
    status: "pending_upload",

    invoiceType,
    invoiceSystem,

    invoiceNo: null,
    invoiceDate: null,
    invoiceUrl: null,
    invoiceStoragePath: null,

    uploadedAt: null,
    uploadedBy: null,

    uploadDeadlineAt: addHoursToIso(72),

    warnings: 0,
    penaltyPoints: 0,

    validationIssues,

    pricing: pricing || {
      subtotal: 0,
      shippingTotal: 0,
      taxTotal: 0,
      grandTotal: 0,
    },

    billingSnapshot: safeBilling,
    sellerSnapshot: safeSeller,

    createdAt: nowIso,
    updatedAt: nowIso,
  };
}

function buildInitialComplianceObject(nowIso) {
  return {
    invoiceRequired: true,
    invoiceMissing: true,
    invoiceLate: false,
    warningCount: 0,
    penaltyPoints: 0,
    lastWarningAt: null,
    lastCheckedAt: nowIso,
  };
}

async function getCommissionRate(db, businessId) {
  const businessSnap = await db.collection("businesses").doc(businessId).get();

  if (!businessSnap.exists) {
    throw new Error("Business not found");
  }

  const business = businessSnap.data() || {};
  const rawSector =
    business.sector ||
    (Array.isArray(business.sectors) ? business.sectors[0] : null) ||
    "petshop";
  const sector = normalizeSector(rawSector);
  // normalize
  // normalize function بالا اضافه کن (یکبار)
  function normalizeSector(value) {
    if (!value) return "petshop";

    const map = {
      pet_shop: "petshop",
      petshop: "petshop",
      petShop: "petshop",
      PETSHOP: "petshop",
    };

    return map[value] || value;
  }
  logger.info("🧠 COMMISSION SECTOR DEBUG", {
    businessId,
    rawSector,
    finalSector: sector,
  });
  const tier = business.commissionTier || null;

  const configSnap = await db.collection("commission_configs").doc(sector).get();

  if (!configSnap.exists) {
    logger.error("⚠️ COMMISSION CONFIG NOT FOUND", { sector });

    // fallback امن
    return 0.10; // 10%
  }

  const config = configSnap.data();

  // اگر tier داشت
  if (tier && Array.isArray(config.tiers)) {
    const tierConfig = config.tiers.find(t => t.name === tier);
    if (tierConfig) {
      return tierConfig.rate;
    }
  }

  // fallback
  return config.defaultRate || 0;
}
exports.createCheckoutSession = onCall(
  {
    region: "europe-west3",
    memory: "512MiB",
    timeoutSeconds: 60,
    secrets: [IYZICO_API_KEY, IYZICO_SECRET_KEY],
  },

  async (request) => {
    try {
      logger.info("🚨 CREATE CHECKOUT SESSION CALLED");
      const auth = request.auth;
      const data = request.data || {};
      const db = admin.firestore();

      if (!auth?.uid) {
        throw new HttpsError("unauthenticated", "User must be logged in.");
      }

      const rawOrderId = data.orderId ?? data.note;

      if (!rawOrderId || typeof rawOrderId !== "string") {
        throw new HttpsError("invalid-argument", "Missing or invalid orderId");
      }

      const orderId = rawOrderId.trim();
      if (!orderId) {
        throw new HttpsError("invalid-argument", "Missing orderId");
      }

      const orderRef = db.collection("orders").doc(orderId);
      const orderSnap = await orderRef.get();

      if (!orderSnap.exists) {
        throw new HttpsError("not-found", "Order not found");
      }

      const orderData = orderSnap.data() || {};

      const items = Array.isArray(data.items) ? data.items : [];
      const currency = normalizeText(data.currency || "TRY") || "TRY";
      const successUrl = normalizeText(data.successUrl);
      const cancelUrl = normalizeText(data.cancelUrl);

      const buyer = data.buyer || {};
      const shippingAddressInput = data.shippingAddress || {};
      const billingAddressInput = data.billingAddress || {};

      const selectedCarrier = normalizeCarrier(
        data.carrier ||
        data.selectedCarrier ||
        orderData?.shipping?.carrier ||
        ""
      );

      if (items.length === 0) {
        throw new HttpsError("invalid-argument", "Cart is empty.");
      }

      const buyerId = buyer.buyerId || buyer.id || auth.uid;
      const buyerName = normalizeText(buyer.name);
      const buyerSurname = normalizeText(buyer.surname || "User");
      const buyerPhone = normalizeText(buyer.gsmNumber || buyer.phone);
      const buyerEmail = normalizeText(buyer.email);

      const buyerIdentityNumber = normalizeText(
        buyer.identityNumber ||
        billingAddressInput.identityNumber ||
        orderData?.buyer?.identityNumber ||
        orderData?.billing?.identityNumber ||
        ""
      );

      const billingContactName = normalizeText(
        billingAddressInput.contactName ||
        `${buyerName} ${buyerSurname}`
      );

      const billingNameParts = billingContactName.split(" ").filter(Boolean);

      const billingName =
        normalizeText(buyerName) ||
        billingNameParts[0] ||
        "";

      const billingSurname =
        normalizeText(buyerSurname) ||
        billingNameParts.slice(1).join(" ") ||
        "";

      logger.info("🧾 CHECKOUT BUYER DEBUG", {
        orderId,
        buyerRaw: buyer,
        buyerName,
        buyerSurname,
        identityNumber: buyer.identityNumber || null,
      });

      if (!buyerId || !buyerName || !buyerPhone || !buyerEmail) {
        throw new HttpsError("invalid-argument", "Missing buyer info.");
      }

      if (
        !normalizeText(shippingAddressInput.contactName) ||
        !normalizeText(shippingAddressInput.city) ||
        !normalizeText(shippingAddressInput.address)
      ) {
        throw new HttpsError("invalid-argument", "Missing shipping address.");
      }

      if (
        !normalizeText(billingAddressInput.contactName) ||
        !normalizeText(billingAddressInput.city) ||
        !normalizeText(billingAddressInput.address)
      ) {
        throw new HttpsError("invalid-argument", "Missing billing address.");
      }

      const grouped = groupItemsByBusiness(items);
      if (grouped.size === 0) {
        throw new HttpsError(
          "invalid-argument",
          "No valid business groups found."
        );
      }

      let subtotal = 0;
      let shippingTotal = 0;
      let taxTotal = 0;
      let totalCommission = 0;

      const normalizedItems = [];
      const sellerPricingMap = new Map();

      const sellerInvoiceMap = new Map();

      for (const [businessId, sellerItems] of grouped.entries()) {
        logger.info("💸 COMMISSION BLOCK ENTERED", { businessId });
        // 🔥 COMMISSION RATE
        logger.info("🧠 COMMISSION FETCH START", {
          businessId,
        });
        const commissionRate = await getCommissionRate(db, businessId);

        logger.info("💸 COMMISSION RATE", {
          businessId,
          commissionRate,
        });
        const businessSnap = await db.collection("businesses").doc(businessId).get();
        const business = businessSnap.data();

        //const subMerchantKey = business.subMerchantKey;
        const configRef = db.collection("shipping_configs").doc(businessId);

        logger.info("🚚 SHIPPING CONFIG LOOKUP", {
          businessId,
        });

        const configSnap = await configRef.get();

        logger.info("📦 SHIPPING CONFIG RESULT", {
          businessId,
          exists: configSnap.exists,
        });

        if (!configSnap.exists) {
          throw new HttpsError(
            "failed-precondition",
            `Missing shipping config for business ${businessId}`
          );
        }

        const config = configSnap.data() || {};

        let sellerSubtotal = 0;
        let sellerShippingTotal = 0;
        let sellerTaxTotal = 0;
        let sellerCommissionTotal = 0;
        const sellerInvoiceItems = [];
        for (const rawItem of sellerItems) {
          const productId = String(rawItem.productId || "").trim();

          logger.info("🧪 PRODUCT ID CHECK", {
            original: rawItem.productId,
            used: productId,
          });

          const quantity = Math.max(1, asNumber(rawItem.quantity, 1));

          if (!productId) {
            throw new HttpsError("invalid-argument", "Item missing productId");
          }

          logger.info("🔎 PRODUCT FETCH START", {
            businessId,
            productId,
          });

          let productSnap = await db
            .collection("businesses")
            .doc(businessId)
            .collection("products")
            .doc(productId)
            .get();

          let fallbackProductId = null;


          if (!productSnap.exists) {
            throw new HttpsError(
              "not-found",
              `Product not found in business: ${productId}`
            );
          }

          const productData = productSnap.data() || {};

          if (String(productData.businessId || businessId) !== String(businessId)) {
            throw new HttpsError(
              "failed-precondition",
              `Product business mismatch: ${productId}`
            );
          }

          logger.info("✅ PRODUCT FETCH OK", {
            businessId,
            productId,
          });

          const serverUnitPrice = asNumber(
            productData.salePrice || productData.price || rawItem.price,
            0
          );


          if (serverUnitPrice <= 0) {
            throw new HttpsError(
              "failed-precondition",
              `Invalid product price for ${productId}`
            );
          }

          const kdvRate = asNumber(
            productData.kdvRate ?? productData.taxRate ?? rawItem.kdvRate ?? 0,
            0
          );

          const weightKg = asNumber(
            productData.weightKg ?? rawItem.weightKg ?? 0,
            0
          );

          const lengthCm = asNumber(
            productData.lengthCm ?? rawItem.lengthCm ?? 0,
            0
          );

          const widthCm = asNumber(
            productData.widthCm ?? rawItem.widthCm ?? 0,
            0
          );

          const heightCm = asNumber(
            productData.heightCm ?? rawItem.heightCm ?? 0,
            0
          );

          const imageUrl =
            productData.imageUrl ||
            productData.coverImageUrl ||
            (Array.isArray(productData.images) && productData.images.length > 0
              ? productData.images[0]
              : null) ||
            rawItem.imageUrl ||
            null;

          const itemSubtotal = roundMoney(serverUnitPrice * quantity);
          const itemCommission = roundMoney(itemSubtotal * commissionRate);
          sellerCommissionTotal += itemCommission;
          const itemTaxTotal = roundMoney(itemSubtotal * (kdvRate / 100));

          const productName = normalizeText(
            productData.name || rawItem.name || "Product"
          );

          sellerInvoiceItems.push({
            productId,
            productName,
            quantity,
            unitPriceExclTax: serverUnitPrice,
            kdvRate,
            kdvAmount: itemTaxTotal,
            subtotal: itemSubtotal,

            lineTotal: roundMoney(itemSubtotal + itemTaxTotal),
            imageUrl,
          });
          const shippingCalc = calculateShippingForItem({
            item: {
              quantity,
              price: serverUnitPrice,
              weightKg,
              lengthCm,
              widthCm,
              heightCm,
            },
            config,
            selectedCarrier,
          });

          subtotal += itemSubtotal;
          shippingTotal += shippingCalc.shippingFeeTotal;
          taxTotal += itemTaxTotal;
          totalCommission += itemCommission;
          sellerSubtotal += itemSubtotal;
          sellerShippingTotal += shippingCalc.shippingFeeTotal;
          sellerTaxTotal += itemTaxTotal;

          normalizedItems.push({
            productId,
            businessId,
            shopId: businessId,
            name: productName,
            quantity,

            // pricing
            price: serverUnitPrice,
            unitPrice: serverUnitPrice,
            unitPriceExclTax: serverUnitPrice,
            subtotal: itemSubtotal,

            // tax / kdv
            kdvRate,
            kdvAmount: itemTaxTotal,
            taxRate: kdvRate,
            taxTotal: itemTaxTotal,

            // totals
            lineTotal: roundMoney(itemSubtotal + itemTaxTotal),
            shippingFeeTotal: shippingCalc.shippingFeeTotal,

            // shipping snapshot
            carrier: shippingCalc.carrierApplied,
            weightKg,
            lengthCm,
            widthCm,
            heightCm,
            desi: shippingCalc.desi,

            // media snapshot
            imageUrl,

            // invoice snapshot helpers
            invoiceLineSnapshot: {
              productId,
              productName,
              quantity,
              unitPriceExclTax: serverUnitPrice,
              kdvRate,
              kdvAmount: itemTaxTotal,
              subtotal: itemSubtotal,
              lineTotal: roundMoney(itemSubtotal + itemTaxTotal),
            },
          });
        }

        sellerPricingMap.set(businessId, {
          subtotal: roundMoney(sellerSubtotal),
          shippingTotal: roundMoney(sellerShippingTotal),
          taxTotal: roundMoney(sellerTaxTotal),
          grandTotal: roundMoney(
            sellerSubtotal + sellerShippingTotal + sellerTaxTotal
          ),

          // 🔥 NEW
          commissionAmount: roundMoney(sellerCommissionTotal),
        });
        sellerInvoiceMap.set(businessId, {
          items: sellerInvoiceItems,
          pricing: {
            subtotal: roundMoney(sellerSubtotal),
            shippingTotal: roundMoney(sellerShippingTotal),
            taxTotal: roundMoney(sellerTaxTotal),
            grandTotal: roundMoney(
              sellerSubtotal + sellerShippingTotal + sellerTaxTotal
            ),
          },
        });
      }

      subtotal = roundMoney(subtotal);
      shippingTotal = roundMoney(shippingTotal);
      taxTotal = roundMoney(taxTotal);

      const grandTotal = roundMoney(subtotal + shippingTotal + taxTotal);
      const platformNet = roundMoney(totalCommission);

      const iyzi = new Iyzipay({
        apiKey: IYZICO_API_KEY.value(),
        secretKey: IYZICO_SECRET_KEY.value(),
        uri: "https://sandbox-api.iyzipay.com",
      });

      // ✅ STEP 1: تعریف
      const basketItems = [];

      // ✅ STEP 2: ساخت basketItems
      for (const [businessId, sellerPricing] of sellerPricingMap.entries()) {

        const businessSnap = await db
          .collection("businesses")
          .doc(businessId)
          .get();

        const business = businessSnap.data() || {};
        const subMerchantKey = business.subMerchantKey;
        /*
                if (!subMerchantKey) {
                  throw new HttpsError(
                    "failed-precondition",
                    `Missing subMerchantKey for business ${businessId}`
                  );
                }
        */
        const sellerNetAmount = roundMoney(
          sellerPricing.subtotal - sellerPricing.commissionAmount
        );

        logger.info("💰 SPLIT DEBUG", {
          businessId,
          sellerNetAmount,
          commission: sellerPricing.commissionAmount,
        });

        basketItems.push({
          id: `item-${businessId}`,
          name: "Pet Products",
          category1: "Pet",
          itemType: Iyzipay.BASKET_ITEM_TYPE.PHYSICAL,

          price: sellerPricing.subtotal.toFixed(2),

          //subMerchantKey,
          //subMerchantPrice: sellerNetAmount.toFixed(2),
        });
      }

      // 🔥 DEBUG + FIX (خیلی مهم)
      const basketTotal = basketItems.reduce(
        (sum, item) => sum + parseFloat(item.price),
        0
      );

      logger.info("💰 IYZICO CHECK BEFORE REQUEST", {
        basketTotal,
        subtotal,
        shippingTotal,
        taxTotal,
        grandTotal,
      });

      if (Math.abs(basketTotal - subtotal) > 0.01) {
        throw new HttpsError(
          "failed-precondition",
          `Basket total mismatch: basket=${basketTotal} subtotal=${subtotal}`
        );
      }

      const conversationId = orderId;

      const iyziRequest = {
        locale: Iyzipay.LOCALE.TR,
        conversationId,
        price: subtotal.toFixed(2),       // ❗ فقط کالا
        paidPrice: grandTotal.toFixed(2), // ✅ کل پرداخت
        currency: Iyzipay.CURRENCY.TRY,
        basketId: orderId,
        paymentGroup: Iyzipay.PAYMENT_GROUP.PRODUCT,
        callbackUrl: `https://app.petsupo.com/payment-callback?orderId=${orderId}`,

        buyer: {
          id: String(buyerId),
          name: String(buyerName),
          surname: String(buyerSurname),
          gsmNumber: String(buyerPhone),
          email: String(buyerEmail),
          identityNumber: String(buyer.identityNumber || "11111111111"),
          registrationAddress: String(
            buyer.registrationAddress || billingAddressInput.address
          ),
          ip: String(buyer.ip || "85.34.78.112"),
          city: normalizeTurkishText(
            buyer.city || billingAddressInput.city || "Istanbul"
          ),
          country: "Turkey",
        },

        shippingAddress: {
          contactName: String(shippingAddressInput.contactName),
          city: normalizeTurkishText(shippingAddressInput.city),
          address: String(shippingAddressInput.address),
          country: "Turkey",
        },

        billingAddress: {
          contactName: String(billingAddressInput.contactName),
          city: normalizeTurkishText(billingAddressInput.city),
          address: String(billingAddressInput.address),
          country: "Turkey",
        },

        basketItems,
      };

      const iyziResult = await new Promise((resolve, reject) => {
        iyzi.checkoutFormInitialize.create(iyziRequest, (err, result) => {
          if (err) return reject(err);
          return resolve(result);
        });
      });

      if (!iyziResult || iyziResult.status !== "success") {
        await orderRef.update({
          status: "payment_init_failed",
          paymentStatus: "init_failed",
          "payment.status": "init_failed",
          "payment.errorMessage": iyziResult?.errorMessage || null,
          "payment.errorCode": iyziResult?.errorCode || null,
          "payment.provider": "iyzico",
          pricing: {
            subtotal,
            shippingTotal,
            taxTotal,
            grandTotal,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          timeline: admin.firestore.FieldValue.arrayUnion({
            status: "payment_init_failed",
            at: new Date().toISOString(),
            by: "system",
          }),
        });

        throw new HttpsError(
          "internal",
          iyziResult?.errorMessage || "iyzico init failed"
        );
      }

      const checkoutUrl = iyziResult.paymentPageUrl;
      const checkoutToken = iyziResult.token;

      if (!checkoutUrl || !checkoutToken) {
        throw new HttpsError(
          "internal",
          "Missing checkoutUrl or token from iyzico"
        );
      }

      const paymentSuccessCallbackUrl =
        `https://app.petsupo.com/payment-callback?orderId=${orderId}&token=${checkoutToken}`;

      const paymentCancelCallbackUrl =
        `https://app.petsupo.com/payment-cancel?orderId=${orderId}`;

      logger.info("🧾 ROOT ORDER BEFORE SAVE DEBUG", {
        orderId,
        buyerName,
        buyerSurname,
        identityNumber: buyer.identityNumber || null,
        billingAddressInput,
      });
      await orderRef.set(
        {
          status: "payment_pending",
          paymentStatus: "pending",
          currency,
          pricing: {
            subtotal,
            shippingTotal,
            taxTotal,
            grandTotal,
          },
          financial: {
            grossAmount: grandTotal,
            commissionAmount: totalCommission,
            platformNet,
          },
          documents: {
            ...(orderData.documents || {}),
            invoiceStatus: "pending_seller_uploads",
            invoiceRequired: true,
          },
          payment: {
            ...(orderData.payment || {}),
            status: "pending",
            provider: "iyzico",
            conversationId,
            token: checkoutToken,
            checkoutToken,
            checkoutUrl,
            currency,
            successUrlFromClient: paymentSuccessCallbackUrl,
            cancelUrlFromClient: paymentCancelCallbackUrl,
          },
          shipping: {
            ...(orderData.shipping || {}),
            carrier: selectedCarrier || null,
          },
          buyerUid: orderData.buyerUid || auth.uid,
          buyerName: orderData.buyerName || buyerName,
          buyerEmail: orderData.buyerEmail || buyerEmail,
          buyerPhone: orderData.buyerPhone || buyerPhone,
          items: normalizedItems,
          invoiceSummary: {
            sellerInvoiceCountExpected: grouped.size,
            sellerInvoiceCountUploaded: 0,
            status: "pending_seller_uploads",
          },
          // 🔥🔥🔥 ADD THIS
          buyer: {
            name: buyerName,
            surname: buyerSurname,
            email: buyerEmail,
            phone: buyerPhone,
            identityNumber: buyer.identityNumber || null,
            city: buyer.city || null,
          },

          billing: {
            invoiceType: billingAddressInput.invoiceType || "individual",

            name: billingName,
            surname: billingSurname,
            contactName: `${billingName} ${billingSurname}`.trim(),

            identityNumber: buyerIdentityNumber || null,

            city: billingAddressInput.city || null,
            district: billingAddressInput.district || null,
            address: billingAddressInput.address || null,

            companyName: billingAddressInput.companyName || null,
            taxNumber: billingAddressInput.taxNumber || null,
            taxOffice: billingAddressInput.taxOffice || null,
          },
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          timeline: admin.firestore.FieldValue.arrayUnion({
            status: "payment_pending",
            at: new Date().toISOString(),
            by: "system",
          }),
        },
        { merge: true }
      );
      const rootAfterSaveSnap = await orderRef.get();
      logger.info("🧾 ROOT ORDER AFTER SAVE DEBUG", {
        orderId,
        buyer: rootAfterSaveSnap.data()?.buyer || null,
        billing: rootAfterSaveSnap.data()?.billing || null,
        buyerName: rootAfterSaveSnap.data()?.buyerName || null,
        buyerSurname: rootAfterSaveSnap.data()?.buyerSurname || null,
      });

      const sellerOrdersSnap = await db
        .collection("sellerOrders")
        .where("rootOrderId", "==", orderId)
        .get();

      const sellerBatch = db.batch();
      const nowIso = new Date().toISOString();
      for (const doc of sellerOrdersSnap.docs) {
        const sellerData = doc.data() || {};
        const sellerBusinessId = String(
          sellerData.businessId || sellerData.shopId || ""
        ).trim();

        const sellerPricing = sellerPricingMap.get(sellerBusinessId) || {
          subtotal: 0,
          shippingTotal: 0,
          taxTotal: 0,
          grandTotal: 0,
        };
        const sellerInvoiceData = sellerInvoiceMap.get(sellerBusinessId) || {
          items: [],
          pricing: {
            subtotal: 0,
            shippingTotal: 0,
            taxTotal: 0,
            grandTotal: 0,
          },
        };


        const existingShipping = sellerData.shipping || {};

        const freshOrderSnap = await orderRef.get();
        const freshOrderData = freshOrderSnap.data() || {};

        const orderBilling = freshOrderData.billing || {};

        logger.info("🧾 FIXED ORDER BILLING DEBUG", {
          orderBilling,
        });

        logger.info("🧾 SELLER ORDER BILLING SOURCE DEBUG", {
          sellerOrderId: doc.id,
          orderId,
          orderBillingFromOldOrderData: orderBilling,
          buyerName,
          buyerSurname,
          buyerIdentityNumber: buyer.identityNumber || null,
          billingAddressInput,
        });

        const billingSnapshot = {
          invoiceType: orderBilling.invoiceType || "individual",

          name: orderBilling.name || billingName || buyerName,
          surname: orderBilling.surname || billingSurname || buyerSurname,

          contactName:
            orderBilling.contactName ||
            `${orderBilling.name || billingName || buyerName} ${orderBilling.surname || billingSurname || buyerSurname}`.trim(),

          identityNumber:
            orderBilling.identityNumber ||
            buyerIdentityNumber ||
            billingAddressInput.identityNumber ||
            null,

          taxNumber:
            orderBilling.taxNumber ||
            billingAddressInput.taxNumber ||
            null,

          taxOffice:
            orderBilling.taxOffice ||
            billingAddressInput.taxOffice ||
            null,

          companyName:
            orderBilling.companyName ||
            billingAddressInput.companyName ||
            null,

          city: orderBilling.city || billingAddressInput.city || null,
          district: orderBilling.district || billingAddressInput.district || null,
          address: orderBilling.address || billingAddressInput.address || null,
        };

        logger.info("🔥 SELLER ORDER DATA", {
          sellerOrderId: doc.id,
          rootOrderId: orderId,
          billing: billingSnapshot,
        });

        // اگر از قبل snapshot تو sellerOrder ذخیره شده
        let sellerSnapshot = sellerData.sellerSnapshot || null;

        if (!sellerSnapshot) {
          const businessSnap = await db
            .collection("businesses")
            .doc(sellerBusinessId)
            .get();

          const businessData = businessSnap.exists ? businessSnap.data() : {};

          sellerSnapshot = {
            businessId: sellerBusinessId,
            ownerUid: businessData?.ownerUid || null,
            businessName:
              businessData?.profile?.businessName ||
              businessData?.profile?.name ||
              null,
            taxNumber: businessData?.legal?.taxNumber || null,
            mersisNumber: businessData?.legal?.mersisNumber || null,
            city: businessData?.contact?.city || null,
            addressLine: businessData?.contact?.addressLine || null,
          };
        }

        const initialInvoice = buildInitialInvoiceObject({
          billingSnapshot,
          sellerSnapshot,
          pricing: sellerInvoiceData.pricing,
          nowIso,
        });

        const initialCompliance = buildInitialComplianceObject(nowIso);

        const sellerNetAmount = roundMoney(
          sellerPricing.grandTotal - sellerPricing.commissionAmount
        );

        sellerBatch.set(
          doc.ref,
          {
            status: "payment_pending",
            paymentStatus: "pending",
            currency,

            pricing: sellerPricing,

            billing: billingSnapshot,

            invoice: {
              ...initialInvoice,
              items: sellerInvoiceData.items,
            },

            compliance: initialCompliance,

            deadlines: {
              invoiceUploadDeadlineAt: initialInvoice.uploadDeadlineAt,
              lastInvoiceReminderAt: null,
            },

            financial: {
              grossAmount: sellerPricing.grandTotal,
              commissionAmount: sellerPricing.commissionAmount,
              sellerNetAmount,
              platformNet: sellerPricing.commissionAmount,
            },

            payout: {
              status: "payment_pending",
              amount: sellerNetAmount,
              currency,
              requestedAt: null,
              readyAt: null,
              paidAt: null,
              reference: null,
              note: null,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },

            documents: {
              ...(sellerData.documents || {}),
              invoiceStatus: "pending_upload",
              invoiceRequired: true,
            },

            shipping: {
              ...existingShipping,
              carrier: existingShipping.carrier || selectedCarrier || null,
            },

            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        const businessSnap = await db
          .collection("businesses")
          .doc(sellerBusinessId)
          .get();

        const sellerUid = sellerSnapshot?.ownerUid || null;

        if (sellerUid) {
          const notifRef = db.collection("notifications").doc();
          sellerBatch.set(notifRef, {
            recipientUserId: sellerUid,
            type: "new_order",
            title: "New order received 📦",
            body: "A new order is waiting for payment confirmation.",

            /// 🔥 مهم‌ترین بخش
            payload: {
              type: "new_order",
              orderId: orderId,
              sellerOrderId: doc.id,
            },

            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      const buyerUid = orderData.buyerUid || buyer.buyerId || auth.uid;
      if (buyerUid) {
        const notifRef = db.collection("notifications").doc();
        sellerBatch.set(notifRef, {
          recipientUserId: buyerUid,
          type: "order_created",
          title: "Order created 🧾",
          body: "Your order has been created and payment page is ready.",
          orderId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await sellerBatch.commit();

      logger.info("✅ CHECKOUT SESSION CREATED", {
        orderId,
        sellerCount: sellerOrdersSnap.size,
        subtotal,
        shippingTotal,
        taxTotal,
        grandTotal,
        selectedCarrier,
      });

      return {
        success: true,
        provider: "iyzico",
        orderId,
        checkoutUrl,
        token: checkoutToken,

        pricing: {
          subtotal,
          shippingTotal,
          taxTotal,
          grandTotal,
        },

        financial: {
          commissionAmount: totalCommission,
          platformNet,
        }
      };
    } catch (error) {
      logger.error("🔥 FULL ERROR DEBUG", {
        message: error?.message || String(error),
        code: error?.code || null,
        details: error?.details || null,
        stack: error?.stack || null,
        raw: JSON.stringify(error, Object.getOwnPropertyNames(error)),
      });

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        error?.message || "Checkout session failed"
      );
    }
  }
);

exports.markSellerPayoutReady = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request) => {
    const auth = request.auth;

    if (!auth) {
      throw new HttpsError("unauthenticated", "Login required.");
    }

    const uid = auth.uid;
    const data = request.data || {};
    const sellerOrderId = String(data.sellerOrderId || "").trim();

    if (!sellerOrderId) {
      throw new HttpsError("invalid-argument", "sellerOrderId is required.");
    }

    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.data() || {};

    if (userData.role !== "admin") {
      throw new HttpsError("permission-denied", "Admin only.");
    }

    const sellerOrderRef = db.collection("sellerOrders").doc(sellerOrderId);
    const sellerOrderSnap = await sellerOrderRef.get();

    if (!sellerOrderSnap.exists) {
      throw new HttpsError("not-found", "Seller order not found.");
    }

    const sellerOrder = sellerOrderSnap.data() || {};
    const currentPayoutStatus = sellerOrder.payout?.status || "unknown";

    if (currentPayoutStatus === "paid") {
      throw new HttpsError(
        "failed-precondition",
        "This payout is already paid."
      );
    }

    await sellerOrderRef.set(
      {
        "payout.status": "ready",
        "payout.readyAt": admin.firestore.FieldValue.serverTimestamp(),
        "payout.updatedAt": admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      sellerOrderId,
      payoutStatus: "ready",
    };
  }
);

exports.markSellerPayoutPaid = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request) => {
    const auth = request.auth;

    if (!auth) {
      throw new HttpsError("unauthenticated", "Login required.");
    }

    const uid = auth.uid;
    const data = request.data || {};

    const sellerOrderId = String(data.sellerOrderId || "").trim();
    const reference = String(data.reference || "").trim();
    const note = String(data.note || "").trim();

    if (!sellerOrderId) {
      throw new HttpsError("invalid-argument", "sellerOrderId is required.");
    }

    if (!reference) {
      throw new HttpsError(
        "invalid-argument",
        "Bank transfer reference is required."
      );
    }

    const userSnap = await db.collection("users").doc(uid).get();
    const userData = userSnap.data() || {};

    if (userData.role !== "admin") {
      throw new HttpsError("permission-denied", "Admin only.");
    }

    const sellerOrderRef = db.collection("sellerOrders").doc(sellerOrderId);
    const sellerOrderSnap = await sellerOrderRef.get();

    if (!sellerOrderSnap.exists) {
      throw new HttpsError("not-found", "Seller order not found.");
    }

    const sellerOrder = sellerOrderSnap.data() || {};
    const payoutStatus = sellerOrder.payout?.status || "unknown";

    if (payoutStatus === "paid") {
      throw new HttpsError(
        "failed-precondition",
        "This payout is already paid."
      );
    }

    await sellerOrderRef.set(
      {
        "payout.status": "paid",
        "payout.paidAt": admin.firestore.FieldValue.serverTimestamp(),
        "payout.reference": reference,
        "payout.note": note || null,
        "payout.updatedAt": admin.firestore.FieldValue.serverTimestamp(),

        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      success: true,
      sellerOrderId,
      payoutStatus: "paid",
      reference,
    };
  }
);

exports.verifyPaymentByOrderId = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 60,
    memory: "512MiB",
    secrets: [IYZICO_API_KEY, IYZICO_SECRET_KEY],
  },
  async (request) => {
    try {
      const auth = request.auth;
      if (!auth?.uid) {
        throw new HttpsError("unauthenticated", "Login required.");
      }

      const { orderId } = request.data || {};
      const safeOrderId = normalizeText(orderId);

      logger.info("🔥 VERIFY ORDER ID BACKEND", {
        orderId: safeOrderId,
      });

      if (!safeOrderId) {
        throw new HttpsError("invalid-argument", "Missing orderId");
      }

      const db = admin.firestore();
      const now = admin.firestore.FieldValue.serverTimestamp();
      const sampleOrders = await db.collection("orders").limit(5).get();

      logger.info("📦 SAMPLE ORDER IDS", {
        ids: sampleOrders.docs.map(d => d.id),
      });
      const orderRef = db.collection("orders").doc(safeOrderId);
      const orderSnap = await orderRef.get();

      if (!orderSnap.exists) {
        throw new HttpsError("not-found", "Order not found");
      }

      const orderData = orderSnap.data() || {};
      const paymentToken = orderData?.payment?.token || null;

      if (!paymentToken) {
        throw new HttpsError("failed-precondition", "Missing payment token in order");
      }

      // idempotent
      if (
        normalizeLower(orderData.status) === "paid" ||
        normalizeLower(orderData?.payment?.status) === "paid" ||
        normalizeLower(orderData?.payment?.status) === "success"
      ) {
        return {
          success: true,
          alreadyProcessed: true,
          orderId: safeOrderId,
          paymentId: orderData?.payment?.paymentId || null,
          sellerOrderIds: Array.isArray(orderData?.sellerOrderIds)
            ? orderData.sellerOrderIds
            : [],
        };
      }

      const iyzi = new Iyzipay({
        apiKey: IYZICO_API_KEY.value(),
        secretKey: IYZICO_SECRET_KEY.value(),
        uri: "https://sandbox-api.iyzipay.com",
      });

      const result = await new Promise((resolve, reject) => {
        iyzi.checkoutForm.retrieve(
          {
            locale: Iyzipay.LOCALE.TR,
            token: paymentToken,
          },
          (err, res) => {
            if (err) return reject(err);
            return resolve(res);
          }
        );
      });

      logger.info("💰 VERIFY RESULT", {
        orderId: safeOrderId,
        paymentStatus: result?.paymentStatus || null,
        status: result?.status || null,
        paymentId: result?.paymentId || null,
      });

      const sellerOrdersSnap = await db
        .collection("sellerOrders")
        .where("rootOrderId", "==", safeOrderId)
        .get();

      const sellerOrderIds = sellerOrdersSnap.docs.map((d) => d.id);

      const hardFailure =
        !result ||
        normalizeLower(result?.status) === "failure" ||
        normalizeLower(result?.paymentStatus) === "failure";

      const success =
        normalizeLower(result?.status) === "success" &&
        normalizeLower(result?.paymentStatus) === "success";

      // -------------------------
      // HARD FAILURE
      // -------------------------
      if (hardFailure) {
        const batch = db.batch();

        batch.set(
          orderRef,
          {
            status: "payment_failed",
            paymentStatus: "failed",
            payment: {
              ...(orderData.payment || {}),
              status: "failed",
              provider: "iyzico",
              errorMessage: result?.errorMessage || null,
              errorCode: result?.errorCode || null,
              raw: result || null,
            },
            updatedAt: now,
            timeline: admin.firestore.FieldValue.arrayUnion({
              status: "payment_failed",
              at: new Date().toISOString(),
              by: "system",
            }),
          },
          { merge: true }
        );

        for (const doc of sellerOrdersSnap.docs) {
          batch.set(
            doc.ref,
            {
              status: "failed",
              paymentStatus: "failed",
              payment: {
                ...(doc.data()?.payment || {}),
                status: "failed",
                provider: "iyzico",
                errorMessage: result?.errorMessage || null,
                errorCode: result?.errorCode || null,
              },
              updatedAt: now,
              timeline: admin.firestore.FieldValue.arrayUnion({
                status: "payment_failed",
                at: new Date().toISOString(),
                by: "system",
              }),
            },
            { merge: true }
          );
        }

        await batch.commit();

        throw new HttpsError(
          "failed-precondition",
          result?.errorMessage || "Payment failed"
        );
      }

      // -------------------------
      // STILL PENDING
      // -------------------------
      if (!success) {
        await orderRef.set(
          {
            status: "payment_pending",
            paymentStatus: "pending",
            payment: {
              ...(orderData.payment || {}),
              status: "pending",
              provider: "iyzico",
              raw: result || null,
            },
            updatedAt: now,
          },
          { merge: true }
        );

        return {
          success: false,
          pending: true,
          orderId: safeOrderId,
          paymentId: result?.paymentId || null,
          sellerOrderIds,
        };
      }

      // -------------------------
      // SUCCESS
      // -------------------------
      const batch = db.batch();

      batch.set(
        orderRef,
        {
          status: "paid",
          paymentStatus: "paid",
          paidAt: now,
          cartCleared: true,
          payment: {
            ...(orderData.payment || {}),
            status: "paid",
            provider: "iyzico",
            paymentId: result?.paymentId || null,
            conversationId: result?.conversationId || null,
            paidPrice: asNumber(result?.paidPrice, 0),
            price: asNumber(result?.price, 0),
            currency: result?.currency || orderData?.currency || "TRY",
            installment: asNumber(result?.installment, 1),
            raw: result,
          },
          updatedAt: now,
          timeline: admin.firestore.FieldValue.arrayUnion({
            status: "paid",
            at: new Date().toISOString(),
            by: "system",
          }),
        },
        { merge: true }
      );

      const sellerBusinessIds = new Set();

      for (const doc of sellerOrdersSnap.docs) {
        const sellerOrder = doc.data() || {};
        const businessId = sellerOrder.businessId || sellerOrder.shopId || null;
        if (businessId) sellerBusinessIds.add(String(businessId));

        batch.set(
          doc.ref,
          {
            status: "paid",
            paymentStatus: "paid",
            paidAt: now,
            payment: {
              ...(sellerOrder.payment || {}),
              status: "paid",
              provider: "iyzico",
              paymentId: result?.paymentId || null,
              conversationId: result?.conversationId || null,
              paidPrice: asNumber(result?.paidPrice, 0),
              price: asNumber(result?.price, 0),
              currency: result?.currency || sellerOrder?.currency || "TRY",
              installment: asNumber(result?.installment, 1),
            },
            updatedAt: now,
            timeline: admin.firestore.FieldValue.arrayUnion({
              status: "paid",
              at: new Date().toISOString(),
              by: "system",
            }),
          },
          { merge: true }
        );
      }

      await batch.commit();

      const buyerUid = orderData.buyerUid || orderData.userId || auth.uid;

      if (buyerUid) {
        await createNotification(db, {
          recipientUserId: buyerUid,
          userId: buyerUid,
          type: "order_paid",
          title: "Order confirmed 🎉",
          body: "Your order has been successfully placed.",
          orderId: safeOrderId,
        });
      }

      for (const businessId of sellerBusinessIds) {
        const businessSnap = await db.collection("businesses").doc(businessId).get();
        const ownerUid = businessSnap.exists
          ? businessSnap.data()?.ownerUid || null
          : null;

        if (ownerUid) {
          await createNotification(db, {
            recipientUserId: ownerUid,
            userId: ownerUid,
            type: "new_paid_order",
            title: "New paid order 🛒",
            body: "A customer has completed payment for a new order.",
            orderId: safeOrderId,
          });
        }
      }

      for (const doc of sellerOrdersSnap.docs) {
        const sellerOrderId = doc.id;
        const sellerData = doc.data() || {};
        const businessId = sellerData.businessId || sellerData.shopId || null;

        const businessSnap = await db.collection("businesses").doc(businessId).get();
        const ownerUid = businessSnap.exists
          ? businessSnap.data()?.ownerUid || null
          : null;

        if (ownerUid) {
          await createNotification(db, {
            recipientUserId: ownerUid,
            userId: ownerUid,
            type: "new_paid_order",
            title: "New paid order 🛒",
            body: "A customer has completed payment for a new order.",

            orderId: safeOrderId,
            sellerOrderId: sellerOrderId, // ✅🔥 این خط کل داستانه

            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      return {
        success: true,
        orderId: safeOrderId,
        paymentId: result?.paymentId || null,
        sellerOrderIds,
      };
    } catch (error) {
      logger.error("❌ verifyPaymentByOrderId ERROR", {
        message: error?.message || String(error),
        stack: error?.stack || null,
      });

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError("internal", error?.message || "Verify failed");
    }
  }
);
exports.verifyPayment = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 60,
    memory: "256MiB",
    secrets: [IYZICO_API_KEY, IYZICO_SECRET_KEY],
  },
  async (request) => {
    try {
      const auth = request.auth;
      if (!auth?.uid) {
        throw new HttpsError("unauthenticated", "Login required.");
      }

      const { orderId } = request.data || {};
      if (!orderId) {
        throw new HttpsError("invalid-argument", "Missing orderId");
      }

      const db = admin.firestore();
      const orderRef = db.collection("orders").doc(orderId);
      const orderSnap = await orderRef.get();

      if (!orderSnap.exists) {
        throw new HttpsError("not-found", "Order not found");
      }

      const orderData = orderSnap.data() || {};
      const token = orderData.payment?.checkoutToken;

      if (!token) {
        throw new HttpsError(
          "failed-precondition",
          "Missing payment token in order"
        );
      }

      // =========================
      // 💳 VERIFY WITH IYZICO
      // =========================
      const iyzi = new Iyzipay({
        apiKey: IYZICO_API_KEY.value(),
        secretKey: IYZICO_SECRET_KEY.value(),
        uri: "https://sandbox-api.iyzipay.com",
      });

      const result = await new Promise((resolve, reject) => {
        iyzi.checkoutForm.retrieve({ token }, (err, res) => {
          if (err) return reject(err);
          return resolve(res);
        });
      });

      if (!result || result.status !== "success") {
        throw new HttpsError(
          "failed-precondition",
          "Payment not successful"
        );
      }

      // 🔁 جلوگیری از دوباره پرداخت
      if (orderData.payment?.status === "paid") {
        return {
          success: true,
          alreadyPaid: true,
          sellerOrderIds: orderData.sellerOrderIds || [],
        };
      }

      // =========================
      // ✅ UPDATE ORDER
      // =========================
      await orderRef.update({
        "payment.status": "paid",
        paymentStatus: "paid",
        status: "paid",
        "payment.paymentId": result.paymentId || null,
        "payment.paidPrice": result.paidPrice || null,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // =========================
      // 🔥 UPDATE APPOINTMENT + NOTIF + FCM
      // =========================
      if (orderData.type === "appointment") {
        const appointmentId = orderData.appointmentId;

        if (appointmentId) {
          const appointmentRef = db
            .collection("vet_appointments")
            .doc(appointmentId);

          const appointmentSnap = await appointmentRef.get();
          const appointmentData = appointmentSnap.exists
            ? appointmentSnap.data() || {}
            : {};

          await appointmentRef.update({
            paymentStatus: "paid",
            status: "confirmed_paid",
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // 🎯 پیدا کردن گیرنده (vet)
          const recipientUserId =
            orderData.businessId ||
            appointmentData.businessId ||
            appointmentData.vetId ||
            null;

          logger.info("🐾 Appointment marked as PAID", {
            appointmentId,
            recipientUserId,
          });

          if (recipientUserId) {
            // =========================
            // 🟣 1. SAVE IN-APP NOTIFICATION
            // =========================
            await db.collection("notifications").add({
              type: "appointment_paid",
              recipientUserId: recipientUserId,
              senderUserId: auth.uid,
              title: "Payment Completed",
              body: `${appointmentData.petName ||
                appointmentData.dogName ||
                "Appointment"
                } payment completed successfully`,
              appointmentId: appointmentId,
              orderId: orderId,
              isRead: false,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // =========================
            // 🔔 2. SEND PUSH (FCM)
            // =========================
            const userSnap = await db
              .collection("users")
              .doc(recipientUserId)
              .get();

            const fcmToken = userSnap.data()?.fcmToken;

            if (fcmToken) {
              await admin.messaging().send({
                token: fcmToken,
                notification: {
                  title: "Payment Completed",
                  body: "Appointment has been paid",
                },
                data: {
                  type: "appointment_paid",
                  appointmentId: appointmentId,
                },
              });

              logger.info("🔔 FCM sent", {
                recipientUserId,
                appointmentId,
              });
            } else {
              logger.warn("⚠️ No FCM token found", {
                recipientUserId,
              });
            }
          } else {
            logger.warn("⚠️ No recipientUserId", {
              appointmentId,
            });
          }
        }
      }

      // =========================
      // 💰 SELLER ORDERS UPDATE
      // =========================
      const sellerOrdersSnap = await db
        .collection("sellerOrders")
        .where("rootOrderId", "==", orderId)
        .get();

      const batch = db.batch();
      const sellerOrderIds = [];

      for (const doc of sellerOrdersSnap.docs) {
        const data = doc.data() || {};
        sellerOrderIds.push(doc.id);

        const sellerNetAmount =
          data.financial?.sellerNetAmount ?? null;

        batch.update(doc.ref, {
          status: "paid",
          paymentStatus: "paid",
          "payout.status": "pending",
          "payout.amount": sellerNetAmount,
          "payout.requestedAt":
            admin.firestore.FieldValue.serverTimestamp(),
          "payout.updatedAt":
            admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      return {
        success: true,
        sellerOrderIds,
      };
    } catch (error) {
      logger.error("❌ verifyPayment ERROR", {
        message: error?.message || String(error),
        stack: error?.stack || null,
      });

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        "internal",
        error?.message || "Verify failed"
      );
    }
  }
);

exports.reminderAppointments = onSchedule(
  "every 5 minutes",
  async () => {

    const now = admin.firestore.Timestamp.now();
    const twoHoursLater = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 2 * 60 * 60 * 1000
    );

    const snap = await admin.firestore()
      .collection("vet_appointments")
      .where("scheduledAt", "<=", twoHoursLater)
      .where("scheduledAt", ">", now)
      .where("status", "in", ["confirmed", "confirmed_paid"])
      .get();

    for (const doc of snap.docs) {
      const data = doc.data();

      // جلوگیری از دوباره ارسال
      if (data.reminderSent) continue;

      const userId = data.userId;

      const userSnap = await admin.firestore()
        .collection("users")
        .doc(userId)
        .get();

      const fcmToken = userSnap.data()?.fcmToken;

      if (fcmToken) {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "Reminder ⏰",
            body: "You have an appointment in 2 hours",
          },
          data: {
            type: "appointment_reminder",
            appointmentId: doc.id,
          },
        });
      }

      await doc.ref.update({
        reminderSent: true,
      });
    }
  }
);

exports.createSubMerchant = onCall(
  { region: "europe-west3" },
  async (request) => {
    const data = request.data;
    const db = admin.firestore();

    const businessId = data.businessId;

    // 🔥 بیزینس رو بگیر
    const businessSnap = await db.collection("businesses").doc(businessId).get();

    if (!businessSnap.exists) {
      throw new Error("Business not found");
    }

    const business = businessSnap.data();

    // 🔴 TODO: اتصال به iyzico API
    // فعلاً mock می‌زنیم

    const fakeSubMerchantKey = "sub_" + businessId;

    // 🔥 ذخیره
    await db.collection("businesses").doc(businessId).update({
      subMerchantKey: fakeSubMerchantKey,
    });

    return {
      success: true,
      subMerchantKey: fakeSubMerchantKey,
    };
  }
);

exports.migrateServices = onRequest(async (req, res) => {
  const db = admin.firestore();

  let updatedCount = 0;

  try {
    const businesses = await db.collection("businesses").get();

    for (const business of businesses.docs) {
      const servicesRef = db
        .collection("businesses")
        .doc(business.id)
        .collection("services");

      const services = await servicesRef.get();

      for (const service of services.docs) {
        const data = service.data();

        const updates = {};

        // ✅ ensure deposit fields exist (for backward compatibility)
        if (data.requiresDeposit === undefined) {
          updates.requiresDeposit = false;
        }

        if (data.depositAmount === undefined) {
          updates.depositAmount = 0;
        }

        // ✅ ensure category exists
        if (!data.category) {
          updates.category = "general";
        }

        if (Object.keys(updates).length > 0) {
          await service.ref.update(updates);
          updatedCount++;

          console.log(`✅ Updated service: ${service.id}`, updates);
        }
      }
    }

    res.send(`🔥 Migration DONE. Updated ${updatedCount} services.`);
  } catch (e) {
    console.error("❌ Migration error:", e);
    res.status(500).send("Migration failed");
  }
});



exports.processProductVideo = onObjectFinalized(
  {
    region: "europe-west3",
    memory: "2GiB",
    timeoutSeconds: 120,
  },
  async (event) => {
    console.log("🔥 FUNCTION STARTED");

    try {
      const object = event.data;

      if (!object) {
        console.log("❌ NO OBJECT DATA");
        return null;
      }

      const filePath = object.name || "";
      const bucketName = object.bucket || "";

      console.log("📁 FILE PATH:", filePath);

      // فقط فایل raw
      if (!filePath.startsWith("products_raw/")) {
        console.log("⏭ SKIPPED (not raw):", filePath);
        return null;
      }

      const lower = filePath.toLowerCase();

      const isVideo =
        lower.endsWith(".mp4") ||
        lower.endsWith(".mov") ||
        lower.endsWith(".hevc") ||
        lower.endsWith(".webm") ||
        lower.endsWith(".m4v");

      if (!isVideo) {
        console.log("⏭ SKIPPED (not video):", filePath);
        return null;
      }

      console.log("🎬 Processing video:", filePath);

      const bucket = admin.storage().bucket(bucketName);
      const fileName = path.basename(filePath);
      const parts = filePath.split("/");
      const businessId = parts.length > 1 ? parts[1] : null;

      if (!businessId) {
        console.log("❌ INVALID BUSINESS ID");
        return null;
      }

      const tempInput = path.join(os.tmpdir(), fileName);
      const outputMp4 = path.join(os.tmpdir(), `${fileName}.mp4`);

      const processedPath = `products_processed/${businessId}/${fileName}.mp4`;
      const thumbPath = `products_thumbs/${businessId}/${fileName}.jpg`;

      await bucket.file(filePath).download({ destination: tempInput });

      let processedUrl = null;
      let thumbUrl = null;

      const buildUrl = async (storagePath, contentType) => {
        const token = crypto.randomUUID();

        await bucket.file(storagePath).setMetadata({
          contentType,
          metadata: {
            firebaseStorageDownloadTokens: token,
          },
        });

        return `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(
          storagePath
        )}?alt=media&token=${token}`;
      };

      // ================= VIDEO CONVERT =================
      try {
        await new Promise((resolve, reject) => {
          ffmpeg(tempInput)
            .outputOptions([
              "-vf scale=720:-2",
              "-c:v libx264",
              "-preset veryfast",
              "-crf 28",
              "-pix_fmt yuv420p",
              "-movflags +faststart",
              "-c:a aac",
              "-b:a 96k",
            ])
            .save(outputMp4)
            .on("end", resolve)
            .on("error", reject);
        });

        await bucket.upload(outputMp4, {
          destination: processedPath,
          metadata: { contentType: "video/mp4" },
        });

        processedUrl = await buildUrl(processedPath, "video/mp4");

        console.log("✅ Video converted");
      } catch (e) {
        console.log("⚠️ FALLBACK RAW VIDEO", e);

        processedUrl = await buildUrl(
          filePath,
          object.contentType || "video/mp4"
        );
      }

      // ================= THUMBNAIL =================
      try {
        const tempThumb = path.join(os.tmpdir(), `${fileName}_thumb.jpg`);

        await new Promise((resolve, reject) => {
          ffmpeg(tempInput)
            .outputOptions([
              "-ss 00:00:00.5",
              "-vframes 1",
              "-vf scale=320:-1",
            ])
            .output(tempThumb)
            .on("end", resolve)
            .on("error", reject)
            .run();
        });

        await bucket.upload(tempThumb, {
          destination: thumbPath,
          metadata: { contentType: "image/jpeg" },
        });

        thumbUrl = await buildUrl(thumbPath, "image/jpeg");

        console.log("🖼 THUMB CREATED");
      } catch (e) {
        console.log("⚠️ THUMB FAILED", e);
        thumbUrl = null;
      }

      // ================= FIRESTORE UPDATE =================
      const db = admin.firestore();

      const snap = await db
        .collection("products")
        .where("businessId", "==", businessId)
        .get();

      const batch = db.batch();

      snap.forEach((doc) => {
        const data = doc.data();
        const media = Array.isArray(data.media) ? data.media : [];

        let changed = false;

        const updated = media.map((m) => {
          if (
            m.type === "video" &&
            (m.status === "processing" || !m.thumbnailUrl)
          ) {
            changed = true;

            return {
              ...m,
              playbackUrl: processedUrl,
              thumbnailUrl: thumbUrl,
              status: "ready",
            };
          }

          return m;
        });

        if (changed) {
          batch.update(doc.ref, { media: updated });
        }
      });

      await batch.commit();

      console.log("🔥 FIRESTORE UPDATED");

      // ================= CLEANUP =================
      [tempInput, outputMp4].forEach((p) => {
        try {
          if (fs.existsSync(p)) fs.unlinkSync(p);
        } catch (_) { }
      });

      console.log("✅ FUNCTION DONE");

      return null;
    } catch (err) {
      console.error("💥 FATAL ERROR:", err);
      return null;
    }
  }
);



exports.saveGlobalProduct = require("./globalProducts/saveGlobalProduct")
  .saveGlobalProduct;

exports.createProduct = onCall(async (request) => {
  const data = request.data;

  const sku = data.sku;
  const businessId = data.businessId;

  if (!sku || !businessId) {
    throw new HttpsError("invalid-argument", "Missing SKU or businessId");
  }

  // ✅ FIXED
  const docId = `${businessId}_${sku}`;

  const db = admin.firestore();
  const ref = db.collection("products").doc(docId);

  await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);

    if (doc.exists) {
      throw new HttpsError("already-exists", "SKU already exists");
    }

    tx.set(ref, {
      ...data,
      id: docId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

exports.updateGlobalStats = onDocumentWritten("products/{id}", async (event) => {
  const data = event.data.after.data();
  if (!data.barcode) return;

  const db = admin.firestore();

  const snapshot = await db
    .collection("products")
    .where("barcode", "==", data.barcode)
    .get();

  const prices = snapshot.docs.map(d => d.data().price || 0);

  const avg = prices.reduce((a, b) => a + b, 0) / prices.length;

  await db.collection("global_products")
    .doc(data.barcode)
    .set({
      avgPrice: avg,
      sellerCount: prices.length,
      trendingScore: prices.length * 10,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
});



exports.aggregateProductPrices = onDocumentWritten(
  "businesses/{businessId}/products/{productId}",
  async (event) => {
    const after = event.data?.after?.data();

    if (!after) return;

    const barcode = after.barcode;
    const db = admin.firestore();

    if (!barcode) return;

    try {
      // 🔥 collect ALL products from ALL businesses
      const snapshot = await db

        .collectionGroup("products")
        .where("barcode", "==", barcode)
        .get();
      logger.info("⚡ RUNNING COLLECTION GROUP QUERY", {
        productId,
        query: "products.productId == value",
      });
      if (snapshot.empty) return;

      const prices = [];

      snapshot.forEach((doc) => {
        const p = doc.data().price;
        if (p && p > 0) prices.push(p);
      });

      if (prices.length === 0) return;

      prices.sort((a, b) => a - b);

      const sum = prices.reduce((a, b) => a + b, 0);
      const avg = sum / prices.length;

      let median;
      if (prices.length % 2 === 1) {
        median = prices[Math.floor(prices.length / 2)];
      } else {
        const mid = prices.length / 2;
        median = (prices[mid - 1] + prices[mid]) / 2;
      }

      const best = prices[0];
      const max = prices[prices.length - 1];

      await db
        .collection("global_product_aggregates")
        .doc(barcode)
        .set(
          {
            avgPrice: avg,
            medianPrice: median,
            bestPrice: best,
            maxPrice: max,
            sellerCount: prices.length,
            lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

      console.log(`✅ AGGREGATED: ${barcode}`);
    } catch (e) {
      console.error("❌ Aggregation error:", e);
    }
  }
);

function buildTrackingUrl(carrier, code) {
  if (!carrier || !code) return "";

  const c = carrier
    .toLowerCase()
    .replaceAll("ı", "i")
    .replaceAll("ç", "c");

  if (c.includes("yurtici"))
    return `https://www.yurticikargo.com/tr/online-servisler/gonderi-sorgula?code=${code}`;

  if (c.includes("aras"))
    return `https://kargotakip.araskargo.com.tr/mainpage.aspx?code=${code}`;

  return "";
}

exports.updateOrderStatus = onCall(
  { region: "europe-west3" },
  async (request) => {
    try {
      const { orderId, status, trackingNumber } = request.data || {};

      if (!orderId || !status) {
        throw new HttpsError("invalid-argument", "Missing orderId or status");
      }

      if (!request.auth?.uid) {
        throw new HttpsError("unauthenticated", "User not logged in");
      }

      const db = admin.firestore();

      // ======================
      // 🔎 GET sellerOrder
      // ======================
      const sellerOrderRef = db.collection("sellerOrders").doc(orderId);
      const sellerSnap = await sellerOrderRef.get();

      if (!sellerSnap.exists) {
        throw new HttpsError("not-found", "Seller order not found");
      }

      const sellerOrder = sellerSnap.data();

      // ======================
      // 🔒 SECURITY
      // ======================
      if (request.auth.uid !== sellerOrder.shopId) {
        throw new HttpsError("permission-denied", "Only seller can update");
      }

      // ======================
      // 🧠 GET SHIPPING FROM ROOT ORDER
      // ======================
      let carrier = sellerOrder?.shipping?.carrier || null;

      if (!carrier && sellerOrder.rootOrderId) {
        const rootSnap = await db
          .collection("orders")
          .doc(sellerOrder.rootOrderId)
          .get();

        if (rootSnap.exists) {
          carrier = rootSnap.data()?.shipping?.carrier || null;
        }
      }

      // ======================
      // 🚚 TRACKING URL
      // ======================
      const buildTrackingUrl = (carrier, code) => {
        if (!carrier || !code) return null;

        const c = carrier.toLowerCase();

        if (c.includes("aras"))
          return `https://kargotakip.araskargo.com.tr/mainpage.aspx?code=${code}`;

        if (c.includes("yurtici"))
          return `https://www.yurticikargo.com/tr/online-servisler/gonderi-sorgula?code=${code}`;

        if (c.includes("mng"))
          return `https://www.mngkargo.com.tr/gonderi-takip?code=${code}`;

        if (c.includes("ptt"))
          return `https://gonderitakip.ptt.gov.tr/Track/Verify?q=${code}`;

        if (c.includes("hepsijet"))
          return `https://www.hepsijet.com/gonderi-takibi/${code}`;

        if (c.includes("sendeo"))
          return `https://sendeo.com.tr/tracking/${code}`;

        if (c.includes("dhl"))
          return `https://www.dhl.com/global-en/home/tracking.html?tracking-id=${code}`;

        return null;
      };

      // ======================
      // 🧾 UPDATE sellerOrder
      // ======================
      const updateData = {
        status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (status === "shipped") {
        if (!trackingNumber) {
          throw new HttpsError("invalid-argument", "Tracking number required");
        }

        if (!carrier) {
          throw new HttpsError("failed-precondition", "Carrier missing from order");
        }

        updateData.shipping = {
          ...(sellerOrder.shipping || {}),
          carrier,
          trackingNumber,
          trackingUrl: buildTrackingUrl(carrier, trackingNumber),
          shippedAt: admin.firestore.FieldValue.serverTimestamp(),
          deliveredAt: null,
        };
      }

      if (status === "delivered") {
        updateData["shipping.deliveredAt"] =
          admin.firestore.FieldValue.serverTimestamp();
      }

      await sellerOrderRef.set(updateData, { merge: true });

      // ======================
      // 📜 TIMELINE
      // ======================
      await sellerOrderRef.update({
        timeline: admin.firestore.FieldValue.arrayUnion({
          status,
          at: new Date().toISOString(),
        }),
      });

      // ======================
      // 🔄 ROOT ORDER STATUS (SMART)
      // ======================
      if (sellerOrder.rootOrderId) {
        const siblings = await db
          .collection("sellerOrders")
          .where("rootOrderId", "==", sellerOrder.rootOrderId)
          .get();

        const statuses = siblings.docs.map((d) => {
          if (d.id === orderId) return status;
          return d.data().status;
        });

        let rootStatus = "paid";

        if (statuses.every((s) => s === "delivered")) {
          rootStatus = "delivered";
        } else if (statuses.some((s) => s === "shipped")) {
          rootStatus = "partially_shipped";
        } else if (statuses.some((s) => s === "preparing")) {
          rootStatus = "preparing";
        } else if (statuses.some((s) => s === "confirmed")) {
          rootStatus = "confirmed";
        }

        await db
          .collection("orders")
          .doc(sellerOrder.rootOrderId)
          .update({
            status: rootStatus,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
      }

      // ======================
      // 🔔 NOTIFICATION
      // ======================
      const buyerUid = sellerOrder.buyerUid || sellerOrder.userId;

      if (buyerUid) {
        await db.collection("notifications").add({
          recipientUserId: buyerUid,
          type: "order_update",
          title: "Order update 📦",
          body: `Your order is now ${status}`,
          orderId: sellerOrder.rootOrderId || orderId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      return { success: true };

    } catch (error) {
      console.error("❌ updateOrderStatus ERROR:", error);

      throw new HttpsError(
        "internal",
        error.message || "Update failed"
      );
    }
  }
);


exports.deleteUserAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "User must be logged in"
    );
  }

  const uid = request.auth.uid;
  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  try {
    // --------------------------------------------------
    // 1) delete dogs owned by user
    // --------------------------------------------------
    const dogsSnap = await db
      .collection("dogs")
      .where("ownerId", "==", uid)
      .get();

    for (const doc of dogsSnap.docs) {
      const dogId = doc.id;

      // delete dog image files if they are inside your bucket
      const data = doc.data() || {};
      const imagePaths = Array.isArray(data.imagePaths) ? data.imagePaths : [];

      for (const url of imagePaths) {
        try {
          const filePath = extractStoragePathFromUrl(url);
          if (filePath) {
            await bucket.file(filePath).delete({ ignoreNotFound: true });
          }
        } catch (e) {
          logger.warn("Failed deleting dog image", { uid, dogId, url, error: String(e) });
        }
      }

      await db.collection("dogs").doc(dogId).delete();
    }

    // --------------------------------------------------
    // 2) delete user document
    // --------------------------------------------------
    await db.collection("users").doc(uid).delete().catch(() => null);

    // --------------------------------------------------
    // 3) delete notifications related to user
    // --------------------------------------------------
    await deleteByQuery(
      db.collection("notifications").where("userId", "==", uid)
    );

    await deleteByQuery(
      db.collection("notifications").where("targetUserId", "==", uid)
    );

    await deleteByQuery(
      db.collection("notifications").where("fromUserId", "==", uid)
    );

    await deleteByQuery(
      db.collection("scheduled_notifications").where("userId", "==", uid)
    );

    // --------------------------------------------------
    // found/lost Dog
    // --------------------------------------------------

    await deleteByQuery(
      db.collection("found_dogs").where("ownerId", "==", uid)
    );

    await deleteByQuery(
      db.collection("lost_dogs").where("ownerId", "==", uid)
    );

    // --------------------------------------------------
    // vet apoinment
    // --------------------------------------------------
    await deleteByQuery(
      db.collection("vet_appointments").where("userId", "==", uid)
    );
    // --------------------------------------------------
    // subscribtion
    // --------------------------------------------------
    await deleteByQuery(
      db.collection("subscriptions").where("userId", "==", uid)
    );

    // --------------------------------------------------
    // complains
    // --------------------------------------------------
    await deleteByQuery(
      db.collection("complaints").where("userId", "==", uid)
    );

    // --------------------------------------------------
    // 4) delete play date requests related to user
    // --------------------------------------------------
    await deleteByQuery(
      db.collection("playDateRequests").where("requesterUserId", "==", uid)
    );

    await deleteByQuery(
      db.collection("playDateRequests").where("targetUserId", "==", uid)
    );

    await deleteByQuery(
      db.collection("playDateRequests").where("ownerId", "==", uid)
    );

    // --------------------------------------------------
    // 5) delete adoption requests related to user
    // --------------------------------------------------
    await deleteByQuery(
      db.collection("adoptionRequests").where("requesterUserId", "==", uid)
    );

    await deleteByQuery(
      db.collection("adoptionRequests").where("ownerId", "==", uid)
    );

    // --------------------------------------------------
    // 6) delete favorites / likes / offer clicks / misc
    // --------------------------------------------------
    await deleteByQuery(
      db.collection("offer_clicks").where("userId", "==", uid)
    );

    await deleteByQuery(
      db.collection("reports").where("reportedBy", "==", uid)
    );

    // --------------------------------------------------
    // 7) delete business requests by uid
    // --------------------------------------------------
    await deleteByQuery(
      db.collection("business_requests").where("uid", "==", uid)
    );

    // --------------------------------------------------
    // orders
    // --------------------------------------------------

    await deleteByQuery(
      db.collection("orders").where("userId", "==", uid)
    );

    await deleteByQuery(
      db.collection("orders").where("businessId", "==", uid)
    );

    // --------------------------------------------------
    //      chats
    // --------------------------------------------------

    await deleteByQuery(
      db.collection("chats").where("participants", "array-contains", uid)
    );

    // --------------------------------------------------
    // likes
    // --------------------------------------------------

    await deleteByQuery(
      db.collection("likes").where("userId", "==", uid)
    );


    // --------------------------------------------------
    // 8) delete owned businesses and related storage/docs
    // --------------------------------------------------
    const businessSnap = await db
      .collection("businesses")
      .where("ownerUid", "==", uid)
      .get();

    for (const bizDoc of businessSnap.docs) {
      const businessId = bizDoc.id;

      // delete appointments linked to business if you use this collection
      await deleteByQuery(
        db.collection("appointments").where("businessId", "==", businessId)
      );

      // delete reviews linked to business if needed
      await deleteByQuery(
        db.collection("reviews").where("businessId", "==", businessId)
      );

      await db.collection("businesses").doc(businessId).delete();

      // try deleting business folder patterns in storage
      await deleteFilesByPrefix(bucket, `business_sector_docs/${uid}/`);
      await deleteFilesByPrefix(bucket, `businesses/${businessId}/`);
    }

    // --------------------------------------------------
    // 9) delete user profile media in storage
    // --------------------------------------------------
    await deleteFilesByPrefix(bucket, `users/${uid}/`);
    await deleteFilesByPrefix(bucket, `dogs/${uid}/`);

    // --------------------------------------------------
    // 10) finally delete auth user
    // --------------------------------------------------
    await admin.auth().deleteUser(uid);

    return {
      success: true,
      message: "User account and related data deleted successfully.",
    };
  } catch (error) {
    logger.error("deleteUserAccount failed", {
      uid,
      error: String(error),
    });

    throw new HttpsError(
      "internal",
      "Failed to delete user account."
    );
  }
});

async function deleteByQuery(query, batchSize = 200) {
  let snapshot = await query.limit(batchSize).get();

  while (!snapshot.empty) {
    const batch = db.batch();

    snapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();

    if (snapshot.size < batchSize) break;

    snapshot = await query.limit(batchSize).get();
  }
}

async function deleteFilesByPrefix(bucket, prefix) {
  try {
    const [files] = await bucket.getFiles({ prefix });

    if (!files.length) return;

    await Promise.all(
      files.map((file) =>
        file.delete({ ignoreNotFound: true }).catch((e) => {
          logger.warn("Failed deleting storage file", {
            file: file.name,
            error: String(e),
          });
        })
      )
    );
  } catch (e) {
    logger.warn("Failed deleting storage prefix", {
      prefix,
      error: String(e),
    });
  }
}

function extractStoragePathFromUrl(url) {
  if (!url || typeof url !== "string") return null;

  try {
    // Firebase download URL format:
    // https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encodedPath>?alt=media&token=...
    const marker = "/o/";
    const markerIndex = url.indexOf(marker);

    if (markerIndex === -1) return null;

    const encodedPath = url.substring(markerIndex + marker.length).split("?")[0];
    return decodeURIComponent(encodedPath);
  } catch (e) {
    logger.warn("Failed to parse storage URL", {
      url,
      error: String(e),
    });
    return null;
  }
}




function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function normalizeDigits(value) {
  return String(value || "").replace(/\D/g, "");
}

function normalizeText(value) {
  return String(value || "").trim().toLowerCase();
}

function asNumber(value) {
  if (typeof value === "number") return value;
  const n = Number(value);
  return Number.isFinite(n) ? n : 0;
}

function buildOrderNumber(sequence) {
  const year = new Date().getFullYear();
  const padded = String(sequence).padStart(6, "0");
  return `BM-${year}-${padded}`;
}

function buildSellerOrderNumber(rootOrderNumber, index) {
  return `${rootOrderNumber}-${String(index).padStart(2, "0")}`;
}

function buildInitialTimeline(status) {
  return [
    {
      status,
      at: new Date().toISOString(), // ✅ FIX
      by: "system",
    },
  ];
}

exports.createMarketplaceOrderV2 = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    const auth = request.auth;
    if (!auth) {
      throw new HttpsError("unauthenticated", "Login required.");
    }

    const data = request.data || {};
    const buyer = data.buyer || {};
    const billing = data.billing || {};
    const delivery = data.delivery || {};
    const payment = data.payment || {};
    const legal = data.legal || {};
    const currency = data.currency || "TRY";
    const items = Array.isArray(data.items) ? data.items : [];

    let rootSubtotal = 0;
    let rootShippingTotal = 0;
    let rootTaxTotal = 0;

    if (items.length === 0) {
      throw new HttpsError("invalid-argument", "Items are required.");
    }

    const invalidItem = items.find(
      (item) =>
        !item ||
        !item.shopId ||
        !item.productId ||
        asNumber(item.quantity) <= 0
    );

    if (invalidItem) {
      throw new HttpsError(
        "invalid-argument",
        "Each item must include shopId, productId, and quantity."
      );
    }

    const invoiceType = billing.invoiceType || "individual";

    if (invoiceType === "individual") {
      if (!billing.identityNumber) {
        throw new HttpsError(
          "invalid-argument",
          "identityNumber is required for individual invoice."
        );
      }
    }

    if (invoiceType === "corporate") {
      if (!billing.taxNumber || !billing.taxOffice || !billing.companyName) {
        throw new HttpsError(
          "invalid-argument",
          "companyName, taxNumber, and taxOffice are required for corporate invoice."
        );
      }
    }



    const name = billing.name || buyer.name || null;
    const surname = billing.surname || buyer.surname || null;

    if (!name || !surname) {
      throw new HttpsError(
        "invalid-argument",
        "name and surname are required for invoice."
      );
    }

    const counterRef = db.collection("counters").doc("orderCounter");
    const rootOrderRef = db.collection("orders").doc();

    const sequence = await db.runTransaction(async (tx) => {
      const counterSnap = await tx.get(counterRef);
      const current = counterSnap.exists ? asNumber(counterSnap.data().current) : 0;
      const next = current + 1;
      tx.set(counterRef, { current: next }, { merge: true });
      return next;
    });

    const orderNumber = buildOrderNumber(sequence);
    const normalizeKdvRate = (value) => {
      const rate = asNumber(value);
      if (rate < 0) return 0;
      return Number(rate.toFixed(2));
    };

    const buildTaxSnapshotItem = (item) => {
      const quantity = asNumber(item.quantity);
      const unitPriceInclTax = asNumber(item.unitPrice || item.price);
      const shippingFeeTotal = asNumber(item.shippingFeeTotal || 0);
      const kdvRate = normalizeKdvRate(
        item.kdvRate ?? item.taxRate ?? item.vatRate ?? 0
      );

      const divisor = 1 + kdvRate / 100;

      const unitPriceExclTax =
        divisor > 0
          ? Number((unitPriceInclTax / divisor).toFixed(2))
          : Number(unitPriceInclTax.toFixed(2));

      const unitKdvAmount = Number((unitPriceInclTax - unitPriceExclTax).toFixed(2));

      const lineSubtotal = Number((unitPriceExclTax * quantity).toFixed(2));
      const lineKdvTotal = Number((unitKdvAmount * quantity).toFixed(2));
      const lineShipping = Number(shippingFeeTotal.toFixed(2));
      const lineGrandTotal = Number(
        (lineSubtotal + lineKdvTotal + lineShipping).toFixed(2)
      );

      return {
        ...item,

        quantity,

        unitPriceInclTax: Number(unitPriceInclTax.toFixed(2)),
        unitPriceExclTax,
        kdvRate,
        unitKdvAmount,

        lineSubtotal,
        lineTaxTotal: lineKdvTotal,
        lineShipping,
        lineGrandTotal,

        taxSnapshot: {
          currency,
          kdvRate,
          unitPriceInclTax: Number(unitPriceInclTax.toFixed(2)),
          unitPriceExclTax,
          unitKdvAmount,
          lineSubtotal,
          lineKdvTotal,
          lineShipping,
          lineGrandTotal,
        },
      };
    };
    const grouped = new Map();
    for (const item of items) {
      const key = String(item.shopId);
      const bucket = grouped.get(key) || [];
      bucket.push(item);
      grouped.set(key, bucket);
    }

    const groupedEntries = Array.from(grouped.entries());

    const normalizedGroupedEntries = groupedEntries.map(([shopId, shopItems]) => {
      const normalizedItems = shopItems.map((item) => buildTaxSnapshotItem(item));
      return [shopId, normalizedItems];
    });

    const sellerOrderRefs = [];
    const sellerOrderPayloads = [];
    const sellerOrderIds = [];

    for (let i = 0; i < normalizedGroupedEntries.length; i++) {
      const [shopId, shopItems] = normalizedGroupedEntries[i];
      const businessDoc = await db
        .collection("businesses")
        .doc(shopId)
        .get();

      if (!businessDoc.exists) {
        throw new HttpsError("not-found", `Business not found: ${shopId}`);
      }

      const businessData = businessDoc.data() || {};
      const sellerUid = businessDoc.data()?.ownerUid;

      if (!sellerUid) {
        throw new HttpsError(
          "failed-precondition",
          `Missing ownerUid for business ${shopId}`
        );
      }
      const sellerOrderRef = db.collection("sellerOrders").doc();
      const sellerOrderId = sellerOrderRef.id;
      const sellerOrderNumber = buildSellerOrderNumber(orderNumber, i + 1);
      const subtotal = Number(
        shopItems.reduce(
          (sum, item) => sum + asNumber(item.taxSnapshot?.lineSubtotal || 0),
          0
        ).toFixed(2)
      );
      const shippingTotal = Number(
        shopItems.reduce(
          (sum, item) => sum + asNumber(item.taxSnapshot?.lineShipping || 0),
          0
        ).toFixed(2)
      );
      const taxTotal = Number(
        shopItems.reduce(
          (sum, item) => sum + asNumber(item.taxSnapshot?.lineKdvTotal || 0),
          0
        ).toFixed(2)
      );

      const grandTotal = Number(
        (subtotal + shippingTotal + taxTotal).toFixed(2)
      );

      rootSubtotal += subtotal;
      rootShippingTotal += shippingTotal;
      rootTaxTotal += taxTotal;

      sellerOrderRefs.push(sellerOrderRef);
      sellerOrderIds.push(sellerOrderId);


      const sellerSnapshot = {
        businessId: shopId,

        ownerUid: businessData.ownerUid || null,

        businessName:
          businessData?.profile?.businessName ||
          businessData?.profile?.name ||
          null,

        taxNumber: businessData?.legal?.taxNumber || null,
        mersisNumber: businessData?.legal?.mersisNumber || null,

        city: businessData?.contact?.city || null,
        addressLine: businessData?.contact?.addressLine || null,
      };
      sellerOrderPayloads.push({
        sellerUid: sellerUid, // 🔥🔥🔥 این مهم‌ترین خطه
        sellerSnapshot: sellerSnapshot,
        rootOrderId: rootOrderRef.id,
        rootOrderNumber: orderNumber,
        sellerOrderNumber,
        shopId,
        buyerUid: auth.uid,
        buyerName: name,
        buyerSurname: surname,
        buyerEmail: buyer.email || null,
        buyerPhone: buyer.phone || null,
        status: payment.status === "paid" ? "paid" : "pending_payment",
        paymentStatus: payment.status || "pending",
        currency,
        items: shopItems,
        delivery: {
          city: delivery.city || null,
          district: delivery.district || null,
          address: delivery.address || null,
          fullName: delivery.fullName || buyer.name || null,
          phone: delivery.phone || buyer.phone || null,
        },
        shipping: {
          carrier: null,
          trackingNumber: null,
          shippedAt: null,
          deliveredAt: null,
        },
        pricing: {
          currency,
          subtotal,
          shippingTotal,
          taxTotal,
          grandTotal,
        },
        invoice: {
          required: true,
          status: "pending_upload",
          type: "seller_uploaded",

          invoiceNumber: null,
          invoiceDate: null,
          uploadDeadlineAt: null,
          uploadDeadlineAt: null,
          uploadedAt: null,
          approvedAt: null,
          rejectedAt: null,

          pdfUrl: null,
          filePath: null,

          notes: null,
          rejectionReason: null,

          lastReminderAt: null,
          reminderCount: 0,

          billingSnapshot: {
            invoiceType,

            name,
            surname,
            contactName: `${name} ${surname}`,

            identityNumber:
              invoiceType === "individual" ? billing.identityNumber : null,

            companyName:
              invoiceType === "corporate" ? billing.companyName : null,

            taxNumber:
              invoiceType === "corporate" ? billing.taxNumber : null,

            taxOffice:
              invoiceType === "corporate" ? billing.taxOffice : null,

            city: billing.city || delivery.city || null,
            district: billing.district || delivery.district || null,
            address: billing.address || delivery.address || null,
            country: billing.country || "Turkey",
          },
        },
        timeline: buildInitialTimeline(
          payment.status === "paid" ? "paid" : "pending_payment"
        ),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        search: {
          sellerOrderNumberLower: sellerOrderNumber.toLowerCase(),
          rootOrderNumberLower: orderNumber.toLowerCase(),
          buyerEmailLower: normalizeEmail(buyer.email),
          buyerPhoneDigits: normalizeDigits(buyer.phone),
          shopIdLower: normalizeText(shopId),
        },
      });
    }

    const subtotal = Number(rootSubtotal.toFixed(2));
    const shippingTotal = Number(rootShippingTotal.toFixed(2));
    const taxTotal = Number(rootTaxTotal.toFixed(2));
    const grandTotal = Number((subtotal + shippingTotal + taxTotal).toFixed(2));

    const batch = db.batch();

    batch.set(rootOrderRef, {
      orderNumber,
      buyerUid: auth.uid,
      buyerName: name,
      buyerSurname: surname,
      buyerEmail: buyer.email || null,
      buyerPhone: buyer.phone || null,
      status: payment.status === "paid" ? "paid" : "pending_payment",
      paymentStatus: payment.status || "pending",
      currency,
      pricing: {
        currency,
        subtotal,
        shippingTotal,
        taxTotal,
        grandTotal,
      },
      delivery: {
        city: delivery.city || null,
        district: delivery.district || null,
        address: delivery.address || null,
        fullName: delivery.fullName || buyer.name || null,
        phone: delivery.phone || buyer.phone || null,
      },
      invoice: {
        hasInvoice: false,
        invoiceCount: sellerOrderIds.length,
      },
      payment: {
        provider: payment.provider || null,
        paymentId: payment.paymentId || null,
        conversationId: payment.conversationId || null,
      },
      legal: {
        kvkkAccepted: legal.kvkkAccepted === true,
        preInfoAccepted: legal.preInfoAccepted === true,
        distanceSalesAccepted: legal.distanceSalesAccepted === true,
        marketingConsent: legal.marketingConsent === true,
        notificationPreference: legal.notificationPreference || null,
        acceptedAt: legal.acceptedAt || null,
      },
      sellerOrderIds,
      sellerCount: sellerOrderIds.length,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      search: {
        orderNumberLower: orderNumber.toLowerCase(),
        buyerEmailLower: normalizeEmail(buyer.email),
        buyerPhoneDigits: normalizeDigits(buyer.phone),
      },
    });
    if (legal.marketingConsent === true) {
      batch.set(
        db.collection("users").doc(auth.uid),
        {
          marketingConsent: true,
          marketingConsentAt: admin.firestore.FieldValue.serverTimestamp(),
          marketingConsentSource: "checkout",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }
    for (let i = 0; i < sellerOrderRefs.length; i++) {
      batch.set(sellerOrderRefs[i], sellerOrderPayloads[i]);
    }
    logger.info("💰 ROOT ORDER PRICING", {
      subtotal,
      shippingTotal,
      taxTotal,
      grandTotal,
    });
    await batch.commit();

    return {
      ok: true,
      orderId: rootOrderRef.id,
      orderNumber,
      sellerOrderIds,
      sellerCount: sellerOrderIds.length,
    };
  }
);



exports.updateSellerOrderStatusV2 = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    try {
      const db = admin.firestore();
      const auth = request.auth;

      if (!auth?.uid) {
        throw new HttpsError("unauthenticated", "Login required.");
      }

      const data = request.data || {};

      const sellerOrderId = data.sellerOrderId;
      const newStatus = normalizeLower(data.status);
      const trackingNumber = normalizeText(data.trackingNumber);
      const carrierInput = normalizeText(data.carrier);
      logger.info("🧪 SELLER ORDER ID RAW", data.sellerOrderId);
      logger.info("🧪 SELLER ORDER ID USED", sellerOrderId);
      logger.info("🧪 UPDATE STATUS INPUT", {
        authUid: auth.uid,
        sellerOrderId,
        newStatus,
        trackingNumber,
        carrierInput,
        rawData: data,
      });

      if (!sellerOrderId || !newStatus) {
        throw new HttpsError(
          "invalid-argument",
          "sellerOrderId and status are required."
        );
      }

      const allowedStatuses = [
        "pending_payment",
        "paid",
        "confirmed",
        "preparing",
        "shipped",
        "delivered",
        "failed",
        "cancelled",
      ];

      if (!allowedStatuses.includes(newStatus)) {
        throw new HttpsError("invalid-argument", "Invalid status.");
      }

      const sellerOrderRef = db.collection("sellerOrders").doc(sellerOrderId);
      const sellerOrderSnap = await sellerOrderRef.get();

      logger.info("🧪 SELLER ORDER LOOKUP", {
        sellerOrderId,
        exists: sellerOrderSnap.exists,
      });

      if (!sellerOrderSnap.exists) {
        throw new HttpsError("not-found", "Seller order not found.");
      }

      const sellerOrder = sellerOrderSnap.data() || {};

      logger.info("🧪 SELLER ORDER DATA", {
        sellerOrderId,
        rootOrderId: sellerOrder.rootOrderId || null,
        shopId: sellerOrder.shopId || null,
        sellerUid: sellerOrder.sellerUid || null,
        buyerUid: sellerOrder.buyerUid || null,
        status: sellerOrder.status || null,
      });

      const currentStatus = normalizeLower(sellerOrder.status);
      const rootOrderId = sellerOrder.rootOrderId || null;

      if (!rootOrderId) {
        throw new HttpsError("failed-precondition", "Missing rootOrderId");
      }

      const businessId = sellerOrder.businessId || sellerOrder.shopId || null;
      if (!businessId) {
        throw new HttpsError(
          "failed-precondition",
          "Missing businessId/shopId in sellerOrder"
        );
      }

      const businessSnap = await db.collection("businesses").doc(businessId).get();

      logger.info("🧪 BUSINESS LOOKUP", {
        businessId,
        exists: businessSnap.exists,
      });

      if (!businessSnap.exists) {
        throw new HttpsError("not-found", "Business not found");
      }

      const businessData = businessSnap.data() || {};

      logger.info("🧪 BUSINESS OWNER CHECK", {
        businessId,
        businessOwnerUid: businessData.ownerUid || null,
        authUid: auth.uid,
      });

      if (businessData.ownerUid !== auth.uid) {
        throw new HttpsError(
          "permission-denied",
          "You are not the owner of this business"
        );
      }

      const allowedTransitions = {
        pending_payment: ["paid", "failed", "cancelled"],
        paid: ["confirmed", "cancelled"],
        confirmed: ["preparing", "cancelled"],
        preparing: ["shipped", "cancelled"],
        shipped: ["delivered"],
        delivered: [],
        failed: [],
        cancelled: [],
      };

      const nextAllowed = allowedTransitions[currentStatus] || [];

      if (
        currentStatus &&
        currentStatus !== newStatus &&
        !nextAllowed.includes(newStatus)
      ) {
        throw new HttpsError(
          "failed-precondition",
          `Invalid status transition: ${currentStatus} -> ${newStatus}`
        );
      }

      const rootOrderRef = db.collection("orders").doc(rootOrderId);
      const rootOrderSnap = await rootOrderRef.get();
      const rootOrder = rootOrderSnap.exists ? rootOrderSnap.data() || {} : {};

      logger.info("🧪 ROOT ORDER LOOKUP", {
        rootOrderId,
        exists: rootOrderSnap.exists,
      });

      const existingShipping = sellerOrder.shipping || {};
      const carrier =
        carrierInput ||
        existingShipping.carrier ||
        rootOrder?.shipping?.carrier ||
        null;

      if (newStatus === "shipped") {
        if (!carrier) {
          throw new HttpsError(
            "failed-precondition",
            "Carrier is required for shipped status"
          );
        }
        if (!trackingNumber) {
          throw new HttpsError(
            "invalid-argument",
            "Tracking number is required for shipped status"
          );
        }
      }

      if (newStatus === "delivered" && !existingShipping.shippedAt) {
        throw new HttpsError(
          "failed-precondition",
          "Order must be shipped before marking delivered"
        );
      }

      const now = admin.firestore.FieldValue.serverTimestamp();

      const sellerPatch = {
        status: newStatus,
        updatedAt: now,
        timeline: admin.firestore.FieldValue.arrayUnion({
          status: newStatus,
          at: new Date().toISOString(),
          by: auth.uid,
        }),
      };

      if (newStatus === "confirmed") {
        sellerPatch.confirmedAt = now;
      }

      if (newStatus === "preparing") {
        sellerPatch.preparingAt = now;
      }
      // 🔥 INVOICE TRIGGER
      if (newStatus === "preparing") {
        const currentInvoice = sellerOrder.invoice || {};

        if (!currentInvoice.uploadDeadlineAt) {
          const nowTs = admin.firestore.Timestamp.now();

          const deadline = admin.firestore.Timestamp.fromMillis(
            nowTs.toMillis() + 3 * 24 * 60 * 60 * 1000
          );

          sellerPatch["invoice.status"] = "pending_upload";
          sellerPatch["invoice.uploadDeadlineAt"] = deadline;

          // ✅ DEBUG LOG
          logger.info("🧾 INVOICE DEADLINE SET (FAILSAFE)", {
            sellerOrderId,
            previousDeadline: currentInvoice.uploadDeadlineAt || null,
            newDeadline: deadline.toDate().toISOString(),
            triggeredBy: "shipped",
            now: nowTs.toDate().toISOString(),
          });
        } else {
          // ✅ DEBUG LOG (already exists)
          logger.info("🧾 INVOICE DEADLINE ALREADY EXISTS", {
            sellerOrderId,
            existingDeadline: currentInvoice.uploadDeadlineAt?.toDate?.() || null,
            skipped: true,
          });
        }

      }
      if (newStatus === "shipped") {
        sellerPatch.shipping = {
          ...existingShipping,
          carrier,
          trackingNumber,
          trackingUrl: buildTrackingUrl(carrier, trackingNumber),
          shippedAt: now,
          deliveredAt: existingShipping.deliveredAt || null,
        };

        // 🔥 FAILSAFE INVOICE TRIGGER
        const currentInvoice = sellerOrder.invoice || {};

        if (!currentInvoice.uploadDeadlineAt) {
          const nowTs = admin.firestore.Timestamp.now();

          const deadline = admin.firestore.Timestamp.fromMillis(
            nowTs.toMillis() + 3 * 24 * 60 * 60 * 1000
          );

          sellerPatch["invoice.status"] = "pending_upload";
          sellerPatch["invoice.uploadDeadlineAt"] = deadline;
        }
      }

      if (newStatus === "delivered") {
        sellerPatch.shipping = {
          ...existingShipping,
          carrier: existingShipping.carrier || carrier || null,
          trackingNumber:
            existingShipping.trackingNumber || trackingNumber || null,
          trackingUrl:
            existingShipping.trackingUrl ||
            buildTrackingUrl(
              existingShipping.carrier || carrier || null,
              existingShipping.trackingNumber || trackingNumber || null
            ),
          shippedAt: existingShipping.shippedAt || null,
          deliveredAt: now,
        };
      }

      if (newStatus === "cancelled") {
        sellerPatch.cancelledAt = now;
      }

      if (newStatus === "failed") {
        sellerPatch.failedAt = now;
      }

      await sellerOrderRef.set(sellerPatch, { merge: true });

      // 🔔 Notify seller about invoice requirement
      if (newStatus === "preparing" || newStatus === "shipped") {
        await createNotification(db, {
          recipientUserId: auth.uid,
          userId: auth.uid,
          type: "invoice_required",
          title: "Fatura gerekli ⚠️",
          body: "Sipariş için faturanızı yüklemeyi unutmayın.",
          sellerOrderId,
          orderId: rootOrderId,
        });
      }

      const siblingsSnap = await db
        .collection("sellerOrders")
        .where("rootOrderId", "==", rootOrderId)
        .get();

      const siblingStatuses = siblingsSnap.docs.map((doc) => {
        if (doc.id === sellerOrderId) return newStatus;
        return doc.data()?.status || "pending_payment";
      });

      const rootStatus = computeRootStatusFromSellerStatuses(siblingStatuses);

      await rootOrderRef.set(
        {
          status: rootStatus,
          updatedAt: now,
          timeline: admin.firestore.FieldValue.arrayUnion({
            status: rootStatus,
            at: new Date().toISOString(),
            by: "system",
          }),
        },
        { merge: true }
      );

      const buyerUid =
        sellerOrder.buyerUid || rootOrder.buyerUid || rootOrder.userId || null;

      if (buyerUid) {
        let body = `Your order status is now ${newStatus}.`;

        if (newStatus === "shipped") {
          body = trackingNumber
            ? `Your order has been shipped. Tracking number: ${trackingNumber}`
            : "Your order has been shipped.";
        }

        if (newStatus === "delivered") {
          body = "Your order has been delivered.";
        }

        await createNotification(db, {
          recipientUserId: buyerUid,
          userId: buyerUid,
          type: "order_update",
          title: "Order update 📦",
          body,
          orderId: rootOrderId,
          sellerOrderId,
        });
      }

      logger.info("✅ SELLER ORDER STATUS UPDATED", {
        sellerOrderId,
        rootOrderId,
        newStatus,
        rootStatus,
      });

      return {
        ok: true,
        sellerOrderId,
        status: newStatus,
        rootStatus,
        shipping:
          newStatus === "shipped" || newStatus === "delivered"
            ? {
              carrier: carrier || existingShipping.carrier || null,
              trackingNumber:
                trackingNumber || existingShipping.trackingNumber || null,
              trackingUrl:
                buildTrackingUrl(
                  carrier || existingShipping.carrier || null,
                  trackingNumber || existingShipping.trackingNumber || null
                ) || existingShipping.trackingUrl || null,
            }
            : null,
      };
    } catch (error) {
      logger.error("❌ updateSellerOrderStatusV2 ERROR", {
        message: error?.message || String(error),
        stack: error?.stack || null,
      });

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError("internal", error?.message || "Update failed");
    }
  }
);


function extractInvoiceNumber(text = "") {
  const normalized = text
    .replace(/İ/g, "I")
    .replace(/\s+/g, " ")
    .trim();

  const patterns = [
    /Fatura\s*No[:\s]*([A-Z0-9\-]+)/i,
    /Invoice\s*No[:\s]*([A-Z0-9\-]+)/i,

    // 🔥 GIB robust
    /(GIB[\s\-]*[0-9]{6,})/i,
  ];

  for (const p of patterns) {
    const m = normalized.match(p);
    if (m) {
      return m[1]
        .replace(/\s+/g, "")   // حذف فاصله وسط
        .replace(/-/g, "")     // حذف dash
        .trim();
    }
  }

  return null;
}

function extractInvoiceDate(text = "") {
  const normalized = text.replace(/\s+/g, " ");

  const patterns = [
    // 31-12-2025
    /Fatura\s*Tarihi[:\s]*([0-9]{2}-[0-9]{2}-[0-9]{4})/i,

    // 31.12.2025
    /Fatura\s*Tarihi[:\s]*([0-9]{2}\.[0-9]{2}\.[0-9]{4})/i,

    // 2025-12-31
    /Fatura\s*Tarihi[:\s]*([0-9]{4}-[0-9]{2}-[0-9]{2})/i,

    // 🔥 همراه ساعت (مهم!)
    /Fatura\s*Tarihi[:\s]*([0-9]{2}-[0-9]{2}-[0-9]{4}\s*[0-9:]+)/i,
  ];

  for (const p of patterns) {
    const m = normalized.match(p);
    if (m && m[1]) {
      return m[1].trim();
    }
  }

  return null;
}

function extractInvoiceSystem(text = "") {
  const normalized = text
    .toUpperCase()
    .replace(/İ/g, "I");

  if (
    normalized.includes("EARSIV") ||
    normalized.includes("E-ARSIV") ||
    normalized.includes("EARSIVFATURA")
  ) {
    return "e-Arşiv";
  }

  if (
    normalized.includes("EFATURA") ||
    normalized.includes("E-FATURA")
  ) {
    return "e-Fatura";
  }

  return null;
}

async function extractTextFromPdfGcs(bucketName, inputFilePath) {
  const outputPrefix = `ocr-output/${Date.now()}-${Math.random()
    .toString(36)
    .slice(2)}/`;

  const request = {
    requests: [
      {
        inputConfig: {
          gcsSource: {
            uri: `gs://${bucketName}/${inputFilePath}`,
          },
          mimeType: "application/pdf",
        },
        features: [{ type: "DOCUMENT_TEXT_DETECTION" }],
        outputConfig: {
          gcsDestination: {
            uri: `gs://${bucketName}/${outputPrefix}`,
          },
          batchSize: 1,
        },
      },
    ],
  };

  const [operation] = await client.asyncBatchAnnotateFiles(request);
  await operation.promise();

  const [files] = await admin.storage().bucket(bucketName).getFiles({
    prefix: outputPrefix,
  });

  let fullText = "";

  for (const f of files) {
    if (!f.name.endsWith(".json")) continue;

    const [contents] = await f.download();
    const parsed = JSON.parse(contents.toString("utf8"));

    const responses = parsed.responses || [];
    for (const r of responses) {
      const text = r.fullTextAnnotation?.text || "";
      if (text) {
        fullText += text + "\n";
      }
    }
  }

  return fullText.trim();
}

exports.uploadInvoiceAndValidate = onCall(
  { region: "europe-west3" },
  async (request) => {

    const { sellerOrderId, fileBytes, fileName } = request.data || {};
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    if (!sellerOrderId || typeof sellerOrderId !== "string") {
      throw new HttpsError("invalid-argument", "sellerOrderId is required");
    }

    if (!fileBytes) {
      throw new HttpsError("invalid-argument", "fileBytes is required");
    }

    if (!fileName || typeof fileName !== "string") {
      throw new HttpsError("invalid-argument", "fileName is required");
    }

    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    // =========================
    // 1) GET ORDER
    // =========================
    const orderRef = db.collection("sellerOrders").doc(sellerOrderId);
    const orderSnap = await orderRef.get();

    if (!orderSnap.exists) {
      throw new HttpsError("not-found", "Order not found");
    }

    const order = orderSnap.data() || {};

    // =========================
    // 2) SECURITY CHECK
    // =========================
    const sellerOwnerUid =
      order?.sellerSnapshot?.ownerUid ||
      order?.sellerUid ||
      order?.shopId ||
      null;

    if (!sellerOwnerUid) {
      throw new HttpsError(
        "failed-precondition",
        "Seller ownership data missing on order"
      );
    }

    if (sellerOwnerUid !== uid) {
      throw new HttpsError("permission-denied", "Not your order");
    }

    // =========================
    // 3) NORMALIZE FILE
    // =========================
    const normalizedFileName = String(fileName).replace(/[^\w.\-]/g, "_");

    let contentType = "application/octet-stream";
    const lowerName = normalizedFileName.toLowerCase();

    if (lowerName.endsWith(".pdf")) {
      contentType = "application/pdf";
    } else if (lowerName.endsWith(".jpg") || lowerName.endsWith(".jpeg")) {
      contentType = "image/jpeg";
    } else if (lowerName.endsWith(".png")) {
      contentType = "image/png";
    }

    const buffer = Buffer.isBuffer(fileBytes)
      ? fileBytes
      : Buffer.from(fileBytes);

    if (!buffer || !buffer.length) {
      throw new HttpsError("invalid-argument", "Uploaded file is empty");
    }

    if (buffer.length > 5 * 1024 * 1024) {
      throw new HttpsError("invalid-argument", "File too large");
    }

    // =========================
    // 4) UPLOAD FILE
    // =========================
    const filePath = `invoices/${uid}/${sellerOrderId}/${normalizedFileName}`;
    const file = bucket.file(filePath);

    await file.save(buffer, {
      metadata: { contentType },
      resumable: false,
    });

    await file.makePublic();

    const url = `https://storage.googleapis.com/${bucket.name}/${filePath}`;

    // =========================
    // 5) OCR
    // =========================
    let extractedText = "";

    try {
      extractedText = await extractTextFromPdfGcs(bucket.name, filePath);

      console.log("🔥 OCR TEXT START");
      console.log(extractedText);
      console.log("🔥 OCR TEXT END");
    } catch (e) {
      console.error("❌ OCR ERROR:", e);
      extractedText = "";
    }

    // =========================
    // 6) EXTRACT FROM OCR TEXT
    // =========================
    const extractedInvoiceNumber = extractInvoiceNumber(extractedText);
    const extractedInvoiceDate = extractInvoiceDate(extractedText);
    const extractedInvoiceSystem = extractInvoiceSystem(extractedText);

    // =========================
    // 7) VALIDATION
    // =========================
    const nowIso = new Date().toISOString();

    const validationIssues = validateInvoiceData({
      billingSnapshot: order?.billing || {},
      sellerSnapshot: order?.sellerSnapshot || {},
    });

    let riskFlags = [];

    const billing = order?.billing || {};

    // 🔥 این خط مهمه (fix اصلی)
    const expectedInvoiceSystem =
      billing?.invoiceType === "company"
        ? "eFatura"
        : "eArsiv";

    const newStatus =
      validationIssues.length === 0
        ? "uploaded_valid"
        : "uploaded_with_issues";

    // =========================
    // 8) SAVE
    // =========================
    await orderRef.update({
      "invoice.pdfUrl": url,
      "invoice.filePath": filePath,

      "invoice.status": newStatus,
      "invoice.uploadedAt": nowIso,
      "invoice.uploadedBy": uid,

      "invoice.invoiceNumber": extractedInvoiceNumber || null,
      "invoice.invoiceDate": extractedInvoiceDate || null,
      "invoice.invoiceSystem":
        extractedInvoiceSystem || expectedInvoiceSystem || null,

      "invoice.validationIssues": validationIssues,

      "invoice.validation": {
        checked: true,
        riskFlags,
        extractedInvoiceNumber: extractedInvoiceNumber || null,
        extractedInvoiceDate: extractedInvoiceDate || null,
        extractedInvoiceSystem: extractedInvoiceSystem || null,
        expectedInvoiceSystem,
        ocrText: extractedText || "",
        checkedAt: nowIso,
      },

      "invoice.isLate": false,

      "documents.invoiceStatus": newStatus,
      "documents.invoiceRequired": true,

      "compliance.invoiceMissing": false,
      "compliance.lastCheckedAt": nowIso,

      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // =========================
    // 9) RETURN
    // =========================
    return {
      success: true,
      pdfUrl: url,
      invoiceNumber: extractedInvoiceNumber || null,
      invoiceDate: extractedInvoiceDate || null,
      invoiceSystem: extractedInvoiceSystem || null,
      expectedInvoiceSystem,
      riskFlags,
    };
  }
);
exports.checkPendingInvoices = onSchedule(
  {
    schedule: "every 5 minutes",
    region: "europe-west3",
  },
  async () => {
    const db = admin.firestore();
    const nowMillis = Date.now();

    const snap = await db
      .collection("sellerOrders")
      .where("invoice.status", "==", "pending_upload")
      .get();

    for (const doc of snap.docs) {
      const data = doc.data();
      const invoice = data.invoice || {};
      const deadline = invoice.uploadDeadlineAt;

      if (!deadline) continue;

      // ✅ SAFE TIME CONVERSION
      const deadlineMillis = toMillisSafe(deadline);
      if (!deadlineMillis) continue;

      const isLate = deadlineMillis < nowMillis;

      // 🔴 LATE
      if (isLate) {
        await doc.ref.update({
          "invoice.status": "late",
          "invoice.isLate": true,

          "compliance.invoiceLate": true,
          "compliance.warningCount":
            admin.firestore.FieldValue.increment(1),
          "compliance.penaltyPoints":
            admin.firestore.FieldValue.increment(10),

          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logger.warn("⚠️ INVOICE LATE", {
          sellerOrderId: doc.id,
        });
      }

      // 🟡 REMINDER
      else {
        const hoursLeft =
          (deadlineMillis - nowMillis) / (1000 * 60 * 60);

        if (hoursLeft < 24) {
          await createNotification(db, {
            recipientUserId: data.sellerUid,
            userId: data.sellerUid,
            type: "invoice_reminder",
            title: "Fatura hatırlatma ⏰",
            body: "Faturanızı yüklemek için son 24 saat.",
            sellerOrderId: doc.id,
            orderId: data.rootOrderId,
          });

          logger.info("⏰ INVOICE REMINDER SENT", {
            sellerOrderId: doc.id,
            hoursLeft,
          });
        }
      }
    }

    return null;
  }
);

exports.calculatePricing = onCall(
  {
    region: "europe-west3",
    memory: "256MiB",
    timeoutSeconds: 30,
  },
  async (request) => {
    try {
      const data = request.data || {};
      const db = admin.firestore();

      const items = Array.isArray(data.items) ? data.items : [];
      const selectedCarrier = data.carrier || "";

      if (items.length === 0) {
        throw new HttpsError("invalid-argument", "Cart is empty");
      }

      const grouped = groupItemsByBusiness(items);

      let subtotal = 0;
      let shippingTotal = 0;
      let taxTotal = 0;

      for (const [businessId, sellerItems] of grouped.entries()) {
        const configRef = db.collection("shipping_configs").doc(businessId);
        const configSnap = await configRef.get();

        if (!configSnap.exists) {
          throw new HttpsError(
            "failed-precondition",
            `Missing shipping config for ${businessId}`
          );
        }

        const config = configSnap.data() || {};

        for (const rawItem of sellerItems) {
          const productId = String(rawItem.productId || "").trim();
          const quantity = Math.max(1, Number(rawItem.quantity || 1));

          const productSnap = await db
            .collection("businesses")
            .doc(businessId)
            .collection("products")
            .doc(productId)
            .get();

          if (!productSnap.exists) {
            throw new HttpsError("not-found", `Product not found: ${productId}`);
          }

          const product = productSnap.data() || {};

          const price = Number(
            product.salePrice || product.price || rawItem.price || 0
          );

          const kdvRate = Number(product.kdvRate || 0);

          const itemSubtotal = price * quantity;
          const itemTax = itemSubtotal * (kdvRate / 100);

          const shipping = calculateShippingForItem({
            item: {
              quantity,
              price,
              weightKg: product.weightKg || 0,
              lengthCm: product.lengthCm || 0,
              widthCm: product.widthCm || 0,
              heightCm: product.heightCm || 0,
            },
            config,
            selectedCarrier,
          });

          subtotal += itemSubtotal;
          taxTotal += itemTax;
          shippingTotal += shipping.shippingFeeTotal;
        }
      }

      subtotal = roundMoney(subtotal);
      taxTotal = roundMoney(taxTotal);
      shippingTotal = roundMoney(shippingTotal);

      const grandTotal = roundMoney(
        subtotal + taxTotal + shippingTotal
      );

      return {
        success: true,
        pricing: {
          subtotal,
          taxTotal,
          shippingTotal,
          grandTotal,
        },
      };
    } catch (error) {
      logger.error("🔥 calculatePricing ERROR", {
        message: error?.message,
        stack: error?.stack,
      });

      if (error instanceof HttpsError) throw error;

      throw new HttpsError(
        "internal",
        error?.message || "Pricing failed"
      );
    }
  }
);



function slugify(title) {
  return title
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "_")
    .replace(/[^a-z0-9_]/g, "");
}

exports.upsertService = onCall(async (request) => {
  const { auth, data } = request;

  if (!auth) {
    throw new HttpsError("unauthenticated", "Login required");
  }

  const { businessId, title, price, duration } = data;

  if (!businessId || !title) {
    throw new HttpsError("invalid-argument", "Missing fields");
  }

  const uid = auth.uid;

  const businessRef = db.collection("businesses").doc(businessId);
  const businessSnap = await businessRef.get();

  if (!businessSnap.exists) {
    throw new HttpsError("not-found", "Business not found");
  }

  if (businessSnap.data().ownerUid !== uid) {
    throw new HttpsError("permission-denied", "Not owner");
  }

  // 🔥 slug
  const slug = title
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "_")
    .replace(/[^a-z0-9_]/g, "");

  const serviceRef = businessRef.collection("services").doc(slug);

  const existing = await serviceRef.get();

  if (existing.exists) {
    await serviceRef.update({
      price: price ?? null,
      duration: duration ?? null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { status: "updated", id: slug };
  } else {
    await serviceRef.set({
      title,
      price: price ?? null,
      duration: duration ?? null,
      currency: "TRY",
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { status: "created", id: slug };
  }
});

// =====================================================
// VET APPOINTMENTS — PHASE 3
// =====================================================

const VET_APPOINTMENT_STATUSES = [
  "pending",
  "confirmed",
  "rejected",
  "completed",
  "cancelled_by_user",
  "cancelled_by_vet",
  "expired",
];

const VET_APPOINTMENT_ALLOWED_TRANSITIONS = {
  pending: ["confirmed", "rejected"],
  confirmed: ["completed", "cancelled_by_vet", "rejected"],
};

function assertVetAppointmentStatus(status) {
  if (!VET_APPOINTMENT_STATUSES.includes(status)) {
    throw new HttpsError("invalid-argument", `Invalid status: ${status}`);
  }
}

exports.updateVetAppointmentStatus = onCall(
  {
    region: "europe-west3",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required.");
    }

    const uid = request.auth.uid;
    const { appointmentId, newStatus } = request.data || {};

    if (!appointmentId || typeof appointmentId !== "string") {
      throw new HttpsError("invalid-argument", "appointmentId is required.");
    }

    if (!newStatus || typeof newStatus !== "string") {
      throw new HttpsError("invalid-argument", "newStatus is required.");
    }

    assertVetAppointmentStatus(newStatus);

    const appointmentRef = db.collection("vet_appointments").doc(appointmentId);

    // =========================
    // 🔥 TRANSACTION (ONLY UPDATE)
    // =========================
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(appointmentRef);

      if (!snap.exists) {
        throw new HttpsError("not-found", "Appointment not found.");
      }

      const data = snap.data() || {};
      const currentStatus = data.status || "pending";
      // =========================
      // 🛑 PREVENT SAME STATUS UPDATE (FIX ERROR)
      // =========================
      if (currentStatus === newStatus) {
        logger.warn("⚠️ Same status update blocked", {
          appointmentId,
          status: currentStatus,
        });

        return {
          appointmentId,
          oldStatus: currentStatus,
          newStatus,
          businessId,
          skipped: true, // 👈 مهم
        };
      }
      const businessId = data.businessId;

      assertVetAppointmentStatus(currentStatus);

      if (!businessId) {
        throw new HttpsError(
          "failed-precondition",
          "Appointment has no businessId."
        );
      }

      const businessRef = db.collection("businesses").doc(businessId);
      const businessSnap = await tx.get(businessRef);

      if (!businessSnap.exists) {
        throw new HttpsError("not-found", "Business not found.");
      }

      const businessData = businessSnap.data() || {};
      const ownerUid = businessData.ownerUid || businessData.uid;

      if (ownerUid !== uid) {
        throw new HttpsError(
          "permission-denied",
          "Only the vet business owner can update this appointment."
        );
      }

      const allowedNext =
        VET_APPOINTMENT_ALLOWED_TRANSITIONS[currentStatus] || [];

      if (!allowedNext.includes(newStatus)) {
        throw new HttpsError(
          "failed-precondition",
          `Invalid transition: ${currentStatus} → ${newStatus}`
        );
      }

      logger.info("🔥 BEFORE UPDATE", {
        appointmentId,
        currentStatus,
        newStatus,
      });

      tx.update(appointmentRef, {
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedBy: uid,
        lastStatusChange: {
          from: currentStatus,
          to: newStatus,
          by: uid,
          at: admin.firestore.FieldValue.serverTimestamp(),
        },
      });

      logger.info("🔥 AFTER UPDATE", {
        appointmentId,
        newStatus,
      });

      return {
        appointmentId,
        oldStatus: currentStatus,
        newStatus,
        businessId, // 🔥 مهم
      };
    });

    // =========================
    // 🔥 OUTSIDE TRANSACTION
    // =========================

    try {
      const statsRef = db.collection("businesses").doc(result.businessId);

      const countSnap = await db
        .collection("vet_appointments")
        .where("businessId", "==", result.businessId)
        .get();

      await statsRef.set(
        {
          stats: {
            appointmentCount: countSnap.size,
          },
        },
        { merge: true }
      );

      logger.info("📊 Stats updated", {
        businessId: result.businessId,
        count: countSnap.size,
      });
    } catch (err) {
      // ❗ اینجا crash نکن
      logger.error("❌ Stats update failed", err);
    }

    logger.info("✅ Vet appointment status updated", result);

    try {
      const snap = await db
        .collection("vet_appointments")
        .doc(result.appointmentId)
        .get();

      const data = snap.data() || {};
      const userId = data.userId;

      // =========================
      // 🔥 BUILD TITLE & BODY (MOVE OUTSIDE PUSH)
      // =========================

      let title = "Appointment Update";
      let body = "Your appointment status changed";

      if (result.newStatus === "confirmed") {
        title = "Appointment Confirmed ✅";
        body = `${data.serviceTitle || "Service"} is confirmed`;
      } else if (result.newStatus === "rejected") {
        title = "Appointment Rejected ❌";
        body = `Your appointment was rejected`;
      }

      if (userId) {
        // =========================
        // 🔥 SAVE FIRESTORE NOTIFICATION (MISSING PART)
        // =========================
        await db.collection("notifications").add({
          type: "vet_appointment_response",

          recipientUserId: userId,
          senderUserId: result.businessId,

          appointmentId: result.appointmentId,
          status: result.newStatus,

          title,
          body,

          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        const userSnap = await db.collection("users").doc(userId).get();
        const userData = userSnap.data() || {};
        const fcmToken = userData.fcmToken;

        if (fcmToken) {


          await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            data: {
              type: "vet_appointment_response",
              appointmentId: result.appointmentId,
              status: result.newStatus, // 🔥 مهم
            },
          });
        }
      }
    } catch (e) {
      logger.error("❌ notify user failed", e);
    }

    return {
      ok: true,
      ...result,
    };
  }
);


exports.createVetAppointment = onCall(
  { region: "europe-west3" },
  async (request) => {
    try {
      // =========================
      // AUTH
      // =========================
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required.");
      }

      const uid = request.auth.uid;

      const {
        petId,
        petName,
        petType,

        // backward
        dogId,
        dogName,

        businessId,
        businessName,

        serviceId,
        serviceTitle,
        price,
        durationMin,

        scheduledAt,
        note,
      } = request.data || {};

      // =========================
      // NORMALIZE
      // =========================
      const finalPetId = petId || dogId;
      const finalPetName = petName || dogName;
      const finalPetType = petType || "dog";

      if (!finalPetId || !businessId || !scheduledAt) {
        throw new HttpsError(
          "invalid-argument",
          "Missing required fields."
        );
      }

      const scheduledDate = new Date(scheduledAt);

      if (isNaN(scheduledDate.getTime())) {
        throw new HttpsError("invalid-argument", "Invalid date.");
      }

      const scheduledTs =
        admin.firestore.Timestamp.fromDate(scheduledDate);

      const col = db.collection("vet_appointments");

      // =========================
      // DUPLICATE CHECK
      // =========================
      const duplicateSnap = await col
        .where("userId", "==", uid)
        .where("scheduledAt", "==", scheduledTs)
        .limit(1)
        .get();

      if (!duplicateSnap.empty) {
        throw new HttpsError(
          "already-exists",
          "You already have an appointment at this time."
        );
      }

      // =========================
      // VET CONFLICT
      // =========================
      const vetConflictSnap = await col
        .where("businessId", "==", businessId)
        .where("scheduledAt", "==", scheduledTs)
        .where("status", "in", ["pending", "confirmed"])
        .limit(1)
        .get();

      if (!vetConflictSnap.empty) {
        throw new HttpsError(
          "already-exists",
          "This time slot is already booked."
        );
      }

      // =========================
      // CREATE APPOINTMENT
      // =========================
      const docRef = await col.add({
        userId: uid,

        // 🐾 PET
        petId: finalPetId,
        petName: finalPetName,
        petType: finalPetType,
        petBreed: request.data.petBreed || "",
        petAge: request.data.petAge ?? null,

        // backward
        dogId: finalPetId,
        dogName: finalPetName,

        // 🏥 BUSINESS
        businessId,
        businessName,
        vetId: businessId,
        vetName: businessName,

        // 🧾 SERVICE
        serviceId: serviceId || null,
        serviceTitle: serviceTitle || "",
        price: price || 0,
        durationMin: durationMin || 0,

        // ⏱ TIME
        scheduledAt: scheduledTs,

        // 📝 META
        note: note || "",
        status: "pending",

        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),

        isActive: true,
      });

      logger.info("✅ Appointment created:", docRef.id);

      // =========================
      // NOTIFICATION SYSTEM
      // =========================
      try {
        const businessSnap = await db
          .collection("businesses")
          .doc(businessId)
          .get();

        const businessData = businessSnap.data() || {};
        const fcmToken = businessData.fcmToken;

        const title = "New Appointment Request 🐾";
        const body = `${finalPetName} requested ${serviceTitle}`;

        // =========================
        // 1. SAVE IN-APP NOTIFICATION
        // =========================
        await db.collection("notifications").add({
          type: "vet_appointment_request",

          recipientUserId: businessId,
          senderUserId: uid,

          title,
          body,

          appointmentId: docRef.id,

          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logger.info("📦 In-app notification saved");

        // =========================
        // 2. SEND PUSH
        // =========================
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,

            notification: {
              title,
              body,
            },

            data: {
              type: "vet_appointment_request",
              appointmentId: docRef.id,
              businessId: businessId,
            },
          });

          logger.info("🔔 Push sent to vet:", businessId);
        } else {
          logger.warn("⚠️ No FCM token for business:", businessId);
        }

      } catch (e) {
        logger.error("❌ Notification error:", e);
      }

      // =========================
      // RESPONSE
      // =========================
      return {
        ok: true,
        appointmentId: docRef.id,
      };

    } catch (e) {
      logger.error("❌ createVetAppointment FAILED:", e);

      if (e instanceof HttpsError) {
        throw e;
      }

      throw new HttpsError("internal", e.message);
    }
  }
);

exports.syncBusinessToken = onCall(async (req) => {
  const uid = req.auth.uid;
  const token = req.data.token;

  const businessSnap = await db
    .collection('businesses')
    .where('ownerUid', '==', uid)
    .limit(1)
    .get();

  if (!businessSnap.empty) {
    await businessSnap.docs[0].ref.update({
      fcmToken: token,
    });
  }

  return { success: true };
});

exports.createAppointmentCheckout = onCall(
  { region: "europe-west3" },
  async (request) => {
    const uid = request.auth?.uid;
    const { appointmentId } = request.data;

    if (!uid) throw new HttpsError("unauthenticated", "Login required");

    const snap = await db
      .collection("vet_appointments")
      .doc(appointmentId)
      .get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Appointment not found");
    }

    const data = snap.data();

    // 🔥 مهم
    const price = data.price || 100; // fallback

    // 👉 مثل petshop
    const checkout = await iyzipay.checkoutFormInitialize.create({
      locale: "tr",
      conversationId: appointmentId,
      price: price.toString(),
      paidPrice: price.toString(),
      currency: "TRY",

      basketItems: [
        {
          id: appointmentId,
          name: data.serviceTitle || "Vet Service",
          category1: "Vet",
          itemType: "VIRTUAL",
          price: price.toString(),
        },
      ],

      buyer: {
        id: uid,
        name: "User",
        surname: "User",
        email: "test@test.com",
      },

      callbackUrl:
        "https://barkymatches.app/payment-success?appointmentId=" +
        appointmentId,
    });

    return {
      checkoutUrl: checkout.paymentPageUrl,
    };
  }
);

function formatIyziDate(date = new Date()) {
  const pad = (n) => n.toString().padStart(2, "0");

  return (
    date.getFullYear() +
    "-" +
    pad(date.getMonth() + 1) +
    "-" +
    pad(date.getDate()) +
    " " +
    pad(date.getHours()) +
    ":" +
    pad(date.getMinutes()) +
    ":" +
    pad(date.getSeconds())
  );
}

const safe = (val, fallback) => {
  if (!val) return fallback;
  if (typeof val === "string" && val.trim().length === 0) return fallback;
  return val;
};

exports.createAppointmentOrder = onCall(
  {
    region: "europe-west3",
    secrets: [IYZICO_API_KEY, IYZICO_SECRET_KEY],
  },
  async (request) => {
    logger.info("🔥 FUNCTION HIT createAppointmentOrder");

    try {
      logger.info("🔥 RAW REQUEST DATA", request.data);

      // =========================
      // AUTH
      // =========================
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Login required");
      }

      // =========================
      // INPUT
      // =========================
      const appointmentId = request.data?.appointmentId;
      if (!appointmentId) {
        throw new HttpsError("invalid-argument", "appointmentId required");
      }

      // =========================
      // APPOINTMENT
      // =========================
      const snap = await db
        .collection("vet_appointments")
        .doc(appointmentId)
        .get();

      if (!snap.exists) {
        throw new HttpsError("not-found", "Appointment not found");
      }

      const data = snap.data() || {};

      const price = data.price;
      if (!price || price <= 0) {
        throw new HttpsError("failed-precondition", "Invalid price");
      }

      // =========================
      // USER
      // =========================
      const userSnap = await db.collection("users").doc(uid).get();
      const user = userSnap.data() || {};

      const buyer = {
        id: uid,
        name: safe(user.name || user.displayName, "User"),
        surname: safe(user.surname, "User"),
        gsmNumber: safe(user.phone, "+905000000000"),
        email: safe(user.email, "test@email.com"),
        identityNumber: "11111111111",

        registrationAddress: safe(user.address, "Istanbul"),

        ip: request.rawRequest?.ip || "85.34.78.112",
        city: safe(user.city, "Istanbul"),
        country: "Turkey",
        zipCode: safe(user.zipCode, "34000"),

        registrationDate: formatIyziDate(),
        lastLoginDate: formatIyziDate(),
      };

      const address = {
        contactName: `${buyer.name} ${buyer.surname}`,
        city: buyer.city,
        country: buyer.country,
        address: buyer.registrationAddress,
        zipCode: buyer.zipCode,
      };

      // =========================
      // ORDER
      // =========================
      const orderRef = db.collection("orders").doc();

      await orderRef.set({
        type: "appointment",
        appointmentId,
        buyerUid: uid,
        businessId: data.businessId,
        status: "pending",
        paymentStatus: "pending",
        pricing: {
          grandTotal: price,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // =========================
      // IYZICO
      // =========================
      const iyzi = new Iyzipay({
        apiKey: IYZICO_API_KEY.value(),
        secretKey: IYZICO_SECRET_KEY.value(),
        uri: "https://sandbox-api.iyzipay.com",
      });

      const result = await new Promise((resolve, reject) => {
        iyzi.checkoutFormInitialize.create(
          {
            locale: Iyzipay.LOCALE.TR,
            conversationId: orderRef.id,

            price: price.toString(),
            paidPrice: price.toString(),
            currency: "TRY",

            buyer: buyer,
            shippingAddress: address,
            billingAddress: address,

            basketItems: [
              {
                id: appointmentId,
                name: data.serviceTitle || "Vet Appointment",
                category1: "Vet",
                itemType: "VIRTUAL",
                price: price.toString(),
              },
            ],

            callbackUrl:
              "https://barkymatches.app/payment-success?orderId=" +
              orderRef.id,
          },
          (err, res) => {
            if (err) return reject(err);
            resolve(res);
          }
        );
      });

      if (!result || !result.token) {
        logger.error("❌ INVALID IYZICO RESPONSE", result);
        throw new HttpsError("internal", "Iyzi failed");
      }

      await orderRef.update({
        payment: {
          checkoutToken: result.token,
        },
      });

      return {
        orderId: orderRef.id,
        checkoutUrl: result.paymentPageUrl,
      };

    } catch (error) {
      logger.error("❌ FINAL ERROR", error);

      if (error instanceof HttpsError) throw error;

      throw new HttpsError("internal", "Unknown error");
    }
  }
);


exports.activateSubscription = onCall(async (request) => {
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError('unauthenticated', 'User not logged in');
  }

  const { plan, productId } = request.data;

  if (!plan) {
    throw new HttpsError('invalid-argument', 'Missing plan');
  }

  // ✅ 1. ذخیره در collection subscriptions
  await admin.firestore()
    .collection('subscriptions')
    .doc(uid)
    .set({
      plan,
      status: 'active',
      userId: uid,
      startedAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      productId,
    });

  // 🔥🔥🔥 اینجاااااااااااا اضافه کن
  // ✅ 2. sync با users (برای rules و UI)
  await admin.firestore()
    .collection('users')
    .doc(uid)
    .update({
      subscription: {
        plan: plan,
        status: 'active',
        productId: productId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    });

  return { success: true };
});