"use strict";

// Petsupo Marketplace P1-A compliance foundation — compliance-scanner
// service, ClamAV clamd wire protocol (Slice 2.1, part C). Talks to
// clamd over a local Unix socket or TCP loopback using clamd's own
// documented INSTREAM command — no third-party clamd client library, so
// the entire dependency surface for this specific piece is Node's
// built-in `net` module plus this ~150-line, directly-auditable file.
//
// INSTREAM protocol (see ClamAV's own clamd protocol documentation):
// send the literal command "zINSTREAM\0", then a sequence of chunks each
// framed as a 4-byte big-endian length prefix followed by that many raw
// bytes, terminated by a single zero-length chunk. clamd replies with a
// single line: "stream: OK", "stream: <signature name> FOUND", or
// "stream: <message> ERROR".

const net = require("node:net");

const DEFAULT_CHUNK_SIZE = 8192;

// Slice 2.1 correction, part C: a bare "FOUND" from clamd does not
// always mean malware — ClamAV's own heuristic engine (AlertEncrypted*
// in clamd.conf) reports encrypted/password-protected content it cannot
// inspect through the SAME "FOUND" reply path a genuine detection uses.
// Reporting an encrypted PDF as confirmed malware to a seller/admin
// would be factually false, even though the correct SECURITY outcome
// (never approve it) is the same either way.
//
// This is a narrow, explicit ALLOWLIST — not a general "downgrade
// anything that looks uncertain" rule. Only signature names ClamAV
// itself uses for its documented AlertEncrypted* heuristic family
// (Heuristics.Encrypted.*, covering PDF/Zip/RAR/DOC/etc. alike) are
// reclassified; every other FOUND result, known malware or otherwise
// unrecognized, is treated as a genuine infection and fails closed
// exactly as before. An unrecognized heuristic name is deliberately
// NOT given the benefit of the doubt.
const ENCRYPTED_HEURISTIC_SIGNATURE_PATTERN = /^Heuristics\.Encrypted\./;

function classifySignatureName(signatureName) {
  if (ENCRYPTED_HEURISTIC_SIGNATURE_PATTERN.test(signatureName)) {
    return "unsupported";
  }
  return "infected";
}

// Pure, socket-free — parses clamd's single-line INSTREAM reply. Kept
// separate from the socket I/O below specifically so it is trivially
// unit-testable without any real or fake socket at all.
function parseClamdResponse(rawText) {
  const text = String(rawText || "").replace(/\0/g, "").trim();
  if (text.length === 0) {
    return { outcome: "error", message: "empty_response" };
  }
  if (/\bOK$/.test(text)) {
    return { outcome: "clean" };
  }
  const foundMatch = text.match(/^stream:\s*(.+?)\s+FOUND$/);
  if (foundMatch) {
    const signatureName = foundMatch[1];
    const classification = classifySignatureName(signatureName);
    if (classification === "unsupported") {
      return { outcome: "unsupported", signatureName, reason: "encrypted_document_unsupported" };
    }
    return { outcome: "infected", signatureName };
  }
  if (/ERROR$/.test(text)) {
    return { outcome: "error", message: text };
  }
  return { outcome: "error", message: "unparseable_clamd_response" };
}

// Streams `buffer` to clamd over a fresh connection (per-scan — clamd's
// INSTREAM is not designed for multiplexed reuse over one connection)
// and resolves with the parsed outcome. Bounded by `timeoutMs` end to
// end (connect + stream + reply) — a slow/hung clamd is a hard timeout,
// never an indefinite wait, and a timeout is always surfaced as
// outcome: "error", never silently retried into a false "clean".
function scanBufferWithClamd({ buffer, host, port, socketPath, timeoutMs, chunkSize = DEFAULT_CHUNK_SIZE }) {
  return new Promise((resolve) => {
    let settled = false;
    const finish = (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      socket.removeAllListeners();
      socket.destroy();
      resolve(result);
    };

    const socket = socketPath
      ? net.createConnection({ path: socketPath })
      : net.createConnection({ host, port });

    const timer = setTimeout(() => {
      finish({ outcome: "error", message: "clamd_scan_timeout" });
    }, timeoutMs);

    let responseChunks = [];

    socket.on("connect", () => {
      try {
        socket.write("zINSTREAM\0");
        let offset = 0;
        while (offset < buffer.length) {
          const chunk = buffer.subarray(offset, Math.min(offset + chunkSize, buffer.length));
          const sizeHeader = Buffer.alloc(4);
          sizeHeader.writeUInt32BE(chunk.length, 0);
          socket.write(sizeHeader);
          socket.write(chunk);
          offset += chunk.length;
        }
        const zeroHeader = Buffer.alloc(4);
        zeroHeader.writeUInt32BE(0, 0);
        socket.write(zeroHeader);
      } catch (err) {
        finish({ outcome: "error", message: "clamd_write_failed" });
      }
    });

    socket.on("data", (data) => {
      responseChunks.push(data);
    });

    socket.on("error", () => {
      finish({ outcome: "error", message: "clamd_connection_error" });
    });

    socket.on("close", () => {
      if (settled) return;
      const text = Buffer.concat(responseChunks).toString("utf8");
      finish(parseClamdResponse(text));
    });
  });
}

// zPING\0 -> "PONG" — clamd's cheap reachability check, used by
// /healthz. Bounded by its own short timeout so a hung clamd never hangs
// the health endpoint itself.
function pingClamd({ host, port, socketPath, timeoutMs = 3000 }) {
  return new Promise((resolve) => {
    let settled = false;
    const finish = (ok) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      socket.removeAllListeners();
      socket.destroy();
      resolve(ok);
    };
    const socket = socketPath
      ? net.createConnection({ path: socketPath })
      : net.createConnection({ host, port });
    const timer = setTimeout(() => finish(false), timeoutMs);
    let response = Buffer.alloc(0);

    socket.on("connect", () => {
      socket.write("zPING\0");
    });
    socket.on("data", (data) => {
      response = Buffer.concat([response, data]);
    });
    socket.on("error", () => finish(false));
    socket.on("close", () => {
      finish(response.toString("utf8").includes("PONG"));
    });
  });
}

// Real, injectable clamd scanner adapter matching the same
// `{ scanBuffer(buffer) }` shape the fake adapters expose for tests.
function createRealClamdScanner({ host, port, socketPath, timeoutMs }) {
  return {
    async scanBuffer(buffer) {
      return scanBufferWithClamd({ buffer, host, port, socketPath, timeoutMs });
    },
    async ping() {
      return pingClamd({ host, port, socketPath });
    },
  };
}

module.exports = {
  parseClamdResponse,
  scanBufferWithClamd,
  pingClamd,
  createRealClamdScanner,
  classifySignatureName,
  ENCRYPTED_HEURISTIC_SIGNATURE_PATTERN,
};
