#!/usr/bin/env python3
"""Petsupo Marketplace P1-A compliance foundation — signature-refresh
pipeline, single-purpose helper for ci/verify-deployed-candidate.sh
(Slice 2.2 correction, closing a real staging failure — build
aa407156-0dea-4ed0-9e85-47354d3bbf3e, step verify-deployed-candidate:
"could not resolve candidate tag URL"). Root cause: gcloud's own
--format resource-key language does not support the JMESPath-style
embedded predicate `status.traffic[?tag=='...']` this step's two
gcloud describe calls previously used — every variant silently
resolved to an empty string (exit 0, no error) rather than failing
loudly, confirmed empirically against a real deployed candidate whose
matching traffic entry genuinely existed.

Reads Cloud Run's `status.traffic` array (as produced by
`gcloud run services describe ... --format="json(status.traffic)"`)
from stdin, finds the SINGLE entry whose "tag" field exactly equals
CANDIDATE_TRAFFIC_TAG (read from the environment — never interpolated
into this script's own source and never taken from argv either, so a
maliciously- or accidentally-crafted tag value is always inert data,
never executable code or a matching-logic operator), and prints
exactly two lines on success: the matching entry's "url", then its
"revisionName" — both independently, structurally validated before
being printed at all. Never falls back to the base (100%-traffic,
untagged) revision or any other entry — a tag that does not match
EXACTLY ONE entry is a hard failure, never a best-effort guess.
"""
import json
import os
import re
import sys

CANDIDATE_TRAFFIC_TAG = os.environ.get("CANDIDATE_TRAFFIC_TAG", "")

# RFC1035-label-shaped, matching Cloud Run's own revision-name
# constraints: lowercase letters, digits, hyphens; starts with a
# letter; does not end with a hyphen; bounded to the same 63-character
# label limit Cloud Run itself enforces.
REVISION_NAME_PATTERN = re.compile(r"^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$")

CONTROL_OR_WHITESPACE_PATTERN = re.compile(r"[\s\x00-\x1f\x7f]")


def fail(reason):
    print("resolveCandidateTrafficEntry: " + reason, file=sys.stderr)
    sys.exit(1)


def main():
    if not CANDIDATE_TRAFFIC_TAG:
        fail("CANDIDATE_TRAFFIC_TAG environment variable is required and must be non-empty")
        return

    raw = sys.stdin.read()
    try:
        data = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        fail("stdin is not valid JSON")
        return

    if not isinstance(data, dict):
        fail("top-level JSON value is not an object")
        return

    status = data.get("status")
    if not isinstance(status, dict):
        fail("status field is missing or not an object")
        return

    traffic = status.get("traffic")
    if not isinstance(traffic, list):
        fail("status.traffic is missing or not an array")
        return

    matches = [t for t in traffic if isinstance(t, dict) and t.get("tag") == CANDIDATE_TRAFFIC_TAG]

    if len(matches) == 0:
        fail("no traffic entry has tag '" + CANDIDATE_TRAFFIC_TAG + "'")
        return
    if len(matches) > 1:
        fail(str(len(matches)) + " traffic entries have tag '" + CANDIDATE_TRAFFIC_TAG + "', expected exactly one")
        return

    entry = matches[0]
    url = entry.get("url")
    revision_name = entry.get("revisionName")

    if not isinstance(url, str) or url == "":
        fail("matched traffic entry has a missing or empty url")
        return
    if not url.startswith("https://"):
        fail("matched traffic entry's url is not HTTPS: '" + url + "'")
        return
    if CONTROL_OR_WHITESPACE_PATTERN.search(url):
        fail("matched traffic entry's url contains whitespace or control characters")
        return

    if not isinstance(revision_name, str) or revision_name == "":
        fail("matched traffic entry has a missing or empty revisionName")
        return
    if not REVISION_NAME_PATTERN.match(revision_name):
        fail("matched traffic entry's revisionName does not match the expected Cloud Run-safe shape: '" + revision_name + "'")
        return

    print(url)
    print(revision_name)


if __name__ == "__main__":
    main()
