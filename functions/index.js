
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
const ORDER_EXTERNAL_NOTIFICATIONS_ENABLED = defineSecret(
  "ORDER_EXTERNAL_NOTIFICATIONS_ENABLED"
);



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
  const { skipPush, fallbackToken, ...notificationPayload } = payload || {};

  await db.collection("notifications").add({
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...notificationPayload,
  });

  const recipientUserId =
    notificationPayload?.recipientUserId || notificationPayload?.userId || null;
  const title = notificationPayload?.title || null;
  const body = notificationPayload?.body || null;
  const type = notificationPayload?.type || null;

  if (skipPush) {
    logger.info("🔔 createNotification push skipped by caller", {
      type: type || null,
      recipientUserId: recipientUserId || null,
    });
    return;
  }

  if (!recipientUserId || !title || !body || !type) {
    logger.info("🔔 createNotification push skipped", {
      type: type || null,
      recipientUserId: recipientUserId || null,
      hasTitle: Boolean(title),
      hasBody: Boolean(body),
    });
    return;
  }

  try {
    const userSnap = await db.collection("users").doc(String(recipientUserId)).get();
    const token = userSnap.data()?.fcmToken || fallbackToken || null;

    if (type === "new_paid_order") {
      console.log('🔔 PUSH TYPE = new_paid_order');
      console.log('🔔 RECIPIENT UID =', recipientUserId);
      console.log('🔔 BUSINESS ID =', notificationPayload?.businessId || null);
      console.log('🔔 TOKEN FOUND =', !!token);
      console.log('🔔 TOKEN VALUE =', token);
    }

    if (!token) {
      logger.warn("⚠️ Push token missing", {
        type,
        recipientUserId,
        businessId: notificationPayload?.businessId || null,
        checkedUserToken: userSnap.exists,
        hasFallbackToken: Boolean(fallbackToken),
      });
      return;
    }

    const data = {};
    const addStringField = (key, value) => {
      if (value === undefined || value === null) return;
      if (typeof value === "object") return;
      data[key] = String(value);
    };

    Object.entries(notificationPayload || {}).forEach(([key, value]) => {
      if (["title", "body", "isRead", "createdAt"].includes(key)) return;
      addStringField(key, value);
    });

    if (notificationPayload?.payload && typeof notificationPayload.payload === "object") {
      Object.entries(notificationPayload.payload).forEach(([key, value]) => {
        addStringField(key, value);
      });
    }

    data.type = String(type);

    logger.info("🔔 Playdate/PetTaxi reference sound payload attached", {
      type,
      recipientUserId,
      dataKeys: Object.keys(data),
    });

    const pushPayload = {
      notification: {
        title: String(title),
        body: String(body),
      },
      data,
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
              title: String(title),
              body: String(body),
            },
            sound: "default",
            badge: 1,
            "interruption-level": "time-sensitive",
          },
        },
      },
    };

    if (type === "new_paid_order") {
      console.log('🔔 PUSH PAYLOAD =', JSON.stringify(pushPayload));
      console.log('🔔 ABOUT TO SEND PUSH');
    }

    const sent = await safeSendPush({
      token,
      userId: String(recipientUserId),
      payload: pushPayload,
    });

    if (type === "new_paid_order" && sent) {
      console.log('🔔 PUSH SENT SUCCESS');
    }

    if (type === "new_paid_order" && !sent) {
      console.log('🔔 PUSH SEND FAILED', 'safeSendPush returned false');
    }

    logger.info("🔔 Push send result", {
      type,
      recipientUserId,
      sent,
      soundEnabled: true,
      apnsPayloadAttached: true,
    });
  } catch (error) {
    if (type === "new_paid_order") {
      console.log('🔔 PUSH SEND FAILED', error);
    }
    logger.error("❌ createNotification push failed", {
      type,
      recipientUserId,
      message: error?.message || String(error),
      stack: error?.stack || null,
    });
  }
}

function readBoolEnv(name, defaultValue = false) {
  const value = String(process.env[name] || "").trim().toLowerCase();
  if (!value) return defaultValue;
  return ["1", "true", "yes", "on"].includes(value);
}

function readStringEnv(name, defaultValue = "") {
  const value = String(process.env[name] || "").trim();
  return value || defaultValue;
}

function normalizeExternalNotificationPreference(raw) {
  const value = String(raw || "").trim().toLowerCase();

  if (value === "email" || value === "sms" || value === "both") {
    return value;
  }

  return "email";
}

function resolveExternalNotificationDefaultChannel() {
  const configured = readStringEnv(
    "ORDER_EXTERNAL_NOTIFICATION_DEFAULT_CHANNEL",
    "email"
  ).toLowerCase();

  if (configured === "email") {
    return "email";
  }

  return "email";
}

function resolveExternalNotificationPreference(orderData) {
  const preference =
    orderData?.legal?.notificationPreference ||
    orderData?.notificationPreference ||
    orderData?.orderAddress?.notificationPreference ||
    orderData?.billing?.invoiceDeliveryPreference;

  if (preference) {
    return normalizeExternalNotificationPreference(preference);
  }

  return resolveExternalNotificationDefaultChannel();
}

function formatOrderMoney(value) {
  const text = String(value || "").trim();
  if (!text) return null;

  const numeric = Number(text);
  if (Number.isFinite(numeric)) {
    return `${numeric.toFixed(2)} TL`;
  }

  return text;
}

function resolveOrderBuyerName(orderData, userData = {}) {
  return firstNonEmptyValue(
    orderData?.buyerName,
    orderData?.buyer?.name,
    orderData?.delivery?.fullName,
    userData?.displayName,
    userData?.name
  );
}

function resolveOrderBuyerEmail(orderData, userData = {}) {
  return firstNonEmptyValue(
    orderData?.buyerEmail,
    orderData?.email,
    orderData?.buyer?.email,
    userData?.email
  );
}

function resolveOrderBuyerPhone(orderData, userData = {}) {
  return firstNonEmptyValue(
    orderData?.buyerPhone,
    orderData?.buyer?.phone,
    orderData?.delivery?.phone,
    userData?.phoneNumber,
    userData?.phone
  );
}

function resolveOrderNumber(orderId, orderData = {}) {
  return firstNonEmptyValue(
    orderData?.orderNumber,
    orderData?.rootOrderNumber,
    orderData?.sellerOrderNumber,
    orderId
  );
}

function resolveOrderTotalText(orderData = {}) {
  return formatOrderMoney(
    firstNonEmptyValue(
      orderData?.pricing?.grandTotal,
      orderData?.payment?.paidPrice,
      orderData?.payment?.price,
      orderData?.total
    )
  );
}

function buildExternalNotificationChannels(preference) {
  const normalized = normalizeExternalNotificationPreference(preference);

  return {
    email: normalized === "email" || normalized === "both",
    sms: normalized === "sms" || normalized === "both",
    preference: normalized,
  };
}

async function claimExternalNotificationDispatch({
  dispatchRef,
  orderId,
  source,
  paymentId,
  preference,
  version,
}) {
  const processingStaleAfterMs = 10 * 60 * 1000;

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(dispatchRef);
    const existing = snap.exists ? snap.data() || {} : null;
    const now = Date.now();
    const updatedAtMs = toMillisSafe(existing?.updatedAt);

    if (Number(existing?.version || 0) === version && existing?.state === "sent") {
      return {
        shouldSend: false,
        reason: "already_sent",
        existing,
      };
    }

    if (
      existing?.state === "processing" &&
      updatedAtMs &&
      now - updatedAtMs < processingStaleAfterMs
    ) {
      return {
        shouldSend: false,
        reason: "processing_recent",
        existing,
      };
    }

    const nextAttemptCount = Number(existing?.attemptCount || 0) + 1;

    tx.set(
      dispatchRef,
      {
        orderId,
        type: "payment_success",
        version,
        state: "processing",
        source,
        paymentId: paymentId || null,
        preference,
        attemptCount: nextAttemptCount,
        channels: {
          email: {
            status: "pending",
            sentAt: null,
            messageId: null,
            error: null,
          },
          sms: {
            status: "pending",
            sentAt: null,
            providerSid: null,
            error: null,
            skippedReason: null,
          },
        },
        createdAt:
          existing?.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      shouldSend: true,
      reason: "claimed",
      existing,
    };
  });
}

async function markExternalNotificationDispatch(dispatchRef, patch) {
  await dispatchRef.set(
    {
      ...patch,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function sendOrderPaymentSuccessEmail({
  resend,
  to,
  buyerName,
  orderId,
  orderNumber,
  totalText,
}) {
  if (!to) {
    return {
      status: "skipped",
      skippedReason: "missing_email",
      messageId: null,
      error: null,
    };
  }

  try {
    const greetingName = buyerName || "Değerli müşterimiz";
    const subject = "PetSupo siparişiniz alındı";
    const bodyLines = [
      `Merhaba ${greetingName},`,
      "",
      "Siparişiniz başarıyla alındı.",
      orderNumber ? `Sipariş No: ${orderNumber}` : null,
      totalText ? `Toplam Tutar: ${totalText}` : null,
      "",
      "Teşekkür ederiz.",
      "PetSupo",
    ].filter(Boolean);

    const html = `
      <div style="margin:0;padding:0;background:#f4f6fb;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#f4f6fb;margin:0;padding:0;width:100%;">
          <tr>
            <td align="center" style="padding:24px 12px;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:600px;width:100%;background:#ffffff;border:1px solid #e8ebf2;border-radius:20px;overflow:hidden;">
                <tr>
                  <td style="padding:28px 28px 20px 28px;font-family:Arial,Helvetica,sans-serif;color:#111827;">
                    <div style="font-size:28px;line-height:34px;font-weight:700;letter-spacing:-0.02em;color:#111827;">PetSupo</div>
                    <div style="margin-top:6px;font-size:15px;line-height:22px;color:#6b7280;font-weight:600;">Sipariş Onayı</div>
                  </td>
                </tr>
                <tr>
                  <td style="padding:0 28px 24px 28px;font-family:Arial,Helvetica,sans-serif;">
                    <div style="background:#ecfdf3;border:1px solid #bbf7d0;border-radius:16px;padding:18px 16px;text-align:left;">
                      <div style="font-size:18px;line-height:26px;font-weight:700;color:#166534;">✅ Ödeme Başarıyla Alındı</div>
                    </div>
                  </td>
                </tr>
                <tr>
                  <td style="padding:0 28px 24px 28px;font-family:Arial,Helvetica,sans-serif;color:#111827;">
                    <div style="font-size:16px;line-height:24px;color:#111827;margin:0 0 16px 0;">Merhaba ${greetingName},</div>
                    <div style="font-size:15px;line-height:22px;color:#374151;margin:0 0 20px 0;">Siparişiniz başarıyla alındı. Aşağıda özet bilgileri bulabilirsiniz.</div>

                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;border-collapse:separate;border-spacing:0;background:#f9fafb;border:1px solid #e5e7eb;border-radius:16px;">
                      <tr>
                        <td style="padding:18px 18px 8px 18px;font-family:Arial,Helvetica,sans-serif;">
                          <div style="font-size:13px;line-height:18px;color:#6b7280;font-weight:700;text-transform:uppercase;letter-spacing:0.04em;margin:0 0 4px 0;">Sipariş Bilgileri</div>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:0 18px 18px 18px;font-family:Arial,Helvetica,sans-serif;">
                          <div style="font-size:15px;line-height:22px;color:#111827;margin:0 0 10px 0;"><strong>Sipariş No:</strong> ${orderNumber || "-"}</div>
                          <div style="font-size:15px;line-height:22px;color:#111827;margin:0 0 10px 0;"><strong>Toplam Tutar:</strong> ${totalText || "-"}</div>
                          <div style="font-size:15px;line-height:22px;color:#111827;margin:0 0 10px 0;"><strong>Ödeme Durumu:</strong> Ödeme Başarılı</div>
                          <div style="font-size:15px;line-height:22px;color:#111827;margin:0;"><strong>Kargo Firması:</strong> Hazırlanıyor</div>
                        </td>
                      </tr>
                    </table>

                    <div style="height:24px;line-height:24px;font-size:24px;">&nbsp;</div>

                    <div style="font-size:18px;line-height:26px;font-weight:700;color:#111827;margin:0 0 12px 0;">Bundan sonra ne olacak?</div>
                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="width:100%;">
                      <tr>
                        <td style="padding:0 0 10px 0;font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:22px;color:#374151;">✓ Sipariş satıcıya iletildi</td>
                      </tr>
                      <tr>
                        <td style="padding:0 0 10px 0;font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:22px;color:#374151;">✓ Hazırlık başlayacak</td>
                      </tr>
                      <tr>
                        <td style="padding:0;font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:22px;color:#374151;">✓ Güncellemeler paylaşılacak</td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td style="padding:0 28px 28px 28px;font-family:Arial,Helvetica,sans-serif;">
                    <div style="border-top:1px solid #e5e7eb;padding-top:18px;font-size:14px;line-height:22px;color:#6b7280;">
                      <div style="font-weight:700;color:#111827;">PetSupo Team</div>
                      <div>support@petsupo.com</div>
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </div>
    `;

    const text = bodyLines.join("\n");
    const result = await resend.emails.send({
      from: "PetSupo 🐾 <no-reply@petsupo.com>",
      to,
      subject,
      html,
      text,
    });

    return {
      status: "sent",
      skippedReason: null,
      messageId: result?.data?.id || result?.id || null,
      error: null,
    };
  } catch (error) {
    return {
      status: "failed",
      skippedReason: null,
      messageId: null,
      error: error?.message || String(error),
    };
  }
}

async function sendOrderPaymentSuccessSms({
  to,
  buyerName,
  orderNumber,
  totalText,
}) {
  const smsEnabled = readBoolEnv("ORDER_SMS_ENABLED", false);
  const smsProvider = readStringEnv("ORDER_SMS_PROVIDER", "none").toLowerCase();

  if (!smsEnabled || smsProvider === "none") {
    return {
      status: "skipped",
      skippedReason: "sms_not_configured",
      providerSid: null,
      error: null,
    };
  }

  if (!to) {
    return {
      status: "skipped",
      skippedReason: "missing_phone",
      providerSid: null,
      error: null,
    };
  }

  return {
    status: "skipped",
    skippedReason: "sms_provider_not_implemented",
    providerSid: null,
    error: null,
  };
}

async function sendExternalOrderNotifications({
  orderId,
  orderData,
  source,
  paymentId,
  userId,
}) {
  const externalEnabled = (() => {
    const value = String(
      ORDER_EXTERNAL_NOTIFICATIONS_ENABLED?.value?.() || ""
    )
      .trim()
      .toLowerCase();
    return ["true", "1", "yes", "on"].includes(value);
  })();
  const preference = resolveExternalNotificationPreference(orderData);
  const channels = buildExternalNotificationChannels(preference);
  const dispatchId = `order_${orderId}_payment_success_v1`;
  const dispatchRef = db.collection("external_notification_dispatches").doc(dispatchId);
  const userSnap = userId
    ? await db.collection("users").doc(String(userId)).get()
    : null;
  const userData = userSnap?.exists ? userSnap.data() || {} : {};
  const buyerName = resolveOrderBuyerName(orderData, userData);
  const buyerEmail = resolveOrderBuyerEmail(orderData, userData);
  const buyerPhone = resolveOrderBuyerPhone(orderData, userData);
  const orderNumber = resolveOrderNumber(orderId, orderData);
  const totalText = resolveOrderTotalText(orderData);
  const claim = await claimExternalNotificationDispatch({
    dispatchRef,
    orderId,
    source,
    paymentId,
    preference,
    version: 1,
  });

  if (!claim.shouldSend) {
    if (claim.reason === "already_sent") {
      console.log("ledger already sent", { orderId, source });
    } else if (claim.reason === "processing_recent") {
      console.log("ledger processing recent", { orderId, source });
    } else {
      console.log("external notification dispatch skipped", {
        orderId,
        source,
        reason: claim.reason,
      });
    }
    return;
  }

  if (!externalEnabled) {
    console.log("external notifications disabled", { orderId, source });
    await markExternalNotificationDispatch(dispatchRef, {
      orderId,
      type: "payment_success",
      version: 1,
      state: "skipped",
      source,
      paymentId: paymentId || null,
      preference,
      attemptCount: Number(claim.existing?.attemptCount || 0) + 1,
      channels: {
        email: {
          status: channels.email ? "skipped" : "skipped",
          sentAt: null,
          messageId: null,
          error: null,
          skippedReason: "external_notifications_disabled",
        },
        sms: {
          status: channels.sms ? "skipped" : "skipped",
          sentAt: null,
          providerSid: null,
          error: null,
          skippedReason: "external_notifications_disabled",
        },
      },
    });
    return;
  }

  const resend = new Resend(resendApiKey.value());
  let emailResult = {
    status: "skipped",
    skippedReason: "preference_not_requested",
    messageId: null,
    error: null,
  };
  let smsResult = {
    status: "skipped",
    skippedReason: "preference_not_requested",
    providerSid: null,
    error: null,
  };

  if (channels.email) {
    emailResult = await sendOrderPaymentSuccessEmail({
      resend,
      to: buyerEmail,
      buyerName,
      orderId,
      orderNumber,
      totalText,
    });

    if (emailResult.status === "sent") {
      console.log("email sent", {
        orderId,
        source,
        messageId: emailResult.messageId || null,
      });
    } else if (emailResult.status === "failed") {
      console.error("email failed", {
        orderId,
        source,
        error: emailResult.error || null,
      });
    } else {
      console.log("email skipped", {
        orderId,
        source,
        reason: emailResult.skippedReason || "unknown",
      });
    }
  } else {
    console.log("email skipped", {
      orderId,
      source,
      reason: "preference_not_requested",
    });
  }

  if (channels.sms) {
    smsResult = await sendOrderPaymentSuccessSms({
      to: buyerPhone,
      buyerName,
      orderId,
      orderNumber,
      totalText,
    });

    if (smsResult.status === "sent") {
      console.log("sms sent", {
        orderId,
        source,
        providerSid: smsResult.providerSid || null,
      });
    } else if (smsResult.status === "failed") {
      console.error("sms failed", {
        orderId,
        source,
        error: smsResult.error || null,
      });
    } else {
      console.log("sms skipped", {
        orderId,
        source,
        reason: smsResult.skippedReason || "unknown",
      });
    }
  } else {
    console.log("sms skipped", {
      orderId,
      source,
      reason: "preference_not_requested",
    });
  }

  const requestedChannels = Number(channels.email) + Number(channels.sms);
  const sentChannels = Number(emailResult.status === "sent") + Number(smsResult.status === "sent");
  const failedChannels =
    Number(emailResult.status === "failed") + Number(smsResult.status === "failed");

  let finalState = "skipped";
  if (sentChannels > 0 && failedChannels > 0) {
    finalState = "partial";
  } else if (sentChannels > 0 && requestedChannels === sentChannels && failedChannels === 0) {
    finalState = "sent";
  } else if (sentChannels > 0) {
    finalState = "partial";
  } else if (failedChannels > 0) {
    finalState = "failed";
  }

  await markExternalNotificationDispatch(dispatchRef, {
    orderId,
    type: "payment_success",
    version: 1,
    state: finalState,
    source,
    paymentId: paymentId || null,
    preference,
    attemptCount: Number(claim.existing?.attemptCount || 0) + 1,
    channels: {
      email: {
        status: emailResult.status,
        sentAt: emailResult.status === "sent" ? admin.firestore.FieldValue.serverTimestamp() : null,
        messageId: emailResult.messageId || null,
        error: emailResult.error || null,
        skippedReason: emailResult.skippedReason || null,
      },
      sms: {
        status: smsResult.status,
        sentAt: smsResult.status === "sent" ? admin.firestore.FieldValue.serverTimestamp() : null,
        providerSid: smsResult.providerSid || null,
        error: smsResult.error || null,
        skippedReason: smsResult.skippedReason || null,
      },
    },
  });

  if (finalState === "partial") {
    console.error("external notification partial failure", {
      orderId,
      source,
      emailStatus: emailResult.status,
      smsStatus: smsResult.status,
    });
  } else if (finalState === "failed") {
    console.error("external notification failed", {
      orderId,
      source,
      emailStatus: emailResult.status,
      smsStatus: smsResult.status,
    });
  }
}

function isInvoiceReadyStatus(value) {
  const status = normalizeLower(value);
  return (
    status === "uploaded_valid" ||
    status === "uploaded_with_issues" ||
    status === "approved" ||
    status === "ready"
  );
}

function isInvoiceReadyTransition(beforeData = {}, afterData = {}) {
  const beforeStatus = normalizeLower(beforeData?.invoice?.status);
  const afterStatus = normalizeLower(afterData?.invoice?.status);

  return !isInvoiceReadyStatus(beforeStatus) && isInvoiceReadyStatus(afterStatus);
}

function resolveInvoiceBuyerEmail(orderData = {}, rootOrderData = {}, userData = {}) {
  return firstNonEmptyValue(
    orderData?.buyerEmail,
    orderData?.email,
    orderData?.buyer?.email,
    rootOrderData?.buyerEmail,
    rootOrderData?.email,
    rootOrderData?.buyer?.email,
    userData?.email
  );
}

function resolveInvoiceBuyerName(orderData = {}, rootOrderData = {}, userData = {}) {
  const fullName = firstNonEmptyValue(
    orderData?.buyerName,
    orderData?.buyer?.name,
    orderData?.delivery?.fullName,
    rootOrderData?.buyerName,
    rootOrderData?.buyer?.name,
    rootOrderData?.delivery?.fullName,
    userData?.displayName,
    userData?.name
  );

  if (fullName) {
    return fullName;
  }

  const name = firstNonEmptyValue(
    orderData?.buyer?.firstName,
    rootOrderData?.buyer?.firstName,
    userData?.firstName
  );
  const surname = firstNonEmptyValue(
    orderData?.buyer?.lastName,
    rootOrderData?.buyer?.lastName,
    userData?.lastName
  );

  return firstNonEmptyValue(`${name} ${surname}`.trim());
}

function resolveInvoiceOrderNumber(orderData = {}, rootOrderData = {}, sellerOrderId = "") {
  return firstNonEmptyValue(
    orderData?.rootOrderNumber,
    rootOrderData?.orderNumber,
    orderData?.orderNumber,
    orderData?.sellerOrderNumber,
    sellerOrderId
  );
}

function resolveInvoiceCarrierCompany(orderData = {}, rootOrderData = {}) {
  return firstNonEmptyValue(
    orderData?.shipping?.carrier,
    orderData?.shippingCarrier,
    rootOrderData?.shipping?.carrier,
    rootOrderData?.shippingCarrier,
    "Hazırlanıyor"
  );
}

async function claimInvoiceEmailDispatch({
  dispatchRef,
  sellerOrderId,
  version,
}) {
  const processingStaleAfterMs = 10 * 60 * 1000;

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(dispatchRef);
    const existing = snap.exists ? snap.data() || {} : null;
    const now = Date.now();
    const updatedAtMs = toMillisSafe(existing?.updatedAt);

    if (Number(existing?.version || 0) === version && existing?.state === "sent") {
      return {
        shouldSend: false,
        reason: "already_sent",
        existing,
      };
    }

    if (
      existing?.state === "processing" &&
      updatedAtMs &&
      now - updatedAtMs < processingStaleAfterMs
    ) {
      return {
        shouldSend: false,
        reason: "processing_recent",
        existing,
      };
    }

    const nextAttemptCount = Number(existing?.attemptCount || 0) + 1;

    tx.set(
      dispatchRef,
      {
        sellerOrderId,
        type: "invoice_ready",
        version,
        state: "processing",
        attemptCount: nextAttemptCount,
        channels: {
          email: {
            status: "pending",
            sentAt: null,
            messageId: null,
            error: null,
          },
        },
        createdAt:
          existing?.createdAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return {
      shouldSend: true,
      reason: "claimed",
      existing,
    };
  });
}

async function markInvoiceEmailDispatch(dispatchRef, patch) {
  await dispatchRef.set(
    {
      ...patch,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

async function sendInvoiceReadyEmail({
  resend,
  to,
  buyerName,
  orderNumber,
  carrierCompany,
}) {
  if (!to) {
    return {
      status: "skipped",
      skippedReason: "missing_email",
      messageId: null,
      error: null,
    };
  }

  try {
    const greetingName = buyerName || "Değerli müşterimiz";
    const subject = "Faturanız hazır — PetSupo";
    const bodyLines = [
      `Merhaba ${greetingName},`,
      "",
      "Siparişinizin faturası hazır.",
      orderNumber ? `Sipariş No: ${orderNumber}` : null,
      carrierCompany ? `Kargo Firması: ${carrierCompany}` : null,
      "",
      "Lütfen uygulamayı açarak faturanızın detaylarını görüntüleyin.",
      "",
      "Teşekkür ederiz.",
      "PetSupo",
    ].filter(Boolean);

    const html = `
      <div style="font-family:Arial,sans-serif;background:#f6f7fb;padding:24px;">
        <div style="max-width:560px;margin:auto;background:#ffffff;border-radius:14px;padding:28px;">
          <h2 style="margin:0 0 16px;color:#9E1B4F;">PetSupo</h2>
          <p style="margin:0 0 12px;font-size:15px;color:#222;">Merhaba ${greetingName},</p>
          <p style="margin:0 0 12px;font-size:15px;color:#222;">Siparişinizin faturası hazır.</p>
          ${orderNumber ? `<p style="margin:0 0 8px;font-size:14px;color:#444;">Sipariş No: ${orderNumber}</p>` : ""}
          ${carrierCompany ? `<p style="margin:0 0 8px;font-size:14px;color:#444;">Kargo Firması: ${carrierCompany}</p>` : ""}
          <p style="margin:16px 0 0;font-size:14px;color:#444;">Lütfen uygulamayı açarak faturanızın detaylarını görüntüleyin.</p>
          <p style="margin:16px 0 0;font-size:14px;color:#444;">Teşekkür ederiz.</p>
          <p style="margin:8px 0 0;font-size:14px;color:#444;">PetSupo</p>
        </div>
      </div>
    `;

    const text = bodyLines.join("\n");
    const result = await resend.emails.send({
      from: "PetSupo 🐾 <no-reply@petsupo.com>",
      to,
      subject,
      html,
      text,
    });

    return {
      status: "sent",
      skippedReason: null,
      messageId: result?.data?.id || result?.id || null,
      error: null,
    };
  } catch (error) {
    return {
      status: "failed",
      skippedReason: null,
      messageId: null,
      error: error?.message || String(error),
    };
  }
}

async function isAdminUser(db, uid) {
  if (!uid) return false;

  const snap = await db.collection("users").doc(uid).get();
  return snap.exists && snap.data()?.role === "admin";
}

function addReturnTimelineStep(steps, status, by, note = null, extra = {}) {
  steps.push({
    status,
    at: new Date().toISOString(),
    by,
    ...(note ? { note } : {}),
    ...extra,
  });
}

function normalizeReturnStatus(value) {
  const lower = normalizeLower(value);

  if (lower.includes("approved")) return "approved";
  if (lower.includes("rejected")) return "rejected";
  if (lower.includes("shipped")) return "shipped_back";
  if (lower.includes("received")) return "received_by_seller";
  if (lower.includes("refund_pending")) return "refund_pending";
  if (lower.includes("refund_failed")) return "refund_failed";
  if (lower.includes("refunded")) return "refunded";
  if (lower.includes("cancel")) return "cancelled";

  return "pending";
}

function extractPaymentTransactionIds(value) {
  const list = [];

  const push = (entry) => {
    const id = String(entry || "").trim();
    if (id && !list.includes(id)) {
      list.push(id);
    }
  };

  const visit = (entry) => {
    if (!entry) return;

    if (typeof entry === "string" || typeof entry === "number") {
      push(entry);
      return;
    }

    if (Array.isArray(entry)) {
      for (const item of entry) {
        visit(item);
      }
      return;
    }

    if (typeof entry === "object") {
      push(entry.paymentTransactionId);
      push(entry.iyzicoPaymentTransactionId);
      push(entry.transactionId);
      push(entry.id);

      if (entry.paymentTransactionIds) visit(entry.paymentTransactionIds);
      if (entry.itemTransactions) visit(entry.itemTransactions);
      if (entry.raw && entry.raw !== entry) {
        if (entry.raw.paymentTransactionIds) {
          visit(entry.raw.paymentTransactionIds);
        }
        if (entry.raw.itemTransactions) visit(entry.raw.itemTransactions);
        push(entry.raw.paymentTransactionId);
      }
    }
  };

  visit(value);

  return list;
}

function firstNonEmptyString(...values) {
  for (const value of values) {
    if (value == null) continue;
    const text = String(value).trim();
    if (text) return text;
  }

  return null;
}

function firstPositiveNumber(...values) {
  for (const value of values) {
    const amount = asNumber(value, 0);
    if (amount > 0) return amount;
  }

  return 0;
}

function firstStringArray(...values) {
  for (const value of values) {
    if (!Array.isArray(value)) continue;

    const strings = value
      .map((entry) => String(entry || "").trim())
      .filter(Boolean);

    if (strings.length > 0) return strings;
  }

  return [];
}

function parseLocalizedNumber(value) {
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }

  const raw = String(value || "").trim();
  if (!raw) return null;

  const comma = raw.lastIndexOf(",");
  const dot = raw.lastIndexOf(".");
  let normalized = raw;

  if (comma >= 0 && dot >= 0) {
    normalized = comma > dot
      ? raw.replace(/\./g, "").replace(",", ".")
      : raw.replace(/,/g, "");
  } else if (comma >= 0) {
    normalized = raw.replace(",", ".");
  } else if ((raw.match(/\./g) || []).length > 1) {
    normalized = raw.replace(/\./g, "");
  }

  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : null;
}

function parsePriceFromText(value) {
  if (typeof value === "number") {
    return value > 0 ? roundMoney(value) : null;
  }

  const text = String(value || "");
  const matches = text.match(/\d+(?:[.,]\d+)*/g) || [];

  for (const match of matches) {
    const parsed = parseLocalizedNumber(match);
    if (parsed && parsed > 0) return roundMoney(parsed);
  }

  return null;
}

function durationLabelToMinutes(value) {
  if (typeof value === "number") {
    return value > 0 ? Math.round(value) : 0;
  }

  const text = String(value || "").toLowerCase().trim();
  if (!text) return 0;

  const numberMatch = text.match(/\d+/);
  const amount = numberMatch ? Number(numberMatch[0]) : 0;

  if (text.includes("hour")) return amount > 0 ? amount * 60 : 0;
  if (text.includes("half day")) return 4 * 60;
  if (text.includes("full day")) return 8 * 60;
  if (text.includes("min")) return amount;

  return amount;
}

function formatIyzicoPrice(value) {
  return asNumber(value, 0).toFixed(2);
}

function buildIyzicoAuthorizationHeader({
  apiKey,
  secretKey,
  path,
  bodyJson,
  randomString,
}) {
  const signature = crypto
    .createHmac("sha256", secretKey)
    .update(randomString + path + bodyJson)
    .digest("hex");
  const authorizationParams = [
    `apiKey:${apiKey}`,
    `randomKey:${randomString}`,
    `signature:${signature}`,
  ].join("&");

  return `IYZWSv2 ${Buffer.from(authorizationParams).toString("base64")}`;
}

async function createIyzicoTransactionRefund({
  apiKey,
  secretKey,
  uri,
  request,
}) {
  const path = "/payment/refund";
  const baseUri = String(uri || "").replace(/\/+$/, "");
  const body = Object.fromEntries(
    Object.entries(request || {}).filter(([, value]) => value != null)
  );
  const bodyJson = JSON.stringify(body);
  const randomString = `${process.hrtime()[0]}${Math.random()
    .toString(36)
    .slice(2)}`;

  const response = await fetch(`${baseUri}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      Authorization: buildIyzicoAuthorizationHeader({
        apiKey,
        secretKey,
        path,
        bodyJson,
        randomString,
      }),
      "x-iyzi-rnd": randomString,
      "x-iyzi-client-version": "iyzipay-node-2.0.67",
    },
    body: bodyJson,
  });

  const responseText = await response.text();
  let parsed = null;
  try {
    parsed = responseText ? JSON.parse(responseText) : null;
  } catch (error) {
    parsed = null;
  }

  if (parsed && typeof parsed === "object") {
    return {
      ...parsed,
      httpStatus: response.status,
    };
  }

  return {
    status: "failure",
    httpStatus: response.status,
    errorMessage:
      responseText || `Iyzico refund HTTP ${response.status}`,
    rawBody: responseText || null,
  };
}

function sumReturnItemAmount(returnItems = []) {
  return returnItems.reduce((sum, item) => {
    const lineTotal = asNumber(item?.lineTotal, 0);
    if (lineTotal > 0) {
      return sum + lineTotal;
    }

    const quantity = Math.max(1, asNumber(item?.quantity, 1));
    const unitPrice = asNumber(item?.unitPrice ?? item?.price, 0);
    return sum + quantity * unitPrice;
  }, 0);
}

function resolveReturnShippingResponsibility(values = []) {
  const cleaned = values
    .map((v) => normalizeLower(v))
    .filter(Boolean);

  if (cleaned.includes("buyer")) return "buyer";
  if (cleaned.includes("seller_always")) return "seller";
  if (cleaned.includes("seller_if_contract_carrier")) {
    return "seller_if_contract_carrier";
  }

  return "seller_if_contract_carrier";
}

async function uploadReturnImagesToStorage({
  bucket,
  returnId,
  sellerOrderId,
  images = [],
}) {
  const uploaded = [];

  for (let index = 0; index < images.length; index++) {
    const image = images[index] || {};
    const base64 = String(image.base64 || "");
    if (!base64) continue;

    const buffer = Buffer.from(base64, "base64");
    if (!buffer.length) continue;

    const safeName = String(image.name || `return_${index}.jpg`)
      .replace(/[^\w.\-]/g, "_")
      .slice(0, 120);
    const contentType = String(image.contentType || "image/jpeg");
    const path = `order_returns/${sellerOrderId}/${returnId}/${Date.now()}_${index}_${safeName}`;
    const file = bucket.file(path);

    await file.save(buffer, {
      metadata: { contentType },
      resumable: false,
    });

    await file.makePublic();

    uploaded.push({
      url: `https://storage.googleapis.com/${bucket.name}/${path}`,
      path,
      name: safeName,
      contentType,
    });
  }

  return uploaded;
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
    return false;
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
    return true;

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
    return false;
  }
}

function truncateNotificationPreview(value, maxLength = 120) {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  if (text.length <= maxLength) return text;
  return `${text.slice(0, maxLength - 1).trim()}…`;
}

function firstNonEmptyValue(...values) {
  for (const value of values) {
    const text = String(value || "").trim();
    if (text) return text;
  }
  return "";
}

function firstPushTokenFromData(data = {}) {
  const fields = [
    "fcmToken",
    "deviceToken",
    "notificationToken",
  ];

  for (const field of fields) {
    const token = String(data[field] || "").trim();
    if (token) return token;
  }

  const listFields = [
    "fcmTokens",
    "deviceTokens",
    "notificationTokens",
  ];

  for (const field of listFields) {
    const value = data[field];

    if (Array.isArray(value)) {
      const token = value
        .map((item) => String(item || "").trim())
        .find(Boolean);
      if (token) return token;
    }

    if (value && typeof value === "object") {
      const token = Object.values(value)
        .map((item) => String(item || "").trim())
        .find(Boolean);
      if (token) return token;
    }
  }

  return null;
}

async function safeMessagingSend(message, context = {}) {
  try {
    const response = await admin.messaging().send(message);
    return response;
  } catch (error) {
    console.error("🔔 NOTIFICATION SEND FAILED BUT CONTINUING", {
      ...context,
      code: error?.code || null,
      message: error?.message || String(error),
      stack: error?.stack || null,
    });
    return null;
  }
}

function nonEmptyString(value) {
  const text = value === undefined || value === null
    ? ""
    : String(value).trim();
  return text || null;
}

function hasMeaningfulOwnerSnapshot(profile = {}) {
  return [
    "ownerName",
    "ownerPhone",
    "emergencyContact",
    "emergencyPhone",
    "city",
    "district",
    "address",
    "email",
  ].some((key) => !!nonEmptyString(profile[key]));
}

function completeOwnerProfileSnapshot(profile = {}) {
  return {
    ownerName: nonEmptyString(profile.ownerName) || "",
    ownerPhone: nonEmptyString(profile.ownerPhone) || "",
    emergencyContact: nonEmptyString(profile.emergencyContact) || "",
    emergencyPhone: nonEmptyString(profile.emergencyPhone) || "",
    city: nonEmptyString(profile.city) || "",
    district: nonEmptyString(profile.district) || "",
    address: nonEmptyString(profile.address) || "",
    email: nonEmptyString(profile.email) || "",
  };
}

function normalizeOwnerProfileSnapshot(...sources) {
  const profile = {};

  const mergeValue = (key, value) => {
    const text = nonEmptyString(value);
    if (!text || nonEmptyString(profile[key])) return;
    profile[key] = text;
  };

  const mergeSource = (source) => {
    if (!source || typeof source !== "object") return;

    if (source.ownerProfile && typeof source.ownerProfile === "object") {
      mergeSource(source.ownerProfile);
    }

    ["owner", "user", "client"].forEach((key) => {
      if (source[key] && typeof source[key] === "object") {
        mergeSource(source[key]);
      }
    });

    mergeValue(
      "ownerName",
      source.ownerName ||
      source.ownerDisplayName ||
      source.displayName ||
      source.name ||
      source.fullName ||
      source.userName ||
      source.username
    );
    mergeValue(
      "ownerPhone",
      source.ownerPhone ||
      source.phone ||
      source.phoneNumber ||
      source.userPhone
    );
    mergeValue("emergencyContact", source.emergencyContact);
    mergeValue(
      "emergencyPhone",
      source.emergencyPhone || source.emergencyContactNumber
    );
    mergeValue("city", source.city);
    mergeValue("district", source.district);
    mergeValue("address", source.address || source.registrationAddress);
    mergeValue("email", source.email || source.ownerEmail || source.userEmail);
  };

  sources.forEach(mergeSource);
  return completeOwnerProfileSnapshot(profile);
}

function mergeOwnerProfileSnapshots(existing = {}, incoming = {}) {
  const merged = { ...(existing || {}) };

  Object.entries(incoming || {}).forEach(([key, value]) => {
    const text = nonEmptyString(value);
    if (!text || nonEmptyString(merged[key])) return;
    merged[key] = text;
  });

  return completeOwnerProfileSnapshot(merged);
}

async function buildOwnerProfileSnapshot({
  db,
  ownerId,
  petId,
  appointmentData = {},
  patientData = {},
}) {
  let userData = {};
  let dogData = {};
  const resolvedPetId =
    nonEmptyString(petId) ||
    nonEmptyString(appointmentData.petId) ||
    nonEmptyString(appointmentData.dogId) ||
    nonEmptyString(patientData.petId) ||
    null;

  if (resolvedPetId) {
    try {
      const dogSnap = await db.collection("dogs").doc(resolvedPetId).get();
      dogData = dogSnap.data() || {};
    } catch (error) {
      logger.warn("PATIENT OWNER SNAPSHOT DOG LOOKUP FAILED", {
        petId: resolvedPetId,
        message: error?.message || String(error),
      });
    }
  }

  const resolvedOwnerId = resolvePetOwnerUidFromData({
    explicitOwnerId: ownerId,
    appointmentData,
    patientData,
    dogData,
  });

  logger.info("PATIENT OWNER UID", {
    resolvedOwnerId,
    explicitOwnerId: nonEmptyString(ownerId),
    appointmentUserUid: nonEmptyString(appointmentData.userId),
    appointmentRequesterUid: nonEmptyString(appointmentData.requesterUserId),
    businessOwnerUid: nonEmptyString(appointmentData.businessOwnerUid),
    businessId: nonEmptyString(appointmentData.businessId),
    dogOwnerUid: nonEmptyString(dogData.ownerId),
  });

  if (resolvedOwnerId) {
    try {
      const userSnap = await db.collection("users").doc(resolvedOwnerId).get();
      userData = userSnap.data() || {};
    } catch (error) {
      logger.warn("PATIENT OWNER SNAPSHOT USER LOOKUP FAILED", {
        ownerId: resolvedOwnerId,
        message: error?.message || String(error),
      });
    }
  }

  return normalizeOwnerProfileSnapshot(
    appointmentData,
    patientData,
    dogData,
    userData
  );
}

function resolvePetOwnerUidFromData({
  explicitOwnerId,
  appointmentData = {},
  patientData = {},
  dogData = {},
}) {
  const blocked = new Set([
    nonEmptyString(appointmentData.businessId),
    nonEmptyString(appointmentData.vetId),
    nonEmptyString(appointmentData.businessOwnerUid),
    nonEmptyString(appointmentData.createdByBusinessId),
    nonEmptyString(appointmentData.createdByVetId),
    nonEmptyString(patientData.businessId),
    nonEmptyString(patientData.vetId),
    nonEmptyString(patientData.businessOwnerUid),
    nonEmptyString(patientData.createdByBusinessId),
    nonEmptyString(patientData.createdByVetId),
  ].filter(Boolean));

  const candidates = [
    nonEmptyString(appointmentData.petOwnerUid),
    nonEmptyString(appointmentData.petOwnerId),
    nonEmptyString(patientData.petOwnerUid),
    nonEmptyString(patientData.petOwnerId),
    nonEmptyString(dogData.ownerId),
    nonEmptyString(dogData.userId),
    nonEmptyString(appointmentData.requesterUserId),
    nonEmptyString(appointmentData.requesterUid),
    nonEmptyString(explicitOwnerId),
    nonEmptyString(appointmentData.ownerId),
    nonEmptyString(appointmentData.userId),
    nonEmptyString(appointmentData.clientUserId),
    nonEmptyString(patientData.ownerId),
    nonEmptyString(patientData.userId),
    nonEmptyString(patientData.clientUserId),
  ];

  return candidates.find((uid) => uid && !blocked.has(uid)) || null;
}

async function syncVetPatientVisitAfterPaid({
  db,
  appointmentId,
  appointmentData,
}) {
  try {
    const businessId = appointmentData.businessId || null;
    const petId = appointmentData.petId || null;
    const dogDataForOwner = petId
      ? (await db.collection("dogs").doc(String(petId)).get()).data() || {}
      : {};
    const ownerId = resolvePetOwnerUidFromData({
      appointmentData,
      dogData: dogDataForOwner,
    });

    logger.info("APPOINTMENT USER UID", {
      appointmentId,
      userId: nonEmptyString(appointmentData.userId),
      requesterUserId: nonEmptyString(appointmentData.requesterUserId),
      petOwnerUid: nonEmptyString(appointmentData.petOwnerUid),
    });
    logger.info("BUSINESS OWNER UID", {
      appointmentId,
      businessId: nonEmptyString(appointmentData.businessId),
      businessOwnerUid: nonEmptyString(appointmentData.businessOwnerUid),
      vetId: nonEmptyString(appointmentData.vetId),
    });
    logger.info("DOG OWNER UID", {
      appointmentId,
      petId,
      dogOwnerUid: nonEmptyString(dogDataForOwner.ownerId),
    });

    if (!businessId || !ownerId || !petId) {
      logger.warn("⚠️ VET PATIENT VISIT SYNC SKIPPED", {
        appointmentId,
        businessId,
        ownerId,
        petOwnerUid: ownerId,
        petId,
      });
      return;
    }

    const petName =
      appointmentData.petName ||
      appointmentData.dogName ||
      "Unnamed pet";
    const breed =
      appointmentData.breed ||
      appointmentData.petBreed ||
      "Breed not set";
    const ownerName =
      appointmentData.userName ||
      appointmentData.ownerName ||
      "Owner";

    const patientsRef = db
      .collection("businesses")
      .doc(String(businessId))
      .collection("patients");

    const existingPatient = await patientsRef
      .where("petId", "==", petId)
      .limit(1)
      .get();

    let patientRef;
    let patientId;

    if (!existingPatient.empty) {
      patientRef = existingPatient.docs[0].ref;
      patientId = existingPatient.docs[0].id;
      const existingPatientData = existingPatient.docs[0].data() || {};
      const ownerProfileSnapshot = await buildOwnerProfileSnapshot({
        db,
        ownerId,
        petId,
        appointmentData,
        patientData: existingPatientData,
      });
      const mergedOwnerProfile = mergeOwnerProfileSnapshots(
        existingPatientData.ownerProfile || {},
        ownerProfileSnapshot
      );

      await patientRef.set({
        businessId,
        ownerId,
        petOwnerUid: ownerId,
        petId,
        petName,
        breed,
        ownerName,
        ...(hasMeaningfulOwnerSnapshot(mergedOwnerProfile)
          ? {
            ownerProfile: mergedOwnerProfile,
            ownerProfileUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }
          : {}),
        lastVisitAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      if (hasMeaningfulOwnerSnapshot(mergedOwnerProfile)) {
        logger.info("PATIENT OWNER SNAPSHOT MERGED", {
          appointmentId,
          patientId,
          petId,
          businessId,
        });
      }

      logger.info("🩺 PATIENT RECORD UPDATED", {
        appointmentId,
        patientId,
        petId,
        businessId,
      });
    } else {
      patientRef = patientsRef.doc();
      patientId = patientRef.id;
      const ownerProfileSnapshot = await buildOwnerProfileSnapshot({
        db,
        ownerId,
        petId,
        appointmentData,
      });

      await patientRef.set({
        businessId,
        ownerId,
        petId,
        petName,
        breed,
        ownerName,
        ...(hasMeaningfulOwnerSnapshot(ownerProfileSnapshot)
          ? {
            ownerProfile: ownerProfileSnapshot,
            ownerProfileUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }
          : {}),
        notes: "",
        needsFollowUp: false,
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastVisitAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (hasMeaningfulOwnerSnapshot(ownerProfileSnapshot)) {
        logger.info("PATIENT OWNER SNAPSHOT SAVED", {
          appointmentId,
          patientId,
          petId,
          businessId,
        });
      }

      logger.info("🩺 PATIENT RECORD UPDATED", {
        appointmentId,
        patientId,
        petId,
        businessId,
        created: true,
      });
    }

    const visitRef = patientRef
      .collection("visits")
      .doc(String(appointmentId));

    await visitRef.set({
      appointmentId,
      title:
        appointmentData.serviceTitle ||
        appointmentData.serviceName ||
        "Veterinary Visit",
      summary: "Appointment payment completed successfully.",
      diagnosis: "",
      treatment: "",
      followUpRequired: false,
      paymentStatus: "paid",
      status: "confirmed_paid",
      visitDate: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    logger.info("🩺 VISIT AUTO CREATED", {
      appointmentId,
      patientId,
      petId,
    });
  } catch (error) {
    logger.error("❌ VET PATIENT VISIT SYNC FAILED", {
      appointmentId,
      message: error?.message || String(error),
      stack: error?.stack || null,
    });
  }
}

async function sendBusinessChatPush({
  token,
  payload,
  recipientRole,
  recipientDocRef,
}) {
  if (!token) {
    console.log("💼 BUSINESS CHAT TOKEN FOUND", false);
    return false;
  }

  console.log("💼 BUSINESS CHAT TOKEN FOUND", true);
  console.log("💼 BUSINESS CHAT PUSH PAYLOAD", JSON.stringify(payload));

  const message = {
    token,
    ...payload,
    apns: {
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
    },
  };

  try {
    const response = await admin.messaging().send(message);
    console.log("💼 BUSINESS CHAT PUSH SENT OK", response);
    return true;
  } catch (error) {
    console.error("💼 BUSINESS CHAT PUSH ERROR", error);

    if (
      recipientDocRef &&
      (
        error.code === "messaging/registration-token-not-registered" ||
        error.code === "messaging/invalid-registration-token"
      )
    ) {
      await recipientDocRef.set({
        fcmToken: admin.firestore.FieldValue.delete(),
      }, { merge: true });

      console.log("💼 BUSINESS CHAT INVALID TOKEN REMOVED", recipientRole);
    }

    return false;
  }
}

exports.onChatMessageCreated = onDocumentCreated(
  {
    region: "europe-west3",
    document: "chats/{chatId}/messages/{messageId}",
  },
  async (event) => {
    const messageData = event.data?.data() || {};
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const senderId = String(messageData.senderId || "").trim();
    const rawText = String(messageData.text || "").trim();

    console.log("💬 CHAT PUSH START", {
      chatId,
      messageId,
      senderId,
      hasText: rawText.length > 0,
    });

    if (!senderId || !rawText) {
      console.log("💬 CHAT PUSH SKIPPED", "missing senderId/text");
      return;
    }

    const chatSnap = await db.collection("chats").doc(chatId).get();
    if (!chatSnap.exists) {
      console.log("💬 CHAT PUSH SKIPPED", "chat not found");
      return;
    }

    const chatData = chatSnap.data() || {};
    const participants = Array.isArray(chatData.participants)
      ? chatData.participants.map((id) => String(id || "").trim()).filter(Boolean)
      : [];
    const recipientUserId = firstNonEmptyValue(
      messageData.receiverId,
      participants.find((id) => id && id !== senderId)
    );

    if (!recipientUserId || recipientUserId === senderId) {
      console.log("💬 CHAT PUSH SKIPPED", {
        reason: "recipient not resolved",
        chatId,
        messageId,
        senderId,
        recipientUserId,
      });
      return;
    }

    const senderSnap = await db.collection("users").doc(senderId).get();
    const senderData = senderSnap.data() || {};
    const participantNames = chatData.participantNames || {};
    const senderName = firstNonEmptyValue(
      senderData.username,
      senderData.displayName,
      senderData.name,
      senderData.fullName,
      messageData.senderName,
      participantNames[senderId],
      "PetSupo user"
    );

    const recipientSnap = await db.collection("users").doc(recipientUserId).get();
    const token = recipientSnap.data()?.fcmToken || null;
    const preview = truncateNotificationPreview(rawText);

    const payload = {
      notification: {
        title: `${senderName} sent you a message`,
        body: preview,
      },
      data: {
        type: "chat_message",
        chatId: String(chatId),
        conversationId: String(chatId),
        messageId: String(messageId),
        senderId: String(senderId),
        senderName: String(senderName),
        recipientUserId: String(recipientUserId),
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "high_importance_channel",
        },
      },
    };

    console.log("💬 CHAT PUSH TOKEN FOUND", !!token);
    console.log("💬 CHAT PUSH PAYLOAD", JSON.stringify(payload));

    if (!token) {
      console.log("💬 CHAT PUSH SKIPPED", {
        reason: "missing token",
        recipientUserId,
      });
      return;
    }

    const sent = await safeSendPush({
      token,
      userId: recipientUserId,
      payload,
    });

    console.log("💬 CHAT PUSH RESULT", {
      chatId,
      messageId,
      recipientUserId,
      sent,
    });
  }
);

exports.onBusinessChatMessageCreated = onDocumentCreated(
  {
    region: "europe-west3",
    document: "business_chats/{chatId}/messages/{messageId}",
  },
  async (event) => {
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const messageData = event.data?.data() || {};
    const senderId = String(messageData.senderId || "").trim();
    const text = String(messageData.text || "").replace(/\s+/g, " ").trim();

    console.log("💼 BUSINESS CHAT PUSH START", {
      chatId,
      messageId,
      senderId,
      hasText: text.length > 0,
    });

    if (!senderId) {
      console.log("💼 BUSINESS CHAT PUSH SKIPPED", "missing senderId");
      return;
    }

    const chatRef = db.collection("business_chats").doc(chatId);
    const chatSnap = await chatRef.get();

    if (!chatSnap.exists) {
      console.log("💼 BUSINESS CHAT PUSH SKIPPED", "chat doc missing");
      return;
    }

    const chatData = chatSnap.data() || {};
    console.log("💼 BUSINESS CHAT DOC FOUND", {
      chatId,
      businessId: chatData.businessId || "",
      clientUserId: chatData.clientUserId || "",
    });

    const businessId = String(chatData.businessId || "").trim();
    const businessName = firstNonEmptyValue(chatData.businessName, "Business");
    const clientUserId = String(chatData.clientUserId || "").trim();
    const clientUserName = firstNonEmptyValue(
      chatData.clientUserName,
      chatData.clientName,
      "Pet Owner"
    );

    let senderRole = String(messageData.senderRole || chatData.lastSenderRole || "").trim();
    if (!senderRole) {
      senderRole = senderId === clientUserId ? "client" : "business";
    }

    if (senderRole !== "client" && senderRole !== "business") {
      console.log("💼 BUSINESS CHAT PUSH SKIPPED", {
        reason: "invalid senderRole",
        senderRole,
      });
      return;
    }

    const recipientRole = senderRole === "client" ? "business" : "client";

    console.log("💼 BUSINESS CHAT RECIPIENT ROLE", {
      senderRole,
      recipientRole,
    });

    let recipientDocRef = null;
    let recipientSnap = null;
    let recipientId = "";

    if (recipientRole === "business") {
      if (!businessId) {
        console.log("💼 BUSINESS CHAT PUSH SKIPPED", "missing businessId");
        return;
      }

      recipientId = businessId;
      recipientDocRef = db.collection("businesses").doc(businessId);
      recipientSnap = await recipientDocRef.get();

      if (!recipientSnap.exists) {
        console.log("💼 BUSINESS CHAT PUSH SKIPPED", "business doc missing");
        return;
      }

      const businessOwnerUid = String(recipientSnap.data()?.ownerUid || "").trim();
      if (businessOwnerUid && businessOwnerUid === senderId) {
        console.log("💼 BUSINESS CHAT PUSH SKIPPED", "sender is business recipient");
        return;
      }
    } else {
      if (!clientUserId) {
        console.log("💼 BUSINESS CHAT PUSH SKIPPED", "missing clientUserId");
        return;
      }

      if (senderId === clientUserId) {
        console.log("💼 BUSINESS CHAT PUSH SKIPPED", "sender is client recipient");
        return;
      }

      recipientId = clientUserId;
      recipientDocRef = db.collection("users").doc(clientUserId);
      recipientSnap = await recipientDocRef.get();

      if (!recipientSnap.exists) {
        console.log("💼 BUSINESS CHAT PUSH SKIPPED", "client user doc missing");
        return;
      }
    }

    const recipientData = recipientSnap.data() || {};
    const token = firstPushTokenFromData(recipientData);
    const preview = truncateNotificationPreview(text || "New message");

    if (!token) {
      console.log("💼 BUSINESS CHAT TOKEN FOUND", false);
      console.log("💼 BUSINESS CHAT PUSH SKIPPED", {
        reason: "missing token",
        recipientRole,
        recipientId,
      });
      return;
    }

    const title = recipientRole === "business"
      ? `${clientUserName} sent you a message`
      : `${businessName} sent you a message`;

    const payload = {
      notification: {
        title,
        body: preview || "New message",
      },
      data: {
        type: "business_chat_message",
        chatId: String(chatId),
        conversationId: String(chatId),
        messageId: String(messageId),
        senderId: String(senderId),
        senderRole: String(senderRole),
        businessId: String(businessId),
        clientUserId: String(clientUserId),
        recipientRole: String(recipientRole),
      },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          channelId: "high_importance_channel",
        },
      },
    };

    await sendBusinessChatPush({
      token,
      payload,
      recipientRole,
      recipientDocRef,
    });
  }
);

function normalizeAppointmentRefundStatus(value) {
  const lower = normalizeLower(value);

  if (lower.includes("success")) return "success";
  if (lower.includes("refunded")) return "success";
  if (lower.includes("refund_failed")) return "refund_failed";
  if (lower.includes("failed")) return "refund_failed";
  if (lower.includes("refund_pending")) return "refund_pending";
  if (lower.includes("pending_manual_review")) return "refund_pending";
  if (lower.includes("pending")) return "refund_pending";

  return lower;
}

function isPaidAppointmentOrder(data = {}) {
  const statuses = [
    data.status,
    data.paymentStatus,
    data.payment?.status,
    data.payment?.paymentStatus,
    data.iyzicoStatus,
    data.payment?.iyzicoStatus,
  ].map((value) => normalizeLower(value));

  const rejected = ["cancelled", "canceled", "failed", "failure", "unpaid"];
  if (statuses.some((status) => rejected.includes(status))) {
    return false;
  }

  return statuses.some((status) =>
    ["paid", "success", "completed", "confirmed_paid"].includes(status)
  );
}

function timestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number") return value;
  if (typeof value === "string") {
    const parsed = new Date(value).getTime();
    return Number.isNaN(parsed) ? 0 : parsed;
  }
  return 0;
}

function newestAppointmentOrderMillis(data = {}) {
  return Math.max(
    timestampMillis(data.paidAt),
    timestampMillis(data.payment?.paidAt),
    timestampMillis(data.updatedAt),
    timestampMillis(data.createdAt)
  );
}

function extractAppointmentOrderMeta(doc, collectionName) {
  const data = doc.data() || {};
  const payment = data.payment || {};
  const rawPayment = payment.raw || {};
  const paymentTransactionIds = extractPaymentTransactionIds(
    [
      payment.paymentTransactionIds,
      payment.itemTransactions,
      rawPayment.paymentTransactionIds,
      rawPayment.itemTransactions,
      data.paymentTransactionIds,
      data.itemTransactions,
    ]
  );
  const paymentTransactionId = firstNonEmptyString(
    payment.paymentTransactionId ||
    payment.iyzicoPaymentTransactionId ||
    rawPayment.paymentTransactionId ||
    data.paymentTransactionId ||
    data.iyzicoPaymentTransactionId ||
    (paymentTransactionIds.length > 0 ? paymentTransactionIds[0] : null)
  );
  const paymentId = firstNonEmptyString(
    payment.paymentId,
    rawPayment.paymentId,
    data.paymentId,
    data.iyzicoPaymentId
  );
  const conversationId = firstNonEmptyString(
    payment.conversationId,
    rawPayment.conversationId,
    data.conversationId,
    doc.id
  );
  const currency = firstNonEmptyString(
    payment.currency,
    rawPayment.currency,
    data.currency,
    data.pricing?.currency,
    "TRY"
  ).toUpperCase();
  const refundAmount = Number(
    firstPositiveNumber(
      payment.paidPrice,
      rawPayment.paidPrice,
      payment.price,
      rawPayment.price,
      data.paidPrice,
      data.price,
      data.pricing?.grandTotal,
      data.pricing?.price
    ).toFixed(2)
  );

  return {
    orderId: doc.id,
    orderCollection: collectionName,
    orderData: data,
    paymentId,
    paymentTransactionId,
    paymentTransactionIds,
    conversationId,
    currency,
    refundAmount,
    formattedPrice: formatIyzicoPrice(refundAmount),
    paidSortMillis: newestAppointmentOrderMillis(data),
  };
}

async function loadAppointmentOrderCandidates(collectionName, appointmentId) {
  const snap = await db
    .collection(collectionName)
    .where("appointmentId", "==", appointmentId)
    .limit(20)
    .get();

  return snap.docs.map((doc) => extractAppointmentOrderMeta(doc, collectionName));
}

async function resolveVetAppointmentPaymentMeta(appointmentId) {
  const appointmentOrderCandidates =
    await loadAppointmentOrderCandidates("appointment_orders", appointmentId);
  const legacyOrderCandidates =
    appointmentOrderCandidates.length > 0
      ? []
      : await loadAppointmentOrderCandidates("orders", appointmentId);

  const candidates = [...appointmentOrderCandidates, ...legacyOrderCandidates];

  if (candidates.length > 1) {
    logger.warn("⚠️ MULTIPLE APPOINTMENT ORDER MATCHES", {
      appointmentId,
      orderIds: candidates.map((candidate) => candidate.orderId),
      orderCollections: candidates.map((candidate) => candidate.orderCollection),
    });
  }

  const paidCandidates = candidates
    .filter((candidate) => isPaidAppointmentOrder(candidate.orderData))
    .sort((a, b) => b.paidSortMillis - a.paidSortMillis);

  const selected = paidCandidates[0] || null;

  logger.info("🩺 RESOLVED REFUND PAYMENT META", {
    appointmentId,
    candidateCount: candidates.length,
    paidCandidateCount: paidCandidates.length,
    selectedOrderId: selected?.orderId || null,
    selectedOrderCollection: selected?.orderCollection || null,
    selectedPaymentId: selected?.paymentId || null,
    selectedConversationId: selected?.conversationId || null,
    selectedPaymentTransactionId: selected?.paymentTransactionId || null,
    selectedRefundAmount: selected?.refundAmount || null,
    selectedFormattedPrice: selected?.formattedPrice || null,
    selectedCurrency: selected?.currency || null,
  });

  if (selected) {
    logger.info("🩺 REFUND TARGET ORDER", {
      appointmentId,
      orderId: selected.orderId,
      orderCollection: selected.orderCollection,
      paymentId: selected.paymentId || null,
      conversationId: selected.conversationId || null,
      paymentTransactionId: selected.paymentTransactionId || null,
      paymentTransactionIds: selected.paymentTransactionIds || [],
      refundAmount: selected.refundAmount || null,
      formattedPrice: selected.formattedPrice || null,
      currency: selected.currency || null,
    });
  }

  return selected || {
    paymentId: null,
    paymentTransactionId: null,
    paymentTransactionIds: [],
    conversationId: null,
    orderId: null,
    orderData: {},
    currency: "TRY",
    refundAmount: 0,
    formattedPrice: "0.00",
  };
}

async function resolveVetAppointmentRefundContext(db, appointmentId, appointmentData = {}) {
  const paymentMeta = await resolveVetAppointmentPaymentMeta(appointmentId);
  const orderData = paymentMeta.orderData || {};
  const orderId = paymentMeta.orderId || String(appointmentData.orderId || "").trim() || null;
  const payment = orderData.payment || {};
  const rawPayment = payment.raw || {};
  const appointmentPayment = appointmentData.payment || {};
  const appointmentRawPayment = appointmentPayment.raw || {};
  const refundDetails = appointmentData.refundDetails || {};

  const paymentId = firstNonEmptyString(
    paymentMeta.paymentId,
    payment.paymentId,
    rawPayment.paymentId,
    orderData.paymentId,
    orderData.iyzicoPaymentId,
    appointmentPayment.paymentId,
    appointmentRawPayment.paymentId,
    appointmentData.paymentId,
    appointmentData.iyzicoPaymentId,
    refundDetails.paymentId
  );

  const paymentTransactionIds = extractPaymentTransactionIds(
    [
      paymentMeta.paymentTransactionIds,
      payment.paymentTransactionIds,
      payment.itemTransactions,
      rawPayment.paymentTransactionIds,
      rawPayment.itemTransactions,
      orderData.paymentTransactionIds,
      orderData.itemTransactions,
      appointmentPayment.paymentTransactionIds,
      appointmentPayment.itemTransactions,
      appointmentRawPayment.paymentTransactionIds,
      appointmentRawPayment.itemTransactions,
      appointmentData.paymentTransactionIds,
      appointmentData.itemTransactions,
      refundDetails.paymentTransactionIds,
      refundDetails.itemTransactions,
    ]
  );

  const paymentTransactionId = firstNonEmptyString(
    paymentMeta.paymentTransactionId,
    payment.paymentTransactionId,
    payment.iyzicoPaymentTransactionId,
    rawPayment.paymentTransactionId,
    rawPayment.iyzicoPaymentTransactionId,
    orderData.paymentTransactionId,
    orderData.iyzicoPaymentTransactionId,
    appointmentPayment.paymentTransactionId,
    appointmentPayment.iyzicoPaymentTransactionId,
    appointmentRawPayment.paymentTransactionId,
    appointmentRawPayment.iyzicoPaymentTransactionId,
    appointmentData.paymentTransactionId,
    appointmentData.iyzicoPaymentTransactionId,
    refundDetails.paymentTransactionId,
    refundDetails.iyzicoPaymentTransactionId,
    paymentTransactionIds.length > 0 ? paymentTransactionIds[0] : null
  );

  const currency = firstNonEmptyString(
    paymentMeta.currency ||
    payment.currency ||
    rawPayment.currency ||
    orderData.currency ||
    orderData.pricing?.currency ||
    appointmentPayment.currency ||
    appointmentRawPayment.currency ||
    appointmentData.currency ||
    refundDetails.currency ||
    "TRY"
  ).toUpperCase();

  const refundAmount = Number(
    firstPositiveNumber(
      paymentMeta.refundAmount,
      payment.paidPrice,
      rawPayment.paidPrice,
      payment.price,
      rawPayment.price,
      orderData.paidPrice,
      orderData.price,
      orderData.pricing?.grandTotal,
      orderData.pricing?.price,
      appointmentPayment.paidPrice,
      appointmentRawPayment.paidPrice,
      appointmentPayment.price,
      appointmentRawPayment.price,
      appointmentData.paidPrice,
      appointmentData.price,
      appointmentData.servicePrice,
      refundDetails.refundAmount,
      refundDetails.clampedRefundAmount,
      refundDetails.requestedRefundAmount
    ).toFixed(2)
  );
  const formattedPrice = formatIyzicoPrice(refundAmount);

  const conversationId = firstNonEmptyString(
    paymentMeta.conversationId,
    payment.conversationId,
    rawPayment.conversationId,
    orderData.conversationId,
    appointmentPayment.conversationId,
    appointmentRawPayment.conversationId,
    appointmentData.conversationId,
    refundDetails.conversationId,
    orderId,
    appointmentId
  );

  return {
    orderId,
    orderData,
    paymentId,
    paymentTransactionIds,
    paymentTransactionId,
    conversationId,
    currency,
    refundAmount,
    formattedPrice,
  };
}

async function processVetAppointmentRefund({
  db,
  appointmentId,
  appointmentData,
  beforeData = null,
  eventId = null,
  actorUid = null,
  preserveManualReviewOnFailure = false,
}) {
  const currentStatus = normalizeLower(appointmentData?.status);
  const paymentStatus = normalizeLower(appointmentData?.paymentStatus);
  const refundStatus = normalizeAppointmentRefundStatus(
    appointmentData?.refundStatus
  );
  const isRefunded =
    paymentStatus === "refunded" ||
    refundStatus === "refunded" ||
    refundStatus === "success";

  logger.info("🩺 VET REFUND GATE", {
    appointmentId,
    currentStatus,
    paymentStatus,
    refundStatus,
    eventId: eventId || null,
    actorUid: actorUid || null,
  });

  if (currentStatus !== "cancelled_by_user" || paymentStatus !== "paid") {
    logger.info("🩺 VET REFUND SKIPPED NOT ELIGIBLE", {
      appointmentId,
      currentStatus,
      paymentStatus,
    });
    return { skipped: true, reason: "not_eligible" };
  }

  if (isRefunded) {
    logger.info("🩺 VET REFUND SKIPPED ALREADY REFUNDED", {
      appointmentId,
      paymentStatus,
      refundStatus,
    });
    return { skipped: true, reason: "already_refunded" };
  }

  const existingRequestId = String(appointmentData.refundRequestId || "").trim();
  if (
    existingRequestId &&
    eventId &&
    existingRequestId !== eventId &&
    (refundStatus === "refund_pending" || refundStatus === "refund_processing")
  ) {
    logger.info("🩺 VET REFUND DUPLICATE SKIPPED", {
      appointmentId,
      eventId,
      existingRequestId,
      refundStatus,
    });
    return { skipped: true, reason: "already_processing" };
  }

  const {
    orderId,
    orderData,
    paymentId,
    paymentTransactionIds,
    paymentTransactionId,
    conversationId,
    currency,
    refundAmount,
    formattedPrice,
  } = await resolveVetAppointmentRefundContext(db, appointmentId, appointmentData);
  const appointmentRef = db.collection("vet_appointments").doc(appointmentId);

  if (!paymentTransactionId) {
    const failedAt = admin.firestore.FieldValue.serverTimestamp();
    logger.error("🩺 VET REFUND MISSING PAYMENT META", {
      appointmentId,
      reason: "paymentTransactionId missing",
      orderId: orderId || null,
      paymentId: paymentId || null,
      conversationId: conversationId || null,
      paymentTransactionIds,
      refundAmount,
      formattedPrice,
      currency,
    });
    await appointmentRef.set(
      {
        refundStatus: "refund_failed",
        refundRequired: false,
        refundError: "paymentTransactionId missing",
        refundFailedAt: failedAt,
        updatedAt: failedAt,
        refundDetails: {
          ...(appointmentData.refundDetails || {}),
          status: "refund_failed",
          reason: "paymentTransactionId missing",
          orderId: orderId || null,
          paymentId: paymentId || null,
          conversationId: conversationId || null,
          paymentTransactionId: null,
          paymentTransactionIds,
          refundAmount,
          formattedPrice,
          currency,
        },
      },
      { merge: true }
    );
    return { success: false, reason: "paymentTransactionId missing" };
  }

  if (!(refundAmount > 0)) {
    const failedAt = admin.firestore.FieldValue.serverTimestamp();
    logger.error("🩺 VET REFUND MISSING PAYMENT META", {
      appointmentId,
      reason: "Refund amount must be greater than zero",
      orderId: orderId || null,
      paymentId: paymentId || null,
      paymentTransactionId: paymentTransactionId || null,
      formattedPrice,
      currency,
    });
    await appointmentRef.set(
      {
        refundStatus: "refund_failed",
        refundRequired: false,
        refundError: "Refund amount must be greater than zero",
        refundFailedAt: failedAt,
        updatedAt: failedAt,
        refundDetails: {
          ...(appointmentData.refundDetails || {}),
          status: "refund_failed",
          reason: "Refund amount must be greater than zero",
          orderId: orderId || null,
          paymentId: paymentId || null,
          paymentTransactionId: paymentTransactionId || null,
          paymentTransactionIds,
          refundAmount,
          formattedPrice,
          currency,
        },
      },
      { merge: true }
    );
    return {
      success: false,
      reason: "Refund amount must be greater than zero",
    };
  }

  const existingRetryCount = asNumber(appointmentData.refundRetryCount, 0);
  const retryCount =
    existingRequestId && eventId && existingRequestId === eventId
      ? Math.max(1, existingRetryCount)
      : Math.max(1, existingRetryCount + 1);
  const requestId = eventId || existingRequestId || `${appointmentId}_${Date.now()}`;
  const pendingAt = admin.firestore.FieldValue.serverTimestamp();

  logger.info("🩺 VET REFUND FLOW DETECTED", {
    appointmentId,
    currentStatus,
    paymentStatus,
    refundStatus,
    orderId: orderId || null,
    paymentId: paymentId || null,
    paymentTransactionId: paymentTransactionId || null,
    iyzicoPaymentId: paymentId || null,
    iyzicoPaymentTransactionId: paymentTransactionId || null,
    conversationId: conversationId || null,
    currency,
    refundAmount,
    formattedPrice,
    checkoutToken: appointmentData.checkoutToken || null,
  });

  logger.info("🩺 BYPASSING PETSHOP RETURN FLOW", {
    appointmentId,
    reason: "vet_appointment_direct_refund",
  });

  console.log("🩺 VET REFUND START", {
    appointmentId,
    serviceRequiresPayment:
      appointmentData.serviceRequiresPayment ?? appointmentData.requiresPayment ?? null,
    servicePrice: appointmentData.servicePrice ?? null,
    price: appointmentData.price ?? null,
    refundAmount,
    formattedPrice,
    requiresPayment: true,
  });

  await appointmentRef.set(
    {
      refundRequestId: requestId,
      refundRequestedAt: appointmentData.refundRequestedAt || pendingAt,
      refundStartedAt: pendingAt,
      refundRetryCount: retryCount,
      refundStatus: "refund_processing",
      refundRequired: false,
      refundReason:
        appointmentData.refundReason || "user_cancelled_paid_appointment",
      refundDetails: {
        ...(appointmentData.refundDetails || {}),
        status: "refund_processing",
        retryCount,
        paymentId,
        paymentTransactionId: paymentTransactionId || null,
        paymentTransactionIds,
        currency,
        refundAmount,
        formattedPrice,
        conversationId: conversationId || null,
        orderId,
        appointmentId,
        rawRequest: {
          appointmentId,
          orderId,
          paymentId,
          paymentTransactionId,
          conversationId: conversationId || null,
          refundAmount,
          formattedPrice,
          currency,
          retryCount,
          requestId,
        },
      },
      updatedAt: pendingAt,
    },
    { merge: true }
  );

  logger.info("🩺 VET REFUND MARKED PENDING", {
    appointmentId,
    orderId,
    paymentId,
    paymentTransactionId,
    paymentTransactionIds,
    conversationId: conversationId || null,
    currency,
    refundAmount,
    formattedPrice,
    retryCount,
    requestId,
  });

  try {
    const iyzicoRefundRequest = {
      locale: Iyzipay.LOCALE.TR,
      conversationId: conversationId || appointmentId,
      paymentTransactionId,
      price: formattedPrice,
      currency,
      ip: "85.34.78.112",
    };

    const refundResult = await new Promise((resolve, reject) => {
      logger.info("🩺 IYZICO REFUND START", {
        appointmentId,
        retryCount,
        paymentId,
        paymentTransactionId: paymentTransactionId || null,
        conversationId: conversationId || null,
        currency,
        refundAmount,
        formattedPrice,
      });
      logger.info("🩺 IYZICO REFUND REQUEST", {
        appointmentId,
        retryCount,
        paymentId,
        paymentTransactionId: paymentTransactionId || null,
        paymentTransactionIds,
        currency,
        refundAmount,
        formattedPrice,
        conversationId: conversationId || appointmentId,
        request: iyzicoRefundRequest,
      });

      createIyzicoTransactionRefund({
        apiKey: IYZICO_API_KEY.value(),
        secretKey: IYZICO_SECRET_KEY.value(),
        uri: "https://sandbox-api.iyzipay.com",
        request: iyzicoRefundRequest,
      })
        .then(resolve)
        .catch(reject);
    });

    logger.info("🩺 VET REFUND IYZICO RESPONSE", {
      appointmentId,
      retryCount,
      response: refundResult || null,
    });

    if (!refundResult || normalizeLower(refundResult.status) !== "success") {
      logger.error("🩺 IYZICO REFUND FAILED RESPONSE", {
        appointmentId,
        retryCount,
        status: refundResult?.status || null,
        errorCode: refundResult?.errorCode || null,
        errorMessage: refundResult?.errorMessage || null,
        rawResponse: refundResult || null,
      });

      const failure = new Error(
        refundResult?.errorMessage ||
        refundResult?.errorCode ||
        "Iyzico refund failed"
      );
      failure.iyzicoRefundResult = refundResult || null;
      throw failure;
    }

    const completedAt = admin.firestore.FieldValue.serverTimestamp();
    await appointmentRef.set(
      {
        paymentStatus: "refunded",
        refundStatus: "refunded",
        refundRequired: false,
        refundError: null,
        refundedAt: completedAt,
        refundCompletedAt: completedAt,
        updatedAt: completedAt,
        paymentId: paymentId || appointmentData.paymentId || null,
        orderId: orderId || appointmentData.orderId || null,
        paymentTransactionId: paymentTransactionId || null,
        paymentTransactionIds,
        iyzicoPaymentTransactionId: paymentTransactionId || null,
        refundDetails: {
          ...(appointmentData.refundDetails || {}),
          status: "refunded",
          gatewayStatus: refundResult.status || "success",
          retryCount,
          paymentId: refundResult.paymentId || paymentId || null,
          paymentTransactionId: paymentTransactionId || null,
          paymentTransactionIds,
          refundHostReference: refundResult.refundHostReference || null,
          authCode: refundResult.authCode || null,
          hostReference: refundResult.hostReference || null,
          currency: refundResult.currency || currency,
          price: refundResult.price || formattedPrice,
          refundAmount,
          formattedPrice,
          raw: refundResult,
        },
      },
      { merge: true }
    );

    logger.info("🩺 VET REFUND SUCCESS", {
      appointmentId,
      refundStatus: "refunded",
    });
    logger.info("🩺 IYZICO REFUND SUCCESS", {
      appointmentId,
      paymentId,
      conversationId: conversationId || null,
      refundAmount,
      formattedPrice,
    });
    logger.info("🩺 PAYMENT PRESERVED AFTER CANCELLATION", {
      appointmentId,
      paymentId: paymentId || null,
      orderId: orderId || null,
    });
    logger.info("🩺 VET REFUND COMPLETE", {
      appointmentId,
      paymentId,
      retryCount,
      paymentTransactionId,
      formattedPrice,
    });

    const userId = appointmentData.userId || appointmentData.buyerUid || null;
    const serviceTitle = appointmentData.serviceTitle || "Appointment";
    if (userId) {
      await createNotification(db, {
        recipientUserId: userId,
        userId,
        type: "vet_appointment_refunded",
        title: "Refund completed",
        body: `${serviceTitle} refund has been completed`,
        appointmentId,
        orderId: orderId || appointmentData.orderId || null,
        skipPush: true,
      });

      const userSnap = await db.collection("users").doc(userId).get();
      const fcmToken = userSnap.data()?.fcmToken;
      if (fcmToken) {
        await safeSendPush({
          token: fcmToken,
          userId,
          payload: {
            notification: {
              title: "Refund completed",
              body: `${serviceTitle} refund has been completed`,
            },
            data: {
              type: "vet_appointment_refunded",
              appointmentId,
              status: "cancelled_by_user",
              paymentStatus: "refunded",
              refundStatus: "refunded",
            },
            android: { priority: "high" },
          },
        });
      }
    }

    return {
      success: true,
      paymentTransactionId,
      paymentId: paymentId || null,
      conversationId: conversationId || null,
      refundAmount,
      formattedPrice,
      refundResult,
    };
  } catch (error) {
    const rawIyzicoResponse = error?.iyzicoRefundResult || null;
    const refundError =
      rawIyzicoResponse?.errorMessage ||
      rawIyzicoResponse?.errorCode ||
      error?.errorMessage ||
      error?.errorCode ||
      error?.message ||
      "Iyzico refund failed";

    logger.error("🩺 VET REFUND FAILED", {
      appointmentId,
      retryCount,
      message: refundError,
      stack: error?.stack || null,
    });
    logger.error("🩺 IYZICO REFUND FAILED", {
      appointmentId,
      paymentId,
      paymentTransactionId: paymentTransactionId || null,
      paymentTransactionIds,
      conversationId: conversationId || null,
      currency,
      refundAmount,
      formattedPrice,
      status: rawIyzicoResponse?.status || null,
      errorCode: rawIyzicoResponse?.errorCode || error?.errorCode || null,
      errorMessage: rawIyzicoResponse?.errorMessage || error?.errorMessage || null,
      rawResponse: rawIyzicoResponse,
      message: refundError,
    });

    const failedAt = admin.firestore.FieldValue.serverTimestamp();
    await appointmentRef.set(
      {
        refundStatus: "refund_failed",
        refundError,
        refundFailedAt: failedAt,
        updatedAt: failedAt,
        refundRetryCount: retryCount,
        refundRequired: false,
        refundDetails: {
          ...(appointmentData.refundDetails || {}),
          status: "refund_failed",
          gatewayStatus: rawIyzicoResponse?.status || "failed",
          errorCode: rawIyzicoResponse?.errorCode || error?.errorCode || null,
          errorMessage:
            rawIyzicoResponse?.errorMessage ||
            error?.errorMessage ||
            refundError,
          retryCount,
          paymentId,
          paymentTransactionId: paymentTransactionId || null,
          paymentTransactionIds,
          currency,
          refundAmount,
          formattedPrice,
          conversationId: conversationId || null,
          orderId,
          appointmentId,
          raw: rawIyzicoResponse || null,
          rawError: {
            message: refundError,
            stack: error?.stack || null,
          },
        },
      },
      { merge: true }
    );

    const userId = appointmentData.userId || appointmentData.buyerUid || null;
    if (userId) {
      await createNotification(db, {
        recipientUserId: userId,
        userId,
        type: "vet_appointment_refund_failed",
        title: "Refund failed",
        body: `${appointmentData.serviceTitle || "Appointment"} refund failed`,
        appointmentId,
        orderId: orderId || appointmentData.orderId || null,
      });
    }

    return {
      success: false,
      error: refundError,
    };
  }
}

// =====================================================
// ADOPTION REQUEST STATUS
// =====================================================

const ADOPTION_REQUEST_STATUSES = [
  "pending",
  "approved",
  "rejected",
  "completed",
  "cancelled",
];

const ADOPTION_REQUEST_ALLOWED_TRANSITIONS = {
  pending: [
    "approved",
    "rejected",
    "cancelled",
  ],

  approved: [
    "completed",
    "cancelled",
  ],
};

function assertAdoptionRequestStatus(
  status,
) {
  const normalized = String(
    status || "",
  ).trim();

  if (
    !ADOPTION_REQUEST_STATUSES.includes(
      normalized,
    )
  ) {
    throw new HttpsError(
      "invalid-argument",
      `Invalid adoption request status: ${normalized}`,
    );
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

      // =====================================================
      // NEW BUSINESS-BASED ARCHITECTURE
      // =====================================================

      const businessId = data.businessId;

      if (!businessId) {
        console.error(
          "❌ Missing businessId in adoption request",
        );
        return;
      }

      const requesterName =
        data.requesterName || "Someone";

      const targetType =
        data.targetType || "dog";

      const db = admin.firestore();

      // =====================================================
      // GET BUSINESS OWNER
      // =====================================================

      const businessSnap = await db
        .collection("businesses")
        .doc(businessId)
        .get();

      if (!businessSnap.exists) {
        console.error(
          "❌ Business not found:",
          businessId,
        );
        return;
      }

      const businessData =
        businessSnap.data() || {};

      const businessOwnerUid =
        businessData.ownerUid ||
        businessData.uid;

      if (!businessOwnerUid) {
        console.error(
          "❌ Missing business owner uid:",
          businessId,
        );
        return;
      }

      // =====================================================
      // CREATE FIRESTORE NOTIFICATION
      // =====================================================

      await db.collection("notifications").add({
        recipientUserId:
          businessOwnerUid,

        senderUserId:
          data.requesterUserId || null,

        businessId,

        title:
          "New Adoption Request 🐾",

        body:
          `${requesterName} sent an adoption request`,

        type: "adoption_request",

        requestId,

        targetType,

        isRead: false,

        createdAt:
          admin.firestore.FieldValue.serverTimestamp(),
      });

      // =====================================================
      // GET OWNER TOKEN
      // =====================================================

      const ownerDoc = await db
        .collection("users")
        .doc(businessOwnerUid)
        .get();

      const token =
        ownerDoc.data()?.fcmToken;

      // =====================================================
      // SEND PUSH
      // =====================================================

      await safeSendPush({
        token,

        userId: businessOwnerUid,

        payload: {
          notification: {
            title:
              "New Adoption Request 🐾",

            body:
              `${requesterName} sent an adoption request`,
          },

          data: {
            type:
              "adoption_request",

            requestId,

            businessId,
          },

          android: {
            priority: "high",
          },

          apns: {
            headers: {
              "apns-priority": "10",
            },

            payload: {
              aps: {
                alert: {
                  title:
                    "New Adoption Request 🐾",

                  body:
                    `${requesterName} sent an adoption request`,
                },

                sound: "default",

                badge: 1,
              },
            },
          },
        },
      });

      console.log(
        "✅ Adoption request push sent:",
        requestId,
      );
    } catch (err) {
      console.error(
        "❌ onAdoptionRequestCreated error:",
        err,
      );
    }
  },
);

/* =====================================================
 * 🐶 UPDATE ADOPTION REQUEST STATUS
 * ===================================================== */

exports.updateAdoptionRequestStatus =
  onCall(
    {
      region: "europe-west3",
    },

    async (request) => {
      // =====================================================
      // AUTH
      // =====================================================

      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "Login required",
        );
      }

      const uid = request.auth.uid;

      // =====================================================
      // INPUT
      // =====================================================

      const requestId =
        request.data?.requestId;

      const newStatus = String(
        request.data?.newStatus || "",
      ).trim();

      if (!requestId) {
        throw new HttpsError(
          "invalid-argument",
          "requestId required",
        );
      }

      if (!newStatus) {
        throw new HttpsError(
          "invalid-argument",
          "newStatus required",
        );
      }

      assertAdoptionRequestStatus(
        newStatus,
      );

      // =====================================================
      // REQUEST
      // =====================================================

      const requestRef = db
        .collection(
          "adoption_requests",
        )
        .doc(requestId);

      const snap =
        await requestRef.get();

      if (!snap.exists) {
        throw new HttpsError(
          "not-found",
          "Request not found",
        );
      }

      const data = snap.data() || {};

      const currentStatus =
        data.status || "pending";

      assertAdoptionRequestStatus(
        currentStatus,
      );

      // =====================================================
      // BUSINESS
      // =====================================================

      const businessId =
        data.businessId;

      if (!businessId) {
        throw new HttpsError(
          "failed-precondition",
          "Missing businessId",
        );
      }

      const businessSnap =
        await db
          .collection("businesses")
          .doc(businessId)
          .get();

      if (!businessSnap.exists) {
        throw new HttpsError(
          "not-found",
          "Business not found",
        );
      }

      const businessData =
        businessSnap.data() || {};

      const businessOwnerUid =
        businessData.ownerUid ||
        businessData.uid;

      if (
        businessOwnerUid !== uid
      ) {
        throw new HttpsError(
          "permission-denied",
          "Only business owner can update requests",
        );
      }

      // =====================================================
      // VALIDATE TRANSITION
      // =====================================================

      const allowedNext =
        ADOPTION_REQUEST_ALLOWED_TRANSITIONS[
        currentStatus
        ] || [];

      if (
        !allowedNext.includes(
          newStatus,
        )
      ) {
        throw new HttpsError(
          "failed-precondition",
          `Invalid transition: ${currentStatus} → ${newStatus}`,
        );
      }

      // =====================================================
      // UPDATE
      // =====================================================

      await requestRef.update({
        status: newStatus,

        updatedAt:
          admin.firestore.FieldValue.serverTimestamp(),

        statusUpdatedAt:
          admin.firestore.FieldValue.serverTimestamp(),

        statusUpdatedBy: uid,

        lastStatusChange: {
          from: currentStatus,
          to: newStatus,
          by: uid,
          at: admin.firestore.FieldValue.serverTimestamp(),
        },
      });

      // =====================================================
      // NOTIFICATION
      // =====================================================

      const requesterUserId =
        data.requesterUserId ||
        data.userId;

      if (requesterUserId) {
        let title =
          "Adoption Request Updated";

        let body =
          "Your adoption request status changed";

        let type =
          "adoption_request_update";

        if (
          newStatus === "approved"
        ) {
          title =
            "Adoption Approved ✅";

          body =
            "Your adoption request was approved";

          type =
            "adoption_request_approved";
        }

        else if (
          newStatus === "rejected"
        ) {
          title =
            "Adoption Rejected ❌";

          body =
            "Your adoption request was rejected";

          type =
            "adoption_request_rejected";
        }

        else if (
          newStatus === "completed"
        ) {
          title =
            "Adoption Completed 🎉";

          body =
            "Adoption completed successfully";

          type =
            "adoption_request_completed";
        }

        else if (
          newStatus === "cancelled"
        ) {
          title =
            "Adoption Cancelled";

          body =
            "Adoption request cancelled";

          type =
            "adoption_request_cancelled";
        }

        // =====================================================
        // FIRESTORE NOTIFICATION
        // =====================================================

        await db
          .collection(
            "notifications",
          )
          .add({
            recipientUserId:
              requesterUserId,

            senderUserId: uid,

            businessId,

            requestId,

            type,

            status: newStatus,

            title,

            body,

            isRead: false,

            createdAt:
              admin.firestore.FieldValue.serverTimestamp(),
          });

        // =====================================================
        // PUSH
        // =====================================================

        try {
          const userSnap =
            await db
              .collection(
                "users",
              )
              .doc(
                requesterUserId,
              )
              .get();

          const token =
            userSnap.data()
              ?.fcmToken;

          if (token) {
            await safeSendPush({
              token,

              userId:
                requesterUserId,

              payload: {
                notification: {
                  title,
                  body,
                },

                data: {
                  type,
                  requestId,
                  businessId,
                  status:
                    newStatus,
                },

                android: {
                  priority:
                    "high",
                },
              },
            });
          }
        } catch (pushError) {
          logger.error(
            "❌ Adoption push failed",
            {
              requestId,
              message:
                pushError?.message ||
                String(
                  pushError,
                ),
            },
          );
        }
      }

      logger.info(
        "✅ Adoption request updated",
        {
          requestId,
          oldStatus:
            currentStatus,
          newStatus,
        },
      );

      return {
        ok: true,
        requestId,
        oldStatus:
          currentStatus,
        newStatus,
      };
    },
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

      const type = lostDogId ? "lost_pet" : "found_pet";

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
          ...(lostDogId && { lostPetId: String(lostDogId) }),
          ...(foundDogId && { foundDogId: String(foundDogId) }),
          ...(foundDogId && { foundPetId: String(foundDogId) }),
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
          ...(lostDogId && { lostPetId: String(lostDogId) }),
          ...(foundDogId && { foundDogId: String(foundDogId) }),
          ...(foundDogId && { foundPetId: String(foundDogId) }),

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
        type: lostDogId ? "lost_pet" : "found_pet",
        ...(lostDogId && { lostDogId: lostDogId.toString() }),
        ...(lostDogId && { lostPetId: lostDogId.toString() }),
        ...(foundDogId && { foundDogId: foundDogId.toString() }),
        ...(foundDogId && { foundPetId: foundDogId.toString() }),
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
        type: lostDogId ? "lost_pet" : "found_pet",
        ...(lostDogId && { lostDogId: lostDogId.toString() }),
        ...(lostDogId && { lostPetId: lostDogId.toString() }),
        ...(foundDogId && { foundDogId: foundDogId.toString() }),
        ...(foundDogId && { foundPetId: foundDogId.toString() }),
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

exports.sendVaccineCompletedPush = onCall(
  { region: "europe-west3", cors: true, enforceAppCheck: false },
  async (request) => {
    const {
      ownerId,
      vaccineName,
      businessId,
      patientId,
      vaccineId,
    } = request.data || {};

    if (!request.auth?.uid) {
      logger.warn("sendVaccineCompletedPush unauthenticated");
      return { success: false, reason: "unauthenticated" };
    }

    if (!ownerId || !vaccineName || !businessId || !patientId || !vaccineId) {
      logger.warn("sendVaccineCompletedPush invalid payload", {
        ownerId,
        vaccineName,
        businessId,
        patientId,
        vaccineId,
      });
      return { success: false, reason: "invalid-payload" };
    }

    try {
      const userSnap = await db.collection("users").doc(String(ownerId)).get();
      const token = userSnap.data()?.fcmToken || null;

      if (!token) {
        logger.info("sendVaccineCompletedPush missing token", { ownerId });
        return { success: false, reason: "missing-token" };
      }

      const body = `${String(vaccineName)} vaccine has been completed.`;
      const payload = {
        token,
        notification: {
          title: "Vaccination Completed",
          body,
        },
        data: {
          type: "vaccine_completed",
          ownerId: String(ownerId),
          businessId: String(businessId),
          patientId: String(patientId),
          vaccineId: String(vaccineId),
        },
        android: {
          priority: "high",
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(payload);
      logger.info("sendVaccineCompletedPush sent", {
        ownerId,
        vaccineId,
        response,
      });

      return { success: true };
    } catch (error) {
      logger.error("sendVaccineCompletedPush failed", toPlainError(error));
      return { success: false, reason: "push-failed" };
    }
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
      const sectorData = draft.sectorData || {};
      const veterinaryData = sectorData.veterinary || {};
      const veterinaryProfile = veterinaryData.profileContent || {};
      const veterinarySocial = veterinaryProfile.socialMedia || {};
      const veterinaryServices = veterinaryData.services || {};
      const groomingData = sectorData.grooming || sectorData.groomer || {};
      const groomingProfile = groomingData.profileContent || groomingData.media || {};
      const groomingSocial = groomingProfile.socialMedia || groomingData.contact || {};
      const groomingServices = groomingData.services || {};
      const hotelData = sectorData.pet_hotel || sectorData.hotel || sectorData.petHotel || {};
      const hotelProfile = hotelData.profileContent || hotelData.media || {};
      const hotelSocial = hotelProfile.socialMedia || hotelData.contact || {};
      const hotelServices = hotelData.services || {};
      const petTaxiData = sectorData.pet_taxi || sectorData.petTaxi || {};
      const adoptionData =
        sectorData.adoptionCenter ||
        sectorData.adoption_center ||
        {};

      const adoptionProfile =
        adoptionData.profileContent ||
        adoptionData.media ||
        {};

      const adoptionSocial =
        adoptionProfile.socialMedia ||
        adoptionData.contact ||
        {};

      const adoptionServices =
        adoptionData.services ||
        {};
      const veterinaryImages = firstStringArray(
        veterinaryProfile.clinicPhotoUrls,
        veterinaryProfile.images
      );
      const groomingImages = firstStringArray(
        groomingProfile.clinicPhotoUrls,
        groomingProfile.images,
        groomingProfile.photos,
        groomingData.media?.photos
      );
      const hotelImages = firstStringArray(
        hotelProfile.clinicPhotoUrls,
        hotelProfile.images,
        hotelProfile.photos,
        hotelData.coverImage
      );
      const adoptionImages = firstStringArray(
        adoptionProfile.photoUrls,
        adoptionProfile.images,
        adoptionProfile.photos,
        adoptionData.coverImage
      );
      const businessImages =
        veterinaryImages.length > 0
          ? veterinaryImages
          : groomingImages.length > 0
            ? groomingImages
            : hotelImages.length > 0
              ? hotelImages
              : adoptionImages;
      const profileLogoUrl = firstNonEmptyString(
        profile.logoUrl,
        veterinaryProfile.clinicLogoUrl,
        groomingProfile.clinicLogoUrl,
        groomingProfile.logo,
        groomingData.logo,
        adoptionProfile.logoUrl,
        adoptionProfile.logo,
        adoptionData.logo,
        hotelProfile.clinicLogoUrl,
        hotelProfile.logo,
        hotelData.logo
      );
      const coverImageUrl = firstNonEmptyString(
        profile.coverImageUrl,
        profile.coverUrl,
        veterinaryProfile.coverImageUrl,
        groomingProfile.coverImageUrl,
        groomingData.coverImage,
        hotelProfile.coverImageUrl,
        hotelData.coverImage,
        adoptionProfile.coverImageUrl,
        adoptionData.coverImage,
        businessImages[0]
      );
      const contactInstagram = firstNonEmptyString(
        contact.instagram,
        veterinarySocial.instagram,
        groomingSocial.instagram,
        adoptionSocial.instagram,
        hotelSocial.instagram
      );
      const contactWhatsapp = firstNonEmptyString(
        contact.whatsapp,
        veterinarySocial.whatsapp,
        groomingSocial.whatsapp,
        adoptionSocial.whatsapp,
        hotelSocial.whatsapp
      );
      const contactWebsite = firstNonEmptyString(
        contact.website,
        veterinarySocial.website,
        groomingSocial.website,
        adoptionSocial.website,
        hotelSocial.website
      );

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
        .where("status", "in", ["pending", "under_review", "pending_review"])
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
      const hasPetTaxiSector = sectors.includes("pet_taxi");
      const publicSectorData = hasPetTaxiSector
        ? {
          ...sectorData,
          pet_taxi: {
            ...(sectorData.pet_taxi || {}),
            documents: {
              requiredDocumentKeys:
                sectorData.pet_taxi?.documents?.requiredDocumentKeys || [],
              optionalDocumentKeys:
                sectorData.pet_taxi?.documents?.optionalDocumentKeys || [],
            },
          },
        }
        : sectorData;

      // =========================
      // CREATE BUSINESS (PENDING)
      // =========================
      const businessRef = db.collection("businesses").doc(uid);

      const businessDoc = {
        sectors,
        sectorData: publicSectorData,
        ownerUid: uid,
        status: hasPetTaxiSector ? "pending_review" : "pending",
        isActive: hasPetTaxiSector ? false : true,
        published: hasPetTaxiSector ? false : true,

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
          logoUrl: profileLogoUrl,
          coverUrl: coverImageUrl,
          categories: [],
          tags: [],
        },

        coverImageUrl,
        images: businessImages,
        clinicPhotoUrls: businessImages,
        ...(hotelData.maxCapacity || hotelData.capacity?.maxCapacity
          ? {
            maxCapacity: asNumber(
              hotelData.capacity?.maxCapacity ?? hotelData.maxCapacity,
              25
            ),
          }
          : {}),

        contact: {
          phone: contact.phone || null,
          whatsapp: contactWhatsapp,
          email: contact.email || null,
          instagram: contactInstagram,
          website: contactWebsite,
          city: contact.city.trim(),
          district: contact.district.trim(),
          addressLine: contact.addressLine || "",
          location: { lat, lng },
        },

        legal: {
          taxNumber: legal.taxNumber,
          mersisNumber: legal.mersisNumber,
          documents: [],
          petTaxiDocumentsPrivate: hasPetTaxiSector,
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

      const hasVeterinarySector = sectors.includes("veterinary");
      const hasGroomingSector =
        sectors.includes("grooming") || sectors.includes("groomer");
      const hasHotelSector =
        sectors.includes("pet_hotel") || sectors.includes("hotel");
      const hasAdoptionSector =
        sectors.includes("adoption_center") ||
        sectors.includes("adoptionCenter");
      const offeredServices = [
        ...(hasVeterinarySector
          ? firstStringArray(veterinaryServices.offeredServices)
          : []),
        ...(hasGroomingSector
          ? firstStringArray(
            groomingServices.offeredServices,
            Array.isArray(groomingServices) ? groomingServices : null,
            groomingData.specialties
          )
          : []),
        ...(hasHotelSector
          ? firstStringArray(
            hotelServices.offeredServices,
            Array.isArray(hotelServices) ? hotelServices : null,
            hotelData.specialties
          )
          : []),
        ...(hasAdoptionSector
          ? firstStringArray(
            adoptionServices.offeredServices,
            Array.isArray(adoptionServices)
              ? adoptionServices
              : null,
            adoptionData.specialties
          )
          : []),
      ].filter((service, index, list) => list.indexOf(service) === index);
      const defaultServicePrice = parsePriceFromText(
        hasHotelSector
          ? hotelServices.averagePriceRange
          : hasGroomingSector
            ? groomingServices.averagePriceRange
            : hasAdoptionSector
              ? adoptionServices.averagePriceRange
              : veterinaryServices.averagePriceRange
      );
      if (
        (
          hasVeterinarySector ||
          hasGroomingSector ||
          hasHotelSector ||
          hasAdoptionSector
        ) &&
        offeredServices.length > 0
      ) {
        const servicesBatch = db.batch();

        offeredServices.forEach((serviceTitle, index) => {
          const serviceRef = businessRef
            .collection("services")
            .doc(slugify(serviceTitle));

          servicesBatch.set(serviceRef, {
            title: serviceTitle,
            price: defaultServicePrice,
            currency: "TRY",
            durationMin:
              hasHotelSector
                ? 1440
                : hasAdoptionSector
                  ? 60
                  : 30,
            durationType:
              hasHotelSector
                ? "night"
                : "minute",
            description: "",
            isActive: true,
            sortOrder: index + 1,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        await servicesBatch.commit();
      }

      // =========================
      // CREATE REQUEST (FOR ADMIN)
      // =========================
      const requestRef = await db.collection("business_requests").add({
        uid,
        businessId: businessRef.id, // 🔥🔥🔥 مهم‌ترین خط
        status: hasPetTaxiSector ? "pending_review" : "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),

        sectors,

        profile: {
          displayName: profile.displayName.trim(),
          description: profile.description?.trim() || "",
          logoUrl: profileLogoUrl,
          coverUrl: coverImageUrl,
          coverImageUrl,
        },

        contact: {
          phone: contact.phone || null,
          whatsapp: contactWhatsapp,
          email: contact.email || null,
          instagram: contactInstagram,
          website: contactWebsite,
          city: contact.city.trim(),
          district: contact.district.trim(),
          addressLine: contact.addressLine || "",
          location: { lat, lng },
        },

        legal: {
          taxNumber: legal.taxNumber,
          mersisNumber: legal.mersisNumber,
        },

        coverImageUrl,
        images: businessImages,
        clinicPhotoUrls: businessImages,
        sectorData,
      });

      // =========================
      // UPDATE USER
      // =========================
      await db.collection("users").doc(uid).set(
        {
          business: {
            requestId: requestRef.id,
            status: hasPetTaxiSector ? "pending_review" : "pending",
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
    invoker: "admin",
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
      return "lost_pets";

    case "found_dog":
      return "found_pets";

    case "adoption":
      return "businesses";

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
    const defaultServicePrice = parsePriceFromText(
      data.sectorData?.veterinary?.services?.averagePriceRange ||
      data.services?.averagePriceRange
    );

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
        price: defaultServicePrice,
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
          subMerchantKey: subMerchantKey || null,
        });

        if (!subMerchantKey) {
          logger.warn("⚠️ MISSING SUB MERCHANT KEY", {
            businessId,
            orderId,
          });
        }

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

      logger.info("🧾 IYZICO REQUEST PAYLOAD", {
        orderId,
        conversationId,
        paidPrice: iyziRequest.paidPrice,
        price: iyziRequest.price,
        basketItems,
        buyer: iyziRequest.buyer,
        shippingAddress: iyziRequest.shippingAddress,
        billingAddress: iyziRequest.billingAddress,
        carrier: selectedCarrier || null,
        subMerchantKey: null,
      });

      let iyziResult;
      try {
        iyziResult = await new Promise((resolve, reject) => {
          iyzi.checkoutFormInitialize.create(iyziRequest, (err, result) => {
            if (err) return reject(err);
            return resolve(result);
          });
        });
      } catch (error) {
        logger.error("❌ IYZICO CHECKOUT CREATE FAILED", {
          orderId,
          conversationId,
          message: error?.message || String(error),
          code: error?.code || error?.response?.code || null,
          response:
            error?.response?.data ||
            error?.response ||
            error?.body ||
            null,
          stack: error?.stack || null,
        });
        throw error;
      }

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

        console.log("📦 ORDER NOTIFICATION DEBUG", {
          skippedAt: "createCheckoutSession",
          reason: "seller notification is created only after successful payment",
          type: "new_order",
          orderId: String(orderId || ""),
          sellerOrderId: String(doc.id || ""),
          businessId: String(sellerBusinessId || ""),
        });
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
    secrets: [
      IYZICO_API_KEY,
      IYZICO_SECRET_KEY,
      resendApiKey,
      ORDER_EXTERNAL_NOTIFICATIONS_ENABLED,
    ],
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

      const paymentTransactionIds = extractPaymentTransactionIds(
        result?.itemTransactions
      );
      const paymentTransactionId =
        paymentTransactionIds.length > 0
          ? paymentTransactionIds[0]
          : result?.paymentTransactionId?.toString?.() ||
          result?.paymentTransactionId ||
          null;

      console.log("💳 PAYMENT TRANSACTION ID", paymentTransactionId);
      if (!paymentTransactionId) {
        console.warn("⚠️ Missing paymentTransactionId");
      }

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
            paymentTransactionId,
            paymentTransactionIds,
            itemTransactions: result?.itemTransactions || [],
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
      const sellerOrderIdsByBusiness = new Map();

      for (const doc of sellerOrdersSnap.docs) {
        const sellerOrder = doc.data() || {};
        const businessId = sellerOrder.businessId || sellerOrder.shopId || null;
        if (businessId) {
          sellerBusinessIds.add(String(businessId));
          if (!sellerOrderIdsByBusiness.has(String(businessId))) {
            sellerOrderIdsByBusiness.set(String(businessId), doc.id);
          }
        }

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
              paymentProvider: sellerOrder.payment?.paymentProvider || "iyzico",
              paymentId: result?.paymentId || null,
              paymentTransactionId,
              paymentTransactionIds,
              itemTransactions: result?.itemTransactions || [],
              conversationId: result?.conversationId || null,
              paidPrice: asNumber(result?.paidPrice, 0),
              price: asNumber(result?.price, 0),
              currency: result?.currency || sellerOrder?.currency || "TRY",
              installment: asNumber(result?.installment, 1),
              paymentTransactionId,
              paymentTransactionIds,
              itemTransactions: result?.itemTransactions || [],
              iyzicoPaymentTransactionId: paymentTransactionId || null,
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

      for (const doc of sellerOrdersSnap.docs) {
        const sellerOrderId = doc.id;
        const sellerData = doc.data() || {};
        const businessId = sellerData.businessId || sellerData.shopId || null;

        const businessSnap = await db.collection("businesses").doc(businessId).get();
        const businessData = businessSnap.exists ? businessSnap.data() || {} : {};
        const ownerUid = businessSnap.exists
          ? businessData.ownerUid || businessData.uid || null
          : null;
        const businessToken = businessData.fcmToken || null;

        console.log('🔔 PUSH TYPE = new_paid_order');
        console.log('🔔 RECIPIENT UID =', ownerUid);
        console.log('🔔 BUSINESS ID =', businessId);

        if (ownerUid) {
          const notificationKey = `new_order_${sellerOrderId}`;
          const orderNotificationDebug = {
            type: "new_order",
            orderId: String(safeOrderId || ""),
            sellerOrderId: String(sellerOrderId || ""),
            businessId: String(businessId || ""),
            recipientUserId: String(ownerUid || ""),
            notificationKey,
          };
          const existingNotificationSnap = await db
            .collection("notifications")
            .where("notificationKey", "==", notificationKey)
            .limit(1)
            .get();

          console.log("📦 ORDER NOTIFICATION DEBUG", {
            ...orderNotificationDebug,
            exists: !existingNotificationSnap.empty,
          });

          if (!existingNotificationSnap.empty) {
            console.log("📦 ORDER NOTIFICATION DEBUG", {
              skipped: true,
              reason: "duplicate notificationKey",
              ...orderNotificationDebug,
            });
            continue;
          }

          await db.collection("notifications").add({
            recipientUserId: ownerUid,
            userId: ownerUid,
            type: "new_order",
            title: "New paid order 🛒",
            body: "A customer has completed payment for a new order.",

            orderId: orderNotificationDebug.orderId,
            sellerOrderId: orderNotificationDebug.sellerOrderId,
            businessId: orderNotificationDebug.businessId,
            notificationKey,
            payload: orderNotificationDebug,

            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          try {
            const recipientSnap = await db.collection("users").doc(ownerUid).get();
            const token = recipientSnap.data()?.fcmToken || businessToken || null;
            const message = {
              token,
              notification: {
                title: "New paid order 🛒",
                body: "A customer has completed payment for a new order.",
              },
              data: {
                type: orderNotificationDebug.type,
                orderId: orderNotificationDebug.orderId,
                sellerOrderId: orderNotificationDebug.sellerOrderId,
                businessId: orderNotificationDebug.businessId,
                recipientUserId: orderNotificationDebug.recipientUserId,
                notificationKey: orderNotificationDebug.notificationKey,
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
                },
                payload: {
                  aps: {
                    alert: {
                      title: "New paid order 🛒",
                      body: "A customer has completed payment for a new order.",
                    },
                    sound: "default",
                    badge: 1,
                    "interruption-level": "time-sensitive",
                  },
                },
              },
            };

            console.log("📨 FCM PAYLOAD DEBUG", message);
            console.log("🔔 PUSH TYPE = new_paid_order");
            console.log("🔔 RECIPIENT UID =", ownerUid);
            console.log("🔔 BUSINESS ID =", businessId);
            console.log("🔔 TOKEN FOUND =", !!token);

            if (token) {
              console.log("🔔 ABOUT TO SEND PUSH");
              console.log("🔔 PUSH TOKEN", token);
              console.log("🔔 PUSH PAYLOAD", message);
              const response = await safeMessagingSend(message, {
                functionName: "verifyPaymentByOrderId",
                notificationType: "new_order",
                orderId: orderNotificationDebug.orderId,
                sellerOrderId: orderNotificationDebug.sellerOrderId,
                businessId: orderNotificationDebug.businessId,
                recipientUserId: orderNotificationDebug.recipientUserId,
              });
              if (response) {
                console.log("✅ PUSH SENT SUCCESS", response);
              }
            } else {
              console.error("❌ PUSH SEND FAILED", "missing token");
            }
          } catch (error) {
            console.error("❌ PUSH SEND FAILED", error);
          }
        } else {
          console.log('❌ PUSH SEND FAILED', 'new_paid_order ownerUid missing');
        }
      }

      try {
        await sendExternalOrderNotifications({
          orderId: safeOrderId,
          orderData,
          source: "verifyPaymentByOrderId",
          paymentId: result?.paymentId || orderData?.payment?.paymentId || null,
          userId: orderData.buyerUid || orderData.userId || auth.uid,
        });
      } catch (e) {
        console.error("External order notification failed:", e);
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
    secrets: [
      IYZICO_API_KEY,
      IYZICO_SECRET_KEY,
      resendApiKey,
      ORDER_EXTERNAL_NOTIFICATIONS_ENABLED,
    ],
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
      let paymentTransactionIds = [];
      let paymentTransactionId = null;

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

      paymentTransactionIds = extractPaymentTransactionIds(
        result?.itemTransactions
      );
      paymentTransactionId =
        paymentTransactionIds.length > 0
          ? paymentTransactionIds[0]
          : result?.paymentTransactionId?.toString?.() ||
          result?.paymentTransactionId ||
          null;

      console.log("💳 PAYMENT TRANSACTION ID", paymentTransactionId);
      if (!paymentTransactionId) {
        console.warn("⚠️ Missing paymentTransactionId");
      }

      // 🔁 جلوگیری از دوباره پرداخت
      if (orderData.payment?.status === "paid") {
        if (orderData.type === "appointment") {
          const appointmentCollection = appointmentCollectionForOrder(orderData);
          const appointmentId = orderData.appointmentId || null;

          if (appointmentCollection === "vet_appointments" && appointmentId) {
            const appointmentSnap = await db
              .collection(appointmentCollection)
              .doc(appointmentId)
              .get();

            if (appointmentSnap.exists) {
              await syncVetPatientVisitAfterPaid({
                db,
                appointmentId,
                appointmentData: appointmentSnap.data() || {},
              });
            }
          }
        }

        return {
          success: true,
          alreadyPaid: true,
          type: orderData.type || null,
          appointmentCollection: orderData.type === "appointment"
            ? appointmentCollectionForOrder(orderData)
            : null,
          appointmentType: orderData.appointmentType || null,
          appointmentId: orderData.type === "appointment"
            ? orderData.appointmentId || null
            : null,
          sellerOrderIds: orderData.sellerOrderIds || [],
        };
      }

      if (orderData.type === "appointment") {
        const appointmentId = orderData.appointmentId;
        const appointmentCollection = appointmentCollectionForOrder(orderData);

        if (!appointmentId) {
          throw new HttpsError(
            "failed-precondition",
            "Missing appointmentId in order"
          );
        }

        const appointmentRef = db
          .collection(appointmentCollection)
          .doc(appointmentId);
        const appointmentSnap = await appointmentRef.get();

        if (!appointmentSnap.exists) {
          throw new HttpsError("not-found", "Appointment not found");
        }

        const appointmentData = appointmentSnap.data() || {};
        const appointmentStatus = appointmentData.status || "pending";
        const appointmentPaymentPolicy = resolveAppointmentPaymentPolicy(
          appointmentData
        );
        const deadlineMillis = toMillisSafe(
          appointmentData.paymentDeadlineAt || null
        );

        if (appointmentStatus !== "awaiting_payment") {
          throw new HttpsError(
            "failed-precondition",
            `Appointment is not awaiting payment: ${appointmentStatus}`
          );
        }

        if (!appointmentPaymentPolicy.requiresPayment) {
          throw new HttpsError(
            "failed-precondition",
            "Appointment does not require payment"
          );
        }

        if (deadlineMillis && deadlineMillis < Date.now()) {
          throw new HttpsError(
            "failed-precondition",
            "Payment window expired"
          );
        }
      }

      // =========================
      // ✅ UPDATE ORDER
      // =========================
      await orderRef.update({
        "payment.status": "paid",
        paymentStatus: "paid",
        status: "paid",
        "payment.paymentId": result.paymentId || null,
        "payment.paymentProvider": "iyzico",
        "payment.paidPrice": result.paidPrice || null,
        "payment.price": result.price || null,
        "payment.conversationId": result.conversationId || orderData.payment?.conversationId || null,
        "payment.paymentTransactionId": paymentTransactionId || null,
        "payment.paymentTransactionIds": paymentTransactionIds,
        "payment.iyzicoPaymentTransactionId": paymentTransactionId || null,
        "payment.currency": result.currency || orderData.payment?.currency || orderData.currency || "TRY",
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // =========================
      // 🔥 UPDATE APPOINTMENT + NOTIF + FCM
      // =========================
      if (orderData.type === "appointment") {
        const appointmentId = orderData.appointmentId;
        const appointmentCollection = appointmentCollectionForOrder(orderData);

        if (appointmentId) {
          const appointmentRef = db
            .collection(appointmentCollection)
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
            paymentId: result.paymentId || null,
            iyzicoPaymentId: result.paymentId || null,
            paymentTransactionId: paymentTransactionId || null,
            paymentTransactionIds,
            iyzicoPaymentTransactionId: paymentTransactionId || null,
            conversationId:
              result.conversationId || orderData.payment?.conversationId || null,
            orderId: orderId || null,
            checkoutToken: orderData.payment?.checkoutToken || null,
          });

          // 🎯 پیدا کردن گیرنده (vet)
          const targetBusinessId =
            orderData.businessId ||
            appointmentData.businessId ||
            appointmentData.vetId ||
            null;
          let recipientUserId = targetBusinessId;
          if (targetBusinessId) {
            try {
              const businessSnap = await db
                .collection("businesses")
                .doc(targetBusinessId)
                .get();
              const businessData = businessSnap.data() || {};
              recipientUserId =
                businessData.ownerUid ||
                businessData.uid ||
                targetBusinessId;
            } catch (error) {
              logger.warn("⚠️ Payment recipient owner lookup failed", {
                businessId: targetBusinessId,
                message: error?.message || String(error),
              });
            }
          }
          const isHotelBooking = appointmentCollection === "hotel_bookings";

          logger.info("🐾 Appointment marked as PAID", {
            appointmentId,
            recipientUserId,
          });

          if (appointmentCollection === "vet_appointments") {
            await syncVetPatientVisitAfterPaid({
              db,
              appointmentId,
              appointmentData,
            });
          }

          if (recipientUserId) {
            // =========================
            // 🟣 1. SAVE IN-APP NOTIFICATION
            // =========================
            await db.collection("notifications").add({
              type: isHotelBooking
                ? "hotel_booking_payment_completed"
                : "appointment_paid",
              recipientUserId: recipientUserId,
              senderUserId: auth.uid,
              title: isHotelBooking
                ? "Hotel Payment Completed"
                : "Payment Completed",
              body: `${appointmentData.petName ||
                appointmentData.dogName ||
                (isHotelBooking ? "Booking" : "Appointment")
                } payment completed successfully`,
              appointmentId: appointmentId,
              bookingId: isHotelBooking ? appointmentId : null,
              appointmentCollection,
              appointmentType: orderData.appointmentType || null,
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
              logger.info("🔔 Playdate/PetTaxi reference sound payload attached", {
                type: isHotelBooking
                  ? "hotel_booking_payment_completed"
                  : "appointment_paid",
                recipientUserId,
                appointmentId,
              });
              const paymentPushMessage = {
                token: fcmToken,
                notification: {
                  title: "Payment Completed",
                  body: isHotelBooking
                    ? "Hotel booking has been paid"
                    : "Appointment has been paid",
                },
                data: {
                  type: isHotelBooking
                    ? "hotel_booking_payment_completed"
                    : "appointment_paid",
                  appointmentId: appointmentId,
                  bookingId: isHotelBooking ? appointmentId : "",
                  appointmentCollection,
                  appointmentType: orderData.appointmentType || "",
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
                        title: "Payment Completed",
                        body: isHotelBooking
                          ? "Hotel booking has been paid"
                          : "Appointment has been paid",
                      },
                      sound: "default",
                      badge: 1,
                      "interruption-level": "time-sensitive",
                    },
                  },
                },
              };

              const fcmResponse = await safeMessagingSend(paymentPushMessage, {
                functionName: "verifyPayment",
                notificationType: isHotelBooking
                  ? "hotel_booking_payment_completed"
                  : "appointment_paid",
                recipientUserId,
                appointmentId,
                appointmentCollection,
              });

              if (fcmResponse) {
                logger.info("🔔 FCM sent", {
                  recipientUserId,
                  appointmentId,
                  soundEnabled: true,
                });
              }
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

          if (isHotelBooking && appointmentData.userId) {
            await createNotification(db, {
              type: "hotel_booking_response",
              recipientUserId: appointmentData.userId,
              userId: appointmentData.userId,
              senderUserId: recipientUserId || "system",
              businessId: appointmentData.businessId || targetBusinessId,
              appointmentId,
              bookingId: appointmentId,
              appointmentCollection,
              status: "confirmed_paid",
              title: "Hotel Payment Completed",
              body: `${appointmentData.serviceTitle || "Hotel stay"} is confirmed and paid`,
            });
          }
        }
      }

      if (orderData.type === "appointment") {
        try {
          await sendExternalOrderNotifications({
            orderId,
            orderData,
            source: "verifyPayment",
            paymentId: result?.paymentId || orderData?.payment?.paymentId || null,
            userId: orderData.buyerUid || orderData.userId || auth.uid,
          });
        } catch (e) {
          console.error("External order notification failed:", e);
        }

        return {
          success: true,
          type: "appointment",
          appointmentCollection: appointmentCollectionForOrder(orderData),
          appointmentType: orderData.appointmentType || null,
          appointmentId: orderData.appointmentId || null,
          sellerOrderIds: [],
        };
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
          payment: {
            ...(data.payment || {}),
            status: "paid",
            provider: "iyzico",
            paymentProvider: data.payment?.paymentProvider || "iyzico",
            paymentId: result.paymentId || null,
            paidPrice: result.paidPrice || null,
            price: result.price || null,
            conversationId: result.conversationId || orderData.payment?.conversationId || null,
            currency: result.currency || orderData.payment?.currency || orderData.currency || "TRY",
            paymentTransactionId: paymentTransactionId || null,
            paymentTransactionIds: paymentTransactionIds,
            iyzicoPaymentTransactionId: paymentTransactionId || null,
          },
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

      for (const doc of sellerOrdersSnap.docs) {
        const sellerOrderId = doc.id;
        const sellerData = doc.data() || {};
        const businessId = sellerData.businessId || sellerData.shopId || null;

        const businessSnap = businessId
          ? await db.collection("businesses").doc(String(businessId)).get()
          : null;
        const businessData = businessSnap?.exists ? businessSnap.data() || {} : {};
        const ownerUid = businessSnap?.exists
          ? businessData.ownerUid || businessData.uid || null
          : null;
        const businessToken = businessData.fcmToken || null;

        console.log("🔔 PUSH TYPE = new_paid_order");
        console.log("🔔 RECIPIENT UID =", ownerUid);
        console.log("🔔 BUSINESS ID =", businessId);

        if (ownerUid) {
          const notificationKey = `new_order_${sellerOrderId}`;
          const orderNotificationDebug = {
            type: "new_order",
            orderId: String(orderId || ""),
            sellerOrderId: String(sellerOrderId || ""),
            businessId: String(businessId || ""),
            recipientUserId: String(ownerUid || ""),
            notificationKey,
          };
          const existingNotificationSnap = await db
            .collection("notifications")
            .where("notificationKey", "==", notificationKey)
            .limit(1)
            .get();

          console.log("📦 ORDER NOTIFICATION DEBUG", {
            ...orderNotificationDebug,
            exists: !existingNotificationSnap.empty,
          });

          if (!existingNotificationSnap.empty) {
            console.log("📦 ORDER NOTIFICATION DEBUG", {
              skipped: true,
              reason: "duplicate notificationKey",
              ...orderNotificationDebug,
            });
            continue;
          }

          await db.collection("notifications").add({
            recipientUserId: ownerUid,
            userId: ownerUid,
            type: "new_order",
            title: "New paid order 🛒",
            body: "A customer has completed payment for a new order.",
            orderId: orderNotificationDebug.orderId,
            sellerOrderId: orderNotificationDebug.sellerOrderId,
            businessId: orderNotificationDebug.businessId,
            notificationKey,
            payload: orderNotificationDebug,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          try {
            const recipientSnap = await db
              .collection("users")
              .doc(String(ownerUid))
              .get();
            const token = recipientSnap.data()?.fcmToken || businessToken || null;
            const message = {
              token,
              notification: {
                title: "New paid order 🛒",
                body: "A customer has completed payment for a new order.",
              },
              data: {
                type: orderNotificationDebug.type,
                orderId: orderNotificationDebug.orderId,
                sellerOrderId: orderNotificationDebug.sellerOrderId,
                businessId: orderNotificationDebug.businessId,
                recipientUserId: orderNotificationDebug.recipientUserId,
                notificationKey: orderNotificationDebug.notificationKey,
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
                },
                payload: {
                  aps: {
                    alert: {
                      title: "New paid order 🛒",
                      body: "A customer has completed payment for a new order.",
                    },
                    sound: "default",
                    badge: 1,
                    "interruption-level": "time-sensitive",
                  },
                },
              },
            };

            console.log("📨 FCM PAYLOAD DEBUG", message);
            console.log("🔔 TOKEN FOUND =", !!token);

            if (token) {
              console.log("🔔 ABOUT TO SEND PUSH");
              console.log("🔔 PUSH TOKEN", token);
              console.log("🔔 PUSH PAYLOAD", message);
              const response = await safeMessagingSend(message, {
                functionName: "verifyPayment",
                notificationType: "new_order",
                orderId: orderNotificationDebug.orderId,
                sellerOrderId: orderNotificationDebug.sellerOrderId,
                businessId: orderNotificationDebug.businessId,
                recipientUserId: orderNotificationDebug.recipientUserId,
              });
              if (response) {
                console.log("✅ PUSH SENT SUCCESS", response);
              }
            } else {
              console.error("❌ PUSH SEND FAILED", "missing token");
            }
          } catch (error) {
            console.error("❌ PUSH SEND FAILED", error);
          }
        } else {
          console.log("❌ PUSH SEND FAILED", "new_paid_order ownerUid missing");
        }
      }

      try {
        await sendExternalOrderNotifications({
          orderId,
          orderData,
          source: "verifyPayment",
          paymentId: result?.paymentId || orderData?.payment?.paymentId || null,
          userId: orderData.buyerUid || orderData.userId || auth.uid,
        });
      } catch (e) {
        console.error("External order notification failed:", e);
      }

      return {
        success: true,
        sellerOrderIds,
      };
    } catch (error) {
      console.error("❌ verifyPayment INTERNAL CRASH", error);
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

exports.verifyHotelBookingPayment = exports.verifyPayment;

exports.expireAwaitingAppointmentPayments = onSchedule(
  {
    region: "europe-west3",
    schedule: "every 5 minutes",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const snap = await db
      .collection("vet_appointments")
      .where("status", "==", "awaiting_payment")
      .where("paymentDeadlineAt", "<", now)
      .orderBy("paymentDeadlineAt")
      .limit(100)
      .get();

    if (snap.empty) {
      logger.info("🩺 PAYMENT EXPIRE JOB: no overdue appointments");
      return;
    }

    const batch = db.batch();
    const targets = [];

    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const appointmentId = doc.id;
      const businessId = data.businessId || null;
      const userId = data.userId || data.buyerUid || null;

      console.log("🩺 PAYMENT EXPIRED", {
        appointmentId,
        businessId,
        userId,
        currentStatus: data.status || null,
        paymentDeadlineAt: data.paymentDeadlineAt || null,
      });
      console.log("🩺 SLOT RELEASED", {
        appointmentId,
      });

      batch.update(doc.ref, {
        status: "payment_expired",
        paymentStatus: "expired",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedBy: "system",
        paymentExpiredAt: admin.firestore.FieldValue.serverTimestamp(),
        lastStatusChange: {
          from: "awaiting_payment",
          to: "payment_expired",
          by: "system",
          at: admin.firestore.FieldValue.serverTimestamp(),
        },
      });

      targets.push({
        appointmentId,
        businessId,
        userId,
        serviceTitle: data.serviceTitle || "Service",
      });
    }

    await batch.commit();

    for (const target of targets) {
      try {
        if (target.userId) {
          await db.collection("notifications").add({
            type: "appointment_payment_expired",
            recipientUserId: target.userId,
            senderUserId: "system",
            appointmentId: target.appointmentId,
            status: "payment_expired",
            title: "Payment window expired",
            body: `${target.serviceTitle} payment window expired`,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          const userSnap = await db.collection("users").doc(target.userId).get();
          const fcmToken = userSnap.data()?.fcmToken;

          if (fcmToken) {
            logger.info("🔔 Playdate/PetTaxi reference sound payload attached", {
              type: "appointment_payment_expired",
              recipientUserId: target.userId,
              appointmentId: target.appointmentId,
            });
            await admin.messaging().send({
              token: fcmToken,
              notification: {
                title: "Payment window expired",
                body: `${target.serviceTitle} payment window expired`,
              },
              data: {
                type: "appointment_payment_expired",
                appointmentId: target.appointmentId,
                status: "payment_expired",
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
                      title: "Payment window expired",
                      body: `${target.serviceTitle} payment window expired`,
                    },
                    sound: "default",
                    badge: 1,
                    "interruption-level": "time-sensitive",
                  },
                },
              },
            });
            logger.info("🔔 Push send success", {
              type: "appointment_payment_expired",
              recipientUserId: target.userId,
              soundEnabled: true,
            });
          } else {
            logger.warn("⚠️ Push token missing", {
              type: "appointment_payment_expired",
              recipientUserId: target.userId,
            });
          }
        }

        if (target.businessId) {
          const businessSnap = await db
            .collection("businesses")
            .doc(target.businessId)
            .get();
          const businessData = businessSnap.data() || {};
          const businessOwnerUid = businessData.ownerUid || businessData.uid || target.businessId;

          await db.collection("notifications").add({
            type: "vet_appointment_payment_expired",
            recipientUserId: businessOwnerUid,
            senderUserId: "system",
            appointmentId: target.appointmentId,
            status: "payment_expired",
            title: "Appointment payment expired",
            body: `${target.serviceTitle} payment window expired`,
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          const vetUserSnap = await db.collection("users").doc(businessOwnerUid).get();
          const vetToken = vetUserSnap.data()?.fcmToken;

          if (vetToken) {
            await safeSendPush({
              token: vetToken,
              userId: businessOwnerUid,
              payload: {
                notification: {
                  title: "Appointment payment expired",
                  body: `${target.serviceTitle} payment window expired`,
                },
                data: {
                  type: "vet_appointment_payment_expired",
                  appointmentId: target.appointmentId,
                  status: "payment_expired",
                },
                android: { priority: "high" },
              },
            });
          }
        }
      } catch (error) {
        logger.error("❌ payment expiry notification failed", {
          appointmentId: target.appointmentId,
          message: error?.message || String(error),
        });
      }
    }
  }
);

exports.expireAwaitingGroomyAppointmentPayments = onSchedule(
  {
    region: "europe-west3",
    schedule: "every 5 minutes",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const snap = await db
      .collection("groomy_appointments")
      .where("status", "==", "awaiting_payment")
      .where("paymentDeadlineAt", "<", now)
      .orderBy("paymentDeadlineAt")
      .limit(100)
      .get();

    if (snap.empty) {
      logger.info("✂️ GROOMY PAYMENT EXPIRE JOB: no overdue appointments");
      return;
    }

    const batch = db.batch();
    const targets = [];

    for (const doc of snap.docs) {
      const data = doc.data() || {};

      batch.update(doc.ref, {
        status: "payment_expired",
        paymentStatus: "expired",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedBy: "system",
        paymentExpiredAt: admin.firestore.FieldValue.serverTimestamp(),
        lastStatusChange: {
          from: "awaiting_payment",
          to: "payment_expired",
          by: "system",
          at: admin.firestore.FieldValue.serverTimestamp(),
        },
      });

      targets.push({
        appointmentId: doc.id,
        businessId: data.businessId || null,
        userId: data.userId || data.buyerUid || null,
        serviceTitle: data.serviceTitle || "Grooming service",
      });
    }

    await batch.commit();

    for (const target of targets) {
      try {
        if (target.userId) {
          await createNotification(db, {
            type: "groomy_appointment_response",
            recipientUserId: target.userId,
            userId: target.userId,
            senderUserId: "system",
            appointmentId: target.appointmentId,
            appointmentCollection: "groomy_appointments",
            status: "payment_expired",
            title: "Payment window expired",
            body: `${target.serviceTitle} payment window expired`,
          });
        }

        if (target.businessId) {
          const businessSnap = await db
            .collection("businesses")
            .doc(target.businessId)
            .get();
          const businessData = businessSnap.data() || {};
          const businessOwnerUid =
            businessData.ownerUid || businessData.uid || target.businessId;

          await createNotification(db, {
            type: "groomy_appointment_payment_expired",
            recipientUserId: businessOwnerUid,
            userId: businessOwnerUid,
            senderUserId: "system",
            appointmentId: target.appointmentId,
            appointmentCollection: "groomy_appointments",
            businessId: target.businessId,
            status: "payment_expired",
            title: "Grooming payment expired",
            body: `${target.serviceTitle} payment window expired`,
          });
        }
      } catch (error) {
        logger.error("❌ Groomy payment expiry notification failed", {
          appointmentId: target.appointmentId,
          message: error?.message || String(error),
        });
      }
    }
  }
);

exports.expireAwaitingHotelBookingPayments = onSchedule(
  {
    region: "europe-west3",
    schedule: "every 5 minutes",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const snap = await db
      .collection("hotel_bookings")
      .where("status", "==", "awaiting_payment")
      .where("paymentDeadlineAt", "<", now)
      .orderBy("paymentDeadlineAt")
      .limit(100)
      .get();

    if (snap.empty) {
      logger.info("🏨 HOTEL PAYMENT EXPIRE JOB: no overdue bookings");
      return;
    }

    const batch = db.batch();
    const targets = [];

    for (const doc of snap.docs) {
      const data = doc.data() || {};

      batch.update(doc.ref, {
        status: "payment_expired",
        paymentStatus: "expired",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedBy: "system",
        paymentExpiredAt: admin.firestore.FieldValue.serverTimestamp(),
        lastStatusChange: {
          from: "awaiting_payment",
          to: "payment_expired",
          by: "system",
          at: admin.firestore.FieldValue.serverTimestamp(),
        },
      });

      targets.push({
        bookingId: doc.id,
        businessId: data.businessId || null,
        userId: data.userId || data.buyerUid || null,
        serviceTitle: data.serviceTitle || "Hotel stay",
      });
    }

    await batch.commit();

    for (const target of targets) {
      try {
        if (target.userId) {
          await createNotification(db, {
            type: "hotel_booking_response",
            recipientUserId: target.userId,
            userId: target.userId,
            senderUserId: "system",
            appointmentId: target.bookingId,
            bookingId: target.bookingId,
            appointmentCollection: "hotel_bookings",
            status: "payment_expired",
            title: "Payment window expired",
            body: `${target.serviceTitle} payment window expired`,
          });
        }

        if (target.businessId) {
          const businessSnap = await db
            .collection("businesses")
            .doc(target.businessId)
            .get();
          const businessData = businessSnap.data() || {};
          const businessOwnerUid =
            businessData.ownerUid || businessData.uid || target.businessId;

          await createNotification(db, {
            type: "hotel_booking_payment_expired",
            recipientUserId: businessOwnerUid,
            userId: businessOwnerUid,
            senderUserId: "system",
            appointmentId: target.bookingId,
            bookingId: target.bookingId,
            appointmentCollection: "hotel_bookings",
            businessId: target.businessId,
            status: "payment_expired",
            title: "Hotel payment expired",
            body: `${target.serviceTitle} payment window expired`,
          });
        }
      } catch (error) {
        logger.error("❌ Hotel payment expiry notification failed", {
          bookingId: target.bookingId,
          message: error?.message || String(error),
        });
      }
    }
  }
);

exports.reminderHotelBookings = onSchedule(
  {
    region: "europe-west3",
    schedule: "every 30 minutes",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const in24Hours = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 24 * 60 * 60 * 1000
    );

    const checkInSnap = await db
      .collection("hotel_bookings")
      .where("checkInDate", "<=", in24Hours)
      .where("checkInDate", ">", now)
      .where("status", "in", ["confirmed", "confirmed_paid"])
      .limit(100)
      .get();

    const checkOutSnap = await db
      .collection("hotel_bookings")
      .where("checkOutDate", "<=", in24Hours)
      .where("checkOutDate", ">", now)
      .where("status", "in", ["checked_in", "confirmed", "confirmed_paid"])
      .limit(100)
      .get();

    async function sendReminder(doc, kind) {
      const data = doc.data() || {};
      const sentField =
        kind === "check_in" ? "checkInReminderSent" : "checkOutReminderSent";
      if (data[sentField]) return;

      const userId = data.userId || data.buyerUid || null;
      if (!userId) return;

      const title =
        kind === "check_in"
          ? "Check-in Reminder"
          : "Check-out Reminder";
      const body =
        kind === "check_in"
          ? `${data.petName || data.dogName || "Your pet"} checks in soon`
          : `${data.petName || data.dogName || "Your pet"} checks out soon`;

      await db.collection("notifications").add({
        type:
          kind === "check_in"
            ? "hotel_booking_check_in_reminder"
            : "hotel_booking_check_out_reminder",
        recipientUserId: userId,
        senderUserId: "system",
        appointmentId: doc.id,
        bookingId: doc.id,
        appointmentCollection: "hotel_bookings",
        title,
        body,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await doc.ref.update({
        [sentField]: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const userSnap = await db.collection("users").doc(userId).get();
      const fcmToken = userSnap.data()?.fcmToken;
      if (fcmToken) {
        logger.info("🔔 Playdate/PetTaxi reference sound payload attached", {
          type:
            kind === "check_in"
              ? "hotel_booking_check_in_reminder"
              : "hotel_booking_check_out_reminder",
          recipientUserId: userId,
          bookingId: doc.id,
        });
        await admin.messaging().send({
          token: fcmToken,
          notification: { title, body },
          data: {
            type:
              kind === "check_in"
                ? "hotel_booking_check_in_reminder"
                : "hotel_booking_check_out_reminder",
            appointmentId: doc.id,
            bookingId: doc.id,
            appointmentCollection: "hotel_bookings",
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
                  title,
                  body,
                },
                sound: "default",
                badge: 1,
                "interruption-level": "time-sensitive",
              },
            },
          },
        });
        logger.info("🔔 Push send success", {
          type:
            kind === "check_in"
              ? "hotel_booking_check_in_reminder"
              : "hotel_booking_check_out_reminder",
          recipientUserId: userId,
          soundEnabled: true,
        });
      } else {
        logger.warn("⚠️ Push token missing", {
          type:
            kind === "check_in"
              ? "hotel_booking_check_in_reminder"
              : "hotel_booking_check_out_reminder",
          recipientUserId: userId,
        });
      }
    }

    for (const doc of checkInSnap.docs) {
      await sendReminder(doc, "check_in");
    }

    for (const doc of checkOutSnap.docs) {
      await sendReminder(doc, "check_out");
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
        logger.info("🔔 Playdate/PetTaxi reference sound payload attached", {
          type: "appointment_reminder",
          recipientUserId: userId,
          appointmentId: doc.id,
        });
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
                  title: "Reminder ⏰",
                  body: "You have an appointment in 2 hours",
                },
                sound: "default",
                badge: 1,
                "interruption-level": "time-sensitive",
              },
            },
          },
        });
        logger.info("🔔 Push send success", {
          type: "appointment_reminder",
          recipientUserId: userId,
          soundEnabled: true,
        });
      } else {
        logger.warn("⚠️ Push token missing", {
          type: "appointment_reminder",
          recipientUserId: userId,
        });
      }

      await doc.ref.update({
        reminderSent: true,
      });
    }
  }
);

function readFirestoreDate(value) {
  if (!value) return null;

  if (typeof value.toDate === "function") {
    const date = value.toDate();
    return date instanceof Date && !Number.isNaN(date.getTime()) ? date : null;
  }

  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }

  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function formatDateKeyInTimeZone(date, timeZone = "Europe/Istanbul") {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) return null;

  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const parts = formatter.formatToParts(date);
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  const day = parts.find((part) => part.type === "day")?.value;

  if (!year || !month || !day) return null;
  return `${year}-${month}-${day}`;
}

function addDaysToDateKey(dateKey, days) {
  if (!dateKey) return null;

  const parsed = new Date(`${dateKey}T00:00:00.000Z`);
  if (Number.isNaN(parsed.getTime())) return null;

  parsed.setUTCDate(parsed.getUTCDate() + days);
  return parsed.toISOString().slice(0, 10);
}

function normalizeReminderString(value) {
  return String(value || "").trim();
}

function isReminderProcessingStale(value, staleAfterMinutes = 30) {
  const date = readFirestoreDate(value);
  if (!date) return false;

  const ageMs = Date.now() - date.getTime();
  return ageMs > staleAfterMinutes * 60 * 1000;
}

function buildVaccineReminderId({
  ownerId,
  businessId,
  patientId,
  vaccineId,
  dueDateKey,
}) {
  return [
    "vaccine_reminder",
    ownerId,
    businessId || "unknown_business",
    patientId || "unknown_patient",
    vaccineId,
    dueDateKey,
  ]
    .map((part) => normalizeReminderString(part).replace(/[^a-zA-Z0-9_-]/g, "_"))
    .join("_");
}

async function loadVaccineReminderContext(doc, parentCache) {
  const data = doc.data() || {};
  const parentRef = doc.ref.parent?.parent || null;
  const parentCollectionRef = parentRef?.parent || null;
  const businessRef = parentCollectionRef?.parent || null;
  const sourcePath = doc.ref.path;

  logger.info("VACCINE REMINDER RAW DOC", {
    sourcePath,
    docId: doc.id,
    keys: Object.keys(data),
    ownerId: data.ownerId || null,
  });
  logger.info("NON EMPTY STRING TEST", {
    input: data.ownerId,
    output: nonEmptyString(data.ownerId),
  });

  let parentData = null;
  if (parentRef) {
    const cached = parentCache.get(parentRef.path);
    if (cached) {
      parentData = cached;
    } else {
      const parentSnap = await parentRef.get();
      parentData = parentSnap.data() || {};
      parentCache.set(parentRef.path, parentData);
    }
  }

  const ownerId =
    nonEmptyString(data.ownerId) ||
    nonEmptyString(data.ownerUid) ||
    nonEmptyString(data.userId) ||
    nonEmptyString(data.clientUserId) ||
    nonEmptyString(data.petOwnerUid) ||
    nonEmptyString(data.petOwnerId) ||
    nonEmptyString(parentData?.ownerId) ||
    nonEmptyString(parentData?.ownerUid) ||
    nonEmptyString(parentData?.userId) ||
    nonEmptyString(parentData?.clientUserId);

  logger.info("OWNER RESOLUTION DEBUG", {
    sourcePath,
    keys: Object.keys(data),
    ownerId: data.ownerId || null,
    resolvedOwnerId: ownerId || null,
  });

  logger.info("VACCINE OWNER RESOLUTION", {
    sourcePath,
    vaccineOwnerId: nonEmptyString(data.ownerId) || null,
    parentOwnerId: nonEmptyString(parentData?.ownerId) || null,
    parentOwnerUid: nonEmptyString(parentData?.ownerUid) || null,
    resolvedOwnerId: ownerId || null,
    patientPath: parentRef?.path || null,
  });

  const patientId =
    nonEmptyString(data.patientId) ||
    (parentRef?.parent?.id === "patients" ? parentRef.id : null) ||
    nonEmptyString(parentData?.patientId);

  const petId =
    nonEmptyString(data.petId) ||
    (parentRef?.parent?.id === "dogs" ? parentRef.id : null) ||
    nonEmptyString(parentData?.petId);

  const vaccineId = doc.id;
  const vaccineName =
    nonEmptyString(data.name) || nonEmptyString(data.vaccineName) || "Vaccine";
  const nextDueDate = readFirestoreDate(data.nextDueDate);
  const status = normalizeLower(data.status);
  const reminderEnabled = data.reminderEnabled === true;
  const businessId =
    nonEmptyString(data.businessId) ||
    nonEmptyString(parentData?.businessId) ||
    nonEmptyString(businessRef?.id);
  const isAuthoritativeSource =
    parentCollectionRef?.id === "patients" &&
    businessRef?.parent?.id === "businesses";

  return {
    data,
    ownerId,
    patientId,
    petId,
    vaccineId,
    vaccineName,
    nextDueDate,
    status,
    reminderEnabled,
    businessId,
    isAuthoritativeSource,
    sourcePath: doc.ref.path,
  };
}

async function sendVaccineReminderNotification({
  context,
  dueDateKey,
  dueDateLabel,
}) {
  const {
    data,
    ownerId,
    patientId,
    petId,
    vaccineId,
    vaccineName,
    nextDueDate,
    businessId,
    sourcePath,
  } = context;

  if (!ownerId || !vaccineId || !nextDueDate || !dueDateKey) {
    return { skipped: true, reason: "missing-required-fields" };
  }

  const reminderId = buildVaccineReminderId({
    ownerId,
    businessId: businessId || data.businessId || null,
    patientId,
    vaccineId,
    dueDateKey,
  });
  const notificationRef = db.collection("notifications").doc(reminderId);
  const claimNow = admin.firestore.FieldValue.serverTimestamp();
  const title = "Vaccination Reminder";
  const petLabel = normalizeReminderString(data.petName) ||
    normalizeReminderString(data.dogName) ||
    "Your pet";
  const body = `${petLabel} has ${vaccineName} due on ${dueDateLabel}.`;
  const claimResult = await db.runTransaction(async (transaction) => {
    const snap = await transaction.get(notificationRef);

    if (snap.exists) {
      const existing = snap.data() || {};

      if (existing.pushSentAt) {
        return { status: "already-pushed" };
      }

      if (existing.processingStartedAt) {
        const processingStartedAt = readFirestoreDate(existing.processingStartedAt);
        const processingIsStale = processingStartedAt
          ? isReminderProcessingStale(processingStartedAt, 5)
          : true;

        if (!processingIsStale) {
          return { status: "processing" };
        }
      }

      transaction.set(
        notificationRef,
        {
          processingStartedAt: claimNow,
          processingBy: "reminderVaccines",
          processingSourcePath: sourcePath,
          processingUpdatedAt: claimNow,
          businessId: businessId || data.businessId || null,
          updatedAt: claimNow,
        },
        { merge: true }
      );
      return { status: "claimed", created: false };
    }

    transaction.set(notificationRef, {
      recipientUserId: ownerId,
      userId: ownerId,
      ownerId,
      type: "vaccine_reminder",
      title,
      body,
      businessId: businessId || data.businessId || null,
      patientId: patientId || data.patientId || null,
      petId: petId || data.petId || null,
      vaccineId,
      vaccineName,
      nextDueDate: admin.firestore.Timestamp.fromDate(nextDueDate),
      reminderKey: reminderId,
      sourcePath,
      isRead: false,
      read: false,
      createdAt: claimNow,
      processingStartedAt: claimNow,
      processingBy: "reminderVaccines",
      processingSourcePath: sourcePath,
      processingUpdatedAt: claimNow,
      pushSentAt: null,
      pushFailedAt: null,
      pushError: null,
    });
    return { status: "claimed", created: true };
  });

  if (claimResult?.status === "already-pushed") {
    logger.info("💉 VACCINE REMINDER ALREADY PUSHED", {
      reminderId,
      ownerId,
      vaccineId,
      dueDateKey,
    });
    return { skipped: true, reason: "already-pushed", reminderId };
  }

  if (claimResult?.status === "processing") {
    logger.info("💉 VACCINE REMINDER PROCESSING SKIPPED", {
      reminderId,
      ownerId,
      vaccineId,
      dueDateKey,
    });
    return { skipped: true, reason: "already-processing", reminderId };
  }

  logger.info("💉 VACCINE REMINDER DOC CLAIMED", {
    reminderId,
    ownerId,
    patientId: patientId || data.patientId || null,
    petId: petId || data.petId || null,
    vaccineId,
    dueDateKey,
  });
  logger.info("REMINDER SEND START", {
    ownerId: context.ownerId,
    vaccineId: context.vaccineId,
    dueDateKey,
  })

  const userSnap = await db.collection("users").doc(ownerId).get();
  logger.info("REMINDER USER LOOKUP", {
    ownerId: context.ownerId,
    userExists: !!userSnap.exists,
  })

  logger.info("REMINDER SEND RESULT", {
    success: true
  })
  const fcmToken = userSnap.data()?.fcmToken || null;
  logger.info("REMINDER TOKEN RESULT", {
    tokenCount: fcmToken ? 1 : 0,
  })

  const pushPayload = {
    notification: {
      title,
      body,
    },
    data: {
      type: "vaccine_reminder",
      ownerId: String(ownerId),
      userId: String(ownerId),
      businessId: String(businessId || data.businessId || ""),
      patientId: String(patientId || data.patientId || ""),
      petId: String(petId || data.petId || ""),
      vaccineId: String(vaccineId),
      vaccineName: String(vaccineName),
      nextDueDate: nextDueDate.toISOString(),
      reminderId: String(reminderId),
      title,
      body,
    },
    android: {
      priority: "high",
      notification: {
        sound: "default",
        channelId: "high_importance_channel",
      },
    },
  };

  if (fcmToken) {
    const sent = await safeSendPush({
      token: fcmToken,
      userId: ownerId,
      payload: pushPayload,
    });

    if (sent) {
      await notificationRef.set(
        {
          processingStartedAt: admin.firestore.FieldValue.delete(),
          processingBy: admin.firestore.FieldValue.delete(),
          processingSourcePath: admin.firestore.FieldValue.delete(),
          processingUpdatedAt: admin.firestore.FieldValue.delete(),
          pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
          pushFailedAt: admin.firestore.FieldValue.delete(),
          pushError: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      logger.info("💉 VACCINE REMINDER PUSH SENT", {
        reminderId,
        ownerId,
        vaccineId,
        dueDateKey,
      });
    } else {
      await notificationRef.set(
        {
          processingStartedAt: admin.firestore.FieldValue.delete(),
          processingBy: admin.firestore.FieldValue.delete(),
          processingSourcePath: admin.firestore.FieldValue.delete(),
          processingUpdatedAt: admin.firestore.FieldValue.delete(),
          pushFailedAt: admin.firestore.FieldValue.serverTimestamp(),
          pushError: "push-send-failed",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      logger.warn("⚠️ VACCINE REMINDER PUSH FAILED", {
        reminderId,
        ownerId,
        vaccineId,
        dueDateKey,
      });
    }
  } else {
    await notificationRef.set(
      {
        processingStartedAt: admin.firestore.FieldValue.delete(),
        processingBy: admin.firestore.FieldValue.delete(),
        processingSourcePath: admin.firestore.FieldValue.delete(),
        processingUpdatedAt: admin.firestore.FieldValue.delete(),
        pushFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        pushError: "missing-fcm-token",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    logger.warn("⚠️ VACCINE REMINDER TOKEN MISSING", {
      reminderId,
      ownerId,
      vaccineId,
      dueDateKey,
    });
  }

  return { skipped: false, reminderId };
}

exports.reminderVaccines = onSchedule(
  {
    region: "europe-west3",
    schedule: "every 6 hours",
    timeZone: "Europe/Istanbul",
  },
  async () => {
    const tz = "Europe/Istanbul";
    const now = new Date();
    const todayKey = formatDateKeyInTimeZone(now, tz);
    const windowEndKey = addDaysToDateKey(todayKey, 3);

    logger.info("💉 VACCINE REMINDER JOB START", {
      timeZone: tz,
      todayKey,
      windowEndKey,
      reminderWindowDays: 3,
    });

    if (!todayKey || !windowEndKey) {
      logger.error("❌ VACCINE REMINDER JOB ABORTED", {
        reason: "failed-to-compute-date-window",
      });
      return;
    }
    logger.info("BEFORE PATIENT QUERY");
    const patientSnap = await db
      .collectionGroup("patients")
      .get();

    logger.info("AFTER PATIENT QUERY", {
      count: patientSnap.size,
      empty: patientSnap.empty,
    });

    const seenReminderIds = new Set();
    let scanned = 0;
    let matched = 0;
    let created = 0;
    let sent = 0;
    let skipped = 0;

    for (const patientDoc of patientSnap.docs) {
      const patientData = patientDoc.data() || {};
      const businessId = nonEmptyString(patientData.businessId);
      const patientId = nonEmptyString(patientData.patientId) || patientDoc.id;

      if (!businessId || !patientId) {
        continue;
      }

      const parentCache = new Map([[patientDoc.ref.path, patientData]]);
      const vaccineSnap = await patientDoc.ref
        .collection("vaccines")
        .where("reminderEnabled", "==", true)
        .get();

      for (const doc of vaccineSnap.docs) {
        scanned++;
        const context = await loadVaccineReminderContext(doc, parentCache);

        if (!context.isAuthoritativeSource) {
          logger.info("VACCINE SKIP ownerId", {
            sourcePath: context.sourcePath,
            vaccineId: context.vaccineId,
            patientId: context.patientId,
            ownerIdResolved: context.ownerId,
            nextDueDate: context.nextDueDate,
          });
          skipped++;
          continue;
        }

        const dueDate = context.nextDueDate;
        if (!dueDate) {
          logger.info("SKIP MISSING DATA", {
            sourcePath: context.sourcePath,
            vaccineId: context.vaccineId,
            patientId: context.patientId,
            dueDateExists: !!dueDate,
            nextDueDate: context.nextDueDate,
            ownerId: context.ownerId,
            status: context.status,
          });
          logger.info("SKIP NO DUE DATE", {
            sourcePath: context.sourcePath,
            ownerId: context.ownerId,
            nextDueDate: context.nextDueDate,
          })
          skipped++;
          continue;
        }

        if (!context.ownerId) {
          logger.info("SKIP MISSING DATA", {
            sourcePath: context.sourcePath,
            vaccineId: context.vaccineId,
            patientId: context.patientId,
            dueDateExists: !!dueDate,
            nextDueDate: context.nextDueDate,
            ownerId: context.ownerId,
            status: context.status,
          });
          logger.info("SKIP NO OWNER", {
            sourcePath: context.sourcePath,
            ownerId: context.ownerId,
            nextDueDate: context.nextDueDate,
          })
          skipped++;
          continue;
        }

        logger.info("STATUS CHECK", {
          sourcePath: context.sourcePath,
          vaccineId: context.vaccineId,
          status: context.status,
        });
        if (context.status === "completed") {
          logger.info("VACCINE SKIP completed", {
            sourcePath: context.sourcePath,
            vaccineId: context.vaccineId,
            status: context.status,
          });
          skipped++;
          continue;
        }

        const dueDateKey = formatDateKeyInTimeZone(dueDate, tz);
        if (!dueDateKey) {
          logger.info("VACCINE SKIP dueDate", {
            sourcePath: context.sourcePath,
            vaccineId: context.vaccineId,
            nextDueDate: context.nextDueDate,
          });
          skipped++;
          continue;
        }
        logger.info("DATE WINDOW CHECK", {
          sourcePath: context.sourcePath,
          vaccineId: context.vaccineId,
          dueDateKey,
          todayKey,
          windowEndKey,
          ownerId: context.ownerId,
          status: context.status,
        })
        if (dueDateKey < todayKey || dueDateKey > windowEndKey) {
          logger.info("VACCINE SKIP window", {
            sourcePath: context.sourcePath,
            vaccineId: context.vaccineId,
            dueDateKey,
            todayKey,
            windowEndKey,
          });
          skipped++;
          continue;
        }

        const dueDateLabel = dueDate.toLocaleDateString("tr-TR", {
          timeZone: tz,
          day: "2-digit",
          month: "2-digit",
          year: "numeric",
        });
        const reminderId = buildVaccineReminderId({
          ownerId: context.ownerId,
          businessId,
          patientId,
          vaccineId: context.vaccineId,
          dueDateKey,
        });

        if (seenReminderIds.has(reminderId)) {
          logger.info("💉 VACCINE REMINDER DUPLICATE SKIPPED", {
            reminderId,
            sourcePath: context.sourcePath,
            ownerId: context.ownerId,
            vaccineId: context.vaccineId,
            dueDateKey,
          });
          skipped++;
          continue;
        }

        logger.info("VACCINE MATCHED", {
          sourcePath: context.sourcePath,
          vaccineId: context.vaccineId,
          ownerId: context.ownerId,
          dueDateKey,
        });

        logger.info("OWNER RESOLUTION RESULT", {
          sourcePath: context.sourcePath,
          vaccineId: context.vaccineId,
          resolvedOwnerId: context.ownerId,
        });

        seenReminderIds.add(reminderId);
        matched++;

        const result = await sendVaccineReminderNotification({
          context,
          dueDateKey,
          dueDateLabel,
        });

        if (result.skipped) {
          skipped++;
        } else {
          created++;
          sent++;
        }
      }
    }

    logger.info("💉 VACCINE REMINDER JOB DONE", {
      scanned,
      matched,
      created,
      sent,
      skipped,
      todayKey,
      windowEndKey,
    });
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


exports.deleteUserAccount = onCall(
  {
    region: "europe-west3",
  },
  async (request) => {

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
        db.collection("found_pets").where("ownerId", "==", uid)
      );

      await deleteByQuery(
        db.collection("lost_pets").where("ownerId", "==", uid)
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
        payment: {
          provider: payment.provider || null,
          paymentProvider: payment.paymentProvider || payment.provider || null,
          paymentId: payment.paymentId || null,
          paymentTransactionId: payment.paymentTransactionId || null,
          paymentTransactionIds: Array.isArray(payment.paymentTransactionIds)
            ? payment.paymentTransactionIds
            : [],
          conversationId: payment.conversationId || null,
          iyzicoPaymentTransactionId:
            payment.iyzicoPaymentTransactionId || payment.paymentTransactionId || null,
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
        paymentProvider: payment.paymentProvider || payment.provider || null,
        paymentId: payment.paymentId || null,
        paymentTransactionId: payment.paymentTransactionId || null,
        paymentTransactionIds: Array.isArray(payment.paymentTransactionIds)
          ? payment.paymentTransactionIds
          : [],
        conversationId: payment.conversationId || null,
        iyzicoPaymentTransactionId:
          payment.iyzicoPaymentTransactionId || payment.paymentTransactionId || null,
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

exports.createOrderReturnRequest = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 60,
    memory: "512MiB",
    secrets: [IYZICO_API_KEY, IYZICO_SECRET_KEY],
  },
  async (request) => {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();
    const authUid = request.auth?.uid;

    logger.info("🔄 ORDER RETURN REQUEST CREATE START", {
      authUid: authUid || null,
      rawData: request.data || null,
    });

    if (!authUid) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const data = request.data || {};
    console.log("RETURN RAW DATA", data);
    const sellerOrderId = String(data.sellerOrderId || "").trim();
    const rootOrderId = String(data.rootOrderId || "").trim();
    const reason = normalizeLower(data.reason) || "other";
    const description = String(data.description || "").trim();
    const refundType = normalizeLower(data.refundType) || "partial";
    const shippingResponsibilityInput = normalizeLower(
      data.shippingResponsibility
    );
    const requestedRefundAmount = asNumber(data.refundAmount, 0);
    const returnWindowDaysInput = Math.max(
      1,
      asNumber(data.returnWindowDays, 14)
    );
    const rawReturnItems = Array.isArray(data.returnItems) ? data.returnItems : [];
    const rawImages = Array.isArray(data.images) ? data.images : [];

    console.log("RETURN VALIDATION ENTRY");

    const normalizeStatus = (value) => {
      const lower = String(value || "").trim().toLowerCase();
      if (lower.includes("pending")) return "pending";
      if (lower.includes("paid")) return "paid";
      if (lower.includes("confirmed")) return "confirmed";
      if (lower.includes("preparing")) return "preparing";
      if (lower.includes("shipped")) return "shipped";
      if (lower.includes("delivered")) return "delivered";
      if (lower.includes("completed")) return "completed";
      if (lower.includes("fail")) return "failed";
      if (lower.includes("cancel")) return "cancelled";
      return lower;
    };

    const failValidation = (code, message, extra = {}) => {
      logger.warn("❌ RETURN VALIDATION FAILED", {
        code,
        message,
        sellerOrderId,
        rootOrderId,
        authUid,
        ...extra,
      });
      throw new HttpsError(code, message);
    };

    if (!sellerOrderId) {
      failValidation("invalid-argument", "sellerOrderId required");
    }

    if (!rootOrderId) {
      failValidation("invalid-argument", "rootOrderId required");
    }

    if (!reason) {
      failValidation("invalid-argument", "reason required");
    }

    if (!description && reason !== "changed_mind") {
      failValidation("invalid-argument", "description required", { reason });
    }

    if (rawReturnItems.length === 0) {
      failValidation("invalid-argument", "returnItems required");
    }

    logger.info("🔎 RETURN SELLER ORDER LOOKUP", {
      sellerOrderId,
      rootOrderId,
      lookupPath: `sellerOrders/${sellerOrderId}`,
    });

    let sellerOrderRef = db.collection("sellerOrders").doc(sellerOrderId);
    let sellerOrderSnap = await sellerOrderRef.get();

    if (!sellerOrderSnap.exists) {
      logger.warn("⚠️ RETURN SELLER ORDER LOOKUP MISS", {
        sellerOrderId,
        rootOrderId,
      });

      const candidatesSnap = await db
        .collection("sellerOrders")
        .where("rootOrderId", "==", rootOrderId)
        .limit(10)
        .get();

      logger.info("🔎 RETURN SELLER ORDER CANDIDATES", {
        rootOrderId,
        candidateCount: candidatesSnap.size,
        candidateIds: candidatesSnap.docs.map((doc) => doc.id),
      });

      if (candidatesSnap.size === 1) {
        sellerOrderRef = candidatesSnap.docs[0].ref;
        sellerOrderSnap = candidatesSnap.docs[0];
        logger.info("✅ RETURN SELLER ORDER FALLBACK RESOLVED", {
          sellerOrderId: sellerOrderSnap.id,
          rootOrderId,
        });
      }
    }

    if (!sellerOrderSnap.exists) {
      failValidation("not-found", "Seller order not found", {
        lookupPath: `sellerOrders/${sellerOrderId}`,
      });
    }

    const sellerOrder = sellerOrderSnap.data() || {};
    const rootOrderSnap = await db.collection("orders").doc(rootOrderId).get();
    const rootOrder = rootOrderSnap.exists ? rootOrderSnap.data() || {} : {};
    const buyerUid = sellerOrder.buyerUid || sellerOrder.userId || null;
    const sellerUid =
      sellerOrder.sellerUid ||
      sellerOrder.sellerSnapshot?.ownerUid ||
      sellerOrder.shopId ||
      null;
    const businessId = sellerOrder.businessId || sellerOrder.shopId || null;
    const sellerPayment = sellerOrder?.payment || {};
    const rootPayment = rootOrder?.payment || {};
    const paymentId =
      sellerPayment.paymentId ||
      rootPayment.paymentId ||
      rootOrder.paymentId ||
      null;
    const paymentProvider =
      sellerPayment.paymentProvider ||
      sellerPayment.provider ||
      rootPayment.paymentProvider ||
      rootPayment.provider ||
      null;
    const paymentTransactionIds = extractPaymentTransactionIds(
      sellerPayment.paymentTransactionIds ||
      sellerPayment.itemTransactions ||
      rootPayment.paymentTransactionIds ||
      rootPayment.itemTransactions ||
      []
    );
    const paymentTransactionId =
      sellerPayment.paymentTransactionId ||
      rootPayment.paymentTransactionId ||
      (paymentTransactionIds.length > 0 ? paymentTransactionIds[0] : null);
    const conversationId =
      sellerPayment.conversationId ||
      rootPayment.conversationId ||
      rootOrder.payment?.conversationId ||
      null;

    logger.info("🧾 RETURN SELLER ORDER RESOLVED", {
      sellerOrderId: sellerOrderSnap.id,
      rootOrderId: sellerOrder.rootOrderId || null,
      buyerUid,
      sellerUid,
      businessId,
      paymentId,
      paymentTransactionId,
      paymentTransactionIds,
      status: sellerOrder.status || null,
      deliveredAt:
        sellerOrder?.shipping?.deliveredAt ||
        sellerOrder?.deliveredAt ||
        sellerOrder?.timeline?.find?.((step) =>
          normalizeLower(step?.status) === "delivered"
        )?.at ||
        null,
      returnItemCount: rawReturnItems.length,
      imageCount: rawImages.length,
    });

    if (!buyerUid) {
      failValidation("failed-precondition", "Missing buyerUid", {
        sellerOrderId: sellerOrderSnap.id,
      });
    }

    if (!sellerUid || !businessId) {
      failValidation("failed-precondition", "Missing seller identity", {
        sellerUid,
        businessId,
        sellerOrderId: sellerOrderSnap.id,
      });
    }

    const isAdmin = await isAdminUser(db, authUid);
    if (authUid !== buyerUid && !isAdmin) {
      failValidation("permission-denied", "Only the buyer can create a return", {
        buyerUid,
        authUid,
        isAdmin,
      });
    }

    const status = normalizeStatus(sellerOrder.status || "");
    if (status !== "delivered") {
      failValidation(
        "failed-precondition",
        "Return requests are only allowed after delivery",
        { status, sellerOrderStatus: sellerOrder.status || null }
      );
    }

    const deliveredAtRaw =
      sellerOrder?.shipping?.deliveredAt ||
      sellerOrder?.deliveredAt ||
      sellerOrder?.timeline?.find?.((step) =>
        normalizeLower(step?.status) === "delivered"
      )?.at ||
      null;
    const deliveredMillis = toMillisSafe(deliveredAtRaw);

    if (!deliveredMillis) {
      failValidation("failed-precondition", "Delivered timestamp not found", {
        deliveredAtRaw,
      });
    }

    const orderItems = Array.isArray(sellerOrder.items) ? sellerOrder.items : [];
    const orderItemsByProductId = new Map(
      orderItems.map((item) => [String(item.productId || ""), item])
    );

    const normalizedReturnItems = [];
    const shippingPayerSources = [];
    let calculatedRefundAmount = 0;
    let effectiveReturnWindowDays = null;

    for (const rawItem of rawReturnItems) {
      const productId = String(rawItem?.productId || "").trim();
      const quantity = Math.max(1, asNumber(rawItem?.quantity, 1));

      if (!productId) {
        failValidation("invalid-argument", "Return item missing productId", {
          rawItem,
        });
      }

      const orderItem = orderItemsByProductId.get(productId);
      if (!orderItem) {
        failValidation(
          "failed-precondition",
          `Return item not in order: ${productId}`,
          { productId, sellerOrderId: sellerOrderSnap.id }
        );
      }

      const orderQuantity = Math.max(1, asNumber(orderItem.quantity, 1));
      if (quantity > orderQuantity) {
        failValidation("invalid-argument", `Invalid quantity for ${productId}`, {
          productId,
          quantity,
          orderQuantity,
        });
      }

      const productSnap = await db
        .collection("businesses")
        .doc(String(businessId))
        .collection("products")
        .doc(productId)
        .get();

      if (!productSnap.exists) {
        failValidation("not-found", `Product not found: ${productId}`, {
          businessId,
          productId,
        });
      }

      const productData = productSnap.data() || {};
      if (productData.allowReturns !== true) {
        failValidation(
          "failed-precondition",
          `Returns are disabled for ${productId}`,
          { productId, businessId }
        );
      }

      const productWindowDays = Math.max(
        1,
        asNumber(
          productData.returnWindowDays ||
          sellerOrder.returnWindowDays ||
          14,
          14
        )
      );
      effectiveReturnWindowDays =
        effectiveReturnWindowDays == null
          ? productWindowDays
          : Math.min(effectiveReturnWindowDays, productWindowDays);

      shippingPayerSources.push(
        productData.returnShippingPayer || "seller_if_contract_carrier"
      );

      const unitPrice = asNumber(
        orderItem.unitPrice ?? orderItem.price ?? orderItem.subtotal,
        0
      );
      const lineTotal = Number((unitPrice * quantity).toFixed(2));
      calculatedRefundAmount += lineTotal;

      normalizedReturnItems.push({
        productId,
        name: String(orderItem.name || rawItem.name || ""),
        quantity,
        unitPrice,
        lineTotal,
        imageUrl: orderItem.imageUrl || rawItem.imageUrl || null,
      });
    }

    const windowDays = effectiveReturnWindowDays || returnWindowDaysInput;
    const deadline = deliveredMillis + windowDays * 24 * 60 * 60 * 1000;
    if (Date.now() > deadline) {
      failValidation("failed-precondition", "Return window expired", {
        deadline,
        deliveredMillis,
        windowDays,
      });
    }

    const shippingResponsibility =
      shippingResponsibilityInput ||
      resolveReturnShippingResponsibility(shippingPayerSources);

    const returnRef = db.collection("order_returns").doc();
    console.log("💳 REFUND PAYMENT META", {
      paymentId,
      paymentProvider,
      returnId: returnRef.id,
      orderId: rootOrderId,
      conversationId,
    });
    const uploadedImages = await uploadReturnImagesToStorage({
      bucket,
      returnId: returnRef.id,
      sellerOrderId,
      images: rawImages,
    });

    const requestedAt = admin.firestore.FieldValue.serverTimestamp();
    const timeline = [];
    addReturnTimelineStep(timeline, "pending", authUid, "created");

    const refundAmount = Number(
      (
        requestedRefundAmount > 0
          ? requestedRefundAmount
          : calculatedRefundAmount
      ).toFixed(2)
    );

    const payload = {
      returnId: returnRef.id,
      orderId: rootOrderId,
      sellerOrderId,
      rootOrderId,
      buyerUid,
      sellerUid,
      businessId,
      status: "pending",
      reason,
      description,
      images: uploadedImages.map((i) => i.url),
      returnItems: normalizedReturnItems,
      requestedAt,
      reviewedAt: null,
      resolvedAt: null,
      refundAmount,
      refundType,
      shippingResponsibility,
      trackingNumber: null,
      carrier: null,
      paymentId,
      paymentProvider,
      paymentTransactionId,
      paymentTransactionIds,
      conversationId,
      adminNotes: null,
      sellerNotes: null,
      refundDetails: {
        requestedRefundAmount: refundAmount,
        currency:
          sellerOrder?.pricing?.currency ||
          sellerOrder?.currency ||
          rootOrder?.payment?.currency ||
          rootOrder?.currency ||
          "TRY",
        paymentId,
        paymentProvider,
        paymentTransactionId,
        paymentTransactionIds,
        iyzicoPaymentTransactionId: paymentTransactionId,
        conversationId,
      },
      returnWindowDays: windowDays,
      imagesMeta: uploadedImages,
      timeline,
      createdAt: requestedAt,
      updatedAt: requestedAt,
    };

    await returnRef.set(payload);

    logger.info("✅ RETURN REQUEST CREATED", {
      returnId: returnRef.id,
      sellerOrderId,
      buyerUid,
      sellerUid,
      businessId,
      refundAmount,
      itemCount: normalizedReturnItems.length,
    });

    await createNotification(db, {
      recipientUserId: sellerUid,
      userId: sellerUid,
      type: "order_return_requested",
      title: "Return requested",
      body: `Return request created for order ${sellerOrderId}`,
      sellerOrderId,
      orderId: rootOrderId,
      returnId: returnRef.id,
    });

    return {
      success: true,
      returnId: returnRef.id,
    };
  }
);

exports.reviewOrderReturnRequest = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    const db = admin.firestore();
    const authUid = request.auth?.uid;

    logger.info("🔔 RETURN REVIEW START", {
      authUid: authUid || null,
      rawData: request.data || null,
    });

    if (!authUid) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const data = request.data || {};
    const returnId = String(data.returnId || "").trim();
    const action = normalizeLower(data.action);
    const notes = String(data.notes || "").trim();
    const shippingResponsibility = normalizeLower(data.shippingResponsibility);

    if (!returnId) {
      throw new HttpsError("invalid-argument", "returnId required");
    }

    if (!["approved", "rejected"].includes(action)) {
      throw new HttpsError("invalid-argument", "Invalid return action");
    }

    const returnRef = db.collection("order_returns").doc(returnId);
    const returnSnap = await returnRef.get();

    if (!returnSnap.exists) {
      throw new HttpsError("not-found", "Return request not found");
    }

    const returnData = returnSnap.data() || {};
    const businessId = returnData.businessId || null;
    const sellerUid = returnData.sellerUid || null;
    const buyerUid = returnData.buyerUid || null;

    const isAdmin = await isAdminUser(db, authUid);
    const businessSnap = businessId
      ? await db.collection("businesses").doc(String(businessId)).get()
      : null;
    const ownerUid = businessSnap?.exists
      ? businessSnap.data()?.ownerUid || null
      : null;

    if (
      !isAdmin &&
      authUid !== sellerUid &&
      authUid !== ownerUid
    ) {
      throw new HttpsError("permission-denied", "Not allowed");
    }

    if (normalizeReturnStatus(returnData.status) !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        `Return is already ${returnData.status}`
      );
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const timeline = Array.isArray(returnData.timeline)
      ? [...returnData.timeline]
      : [];

    addReturnTimelineStep(
      timeline,
      action,
      authUid,
      notes || null,
      shippingResponsibility ? { shippingResponsibility } : {}
    );

    const updateData = {
      status: action,
      reviewedAt: now,
      updatedAt: now,
      sellerNotes: notes || returnData.sellerNotes || null,
      ...(shippingResponsibility
        ? { shippingResponsibility }
        : {}),
      ...(action === "approved"
        ? {
          refundDetails: {
            ...(returnData.refundDetails || {}),
            shippingResponsibility:
              shippingResponsibility || returnData.shippingResponsibility || null,
          },
        }
        : {}),
    };

    await returnRef.set(updateData, { merge: true });

    logger.info("✅ RETURN REVIEWED", {
      returnId,
      action,
      authUid,
      businessId,
    });

    await createNotification(db, {
      recipientUserId: buyerUid,
      userId: buyerUid,
      type: action === "approved" ? "order_return_approved" : "order_return_rejected",
      title: action === "approved" ? "Return approved" : "Return rejected",
      body:
        action === "approved"
          ? `Return request ${returnId} was approved`
          : `Return request ${returnId} was rejected`,
      orderId: returnData.rootOrderId || returnData.orderId || null,
      sellerOrderId: returnData.sellerOrderId || null,
      returnId,
    });

    return { success: true };
  }
);

exports.cancelOrderReturnRequest = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    const db = admin.firestore();
    const authUid = request.auth?.uid;

    if (!authUid) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const { returnId, notes } = request.data || {};
    const safeReturnId = String(returnId || "").trim();

    if (!safeReturnId) {
      throw new HttpsError("invalid-argument", "returnId required");
    }

    const returnRef = db.collection("order_returns").doc(safeReturnId);
    const returnSnap = await returnRef.get();

    if (!returnSnap.exists) {
      throw new HttpsError("not-found", "Return request not found");
    }

    const returnData = returnSnap.data() || {};
    if (returnData.buyerUid !== authUid) {
      throw new HttpsError("permission-denied", "Not allowed");
    }

    if (normalizeReturnStatus(returnData.status) !== "pending") {
      throw new HttpsError(
        "failed-precondition",
        "Only pending requests can be cancelled"
      );
    }

    const timeline = Array.isArray(returnData.timeline)
      ? [...returnData.timeline]
      : [];
    addReturnTimelineStep(timeline, "cancelled", authUid, notes || null);

    await returnRef.set(
      {
        status: "cancelled",
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        buyerNotes: notes || returnData.buyerNotes || null,
        timeline,
      },
      { merge: true }
    );

    await createNotification(db, {
      recipientUserId: returnData.sellerUid,
      userId: returnData.sellerUid,
      type: "order_return_cancelled",
      title: "Return cancelled",
      body: `Return request ${safeReturnId} was cancelled`,
      orderId: returnData.rootOrderId || returnData.orderId || null,
      sellerOrderId: returnData.sellerOrderId || null,
      returnId: safeReturnId,
    });

    logger.info("✅ RETURN CANCELLED", {
      returnId: safeReturnId,
      authUid,
    });

    return { success: true };
  }
);

exports.markOrderReturnShippedBack = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    const db = admin.firestore();
    const authUid = request.auth?.uid;

    try {
      if (!authUid) {
        console.error("❌ INVALID_ACTOR", {
          returnId: null,
          authUid: null,
          currentStatus: null,
          sellerUid: null,
          businessId: null,
          buyerUid: null,
          trackingNumber: null,
          carrier: null,
          reason: "missing authUid",
        });
        throw new HttpsError("unauthenticated", "Login required");
      }

      const { returnId, trackingNumber, carrier, notes } = request.data || {};
      const safeReturnId = String(returnId || "").trim();
      const safeTracking = String(trackingNumber || "").trim();
      const safeCarrier = String(carrier || "").trim();

      if (!safeReturnId) {
        console.error("❌ RETURN_ID_REQUIRED", {
          returnId: null,
          authUid,
          currentStatus: null,
          sellerUid: null,
          businessId: null,
          buyerUid: null,
          trackingNumber: safeTracking || null,
          carrier: safeCarrier || null,
        });
        throw new HttpsError("invalid-argument", "returnId required");
      }

      const returnRef = db.collection("order_returns").doc(safeReturnId);
      const returnSnap = await returnRef.get();

      if (!returnSnap.exists) {
        console.error("❌ RETURN_NOT_FOUND", {
          returnId: safeReturnId,
          authUid,
          currentStatus: null,
          sellerUid: null,
          businessId: null,
          buyerUid: null,
          trackingNumber: safeTracking || null,
          carrier: safeCarrier || null,
        });
        throw new HttpsError("not-found", "Return request not found");
      }

      const returnData = returnSnap.data() || {};
      console.log("📦 SHIPPED BACK SNAPSHOT", returnData);

      const businessId = returnData.businessId || null;
      const trackingInfo = {
        returnId: safeReturnId,
        authUid,
        currentStatus: returnData.status || null,
        sellerUid: returnData.sellerUid || null,
        buyerUid: returnData.buyerUid || null,
        businessId,
        trackingNumber: safeTracking || null,
        carrier: safeCarrier || null,
      };

      logger.info("🧪 SHIPPED BACK VALIDATION", {
        ...trackingInfo,
        expectedPreviousStatus: "approved",
      });

      const failShippedBackValidation = (reason, code, message, extra = {}) => {
        console.error(`❌ ${reason}`, {
          ...trackingInfo,
          ...extra,
        });
        throw new HttpsError(code, message);
      };

      if (returnData.buyerUid !== authUid && !(await isAdminUser(db, authUid))) {
        failShippedBackValidation("BUYER_MISMATCH", "permission-denied", "Not allowed", {
          expectedActor: returnData.buyerUid || null,
        });
      }

      if (!safeTracking) {
        failShippedBackValidation(
          "INVALID_TRACKING",
          "invalid-argument",
          "trackingNumber required"
        );
      }

      if (!safeCarrier) {
        failShippedBackValidation(
          "INVALID_CARRIER",
          "invalid-argument",
          "carrier required"
        );
      }

      const currentStatus = normalizeReturnStatus(returnData.status);
      if (currentStatus === "shipped_back") {
        failShippedBackValidation(
          "ALREADY_SHIPPED",
          "failed-precondition",
          "Return is already shipped back",
          { currentStatus }
        );
      }

      if (currentStatus !== "approved") {
        failShippedBackValidation(
          "INVALID_STATUS",
          "failed-precondition",
          "Return must be approved before shipping back",
          { currentStatus, expectedPreviousStatus: "approved" }
        );
      }

      const timeline = Array.isArray(returnData.timeline)
        ? [...returnData.timeline]
        : [];
      addReturnTimelineStep(timeline, "shipped_back", authUid, notes || null, {
        trackingNumber: safeTracking,
        carrier: safeCarrier,
      });

      await returnRef.set(
        {
          status: "shipped_back",
          trackingNumber: safeTracking,
          carrier: safeCarrier,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          timeline,
        },
        { merge: true }
      );

      await createNotification(db, {
        recipientUserId: returnData.sellerUid,
        userId: returnData.sellerUid,
        type: "order_return_shipped_back",
        title: "Return shipped back",
        body: `Return request ${safeReturnId} has been shipped back`,
        orderId: returnData.rootOrderId || returnData.orderId || null,
        sellerOrderId: returnData.sellerOrderId || null,
        returnId: safeReturnId,
      });

      logger.info("✅ RETURN SHIPPED BACK", {
        returnId: safeReturnId,
        authUid,
        trackingNumber: safeTracking,
        carrier: safeCarrier,
      });

      return { success: true };
    } catch (error) {
      console.error("❌ SHIPPED BACK FATAL", error);
      throw error;
    }
  }
);

exports.markOrderReturnReceived = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    const db = admin.firestore();
    const authUid = request.auth?.uid;

    if (!authUid) {
      console.error("❌ INVALID_ACTOR", {
        returnId: null,
        authUid: null,
        currentStatus: null,
        sellerUid: null,
        businessId: null,
        buyerUid: null,
        reason: "missing authUid",
      });
      throw new HttpsError("unauthenticated", "Login required");
    }

    const { returnId, notes } = request.data || {};
    const safeReturnId = String(returnId || "").trim();

    if (!safeReturnId) {
      console.error("❌ RETURN_ID_REQUIRED", {
        returnId: null,
        authUid,
        currentStatus: null,
        sellerUid: null,
        businessId: null,
        buyerUid: null,
      });
      throw new HttpsError("invalid-argument", "returnId required");
    }

    const returnRef = db.collection("order_returns").doc(safeReturnId);
    const returnSnap = await returnRef.get();

    if (!returnSnap.exists) {
      console.error("❌ RETURN_NOT_FOUND", {
        returnId: safeReturnId,
        authUid: authUid || null,
        currentStatus: null,
        sellerUid: null,
        businessId: null,
        buyerUid: null,
      });
      throw new HttpsError("not-found", "Return request not found");
    }

    const returnData = returnSnap.data() || {};
    console.log("📦 RETURN SNAPSHOT", returnData);
    const businessId = returnData.businessId || null;
    const businessSnap = businessId
      ? await db.collection("businesses").doc(String(businessId)).get()
      : null;
    const ownerUid = businessSnap?.exists
      ? businessSnap.data()?.ownerUid || null
      : null;

    logger.info("🧪 RETURN RECEIVE VALIDATION", {
      returnId: safeReturnId,
      authUid,
      currentStatus: returnData.status || null,
      sellerUid: returnData.sellerUid || null,
      businessId,
      buyerUid: returnData.buyerUid || null,
      ownerUid,
      allowedActor:
        authUid === returnData.sellerUid ||
        authUid === ownerUid ||
        (await isAdminUser(db, authUid)),
      expectedPreviousStatus: "approved|shipped_back",
    });

    if (
      authUid !== returnData.sellerUid &&
      authUid !== ownerUid &&
      !(await isAdminUser(db, authUid))
    ) {
      console.error("❌ INVALID_ACTOR", {
        returnId: safeReturnId,
        authUid,
        currentStatus: returnData.status || null,
        sellerUid: returnData.sellerUid || null,
        businessId,
        buyerUid: returnData.buyerUid || null,
        ownerUid,
      });
      throw new HttpsError("permission-denied", "Not allowed");
    }

    const currentStatus = normalizeReturnStatus(returnData.status);
    console.error("🧪 RETURN_STATUS_CHECK", {
      returnId: safeReturnId,
      authUid,
      currentStatus,
      sellerUid: returnData.sellerUid || null,
      businessId,
      buyerUid: returnData.buyerUid || null,
      expectedPreviousStatus: "approved|shipped_back",
    });
    if (!["approved", "shipped_back"].includes(currentStatus)) {
      console.error("❌ INVALID_STATUS", {
        returnId: safeReturnId,
        authUid,
        currentStatus,
        sellerUid: returnData.sellerUid || null,
        businessId,
        buyerUid: returnData.buyerUid || null,
        expectedPreviousStatus: "approved|shipped_back",
      });
      throw new HttpsError(
        "failed-precondition",
        "Return must be approved or shipped back before marking received"
      );
    }

    const timeline = Array.isArray(returnData.timeline)
      ? [...returnData.timeline]
      : [];
    addReturnTimelineStep(timeline, "received_by_seller", authUid, notes || null);

    await returnRef.set(
      {
        status: "received_by_seller",
        reviewedAt:
          returnData.reviewedAt || admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        sellerNotes: notes || returnData.sellerNotes || null,
        timeline,
      },
      { merge: true }
    );

    await createNotification(db, {
      recipientUserId: returnData.buyerUid,
      userId: returnData.buyerUid,
      type: "order_return_received",
      title: "Return received",
      body: `Seller received return request ${safeReturnId}`,
      orderId: returnData.rootOrderId || returnData.orderId || null,
      sellerOrderId: returnData.sellerOrderId || null,
      returnId: safeReturnId,
    });

    logger.info("✅ RETURN RECEIVED BY SELLER", {
      returnId: safeReturnId,
      authUid,
    });

    return { success: true };
  }
);

exports.triggerOrderReturnRefund = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 60,
    memory: "512MiB",
    secrets: [IYZICO_API_KEY, IYZICO_SECRET_KEY],
  },
  async (request) => {
    const db = admin.firestore();
    const authUid = request.auth?.uid;

    logger.info("💸 RETURN REFUND START", {
      authUid: authUid || null,
      rawData: request.data || null,
    });

    if (!authUid) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const data = request.data || {};
    console.log("RETURN REFUND RAW DATA", data);
    const returnId = String(data.returnId || "").trim();
    const refundAmount = asNumber(data.refundAmount, 0);
    const refundType = normalizeLower(data.refundType) || "full";
    const notes = String(data.notes || "").trim();
    const paymentId = String(data.paymentId || "").trim();
    console.log("RETURN REFUND VALIDATION ENTRY");

    const failRefundValidation = (code, message, extra = {}) => {
      logger.warn("❌ RETURN REFUND VALIDATION FAILED", {
        code,
        message,
        authUid,
        returnId: returnId || null,
        refundAmount,
        refundType,
        paymentId: paymentId || null,
        ...extra,
      });
      throw new HttpsError(code, message);
    };

    if (!returnId) {
      failRefundValidation("invalid-argument", "returnId required");
    }

    if (!(refundAmount > 0)) {
      failRefundValidation("invalid-argument", "refundAmount required");
    }

    const returnRef = db.collection("order_returns").doc(returnId);
    const returnSnap = await returnRef.get();

    if (!returnSnap.exists) {
      failRefundValidation("not-found", "Return request not found");
    }

    const returnData = returnSnap.data() || {};
    const businessId = returnData.businessId || null;
    const businessSnap = businessId
      ? await db.collection("businesses").doc(String(businessId)).get()
      : null;
    const ownerUid = businessSnap?.exists
      ? businessSnap.data()?.ownerUid || null
      : null;

    if (
      authUid !== returnData.sellerUid &&
      authUid !== ownerUid &&
      !(await isAdminUser(db, authUid))
    ) {
      failRefundValidation("permission-denied", "Not allowed", {
        sellerUid: returnData.sellerUid || null,
        ownerUid: ownerUid || null,
      });
    }

    const returnStatus = normalizeReturnStatus(returnData.status);
    if (returnStatus === "refund_pending") {
      failRefundValidation("failed-precondition", "Refund is already pending", {
        status: returnStatus,
      });
    }

    if (returnStatus === "refunded") {
      failRefundValidation("failed-precondition", "Return is already refunded", {
        status: returnStatus,
      });
    }

    if (!["received_by_seller", "refund_failed"].includes(returnStatus)) {
      failRefundValidation(
        "failed-precondition",
        "Return must be received before refund",
        { status: returnStatus }
      );
    }

    const sellerOrderId = returnData.sellerOrderId || null;
    const sellerOrderSnap = sellerOrderId
      ? await db.collection("sellerOrders").doc(String(sellerOrderId)).get()
      : null;
    const sellerOrder = sellerOrderSnap?.exists ? sellerOrderSnap.data() || {} : {};
    const rootOrderId = returnData.rootOrderId || returnData.orderId || null;
    const rootOrderSnap = rootOrderId
      ? await db.collection("orders").doc(String(rootOrderId)).get()
      : null;
    const rootOrder = rootOrderSnap?.exists ? rootOrderSnap.data() || {} : {};

    const payment = sellerOrder.payment || {};
    const rootPayment = rootOrder.payment || {};
    const paymentProvider =
      payment.paymentProvider ||
      payment.provider ||
      rootPayment.paymentProvider ||
      rootPayment.provider ||
      returnData.refundDetails?.paymentProvider ||
      null;
    const orderPaymentId =
      payment.paymentId ||
      rootPayment.paymentId ||
      rootOrder.paymentId ||
      returnData.paymentId ||
      returnData.refundDetails?.paymentId ||
      paymentId;
    if (!orderPaymentId) {
      failRefundValidation("failed-precondition", "paymentId required", {
        sellerOrderId,
        rootOrderId,
      });
    }
    const currency =
      payment.currency ||
      sellerOrder.currency ||
      rootPayment.currency ||
      rootOrder.currency ||
      "TRY";
    const buyerUid = returnData.buyerUid || null;
    console.log("💳 REFUND PAYMENT META", {
      paymentId: orderPaymentId,
      paymentProvider,
      returnId,
      orderId: rootOrderId,
    });
    const originalPaidAmount = Math.max(
      0,
      asNumber(
        payment.paidPrice ??
        sellerOrder?.pricing?.grandTotal ??
        sellerOrder?.financial?.grossAmount ??
        sellerOrder?.payment?.price ??
        0,
        0
      )
    );
    const returnItemsAmount = Number(
      sumReturnItemAmount(Array.isArray(returnData.returnItems) ? returnData.returnItems : []).toFixed(2)
    );
    const shippingAmount = Math.max(
      0,
      asNumber(
        sellerOrder?.pricing?.shippingTotal ??
        sellerOrder?.shipping?.price ??
        sellerOrder?.shipping?.amount ??
        0,
        0
      )
    );
    const maxAllowedRefund =
      refundType === "shipping"
        ? shippingAmount
        : refundType === "full"
          ? Math.min(originalPaidAmount, returnItemsAmount + shippingAmount)
          : Math.min(originalPaidAmount, returnItemsAmount);
    const requestedRefundAmount =
      refundAmount > 0 ? refundAmount : asNumber(returnData.refundAmount, 0);
    const clampedRefundAmount = Number(
      Math.min(
        requestedRefundAmount > 0 ? requestedRefundAmount : maxAllowedRefund,
        maxAllowedRefund || requestedRefundAmount || 0,
        originalPaidAmount || requestedRefundAmount || 0
      ).toFixed(2)
    );
    if (!(clampedRefundAmount > 0)) {
      failRefundValidation("failed-precondition", "Refund amount must be greater than zero", {
        originalPaidAmount,
        returnItemsAmount,
        shippingAmount,
        refundType,
      });
    }
    const existingRetryCount = asNumber(
      returnData.refundRetryCount ??
      returnData.refundDetails?.retryCount ??
      0,
      0
    );
    const retryCount = existingRetryCount + 1;
    const sellerPaymentTransactionIds = extractPaymentTransactionIds(
      payment.paymentTransactionIds ||
      payment.itemTransactions ||
      returnData.refundDetails?.paymentTransactionIds ||
      []
    );
    const sellerPaymentTransactionId =
      payment.paymentTransactionId ||
      returnData.refundDetails?.paymentTransactionId ||
      (sellerPaymentTransactionIds.length > 0
        ? sellerPaymentTransactionIds[0]
        : null);

    logger.info("🧾 RETURN REFUND VALIDATED", {
      returnId,
      sellerOrderId,
      rootOrderId: returnData.rootOrderId || null,
      authUid,
      sellerUid: returnData.sellerUid || null,
      ownerUid: ownerUid || null,
      returnStatus,
      originalPaidAmount,
      returnItemsAmount,
      shippingAmount,
      requestedRefundAmount,
      clampedRefundAmount,
      retryCount,
      paymentTransactionId: sellerPaymentTransactionId,
      paymentTransactionIds: sellerPaymentTransactionIds,
    });

    if (!sellerOrderSnap?.exists) {
      failRefundValidation("not-found", "Seller order not found", {
        sellerOrderId,
        rootOrderId: returnData.rootOrderId || null,
      });
    }

    const iyzi = new Iyzipay({
      apiKey: IYZICO_API_KEY.value(),
      secretKey: IYZICO_SECRET_KEY.value(),
      uri: "https://sandbox-api.iyzipay.com",
    });

    const pendingAt = admin.firestore.FieldValue.serverTimestamp();
    const timeline = Array.isArray(returnData.timeline)
      ? [...returnData.timeline]
      : [];
    addReturnTimelineStep(timeline, "refund_pending", authUid, notes || null, {
      requestedRefundAmount,
      clampedRefundAmount,
      retryCount,
      paymentId: orderPaymentId,
      paymentTransactionId: sellerPaymentTransactionId,
    });

    await returnRef.set(
      {
        status: "refund_pending",
        refundRequestedAt: returnData.refundRequestedAt || pendingAt,
        refundStartedAt: pendingAt,
        updatedAt: pendingAt,
        refundAmount: clampedRefundAmount,
        refundType,
        refundRetryCount: retryCount,
        paymentTransactionId: sellerPaymentTransactionId || null,
        paymentTransactionIds: sellerPaymentTransactionIds,
        refundDetails: {
          ...(returnData.refundDetails || {}),
          status: "refund_pending",
          retryCount,
          paymentId: orderPaymentId,
          paymentTransactionId: sellerPaymentTransactionId || null,
          paymentTransactionIds: sellerPaymentTransactionIds,
          refundRequestedAmount: requestedRefundAmount,
          clampedRefundAmount,
          originalPaidAmount,
          returnItemsAmount,
          shippingAmount,
          currency,
          method: "iyzico",
          rawRequest: {
            returnId,
            refundAmount: clampedRefundAmount,
            refundType,
            paymentId: orderPaymentId,
            retryCount,
          },
        },
        adminNotes: notes || returnData.adminNotes || null,
        timeline,
      },
      { merge: true }
    );

    try {
      const refundResult = await new Promise((resolve, reject) => {
        iyzi.refundV2.create(
          {
            locale: Iyzipay.LOCALE.TR,
            conversationId: returnId,
            paymentId: orderPaymentId,
            price: clampedRefundAmount.toString(),
            currency,
            ip: request.rawRequest?.ip || "85.34.78.112",
          },
          (err, res) => {
            if (err) return reject(err);
            return resolve(res);
          }
        );
      });

      logger.info("💸 RETURN REFUND IYZICO RESPONSE", {
        returnId,
        retryCount,
        response: refundResult || null,
      });

      if (!refundResult || normalizeLower(refundResult.status) !== "success") {
        logger.error("❌ RETURN REFUND FAILED", {
          returnId,
          retryCount,
          refundResult,
        });

        const failedAt = admin.firestore.FieldValue.serverTimestamp();
        const failedTimeline = Array.isArray(returnData.timeline)
          ? [...returnData.timeline]
          : [];
        addReturnTimelineStep(
          failedTimeline,
          "refund_failed",
          authUid,
          notes || null,
          {
            retryCount,
            failureReason: refundResult?.errorMessage || "Refund failed",
            paymentId: orderPaymentId,
            paymentTransactionId: sellerPaymentTransactionId,
          }
        );

        await returnRef.set(
          {
            status: "refund_failed",
            refundFailedAt: failedAt,
            updatedAt: failedAt,
            refundAmount: clampedRefundAmount,
            refundType,
            refundRetryCount: retryCount,
            paymentTransactionId: sellerPaymentTransactionId || null,
            paymentTransactionIds: sellerPaymentTransactionIds,
            refundDetails: {
              ...(returnData.refundDetails || {}),
              status: "refund_failed",
              retryCount,
              errorMessage: refundResult?.errorMessage || null,
              errorCode: refundResult?.errorCode || null,
              paymentId: orderPaymentId,
              paymentTransactionId: sellerPaymentTransactionId || null,
              paymentTransactionIds: sellerPaymentTransactionIds,
              requestedRefundAmount,
              clampedRefundAmount,
              originalPaidAmount,
              returnItemsAmount,
              shippingAmount,
              currency,
              raw: refundResult || null,
            },
            adminNotes: notes || returnData.adminNotes || null,
            timeline: failedTimeline,
          },
          { merge: true }
        );

        await createNotification(db, {
          recipientUserId: buyerUid,
          userId: buyerUid,
          type: "order_return_refund_failed",
          title: "Return refund failed",
          body: `Refund failed for return ${returnId}`,
          orderId: returnData.rootOrderId || returnData.orderId || null,
          sellerOrderId: sellerOrderId || null,
          returnId,
        });

        throw new HttpsError(
          "internal",
          refundResult?.errorMessage || "Refund failed"
        );
      }

      const completedAt = admin.firestore.FieldValue.serverTimestamp();
      const completedTimeline = Array.isArray(returnData.timeline)
        ? [...returnData.timeline]
        : [];
      addReturnTimelineStep(
        completedTimeline,
        "refunded",
        authUid,
        notes || null,
        {
          refundAmount: clampedRefundAmount,
          refundType,
          paymentId: orderPaymentId,
          paymentTransactionId: sellerPaymentTransactionId,
          retryCount,
        }
      );

      await returnRef.set(
        {
          status: "refunded",
          resolvedAt: completedAt,
          refundCompletedAt: completedAt,
          updatedAt: completedAt,
          refundAmount: clampedRefundAmount,
          refundType,
          refundRetryCount: retryCount,
          paymentTransactionId: sellerPaymentTransactionId || null,
          paymentTransactionIds: sellerPaymentTransactionIds,
          refundDetails: {
            ...(returnData.refundDetails || {}),
            status: "refunded",
            gatewayStatus: refundResult.status || "success",
            retryCount,
            paymentId: refundResult.paymentId || orderPaymentId,
            paymentTransactionId: sellerPaymentTransactionId || null,
            paymentTransactionIds: sellerPaymentTransactionIds,
            refundHostReference: refundResult.refundHostReference || null,
            authCode: refundResult.authCode || null,
            hostReference: refundResult.hostReference || null,
            currency: refundResult.currency || currency,
            price: refundResult.price || clampedRefundAmount,
            raw: refundResult,
          },
          adminNotes: notes || returnData.adminNotes || null,
          timeline: completedTimeline,
        },
        { merge: true }
      );

      await createNotification(db, {
        recipientUserId: buyerUid,
        userId: buyerUid,
        type: "order_return_refunded",
        title: "Return refunded",
        body: `Refund completed for return ${returnId}`,
        orderId: returnData.rootOrderId || returnData.orderId || null,
        sellerOrderId: sellerOrderId || null,
        returnId,
      });

      logger.info("✅ RETURN REFUND SUCCESS", {
        returnId,
        refundAmount: clampedRefundAmount,
        refundType,
        paymentId: orderPaymentId,
        retryCount,
      });

      return {
        success: true,
        refundResult,
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      logger.error("❌ RETURN REFUND ERROR", {
        returnId,
        retryCount,
        message: error?.message || String(error),
        stack: error?.stack || null,
      });

      const failedAt = admin.firestore.FieldValue.serverTimestamp();
      const failedTimeline = Array.isArray(returnData.timeline)
        ? [...returnData.timeline]
        : [];
      addReturnTimelineStep(
        failedTimeline,
        "refund_failed",
        authUid,
        notes || null,
        {
          retryCount,
          failureReason: error?.message || String(error),
          paymentId: orderPaymentId,
          paymentTransactionId: sellerPaymentTransactionId,
        }
      );

      await returnRef.set(
        {
          status: "refund_failed",
          refundFailedAt: failedAt,
          updatedAt: failedAt,
          refundAmount: clampedRefundAmount,
          refundType,
          refundRetryCount: retryCount,
          paymentTransactionId: sellerPaymentTransactionId || null,
          paymentTransactionIds: sellerPaymentTransactionIds,
          refundDetails: {
            ...(returnData.refundDetails || {}),
            status: "refund_failed",
            gatewayStatus: "failed",
            retryCount,
            errorMessage: error?.message || String(error),
            paymentId: orderPaymentId,
            paymentTransactionId: sellerPaymentTransactionId || null,
            paymentTransactionIds: sellerPaymentTransactionIds,
            requestedRefundAmount,
            clampedRefundAmount,
            originalPaidAmount,
            returnItemsAmount,
            shippingAmount,
            currency,
            rawError: {
              message: error?.message || String(error),
              stack: error?.stack || null,
            },
          },
          adminNotes: notes || returnData.adminNotes || null,
          timeline: failedTimeline,
        },
        { merge: true }
      );

      throw error;
    }
  }
);

// Backward-compatible aliases for return callables.
exports.createReturnRequest = exports.createOrderReturnRequest;
exports.approveReturnRequest = exports.reviewOrderReturnRequest;
exports.rejectReturnRequest = exports.reviewOrderReturnRequest;
exports.refundOrderReturn = exports.triggerOrderReturnRefund;

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

exports.onInvoiceReadyEmail = onDocumentUpdated(
  {
    region: "europe-west3",
    document: "sellerOrders/{sellerOrderId}",
    secrets: [resendApiKey],
  },
  async (event) => {
    try {
      const db = admin.firestore();
      const sellerOrderId = event.params.sellerOrderId;
      const beforeData = event.data?.before?.data() || {};
      const afterData = event.data?.after?.data() || {};

      if (!isInvoiceReadyTransition(beforeData, afterData)) {
        return null;
      }

      const rootOrderId = firstNonEmptyValue(
        afterData.rootOrderId,
        beforeData.rootOrderId
      );
      const rootOrderSnap = rootOrderId
        ? await db.collection("orders").doc(rootOrderId).get()
        : null;
      const rootOrderData = rootOrderSnap?.exists ? rootOrderSnap.data() || {} : {};

      const buyerUid = firstNonEmptyValue(
        afterData.buyerUid,
        rootOrderData.buyerUid,
        rootOrderData.userId
      );
      const userSnap = buyerUid
        ? await db.collection("users").doc(String(buyerUid)).get()
        : null;
      const userData = userSnap?.exists ? userSnap.data() || {} : {};

      const dispatchId = `invoice_${sellerOrderId}_v1`;
      const dispatchRef = db.collection("invoice_notification_dispatches").doc(dispatchId);
      const claim = await claimInvoiceEmailDispatch({
        dispatchRef,
        sellerOrderId,
        version: 1,
      });

      if (!claim.shouldSend) {
        console.log("invoice email dispatch skipped", {
          sellerOrderId,
          reason: claim.reason,
        });
        return null;
      }

      const resend = new Resend(resendApiKey.value());
      const buyerEmail = resolveInvoiceBuyerEmail(afterData, rootOrderData, userData);
      const buyerName = resolveInvoiceBuyerName(afterData, rootOrderData, userData);
      const orderNumber = resolveInvoiceOrderNumber(afterData, rootOrderData, sellerOrderId);
      const carrierCompany = resolveInvoiceCarrierCompany(afterData, rootOrderData);

      const emailResult = await sendInvoiceReadyEmail({
        resend,
        to: buyerEmail,
        buyerName,
        orderNumber,
        carrierCompany,
      });

      const smsResult = {
        status: "skipped",
        skippedReason: "sms_not_configured",
        providerSid: null,
        error: null,
      };

      if (emailResult.status === "sent") {
        console.log("invoice email sent", {
          sellerOrderId,
          dispatchId,
          messageId: emailResult.messageId || null,
        });
      } else if (emailResult.status === "failed") {
        console.error("invoice email failed", {
          sellerOrderId,
          dispatchId,
          error: emailResult.error || null,
        });
      } else {
        console.log("invoice email skipped", {
          sellerOrderId,
          dispatchId,
          reason: emailResult.skippedReason || "unknown",
        });
      }

      const finalState =
        emailResult.status === "sent"
          ? "sent"
          : emailResult.status === "failed"
            ? "failed"
            : "skipped";

      await markInvoiceEmailDispatch(dispatchRef, {
        sellerOrderId,
        rootOrderId: rootOrderId || null,
        buyerUid: buyerUid || null,
        buyerEmail: buyerEmail || null,
        buyerName: buyerName || null,
        orderNumber: orderNumber || null,
        carrierCompany: carrierCompany || null,
        type: "invoice_ready",
        version: 1,
        state: finalState,
        attemptCount: Number(claim.existing?.attemptCount || 0) + 1,
        channels: {
          email: {
            status: emailResult.status,
            sentAt:
              emailResult.status === "sent"
                ? admin.firestore.FieldValue.serverTimestamp()
                : null,
            messageId: emailResult.messageId || null,
            error: emailResult.error || null,
          },
          sms: {
            status: smsResult.status,
            sentAt: null,
            providerSid: smsResult.providerSid || null,
            error: smsResult.error || null,
            skippedReason: smsResult.skippedReason || null,
          },
        },
      });

      return null;
    } catch (error) {
      console.error("onInvoiceReadyEmail ERROR:", error);
      return null;
    }
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

  const { businessId, title, price, duration, durationMin } = data;

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
  const existingData = existing.data() || {};
  const normalizedPrice = parsePriceFromText(price);
  const normalizedDurationMin = asNumber(
    durationMin ?? durationLabelToMinutes(duration),
    0
  );
  const nextSortOrder = existingData.sortOrder || Date.now();

  if (existing.exists) {
    await serviceRef.update({
      price: normalizedPrice,
      duration: duration ?? null,
      durationMin: normalizedDurationMin,
      sortOrder: nextSortOrder,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { status: "updated", id: slug };
  } else {
    await serviceRef.set({
      title,
      price: normalizedPrice,
      duration: duration ?? null,
      durationMin: normalizedDurationMin,
      currency: "TRY",
      isActive: true,
      sortOrder: nextSortOrder,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { status: "created", id: slug };
  }
});

// =====================================================
// VET APPOINTMENTS — PHASE 3
// =====================================================

const VET_APPOINTMENT_STATUSES = [
  "pending",
  "awaiting_payment",
  "confirmed",
  "confirmed_paid",
  "payment_expired",
  "rejected",
  "completed",
  "cancelled_by_user",
  "cancelled_by_vet",
  "expired",
];

const VET_APPOINTMENT_ALLOWED_TRANSITIONS = {
  pending: ["awaiting_payment", "confirmed", "rejected"],
  awaiting_payment: ["confirmed_paid", "payment_expired", "cancelled_by_vet"],
  confirmed: ["completed", "cancelled_by_vet", "rejected"],
  confirmed_paid: ["completed", "cancelled_by_vet"],
};

const GROOMY_APPOINTMENT_STATUSES = [
  "pending",
  "awaiting_payment",
  "confirmed",
  "confirmed_paid",
  "payment_expired",
  "rejected",
  "completed",
  "cancelled_by_user",
  "cancelled_by_groomy",
  "expired",
];

const GROOMY_APPOINTMENT_ALLOWED_TRANSITIONS = {
  pending: ["awaiting_payment", "confirmed", "rejected"],
  awaiting_payment: [
    "confirmed_paid",
    "payment_expired",
    "cancelled_by_groomy",
  ],
  confirmed: ["completed", "cancelled_by_groomy", "rejected"],
  confirmed_paid: ["completed", "cancelled_by_groomy"],
};

const HOTEL_BOOKING_STATUSES = [
  "pending",
  "awaiting_payment",
  "confirmed",
  "confirmed_paid",
  "checked_in",
  "rejected",
  "cancelled_by_user",
  "cancelled_by_hotel",
  "completed",
  "payment_expired",
  "expired",
];

const HOTEL_BOOKING_ALLOWED_TRANSITIONS = {
  pending: ["awaiting_payment", "confirmed", "rejected", "cancelled_by_hotel"],
  awaiting_payment: [
    "confirmed_paid",
    "payment_expired",
    "cancelled_by_hotel",
  ],
  confirmed: ["checked_in", "completed", "cancelled_by_hotel", "rejected"],
  confirmed_paid: ["checked_in", "completed", "cancelled_by_hotel"],
  checked_in: ["completed", "cancelled_by_hotel"],
};

function assertVetAppointmentStatus(status) {
  const requestedStatus = String(status || "").trim();
  const allowedStatuses = VET_APPOINTMENT_STATUSES;

  console.log("🩺 STATUS VALIDATION CHECK", {
    requestedStatus,
    allowedStatuses,
  });

  if (!allowedStatuses.includes(requestedStatus)) {
    console.log("🩺 INVALID STATUS REJECTED", {
      requestedStatus,
    });
    throw new HttpsError("invalid-argument", `Invalid status: ${requestedStatus}`);
  }
}

function assertGroomyAppointmentStatus(status) {
  const requestedStatus = String(status || "").trim();

  if (!GROOMY_APPOINTMENT_STATUSES.includes(requestedStatus)) {
    throw new HttpsError("invalid-argument", `Invalid status: ${requestedStatus}`);
  }
}

function assertHotelBookingStatus(status) {
  const requestedStatus = String(status || "").trim();

  if (!HOTEL_BOOKING_STATUSES.includes(requestedStatus)) {
    throw new HttpsError("invalid-argument", `Invalid status: ${requestedStatus}`);
  }
}

const DEFAULT_APPOINTMENT_PAYMENT_WINDOW_MINUTES = 15;

function requiresAppointmentPayment(source = {}) {
  const serviceRequiresPayment = source.serviceRequiresPayment;
  const servicePrice = asNumber(source.servicePrice ?? 0, 0);
  const price = asNumber(source.price ?? 0, 0);

  return (
    serviceRequiresPayment === true ||
    servicePrice > 0 ||
    price > 0
  );
}

function resolveAppointmentPaymentPolicy(source = {}) {
  const servicePrice = asNumber(
    source.servicePrice ?? source.price ?? source.grandTotal ?? 0,
    0,
  );
  const price = asNumber(source.price ?? 0, 0);

  const paymentWindowMinutesRaw = asNumber(
    source.paymentWindowMinutes ?? source.paymentWindow ?? 0,
    DEFAULT_APPOINTMENT_PAYMENT_WINDOW_MINUTES,
  );
  const requiresPayment = requiresAppointmentPayment({
    serviceRequiresPayment: source.requiresPayment ?? source.serviceRequiresPayment,
    servicePrice,
    price,
  });

  return {
    requiresPayment,
    servicePrice,
    paymentWindowMinutes:
      paymentWindowMinutesRaw > 0
        ? paymentWindowMinutesRaw
        : DEFAULT_APPOINTMENT_PAYMENT_WINDOW_MINUTES,
  };
}

function buildAppointmentPaymentDeadline(paymentWindowMinutes) {
  const minutes = asNumber(
    paymentWindowMinutes,
    DEFAULT_APPOINTMENT_PAYMENT_WINDOW_MINUTES
  );

  return admin.firestore.Timestamp.fromMillis(
    Date.now() + minutes * 60 * 1000
  );
}

function asDateOrNull(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === "string") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function hotelIntervalsOverlap(aCheckIn, aCheckOut, bCheckIn, bCheckOut) {
  return aCheckIn < bCheckOut && aCheckOut > bCheckIn;
}

function hotelMaxCapacity(businessData = {}) {
  const sectorData = businessData.sectorData || {};
  const hotelData =
    sectorData.pet_hotel || sectorData.hotel || sectorData.petHotel || {};
  const capacity = hotelData.capacity || {};
  return asNumber(
    capacity.maxCapacity ?? hotelData.maxCapacity ?? businessData.maxCapacity,
    25
  );
}

async function countOverlappingHotelBookings({
  businessId,
  checkInDate,
  checkOutDate,
  statuses,
  excludeBookingId = null,
}) {
  const snap = await db
    .collection("hotel_bookings")
    .where("businessId", "==", businessId)
    .where("status", "in", statuses)
    .get();

  let count = 0;
  for (const doc of snap.docs) {
    if (excludeBookingId && doc.id === excludeBookingId) continue;
    const data = doc.data() || {};
    const existingCheckIn = asDateOrNull(data.checkInDate);
    const existingCheckOut = asDateOrNull(data.checkOutDate);
    if (!existingCheckIn || !existingCheckOut) continue;
    if (
      hotelIntervalsOverlap(
        existingCheckIn,
        existingCheckOut,
        checkInDate,
        checkOutDate
      )
    ) {
      count += 1;
    }
  }

  return count;
}

async function assertHotelCapacityAvailable({
  businessId,
  checkInDate,
  checkOutDate,
  excludeBookingId = null,
  includePending = false,
}) {
  const businessSnap = await db.collection("businesses").doc(businessId).get();
  if (!businessSnap.exists) {
    throw new HttpsError("not-found", "Business not found.");
  }

  const maxCapacity = hotelMaxCapacity(businessSnap.data() || {});
  const statuses = includePending
    ? ["pending", "awaiting_payment", "confirmed", "confirmed_paid", "checked_in"]
    : ["awaiting_payment", "confirmed", "confirmed_paid", "checked_in"];
  const overlapping = await countOverlappingHotelBookings({
    businessId,
    checkInDate,
    checkOutDate,
    statuses,
    excludeBookingId,
  });

  if (overlapping >= maxCapacity) {
    throw new HttpsError(
      "already-exists",
      "Pet hotel capacity is full for the selected dates."
    );
  }

  return { businessSnap, maxCapacity, overlapping };
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
    const { appointmentId } = request.data || {};
    const newStatus = String(
      request.data?.newStatus || request.data?.status || "",
    ).trim();

    if (!appointmentId || typeof appointmentId !== "string") {
      throw new HttpsError("invalid-argument", "appointmentId is required.");
    }

    if (!newStatus) {
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
      const businessId = data.businessId;
      const ownerUid = data.userId || null;
      const isAdminUser = await db
        .collection("users")
        .doc(uid)
        .get()
        .then((userSnap) => (userSnap.exists ? userSnap.data()?.role === "admin" : false))
        .catch(() => false);

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
      const businessOwnerUid = businessData.ownerUid || businessData.uid;
      const appointmentOwnerUid = data.userId || data.buyerUid || null;
      const isOwner = appointmentOwnerUid === uid;
      const isBusinessOwner = businessOwnerUid === uid;
      const canUseStaffFlow = isBusinessOwner || isAdminUser;
      const isOwnerCancellation = newStatus === "cancelled_by_user";
      const ownerCancelableStatuses = [
        "pending",
        "awaiting_payment",
        "confirmed",
        "confirmed_paid",
        "awaiting_service",
      ];
      const isApprovalAttempt =
        currentStatus === "pending" &&
        (newStatus === "confirmed" || newStatus === "awaiting_payment");
      let approvalPolicySource = data;

      if (
        isApprovalAttempt &&
        businessId &&
        data.serviceId &&
        (!data.serviceRequiresPayment ||
          data.serviceRequiresPayment === null ||
          data.serviceRequiresPayment === undefined)
      ) {
        try {
          const serviceRef = db
            .collection("businesses")
            .doc(businessId)
            .collection("services")
            .doc(data.serviceId);

          const serviceSnap = await tx.get(serviceRef);
          if (serviceSnap.exists) {
            const serviceData = serviceSnap.data() || {};
            approvalPolicySource = {
              ...data,
              ...serviceData,
              servicePrice: serviceData.price ?? data.servicePrice ?? data.price ?? 0,
              price: serviceData.price ?? data.servicePrice ?? data.price ?? 0,
              paymentWindowMinutes:
                serviceData.paymentWindowMinutes ??
                data.paymentWindowMinutes ??
                data.paymentWindow ??
                0,
              requiresPayment: serviceData.requiresPayment,
              requiresDeposit: serviceData.requiresDeposit,
            };
          }
        } catch (error) {
          logger.warn("⚠️ Approval service lookup failed", {
            appointmentId,
            businessId,
            serviceId: data.serviceId || null,
            message: error?.message || String(error),
          });
        }
      }

      const paymentPolicy = resolveAppointmentPaymentPolicy(approvalPolicySource);
      const requiresPayment = requiresAppointmentPayment({
        serviceRequiresPayment:
          approvalPolicySource.serviceRequiresPayment ??
          approvalPolicySource.requiresPayment,
        servicePrice: paymentPolicy.servicePrice,
        price: approvalPolicySource.price ?? data.price ?? 0,
      });
      const finalStatus = requiresPayment ? "awaiting_payment" : "confirmed";
      const finalPaymentStatus = requiresPayment ? "pending" : "not_required";
      let appliedStatus = newStatus;

      console.log("🩺 PAYMENT REQUIREMENT ANALYSIS", {
        appointmentId,
        serviceRequiresPayment:
          approvalPolicySource.serviceRequiresPayment ??
          approvalPolicySource.requiresPayment ??
          null,
        servicePrice: paymentPolicy.servicePrice,
        price: approvalPolicySource.price ?? data.price ?? null,
        requiresPayment,
      });

      if (isApprovalAttempt) {
        appliedStatus = finalStatus;
      } else if (
        currentStatus === "pending" &&
        newStatus === "confirmed" &&
        !requiresPayment
      ) {
        appliedStatus = "confirmed";
      }

      if (
        currentStatus === "awaiting_payment" &&
        newStatus === "confirmed_paid"
      ) {
        appliedStatus = "confirmed_paid";
      }

      if (
        currentStatus === "awaiting_payment" &&
        newStatus === "payment_expired"
      ) {
        appliedStatus = "payment_expired";
      }

      const logCancelValidation = (reason, extra = {}) => {
        console.log("🩺 CANCEL VALIDATION", {
          appointmentId,
          uid,
          currentStatus,
          requestedStatus: newStatus,
          sellerUid: businessOwnerUid,
          businessId,
          buyerUid: appointmentOwnerUid,
          ...extra,
          reason,
        });
      };

      console.log("🩺 APPOINTMENT STATUS REQUEST", {
        appointmentId,
        uid,
        currentStatus,
        requestedStatus: newStatus,
        appliedStatus,
        sellerUid: businessOwnerUid,
        businessId,
        buyerUid: appointmentOwnerUid,
        isOwner,
        isBusinessOwner,
        isAdminUser,
      });

      console.log("🩺 FINAL APPROVAL DECISION", {
        appointmentId,
        finalStatus,
        finalPaymentStatus,
      });

      const isPaidCancellation =
        currentStatus === "confirmed_paid" ||
        currentStatus === "awaiting_service" ||
        currentStatus === "confirmed" ||
        normalizeLower(data.paymentStatus) === "paid";

      if (isOwnerCancellation) {
        logCancelValidation("OWNER_CANCELLATION_ATTEMPT");

        if (!isOwner) {
          console.error("🩺 INVALID CANCEL ATTEMPT", {
            appointmentId,
            currentStatus,
            requestedStatus: newStatus,
            uid,
            userId: data.userId || null,
            buyerUid: data.buyerUid || null,
            sellerUid: businessOwnerUid || null,
            businessId,
            reason: "INVALID_ACTOR",
          });
          throw new HttpsError(
            "permission-denied",
            "Only the appointment owner can cancel this appointment."
          );
        }

        if (!ownerCancelableStatuses.includes(currentStatus)) {
          console.error("🩺 INVALID CANCEL ATTEMPT", {
            appointmentId,
            currentStatus,
            requestedStatus: newStatus,
            appliedStatus,
            uid,
            userId: data.userId || null,
            buyerUid: data.buyerUid || null,
            sellerUid: businessOwnerUid || null,
            businessId,
            reason: "INVALID_STATUS",
          });
          throw new HttpsError(
            "failed-precondition",
            `Invalid cancellation transition: ${currentStatus} → ${newStatus}`
          );
        }

        console.log("🩺 USER CANCEL APPOINTMENT", {
          appointmentId,
          uid,
        });
        if (isPaidCancellation) {
          console.log("🩺 CONFIRMED_PAID CANCELLED_BY_USER (payment preserved)", {
            appointmentId,
            uid,
            paymentStatus: data.paymentStatus || null,
            paymentId: data.paymentId || null,
            orderId: data.orderId || null,
          });
          console.log("🩺 PAID APPOINTMENT CANCELLED_BY_USER", {
            appointmentId,
            uid,
          });
        }
      } else if (!canUseStaffFlow) {
        console.error("🩺 INVALID CANCEL ATTEMPT", {
          appointmentId,
          currentStatus,
          requestedStatus: newStatus,
          uid,
          userId: data.userId || null,
          buyerUid: data.buyerUid || null,
          sellerUid: businessOwnerUid || null,
          businessId,
          reason: "INVALID_ACTOR",
        });
        throw new HttpsError(
          "permission-denied",
          "Only the vet business owner can update this appointment."
        );
      }

      const allowedNext =
        VET_APPOINTMENT_ALLOWED_TRANSITIONS[currentStatus] || [];

      if (!isOwnerCancellation && !allowedNext.includes(appliedStatus)) {
        throw new HttpsError(
          "failed-precondition",
          `Invalid transition: ${currentStatus} → ${appliedStatus}`
        );
      }

      logger.info("🔥 BEFORE UPDATE", {
        appointmentId,
        currentStatus,
        newStatus,
        appliedStatus,
      });

      const refundRequestId =
        isOwnerCancellation && isPaidCancellation
          ? `vet_refund_${appointmentId}_${crypto.randomUUID()}`
          : null;

      const updatePayload = {
        status: appliedStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedBy: uid,
        lastStatusChange: {
          from: currentStatus,
          to: appliedStatus,
          by: uid,
          at: admin.firestore.FieldValue.serverTimestamp(),
        },
      };

      if (isOwnerCancellation && isPaidCancellation) {
        const scheduledAt =
          data.scheduledAt?.toDate?.() ||
          (data.scheduledAt ? new Date(data.scheduledAt) : null);

        const now = new Date();

        const hoursUntilAppointment = scheduledAt
          ? (scheduledAt.getTime() - now.getTime()) / (1000 * 60 * 60)
          : 0;

        const eligibleForAutoRefund = hoursUntilAppointment >= 24;

        updatePayload.refundRequestId = refundRequestId;
        updatePayload.refundRequestedAt =
          admin.firestore.FieldValue.serverTimestamp();

        updatePayload.refundReason =
          "user_cancelled_paid_appointment";

        updatePayload.refundRetryCount = 0;

        console.log("🩺 REFUND POLICY CHECK", {
          appointmentId,
          scheduledAt: scheduledAt || null,
          hoursUntilAppointment,
          eligibleForAutoRefund,
        });

        // =========================
        // ✅ AUTO REFUND
        // =========================

        if (eligibleForAutoRefund) {
          updatePayload.refundRequired = false;
          updatePayload.refundStatus = "refund_processing";

          updatePayload.refundStartedAt =
            admin.firestore.FieldValue.serverTimestamp();

          console.log("🩺 AUTO REFUND ENABLED", {
            appointmentId,
            uid,
            refundStatus: "refund_processing",
          });
        }

        // =========================
        // ⏳ MANUAL REVIEW
        // =========================

        else {
          updatePayload.refundRequired = true;

          updatePayload.refundStatus =
            "pending_manual_review";

          console.log("🩺 MANUAL REFUND REVIEW REQUIRED", {
            appointmentId,
            uid,
            refundStatus: "pending_manual_review",
          });
        }

        console.log("🩺 PAYMENT PRESERVED AFTER CANCELLATION", {
          appointmentId,
          uid,
          paymentStatus: data.paymentStatus || null,
          paymentId: data.paymentId || null,
          orderId: data.orderId || null,
        });
      }

      if (appliedStatus === "awaiting_payment") {
        const paymentDeadlineAt = buildAppointmentPaymentDeadline(
          paymentPolicy.paymentWindowMinutes
        );

        updatePayload.paymentStatus = finalPaymentStatus;
        updatePayload.paymentDeadlineAt = paymentDeadlineAt;

        console.log("🩺 APPOINTMENT AWAITING PAYMENT", {
          appointmentId,
          uid,
          paymentWindowMinutes: paymentPolicy.paymentWindowMinutes,
          paymentDeadlineAt,
        });
        console.log("🩺 PAYMENT DEADLINE SET", {
          appointmentId,
          paymentWindowMinutes: paymentPolicy.paymentWindowMinutes,
          paymentDeadlineAt,
        });
      } else if (appliedStatus === "confirmed") {
        updatePayload.paymentStatus = finalPaymentStatus;
        if (!requiresPayment) {
          updatePayload.paymentDeadlineAt = null;
          console.log("🩺 APPOINTMENT CONFIRMED WITHOUT PAYMENT", {
            appointmentId,
            uid,
          });
        }
      } else if (appliedStatus === "payment_expired") {
        updatePayload.paymentStatus = "expired";
        console.log("🩺 PAYMENT EXPIRED", {
          appointmentId,
          uid,
        });
      }

      tx.update(appointmentRef, updatePayload);

      console.log("🩺 APPROVAL RESULT STATUS", {
        appointmentId,
        currentStatus,
        requestedStatus: newStatus,
        appliedStatus,
        paymentWindowMinutes: paymentPolicy.paymentWindowMinutes,
        paymentDeadlineAt: updatePayload.paymentDeadlineAt || null,
      });

      if (appliedStatus === "cancelled_by_user") {
        console.log("🩺 APPOINTMENT CANCELLED_BY_USER", {
          appointmentId,
        });
      }

      logger.info("🔥 AFTER UPDATE", {
        appointmentId,
        newStatus: appliedStatus,
      });

      return {
        appointmentId,
        oldStatus: currentStatus,
        newStatus: appliedStatus,
        businessId, // 🔥 مهم
      };
    });

    const finalSnap = await appointmentRef.get();
    const finalData = finalSnap.data() || {};
    logger.info("🩺 APPROVAL FINAL STATUS", {
      appointmentId,
      status: finalData.status ?? null,
    });
    logger.info("🩺 APPROVAL PAYMENT STATUS", {
      appointmentId,
      paymentStatus: finalData.paymentStatus ?? null,
      serviceRequiresPayment: finalData.serviceRequiresPayment ?? null,
    });
    logger.info("🩺 APPOINTMENT DOC AFTER APPROVAL", {
      appointmentId,
      status: finalData.status ?? null,
      paymentStatus: finalData.paymentStatus ?? null,
      serviceRequiresPayment: finalData.serviceRequiresPayment ?? null,
      servicePrice: finalData.servicePrice ?? null,
      paymentDeadlineAt: finalData.paymentDeadlineAt ?? null,
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

    // =========================
    // 🐾 AUTO CREATE / UPDATE PATIENT
    // =========================

    try {

      const appointmentSnap = await db
        .collection("vet_appointments")
        .doc(result.appointmentId)
        .get();

      const appointmentData =
        appointmentSnap.data() || {};

      const shouldCreatePatient =
        result.newStatus === "confirmed" ||
        result.newStatus === "confirmed_paid";

      if (shouldCreatePatient) {

        const businessId =
          appointmentData.businessId || null;

        const petId =
          appointmentData.petId || null;
        const dogDataForOwner = petId
          ? (await db.collection("dogs").doc(String(petId)).get()).data() || {}
          : {};
        const ownerId = resolvePetOwnerUidFromData({
          appointmentData,
          dogData: dogDataForOwner,
        });

        logger.info("APPOINTMENT USER UID", {
          appointmentId:
            result.appointmentId,
          userId:
            nonEmptyString(appointmentData.userId),
          requesterUserId:
            nonEmptyString(appointmentData.requesterUserId),
          petOwnerUid:
            nonEmptyString(appointmentData.petOwnerUid),
        });
        logger.info("BUSINESS OWNER UID", {
          appointmentId:
            result.appointmentId,
          businessId:
            nonEmptyString(appointmentData.businessId),
          businessOwnerUid:
            nonEmptyString(appointmentData.businessOwnerUid),
          vetId:
            nonEmptyString(appointmentData.vetId),
        });
        logger.info("DOG OWNER UID", {
          appointmentId:
            result.appointmentId,
          petId,
          dogOwnerUid:
            nonEmptyString(dogDataForOwner.ownerId),
        });

        const petName =
          appointmentData.petName ||
          appointmentData.dogName ||
          "Unnamed pet";

        const breed =
          appointmentData.breed ||
          appointmentData.petBreed ||
          "Breed not set";

        const ownerName =
          appointmentData.userName ||
          appointmentData.ownerName ||
          "Owner";

        if (
          businessId &&
          ownerId &&
          petId
        ) {

          const patientsRef = db
            .collection("businesses")
            .doc(businessId)
            .collection("patients");

          const existingPatient =
            await patientsRef
              .where("petId", "==", petId)
              .limit(1)
              .get();

          // =========================
          // ♻️ UPDATE EXISTING
          // =========================

          if (!existingPatient.empty) {
            const patientDoc = existingPatient.docs[0];
            const existingPatientData = patientDoc.data() || {};
            const ownerProfileSnapshot = await buildOwnerProfileSnapshot({
              db,
              ownerId,
              petId,
              appointmentData,
              patientData: existingPatientData,
            });
            const mergedOwnerProfile = mergeOwnerProfileSnapshots(
              existingPatientData.ownerProfile || {},
              ownerProfileSnapshot
            );

            await patientDoc.ref.set({
              ownerId,
              petOwnerUid: ownerId,

              lastVisitAt:
                admin.firestore.FieldValue
                  .serverTimestamp(),

              updatedAt:
                admin.firestore.FieldValue
                  .serverTimestamp(),

              ...(hasMeaningfulOwnerSnapshot(mergedOwnerProfile)
                ? {
                  ownerProfile: mergedOwnerProfile,
                  ownerProfileUpdatedAt:
                    admin.firestore.FieldValue
                      .serverTimestamp(),
                }
                : {}),
            }, { merge: true });

            if (hasMeaningfulOwnerSnapshot(mergedOwnerProfile)) {
              logger.info(
                "PATIENT OWNER SNAPSHOT MERGED",
                {
                  petId,
                  businessId,
                }
              );
            }

            logger.info(
              "♻️ PATIENT UPDATED",
              {
                petId,
                businessId,
              }
            );
          }

          // =========================
          // 🐾 CREATE NEW PATIENT
          // =========================

          else {
            const ownerProfileSnapshot = await buildOwnerProfileSnapshot({
              db,
              ownerId,
              petId,
              appointmentData,
            });

            await patientsRef.add({

              businessId,

              ownerId,
              petOwnerUid: ownerId,
              petId,

              petName,
              breed,
              ownerName,

              ...(hasMeaningfulOwnerSnapshot(ownerProfileSnapshot)
                ? {
                  ownerProfile: ownerProfileSnapshot,
                  ownerProfileUpdatedAt:
                    admin.firestore.FieldValue
                      .serverTimestamp(),
                }
                : {}),

              notes: "",

              needsFollowUp: false,
              isActive: true,

              createdAt:
                admin.firestore.FieldValue
                  .serverTimestamp(),

              updatedAt:
                admin.firestore.FieldValue
                  .serverTimestamp(),

              lastVisitAt:
                admin.firestore.FieldValue
                  .serverTimestamp(),
            });

            if (hasMeaningfulOwnerSnapshot(ownerProfileSnapshot)) {
              logger.info(
                "PATIENT OWNER SNAPSHOT SAVED",
                {
                  petId,
                  petName,
                  businessId,
                }
              );
            }

            logger.info(
              "🐾 PATIENT AUTO CREATED",
              {
                petId,
                petName,
                businessId,
              }
            );
          }
        }

        else {

          logger.warn(
            "⚠️ PATIENT AUTO CREATE SKIPPED",
            {
              businessId,
              ownerId,
              petId,
            }
          );
        }
      }

    } catch (error) {

      logger.error(
        "❌ PATIENT AUTO CREATE FAILED",
        {
          appointmentId:
            result.appointmentId,

          message:
            error?.message ||
            String(error),
        }
      );
    }

    // =========================
    // 🩺 AUTO CREATE VISIT
    // =========================

    if (result.newStatus === "completed") {

      try {

        const appointmentSnap = await db
          .collection("vet_appointments")
          .doc(result.appointmentId)
          .get();

        const appointmentData =
          appointmentSnap.data() || {};

        const businessId =
          appointmentData.businessId || null;

        const petId =
          appointmentData.petId || null;

        if (businessId && petId) {

          const patientsRef = db
            .collection("businesses")
            .doc(businessId)
            .collection("patients");

          const patientQuery =
            await patientsRef
              .where("petId", "==", petId)
              .limit(1)
              .get();

          if (!patientQuery.empty) {

            const patientDoc =
              patientQuery.docs[0];

            const patientRef =
              patientDoc.ref;

            // =========================
            // 🩺 CREATE VISIT
            // =========================

            await patientRef
              .collection("visits")
              .add({

                appointmentId:
                  result.appointmentId,

                title:
                  appointmentData.serviceName ||
                  "Veterinary Visit",

                summary:
                  "Appointment completed successfully.",

                diagnosis: "",

                treatment: "",

                followUpRequired: false,

                visitDate:
                  admin.firestore.FieldValue
                    .serverTimestamp(),

                createdAt:
                  admin.firestore.FieldValue
                    .serverTimestamp(),
              });

            // =========================
            // ♻️ UPDATE PATIENT
            // =========================
            const dogDataForOwner = petId
              ? (await db.collection("dogs").doc(String(petId)).get()).data() || {}
              : {};
            const ownerId = resolvePetOwnerUidFromData({
              appointmentData,
              patientData: patientDoc.data() || {},
              dogData: dogDataForOwner,
            });

            logger.info("APPOINTMENT USER UID", {
              appointmentId:
                result.appointmentId,
              userId:
                nonEmptyString(appointmentData.userId),
              requesterUserId:
                nonEmptyString(appointmentData.requesterUserId),
              petOwnerUid:
                nonEmptyString(appointmentData.petOwnerUid),
            });
            logger.info("BUSINESS OWNER UID", {
              appointmentId:
                result.appointmentId,
              businessId:
                nonEmptyString(appointmentData.businessId),
              businessOwnerUid:
                nonEmptyString(appointmentData.businessOwnerUid),
              vetId:
                nonEmptyString(appointmentData.vetId),
            });
            logger.info("DOG OWNER UID", {
              appointmentId:
                result.appointmentId,
              petId,
              dogOwnerUid:
                nonEmptyString(dogDataForOwner.ownerId),
            });

            const ownerProfileSnapshot = await buildOwnerProfileSnapshot({
              db,
              ownerId,
              petId,
              appointmentData,
              patientData: patientDoc.data() || {},
            });
            const mergedOwnerProfile = mergeOwnerProfileSnapshots(
              (patientDoc.data() || {}).ownerProfile || {},
              ownerProfileSnapshot
            );

            await patientRef.set({
              ownerId,
              petOwnerUid: ownerId,

              lastVisitAt:
                admin.firestore.FieldValue
                  .serverTimestamp(),

              updatedAt:
                admin.firestore.FieldValue
                  .serverTimestamp(),

              ...(hasMeaningfulOwnerSnapshot(mergedOwnerProfile)
                ? {
                  ownerProfile: mergedOwnerProfile,
                  ownerProfileUpdatedAt:
                    admin.firestore.FieldValue
                      .serverTimestamp(),
                }
                : {}),
            }, { merge: true });

            if (hasMeaningfulOwnerSnapshot(mergedOwnerProfile)) {
              logger.info(
                "PATIENT OWNER SNAPSHOT MERGED",
                {
                  patientId:
                    patientDoc.id,

                  petId,
                }
              );
            }

            logger.info(
              "🩺 VISIT AUTO CREATED",
              {
                patientId:
                  patientDoc.id,

                petId,
              }
            );
          }
        }

      } catch (error) {

        logger.error(
          "❌ AUTO VISIT CREATE FAILED",
          {
            appointmentId:
              result.appointmentId,

            message:
              error?.message ||
              String(error),
          }
        );
      }
    }

    try {
      const snap = await db
        .collection("vet_appointments")
        .doc(result.appointmentId)
        .get();

      const data = snap.data() || {};
      const userId = data.userId;
      const businessId = data.businessId || result.businessId || null;
      const businessSnap = businessId
        ? await db.collection("businesses").doc(businessId).get()
        : null;
      const businessData = businessSnap?.data() || {};
      const businessOwnerUid = businessData.ownerUid || businessData.uid || null;

      if (result.newStatus === "cancelled_by_user") {
        logger.info("🩺 APPOINTMENT DOC AFTER CANCELLATION", {
          appointmentId: result.appointmentId,
          status: data.status ?? null,
          paymentStatus: data.paymentStatus ?? null,
          refundStatus: data.refundStatus ?? null,
          refundRequired: data.refundRequired ?? null,
          refundReason: data.refundReason ?? null,
          paymentId: data.paymentId ?? null,
          iyzicoPaymentId: data.iyzicoPaymentId ?? null,
          orderId: data.orderId ?? null,
          paymentTransactionId: data.paymentTransactionId ?? null,
          iyzicoPaymentTransactionId:
            data.iyzicoPaymentTransactionId ?? data.paymentTransactionId ?? null,
          conversationId: data.conversationId ?? null,
          checkoutToken: data.checkoutToken ?? null,
          refundRequestId: data.refundRequestId ?? null,
          refundedAt: data.refundedAt ?? null,
          refundError: data.refundError ?? null,
        });
      }

      // =========================
      // 🔥 BUILD TITLE & BODY (MOVE OUTSIDE PUSH)
      // =========================

      let title = "Appointment Update";
      let body = "Your appointment status changed";
      const wasPaidCancellationForNotify =
        result.newStatus === "cancelled_by_user" &&
        (normalizeLower(data.paymentStatus) === "paid" ||
          ["confirmed_paid", "awaiting_service", "confirmed"].includes(
            normalizeLower(result.oldStatus)
          ));

      if (result.newStatus === "awaiting_payment") {
        title = "Payment Required ⏳";
        body = `${data.serviceTitle || "Service"} is waiting for payment`;
      } else if (result.newStatus === "confirmed") {
        title = "Appointment Confirmed ✅";
        body = `${data.serviceTitle || "Service"} is confirmed`;
      } else if (result.newStatus === "rejected") {
        title = "Appointment Rejected ❌";
        body = `Your appointment was rejected`;
      } else if (result.newStatus === "cancelled_by_user") {
        title = "Appointment Cancelled";
        body = `${data.serviceTitle || "Service"} was cancelled by the user`;
      }

      const userBody = wasPaidCancellationForNotify
        ? `${data.serviceTitle || "Service"} was cancelled by the user. Refund is being processed automatically.`
        : body;
      const vetBody = wasPaidCancellationForNotify
        ? `${data.serviceTitle || "Service"} was cancelled by the user. Refund is being processed automatically.`
        : `${data.serviceTitle || "Service"} was cancelled by the user`;

      if (userId) {
        // =========================
        // 🔥 SAVE FIRESTORE NOTIFICATION (MISSING PART)
        // =========================
        await db.collection("notifications").add({
          type:
            result.newStatus === "cancelled_by_user"
              ? "appointment_cancelled_confirmation"
              : "vet_appointment_response",

          recipientUserId: userId,
          senderUserId: result.businessId,

          appointmentId: result.appointmentId,
          status: result.newStatus,

          title,
          body: userBody,

          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        const userSnap = await db.collection("users").doc(userId).get();
        const userData = userSnap.data() || {};
        const fcmToken = userData.fcmToken;

        if (fcmToken) {


          logger.info("🔔 Playdate/PetTaxi reference sound payload attached", {
            type: "vet_appointment_response",
            recipientUserId: userId,
            appointmentId: result.appointmentId,
          });
          await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            data: {
              type: "vet_appointment_response",
              appointmentId: result.appointmentId,
              status: result.newStatus, // 🔥 مهم
              refundRequired: wasPaidCancellationForNotify ? "true" : "false",
              refundStatus: wasPaidCancellationForNotify
                ? "refund_pending"
                : "",
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
                    title,
                    body,
                  },
                  sound: "default",
                  badge: 1,
                  "interruption-level": "time-sensitive",
                },
              },
            },
          });
          logger.info("🔔 Push send success", {
            type: "vet_appointment_response",
            recipientUserId: userId,
            soundEnabled: true,
          });
        } else {
          logger.warn("⚠️ Push token missing", {
            type: "vet_appointment_response",
            recipientUserId: userId,
          });
        }
      }

      if (result.newStatus === "cancelled_by_user" && businessOwnerUid) {
        await db.collection("notifications").add({
          type: "vet_appointment_cancelled_by_user",
          recipientUserId: businessOwnerUid,
          senderUserId: userId || uid,
          appointmentId: result.appointmentId,
          status: result.newStatus,
          title: "Appointment Cancelled",
          body: vetBody,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const vetUserSnap = await db.collection("users").doc(businessOwnerUid).get();
        const vetToken = vetUserSnap.data()?.fcmToken;

        if (vetToken) {
          await safeSendPush({
            token: vetToken,
            userId: businessOwnerUid,
            payload: {
              notification: {
                title: "Appointment Cancelled",
                body: `${data.serviceTitle || "Service"} was cancelled by the user`,
              },
              data: {
                type: "vet_appointment_cancelled_by_user",
                appointmentId: result.appointmentId,
                status: result.newStatus,
                refundRequired: wasPaidCancellationForNotify ? "true" : "false",
                refundStatus: wasPaidCancellationForNotify
                  ? "refund_pending"
                  : "",
              },
              android: { priority: "high" },
            },
          });
        }
      }
    } catch (e) {
      logger.error("❌ notify user failed", e);
    }

    if (
      result.newStatus === "cancelled_by_user" &&
      finalData.refundStatus === "refund_processing" &&
      (normalizeLower(finalData.paymentStatus) === "paid" ||
        ["confirmed_paid", "awaiting_service", "confirmed"].includes(
          normalizeLower(result.oldStatus)
        ))
    ) {
      try {
        logger.info("🩺 VET REFUND FLOW DETECTED", {
          appointmentId: result.appointmentId,
          oldStatus: result.oldStatus || null,
          newStatus: result.newStatus || null,
          paymentStatus: finalData.paymentStatus || null,
          refundStatus: finalData.refundStatus || null,
          paymentId: finalData.paymentId || null,
          iyzicoPaymentId: finalData.iyzicoPaymentId || null,
          paymentTransactionId: finalData.paymentTransactionId || null,
          iyzicoPaymentTransactionId:
            finalData.iyzicoPaymentTransactionId ||
            finalData.paymentTransactionId ||
            null,
          conversationId: finalData.conversationId || null,
          checkoutToken: finalData.checkoutToken || null,
        });
        logger.info("🩺 BYPASSING PETSHOP RETURN FLOW", {
          appointmentId: result.appointmentId,
          reason: "vet_direct_cancel_refund",
        });
        logger.info("🩺 DIRECT VET REFUND START", {
          appointmentId: result.appointmentId,
          status: finalData.status || null,
          paymentStatus: finalData.paymentStatus || null,
          refundStatus: finalData.refundStatus || null,
        });
        const refundResult = await processVetAppointmentRefund({
          db,
          appointmentId: result.appointmentId,
          appointmentData: finalData,
          beforeData: null,
          eventId: finalData.refundRequestId || null,
          actorUid: uid,
        });

        if (refundResult?.success) {
          logger.info("🩺 DIRECT VET REFUND SUCCESS", {
            appointmentId: result.appointmentId,
            source: "callable",
          });
        } else if (!refundResult?.skipped) {
          throw new HttpsError(
            "internal",
            refundResult?.error || "Refund processing failed"
          );
        }
      } catch (error) {
        logger.error("🩺 DIRECT VET REFUND FAILURE", {
          appointmentId: result.appointmentId,
          message: error?.message || String(error),
          stack: error?.stack || null,
        });
        throw error instanceof HttpsError
          ? error
          : new HttpsError("internal", error?.message || "Refund failed");
      }
    }

    return {
      ok: true,
      ...result,
    };
  }
);

exports.updateGroomyAppointmentStatus = onCall(
  {
    region: "europe-west3",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required.");
    }

    const uid = request.auth.uid;
    const { appointmentId } = request.data || {};
    const newStatus = String(
      request.data?.newStatus || request.data?.status || "",
    ).trim();

    if (!appointmentId || typeof appointmentId !== "string") {
      throw new HttpsError("invalid-argument", "appointmentId is required.");
    }

    if (!newStatus) {
      throw new HttpsError("invalid-argument", "newStatus is required.");
    }

    assertGroomyAppointmentStatus(newStatus);

    const appointmentRef = db.collection("groomy_appointments").doc(appointmentId);

    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(appointmentRef);

      if (!snap.exists) {
        throw new HttpsError("not-found", "Appointment not found.");
      }

      const data = snap.data() || {};
      const currentStatus = data.status || "pending";
      const businessId = data.businessId;
      const appointmentOwnerUid = data.userId || data.buyerUid || null;

      assertGroomyAppointmentStatus(currentStatus);

      if (!businessId) {
        throw new HttpsError(
          "failed-precondition",
          "Appointment has no businessId."
        );
      }

      if (currentStatus === newStatus) {
        return {
          appointmentId,
          oldStatus: currentStatus,
          newStatus,
          businessId,
          userId: appointmentOwnerUid,
          skipped: true,
        };
      }

      const businessRef = db.collection("businesses").doc(businessId);
      const businessSnap = await tx.get(businessRef);

      if (!businessSnap.exists) {
        throw new HttpsError("not-found", "Business not found.");
      }

      const adminSnap = await tx.get(db.collection("users").doc(uid));
      const isAdminUser = adminSnap.exists && adminSnap.data()?.role === "admin";
      const businessData = businessSnap.data() || {};
      const businessOwnerUid = businessData.ownerUid || businessData.uid || null;
      const isOwner = appointmentOwnerUid === uid;
      const isBusinessOwner = businessOwnerUid === uid;
      const canUseStaffFlow = isBusinessOwner || isAdminUser;
      const isOwnerCancellation = newStatus === "cancelled_by_user";
      const ownerCancelableStatuses = [
        "pending",
        "awaiting_payment",
        "confirmed",
        "confirmed_paid",
      ];
      const isApprovalAttempt =
        currentStatus === "pending" &&
        (newStatus === "confirmed" || newStatus === "awaiting_payment");
      let approvalPolicySource = data;

      if (
        isApprovalAttempt &&
        data.serviceId &&
        (!data.serviceRequiresPayment ||
          data.serviceRequiresPayment === null ||
          data.serviceRequiresPayment === undefined)
      ) {
        const serviceSnap = await tx.get(
          businessRef.collection("services").doc(data.serviceId)
        );

        if (serviceSnap.exists) {
          const serviceData = serviceSnap.data() || {};
          approvalPolicySource = {
            ...data,
            ...serviceData,
            servicePrice: serviceData.price ?? data.servicePrice ?? data.price ?? 0,
            price: serviceData.price ?? data.servicePrice ?? data.price ?? 0,
            paymentWindowMinutes:
              serviceData.paymentWindowMinutes ??
              data.paymentWindowMinutes ??
              data.paymentWindow ??
              0,
            requiresPayment: serviceData.requiresPayment,
            requiresDeposit: serviceData.requiresDeposit,
          };
        }
      }

      const paymentPolicy = resolveAppointmentPaymentPolicy(approvalPolicySource);
      const requiresPayment = requiresAppointmentPayment({
        serviceRequiresPayment:
          approvalPolicySource.serviceRequiresPayment ??
          approvalPolicySource.requiresPayment,
        servicePrice: paymentPolicy.servicePrice,
        price: approvalPolicySource.price ?? data.price ?? 0,
      });
      const finalStatus = requiresPayment ? "awaiting_payment" : "confirmed";
      const finalPaymentStatus = requiresPayment ? "pending" : "not_required";
      let appliedStatus = newStatus;

      if (isApprovalAttempt) {
        appliedStatus = finalStatus;
      } else if (
        currentStatus === "awaiting_payment" &&
        newStatus === "confirmed_paid"
      ) {
        appliedStatus = "confirmed_paid";
      } else if (
        currentStatus === "awaiting_payment" &&
        newStatus === "payment_expired"
      ) {
        appliedStatus = "payment_expired";
      }

      if (isOwnerCancellation) {
        if (!isOwner) {
          throw new HttpsError(
            "permission-denied",
            "Only the appointment owner can cancel this appointment."
          );
        }

        if (!ownerCancelableStatuses.includes(currentStatus)) {
          throw new HttpsError(
            "failed-precondition",
            `Invalid cancellation transition: ${currentStatus} → ${newStatus}`
          );
        }
      } else if (!canUseStaffFlow) {
        throw new HttpsError(
          "permission-denied",
          "Only the grooming business owner can update this appointment."
        );
      }

      const allowedNext =
        GROOMY_APPOINTMENT_ALLOWED_TRANSITIONS[currentStatus] || [];

      if (!isOwnerCancellation && !allowedNext.includes(appliedStatus)) {
        throw new HttpsError(
          "failed-precondition",
          `Invalid transition: ${currentStatus} → ${appliedStatus}`
        );
      }

      const updatePayload = {
        status: appliedStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedBy: uid,
        lastStatusChange: {
          from: currentStatus,
          to: appliedStatus,
          by: uid,
          at: admin.firestore.FieldValue.serverTimestamp(),
        },
      };

      if (appliedStatus === "awaiting_payment") {
        updatePayload.paymentStatus = finalPaymentStatus;
        logger.info("🟣 GROOMY PAYMENT POLICY", {
          paymentWindowMinutes: paymentPolicy.paymentWindowMinutes,
          servicePrice: paymentPolicy.servicePrice,
          requiresPayment,
        });
        updatePayload.paymentDeadlineAt = buildAppointmentPaymentDeadline(
          paymentPolicy.paymentWindowMinutes
        );
        updatePayload.serviceRequiresPayment = true;
        updatePayload.servicePrice = paymentPolicy.servicePrice;
        updatePayload.price = paymentPolicy.servicePrice;
        updatePayload.paymentWindowMinutes = paymentPolicy.paymentWindowMinutes;
      } else if (appliedStatus === "confirmed") {
        updatePayload.paymentStatus = finalPaymentStatus;
        if (!requiresPayment) {
          updatePayload.paymentDeadlineAt = null;
        }
      } else if (appliedStatus === "payment_expired") {
        updatePayload.paymentStatus = "expired";
      }

      tx.update(appointmentRef, updatePayload);

      return {
        appointmentId,
        oldStatus: currentStatus,
        newStatus: appliedStatus,
        businessId,
        userId: appointmentOwnerUid,
        businessOwnerUid,
      };
    });

    try {
      const countSnap = await db
        .collection("groomy_appointments")
        .where("businessId", "==", result.businessId)
        .get();

      await db.collection("businesses").doc(result.businessId).set(
        {
          stats: {
            groomingAppointmentCount: countSnap.size,
          },
        },
        { merge: true }
      );
    } catch (err) {
      logger.error("❌ Groomy stats update failed", err);
    }

    try {
      const finalSnap = await appointmentRef.get();
      const data = finalSnap.data() || {};
      const userId = data.userId || result.userId;
      const businessId = data.businessId || result.businessId;
      const businessSnap = businessId
        ? await db.collection("businesses").doc(businessId).get()
        : null;
      const businessData = businessSnap?.data() || {};
      const businessOwnerUid =
        businessData.ownerUid || businessData.uid || result.businessOwnerUid;

      let title = "Grooming Appointment Update";
      let body = "Your grooming appointment status changed";

      if (result.newStatus === "awaiting_payment") {
        title = "Payment Required";
        body = `${data.serviceTitle || "Grooming service"} is waiting for payment`;
      } else if (result.newStatus === "confirmed") {
        title = "Grooming Appointment Confirmed";
        body = `${data.serviceTitle || "Grooming service"} is confirmed`;
      } else if (result.newStatus === "rejected") {
        title = "Grooming Appointment Rejected";
        body = "Your grooming appointment was rejected";
      } else if (result.newStatus === "cancelled_by_groomy") {
        title = "Grooming Appointment Cancelled";
        body = `${data.serviceTitle || "Grooming service"} was cancelled`;
      } else if (result.newStatus === "completed") {
        title = "Grooming Appointment Completed";
        body = `${data.serviceTitle || "Grooming service"} is completed`;
      } else if (result.newStatus === "cancelled_by_user") {
        title = "Grooming Appointment Cancelled";
        body = `${data.serviceTitle || "Grooming service"} was cancelled by the user`;
      }

      if (userId) {
        await db.collection("notifications").add({
          type: "groomy_appointment_response",
          recipientUserId: userId,
          senderUserId: businessOwnerUid || uid,
          businessId,
          appointmentId: result.appointmentId,
          appointmentCollection: "groomy_appointments",
          status: result.newStatus,
          title,
          body,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const userSnap = await db.collection("users").doc(userId).get();
        const fcmToken = userSnap.data()?.fcmToken;

        if (fcmToken) {
          logger.info("🔔 Playdate/PetTaxi reference sound payload attached", {
            type: "groomy_appointment_response",
            recipientUserId: userId,
            appointmentId: result.appointmentId,
          });
          await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            data: {
              type: "groomy_appointment_response",
              appointmentId: result.appointmentId,
              appointmentCollection: "groomy_appointments",
              status: result.newStatus,
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
                    title,
                    body,
                  },
                  sound: "default",
                  badge: 1,
                  "interruption-level": "time-sensitive",
                },
              },
            },
          });
          logger.info("🔔 Push send success", {
            type: "groomy_appointment_response",
            recipientUserId: userId,
            soundEnabled: true,
          });
        } else {
          logger.warn("⚠️ Push token missing", {
            type: "groomy_appointment_response",
            recipientUserId: userId,
          });
        }
      }

      if (result.newStatus === "cancelled_by_user" && businessOwnerUid) {
        await db.collection("notifications").add({
          type: "groomy_appointment_cancelled_by_user",
          recipientUserId: businessOwnerUid,
          senderUserId: userId || uid,
          businessId,
          appointmentId: result.appointmentId,
          appointmentCollection: "groomy_appointments",
          status: result.newStatus,
          title: "Grooming Appointment Cancelled",
          body: `${data.serviceTitle || "Grooming service"} was cancelled by the user`,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      logger.error("❌ Groomy notify failed", e);
    }

    return {
      ok: true,
      ...result,
    };
  }
);

exports.reviewVetAppointmentRefund = onCall(
  {
    region: "europe-west3",
    secrets: [IYZICO_API_KEY, IYZICO_SECRET_KEY],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required.");
    }

    const adminUid = request.auth.uid;
    const allowed = await isAdminUser(db, adminUid);
    if (!allowed) {
      throw new HttpsError("permission-denied", "Admin only");
    }

    const appointmentId = String(request.data?.appointmentId || "").trim();
    const action = String(request.data?.action || "").trim().toLowerCase();
    const note = String(request.data?.note || "").trim();

    if (!appointmentId) {
      throw new HttpsError("invalid-argument", "appointmentId is required.");
    }

    if (!["approve", "reject"].includes(action)) {
      throw new HttpsError("invalid-argument", "Invalid refund review action.");
    }

    const appointmentRef = db.collection("vet_appointments").doc(appointmentId);
    const snap = await appointmentRef.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Appointment not found.");
    }

    const data = snap.data() || {};
    const paymentStatus = normalizeLower(data.paymentStatus);
    const refundStatus = normalizeLower(data.refundStatus);

    if (paymentStatus !== "paid") {
      throw new HttpsError(
        "failed-precondition",
        "Only paid appointments can be refunded."
      );
    }

    if (refundStatus !== "pending_manual_review") {
      throw new HttpsError(
        "failed-precondition",
        "Appointment is not pending manual refund review."
      );
    }

    logger.info("🩺 ADMIN REFUND REVIEW OPEN", {
      appointmentId,
      action,
      adminUid,
    });

    if (action === "reject") {
      const reviewedAt = admin.firestore.FieldValue.serverTimestamp();

      await appointmentRef.set(
        {
          refundStatus: "rejected",
          refundRequired: false,
          refundReviewedAt: reviewedAt,
          refundReviewedBy: adminUid,
          refundReviewNote: note || null,
          updatedAt: reviewedAt,
        },
        { merge: true }
      );

      await db.collection("admin_logs").add({
        entityType: "vet_appointment",
        entityId: appointmentId,
        action: "vet_refund_rejected",
        performedBy: adminUid,
        reason: note || null,
        metadata: {
          appointmentId,
          paymentStatus,
          refundStatus,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info("🩺 ADMIN REFUND REJECTED", {
        appointmentId,
        adminUid,
      });

      return {
        success: true,
        appointmentId,
        action,
        refundStatus: "rejected",
      };
    }

    logger.info("🩺 ADMIN REFUND APPROVED", {
      appointmentId,
      adminUid,
    });

    const refundResult = await processVetAppointmentRefund({
      db,
      appointmentId,
      appointmentData: {
        ...data,
        status: "cancelled_by_user",
        refundStatus: "pending_manual_review",
      },
      beforeData: null,
      eventId:
        data.refundRequestId ||
        `vet_manual_refund_${appointmentId}_${crypto.randomUUID()}`,
      actorUid: adminUid,
      preserveManualReviewOnFailure: true,
    });

    if (!refundResult?.success) {
      await db.collection("admin_logs").add({
        entityType: "vet_appointment",
        entityId: appointmentId,
        action: "vet_refund_approve_failed",
        performedBy: adminUid,
        reason: note || null,
        metadata: {
          appointmentId,
          error: refundResult?.error || refundResult?.reason || null,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      throw new HttpsError(
        "internal",
        refundResult?.error || refundResult?.reason || "Refund failed"
      );
    }

    const reviewedAt = admin.firestore.FieldValue.serverTimestamp();
    await appointmentRef.set(
      {
        status: "cancelled_by_user",
        refundStatus: "refunded",
        refundRequired: false,
        refundedAt: data.refundedAt || reviewedAt,
        refundReviewedAt: reviewedAt,
        refundReviewedBy: adminUid,
        refundReviewNote: note || null,
        refundError: null,
        updatedAt: reviewedAt,
      },
      { merge: true }
    );

    await db.collection("admin_logs").add({
      entityType: "vet_appointment",
      entityId: appointmentId,
      action: "vet_refund_approved",
      performedBy: adminUid,
      reason: note || null,
      metadata: {
        appointmentId,
        paymentStatus,
        refundStatus,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("🩺 REFUND SUCCESS", {
      appointmentId,
      adminUid,
      source: "manual_review",
    });

    return {
      success: true,
      appointmentId,
      action,
      refundStatus: "refunded",
    };
  }
);

exports.triggerAppointmentRefund = onDocumentUpdated(
  {
    region: "europe-west3",
    document: "vet_appointments/{appointmentId}",
    secrets: [IYZICO_API_KEY, IYZICO_SECRET_KEY],
  },
  async (event) => {
    const db = admin.firestore();
    const appointmentId = event.params.appointmentId;
    const beforeData = event.data?.before?.data() || {};
    const afterData = event.data?.after?.data() || {};
    const eventId = event.id || `${appointmentId}_${Date.now()}`;

    const beforeStatus = normalizeLower(beforeData.status);
    const afterStatus = normalizeLower(afterData.status);
    const beforePaymentStatus = normalizeLower(beforeData.paymentStatus);
    const afterPaymentStatus = normalizeLower(afterData.paymentStatus);

    if (afterData.refundRequestId) {
      logger.info("🩺 VET REFUND SKIPPED ALREADY HANDLED BY CALLABLE", {
        appointmentId,
        refundRequestId: afterData.refundRequestId,
        refundStatus: afterData.refundStatus || null,
      });
      return null;
    }

    logger.info("🩺 VET REFUND START", {
      appointmentId,
      beforeStatus,
      afterStatus,
      beforePaymentStatus,
      afterPaymentStatus,
      refundStatus: afterData.refundStatus || null,
      eventId,
    });

    const becameCancelledByUser =
      beforeStatus !== "cancelled_by_user" && afterStatus === "cancelled_by_user";

    if (!becameCancelledByUser) {
      return null;
    }

    if (afterPaymentStatus !== "paid") {
      logger.info("🩺 VET REFUND SKIPPED NOT ELIGIBLE", {
        appointmentId,
        reason: "payment_not_paid",
        paymentStatus: afterPaymentStatus,
      });
      return null;
    }

    try {
      const refundResult = await processVetAppointmentRefund({
        db,
        appointmentId,
        appointmentData: afterData,
        beforeData,
        eventId,
        actorUid: afterData.statusUpdatedBy || null,
      });

      if (refundResult?.success) {
        logger.info("🩺 VET REFUND SUCCESS", {
          appointmentId,
        });
      } else {
        logger.warn("🩺 VET REFUND FAILED", {
          appointmentId,
          result: refundResult || null,
        });
      }
    } catch (error) {
      logger.error("🩺 VET REFUND FAILED", {
        appointmentId,
        message: error?.message || String(error),
        stack: error?.stack || null,
      });
    }

    return null;
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
        preVisitForm,
        preVisitAnswers,
        preVisitSnapshot,
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

      let serviceSnapshot = null;
      if (serviceId) {
        try {
          serviceSnapshot = await db
            .collection("businesses")
            .doc(businessId)
            .collection("services")
            .doc(serviceId)
            .get();
        } catch (error) {
          logger.warn("⚠️ Service snapshot lookup failed", {
            businessId,
            serviceId,
            message: error?.message || String(error),
          });
        }
      }

      const serviceData = serviceSnapshot?.data() || {};
      const paymentPolicy = resolveAppointmentPaymentPolicy({
        ...serviceData,
        servicePrice: serviceData.price ?? price ?? 0,
        price: serviceData.price ?? price ?? 0,
        paymentWindowMinutes: serviceData.paymentWindowMinutes,
        requiresPayment: serviceData.requiresPayment,
        requiresDeposit: serviceData.requiresDeposit,
      });

      const scheduledDate = new Date(scheduledAt);

      if (isNaN(scheduledDate.getTime())) {
        throw new HttpsError("invalid-argument", "Invalid date.");
      }

      const scheduledTs =
        admin.firestore.Timestamp.fromDate(scheduledDate);

      let safePreVisitAnswers = null;
      let safePreVisitSnapshot = null;

      if (preVisitAnswers && typeof preVisitAnswers === "object" && !Array.isArray(preVisitAnswers)) {
        safePreVisitAnswers = {};
        Object.entries(preVisitAnswers).forEach(([key, value]) => {
          const safeKey = String(key || "").trim();
          if (!safeKey) return;
          safePreVisitAnswers[safeKey] = Array.isArray(value)
            ? value.map((item) => String(item))
            : value;
        });
      }

      if (preVisitSnapshot && typeof preVisitSnapshot === "object") {
        const rawQuestions = Array.isArray(preVisitSnapshot.questions)
          ? preVisitSnapshot.questions
          : [];

        safePreVisitSnapshot = {
          serviceId: preVisitSnapshot.serviceId
            ? String(preVisitSnapshot.serviceId)
            : (serviceId ? String(serviceId) : null),
          questions: rawQuestions
            .filter((item) => item && typeof item === "object")
            .map((item) => ({
              id: item.id ? String(item.id) : "",
              question: item.question ? String(item.question) : "",
              type: item.type ? String(item.type) : "text",
              required: item.required === true,
              options: Array.isArray(item.options)
                ? item.options.map((option) => String(option))
                : [],
            }))
            .filter((item) => item.id && item.question),
        };
      }

      // Backward compatibility for the previous preVisitForm payload.
      if (!safePreVisitAnswers && preVisitForm && typeof preVisitForm === "object") {
        const rawAnswers = Array.isArray(preVisitForm.answers)
          ? preVisitForm.answers
          : [];

        safePreVisitAnswers = {};
        const snapshotQuestions = [];

        rawAnswers
          .filter((item) => item && typeof item === "object")
          .forEach((item) => {
            const questionId = item.questionId ? String(item.questionId) : "";
            if (!questionId) return;

            const answer = Array.isArray(item.answer)
              ? item.answer.map((value) => String(value))
              : (item.answer === undefined ? null : item.answer);

            safePreVisitAnswers[questionId] = answer;
            snapshotQuestions.push({
              id: questionId,
              question: item.question ? String(item.question) : "",
              type: item.type ? String(item.type) : "text",
              required: false,
              options: [],
            });
          });

        safePreVisitSnapshot = {
          serviceId: preVisitForm.serviceId
            ? String(preVisitForm.serviceId)
            : (serviceId ? String(serviceId) : null),
          questions: snapshotQuestions.filter((item) => item.id && item.question),
        };
      }

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
      const dogOwnerSnap = await db.collection("dogs").doc(String(finalPetId)).get();
      const dogOwnerData = dogOwnerSnap.data() || {};
      const petOwnerUid =
        nonEmptyString(request.data.petOwnerUid) ||
        nonEmptyString(dogOwnerData.ownerId) ||
        uid;
      let businessOwnerUid = null;
      try {
        const businessOwnerSnap = await db.collection("businesses").doc(String(businessId)).get();
        const businessOwnerData = businessOwnerSnap.data() || {};
        businessOwnerUid =
          nonEmptyString(businessOwnerData.ownerUid) ||
          nonEmptyString(businessOwnerData.uid);
      } catch (error) {
        logger.warn("BUSINESS OWNER UID LOOKUP FAILED", {
          businessId,
          message: error?.message || String(error),
        });
      }

      logger.info("APPOINTMENT USER UID", {
        requesterUserId: uid,
        petOwnerUid,
      });
      logger.info("BUSINESS OWNER UID", {
        businessId,
        businessOwnerUid,
      });
      logger.info("DOG OWNER UID", {
        petId: finalPetId,
        dogOwnerUid: nonEmptyString(dogOwnerData.ownerId),
      });

      const ownerProfileSnapshot = await buildOwnerProfileSnapshot({
        db,
        ownerId: petOwnerUid,
        petId: finalPetId,
        appointmentData: {
          ...(request.data || {}),
          userId: uid,
          requesterUserId: uid,
          ownerId: petOwnerUid,
          petOwnerUid,
          businessOwnerUid,
        },
      });

      const docRef = await col.add({
        userId: uid,
        requesterUserId: uid,
        ownerId: petOwnerUid,
        petOwnerUid,
        businessOwnerUid,
        ...(hasMeaningfulOwnerSnapshot(ownerProfileSnapshot)
          ? { ownerProfile: ownerProfileSnapshot }
          : {}),

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
        price: paymentPolicy.servicePrice ?? price ?? 0,
        durationMin: durationMin || 0,
        serviceRequiresPayment: paymentPolicy.requiresPayment,
        servicePrice: paymentPolicy.servicePrice ?? price ?? 0,
        paymentWindowMinutes: paymentPolicy.paymentWindowMinutes,
        paymentStatus: paymentPolicy.requiresPayment ? "pending" : "not_required",
        paymentDeadlineAt: null,
        paidAt: null,
        paymentId: null,
        orderId: null,
        paymentTransactionId: null,
        paymentTransactionIds: [],

        // ⏱ TIME
        scheduledAt: scheduledTs,

        // 📝 META
        note: note || "",
        preVisitAnswers: safePreVisitAnswers,
        preVisitSnapshot: safePreVisitSnapshot,
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
          logger.info("🔔 Playdate/PetTaxi reference sound payload attached", {
            type: "vet_appointment_request",
            recipientUserId: businessId,
            appointmentId: docRef.id,
          });
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
                    title,
                    body,
                  },
                  sound: "default",
                  badge: 1,
                  "interruption-level": "time-sensitive",
                },
              },
            },
          });

          logger.info("🔔 Push sent to vet:", {
            businessId,
            soundEnabled: true,
          });
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

exports.createGroomyAppointment = onCall(
  { region: "europe-west3" },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required.");
      }

      const uid = request.auth.uid;

      const {
        petId,
        petName,
        petType,
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

      const finalPetId = petId || dogId;
      const finalPetName = petName || dogName;
      const finalPetType = petType || "dog";

      if (!finalPetId || !businessId || !scheduledAt) {
        throw new HttpsError("invalid-argument", "Missing required fields.");
      }

      const businessSnap = await db.collection("businesses").doc(businessId).get();
      if (!businessSnap.exists) {
        throw new HttpsError("not-found", "Business not found.");
      }

      const businessData = businessSnap.data() || {};
      const businessSectors = Array.isArray(businessData.sectors)
        ? businessData.sectors.map((sector) => normalizeLower(sector))
        : [];
      const businessSectorData = businessData.sectorData || {};
      const isGroomingBusiness =
        businessSectors.includes("grooming") ||
        businessSectors.includes("groomer") ||
        Boolean(businessSectorData.grooming || businessSectorData.groomer);

      if (!isGroomingBusiness) {
        throw new HttpsError(
          "failed-precondition",
          "Business is not a grooming business."
        );
      }

      let serviceSnapshot = null;
      if (serviceId) {
        try {
          serviceSnapshot = await db
            .collection("businesses")
            .doc(businessId)
            .collection("services")
            .doc(serviceId)
            .get();
        } catch (error) {
          logger.warn("⚠️ Groomy service snapshot lookup failed", {
            businessId,
            serviceId,
            message: error?.message || String(error),
          });
        }
      }

      const serviceData = serviceSnapshot?.data() || {};
      const paymentPolicy = resolveAppointmentPaymentPolicy({
        ...serviceData,
        servicePrice: serviceData.price ?? price ?? 0,
        price: serviceData.price ?? price ?? 0,
        paymentWindowMinutes: serviceData.paymentWindowMinutes,
        requiresPayment: serviceData.requiresPayment,
        requiresDeposit: serviceData.requiresDeposit,
      });

      const scheduledDate = new Date(scheduledAt);
      if (isNaN(scheduledDate.getTime())) {
        throw new HttpsError("invalid-argument", "Invalid date.");
      }

      const scheduledTs = admin.firestore.Timestamp.fromDate(scheduledDate);
      const col = db.collection("groomy_appointments");

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

      const conflictSnap = await col
        .where("businessId", "==", businessId)
        .where("scheduledAt", "==", scheduledTs)
        .where("status", "in", [
          "pending",
          "awaiting_payment",
          "confirmed",
          "confirmed_paid",
        ])
        .limit(1)
        .get();

      if (!conflictSnap.empty) {
        throw new HttpsError(
          "already-exists",
          "This time slot is already booked."
        );
      }

      const finalBusinessName = businessName ||
        businessData.profile?.displayName ||
        "Grooming studio";

      const docRef = await col.add({
        appointmentType: "grooming",
        userId: uid,

        petId: finalPetId,
        petName: finalPetName,
        petType: finalPetType,
        petBreed: request.data.petBreed || "",
        petAge: request.data.petAge ?? null,
        dogId: finalPetId,
        dogName: finalPetName,

        businessId,
        businessName: finalBusinessName,
        groomyId: businessId,
        groomyName: finalBusinessName,

        serviceId: serviceId || null,
        serviceTitle: serviceTitle || "",
        price: paymentPolicy.servicePrice ?? price ?? 0,
        durationMin: durationMin || serviceData.durationMin || 0,
        serviceRequiresPayment: paymentPolicy.requiresPayment,
        servicePrice: paymentPolicy.servicePrice ?? price ?? 0,
        paymentWindowMinutes: paymentPolicy.paymentWindowMinutes,
        paymentStatus: paymentPolicy.requiresPayment ? "pending" : "not_required",
        paymentDeadlineAt: null,
        paidAt: null,
        paymentId: null,
        orderId: null,
        paymentTransactionId: null,
        paymentTransactionIds: [],

        scheduledAt: scheduledTs,
        note: note || "",
        status: "pending",

        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true,
      });

      logger.info("✅ Groomy appointment created:", docRef.id);

      try {
        const businessOwnerUid =
          businessData.ownerUid || businessData.uid || businessId;
        const title = "New Grooming Request";
        const body = `${finalPetName} requested ${serviceTitle || "grooming"}`;

        await db.collection("notifications").add({
          type: "groomy_appointment_request",
          recipientUserId: businessOwnerUid,
          senderUserId: uid,
          title,
          body,
          appointmentId: docRef.id,
          appointmentCollection: "groomy_appointments",
          businessId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const ownerSnap = await db.collection("users").doc(businessOwnerUid).get();
        const fcmToken = ownerSnap.data()?.fcmToken || businessData.fcmToken;

        if (fcmToken) {
          logger.info("🔔 Playdate/PetTaxi reference sound payload attached", {
            type: "groomy_appointment_request",
            recipientUserId: businessOwnerUid,
            appointmentId: docRef.id,
          });
          await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            data: {
              type: "groomy_appointment_request",
              appointmentId: docRef.id,
              appointmentCollection: "groomy_appointments",
              businessId,
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
                    title,
                    body,
                  },
                  sound: "default",
                  badge: 1,
                  "interruption-level": "time-sensitive",
                },
              },
            },
          });
          logger.info("🔔 Push send success", {
            type: "groomy_appointment_request",
            recipientUserId: businessOwnerUid,
            soundEnabled: true,
          });
        } else {
          logger.warn("⚠️ Push token missing", {
            type: "groomy_appointment_request",
            recipientUserId: businessOwnerUid,
          });
        }
      } catch (e) {
        logger.error("❌ Groomy notification error:", e);
      }

      return {
        ok: true,
        appointmentId: docRef.id,
      };
    } catch (e) {
      logger.error("❌ createGroomyAppointment FAILED:", e);

      if (e instanceof HttpsError) {
        throw e;
      }

      throw new HttpsError("internal", e.message);
    }
  }
);

exports.createHotelBooking = onCall(
  { region: "europe-west3" },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required.");
      }

      const uid = request.auth.uid;
      const {
        petId,
        petName,
        petType,
        dogId,
        dogName,
        businessId,
        businessName,
        serviceId,
        serviceTitle,
        price,
        pricePerNight,
        checkInDate,
        checkOutDate,
        note,
      } = request.data || {};

      const finalPetId = petId || dogId;
      const finalPetName = petName || dogName;
      const finalPetType = petType || "dog";

      if (!finalPetId || !businessId || !checkInDate || !checkOutDate) {
        throw new HttpsError("invalid-argument", "Missing required fields.");
      }

      const parsedCheckIn = new Date(checkInDate);
      const parsedCheckOut = new Date(checkOutDate);
      if (
        Number.isNaN(parsedCheckIn.getTime()) ||
        Number.isNaN(parsedCheckOut.getTime()) ||
        parsedCheckOut <= parsedCheckIn
      ) {
        throw new HttpsError("invalid-argument", "Invalid stay dates.");
      }

      const capacityResult = await assertHotelCapacityAvailable({
        businessId,
        checkInDate: parsedCheckIn,
        checkOutDate: parsedCheckOut,
        includePending: true,
      });
      const businessData = capacityResult.businessSnap.data() || {};
      const businessSectors = Array.isArray(businessData.sectors)
        ? businessData.sectors.map((sector) => normalizeLower(sector))
        : [];
      const businessSectorData = businessData.sectorData || {};
      const isHotelBusiness =
        businessSectors.includes("pet_hotel") ||
        businessSectors.includes("hotel") ||
        Boolean(businessSectorData.pet_hotel || businessSectorData.hotel);

      if (!isHotelBusiness) {
        throw new HttpsError(
          "failed-precondition",
          "Business is not a pet hotel."
        );
      }

      let serviceSnapshot = null;
      if (serviceId) {
        try {
          serviceSnapshot = await db
            .collection("businesses")
            .doc(businessId)
            .collection("services")
            .doc(serviceId)
            .get();
        } catch (error) {
          logger.warn("⚠️ Hotel service snapshot lookup failed", {
            businessId,
            serviceId,
            message: error?.message || String(error),
          });
        }
      }

      const serviceData = serviceSnapshot?.data() || {};
      const nightlyPrice = asNumber(
        serviceData.price ?? serviceData.pricePerNight ?? pricePerNight ?? price ?? 0,
        0
      );
      const totalNights = Math.max(
        1,
        Math.ceil(
          (parsedCheckOut.getTime() - parsedCheckIn.getTime()) /
          (24 * 60 * 60 * 1000)
        )
      );
      const totalPrice = roundMoney(nightlyPrice * totalNights);
      const paymentPolicy = resolveAppointmentPaymentPolicy({
        ...serviceData,
        servicePrice: totalPrice,
        price: totalPrice,
        requiresPayment: serviceData.requiresPayment,
        paymentWindowMinutes: serviceData.paymentWindowMinutes,
      });

      const finalBusinessName =
        businessName ||
        businessData.profile?.displayName ||
        "Pet hotel";

      const docRef = await db.collection("hotel_bookings").add({
        appointmentType: "pet_hotel",
        bookingType: "pet_hotel",
        userId: uid,

        petId: finalPetId,
        petName: finalPetName,
        petType: finalPetType,
        petBreed: request.data.petBreed || "",
        petAge: request.data.petAge ?? null,
        dogId: finalPetId,
        dogName: finalPetName,

        businessId,
        businessName: finalBusinessName,
        hotelId: businessId,
        hotelName: finalBusinessName,

        serviceId: serviceId || null,
        serviceTitle: serviceTitle || serviceData.title || "Hotel stay",
        durationType: serviceData.durationType || "night",

        checkInDate: admin.firestore.Timestamp.fromDate(parsedCheckIn),
        checkOutDate: admin.firestore.Timestamp.fromDate(parsedCheckOut),
        totalNights,
        pricePerNight: nightlyPrice,
        totalPrice,
        price: totalPrice,
        requiresPayment: paymentPolicy.requiresPayment,
        serviceRequiresPayment: paymentPolicy.requiresPayment,
        servicePrice: totalPrice,
        paymentWindowMinutes: paymentPolicy.paymentWindowMinutes,
        paymentStatus: paymentPolicy.requiresPayment ? "pending" : "not_required",
        paymentDeadlineAt: null,
        paidAt: null,
        paymentId: null,
        orderId: null,
        paymentTransactionId: null,
        paymentTransactionIds: [],

        note: note || "",
        status: "pending",

        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        isActive: true,
      });

      logger.info("✅ Hotel booking created:", docRef.id);

      try {
        const businessOwnerUid =
          businessData.ownerUid || businessData.uid || businessId;
        const title = "New Hotel Booking Request";
        const body = `${finalPetName} requested ${serviceTitle || "a stay"}`;

        await db.collection("notifications").add({
          type: "hotel_booking_request",
          recipientUserId: businessOwnerUid,
          senderUserId: uid,
          title,
          body,
          appointmentId: docRef.id,
          bookingId: docRef.id,
          appointmentCollection: "hotel_bookings",
          businessId,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const ownerSnap = await db.collection("users").doc(businessOwnerUid).get();
        const fcmToken = ownerSnap.data()?.fcmToken || businessData.fcmToken;

        if (fcmToken) {
          logger.info("🔔 Playdate/PetTaxi reference sound payload attached", {
            type: "hotel_booking_request",
            recipientUserId: businessOwnerUid,
            bookingId: docRef.id,
          });
          await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            data: {
              type: "hotel_booking_request",
              appointmentId: docRef.id,
              bookingId: docRef.id,
              appointmentCollection: "hotel_bookings",
              businessId,
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
                    title,
                    body,
                  },
                  sound: "default",
                  badge: 1,
                  "interruption-level": "time-sensitive",
                },
              },
            },
          });
          logger.info("🔔 Push send success", {
            type: "hotel_booking_request",
            recipientUserId: businessOwnerUid,
            soundEnabled: true,
          });
        } else {
          logger.warn("⚠️ Push token missing", {
            type: "hotel_booking_request",
            recipientUserId: businessOwnerUid,
          });
        }
      } catch (e) {
        logger.error("❌ Hotel booking notification error:", e);
      }

      return {
        ok: true,
        bookingId: docRef.id,
        appointmentId: docRef.id,
      };
    } catch (e) {
      logger.error("❌ createHotelBooking FAILED:", e);

      if (e instanceof HttpsError) {
        throw e;
      }

      throw new HttpsError("internal", e.message);
    }
  }
);

exports.updateHotelBookingStatus = onCall(
  { region: "europe-west3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required.");
    }

    const uid = request.auth.uid;
    const bookingId = String(
      request.data?.bookingId || request.data?.appointmentId || ""
    ).trim();
    const newStatus = String(
      request.data?.newStatus || request.data?.status || ""
    ).trim();

    if (!bookingId) {
      throw new HttpsError("invalid-argument", "bookingId is required.");
    }

    if (!newStatus) {
      throw new HttpsError("invalid-argument", "newStatus is required.");
    }

    assertHotelBookingStatus(newStatus);

    const bookingRef = db.collection("hotel_bookings").doc(bookingId);

    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(bookingRef);

      if (!snap.exists) {
        throw new HttpsError("not-found", "Booking not found.");
      }

      const data = snap.data() || {};
      const currentStatus = data.status || "pending";
      const businessId = data.businessId;
      const bookingOwnerUid = data.userId || data.buyerUid || null;

      assertHotelBookingStatus(currentStatus);

      if (!businessId) {
        throw new HttpsError(
          "failed-precondition",
          "Booking has no businessId."
        );
      }

      if (currentStatus === newStatus) {
        return {
          bookingId,
          appointmentId: bookingId,
          oldStatus: currentStatus,
          newStatus,
          businessId,
          userId: bookingOwnerUid,
          skipped: true,
        };
      }

      const businessRef = db.collection("businesses").doc(businessId);
      const businessSnap = await tx.get(businessRef);

      if (!businessSnap.exists) {
        throw new HttpsError("not-found", "Business not found.");
      }

      const adminSnap = await tx.get(db.collection("users").doc(uid));
      const isAdminUser = adminSnap.exists && adminSnap.data()?.role === "admin";
      const businessData = businessSnap.data() || {};
      const businessOwnerUid = businessData.ownerUid || businessData.uid || null;
      const isOwner = bookingOwnerUid === uid;
      const isBusinessOwner = businessOwnerUid === uid;
      const canUseStaffFlow = isBusinessOwner || isAdminUser;
      const isOwnerCancellation = newStatus === "cancelled_by_user";
      const ownerCancelableStatuses = [
        "pending",
        "awaiting_payment",
        "confirmed",
        "confirmed_paid",
      ];
      const isApprovalAttempt =
        currentStatus === "pending" &&
        (newStatus === "confirmed" || newStatus === "awaiting_payment");
      let approvalPolicySource = data;

      if (
        isApprovalAttempt &&
        data.serviceId &&
        (!data.serviceRequiresPayment ||
          data.serviceRequiresPayment === null ||
          data.serviceRequiresPayment === undefined)
      ) {
        const serviceSnap = await tx.get(
          businessRef.collection("services").doc(data.serviceId)
        );

        if (serviceSnap.exists) {
          const serviceData = serviceSnap.data() || {};
          approvalPolicySource = {
            ...data,
            ...serviceData,
            servicePrice: data.totalPrice ?? data.price ?? serviceData.price ?? 0,
            price: data.totalPrice ?? data.price ?? serviceData.price ?? 0,
            paymentWindowMinutes:
              serviceData.paymentWindowMinutes ??
              data.paymentWindowMinutes ??
              data.paymentWindow ??
              0,
            requiresPayment: serviceData.requiresPayment,
          };
        }
      }

      const paymentPolicy = resolveAppointmentPaymentPolicy(approvalPolicySource);
      const requiresPayment = requiresAppointmentPayment({
        serviceRequiresPayment:
          approvalPolicySource.serviceRequiresPayment ??
          approvalPolicySource.requiresPayment,
        servicePrice:
          approvalPolicySource.totalPrice ??
          paymentPolicy.servicePrice ??
          data.totalPrice ??
          data.price ??
          0,
        price: approvalPolicySource.price ?? data.price ?? 0,
      });
      const finalStatus = requiresPayment ? "awaiting_payment" : "confirmed";
      const finalPaymentStatus = requiresPayment ? "pending" : "not_required";
      let appliedStatus = newStatus;

      if (isApprovalAttempt) {
        appliedStatus = finalStatus;
      } else if (
        currentStatus === "awaiting_payment" &&
        newStatus === "confirmed_paid"
      ) {
        appliedStatus = "confirmed_paid";
      } else if (
        currentStatus === "awaiting_payment" &&
        newStatus === "payment_expired"
      ) {
        appliedStatus = "payment_expired";
      }

      if (isOwnerCancellation) {
        if (!isOwner) {
          throw new HttpsError(
            "permission-denied",
            "Only the booking owner can cancel this booking."
          );
        }

        if (!ownerCancelableStatuses.includes(currentStatus)) {
          throw new HttpsError(
            "failed-precondition",
            `Invalid cancellation transition: ${currentStatus} → ${newStatus}`
          );
        }
      } else if (!canUseStaffFlow) {
        throw new HttpsError(
          "permission-denied",
          "Only the hotel business owner can update this booking."
        );
      }

      const allowedNext =
        HOTEL_BOOKING_ALLOWED_TRANSITIONS[currentStatus] || [];

      if (!isOwnerCancellation && !allowedNext.includes(appliedStatus)) {
        throw new HttpsError(
          "failed-precondition",
          `Invalid transition: ${currentStatus} → ${appliedStatus}`
        );
      }

      const checkIn = asDateOrNull(data.checkInDate);
      const checkOut = asDateOrNull(data.checkOutDate);
      if (
        ["awaiting_payment", "confirmed", "confirmed_paid", "checked_in"].includes(
          appliedStatus
        ) &&
        checkIn &&
        checkOut
      ) {
        const maxCapacity = hotelMaxCapacity(businessData);
        const overlapping = await countOverlappingHotelBookings({
          businessId,
          checkInDate: checkIn,
          checkOutDate: checkOut,
          statuses: ["awaiting_payment", "confirmed", "confirmed_paid", "checked_in"],
          excludeBookingId: bookingId,
        });

        if (overlapping >= maxCapacity) {
          throw new HttpsError(
            "already-exists",
            "Pet hotel capacity is full for these dates."
          );
        }
      }

      const updatePayload = {
        status: appliedStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        statusUpdatedBy: uid,
        lastStatusChange: {
          from: currentStatus,
          to: appliedStatus,
          by: uid,
          at: admin.firestore.FieldValue.serverTimestamp(),
        },
      };

      if (appliedStatus === "awaiting_payment") {
        updatePayload.paymentStatus = finalPaymentStatus;
        updatePayload.paymentDeadlineAt = buildAppointmentPaymentDeadline(
          paymentPolicy.paymentWindowMinutes
        );
        updatePayload.serviceRequiresPayment = true;
        updatePayload.requiresPayment = true;
        updatePayload.servicePrice = data.totalPrice ?? data.price ?? 0;
        updatePayload.price = data.totalPrice ?? data.price ?? 0;
        updatePayload.paymentWindowMinutes = paymentPolicy.paymentWindowMinutes;
      } else if (appliedStatus === "confirmed") {
        updatePayload.paymentStatus = finalPaymentStatus;
        if (!requiresPayment) {
          updatePayload.paymentDeadlineAt = null;
        }
      } else if (appliedStatus === "payment_expired") {
        updatePayload.paymentStatus = "expired";
      }

      tx.update(bookingRef, updatePayload);

      return {
        bookingId,
        appointmentId: bookingId,
        oldStatus: currentStatus,
        newStatus: appliedStatus,
        businessId,
        userId: bookingOwnerUid,
        businessOwnerUid,
      };
    });

    try {
      const finalSnap = await bookingRef.get();
      const data = finalSnap.data() || {};
      const userId = data.userId || result.userId;
      const businessId = data.businessId || result.businessId;
      const businessSnap = businessId
        ? await db.collection("businesses").doc(businessId).get()
        : null;
      const businessData = businessSnap?.data() || {};
      const businessOwnerUid =
        businessData.ownerUid || businessData.uid || result.businessOwnerUid;

      let title = "Hotel Booking Update";
      let body = "Your hotel booking status changed";

      if (result.newStatus === "awaiting_payment") {
        title = "Payment Required";
        body = `${data.serviceTitle || "Hotel stay"} is waiting for payment`;
      } else if (result.newStatus === "confirmed") {
        title = "Hotel Booking Confirmed";
        body = `${data.serviceTitle || "Hotel stay"} is confirmed`;
      } else if (result.newStatus === "confirmed_paid") {
        title = "Hotel Booking Paid";
        body = `${data.serviceTitle || "Hotel stay"} payment completed`;
      } else if (result.newStatus === "rejected") {
        title = "Hotel Booking Rejected";
        body = "Your hotel booking was rejected";
      } else if (result.newStatus === "cancelled_by_hotel") {
        title = "Hotel Booking Cancelled";
        body = `${data.serviceTitle || "Hotel stay"} was cancelled`;
      } else if (result.newStatus === "completed") {
        title = "Hotel Stay Completed";
        body = `${data.serviceTitle || "Hotel stay"} is completed`;
      } else if (result.newStatus === "cancelled_by_user") {
        title = "Hotel Booking Cancelled";
        body = `${data.serviceTitle || "Hotel stay"} was cancelled by the user`;
      } else if (result.newStatus === "checked_in") {
        title = "Pet Checked In";
        body = `${data.petName || data.dogName || "Pet"} checked in`;
      }

      if (userId) {
        await db.collection("notifications").add({
          type: "hotel_booking_response",
          recipientUserId: userId,
          senderUserId: businessOwnerUid || uid,
          businessId,
          appointmentId: result.bookingId,
          bookingId: result.bookingId,
          appointmentCollection: "hotel_bookings",
          status: result.newStatus,
          title,
          body,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const userSnap = await db.collection("users").doc(userId).get();
        const fcmToken = userSnap.data()?.fcmToken;

        if (fcmToken) {
          logger.info("🔔 Playdate/PetTaxi reference sound payload attached", {
            type: "hotel_booking_response",
            recipientUserId: userId,
            bookingId: result.bookingId,
          });
          await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            data: {
              type: "hotel_booking_response",
              appointmentId: result.bookingId,
              bookingId: result.bookingId,
              appointmentCollection: "hotel_bookings",
              status: result.newStatus,
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
                    title,
                    body,
                  },
                  sound: "default",
                  badge: 1,
                  "interruption-level": "time-sensitive",
                },
              },
            },
          });
          logger.info("🔔 Push send success", {
            type: "hotel_booking_response",
            recipientUserId: userId,
            soundEnabled: true,
          });
        } else {
          logger.warn("⚠️ Push token missing", {
            type: "hotel_booking_response",
            recipientUserId: userId,
          });
        }
      }

      if (result.newStatus === "cancelled_by_user" && businessOwnerUid) {
        await db.collection("notifications").add({
          type: "hotel_booking_cancelled_by_user",
          recipientUserId: businessOwnerUid,
          senderUserId: userId || uid,
          businessId,
          appointmentId: result.bookingId,
          bookingId: result.bookingId,
          appointmentCollection: "hotel_bookings",
          status: result.newStatus,
          title: "Hotel Booking Cancelled",
          body: `${data.serviceTitle || "Hotel stay"} was cancelled by the user`,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      logger.error("❌ Hotel booking notify failed", e);
    }

    return {
      ok: true,
      ...result,
    };
  }
);

const PET_TAXI_STATUSES = [
  "pending",
  "awaiting_user_payment",
  "confirmed_paid",
  "payment_failed",
  "refund_pending",
  "refunded",
  "driver_on_the_way",
  "arrived",
  "pet_picked_up",
  "on_trip",
  "completed",
  "cancelled_by_user",
  "cancelled_by_business",
];

function assertPetTaxiStatus(status) {
  if (!PET_TAXI_STATUSES.includes(status)) {
    throw new HttpsError("invalid-argument", "Invalid pet taxi status.");
  }
}

function petTaxiAllowedTransition(from, to) {
  const allowed = {
    pending: ["awaiting_user_payment", "cancelled_by_user", "cancelled_by_business"],
    awaiting_user_payment: ["awaiting_user_payment", "confirmed_paid", "payment_failed", "cancelled_by_user", "cancelled_by_business"],
    payment_failed: ["awaiting_user_payment", "cancelled_by_user", "cancelled_by_business"],
    confirmed_paid: ["driver_on_the_way", "refund_pending", "cancelled_by_business"],
    refund_pending: ["refunded"],
    driver_on_the_way: ["arrived", "cancelled_by_business"],
    arrived: ["pet_picked_up", "cancelled_by_business"],
    pet_picked_up: ["on_trip", "cancelled_by_business"],
    on_trip: ["completed", "cancelled_by_business"],
    completed: [],
    refunded: [],
    cancelled_by_user: [],
    cancelled_by_business: [],
  };
  return (allowed[from] || []).includes(to);
}

function petTaxiPushData({
  type,
  bookingId,
  businessId,
  recipientUserId,
  status,
}) {
  return {
    type: String(type || ""),
    bookingId: String(bookingId || ""),
    appointmentId: String(bookingId || ""),
    appointmentCollection: "pet_taxi_bookings",
    businessId: String(businessId || ""),
    recipientUserId: String(recipientUserId || ""),
    status: String(status || ""),
  };
}

async function sendPetTaxiPush({
  recipientUserId,
  fallbackToken = null,
  type,
  title,
  body,
  bookingId,
  businessId,
  status,
}) {
  try {
    logger.info("🚕 Pet Taxi push lookup", {
      type,
      bookingId,
      recipientUserId,
      status,
    });

    let token = fallbackToken || null;
    if (recipientUserId) {
      const userSnap = await db.collection("users").doc(recipientUserId).get();
      token = userSnap.data()?.fcmToken || token;
    }

    if (!token) {
      logger.warn("🚕 Pet Taxi push token missing", {
        type,
        bookingId,
        recipientUserId,
      });
      return;
    }

    logger.info("🚕 Pet Taxi push token found", {
      type,
      bookingId,
      recipientUserId,
    });

    logger.info("🚕 Playdate reference path detected", {
      reference: "safeSendPush(notification + data + android priority + apns aps sound)",
      type,
      bookingId,
      recipientUserId,
    });

    const pushPayload = {
      notification: {
        title,
        body,
      },
      data: petTaxiPushData({
        type,
        bookingId,
        businessId,
        recipientUserId,
        status,
      }),
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
              title,
              body,
            },
            sound: "default",
            badge: 1,
            "interruption-level": "time-sensitive",
          },
        },
      },
    };

    logger.info("🚕 Pet Taxi using same sound path", {
      type,
      bookingId,
      recipientUserId,
      helper: "safeSendPush",
      hasNotification: Boolean(pushPayload.notification),
      dataKeys: Object.keys(pushPayload.data),
    });
    logger.info("🚕 Pet Taxi APNS payload built", {
      type,
      bookingId,
      recipientUserId,
      sound: pushPayload.apns.payload.aps.sound,
      badge: pushPayload.apns.payload.aps.badge,
      priority: pushPayload.apns.headers["apns-priority"],
    });
    logger.info("🚕 Pet Taxi sound payload attached", {
      type,
      bookingId,
      recipientUserId,
    });

    const sent = await safeSendPush({
      token,
      userId: recipientUserId,
      payload: pushPayload,
    });

    logger.info("🚕 Pet Taxi push sent", {
      type,
      bookingId,
      recipientUserId,
      sent,
    });
  } catch (error) {
    logger.error("🚕 Pet Taxi push failed", {
      type,
      bookingId,
      recipientUserId,
      message: error?.message || String(error),
      stack: error?.stack || null,
    });
  }
}

async function createPetTaxiNotification({
  type,
  recipientUserId,
  senderUserId,
  title,
  body,
  bookingId,
  businessId,
  status,
  fallbackToken = null,
  extra = {},
}) {
  await db.collection("notifications").add({
    type,
    recipientUserId,
    senderUserId,
    title,
    body,
    bookingId,
    appointmentId: bookingId,
    appointmentCollection: "pet_taxi_bookings",
    businessId,
    status: status || null,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...extra,
  });

  await sendPetTaxiPush({
    recipientUserId,
    fallbackToken,
    type,
    title,
    body,
    bookingId,
    businessId,
    status,
  });
}

function petTaxiUserPushTypeForStatus(status) {
  const map = {
    awaiting_user_payment: "pet_taxi_price_proposed",
    driver_on_the_way: "pet_taxi_driver_on_the_way",
    arrived: "pet_taxi_driver_arrived",
    pet_picked_up: "pet_taxi_pet_picked_up",
    on_trip: "pet_taxi_trip_started",
    completed: "pet_taxi_trip_completed",
    cancelled_by_business: "pet_taxi_booking_cancelled",
  };
  return map[status] || "pet_taxi_status_update";
}

exports.createPetTaxiBooking = onCall(
  { region: "europe-west3" },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required.");
      }

      const uid = request.auth.uid;
      const {
        businessId,
        businessName,
        petId,
        petName,
        petType,
        petBreed,
        pickupAddress,
        pickupLocation,
        pickupLat,
        pickupLng,
        dropoffAddress,
        dropoffLocation,
        dropoffLat,
        dropoffLng,
        scheduledAt,
        tripType,
        serviceReason,
        petSize,
        specialNotes,
        userPhone,
        paymentMethod,
      } = request.data || {};

      if (!businessId || !petId || !petName || !pickupAddress || !dropoffAddress || !scheduledAt || !userPhone) {
        throw new HttpsError("invalid-argument", "Missing required fields.");
      }

      const parsedScheduledAt = new Date(scheduledAt);
      if (Number.isNaN(parsedScheduledAt.getTime())) {
        throw new HttpsError("invalid-argument", "Invalid scheduledAt.");
      }

      const businessSnap = await db.collection("businesses").doc(businessId).get();
      if (!businessSnap.exists) {
        throw new HttpsError("not-found", "Business not found.");
      }

      const businessData = businessSnap.data() || {};
      const sectors = Array.isArray(businessData.sectors)
        ? businessData.sectors.map((sector) => String(sector).toLowerCase())
        : [];
      const sectorData = businessData.sectorData || {};
      const isPetTaxi =
        sectors.includes("pet_taxi") ||
        Boolean(sectorData.pet_taxi || sectorData.petTaxi || sectorData.taxi);

      if (!isPetTaxi) {
        throw new HttpsError("failed-precondition", "Business is not a pet taxi.");
      }

      const finalBusinessName =
        businessName ||
        businessData.profile?.displayName ||
        "Pet Taxi";

      const docRef = await db.collection("pet_taxi_bookings").add({
        userId: uid,
        businessId,
        businessName: finalBusinessName,
        petId,
        petName,
        petType: petType || "dog",
        petBreed: petBreed || "",
        pickupAddress,
        pickupLocation: pickupLocation || null,
        pickupLat: pickupLat ?? pickupLocation?.lat ?? null,
        pickupLng: pickupLng ?? pickupLocation?.lng ?? null,
        dropoffAddress,
        dropoffLocation: dropoffLocation || null,
        dropoffLat: dropoffLat ?? dropoffLocation?.lat ?? null,
        dropoffLng: dropoffLng ?? dropoffLocation?.lng ?? null,
        scheduledAt: admin.firestore.Timestamp.fromDate(parsedScheduledAt),
        tripType: tripType || "one_way",
        serviceReason: serviceReason || "custom",
        petSize: petSize || "medium",
        specialNotes: specialNotes || "",
        userPhone,
        paymentMethod: "in_app",
        paymentStatus: "unpaid",
        paymentOrderId: null,
        paymentTransactionId: null,
        paymentProvider: "iyzico",
        paidAt: null,
        paymentAmount: null,
        paymentCurrency: request.data.estimateCurrency || "TRY",
        providerPayoutStatus: "not_ready",
        providerPayoutAt: null,
        refundStatus: "none",
        refundReason: null,
        priceEstimate: request.data.priceEstimate ?? null,
        estimatedMinPrice: request.data.estimatedMinPrice ?? null,
        estimatedMaxPrice: request.data.estimatedMaxPrice ?? null,
        estimateCurrency: request.data.estimateCurrency || "TRY",
        estimatedDistanceKm: request.data.estimatedDistanceKm ?? null,
        routeDistanceKm: request.data.routeDistanceKm ?? null,
        routeDurationMinutes: request.data.routeDurationMinutes ?? null,
        routeEstimate: request.data.routeEstimate || null,
        pricingRulesSnapshot: request.data.pricingRulesSnapshot || null,
        finalPrice: null,
        finalPriceCurrency: request.data.estimateCurrency || "TRY",
        priceConfirmedBy: null,
        priceConfirmedAt: null,
        userAcceptedPrice: false,
        userAcceptedAt: null,
        petMicrochipId: request.data.petMicrochipId || "",
        vaccinationCardInfo: request.data.vaccinationCardInfo || "",
        medicalConditionNotes: request.data.medicalConditionNotes || "",
        behaviorNotes: request.data.behaviorNotes || "",
        emergencyContactNumber: request.data.emergencyContactNumber || "",
        cageCarrierRequired: request.data.cageCarrierRequired === true,
        leashRequired: request.data.leashRequired === true,
        largeDog: request.data.largeDog === true,
        specialAssistanceRequired: request.data.specialAssistanceRequired === true,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastStatusChange: {
          from: null,
          to: "pending",
          at: admin.firestore.FieldValue.serverTimestamp(),
          by: uid,
        },
      });

      try {
        const businessOwnerUid = businessData.ownerUid || businessData.uid || businessId;
        const title = "New Pet Taxi Request";
        const body = `${petName} needs a pet taxi ride`;

        await createPetTaxiNotification({
          type: "pet_taxi_booking_request",
          recipientUserId: businessOwnerUid,
          senderUserId: uid,
          title,
          body,
          bookingId: docRef.id,
          businessId,
          status: "pending",
          fallbackToken: businessData.fcmToken || null,
        });
      } catch (e) {
        logger.error("❌ Pet taxi booking notification error:", e);
      }

      return { ok: true, bookingId: docRef.id };
    } catch (e) {
      logger.error("❌ createPetTaxiBooking FAILED:", e);
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", e.message || "Failed to create booking.");
    }
  }
);

exports.updatePetTaxiBookingStatus = onCall(
  { region: "europe-west3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required.");
    }

    const uid = request.auth.uid;
    const bookingId = String(request.data?.bookingId || "").trim();
    const newStatus = String(request.data?.newStatus || request.data?.status || "").trim();
    const finalPrice = request.data?.finalPrice;
    const finalPriceCurrency = request.data?.finalPriceCurrency || "TRY";

    if (!bookingId || !newStatus) {
      throw new HttpsError("invalid-argument", "bookingId and newStatus are required.");
    }

    assertPetTaxiStatus(newStatus);
    const bookingRef = db.collection("pet_taxi_bookings").doc(bookingId);

    const result = await db.runTransaction(async (tx) => {
      const bookingSnap = await tx.get(bookingRef);
      if (!bookingSnap.exists) {
        throw new HttpsError("not-found", "Booking not found.");
      }

      const data = bookingSnap.data() || {};
      const oldStatus = data.status || "pending";
      assertPetTaxiStatus(oldStatus);

      const businessId = data.businessId;
      const businessRef = db.collection("businesses").doc(businessId);
      const businessSnap = await tx.get(businessRef);
      if (!businessSnap.exists) {
        throw new HttpsError("not-found", "Business not found.");
      }

      const adminSnap = await tx.get(db.collection("users").doc(uid));
      const isAdminUser = adminSnap.exists && adminSnap.data()?.role === "admin";
      const businessData = businessSnap.data() || {};
      const businessOwnerUid = businessData.ownerUid || businessData.uid || businessId;
      const isBusinessOwner = businessOwnerUid === uid;
      const isBookingOwner = data.userId === uid;
      const proposingPrice =
        newStatus === "awaiting_user_payment";
      const editingProposedPrice =
        proposingPrice &&
        (oldStatus === "awaiting_user_payment" || oldStatus === "payment_failed");

      if (oldStatus === newStatus && !editingProposedPrice) {
        return { skipped: true, data, oldStatus, newStatus };
      }

      if (!editingProposedPrice && !petTaxiAllowedTransition(oldStatus, newStatus)) {
        throw new HttpsError("failed-precondition", "Status transition is not allowed.");
      }

      if (newStatus === "cancelled_by_user") {
        if (!isBookingOwner && !isAdminUser) {
          throw new HttpsError("permission-denied", "Only the user can cancel this booking.");
        }
      } else if (!isBusinessOwner && !isAdminUser) {
        throw new HttpsError("permission-denied", "Only the business owner can update this booking.");
      }

      const update = {
        status: proposingPrice ? "awaiting_user_payment" : newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastStatusChange: {
          from: oldStatus,
          to: proposingPrice ? "awaiting_user_payment" : newStatus,
          at: admin.firestore.FieldValue.serverTimestamp(),
          by: uid,
        },
      };

      if (proposingPrice) {
        const parsedFinalPrice = Number(finalPrice);
        if (!Number.isFinite(parsedFinalPrice) || parsedFinalPrice <= 0) {
          throw new HttpsError("invalid-argument", "Final price is required.");
        }
        update.finalPrice = Math.round(parsedFinalPrice * 100) / 100;
        update.finalPriceCurrency = String(finalPriceCurrency || "TRY");
        update.priceConfirmedBy = uid;
        update.priceConfirmedAt = admin.firestore.FieldValue.serverTimestamp();
        update.paymentStatus = "unpaid";
        update.paymentAmount = Math.round(parsedFinalPrice * 100) / 100;
        update.paymentCurrency = String(finalPriceCurrency || "TRY");
      }

      if (newStatus === "cancelled_by_user" && request.data?.priceRejected === true) {
        update.userRejectedPrice = true;
        update.userRejectedAt = admin.firestore.FieldValue.serverTimestamp();
      }

      if (newStatus === "completed") {
        update.providerPayoutStatus = data.paymentStatus === "paid"
          ? "pending"
          : data.providerPayoutStatus || "not_ready";
        update.providerPayoutAt = null;
      }

      tx.update(bookingRef, update);

      return {
        skipped: false,
        data,
        oldStatus,
        newStatus: proposingPrice ? "awaiting_user_payment" : newStatus,
        businessData,
        businessOwnerUid,
      };
    });

    if (!result.skipped) {
      try {
        const data = result.data || {};
        const businessData = result.businessData || {};
        const businessOwnerUid = result.businessOwnerUid ||
          businessData.ownerUid ||
          businessData.uid ||
          data.businessId;
        const effectiveStatus = result.newStatus || newStatus;
        const providerSide = effectiveStatus === "cancelled_by_user";
        const type = providerSide
          ? "pet_taxi_booking_cancelled_by_user"
          : petTaxiUserPushTypeForStatus(effectiveStatus);
        const recipientId = providerSide ? businessOwnerUid : data.userId;
        const senderId = providerSide ? data.userId : businessOwnerUid;
        const title = effectiveStatus === "awaiting_user_payment"
          ? "Pet Taxi Final Price"
          : effectiveStatus === "cancelled_by_user"
            ? "Pet Taxi Booking Cancelled"
            : effectiveStatus === "cancelled_by_business"
              ? "Pet Taxi Booking Cancelled"
              : "Pet Taxi Status Update";
        const body = effectiveStatus === "awaiting_user_payment"
          ? `Final price proposed for ${data.petName || "your pet taxi booking"}`
          : effectiveStatus === "cancelled_by_user"
            ? `${data.petName || "Pet taxi booking"} was cancelled by the customer`
            : `${data.petName || "Your pet taxi booking"} is ${effectiveStatus.replace(/_/g, " ")}`;

        await createPetTaxiNotification({
          type,
          recipientUserId: recipientId,
          senderUserId: senderId,
          title,
          body,
          bookingId,
          businessId: data.businessId,
          status: effectiveStatus,
        });
      } catch (e) {
        logger.error("❌ Pet taxi status notification error:", e);
      }
    }

    return {
      ok: true,
      bookingId,
      oldStatus: result.oldStatus,
      newStatus: result.newStatus || newStatus,
      skipped: result.skipped,
    };
  }
);

exports.createPetTaxiOrder = onCall(
  {
    region: "europe-west3",
    secrets: [IYZICO_API_KEY, IYZICO_SECRET_KEY],
  },
  async (request) => {
    try {
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Login required");
      }

      const bookingId = String(request.data?.bookingId || request.data?.appointmentId || "").trim();
      if (!bookingId) {
        throw new HttpsError("invalid-argument", "bookingId required");
      }

      const bookingRef = db.collection("pet_taxi_bookings").doc(bookingId);
      const bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) {
        throw new HttpsError("not-found", "Pet taxi booking not found");
      }

      const data = bookingSnap.data() || {};
      if (data.userId !== uid) {
        throw new HttpsError("permission-denied", "Only the booking owner can pay");
      }
      if (!["awaiting_user_payment", "payment_failed"].includes(data.status)) {
        throw new HttpsError(
          "failed-precondition",
          `Payment can only be started while awaiting payment. Current status: ${data.status}`
        );
      }

      const price = Number(data.finalPrice || data.paymentAmount || 0);
      if (!Number.isFinite(price) || price <= 0) {
        throw new HttpsError("failed-precondition", "Invalid final price");
      }
      const currency = data.finalPriceCurrency || data.paymentCurrency || "TRY";

      const userSnap = await db.collection("users").doc(uid).get();
      const user = userSnap.data() || {};

      const buyer = {
        id: uid,
        name: safe(user.name || user.displayName, "User"),
        surname: safe(user.surname, "User"),
        gsmNumber: safe(user.phone || data.userPhone, "+905000000000"),
        email: safe(user.email, "test@email.com"),
        identityNumber: "11111111111",
        registrationAddress: safe(user.address || data.pickupAddress, "Istanbul"),
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

      const orderRef = db.collection("orders").doc();
      await orderRef.set({
        type: "pet_taxi",
        appointmentType: "pet_taxi",
        appointmentCollection: "pet_taxi_bookings",
        appointmentId: bookingId,
        bookingId,
        buyerUid: uid,
        businessId: data.businessId,
        status: "pending",
        paymentStatus: "pending",
        pricing: {
          grandTotal: price,
          currency,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

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
            currency,
            buyer,
            shippingAddress: address,
            billingAddress: address,
            basketItems: [
              {
                id: bookingId,
                name: data.serviceTitle || `Pet Taxi Booking - ${data.petName || "Pet"}`,
                category1: "Pet Taxi",
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

      if (!result || !result.token || !result.paymentPageUrl) {
        logger.error("❌ INVALID PET TAXI IYZICO RESPONSE", result);
        throw new HttpsError("internal", "Iyzi failed");
      }

      await orderRef.update({
        payment: {
          checkoutToken: result.token,
          checkoutUrl: result.paymentPageUrl,
          provider: "iyzico",
          status: "pending",
          currency,
          price,
          conversationId: orderRef.id,
        },
      });

      await bookingRef.set(
        {
          status: "awaiting_user_payment",
          orderId: orderRef.id,
          paymentOrderId: orderRef.id,
          checkoutToken: result.token,
          conversationId: orderRef.id,
          paymentStatus: "pending",
          paymentProvider: "iyzico",
          paymentAmount: price,
          paymentCurrency: currency,
          refundStatus: data.refundStatus || "none",
          providerPayoutStatus: data.providerPayoutStatus || "not_ready",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastStatusChange: {
            from: data.status || "awaiting_user_payment",
            to: "awaiting_user_payment",
            at: admin.firestore.FieldValue.serverTimestamp(),
            by: uid,
          },
        },
        { merge: true }
      );

      return {
        orderId: orderRef.id,
        checkoutUrl: result.paymentPageUrl,
      };
    } catch (error) {
      logger.error("❌ createPetTaxiOrder ERROR", error);
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", error?.message || "Unknown error");
    }
  }
);

exports.verifyPetTaxiPayment = onCall(
  {
    region: "europe-west3",
    timeoutSeconds: 60,
    memory: "256MiB",
    secrets: [IYZICO_API_KEY, IYZICO_SECRET_KEY],
  },
  async (request) => {
    try {
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Login required");
      }

      const orderId = String(request.data?.orderId || "").trim();
      if (!orderId) {
        throw new HttpsError("invalid-argument", "Missing orderId");
      }

      const orderRef = db.collection("orders").doc(orderId);
      const orderSnap = await orderRef.get();
      if (!orderSnap.exists) {
        throw new HttpsError("not-found", "Order not found");
      }

      const orderData = orderSnap.data() || {};
      if (orderData.type !== "pet_taxi") {
        throw new HttpsError("failed-precondition", "Order is not a pet taxi order");
      }
      if (orderData.buyerUid !== uid) {
        throw new HttpsError("permission-denied", "Only the buyer can verify payment");
      }

      const token = orderData.payment?.checkoutToken;
      if (!token) {
        throw new HttpsError("failed-precondition", "Missing payment token in order");
      }

      const bookingId = orderData.bookingId || orderData.appointmentId;
      const bookingRef = db.collection("pet_taxi_bookings").doc(bookingId);
      const bookingSnap = await bookingRef.get();
      if (!bookingSnap.exists) {
        throw new HttpsError("not-found", "Pet taxi booking not found");
      }
      const bookingData = bookingSnap.data() || {};

      if (orderData.payment?.status === "paid") {
        return {
          success: true,
          alreadyPaid: true,
          type: "pet_taxi",
          appointmentCollection: "pet_taxi_bookings",
          appointmentType: "pet_taxi",
          appointmentId: bookingId,
        };
      }

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

      const paymentTransactionIds = extractPaymentTransactionIds(
        result?.itemTransactions
      );
      const paymentTransactionId =
        paymentTransactionIds.length > 0
          ? paymentTransactionIds[0]
          : result?.paymentTransactionId?.toString?.() ||
          result?.paymentTransactionId ||
          null;

      if (!result || result.status !== "success") {
        await orderRef.set(
          {
            status: "failed",
            paymentStatus: "failed",
            payment: {
              ...(orderData.payment || {}),
              status: "failed",
              provider: "iyzico",
              errorMessage: result?.errorMessage || "Payment not successful",
              rawStatus: result?.status || null,
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        await bookingRef.set(
          {
            status: "payment_failed",
            paymentStatus: "failed",
            paymentOrderId: orderId,
            paymentProvider: "iyzico",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastStatusChange: {
              from: bookingData.status || "awaiting_user_payment",
              to: "payment_failed",
              at: admin.firestore.FieldValue.serverTimestamp(),
              by: uid,
            },
          },
          { merge: true }
        );
        throw new HttpsError("failed-precondition", "Payment not successful");
      }

      await orderRef.update({
        "payment.status": "paid",
        paymentStatus: "paid",
        status: "paid",
        "payment.paymentId": result.paymentId || null,
        "payment.paymentProvider": "iyzico",
        "payment.paidPrice": result.paidPrice || null,
        "payment.price": result.price || null,
        "payment.conversationId": result.conversationId || orderData.payment?.conversationId || null,
        "payment.paymentTransactionId": paymentTransactionId || null,
        "payment.paymentTransactionIds": paymentTransactionIds,
        "payment.iyzicoPaymentTransactionId": paymentTransactionId || null,
        "payment.currency": result.currency || orderData.payment?.currency || orderData.pricing?.currency || "TRY",
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await bookingRef.update({
        paymentStatus: "paid",
        status: "confirmed_paid",
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        paymentOrderId: orderId,
        orderId,
        paymentId: result.paymentId || null,
        iyzicoPaymentId: result.paymentId || null,
        paymentTransactionId: paymentTransactionId || null,
        paymentTransactionIds,
        iyzicoPaymentTransactionId: paymentTransactionId || null,
        paymentProvider: "iyzico",
        paymentAmount: Number(result.paidPrice || result.price || bookingData.finalPrice || 0),
        paymentCurrency: result.currency || bookingData.finalPriceCurrency || "TRY",
        providerPayoutStatus: "pending_completion",
        providerPayoutAt: null,
        refundStatus: bookingData.refundStatus || "none",
        refundReason: bookingData.refundReason || null,
        conversationId: result.conversationId || orderData.payment?.conversationId || null,
        checkoutToken: orderData.payment?.checkoutToken || null,
        lastStatusChange: {
          from: bookingData.status || "awaiting_user_payment",
          to: "confirmed_paid",
          at: admin.firestore.FieldValue.serverTimestamp(),
          by: uid,
        },
      });

      const businessId = bookingData.businessId || orderData.businessId;
      let recipientUserId = businessId;
      if (businessId) {
        try {
          const businessSnap = await db.collection("businesses").doc(businessId).get();
          const businessData = businessSnap.data() || {};
          recipientUserId = businessData.ownerUid || businessData.uid || businessId;
        } catch (error) {
          logger.warn("⚠️ Pet taxi payment recipient lookup failed", {
            businessId,
            message: error?.message || String(error),
          });
        }
      }

      if (recipientUserId) {
        await createPetTaxiNotification({
          type: "pet_taxi_payment_completed",
          recipientUserId,
          senderUserId: uid,
          title: "Pet Taxi Payment Completed",
          body: `${bookingData.petName || "Pet taxi booking"} payment completed successfully`,
          bookingId,
          businessId,
          status: "confirmed_paid",
          extra: {
            appointmentType: "pet_taxi",
            orderId,
          },
        });
      }

      await createPetTaxiNotification({
        type: "pet_taxi_payment_success",
        recipientUserId: uid,
        senderUserId: recipientUserId || "system",
        title: "Pet Taxi Payment Successful",
        body: `${bookingData.petName || "Your pet taxi booking"} is paid and confirmed`,
        bookingId,
        businessId,
        status: "confirmed_paid",
        extra: {
          appointmentType: "pet_taxi",
          orderId,
        },
      });

      return {
        success: true,
        type: "pet_taxi",
        appointmentCollection: "pet_taxi_bookings",
        appointmentType: "pet_taxi",
        appointmentId: bookingId,
      };
    } catch (error) {
      logger.error("❌ verifyPetTaxiPayment ERROR", {
        message: error?.message || String(error),
        stack: error?.stack || null,
      });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError("internal", error?.message || "Unknown error");
    }
  }
);

exports.syncBusinessToken = onCall(
  { region: 'europe-west3' },
  async (req) => {
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
  },
);

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

function appointmentCollectionForRequest(data = {}) {
  const requestedCollection = String(data.appointmentCollection || "").trim();
  if (requestedCollection === "hotel_bookings") {
    return "hotel_bookings";
  }

  if (requestedCollection === "groomy_appointments") {
    return "groomy_appointments";
  }

  const requestedType = normalizeLower(
    data.appointmentType || data.businessType || data.sector || ""
  );

  if (
    requestedType.includes("hotel") ||
    requestedType.includes("boarding") ||
    requestedType.includes("pet_hotel")
  ) {
    return "hotel_bookings";
  }

  return requestedType.includes("groom")
    ? "groomy_appointments"
    : "vet_appointments";
}

function appointmentCollectionForOrder(orderData = {}) {
  logger.info("🧪 appointmentCollectionForOrder INPUT", orderData);

  if (orderData.appointmentCollection === "groomy_appointments") {
    logger.info("🧪 RETURN groomy_appointments via explicit collection");
    return "groomy_appointments";
  }

  if (orderData.appointmentCollection === "hotel_bookings") {
    logger.info("🧪 RETURN hotel_bookings via explicit collection");
    return "hotel_bookings";
  }

  const normalizedType = normalizeLower(orderData.appointmentType);

  logger.info("🧪 normalizedType", normalizedType);

  const result =
    normalizedType.includes("hotel") ||
      normalizedType.includes("boarding") ||
      normalizedType.includes("pet_hotel")
      ? "hotel_bookings"
      : normalizedType.includes("groom")
        ? "groomy_appointments"
        : "vet_appointments";

  logger.info("🧪 appointmentCollectionForOrder RESULT", result);

  return result;
}

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
      const appointmentCollection = appointmentCollectionForRequest(request.data);
      const appointmentType =
        appointmentCollection === "hotel_bookings"
          ? "pet_hotel"
          : appointmentCollection === "groomy_appointments"
            ? "grooming"
            : "veterinary";

      // =========================
      // APPOINTMENT
      // =========================
      const snap = await db
        .collection(appointmentCollection)
        .doc(appointmentId)
        .get();

      if (!snap.exists) {
        throw new HttpsError("not-found", "Appointment not found");
      }

      const data = snap.data() || {};
      const paymentPolicy = resolveAppointmentPaymentPolicy(data);
      const currentStatus = data.status || "pending";
      const paymentDeadlineAt = data.paymentDeadlineAt || null;

      const price = data.price;
      if (!price || price <= 0) {
        throw new HttpsError("failed-precondition", "Invalid price");
      }

      if (!paymentPolicy.requiresPayment) {
        throw new HttpsError(
          "failed-precondition",
          "This appointment does not require payment"
        );
      }

      if (currentStatus !== "awaiting_payment") {
        throw new HttpsError(
          "failed-precondition",
          `Payment can only be started while awaiting payment. Current status: ${currentStatus}`
        );
      }

      if (paymentDeadlineAt) {
        const deadlineMillis = toMillisSafe(paymentDeadlineAt);
        if (deadlineMillis && deadlineMillis < Date.now()) {
          throw new HttpsError(
            "failed-precondition",
            "Payment window has expired"
          );
        }
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
        appointmentType,
        appointmentCollection,
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
                name: data.serviceTitle ||
                  (appointmentType === "pet_hotel"
                    ? "Pet Hotel Booking"
                    : appointmentType === "grooming"
                      ? "Grooming Appointment"
                      : "Vet Appointment"),
                category1: appointmentType === "pet_hotel"
                  ? "Pet Hotel"
                  : appointmentType === "grooming"
                    ? "Grooming"
                    : "Vet",
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

      await db
        .collection(appointmentCollection)
        .doc(appointmentId)
        .set(
          {
            orderId: orderRef.id,
            checkoutToken: result.token,
            conversationId: orderRef.id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

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

exports.createHotelBookingOrder = exports.createAppointmentOrder;


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
