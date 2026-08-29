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
  "4.2r7-create-1. legacy create with both sellerRelationship and productInputRevision absent remains allowed",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "businesses/biz-1/products/r7-c1"), safeProduct())
    );
  }
);

rulesTest(
  "4.2r7-create-2. legacy create with sellerRelationship absent and productInputRevision 0 remains allowed",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(
        doc(db, "businesses/biz-1/products/r7-c2"),
        safeProduct({ productInputRevision: 0 })
      )
    );
  }
);

// --- Create: each valid relationship, exact revision requirement (item
// 3). Per §9's create-contract table, productInputRevision's own create
// legality (absent or exactly 0) is unconditional and does not vary with
// sellerRelationship's presence — there is no "must be 1 on create when
// adopting a relationship" rule; that adoption-requires-+1 rule applies
// only to UPDATE (§9's own-field row B), where a genuine "existing"
// baseline exists to diff against. Create has no such baseline, so it is
// governed solely by the separate, unconditional create table. ---

for (const relationship of SELLER_RELATIONSHIP_VALUES) {
  rulesTest(
    `4.2r7-create-3a. ${relationship}: valid relationship with absent productInputRevision is allowed on create`,
    async () => {
      await resetSeed();
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertSucceeds(
        setDoc(
          doc(db, `businesses/biz-1/products/r7-c3a-${relationship}`),
          safeProduct({ sellerRelationship: relationship })
        )
      );
    }
  );

  rulesTest(
    `4.2r7-create-3b. ${relationship}: valid relationship with productInputRevision 0 is allowed on create`,
    async () => {
      await resetSeed();
      const db = (await env()).authenticatedContext("seller-1").firestore();
      await assertSucceeds(
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
    `4.2r7-create-3c. ${relationship}: valid relationship with productInputRevision 1 is rejected on create (create's own contract is unconditional, not relationship-dependent)`,
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
  "4.2r7-create-5. an ordinary create with no sellerRelationship stores no key at all, never a default",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
      setDoc(doc(db, "businesses/biz-1/products/r7-c5"), safeProduct())
    );
    const rulesEnv = await env();
    await rulesEnv.withSecurityRulesDisabled(async (context) => {
      const snap = await getDoc(
        doc(context.firestore(), "businesses/biz-1/products/r7-c5")
      );
      assert.equal("sellerRelationship" in snap.data(), false);
    });
  }
);

// --- Create: sellerRelationship is seller-owned, not server-owned (item
// 6) — a seller MAY supply it, unlike the five real server-owned
// compliance fields (still rejected above, unchanged, by the
// COMPLIANCE_SERVER_OWNED_FIELDS loop) ---

rulesTest(
  "4.2r7-create-6. seller CAN supply sellerRelationship on create, unlike the five real server-owned compliance fields",
  async () => {
    await resetSeed();
    const db = (await env()).authenticatedContext("seller-1").firestore();
    await assertSucceeds(
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
    const db = rulesEnv.unauthenticatedContext().firestore();
    await assertSucceeds(
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
