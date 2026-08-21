"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// service, HTTP server wiring (Slice 2.1, part C). Thin routing only —
// all real logic lives in scanHandler.js/healthHandler.js. Adapters
// (gcsReader, clamdScanner) are always injected, never constructed here
// — production wiring lives in index.js, tests inject fakeAdapters.js.
//
// No request-level authentication is implemented in this server by
// design ("authenticate invocation through Cloud Run/IAM at deployment;
// do not invent a shared bearer secret" — Slice 2.1 spec). Cloud Run's
// own IAM (roles/run.invoker granted only to the compliance Functions'
// runtime identity — see the deployment-readiness doc) is what makes
// this service unreachable by anyone else; a request that reaches this
// code has already been authenticated and authorized at the platform
// layer. Implementing a second, application-level auth scheme here
// (e.g. a shared bearer secret) would be redundant at best and, if that
// secret ever leaked, a strictly worse boundary than IAM.

const http = require("node:http");
const { handleScanRequest } = require("./scanHandler");
const { handleHealthCheck } = require("./healthHandler");
const { createLogger } = require("./logger");

// The request never carries raw document bytes — only a handful of
// short fields (contractVersion/requestId/bucket/objectPath/generation/
// sha256/sizeBytes) — so the body limit is deliberately small. Anything
// larger is rejected before it is even parsed as JSON.
const MAX_BODY_BYTES = 16 * 1024;

function readJsonBody(req, { maxBytes = MAX_BODY_BYTES } = {}) {
  return new Promise((resolve, reject) => {
    let total = 0;
    let overLimit = false;
    const chunks = [];
    req.on("data", (chunk) => {
      if (overLimit) return;
      total += chunk.length;
      if (total > maxBytes) {
        // Deliberately do NOT destroy the socket here — req and res
        // share the same underlying connection, and destroying it would
        // prevent the caller from ever sending its 413 response (the
        // client would see a bare connection reset instead of a proper
        // HTTP error). Just stop accumulating further chunks and reject
        // — the caller sends 413 over `res` normally.
        overLimit = true;
        reject(Object.assign(new Error("body_too_large"), { code: "BODY_TOO_LARGE" }));
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      if (overLimit) return;
      try {
        const text = Buffer.concat(chunks).toString("utf8");
        resolve(text.length ? JSON.parse(text) : {});
      } catch (err) {
        reject(Object.assign(new Error("invalid_json"), { code: "INVALID_JSON" }));
      }
    });
    req.on("error", (err) => {
      if (overLimit) return;
      reject(err);
    });
  });
}

function sendJson(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

function createServer({ config, gcsReader, clamdScanner, logger = createLogger() }) {
  const server = http.createServer(async (req, res) => {
    try {
      if (req.method === "GET" && req.url === "/healthz") {
        const result = await handleHealthCheck({ config, clamdScanner });
        sendJson(res, result.status, result.body);
        return;
      }

      if (req.method === "POST" && req.url === "/v1/scan") {
        const contentType = String(req.headers["content-type"] || "");
        if (!contentType.toLowerCase().startsWith("application/json")) {
          sendJson(res, 415, { error: "unsupported_media_type" });
          return;
        }

        let body;
        try {
          body = await readJsonBody(req);
        } catch (err) {
          if (err.code === "BODY_TOO_LARGE") {
            sendJson(res, 413, { error: "request_too_large" });
          } else {
            sendJson(res, 400, { error: "invalid_json" });
          }
          return;
        }

        const result = await handleScanRequest({ body, config, gcsReader, clamdScanner, logger });
        sendJson(res, result.status, result.body);
        return;
      }

      sendJson(res, 404, { error: "not_found" });
    } catch (err) {
      logger.error({ event: "unhandled_server_error" });
      sendJson(res, 500, { error: "internal_error" });
    }
  });

  return server;
}

module.exports = { createServer, readJsonBody, sendJson, MAX_BODY_BYTES };
