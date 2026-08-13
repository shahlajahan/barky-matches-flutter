"use strict";

// Google-only Functions configuration. Keep this declaration out of the main
// Apple Functions module so Firebase analysis of Apple targets does not prompt
// for the Google service-account secret.
// A literal secret resource name is valid in a Functions `secrets` option.
// Keeping it as a string avoids registering the Google secret as a global
// parameter during Firebase analysis of Apple-only targets. Google handlers
// read the injected value only at runtime.
const GOOGLE_PLAY_SERVICE_ACCOUNT_JSON = "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON";
// Keep the established package-name configuration available to Google
// handlers without registering a Google-only deployment parameter globally.
const GOOGLE_PLAY_PACKAGE_NAME = "com.petsupo.app";

module.exports = {
  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON,
  GOOGLE_PLAY_PACKAGE_NAME,
};
