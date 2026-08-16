"use strict";

const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const test = require("node:test");

const { addSocialCommentCore } = require("../src/social/addSocialCommentCore");

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  test("addSocialComment emulator coverage", { skip: "run with the Firestore emulator" }, () => {});
} else {
  if (!admin.apps.length) {
    admin.initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID || "demo-petsupo" });
  }
  const db = admin.firestore();

  async function seedPost(postId, overrides = {}) {
    await db.collection("social_posts").doc(postId).set({
      userId: "owner-uid",
      caption: "hello",
      visibility: "public",
      moderationStatus: "active",
      isHidden: false,
      likeCount: 0,
      commentCount: 0,
      ...overrides,
    });
  }

  async function readPost(postId) {
    const snap = await db.collection("social_posts").doc(postId).get();
    return snap.data();
  }

  test("throws unauthenticated when uid is missing", async () => {
    await assert.rejects(
      () => addSocialCommentCore({ db, uid: null, data: { postId: "x", text: "hi" } }),
      (error) => error.code === "unauthenticated"
    );
  });

  test("throws invalid-argument for a missing postId", async () => {
    await assert.rejects(
      () => addSocialCommentCore({ db, uid: "u1", data: { postId: "", text: "hi" } }),
      (error) => error.code === "invalid-argument"
    );
  });

  test("throws invalid-argument for empty/whitespace-only text", async () => {
    await seedPost("post-empty-text");
    await assert.rejects(
      () =>
        addSocialCommentCore({
          db,
          uid: "u1",
          data: { postId: "post-empty-text", text: "   " },
        }),
      (error) => error.code === "invalid-argument"
    );
  });

  test("throws invalid-argument for oversized text", async () => {
    await seedPost("post-oversized-text");
    await assert.rejects(
      () =>
        addSocialCommentCore({
          db,
          uid: "u1",
          data: { postId: "post-oversized-text", text: "x".repeat(2001) },
        }),
      (error) => error.code === "invalid-argument"
    );
  });

  test("throws failed-precondition for a nonexistent post", async () => {
    await assert.rejects(
      () =>
        addSocialCommentCore({
          db,
          uid: "u1",
          data: { postId: "does-not-exist", text: "hi" },
        }),
      (error) => error.code === "failed-precondition"
    );
  });

  test(
    "a hidden/moderated post and a nonexistent post report the identical " +
      "error (no existence leakage)",
    async () => {
      await seedPost("post-hidden", {
        moderationStatus: "removed",
        isHidden: true,
      });

      const hiddenError = await addSocialCommentCore({
        db,
        uid: "u1",
        data: { postId: "post-hidden", text: "hi" },
      }).catch((error) => error);
      const missingError = await addSocialCommentCore({
        db,
        uid: "u1",
        data: { postId: "does-not-exist-2", text: "hi" },
      }).catch((error) => error);

      assert.equal(hiddenError.code, "failed-precondition");
      assert.equal(missingError.code, "failed-precondition");
      assert.equal(hiddenError.message, missingError.message);

      const post = await readPost("post-hidden");
      assert.equal(post.commentCount, 0);
    }
  );

  test("creates the comment and increments commentCount exactly once", async () => {
    await seedPost("post-valid");
    await db.collection("users").doc("u1").set({ username: "Alice" });

    const result = await addSocialCommentCore({
      db,
      uid: "u1",
      data: { postId: "post-valid", text: "  Nice post!  " },
    });

    assert.ok(result.commentId);
    const commentSnap = await db.collection("post_comments").doc(result.commentId).get();
    assert.equal(commentSnap.data().userId, "u1");
    assert.equal(commentSnap.data().username, "Alice");
    assert.equal(commentSnap.data().postId, "post-valid");
    // Client-supplied text is trimmed server-side, never trusted verbatim.
    assert.equal(commentSnap.data().text, "Nice post!");
    assert.equal(commentSnap.data().moderationStatus, "active");
    assert.equal(commentSnap.data().isHidden, false);

    const post = await readPost("post-valid");
    assert.equal(post.commentCount, 1);
  });

  test("never trusts client-supplied identity fields", async () => {
    await seedPost("post-identity");
    await db.collection("users").doc("u2").set({ username: "RealName" });

    const result = await addSocialCommentCore({
      db,
      uid: "u2",
      data: {
        postId: "post-identity",
        text: "hi",
        userId: "someone-else",
        username: "Forged Name",
        moderationStatus: "pinned",
        isHidden: true,
      },
    });

    const commentSnap = await db.collection("post_comments").doc(result.commentId).get();
    assert.equal(commentSnap.data().userId, "u2");
    assert.equal(commentSnap.data().username, "RealName");
    assert.equal(commentSnap.data().moderationStatus, "active");
    assert.equal(commentSnap.data().isHidden, false);
  });

  test("a retried call with the same requestId is idempotent (no duplicate, no double count)", async () => {
    await seedPost("post-retry");

    const first = await addSocialCommentCore({
      db,
      uid: "u1",
      data: { postId: "post-retry", text: "hello", requestId: "client-req-1" },
    });
    const second = await addSocialCommentCore({
      db,
      uid: "u1",
      data: { postId: "post-retry", text: "hello", requestId: "client-req-1" },
    });

    assert.equal(first.commentId, second.commentId);
    const post = await readPost("post-retry");
    assert.equal(post.commentCount, 1, "the retry must not double-increment");

    const comments = await db
      .collection("post_comments")
      .where("postId", "==", "post-retry")
      .get();
    assert.equal(comments.size, 1);
  });

  test("a new requestId creates a genuinely separate comment", async () => {
    await seedPost("post-two-requests");

    await addSocialCommentCore({
      db,
      uid: "u1",
      data: { postId: "post-two-requests", text: "first", requestId: "req-a" },
    });
    await addSocialCommentCore({
      db,
      uid: "u1",
      data: { postId: "post-two-requests", text: "second", requestId: "req-b" },
    });

    const post = await readPost("post-two-requests");
    assert.equal(post.commentCount, 2);
  });

  test("concurrent comments from different users both count, no lost update", async () => {
    await seedPost("post-concurrent");
    await Promise.all([
      db.collection("users").doc("u1").set({ username: "Alice" }),
      db.collection("users").doc("u2").set({ username: "Bob" }),
    ]);

    await Promise.all([
      addSocialCommentCore({
        db,
        uid: "u1",
        data: { postId: "post-concurrent", text: "from Alice" },
      }),
      addSocialCommentCore({
        db,
        uid: "u2",
        data: { postId: "post-concurrent", text: "from Bob" },
      }),
    ]);

    const post = await readPost("post-concurrent");
    assert.equal(post.commentCount, 2);
  });
}
