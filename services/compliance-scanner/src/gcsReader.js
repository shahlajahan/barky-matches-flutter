"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// service, real GCS reader (Slice 2.1, part C). This is the ONLY file
// in this service that requires @google-cloud/storage — every other
// module (contract.js, clamdProtocol.js, scanHandler.js, healthHandler
// .js) is dependency-free or injected, specifically so unit/HTTP tests
// never need `npm install` to have run for this package: they inject
// fakeAdapters.js instead of ever loading this file.
//
// Read-only, generation-pinned, single-bucket by construction: the
// caller (scanHandler.js) always supplies the exact bucket/objectPath/
// generation from an already-validated request; this module does not
// itself decide what is safe to read, only how to read it.

function createRealGcsReader() {
  // Deferred require — keeps this dependency out of any module graph a
  // test might load indirectly.
  const { Storage } = require("@google-cloud/storage");
  const storage = new Storage();

  return {
    async downloadGenerationPinned({ bucket, objectPath, generation }) {
      const file = storage.bucket(bucket).file(objectPath, { generation: Number(generation) });
      const [buffer] = await file.download();
      return buffer;
    },
  };
}

module.exports = { createRealGcsReader };
