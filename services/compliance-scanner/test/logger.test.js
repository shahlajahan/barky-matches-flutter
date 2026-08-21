"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const { createLogger, nonReversibleCorrelationId, sizeBucket } = require("../src/logger");

function captureSink() {
  const lines = [];
  return {
    lines,
    info: (l) => lines.push(l),
    warn: (l) => lines.push(l),
    error: (l) => lines.push(l),
  };
}

test("only allowlisted fields are ever written to the log line", () => {
  const sink = captureSink();
  const logger = createLogger({ sink });
  logger.info({
    requestId: "req-1",
    verdict: "clean",
    // Everything below must be silently dropped, not merely discouraged.
    objectPath: "compliance_quarantine/biz-1/sess-1/original-filename.pdf",
    rawDocumentBytes: "%PDF-1.4 ...",
    supplierName: "Acme Tedarik A.S.",
    invoiceNumber: "INV-2026-00042",
    firebaseToken: "eyJhbGciOi...",
    signedUrl: "https://storage.googleapis.com/...?X-Goog-Signature=...",
    authorizationHeader: "Bearer secret-token",
    rawScannerResponse: { contractVersion: 1, verdict: "clean" },
    environmentValue: "some-secret-env-value",
  });
  const parsed = JSON.parse(sink.lines[0]);
  assert.equal(parsed.requestId, "req-1");
  assert.equal(parsed.verdict, "clean");
  for (const forbiddenKey of [
    "objectPath",
    "rawDocumentBytes",
    "supplierName",
    "invoiceNumber",
    "firebaseToken",
    "signedUrl",
    "authorizationHeader",
    "rawScannerResponse",
    "environmentValue",
  ]) {
    assert.equal(forbiddenKey in parsed, false, `"${forbiddenKey}" must never appear in a log line`);
  }
});

test("the raw serialized log line never contains sensitive substrings even when passed", () => {
  const sink = captureSink();
  const logger = createLogger({ sink });
  logger.error({
    requestId: "req-2",
    rawScannerResponse: "Bearer super-secret-value-should-never-leak",
    filename: "acme-invoice-confidential.pdf",
  });
  const raw = sink.lines[0];
  assert.equal(raw.includes("super-secret-value-should-never-leak"), false);
  assert.equal(raw.includes("acme-invoice-confidential.pdf"), false);
});

test("nonReversibleCorrelationId never reproduces the original value and is deterministic", () => {
  const original = "compliance_quarantine/biz-1/sess-1/tok.pdf";
  const id = nonReversibleCorrelationId(original);
  assert.equal(typeof id, "string");
  assert.equal(id.includes(original), false);
  assert.equal(id.includes("biz-1"), false);
  assert.equal(nonReversibleCorrelationId(original), id, "must be deterministic for the same input");
});

test("nonReversibleCorrelationId of two different paths never collides in this test's samples", () => {
  const a = nonReversibleCorrelationId("compliance_quarantine/biz-1/sess-1/tok.pdf");
  const b = nonReversibleCorrelationId("compliance_quarantine/biz-2/sess-2/tok.pdf");
  assert.notEqual(a, b);
});

test("sizeBucket coarsens exact byte counts into a small/medium/large label, never logging the exact size", () => {
  assert.equal(sizeBucket(500 * 1024), "small");
  assert.equal(sizeBucket(4 * 1024 * 1024), "medium");
  assert.equal(sizeBucket(14 * 1024 * 1024), "large");
  assert.equal(sizeBucket(undefined), "unknown");
});
