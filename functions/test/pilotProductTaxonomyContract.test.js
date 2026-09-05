"use strict";

// =====================================================================
// Marketplace Revision 41 §0.39 — plan-contract tests for the expanded
// pilot product taxonomy.
//
// Revision 41 is CONTRACT-ONLY: it mints six new class identifiers in the
// Master Plan and changes no runtime code. These tests therefore prove two
// distinct things and never conflate them:
//
//   1. the amendment is present, complete and internally consistent; and
//   2. the runtime is still at its PRE-implementation state — the four
//      Revision 31 §C values — so slice 7C-1 has an exact, unambiguous
//      target and no one can mistake the contract for the implementation.
//
// Every architectural claim the amendment makes about existing code is
// checked against that code here, not assumed. If a later slice implements
// 7C-1, the two assertions marked PRE-IMPLEMENTATION below are the ones that
// must be updated, together with §15 item 1077.
//
// Follows the existing precedent of
// `marketplacePublicVisibilityContract.test.js`, which likewise pins a frozen
// contract to the Master Plan text.
// =====================================================================

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const REPO = path.join(__dirname, "..", "..");
const PLAN_PATH = path.join(
  REPO, "docs", "plans",
  "marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md"
);
const plan = fs.readFileSync(PLAN_PATH, "utf8");

function src(relative) {
  return fs.readFileSync(path.join(REPO, relative), "utf8");
}

const constantsSource = src("functions/src/marketplace/compliance/complianceConstants.js");
const approvalSource = src("functions/src/marketplace/compliance/pilotProductApproval.js");
const classificationSource = src("functions/src/marketplace/compliance/pilotProductClassification.js");
const evaluatorSource = src("functions/src/marketplace/compliance/complianceEligibilityEvaluator.js");
const publicVisibilitySource = src("functions/src/marketplace/publicCatalog/marketplacePublicVisibility.js");
const productVisibilitySource = src("functions/src/marketplace/publicCatalog/marketplaceProductVisibility.js");
const submitSource = src("functions/src/marketplace/product/submitMarketplaceProduct.js");
const rulesSource = src("firestore.rules");

const {
  PILOT_PRODUCT_CLASS,
  PILOT_PRODUCT_CLASS_VALUES,
  isValidPilotProductClass,
  COMPLIANCE_INTAKE_EVIDENCE_MATRIX,
  COMPLIANCE_INTAKE_UNRESOLVED_DOCUMENT_TYPES,
  SELLER_RELATIONSHIP,
} = require("../src/marketplace/compliance/complianceConstants");

// The ten frozen identifiers of Revision 41 §C.
const GROUP_A = [
  "sealed_dry_food",
  "sealed_wet_food",
  "non_medicinal_treats",
  "non_biocidal_litter",
];
const GROUP_B = [
  "pet_apparel",
  "collars_harnesses_leashes",
  "feeding_accessories",
  "beds_carriers",
  "non_electronic_toys",
  "grooming_accessories_non_chemical",
];
const ALL_CLASSES = [...GROUP_A, ...GROUP_B];

// The separate eight-value approval-call vocabulary, which must stay disjoint.
const APPROVAL_CATEGORIES = [
  "food", "treats", "litter", "toys",
  "collars_leads", "beds", "bowls", "grooming_tools",
];

// The taxonomy section of the plan, isolated so a match cannot be satisfied
// by unrelated prose elsewhere in a 6,000-line document.
const REV41 = (() => {
  const start = plan.indexOf("### 0.39 Revision 41 change log");
  assert.ok(start > 0, "Revision 41 §0.39 must exist in the master plan");
  const next = plan.indexOf("\n## ", start);
  return plan.slice(start, next === -1 ? plan.length : next);
})();

// =====================================================================
// The amendment exists and is complete
// =====================================================================

test("the amendment is recorded as Revision 41 §0.39 and is contract-only", () => {
  assert.match(REV41, /Pilot product taxonomy expansion, frozen \(contract-only/);
  assert.match(REV41, /\*\*This revision is contract-only\.\*\*/);
  // It must disclaim every runtime effect.
  for (const disclaimed of [
    "no implementation", "deployment", "Rules change", "migration",
    "seller activation", "approval or publication",
  ]) {
    assert.ok(
      REV41.includes(disclaimed),
      `the contract-only disclaimer must cover: ${disclaimed}`
    );
  }
});

test("all ten canonical identifiers are frozen in the amendment's own table", () => {
  for (const value of ALL_CLASSES) {
    assert.ok(
      REV41.includes(`\`${value}\``),
      `Revision 41 must freeze the identifier ${value}`
    );
  }
  // Group A is preserved verbatim, Group B is named as new.
  assert.match(REV41, /byte-identical to Revision 31 §C's originals/);
  assert.match(REV41, /The six Group B identifiers are new/);
});

test("the amendment retires 'exactly four' by naming each superseded assertion", () => {
  // It must supersede by explicit reference, never by silent rewriting.
  assert.match(REV41, /\*\*B\. Exact superseded assertions\.\*\*/);
  // Scoped to §B itself: a passing mention of a section elsewhere in the
  // amendment must not be able to satisfy the supersession list.
  const sectionB = REV41.slice(
    REV41.indexOf("**B. Exact superseded assertions.**"),
    REV41.indexOf("**C. The canonical taxonomy, frozen")
  );
  assert.ok(sectionB.length > 500, "§B must be a substantive list");
  for (const ref of ["Revision 31 §A", "Revision 31 §B", "Revision 31 §C", "Revision 31 §D", "Revision 35 §0.33"]) {
    assert.ok(sectionB.includes(ref), `§B must name the superseded source: ${ref}`);
  }
  // §15 items 1068/1071/1072 carried the four-value cardinality.
  assert.match(sectionB, /items 1068, 1071, 1072/);
});

test("historical revisions are not rewritten — Revision 31 §C's original four-row table survives", () => {
  // The amendment supersedes by addition; the original text must still be
  // readable in place, exactly as the plan's own amendment discipline requires.
  assert.ok(
    plan.includes("**C. D2 — the authoritative pilot class, frozen.**"),
    "Revision 31 §C must remain present and unaltered"
  );
  assert.ok(
    plan.includes("its value set is exactly and only"),
    "the superseded sentence must remain readable in its original place"
  );
  // And the superseded accessories sentence must still stand IN REVISION 31
  // ITSELF. Scoped deliberately: Revision 41 §B quotes the same sentence, so
  // an unscoped search would be satisfied by the quotation even if the
  // original had been rewritten.
  const rev31 = plan.slice(
    plan.indexOf("### 0.29 Revision 31 change log"),
    plan.indexOf("### 0.30 ")
  );
  assert.ok(rev31.length > 1000, "Revision 31's own section must be locatable");
  assert.ok(
    rev31.includes("Accessories — toys, collars and leads, beds, bowls, grooming tools — likewise remain outside the pilot"),
    "the superseded sentence must remain in Revision 31 itself, not be deleted"
  );
  assert.ok(
    rev31.includes("its value set is exactly and only"),
    "Revision 31 §C's original wording must remain in place"
  );
});

test("the amendment restores §21.12's own frozen scope rather than widening it", () => {
  // Every Group B class must trace to something §21.12 already allows.
  const scope = plan.slice(plan.indexOf("### 21.12 Accelerated commercial pilot scope"));
  for (const allowed of [
    "collars/leads", "bowls", "beds", "ordinary toys", "clothing", "carriers",
  ]) {
    assert.ok(
      scope.includes(allowed),
      `§21.12 must already include ${allowed} for Revision 41 to be a restoration`
    );
  }
  assert.match(REV41, /restores §21\.12's frozen scope; it does not widen it/);
});

// =====================================================================
// Exclusions stay closed
// =====================================================================

test("every excluded family is reaffirmed, including electrical/electronic products", () => {
  for (const excluded of [
    "Medicines", "vitamins", "supplements", "medicated food",
    "prescription or therapeutic veterinary diets", "biocides", "pesticides",
    "unpackaged or loose food",
  ]) {
    assert.ok(REV41.includes(excluded), `exclusion must be reaffirmed: ${excluded}`);
  }
  assert.match(
    REV41,
    /\*\*Electrical and electronic products are excluded\*\*/,
    "electronics must be excluded unless separately approved"
  );
  assert.match(REV41, /Uncertainty means exclusion, never provisional inclusion/);
});

test("no excluded family is minted as a class identifier", () => {
  const forbidden = [
    "vitamins", "supplements", "medicine", "medicated", "prescription",
    "flea", "tick", "biocide", "pesticide", "therapeutic", "electronic_toys",
  ];
  for (const value of ALL_CLASSES) {
    for (const bad of forbidden) {
      if (value === "non_electronic_toys" && bad === "electronic_toys") continue;
      assert.ok(
        !value.includes(bad),
        `class identifier ${value} must not name an excluded family (${bad})`
      );
    }
  }
});

// =====================================================================
// Internal consistency with the SEVEN named subsystems
// =====================================================================

test("consistency 1 — classification authority: one admin-only writer", () => {
  assert.match(
    classificationSource,
    /sole write authority for `pilotProductClass`/,
    "setPilotProductClassification must remain the sole writer"
  );
  // Rules keep the field server-owned on both create and update.
  assert.ok(rulesSource.includes("pilotProductClass"));
  assert.match(rulesSource, /`pilotProductClass` is server-owned/);
  assert.match(REV41, /\*\*Admin alone assigns or changes the class\*\*/);
});

test("consistency 2 — decision hash binds the class snapshot", () => {
  assert.ok(
    constantsSource.includes('"pilotProductClassSnapshot"'),
    "pilotProductClassSnapshot must be a bound decision field"
  );
  assert.match(REV41, /`pilotProductClassSnapshot` is a bound field of `decisionHash`/);
});

test("consistency 3 — approval fingerprint binds the live class", () => {
  const fingerprint = approvalSource.slice(
    approvalSource.indexOf("function computeApprovalFingerprint"),
    approvalSource.indexOf("function computeApprovalFingerprint") + 1200
  );
  assert.match(
    fingerprint,
    /pilotProductClass: product \? product\.pilotProductClass : null/,
    "the class must be a bound fingerprint input"
  );
  assert.match(REV41, /bound input #2 of the eleven-input `computeApprovalFingerprint`/);
});

test("consistency 4 — live eligibility routes through the single predicate", () => {
  for (const [label, source] of [
    ["evaluator", evaluatorSource],
    ["approval", approvalSource],
    ["classification", classificationSource],
    ["product visibility", productVisibilitySource],
  ]) {
    assert.ok(
      source.includes("isValidPilotProductClass"),
      `${label} must decide class validity through the shared predicate`
    );
  }
  // Which is what makes slice 7C-1 a one-constant change.
  assert.match(REV41, /This is the only runtime constant that must change/);
});

test("consistency 5 — callable-only discovery never leaks the class", () => {
  assert.ok(
    publicVisibilitySource.includes('"pilotProductClass"'),
    "pilotProductClass must remain a forbidden public field"
  );
  const forbidden = publicVisibilitySource.slice(
    publicVisibilitySource.indexOf("PUBLIC_FORBIDDEN_FIELDS"),
    publicVisibilitySource.indexOf("PUBLIC_FORBIDDEN_FIELDS") + 600
  );
  assert.match(forbidden, /pilotProductClass/);
});

test("consistency 6 — seller submission can never author the class", () => {
  assert.match(
    submitSource,
    /`pilotProductClass`/,
    "submission must name the field it refuses"
  );
  assert.match(
    REV41,
    /Seller category is descriptive only and can never determine `pilotProductClass`/
  );
  // No mapping table from category to class may exist anywhere.
  for (const [label, source] of [
    ["submit", submitSource],
    ["classification", classificationSource],
    ["approval", approvalSource],
  ]) {
    assert.ok(
      !/Food\s*>\s*Dry Food["'\s]*\]?\s*:/.test(source),
      `${label} must contain no category-to-class mapping`
    );
  }
});

test("consistency 7 — evidence linkage keys on relationship, not class", () => {
  // This is why Group B is not asked for food or chemical documents: no
  // document requirement is reachable from a class identifier at all.
  const matrixKeys = Object.keys(COMPLIANCE_INTAKE_EVIDENCE_MATRIX).sort();
  assert.deepEqual(matrixKeys, Object.values(SELLER_RELATIONSHIP).sort());
  for (const key of matrixKeys) {
    assert.ok(
      !ALL_CLASSES.includes(key),
      "no product class may key the intake evidence matrix"
    );
  }
  assert.match(REV41, /keys on the six-value `SELLER_RELATIONSHIP` enum and \*\*not\*\* on product class/);
});

test("category_compliance_evidence stays fail-closed for BOTH groups", () => {
  assert.deepEqual(
    [...COMPLIANCE_INTAKE_UNRESOLVED_DOCUMENT_TYPES],
    ["category_compliance_evidence"],
    "it must remain accepted for no relationship"
  );
  assert.match(
    REV41,
    /\*\*This revision does not activate it for either group\.\*\*/
  );
});

// =====================================================================
// The two vocabularies stay disjoint
// =====================================================================

test("the class enum and the approval-category enum share no value", () => {
  const { ALLOWED_PILOT_CATEGORIES } = require("../src/marketplace/compliance/pilotProductApproval");
  assert.deepEqual([...ALLOWED_PILOT_CATEGORIES].sort(), [...APPROVAL_CATEGORIES].sort());
  for (const category of ALLOWED_PILOT_CATEGORIES) {
    assert.ok(
      !ALL_CLASSES.includes(category),
      `${category} is an approval-call argument and must never be a class value`
    );
    assert.equal(
      isValidPilotProductClass(category),
      false,
      `${category} must be rejected as a pilotProductClass`
    );
  }
  assert.match(REV41, /the two vocabularies remain non-interchangeable/i);
});

test("the amendment retires the incorrect 'five values wider' narrowing obligation", () => {
  // §21.12 includes all eight, so the constant was never too wide.
  assert.match(REV41, /That statement is factually incorrect and is corrected here/);
  assert.match(REV41, /narrowing obligation Revision 31 §D imposed on slice 7 is \*\*retired\*\*/);
});

// =====================================================================
// Rules require no change (slice 7C-3's claim, verified)
// =====================================================================

test("firestore.rules never enumerates class VALUES, so the taxonomy needs no Rules change", () => {
  for (const value of ALL_CLASSES) {
    assert.ok(
      !rulesSource.includes(value),
      `firestore.rules must not enumerate the class value ${value}`
    );
  }
  assert.match(REV41, /`firestore\.rules` \*\*never enumerates class values\*\*/);
});

test("the Seller category allowlist is mirrored between Flutter and Rules, and is the real reachability gate", () => {
  const addProduct = src("lib/ui/business/petshop/add_product_page.dart");
  const sellerCategories = [
    "Food > Dry Food", "Food > Wet Food", "Food > Treats",
    "Accessories > Collar", "Accessories > Leash", "Accessories > Clothing",
    "Health > Vitamins", "Toys > Chew Toy", "Toys > Interactive",
  ];
  for (const category of sellerCategories) {
    assert.ok(
      rulesSource.includes(`'${category}'`),
      `Rules must mirror the seller category ${category}`
    );
  }
  // The Flutter side stores them split into main/sub.
  assert.match(addProduct, /"Food": \["Dry Food", "Wet Food", "Treats"\]/);
  assert.match(addProduct, /"Accessories": \["Collar", "Leash", "Clothing"\]/);
  // Which is exactly why slice 7C-5 exists.
  assert.match(REV41, /Required for the new classes to be reachable at all/);
});

// =====================================================================
// PRE-IMPLEMENTATION state — the exact target for slice 7C-1
// =====================================================================

test("PRE-IMPLEMENTATION: the runtime still carries only the four Revision 31 §C values", () => {
  // Revision 41 changes no runtime code. This assertion records the gap the
  // implementation slice must close; it is expected to be updated by 7C-1,
  // together with §15 item 1077.
  assert.deepEqual([...PILOT_PRODUCT_CLASS_VALUES].sort(), [...GROUP_A].sort());
  assert.equal(Object.isFrozen(PILOT_PRODUCT_CLASS), true);
  for (const value of GROUP_A) {
    assert.equal(isValidPilotProductClass(value), true, value);
  }
});

test("PRE-IMPLEMENTATION: the six new identifiers are contract-only and not yet accepted", () => {
  for (const value of GROUP_B) {
    assert.equal(
      isValidPilotProductClass(value),
      false,
      `${value} is frozen in the contract but must NOT yet be accepted by the runtime`
    );
  }
  // Meaning no Group B product can be classified, approved or published today.
  assert.match(REV41, /\*\*7C-1\*\*/);
});

// =====================================================================
// The publication invariant and the worked example
// =====================================================================

test("no product of any class publishes without an explicit admin approval", () => {
  assert.match(
    REV41,
    /no product of any class publishes without an Admin approval/i
  );
  assert.match(REV41, /Nothing in 7C-1 alone publishes anything/);
  assert.match(REV41, /Adding an identifier makes a product \*classifiable\*/);
});

test("the frozen worked example maps a handmade harness to review, not publication", () => {
  assert.ok(REV41.includes("handmade markalı göğüs tasması"));
  assert.match(REV41, /maps to \*\*`collars_harnesses_leashes`\*\*/);
  assert.match(REV41, /\*\*eligible for admin review\*\* — never automatically published/);
  assert.match(REV41, /"Eligible for review" is not "approved"/);
});

test("transition rules cover reclassification, invalidation, fail-closed aliases and migration", () => {
  assert.match(REV41, /Reclassifying an active product unpublishes it\*\*, atomically/);
  assert.match(REV41, /invalidates both the Decision and the Approval fingerprints/);
  assert.match(REV41, /fail closed.*Strict membership only/s);
  assert.match(REV41, /Existing four-class records remain valid/);
  assert.match(REV41, /\*\*No migration is required\.\*\*/);
  // The greenfield claim must cite already-recorded evidence, not new access.
  assert.match(REV41, /2026-09-05T04:53:22Z/);
  assert.match(REV41, /relies solely on that already-recorded evidence and performed no production access/);
  assert.match(REV41, /must be re-verified immediately before any enforcement deployment/);
});

test("reclassification of an active product is already implemented as the contract states", () => {
  // The amendment claims this is existing behaviour, not new work.
  assert.match(
    classificationSource,
    /unpublishes it atomically, through the single canonical revocation/,
    "the classification writer must already unpublish on reclassification"
  );
});

test("the §15 item range 1077-1090 is added without renumbering earlier items", () => {
  for (let item = 1077; item <= 1090; item += 1) {
    assert.ok(
      new RegExp(`^${item}\\. `, "m").test(REV41),
      `§15 item ${item} must be present`
    );
  }
  // Revision 31's own range must be untouched.
  assert.ok(plan.includes("1076. a claim discovered after classification"));
});
