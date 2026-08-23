"use strict";

// Petsupo Marketplace P1-A compliance foundation — signature-refresh
// pipeline, single-purpose helper for ci/verify-deployed-candidate.sh
// and ci/promote.sh (Slice 2.2 correction, closing a real staging
// failure — build aa407156-0dea-4ed0-9e85-47354d3bbf3e, step
// verify-deployed-candidate: "could not resolve candidate tag URL").
// Root cause: gcloud's own --format resource-key language does not
// support the JMESPath-style embedded predicate
// `status.traffic[?tag=='...']` both scripts previously used — every
// variant silently resolved to an empty string (exit 0, no error)
// rather than failing loudly, confirmed empirically against a real
// deployed candidate whose matching traffic entry genuinely existed.
//
// Rewritten from Python to Node (build ea9bad30-d2e2-4aa1-9fdb-a765bde94372,
// step verify-source: "spawnSync git ENOENT" / python3 spawn failures)
// — the ORIGINAL ci/resolveCandidateTrafficEntry.py was correct, but
// verify-source.sh runs on node:20.18.1-bookworm-slim, a minimal
// Node-only Cloud Build image with neither python3 nor git on PATH.
// verify-deployed-candidate.sh and promote.sh themselves run on
// images that DO have python3 (the plain cloud-sdk image and the
// combined ci-builder image, respectively) — this rewrite is not
// fixing a production-path defect, only removing a dependency this
// helper never actually needed: Node's standard library already
// provides everything used here (JSON.parse, a hand-rolled regex),
// and Node itself is the one runtime guaranteed present in every
// step of this entire pipeline, including verify-source, where this
// module is now also imported directly for zero-process-spawn
// behavioral testing.
//
// Reads Cloud Run's `status.traffic` array (as produced by
// `gcloud run services describe ... --format="json(status.traffic)"`)
// from stdin, finds the SINGLE entry whose "tag" field exactly equals
// CANDIDATE_TRAFFIC_TAG (read from the environment — never
// interpolated into this script's own source, never taken from argv
// either, so a maliciously- or accidentally-crafted tag value is
// always inert data compared with strict `===`, never executable
// code or a matching-logic operator — this module contains no
// `eval`, no `Function` constructor, and never shells out to
// anything), and prints exactly two lines on success: the matching
// entry's "url", then its "revisionName" — both independently,
// structurally validated before being printed at all. Never falls
// back to the base (100%-traffic, untagged) revision, a previously
// deployed but now-stale candidate, or any other entry — a tag that
// does not match EXACTLY ONE entry is a hard failure, never a
// best-effort guess.
//
// Split into two parts, the same way this pipeline's other ci/*.js
// modules already are: a pure, dependency-free decision function
// (resolveCandidateTrafficEntry, fully unit-testable with a plain
// in-memory object — no stdin, no process, no environment) and a
// thin CLI wrapper (require.main === module) that does the real I/O.

const REVISION_NAME_PATTERN = /^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$/;
const CONTROL_OR_WHITESPACE_PATTERN = /[\s\x00-\x1f\x7f]/;

/**
 * Pure decision function — no I/O. Given the parsed `status.traffic`
 * JSON payload and the tag to match, returns either the validated
 * `{ url, revisionName }` of the unique matching entry, or a
 * `{ error }` describing exactly why resolution failed. Never throws
 * for a malformed/unexpected `parsed` shape — every failure path
 * returns an explicit error string, the same "never silently omit a
 * reason" discipline this pipeline's other decision functions
 * (fixtureManifest.js, signatureRefreshLock.js) already follow.
 *
 * @param {unknown} parsed Already-JSON.parse()d input.
 * @param {string} tag CANDIDATE_TRAFFIC_TAG — treated strictly as
 *   data: only ever compared with `===`, never interpolated into a
 *   string that is executed or evaluated.
 * @returns {{ ok: true, url: string, revisionName: string } | { ok: false, error: string }}
 */
function resolveCandidateTrafficEntry(parsed, tag) {
  if (!tag) {
    return { ok: false, error: "CANDIDATE_TRAFFIC_TAG is required and must be non-empty" };
  }
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    return { ok: false, error: "top-level JSON value is not an object" };
  }

  const status = parsed.status;
  if (status === null || typeof status !== "object" || Array.isArray(status)) {
    return { ok: false, error: "status field is missing or not an object" };
  }

  const traffic = status.traffic;
  if (!Array.isArray(traffic)) {
    return { ok: false, error: "status.traffic is missing or not an array" };
  }

  const matches = traffic.filter(
    (t) => t !== null && typeof t === "object" && !Array.isArray(t) && t.tag === tag
  );

  if (matches.length === 0) {
    return { ok: false, error: "no traffic entry has tag '" + tag + "'" };
  }
  if (matches.length > 1) {
    return { ok: false, error: matches.length + " traffic entries have tag '" + tag + "', expected exactly one" };
  }

  const entry = matches[0];
  const url = entry.url;
  const revisionName = entry.revisionName;

  if (typeof url !== "string" || url === "") {
    return { ok: false, error: "matched traffic entry has a missing or empty url" };
  }
  if (!url.startsWith("https://")) {
    return { ok: false, error: "matched traffic entry's url is not HTTPS: '" + url + "'" };
  }
  if (CONTROL_OR_WHITESPACE_PATTERN.test(url)) {
    return { ok: false, error: "matched traffic entry's url contains whitespace or control characters" };
  }

  if (typeof revisionName !== "string" || revisionName === "") {
    return { ok: false, error: "matched traffic entry has a missing or empty revisionName" };
  }
  if (!REVISION_NAME_PATTERN.test(revisionName)) {
    return {
      ok: false,
      error: "matched traffic entry's revisionName does not match the expected Cloud Run-safe shape: '" + revisionName + "'",
    };
  }

  return { ok: true, url, revisionName };
}

if (require.main === module) {
  const CANDIDATE_TRAFFIC_TAG = process.env.CANDIDATE_TRAFFIC_TAG || "";

  const chunks = [];
  process.stdin.on("data", (chunk) => chunks.push(chunk));
  process.stdin.on("end", () => {
    const raw = Buffer.concat(chunks).toString("utf8");
    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (err) {
      process.stderr.write("resolveCandidateTrafficEntry: stdin is not valid JSON\n");
      process.exitCode = 1;
      return;
    }

    const result = resolveCandidateTrafficEntry(parsed, CANDIDATE_TRAFFIC_TAG);
    if (!result.ok) {
      process.stderr.write("resolveCandidateTrafficEntry: " + result.error + "\n");
      process.exitCode = 1;
      return;
    }

    process.stdout.write(result.url + "\n" + result.revisionName + "\n");
  });
}

module.exports = { resolveCandidateTrafficEntry };
