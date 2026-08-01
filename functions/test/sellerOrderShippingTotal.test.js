"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(
  path.resolve(__dirname, "../index.js"),
  "utf8"
);

function extractCheckoutSession() {
  const match = source.match(
    /exports\.createCheckoutSession = onCall\([\s\S]*?\n\);\n\nfunction normalizeCheckoutFailureReason/
  );
  assert.ok(match, "createCheckoutSession export not found");
  return match[0];
}

test("free shipping: seller shipping accumulator uses shippingFeeTotal, never sellerShippingCostTotal", () => {
  const fn = extractCheckoutSession();
  assert.match(
    fn,
    /sellerShippingTotal \+= buyerFacingShippingTotal;/
  );
  // The old nullish-fallback-to-cost bug must not be present anywhere.
  assert.doesNotMatch(
    fn,
    /sellerShippingTotal \+=\s*\n?\s*shippingCalc\.sellerShippingCostTotal \?\?/
  );
});

test("root order shipping accumulator is untouched by the fix", () => {
  const fn = extractCheckoutSession();
  assert.match(fn, /shippingTotal \+= shippingCalc\.shippingFeeTotal;/);
});

test("internal absorbed shipping cost is tracked in its own map, not merged into sellerPricingMap", () => {
  const fn = extractCheckoutSession();
  assert.match(fn, /const sellerAbsorbedShippingMap = new Map\(\);/);
  assert.match(
    fn,
    /sellerAbsorbedShippingCostTotal \+= asNumber\(\s*\n?\s*shippingCalc\.sellerShippingCostTotal,\s*\n?\s*0\s*\n?\s*\);/
  );
  // sellerPricingMap.set(...) — the object that becomes sellerOrder.pricing
  // wholesale — must contain exactly subtotal/shippingTotal/taxTotal/
  // grandTotal/commissionAmount and nothing shipping-cost related.
  const pricingMapSet = fn.match(
    /sellerPricingMap\.set\(businessId, \{[\s\S]*?\}\);/
  );
  assert.ok(pricingMapSet);
  assert.doesNotMatch(pricingMapSet[0], /sellerAbsorbedShippingCostTotal/);
  assert.doesNotMatch(pricingMapSet[0], /sellerShippingCostTotal/);
});

test("financial object carries the absorbed cost as its own explicit field, not via a spread of sellerPricing", () => {
  const fn = extractCheckoutSession();
  const financialWrite = fn.match(/financial: \{[\s\S]*?settlement: \{[\s\S]*?\},\s*\n\s*\},/);
  assert.ok(financialWrite, "financial object write not found");
  assert.match(financialWrite[0], /sellerAbsorbedShippingCostTotal,/);
  // Must never be spread wholesale from sellerPricing (which would risk
  // leaking arbitrary future keys into customer-facing financial fields).
  assert.doesNotMatch(financialWrite[0], /\.\.\.sellerPricing/);
});

test("grossAmount, businessNetAmount, sellerNetAmount, and payout.amount are derived only from sellerPricing.grandTotal / sellerNetAmount, never from the absorbed cost", () => {
  const fn = extractCheckoutSession();
  assert.match(fn, /grossAmount: sellerPricing\.grandTotal,/);
  assert.match(fn, /businessNetAmount: sellerNetAmount,/);
  assert.match(
    fn,
    /const sellerNetAmount = roundMoney\(\s*\n\s*sellerPricing\.grandTotal - sellerPricing\.commissionAmount\s*\n\s*\);/
  );
  assert.match(fn, /amount: sellerNetAmount,/);
  // None of these four assignments may reference the absorbed-cost variable.
  for (const pattern of [
    /grossAmount: sellerPricing\.grandTotal,/,
    /businessNetAmount: sellerNetAmount,/,
    /amount: sellerNetAmount,/,
  ]) {
    const line = fn.match(pattern)[0];
    assert.doesNotMatch(line, /AbsorbedShippingCost/);
  }
});

test("free-shipping invariant clamps the buyer-facing shipping charge to 0 and logs instead of throwing", () => {
  const fn = extractCheckoutSession();
  assert.match(
    fn,
    /shippingCalc\.shippingMode === "free_shipping" \|\|\s*\n\s*shippingCalc\.shippingMethod === "free_shipping"/
  );
  const invariantBlock = fn.match(
    /if \(\s*\n\s*\(shippingCalc\.shippingMode === "free_shipping"[\s\S]*?buyerFacingShippingTotal = 0;\s*\n\s*\}/
  );
  assert.ok(invariantBlock, "invariant clamp block not found");
  assert.match(invariantBlock[0], /logger\.error\("🚨 FREE SHIPPING INVARIANT VIOLATED"/);
  assert.doesNotMatch(invariantBlock[0], /throw /);
});

test("required structured logs are present", () => {
  const fn = extractCheckoutSession();
  assert.match(fn, /logger\.info\("🚚 SELLER SHIPPING ITEM", \{/);
  assert.match(fn, /logger\.info\("🧾 SELLER PRICING AGGREGATE", \{/);
  const itemLog = fn.match(/logger\.info\("🚚 SELLER SHIPPING ITEM", \{[\s\S]*?\}\);/)[0];
  for (const field of ["businessId", "shippingMode", "buyerShippingTotal", "sellerShippingCostTotal"]) {
    assert.match(itemLog, new RegExp(field));
  }
  const aggregateLog = fn.match(/logger\.info\("🧾 SELLER PRICING AGGREGATE", \{[\s\S]*?\}\);/)[0];
  for (const field of ["businessId", "sellerSubtotal", "sellerTaxTotal", "sellerGrandTotal", "buyerShippingTotal", "sellerShippingCostTotal"]) {
    assert.match(aggregateLog, new RegExp(field));
  }
});

test("finalizeIsbankPaidOrder persists the existing financial values without recomputation", () => {
  const finalizer = source.match(
    /async function finalizeIsbankPaidOrder\(\{[\s\S]*?await batch\.commit\(\);\s*\n\s*\}/
  );
  assert.ok(finalizer);
  assert.match(
    finalizer[0],
    /const sellerNetAmount = asNumber\(\s*\n\s*sellerOrder\.financial\?\.sellerNetAmount \?\? sellerOrder\.payout\?\.amount \?\? 0,/
  );
  assert.match(finalizer[0], /amount: sellerNetAmount,/);
});
