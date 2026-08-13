"use strict";

function planPrice(amount, currency, durationDays = 30) {
  const normalizedAmount = Number(amount);
  const normalizedCurrency = String(currency || "").trim().toUpperCase();
  if (!Number.isFinite(normalizedAmount) || normalizedAmount <= 0) {
    throw new Error("invalid-price");
  }
  if (!normalizedCurrency) throw new Error("missing-currency");
  return Object.freeze({
    amount: Math.round(normalizedAmount * 100) / 100,
    currency: normalizedCurrency,
    durationDays,
  });
}

const ADMIN_SUBSCRIPTION_CATALOG = Object.freeze({
  premium: planPrice(2.99, "USD"),
  gold: planPrice(9.99, "USD"),
});

function buildSubscriptionCatalog({premiumAmount, goldAmount, currency}) {
  return {
    premium: planPrice(premiumAmount, currency),
    gold: planPrice(goldAmount, currency),
  };
}

module.exports = {ADMIN_SUBSCRIPTION_CATALOG, buildSubscriptionCatalog, planPrice};
