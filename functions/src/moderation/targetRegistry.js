const admin = require("firebase-admin");
const { suspendBusinessCore, restoreBusinessCore } = require("./businessSuspension");

/**
 * Single source of truth for "what does approving a report against this
 * target type actually do". Adding a future report target (vet
 * appointments, marketplace products, chat messages, ...) means adding one
 * entry here that reuses the soft-moderation helpers below - never an
 * exhaustive switch statement in createReport/reviewReport.
 *
 * Every action has the signature (db, targetId, ctx) => Promise<void>, where
 * ctx = { adminUid, notes, reportId, createNotification }. Actions never run
 * unless the caller has already been verified as an admin (see adminAuth.js)
 * - this module has no independent authorization of its own.
 */

function softHide(collection) {
  return async (db, targetId, ctx) => {
    await db.collection(collection).doc(targetId).update({
      isHidden: true,
      moderationStatus: "hidden",
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
      moderatedBy: ctx.adminUid,
    });
  };
}

function softRemove(collection) {
  return async (db, targetId, ctx) => {
    await db.collection(collection).doc(targetId).update({
      isHidden: true,
      moderationStatus: "removed",
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
      moderatedBy: ctx.adminUid,
    });
  };
}

function softRestore(collection, extraFields = {}) {
  return async (db, targetId, ctx) => {
    await db.collection(collection).doc(targetId).update({
      isHidden: false,
      moderationStatus: "active",
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
      moderatedBy: ctx.adminUid,
      ...extraFields,
    });
  };
}

async function commentRemove(db, targetId, ctx) {
  const commentRef = db.collection("post_comments").doc(targetId);
  await commentRef.update({
    isHidden: true,
    moderationStatus: "removed",
    moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
    moderatedBy: ctx.adminUid,
  });
}

async function commentRestore(db, targetId, ctx) {
  await db.collection("post_comments").doc(targetId).update({
    isHidden: false,
    moderationStatus: "active",
    moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
    moderatedBy: ctx.adminUid,
  });
}

async function notifyUser(ctx, recipientUserId, payload) {
  if (typeof ctx.createNotification !== "function" || typeof ctx.db !== "object") {
    return;
  }
  await ctx.createNotification(ctx.db, { recipientUserId, ...payload });
}

async function userWarning(db, targetId, ctx) {
  await db.collection("user_moderation_actions").add({
    userId: targetId,
    type: "warning",
    reason: ctx.notes || "",
    moderator: ctx.adminUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: null,
    permanent: false,
    restoredAt: null,
    restoredBy: null,
    reportId: ctx.reportId || null,
  });

  await notifyUser({ ...ctx, db }, targetId, {
    type: "moderation_warning",
    title: "Account warning",
    body:
      ctx.notes ||
      "You have received a warning for violating our community guidelines.",
  });
}

async function userSuspend(db, targetId, ctx) {
  await admin.auth().updateUser(targetId, { disabled: true });

  await db.collection("users").doc(targetId).set(
    {
      accountStatus: "suspended",
      moderationReason: ctx.notes || null,
      moderationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await db.collection("user_moderation_actions").add({
    userId: targetId,
    type: "suspend",
    reason: ctx.notes || "",
    moderator: ctx.adminUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: null,
    permanent: false,
    restoredAt: null,
    restoredBy: null,
    reportId: ctx.reportId || null,
  });

  await notifyUser({ ...ctx, db }, targetId, {
    type: "account_suspended",
    title: "Account suspended",
    body:
      ctx.notes ||
      "Your account has been suspended for violating our community guidelines.",
  });
}

async function userBlock(db, targetId, ctx) {
  await admin.auth().updateUser(targetId, { disabled: true });

  await db.collection("users").doc(targetId).set(
    {
      accountStatus: "blocked",
      moderationReason: ctx.notes || null,
      moderationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  await db.collection("user_moderation_actions").add({
    userId: targetId,
    type: "block",
    reason: ctx.notes || "",
    moderator: ctx.adminUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: null,
    permanent: true,
    restoredAt: null,
    restoredBy: null,
    reportId: ctx.reportId || null,
  });

  await notifyUser({ ...ctx, db }, targetId, {
    type: "account_blocked",
    title: "Account blocked",
    body:
      ctx.notes ||
      "Your account has been blocked for violating our community guidelines.",
  });
}

async function userReactivate(db, targetId, ctx) {
  await admin.auth().updateUser(targetId, { disabled: false });

  await db.collection("users").doc(targetId).set(
    {
      accountStatus: "active",
      moderationReason: null,
      moderationUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // Append restoredAt/restoredBy to the most recent suspend/block record
  // rather than mutating history - the original action stays visible.
  const latest = await db
    .collection("user_moderation_actions")
    .where("userId", "==", targetId)
    .orderBy("createdAt", "desc")
    .limit(1)
    .get();

  if (!latest.empty) {
    await latest.docs[0].ref.update({
      restoredAt: admin.firestore.FieldValue.serverTimestamp(),
      restoredBy: ctx.adminUid,
    });
  }

  await notifyUser({ ...ctx, db }, targetId, {
    type: "account_reactivated",
    title: "Account reactivated",
    body: "Your account has been reactivated.",
  });
}

const TARGET_REGISTRY = {
  dog: {
    collection: "dogs",
    ownerField: "ownerUid",
    actions: {
      hide: softHide("dogs"),
      disable_listing: async (db, targetId, ctx) => {
        await db.collection("dogs").doc(targetId).update({
          isAvailableForAdoption: false,
          moderationStatus: "restricted",
          moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
          moderatedBy: ctx.adminUid,
        });
      },
      restore: softRestore("dogs", { isAvailableForAdoption: true }),
    },
  },
  post: {
    collection: "social_posts",
    ownerField: "userId",
    actions: {
      hide: softHide("social_posts"),
      remove: softRemove("social_posts"),
      restore: softRestore("social_posts"),
    },
  },
  comment: {
    collection: "post_comments",
    ownerField: "userId",
    actions: {
      remove: commentRemove,
      restore: commentRestore,
    },
  },
  business: {
    collection: "businesses",
    ownerField: "ownerUid",
    actions: {
      disable: async (db, targetId, ctx) =>
        suspendBusinessCore(db, targetId, ctx.adminUid, ctx.notes),
      flag: async (db, targetId) => {
        await db.collection("businesses").doc(targetId).update({
          "moderation.status": "flagged",
        });
      },
      restore: async (db, targetId, ctx) =>
        restoreBusinessCore(db, targetId, ctx.adminUid),
    },
  },
  user: {
    collection: "users",
    ownerField: null,
    actions: {
      warning: userWarning,
      suspend: userSuspend,
      block: userBlock,
      restore: userReactivate,
    },
  },
};

module.exports = { TARGET_REGISTRY };
