"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const chatService = fs.readFileSync(
  path.resolve(__dirname, "../../lib/services/chat_service.dart"),
  "utf8"
);

test("ChatService uses a sorted deterministic direct chat id", () => {
  assert.match(chatService, /canonicalDirectChatParticipants/);
  assert.match(chatService, /final ids = \[userA, userB\]\.\.sort\(\)/);
  assert.match(chatService, /join\('_'\)/);
});

test("getOrCreateChat creates before reading the chat document", () => {
  const start = chatService.indexOf("Future<String> getOrCreateChat");
  const end = chatService.indexOf("\n  /// =========================================================\n  /// SEND MESSAGE", start);
  const body = start >= 0 && end > start ? chatService.slice(start, end) : "";
  const createIndex = body.indexOf("chatRef.set");
  const getIndex = body.indexOf("chatRef.get");

  assert.ok(createIndex >= 0, "expected create-first set call");
  assert.ok(getIndex >= 0, "expected fallback existing-chat read");
  assert.ok(createIndex < getIndex, "chatRef.get must not run before create");
});

test("getOrCreateChat verifies authenticated identity and target user", () => {
  assert.match(chatService, /FirebaseAuth\.instance\.currentUser\?\.uid/);
  assert.match(chatService, /authUid == null \|\| authUid != currentUserId/);
  assert.match(chatService, /_verifyTargetUser\(otherUserId\)/);
  assert.match(chatService, /collection\('users_public'\)/);
  assert.match(chatService, /\.doc\(userId\)/);
});
