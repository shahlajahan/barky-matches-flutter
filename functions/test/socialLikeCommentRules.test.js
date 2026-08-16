"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} = require("firebase/firestore");

const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let testEnv;

function rulesTest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

async function env() {
  if (testEnv) return testEnv;

  testEnv = await initializeTestEnvironment({
    projectId: `social-like-comment-rules-${Date.now()}`,
    firestore: { rules },
  });

  return testEnv;
}

const OWNER = "owner-uid";
const OTHER = "other-uid";
const THIRD = "third-uid";
const ADMIN = "admin-uid";

async function seed() {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", ADMIN), { role: "admin" });
    await setDoc(doc(db, "social_posts", "post-1"), {
      userId: OWNER,
      caption: "hello",
      visibility: "public",
      moderationStatus: "active",
      isHidden: false,
      likeCount: 0,
      commentCount: 0,
    });
    // Moderated/removed post: eligible for neither a like nor a comment.
    await setDoc(doc(db, "social_posts", "post-hidden"), {
      userId: OWNER,
      caption: "hidden",
      visibility: "public",
      moderationStatus: "removed",
      isHidden: true,
      likeCount: 0,
      commentCount: 0,
    });
    // A second eligible post, for cross-post coupling exploit tests.
    await setDoc(doc(db, "social_posts", "post-2"), {
      userId: OWNER,
      caption: "second post",
      visibility: "public",
      moderationStatus: "active",
      isHidden: false,
      likeCount: 0,
      commentCount: 0,
    });
  });
}

function likePayload(uid, postId) {
  return { userId: uid, postId, createdAt: serverTimestamp() };
}

function commentPayload(uid, postId, text) {
  return {
    postId,
    userId: uid,
    username: uid,
    userPhotoUrl: null,
    text,
    createdAt: serverTimestamp(),
    moderationStatus: "active",
    isHidden: false,
  };
}

async function readPost(postId) {
  const rulesEnv = await env();
  let data;
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const snap = await getDoc(doc(context.firestore(), "social_posts", postId));
    data = snap.data();
  });
  return data;
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

// ─────────────────────────── LIKE: positive ───────────────────────────

rulesTest("authenticated user can like an eligible visible post", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();

  const batch = writeBatch(db);
  batch.set(doc(db, "post_likes", `post-1_${OTHER}`), likePayload(OTHER, "post-1"));
  batch.update(doc(db, "social_posts", "post-1"), { likeCount: increment(1) });
  await assertSucceeds(batch.commit());

  assert.equal((await readPost("post-1")).likeCount, 1);
});

rulesTest("the same user can unlike their own like, returning to canonical state", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  const likeRef = doc(db, "post_likes", `post-1_${OTHER}`);
  const postRef = doc(db, "social_posts", "post-1");

  const likeBatch = writeBatch(db);
  likeBatch.set(likeRef, likePayload(OTHER, "post-1"));
  likeBatch.update(postRef, { likeCount: increment(1) });
  await assertSucceeds(likeBatch.commit());

  const unlikeBatch = writeBatch(db);
  unlikeBatch.delete(likeRef);
  unlikeBatch.update(postRef, { likeCount: increment(-1) });
  await assertSucceeds(unlikeBatch.commit());

  assert.equal((await readPost("post-1")).likeCount, 0);
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const likeSnap = await getDoc(doc(context.firestore(), "post_likes", `post-1_${OTHER}`));
    assert.equal(likeSnap.exists(), false);
  });
});

rulesTest("multiple different users can like the same post safely", async () => {
  await seed();
  const dbOther = (await env()).authenticatedContext(OTHER).firestore();
  const dbThird = (await env()).authenticatedContext(THIRD).firestore();

  const b1 = writeBatch(dbOther);
  b1.set(doc(dbOther, "post_likes", `post-1_${OTHER}`), likePayload(OTHER, "post-1"));
  b1.update(doc(dbOther, "social_posts", "post-1"), { likeCount: increment(1) });
  await assertSucceeds(b1.commit());

  const b2 = writeBatch(dbThird);
  b2.set(doc(dbThird, "post_likes", `post-1_${THIRD}`), likePayload(THIRD, "post-1"));
  b2.update(doc(dbThird, "social_posts", "post-1"), { likeCount: increment(1) });
  await assertSucceeds(b2.commit());

  assert.equal((await readPost("post-1")).likeCount, 2);
});

rulesTest("toggling like twice is idempotent: same net state as never liking", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  const likeRef = doc(db, "post_likes", `post-1_${OTHER}`);
  const postRef = doc(db, "social_posts", "post-1");

  for (let i = 0; i < 2; i += 1) {
    const likeBatch = writeBatch(db);
    likeBatch.set(likeRef, likePayload(OTHER, "post-1"));
    likeBatch.update(postRef, { likeCount: increment(1) });
    await assertSucceeds(likeBatch.commit());

    const unlikeBatch = writeBatch(db);
    unlikeBatch.delete(likeRef);
    unlikeBatch.update(postRef, { likeCount: increment(-1) });
    await assertSucceeds(unlikeBatch.commit());
  }

  assert.equal((await readPost("post-1")).likeCount, 0);
});

// ─────────────────────────── LIKE: negative ───────────────────────────

rulesTest("guest cannot like", async () => {
  await seed();
  const db = (await env()).unauthenticatedContext().firestore();
  await assertFails(setDoc(doc(db, "post_likes", `post-1_${OTHER}`), likePayload(OTHER, "post-1")));
});

rulesTest("user cannot create a like under another uid", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(setDoc(doc(db, "post_likes", `post-1_${THIRD}`), likePayload(THIRD, "post-1")));
});

rulesTest("user cannot delete another user's like", async () => {
  await seed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "post_likes", `post-1_${OTHER}`), likePayload(OTHER, "post-1"));
  });
  const dbThird = rulesEnv.authenticatedContext(THIRD).firestore();
  await assertFails(deleteDoc(doc(dbThird, "post_likes", `post-1_${OTHER}`)));
});

rulesTest("user cannot arbitrarily set likeCount to any value", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(updateDoc(doc(db, "social_posts", "post-1"), { likeCount: 99999 }));
});

rulesTest("user cannot modify unrelated post fields through a like operation", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(
    updateDoc(doc(db, "social_posts", "post-1"), { likeCount: increment(1), caption: "hacked" })
  );
});

rulesTest("user cannot like a deleted/inaccessible post", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(
    setDoc(doc(db, "post_likes", `post-hidden_${OTHER}`), likePayload(OTHER, "post-hidden"))
  );
});

rulesTest("malformed/missing post id is rejected", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(
    setDoc(doc(db, "post_likes", `missing-post_${OTHER}`), likePayload(OTHER, "missing-post"))
  );
});

rulesTest("like document id must match postId_uid (prevents duplicate-like inflation)", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(setDoc(doc(db, "post_likes", "random-id"), likePayload(OTHER, "post-1")));
});

rulesTest("client cannot forge a like notification to an arbitrary recipient", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(
    setDoc(doc(db, "notifications", "forged-like-1"), {
      userId: OWNER,
      recipientUserId: OWNER,
      type: "post_liked",
      title: "forged",
    })
  );
});

// ────────────────────────── COMMENT: positive ──────────────────────────
//
// Comments are callable-only (see the architectural comment above
// post_comments.create in firestore.rules and section B below): there is
// no direct-write path left for the Rules emulator to exercise a genuine
// create/count-increment/concurrency-safe positive case against. That
// coverage — successful creation, commentCount incrementing exactly once,
// and concurrent calls not losing updates — lives in
// functions/test/addSocialComment.test.js against the real transactional
// callable instead.

rulesTest(
  "comment author cannot delete their own comment directly (no client " +
    "delete path exists while commentCount has no compensating decrement)",
  async () => {
    await seed();
    const rulesEnv = await env();
    let commentId;
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const ref = doc(collection(context.firestore(), "post_comments"));
      commentId = ref.id;
      await setDoc(ref, commentPayload(OTHER, "post-1", "hi"));
    });
    const db = rulesEnv.authenticatedContext(OTHER).firestore();
    await assertFails(deleteDoc(doc(db, "post_comments", commentId)));
  }
);

// ────────────────────────── COMMENT: negative ──────────────────────────

rulesTest("guest cannot comment", async () => {
  await seed();
  const db = (await env()).unauthenticatedContext().firestore();
  await assertFails(
    setDoc(doc(collection(db, "post_comments")), commentPayload(OTHER, "post-1", "hi"))
  );
});

rulesTest("user cannot create a comment attributed to another uid", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(
    setDoc(doc(collection(db, "post_comments")), commentPayload(THIRD, "post-1", "hi"))
  );
});

rulesTest("empty/whitespace-only content is rejected", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(
    setDoc(doc(collection(db, "post_comments")), commentPayload(OTHER, "post-1", "   "))
  );
});

rulesTest("oversized content is rejected", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(
    setDoc(
      doc(collection(db, "post_comments")),
      commentPayload(OTHER, "post-1", "x".repeat(2001))
    )
  );
});

rulesTest("comments are immutable; no client update is ever allowed", async () => {
  await seed();
  const rulesEnv = await env();
  let commentId;
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const ref = doc(collection(context.firestore(), "post_comments"));
    commentId = ref.id;
    await setDoc(ref, commentPayload(OTHER, "post-1", "hi"));
  });
  const db = rulesEnv.authenticatedContext(OTHER).firestore();
  await assertFails(updateDoc(doc(db, "post_comments", commentId), { text: "edited" }));
});

rulesTest("user cannot edit/delete another user's comment", async () => {
  await seed();
  const rulesEnv = await env();
  let commentId;
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const ref = doc(collection(context.firestore(), "post_comments"));
    commentId = ref.id;
    await setDoc(ref, commentPayload(OTHER, "post-1", "hi"));
  });
  const dbThird = rulesEnv.authenticatedContext(THIRD).firestore();
  await assertFails(deleteDoc(doc(dbThird, "post_comments", commentId)));
});

rulesTest("admin can moderate-delete any comment", async () => {
  await seed();
  const rulesEnv = await env();
  let commentId;
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const ref = doc(collection(context.firestore(), "post_comments"));
    commentId = ref.id;
    await setDoc(ref, commentPayload(OTHER, "post-1", "hi"));
  });
  const dbAdmin = rulesEnv.authenticatedContext(ADMIN).firestore();
  await assertSucceeds(deleteDoc(doc(dbAdmin, "post_comments", commentId)));
});

rulesTest("user cannot arbitrarily set commentCount", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(updateDoc(doc(db, "social_posts", "post-1"), { commentCount: 99999 }));
});

rulesTest("user cannot comment on a deleted/inaccessible post", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(
    setDoc(doc(collection(db, "post_comments")), commentPayload(OTHER, "post-hidden", "hi"))
  );
});

rulesTest("user cannot inject moderation/admin/server-owned fields on create", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(
    setDoc(doc(collection(db, "post_comments")), {
      ...commentPayload(OTHER, "post-1", "hi"),
      moderatedBy: "self-forged-admin",
    })
  );
});

rulesTest("client cannot forge a comment notification to an arbitrary recipient", async () => {
  await seed();
  const db = (await env()).authenticatedContext(OTHER).firestore();
  await assertFails(
    setDoc(doc(db, "notifications", "forged-comment-1"), {
      userId: OWNER,
      recipientUserId: OWNER,
      type: "post_commented",
      title: "forged",
    })
  );
});

// ═════════════════════════════════════════════════════════════════════
// COUNTER-FORGERY EXPLOIT TESTS
//
// A ±1-bounded, changed-keys-only rule on social_posts.likeCount/
// commentCount is NOT sufficient on its own: it bounds the size of each
// write but says nothing about whether that write corresponds to a real
// post_likes/post_comments mutation. A malicious authenticated user could
// otherwise call `postRef.update({likeCount: increment(1)})` standalone,
// repeatedly, with no post_likes document ever created. These tests prove
// that can no longer happen: every counter transition must be atomically
// paired (in the same write/commit) with the real membership change it
// claims to represent, and commentCount can never be written by a client
// at all (comment creation is a trusted callable — see addSocialComment
// in functions/index.js).
// ═════════════════════════════════════════════════════════════════════

// ── A. Like counter forgery ──────────────────────────────────────────

rulesTest(
  "[A1] standalone likeCount +1 with no paired post_likes document is denied",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    await assertFails(
      updateDoc(doc(db, "social_posts", "post-1"), { likeCount: increment(1) })
    );
  }
);

rulesTest(
  "[A2] repeating the standalone likeCount +1 forgery is denied every time",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    for (let i = 0; i < 3; i += 1) {
      await assertFails(
        updateDoc(doc(db, "social_posts", "post-1"), {
          likeCount: increment(1),
        })
      );
    }
    const post = await readPost("post-1");
    assert.equal(post.likeCount, 0, "forged attempts must never move the counter");
  }
);

rulesTest(
  "[A3] standalone likeCount -1 without deleting the caller's like document is denied",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    // Establish one genuine like first.
    const genuineBatch = writeBatch(db);
    genuineBatch.set(
      doc(db, "post_likes", `post-1_${OTHER}`),
      likePayload(OTHER, "post-1")
    );
    genuineBatch.update(doc(db, "social_posts", "post-1"), {
      likeCount: increment(1),
    });
    await assertSucceeds(genuineBatch.commit());

    // Now attempt a standalone decrement that leaves the like document in
    // place — no paired deletion in the same write.
    await assertFails(
      updateDoc(doc(db, "social_posts", "post-1"), { likeCount: increment(-1) })
    );
    const post = await readPost("post-1");
    assert.equal(post.likeCount, 1, "the unpaired decrement must not apply");
  }
);

rulesTest(
  "[A4] creating a like document without the paired parent counter mutation is denied",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    // Atomic pairing is the canonical contract: standalone membership-only
    // creation (no counter change in the same write) is also rejected, not
    // just standalone counter-only writes.
    await assertFails(
      setDoc(doc(db, "post_likes", `post-1_${OTHER}`), likePayload(OTHER, "post-1"))
    );
  }
);

rulesTest(
  "[A5] a mismatched like-document id cannot be paired with a genuine counter update to inflate the count",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    const batch = writeBatch(db);
    // Well-formed pairing (create + matching +1) but under the WRONG,
    // attacker-chosen document id instead of the deterministic
    // "{postId}_{uid}" identity.
    batch.set(doc(db, "post_likes", "attacker-chosen-id"), likePayload(OTHER, "post-1"));
    batch.update(doc(db, "social_posts", "post-1"), { likeCount: increment(1) });
    await assertFails(batch.commit());
    const post = await readPost("post-1");
    assert.equal(post.likeCount, 0);
  }
);

rulesTest(
  "[A6] after one genuine like, a second standalone +1 forgery is denied",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    const genuineBatch = writeBatch(db);
    genuineBatch.set(
      doc(db, "post_likes", `post-1_${OTHER}`),
      likePayload(OTHER, "post-1")
    );
    genuineBatch.update(doc(db, "social_posts", "post-1"), {
      likeCount: increment(1),
    });
    await assertSucceeds(genuineBatch.commit());

    // The like document already exists (before == after, unchanged), so
    // this second, unpaired +1 attempt must be denied.
    await assertFails(
      updateDoc(doc(db, "social_posts", "post-1"), { likeCount: increment(1) })
    );
    const post = await readPost("post-1");
    assert.equal(post.likeCount, 1, "only the one genuine like should count");
  }
);

// ── B. Comment counter forgery ───────────────────────────────────────

rulesTest(
  "[B7] standalone commentCount +1 with no created comment is denied",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    await assertFails(
      updateDoc(doc(db, "social_posts", "post-1"), { commentCount: increment(1) })
    );
  }
);

rulesTest(
  "[B8] repeating the standalone commentCount +1 forgery is denied every time",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    for (let i = 0; i < 3; i += 1) {
      await assertFails(
        updateDoc(doc(db, "social_posts", "post-1"), {
          commentCount: increment(1),
        })
      );
    }
    const post = await readPost("post-1");
    assert.equal(post.commentCount, 0);
  }
);

rulesTest(
  "[B9] standalone commentCount -1 without a corresponding authorized deletion is denied",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    await assertFails(
      updateDoc(doc(db, "social_posts", "post-1"), { commentCount: increment(-1) })
    );
  }
);

rulesTest(
  "[B10] direct client comment creation is denied regardless of payload — comments are callable-only",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    const batch = writeBatch(db);
    batch.set(
      doc(collection(db, "post_comments")),
      commentPayload(OTHER, "post-1", "a well-formed comment")
    );
    batch.update(doc(db, "social_posts", "post-1"), { commentCount: increment(1) });
    await assertFails(batch.commit());
    const post = await readPost("post-1");
    assert.equal(post.commentCount, 0);
  }
);

rulesTest(
  "[B11] an invalid (oversized) direct comment paired with a valid-looking +1 is denied wholesale",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    const batch = writeBatch(db);
    batch.set(
      doc(collection(db, "post_comments")),
      commentPayload(OTHER, "post-1", "x".repeat(2001))
    );
    batch.update(doc(db, "social_posts", "post-1"), { commentCount: increment(1) });
    await assertFails(batch.commit());
  }
);

// ── C. Cross-user / cross-post coupling ──────────────────────────────

rulesTest(
  "[C12] creating a like for post-1 while incrementing post-2's likeCount is denied",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, "post_likes", `post-1_${OTHER}`), likePayload(OTHER, "post-1"));
    batch.update(doc(db, "social_posts", "post-2"), { likeCount: increment(1) });
    await assertFails(batch.commit());
    const post1 = await readPost("post-1");
    const post2 = await readPost("post-2");
    assert.equal(post1.likeCount, 0);
    assert.equal(post2.likeCount, 0);
  }
);

rulesTest(
  "[C13] creating a comment for post-1 while incrementing post-2's commentCount is denied",
  async () => {
    await seed();
    const db = (await env()).authenticatedContext(OTHER).firestore();
    const batch = writeBatch(db);
    batch.set(
      doc(collection(db, "post_comments")),
      commentPayload(OTHER, "post-1", "cross post")
    );
    batch.update(doc(db, "social_posts", "post-2"), { commentCount: increment(1) });
    await assertFails(batch.commit());
  }
);

rulesTest(
  "[C14] deleting another user's like while decrementing the counter is denied",
  async () => {
    await seed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "post_likes", `post-1_${OTHER}`),
        likePayload(OTHER, "post-1")
      );
      await updateDoc(doc(context.firestore(), "social_posts", "post-1"), {
        likeCount: 1,
      });
    });
    const dbThird = rulesEnv.authenticatedContext(THIRD).firestore();
    const batch = writeBatch(dbThird);
    batch.delete(doc(dbThird, "post_likes", `post-1_${OTHER}`));
    batch.update(doc(dbThird, "social_posts", "post-1"), {
      likeCount: increment(-1),
    });
    await assertFails(batch.commit());
    const post = await readPost("post-1");
    assert.equal(post.likeCount, 1, "the like must survive the denied attempt");
  }
);

rulesTest(
  "[C15] deleting another user's comment while decrementing the counter is denied",
  async () => {
    await seed();
    const rulesEnv = await env();
    let commentId;
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const ref = doc(collection(context.firestore(), "post_comments"));
      commentId = ref.id;
      await setDoc(ref, commentPayload(OTHER, "post-1", "hi"));
      await updateDoc(doc(context.firestore(), "social_posts", "post-1"), {
        commentCount: 1,
      });
    });
    const dbThird = rulesEnv.authenticatedContext(THIRD).firestore();
    const batch = writeBatch(dbThird);
    batch.delete(doc(dbThird, "post_comments", commentId));
    batch.update(doc(dbThird, "social_posts", "post-1"), {
      commentCount: increment(-1),
    });
    await assertFails(batch.commit());
    const post = await readPost("post-1");
    assert.equal(post.commentCount, 1);
  }
);
