"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
  path.resolve(__dirname, "../index.js"),
  "utf8"
);

test("callback excludes Payten-appended response-only fields from Hash V3", () => {
  const callbackValidator = source.match(
    /function validateIsbankGenericVer3CallbackHash[\s\S]*?function buildIsbankCallbackHashDiagnostics/
  );
  assert.ok(callbackValidator);
  assert.match(
    callbackValidator[0],
    /excludedFieldNames:\s*\["NATIONALIDNO", "EXTRA\.HOSTMSG"\]/
  );
});

test("request hash generation retains the existing unmodified field set", () => {
  const requestHash = source.match(
    /function buildIsbank3DHash[\s\S]*?function escapeIsbankHtmlAttribute/
  );
  assert.ok(requestHash);
  assert.doesNotMatch(requestHash[0], /excludedFieldNames/);
});
