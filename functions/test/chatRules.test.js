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
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
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

function canonicalChatId(userA, userB) {
  return [userA, userB].sort().join("_");
}

async function env() {
  if (testEnv) return testEnv;

  testEnv = await initializeTestEnvironment({
    projectId: `chat-rules-${Date.now()}`,
    firestore: { rules },
  });

  return testEnv;
}

async function resetSeed() {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", "user-a"), { displayName: "User A" });
    await setDoc(doc(db, "users", "user-b"), { displayName: "User B" });
    await setDoc(doc(db, "users", "user-c"), { displayName: "User C" });
    await setDoc(doc(db, "users_public", "user-a"), { displayName: "User A" });
    await setDoc(doc(db, "users_public", "user-b"), { displayName: "User B" });
    await setDoc(doc(db, "users_public", "user-c"), { displayName: "User C" });
  });
}

function chatCreatePayload(createdBy = "user-a") {
  const participants = ["user-a", "user-b"].sort();
  const chatId = participants.join("_");
  return {
    chatId,
    type: "direct",
    participants,
    participantMap: { "user-a": true, "user-b": true },
    participantNames: { "user-a": "User A", "user-b": "User B" },
    participantPhotos: { "user-a": null, "user-b": null },
    lastMessage: "",
    lastMessageAt: serverTimestamp(),
    lastSenderId: "",
    unreadCount: { "user-a": 0, "user-b": 0 },
    createdBy,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    schemaVersion: 1,
  };
}

async function seedChat() {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "chats", "user-a_user-b"), {
      ...chatCreatePayload("user-a"),
      createdAt: "created",
      updatedAt: "updated",
      lastMessageAt: "last",
    });
  });
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

rulesTest("User A can create a direct chat with User B from Playmate", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("user-a").firestore();
  await assertSucceeds(setDoc(doc(db, "chats", "user-a_user-b"), chatCreatePayload()));
});

rulesTest("legacy Playmate can read a missing canonical chat before creating it", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("user-a").firestore();
  await assertSucceeds(getDoc(doc(db, "chats", "user-a_user-b")));
});

rulesTest("legacy random-id chats can still be created with valid participants", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("user-a").firestore();
  await assertSucceeds(
    addDoc(collection(db, "chats"), {
      participants: ["user-a", "user-b"],
      participantNames: { "user-a": "User A", "user-b": "User B" },
      lastMessage: "",
      lastMessageAt: serverTimestamp(),
      createdAt: serverTimestamp(),
    })
  );
});

rulesTest("User B opening User A resolves to the same canonical chat id", () => {
  assert.equal(canonicalChatId("user-a", "user-b"), "user-a_user-b");
  assert.equal(canonicalChatId("user-b", "user-a"), "user-a_user-b");
});

rulesTest("reopening the same conversation does not create a duplicate", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("user-a").firestore();
  await assertSucceeds(setDoc(doc(db, "chats", "user-a_user-b"), chatCreatePayload()));
  await assertFails(setDoc(doc(db, "chats", "user-b_user-a"), chatCreatePayload()));
});

rulesTest("both participants can read the chat and messages", async () => {
  await resetSeed();
  await seedChat();
  const dbA = (await env()).authenticatedContext("user-a").firestore();
  const dbB = (await env()).authenticatedContext("user-b").firestore();
  await assertSucceeds(getDoc(doc(dbA, "chats", "user-a_user-b")));
  await assertSucceeds(getDoc(doc(dbB, "chats", "user-a_user-b")));
  await assertSucceeds(
    addDoc(collection(dbA, "chats", "user-a_user-b", "messages"), {
      messageId: "message-a",
      chatId: "user-a_user-b",
      senderId: "user-a",
      receiverId: "user-b",
      senderName: "User A",
      text: "hello",
      type: "text",
      createdAt: serverTimestamp(),
      seenBy: { "user-a": true },
    })
  );
  await assertSucceeds(getDocs(collection(dbB, "chats", "user-a_user-b", "messages")));
});

rulesTest("a participant can send only with their own sender id", async () => {
  await resetSeed();
  await seedChat();
  const db = (await env()).authenticatedContext("user-a").firestore();
  await assertSucceeds(
    addDoc(collection(db, "chats", "user-a_user-b", "messages"), {
      messageId: "message-a",
      chatId: "user-a_user-b",
      senderId: "user-a",
      receiverId: "user-b",
      senderName: "User A",
      text: "hello",
      type: "text",
      createdAt: serverTimestamp(),
      seenBy: { "user-a": true },
    })
  );
  await assertFails(
    addDoc(collection(db, "chats", "user-a_user-b", "messages"), {
      messageId: "message-b",
      chatId: "user-a_user-b",
      senderId: "user-b",
      receiverId: "user-a",
      senderName: "User B",
      text: "spoofed",
      type: "text",
      createdAt: serverTimestamp(),
      seenBy: { "user-b": true },
    })
  );
});

rulesTest("User C cannot read or write User A/User B chat or messages", async () => {
  await resetSeed();
  await seedChat();
  const db = (await env()).authenticatedContext("user-c").firestore();
  await assertFails(getDoc(doc(db, "chats", "user-a_user-b")));
  await assertFails(getDocs(collection(db, "chats", "user-a_user-b", "messages")));
  await assertFails(
    addDoc(collection(db, "chats", "user-a_user-b", "messages"), {
      messageId: "message-c",
      chatId: "user-a_user-b",
      senderId: "user-c",
      receiverId: "user-a",
      text: "nope",
      type: "text",
      createdAt: serverTimestamp(),
      seenBy: { "user-c": true },
    })
  );
});

rulesTest("unauthenticated access remains denied", async () => {
  await resetSeed();
  await seedChat();
  const db = (await env()).unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, "chats", "user-a_user-b")));
  await assertFails(getDocs(collection(db, "chats", "user-a_user-b", "messages")));
});

rulesTest("duplicate or malformed participant arrays are denied", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("user-a").firestore();
  await assertFails(
    setDoc(doc(db, "chats", "user-a_user-a"), {
      ...chatCreatePayload(),
      chatId: "user-a_user-a",
      participants: ["user-a", "user-a"],
    })
  );
  await assertFails(
    setDoc(doc(db, "chats", "user-a_user-c"), {
      ...chatCreatePayload(),
      chatId: "user-a_user-c",
      participants: ["user-a", "user-b", "user-c"],
    })
  );
});

rulesTest("a user cannot remove or replace the other participant", async () => {
  await resetSeed();
  await seedChat();
  const db = (await env()).authenticatedContext("user-a").firestore();
  await assertFails(updateDoc(doc(db, "chats", "user-a_user-b"), {
    participants: ["user-a", "user-c"],
  }));
});

rulesTest("existing legacy participant-array chats continue to open", async () => {
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "chats", "legacy-random-id"), {
      participants: ["user-a", "user-b"],
    });
  });
  const db = rulesEnv.authenticatedContext("user-a").firestore();
  await assertSucceeds(getDoc(doc(db, "chats", "legacy-random-id")));
  await assertSucceeds(
    getDocs(query(collection(db, "chats"), where("participants", "array-contains", "user-a")))
  );
});
