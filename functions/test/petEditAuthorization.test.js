"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const appState = fs.readFileSync(
  path.resolve(__dirname, "../../lib/app_state.dart"),
  "utf8"
);
const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);
const storageRules = fs.readFileSync(
  path.resolve(__dirname, "../../storage.rules"),
  "utf8"
);

test("saveEditedDog updates only pet-editable fields", () => {
  const saveBlock = appState.match(
    /final docRef = FirebaseFirestore\.instance[\s\S]*?await docRef\.update\(\{([\s\S]*?)\n      \}\);/
  )?.[1] || "";
  assert.match(saveBlock, /'name':/);
  assert.match(saveBlock, /'isAvailableForAdoption':/);
  assert.doesNotMatch(saveBlock, /'ownerUid':|\b'ownerRole':|\b'centerId':/);
});

test("dog owner rules support ownerUid documents without broadening ownership", () => {
  const dogs = rules.match(/match \/dogs\/\{dogId\} \{([\s\S]*?)\n    \}/)?.[1] || "";
  assert.match(dogs, /data\.ownerId == request\.auth\.uid/);
  assert.match(dogs, /data\.ownerUid == request\.auth\.uid/);
  assert.match(dogs, /affectedKeys\(\)\n\s*\.hasOnly\(\[\s*'name'/);
  assert.doesNotMatch(dogs, /allow update:\s*if isSignedIn\(\)/);
});

test("dog Storage remains owner-path restricted and media validated", () => {
  const dogs = storageRules.match(
    /match \/dogs\/\{ownerUid\}\/\{allPaths=\*\*\} \{([\s\S]*?)\n    \}/
  )?.[1] || "";
  assert.match(dogs, /request\.auth\.uid == ownerUid/);
  assert.match(dogs, /hasAllowedMedia\(\)/);
  assert.match(storageRules, /match \/\{allPaths=\*\*\} \{\s*allow read, write: if false;/);
});
