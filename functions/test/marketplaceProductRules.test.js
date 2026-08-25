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
  "P0.1-1. seller can create a valid P0 product without any server-owned field",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
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
    const db = rulesEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
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

rulesTest("4.2-create-1. absent productInputRevision is allowed on create", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertSucceeds(
    setDoc(doc(db, "businesses/biz-1/products/piv-c1"), safeProduct())
  );
});

rulesTest("4.2-create-2. present productInputRevision 0 is allowed on create", async () => {
  await resetSeed();
  const db = (await env()).authenticatedContext("seller-1").firestore();
  await assertSucceeds(
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
  "4.2-updateA-14. sku change (absent->value), absent->absent revision, is allowed",
  async () => {
    await resetSeed();
    await seedProductWithRevision(undefined, {}, "piv-a14");
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
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

const MATCHING_FIELD_CHANGES = [
  ["category", "Toys > Chew Toy"],
  ["brand", "Acme"],
  ["barcode", "1234567890123"],
  ["sku", "SKU-1"],
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
  "4.2-regression-38a. an ordinary create with no productInputRevision still succeeds during dormancy",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
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
    // No complianceEffectiveStatus field exists on this document at all —
    // if a read gate had been introduced, this would now be expected to
    // fail; it must still succeed, exactly as before Slice 4.2.
    const db = rulesEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
      getDoc(doc(db, "businesses/biz-1/products/piv-reg-41"))
    );
  }
);
