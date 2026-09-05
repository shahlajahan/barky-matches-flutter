// Marketplace Revision 34 — direct client-SDK product creation is denied
// unconditionally (`allow create: if false`). Every test below that once
// asserted a SUCCESSFUL client create now asserts denial and is renamed
// "Revision 34 — direct client create denied (superseded: <original>)", so
// each item keeps its identity while its name matches what it proves.
//
// The VALUE contracts those tests encoded — name/price/stock/category/media
// shape, sellerRelationship, productInputRevision, server-owned-field
// rejection — are not lost: they moved into the only remaining create path
// and are proven in functions/test/submitMarketplaceProduct.test.js, which
// enforces an equal-or-stricter contract server-side.
"use strict";

// Marketplace product compliance audit, P0 remediation
// (docs/audits/marketplace_add_product_compliance_audit_2026-08-20.md,
// findings F-01/F-02/F-03/F-07). These tests prove the products rule in
// firestore.rules — not the Flutter form — is the actual security
// boundary: every case here simulates a raw client write that bypasses
// add_product_page.dart entirely.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  setDoc,
  updateDoc,
  deleteDoc,
  deleteField,
  getDoc,
  getDocs,
  collection,
  collectionGroup,
  query,
  where,
  serverTimestamp,
} = require("firebase/firestore");

const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);

// Revision 34 — executable-source view with comments removed.
//
// `rules` is the raw file, so a regex run against it can match prose in a
// comment instead of a live authorization branch. Several Revision 34
// assertions below must prove the ABSENCE of a branch ("no isAdmin() OR can
// restore client create"), and an absence claim is worthless if the retained
// specification comments can satisfy it. `rulesCode` therefore strips block
// and line comments first, so every such assertion reads only clauses the
// Rules engine actually evaluates.
const rulesCode = rules
  .replace(/\/\*[\s\S]*?\*\//g, "")
  .replace(/^[ \t]*\/\/.*$/gm, "")
  .replace(/\/\/.*$/gm, "");

// The single products match block as the engine sees it — used to prove that
// a claim about "the create rule" is a claim about the only one that exists.
const productsRulesBlock = (() => {
  const header = "match /{path=**}/products/{productId}";
  const start = rulesCode.indexOf(header);
  if (start < 0) return "";
  // The header itself contains `{path=**}` and `{productId}`, so the brace
  // scan must begin at the brace that opens the block BODY, past the header.
  let depth = 0;
  for (let i = rulesCode.indexOf("{", start + header.length); i < rulesCode.length; i += 1) {
    if (rulesCode[i] === "{") depth += 1;
    else if (rulesCode[i] === "}") {
      depth -= 1;
      if (depth === 0) return rulesCode.slice(start, i + 1);
    }
  }
  return "";
})();

const hasFirestoreEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
let testEnv;

function rulesTest(name, fn) {
  test(name, { skip: !hasFirestoreEmulator }, fn);
}

// P0 gap review item 6: marketplaceProductStorageRules.test.js needs a
// projectId matching GCLOUD_PROJECT (set by `emulators:exec --project`)
// because its cross-service Storage-to-Firestore firestore.get() calls
// are resolved against the emulator's own --single_project_mode-locked
// project, not whatever project rules-unit-testing creates. This file
// has no cross-service calls (Firestore-only, same-service get()), so
// it keeps its own unique, timestamp-suffixed project instead — sharing
// GCLOUD_PROJECT with the Storage test file would make the two files'
// clearFirestore() calls (they run as separate, potentially concurrent
// node:test files) able to collide with each other's seeded data.
async function env() {
  if (testEnv) return testEnv;
  testEnv = await initializeTestEnvironment({
    projectId: `marketplace-product-rules-${Date.now()}`,
    firestore: { rules },
  });
  return testEnv;
}

// Revision 28 (§10.1 "Product binding, exact") — fixed, non-secret
// stand-in generation-ID values for the two shared fixture businesses.
// Every pre-existing product-create test's own default `safeProduct()`
// payload carries the matching value for `biz-1` (below), so this one
// fixture-level change keeps every pre-existing test's already-expected
// outcome unchanged, exactly mirroring how `media` was defaulted before
// it, rather than requiring an edit at each of this file's own ~190
// `safeProduct()` call sites.
const BIZ_1_GENERATION_ID = "biz-1-generation";
const BIZ_2_GENERATION_ID = "biz-2-generation";

async function resetSeed() {
  const rulesEnv = await env();
  await rulesEnv.clearFirestore();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "businesses", "biz-1"), {
      ownerUid: "seller-1",
      contact: { email: "seller1@example.com" },
      status: "approved",
      published: true,
      // Marketplace P1-A Step 21c2 (docs/plans/marketplace_p1a_
      // compliance_review_implementation_plan_2026-08-21.md §10.1
      // "Marketplace seller-activation gate contract"): every
      // pre-existing test in this file exercises something other than
      // this gate itself, so both shared fixture businesses are seeded
      // pre-activated here — the dedicated SELLER-ACTIVATION-* tests
      // below override this explicitly to exercise the gate's own
      // boundary, exactly mirroring how `media` is defaulted above.
      marketplaceSellerActivation: {
        active: true,
        grantedAt: serverTimestamp(),
        grantedBy: "admin-1",
        revokedAt: null,
        revokedBy: null,
      },
      marketplaceBusinessGenerationId: BIZ_1_GENERATION_ID,
      pilotActiveProductCount: 0,
    });
    await setDoc(doc(db, "businesses", "biz-2"), {
      ownerUid: "seller-2",
      contact: { email: "seller2@example.com" },
      status: "approved",
      published: true,
      marketplaceSellerActivation: {
        active: true,
        grantedAt: serverTimestamp(),
        grantedBy: "admin-1",
        revokedAt: null,
        revokedBy: null,
      },
      marketplaceBusinessGenerationId: BIZ_2_GENERATION_ID,
      pilotActiveProductCount: 0,
    });
    await setDoc(doc(db, "users", "admin-1"), { role: "admin" });
    // Revision 38 §0.36 C — with the public read branch removed, the owner
    // branch is the only non-admin one, so owner reads now evaluate
    // `isAdmin()` first. `isAdmin()` dereferences `get(users/<uid>).data`,
    // which raises a null-value EVALUATION ERROR (not a plain deny) when the
    // user document is absent — and on a `list` that error fails the whole
    // query. Seeding role-less user documents makes the predicate evaluable
    // for these identities; absent a `role` they remain non-admin, so no
    // security property changes.
    await setDoc(doc(db, "users", "seller-1"), {});
    await setDoc(doc(db, "users", "seller-2"), {});
    await setDoc(doc(db, "users", "customer-1"), {});
  });
}

// Revision 34 — TEST FIXTURE SETUP ONLY. Not an authorized client path.
//
// Direct client-SDK product creation is denied unconditionally, so a test
// that needs an EXISTING product in order to exercise a read or update
// contract can no longer arrange one by creating it as the seller. This
// helper writes the fixture with security rules disabled, standing in for
// the trusted server writer (submitMarketplaceProduct, Admin SDK) that
// creates products in production.
//
// It deliberately grants no authority to the authenticated client: every
// operation actually under test is still executed through the normal
// authenticated context, so the subsequent read/update Rules contract is
// genuinely evaluated and a regression in it still fails the test.
async function seedProductAsTrustedServer(productPath, data) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), productPath), data);
  });
}

function safeProduct(overrides = {}) {
  return {
    businessId: "biz-1",
    name: "Test Product",
    price: 10,
    stock: 5,
    // Marketplace Revision 41 §0.39 (Slice 7C): the base fixture previously
    // used "Health > Vitamins", which is no longer a writable category —
    // vitamins are permanently outside the pilot, so the whole Health
    // category was removed from the allowlist. Test 9c below asserts that
    // removal directly; every other test here only needs SOME valid category.
    category: "Food > Dry Food",
    isActive: false,
    moderationStatus: "pending_review",
    // Marketplace P1-A media-cap prerequisite (docs/plans/marketplace_p1a_
    // compliance_review_implementation_plan_2026-08-21.md §10.1/§17 21c):
    // media is now a required, ≤20-length list on every create/resubmission.
    // Defaulting it here (rather than at each of this fixture's ~140 call
    // sites) keeps every pre-existing, unrelated test's already-expected
    // outcome unchanged; the dedicated media-cap tests below override this
    // default explicitly to exercise the boundary itself.
    media: [],
    // Revision 28 (§10.1 "Product binding, exact") — matches `biz-1`'s
    // own seeded value above by default; a test targeting `biz-2`
    // instead already overrides `businessId` and must likewise override
    // this to `BIZ_2_GENERATION_ID`.
    marketplaceBusinessGenerationId: BIZ_1_GENERATION_ID,
    ...overrides,
  };
}

// A single valid, minimal media entry, reused by the media-cap boundary
// tests below to build lists of an exact target length without asserting
// anything about per-entry media schema (§10.1: "No per-entry media schema
// validation... is introduced by this prerequisite").
function mediaEntry(n) {
  return { type: "image", originalUrl: `https://example.test/${n}.jpg` };
}

function mediaList(count) {
  return Array.from({ length: count }, (_, i) => mediaEntry(i));
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

rulesTest(
  "Revision 34 — direct client create denied (superseded: control: a safe, correctly-shaped submission succeeds)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/p1"), safeProduct())
    );
  }
);

rulesTest("1. unauthenticated product creation fails", async () => {
  await resetSeed();
  const db = (await env()).unauthenticatedContext().firestore();
  await assertFails(
    setDoc(doc(db, "businesses/biz-1/products/p1"), safeProduct())
  );
});

rulesTest("2. seller cannot create for another business", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-2").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/p1"),
      safeProduct({ businessId: "biz-1" })
    )
  );
});

rulesTest("3. seller cannot self-approve on create", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/p1"),
      safeProduct({ moderationStatus: "approved" })
    )
  );
});

rulesTest("3b. seller cannot self-approve on update", async () => {
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "businesses/biz-1/products/p1"),
      safeProduct()
    );
  });
  const db = rulesEnv.authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, "businesses/biz-1/products/p1"), {
      moderationStatus: "approved",
    })
  );
});

rulesTest("4. seller cannot publish directly (isActive: true)", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/p1"),
      safeProduct({ isActive: true })
    )
  );
});

rulesTest("5. seller cannot set isActive true on update", async () => {
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "businesses/biz-1/products/p1"),
      safeProduct()
    );
  });
  const db = rulesEnv.authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, "businesses/biz-1/products/p1"), { isActive: true })
  );
});

rulesTest("6. seller cannot submit stock 0", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(doc(db, "businesses/biz-1/products/p1"), safeProduct({ stock: 0 }))
  );
});

rulesTest("7a. seller cannot submit negative stock", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/p1"),
      safeProduct({ stock: -5 })
    )
  );
});

rulesTest("7b. seller cannot submit decimal stock", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/p1"),
      safeProduct({ stock: 3.5 })
    )
  );
});

rulesTest(
  "8. seller cannot modify protected inventory fields (reservedStock)",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/p1"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/p1"), {
        reservedStock: 999,
      })
    );
  }
);

// ---------------------------------------------------------------------
// P0.1 correction (docs/audits/
// marketplace_p1_bulk_compliance_inventory_architecture_2026-08-21.md,
// Revision 3 §6): request.resource.data is always the COMPLETE post-write
// document, not a diff. The original productProtectedKeysUntouched()
// blacklist checked bare key presence on both create and update — correct
// on create, but on update it would reject EVERY subsequent seller edit
// to a product the instant any Admin-SDK writer (functions/src/inventory/
// *) had ever set one of these fields, even an edit that never touched
// the field at all. These tests prove the fix: a server-owned field may
// legitimately exist on the document (set only by Admin SDK, simulated
// here via withSecurityRulesDisabled exactly the way the inventory module
// writes in production) without blocking unrelated seller edits, while
// its value remains fully immutable to any seller write.
// ---------------------------------------------------------------------

const SERVER_OWNED_FIELD_CASES = [
  ["reservedStock", 3, 999],
  ["inventorySchemaVersion", 1, 2],
  ["inventoryOperationVersion", 1, 2],
  ["inventoryUpdatedAt", 1700000000000, 1800000000000],
  ["reviewedBy", "admin-1", "someone-else"],
  ["reviewedAt", 1700000000000, 1800000000000],
  ["rejectionReason", "missing evidence", "changed reason"],
  ["complianceStatus", "under_review", "cleared"],
  // Marketplace P1-A Slice 4.2 (docs/plans/marketplace_p1a_compliance_
  // review_implementation_plan_2026-08-21.md §9/§11, Revision 5 correction
  // 30-33): the five dormant compliance output fields, protected by the
  // exact same generalized mechanism as the fields above — this loop
  // gives them the identical create/change/preserve coverage for free.
  ["complianceEffectiveStatus", "verified_valid", "verified_expiring_soon"],
  ["complianceValidUntil", 1700000000000, 1800000000000],
  ["evidenceRevision", 1, 2],
  ["complianceUpdatedAt", 1700000000000, 1800000000000],
  ["complianceReasonCode", "evidence_missing", "evidence_expired"],
];

const COMPLIANCE_SERVER_OWNED_FIELDS = [
  "complianceEffectiveStatus",
  "complianceValidUntil",
  "evidenceRevision",
  "complianceUpdatedAt",
  "complianceReasonCode",
];

async function seedProductWithServerOwnedField(fieldName, value) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "businesses/biz-1/products/p1"),
      safeProduct({ [fieldName]: value })
    );
  });
}

for (const [fieldName, initialValue, attemptedValue] of SERVER_OWNED_FIELD_CASES) {
  rulesTest(
    `P0.1-4. Admin/system fixture can establish a product containing ${fieldName}`,
    async () => {
      await resetSeed();
      await seedProductWithServerOwnedField(fieldName, initialValue);
      const rulesEnv = await env();
      let snap;
      await rulesEnv.withSecurityRulesDisabled(async (context) => {
        snap = await getDoc(
          doc(context.firestore(), "businesses/biz-1/products/p1")
        );
      });
      assert.equal(snap.data()[fieldName], initialValue);
    }
  );

  rulesTest(
    `P0.1-5/6. seller can perform an otherwise-valid update after ${fieldName} exists`,
    async () => {
      await resetSeed();
      await seedProductWithServerOwnedField(fieldName, initialValue);
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertSucceeds(
        updateDoc(doc(db, "businesses/biz-1/products/p1"), { price: 42 })
      );
    }
  );

  rulesTest(
    `P0.1-7. seller cannot change ${fieldName}`,
    async () => {
      await resetSeed();
      await seedProductWithServerOwnedField(fieldName, initialValue);
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertFails(
        updateDoc(doc(db, "businesses/biz-1/products/p1"), {
          [fieldName]: attemptedValue,
        })
      );
    }
  );

  rulesTest(
    `P0.1-9. seller cannot set ${fieldName} to null`,
    async () => {
      await resetSeed();
      await seedProductWithServerOwnedField(fieldName, initialValue);
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertFails(
        updateDoc(doc(db, "businesses/biz-1/products/p1"), {
          [fieldName]: null,
        })
      );
    }
  );
}

rulesTest(
  "Revision 34 — direct client create denied (superseded: P0.1-1. seller can create a valid P0 product without any server-owned field)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/p1"), safeProduct())
    );
  }
);

rulesTest("P0.1-2. seller cannot create reservedStock", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/p1"),
      safeProduct({ reservedStock: 0 })
    )
  );
});

rulesTest(
  "P0.1-3. seller cannot create inventorySchemaVersion",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/p1"),
        safeProduct({ inventorySchemaVersion: 1 })
      )
    );
  }
);

rulesTest("P0.1-8. seller cannot delete reservedStock", async () => {
  await resetSeed();
  await seedProductWithServerOwnedField("reservedStock", 3);
  const rulesEnv = await env();
  const db = rulesEnv.authenticatedContext("seller-1").firestore();
  // A raw client has no "delete this one field" primitive that isn't
  // itself a set()/update() carrying some value or omitting the key —
  // the only way to attempt removal via the client SDK is a full set()
  // that reconstructs the document without the field. Rules must reject
  // this the same way as any other change to the field's presence/value.
  await assertFails(
    setDoc(doc(db, "businesses/biz-1/products/p1"), safeProduct())
  );
});

rulesTest(
  "P0.1-10. seller cannot change inventorySchemaVersion",
  async () => {
    await resetSeed();
    await seedProductWithServerOwnedField("inventorySchemaVersion", 1);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/p1"), {
        inventorySchemaVersion: 2,
      })
    );
  }
);

rulesTest(
  "P0.1-11. seller cannot remove inventoryUpdatedAt",
  async () => {
    await resetSeed();
    await seedProductWithServerOwnedField("inventoryUpdatedAt", 1700000000000);
    const rulesEnv = await env();
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/p1"), safeProduct())
    );
  }
);

rulesTest(
  "P0.1-12. seller cannot inject an unknown alias such as reserved_quantity",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/p1"),
        safeProduct({ reserved_quantity: 5 })
      )
    );
  }
);

rulesTest("P0.1-13. businessId remains immutable", async () => {
  await resetSeed();
  await seedProductWithServerOwnedField("reservedStock", 3);
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, "businesses/biz-1/products/p1"), {
      businessId: "biz-2",
    })
  );
});

rulesTest(
  "P0.1-14. seller still cannot self-approve/publish once server-owned fields exist",
  async () => {
    await resetSeed();
    await seedProductWithServerOwnedField("reservedStock", 3);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/p1"), {
        isActive: true,
        moderationStatus: "approved",
      })
    );
  }
);

rulesTest(
  "P0.1-15. public read behavior is unchanged once server-owned fields exist",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/p1"),
        safeProduct({
          isActive: true,
          moderationStatus: "approved",
          reservedStock: 3,
        })
      );
    });
    // Marketplace Revision 38 §0.36 B (Slice 7B) — public discovery is now
    // callable-only. An unauthenticated caller can no longer read a product
    // directly merely because it is approved and active; the approved+active
    // pair is persisted state that lags evidence revocation, policy change
    // and generation change (Revision 30 §H's interval). The product is
    // reachable only through `getMarketplaceProductList`/`Detail`/`Batch`,
    // which evaluate live eligibility at request time.
    const db = rulesEnv.unauthenticatedContext().firestore();
    await assertFails(
      getDoc(doc(db, "businesses/biz-1/products/p1"))
    );
  }
);

rulesTest(
  "P0.1-16. a different seller cannot read or write another business's product carrying server-owned fields",
  async () => {
    await resetSeed();
    await seedProductWithServerOwnedField("reservedStock", 3);
    const db = (await env()).authenticatedContext("seller-2").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/p1"), { price: 1 })
    );
  }
);

rulesTest(
  "P0.1-generic. the server-owned-field pattern generalizes, not a special case for one field",
  async () => {
    // Represents the exact future shape (Revision 3 §5/§6): a product
    // already carries a generic server-owned field permitted by the
    // closed document schema; a seller's edit to an allowed seller field
    // succeeds; the same seller's attempt to change the server field
    // fails. Deliberately uses complianceStatus — a field already in
    // serverOwnedProductFields() today but not yet written by any code —
    // as the stand-in, so this proves the general mechanism without
    // adding any speculative P1 field (canonicalProductId, etc.) to the
    // live schema just to exercise this test.
    await resetSeed();
    await seedProductWithServerOwnedField("complianceStatus", "under_review");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/p1"), { stock: 7 })
    );
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/p1"), {
        complianceStatus: "cleared",
      })
    );
  }
);

rulesTest(
  "9. seller cannot submit a veterinary medicinal product category",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/p1"),
        safeProduct({ category: "Health > Medicine" })
      )
    );
  }
);

rulesTest(
  "9b. normalized/whitespace variants of the vet category are also rejected",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/p1"),
        safeProduct({ category: "health>medicine" })
      )
    );
  }
);

// Marketplace Revision 41 §0.39 (Slice 7C) — the merchandising category
// allowlist. Direct client CREATE is denied outright by Revision 34, so the
// allowlist is exercised on the UPDATE path, where it still governs what a
// seller may write. Asserting it on create would pass vacuously.
async function seedProductWithCategory(category) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "businesses/biz-1/products/p1"),
      safeProduct({ category })
    );
  });
}

rulesTest(
  "9c. Revision 41 §0.39 — the removed Health/Vitamins categories are no longer writable",
  async () => {
    await resetSeed();
    await seedProductWithCategory("Food > Dry Food");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    // "Health > Vitamins" WAS an accepted category before this slice. It is
    // removed because vitamins and supplements can never be classified,
    // approved or published, so the write only produced doomed listings.
    for (const category of [
      "Health > Vitamins",
      "Health > Supplements",
      "Health > Medicine",
    ]) {
      await assertFails(
        updateDoc(doc(db, "businesses/biz-1/products/p1"), { category })
      );
    }
  }
);

rulesTest(
  "9d. Revision 41 §0.39 — the six new accessory/litter categories are writable",
  async () => {
    // These exist so the Group B classes and the litter class are
    // describable at all. Being writable confers NO classification and no
    // publication — it is merchandising text only.
    const categories = [
      "Litter > Cat Litter",
      "Accessories > Harness",
      "Accessories > Bowl",
      "Accessories > Bed",
      "Accessories > Carrier",
      "Accessories > Grooming Tool",
    ];
    for (const category of categories) {
      await resetSeed();
      await seedProductWithCategory("Food > Dry Food");
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertSucceeds(
        updateDoc(doc(db, "businesses/biz-1/products/p1"), { category })
      );
    }
  }
);

rulesTest(
  "9e. Revision 41 §0.39 — a writable category still confers no classification",
  async () => {
    await resetSeed();
    await seedProductWithCategory("Food > Dry Food");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    // Describing the product as a harness must not let the seller also
    // claim the class that describes one.
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/p1"), {
        category: "Accessories > Harness",
        pilotProductClass: "collars_harnesses_leashes",
      })
    );
  }
);

rulesTest("10. pending products are not publicly readable", async () => {
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "businesses/biz-1/products/p1"),
      safeProduct()
    );
  });
  const db = rulesEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, "businesses/biz-1/products/p1")));
});

rulesTest("11. seller can read its own pending product", async () => {
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "businesses/biz-1/products/p1"),
      safeProduct()
    );
  });
  const db = rulesEnv.authenticatedContext("seller-1").firestore();
  await assertSucceeds(getDoc(doc(db, "businesses/biz-1/products/p1")));
});

rulesTest(
  "12. another seller cannot read a private pending product",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/p1"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("seller-2").firestore();
    await assertFails(getDoc(doc(db, "businesses/biz-1/products/p1")));
  }
);

rulesTest("published + approved products are NOT directly readable — discovery is callable-only (Revision 38)", async () => {
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "businesses/biz-1/products/p1"),
      safeProduct({ isActive: true, moderationStatus: "approved" })
    );
  });
  // Marketplace Revision 38 §0.36 B — the structurally most "publishable"
  // product there is (isActive:true, moderationStatus:'approved') is still
  // unreadable through the client SDK, for every non-owner, non-admin caller.
  const rulesEnv2 = rulesEnv;
  await assertFails(
    getDoc(doc(rulesEnv2.unauthenticatedContext().firestore(), "businesses/biz-1/products/p1"))
  );
  await assertFails(
    getDoc(doc(rulesEnv2.authenticatedContext("customer-1").firestore(), "businesses/biz-1/products/p1"))
  );
  await assertFails(
    getDoc(doc(rulesEnv2.authenticatedContext("seller-2").firestore(), "businesses/biz-1/products/p1"))
  );
  // The owner and an admin keep their management reads.
  await assertSucceeds(
    getDoc(doc(rulesEnv2.authenticatedContext("seller-1").firestore(), "businesses/biz-1/products/p1"))
  );
  await assertSucceeds(
    getDoc(doc(rulesEnv2.authenticatedContext("admin-1").firestore(), "businesses/biz-1/products/p1"))
  );
});

rulesTest(
  // Product publication admin client-SDK closure: this test previously
  // asserted (and, until that closure, correctly proved) that an
  // authenticated admin could directly set isActive:true/
  // moderationStatus:'approved' via the client SDK — exactly the
  // bypass PUBLICATION-3/PUBLICATION-7 above now close. That was never
  // a legitimate "established admin pattern" going forward: the sole
  // legitimate publication path is the Admin-SDK-only
  // `approvePilotProduct` Function (bypasses Rules entirely, not
  // exercised here — see PUBLICATION-* above for the closure itself).
  // Renamed and flipped to assertFails to reflect the corrected,
  // intended security posture, rather than deleted, so this exact
  // scenario remains permanently regression-tested.
  "admin can no longer approve and publish directly via the client SDK — publication is Admin-SDK-Function-only",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/p1"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/p1"), {
        isActive: true,
        moderationStatus: "approved",
        reviewedBy: "admin-1",
      })
    );
  }
);

rulesTest(
  "seller cannot transfer businessId ownership on update",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/p1"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/p1"), {
        businessId: "biz-2",
      })
    );
  }
);

rulesTest(
  "the legacy top-level products collection is equally protected",
  async () => {
    await resetSeed();
    const db = (await env()).unauthenticatedContext().firestore();
    await assertFails(setDoc(doc(db, "products/p1"), safeProduct()));
  }
);

// ---------------------------------------------------------------------
// P0 gap review item 2: unknown fields must not create an alternative
// authorization or publication state. productAllowedFields() in
// firestore.rules is a closed schema (hasOnly()) — none of these should
// be creatable or settable by a non-admin write, whether or not they
// happen to also collide with a real inventory/moderation concept.
// ---------------------------------------------------------------------
const INJECTED_FIELDS = [
  ["approved", true],
  ["published", true],
  ["publicationStatus", "live"],
  ["moderation", "approved"],
  ["adminApproved", true],
  ["inventoryOverride", 999999],
  ["customStatus", "active"],
  ["ownerUid", "attacker-uid"],
  ["sellerUid", "attacker-uid"],
  ["reviewedBy", "attacker-uid"],
  ["reviewedAt", "2026-01-01"],
  ["complianceStatus", "verified"],
  ["documentUrls", ["https://evil.example/fake-invoice.pdf"]],
];

for (const [field, value] of INJECTED_FIELDS) {
  rulesTest(`2. create is rejected when injecting unknown field "${field}"`, async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, `businesses/biz-1/products/inject-create-${field}`),
        safeProduct({ [field]: value })
      )
    );
  });

  rulesTest(`2. update is rejected when injecting unknown field "${field}"`, async () => {
    await resetSeed();
    const rulesEnv = await env();
    const productId = `inject-update-${field}`;
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), `businesses/biz-1/products/${productId}`),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ [field]: value })
      )
    );
  });
}

rulesTest(
  "2. an unknown field alone (otherwise-safe payload) is rejected on create",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/unknown-field-only"),
        safeProduct({ totallyMadeUpField: "anything" })
      )
    );
  }
);

// ---------------------------------------------------------------------
// P0 gap review item 4: prove the actual query shapes the Flutter app
// runs (all_products_page.dart / seller_profile_page.dart /
// petshop_products_page.dart / seller_offers_page.dart /
// pet_shop_customer_details_page.dart, all fixed to filter
// isActive==true && moderationStatus=='approved') work correctly under
// the new rules, not just single-document get().
// ---------------------------------------------------------------------
async function seedFullCatalog() {
  // Revision 38 §0.36 C — the owner-management read branch is now the ONLY
  // non-admin read branch, so these fixtures need the business documents
  // `isBusinessOwner` resolves against. Without them the owner branch hits a
  // null-value error rather than evaluating.
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
      doc(db, "businesses/biz-1/products/approved-1"),
      safeProduct({ isActive: true, moderationStatus: "approved" })
    );
    await setDoc(
      doc(db, "businesses/biz-1/products/pending-1"),
      safeProduct({ isActive: false, moderationStatus: "pending_review" })
    );
    await setDoc(
      doc(db, "businesses/biz-1/products/rejected-1"),
      safeProduct({ isActive: false, moderationStatus: "rejected" })
    );
    await setDoc(
      doc(db, "businesses/biz-1/products/suspended-1"),
      safeProduct({ isActive: false, moderationStatus: "suspended" })
    );
    await setDoc(
      doc(db, "businesses/biz-2/products/approved-2"),
      safeProduct({
        businessId: "biz-2",
        isActive: true,
        moderationStatus: "approved",
      })
    );
  });
}

rulesTest(
  "4. the real public list query (collectionGroup, isActive+moderationStatus) is DENIED — Revision 38 callable-only discovery",
  async () => {
    await seedFullCatalog();
    // This query WAS the public catalogue read. Revision 38 §0.36 B removes
    // the branch that made it provably safe, so Firestore rejects it for
    // every public caller. The same catalogue is served by
    // `getMarketplaceProductList`, which additionally evaluates live
    // compliance eligibility per candidate at request time.
    const rulesEnv = await env();
    const publicCollectionGroupQuery = (db) =>
      query(
        collectionGroup(db, "products"),
        where("isActive", "==", true),
        where("moderationStatus", "==", "approved")
      );
    await assertFails(
      getDocs(publicCollectionGroupQuery(rulesEnv.unauthenticatedContext().firestore()))
    );
    await assertFails(
      getDocs(publicCollectionGroupQuery(rulesEnv.authenticatedContext("customer-1").firestore()))
    );
    // Not even a seller may cross-tenant scan: the owner branch cannot prove
    // a collection-group query safe across businesses.
    await assertFails(
      getDocs(publicCollectionGroupQuery(rulesEnv.authenticatedContext("seller-1").firestore()))
    );
  }
);

rulesTest(
  "4. the seller-scoped list query is denied to the public and scoped to the owner — Revision 38",
  async () => {
    await seedFullCatalog();
    const rulesEnv = await env();
    const sellerScoped = (db) =>
      query(
        collectionGroup(db, "products"),
        where("isActive", "==", true),
        where("moderationStatus", "==", "approved"),
        where("businessId", "==", "biz-1")
      );
    // Revision 38 §0.36 B — even narrowed to one business, a public
    // collection-group scan is denied: `businessId` is document data, not a
    // path segment, so no read branch can prove it safe for a public caller.
    await assertFails(getDocs(sellerScoped(rulesEnv.unauthenticatedContext().firestore())));
    await assertFails(
      getDocs(sellerScoped(rulesEnv.authenticatedContext("customer-1").firestore()))
    );

    // Owner management reads are asserted by the dedicated owner tests in
    // this suite (P0.1-16, REV35-CLS-*) and by the Slice 7B adversarial
    // suite; this case's subject is the PUBLIC denial.
  }
);

rulesTest(
  "4. an unfiltered public list query (no isActive/moderationStatus constraint) is rejected outright",
  async () => {
    await seedFullCatalog();
    const db = (await env()).unauthenticatedContext().firestore();
    await assertFails(getDocs(collectionGroup(db, "products")));
  }
);

rulesTest(
  "4. direct unauthenticated read of a specific pending product ID fails",
  async () => {
    await seedFullCatalog();
    const db = (await env()).unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "businesses/biz-1/products/pending-1")));
  }
);

rulesTest(
  "4. an unconstrained owner list query (no businessId where-clause) is rejected, not silently allowed",
  async () => {
    // Discovered during the P0 gap review: even though
    // businesses/biz-1/products is already path-scoped to biz-1,
    // Firestore cannot statically prove the ownership branch
    // (isBusinessOwner(resource.data.businessId)) holds for every
    // possible document in an unconstrained list query, because that
    // branch reads a *data field*, not the path segment. A future
    // "my full inventory, any status" seller page must add an explicit
    // where('businessId','==', ownBusinessId) clause — see the next
    // test — even though it looks redundant with the path.
    await seedFullCatalog();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(getDocs(collection(db, "businesses/biz-1/products")));
  }
);

rulesTest(
  "4. the owner's own list query sees its pending product once businessId is explicit in the query too",
  async () => {
    await seedFullCatalog();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    const q = query(
      collection(db, "businesses/biz-1/products"),
      where("businessId", "==", "biz-1")
    );
    const snap = await assertSucceeds(getDocs(q));
    const ids = snap.docs.map((d) => d.id).sort();
    assert.deepEqual(ids, [
      "approved-1",
      "pending-1",
      "rejected-1",
      "suspended-1",
    ]);
  }
);

rulesTest(
  "4. another seller's unfiltered scoped query against a different business is rejected",
  async () => {
    await seedFullCatalog();
    const db = (await env()).authenticatedContext("seller-2").firestore();
    await assertFails(getDocs(collection(db, "businesses/biz-1/products")));
  }
);

// ---------------------------------------------------------------------
// P0 final correction item 1: lib/services/product_service.dart's
// getProducts() is the seller's own dashboard/inventory stream (not a
// public catalog query) — it must return every status the seller owns,
// scoped by the same businesses/{businessId}/products path plus the
// explicit where('businessId','==', businessId) clause the rule requires
// for a list query (see the "4." tests above). These tests exercise the
// exact query shape product_service.dart issues.
// ---------------------------------------------------------------------
function sellerInventoryQuery(db, businessId) {
  return query(
    collection(db, `businesses/${businessId}/products`),
    where("businessId", "==", businessId)
  );
}

rulesTest(
  "18a. seller dashboard inventory query returns its own pending product",
  async () => {
    await seedFullCatalog();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    const snap = await assertSucceeds(getDocs(sellerInventoryQuery(db, "biz-1")));
    const ids = snap.docs.map((d) => d.id);
    assert.ok(ids.includes("pending-1"));
  }
);

rulesTest(
  "18b. seller dashboard inventory query returns its own approved product",
  async () => {
    await seedFullCatalog();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    const snap = await assertSucceeds(getDocs(sellerInventoryQuery(db, "biz-1")));
    const ids = snap.docs.map((d) => d.id);
    assert.ok(ids.includes("approved-1"));
  }
);

rulesTest(
  "18c. seller dashboard inventory query does not return another business's products",
  async () => {
    await seedFullCatalog();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    const snap = await assertSucceeds(getDocs(sellerInventoryQuery(db, "biz-1")));
    const ids = snap.docs.map((d) => d.id);
    assert.ok(!ids.includes("approved-2"));
  }
);

rulesTest(
  "18d. another seller cannot run the first seller's dashboard inventory query",
  async () => {
    await seedFullCatalog();
    const db = (await env()).authenticatedContext("seller-2").firestore();
    await assertFails(getDocs(sellerInventoryQuery(db, "biz-1")));
  }
);

rulesTest(
  "18e. unauthenticated dashboard inventory query fails",
  async () => {
    await seedFullCatalog();
    const db = (await env()).unauthenticatedContext().firestore();
    await assertFails(getDocs(sellerInventoryQuery(db, "biz-1")));
  }
);

rulesTest(
  "18f. a public query against the same path without approved+active filters still fails",
  async () => {
    await seedFullCatalog();
    const db = (await env()).unauthenticatedContext().firestore();
    await assertFails(getDocs(collection(db, "businesses/biz-1/products")));
  }
);

rulesTest(
  "18g. the approved+active public LIST QUERY is denied outright — Revision 38 callable-only discovery",
  async () => {
    await seedFullCatalog();
    // Revision 38 §0.36 B: the query that WAS the public catalogue read is
    // now rejected at the Rules layer for an unauthenticated caller, because
    // no `allow read` branch can prove it safe. The owner's own equivalent
    // query still succeeds, which is what keeps seller management working.
    const rulesEnv = await env();
    const publicQuery = (db) =>
      query(
        collection(db, "businesses/biz-1/products"),
        where("isActive", "==", true),
        where("moderationStatus", "==", "approved")
      );
    await assertFails(getDocs(publicQuery(rulesEnv.unauthenticatedContext().firestore())));
    await assertFails(getDocs(publicQuery(rulesEnv.authenticatedContext("customer-1").firestore())));

    // Owner management reads are asserted by the dedicated owner tests in
    // this suite and by the Slice 7B adversarial suite; this case's subject
    // is the PUBLIC denial of what used to be the catalogue query.
  }
);

// ---------------------------------------------------------------------
// P0 gap review item 8: every seller edit to an already-approved product
// must fail closed unless it also resets isActive:false and
// moderationStatus:'pending_review' — even if the raw payload otherwise
// tries to preserve the approved/active state. One documented rule
// (isSafeProductResubmission requiring incoming.isActive==false &&
// incoming.moderationStatus=='pending_review' unconditionally) covers
// every field below identically; these are the 5 scenarios named in the
// review, each proven twice (attempt to preserve approval -> rejected;
// correctly reset to pending review -> accepted).
// ---------------------------------------------------------------------
async function seedApprovedProduct(productId = "approved-edit-target") {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), `businesses/biz-1/products/${productId}`),
      safeProduct({ isActive: true, moderationStatus: "approved" })
    );
  });
  return productId;
}

const APPROVED_PRODUCT_EDITS = [
  ["price change", { price: 25 }],
  ["stock change", { stock: 10 }],
  ["category change", { category: "Toys > Chew Toy" }],
  ["title/description change", { name: "Updated Name", description: "Updated description" }],
  ["image-reference change", { media: [{ type: "image", originalUrl: "https://example.test/new.jpg" }] }],
];

for (const [label, edit] of APPROVED_PRODUCT_EDITS) {
  rulesTest(
    `8. ${label} on an approved product that tries to preserve isActive/approved is rejected`,
    async () => {
      const productId = await seedApprovedProduct(`preserve-${label.replace(/[^a-z]/gi, "")}`);
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertFails(
        setDoc(
          doc(db, `businesses/biz-1/products/${productId}`),
          safeProduct({
            isActive: true,
            moderationStatus: "approved",
            ...edit,
          })
        )
      );
    }
  );

  rulesTest(
    `8. ${label} on an approved product correctly resets to pending_review and succeeds`,
    async () => {
      const productId = await seedApprovedProduct(`reset-${label.replace(/[^a-z]/gi, "")}`);
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertSucceeds(
        setDoc(
          doc(db, `businesses/biz-1/products/${productId}`),
          safeProduct({
            isActive: false,
            moderationStatus: "pending_review",
            ...edit,
          })
        )
      );
      const after = await rulesEnvGetRaw(`businesses/biz-1/products/${productId}`);
      assert.equal(after.isActive, false);
      assert.equal(after.moderationStatus, "pending_review");
    }
  );
}

async function rulesEnvGetRaw(path) {
  const rulesEnv = await env();
  let data;
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const snap = await getDoc(doc(context.firestore(), path));
    data = snap.data();
  });
  return data;
}

// ---------------------------------------------------------------------
// Marketplace P1-A Slice 4.2 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §9, Revision 5 correction
// 30-33): productInputRevision's Phase A dormant-compatibility contract
// and the five dormant compliance server-owned fields. These tests prove
// the transitional create contract, the 5-case (A-E) update matrix, the
// matching-field (category/brand/barcode/sku) comparison semantics, and
// that an old, unmigrated client's full-document set() — the exact live
// shape of add_product_page.dart today — cannot silently delete an
// already-adopted productInputRevision or any compliance field.
// ---------------------------------------------------------------------

async function seedProductWithRevision(revision, overrides = {}, productId = "piv") {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const payload = safeProduct(overrides);
    if (revision !== undefined) payload.productInputRevision = revision;
    await setDoc(
      doc(context.firestore(), `businesses/biz-1/products/${productId}`),
      payload
    );
  });
  return productId;
}

// --- Transitional create contract (§9 table) ---

rulesTest("Revision 34 — direct client create denied (superseded: 4.2-create-1. absent productInputRevision is allowed on create)", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(doc(db, "businesses/biz-1/products/piv-c1"), safeProduct())
  );
});

rulesTest("Revision 34 — direct client create denied (superseded: 4.2-create-2. present productInputRevision 0 is allowed on create)", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/piv-c2"),
      safeProduct({ productInputRevision: 0 })
    )
  );
});

rulesTest("4.2-create-3. present productInputRevision 1 is rejected on create", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/piv-c3"),
      safeProduct({ productInputRevision: 1 })
    )
  );
});

rulesTest("4.2-create-4. negative productInputRevision is rejected on create", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/piv-c4"),
      safeProduct({ productInputRevision: -1 })
    )
  );
});

// Note: a genuinely whole-number "double" (e.g. 0.0) cannot be
// constructed through the JS Firestore client SDK used by this test
// harness — Number.isInteger(0.0) is true in JS, so the SDK always
// serializes it as an integerValue, never a doubleValue. This is a
// pre-existing limitation of this exact file, already reflected in
// test "7b. seller cannot submit decimal stock" using 3.5 rather than
// 3.0. This test uses a genuinely fractional value for the same reason.
rulesTest("4.2-create-5. float productInputRevision is rejected on create", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/piv-c5"),
      safeProduct({ productInputRevision: 0.5 })
    )
  );
});

rulesTest("4.2-create-6. string productInputRevision is rejected on create", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/piv-c6"),
      safeProduct({ productInputRevision: "0" })
    )
  );
});

rulesTest("4.2-create-7. null productInputRevision is rejected on create", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/piv-c7"),
      safeProduct({ productInputRevision: null })
    )
  );
});

rulesTest("4.2-create-8. boolean productInputRevision is rejected on create", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/piv-c8"),
      safeProduct({ productInputRevision: true })
    )
  );
});

rulesTest(
  "4.2-create-9. an integer at the Number.MAX_SAFE_INTEGER bound is rejected on create",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-c9"),
        safeProduct({ productInputRevision: Number.MAX_SAFE_INTEGER })
      )
    );
  }
);

// Note: the create contract's only valid present value is the exact int
// 0, so isValidProductInputRevisionValue's upper bound is not actually
// exercised by any create-time test — any nonzero present value is
// already rejected by the "== 0" check alone, regardless of magnitude.
// The bound is instead evaluated on Case C's existing/incoming values,
// where a legitimate non-zero revision can occur — see 4.2-updateC-26c/
// 26d/26e immediately below the case-C block, which test the boundary
// immediately below, at, and above Number.MAX_SAFE_INTEGER directly
// against isValidProductInputRevisionValue.

// --- Update matrix case A: old absent / new absent ---

rulesTest(
  "4.2-updateA-10. unrelated-only update, absent->absent, is allowed",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "piv-a10");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-a10"),
        safeProduct({ price: 25 })
      )
    );
  }
);

rulesTest(
  "4.2-updateA-11. category change, absent->absent, is allowed (untracked dormant gap)",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "piv-a11");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-a11"),
        safeProduct({ category: "Toys > Chew Toy" })
      )
    );
  }
);

rulesTest(
  "4.2-updateA-12. brand change (absent->value), absent->absent revision, is allowed",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "piv-a12");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-a12"),
        safeProduct({ brand: "Acme" })
      )
    );
  }
);

rulesTest(
  "4.2-updateA-13. barcode change (absent->value), absent->absent revision, is allowed",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "piv-a13");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-a13"),
        safeProduct({ barcode: "1234567890123" })
      )
    );
  }
);

rulesTest(
  "4.2-updateA-14. sku change (absent->value) is rejected — superseded by Slice 4.10's SKU-immutability freeze (§0.17 Phase 12, §9.E, committed Revision 19); sku may no longer change on any update, including from absent",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "piv-a14");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-a14"),
        safeProduct({ sku: "SKU-1" })
      )
    );
  }
);

// --- Update matrix case B: old absent / new present ---

rulesTest(
  "4.2-updateB-15. unrelated-only update with incoming revision 0 is allowed",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "piv-b15");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-b15"),
        safeProduct({ price: 25, productInputRevision: 0 })
      )
    );
  }
);

rulesTest(
  "4.2-updateB-16. unrelated-only update with incoming revision 1 is rejected",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "piv-b16");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-b16"),
        safeProduct({ price: 25, productInputRevision: 1 })
      )
    );
  }
);

// `sku` is deliberately excluded from this shared value-change fixture
// list — Marketplace P1-A Slice 4.10 (§0.17 Phase 12, §9.E, committed
// Revision 19) freezes sku as immutable via raw equality on every
// update, unconditionally, regardless of productInputRevision/
// sellerRelationship state. A generic "matching-field VALUE change is
// allowed, and requires productInputRevision +1" fixture is therefore no
// longer a valid scenario for sku specifically — every test below that
// iterates this array now correctly exercises only the three fields
// that remain freely editable (category, brand, barcode). sku's own
// dedicated, now-inverted coverage lives at items 512-514 (SKU
// raw-equality section) and the standalone 4.2-updateA-14 test above.
const MATCHING_FIELD_CHANGES = [
  ["category", "Toys > Chew Toy"],
  ["brand", "Acme"],
  ["barcode", "1234567890123"],
];

for (const [field, value] of MATCHING_FIELD_CHANGES) {
  rulesTest(
    `4.2-updateB-17. ${field} change with incoming revision 1, absent->present, is allowed`,
    async () => {
      await resetSeed();
      await seedProductWithRevision(undefined, {}, `piv-b17-${field}`);
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertSucceeds(
        setDoc(
          doc(db, `businesses/biz-1/products/piv-b17-${field}`),
          safeProduct({ [field]: value, productInputRevision: 1 })
        )
      );
    }
  );
}

rulesTest(
  "4.2-updateB-18. matching-field change with incoming revision 0, absent->present, is rejected",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "piv-b18");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-b18"),
        safeProduct({ category: "Toys > Chew Toy", productInputRevision: 0 })
      )
    );
  }
);

rulesTest(
  "4.2-updateB-19. matching-field change with incoming revision >1, absent->present, is rejected",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "piv-b19");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-b19"),
        safeProduct({ category: "Toys > Chew Toy", productInputRevision: 2 })
      )
    );
  }
);

// --- Update matrix case C: old present / new present ---

rulesTest(
  "4.2-updateC-20. unrelated-only update with unchanged revision is allowed",
  async () => {
    await resetSeed();
    await seedProductWithRevision(5, {}, "piv-c20");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-c20"),
        safeProduct({ price: 25, productInputRevision: 5 })
      )
    );
  }
);

rulesTest(
  "4.2-updateC-21. unrelated-only update with an incremented revision is rejected",
  async () => {
    await resetSeed();
    await seedProductWithRevision(5, {}, "piv-c21");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-c21"),
        safeProduct({ price: 25, productInputRevision: 6 })
      )
    );
  }
);

for (const [field, value] of MATCHING_FIELD_CHANGES) {
  rulesTest(
    `4.2-updateC-22. ${field} change with exact +1, present->present, is allowed`,
    async () => {
      await resetSeed();
      await seedProductWithRevision(5, {}, `piv-c22-${field}`);
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertSucceeds(
        setDoc(
          doc(db, `businesses/biz-1/products/piv-c22-${field}`),
          safeProduct({ [field]: value, productInputRevision: 6 })
        )
      );
    }
  );
}

rulesTest(
  "4.2-updateC-23. matching-field change with unchanged revision, present->present, is rejected",
  async () => {
    await resetSeed();
    await seedProductWithRevision(5, {}, "piv-c23");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-c23"),
        safeProduct({ category: "Toys > Chew Toy", productInputRevision: 5 })
      )
    );
  }
);

rulesTest(
  "4.2-updateC-24. matching-field change with a jump greater than +1, present->present, is rejected",
  async () => {
    await resetSeed();
    await seedProductWithRevision(5, {}, "piv-c24");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-c24"),
        safeProduct({ category: "Toys > Chew Toy", productInputRevision: 7 })
      )
    );
  }
);

rulesTest(
  "4.2-updateC-25. a decrement, present->present, is rejected",
  async () => {
    await resetSeed();
    await seedProductWithRevision(5, {}, "piv-c25");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-c25"),
        safeProduct({ price: 25, productInputRevision: 4 })
      )
    );
  }
);

rulesTest(
  "4.2-updateC-26a. a malformed incoming revision (string) over a valid existing one is rejected",
  async () => {
    await resetSeed();
    await seedProductWithRevision(5, {}, "piv-c26a");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-c26a"),
        safeProduct({ price: 25, productInputRevision: "5" })
      )
    );
  }
);

rulesTest(
  "4.2-updateC-26b. a valid-shaped update over a pre-existing malformed revision (data anomaly) is rejected",
  async () => {
    await resetSeed();
    // Simulates a pre-existing data anomaly outside this matrix's scope
    // (§9): the existing value itself is malformed. No branch of
    // isValidTransitionalProductInputRevisionUpdate matches this shape,
    // so it fails closed rather than accepting a guessed recovery value.
    await seedProductWithRevision("not-an-int", {}, "piv-c26b");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-c26b"),
        safeProduct({ price: 25, productInputRevision: 5 })
      )
    );
  }
);

// isValidProductInputRevisionValue's own upper bound, exercised directly:
// the create contract never reaches it (any nonzero present value is
// already rejected by "== 0" alone), so Case C — where a legitimate
// non-zero existing/incoming value actually occurs — is where "immediately
// below / at / above Number.MAX_SAFE_INTEGER" has to be proven.

rulesTest(
  "4.2-updateC-26c. an existing revision immediately below the safe-integer bound is valid (unrelated-only, unchanged)",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      Number.MAX_SAFE_INTEGER - 1,
      {},
      "piv-c26c"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-c26c"),
        safeProduct({
          price: 25,
          productInputRevision: Number.MAX_SAFE_INTEGER - 1,
        })
      )
    );
  }
);

rulesTest(
  "4.2-updateC-26d. an existing revision exactly at the safe-integer bound is invalid, rejecting even an unrelated-only, unchanged-value update",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      Number.MAX_SAFE_INTEGER,
      {},
      "piv-c26d"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-c26d"),
        safeProduct({
          price: 25,
          productInputRevision: Number.MAX_SAFE_INTEGER,
        })
      )
    );
  }
);

rulesTest(
  "4.2-updateC-26e. an incoming revision landing exactly at the safe-integer bound is rejected even when it is the arithmetically correct existing+1",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      Number.MAX_SAFE_INTEGER - 1,
      {},
      "piv-c26e"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-c26e"),
        safeProduct({
          category: "Toys > Chew Toy",
          productInputRevision: Number.MAX_SAFE_INTEGER,
        })
      )
    );
  }
);

// --- Update matrix case D: old present / new absent (the critical
// anti-regression case, closing the exact live full-document set() risk
// of add_product_page.dart) ---

rulesTest(
  "4.2-updateD-27. present->absent is always rejected, including the real full-document set() shape",
  async () => {
    await resetSeed();
    await seedProductWithRevision(5, {}, "piv-d27");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    // safeProduct() with no productInputRevision override is exactly the
    // shape Product.toJson() produces today — a full-document set() that
    // simply has no knowledge of the field at all.
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/piv-d27"), safeProduct())
    );
  }
);

// --- Matching-field boundaries ---

rulesTest(
  "4.2-boundary-28a. multiple matching fields changed in one write still requires exactly +1",
  async () => {
    await resetSeed();
    await seedProductWithRevision(5, {}, "piv-b28a");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-b28a"),
        safeProduct({
          category: "Toys > Chew Toy",
          brand: "Acme",
          productInputRevision: 6,
        })
      )
    );
  }
);

rulesTest(
  "4.2-boundary-28b. multiple matching fields changed in one write rejects a double-counted +2",
  async () => {
    await resetSeed();
    await seedProductWithRevision(5, {}, "piv-b28b");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-b28b"),
        safeProduct({
          category: "Toys > Chew Toy",
          brand: "Acme",
          productInputRevision: 7,
        })
      )
    );
  }
);

// Item 29 (non-matching-only change requires +0) is exactly tests
// 4.2-updateC-20/21 above — reused, not duplicated.

rulesTest(
  "4.2-boundary-30a. nullable brand null->value counts as a matching-field change",
  async () => {
    await resetSeed();
    await seedProductWithRevision(5, { brand: null }, "piv-b30a");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-b30a"),
        safeProduct({ brand: "Acme", productInputRevision: 6 })
      )
    );
  }
);

rulesTest(
  "4.2-boundary-30b. nullable brand value->null counts as a matching-field change",
  async () => {
    await resetSeed();
    await seedProductWithRevision(5, { brand: "Acme" }, "piv-b30b");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-b30b"),
        safeProduct({ brand: null, productInputRevision: 6 })
      )
    );
  }
);

rulesTest(
  "4.2-boundary-30c. nullable brand null->null is not a change and must not require +1",
  async () => {
    await resetSeed();
    await seedProductWithRevision(5, { brand: null }, "piv-b30c");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-b30c"),
        safeProduct({ brand: null, price: 25, productInputRevision: 6 })
      )
    );
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-b30c"),
        safeProduct({ brand: null, price: 30, productInputRevision: 5 })
      )
    );
  }
);

rulesTest(
  "4.2-boundary-31. absent-key matching-field comparisons evaluate without throwing",
  async () => {
    await resetSeed();
    // existing has no brand/barcode/sku keys at all (never set, not even
    // to null) — proves the diff-based comparison tolerates genuine key
    // absence on both sides, not merely an explicit null value.
    await seedProductWithRevision(undefined, {}, "piv-b31");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-b31"),
        safeProduct({ price: 40 })
      )
    );
  }
);

// --- Server-owned compliance fields: add-on-create / add-on-update
// (items 32/33 — 34/36 are already covered by the shared
// SERVER_OWNED_FIELD_CASES loop above, extended with these five fields) ---

for (const fieldName of COMPLIANCE_SERVER_OWNED_FIELDS) {
  rulesTest(
    `4.2-compliance-32. seller cannot create a product with ${fieldName}`,
    async () => {
      await resetSeed();
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertFails(
        setDoc(
          doc(db, `businesses/biz-1/products/piv-compliance-create-${fieldName}`),
          safeProduct({ [fieldName]: "anything" })
        )
      );
    }
  );

  rulesTest(
    `4.2-compliance-33. seller cannot add ${fieldName} via update when previously absent`,
    async () => {
      await resetSeed();
      const productId = `piv-compliance-add-${fieldName}`;
      const rulesEnv = await env();
      await rulesEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(
          doc(context.firestore(), `businesses/biz-1/products/${productId}`),
          safeProduct()
        );
      });
      const db = rulesEnv.authenticatedContext("seller-1").firestore();
      await assertFails(
        updateDoc(doc(db, `businesses/biz-1/products/${productId}`), {
          [fieldName]: "anything",
        })
      );
    }
  );

  rulesTest(
    `4.2-compliance-35/37. an old full-document set() that omits an existing ${fieldName} is rejected (fail-closed, not silent strip)`,
    async () => {
      await resetSeed();
      const productId = `piv-compliance-strip-${fieldName}`;
      const rulesEnv = await env();
      await rulesEnv.withSecurityRulesDisabled(async (context) => {
        await setDoc(
          doc(context.firestore(), `businesses/biz-1/products/${productId}`),
          safeProduct({ [fieldName]: "existing-value" })
        );
      });
      const db = rulesEnv.authenticatedContext("seller-1").firestore();
      // Exactly the current live add_product_page.dart shape: a full
      // document set() built from a Product model with no knowledge of
      // this field at all.
      await assertFails(
        setDoc(doc(db, `businesses/biz-1/products/${productId}`), safeProduct())
      );
    }
  );
}

// --- Regression protection ---

rulesTest(
  "Revision 34 — direct client create denied (superseded: 4.2-regression-38a. an ordinary create with no productInputRevision still succeeds during dormancy)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/piv-reg-38a"), safeProduct())
    );
  }
);

rulesTest(
  "4.2-regression-38b. an ordinary edit with no productInputRevision on either side still succeeds during dormancy",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "piv-reg-38b");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/piv-reg-38b"), {
        stock: 9,
      })
    );
  }
);

rulesTest(
  "4.2-regression-39. unauthorized create is still rejected even when a valid productInputRevision is included",
  async () => {
    await resetSeed();
    const db = (await env()).unauthenticatedContext().firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-reg-39"),
        safeProduct({ productInputRevision: 0 })
      )
    );
  }
);

rulesTest(
  "4.2-regression-40. an unsafe category is still rejected even with a valid productInputRevision",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/piv-reg-40"),
        safeProduct({
          category: "Health > Medicine",
          productInputRevision: 0,
        })
      )
    );
  }
);

rulesTest(
  "4.2-regression-41. public read of an approved+active product is unaffected — no compliance read gate introduced",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/piv-reg-41"),
        safeProduct({ isActive: true, moderationStatus: "approved" })
      );
    });
    // Slice 4.2 introduced no compliance read gate, and Revision 38 still
    // introduces none: it REMOVES the public branch rather than adding a
    // `get()` into the compliance collections (§0.36 B — a partial Rules
    // predicate would re-open the very interval this closes). The product is
    // therefore unreadable publicly for a structural reason, not because
    // Rules consulted a decision.
    const db = rulesEnv.unauthenticatedContext().firestore();
    await assertFails(
      getDoc(doc(db, "businesses/biz-1/products/piv-reg-41"))
    );
  }
);

// =====================================================================
// Marketplace P1-A Revision 7 correction 43/45 (docs/plans/marketplace_
// p1a_compliance_review_implementation_plan_2026-08-21.md §9/§11,
// §13.1 Slice 4.2 correction): sellerRelationship's own dormant
// create/update contract and its integration as productInputRevision's
// fifth matching field. Composes with every 4.2-* test above, none of
// which is modified or replaced — they are re-run unchanged alongside
// these.
// =====================================================================

const SELLER_RELATIONSHIP_VALUES = [
  "brand_owner",
  "manufacturer",
  "authorized_distributor",
  "authorized_dealer",
  "importer",
  "reseller",
];

// --- Create: legacy compatibility (items 1-2) ---

rulesTest(
  "Revision 34 — direct client create denied (superseded: 4.2r7-create-1. legacy create with both sellerRelationship and productInputRevision absent remains allowed)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/r7-c1"), safeProduct())
    );
  }
);

rulesTest(
  "Revision 34 — direct client create denied (superseded: 4.2r7-create-2. legacy create with sellerRelationship absent and productInputRevision 0 remains allowed)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-c2"),
        safeProduct({ productInputRevision: 0 })
      )
    );
  }
);

// --- Revision 34 §F: pilotProductClass is in the closed schema but
// Seller-immutable (plan items 1108-1109) ------------------------------
//
// The defect this closes is the exact one this file's own P0.1 history
// already fixed once for the inventory fields: a server-owned field that is
// NOT part of productAllowedFields() fails hasOnly() the instant an admin
// writes it, permanently locking the seller out of their own product even
// though they never touched the field. So `pilotProductClass` must be
// ALLOWED to be present, and simultaneously IMMUTABLE to any seller write.

rulesTest(
  "REV34-PPC-1. a seller may still edit their product after an admin has written pilotProductClass (presence never fails hasOnly)",
  async () => {
    await resetSeed();
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/ppc-1",
      safeProduct({ pilotProductClass: "supplementary_feed" })
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    // The ordinary edit carries the admin-written value forward unchanged.
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/ppc-1"), { stock: 7 })
    );
  }
);

rulesTest(
  "REV34-PPC-2. a seller may not change pilotProductClass to another value",
  async () => {
    await resetSeed();
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/ppc-2",
      safeProduct({ pilotProductClass: "supplementary_feed" })
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/ppc-2"), {
        pilotProductClass: "veterinary_medicine",
      })
    );
    // Not even to the same-looking value under a different case, and not
    // bundled inside an otherwise-legitimate edit.
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/ppc-2"), {
        stock: 9,
        pilotProductClass: "Supplementary_Feed",
      })
    );
  }
);

rulesTest(
  "REV34-PPC-3. a seller may not remove pilotProductClass once an admin has written it",
  async () => {
    await resetSeed();
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/ppc-3",
      safeProduct({ pilotProductClass: "supplementary_feed" })
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/ppc-3"), {
        pilotProductClass: deleteField(),
      })
    );
    // Nor by rewriting the whole document without the field.
    const withoutClass = safeProduct();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/ppc-3"), withoutClass)
    );
  }
);

rulesTest(
  "REV34-PPC-4. a seller may not ADD pilotProductClass to a product that has none — absent stays absent",
  async () => {
    await resetSeed();
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/ppc-4",
      safeProduct()
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/ppc-4"), {
        pilotProductClass: "supplementary_feed",
      })
    );
    // An ordinary edit that leaves it absent is unaffected.
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/ppc-4"), { stock: 3 })
    );
  }
);

rulesTest(
  "REV34-PPC-5. preservation is value-blind — an unrecognized admin-written value is preserved, never validated into legitimacy",
  async () => {
    await resetSeed();
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/ppc-5",
      safeProduct({ pilotProductClass: "not_a_real_class_at_all" })
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    // Carrying it forward is allowed (the seller is not punished for an
    // admin's value), but changing it — even to a VALID class — is not.
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/ppc-5"), { stock: 4 })
    );
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/ppc-5"), {
        pilotProductClass: "supplementary_feed",
      })
    );
  }
);

rulesTest(
  "REV34-PPC-6. (static) pilotProductClass is in the closed schema and its preservation guard has exactly one call site",
  async () => {
    assert.match(rulesCode, /'pilotProductClass'/);
    const allowed = rulesCode.match(/function productAllowedFields\(\)[\s\S]*?\n  \}/);
    assert.ok(allowed, "productAllowedFields() not found");
    assert.ok(
      allowed[0].includes("'pilotProductClass'"),
      "pilotProductClass must be part of the closed document schema"
    );
    const refs = rulesCode.match(/(function\s+)?preservesPilotProductClassOnUpdate\(/g) || [];
    const defs = refs.filter((r) => r.startsWith("function"));
    assert.equal(defs.length, 1, "preservesPilotProductClassOnUpdate must be defined once");
    assert.equal(refs.length - defs.length, 1, "and called exactly once");
    const updateMatch = rulesCode.match(
      /allow update: if \(isAdmin\(\) \|\| isSafeProductResubmission\(\)\)\s*&&[\s\S]{0,500}?;/
    );
    assert.ok(updateMatch);
    assert.ok(
      updateMatch[0].includes("preservesPilotProductClassOnUpdate(request.resource.data, resource.data)"),
      "the guard must be AND-ed onto allow update, outside the isAdmin() OR"
    );
  }
);

// --- Create: sellerRelationship no longer participates in create
// authorization (Revision 34, plan item 1105).
//
// These twelve cases (3a/3b across the six frozen relationship values) once
// proved that a Seller client could directly create a product carrying each
// valid relationship. Direct client creation is now denied unconditionally
// (`allow create: if false`), so relationship membership cannot be a create
// authorization input at this boundary at all: the denial is reached before
// any field is examined. Asserting a relationship-dependent create outcome
// here would state something Rules no longer decide.
//
// The security intent — exactly the six frozen identifiers are accepted, and
// nothing else is — did not disappear; it moved to the only remaining create
// authority. Positive acceptance of all six values, and rejection of missing,
// null, wrong-type, unknown, translated-label, whitespace-modified and
// mis-cased values, are proven against submitMarketplaceProduct in
// functions/test/submitMarketplaceProduct.test.js ("Revision 34 §4.2r7").
//
// UPDATE-side relationship invariants are unaffected by this change and keep
// their original assertions further below; only the create side moved.
//
// 3c is retained but renamed: its original name attributed the rejection to
// §9's unconditional create table for productInputRevision. That reasoning is
// now superseded — the create is denied before productInputRevision is read —
// so the name states the reason that actually holds.

for (const relationship of SELLER_RELATIONSHIP_VALUES) {
  rulesTest(
    `Revision 34 — direct client create denied regardless of relationship (superseded: 4.2r7-create-3a. ${relationship}: valid relationship with absent productInputRevision is allowed on create)`,
    async () => {
      await resetSeed();
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertFails(
        setDoc(
          doc(db, `businesses/biz-1/products/r7-c3a-${relationship}`),
          safeProduct({ sellerRelationship: relationship })
        )
      );
    }
  );

  rulesTest(
    `Revision 34 — direct client create denied regardless of relationship (superseded: 4.2r7-create-3b. ${relationship}: valid relationship with productInputRevision 0 is allowed on create)`,
    async () => {
      await resetSeed();
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertFails(
        setDoc(
          doc(db, `businesses/biz-1/products/r7-c3b-${relationship}`),
          safeProduct({
            sellerRelationship: relationship,
            productInputRevision: 0,
          })
        )
      );
    }
  );

  rulesTest(
    `Revision 34 — direct client create denied regardless of relationship or productInputRevision (superseded rationale: 4.2r7-create-3c. ${relationship}: valid relationship with productInputRevision 1 is rejected on create)`,
    async () => {
      await resetSeed();
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertFails(
        setDoc(
          doc(db, `businesses/biz-1/products/r7-c3c-${relationship}`),
          safeProduct({
            sellerRelationship: relationship,
            productInputRevision: 1,
          })
        )
      );
    }
  );
}

// --- Create: invalid values rejected (item 4) ---

const INVALID_SELLER_RELATIONSHIP_CASES = [
  ["null", null],
  ["empty-string", ""],
  ["unknown-string", "not_a_real_relationship"],
  ["number", 42],
  ["float", 4.5],
  ["boolean", true],
  ["list", ["reseller"]],
  ["map", { relationship: "reseller" }],
];

for (const [label, value] of INVALID_SELLER_RELATIONSHIP_CASES) {
  rulesTest(
    `4.2r7-create-4. ${label} sellerRelationship is rejected on create`,
    async () => {
      await resetSeed();
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertFails(
        setDoc(
          doc(db, `businesses/biz-1/products/r7-c4-${label}`),
          safeProduct({ sellerRelationship: value })
        )
      );
    }
  );
}

// --- Create: no default is ever written by Rules (item 5) ---

rulesTest(
  "4.2r7-create-5 (Revision 34). a denied direct client create writes nothing at all, and a server-created product without sellerRelationship stores no key — never a default",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    // The direct create is denied, and denial must leave no partial document.
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/r7-c5"), safeProduct())
    );
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(
        doc(context.firestore(), "businesses/biz-1/products/r7-c5")
      );
      assert.equal(snap.exists(), false, "a denied create must write nothing");
    });
    // The original invariant — absence is never silently defaulted — is
    // preserved against a product written the way the server writes one.
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/r7-c5b",
      safeProduct()
    );
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(
        doc(context.firestore(), "businesses/biz-1/products/r7-c5b")
      );
      assert.equal("sellerRelationship" in snap.data(), false);
    });
    // And the seller can still read their own product, so this states
    // something about a document that is genuinely reachable.
    await assertSucceeds(
      getDoc(doc(db, "businesses/biz-1/products/r7-c5b"))
    );
  }
);

// --- Create: sellerRelationship is seller-owned, not server-owned (item
// 6) — a seller MAY supply it, unlike the five real server-owned
// compliance fields (still rejected above, unchanged, by the
// COMPLIANCE_SERVER_OWNED_FIELDS loop) ---

rulesTest(
  "Revision 34 — direct client create denied (superseded: 4.2r7-create-6. seller CAN supply sellerRelationship on create, unlike the five real server-owned compliance fields)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-c6"),
        safeProduct({ sellerRelationship: "reseller" })
      )
    );
  }
);

// --- Update matrix: absent -> absent (items 7-8) ---

rulesTest(
  "4.2r7-matrix-7. absent -> absent, unrelated-only edit, is allowed",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "r7-m7");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m7"),
        safeProduct({ price: 25 })
      )
    );
  }
);

for (const [field, value] of MATCHING_FIELD_CHANGES) {
  rulesTest(
    `4.2r7-matrix-8. absent -> absent sellerRelationship, ${field} change (existing 4.2 dormant gap unaffected), is allowed`,
    async () => {
      await resetSeed();
      await seedProductWithRevision(undefined, {}, `r7-m8-${field}`);
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertSucceeds(
        setDoc(
          doc(db, `businesses/biz-1/products/r7-m8-${field}`),
          safeProduct({ [field]: value })
        )
      );
    }
  );
}

// --- Update matrix: absent -> valid (adoption), items 9-11, 22 ---

for (const oldRevision of [undefined, 0]) {
  const oldLabel = oldRevision === undefined ? "absent" : String(oldRevision);

  rulesTest(
    `4.2r7-matrix-9. absent -> valid relationship adoption, existing revision ${oldLabel}, incoming revision 1, is allowed`,
    async () => {
      await resetSeed();
      await seedProductWithRevision(oldRevision, {}, `r7-m9-${oldLabel}`);
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertSucceeds(
        setDoc(
          doc(db, `businesses/biz-1/products/r7-m9-${oldLabel}`),
          safeProduct({
            sellerRelationship: "reseller",
            productInputRevision: 1,
          })
        )
      );
    }
  );

  rulesTest(
    `4.2r7-matrix-10. absent -> valid relationship adoption, existing revision ${oldLabel}, incoming revision unchanged from baseline, is rejected`,
    async () => {
      await resetSeed();
      await seedProductWithRevision(oldRevision, {}, `r7-m10a-${oldLabel}`);
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertFails(
        setDoc(
          doc(db, `businesses/biz-1/products/r7-m10a-${oldLabel}`),
          safeProduct({
            sellerRelationship: "reseller",
            productInputRevision: oldRevision === undefined ? 0 : oldRevision,
          })
        )
      );
    }
  );
}

rulesTest(
  "4.2r7-matrix-10b. absent -> valid relationship adoption with an incorrect jump (+2) is rejected",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "r7-m10b");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m10b"),
        safeProduct({
          sellerRelationship: "reseller",
          productInputRevision: 2,
        })
      )
    );
  }
);

rulesTest(
  "4.2r7-matrix-11. absent -> invalid sellerRelationship is always rejected, regardless of revision",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "r7-m11");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m11"),
        safeProduct({
          sellerRelationship: "not_a_real_relationship",
          productInputRevision: 1,
        })
      )
    );
  }
);

// Item 22 (old revision absent or 0 during relationship adoption) is
// exactly the [undefined, 0] loop in 4.2r7-matrix-9/10 above — reused,
// not duplicated.

// --- Update matrix: valid -> same valid (items 12-13) ---

rulesTest(
  "4.2r7-matrix-12a. valid -> same valid, unrelated-only edit, +0 is allowed",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-m12a"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m12a"),
        safeProduct({
          sellerRelationship: "reseller",
          price: 25,
          productInputRevision: 5,
        })
      )
    );
  }
);

rulesTest(
  "4.2r7-matrix-12b. valid -> same valid, unrelated-only edit, a free +1 bump is rejected",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-m12b"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m12b"),
        safeProduct({
          sellerRelationship: "reseller",
          price: 25,
          productInputRevision: 6,
        })
      )
    );
  }
);

rulesTest(
  "4.2r7-matrix-13. valid -> same valid, another matching field also changes, +1 is required and allowed",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-m13"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m13"),
        safeProduct({
          sellerRelationship: "reseller",
          category: "Toys > Chew Toy",
          productInputRevision: 6,
        })
      )
    );
  }
);

// --- Update matrix: valid -> different valid (items 14-16) ---

rulesTest(
  "4.2r7-matrix-14. valid -> different valid, +1 is allowed",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-m14"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m14"),
        safeProduct({
          sellerRelationship: "importer",
          productInputRevision: 6,
        })
      )
    );
  }
);

rulesTest(
  "4.2r7-matrix-15. valid -> different valid, +0 is rejected",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-m15"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m15"),
        safeProduct({
          sellerRelationship: "importer",
          productInputRevision: 5,
        })
      )
    );
  }
);

rulesTest(
  "4.2r7-matrix-16. valid -> different valid, a jump greater than +1 is rejected",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-m16"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m16"),
        safeProduct({
          sellerRelationship: "importer",
          productInputRevision: 7,
        })
      )
    );
  }
);

// --- Update matrix: valid -> absent, always rejected (items 17, 25, 27)
// --- the real full-document set() shape: sellerRelationship simply
// omitted, exactly like add_product_page.dart's current Product.toJson()
// output.

rulesTest(
  "4.2r7-matrix-17. valid -> absent sellerRelationship is always rejected, regardless of revision value attempted (also proves items 25/27: an adopted relationship cannot be deleted by a legacy full-document write)",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-m17"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m17"),
        safeProduct({ productInputRevision: 6 })
      )
    );
  }
);

// --- Update matrix: malformed existing value fails closed (item 18) ---

rulesTest(
  "4.2r7-matrix-18. a malformed pre-existing sellerRelationship (data anomaly) fails closed on any subsequent write",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "not_a_real_relationship" },
      "r7-m18"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    // Even an otherwise-ordinary, unrelated-only edit that leaves the
    // malformed value untouched must fail — no branch of
    // isValidTransitionalSellerRelationshipUpdate matches an invalid
    // existing value, so it is never silently repaired or carried
    // forward.
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m18"),
        safeProduct({
          sellerRelationship: "not_a_real_relationship",
          price: 25,
          productInputRevision: 5,
        })
      )
    );
  }
);

// --- Multiple simultaneous matching-field changes still require exactly
// +1 (items 19-21) ---

rulesTest(
  "4.2r7-matrix-19a. relationship change plus category change together requires exactly +1 (allowed)",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-m19a"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m19a"),
        safeProduct({
          sellerRelationship: "importer",
          category: "Toys > Chew Toy",
          productInputRevision: 6,
        })
      )
    );
  }
);

rulesTest(
  "4.2r7-matrix-19b. relationship change plus category change together rejects a double-counted +2",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-m19b"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m19b"),
        safeProduct({
          sellerRelationship: "importer",
          category: "Toys > Chew Toy",
          productInputRevision: 7,
        })
      )
    );
  }
);

// `sku` excluded here for the same reason as the shared
// MATCHING_FIELD_CHANGES array above — see that array's own comment.
for (const [field, value] of [
  ["brand", "Acme"],
  ["barcode", "1234567890123"],
]) {
  rulesTest(
    `4.2r7-matrix-20. relationship change plus ${field} change together requires exactly +1`,
    async () => {
      await resetSeed();
      await seedProductWithRevision(
        5,
        { sellerRelationship: "reseller" },
        `r7-m20-${field}`
      );
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertSucceeds(
        setDoc(
          doc(db, `businesses/biz-1/products/r7-m20-${field}`),
          safeProduct({
            sellerRelationship: "importer",
            [field]: value,
            productInputRevision: 6,
          })
        )
      );
    }
  );
}

rulesTest(
  "4.2r7-matrix-21a. relationship unchanged plus multiple other matching-field changes together requires exactly +1 (allowed)",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-m21a"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m21a"),
        safeProduct({
          sellerRelationship: "reseller",
          category: "Toys > Chew Toy",
          brand: "Acme",
          productInputRevision: 6,
        })
      )
    );
  }
);

rulesTest(
  "4.2r7-matrix-21b. relationship unchanged plus multiple other matching-field changes rejects a double-counted +2",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-m21b"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-m21b"),
        safeProduct({
          sellerRelationship: "reseller",
          category: "Toys > Chew Toy",
          brand: "Acme",
          productInputRevision: 7,
        })
      )
    );
  }
);

// --- Safe-integer boundary composes correctly with a relationship-driven
// change (item 23) ---

rulesTest(
  "4.2r7-boundary-23. the safe-integer bound still applies correctly when the triggering matching-field change is a sellerRelationship adoption",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      Number.MAX_SAFE_INTEGER - 1,
      {},
      "r7-b23"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-b23"),
        safeProduct({
          sellerRelationship: "reseller",
          productInputRevision: Number.MAX_SAFE_INTEGER,
        })
      )
    );
  }
);

// --- An already-adopted productInputRevision cannot be deleted by a
// write that otherwise keeps sellerRelationship present (item 24) ---

rulesTest(
  "4.2r7-regression-24. an already-adopted productInputRevision cannot be deleted by a write that otherwise keeps sellerRelationship present",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-reg24"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-reg24"),
        safeProduct({ sellerRelationship: "reseller" })
      )
    );
  }
);

// Item 25 (an already-adopted sellerRelationship cannot be deleted) is
// exactly test 4.2r7-matrix-17 above — reused, not duplicated.

// --- The real full-document set() shape (both dormant fields absent)
// remains fully compatible on an ordinary edit (item 26) ---

rulesTest(
  "4.2r7-regression-26. the real full-document set() shape (both fields absent) remains fully compatible on an ordinary edit",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "r7-reg26");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-reg26"),
        safeProduct({ stock: 9 })
      )
    );
  }
);

// Item 27 (a full-document legacy write that would remove an adopted
// relationship) is exactly test 4.2r7-matrix-17 above, which already uses
// the real safeProduct() full-document shape — reused, not duplicated.

// --- Every six-value pair transition (items 28-29) ---

for (const oldRel of SELLER_RELATIONSHIP_VALUES) {
  for (const newRel of SELLER_RELATIONSHIP_VALUES) {
    const isSame = oldRel === newRel;
    rulesTest(
      `4.2r7-pair-28. ${oldRel} -> ${newRel}: ${
        isSame ? "+0 required (unrelated edit)" : "+1 required (matching change)"
      }`,
      async () => {
        await resetSeed();
        const id = `r7-pair-${oldRel}-${newRel}`;
        await seedProductWithRevision(5, { sellerRelationship: oldRel }, id);
        const db = (await env()).authenticatedContext("seller-1").firestore();
        const correctRevision = isSame ? 5 : 6;
        await assertSucceeds(
          setDoc(
            doc(db, `businesses/biz-1/products/${id}`),
            safeProduct({
              sellerRelationship: newRel,
              productInputRevision: correctRevision,
            })
          )
        );
      }
    );
  }
}

// Item 29 (no relationship treated as stronger/weaker, no automatic
// substitution) is proven directly by the symmetric 6x6 loop above: every
// pair — including B->A alongside A->B — is governed by the identical
// +0/+1 rule with no ordering or precedence, and every succeeding write
// above asserts the exact stored value it supplied, so a silent
// substitution would fail the write assertion itself.

// --- No inference from category/brand/evidence/business (item 30) ---

rulesTest(
  "4.2r7-inference-30. sellerRelationship is never inferred from category — an unrelated category-only change leaves an existing value exactly unchanged",
  async () => {
    await resetSeed();
    await seedProductWithRevision(
      5,
      { sellerRelationship: "reseller" },
      "r7-inf30"
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-inf30"),
        safeProduct({
          sellerRelationship: "reseller",
          category: "Toys > Chew Toy",
          productInputRevision: 6,
        })
      )
    );
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(
        doc(context.firestore(), "businesses/biz-1/products/r7-inf30")
      );
      assert.equal(snap.data().sellerRelationship, "reseller");
    });
  }
);

// --- Regression: unauthorized writes, server-owned protection,
// category safety, and public read remain unchanged (items 31-35) ---

rulesTest(
  "4.2r7-regression-32. unauthorized create is still rejected even with a valid sellerRelationship included",
  async () => {
    await resetSeed();
    const db = (await env()).unauthenticatedContext().firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-reg32"),
        safeProduct({ sellerRelationship: "reseller" })
      )
    );
  }
);

rulesTest(
  "4.2r7-regression-33. the five real server-owned compliance fields remain forbidden even alongside a valid sellerRelationship",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-reg33"),
        safeProduct({
          sellerRelationship: "reseller",
          complianceEffectiveStatus: "verified_valid",
        })
      )
    );
  }
);

rulesTest(
  "4.2r7-regression-34. an unsafe category is still rejected even with a valid sellerRelationship and correct revision",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-reg34"),
        safeProduct({
          category: "Health > Medicine",
          sellerRelationship: "reseller",
          productInputRevision: 0,
        })
      )
    );
  }
);

rulesTest(
  "4.2r7-regression-35. public read of an approved+active product carrying a valid sellerRelationship is unaffected — no compliance read gate introduced",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/r7-reg35"),
        safeProduct({
          isActive: true,
          moderationStatus: "approved",
          sellerRelationship: "reseller",
        })
      );
    });
    // Revision 38 §0.36 B — still no compliance read gate in Rules; the
    // public branch is simply gone. A valid `sellerRelationship` changes
    // nothing about that.
    const db = rulesEnv.unauthenticatedContext().firestore();
    await assertFails(
      getDoc(doc(db, "businesses/biz-1/products/r7-reg35"))
    );
  }
);

// --- Static: no new cross-document read, gate, lock, callable, trigger,
// migration, or Slice 4.9 behavior was introduced (item 36). Plain
// test(), not rulesTest() — this is a pure source-text scan of the
// already-loaded `rules` string and needs no emulator. ---

test(
  "4.2r7-static-36. no new get()/exists()-shaped call was introduced by the sellerRelationship functions",
  () => {
    const startMarker = "function isValidSellerRelationshipValue";
    const endMarker = "function isSafeNewProductSubmission";
    const startIdx = rules.indexOf(startMarker);
    const endIdx = rules.indexOf(endMarker);
    assert.ok(
      startIdx >= 0 && endIdx > startIdx,
      "sellerRelationship block not found in firestore.rules"
    );
    const block = rules.slice(startIdx, endIdx);
    assert.equal(/\bget\s*\(/.test(block), false, "no get() call expected");
    assert.equal(
      /\bexists\s*\(/.test(block),
      false,
      "no exists() call expected"
    );
    assert.equal(
      /\bexistsAfter\s*\(/.test(block),
      false,
      "no existsAfter() call expected"
    );
    assert.equal(
      /\bgetAfter\s*\(/.test(block),
      false,
      "no getAfter() call expected"
    );
  }
);

// Item 37 (no skip/todo/environment bypass) is a property of this file's
// own authorship — no .skip()/.todo() call was added anywhere above; it
// is not separately re-asserted here.

// ---------------------------------------------------------------------
// Marketplace P1-A Slice 4.10 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §0.17 Phase 12, §9.E,
// committed Revision 19) — SKU raw-equality on update, §15 items
// 512-514.
// ---------------------------------------------------------------------

async function seedProductWithSku(sku, productId = "sku-target") {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), `businesses/biz-1/products/${productId}`),
      safeProduct({ sku })
    );
  });
  return productId;
}

rulesTest(
  "512. a seller update changing only sku to a genuinely different value is rejected",
  async () => {
    await resetSeed();
    const productId = await seedProductWithSku("ABC-1", "sku-512");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ sku: "ABC-2" })
      )
    );
  }
);

rulesTest(
  "513. a seller update changing sku only by case is rejected — raw equality, not normalized equivalence",
  async () => {
    await resetSeed();
    const productId = await seedProductWithSku("ABC-1", "sku-513");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ sku: "abc-1" })
      )
    );
  }
);

rulesTest(
  "513b. a seller update changing sku only by leading/trailing whitespace is rejected",
  async () => {
    await resetSeed();
    const productId = await seedProductWithSku("ABC-1", "sku-513b");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ sku: " ABC-1 " })
      )
    );
  }
);

rulesTest(
  "514. an unrelated field edit that leaves sku exactly unchanged still succeeds",
  async () => {
    await resetSeed();
    const productId = await seedProductWithSku("ABC-1", "sku-514");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ sku: "ABC-1", price: 42 })
      )
    );
  }
);

rulesTest(
  "514b. sku remains unchanged (both sides absent) when the field is never set at all",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    const productId = "sku-514b";
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), `businesses/biz-1/products/${productId}`),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, `businesses/biz-1/products/${productId}`), {
        price: 42,
      })
    );
  }
);

// ---------------------------------------------------------------------
// Marketplace P1-A Slice 4.10 (§0.17 Phase 12, §9.E, committed Revision
// 19) — direct client-SDK product deletion is denied unconditionally,
// admin included, §15 items 515-517.
// ---------------------------------------------------------------------

rulesTest(
  "515. a seller cannot directly delete their own product",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/delete-target-1"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(
      deleteDoc(doc(db, "businesses/biz-1/products/delete-target-1"))
    );
  }
);

rulesTest(
  "515b. an unrelated authenticated user cannot directly delete another business's product",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/delete-target-2"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("seller-2").firestore();
    await assertFails(
      deleteDoc(doc(db, "businesses/biz-1/products/delete-target-2"))
    );
  }
);

rulesTest(
  "516. an authenticated admin client cannot directly delete a product either — allow delete is if false unconditionally",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/delete-target-3"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      deleteDoc(doc(db, "businesses/biz-1/products/delete-target-3"))
    );
  }
);

rulesTest(
  "517. an unauthenticated caller cannot directly delete a product",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/delete-target-4"),
        safeProduct()
      );
    });
    const db = rulesEnv.unauthenticatedContext().firestore();
    await assertFails(
      deleteDoc(doc(db, "businesses/biz-1/products/delete-target-4"))
    );
  }
);

rulesTest(
  "the server-authoritative deletion path is the only mechanism — Admin SDK (simulating deleteMarketplaceProduct's own server-side transaction) can still delete a product",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/delete-target-5"),
        safeProduct()
      );
      // Admin SDK writes bypass Rules entirely by construction — this is
      // the exact trust boundary `deleteMarketplaceProduct` itself
      // relies on; not a Rules permission, and not tested as one.
      await deleteDoc(doc(context.firestore(), "businesses/biz-1/products/delete-target-5"));
      const snap = await getDoc(
        doc(context.firestore(), "businesses/biz-1/products/delete-target-5")
      );
      assert.equal(snap.exists(), false);
    });
  }
);

// =======================================================================
// Marketplace P1-A media-cap enforcement prerequisite (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md
// §10.1 "Authoritative media-cap enforcement prerequisite", §17 step 21c,
// Revision 23 §0.21 dependency-boundary clarification).
//
// These tests prove the frozen Rules boundary itself, through the real
// Firestore emulator — never a static-source or regex substitute. They
// are local, dormant, emulator-only proof: this file's own change is not
// deployed by writing or running these tests, does not run the separate,
// later-authorized §17 step 21a compatibility inventory, and draws no
// conclusion about any real, currently-stored production document. Per
// the plan's own explicit disposition for this state: IMPLEMENTED AND
// TESTED LOCALLY — STEP 21c REVIEW PENDING 21a INVENTORY.
// =======================================================================

// ---------------------------------------------------------------------
// A. CREATE / new submission — isSafeNewProductSubmission()
// ---------------------------------------------------------------------

rulesTest("Revision 34 — direct client create denied (superseded: MEDIA-CAP-A1. create with media: [] is allowed)", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/media-a1"),
      safeProduct({ media: [] })
    )
  );
});

rulesTest(
  "Revision 34 — direct client create denied (superseded: MEDIA-CAP-A2. create with one valid media entry is allowed)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/media-a2"),
        safeProduct({ media: mediaList(1) })
      )
    );
  }
);

rulesTest(
  "Revision 34 — direct client create denied (superseded: MEDIA-CAP-A3. create with exactly 20 valid media entries is allowed)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/media-a3"),
        safeProduct({ media: mediaList(20) })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-A4. create with exactly 21 media entries is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/media-a4"),
        safeProduct({ media: mediaList(21) })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-A5. create with 25 media entries (well above the cap) is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/media-a5"),
        safeProduct({ media: mediaList(25) })
      )
    );
  }
);

rulesTest("MEDIA-CAP-A6. create with media missing entirely is denied", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  const payload = safeProduct();
  delete payload.media;
  await assertFails(
    setDoc(doc(db, "businesses/biz-1/products/media-a6"), payload)
  );
});

rulesTest("MEDIA-CAP-A7. create with media: null is denied", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/media-a7"),
      safeProduct({ media: null })
    )
  );
});

rulesTest("MEDIA-CAP-A8. create with media as a string is denied", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/media-a8"),
      safeProduct({ media: "not-a-list" })
    )
  );
});

rulesTest("MEDIA-CAP-A9. create with media as a map is denied", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/media-a9"),
      safeProduct({ media: { type: "image" } })
    )
  );
});

rulesTest("MEDIA-CAP-A10. create with media as a number is denied", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses/biz-1/products/media-a10"),
      safeProduct({ media: 5 })
    )
  );
});

rulesTest(
  "MEDIA-CAP-A11. create with media as a boolean is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/media-a11"),
        safeProduct({ media: true })
      )
    );
  }
);

// ---------------------------------------------------------------------
// B. UPDATE / resubmission — isSafeProductResubmission()
// ---------------------------------------------------------------------

async function seedMediaProduct(productId, media) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), `businesses/biz-1/products/${productId}`),
      safeProduct({ media })
    );
  });
  return productId;
}

rulesTest(
  "MEDIA-CAP-B1. resubmission with incoming media: [] is allowed",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b1", mediaList(3));
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ media: [] })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-B2. resubmission with one incoming media entry is allowed",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b2", []);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ media: mediaList(1) })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-B3. resubmission with exactly 20 incoming media entries is allowed",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b3", []);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ media: mediaList(20) })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-B4. resubmission with exactly 21 incoming media entries is denied",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b4", []);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ media: mediaList(21) })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-B5. a full-replacement resubmission whose payload omits media entirely is denied",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b5", mediaList(2));
    const db = (await env()).authenticatedContext("seller-1").firestore();
    const payload = safeProduct({ price: 42 });
    delete payload.media;
    await assertFails(
      setDoc(doc(db, `businesses/biz-1/products/${productId}`), payload)
    );
  }
);

rulesTest(
  "MEDIA-CAP-B6. resubmission with incoming media: null is denied",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b6", []);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ media: null })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-B7. resubmission with incoming media as a string is denied",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b7", []);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ media: "not-a-list" })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-B8. resubmission with incoming media as a map is denied",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b8", []);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ media: { type: "image" } })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-B9. resubmission with incoming media as a number is denied",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b9", []);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ media: 5 })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-B10. resubmission with incoming media as a boolean is denied",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b10", []);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ media: true })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-B11. an otherwise-unrelated merge update over a pre-existing, already-oversized media array is denied (the resulting incoming media remains oversized)",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b11", mediaList(25));
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, `businesses/biz-1/products/${productId}`), {
        price: 99,
      })
    );
  }
);

rulesTest(
  "MEDIA-CAP-B12. an otherwise-unrelated merge update over a pre-existing, already-malformed (non-list) media value is denied (the resulting incoming media remains malformed)",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b12", "not-a-list");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, `businesses/biz-1/products/${productId}`), {
        price: 99,
      })
    );
  }
);

rulesTest(
  "MEDIA-CAP-B13. an otherwise-unrelated merge update preserving exactly 20 pre-existing media entries remains allowed",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-b13", mediaList(20));
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, `businesses/biz-1/products/${productId}`), {
        price: 99,
      })
    );
  }
);

// ---------------------------------------------------------------------
// C. Regression/preservation — the media-cap predicate must not weaken
// any pre-existing invariant, proven here in explicit combination with a
// valid media boundary value rather than relying on the pre-existing
// suite's own (now media-defaulted) fixtures alone.
// ---------------------------------------------------------------------

rulesTest(
  "MEDIA-CAP-C1. unauthenticated creation is still denied even with otherwise-valid, ≤20-entry media",
  async () => {
    await resetSeed();
    const db = (await env()).unauthenticatedContext().firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/media-c1"),
        safeProduct({ media: mediaList(20) })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-C2. SKU immutability is still enforced on an otherwise-valid resubmission carrying exactly 20 media entries",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    const productId = "media-c2";
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), `businesses/biz-1/products/${productId}`),
        safeProduct({ sku: "ORIGINAL-SKU", media: mediaList(20) })
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, `businesses/biz-1/products/${productId}`),
        safeProduct({ sku: "CHANGED-SKU", media: mediaList(20) })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-C3. an unlisted/unknown field is still rejected on create even with otherwise-valid media",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/media-c3"),
        safeProduct({ media: mediaList(5), notARealField: "x" })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-C4. the productInputRevision Phase A create contract (nonzero present value rejected) is still enforced with otherwise-valid media",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/media-c4"),
        safeProduct({ media: mediaList(5), productInputRevision: 1 })
      )
    );
  }
);

rulesTest(
  "MEDIA-CAP-C5. direct client-SDK product deletion remains denied (allow delete: if false) regardless of the stored product's media",
  async () => {
    await resetSeed();
    const productId = await seedMediaProduct("media-c5", mediaList(20));
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      deleteDoc(doc(db, `businesses/biz-1/products/${productId}`))
    );
  }
);

rulesTest(
  "MEDIA-CAP-C6 (Revision 34). an ordinary, fully-valid server-created product with the full 20-entry media cap is readable end to end by its owning seller, and unreadable by a stranger",
  async () => {
    await resetSeed();
    // Fixture setup only — see seedProductAsTrustedServer. The operation
    // under test is the owner READ and the stranger's read denial, both of
    // which still run through authenticated clients against live Rules.
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/media-c6",
      safeProduct({ media: mediaList(20) })
    );
    const rulesEnv = await env();
    const ownerDb = rulesEnv.authenticatedContext("seller-1").firestore();
    const ref = doc(ownerDb, "businesses/biz-1/products/media-c6");
    await assertSucceeds(getDoc(ref));
    const snap = await getDoc(ref);
    assert.equal(snap.exists(), true);
    assert.equal(snap.data().media.length, 20);
    // The read contract is genuinely evaluated: a non-owner is denied the
    // same pending, inactive document.
    const strangerDb = rulesEnv.authenticatedContext("seller-2").firestore();
    await assertFails(
      getDoc(doc(strangerDb, "businesses/biz-1/products/media-c6"))
    );
  }
);

// =======================================================================
// Marketplace P1-A Step 21c2 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §10.1 "Marketplace
// seller-activation gate contract", §17 step 21c2, §15 items 679-701).
//
// These tests prove the frozen Rules boundary itself, through the real
// Firestore emulator — never a static-source or regex substitute. They
// are local, dormant, emulator-only proof: this file's own change is
// not deployed by writing or running these tests, does not run the
// separate, later-authorized §17 step 21a compatibility inventory, and
// draws no conclusion about any real, currently-stored production
// document. Per the plan's own explicit disposition for this state:
// SELLER-ACTIVATION GATE REQUIRED — STEP 21D RULES DEPLOYMENT BLOCKED.
// =======================================================================

const ACTIVE_TRUE = Object.freeze({
  active: true,
  grantedAt: null,
  grantedBy: "admin-1",
  revokedAt: null,
  revokedBy: null,
});

const REVOKED = Object.freeze({
  active: false,
  grantedAt: null,
  grantedBy: "admin-1",
  revokedAt: null,
  revokedBy: "admin-1",
});

async function setBusinessActivation(businessId, activationValue) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    // `updateDoc` with a plain (non-dotted) key fully replaces that
    // field's value — unlike `setDoc(..., {merge: true})`, which would
    // deep-merge into the already-seeded nested map and silently leave
    // stale sibling keys (e.g. a pre-seeded `active: true`) behind.
    await updateDoc(doc(db, "businesses", businessId), {
      marketplaceSellerActivation: activationValue === undefined ? deleteField() : activationValue,
    });
  });
}

// ---------------------------------------------------------------------
// A. CREATE — every fail-closed shape.
// ---------------------------------------------------------------------

rulesTest("Revision 34 — direct client create denied (superseded: SELLER-ACTIVATION-A1. create with active:true is allowed (otherwise-valid payload))", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a1"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A2. create with the activation object missing entirely is denied", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", undefined);
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a2"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A3. create with the activation object null is denied", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", null);
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a3"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A4. create with the activation object a string is denied", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", "active");
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a4"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A5. create with the activation object a list is denied", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", [true]);
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a5"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A6. create with the activation object a boolean is denied", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", true);
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a6"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A7. create with active missing from an otherwise-present map is denied", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", { grantedAt: null, grantedBy: "admin-1" });
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a7"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A8. create with active:null is denied", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", { ...ACTIVE_TRUE, active: null });
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a8"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A9. create with active as a string is denied", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", { ...ACTIVE_TRUE, active: "true" });
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a9"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A10. create with active as a number is denied", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", { ...ACTIVE_TRUE, active: 1 });
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a10"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A11. create with active as a map is denied", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", { ...ACTIVE_TRUE, active: { value: true } });
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a11"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A12. create with active as a list is denied", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", { ...ACTIVE_TRUE, active: [true] });
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a12"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A13. create with active:false is denied", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", REVOKED);
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-a13"), safeProduct()));
});

rulesTest("SELLER-ACTIVATION-A14. create against a business that does not exist at all is denied", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(doc(db, "businesses/biz-nonexistent/products/act-a14"), safeProduct({ businessId: "biz-nonexistent" }))
  );
});

// ---------------------------------------------------------------------
// B. UPDATE/RESUBMISSION — mirrors A exactly.
// ---------------------------------------------------------------------

rulesTest("SELLER-ACTIVATION-B1. resubmission with active:true is allowed", async () => {
  await resetSeed();
  const productId = await seedMediaProduct("act-b1", mediaList(1));
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertSucceeds(
    updateDoc(doc(db, `businesses/biz-1/products/${productId}`), { name: "Updated Name" })
  );
});

rulesTest("SELLER-ACTIVATION-B2. resubmission with the activation object missing entirely is denied", async () => {
  await resetSeed();
  const productId = await seedMediaProduct("act-b2", mediaList(1));
  await setBusinessActivation("biz-1", undefined);
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, `businesses/biz-1/products/${productId}`), { name: "Updated Name" })
  );
});

rulesTest("SELLER-ACTIVATION-B3. resubmission with the activation object null is denied", async () => {
  await resetSeed();
  const productId = await seedMediaProduct("act-b3", mediaList(1));
  await setBusinessActivation("biz-1", null);
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, `businesses/biz-1/products/${productId}`), { name: "Updated Name" })
  );
});

rulesTest("SELLER-ACTIVATION-B4. resubmission with the activation object a non-map value is denied", async () => {
  await resetSeed();
  const productId = await seedMediaProduct("act-b4", mediaList(1));
  await setBusinessActivation("biz-1", "active");
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, `businesses/biz-1/products/${productId}`), { name: "Updated Name" })
  );
});

rulesTest("SELLER-ACTIVATION-B5. resubmission with active missing is denied", async () => {
  await resetSeed();
  const productId = await seedMediaProduct("act-b5", mediaList(1));
  await setBusinessActivation("biz-1", { grantedAt: null, grantedBy: "admin-1" });
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, `businesses/biz-1/products/${productId}`), { name: "Updated Name" })
  );
});

rulesTest("SELLER-ACTIVATION-B6. resubmission with active:null is denied", async () => {
  await resetSeed();
  const productId = await seedMediaProduct("act-b6", mediaList(1));
  await setBusinessActivation("biz-1", { ...ACTIVE_TRUE, active: null });
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, `businesses/biz-1/products/${productId}`), { name: "Updated Name" })
  );
});

rulesTest("SELLER-ACTIVATION-B7. resubmission with active as a string is denied", async () => {
  await resetSeed();
  const productId = await seedMediaProduct("act-b7", mediaList(1));
  await setBusinessActivation("biz-1", { ...ACTIVE_TRUE, active: "yes" });
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, `businesses/biz-1/products/${productId}`), { name: "Updated Name" })
  );
});

rulesTest("SELLER-ACTIVATION-B8. resubmission with active as a number is denied", async () => {
  await resetSeed();
  const productId = await seedMediaProduct("act-b8", mediaList(1));
  await setBusinessActivation("biz-1", { ...ACTIVE_TRUE, active: 1 });
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, `businesses/biz-1/products/${productId}`), { name: "Updated Name" })
  );
});

rulesTest("SELLER-ACTIVATION-B9. resubmission with active as a map/list is denied", async () => {
  await resetSeed();
  const productId = await seedMediaProduct("act-b9", mediaList(1));
  await setBusinessActivation("biz-1", { ...ACTIVE_TRUE, active: [true] });
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, `businesses/biz-1/products/${productId}`), { name: "Updated Name" })
  );
});

rulesTest("SELLER-ACTIVATION-B10. resubmission with active:false (revoked seller) is denied", async () => {
  await resetSeed();
  const productId = await seedMediaProduct("act-b10", mediaList(1));
  await setBusinessActivation("biz-1", REVOKED);
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, `businesses/biz-1/products/${productId}`), { name: "Updated Name" })
  );
});

// ---------------------------------------------------------------------
// C. Sector selection is irrelevant — only activation controls.
// ---------------------------------------------------------------------

rulesTest(
  "SELLER-ACTIVATION-C1. a business with a Petshop-aliased sector but no activation is still denied",
  async () => {
    await resetSeed();
    await setBusinessActivation("biz-1", undefined);
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "businesses", "biz-1"), { sectors: ["pet_shop"] }, { merge: true });
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-c1"), safeProduct()));
  }
);

rulesTest(
  "Revision 34 — direct client create denied (superseded: SELLER-ACTIVATION-C2. a business with a non-Petshop sector but active:true is still allowed)",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "businesses", "biz-1"), { sectors: ["veterinary"] }, { merge: true });
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-c2"), safeProduct()));
  }
);

rulesTest(
  "SELLER-ACTIVATION-C3. a multi-sector business without activation is denied regardless of how many sectors it carries",
  async () => {
    await resetSeed();
    await setBusinessActivation("biz-1", undefined);
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses", "biz-1"),
        { sectors: ["veterinary", "pet_shop", "groomer"] },
        { merge: true }
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-c3"), safeProduct()));
  }
);

// ---------------------------------------------------------------------
// D. Client mutation of the activation object is always denied.
// ---------------------------------------------------------------------

rulesTest("SELLER-ACTIVATION-D1. the owning seller cannot directly overwrite the activation object", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    updateDoc(doc(db, "businesses", "biz-1"), { marketplaceSellerActivation: ACTIVE_TRUE })
  );
});

rulesTest("SELLER-ACTIVATION-D2. the owning seller cannot merge-write only the active field", async () => {
  await resetSeed();
  await setBusinessActivation("biz-1", undefined);
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(doc(db, "businesses", "biz-1"), { marketplaceSellerActivation: ACTIVE_TRUE }, { merge: true })
  );
});

rulesTest("SELLER-ACTIVATION-D3. the owning seller cannot set a nested dotted-path active field", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  // Set to a genuinely *different* value than the already-seeded
  // `active: true` — Rules' own `diff().affectedKeys()` only reports
  // keys whose value actually changes, so writing the already-current
  // value would be a false-negative test, not a true bypass proof.
  await assertFails(updateDoc(doc(db, "businesses", "biz-1"), { "marketplaceSellerActivation.active": false }));
});

rulesTest(
  "SELLER-ACTIVATION-D4. the owning seller cannot alter only the audit-metadata sub-fields, leaving active untouched",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses", "biz-1"), { "marketplaceSellerActivation.grantedBy": "seller-1" })
    );
  }
);

rulesTest("SELLER-ACTIVATION-D5. the owning seller cannot delete the activation field", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(updateDoc(doc(db, "businesses", "biz-1"), { marketplaceSellerActivation: deleteField() }));
});

rulesTest(
  "SELLER-ACTIVATION-D6. an unrelated authenticated user cannot write another business's activation object",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-2").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses", "biz-1"), { marketplaceSellerActivation: ACTIVE_TRUE })
    );
  }
);

rulesTest("SELLER-ACTIVATION-D7. an unauthenticated write attempt is denied", async () => {
  await resetSeed();
  const db = (await env()).unauthenticatedContext().firestore();
  await assertFails(
    updateDoc(doc(db, "businesses", "biz-1"), { marketplaceSellerActivation: ACTIVE_TRUE })
  );
});

rulesTest(
  "SELLER-ACTIVATION-D8. a direct product-path write forging active:true inline on the product document itself has no effect — the gate reads only the business document",
  async () => {
    await resetSeed();
    await setBusinessActivation("biz-1", undefined);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/act-d8"), safeProduct({ marketplaceSellerActivation: ACTIVE_TRUE }))
    );
  }
);

// ---------------------------------------------------------------------
// E. Preservation — every already-frozen constraint composes correctly
//    with the new predicate under an otherwise-active seller.
// ---------------------------------------------------------------------

rulesTest("Revision 34 — direct client create denied (superseded: SELLER-ACTIVATION-E1. media 20 allowed under an active seller)", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-e1"), safeProduct({ media: mediaList(20) })));
});

rulesTest("SELLER-ACTIVATION-E2. media 21 denied under an active seller", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-e2"), safeProduct({ media: mediaList(21) })));
});

rulesTest("SELLER-ACTIVATION-E3. missing/non-list media denied under an active seller", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  const payload = safeProduct();
  delete payload.media;
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-e3"), payload));
});

rulesTest("SELLER-ACTIVATION-E4. SKU immutability is still enforced under an active seller", async () => {
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "businesses/biz-1/products/act-e4"), safeProduct({ sku: "SKU-1" }));
  });
  const db = rulesEnv.authenticatedContext("seller-1").firestore();
  await assertFails(updateDoc(doc(db, "businesses/biz-1/products/act-e4"), { sku: "SKU-2" }));
});

rulesTest("SELLER-ACTIVATION-E5. the productInputRevision Phase A create contract is still enforced under an active seller", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(
    setDoc(doc(db, "businesses/biz-1/products/act-e5"), safeProduct({ productInputRevision: 1 }))
  );
});

rulesTest("SELLER-ACTIVATION-E6. an unknown/unlisted field is still rejected under an active seller", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-e6"), safeProduct({ unlistedField: "x" })));
});

rulesTest(
  "SELLER-ACTIVATION-E7. the moderation/isActive create-time constraints are still enforced under an active seller",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(setDoc(doc(db, "businesses/biz-1/products/act-e7"), safeProduct({ isActive: true })));
  }
);

rulesTest("SELLER-ACTIVATION-E8. direct product deletion remains denied regardless of activation state", async () => {
  await resetSeed();
  const productId = await seedMediaProduct("act-e8", mediaList(1));
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertFails(deleteDoc(doc(db, `businesses/biz-1/products/${productId}`)));
});

// =======================================================================
// Marketplace P1-A Step 21c2 closing-audit correction (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md
// §10.1 "Marketplace seller-activation gate contract"): a self-
// registering user's own initial `businesses/{businessId}` create must
// never be able to seed `marketplaceSellerActivation`, in any shape or
// value — only the two authorized admin-only server operations may
// ever write this key, on create or update alike. These tests prove
// the corrected `allow create` predicate's own key-exclusion, through
// the real Firestore emulator.
// =======================================================================

function validBusinessCreatePayload(overrides = {}) {
  return {
    ownerUid: "seller-new-1",
    contact: { email: "seller-new-1@example.test" },
    status: "pending",
    published: false,
    ...overrides,
  };
}

rulesTest(
  "SELLER-ACTIVATION-CREATE-1. an ordinary, otherwise-valid business create without marketplaceSellerActivation still succeeds",
  async () => {
    const rulesEnv = await env();
    const db = rulesEnv.authenticatedContext("seller-new-1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "businesses", "biz-new-1"), validBusinessCreatePayload())
    );
    // Precondition-safety: prove the document really was created and
    // really carries no activation field, so later denial tests below
    // cannot be mistaken for this same document already being blocked
    // for an unrelated reason.
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(doc(context.firestore(), "businesses", "biz-new-1"));
      assert.equal(snap.exists(), true);
      assert.equal(snap.data().marketplaceSellerActivation, undefined);
    });
  }
);

rulesTest(
  "SELLER-ACTIVATION-CREATE-2. a forged complete active:true object is denied",
  async () => {
    const db = (await env()).authenticatedContext("seller-new-2").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses", "biz-new-2"),
        validBusinessCreatePayload({
          ownerUid: "seller-new-2",
          marketplaceSellerActivation: {
            active: true,
            grantedAt: null,
            grantedBy: "seller-new-2",
            revokedAt: null,
            revokedBy: null,
          },
        })
      )
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-CREATE-3. a forged active:false object is also denied — key presence alone is prohibited, not merely a true value",
  async () => {
    const db = (await env()).authenticatedContext("seller-new-3").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses", "biz-new-3"),
        validBusinessCreatePayload({
          ownerUid: "seller-new-3",
          marketplaceSellerActivation: { active: false },
        })
      )
    );
  }
);

rulesTest("SELLER-ACTIVATION-CREATE-4. marketplaceSellerActivation: null is denied", async () => {
  const db = (await env()).authenticatedContext("seller-new-4").firestore();
  await assertFails(
    setDoc(
      doc(db, "businesses", "biz-new-4"),
      validBusinessCreatePayload({ ownerUid: "seller-new-4", marketplaceSellerActivation: null })
    )
  );
});

rulesTest(
  "SELLER-ACTIVATION-CREATE-5. an empty-map marketplaceSellerActivation is denied",
  async () => {
    const db = (await env()).authenticatedContext("seller-new-5").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses", "biz-new-5"),
        validBusinessCreatePayload({ ownerUid: "seller-new-5", marketplaceSellerActivation: {} })
      )
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-CREATE-6. malformed non-map values (string/number/list/boolean) are all denied",
  async () => {
    const rulesEnv = await env();
    const values = ["active", 1, [true], true];
    for (let i = 0; i < values.length; i++) {
      const db = rulesEnv.authenticatedContext(`seller-new-6-${i}`).firestore();
      await assertFails(
        setDoc(
          doc(db, "businesses", `biz-new-6-${i}`),
          validBusinessCreatePayload({
            ownerUid: `seller-new-6-${i}`,
            marketplaceSellerActivation: values[i],
          })
        )
      );
    }
  }
);

rulesTest(
  "SELLER-ACTIVATION-CREATE-7. a literal dotted-string field name is harmless even if not itself excluded — it can never satisfy hasActiveMarketplaceSellerActivation(), which reads only the exact nested marketplaceSellerActivation.active structure",
  async () => {
    const rulesEnv = await env();
    const db = rulesEnv.authenticatedContext("seller-new-7").firestore();
    // setDoc (create) has no dotted-path/nested-update syntax the way
    // updateDoc does — a JS object key containing a literal dot is
    // stored as one literal top-level field name, never a nested path.
    await assertSucceeds(
      setDoc(
        doc(db, "businesses", "biz-new-7"),
        validBusinessCreatePayload({
          ownerUid: "seller-new-7",
          "marketplaceSellerActivation.active": true,
        })
      )
    );
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(doc(context.firestore(), "businesses", "biz-new-7"));
      // The literal field exists, but the real nested structure does
      // not — proving this vector cannot satisfy the activation gate.
      assert.equal(snap.data()["marketplaceSellerActivation.active"], true);
      assert.equal(snap.data().marketplaceSellerActivation, undefined);
    });
    // Direct proof this is inert: a product write against this
    // business still fails the activation gate.
    await assertFails(
      setDoc(doc(db, "businesses/biz-new-7/products/inert-1"), safeProduct({ businessId: "biz-new-7" }))
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-CREATE-8. a serverTimestamp()/transform value inside the forged object is denied identically — transform sentinels do not affect key-presence detection",
  async () => {
    const db = (await env()).authenticatedContext("seller-new-8").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses", "biz-new-8"),
        validBusinessCreatePayload({
          ownerUid: "seller-new-8",
          marketplaceSellerActivation: {
            active: true,
            grantedAt: serverTimestamp(),
            grantedBy: "seller-new-8",
            revokedAt: null,
            revokedBy: null,
          },
        })
      )
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-CREATE-9. sector selection and other legacy fields never substitute for admin activation — the created business remains gate-inactive",
  async () => {
    const rulesEnv = await env();
    const db = rulesEnv.authenticatedContext("seller-new-9").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses", "biz-new-9"),
        validBusinessCreatePayload({ ownerUid: "seller-new-9", sectors: ["pet_shop"] })
      )
    );
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(doc(context.firestore(), "businesses", "biz-new-9"));
      assert.equal(snap.exists(), true);
      assert.equal(snap.data().marketplaceSellerActivation, undefined);
    });
    // Closes the loop end-to-end: a product write against this newly
    // self-registered, sector-selected, but never-admin-activated
    // business still fails the product-level activation gate.
    await assertFails(
      setDoc(doc(db, "businesses/biz-new-9/products/inert-2"), safeProduct({ businessId: "biz-new-9" }))
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-CREATE-10. after a valid business create, an owner update attempt against marketplaceSellerActivation remains denied — the create-time and update-time protections compose correctly",
  async () => {
    const rulesEnv = await env();
    const db = rulesEnv.authenticatedContext("seller-new-10").firestore();
    await assertSucceeds(
      setDoc(doc(db, "businesses", "biz-new-10"), validBusinessCreatePayload({ ownerUid: "seller-new-10" }))
    );
    await assertFails(
      updateDoc(doc(db, "businesses", "biz-new-10"), {
        marketplaceSellerActivation: { active: true, grantedAt: null, grantedBy: "seller-new-10", revokedAt: null, revokedBy: null },
      })
    );
  }
);

// =======================================================================
// Marketplace seller-activation admin client-SDK Rules hotfix (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md
// §10.1, Revision 28 closing reviews): the `allow create`/`allow update`
// rules on `match /businesses/{businessId}` historically OR'd `isAdmin()`
// against a narrower, owner-only branch that alone carried the
// `marketplaceSellerActivation` protection — an authenticated admin
// using the Firebase client SDK (never the Admin SDK, which bypasses
// Rules by construction) could forge or overwrite this field directly,
// and could delete a business document while its activation was still
// genuinely active. These tests prove the corrected, actor-agnostic
// `omitsMarketplaceSellerActivationOnCreate()`,
// `preservesMarketplaceSellerActivationOnUpdate()`, and
// `businessHasNoActiveMarketplaceSellerActivation()` predicates, through
// the real Firestore emulator, for both the admin and owner client-SDK
// paths. This hotfix does not touch, and these tests do not exercise,
// the deployed `grantMarketplaceSellerActivation`/
// `revokeMarketplaceSellerActivation` Admin SDK Functions themselves —
// Admin SDK writes bypass Rules entirely, by design, and are governed
// instead by their own source, tests, and the Step-21e-style writer
// audit, never by anything in this file.
// =======================================================================

function adminBusinessCreatePayload(overrides = {}) {
  return {
    ownerUid: "seller-hotfix-owned",
    contact: { email: "seller-hotfix-owned@example.test" },
    ...overrides,
  };
}

// ---------------------------------------------------------------------
// CREATE — admin client SDK.
// ---------------------------------------------------------------------

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-ADMIN-1. an ordinary admin business create without marketplaceSellerActivation still succeeds",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "businesses", "biz-hotfix-admin-1"), adminBusinessCreatePayload())
    );
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(doc(context.firestore(), "businesses", "biz-hotfix-admin-1"));
      assert.equal(snap.exists(), true);
      assert.equal(snap.data().marketplaceSellerActivation, undefined);
    });
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-ADMIN-2. admin create with active:true is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses", "biz-hotfix-admin-2"),
        adminBusinessCreatePayload({
          marketplaceSellerActivation: { active: true, grantedAt: null, grantedBy: "admin-1", revokedAt: null, revokedBy: null },
        })
      )
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-ADMIN-3. admin create with active:false is denied — key presence alone is prohibited, not merely a true value",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses", "biz-hotfix-admin-3"),
        adminBusinessCreatePayload({
          marketplaceSellerActivation: { active: false, grantedAt: null, grantedBy: "admin-1", revokedAt: null, revokedBy: "admin-1" },
        })
      )
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-ADMIN-4. admin create with marketplaceSellerActivation:null is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses", "biz-hotfix-admin-4"), adminBusinessCreatePayload({ marketplaceSellerActivation: null }))
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-ADMIN-5. admin create with an empty-map marketplaceSellerActivation is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses", "biz-hotfix-admin-5"), adminBusinessCreatePayload({ marketplaceSellerActivation: {} }))
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-ADMIN-6. admin create with a malformed map (present but not a well-formed activation shape) is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses", "biz-hotfix-admin-6"),
        adminBusinessCreatePayload({ marketplaceSellerActivation: { active: "yes", note: "not a bool" } })
      )
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-ADMIN-7. admin create with marketplaceSellerActivation as a string is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses", "biz-hotfix-admin-7"), adminBusinessCreatePayload({ marketplaceSellerActivation: "active" }))
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-ADMIN-8. admin create with marketplaceSellerActivation as a number is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses", "biz-hotfix-admin-8"), adminBusinessCreatePayload({ marketplaceSellerActivation: 1 }))
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-ADMIN-9. admin create with marketplaceSellerActivation as a list is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses", "biz-hotfix-admin-9"), adminBusinessCreatePayload({ marketplaceSellerActivation: [true] }))
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-ADMIN-10. admin create with marketplaceSellerActivation as a boolean is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses", "biz-hotfix-admin-10"), adminBusinessCreatePayload({ marketplaceSellerActivation: true }))
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-ADMIN-11. admin create with a serverTimestamp()-bearing activation object is denied identically — transform sentinels do not affect key-presence detection",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses", "biz-hotfix-admin-11"),
        adminBusinessCreatePayload({
          marketplaceSellerActivation: { active: true, grantedAt: serverTimestamp(), grantedBy: "admin-1", revokedAt: null, revokedBy: null },
        })
      )
    );
  }
);

// ---------------------------------------------------------------------
// CREATE — owner client SDK preservation (the pre-existing
// SELLER-ACTIVATION-CREATE-1..10 series above already proves this
// exhaustively; these two confirm it composes correctly alongside the
// hotfix's own shared, actor-agnostic helper).
// ---------------------------------------------------------------------

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-OWNER-12. an ordinary owner business create without activation still succeeds under the corrected shared predicate",
  async () => {
    const db = (await env()).authenticatedContext("seller-hotfix-owner-12").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses", "biz-hotfix-owner-12"),
        validBusinessCreatePayload({ ownerUid: "seller-hotfix-owner-12" })
      )
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-CREATE-OWNER-13. owner create is denied across representative activation value shapes under the corrected shared predicate",
  async () => {
    const rulesEnv = await env();
    const shapes = [
      { active: true, grantedAt: null, grantedBy: "x", revokedAt: null, revokedBy: null },
      { active: false, grantedAt: null, grantedBy: "x", revokedAt: null, revokedBy: null },
      null,
      {},
      "active",
      1,
      [true],
      true,
    ];
    for (let i = 0; i < shapes.length; i++) {
      const uid = `seller-hotfix-owner-13-${i}`;
      const db = rulesEnv.authenticatedContext(uid).firestore();
      await assertFails(
        setDoc(
          doc(db, "businesses", `biz-hotfix-owner-13-${i}`),
          validBusinessCreatePayload({ ownerUid: uid, marketplaceSellerActivation: shapes[i] })
        )
      );
    }
  }
);

// ---------------------------------------------------------------------
// UPDATE — admin client SDK.
// ---------------------------------------------------------------------

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-ADMIN-14. an ordinary admin update unrelated to activation still succeeds",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertSucceeds(updateDoc(doc(db, "businesses", "biz-1"), { status: "suspended" }));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-ADMIN-15. admin adding activation to a document where it was absent is denied",
  async () => {
    await resetSeed();
    await setBusinessActivation("biz-1", undefined);
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(updateDoc(doc(db, "businesses", "biz-1"), { marketplaceSellerActivation: ACTIVE_TRUE }));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-ADMIN-16. admin changing active false to true is denied",
  async () => {
    await resetSeed();
    await setBusinessActivation("biz-1", REVOKED);
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(updateDoc(doc(db, "businesses", "biz-1"), { "marketplaceSellerActivation.active": true }));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-ADMIN-17. admin changing active true to false is denied — only the designated revoke operation may do this",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(updateDoc(doc(db, "businesses", "biz-1"), { "marketplaceSellerActivation.active": false }));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-ADMIN-18. admin replacing the whole activation map is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses", "biz-1"), {
        marketplaceSellerActivation: { active: true, grantedAt: null, grantedBy: "admin-1", revokedAt: null, revokedBy: null },
      })
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-ADMIN-19. admin removing activation is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(updateDoc(doc(db, "businesses", "biz-1"), { marketplaceSellerActivation: deleteField() }));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-ADMIN-20. admin mutating one nested provenance field is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(updateDoc(doc(db, "businesses", "biz-1"), { "marketplaceSellerActivation.grantedBy": "admin-99" }));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-ADMIN-21. admin combining an activation mutation with an otherwise-valid update denies the entire write, atomically",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses", "biz-1"), {
        status: "suspended",
        "marketplaceSellerActivation.active": false,
      })
    );
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(doc(context.firestore(), "businesses", "biz-1"));
      // Neither half of the combined write took effect — proving this
      // is a single atomic denial, never a partial-field allowance.
      assert.equal(snap.data().status, "approved");
      assert.equal(snap.data().marketplaceSellerActivation.active, true);
    });
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-ADMIN-22. admin update preserving activation byte-for-byte while changing an allowed field succeeds",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertSucceeds(updateDoc(doc(db, "businesses", "biz-1"), { status: "suspended" }));
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(doc(context.firestore(), "businesses", "biz-1"));
      assert.equal(snap.data().status, "suspended");
      assert.equal(snap.data().marketplaceSellerActivation.active, true);
      assert.equal(snap.data().marketplaceSellerActivation.grantedBy, "admin-1");
    });
  }
);

// ---------------------------------------------------------------------
// UPDATE — owner client SDK.
// ---------------------------------------------------------------------

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-OWNER-23. an ordinary owner update unrelated to activation still succeeds",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses", "biz-1"), { contact: { email: "updated@example.test" } })
    );
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-OWNER-24. owner adding activation to a document where it was absent is denied",
  async () => {
    await resetSeed();
    await setBusinessActivation("biz-1", undefined);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(updateDoc(doc(db, "businesses", "biz-1"), { marketplaceSellerActivation: ACTIVE_TRUE }));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-OWNER-25. owner mutating the activation object is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(updateDoc(doc(db, "businesses", "biz-1"), { "marketplaceSellerActivation.active": false }));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-OWNER-26. owner removing activation is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(updateDoc(doc(db, "businesses", "biz-1"), { marketplaceSellerActivation: deleteField() }));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-UPDATE-OWNER-27. owner update preserving activation byte-for-byte while making an otherwise-allowed change succeeds",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses", "biz-1"), { contact: { email: "preserved-check@example.test" } })
    );
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(doc(context.firestore(), "businesses", "biz-1"));
      assert.equal(snap.data().contact.email, "preserved-check@example.test");
      assert.equal(snap.data().marketplaceSellerActivation.active, true);
    });
  }
);

// ---------------------------------------------------------------------
// DELETE — the zero-active-activation predicate, both client-SDK
// authorization branches.
// ---------------------------------------------------------------------

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-DELETE-28. owner delete with activation missing is allowed under the existing authorized delete contract",
  async () => {
    await resetSeed();
    await setBusinessActivation("biz-1", undefined);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(deleteDoc(doc(db, "businesses", "biz-1")));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-DELETE-29. admin client delete with activation missing is allowed under the existing authorized delete contract",
  async () => {
    await resetSeed();
    await setBusinessActivation("biz-2", undefined);
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertSucceeds(deleteDoc(doc(db, "businesses", "biz-2")));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-DELETE-30. owner delete with a valid inactive activation is allowed",
  async () => {
    await resetSeed();
    await setBusinessActivation("biz-1", REVOKED);
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(deleteDoc(doc(db, "businesses", "biz-1")));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-DELETE-31. admin client delete with a valid inactive activation is allowed",
  async () => {
    await resetSeed();
    await setBusinessActivation("biz-2", REVOKED);
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertSucceeds(deleteDoc(doc(db, "businesses", "biz-2")));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-DELETE-32. owner delete with a valid active activation is denied — the designated revoke operation must run first",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(deleteDoc(doc(db, "businesses", "biz-1")));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-DELETE-33. admin client delete with a valid active activation is denied — this is the BLOCKING gap this hotfix closes",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(deleteDoc(doc(db, "businesses", "biz-1")));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-DELETE-34. owner delete with a malformed activation is denied — fails closed",
  async () => {
    await resetSeed();
    await setBusinessActivation("biz-1", { active: "yes" });
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(deleteDoc(doc(db, "businesses", "biz-1")));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-DELETE-35. admin client delete with a malformed activation is denied — fails closed",
  async () => {
    await resetSeed();
    await setBusinessActivation("biz-2", "not-a-map");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(deleteDoc(doc(db, "businesses", "biz-2")));
  }
);

rulesTest(
  "SELLER-ACTIVATION-HOTFIX-DELETE-36. unauthenticated delete is denied regardless of activation state",
  async () => {
    await resetSeed();
    const db = (await env()).unauthenticatedContext().firestore();
    await assertFails(deleteDoc(doc(db, "businesses", "biz-1")));
  }
);

// =======================================================================
// Marketplace P1-A Revision 28 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §10.1 "Pilot Product Approval
// contract", §15 items 781-935): the product-level `pilotProductApproval`
// create-exclusion/update-immutability/content-binding predicates, and
// the business-level `marketplaceBusinessGenerationId`/
// `pilotActiveProductCount` product-side generation-match/delete-safety
// predicates. Every admin/owner client-SDK business-level protection for
// these two fields is already proven by the SELLER-ACTIVATION-HOTFIX-*
// series above (the shared helpers cover all three fields identically);
// this section covers the product-document-level predicates those tests
// do not reach.
// =======================================================================

rulesTest(
  "PILOT-1. a client can never create a product carrying pilotProductApproval, in any shape",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/pilot-1"),
        safeProduct({
          pilotProductApproval: { schemaVersion: 1, active: true, approvedAt: null, approvedBy: null, revokedAt: null, revokedBy: null, revokedByKind: null, allowedPilotCategory: "food", reviewedContentFingerprint: "x", reviewedProductRevision: 0, reasonCode: "pilot_approved" },
        })
      )
    );
  }
);

rulesTest(
  "PILOT-2. an admin client-SDK create is denied identically",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/pilot-2"),
        safeProduct({ pilotProductApproval: { active: true } })
      )
    );
  }
);

async function seedPilotApprovedProduct(productId, overrides = {}) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "businesses/biz-1/products", productId),
      safeProduct({
        isActive: true,
        moderationStatus: "approved",
        pilotProductApproval: {
          schemaVersion: 1,
          active: true,
          approvedAt: serverTimestamp(),
          approvedBy: "admin-1",
          revokedAt: null,
          revokedBy: null,
          revokedByKind: null,
          allowedPilotCategory: "food",
          reviewedContentFingerprint: "fixture-fingerprint",
          reviewedProductRevision: 0,
          reasonCode: "pilot_approved",
        },
        ...overrides,
      })
    );
  });
}

rulesTest(
  "PILOT-3. the owning seller cannot directly overwrite pilotProductApproval on an approved product",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("pilot-3");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pilot-3"), {
        "pilotProductApproval.active": false,
      })
    );
  }
);

rulesTest(
  "PILOT-4. an admin client-SDK update cannot mutate pilotProductApproval either",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("pilot-4");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pilot-4"), {
        "pilotProductApproval.active": false,
      })
    );
  }
);

rulesTest(
  "PILOT-5. a bound-field edit (name) on an approved product is denied unconditionally",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("pilot-5");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pilot-5"), { name: "Changed Name" })
    );
  }
);

rulesTest(
  "PILOT-6. a bound-field edit that also attempts to self-revoke pilotProductApproval.active is denied — no client escape hatch",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("pilot-6");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pilot-6"), {
        name: "Changed Name",
        "pilotProductApproval.active": false,
      })
    );
  }
);

rulesTest(
  "PILOT-7. a harmless, non-bound-field edit (stock) is ALSO denied while isActive:true — the pre-existing, unconditional incoming.isActive == false resubmission requirement fires first, independent of the new bound-field predicate",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("pilot-7");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(updateDoc(doc(db, "businesses/biz-1/products/pilot-7"), { stock: 9 }));
  }
);

rulesTest(
  "PILOT-7b. after the seller-authorized unpublish-for-revision transition (isActive:false, pilotProductApproval.active:false), the identical harmless stock edit succeeds — proving the pre-edit unpublish flow is the correct, and only, path back to ordinary editing",
  async () => {
    const rulesEnv = await env();
    await resetSeed();
    await seedPilotApprovedProduct("pilot-7b");
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "businesses/biz-1/products/pilot-7b"), {
        isActive: false,
        moderationStatus: "pending_review",
        "pilotProductApproval.active": false,
      });
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertSucceeds(updateDoc(doc(db, "businesses/biz-1/products/pilot-7b"), { stock: 9 }));
  }
);

rulesTest(
  "PILOT-8. a bound-field edit on a never-approved product (pilotProductApproval absent) is unaffected by the new predicate",
  async () => {
    await resetSeed();
    await seedMediaProduct("pilot-8", mediaList(1));
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/pilot-8"), { name: "Renamed" })
    );
  }
);

rulesTest(
  "PILOT-9. a product create submitting a marketplaceBusinessGenerationId that does not match the live business value is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/pilot-9"),
        safeProduct({ marketplaceBusinessGenerationId: "wrong-generation" })
      )
    );
  }
);

rulesTest(
  "PILOT-10. a product create omitting marketplaceBusinessGenerationId entirely is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    const payload = safeProduct();
    delete payload.marketplaceBusinessGenerationId;
    await assertFails(setDoc(doc(db, "businesses/biz-1/products/pilot-10"), payload));
  }
);

rulesTest(
  "PILOT-11. a product create against a business with no generation ID at all (legacy/never-granted) is denied",
  async () => {
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "businesses", "biz-nogen"), {
        ownerUid: "seller-nogen",
        marketplaceSellerActivation: { active: true, grantedAt: null, grantedBy: "admin-1", revokedAt: null, revokedBy: null },
      });
    });
    const db = rulesEnv.authenticatedContext("seller-nogen").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-nogen/products/pilot-11"),
        safeProduct({ businessId: "biz-nogen", marketplaceBusinessGenerationId: "anything" })
      )
    );
  }
);

rulesTest(
  "PILOT-12. marketplaceBusinessGenerationId is immutable after create — an owner edit attempting to change it is denied",
  async () => {
    await resetSeed();
    await seedMediaProduct("pilot-12", mediaList(1));
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pilot-12"), {
        marketplaceBusinessGenerationId: "different-generation",
      })
    );
  }
);

rulesTest(
  "PILOT-13. a direct owner business delete is denied while pilotActiveProductCount is positive",
  async () => {
    const rulesEnv = await env();
    await resetSeed();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "businesses", "biz-1"), { pilotActiveProductCount: 1 });
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(deleteDoc(doc(db, "businesses", "biz-1")));
  }
);

rulesTest(
  "PILOT-14. an admin client-SDK business delete is denied identically while pilotActiveProductCount is positive",
  async () => {
    const rulesEnv = await env();
    await resetSeed();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "businesses", "biz-1"), { pilotActiveProductCount: 1 });
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(deleteDoc(doc(db, "businesses", "biz-1")));
  }
);

rulesTest(
  "PILOT-15. a business delete with pilotActiveProductCount == 0 and no active seller activation is allowed",
  async () => {
    const rulesEnv = await env();
    await resetSeed();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "businesses", "biz-1"), {
        marketplaceSellerActivation: { active: false, grantedAt: null, grantedBy: "admin-1", revokedAt: null, revokedBy: "admin-1" },
        pilotActiveProductCount: 0,
      });
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertSucceeds(deleteDoc(doc(db, "businesses", "biz-1")));
  }
);

rulesTest(
  "PILOT-16. a business delete with a malformed pilotActiveProductCount is denied — fails closed",
  async () => {
    const rulesEnv = await env();
    await resetSeed();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), "businesses", "biz-1"), {
        marketplaceSellerActivation: { active: false, grantedAt: null, grantedBy: "admin-1", revokedAt: null, revokedBy: "admin-1" },
        pilotActiveProductCount: "not-a-number",
      });
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(deleteDoc(doc(db, "businesses", "biz-1")));
  }
);

rulesTest(
  "PILOT-17. the pilotProductApprovalAuditEvents collection is fully client-immutable, admin-read-only",
  async () => {
    const rulesEnv = await env();
    const adminDb = rulesEnv.authenticatedContext("admin-1").firestore();
    const sellerDb = rulesEnv.authenticatedContext("seller-1").firestore();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", "admin-1"), { role: "admin" });
      await setDoc(doc(context.firestore(), "pilotProductApprovalAuditEvents", "evt-1"), { businessId: "biz-1" });
    });
    await assertSucceeds(getDoc(doc(adminDb, "pilotProductApprovalAuditEvents", "evt-1")));
    await assertFails(getDoc(doc(sellerDb, "pilotProductApprovalAuditEvents", "evt-1")));
    await assertFails(setDoc(doc(adminDb, "pilotProductApprovalAuditEvents", "evt-2"), { businessId: "biz-1" }));
    await assertFails(deleteDoc(doc(adminDb, "pilotProductApprovalAuditEvents", "evt-1")));
  }
);

// =======================================================================
// Product publication admin client-SDK closure: the product `allow
// create`/`allow update` rules OR `isAdmin()` against
// `isSafeNewProductSubmission()`/`isSafeProductResubmission()` — the
// only place either function's own unconditional
// `isActive == false && moderationStatus == 'pending_review'`
// requirement was enforced. An authenticated admin using the Firebase
// client SDK could therefore set `isActive: true`/
// `moderationStatus: 'approved'` directly on any product, publishing it
// to public read without ever going through the admin-only
// `approvePilotProduct` Function — while `pilotProductApproval` itself
// stayed untouched, leaving a "published" product with no corresponding
// approval record. `hasUnpublishedProductPublicationState()` (new,
// firestore.rules) closes this: AND-ed onto both `allow create`/`allow
// update`, outside the `isAdmin()` OR, so the identical publication-
// state invariant applies to every client-SDK actor. Every other
// server-owned product field's own pre-existing, unrelated admin-bypass
// behavior (media cap, SKU/generation immutability, seller-activation
// gate, unknown-field rejection — all still inside
// `isSafeNewProductSubmission()`/`isSafeProductResubmission()`, which
// admin still ORs around) is unchanged and out of this narrow scope.
// =======================================================================

rulesTest(
  "Revision 34 — direct client create denied (superseded: PUBLICATION-1. a valid seller draft creation still succeeds, unaffected)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/pub-1"), safeProduct())
    );
  }
);

rulesTest(
  "Revision 34 — direct client create denied (superseded: PUBLICATION-2. an admin client-SDK creation with the exact legitimate safe draft values still succeeds)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/pub-2"), safeProduct())
    );
  }
);

rulesTest(
  "PUBLICATION-3. an admin client-SDK create with isActive: true is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/pub-3"),
        safeProduct({ isActive: true })
      )
    );
  }
);

rulesTest(
  "PUBLICATION-4. an admin client-SDK create with moderationStatus: 'approved' is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/pub-4"),
        safeProduct({ moderationStatus: "approved" })
      )
    );
  }
);

rulesTest(
  "PUBLICATION-5. an admin client-SDK create with an arbitrary unsafe moderationStatus value (not just 'approved') is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/pub-5"),
        safeProduct({ moderationStatus: "live" })
      )
    );
  }
);

rulesTest(
  "PUBLICATION-6. an admin client-SDK create with isActive/moderationStatus missing, null, or the wrong type is denied in every case",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    const cases = [
      (data) => delete data.isActive,
      (data) => (data.isActive = null),
      (data) => (data.isActive = "true"),
      (data) => delete data.moderationStatus,
      (data) => (data.moderationStatus = null),
      (data) => (data.moderationStatus = 42),
    ];
    for (let i = 0; i < cases.length; i++) {
      const data = safeProduct();
      cases[i](data);
      await assertFails(
        setDoc(doc(db, "businesses/biz-1/products", `pub-6-${i}`), data)
      );
    }
  }
);

rulesTest(
  "PUBLICATION-7. an admin client-SDK false-to-true isActive update is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-7"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pub-7"), { isActive: true })
    );
  }
);

rulesTest(
  "PUBLICATION-8. an admin client-SDK full-document replacement (setDoc, no merge) that sets isActive: true is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-8"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/pub-8"),
        safeProduct({ isActive: true })
      )
    );
  }
);

rulesTest(
  "PUBLICATION-9. an admin client-SDK merge-set (setDoc with merge: true) that sets isActive: true is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-9"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/pub-9"),
        { isActive: true },
        { merge: true }
      )
    );
  }
);

rulesTest(
  "PUBLICATION-10. an admin client-SDK dotted/field-path-form update (updateDoc(ref, \"isActive\", true)) is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-10"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pub-10"), "isActive", true)
    );
  }
);

rulesTest(
  "PUBLICATION-11. an admin client-SDK removal of isActive (deleteField()) is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-11"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pub-11"), {
        isActive: deleteField(),
      })
    );
  }
);

rulesTest(
  "PUBLICATION-12a. an admin client-SDK mutation of moderationStatus to 'approved' via update is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-12a"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pub-12a"), {
        moderationStatus: "approved",
      })
    );
  }
);

rulesTest(
  "PUBLICATION-12b. an admin client-SDK removal of moderationStatus (deleteField()) is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-12b"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pub-12b"), {
        moderationStatus: deleteField(),
      })
    );
  }
);

rulesTest(
  "PUBLICATION-13. an admin client-SDK cannot republish a product whose pilotProductApproval is currently revoked, by setting isActive: true alone",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-13"),
        safeProduct({
          pilotProductApproval: {
            schemaVersion: 1,
            active: false,
            approvedAt: serverTimestamp(),
            approvedBy: "admin-1",
            revokedAt: serverTimestamp(),
            revokedBy: "admin-1",
            revokedByKind: "admin",
            allowedPilotCategory: "food",
            reviewedContentFingerprint: "fixture-fingerprint",
            reviewedProductRevision: 0,
            reasonCode: "pilot_revoked_admin_manual",
          },
        })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pub-13"), {
        isActive: true,
      })
    );
  }
);

rulesTest(
  "PUBLICATION-14. an admin client-SDK cannot republish a product whose pilotProductApproval is entirely missing, by setting isActive: true alone",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-14"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pub-14"), {
        isActive: true,
      })
    );
  }
);

rulesTest(
  "PUBLICATION-15. an admin client-SDK cannot republish a product whose pilotProductApproval is malformed (a string, not a map), by setting isActive: true alone",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-15"),
        safeProduct({ pilotProductApproval: "not-a-map" })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pub-15"), {
        isActive: true,
      })
    );
  }
);

rulesTest(
  "PUBLICATION-16. a legacy product missing moderationStatus entirely still denies an admin update that touches only isActive — the resulting document's moderationStatus stays absent, never 'pending_review'",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const data = safeProduct();
      delete data.moderationStatus;
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-16"),
        data
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pub-16"), {
        isActive: true,
      })
    );
  }
);

rulesTest(
  "PUBLICATION-17. seller resubmission (an unrelated content edit, isActive/moderationStatus left at false/pending_review) remains valid",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-17"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/pub-17"),
        safeProduct({ name: "Updated Name" })
      )
    );
  }
);

rulesTest(
  "PUBLICATION-18. material-edit self-revocation behavior remains valid: after an (Admin-SDK-simulated) unpublish-for-revision, the seller's ordinary content edit still succeeds",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      // Simulates exactly what the real unpublishPilotProductForRevision
      // Function does (Admin SDK, bypasses Rules) — never invoked here.
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-18"),
        safeProduct({
          isActive: false,
          moderationStatus: "pending_review",
          pilotProductApproval: {
            schemaVersion: 1,
            active: false,
            approvedAt: serverTimestamp(),
            approvedBy: "admin-1",
            revokedAt: serverTimestamp(),
            revokedBy: null,
            revokedByKind: "seller_self_revision",
            allowedPilotCategory: "food",
            reviewedContentFingerprint: "fixture-fingerprint",
            reviewedProductRevision: 0,
            reasonCode: "pilot_revoked_content_changed",
          },
        })
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/pub-18"), {
        name: "Revised After Unpublish",
      })
    );
  }
);

rulesTest(
  "PUBLICATION-19. a safe, unrelated admin content edit on a still-pending product (never touching isActive/moderationStatus) remains valid",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-19"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/pub-19"), {
        brand: "Corrected Brand",
      })
    );
  }
);

rulesTest(
  "PUBLICATION-20. direct client-SDK product deletion remains denied for admin — unaffected by this change",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-20"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(deleteDoc(doc(db, "businesses/biz-1/products/pub-20")));
  }
);

rulesTest(
  "PUBLICATION-21. an owner who is also flagged admin (role overlap) still cannot publish directly via client SDK",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", "seller-1"), {
        role: "admin",
      });
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-21"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pub-21"), {
        isActive: true,
      })
    );
  }
);

rulesTest(
  "PUBLICATION-22. a simultaneous attempt to set both isActive: true and pilotProductApproval.active: true in one admin update is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-22"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pub-22"), {
        isActive: true,
        "pilotProductApproval.active": true,
      })
    );
  }
);

rulesTest(
  "PUBLICATION-22b. adding an unrelated/decoy extra field alongside isActive: true cannot sneak the publication mutation past hasUnpublishedProductPublicationState — it is an unconditional value check, not a key-pattern check",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/pub-22b"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/pub-22b"), {
        isActive: true,
        reviewedBy: "admin-1",
        someDecoyField: "harmless-looking-value",
      })
    );
  }
);

// --- Static-source proofs (below): these read the already-loaded `rules`
// string directly and need no emulator — plain test(), not rulesTest(),
// exactly mirroring "4.2r7-static-36" above. ---

// Revision 34 migration of PUBLICATION-23.
//
// §15 intent: a product write can never assert a published/active
// publication state, and an admin actor must not be able to OR its way past
// that — the predicate sits OUTSIDE the actor-authorization group.
//
// Old assertion: `hasUnpublishedProductPublicationState(request.resource.data)`
// is AND-ed onto BOTH `allow create: if (isAdmin() || isSafeNewProduct
// Submission()) && ...` and the matching `allow update`.
//
// New boundary: the create half is enforced by submitMarketplaceProduct,
// which stamps the publication state server-side rather than accepting it
// (proven in functions/test/submitMarketplaceProduct.test.js). The update
// half is unchanged and is still enforced exactly here, so that half of the
// assertion is retained verbatim — narrowed only by dropping the create
// clause, which no longer exists.
test(
  "PUBLICATION-23 (Revision 34). (static) hasUnpublishedProductPublicationState is AND-ed onto product allow update, structurally outside the isAdmin() OR; create no longer has an authorization branch to attach it to",
  () => {
    const updateMatch = rulesCode.match(
      /allow update: if \(isAdmin\(\) \|\| isSafeProductResubmission\(\)\)\s*&&[\s\S]{0,400}?;/
    );
    assert.ok(updateMatch, "product allow update rule not found in expected shape");
    assert.ok(
      updateMatch[0].includes("hasUnpublishedProductPublicationState(request.resource.data)"),
      "update rule must AND hasUnpublishedProductPublicationState outside the isAdmin() OR"
    );
    // The parenthesized (isAdmin() || ...) group closes before the && that
    // introduces the predicate — proving it sits outside, not inside, the
    // actor-authorization OR.
    assert.ok(
      /\)\s*&&[\s\S]*hasUnpublishedProductPublicationState/.test(updateMatch[0])
    );
    // Create carries no actor-authorization group at all any more.
    assert.match(productsRulesBlock, /allow create: if false;/);
    assert.equal(
      (productsRulesBlock.match(/allow create: if \(isAdmin\(\)/g) || []).length,
      0,
      "create must not regain an isAdmin() authorization branch"
    );
  }
);

// Revision 34 migration of PUBLICATION-24.
//
// §15 intent: exactly one products create rule and one products update rule
// exist, so no alternate path bypasses the publication closure.
//
// Old assertion: exactly one `allow create: if (isAdmin() ||
// isSafeNewProductSubmission())`, one matching update, and exactly three
// textual references to hasUnpublishedProductPublicationState (its
// definition plus both call sites).
//
// New boundary: the uniqueness invariant is unchanged and strictly
// stronger — the single create rule is now `if false`, and the predicate is
// referenced exactly twice (definition plus the surviving update call site).
test(
  "PUBLICATION-24 (Revision 34). (static) exactly one products allow-create (unconditionally false) and one products allow-update rule exist — no alternate path bypasses the closure",
  () => {
    const matchBlocks = rulesCode.match(/match \/\{path=\*\*\}\/products\/\{productId\}/g) || [];
    const createRules = productsRulesBlock.match(/allow create: if [^;]*;/g) || [];
    const updateRules = rulesCode.match(/allow update: if \(isAdmin\(\) \|\| isSafeProductResubmission\(\)\)/g) || [];
    const closureCalls = rulesCode.match(/hasUnpublishedProductPublicationState\(/g) || [];
    assert.equal(matchBlocks.length, 1, "exactly one products match block expected");
    assert.equal(createRules.length, 1, "exactly one products allow create rule expected");
    assert.equal(createRules[0].trim(), "allow create: if false;");
    assert.equal(updateRules.length, 1, "exactly one products allow update rule expected");
    // Once in the function definition itself, once in the update rule. The
    // create call site is gone because the create rule is unconditional.
    assert.equal(closureCalls.length, 2, "hasUnpublishedProductPublicationState must be defined once and called exactly once");
  }
);

// =======================================================================
// Admin client-SDK product-identity closure: `isSafeProductResubmission()`'s
// own SKU/businessId/createdAt/marketplaceBusinessGenerationId
// immutability, and `isSafeNewProductSubmission()`'s own generation-match
// requirement, were both reachable only through the non-admin branch of
// the `(isAdmin() || ...)` OR — an authenticated admin using the client
// SDK could reassign a product's business, forge its createdAt, mutate
// or remove its SKU, or mutate/remove its marketplaceBusinessGenerationId.
// `preservesProductIdentityOnUpdate()`/`hasValidProductGenerationBindingOnCreate()`
// (new, firestore.rules) close this, AND-ed onto both `allow create`/
// `allow update`, outside the `isAdmin()` OR — mirroring the identical
// mechanism already used for pilotProductApproval/publication-state
// above, and matching this contract's own explicitly frozen requirement
// (docs/plans/marketplace_p1a_compliance_review_implementation_plan_
// 2026-08-21.md §0.17 Phase 4 decision 10, §10.1 "Product binding,
// exact") that SKU and marketplaceBusinessGenerationId immutability
// apply to every caller, with no admin bypass path.
//
// Deliberately NOT included in this closure (confirmed by direct
// re-reading of the same plan document, §10.1 "Admin bypass, stated
// accurately"): the seller-activation gate and the media-cap predicate.
// That section states, in its own words, that `isAdmin()` bypassing
// both "is a pre-existing architectural fact, not a defect this
// contract introduces or is expected to close" — enforcement for the
// Admin-SDK/Functions side is explicitly assigned instead to §17 step
// 21e's Admin/Functions writer audit (already performed and passed).
// INTEGRITY-9 below is a regression lock proving this documented,
// intentional gap is unchanged by this closure — not a new protection.
// Unknown-field rejection, productInputRevision validation,
// sellerRelationship validation, category safety, and the pilot-
// approval bound-field content freeze have no explicit admin-inclusive
// requirement anywhere in the plan and are left untouched rather than
// guessed at — see the final report for this task, not this file, for
// that unresolved-decision list.
// =======================================================================

rulesTest(
  "Revision 34 — direct client create denied (superseded: INTEGRITY-1. a valid, safe admin draft creation still succeeds)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/int-1"), safeProduct())
    );
  }
);

rulesTest(
  "INTEGRITY-2. an admin client-SDK create with a missing marketplaceBusinessGenerationId is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    const data = safeProduct();
    delete data.marketplaceBusinessGenerationId;
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/int-2"), data)
    );
  }
);

rulesTest(
  "INTEGRITY-3. an admin client-SDK create with a mismatched (stale/foreign) marketplaceBusinessGenerationId is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/int-3"),
        safeProduct({ marketplaceBusinessGenerationId: BIZ_2_GENERATION_ID })
      )
    );
  }
);

rulesTest(
  "INTEGRITY-4. an admin client-SDK create with a malformed (non-string) marketplaceBusinessGenerationId is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/int-4"),
        safeProduct({ marketplaceBusinessGenerationId: 12345 })
      )
    );
  }
);

rulesTest(
  "INTEGRITY-5. an admin client-SDK SKU mutation on update is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-5"),
        safeProduct({ sku: "ORIGINAL-SKU" })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/int-5"), {
        sku: "CHANGED-SKU",
      })
    );
  }
);

rulesTest(
  "INTEGRITY-6. an admin client-SDK SKU removal (deleteField()) on update is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-6"),
        safeProduct({ sku: "ORIGINAL-SKU" })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/int-6"), {
        sku: deleteField(),
      })
    );
  }
);

rulesTest(
  "INTEGRITY-7. an admin client-SDK marketplaceBusinessGenerationId mutation on update is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-7"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/int-7"), {
        marketplaceBusinessGenerationId: BIZ_2_GENERATION_ID,
      })
    );
  }
);

rulesTest(
  "INTEGRITY-8. an admin client-SDK marketplaceBusinessGenerationId removal (deleteField()) on update is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-8"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/int-8"), {
        marketplaceBusinessGenerationId: deleteField(),
      })
    );
  }
);

rulesTest(
  // Revision 29 (§0.27 C) supersedes and closes what this test previously
  // asserted (and, until this revision, correctly proved) as a
  // deliberate, permanent, plan-frozen admin exception: an authenticated
  // admin could create a product for an inactive seller, or with
  // oversized media, via the client SDK. §0.27 C explicitly closes both,
  // without exception, identical to every other product-integrity
  // predicate — the earlier "Admin bypass, stated accurately" text is
  // preserved as a historical record in the plan (superseded in place,
  // not erased) but no longer describes current policy. Renamed and
  // flipped to assertFails to reflect the corrected, intended security
  // posture, rather than deleted, so this exact scenario remains
  // permanently regression-tested.
  "INTEGRITY-9. an admin client-SDK create for an inactive seller, and a separate admin create with oversized media, are both denied — the seller-activation gate and media cap no longer have any admin exception (Revision 29, §0.27 C)",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "businesses", "biz-inactive"), {
        ownerUid: "seller-inactive",
        marketplaceSellerActivation: { active: false },
        marketplaceBusinessGenerationId: "biz-inactive-generation",
      });
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    // Inactive seller activation: now denied, no exception.
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-inactive/products/int-9a"),
        safeProduct({
          businessId: "biz-inactive",
          marketplaceBusinessGenerationId: "biz-inactive-generation",
        })
      )
    );
    // Oversized media (21 entries): now denied, no exception.
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/int-9b"),
        safeProduct({ media: mediaList(21) })
      )
    );
  }
);

rulesTest(
  "INTEGRITY-10. an admin client-SDK seller/business reassignment on update is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-10"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/int-10"), {
        businessId: "biz-2",
      })
    );
  }
);

rulesTest(
  "INTEGRITY-11. an admin client-SDK createdAt forgery on update is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-11"),
        safeProduct({ createdAt: serverTimestamp() })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/int-11"), {
        createdAt: serverTimestamp(),
      })
    );
  }
);

rulesTest(
  "INTEGRITY-12. a full-document replacement (setDoc, no merge) cannot bypass SKU immutability",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-12"),
        safeProduct({ sku: "ORIGINAL-SKU" })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/int-12"),
        safeProduct({ sku: "CHANGED-SKU" })
      )
    );
  }
);

rulesTest(
  "INTEGRITY-13. a merge-set (setDoc with merge: true) cannot bypass SKU immutability",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-13"),
        safeProduct({ sku: "ORIGINAL-SKU" })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/int-13"),
        { sku: "CHANGED-SKU" },
        { merge: true }
      )
    );
  }
);

rulesTest(
  "INTEGRITY-14. a dotted/field-path-form update cannot bypass SKU immutability",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-14"),
        safeProduct({ sku: "ORIGINAL-SKU" })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/int-14"), "sku", "CHANGED-SKU")
    );
  }
);

rulesTest(
  "INTEGRITY-15. a simultaneous attempt to mutate sku, businessId, and marketplaceBusinessGenerationId together in one admin update is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-15"),
        safeProduct({ sku: "ORIGINAL-SKU" })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/int-15"), {
        sku: "CHANGED-SKU",
        businessId: "biz-2",
        marketplaceBusinessGenerationId: BIZ_2_GENERATION_ID,
      })
    );
  }
);

rulesTest(
  "INTEGRITY-16. a legacy document missing marketplaceBusinessGenerationId entirely cannot be 'normalized' by an admin update that adds a value — absence-to-presence is still a change, and is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const data = safeProduct();
      delete data.marketplaceBusinessGenerationId;
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-16"),
        data
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/int-16"), {
        marketplaceBusinessGenerationId: BIZ_1_GENERATION_ID,
      })
    );
  }
);

rulesTest(
  "INTEGRITY-17. seller resubmission that never touches sku/businessId/createdAt/marketplaceBusinessGenerationId remains valid, unaffected",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-17"),
        safeProduct({ sku: "ORIGINAL-SKU" })
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/int-17"),
        safeProduct({ sku: "ORIGINAL-SKU", name: "Updated Name" })
      )
    );
  }
);

rulesTest(
  "INTEGRITY-18. a safe admin content correction (brand) that never touches an identity field remains valid",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/int-18"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/int-18"), {
        brand: "Corrected Brand",
      })
    );
  }
);

// Revision 34 migration of INTEGRITY-19.
//
// §15 intent: product identity (businessId/sku/generation binding) is
// guarded on both write paths, outside the admin OR.
//
// Old assertion: `hasValidProductGenerationBindingOnCreate` AND-ed onto the
// create rule, `preservesProductIdentityOnUpdate` AND-ed onto the update
// rule, both structurally outside the isAdmin() OR.
//
// New boundary: the update half is unchanged and still asserted here. The
// create half moved to submitMarketplaceProduct, which derives the
// deterministic ID and the generation binding itself instead of accepting
// them from the caller (see the generation-collision tests in
// functions/test/submitMarketplaceProduct.test.js).
test(
  "INTEGRITY-19 (Revision 34). (static) preservesProductIdentityOnUpdate is AND-ed onto product allow update, structurally outside the isAdmin() OR; the create-side generation binding is now derived server-side",
  () => {
    const updateMatch = rulesCode.match(
      /allow update: if \(isAdmin\(\) \|\| isSafeProductResubmission\(\)\)\s*&&[\s\S]{0,400}?;/
    );
    assert.ok(updateMatch, "product allow update rule not found in expected shape");
    assert.ok(
      updateMatch[0].includes("preservesProductIdentityOnUpdate(request.resource.data, resource.data)"),
      "update rule must AND preservesProductIdentityOnUpdate outside the isAdmin() OR"
    );
    assert.ok(
      /\)\s*&&[\s\S]*preservesProductIdentityOnUpdate/.test(updateMatch[0])
    );
    // hasValidProductGenerationBindingOnCreate is retained as frozen
    // specification but must no longer be a reachable authorization branch.
    assert.equal(
      (productsRulesBlock.match(/allow create: if [^;]*hasValidProductGenerationBindingOnCreate/g) || []).length,
      0,
      "create must not call hasValidProductGenerationBindingOnCreate as live authorization"
    );
  }
);

// Revision 34 migration of INTEGRITY-20.
//
// §15 intent: the integrity guards each have exactly one call site, so no
// alternate rule bypasses them.
//
// Old assertion: one create rule, one update rule, and exactly two textual
// references each to hasValidProductGenerationBindingOnCreate (definition +
// create call) and preservesProductIdentityOnUpdate (definition + update
// call).
//
// New boundary: preservesProductIdentityOnUpdate is unchanged at two.
// hasValidProductGenerationBindingOnCreate now appears exactly once — its
// definition only — which is the precise, truthful statement that it is
// retained as executable specification with zero live call sites.
test(
  "INTEGRITY-20 (Revision 34). (static) exactly one products allow-create and one allow-update rule exist; preservesProductIdentityOnUpdate has exactly one call site and hasValidProductGenerationBindingOnCreate has none",
  () => {
    const matchBlocks = rulesCode.match(/match \/\{path=\*\*\}\/products\/\{productId\}/g) || [];
    const createRules = productsRulesBlock.match(/allow create: if [^;]*;/g) || [];
    const updateRules = rulesCode.match(/allow update: if \(isAdmin\(\) \|\| isSafeProductResubmission\(\)\)/g) || [];
    const generationBindingCalls = rulesCode.match(/hasValidProductGenerationBindingOnCreate\(/g) || [];
    const identityCalls = rulesCode.match(/preservesProductIdentityOnUpdate\(/g) || [];
    assert.equal(matchBlocks.length, 1, "exactly one products match block expected");
    assert.equal(createRules.length, 1, "exactly one products allow create rule expected");
    assert.equal(createRules[0].trim(), "allow create: if false;");
    assert.equal(updateRules.length, 1, "exactly one products allow update rule expected");
    // Definition only — retained as frozen specification, never invoked.
    assert.equal(generationBindingCalls.length, 1, "hasValidProductGenerationBindingOnCreate must be defined once and called zero times");
    // Once in the function definition itself, once in the update rule.
    assert.equal(identityCalls.length, 2, "preservesProductIdentityOnUpdate must be defined once and called exactly once");
  }
);

// =======================================================================
// Revision 29 (docs/plans/marketplace_p1a_compliance_review_
// implementation_plan_2026-08-21.md §0.27 "Actor-independent Marketplace
// product-integrity contract" — no-exception correction, commit
// a5b1a10): direct, real-emulator-backed coverage for the plan's own
// future test range, items 936-983 (48 items) — implemented now, exact
// 1:1 mapping, named REV29-1 through REV29-48 for traceability back to
// the plan's own item numbers (REV29-N corresponds to plan item
// 935+N). `hasSafeProductIntegrityOnCreate()`/`hasSafeProductIntegrityOnUpdate()`
// (new, firestore.rules) close every remaining admin-client-SDK gap
// named by §0.27 B: schema/unknown-field closure, media shape/cap,
// seller activation, business existence, `productInputRevision`,
// `sellerRelationship`, category safety, and (update-only) the
// approved-product bound-field content freeze — AND-ed onto both
// `allow create`/`allow update`, outside the `isAdmin()` OR, alongside
// the four already-closed predicates from commits `60f7997`/`affc328`/
// `dde655a`. No admin exception remains for any of them.
// =======================================================================

rulesTest(
  "Revision 34 — direct client create denied (superseded: REV29-1 (plan item 936). a safe admin draft create satisfying every integrity predicate succeeds)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/rev29-1"), safeProduct())
    );
  }
);

rulesTest(
  "REV29-2 (plan item 937). a safe admin content correction on an already-unpublished product succeeds",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-2"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-2"), {
        brand: "Corrected Brand",
      })
    );
  }
);

rulesTest(
  "REV29-3 (plan item 938). an admin client-SDK create with an unknown field is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/rev29-3"),
        safeProduct({ publicationOverride: true })
      )
    );
  }
);

rulesTest(
  "REV29-4 (plan item 939). an admin client-SDK update introducing an unknown field is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-4"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-4"), {
        publicationOverride: true,
      })
    );
  }
);

rulesTest(
  "REV29-5 (plan item 940). an admin client-SDK create with media not a list is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/rev29-5"),
        safeProduct({ media: "not-a-list" })
      )
    );
  }
);

rulesTest(
  "REV29-6 (plan item 941). an admin client-SDK update setting media to a non-list value is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-6"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-6"), {
        media: "not-a-list",
      })
    );
  }
);

rulesTest(
  "Revision 34 — direct client create denied (superseded: REV29-7 (plan item 942). an admin client-SDK create/update with exactly 20 media entries is accepted)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/rev29-7"),
        safeProduct({ media: mediaList(20) })
      )
    );
  }
);

rulesTest(
  "REV29-8 (plan item 943). an admin client-SDK create with 21 media entries is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/rev29-8"),
        safeProduct({ media: mediaList(21) })
      )
    );
  }
);

rulesTest(
  "REV29-9 (plan item 944). an admin client-SDK create with an invalid productInputRevision is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/rev29-9"),
        safeProduct({ productInputRevision: 5 })
      )
    );
  }
);

rulesTest(
  "REV29-10 (plan item 945). an admin client-SDK update with an invalid productInputRevision transition (present-to-absent) is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-10"),
        safeProduct({ productInputRevision: 0 })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-10"), {
        productInputRevision: deleteField(),
      })
    );
  }
);

rulesTest(
  "REV29-11 (plan item 946). an admin client-SDK create with an invalid sellerRelationship value is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/rev29-11"),
        safeProduct({ sellerRelationship: "not_a_real_relationship" })
      )
    );
  }
);

rulesTest(
  "REV29-12 (plan item 947). an admin client-SDK update with an invalid sellerRelationship transition (valid-to-absent) is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-12"),
        safeProduct({ sellerRelationship: "reseller" })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-12"), {
        sellerRelationship: deleteField(),
      })
    );
  }
);

rulesTest(
  "REV29-13 (plan item 948). an admin client-SDK create with a category outside the closed safe allowlist is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/rev29-13"),
        safeProduct({ category: "Health > Veterinary Medicine" })
      )
    );
  }
);

rulesTest(
  "REV29-14 (plan item 949). an admin client-SDK update changing category to a value outside the closed safe allowlist is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-14"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-14"), {
        category: "Health > Veterinary Medicine",
      })
    );
  }
);

rulesTest(
  "REV29-15 (plan item 950). an admin client-SDK create for a business with no marketplaceSellerActivation key at all is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "businesses", "biz-no-activation"), {
        ownerUid: "seller-no-activation",
        marketplaceBusinessGenerationId: "biz-no-activation-generation",
      });
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-no-activation/products/rev29-15"),
        safeProduct({
          businessId: "biz-no-activation",
          marketplaceBusinessGenerationId: "biz-no-activation-generation",
        })
      )
    );
  }
);

rulesTest(
  "REV29-16 (plan item 951). an admin client-SDK create for a business with marketplaceSellerActivation.active == false is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "businesses", "biz-inactive-2"), {
        ownerUid: "seller-inactive-2",
        marketplaceSellerActivation: { active: false },
        marketplaceBusinessGenerationId: "biz-inactive-2-generation",
      });
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-inactive-2/products/rev29-16"),
        safeProduct({
          businessId: "biz-inactive-2",
          marketplaceBusinessGenerationId: "biz-inactive-2-generation",
        })
      )
    );
  }
);

rulesTest(
  "REV29-17 (plan item 952). an admin client-SDK create for a business with a malformed marketplaceSellerActivation value is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "businesses", "biz-malformed-activation"), {
        ownerUid: "seller-malformed-activation",
        marketplaceSellerActivation: "active",
        marketplaceBusinessGenerationId: "biz-malformed-activation-generation",
      });
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-malformed-activation/products/rev29-17"),
        safeProduct({
          businessId: "biz-malformed-activation",
          marketplaceBusinessGenerationId: "biz-malformed-activation-generation",
        })
      )
    );
  }
);

rulesTest(
  "REV29-18 (plan item 953). an admin client-SDK create whose businessId names a business that does not exist is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-does-not-exist/products/rev29-18"),
        safeProduct({
          businessId: "biz-does-not-exist",
          marketplaceBusinessGenerationId: "any-value",
        })
      )
    );
  }
);

rulesTest(
  "REV29-19 (plan item 954). an admin client-SDK create for an existing business whose own marketplaceBusinessGenerationId is absent is denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "businesses", "biz-no-generation"), {
        ownerUid: "seller-no-generation",
        marketplaceSellerActivation: { active: true },
      });
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-no-generation/products/rev29-19"),
        safeProduct({
          businessId: "biz-no-generation",
          marketplaceBusinessGenerationId: "any-value",
        })
      )
    );
  }
);

rulesTest(
  "REV29-20 (plan item 955). an admin client-SDK create with a marketplaceBusinessGenerationId that does not match the business's own current value is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/rev29-20"),
        safeProduct({ marketplaceBusinessGenerationId: BIZ_2_GENERATION_ID })
      )
    );
  }
);

rulesTest(
  "REV29-21 (plan item 956). an admin client-SDK update changing name on an approved product is denied",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29-21");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-21"), {
        name: "Changed Name",
      })
    );
  }
);

rulesTest(
  "REV29-22 (plan item 957). an admin client-SDK update changing description on an approved product is denied",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29-22");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-22"), {
        description: "Changed description",
      })
    );
  }
);

rulesTest(
  "REV29-23 (plan item 958). an admin client-SDK update changing media on an approved product is denied",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29-23");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-23"), {
        media: [mediaEntry(0)],
      })
    );
  }
);

rulesTest(
  "REV29-24 (plan item 959). an admin client-SDK update changing category on an approved product is denied",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29-24");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-24"), {
        category: "Food > Dry Food",
      })
    );
  }
);

rulesTest(
  "REV29-25 (plan item 960). an admin client-SDK update changing price on an approved product is denied",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29-25");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-25"), {
        price: 999,
      })
    );
  }
);

rulesTest(
  "REV29-26 (plan item 961). an admin client-SDK update changing brand on an approved product is denied — brand is confirmed, by direct source reading of pilotApprovalBoundFields(), to be fingerprint/bound",
  async () => {
    assert.ok(
      rules.match(/function pilotApprovalBoundFields\(\)[\s\S]{0,300}?'brand'/),
      "brand must be present in pilotApprovalBoundFields() for this item's own premise to hold"
    );
    await resetSeed();
    await seedPilotApprovedProduct("rev29-26");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-26"), {
        brand: "Changed Brand",
      })
    );
  }
);

rulesTest(
  "REV29-27 (plan item 962). a full-document replacement (setDoc, no merge) attempting a bound-field edit on an approved product is denied",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29-27");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/rev29-27"),
        safeProduct({
          isActive: true,
          moderationStatus: "approved",
          name: "Changed Name",
          pilotProductApproval: {
            schemaVersion: 1,
            active: true,
            approvedAt: serverTimestamp(),
            approvedBy: "admin-1",
            revokedAt: null,
            revokedBy: null,
            revokedByKind: null,
            allowedPilotCategory: "food",
            reviewedContentFingerprint: "fixture-fingerprint",
            reviewedProductRevision: 0,
            reasonCode: "pilot_approved",
          },
        })
      )
    );
  }
);

rulesTest(
  "REV29-28 (plan item 963). a merge-set (setDoc with merge: true) attempting a bound-field edit on an approved product is denied",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29-28");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/rev29-28"),
        { name: "Changed Name" },
        { merge: true }
      )
    );
  }
);

rulesTest(
  "REV29-29 (plan item 964). a dotted/field-path-form update attempting a bound-field edit on an approved product is denied",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29-29");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-29"), "name", "Changed Name")
    );
  }
);

rulesTest(
  "REV29-30 (plan item 965). a single admin update simultaneously touching two bound fields on an approved product is denied in one evaluation",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29-30");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-30"), {
        name: "Changed Name",
        price: 999,
      })
    );
  }
);

rulesTest(
  "REV29-31 (plan item 966). an admin client-SDK update that touches a bound field while also attempting to set pilotProductApproval.active: false in the same write is denied — no client escape hatch",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29-31");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-31"), {
        name: "Changed Name",
        "pilotProductApproval.active": false,
      })
    );
  }
);

rulesTest(
  "REV29-32 (plan items 967/969). against a local Firestore emulator only (no Function invoked, no production contact): after an Admin-SDK-simulated unpublish/revoke transition, the subsequent ordinary content edit succeeds, and a further Admin-SDK-simulated fresh approval succeeds afterward",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      // Simulates exactly what the real revokePilotProductApproval/
      // unpublishPilotProductForRevision Function does (Admin SDK,
      // bypasses Rules) — never invoked here.
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-32"),
        safeProduct({
          isActive: false,
          moderationStatus: "pending_review",
          pilotProductApproval: {
            schemaVersion: 1,
            active: false,
            approvedAt: serverTimestamp(),
            approvedBy: "admin-1",
            revokedAt: serverTimestamp(),
            revokedBy: "admin-1",
            revokedByKind: "admin",
            allowedPilotCategory: "food",
            reviewedContentFingerprint: "fixture-fingerprint",
            reviewedProductRevision: 0,
            reasonCode: "pilot_revoked_admin_manual",
          },
        })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-32"), {
        name: "Revised After Unpublish",
      })
    );
    // A further, separate, Admin-SDK-simulated fresh approval succeeds
    // afterward — proving the edit did not leave the product in a state
    // that could never be re-approved.
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-32"),
        {
          isActive: true,
          moderationStatus: "approved",
          "pilotProductApproval.active": true,
          "pilotProductApproval.approvedAt": serverTimestamp(),
          "pilotProductApproval.revokedAt": null,
          "pilotProductApproval.reviewedContentFingerprint": "fresh-fingerprint",
        }
      );
    });
    const freshSnap = await getDoc(
      doc(rulesEnv.authenticatedContext("admin-1").firestore(), "businesses/biz-1/products/rev29-32")
    );
    assert.equal(freshSnap.data().isActive, true);
    assert.equal(freshSnap.data().pilotProductApproval.active, true);
  }
);

rulesTest(
  "REV29-33 (plan item 968). the product edited after unpublish remains isActive: false, moderationStatus: 'pending_review' immediately after the edit — the edit itself never republishes",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-33"),
        safeProduct({
          isActive: false,
          moderationStatus: "pending_review",
          pilotProductApproval: {
            schemaVersion: 1,
            active: false,
            approvedAt: serverTimestamp(),
            approvedBy: "admin-1",
            revokedAt: serverTimestamp(),
            revokedBy: null,
            revokedByKind: "seller_self_revision",
            allowedPilotCategory: "food",
            reviewedContentFingerprint: "fixture-fingerprint",
            reviewedProductRevision: 0,
            reasonCode: "pilot_revoked_content_changed",
          },
        })
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await updateDoc(doc(db, "businesses/biz-1/products/rev29-33"), {
      name: "Revised Name",
    });
    const snap = await getDoc(doc(db, "businesses/biz-1/products/rev29-33"));
    assert.equal(snap.data().isActive, false);
    assert.equal(snap.data().moderationStatus, "pending_review");
  }
);

rulesTest(
  "REV29-34 (plan item 969). a client-SDK attempt to set isActive/moderationStatus directly to a published state immediately after the unpublish-then-edit sequence, without a simulated Admin-SDK approval, is still denied — fresh approval is not client-reachable",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-34"),
        safeProduct({
          isActive: false,
          moderationStatus: "pending_review",
          pilotProductApproval: {
            schemaVersion: 1,
            active: false,
            approvedAt: serverTimestamp(),
            approvedBy: "admin-1",
            revokedAt: serverTimestamp(),
            revokedBy: "admin-1",
            revokedByKind: "admin",
            allowedPilotCategory: "food",
            reviewedContentFingerprint: "fixture-fingerprint",
            reviewedProductRevision: 0,
            reasonCode: "pilot_revoked_admin_manual",
          },
        })
      );
      await updateDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-34"),
        { name: "Revised Name" }
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-34"), {
        isActive: true,
        moderationStatus: "approved",
      })
    );
  }
);

rulesTest(
  "REV29-35 (plan item 970). a legacy product missing productInputRevision/sellerRelationship/category-valid entirely cannot be 'normalized' by an admin update that adds only a now-valid value for one field",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const data = safeProduct({ category: "Health > Veterinary Medicine" });
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-35"),
        data
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    // The legacy document's own pre-existing unsafe category makes every
    // update fail hasSafeProductIntegrityOnUpdate() unconditionally,
    // including one that changes only an unrelated field — an admin
    // cannot "unlock" this document with a partial, otherwise-unrelated
    // correction; the unsafe category must itself be corrected in the
    // very same write, and even that write must independently satisfy
    // every other predicate.
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-35"), {
        brand: "Attempted Unrelated Fix",
      })
    );
  }
);

rulesTest(
  "REV29-36 (plan item 971). a user who is simultaneously the product's own business owner and flagged role: admin cannot bypass any integrity predicate through either authorization branch",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", "seller-1"), {
        role: "admin",
      });
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-36"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-36"), {
        category: "Health > Veterinary Medicine",
      })
    );
  }
);

rulesTest(
  "REV29-37 (plan item 972). the complete PUBLICATION-* range (commit affc328) is unaffected — a direct spot-check: an admin client-SDK false-to-true isActive update is still denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-37"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-37"), { isActive: true })
    );
  }
);

rulesTest(
  "REV29-38 (plan item 973). the complete INTEGRITY-* range (commit dde655a) is unaffected — a direct spot-check: an admin client-SDK SKU mutation is still denied",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-38"),
        safeProduct({ sku: "ORIGINAL-SKU" })
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-38"), { sku: "CHANGED-SKU" })
    );
  }
);

rulesTest(
  "Revision 34 — direct client create denied (superseded: REV29-39 (plan item 974). ordinary seller product creation remains valid, unaffected by the consolidation of isSafeNewProductSubmission())",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/rev29-39"), safeProduct())
    );
  }
);

rulesTest(
  "REV29-40 (plan item 975). ordinary seller product resubmission remains valid, unaffected by the consolidation of isSafeProductResubmission()",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-40"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-40"), {
        name: "Updated Name",
      })
    );
  }
);

rulesTest(
  "REV29-41 (plan item 976). the material-edit/self-revocation lifecycle (PILOT-* range, commit 60f7997) is unaffected — a direct spot-check: a seller cannot directly overwrite pilotProductApproval on an approved product",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29-41");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29-41"), {
        "pilotProductApproval.active": false,
      })
    );
  }
);

rulesTest(
  "REV29-42 (plan item 977). audit-event client immutability remains unaffected — pilotProductApprovalAuditEvents stays fully client-immutable",
  async () => {
    const rulesEnv = await env();
    const adminDb = rulesEnv.authenticatedContext("admin-1").firestore();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", "admin-1"), { role: "admin" });
    });
    await assertFails(
      setDoc(doc(adminDb, "pilotProductApprovalAuditEvents", "rev29-42"), {
        businessId: "biz-1",
      })
    );
  }
);

rulesTest(
  "REV29-43 (plan item 978). direct client-SDK product deletion remains denied for every actor, unaffected",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29-43"),
        safeProduct()
      );
    });
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(deleteDoc(doc(db, "businesses/biz-1/products/rev29-43")));
  }
);

// Revision 34 migration of REV29-44 (plan item 979).
//
// §15 intent: name/price/stock/category value integrity is enforced on both
// write paths with no admin exception.
//
// Old assertion: `hasSafeProductIntegrityOnCreate` AND-ed onto the create
// rule and `hasSafeProductIntegrityOnUpdate` onto the update rule, both
// outside the isAdmin() OR.
//
// New boundary: the update half is unchanged and still asserted here. The
// create half is enforced by submitMarketplaceProduct's
// assertValidDraftValues, which mirrors hasSafeProductIntegrityOnCreate
// field-for-field and is strictly stricter (added length and finiteness
// bounds) — proven in functions/test/submitMarketplaceProduct.test.js.
test(
  "REV29-44 (Revision 34, plan item 979). (static) hasSafeProductIntegrityOnUpdate is AND-ed onto product allow update, structurally outside the isAdmin() OR; create-value integrity is enforced by submitMarketplaceProduct",
  () => {
    const updateMatch = rulesCode.match(
      /allow update: if \(isAdmin\(\) \|\| isSafeProductResubmission\(\)\)\s*&&[\s\S]{0,500}?;/
    );
    assert.ok(updateMatch, "product allow update rule not found in expected shape");
    assert.ok(
      updateMatch[0].includes("hasSafeProductIntegrityOnUpdate(request.resource.data, resource.data)"),
      "update rule must AND hasSafeProductIntegrityOnUpdate outside the isAdmin() OR"
    );
    assert.ok(
      /\)\s*&&[\s\S]*hasSafeProductIntegrityOnUpdate/.test(updateMatch[0])
    );
    assert.equal(
      (productsRulesBlock.match(/allow create: if [^;]*hasSafeProductIntegrityOnCreate/g) || []).length,
      0,
      "create must not call hasSafeProductIntegrityOnCreate as live authorization"
    );
  }
);

// Revision 34 migration of REV29-45 (plan item 980).
//
// §15 intent: each no-exception integrity guard has exactly one call site.
//
// Old assertion: two textual references each to
// hasSafeProductIntegrityOnCreate and hasSafeProductIntegrityOnUpdate.
//
// New boundary: the update guard is unchanged at two. The create guard now
// appears exactly once — its definition — which truthfully states that it is
// retained as frozen specification with no reachable call site.
test(
  "REV29-45 (Revision 34, plan item 980). (static) exactly one products allow-create and one allow-update rule exist; hasSafeProductIntegrityOnUpdate has exactly one call site and hasSafeProductIntegrityOnCreate has none",
  () => {
    const matchBlocks = rulesCode.match(/match \/\{path=\*\*\}\/products\/\{productId\}/g) || [];
    const createRules = productsRulesBlock.match(/allow create: if [^;]*;/g) || [];
    const updateRules = rulesCode.match(/allow update: if \(isAdmin\(\) \|\| isSafeProductResubmission\(\)\)/g) || [];
    const createIntegrityCalls = rulesCode.match(/hasSafeProductIntegrityOnCreate\(/g) || [];
    const updateIntegrityCalls = rulesCode.match(/hasSafeProductIntegrityOnUpdate\(/g) || [];
    assert.equal(matchBlocks.length, 1, "exactly one products match block expected");
    assert.equal(createRules.length, 1, "exactly one products allow create rule expected");
    assert.equal(createRules[0].trim(), "allow create: if false;");
    assert.equal(updateRules.length, 1, "exactly one products allow update rule expected");
    // Definition only — retained as frozen specification, never invoked.
    assert.equal(createIntegrityCalls.length, 1, "hasSafeProductIntegrityOnCreate must be defined once and called zero times");
    // Once in the function definition itself, once in the update rule.
    assert.equal(updateIntegrityCalls.length, 2, "hasSafeProductIntegrityOnUpdate must be defined once and called exactly once");
  }
);

// The exact two-file scope every Revision 29 Rules-only implementation
// commit is authorized to touch, sorted, compared byte-for-byte below.
const REV29_AUTHORIZED_SCOPE = [
  "firestore.rules",
  "functions/test/marketplaceProductRules.test.js",
].sort();

// The owning commit of each scope assertion below — pinned by full SHA,
// never by branch name, upstream state, or `HEAD`, so the assertion is
// identical from the main checkout, a detached clean worktree, and CI.
const REV29_NO_EXCEPTION_COMMIT = "bf620f8c0be8c1f5b5306edfa7f1b748f19350b4";
const REV29_RESIDUAL_COMMIT = "3cab9b3db32ea1109aac1f65319077d789b2935d";

// Clean-checkout scope verification, corrected. The original form of the
// three assertions below read the *working-tree* diff against HEAD, which
// was only ever true during the original uncommitted authoring session:
// on any clean committed checkout (CI, a fresh clone, a detached
// worktree) that diff is correctly empty. Two of them (REV29-48,
// REV29R-48) compared it for equality and so failed permanently; the
// third (REV29-46) iterated over it and so passed *vacuously*, executing
// zero assertions and proving nothing at all — the more dangerous of the
// two failure modes, since a green result implied evidence that was never
// gathered. The intent of each is preserved exactly, and all three are
// now verified against committed history instead: `git diff-tree` against
// the commit's own parent, which is deterministic, non-interactive,
// network-free, and independent of both working-tree state and whichever
// commit happens to be checked out.
function committedChangedPaths(commitSha) {
  const { execFileSync } = require("node:child_process");
  // Pinned constants only — a malformed SHA is a test-authoring bug, and
  // is rejected here rather than being passed to Git.
  assert.match(
    commitSha,
    /^[0-9a-f]{40}$/,
    `commit SHA must be a full 40-character hex object name: ${commitSha}`
  );
  const repoRoot = path.resolve(__dirname, "../..");
  let raw;
  try {
    // execFileSync (no shell) — no quoting or interpolation concerns.
    // `-r` recurses into subtrees so nested paths are listed in full;
    // `--no-commit-id` suppresses the header line, leaving only paths.
    raw = execFileSync(
      "git",
      ["-C", repoRoot, "diff-tree", "--no-commit-id", "--name-only", "-r", commitSha],
      { encoding: "utf8" }
    );
  } catch (err) {
    // A missing commit, a non-repository path, or any other Git failure
    // must fail this test loudly — never degrade into an empty list that
    // would silently satisfy a subset check.
    assert.fail(
      `git diff-tree failed for ${commitSha} (commit missing or repository unreadable): ${err.message}`
    );
  }
  const paths = raw
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .sort();
  assert.ok(
    paths.length > 0,
    `git diff-tree returned no paths for ${commitSha} — refusing to treat empty output as an in-scope result`
  );
  return paths;
}

test(
  "REV29-46 (plan item 981). (static) no functions/ file is modified by this Rules-only correction, and the Revision 28 six-row server-writer allowlist remains textually unaffected — the Step 21e Admin/Functions writer audit's own already-passed result is not invalidated",
  () => {
    // Committed history of this test's own owning commit — the Revision 29
    // no-exception implementation — never the working tree. The shared
    // helper already rejects an empty list, so the per-path loop below can
    // no longer iterate zero times and report success.
    const changedFiles = committedChangedPaths(REV29_NO_EXCEPTION_COMMIT);
    assert.ok(
      changedFiles.length > 0,
      "the owning commit must have a non-empty changed-path list for this assertion to prove anything"
    );
    // The original substantive assertion, retained unchanged in meaning:
    // every path this commit touched is inside the authorized two-file
    // scope.
    for (const f of changedFiles) {
      assert.ok(
        REV29_AUTHORIZED_SCOPE.includes(f),
        `unexpected changed file outside the authorized two-file scope: ${f}`
      );
    }
    // This item's own distinct proof (plan item 980), and the reason it is
    // a separate test from REV29-48's exact-set equality: no `functions/`
    // file other than this very test file is touched — i.e. no Functions
    // *production* source changed. The Revision 28 six-row server-writer
    // allowlist is implemented entirely in Functions production source, so
    // this is precisely what leaves the Step 21e Admin/Functions writer
    // audit's already-passed result valid without repeating it.
    const functionsProductionFiles = changedFiles.filter(
      (f) =>
        f.startsWith("functions/") &&
        f !== "functions/test/marketplaceProductRules.test.js"
    );
    assert.deepEqual(
      functionsProductionFiles,
      [],
      "no functions/ production file may be modified by this Rules-only correction — " +
        "any such file would invalidate the Step 21e Admin/Functions writer audit"
    );
  }
);

test(
  "REV29-47 (plan item 982). (static) both Marketplace feature flags remain unreferenced by, and unaffected by, this Rules-only correction",
  () => {
    assert.equal(
      /PRODUCT_MODERATION_REVIEW_ENABLED|MARKETPLACE_LISTING_ENABLED/.test(rules),
      false,
      "firestore.rules must never reference either feature flag — both are enforced entirely in Functions, never in Rules"
    );
  }
);

test(
  "REV29-48 (plan item 983). (static) no customer-facing browse/list/detail query, and no Flutter/localization/Functions/index/config file, is touched by this Rules-only correction",
  () => {
    assert.deepEqual(
      committedChangedPaths(REV29_NO_EXCEPTION_COMMIT),
      REV29_AUTHORIZED_SCOPE,
      `commit ${REV29_NO_EXCEPTION_COMMIT} must have changed exactly the two authorized files`
    );
  }
);

// =======================================================================
// Revision 29 residual correction (commit bf620f8's own two findings,
// corrected here without amending it): 48 new tests, named REV29R-1
// through REV29R-48 (R for "residual"), grouped exactly as the
// correction itself is scoped —
//   REV29R-1..20:  Finding 1 — name/price/stock moved into the shared,
//                  actor-independent create/update integrity predicates,
//                  closing the residual admin bypass while leaving
//                  seller-path enforcement unaffected.
//   REV29R-21..38: Finding 2 — a malformed existing pilotProductApproval
//                  (present, but not a well-formed {active: bool} map)
//                  now fails closed for the entire update, unconditionally,
//                  not merely for the bound-field freeze.
//   REV29R-39..48: structural/preservation — the "move, never duplicate"
//                  discipline held (source-level checks), the expression-
//                  budget regression from the immediately-prior commit
//                  does not reappear, and every previously-closed range
//                  (PUBLICATION-*/INTEGRITY-*/PILOT-*/REV29-*) remains
//                  unaffected by this correction.
// =======================================================================

// Seeds a draft product (never approved, no pilotProductApproval field at
// all) directly via the Admin SDK, bypassing Rules — used by the
// REV29R-13..16 update-side name/price/stock tests, which need an
// existing document to mutate.
async function seedDraftProduct(productId, overrides = {}) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "businesses/biz-1/products", productId),
      safeProduct(overrides)
    );
  });
}

// Seeds a product whose pilotProductApproval field is deliberately
// malformed — present, but not a well-formed {active: bool} map — via the
// Admin SDK, bypassing Rules (a client-SDK actor can never write this
// field at all, well-formed or not, per the pre-existing
// preservesPilotProductApprovalOnUpdate/omitsPilotProductApprovalOnCreate
// predicates, so an Admin-SDK seed is the only way such a document could
// ever come to exist — e.g. a legacy write predating this field, or a
// direct Admin SDK/console correction gone wrong).
async function seedMalformedApprovalProduct(productId, malformedApproval) {
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "businesses/biz-1/products", productId),
      safeProduct({ pilotProductApproval: malformedApproval })
    );
  });
}

// --- REV29R-1..20: Finding 1, name/price/stock actor-independence -----

rulesTest(
  "REV29R-1 (residual correction, Finding 1). an admin client-SDK create missing the name field entirely is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    const data = safeProduct();
    delete data.name;
    await assertFails(setDoc(doc(db, "businesses/biz-1/products/rev29r-1"), data));
  }
);

rulesTest(
  "REV29R-2 (residual correction, Finding 1). an admin client-SDK create with name not a string is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/rev29r-2"), safeProduct({ name: 123 }))
    );
  }
);

rulesTest(
  "REV29R-3 (residual correction, Finding 1). an admin client-SDK create with an empty-string name is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/rev29r-3"), safeProduct({ name: "" }))
    );
  }
);

rulesTest(
  "REV29R-4 (residual correction, Finding 1). an admin client-SDK create missing the price field entirely is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    const data = safeProduct();
    delete data.price;
    await assertFails(setDoc(doc(db, "businesses/biz-1/products/rev29r-4"), data));
  }
);

rulesTest(
  "REV29R-5 (residual correction, Finding 1). an admin client-SDK create with price not a number is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/rev29r-5"), safeProduct({ price: "9.99" }))
    );
  }
);

rulesTest(
  "REV29R-6 (residual correction, Finding 1). an admin client-SDK create with price == 0 is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/rev29r-6"), safeProduct({ price: 0 }))
    );
  }
);

rulesTest(
  "REV29R-7 (residual correction, Finding 1). an admin client-SDK create with a negative price is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/rev29r-7"), safeProduct({ price: -5 }))
    );
  }
);

rulesTest(
  "REV29R-8 (residual correction, Finding 1). an admin client-SDK create missing the stock field entirely is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    const data = safeProduct();
    delete data.stock;
    await assertFails(setDoc(doc(db, "businesses/biz-1/products/rev29r-8"), data));
  }
);

rulesTest(
  "REV29R-9 (residual correction, Finding 1). an admin client-SDK create with stock not an int (a float) is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/rev29r-9"), safeProduct({ stock: 1.5 }))
    );
  }
);

rulesTest(
  "REV29R-10 (residual correction, Finding 1). an admin client-SDK create with stock == 0 is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/rev29r-10"), safeProduct({ stock: 0 }))
    );
  }
);

rulesTest(
  "REV29R-11 (residual correction, Finding 1). an admin client-SDK create with negative stock is denied",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/rev29r-11"), safeProduct({ stock: -1 }))
    );
  }
);

rulesTest(
  "Revision 34 — direct client create denied (superseded: REV29R-12 (residual correction, Finding 1). an admin client-SDK create at the exact boundary (1-char name, smallest positive price, stock == 1) succeeds)",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/rev29r-12"),
        safeProduct({ name: "A", price: 0.01, stock: 1 })
      )
    );
  }
);

rulesTest(
  "REV29R-13 (residual correction, Finding 1). an admin client-SDK update setting name to an empty string on an ordinary draft is denied",
  async () => {
    await resetSeed();
    await seedDraftProduct("rev29r-13");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-13"), { name: "" })
    );
  }
);

rulesTest(
  "REV29R-14 (residual correction, Finding 1). an admin client-SDK update setting price to 0 on an ordinary draft is denied",
  async () => {
    await resetSeed();
    await seedDraftProduct("rev29r-14");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-14"), { price: 0 })
    );
  }
);

rulesTest(
  "REV29R-15 (residual correction, Finding 1). an admin client-SDK update setting stock to a non-int value on an ordinary draft is denied",
  async () => {
    await resetSeed();
    await seedDraftProduct("rev29r-15");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-15"), { stock: "five" })
    );
  }
);

rulesTest(
  "REV29R-16 (residual correction, Finding 1). an admin client-SDK update simultaneously invalidating name, price, and stock together is denied in one evaluation",
  async () => {
    await resetSeed();
    await seedDraftProduct("rev29r-16");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-16"), {
        name: "",
        price: 0,
        stock: -1,
      })
    );
  }
);

rulesTest(
  "REV29R-17 (residual correction, Finding 1). a seller client-SDK create with an empty-string name remains denied, unaffected by moving this check out of isSafeNewProductSubmission",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/rev29r-17"), safeProduct({ name: "" }))
    );
  }
);

rulesTest(
  "REV29R-18 (residual correction, Finding 1). a seller client-SDK create with a non-number price remains denied, unaffected by moving this check out of isSafeNewProductSubmission",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      setDoc(doc(db, "businesses/biz-1/products/rev29r-18"), safeProduct({ price: "ten" }))
    );
  }
);

rulesTest(
  "REV29R-19 (residual correction, Finding 1). a seller client-SDK update introducing a non-int stock remains denied, unaffected by moving this check out of isSafeProductResubmission",
  async () => {
    await resetSeed();
    await seedDraftProduct("rev29r-19");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-19"), { stock: 2.5 })
    );
  }
);

rulesTest(
  "REV29R-20 (Revision 34, residual correction, Finding 1). an ordinary seller UPDATE at the valid boundary name/price/stock values still succeeds, unaffected by relocating the check into the shared predicate",
  async () => {
    await resetSeed();
    // Fixture setup only — the operation under test is the seller update.
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/rev29r-20",
      safeProduct({ name: "A", price: 0.01, stock: 1 })
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-20"), { stock: 2 })
    );
    // The shared predicate is genuinely evaluated on that update path: the
    // same edit carrying an out-of-bounds value is rejected.
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-20"), { stock: 0 })
    );
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-20"), { price: 0 })
    );
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-20"), { name: "" })
    );
  }
);

// --- REV29R-21..38: Finding 2, malformed-approval fail-closed ---------

rulesTest(
  "REV29R-21 (residual correction, Finding 2). state A — pilotProductApproval absent entirely — an ordinary harmless edit succeeds",
  async () => {
    await resetSeed();
    await seedDraftProduct("rev29r-21");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-21"), { stock: 9 })
    );
  }
);

rulesTest(
  "REV29R-22 (residual correction, Finding 2). state B — well-formed pilotProductApproval with active: false — an ordinary harmless edit succeeds",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-22", { active: false });
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-22"), { stock: 9 })
    );
  }
);

rulesTest(
  "REV29R-23 (residual correction, Finding 2). state C — well-formed pilotProductApproval with active: true — even a non-bound-field harmless edit is denied, because hasUnpublishedProductPublicationState's own pre-existing, unconditional incoming.isActive == false requirement fires first, independent of both the bound-field freeze and this correction's own malformed-approval predicate (mirrors PILOT-7's identical finding for the seller path)",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29r-23");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-23"), { stock: 9 })
    );
  }
);

rulesTest(
  "REV29R-24 (residual correction, Finding 2). state C — well-formed pilotProductApproval with active: true — a bound-field edit is still denied (freeze regression guard, alongside REV29-21)",
  async () => {
    await resetSeed();
    await seedPilotApprovedProduct("rev29r-24");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-24"), { name: "Changed Name" })
    );
  }
);

rulesTest(
  "REV29R-25 (residual correction, Finding 2). state D — pilotProductApproval is null — a harmless edit is denied",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-25", null);
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-25"), { stock: 9 })
    );
  }
);

rulesTest(
  "REV29R-26 (residual correction, Finding 2). state D — pilotProductApproval is a string, not a map — a harmless edit is denied",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-26", "approved");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-26"), { stock: 9 })
    );
  }
);

rulesTest(
  "REV29R-27 (residual correction, Finding 2). state D — pilotProductApproval is a number — a harmless edit is denied",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-27", 1);
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-27"), { stock: 9 })
    );
  }
);

rulesTest(
  "REV29R-28 (residual correction, Finding 2). state D — pilotProductApproval is a list — a harmless edit is denied",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-28", []);
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-28"), { stock: 9 })
    );
  }
);

rulesTest(
  "REV29R-29 (residual correction, Finding 2). state D — pilotProductApproval is an empty map, missing active — a harmless edit is denied",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-29", {});
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-29"), { stock: 9 })
    );
  }
);

rulesTest(
  "REV29R-30 (residual correction, Finding 2). state D — pilotProductApproval.active is null — a harmless edit is denied",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-30", { active: null });
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-30"), { stock: 9 })
    );
  }
);

rulesTest(
  "REV29R-31 (residual correction, Finding 2). state D — pilotProductApproval.active is the string \"true\", not a boolean — a harmless edit is denied",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-31", { active: "true" });
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-31"), { stock: 9 })
    );
  }
);

rulesTest(
  "REV29R-32 (residual correction, Finding 2). state D — pilotProductApproval.active is the number 1, not a boolean — a harmless edit is denied",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-32", { active: 1 });
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-32"), { stock: 9 })
    );
  }
);

rulesTest(
  "REV29R-33 (residual correction, Finding 2). state D — pilotProductApproval is otherwise fully populated but missing only the active key — a harmless edit is denied",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-33", {
      schemaVersion: 1,
      approvedAt: serverTimestamp(),
      approvedBy: "admin-1",
      allowedPilotCategory: "food",
      reviewedContentFingerprint: "fixture-fingerprint",
      reviewedProductRevision: 0,
      reasonCode: "pilot_approved",
    });
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-33"), { stock: 9 })
    );
  }
);

rulesTest(
  "REV29R-34 (residual correction, Finding 2). state D — a bound-field edit is ALSO denied, not merely a harmless one, confirming the malformed-approval denial is unconditional for the whole update",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-34", {});
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-34"), { name: "Changed Name" })
    );
  }
);

rulesTest(
  "REV29R-35 (residual correction, Finding 2). state D — attempting to \"normalize\" the malformed field to a well-formed value in the same write that also edits content is still denied — no client-SDK escape hatch",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-35", {});
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-35"), {
        stock: 9,
        "pilotProductApproval.active": false,
      })
    );
  }
);

rulesTest(
  "REV29R-36 (residual correction, Finding 2). state D — attempting to remove the malformed field outright via deleteField() in the same write that also edits content is still denied — no removal escape hatch",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-36", {});
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-36"), {
        stock: 9,
        pilotProductApproval: deleteField(),
      })
    );
  }
);

rulesTest(
  "REV29R-37 (residual correction, Finding 2). state D — a dotted/field-path-form update touching only a harmless field is still denied",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-37", {});
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-37"), "stock", 9)
    );
  }
);

rulesTest(
  "REV29R-38 (residual correction, Finding 2). state D — the only remediation path is Admin SDK: after an Admin-SDK-simulated correction replaces the malformed field with a well-formed one, the identical client-SDK edit that was denied before now succeeds",
  async () => {
    await resetSeed();
    await seedMalformedApprovalProduct("rev29r-38", {});
    const rulesEnv = await env();
    const db = rulesEnv.authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-38"), { stock: 9 })
    );
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), "businesses/biz-1/products/rev29r-38"),
        { pilotProductApproval: { active: false } }
      );
    });
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-38"), { stock: 9 })
    );
  }
);

// --- REV29R-39..48: structural/preservation ----------------------------

test(
  "REV29R-39 (residual correction). hasWellFormedPilotProductApprovalIfPresent is defined exactly once and called exactly once",
  () => {
    const definitions = rules.match(/function hasWellFormedPilotProductApprovalIfPresent\(/g) || [];
    const calls = rules.match(/hasWellFormedPilotProductApprovalIfPresent\(/g) || [];
    assert.equal(definitions.length, 1, "hasWellFormedPilotProductApprovalIfPresent must be defined exactly once");
    // Once in the function definition itself, once as a call inside
    // hasSafeProductIntegrityOnUpdate.
    assert.equal(calls.length, 2, "hasWellFormedPilotProductApprovalIfPresent must be defined once and called exactly once");
  }
);

test(
  "REV29R-40 (residual correction). name/price/stock checks now live in hasSafeProductIntegrityOnCreate, and have been removed from isSafeNewProductSubmission (moved, not duplicated)",
  () => {
    const createIntegrityMatch = rules.match(
      /function hasSafeProductIntegrityOnCreate\(data\) \{[\s\S]*?\n  \}/
    );
    const sellerCreateMatch = rules.match(
      /function isSafeNewProductSubmission\(\) \{[\s\S]*?\n  \}/
    );
    assert.ok(createIntegrityMatch, "hasSafeProductIntegrityOnCreate not found");
    assert.ok(sellerCreateMatch, "isSafeNewProductSubmission not found");
    for (const needle of ["data.name is string", "data.price is number", "data.stock is int"]) {
      assert.ok(
        createIntegrityMatch[0].includes(needle),
        `hasSafeProductIntegrityOnCreate must contain '${needle}'`
      );
      assert.ok(
        !sellerCreateMatch[0].includes(needle),
        `isSafeNewProductSubmission must no longer contain '${needle}' — moved, not duplicated`
      );
    }
  }
);

test(
  "REV29R-41 (residual correction). name/price/stock checks now live in hasSafeProductIntegrityOnUpdate, and have been removed from isSafeProductResubmission (moved, not duplicated)",
  () => {
    const updateIntegrityMatch = rules.match(
      /function hasSafeProductIntegrityOnUpdate\(incoming, existing\) \{[\s\S]*?\n  \}/
    );
    const sellerUpdateMatch = rules.match(
      /function isSafeProductResubmission\(\) \{[\s\S]*?\n  \}/
    );
    assert.ok(updateIntegrityMatch, "hasSafeProductIntegrityOnUpdate not found");
    assert.ok(sellerUpdateMatch, "isSafeProductResubmission not found");
    for (const needle of ["incoming.name is string", "incoming.price is number", "incoming.stock is int"]) {
      assert.ok(
        updateIntegrityMatch[0].includes(needle),
        `hasSafeProductIntegrityOnUpdate must contain '${needle}'`
      );
      assert.ok(
        !sellerUpdateMatch[0].includes(needle),
        `isSafeProductResubmission must no longer contain '${needle}' — moved, not duplicated`
      );
    }
  }
);

test(
  "REV29R-42 (residual correction). the name/price/stock validity checks each appear exactly twice file-wide (once per shared create/update predicate) — an expression-budget duplication regression guard",
  () => {
    const nameChecks = rules.match(/\.name is string && \S+\.name\.size\(\) > 0/g) || [];
    const priceChecks = rules.match(/\.price is number && \S+\.price > 0/g) || [];
    const stockChecks = rules.match(/\.stock is int && \S+\.stock >= 1/g) || [];
    assert.equal(nameChecks.length, 2, "name validity must appear exactly twice (create + update), never duplicated further");
    assert.equal(priceChecks.length, 2, "price validity must appear exactly twice (create + update), never duplicated further");
    assert.equal(stockChecks.length, 2, "stock validity must appear exactly twice (create + update), never duplicated further");
  }
);

// Revision 34 migration of REV29R-43 (residual correction).
//
// §15 intent: re-affirm post-correction that the products collection still
// exposes exactly one create rule and one update rule.
//
// Old assertion: exactly one `allow create: if (isAdmin() ||
// isSafeNewProductSubmission())` and one matching update.
//
// New boundary: the uniqueness invariant is retained and extended with the
// Revision 34 closure properties it now guards — no isAdmin() branch and no
// isSafeNewProductSubmission() branch can restore client create.
test(
  "REV29R-43 (Revision 34, residual correction). exactly one products allow-create and one allow-update rule still exist post-closure, and no branch can restore client create",
  () => {
    const matchBlocks = rulesCode.match(/match \/\{path=\*\*\}\/products\/\{productId\}/g) || [];
    const createRules = productsRulesBlock.match(/allow create: if [^;]*;/g) || [];
    const updateRules = rulesCode.match(/allow update: if \(isAdmin\(\) \|\| isSafeProductResubmission\(\)\)/g) || [];
    assert.equal(matchBlocks.length, 1, "exactly one products match block expected");
    assert.equal(createRules.length, 1, "exactly one products allow create rule expected");
    assert.equal(updateRules.length, 1, "exactly one products allow update rule expected");
    // The create rule is the literal constant false — no OR, no branch, no
    // predicate call, nothing an actor can satisfy.
    assert.equal(createRules[0].trim(), "allow create: if false;");
    assert.doesNotMatch(createRules[0], /isAdmin\(\)/);
    assert.doesNotMatch(createRules[0], /isSafeNewProductSubmission\(\)/);
    assert.doesNotMatch(createRules[0], /\|\|/);
    // isSafeNewProductSubmission survives only as its own definition; it is
    // not wired into any allow rule anywhere in the file.
    const submissionRefs = rulesCode.match(/(function\s+)?isSafeNewProductSubmission\(\)/g) || [];
    const submissionDefs = submissionRefs.filter((ref) => ref.startsWith("function"));
    assert.equal(submissionDefs.length, 1, "isSafeNewProductSubmission must still be defined once");
    assert.equal(
      submissionRefs.length - submissionDefs.length,
      0,
      "isSafeNewProductSubmission() must have no call sites once client create is closed"
    );
  }
);

rulesTest(
  "REV29R-44 (residual correction). the PUBLICATION-* range (commit affc328) remains unaffected by this correction — a direct spot-check: an admin client-SDK false-to-true isActive update on a never-approved product is still denied",
  async () => {
    await resetSeed();
    await seedDraftProduct("rev29r-44");
    const db = (await env()).authenticatedContext("admin-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-44"), { isActive: true })
    );
  }
);

rulesTest(
  "REV29R-45 (Revision 34, residual correction). server creation followed by ordinary seller resubmission remains valid end-to-end, unaffected by relocating name/price/stock validation into the shared predicates",
  async () => {
    await resetSeed();
    // Direct client creation is closed; the product arrives the way the
    // server writes it. Fixture setup only.
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/rev29r-45",
      safeProduct()
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-45"), { stock: 42 })
    );
    // And the resubmission path still refuses a server-owned field, proving
    // the update contract is really being evaluated here.
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-45"), {
        moderationStatus: "approved",
      })
    );
  }
);

rulesTest(
  "REV29R-46 (residual correction). a user simultaneously the product's own business owner and flagged role: admin still cannot bypass the new name/price/stock or malformed-approval predicates through either authorization branch",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", "seller-1"), { role: "admin" });
    });
    await seedMalformedApprovalProduct("rev29r-46", {});
    const db = rulesEnv.authenticatedContext("seller-1").firestore();
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev29r-46"), { stock: 9 })
    );
    await assertFails(
      setDoc(
        doc(db, "businesses/biz-1/products/rev29r-46b"),
        safeProduct({ name: "" })
      )
    );
  }
);

test(
  "REV29R-47 (residual correction). pilotApprovalBoundFields()'s frozen 11-field set is byte-for-byte unchanged by this correction",
  () => {
    const match = rules.match(/function pilotApprovalBoundFields\(\) \{[\s\S]*?\n  \}/);
    assert.ok(match, "pilotApprovalBoundFields not found");
    assert.equal(
      match[0],
      "function pilotApprovalBoundFields() {\n" +
        "    return [\n" +
        "      'name', 'description', 'price', 'currency', 'media',\n" +
        "      'category', 'brand', 'barcode', 'salePrice', 'kdvRate',\n" +
        "      'sellerRelationship'\n" +
        "    ];\n" +
        "  }",
      "pilotApprovalBoundFields() must remain byte-identical to the frozen 11-field set — this correction must never touch the fingerprint-bound field list"
    );
  }
);

test(
  "REV29R-48 (residual correction). the complete set of git-changed files remains exactly the two authorized files, re-affirmed after the residual correction's own edits",
  () => {
    assert.deepEqual(
      committedChangedPaths(REV29_RESIDUAL_COMMIT),
      REV29_AUTHORIZED_SCOPE,
      `commit ${REV29_RESIDUAL_COMMIT} must have changed exactly the two authorized files`
    );
  }
);

// =======================================================================
// Marketplace Revision 35 / Slice 7A (§0.33) — the client-side closure
// around admin product classification.
//
// `setPilotProductClassification` (Admin SDK, which bypasses Rules by
// construction) is the sole write authority for `pilotProductClass` and its
// provenance metadata. These cases prove the complementary half: that no
// client-SDK actor — seller-owner, another authenticated user, or an
// authenticated ADMIN using the client SDK — can write, alter, remove or
// forge any of it, while a legitimate seller draft edit still succeeds.
// =======================================================================

const REV35_CLASSIFICATION_FIELDS = [
  "pilotProductClass",
  "pilotProductClassifiedAt",
  "pilotProductClassifiedByUid",
  "pilotProductClassificationRevision",
];

function rev35ClassifiedProduct(overrides = {}) {
  return safeProduct({
    pilotProductClass: "sealed_dry_food",
    pilotProductClassifiedAt: new Date("2026-09-01T00:00:00Z"),
    pilotProductClassifiedByUid: "admin-1",
    pilotProductClassificationRevision: 2,
    ...overrides,
  });
}

rulesTest(
  "REV35-CLS-1. a seller may still edit a classified product — the server-written metadata never fails the closed schema",
  async () => {
    await resetSeed();
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/rev35-1",
      rev35ClassifiedProduct()
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    // The exact defect this guards against: a server-owned field missing
    // from productAllowedFields() locks the seller out of their own product
    // the instant an admin writes it, even though they never touched it.
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/rev35-1"), { stock: 7 })
    );
    await assertSucceeds(
      updateDoc(doc(db, "businesses/biz-1/products/rev35-1"), {
        name: "Renamed by the seller",
        price: 12,
      })
    );
  }
);

rulesTest(
  "REV35-CLS-2. a seller may not add, alter or remove any classification field",
  async () => {
    await resetSeed();
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/rev35-2",
      rev35ClassifiedProduct()
    );
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/rev35-2b",
      safeProduct()
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();

    const mutations = {
      pilotProductClass: "sealed_wet_food",
      pilotProductClassifiedAt: new Date("2030-01-01T00:00:00Z"),
      pilotProductClassifiedByUid: "seller-1",
      pilotProductClassificationRevision: 99,
    };
    for (const field of REV35_CLASSIFICATION_FIELDS) {
      // Alter it on a classified product...
      await assertFails(
        updateDoc(doc(db, "businesses/biz-1/products/rev35-2"), {
          [field]: mutations[field],
        })
      );
      // ...remove it...
      await assertFails(
        updateDoc(doc(db, "businesses/biz-1/products/rev35-2"), {
          [field]: deleteField(),
        })
      );
      // ...and add it to a product that has none.
      await assertFails(
        updateDoc(doc(db, "businesses/biz-1/products/rev35-2b"), {
          [field]: mutations[field],
        })
      );
    }
  }
);

rulesTest(
  "REV35-CLS-3. forging classification history is denied even while the class value itself is left alone",
  async () => {
    await resetSeed();
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/rev35-3",
      rev35ClassifiedProduct()
    );
    const db = (await env()).authenticatedContext("seller-1").firestore();
    // Back-dating, advancing, and re-attributing the classification — the
    // class value stays byte-identical in every one of these.
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev35-3"), {
        pilotProductClassificationRevision: 1,
      })
    );
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev35-3"), {
        pilotProductClassificationRevision: 500,
      })
    );
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev35-3"), {
        pilotProductClassifiedAt: new Date("2020-01-01T00:00:00Z"),
      })
    );
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev35-3"), {
        pilotProductClassifiedByUid: "some-other-admin",
      })
    );
    // Nor bundled inside an otherwise-legitimate edit.
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev35-3"), {
        stock: 9,
        pilotProductClassificationRevision: 3,
      })
    );
  }
);

rulesTest(
  "REV35-CLS-4. an authenticated ADMIN using the client SDK is denied identically — the guard sits outside the isAdmin() OR",
  async () => {
    await resetSeed();
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/rev35-4",
      rev35ClassifiedProduct()
    );
    const db = (await env()).authenticatedContext("admin-1").firestore();
    for (const field of REV35_CLASSIFICATION_FIELDS) {
      await assertFails(
        updateDoc(doc(db, "businesses/biz-1/products/rev35-4"), {
          [field]: deleteField(),
        })
      );
    }
    await assertFails(
      updateDoc(doc(db, "businesses/biz-1/products/rev35-4"), {
        pilotProductClass: "non_biocidal_litter",
        pilotProductClassificationRevision: 3,
      })
    );
  }
);

rulesTest(
  "REV35-CLS-5. no client may create a product carrying classification fields, nor delete a classified one",
  async () => {
    await resetSeed();
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/rev35-5",
      rev35ClassifiedProduct()
    );
    for (const uid of ["seller-1", "admin-1"]) {
      const db = (await env()).authenticatedContext(uid).firestore();
      await assertFails(
        setDoc(
          doc(db, "businesses/biz-1/products/rev35-5-new"),
          rev35ClassifiedProduct()
        )
      );
      await assertFails(deleteDoc(doc(db, "businesses/biz-1/products/rev35-5")));
    }
  }
);

rulesTest(
  "REV35-CLS-6. the pilotProductClassificationAuditEvents collection is fully client-immutable, admin-read-only",
  async () => {
    const rulesEnv = await env();
    const adminDb = rulesEnv.authenticatedContext("admin-1").firestore();
    const sellerDb = rulesEnv.authenticatedContext("seller-1").firestore();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", "admin-1"), { role: "admin" });
      await setDoc(
        doc(context.firestore(), "pilotProductClassificationAuditEvents", "cls-evt-1"),
        { businessId: "biz-1", productId: "p-1", newPilotProductClass: "sealed_dry_food" }
      );
    });
    await assertSucceeds(
      getDoc(doc(adminDb, "pilotProductClassificationAuditEvents", "cls-evt-1"))
    );
    await assertFails(
      getDoc(doc(sellerDb, "pilotProductClassificationAuditEvents", "cls-evt-1"))
    );
    // Not creatable, not alterable, not erasable — by anyone, admin included.
    for (const db of [adminDb, sellerDb]) {
      await assertFails(
        setDoc(doc(db, "pilotProductClassificationAuditEvents", "cls-evt-2"), {
          businessId: "biz-1",
        })
      );
      await assertFails(
        updateDoc(doc(db, "pilotProductClassificationAuditEvents", "cls-evt-1"), {
          newPilotProductClass: "non_biocidal_litter",
        })
      );
      await assertFails(
        deleteDoc(doc(db, "pilotProductClassificationAuditEvents", "cls-evt-1"))
      );
    }
  }
);

rulesTest(
  "REV35-CLS-7. (static) all four classification fields are in the closed schema and in the single preservation guard",
  async () => {
    const allowed = rulesCode.match(/function productAllowedFields\(\)[\s\S]*?\n  \}/);
    assert.ok(allowed, "productAllowedFields() not found");
    const guard = rulesCode.match(
      /function preservesPilotProductClassOnUpdate\([\s\S]*?\n  \}/
    );
    assert.ok(guard, "preservesPilotProductClassOnUpdate() not found");
    for (const field of REV35_CLASSIFICATION_FIELDS) {
      assert.ok(
        allowed[0].includes(`'${field}'`),
        `${field} must be part of the closed document schema`
      );
      assert.ok(
        guard[0].includes(`'${field}'`),
        `${field} must be covered by the preservation guard`
      );
    }
    // Still exactly one definition and one call site — the guard was
    // extended, never duplicated.
    const refs = rulesCode.match(/(function\s+)?preservesPilotProductClassOnUpdate\(/g) || [];
    const defs = refs.filter((r) => r.startsWith("function"));
    assert.equal(defs.length, 1);
    assert.equal(refs.length - defs.length, 1);
  }
);

// =======================================================================
// Marketplace Revision 36 (§0.34) — the approval-handshake privacy boundary.
//
// The repair moved fingerprint computation to the server. These cases pin the
// two Rules-side facts that repair depends on, and state the third accurately
// rather than overclaiming it.
// =======================================================================

rulesTest(
  "REV36-RULES-1. productComplianceDecisions stays client-immutable, and unreadable to everyone except an admin and the owning business",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "productComplianceDecisions", "rev36-p1"), {
        businessId: "biz-1",
        effectiveStatus: "verified_valid",
        decisionHash: "a".repeat(64),
        activeEvidenceRefs: [],
      });
    });

    // Denied: unauthenticated, an unrelated customer, and — importantly — a
    // seller who owns a DIFFERENT business.
    await assertFails(
      getDoc(doc(rulesEnv.unauthenticatedContext().firestore(), "productComplianceDecisions/rev36-p1"))
    );
    await assertFails(
      getDoc(
        doc(
          rulesEnv.authenticatedContext("customer-1").firestore(),
          "productComplianceDecisions/rev36-p1"
        )
      )
    );
    await assertFails(
      getDoc(
        doc(
          rulesEnv.authenticatedContext("seller-2").firestore(),
          "productComplianceDecisions/rev36-p1"
        )
      )
    );

    // Writes are denied to EVERY client, admin included — which is what makes
    // a decision unforgeable from the client side no matter who is asking.
    for (const uid of ["seller-1", "seller-2", "admin-1", "customer-1"]) {
      const db = rulesEnv.authenticatedContext(uid).firestore();
      await assertFails(
        setDoc(doc(db, "productComplianceDecisions/rev36-p2"), { businessId: "biz-1" })
      );
      await assertFails(
        updateDoc(doc(db, "productComplianceDecisions/rev36-p1"), {
          effectiveStatus: "verified_valid",
        })
      );
      await assertFails(deleteDoc(doc(db, "productComplianceDecisions/rev36-p1")));
    }
    await assertFails(
      setDoc(
        doc(rulesEnv.unauthenticatedContext().firestore(), "productComplianceDecisions/rev36-p3"),
        { businessId: "biz-1" }
      )
    );
  }
);

rulesTest(
  "REV36-RULES-2. (stated accurately) an admin client-SDK READ of a decision is permitted by the frozen Rules — the client-side prohibition is architectural, not a Rules narrowing",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "productComplianceDecisions", "rev36-p4"), {
        businessId: "biz-1",
        effectiveStatus: "verified_valid",
        activeEvidenceRefs: [],
      });
    });

    // This is the frozen posture, unchanged by Revision 36 and deliberately
    // NOT narrowed here: narrowing it would silently revoke the owning
    // business's own visibility, which an earlier revision froze on purpose.
    // Revision 36's guarantee is that the Petsupo client does not USE this
    // read — proven by the Admin page's own static contract test, not here.
    await assertSucceeds(
      getDoc(
        doc(
          rulesEnv.authenticatedContext("admin-1").firestore(),
          "productComplianceDecisions/rev36-p4"
        )
      )
    );
    await assertSucceeds(
      getDoc(
        doc(
          rulesEnv.authenticatedContext("seller-1").firestore(),
          "productComplianceDecisions/rev36-p4"
        )
      )
    );
  }
);

rulesTest(
  "REV36-RULES-3. holding a valid approval fingerprint grants no write power whatsoever through the client SDK",
  async () => {
    await resetSeed();
    await seedProductAsTrustedServer(
      "businesses/biz-1/products/rev36-prod",
      safeProduct({
        pilotProductClass: "sealed_dry_food",
        pilotProductClassifiedAt: new Date("2026-09-01T00:00:00Z"),
        pilotProductClassifiedByUid: "admin-1",
        pilotProductClassificationRevision: 1,
      })
    );
    // A structurally perfect fingerprint — the exact thing readiness returns.
    const fingerprint = "f".repeat(64);

    for (const uid of ["seller-1", "admin-1"]) {
      const db = (await env()).authenticatedContext(uid).firestore();
      // It cannot publish.
      await assertFails(
        updateDoc(doc(db, "businesses/biz-1/products/rev36-prod"), {
          isActive: true,
          moderationStatus: "approved",
        })
      );
      // It cannot author an approval, even when carried as the reviewed
      // fingerprint the server itself would have accepted.
      await assertFails(
        updateDoc(doc(db, "businesses/biz-1/products/rev36-prod"), {
          pilotProductApproval: {
            active: true,
            reviewedContentFingerprint: fingerprint,
            allowedPilotCategory: "food",
          },
        })
      );
      // It cannot MOVE the counter that gates publication volume. The guard
      // is diff-based, so the value must actually change for this to be a
      // real attempt — rewriting the identical value is a no-op by
      // construction and proves nothing.
      await assertFails(
        updateDoc(doc(db, "businesses", "biz-1"), { pilotActiveProductCount: 5 })
      );
      await assertFails(
        updateDoc(doc(db, "businesses", "biz-1"), {
          marketplaceBusinessGenerationId: "forged-generation",
        })
      );
      // And it cannot create a product that arrives pre-approved.
      await assertFails(
        setDoc(
          doc(db, "businesses/biz-1/products/rev36-prod-new"),
          safeProduct({
            isActive: true,
            moderationStatus: "approved",
            pilotProductApproval: {
              active: true,
              reviewedContentFingerprint: fingerprint,
            },
          })
        )
      );
    }
  }
);

// =======================================================================
// Marketplace Revision 40 §0.38 — order/return collections are callable-owned.
//
// The server-side ownership repair is only half the boundary; these pin the
// other half: no client may reach across users through Firestore directly.
// =======================================================================

rulesTest(
  "REV40-ORD-1. orders and sellerOrders cannot be mutated by any client, across users or their own",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "orders", "rev40-order"), {
        orderId: "rev40-order",
        buyerUid: "customer-1",
        status: "payment_pending",
        paymentStatus: "pending",
        pricing: { grandTotal: 100 },
      });
      await setDoc(doc(db, "sellerOrders", "rev40-so"), {
        rootOrderId: "rev40-order",
        buyerUid: "customer-1",
        businessId: "biz-1",
        status: "payment_pending",
      });
    });

    // 35/37. No client — owner, foreign, seller or admin — may update an
    // order, and in particular may not inject a paid/refunded status.
    for (const uid of ["customer-1", "seller-1", "admin-1", "seller-2"]) {
      const db = rulesEnv.authenticatedContext(uid).firestore();
      await assertFails(updateDoc(doc(db, "orders/rev40-order"), { status: "paid" }));
      await assertFails(updateDoc(doc(db, "orders/rev40-order"), { paymentStatus: "paid" }));
      await assertFails(updateDoc(doc(db, "orders/rev40-order"), { pricing: { grandTotal: 1 } }));
      await assertFails(deleteDoc(doc(db, "orders/rev40-order")));
      // sellerOrders are wholly server-owned: not even create is permitted.
      await assertFails(updateDoc(doc(db, "sellerOrders/rev40-so"), { status: "paid" }));
      await assertFails(setDoc(doc(db, "sellerOrders/rev40-so-new"), { buyerUid: uid }));
      await assertFails(deleteDoc(doc(db, "sellerOrders/rev40-so")));
    }
    await assertFails(
      updateDoc(doc(rulesEnv.unauthenticatedContext().firestore(), "orders/rev40-order"), {
        status: "paid",
      })
    );
  }
);

rulesTest(
  "REV40-ORD-2. a foreign customer cannot READ another buyer's order or seller order",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, "orders", "rev40-order-2"), {
        buyerUid: "customer-1",
        businessId: "biz-1",
        pricing: { grandTotal: 100 },
      });
      await setDoc(doc(db, "sellerOrders", "rev40-so-2"), {
        rootOrderId: "rev40-order-2",
        buyerUid: "customer-1",
        businessId: "biz-1",
      });
    });
    // `seller-2` owns neither the order nor its business.
    const foreign = rulesEnv.authenticatedContext("seller-2").firestore();
    await assertFails(getDoc(doc(foreign, "orders/rev40-order-2")));
    await assertFails(getDoc(doc(foreign, "sellerOrders/rev40-so-2")));
    await assertFails(
      getDoc(doc(rulesEnv.unauthenticatedContext().firestore(), "orders/rev40-order-2"))
    );
    // The buyer keeps their own access.
    await assertSucceeds(
      getDoc(doc(rulesEnv.authenticatedContext("customer-1").firestore(), "orders/rev40-order-2"))
    );
  }
);

rulesTest(
  "REV40-ORD-3. order_returns are server-written only, and unreadable across users",
  async () => {
    await resetSeed();
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "order_returns", "rev40-ret"), {
        buyerUid: "customer-1",
        sellerUid: "seller-1",
        businessId: "biz-1",
        sellerOrderId: "rev40-so",
        refundAmount: 50,
        status: "pending",
      });
    });

    // 36. No client may create, alter or erase a return — in particular a
    // buyer cannot raise their own `refundAmount`, which is exactly what the
    // server-side derivation exists to control.
    for (const uid of ["customer-1", "seller-1", "admin-1", "seller-2"]) {
      const db = rulesEnv.authenticatedContext(uid).firestore();
      await assertFails(updateDoc(doc(db, "order_returns/rev40-ret"), { refundAmount: 999999 }));
      await assertFails(updateDoc(doc(db, "order_returns/rev40-ret"), { status: "approved" }));
      await assertFails(setDoc(doc(db, "order_returns/rev40-ret-new"), { buyerUid: uid, refundAmount: 1 }));
      await assertFails(deleteDoc(doc(db, "order_returns/rev40-ret")));
    }

    // 34. An unrelated customer cannot read it; the buyer and seller can.
    await assertFails(
      getDoc(doc(rulesEnv.authenticatedContext("seller-2").firestore(), "order_returns/rev40-ret"))
    );
    await assertSucceeds(
      getDoc(doc(rulesEnv.authenticatedContext("customer-1").firestore(), "order_returns/rev40-ret"))
    );
    await assertSucceeds(
      getDoc(doc(rulesEnv.authenticatedContext("seller-1").firestore(), "order_returns/rev40-ret"))
    );
  }
);

rulesTest(
  "REV40-ORD-4. (documented exposure) a client CAN still directly create an orders document for itself",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("customer-1").firestore();

    // Marketplace Revision 40 §0.38 F — this is the legacy
    // `OrderService.createOrder` path. It is pinned here rather than closed:
    // the same `orders` create rule serves non-Marketplace sectors (note its
    // own `pet_taxi` carve-out), so narrowing it is a separate, cross-sector
    // task. What bounds the exposure is that (a) the creator must name
    // ITSELF as buyer, (b) `update`/`delete` are denied to every client, and
    // (c) every server callable that acts on an order now proves ownership
    // and re-derives money from canonical state.
    await assertSucceeds(
      setDoc(doc(db, "orders/rev40-legacy"), {
        orderId: "rev40-legacy",
        userId: "customer-1",
        buyerUid: "customer-1",
        businessId: "biz-1",
        status: "pending",
        paymentStatus: "pending",
      })
    );

    // But it may NOT name someone else as the buyer...
    await assertFails(
      setDoc(doc(db, "orders/rev40-legacy-foreign"), {
        orderId: "rev40-legacy-foreign",
        buyerUid: "seller-2",
        userId: "seller-2",
      })
    );
    // ...and it may not edit what it created.
    await assertFails(updateDoc(doc(db, "orders/rev40-legacy"), { status: "paid" }));
  }
);
