"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const dart = fs.readFileSync(
  path.resolve(__dirname, "../../lib/user_profile_page.dart"),
  "utf8"
);
const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);

test("EditProfileOverlay checks usernames through the public projection", () => {
  const start = dart.indexOf("final usernameCheck =");
  const end = dart.indexOf("\n\n      if (username.isNotEmpty", start);
  const check = start >= 0 && end > start ? dart.slice(start, end) : "";
  assert.match(check, /collection\('users_public'\)/);
  assert.doesNotMatch(check, /collection\('users'\)/);
});

test("profile save writes only the signed-in user's users document", () => {
  assert.match(
    dart,
    /collection\('users'\)\s*\.doc\(widget\.userId\)\s*\.set\(userData, SetOptions\(merge: true\)\)/
  );
  assert.match(dart, /userId: _currentUserId/);
  assert.match(dart, /_currentUserId = user\.uid/);
});

test("users rules retain owner/admin-only writes and creator protection", () => {
  const usersMatch = rules.match(
    /match \/users\/\{userId\} \{([\s\S]*?)\n    \}/
  );
  assert.ok(usersMatch);
  assert.match(usersMatch[1], /allow update: if \(isOwnUserDoc\(userId\) \|\| isAdmin\(\)/);
  assert.match(usersMatch[1], /affectedKeys\(\)\.hasAny\(\['creator'\]\)/);
});

test("public profile projection remains read-only to clients", () => {
  assert.match(
    rules,
    /match \/users_public\/\{userId\} \{[\s\S]*?allow read: if true;[\s\S]*?allow write: if false;/
  );
});
