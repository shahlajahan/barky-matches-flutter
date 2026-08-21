"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const net = require("node:net");
const { parseClamdResponse, scanBufferWithClamd, pingClamd, classifySignatureName } = require("../src/clamdProtocol");

// ---------------------------------------------------------------------
// Pure response parsing — no socket at all
// ---------------------------------------------------------------------

test("parseClamdResponse recognizes a clean OK reply", () => {
  assert.equal(parseClamdResponse("stream: OK").outcome, "clean");
});

test("parseClamdResponse recognizes an infected FOUND reply and extracts the signature name", () => {
  const result = parseClamdResponse("stream: Eicar-Test-Signature FOUND");
  assert.equal(result.outcome, "infected");
  assert.equal(result.signatureName, "Eicar-Test-Signature");
});

test("parseClamdResponse recognizes an ERROR reply", () => {
  const result = parseClamdResponse("stream: Access denied ERROR");
  assert.equal(result.outcome, "error");
});

test("parseClamdResponse treats an empty or unparseable reply as an error, never clean", () => {
  assert.equal(parseClamdResponse("").outcome, "error");
  assert.equal(parseClamdResponse("   ").outcome, "error");
  assert.equal(parseClamdResponse("something unexpected").outcome, "error");
});

test("parseClamdResponse strips embedded null bytes before matching", () => {
  assert.equal(parseClamdResponse("stream: OK\0").outcome, "clean");
});

// ---------------------------------------------------------------------
// Slice 2.1 correction, part C — encrypted/unsupported classification.
// Exact parsing tests for every required case.
// ---------------------------------------------------------------------

test("OK maps to clean", () => {
  const result = parseClamdResponse("stream: OK");
  assert.equal(result.outcome, "clean");
});

test("a real EICAR test-signature FOUND maps to infected", () => {
  const result = parseClamdResponse("stream: Eicar-Test-Signature FOUND");
  assert.equal(result.outcome, "infected");
  assert.equal(result.signatureName, "Eicar-Test-Signature");
});

test("an ordinary named malware FOUND maps to infected", () => {
  const result = parseClamdResponse("stream: Win.Trojan.Generic-12345 FOUND");
  assert.equal(result.outcome, "infected");
  assert.equal(result.signatureName, "Win.Trojan.Generic-12345");
});

test("Heuristics.Encrypted.PDF FOUND maps to unsupported, never infected, never clean", () => {
  const result = parseClamdResponse("stream: Heuristics.Encrypted.PDF FOUND");
  assert.equal(result.outcome, "unsupported");
  assert.equal(result.reason, "encrypted_document_unsupported");
  assert.notEqual(result.outcome, "infected");
  assert.notEqual(result.outcome, "clean");
});

test("an encrypted-archive heuristic (Heuristics.Encrypted.Zip) also maps to unsupported", () => {
  const result = parseClamdResponse("stream: Heuristics.Encrypted.Zip FOUND");
  assert.equal(result.outcome, "unsupported");
  assert.equal(result.reason, "encrypted_document_unsupported");
});

test("an UNKNOWN heuristic-looking name is treated as infected, not given the benefit of the doubt", () => {
  // Deliberately similar in shape to the allowlisted family but not an
  // exact match — proves this is a narrow allowlist, not a broad
  // "anything starting with Heuristics" downgrade.
  const result = parseClamdResponse("stream: Heuristics.SuspiciousMacro.Generic FOUND");
  assert.equal(result.outcome, "infected");
  assert.notEqual(result.outcome, "unsupported");
});

test("a malformed clamd response never maps to clean, infected, or unsupported", () => {
  const result = parseClamdResponse("this is not a real clamd reply at all");
  assert.equal(result.outcome, "error");
  assert.notEqual(result.outcome, "clean");
  assert.notEqual(result.outcome, "infected");
  assert.notEqual(result.outcome, "unsupported");
});

test("classifySignatureName only recognizes the exact Heuristics.Encrypted. prefix, case-sensitively", () => {
  assert.equal(classifySignatureName("Heuristics.Encrypted.PDF"), "unsupported");
  assert.equal(classifySignatureName("Heuristics.Encrypted.RAR"), "unsupported");
  assert.equal(classifySignatureName("Heuristics.Encrypted.DOC"), "unsupported");
  assert.equal(classifySignatureName("heuristics.encrypted.pdf"), "infected", "must be case-sensitive, not case-insensitively broadened");
  assert.equal(classifySignatureName("Heuristics.EncryptedSomethingElse.PDF"), "infected", "must match the exact family, not merely a prefix substring");
  assert.equal(classifySignatureName("Eicar-Test-Signature"), "infected");
});

// ---------------------------------------------------------------------
// Real socket I/O against a local fake "clamd" TCP server (no Docker,
// no real ClamAV — a genuine socket exercising the actual framing code,
// not a mocked function).
// ---------------------------------------------------------------------

function startFakeClamd({ reply, delayMs = 0, dropConnection = false } = {}) {
  return new Promise((resolve) => {
    const server = net.createServer((socket) => {
      if (dropConnection) {
        socket.destroy();
        return;
      }
      let buffered = Buffer.alloc(0);
      socket.on("data", (chunk) => {
        buffered = Buffer.concat([buffered, chunk]);
        const looksLikePing = buffered.toString("latin1").includes("zPING\0");
        // INSTREAM completion: a 4-zero-byte terminating chunk anywhere
        // after the initial "zINSTREAM\0" command — real clamd behavior.
        const looksLikeInstreamDone =
          buffered.length >= 4 && buffered.readUInt32BE(buffered.length - 4) === 0;
        if (looksLikePing || looksLikeInstreamDone) {
          setTimeout(() => {
            socket.end(reply);
          }, delayMs);
        }
      });
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

test("scanBufferWithClamd correctly frames a real chunked INSTREAM request and parses a clean reply", async () => {
  const server = await startFakeClamd({ reply: "stream: OK" });
  const { port } = server.address();
  try {
    const result = await scanBufferWithClamd({
      buffer: Buffer.from("hello world, this is a synthetic test file"),
      host: "127.0.0.1",
      port,
      timeoutMs: 2000,
      chunkSize: 8, // force multiple chunks to genuinely exercise the framing loop
    });
    assert.equal(result.outcome, "clean");
  } finally {
    server.close();
  }
});

test("scanBufferWithClamd surfaces an infected verdict from a real socket round trip", async () => {
  const server = await startFakeClamd({ reply: "stream: Eicar-Test-Signature FOUND" });
  const { port } = server.address();
  try {
    const result = await scanBufferWithClamd({
      buffer: Buffer.from("synthetic eicar-like test payload"),
      host: "127.0.0.1",
      port,
      timeoutMs: 2000,
    });
    assert.equal(result.outcome, "infected");
    assert.equal(result.signatureName, "Eicar-Test-Signature");
  } finally {
    server.close();
  }
});

test("scanBufferWithClamd times out and reports error, never clean, when the daemon never replies", async () => {
  const server = await startFakeClamd({ reply: "stream: OK", delayMs: 5000 }); // slower than our timeout
  const { port } = server.address();
  try {
    const result = await scanBufferWithClamd({
      buffer: Buffer.from("x"),
      host: "127.0.0.1",
      port,
      timeoutMs: 200,
    });
    assert.equal(result.outcome, "error");
    assert.equal(result.message, "clamd_scan_timeout");
  } finally {
    server.close();
  }
});

test("scanBufferWithClamd reports a connection error when the daemon drops the connection immediately", async () => {
  const server = await startFakeClamd({ dropConnection: true });
  const { port } = server.address();
  try {
    const result = await scanBufferWithClamd({
      buffer: Buffer.from("x"),
      host: "127.0.0.1",
      port,
      timeoutMs: 2000,
    });
    assert.equal(result.outcome, "error");
  } finally {
    server.close();
  }
});

test("scanBufferWithClamd never resolves 'clean' when there is no server at all", async () => {
  const result = await scanBufferWithClamd({
    buffer: Buffer.from("x"),
    host: "127.0.0.1",
    port: 1, // reserved/unused port, connection should fail fast
    timeoutMs: 2000,
  });
  assert.equal(result.outcome, "error");
  assert.notEqual(result.outcome, "clean");
});

test("pingClamd returns true for a real PONG reply and false on timeout", async () => {
  const server = await startFakeClamd({ reply: "PONG" });
  const { port } = server.address();
  try {
    const ok = await pingClamd({ host: "127.0.0.1", port, timeoutMs: 2000 });
    assert.equal(ok, true);
  } finally {
    server.close();
  }

  const slowServer = await startFakeClamd({ reply: "PONG", delayMs: 5000 });
  const slowPort = slowServer.address().port;
  try {
    const notOk = await pingClamd({ host: "127.0.0.1", port: slowPort, timeoutMs: 100 });
    assert.equal(notOk, false);
  } finally {
    slowServer.close();
  }
});
