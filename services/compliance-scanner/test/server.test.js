"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const http = require("node:http");
const crypto = require("node:crypto");
const os = require("node:os");
const { createServer, MAX_BODY_BYTES } = require("../src/server");
const { createFakeGcsReader, createFakeClamdScanner } = require("../src/fakeAdapters");
const { CONTRACT_VERSION } = require("../src/contract");

const ALLOWED_BUCKET = "barkymatches-new.firebasestorage.app";
const quietLogger = { info() {}, warn() {}, error() {} };

function baseConfig(overrides = {}) {
  return {
    allowedBucket: ALLOWED_BUCKET,
    engineVersion: "clamav-1.2.3",
    signatureVersion: "sig-9",
    signatureBuiltAt: new Date(Date.now() - 60 * 60 * 1000).toISOString(),
    tmpDir: os.tmpdir(),
    ...overrides,
  };
}

function startTestServer({ config = baseConfig(), gcsReader, clamdScanner } = {}) {
  return new Promise((resolve) => {
    const server = createServer({
      config,
      gcsReader: gcsReader || createFakeGcsReader({ content: Buffer.from("ok") }),
      clamdScanner: clamdScanner || createFakeClamdScanner({ outcome: "clean" }),
      logger: quietLogger,
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function request({ port, method, path: reqPath, headers = {}, body }) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      { host: "127.0.0.1", port, method, path: reqPath, headers },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => {
          const text = Buffer.concat(chunks).toString("utf8");
          let parsed;
          try {
            parsed = JSON.parse(text);
          } catch (err) {
            parsed = null;
          }
          resolve({ status: res.statusCode, body: parsed, rawBody: text });
        });
      }
    );
    req.on("error", reject);
    if (body !== undefined) req.write(body);
    req.end();
  });
}

test("GET /healthz returns 200 with a healthy status for a reachable, fresh scanner", async () => {
  const server = await startTestServer();
  try {
    const { port } = server.address();
    const res = await request({ port, method: "GET", path: "/healthz" });
    assert.equal(res.status, 200);
    assert.equal(res.body.status, "healthy");
  } finally {
    server.close();
  }
});

test("GET /healthz returns 503 when the injected clamd is unreachable", async () => {
  const server = await startTestServer({ clamdScanner: createFakeClamdScanner({ reachable: false }) });
  try {
    const { port } = server.address();
    const res = await request({ port, method: "GET", path: "/healthz" });
    assert.equal(res.status, 503);
  } finally {
    server.close();
  }
});

test("POST /v1/scan with application/json and a valid body returns a clean verdict", async () => {
  const content = Buffer.from("a safe synthetic test document");
  const sha256 = crypto.createHash("sha256").update(content).digest("hex");
  const server = await startTestServer({ gcsReader: createFakeGcsReader({ content }) });
  try {
    const { port } = server.address();
    const body = JSON.stringify({
      contractVersion: CONTRACT_VERSION,
      requestId: "req-1",
      bucket: ALLOWED_BUCKET,
      objectPath: "compliance_quarantine/biz-1/sess-1/tok.pdf",
      generation: "111",
      sha256,
      sizeBytes: content.length,
    });
    const res = await request({
      port,
      method: "POST",
      path: "/v1/scan",
      headers: { "content-type": "application/json", "content-length": Buffer.byteLength(body) },
      body,
    });
    assert.equal(res.status, 200);
    assert.equal(res.body.verdict, "clean");
  } finally {
    server.close();
  }
});

test("POST /v1/scan without application/json content-type is rejected with 415, request never reaches validation", async () => {
  const gcsReader = createFakeGcsReader({ content: Buffer.from("x") });
  const server = await startTestServer({ gcsReader });
  try {
    const { port } = server.address();
    const body = "not even json";
    const res = await request({
      port,
      method: "POST",
      path: "/v1/scan",
      headers: { "content-type": "text/plain", "content-length": Buffer.byteLength(body) },
      body,
    });
    assert.equal(res.status, 415);
    assert.equal(gcsReader.calls.length, 0);
  } finally {
    server.close();
  }
});

test("POST /v1/scan with malformed JSON is rejected with 400", async () => {
  const server = await startTestServer();
  try {
    const { port } = server.address();
    const body = "{not valid json";
    const res = await request({
      port,
      method: "POST",
      path: "/v1/scan",
      headers: { "content-type": "application/json", "content-length": Buffer.byteLength(body) },
      body,
    });
    assert.equal(res.status, 400);
  } finally {
    server.close();
  }
});

test("POST /v1/scan with a body larger than the configured limit is rejected with 413 before JSON parsing", async () => {
  const gcsReader = createFakeGcsReader({ content: Buffer.from("x") });
  const server = await startTestServer({ gcsReader });
  try {
    const { port } = server.address();
    const oversizedBody = "a".repeat(MAX_BODY_BYTES + 1024);
    const res = await request({
      port,
      method: "POST",
      path: "/v1/scan",
      headers: { "content-type": "application/json", "content-length": Buffer.byteLength(oversizedBody) },
      body: oversizedBody,
    });
    assert.equal(res.status, 413);
    assert.equal(gcsReader.calls.length, 0);
  } finally {
    server.close();
  }
});

test("POST /v1/scan with an invalid request body (unknown field) is rejected with 400", async () => {
  const server = await startTestServer();
  try {
    const { port } = server.address();
    const body = JSON.stringify({
      contractVersion: CONTRACT_VERSION,
      requestId: "req-1",
      bucket: ALLOWED_BUCKET,
      objectPath: "compliance_quarantine/biz-1/sess-1/tok.pdf",
      generation: "111",
      sha256: "a".repeat(64),
      sizeBytes: 10,
      unexpectedField: "should not be here",
    });
    const res = await request({
      port,
      method: "POST",
      path: "/v1/scan",
      headers: { "content-type": "application/json", "content-length": Buffer.byteLength(body) },
      body,
    });
    assert.equal(res.status, 400);
    assert.equal(res.body.reason, "unexpected_field");
  } finally {
    server.close();
  }
});

// ---------------------------------------------------------------------
// GET /status (Slice 2.2) — must behave identically to GET /healthz in
// every respect: same handler, same response contract, same IAM-gated
// route path (no application-level auth code introduced anywhere), and
// must never leak any field beyond the existing safe
// {status, checks: {clamdReachable, signaturesLoaded, signaturesFresh}}
// shape.
// ---------------------------------------------------------------------

test("GET /status returns the same safe healthy result as GET /healthz", async () => {
  const server = await startTestServer();
  try {
    const { port } = server.address();
    const healthz = await request({ port, method: "GET", path: "/healthz" });
    const status = await request({ port, method: "GET", path: "/status" });
    assert.equal(status.status, 200);
    assert.deepEqual(status.body, healthz.body);
  } finally {
    server.close();
  }
});

test("GET /status returns 503/unhealthy when clamd is unreachable", async () => {
  const server = await startTestServer({ clamdScanner: createFakeClamdScanner({ reachable: false }) });
  try {
    const { port } = server.address();
    const res = await request({ port, method: "GET", path: "/status" });
    assert.equal(res.status, 503);
    assert.equal(res.body.status, "unhealthy");
    assert.equal(res.body.checks.clamdReachable, false);
  } finally {
    server.close();
  }
});

test("GET /status returns 503/unhealthy when signature metadata is missing", async () => {
  const server = await startTestServer({
    config: baseConfig({ signatureBuiltAt: null, engineVersion: null, signatureVersion: null }),
  });
  try {
    const { port } = server.address();
    const res = await request({ port, method: "GET", path: "/status" });
    assert.equal(res.status, 503);
    assert.equal(res.body.checks.signaturesLoaded, false);
  } finally {
    server.close();
  }
});

test("GET /status returns 503/unhealthy when signatures are stale", async () => {
  const server = await startTestServer({
    config: baseConfig({ signatureBuiltAt: new Date(Date.now() - 49 * 60 * 60 * 1000).toISOString() }),
  });
  try {
    const { port } = server.address();
    const res = await request({ port, method: "GET", path: "/status" });
    assert.equal(res.status, 503);
    assert.equal(res.body.checks.signaturesFresh, false);
  } finally {
    server.close();
  }
});

test("GET /status response contains no sensitive fields", async () => {
  const server = await startTestServer();
  try {
    const { port } = server.address();
    const res = await request({ port, method: "GET", path: "/status" });
    const serialized = JSON.stringify(res.body);
    const forbidden = [
      "bucket",
      "objectPath",
      "compliance_quarantine",
      "sha256",
      "generation",
      "project",
      "socket",
      "/var/run",
      "token",
      "credential",
      "PORT",
      "env",
    ];
    for (const term of forbidden) {
      assert.equal(
        serialized.toLowerCase().includes(term.toLowerCase()),
        false,
        `/status output must not mention "${term}"`
      );
    }
    // Closed field set — nothing beyond status/checks and the three
    // named booleans inside checks.
    assert.deepEqual(Object.keys(res.body).sort(), ["checks", "status"]);
    assert.deepEqual(
      Object.keys(res.body.checks).sort(),
      ["clamdReachable", "signaturesFresh", "signaturesLoaded"]
    );
  } finally {
    server.close();
  }
});

test("POST /status does not succeed — falls through to the standard 404, not the health handler", async () => {
  const server = await startTestServer();
  try {
    const { port } = server.address();
    const res = await request({ port, method: "POST", path: "/status" });
    assert.notEqual(res.status, 200);
    assert.equal(res.status, 404);
  } finally {
    server.close();
  }
});

test("/status/ (trailing slash), /STATUS (uppercase), and /statuss do not accidentally match the health handler", async () => {
  const server = await startTestServer();
  try {
    const { port } = server.address();
    for (const path of ["/status/", "/STATUS", "/statuss", "/Status"]) {
      const res = await request({ port, method: "GET", path });
      assert.equal(res.status, 404, `${path} must not match the /status handler`);
    }
  } finally {
    server.close();
  }
});

test("an unknown route returns 404", async () => {
  const server = await startTestServer();
  try {
    const { port } = server.address();
    const res = await request({ port, method: "GET", path: "/nope" });
    assert.equal(res.status, 404);
  } finally {
    server.close();
  }
});

test("GET /v1/scan (wrong method) does not route to the scan handler", async () => {
  const gcsReader = createFakeGcsReader({ content: Buffer.from("x") });
  const server = await startTestServer({ gcsReader });
  try {
    const { port } = server.address();
    const res = await request({ port, method: "GET", path: "/v1/scan" });
    assert.notEqual(res.status, 200);
    assert.equal(gcsReader.calls.length, 0);
  } finally {
    server.close();
  }
});

test("/v1/scan behavior is unchanged by the addition of /status (Slice 2.2 regression check)", async () => {
  const content = Buffer.from("a safe synthetic test document, unaffected by /status");
  const sha256 = crypto.createHash("sha256").update(content).digest("hex");
  const server = await startTestServer({ gcsReader: createFakeGcsReader({ content }) });
  try {
    const { port } = server.address();
    const body = JSON.stringify({
      contractVersion: CONTRACT_VERSION,
      requestId: "req-status-regression",
      bucket: ALLOWED_BUCKET,
      objectPath: "compliance_quarantine/biz-1/sess-1/tok.pdf",
      generation: "111",
      sha256,
      sizeBytes: content.length,
    });
    const res = await request({
      port,
      method: "POST",
      path: "/v1/scan",
      headers: { "content-type": "application/json", "content-length": Buffer.byteLength(body) },
      body,
    });
    assert.equal(res.status, 200);
    assert.equal(res.body.verdict, "clean");
  } finally {
    server.close();
  }
});
