"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  calculateMarketplaceShipping,
  resolveShippingMode,
} = require("../shipping/marketplaceShipping");

const carrierProduct = {
  shippingMode: "carrier_calculated",
  shippingPayer: "buyer",
  weightKg: 1,
  fixedDesi: 1,
};
const carrierConfig = {
  basePrice: 50,
  pricePerKg: 10,
  pricePerDesi: 5,
  freeShippingThreshold: 1,
};

test("free_shipping is always free for the buyer without a carrier estimate", () => {
  const result = calculateMarketplaceShipping({
    product: { shippingMode: "free_shipping", allowFreeShipping: false },
    quantity: 2,
    unitPrice: 10,
  });

  assert.equal(result.available, true);
  assert.equal(result.buyerShippingTotal, 0);
});

test("seller_absorbs never adds carrier cost to buyer total", () => {
  const result = calculateMarketplaceShipping({
    product: { ...carrierProduct, shippingMode: "seller_absorbs" },
    config: carrierConfig,
    quantity: 1,
    unitPrice: 10,
    selectedCarrier: "YURTICI",
  });

  assert.equal(result.buyerShippingTotal, 0);
  assert.equal(result.sellerShippingCostTotal, 50);
});

test("fixed_price preserves an intentional zero", () => {
  const result = calculateMarketplaceShipping({
    product: { shippingMode: "fixed_price", shippingFee: 0 },
    quantity: 3,
    unitPrice: 10,
  });

  assert.equal(result.available, true);
  assert.equal(result.buyerShippingTotal, 0);
});

test("fixed_price uses the configured fee and rejects a missing fee", () => {
  const charged = calculateMarketplaceShipping({
    product: { shippingMode: "fixed_price", shippingFee: 12.5 },
    quantity: 2,
    unitPrice: 10,
  });
  const unavailable = calculateMarketplaceShipping({
    product: { shippingMode: "fixed_price" },
    quantity: 1,
    unitPrice: 10,
  });

  assert.equal(charged.buyerShippingTotal, 25);
  assert.equal(unavailable.available, false);
  assert.equal(unavailable.reason, "fixed_shipping_fee_missing");
});

test("carrier_calculated uses configured estimator only with required inputs", () => {
  const charged = calculateMarketplaceShipping({
    product: carrierProduct,
    config: carrierConfig,
    quantity: 1,
    unitPrice: 10,
    selectedCarrier: "YURTICI",
  });
  const unavailable = calculateMarketplaceShipping({
    product: { ...carrierProduct, fixedDesi: null },
    config: carrierConfig,
    quantity: 1,
    unitPrice: 10,
    selectedCarrier: "YURTICI",
  });

  assert.equal(charged.buyerShippingTotal, 50);
  assert.equal(unavailable.available, false);
  assert.equal(unavailable.reason, "shipping_dimensions_missing");
});

test("conditional free shipping requires the product campaign switch", () => {
  const disabled = calculateMarketplaceShipping({
    product: {
      shippingMode: "fixed_price",
      shippingFee: 20,
      allowFreeShipping: false,
      freeShippingThreshold: 100,
    },
    config: { freeShippingThreshold: 1 },
    quantity: 1,
    unitPrice: 150,
  });
  const enabled = calculateMarketplaceShipping({
    product: {
      shippingMode: "fixed_price",
      shippingFee: 20,
      allowFreeShipping: true,
      freeShippingThreshold: 100,
    },
    quantity: 1,
    unitPrice: 150,
  });

  assert.equal(disabled.buyerShippingTotal, 20);
  assert.equal(enabled.buyerShippingTotal, 0);
});

test("legacy explicit zero shippingFee resolves as fixed price", () => {
  assert.equal(resolveShippingMode({ shippingFee: 0 }), "fixed_price");
});

test("all authoritative marketplace pricing paths load product shipping data", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const source = fs.readFileSync(path.resolve(__dirname, "../index.js"), "utf8");

  const checkout = source.match(
    /exports\.createCheckoutSession[\s\S]*?exports\.createMarketplaceOrderV2/
  );
  const order = source.match(
    /exports\.createMarketplaceOrderV2[\s\S]*?exports\.updateSellerOrderStatusV2/
  );
  const pricing = source.match(
    /exports\.calculatePricing[\s\S]*?function slugify/
  );
  assert.ok(checkout);
  assert.ok(order);
  assert.ok(pricing);
  assert.match(checkout[0], /productData/);
  assert.match(order[0], /productData/);
  assert.match(pricing[0], /productData:\s*product/);
});
