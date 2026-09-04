"use strict";

// P1-A Slice 2 — Storage Rules tests for compliance_quarantine/ (docs/
// plans/marketplace_p1a_compliance_review_implementation_plan_2026-08-21
// .md, security decision). This rule calls firestore.get() twice
// (isBusinessOwner() and complianceUploadSessionData()), so — per the P0
// gap review's root-caused fix (marketplaceProductStorageRules.test.js)
// — the test projectId must be derived from GCLOUD_PROJECT (set by
// `emulators:exec --project`), not a per-run random suffix, or the
// cross-service Firestore lookup resolves against the wrong
// --single_project_mode-locked project.
//
// Every test uses its own unique sessionId/object path rather than
// relying on clearStorage()/clearFirestore() between tests: investigated
// and confirmed during this pass that @firebase/rules-unit-testing's
// clearStorage() (a plain root listAll() + delete of `items` only) does
// not reliably reach objects nested several path segments deep from the
// bucket root, so a shared "sess-1" path reused test-to-test can — one
// test in twenty, order-dependent — see a stale prior test's object
// still present. Uniquing every path removes the dependency on that
// cleanup being perfect, independent of whatever its root cause is.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const { doc, setDoc } = require("firebase/firestore");
const {
  ref,
  uploadBytes,
  uploadBytesResumable,
  getBytes,
  getMetadata,
  deleteObject,
  updateMetadata,
} = require("firebase/storage");

const firestoreRules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);
const storageRules = fs.readFileSync(
  path.resolve(__dirname, "../../storage.rules"),
  "utf8"
);

const hasEmulators = Boolean(
  process.env.FIRESTORE_EMULATOR_HOST && process.env.FIREBASE_STORAGE_EMULATOR_HOST
);
let testEnv;

function rulesTest(name, fn) {
  test(name, { skip: !hasEmulators }, fn);
}

const PROJECT_ID =
  process.env.GCLOUD_PROJECT || `p1a-compliance-quarantine-rules-${Date.now()}`;

async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: firestoreRules },
    storage: { rules: storageRules },
  });
  return testEnv;
}

const NOW_MS = Date.now();
const FUTURE = new Date(NOW_MS + 15 * 60 * 1000);
const PAST = new Date(NOW_MS - 60 * 1000);

let uniqueCounter = 0;
function uniqueId(label) {
  uniqueCounter += 1;
  return `${label}-${NOW_MS}-${uniqueCounter}`;
}

async function seedBusinesses() {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    // Revision 30 §F (Slice 2) — the quarantine write rule now requires the
    // session's recorded generation to equal the live business generation,
    // so both fixture businesses carry one.
    await setDoc(
      doc(db, "businesses", "biz-1"),
      { ownerUid: "seller-1", marketplaceBusinessGenerationId: "gen-biz-1" },
      { merge: true }
    );
    await setDoc(
      doc(db, "businesses", "biz-2"),
      { ownerUid: "seller-2", marketplaceBusinessGenerationId: "gen-biz-2" },
      { merge: true }
    );
    await setDoc(doc(db, "users", "admin-1"), { role: "admin" }, { merge: true });
  });
}

// Every call gets a fresh, never-reused sessionId/objectId pair, so no
// test can ever collide with another test's Storage object regardless of
// clearStorage()'s reliability. `businesses` are seeded once, lazily, on
// first use (idempotent via merge:true) rather than re-seeded per test.
let businessesSeeded = false;
async function seedSession(overrides = {}) {
  if (!businessesSeeded) {
    await seedBusinesses();
    businessesSeeded = true;
  }
  const rulesEnv = await env();
  const sessionId = uniqueId("sess");
  const objectId = overrides.objectId || "tok.pdf";
  const businessId = overrides.businessId !== undefined ? overrides.businessId : "biz-1";
  const base = {
    businessId: "biz-1",
    issuedBy: "seller-1",
    // Matches the seeded live generation for biz-1; tests that need a
    // mismatch override it explicitly.
    marketplaceBusinessGenerationId: "gen-biz-1",
    status: "upload_authorized",
    expiresAt: FUTURE,
    objectPath: `compliance_quarantine/${businessId}/${sessionId}/${objectId}`,
    maxSizeBytes: 15 * 1024 * 1024,
    declaredMimeType: "application/pdf",
    ...overrides,
  };
  delete base.objectId;
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "complianceUploadSessions", sessionId), base);
  });
  return { sessionId, objectId, businessId, ...base };
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

const validPdfBytes = new Uint8Array([0x25, 0x50, 0x44, 0x46, 1, 2, 3, 4]); // "%PDF"

// 10. valid authorized PDF upload succeeds
rulesTest("valid authorized PDF upload succeeds", async () => {
  const session = await seedSession();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertSucceeds(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, {
      contentType: "application/pdf",
    })
  );
});

// 11. valid authorized JPEG succeeds
rulesTest("valid authorized JPEG upload succeeds", async () => {
  const session = await seedSession({ declaredMimeType: "image/jpeg", objectId: "tok.jpg" });
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertSucceeds(
    uploadBytes(ref(storage, session.objectPath), new Uint8Array([0xff, 0xd8, 0xff, 1, 2]), {
      contentType: "image/jpeg",
    })
  );
});

// 12. valid authorized PNG succeeds
rulesTest("valid authorized PNG upload succeeds", async () => {
  const session = await seedSession({ declaredMimeType: "image/png", objectId: "tok.png" });
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertSucceeds(
    uploadBytes(ref(storage, session.objectPath), new Uint8Array([0x89, 0x50, 0x4e, 0x47, 1, 2]), {
      contentType: "image/png",
    })
  );
});

// 13. SVG fails
rulesTest("SVG upload fails", async () => {
  const session = await seedSession({ declaredMimeType: "image/svg+xml", objectId: "tok.svg" });
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(
      ref(storage, session.objectPath),
      new TextEncoder().encode("<svg onload=\"alert(1)\"></svg>"),
      { contentType: "image/svg+xml" }
    )
  );
});

// 14. HTML/XML fails
rulesTest("HTML upload fails", async () => {
  const session = await seedSession();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), new TextEncoder().encode("<html></html>"), {
      contentType: "text/html",
    })
  );
});

rulesTest("XML upload fails", async () => {
  const session = await seedSession();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(
      ref(storage, session.objectPath),
      new TextEncoder().encode("<?xml version=\"1.0\"?><a/>"),
      { contentType: "application/xml" }
    )
  );
});

// 15. WebP/HEIC fails
rulesTest("WebP upload fails", async () => {
  const session = await seedSession({ declaredMimeType: "image/webp", objectId: "tok.webp" });
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, { contentType: "image/webp" })
  );
});

rulesTest("HEIC upload fails", async () => {
  const session = await seedSession({ declaredMimeType: "image/heic", objectId: "tok.heic" });
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, { contentType: "image/heic" })
  );
});

// 16. executable/archive fails
rulesTest("executable (application/x-msdownload) upload fails", async () => {
  const session = await seedSession();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), new Uint8Array([0x4d, 0x5a, 1, 2]), {
      contentType: "application/x-msdownload",
    })
  );
});

rulesTest("archive (application/zip) upload fails", async () => {
  const session = await seedSession();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), new Uint8Array([0x50, 0x4b, 0x03, 0x04]), {
      contentType: "application/zip",
    })
  );
});

// 17. oversized actual upload fails
rulesTest("an upload exceeding the session's maxSizeBytes fails", async () => {
  const session = await seedSession({ maxSizeBytes: 100 });
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), new Uint8Array(200), {
      contentType: "application/pdf",
    })
  );
});

// 18. declared MIME versus session mismatch fails at the Rules layer
// (the deeper Storage-reported-vs-declared check is a finalize-time,
// server-side concern — see complianceUploadPipeline.test.js)
rulesTest("uploading with a contentType different from the session's declaredMimeType fails", async () => {
  const session = await seedSession({ declaredMimeType: "application/pdf" });
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, { contentType: "image/png" })
  );
});

// 19. file extension trick fails
rulesTest("a disguised double extension not matching the allowlist pattern fails", async () => {
  const session = await seedSession({ objectId: "tok.pdf.exe" });
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, { contentType: "application/pdf" })
  );
});

// 20. magic-byte mismatch — NOT enforceable by Storage Rules (Rules
// cannot inspect file bytes); this is the server-side finalize
// pipeline's job, proven in complianceUploadPipeline.test.js. Documented
// here explicitly rather than silently omitted.

// 21. unauthenticated upload fails
rulesTest("unauthenticated upload fails", async () => {
  const session = await seedSession();
  const storage = (await env()).unauthenticatedContext().storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, { contentType: "application/pdf" })
  );
});

// 22. another seller's upload fails
rulesTest("another seller (not the session's issuer) cannot use the session", async () => {
  const session = await seedSession();
  const storage = (await env()).authenticatedContext("seller-2").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, { contentType: "application/pdf" })
  );
});

// 23. another business's upload fails
rulesTest("a session issued for biz-1 cannot be used to upload under biz-2's path", async () => {
  const session = await seedSession(); // businessId: biz-1
  const substitutedPath = session.objectPath.replace("compliance_quarantine/biz-1/", "compliance_quarantine/biz-2/");
  const storage = (await env()).authenticatedContext("seller-2").storage();
  await assertFails(
    uploadBytes(ref(storage, substitutedPath), validPdfBytes, { contentType: "application/pdf" })
  );
});

// 24. wrong session/path/object ID fails
rulesTest("uploading under a sessionId directory with no matching session document fails", async () => {
  await seedSession();
  const noSuchSessionPath = `compliance_quarantine/biz-1/${uniqueId("no-such-session")}/tok.pdf`;
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, noSuchSessionPath), validPdfBytes, { contentType: "application/pdf" })
  );
});

rulesTest("uploading to a different objectId than the session's recorded objectPath fails", async () => {
  const session = await seedSession(); // objectPath recorded with objectId "tok.pdf"
  const substitutedPath = session.objectPath.replace("tok.pdf", "different-token.pdf");
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, substitutedPath), validPdfBytes, { contentType: "application/pdf" })
  );
});

// 25. expired session upload fails
rulesTest("an expired session cannot authorize an upload", async () => {
  const session = await seedSession({ expiresAt: PAST });
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, { contentType: "application/pdf" })
  );
});

// 26. consumed session cannot be reused
rulesTest("a consumed session cannot authorize a second upload", async () => {
  const session = await seedSession({ status: "consumed" });
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, { contentType: "application/pdf" })
  );
});

rulesTest("a session already in 'uploaded' cannot authorize a second upload attempt", async () => {
  const session = await seedSession({ status: "uploaded" });
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, { contentType: "application/pdf" })
  );
});

// 27. overwrite/update fails
rulesTest("overwriting an already-uploaded object at the same path fails", async () => {
  const session = await seedSession();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), session.objectPath), validPdfBytes, {
      contentType: "application/pdf",
    });
  });
  const storage = rulesEnv.authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, { contentType: "application/pdf" })
  );
});

rulesTest("updateMetadata on an existing object fails", async () => {
  const session = await seedSession();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), session.objectPath), validPdfBytes, {
      contentType: "application/pdf",
    });
  });
  const storage = rulesEnv.authenticatedContext("seller-1").storage();
  await assertFails(
    updateMetadata(ref(storage, session.objectPath), { contentType: "application/pdf" })
  );
});

// 28. client read fails
rulesTest("owner client read fails", async () => {
  const session = await seedSession();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), session.objectPath), validPdfBytes, {
      contentType: "application/pdf",
    });
  });
  const storage = rulesEnv.authenticatedContext("seller-1").storage();
  await assertFails(getBytes(ref(storage, session.objectPath)));
});

rulesTest("admin client read fails", async () => {
  const session = await seedSession();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), session.objectPath), validPdfBytes, {
      contentType: "application/pdf",
    });
  });
  const storage = rulesEnv.authenticatedContext("admin-1").storage();
  await assertFails(getBytes(ref(storage, session.objectPath)));
});

// 29. client delete fails (server cleanup is preferred, per the plan)
rulesTest("owner client delete fails", async () => {
  const session = await seedSession();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await uploadBytes(ref(context.storage(), session.objectPath), validPdfBytes, {
      contentType: "application/pdf",
    });
  });
  const storage = rulesEnv.authenticatedContext("seller-1").storage();
  await assertFails(deleteObject(ref(storage, session.objectPath)));
});

// 30. no download token is created or accepted — Storage Rules do not
// themselves generate tokens; this proves the create path succeeds
// without one being required, and complianceUploadPipeline.test.js
// separately proves a present token fails server-side validation.
rulesTest("a valid upload succeeds without any download-token metadata being required", async () => {
  const session = await seedSession();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertSucceeds(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, {
      contentType: "application/pdf",
      // deliberately no customMetadata.firebaseStorageDownloadTokens
    })
  );
});

// compliance_docs/ remains fully denied in Slice 2 — promotion happens
// only via Admin SDK, which bypasses these Rules entirely.
rulesTest("compliance_docs/ remains fully denied to every client in Slice 2", async () => {
  await seedSession();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, `compliance_docs/biz-1/${uniqueId("doc")}/tok.pdf`), validPdfBytes, {
      contentType: "application/pdf",
    })
  );
});

// ---------------------------------------------------------------------
// Slice 2 correction (adversarial review 2026-08-21, finding E) —
// custom-metadata restriction: request.resource.metadata.size() == 0
// ---------------------------------------------------------------------

// J.9 arbitrary Storage metadata rejected
rulesTest("an upload carrying arbitrary custom metadata is rejected", async () => {
  const session = await seedSession();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, {
      contentType: "application/pdf",
      customMetadata: { someRandomClientKey: "anything" },
    })
  );
});

// J.10 firebaseStorageDownloadTokens rejected. Empirically investigated
// during this correction (a throwaway debug harness against a
// permissive allow-all ruleset, since removed): the Firebase JS SDK's
// uploadBytes()/uploadBytesResumable() silently strips a
// customMetadata.firebaseStorageDownloadTokens key client-side before
// the request is even sent — a sibling key in the same object survives,
// but this one specifically never reaches the wire, so it never reaches
// Rules evaluation via this call at all. That SDK-level behavior is not
// itself a security control this system can rely on (a non-SDK client —
// a raw REST/multipart request, or a modified SDK — would not
// necessarily strip it). The actual defense against that case is the
// blanket "any custom metadata at all is denied" rule proven by the
// "arbitrary custom metadata is rejected" test above: since
// firebaseStorageDownloadTokens is just one more key inside the same
// request.resource.metadata map that rule requires to be empty, a raw
// client that DID manage to attach it would be denied by that same
// check. This specific assertion is NOT independently exercised by this
// test suite (the client SDK's own stripping makes it unreachable
// through @firebase/rules-unit-testing's normal upload APIs) — flagged
// here as a known, reasoned-but-unverified gap rather than silently
// assumed covered.
rulesTest("firebaseStorageDownloadTokens is stripped by the client SDK before it ever reaches Storage", async () => {
  const session = await seedSession();
  const rulesEnv = await env();
  const storage = rulesEnv.authenticatedContext("seller-1").storage();
  await assertSucceeds(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, {
      contentType: "application/pdf",
      customMetadata: { firebaseStorageDownloadTokens: "attacker-supplied-token" },
    })
  );
  // withSecurityRulesDisabled()'s callback RETURN VALUE is discarded by
  // this library (a repeatedly-hit gotcha across this whole engagement)
  // — capture the result into an outer variable instead.
  let metadata;
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    metadata = await getMetadata(ref(context.storage(), session.objectPath));
  });
  assert.equal(
    metadata.customMetadata && metadata.customMetadata.firebaseStorageDownloadTokens,
    undefined,
    "the SDK must not have forwarded this key to Storage at all"
  );
});

// permitted minimal metadata (none at all) succeeds — explicit
// complement to the two rejection tests above, proving the rule is not
// simply denying every upload.
rulesTest("an upload with no custom metadata at all succeeds", async () => {
  const session = await seedSession();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertSucceeds(
    uploadBytes(ref(storage, session.objectPath), validPdfBytes, { contentType: "application/pdf" })
  );
});

// J.11 sessionless quarantine upload rejected — same requirement as
// item 17 above ("uploading under a sessionId directory with no
// matching session document fails"), restated explicitly here under its
// Slice 2 correction item number for direct traceability.
rulesTest("a client cannot create a quarantine object with no owning session document (sessionless orphan)", async () => {
  const sessionId = uniqueId("sess-orphan");
  const objectPath = `compliance_quarantine/biz-1/${sessionId}/tok.pdf`;
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytes(ref(storage, objectPath), validPdfBytes, { contentType: "application/pdf" })
  );
});

// resumable upload behavior — the emulator/client SDK does support
// uploadBytesResumable(); a resumable upload is evaluated by the same
// Rules as a plain uploadBytes() create, so it must be equally
// authorized-or-denied.
rulesTest("a resumable upload is authorized exactly like a plain upload", async () => {
  const session = await seedSession();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertSucceeds(
    uploadBytesResumable(ref(storage, session.objectPath), validPdfBytes, {
      contentType: "application/pdf",
    })
  );
});

rulesTest("a resumable upload carrying arbitrary custom metadata is rejected", async () => {
  const session = await seedSession();
  const storage = (await env()).authenticatedContext("seller-1").storage();
  await assertFails(
    uploadBytesResumable(ref(storage, session.objectPath), validPdfBytes, {
      contentType: "application/pdf",
      customMetadata: { someRandomClientKey: "anything" },
    })
  );
});

// --- Marketplace Revision 30 §F (Slice 2) — generation binding ---------
//
// An upload authorized under one business generation must be refused once
// the business has been deleted and recreated under the same id. Rules are
// the enforcement point for the write itself; the server re-verifies again
// before promotion.

rulesTest(
  "an upload whose session generation no longer matches the live business is denied",
  async () => {
    const session = await seedSession({
      marketplaceBusinessGenerationId: "gen-biz-1-OLD",
    });
    const storage = (await env()).authenticatedContext("seller-1").storage();
    await assertFails(
      uploadBytes(ref(storage, session.objectPath), validPdfBytes, {
        contentType: "application/pdf",
      })
    );
  }
);

rulesTest(
  "an upload whose session carries no generation binding at all is denied",
  async () => {
    const session = await seedSession({
      marketplaceBusinessGenerationId: null,
    });
    const storage = (await env()).authenticatedContext("seller-1").storage();
    await assertFails(
      uploadBytes(ref(storage, session.objectPath), validPdfBytes, {
        contentType: "application/pdf",
      })
    );
  }
);

rulesTest(
  "an upload whose session carries an empty generation binding is denied",
  async () => {
    const session = await seedSession({ marketplaceBusinessGenerationId: "" });
    const storage = (await env()).authenticatedContext("seller-1").storage();
    await assertFails(
      uploadBytes(ref(storage, session.objectPath), validPdfBytes, {
        contentType: "application/pdf",
      })
    );
  }
);

rulesTest(
  "an upload is denied once the live business generation changes underneath it",
  async () => {
    const session = await seedSession();
    const rulesEnv = await env();
    // The business is recreated under the same id with a new generation
    // while the session is still otherwise valid and unexpired.
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses", "biz-1"),
        { ownerUid: "seller-1", marketplaceBusinessGenerationId: "gen-biz-1-NEW" },
        { merge: true }
      );
    });
    const storage = rulesEnv.authenticatedContext("seller-1").storage();
    await assertFails(
      uploadBytes(ref(storage, session.objectPath), validPdfBytes, {
        contentType: "application/pdf",
      })
    );
    // Restore the shared fixture for any later test in this file.
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses", "biz-1"),
        { ownerUid: "seller-1", marketplaceBusinessGenerationId: "gen-biz-1" },
        { merge: true }
      );
    });
  }
);
