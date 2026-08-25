"use strict";

// Petsupo Marketplace P1-A compliance foundation — Slice 4.3 (docs/plans/
// marketplace_p1a_compliance_review_implementation_plan_2026-08-21.md,
// §10/§13.1, correction 9, algorithm frozen Revision 3): the exact,
// versioned brand-normalization algorithm used only for CANDIDATE
// narrowing of `brand`-type complianceDocumentScopes — never the
// authoritative match itself (that is `verifiedBrandId`, admin-set
// during `reviewComplianceScope`). Pure, deterministic, no Firestore/
// clock/network access, no mutable global cache, no locale/environment
// dependency: the same input always produces the same output on any
// machine, at any time, forever, for a given `version`.
//
// Not wired into functions/index.js — no onCall/HTTP/trigger entry
// point exists for this module.

// The only normalizer version this implementation understands. A future
// algorithm change is a NEW version number with its own case branch
// added below — never an in-place edit of this one, since existing
// scopes/decisions are permanently recorded against the version they
// were normalized under (§10).
const NORMALIZER_VERSION = 1;

const MAX_NORMALIZED_LENGTH = 200;

// Collapses any run of characters that are neither a Unicode letter nor
// a Unicode digit into a single space. Deliberately COLLAPSES, never
// deletes: merging two distinct brand words into one via space removal
// is the dangerous direction (it could cause two genuinely different
// brands to collide); a stray space between them is harmless and only
// ever narrows a candidate set, never widens one. `\p{L}`/`\p{N}` with
// the `u` flag are Unicode-aware (not merely ASCII [a-zA-Z0-9]), so
// non-Latin letters/digits are preserved as letters/digits, not stripped
// as punctuation.
const NON_LETTER_OR_DIGIT_RUN = /[^\p{L}\p{N}]+/gu;

// ---------------------------------------------------------------------
// normalizeBrand(raw, version) — the exact frozen algorithm (§10):
//   1. NFKC Unicode normalization.
//   2. Fixed-locale ('en-US') lowercasing — never the runtime default
//      locale, since Turkish 'tr-TR' casing (dotted/dotless I) is
//      locale-sensitive and would make output depend on where the
//      function runs.
//   3. Collapse all non-letter/non-number runs to a single space.
//   4. Trim, collapse internal whitespace.
//   5. Truncate to 200 characters.
// ---------------------------------------------------------------------

function normalizeBrand(raw, version = NORMALIZER_VERSION) {
  if (version !== NORMALIZER_VERSION) {
    throw new Error(`normalizeBrand: unsupported normalizer version ${version}`);
  }
  if (typeof raw !== "string") {
    throw new Error("normalizeBrand: raw must be a string");
  }

  let s = raw.normalize("NFKC");
  s = s.toLocaleLowerCase("en-US");
  s = s.replace(NON_LETTER_OR_DIGIT_RUN, " ");
  s = s.trim().replace(/\s+/g, " ");
  s = s.slice(0, MAX_NORMALIZED_LENGTH);
  return s;
}

// normalizedBrandId = normalizerVersion + ':' + normalizeBrand(rawBrand, normalizerVersion)
// (§10). Never a cross-version comparison — a scope recorded under a
// prior version is only ever compared against a normalizedBrandId
// computed under that same version.
function computeNormalizedBrandId(raw, version = NORMALIZER_VERSION) {
  return `${version}:${normalizeBrand(raw, version)}`;
}

module.exports = {
  NORMALIZER_VERSION,
  normalizeBrand,
  computeNormalizedBrandId,
};
