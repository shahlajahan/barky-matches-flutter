"use strict";

const { HttpsError } = require("firebase-functions/v2/https");

const ACCOUNTING_PERIOD_STATUS = Object.freeze({
  OPEN: "open",
  CLOSED: "closed",
  LOCKED: "locked",
});

function assertPeriodMutable(period) {
  const status = String(period?.status || "").toLowerCase();
  if (
    status === ACCOUNTING_PERIOD_STATUS.CLOSED ||
    status === ACCOUNTING_PERIOD_STATUS.LOCKED
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Historical accounting periods are immutable; use an adjustment."
    );
  }
}

module.exports = {
  ACCOUNTING_PERIOD_STATUS,
  assertPeriodMutable,
};
