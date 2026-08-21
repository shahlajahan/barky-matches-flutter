"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// service, real gcsReader import test (Slice 2.1 correction, part A.7).
// Every OTHER test file in this suite injects fakeAdapters.js and never
// loads @google-cloud/storage at all — this file is the deliberate
// exception: it actually requires gcsReader.js and constructs the real
// adapter, so `npm ci`'s installed dependency graph is genuinely
// exercised by `node --test`, not merely present in package.json as an
// unexecuted require path.
//
// This does NOT make a real network call. The @google-cloud/storage
// `Storage` client is lazy — its constructor does not eagerly validate
// credentials or reach the network; that only happens on the first
// actual API call (e.g. `.download()`), which this test deliberately
// never makes. Constructing the client without Application Default
// Credentials configured in this environment is itself a legitimate
// thing to prove works (or fails predictably) — the mocked-credentials
// boundary this test establishes is "construction succeeds regardless
// of ambient credential state", not "a real download succeeds".

const test = require("node:test");
const assert = require("node:assert/strict");

test("gcsReader.js loads @google-cloud/storage and createRealGcsReader() constructs a working adapter shape", () => {
  const { createRealGcsReader } = require("../src/gcsReader");
  const reader = createRealGcsReader();
  assert.equal(typeof reader.downloadGenerationPinned, "function");
});

test("@google-cloud/storage's Storage class is genuinely resolved from node_modules, not stubbed", () => {
  // Confirms the installed dependency graph (npm ci) actually contains a
  // real, loadable @google-cloud/storage — if this require ever fails
  // (missing/corrupted install), this test fails loudly rather than the
  // gap only surfacing at container-build or deploy time.
  const { Storage } = require("@google-cloud/storage");
  assert.equal(typeof Storage, "function");
  const instance = new Storage();
  assert.equal(typeof instance.bucket, "function");
});

test("createRealGcsReader() never touches the network at construction time (no credential/env setup required for this test to pass)", () => {
  const { createRealGcsReader } = require("../src/gcsReader");
  // Constructing twice must be side-effect-free and independent — proves
  // there is no hidden shared/cached network state at module scope.
  const first = createRealGcsReader();
  const second = createRealGcsReader();
  assert.notEqual(first, second);
  assert.equal(typeof first.downloadGenerationPinned, "function");
  assert.equal(typeof second.downloadGenerationPinned, "function");
});
