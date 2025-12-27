// Updated on 2025-10-24 at 13:30 +03 by Grok
const { onRequest, onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

function toPlainError(err) {
  if (!err) return { message: "Unknown error" };
  return {
    message: err.message || String(err),
    code: err.code,
    name: err.name,
    stack: err.stack ? String(err.stack).split("\n").slice(0, 5).join("\n") : undefined,
  };
}

const transporter = nodemailer.createTransport({
  host: "email-smtp.us-east-1.amazonaws.com",
  port: 465,
  secure: true,
  auth: {
    user: "AKIARA6ZCM27MC7KCMOG",
    pass: "BPcBuS8YPHJHZcCvtXb/Fc+wsqtBWKBemMeixYYOdXse",
  },
});

exports.sendVerificationCode = onRequest({ region: "europe-west3" }, async (request, response) => {
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

exports.acceptPlayDateRequest = onCall({ region: "europe-west3" }, async (request) => {
  console.log("Executing acceptPlayDateRequest function...");
  console.log("Request data:", { requestId: request.data.requestId, requesterUserId: request.data.requesterUserId });
  if (!request.app) {
    console.error("App Check validation failed");
    throw new functions.https.HttpsError("failed-precondition", "The function must be called from an App Check verified app.");
  }
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  const { requestId, requesterUserId, requestedUserId, requesterDogName, requestedDogName } = request.data;
  const db = admin.firestore();
  if (!requestId || !requesterUserId || !requestedUserId || !requesterDogName || !requestedDogName) {
    throw new functions.https.HttpsError("invalid-argument", "Request ID, requesterUserId, requestedUserId, requesterDogName, and requestedDogName are required");
  }
  try {
    const requestRef = db.collection("playDateRequests").doc(requestId);
    const requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Request not found");
    }
    const requestData = requestDoc.data();
    const currentUserId = request.auth.uid;
    if (currentUserId !== requesterUserId && currentUserId !== requestedUserId) {
      throw new functions.https.HttpsError("permission-denied", "User not authorized to update this request");
    }
    await requestRef.update({
      status: "accepted",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const scheduledDateTime = requestData.scheduledDateTime.toDate();
    const currentTime = new Date();
    const reminderTime = new Date(scheduledDateTime.getTime() - 2 * 60 * 60 * 1000);
    if (reminderTime > currentTime) {
      await db.collection("scheduled_notifications").add({
        to: requesterUserId,
        title: "Reminder: Upcoming Playdate!",
        body: `You have a playdate with ${requestedDogName} in 2 hours.`,
        scheduledAt: admin.firestore.Timestamp.fromDate(reminderTime),
      });
      await db.collection("scheduled_notifications").add({
        to: requestedUserId,
        title: "Reminder: Upcoming Playdate!",
        body: `You have a playdate with ${requesterDogName} in 2 hours.`,
        scheduledAt: admin.firestore.Timestamp.fromDate(reminderTime),
      });
    } else if (scheduledDateTime < currentTime) {
      await requestRef.delete();
      console.log("Auto-deleted expired accepted request:", requestId);
    }
    console.log("Request accepted successfully for ID:", requestId);
    return { success: true, message: "Request marked as accepted" };
  } catch (error) {
    console.error("Error accepting request:", toPlainError(error));
    throw new functions.https.HttpsError("internal", "Failed to accept request", toPlainError(error));
  }
});

exports.rejectPlayDateRequest = onCall({ region: "europe-west3" }, async (request) => {
  console.log("Executing rejectPlayDateRequest function...");
  console.log("Request data:", { requestId: request.data.requestId, requesterUserId: request.data.requesterUserId });
  if (!request.app) {
    console.error("App Check validation failed");
    throw new functions.https.HttpsError("failed-precondition", "The function must be called from an App Check verified app.");
  }
  if (!request.auth) {
    throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
  }
  const { requestId, requesterUserId, requestedUserId, requesterDogName, requestedDogName } = request.data;
  const db = admin.firestore();
  if (!requestId || !requesterUserId || !requestedUserId || !requesterDogName || !requestedDogName) {
    throw new functions.https.HttpsError("invalid-argument", "Request ID, requesterUserId, requestedUserId, requesterDogName, and requestedDogName are required");
  }
  try {
    const requestRef = db.collection("playDateRequests").doc(requestId);
    const requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      logger.warn("Request not found, skipping update but returning success", { requestId });
      return { success: true, message: "Request not found, no action taken" };
    }
    const requestData = requestDoc.data();
    const currentUserId = request.auth.uid;
    if (currentUserId !== requesterUserId && currentUserId !== requestedUserId) {
      throw new functions.https.HttpsError("permission-denied", "User not authorized to update this request");
    }
    await admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(requestRef);
      if (!doc.exists) {
        throw new functions.https.HttpsError("not-found", "Document not found during transaction");
      }
      transaction.update(requestRef, {
        status: "rejected",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      transaction.delete(requestRef);
    });
    console.log("Request rejected successfully for ID:", requestId);
    return { success: true, message: "Request marked as rejected" };
  } catch (error) {
    console.error("Error rejecting request:", toPlainError(error));
    throw new functions.https.HttpsError("internal", "Failed to reject request", toPlainError(error));
  }
});

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

exports.updatePlayDateRequestStatusV2 = onCall(
  { region: "europe-west3", cors: true },
  async (request) => {
    try {
      const { requestId, status, requesterUserId, requestedUserId } = request.data || {};

      if (!requestId || !status || !requesterUserId || !requestedUserId) {
        logger.error("Missing required fields", { requestId, status, requesterUserId, requestedUserId });
        throw new functions.https.HttpsError("invalid-argument", "Missing required fields.");
      }

      const db = admin.firestore();
      const requestRef = db.collection("playDateRequests").doc(requestId);
      const requestDoc = await requestRef.get();
      if (!requestDoc.exists) {
        logger.error("Request not found", { requestId });
        throw new functions.https.HttpsError("not-found", "Request not found");
      }
      const requestData = requestDoc.data();
      const currentUserId = request.auth?.uid;
      if (!currentUserId || (currentUserId !== requesterUserId && currentUserId !== requestedUserId)) {
        logger.error("User not authorized to update this request", { currentUserId, requesterUserId, requestedUserId });
        throw new functions.https.HttpsError("permission-denied", "User not authorized to update this request");
      }

      let transactionAttempt = 0;
      const maxAttempts = 3;
      while (transactionAttempt < maxAttempts) {
        try {
          await admin.firestore().runTransaction(async (transaction) => {
            const doc = await transaction.get(requestRef);
            if (!doc.exists) {
              throw new functions.https.HttpsError("not-found", "Document not found during transaction");
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
            throw new functions.https.HttpsError("aborted", "Transaction failed after maximum attempts");
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
      throw new functions.https.HttpsError("internal", "Something went wrong.");
    }
  }
);

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

exports.sendDislikeNotification = onCall({ region: "europe-west3" }, async (request) => {
  if (!request.app) {
    throw new functions.https.HttpsError('failed-precondition', 'The function must be called from an App Check verified app.');
  }
  const { dogId, userId } = request.data;
  if (!dogId || !userId) {
    logger.error("Missing required fields", { dogId, userId });
    throw new functions.https.HttpsError('invalid-argument', 'dogId and userId are required');
  }
  console.log('Received dislike notification request', { dogId, userId });

  try {
    const dogDoc = await admin.firestore().collection('dogs').doc(dogId).get();
    if (!dogDoc.exists) {
      logger.error("Dog not found", { dogId });
      throw new functions.https.HttpsError('not-found', 'Dog not found');
    }
    const dogData = dogDoc.data();
    const dogOwnerId = dogData.ownerId;
    const dogName = dogData.name;
    console.log('Dog details', { dogId, dogName, dogOwnerId });

    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      logger.error("User not found", { userId });
      throw new functions.https.HttpsError('not-found', 'User not found');
    }
    const userName = userDoc.data().username || 'User';
    console.log('User details', { userId, userName });

    const ownerDoc = await admin.firestore().collection('users').doc(dogOwnerId).get();
    if (!ownerDoc.exists) {
      logger.error("Owner not found", { dogOwnerId });
      throw new functions.https.HttpsError('not-found', 'Owner not found');
    }
    const ownerFcmToken = ownerDoc.data().fcmToken;
    console.log('Recipient FCM token status', { recipientUserId: dogOwnerId, hasToken: !!ownerFcmToken });

    if (!ownerFcmToken) {
      logger.warn("No FCM token found for owner", { dogOwnerId });
      throw new functions.https.HttpsError('failed-precondition', 'No FCM token found for owner');
    }

    const message = {
      notification: {
        title: 'Dog Disliked',
        body: `${userName} disliked your dog ${dogName}!`,
      },
      token: ownerFcmToken,
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'high_importance_channel',
        },
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
      },
    };
    console.log('Sending FCM payload', message);

    const response = await admin.messaging().send(message);
    console.log('Dislike notification sent successfully', { response });
    return { success: true };
  } catch (error) {
    console.error('Error sending FCM message:', toPlainError(error));
    throw new functions.https.HttpsError('internal', 'Failed to send dislike notification', error.message);
  }
});

exports.sendNotification = onCall({ region: "europe-west3", cors: true }, async (request) => {
  try {
    const { title, body, lostDogId, foundDogId } = request.data;

    logger.info("Received notification request", { title, body, lostDogId, foundDogId });
    if (!title || !body || (!lostDogId && !foundDogId)) {
      logger.error("Missing required fields", { title, body, lostDogId, foundDogId });
      throw new functions.https.HttpsError("invalid-argument", "title, body, and at least one of lostDogId or foundDogId are required.");
    }

    const db = admin.firestore();
    const currentUserId = request.auth?.uid;
    if (!currentUserId) {
      logger.error("User not authenticated", { currentUserId });
      throw new functions.https.HttpsError("unauthenticated", "The function must be called while authenticated.");
    }

    const payload = {
      notification: {
        title: title,
        body: body,
      },
      topic: 'all_users',
      data: {
        type: lostDogId ? 'lost_dog' : 'found_dog',
        ...(lostDogId && { lostDogId: lostDogId.toString() }),
        ...(foundDogId && { foundDogId: foundDogId.toString() }),
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
      },
    };

    logger.info("Sending FCM payload to topic", { payload });
    logger.info("Before sending FCM payload", { adminDefined: typeof admin !== 'undefined', messagingDefined: typeof admin.messaging !== 'undefined' });
    logger.info("Payload validation", { payloadKeys: Object.keys(payload), payloadValues: Object.values(payload) });
    const response = await admin.messaging().send(payload);
    logger.info("FCM response", { response, messageId: response.split('/').pop() });

    await db.collection("notifications").add({
      title: title,
      body: body,
      type: lostDogId ? 'lost_dog' : 'found_dog',
      ...(lostDogId && { lostDogId: lostDogId.toString() }),
      ...(foundDogId && { foundDogId: foundDogId.toString() }),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
      recipientUserId: null,
    });

    logger.info("Notification saved to Firestore", { lostDogId, foundDogId });
    logger.info("Notification sent successfully", { title, body, lostDogId, foundDogId });

    return { success: true, message: "Notification sent successfully" };
  } catch (err) {
    logger.error("sendNotification failed", { message: err.message, stack: err.stack });
    logger.info("Error details", { error: toPlainError(err) });
    throw new functions.https.HttpsError("internal", "Failed to send notification", err.message);
  }
});

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