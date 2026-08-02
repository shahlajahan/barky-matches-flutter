const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const projectId = "demo-petsupo";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const firestoreBase = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)/documents`;

if (!process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  console.log("public projection rules test skipped: run with the Auth emulator");
  process.exit(0);
}

if (!admin.apps.length) admin.initializeApp({ projectId });
const db = admin.firestore();

async function createAuthUser(label) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=test-key`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        email: `${label}@example.test`,
        password: "Password123!",
        returnSecureToken: true,
      }),
    }
  );
  const body = await response.text();
  assert.equal(response.ok, true, body);
  return JSON.parse(body);
}

function authHeaders(idToken) {
  return idToken ? { Authorization: `Bearer ${idToken}` } : {};
}

async function readDocument(path, idToken) {
  return fetch(`${firestoreBase}/${path}`, {
    headers: authHeaders(idToken),
  });
}

async function updateDocument(path, fields, idToken) {
  return fetch(`${firestoreBase}/${path}`, {
    method: "PATCH",
    headers: { "content-type": "application/json", ...authHeaders(idToken) },
    body: JSON.stringify({
      fields: Object.fromEntries(
        Object.entries(fields).map(([key, value]) => [key, { stringValue: value }])
      ),
    }),
  });
}

async function createDocument(path, fields, idToken) {
  return fetch(`${firestoreBase}/${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", ...authHeaders(idToken) },
    body: JSON.stringify({
      fields: Object.fromEntries(
        Object.entries(fields).map(([key, value]) => [key, { stringValue: value }])
      ),
    }),
  });
}

async function deleteDocument(path, idToken) {
  return fetch(`${firestoreBase}/${path}`, {
    method: "DELETE",
    headers: authHeaders(idToken),
  });
}

async function seed() {
  const [owner, other, adminUser] = await Promise.all([
    createAuthUser("owner"),
    createAuthUser("other"),
    createAuthUser("admin"),
  ]);

  await db.collection("users").doc(owner.localId).set({
    uid: owner.localId,
    username: "owner",
    role: "user",
    savedParks: ["private-park"],
  });
  await db.collection("users").doc(other.localId).set({
    uid: other.localId,
    username: "other",
    role: "user",
  });
  await db.collection("users").doc(adminUser.localId).set({
    uid: adminUser.localId,
    username: "admin",
    role: "admin",
  });

  await db.collection("users_public").doc(owner.localId).set({
    uid: owner.localId,
    username: "owner",
    projectionVersion: 1,
  });
  await db.collection("businesses").doc("business-1").set({
    ownerUid: owner.localId,
    status: "approved",
    published: true,
    payment: { iban: "PRIVATE" },
  });
  await db.collection("businesses_public").doc("business-1").set({
    businessId: "business-1",
    status: "approved",
    published: true,
    profile: { displayName: "Public Business" },
  });
  await db
    .collection("businesses")
    .doc("business-1")
    .collection("services")
    .doc("service-1")
    .set({ name: "Public service" });
  await db.collection("chats").doc("chat-1").set({
    participants: [owner.localId, other.localId],
  });
  await db.collection("business_chats").doc("business-chat-1").set({
    businessId: "business-1",
    clientUserId: other.localId,
  });
  await db.collection("vet_chats").doc("vet-chat-1").set({
    businessId: "business-1",
    clientUserId: other.localId,
  });
  await db.collection("social_posts").doc("post-1").set({
    userId: owner.localId,
    content: "public",
    visibility: "public",
    moderationStatus: "active",
    isHidden: false,
  });

  return { owner, other, adminUser };
}

async function expectStatus(path, token, status, label) {
  const response = await readDocument(path, token);
  assert.equal(response.status, status, `${label}: ${response.status}`);
}

async function main() {
  const { owner, other, adminUser } = await seed();
  const ownerToken = owner.idToken;
  const otherToken = other.idToken;
  const adminToken = adminUser.idToken;

  await expectStatus(`users/${owner.localId}`, ownerToken, 200, "user owner read");
  await expectStatus(`users/${owner.localId}`, otherToken, 403, "user other read");
  await expectStatus(`users/${owner.localId}`, null, 403, "user anonymous read");
  await expectStatus(`users/${owner.localId}`, adminToken, 200, "user admin read");
  const otherUserUpdate = await updateDocument(
    `users/${owner.localId}`,
    { username: "blocked" },
    otherToken
  );
  assert.equal(otherUserUpdate.status, 403, "user other write denied");
  const ownerUserUpdate = await updateDocument(
    `users/${owner.localId}`,
    { username: "owner-updated" },
    ownerToken
  );
  assert.equal(ownerUserUpdate.status, 200, "user owner write");
  const anonymousUserUpdate = await updateDocument(
    `users/${owner.localId}`,
    { username: "blocked" },
    null
  );
  assert.equal(anonymousUserUpdate.status, 403, "user anonymous write denied");
  const adminUserUpdate = await updateDocument(
    `users/${owner.localId}`,
    { uid: owner.localId, username: "admin-updated" },
    adminToken
  );
  assert.equal(adminUserUpdate.status, 200, "user admin write");

  await expectStatus("users_public/unknown", null, 404, "public user missing");
  await expectStatus(`users_public/${owner.localId}`, null, 200, "public user anonymous read");
  const publicUserWrite = await updateDocument(
    `users_public/${owner.localId}`,
    { username: "blocked" },
    ownerToken
  );
  assert.equal(publicUserWrite.status, 403, "public user write denied");
  const adminPublicUserWrite = await updateDocument(
    `users_public/${owner.localId}`,
    { username: "blocked-admin" },
    adminToken
  );
  assert.equal(adminPublicUserWrite.status, 403, "admin public user write denied");

  await expectStatus("businesses/business-1", ownerToken, 200, "business owner read");
  await expectStatus("businesses/business-1", otherToken, 403, "business other read");
  await expectStatus("businesses/business-1", null, 403, "business anonymous read");
  await expectStatus("businesses/business-1", adminToken, 200, "business admin read");
  await expectStatus("businesses_public/business-1", null, 200, "public business anonymous read");
  await expectStatus(
    "businesses/business-1/services/service-1",
    null,
    200,
    "public business service anonymous read"
  );
  const publicBusinessWrite = await updateDocument(
    "businesses_public/business-1",
    { status: "blocked" },
    ownerToken
  );
  assert.equal(publicBusinessWrite.status, 403, "public business write denied");
  const adminPublicBusinessWrite = await updateDocument(
    "businesses_public/business-1",
    { status: "blocked" },
    adminToken
  );
  assert.equal(adminPublicBusinessWrite.status, 403, "admin public business write denied");
  const anonymousBusinessUpdate = await updateDocument(
    "businesses/business-1",
    { ownerUid: owner.localId, status: "approved", published: "true" },
    null
  );
  assert.equal(anonymousBusinessUpdate.status, 403, "business anonymous write denied");

  const otherBusinessUpdate = await updateDocument(
    "businesses/business-1",
    { status: "blocked" },
    otherToken
  );
  assert.equal(otherBusinessUpdate.status, 403, "business other write denied");
  const ownerBusinessUpdate = await updateDocument(
    "businesses/business-1",
    { status: "approved", ownerUid: owner.localId },
    ownerToken
  );
  assert.equal(ownerBusinessUpdate.status, 200, "business owner write");
  const adminBusinessUpdate = await updateDocument(
    "businesses/business-1",
    { ownerUid: owner.localId, status: "approved", published: "true" },
    adminToken
  );
  assert.equal(adminBusinessUpdate.status, 200, "business admin write");

  await expectStatus("chats/chat-1", ownerToken, 200, "chat participant read");
  await expectStatus("chats/chat-1", otherToken, 200, "chat second participant read");
  await expectStatus("chats/chat-1", null, 403, "chat anonymous read");
  const chatMessage = await createDocument(
    "chats/chat-1/messages?documentId=message-1",
    { senderId: owner.localId, text: "hello" },
    ownerToken
  );
  assert.equal(chatMessage.status, 200, "chat participant message create");
  const spoofedMessage = await createDocument(
    "chats/chat-1/messages?documentId=message-2",
    { senderId: adminUser.localId, text: "spoofed" },
    ownerToken
  );
  assert.equal(spoofedMessage.status, 403, "chat sender constraint");
  const chatDelete = await deleteDocument("chats/chat-1", ownerToken);
  assert.equal(chatDelete.status, 403, "chat delete denied");

  await expectStatus("business_chats/business-chat-1", otherToken, 200, "business chat client read");
  await expectStatus("business_chats/business-chat-1", ownerToken, 200, "business chat owner read");
  await expectStatus("business_chats/business-chat-1", adminToken, 200, "business chat admin read");
  await expectStatus("business_chats/business-chat-1", null, 403, "business chat anonymous read");
  const businessChatUpdate = await updateDocument(
    "business_chats/business-chat-1",
    { businessId: "business-1", clientUserId: other.localId },
    otherToken
  );
  assert.equal(businessChatUpdate.status, 200, "business chat client update");
  const businessChatSpoof = await updateDocument(
    "business_chats/business-chat-1",
    { businessId: "business-1", clientUserId: other.localId },
    adminToken
  );
  assert.equal(businessChatSpoof.status, 200, "business chat admin update");
  const businessChatDelete = await deleteDocument("business_chats/business-chat-1", otherToken);
  assert.equal(businessChatDelete.status, 403, "business chat delete denied");

  await expectStatus("vet_chats/vet-chat-1", otherToken, 200, "vet chat client read");
  await expectStatus("vet_chats/vet-chat-1", ownerToken, 200, "vet chat business read");
  await expectStatus("vet_chats/vet-chat-1", adminToken, 200, "vet chat admin read");
  await expectStatus("vet_chats/vet-chat-1", null, 403, "vet chat anonymous read");
  const vetChatUpdate = await updateDocument(
    "vet_chats/vet-chat-1",
    { businessId: "business-1", clientUserId: other.localId },
    otherToken
  );
  assert.equal(vetChatUpdate.status, 200, "vet chat client update");
  const vetChatDelete = await deleteDocument("vet_chats/vet-chat-1", otherToken);
  assert.equal(vetChatDelete.status, 403, "vet chat delete denied");

  await expectStatus("social_posts/post-1", null, 200, "social public read");
  const authorUpdate = await updateDocument("social_posts/post-1", { content: "author" }, ownerToken);
  assert.equal(authorUpdate.status, 200, "social author update");
  const otherUpdate = await updateDocument("social_posts/post-1", { content: "other" }, otherToken);
  assert.equal(otherUpdate.status, 403, "social other update");
  const adminUpdate = await updateDocument(
    "social_posts/post-1",
    { content: "admin", userId: owner.localId },
    adminToken
  );
  assert.equal(adminUpdate.status, 200, "social admin update");
  const authorDelete = await deleteDocument("social_posts/post-1", ownerToken);
  assert.equal(authorDelete.status, 200, "social author delete");
  const secondPost = await createDocument(
    "social_posts?documentId=post-2",
    { userId: owner.localId, content: "admin-delete" },
    ownerToken
  );
  assert.equal(secondPost.status, 200, "social second post create");
  const adminDelete = await deleteDocument("social_posts/post-2", adminToken);
  assert.equal(adminDelete.status, 200, "social admin delete");

  console.log("public projection Firestore authorization tests passed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
