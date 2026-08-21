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
  getDoc,
  getDocs,
  collection,
  collectionGroup,
  query,
  where,
} = require("firebase/firestore");

const rules = fs.readFileSync(
  path.resolve(__dirname, "../../firestore.rules"),
  "utf8"
);

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
    });
    await setDoc(doc(db, "businesses", "biz-2"), {
      ownerUid: "seller-2",
      contact: { email: "seller2@example.com" },
      status: "approved",
      published: true,
    });
    await setDoc(doc(db, "users", "admin-1"), { role: "admin" });
  });
}

function safeProduct(overrides = {}) {
  return {
    businessId: "biz-1",
    name: "Test Product",
    price: 10,
    stock: 5,
    category: "Health > Vitamins",
    isActive: false,
    moderationStatus: "pending_review",
    ...overrides,
  };
}

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

rulesTest(
  "control: a safe, correctly-shaped submission succeeds",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
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

rulesTest("published + approved products are publicly readable", async () => {
  await resetSeed();
  const rulesEnv = await env();
  await rulesEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "businesses/biz-1/products/p1"),
      safeProduct({ isActive: true, moderationStatus: "approved" })
    );
  });
  const db = rulesEnv.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(db, "businesses/biz-1/products/p1")));
});

rulesTest(
  "admin can approve and publish (established admin pattern still works)",
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
    await assertSucceeds(
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
  "4. the real public list query (collectionGroup, isActive+moderationStatus) returns only approved+active products",
  async () => {
    await seedFullCatalog();
    const db = (await env()).unauthenticatedContext().firestore();
    const q = query(
      collectionGroup(db, "products"),
      where("isActive", "==", true),
      where("moderationStatus", "==", "approved")
    );
    const snap = await assertSucceeds(getDocs(q));
    const ids = snap.docs.map((d) => d.id).sort();
    assert.deepEqual(ids, ["approved-1", "approved-2"]);
  }
);

rulesTest(
  "4. the real seller-scoped list query excludes pending/rejected/suspended for that seller",
  async () => {
    await seedFullCatalog();
    const db = (await env()).unauthenticatedContext().firestore();
    const q = query(
      collectionGroup(db, "products"),
      where("isActive", "==", true),
      where("moderationStatus", "==", "approved"),
      where("businessId", "==", "biz-1")
    );
    const snap = await assertSucceeds(getDocs(q));
    const ids = snap.docs.map((d) => d.id);
    assert.deepEqual(ids, ["approved-1"]);
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
  "18g. the normal approved+active public query against the same path still succeeds",
  async () => {
    await seedFullCatalog();
    const db = (await env()).unauthenticatedContext().firestore();
    const q = query(
      collection(db, "businesses/biz-1/products"),
      where("isActive", "==", true),
      where("moderationStatus", "==", "approved")
    );
    const snap = await assertSucceeds(getDocs(q));
    const ids = snap.docs.map((d) => d.id);
    assert.deepEqual(ids, ["approved-1"]);
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
