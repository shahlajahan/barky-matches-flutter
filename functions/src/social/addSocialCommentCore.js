const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

const SOCIAL_COMMENT_MAX_LENGTH = 2000;

/**
 * Atomically creates a post_comments document and increments
 * social_posts/{postId}.commentCount, using the Admin SDK (so it is not
 * subject to firestore.rules) inside a single Firestore transaction.
 *
 * post_comments uses auto-generated document IDs, so firestore.rules has
 * no deterministic path it can use to prove a client create is atomically
 * paired with its commentCount increment the way it can for likes
 * (post_likes/{postId}_{uid} is deterministic). This trusted server path
 * is what makes that pairing atomic and safe instead.
 *
 * @param {object} params
 * @param {FirebaseFirestore.Firestore} params.db
 * @param {string|null|undefined} params.uid - request.auth?.uid from the
 *   calling onCall handler; never trust any client-supplied uid/identity.
 * @param {object} params.data - request.data from the calling onCall
 *   handler.
 * @returns {Promise<{commentId: string}>}
 */
async function addSocialCommentCore({ db, uid, data }) {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign-in is required to comment.");
  }

  const postId = String(data?.postId || "").trim();
  if (!postId) {
    throw new HttpsError("invalid-argument", "postId is required.");
  }

  const text = String(data?.text || "").trim();
  if (!text) {
    throw new HttpsError("invalid-argument", "Comment text must not be empty.");
  }
  if (text.length > SOCIAL_COMMENT_MAX_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `Comment text must be at most ${SOCIAL_COMMENT_MAX_LENGTH} characters.`
    );
  }

  // An optional client-generated request id makes retries (e.g. after an
  // ambiguous network response) idempotent: the same requestId always
  // resolves to the same comment document, so a retried call finds the
  // comment it already created instead of creating a second one and
  // double-incrementing commentCount.
  const requestedId = String(data?.requestId || "").trim();
  const postRef = db.collection("social_posts").doc(postId);
  const commentRef = requestedId
    ? db.collection("post_comments").doc(requestedId)
    : db.collection("post_comments").doc();

  // Never trust client-supplied identity fields; resolve display name and
  // photo from the caller's own canonical user document.
  const userSnap = await db.collection("users").doc(uid).get();
  const userData = userSnap.data() || {};
  const username =
    userData.username || userData.name || userData.displayName || "User";
  const userPhotoUrl = userData.photoUrl || userData.profileImageUrl || null;

  return db.runTransaction(async (tx) => {
    const [postSnap, existingCommentSnap] = await Promise.all([
      tx.get(postRef),
      tx.get(commentRef),
    ]);

    if (existingCommentSnap.exists) {
      // Idempotent retry: this exact request already landed.
      return { commentId: commentRef.id };
    }

    // A missing post and an existing-but-private/hidden/moderated post
    // are reported with the exact same error code and message: a caller
    // probing post IDs must not be able to distinguish "never existed"
    // from "exists but you can't see it" (the same existence-privacy
    // guarantee the public social_posts read rule already provides).
    const post = postSnap.exists ? postSnap.data() || {} : null;
    const eligible =
      post != null &&
      post.visibility === "public" &&
      (post.published === undefined || post.published === true) &&
      (post.moderationStatus === undefined ||
        post.moderationStatus === "active") &&
      (post.isHidden === undefined || post.isHidden === false);
    if (!eligible) {
      throw new HttpsError(
        "failed-precondition",
        "This post is not available for comments."
      );
    }

    tx.set(commentRef, {
      postId,
      userId: uid,
      username,
      userPhotoUrl,
      text,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      moderationStatus: "active",
      isHidden: false,
    });
    tx.update(postRef, {
      commentCount: admin.firestore.FieldValue.increment(1),
    });

    return { commentId: commentRef.id };
  });
}

module.exports = { addSocialCommentCore, SOCIAL_COMMENT_MAX_LENGTH };
