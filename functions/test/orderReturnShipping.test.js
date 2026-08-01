"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(
  path.resolve(__dirname, "../index.js"),
  "utf8"
);

function loadReturnShippingHelpers() {
  const match = source.match(
    /const RETURN_SHIPPING_RESPONSIBILITIES = \[[\s\S]*?\n\}\n\nasync function uploadReturnImagesToStorage/
  );
  assert.ok(match, "return-shipping helper block not found");
  const helperSource = match[0].replace(
    /\nasync function uploadReturnImagesToStorage$/,
    ""
  );

  class TestHttpsError extends Error {
    constructor(code, message) {
      super(message);
      this.code = code;
    }
  }

  const context = {
    HttpsError: TestHttpsError,
    normalizeLower: (value) => String(value || "").trim().toLowerCase(),
  };
  vm.runInNewContext(
    `${helperSource}
    this.helpers = {
      buildInitialReturnShipping,
      verifyContractedReturnCarrierProducts,
      resolveApprovedReturnShipping,
      buildRefundCalculation,
      normalizeRefundDecisionType,
      validateRefundDecisionPolicy,
      buildRefundDecisionFields,
    };`,
    context
  );
  return context.helpers;
}

const helpers = loadReturnShippingHelpers();

test("buyer responsibility resolves to buyer without a shipping-cost deduction", () => {
  const result = helpers.resolveApprovedReturnShipping({
    requestedResponsibility: "buyer",
    products: [{ productId: "p1" }],
    decidedAt: "server-time",
    decidedBy: "seller-1",
  });

  assert.equal(result.returnShipping.resolution, "buyer");
  assert.equal(result.returnShipping.costAmount, null);
  assert.equal(result.returnShipping.costStatus, "unknown");
  assert.equal(result.returnShipping.costSource, "not_available");
  assert.equal(result.returnShipping.buyerWarningRequired, true);
});

test("seller responsibility resolves to seller without reducing buyer refund", () => {
  const result = helpers.resolveApprovedReturnShipping({
    requestedResponsibility: "seller",
    products: [{ productId: "p1" }],
    decidedAt: "server-time",
    decidedBy: "seller-1",
  });
  const calculation = helpers.buildRefundCalculation({
    returnItemsAmount: 100,
    outboundShippingAmount: 20,
    returnShipping: result.returnShipping,
    requestedRefundAmount: 100,
    maxAllowedRefund: 100,
    finalRefundAmount: 100,
    currency: "TRY",
    calculatedAt: "server-time",
  });

  assert.equal(result.returnShipping.resolution, "seller");
  assert.equal(calculation.finalRefundAmount, 100);
  assert.equal(calculation.returnShippingCostAmount, null);
});

test("contracted carrier succeeds only when every product has one common valid carrier", () => {
  const result = helpers.resolveApprovedReturnShipping({
    requestedResponsibility: "seller_if_contract_carrier",
    products: [
      {
        productId: "p1",
        hasContractedReturnCarrier: true,
        returnCarrierCode: "Yurtici",
      },
      {
        productId: "p2",
        hasContractedReturnCarrier: true,
        returnCarrierCode: "Yurtici",
      },
    ],
    decidedAt: "server-time",
    decidedBy: "seller-1",
  });

  assert.equal(result.returnShipping.resolution, "seller");
  assert.equal(result.returnShipping.contractedCarrierVerified, true);
  assert.equal(result.returnShipping.carrierCode, "Yurtici");
  assert.deepEqual(
    Array.from(result.decisionSnapshot.productIds),
    ["p1", "p2"]
  );
});

test("contracted carrier fails safely when any returned product is unconfigured", () => {
  assert.throws(
    () =>
      helpers.resolveApprovedReturnShipping({
        requestedResponsibility: "seller_if_contract_carrier",
        products: [
          {
            productId: "p1",
            hasContractedReturnCarrier: true,
            returnCarrierCode: "Yurtici",
          },
          {
            productId: "p2",
            hasContractedReturnCarrier: false,
            returnCarrierCode: null,
          },
        ],
        decidedAt: "server-time",
        decidedBy: "seller-1",
      }),
    (error) =>
      error.code === "failed-precondition" &&
      error.message ===
        "Contracted return carrier is not configured for all returned items."
  );
});

test("contracted carrier fails when returned products configure different carriers", () => {
  assert.throws(
    () =>
      helpers.resolveApprovedReturnShipping({
        requestedResponsibility: "seller_if_contract_carrier",
        products: [
          {
            productId: "p1",
            hasContractedReturnCarrier: true,
            returnCarrierCode: "Yurtici",
          },
          {
            productId: "p2",
            hasContractedReturnCarrier: true,
            returnCarrierCode: "Aras",
          },
        ],
        decidedAt: "server-time",
        decidedBy: "seller-1",
      }),
    (error) => error.code === "failed-precondition"
  );
});

test("decision snapshot contains the immutable audit fields", () => {
  const result = helpers.resolveApprovedReturnShipping({
    requestedResponsibility: "seller",
    products: [{ productId: "p1" }],
    decidedAt: "server-time",
    decidedBy: "seller-1",
  });

  assert.deepEqual(
    JSON.parse(JSON.stringify(result.decisionSnapshot)),
    {
      requestedResponsibility: "seller",
      resolvedResponsibility: "seller",
      contractedCarrierVerified: false,
      carrierCode: null,
      productIds: ["p1"],
      decidedBy: "seller-1",
      decidedAt: "server-time",
      policyVersion: 1,
    }
  );
  assert.match(
    source,
    /if \(freshReturnData\.returnShippingDecisionSnapshot\) \{/
  );
  assert.match(
    source,
    /returnShippingDecisionSnapshot:\s*\n\s*approvedShipping\.decisionSnapshot/
  );
});

test("refund calculation separates outbound and unknown return shipping", () => {
  const calculation = helpers.buildRefundCalculation({
    returnItemsAmount: 150,
    outboundShippingAmount: 25,
    returnShipping: {
      responsibility: "buyer",
      resolution: "buyer",
      costAmount: null,
      costStatus: "unknown",
    },
    requestedRefundAmount: 150,
    maxAllowedRefund: 150,
    finalRefundAmount: 150,
    currency: "TRY",
    calculatedAt: "server-time",
  });

  assert.equal(calculation.returnItemsAmount, 150);
  assert.equal(calculation.outboundShippingAmount, 25);
  assert.equal(calculation.returnShippingResponsibility, "buyer");
  assert.equal(calculation.returnShippingCostAmount, null);
  assert.equal(calculation.returnShippingCostStatus, "unknown");
  assert.equal(calculation.finalRefundAmount, 150);
  assert.equal(calculation.calculationVersion, 1);
  assert.match(source, /refundCalculation,/);
});

test("legacy return data can produce a refund calculation without returnShipping", () => {
  const calculation = helpers.buildRefundCalculation({
    returnItemsAmount: 80,
    outboundShippingAmount: 10,
    returnShipping: null,
    requestedRefundAmount: 80,
    maxAllowedRefund: 80,
    finalRefundAmount: 80,
    currency: "TRY",
    calculatedAt: "server-time",
  });

  assert.equal(calculation.returnShippingResponsibility, null);
  assert.equal(calculation.returnShippingCostAmount, null);
  assert.equal(calculation.returnShippingCostStatus, "unknown");
  assert.equal(calculation.finalRefundAmount, 80);
});

test("full refund policy records a complete auditable decision", () => {
  helpers.validateRefundDecisionPolicy({
    decisionType: "FULL",
    reasonCode: "defective_product",
    sellerNotes: "",
    buyerExplanation: "",
    refundAmount: 100,
    maxAllowedRefund: 100,
    enforcePolicy: true,
  });
  const fields = helpers.buildRefundDecisionFields({
    decisionType: "FULL",
    reasonCode: "defective_product",
    sellerNotes: "",
    buyerExplanation: "",
    eligibleRefundAmount: 100,
    finalRefundAmount: 100,
    sellerDecisionAt: "server-time",
    sellerDecisionUid: "seller-1",
  });

  assert.equal(fields.refundDecisionType, "FULL");
  assert.equal(fields.refundReason, "Defective product");
  assert.equal(fields.refundDifference, 0);
  assert.match(
    source,
    /refundType === "full"\s*\n\s*\? originalPaidAmount/
  );
  assert.match(
    source,
    /refundAmount: clampedRefundAmount,[\s\S]*?isFullRefund:/
  );
});

test("partial refund policy requires bounded amount, reason, and seller notes", () => {
  assert.throws(
    () =>
      helpers.validateRefundDecisionPolicy({
        decisionType: "PARTIAL",
        reasonCode: "missing_accessories",
        sellerNotes: "",
        buyerExplanation: "",
        refundAmount: 70,
        maxAllowedRefund: 100,
        enforcePolicy: true,
      }),
    (error) => error.code === "invalid-argument"
  );
  assert.throws(
    () =>
      helpers.validateRefundDecisionPolicy({
        decisionType: "PARTIAL",
        reasonCode: "missing_accessories",
        sellerNotes: "Accessory was not returned",
        buyerExplanation: "Accessory was not returned",
        refundAmount: 101,
        maxAllowedRefund: 100,
        enforcePolicy: true,
      }),
    (error) => error.code === "invalid-argument"
  );
  helpers.validateRefundDecisionPolicy({
    decisionType: "PARTIAL",
    reasonCode: "missing_accessories",
    sellerNotes: "Accessory was not returned",
    buyerExplanation: "Accessory was not returned",
    refundAmount: 70,
    maxAllowedRefund: 100,
    enforcePolicy: true,
  });
});

test("refund rejection requires notes and buyer-visible explanation", () => {
  assert.throws(
    () =>
      helpers.validateRefundDecisionPolicy({
        decisionType: "REJECTED",
        reasonCode: "customer_caused_damage",
        sellerNotes: "Damage documented",
        buyerExplanation: "",
        refundAmount: 0,
        maxAllowedRefund: 100,
        enforcePolicy: true,
      }),
    (error) => error.code === "invalid-argument"
  );
  helpers.validateRefundDecisionPolicy({
    decisionType: "REJECTED",
    reasonCode: "customer_caused_damage",
    sellerNotes: "Damage documented",
    buyerExplanation: "The returned item has customer-caused damage.",
    refundAmount: 0,
    maxAllowedRefund: 100,
    enforcePolicy: true,
  });
});

test("legacy refund calls remain outside the new mandatory policy validation", () => {
  helpers.validateRefundDecisionPolicy({
    decisionType: "PARTIAL",
    reasonCode: "",
    sellerNotes: "",
    buyerExplanation: "",
    refundAmount: 10,
    maxAllowedRefund: 100,
    enforcePolicy: false,
  });
  assert.equal(helpers.normalizeRefundDecisionType(null, "partial"), "PARTIAL");
});
