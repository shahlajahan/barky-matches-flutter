"use strict";

class InventoryError extends Error {
  constructor(code, message, details = {}, options = {}) {
    super(message);
    this.name = "InventoryError";
    this.code = code;
    this.details = details;
    this.manualReview = options.manualReview === true;
  }
}

const error = (code, message, details, options) =>
  new InventoryError(code, message, details, options);

module.exports = { InventoryError, error };
