"use strict";

const KNOWN_MODES = new Set([
  "free_shipping",
  "seller_absorbs",
  "fixed_price",
  "carrier_calculated",
]);

function finiteNumber(value) {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function positiveNumber(value) {
  const number = finiteNumber(value);
  return number !== null && number > 0 ? number : null;
}

function nonNegativeNumber(value) {
  const number = finiteNumber(value);
  return number !== null && number >= 0 ? number : null;
}

function roundMoney(value) {
  return Number((Number(value) || 0).toFixed(2));
}

function resolveShippingMode(product = {}) {
  const configured = String(product.shippingMode || "").trim().toLowerCase();
  if (KNOWN_MODES.has(configured)) return configured;

  // Legacy products with an explicit fee retain fixed-price semantics.
  if (
    Object.prototype.hasOwnProperty.call(product, "shippingFee") &&
    nonNegativeNumber(product.shippingFee) !== null
  ) {
    return "fixed_price";
  }
  return "carrier_calculated";
}

function estimateCarrierCost({
  product,
  config,
  quantity,
  selectedCarrier,
}) {
  const fixedDesi = positiveNumber(product.fixedDesi);
  const lengthCm = positiveNumber(product.lengthCm);
  const widthCm = positiveNumber(product.widthCm);
  const heightCm = positiveNumber(product.heightCm);
  const weightKg = positiveNumber(product.weightKg);
  const hasDimensions =
    lengthCm !== null && widthCm !== null && heightCm !== null;

  if (fixedDesi === null && !hasDimensions) {
    return { available: false, reason: "shipping_dimensions_missing" };
  }
  if (weightKg === null) {
    return { available: false, reason: "shipping_weight_missing" };
  }
  if (!String(selectedCarrier || "").trim()) {
    return { available: false, reason: "shipping_carrier_missing" };
  }
  const normalizedCarrier = String(selectedCarrier).trim().toUpperCase();
  const allowedCarriers = Array.isArray(product.allowedCarrierCodes)
    ? product.allowedCarrierCodes
      .map((carrier) => String(carrier).trim().toUpperCase())
      .filter(Boolean)
    : [];
  if (
    allowedCarriers.length > 0 &&
    !allowedCarriers.includes(normalizedCarrier)
  ) {
    return { available: false, reason: "shipping_carrier_not_allowed" };
  }

  const basePrice = nonNegativeNumber(config?.basePrice);
  if (basePrice === null) {
    return { available: false, reason: "shipping_configuration_missing" };
  }
  const pricePerKg = nonNegativeNumber(config?.pricePerKg) ?? 0;
  const pricePerDesi = nonNegativeNumber(config?.pricePerDesi) ?? 0;
  const desi =
    fixedDesi ??
    ((lengthCm || 0) * (widthCm || 0) * (heightCm || 0)) / 3000;

  let unitCost = basePrice;
  if (weightKg > 1) unitCost += (weightKg - 1) * pricePerKg;
  if (desi > 1) unitCost += (desi - 1) * pricePerDesi;

  return {
    available: true,
    carrierCostTotal: roundMoney(unitCost * quantity),
    desi,
  };
}

function calculateMarketplaceShipping({
  product = {},
  config = {},
  quantity = 1,
  unitPrice = 0,
  selectedCarrier = "",
}) {
  const normalizedQuantity = Math.max(1, Math.floor(Number(quantity) || 1));
  const mode = resolveShippingMode(product);
  const shippingPayer = String(product.shippingPayer || "")
    .trim()
    .toLowerCase();
  const itemSubtotal = roundMoney(
    (finiteNumber(unitPrice) || 0) * normalizedQuantity
  );

  if (product.isShippable === false || product.deliveryType === "digital") {
    return {
      available: true,
      mode,
      method: "no_shipping",
      buyerShippingTotal: 0,
      sellerShippingCostTotal: 0,
      desi: 0,
    };
  }

  const campaignThreshold = positiveNumber(product.freeShippingThreshold);
  const conditionalFree =
    product.allowFreeShipping === true &&
    campaignThreshold !== null &&
    itemSubtotal >= campaignThreshold;

  if (mode === "free_shipping" || mode === "seller_absorbs") {
    const estimate = estimateCarrierCost({
      product,
      config,
      quantity: normalizedQuantity,
      selectedCarrier,
    });
    return {
      available: true,
      mode,
      method: mode,
      buyerShippingTotal: 0,
      sellerShippingCostTotal: estimate.available
        ? estimate.carrierCostTotal
        : null,
      desi: estimate.available ? estimate.desi : null,
    };
  }

  if (mode === "fixed_price") {
    const fixedFee = nonNegativeNumber(product.shippingFee);
    if (fixedFee === null) {
      return { available: false, mode, reason: "fixed_shipping_fee_missing" };
    }
    const fixedTotal = roundMoney(fixedFee * normalizedQuantity);
    const buyerShippingTotal =
      conditionalFree || shippingPayer === "seller" ? 0 : fixedTotal;
    return {
      available: true,
      mode,
      method: conditionalFree ? "conditional_free_shipping" : "fixed_price",
      buyerShippingTotal,
      sellerShippingCostTotal: buyerShippingTotal === 0 ? fixedTotal : 0,
      desi: positiveNumber(product.fixedDesi),
    };
  }

  const estimate = estimateCarrierCost({
    product,
    config,
    quantity: normalizedQuantity,
    selectedCarrier,
  });
  if (!estimate.available) return { ...estimate, mode };

  const buyerShippingTotal =
    conditionalFree || shippingPayer === "seller"
      ? 0
      : estimate.carrierCostTotal;
  return {
    available: true,
    mode,
    method: conditionalFree
      ? "conditional_free_shipping"
      : "carrier_calculated",
    buyerShippingTotal,
    sellerShippingCostTotal:
      buyerShippingTotal === 0 ? estimate.carrierCostTotal : 0,
    desi: estimate.desi,
  };
}

module.exports = {
  calculateMarketplaceShipping,
  resolveShippingMode,
};
