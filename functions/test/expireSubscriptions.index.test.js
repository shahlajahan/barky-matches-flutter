"use strict";

const assert = require("node:assert/strict");
const fs = require("fs");
const path = require("path");
const {test} = require("node:test");

test("expiration query has its minimum subscriptions composite index", () => {
  const indexes = JSON.parse(fs.readFileSync(
    path.join(__dirname, "../../firestore.indexes.json"),
    "utf8"
  ));
  const matches = indexes.indexes.filter((index) =>
    index.collectionGroup === "subscriptions" &&
    index.queryScope === "COLLECTION"
  );

  assert.deepEqual(matches, [{
    collectionGroup: "subscriptions",
    queryScope: "COLLECTION",
    fields: [
      {fieldPath: "status", order: "ASCENDING"},
      {fieldPath: "expiresAt", order: "ASCENDING"},
    ],
  }]);
});
