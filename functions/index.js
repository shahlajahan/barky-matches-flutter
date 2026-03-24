
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
const functions = require("firebase-functions");
const { logger } = require("firebase-functions/v2");

const admin = require("firebase-admin");
const vision = require("@google-cloud/vision");
const nodemailer = require("nodemailer");
const revenue = require("./revenue");
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();
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
/*
const transporter = nodemailer.createTransport({
  host: "email-smtp.us-east-1.amazonaws.com",
  port: 465,
  secure: true,
  auth: {
    user: "AKIARA6ZCM27MC7KCMOG",
    pass: "BPcBuS8YPHJHZcCvtXb/Fc+wsqtBWKBemMeixYYOdXse",
  },
});
*/
const transporter = nodemailer.createTransport({
  host: "email-smtp.us-east-1.amazonaws.com",
  port: 465,
  secure: true,
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

exports.createPlayDateRequest = onCall(
  {
    region: "europe-west3",
    enforceAppCheck: false, // فعلاً debug
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

      const db = admin.firestore();

      /* ----------------------------------------------------
       * 🕒 TIME VALIDATION
       * -------------------------------------------------- */
      const scheduled = new Date(scheduledDateTime);

      if (isNaN(scheduled.getTime())) {
        throw new HttpsError(
          "invalid-argument",
          "Invalid scheduledDateTime format"
        );
      }

      const now = new Date();

      if (scheduled.getTime() < now.getTime() + 15 * 60 * 1000) {
        throw new HttpsError(
          "failed-precondition",
          "Playdate must be at least 15 minutes in the future"
        );
      }

      /* ----------------------------------------------------
       * 1️⃣ CREATE PLAYDATE REQUEST
       * -------------------------------------------------- */
      console.log("📝 About to create Firestore document...");

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
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info("🧾 playDateRequest created", {
        requestId: requestRef.id,
      });

      /* ----------------------------------------------------
       * 2️⃣ CREATE FIRESTORE IN-APP NOTIFICATION
       *    (ANTI-DUPLICATE SAFE)
       * -------------------------------------------------- */
      console.log("🧪 Checking for existing notification...");

      const existingNotification = await db
        .collection("notifications")
        .where("requestId", "==", requestRef.id)
        .where("type", "==", "playdaterequest")
        .limit(1)
        .get();

      if (existingNotification.empty) {
        console.log("🆕 Creating notification...");

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
      } else {
        console.log("⚠️ Notification already exists → skipping creation");
      }

      /* ----------------------------------------------------
       * 3️⃣ SEND PUSH NOTIFICATION (SAFE)
       * -------------------------------------------------- */
      const recipientDoc = await db
        .collection("users")
        .doc(requestedUserId)
        .get();

      const recipientFcmToken =
        recipientDoc.exists
          ? recipientDoc.data()?.fcmToken
          : null;

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
    //secrets: ["SMTP_USER", "SMTP_PASS"],
  },
  async (request, response) => {
    console.log("Executing sendVerificationCode function...");
    if (!request.app) {
      console.error("App Check token missing or invalid");
      return response.status(401).json({ error: "Unauthorized: App Check token is required" });
    }
    const email = request.query.email;
    if (!email) {
      console.error("No email provided in the request");
      return response.status(400).json({ error: "Email is required" });
    }
    const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
    const mailOptions = {
      from: "Barky Matches <shahlajahan1982@gmail.com>",
      to: email,
      subject: "A Big Barky Hello for You! 🐶",
      html: `<p>Hey there, new pal! 🐾</p><p>I'm Max, the coolest pup from the Barky Matches crew! I'm wagging my tail like crazy 'cause you're joining our pack! 😊</p><p>Here is your verificationCode: <strong>${verificationCode}</strong></p><p>Please enter this code in the app to verify your email.</p><p>If you didn't ask to verify this address, you can ignore this email.</p><p>Got questions? Just give a bark (or shoot a message to support)! I can't wait to chase you around the park! 🐕💨</p><p>With tons of tail wags,<br>Max, Chief Happiness Officer at Barky Matches 🐶</p>`,
    };
    try {
      const info = await transporter.sendMail(mailOptions);
      console.log("Email sent:", { response: info.response });
      return response.status(200).json({ verificationCode });
    } catch (error) {
      console.error("Error sending email:", toPlainError(error));
      return response.status(500).json({ error: "Error sending email: " + error.message });
    }
  });



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

      const { type, draft, lat, lng } = request.data || {};

      if (!type || !draft) {
        throw new HttpsError("invalid-argument", "Missing type or draft");
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

      // 🔥 PREVENT DOUBLE REGISTRATION
      const existing = await db
        .collection("businesses")
        .where("ownerUid", "==", uid)
        .limit(1)
        .get();

      if (!existing.empty) {
        throw new HttpsError(
          "already-exists",
          "User already has a business"
        );
      }

      // 🔥 OCR VALIDATION (Turkey only)
      let riskFlags = [];

      if (contact.city && contact.city.toLowerCase() === "istanbul" || true) {
        // Turkey logic (you can improve later via countryCode)

        if (!legal.taxNumber || !legal.mersisNumber) {
          throw new HttpsError(
            "invalid-argument",
            "Tax Number and MERSIS required"
          );
        }

        // Fetch OCR draft
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

        const draftData = draftSnap.data();
        const ocr = draftData?.verification?.ocr;

        if (!ocr) {
          throw new HttpsError(
            "failed-precondition",
            "OCR not completed"
          );
        }

        const ocrTax = ocr.extractedTaxNumber;
        const ocrMersis = ocr.extractedMersisNumber;

        // 🔐 TAX MATCH CHECK
        if (ocrTax !== legal.taxNumber) {
          throw new HttpsError(
            "permission-denied",
            "Tax number mismatch with OCR"
          );
        }

        // 🔐 MERSIS MATCH CHECK
        if (ocrMersis && ocrMersis !== legal.mersisNumber) {
          throw new HttpsError(
            "permission-denied",
            "MERSIS mismatch with OCR"
          );
        }

        // 🔐 STRUCTURE VALIDATION
        if (!legal.mersisNumber.startsWith(legal.taxNumber)) {
          riskFlags.push("mersis_prefix_mismatch");
        }
      }

      const businessDoc = {
        type,
        ownerUid: uid,
        status: "pending",

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

          location: {
            lat: lat,
            lng: lng,
          },
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

      const ref = await db.collection("businesses").add(businessDoc);

      await db.collection("business_requests").add({
        uid,
        businessId: ref.id,
        type,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await db.collection("users").doc(uid).set(
        {
          business: {
            businessId: ref.id,
            status: "pending",
            type,
            isVerified: false,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
        },
        { merge: true }
      );

      return { success: true, businessId: ref.id };
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
      if (!request.auth) throw new HttpsError("unauthenticated", "Login required");

      const adminUid = request.auth.uid;
      const db = admin.firestore();

      // Admin check
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
      if (!reqSnap.exists) throw new HttpsError("not-found", "Request not found");

      const reqData = reqSnap.data() || {};
      const ownerUid = reqData.uid || reqData.ownerId;
      const businessId = reqData.businessId || reqData.centerId; // ✅ backward support

      if (!ownerUid || !businessId) {
        throw new HttpsError("failed-precondition", "Request missing uid/businessId");
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

        // 2️⃣ update business verification
        const newStatus = action; // approved | rejected

        tx.set(
          bizRef,
          {
            status: newStatus,
            statusUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
            statusUpdatedBy: adminUid,

            verification: {
              ...(reqData.verification || {}),
              level: action === "approved" ? "verified" : "basic",
              isVerified: action === "approved",
              verifiedAt:
                action === "approved"
                  ? admin.firestore.FieldValue.serverTimestamp()
                  : null,
              verifiedBy: action === "approved" ? adminUid : null,
            },

            updatedAt: admin.firestore.FieldValue.serverTimestamp(),

            ...(action === "rejected"
              ? {
                rejectionReason: reason || null,
                rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
              }
              : {
                approvedAt: admin.firestore.FieldValue.serverTimestamp(),
              }),
          },
          { merge: true }
        );

        // 3️⃣ 🔥 ADMIN LOG
        const logRef = db.collection("admin_logs").doc();

        tx.set(logRef, {
          entityType: "business",
          entityId: businessId,
          action,
          performedBy: adminUid,
          reason: reason || null,
          metadata: {
            requestId,
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

      });

      // in-app notification
      await db.collection("notifications").add({
        recipientUserId: ownerUid,
        title: action === "approved"
          ? "Your Adoption Center is Approved ✅"
          : "Your Adoption Center was Rejected ❌",
        body: action === "approved"
          ? "You can now manage your center dashboard."
          : (reason || "Please contact support."),
        type: "business_resolution",
        status: action,
        requestId,
        businessId: String(businessId),
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true };
    } catch (err) {
      console.error("resolveBusinessRequest error:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", "BUSINESS_RESOLUTION_FAILED", toPlainError(err));
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