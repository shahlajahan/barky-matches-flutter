const { onCall } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const db = admin.firestore();

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function hasRequiredString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function validateClientReport(clientReport) {
  if (!isObject(clientReport)) {
    return "Diagnostics report payload is required.";
  }

  if (
    clientReport.schemaVersion === undefined ||
    clientReport.schemaVersion === null
  ) {
    return "schemaVersion is required.";
  }

  if (!hasRequiredString(clientReport.clientReportId)) {
    return "clientReportId is required.";
  }

  if (!hasRequiredString(clientReport.sessionId)) {
    return "sessionId is required.";
  }

  if (!hasRequiredString(clientReport.createdAt)) {
    return "createdAt is required.";
  }

  if (!hasRequiredString(clientReport.reason)) {
    return "reason is required.";
  }

  if (!hasRequiredString(clientReport.severity)) {
    return "severity is required.";
  }

  if (!isObject(clientReport.app)) {
    return "app is required.";
  }

  if (!isObject(clientReport.device)) {
    return "device is required.";
  }

  if (!isObject(clientReport.user)) {
    return "user is required.";
  }

  if (!isObject(clientReport.screen)) {
    return "screen is required.";
  }

  if (!Array.isArray(clientReport.logs)) {
    return "logs is required.";
  }

  return null;
}

exports.submitDiagnosticsReport = onCall(
  { region: "europe-west1" },
  async (request) => {
    const clientReport = request.data;
    const validationError = validateClientReport(clientReport);

    if (validationError) {
      logger.warn("Diagnostics report rejected: validation failed", {
        message: validationError,
      });
      return {
        success: false,
        code: "INVALID_REPORT",
        message: validationError,
      };
    }

    try {
      const reportRef = db.collection("debug_reports").doc();
      const receivedAt = admin.firestore.FieldValue.serverTimestamp();

      await reportRef.set({
        reportId: reportRef.id,
        receivedAt,
        status: "new",
        fingerprint: null,
        duplicate: false,
        duplicateOf: null,
        processedAt: null,
        reviewedAt: null,
        reviewedBy: null,
        adminNotes: null,
        clientReport,
      });

      logger.info("Diagnostics report stored", { reportId: reportRef.id });

      return {
        success: true,
        reportId: reportRef.id,
        duplicate: false,
      };
    } catch (error) {
      logger.error("Diagnostics report storage failed", {
        error: error instanceof Error ? error.message : String(error),
      });

      return {
        success: false,
        code: "SERVER_ERROR",
        message: "Failed to store diagnostics report.",
      };
    }
  }
);
