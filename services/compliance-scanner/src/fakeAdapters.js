"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// service, test-only fake adapters (Slice 2.1, part F). Mirrors the
// same test-fake convention already established in functions/src/
// marketplace/compliance/complianceScanner.js: deterministic, no real
// network/socket/GCS access, imported only by test files — never by
// server.js's production wiring or index.js's real entrypoint.

function createFakeGcsReader({ content, error } = {}) {
  return {
    calls: [],
    async downloadGenerationPinned(request) {
      this.calls.push(request);
      if (error) throw error;
      return content;
    },
  };
}

function createFakeClamdScanner({ outcome = "clean", signatureName, message, reachable = true } = {}) {
  return {
    calls: [],
    async scanBuffer(buffer) {
      this.calls.push(buffer);
      return { outcome, signatureName, message };
    },
    async ping() {
      return reachable;
    },
  };
}

module.exports = { createFakeGcsReader, createFakeClamdScanner };
