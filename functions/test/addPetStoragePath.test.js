"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const addPetPage = fs.readFileSync(
  path.resolve(__dirname, "../../lib/add_dog_page.dart"),
  "utf8"
);
const storageRules = fs.readFileSync(
  path.resolve(__dirname, "../../storage.rules"),
  "utf8"
);

test("Add Pet uses the owner-scoped canonical dogs Storage path", () => {
  assert.match(addPetPage, /'dogs\/\$userId\/\$fileName'/);
  assert.doesNotMatch(addPetPage, /dog_images\/\$userId/);
  assert.match(addPetPage, /ref\.putFile\(file, metadata\)/);
});

test("canonical Add Pet path is covered by owner-restricted media rules", () => {
  const dogsRule = storageRules.match(
    /match \/dogs\/\{ownerUid\}\/\{allPaths=\*\*\} \{([\s\S]*?)\n    \}/
  )?.[1] || "";
  assert.match(dogsRule, /request\.auth\.uid == ownerUid/);
  assert.match(dogsRule, /hasAllowedMedia\(\)/);
});
