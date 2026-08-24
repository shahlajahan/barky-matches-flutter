"use strict";

// Static/deterministic tests for the signature-refresh pipeline's
// COMMAND CONSTRUCTION and dependency graph (Slice 2.2 adversarial
// correction, Mandatory correction 5). These prove properties of the
// pipeline's TEXT and STRUCTURE — never its live behavior against a
// real GCP project, which requires staging execution (see the Slice
// 2.2 correction report's honesty-language section). No dependency on
// a YAML parser library is introduced: a small purpose-built extractor
// below reads only the specific structure this one file uses
// (top-level `steps:` list, each step's `id`/`waitFor`/`timeout`) —
// it is not a general YAML parser and is not claimed to be one.

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync, spawn } = require("node:child_process");
const os = require("node:os");
const crypto = require("node:crypto");

const REPO_ROOT = path.join(__dirname, "..");
const YAML_PATH = path.join(REPO_ROOT, "cloudbuild.signature-refresh.yaml");
const yamlText = fs.readFileSync(YAML_PATH, "utf8");

function scriptText(name) {
  return fs.readFileSync(path.join(__dirname, name), "utf8");
}

// Minimal, purpose-built extraction of this file's own `steps:` list —
// each step's id, image name, waitFor array, and timeout, from the raw
// text. Good enough for the structural assertions below; not a general
// parser.
function extractSteps(text) {
  const stepsSectionMatch = text.match(/\nsteps:\n([\s\S]*?)\nimages:/);
  assert.ok(stepsSectionMatch, "could not locate steps: section");
  const stepsText = stepsSectionMatch[1];
  const stepBlocks = stepsText.split(/\n  - id: /).slice(1);
  return stepBlocks.map((block) => {
    const id = block.match(/^([a-zA-Z0-9-]+)/)[1];
    const nameMatch = block.match(/name:\s*"([^"]+)"/);
    const name = nameMatch ? nameMatch[1] : null;
    const waitForMatch = block.match(/waitFor:\s*\[(.*)\]/);
    const waitFor = waitForMatch
      ? waitForMatch[1].split(",").map((s) => s.trim().replace(/^"|"$/g, "")).filter(Boolean)
      : [];
    const timeoutMatch = block.match(/timeout:\s*(\d+)s/);
    const timeout = timeoutMatch ? Number(timeoutMatch[1]) : null;
    return { id, name, waitFor, timeout };
  });
}

const steps = extractSteps(yamlText);
const stepsById = Object.fromEntries(steps.map((s) => [s.id, s]));
// Physical declaration order — steps[i]'s index in the real YAML `steps:`
// list, exactly as Cloud Build itself reads it. Cloud Build's own
// validator (proven empirically against the real staging build attempt
// following commit 8c2acce, source archive
// source/1787463438.281026-aa64df9f6b8344df973248ef793b6adc.tgz — the
// submission was rejected with "invalid .steps field: build step #2 -
// 'materialize-runtime-manifest' depends on 'verify-source', which has
// not been defined" before any Build ID was created) requires every
// waitFor target to be declared at a strictly lower index than the step
// referencing it — a purely logical DAG is not sufficient.
const stepIndexById = Object.fromEntries(steps.map((s, i) => [s.id, i]));

function transitiveDependsOn(stepId, target, visited = new Set()) {
  if (visited.has(stepId)) return false;
  visited.add(stepId);
  const step = stepsById[stepId];
  if (!step) return false;
  if (step.waitFor.includes(target)) return true;
  return step.waitFor.some((dep) => transitiveDependsOn(dep, target, visited));
}

// ---------------------------------------------------------------------
// Dependency graph — "no step can promote before every mandatory
// verification step succeeds"
// ---------------------------------------------------------------------

test("pipeline structure: exactly the 13 expected steps exist", () => {
  const ids = steps.map((s) => s.id).sort();
  assert.deepEqual(ids, [
    "acquire-lock",
    "build-candidate",
    "deploy-candidate",
    "install-dependencies",
    "materialize-runtime-manifest",
    "promote",
    "push-candidate",
    "release-lock",
    "resolve-digest",
    "verify-candidate-container",
    "verify-deployed-candidate",
    "verify-fixtures-integrity",
    "verify-source",
  ]);
});

// ---------------------------------------------------------------------
// Step identity integrity — guards the physical reorder (Slice 2.2
// declaration-order correction) against accidentally adding, dropping,
// or duplicating a step while moving the verify-source block.
// ---------------------------------------------------------------------

test("step identity integrity: every step id in the physical steps: list is unique — no duplicate id anywhere, and specifically no duplicate verify-source or materialize-runtime-manifest", () => {
  const ids = steps.map((s) => s.id);
  const seen = new Set();
  const duplicates = [];
  for (const id of ids) {
    if (seen.has(id)) duplicates.push(id);
    seen.add(id);
  }
  assert.deepEqual(duplicates, [], `duplicate step id(s) found: ${duplicates.join(", ")}`);
  assert.equal(ids.filter((id) => id === "verify-source").length, 1, "exactly one verify-source step must exist");
  assert.equal(ids.filter((id) => id === "materialize-runtime-manifest").length, 1, "exactly one materialize-runtime-manifest step must exist");
});

test("step identity integrity: the physical step count is exactly 13, unchanged by the reorder (no step was added, removed, or duplicated while moving the verify-source block)", () => {
  assert.equal(steps.length, 13);
});

// ---------------------------------------------------------------------
// Cloud Build declaration-order regression guard (Slice 2.2, closing
// the real staging submission rejection following commit 8c2acce:
// "invalid .steps field: build step #2 - 'materialize-runtime-manifest'
// depends on 'verify-source', which has not been defined"). Cloud
// Build requires every waitFor target to be declared at a strictly
// lower physical index than the step referencing it — a logically
// correct DAG is not sufficient if a target is declared later in the
// file. This walks the REAL extracted YAML step list and its REAL
// waitFor arrays; it does not hardcode a duplicate imaginary pipeline,
// so it applies to every current and future step, not only
// verify-source/materialize-runtime-manifest.
// ---------------------------------------------------------------------

test("Cloud Build declaration-order regression: for every step and every explicit waitFor target (excluding Cloud Build's special root sentinel \"-\"), the target step id exists, is declared exactly once, and is declared at a strictly lower physical index than the dependent step", () => {
  for (let i = 0; i < steps.length; i++) {
    const step = steps[i];
    for (const target of step.waitFor) {
      if (target === "-") continue; // Cloud Build's special root sentinel — marks "no dependency", not a real step id
      const occurrences = steps.filter((s) => s.id === target).length;
      assert.equal(occurrences, 1, `${step.id}'s waitFor target "${target}" must exist and be declared exactly once, found ${occurrences} times`);
      const targetIndex = stepIndexById[target];
      assert.ok(
        targetIndex < i,
        `${step.id} (declared at index ${i}) has waitFor target "${target}" declared at index ${targetIndex} — Cloud Build requires the target to be declared strictly earlier in the file`
      );
    }
  }
});

test("Cloud Build declaration-order regression, focused: verify-source is physically declared strictly before materialize-runtime-manifest (this exact ordering is what the real staging submission was missing)", () => {
  assert.ok(
    stepIndexById["verify-source"] < stepIndexById["materialize-runtime-manifest"],
    `expected verify-source (index ${stepIndexById["verify-source"]}) to be declared before materialize-runtime-manifest (index ${stepIndexById["materialize-runtime-manifest"]})`
  );
});

test("Cloud Build declaration-order regression: the expected physical sequence begins install-dependencies, acquire-lock, verify-source, materialize-runtime-manifest, verify-fixtures-integrity, in that exact order", () => {
  const expectedPrefix = [
    "install-dependencies",
    "acquire-lock",
    "verify-source",
    "materialize-runtime-manifest",
    "verify-fixtures-integrity",
  ];
  const actualPrefix = steps.slice(0, expectedPrefix.length).map((s) => s.id);
  assert.deepEqual(actualPrefix, expectedPrefix);
});

// ---------------------------------------------------------------------
// Cloud Build execution identity (single-authoritative-execution-
// identity correction, closing a real staging failure — build
// f3caf298-6996-4585-a05b-38a48452c124, step verify-deployed-
// candidate: "PERMISSION_DENIED: Failed to impersonate
// [compliance-scanner-monitor-sa@...]", root-caused to the build
// having silently executed as the project's default Compute Engine
// service account because this file never specified an execution
// identity of its own). These are the LOCAL, repository-level defense
// in depth this correction's own YAML comment promises: if a future
// edit accidentally deletes or corrupts the top-level serviceAccount:
// field, these tests fail closed rather than letting the pipeline
// silently fall back to the default Compute SA again. Cloud Build's
// own build-submission API independently validates and rejects a
// malformed/absent value at submission time — these tests do not
// replace that, they catch the regression before it ever reaches
// Cloud Build at all.
// ---------------------------------------------------------------------

function extractTopLevelServiceAccount(text) {
  const match = text.match(/\nserviceAccount:\s*"([^"]*)"/);
  return match ? match[1] : null;
}

const RESOLVED_SERVICE_ACCOUNT = extractTopLevelServiceAccount(yamlText).replace(/\$\{PROJECT_ID\}/g, "petsupo-platform-staging");

test("Cloud Build execution identity: a top-level serviceAccount: field exists and is not empty", () => {
  const raw = extractTopLevelServiceAccount(yamlText);
  assert.ok(raw !== null, "a top-level serviceAccount: field must exist in cloudbuild.signature-refresh.yaml");
  assert.ok(raw.length > 0, "the top-level serviceAccount: field must not be empty");
});

test("Cloud Build execution identity: serviceAccount uses the full projects/.../serviceAccounts/... resource-name format, never a bare email", () => {
  const raw = extractTopLevelServiceAccount(yamlText);
  assert.ok(
    /^projects\/[^/]+\/serviceAccounts\/[^/]+$/.test(raw),
    `serviceAccount must be the full resource-name form "projects/<project>/serviceAccounts/<email>", got: ${raw}`
  );
});

test("Cloud Build execution identity: serviceAccount uses Cloud Build's own built-in ${PROJECT_ID} substitution, never a hardcoded project id — portable to any project without a repository edit", () => {
  const raw = extractTopLevelServiceAccount(yamlText);
  assert.ok(raw.includes("${PROJECT_ID}"), "serviceAccount must reference ${PROJECT_ID}, not a literal project id");
  const occurrences = (raw.match(/\$\{PROJECT_ID\}/g) || []).length;
  assert.equal(occurrences, 2, "PROJECT_ID must appear exactly twice: once in the projects/ segment, once in the email's domain");
});

test("Cloud Build execution identity: resolves (with PROJECT_ID substituted) to exactly the dedicated staging CI service account", () => {
  assert.equal(
    RESOLVED_SERVICE_ACCOUNT,
    "projects/petsupo-platform-staging/serviceAccounts/compliance-scanner-ci-sa@petsupo-platform-staging.iam.gserviceaccount.com"
  );
});

test("Cloud Build execution identity: the account id component is exactly compliance-scanner-ci-sa — no other account name", () => {
  const raw = extractTopLevelServiceAccount(yamlText);
  const accountIdMatch = raw.match(/\/serviceAccounts\/([^@]+)@/);
  assert.ok(accountIdMatch, "could not extract the service account id from serviceAccount:");
  assert.equal(accountIdMatch[1], "compliance-scanner-ci-sa");
});

test("Cloud Build execution identity: cannot resolve to the default Compute Engine service account (604995650954-compute@developer.gserviceaccount.com) — the exact identity build f3caf298 actually ran as", () => {
  assert.ok(!RESOLVED_SERVICE_ACCOUNT.includes("604995650954-compute@developer.gserviceaccount.com"));
  assert.ok(!RESOLVED_SERVICE_ACCOUNT.includes("-compute@developer.gserviceaccount.com"), "must never resolve to ANY project's default Compute SA, not just this one project's numeric id");
});

test("Cloud Build execution identity: cannot resolve to the Cloud Build default builder identity (604995650954@cloudbuild.gserviceaccount.com)", () => {
  assert.ok(!RESOLVED_SERVICE_ACCOUNT.includes("604995650954@cloudbuild.gserviceaccount.com"));
  assert.ok(!/^\d+@cloudbuild\.gserviceaccount\.com$/.test(RESOLVED_SERVICE_ACCOUNT.split("/").pop()), "must never resolve to the bare numeric Cloud Build builder identity");
});

test("Cloud Build execution identity: cannot resolve to the Cloud Build service AGENT (service-604995650954@gcp-sa-cloudbuild.iam.gserviceaccount.com) — a distinct, GCP-managed identity that must never be used as the execution identity itself", () => {
  assert.ok(!RESOLVED_SERVICE_ACCOUNT.includes("gcp-sa-cloudbuild.iam.gserviceaccount.com"));
  assert.ok(!RESOLVED_SERVICE_ACCOUNT.includes("service-604995650954@"));
});

test("Cloud Build execution identity: options.logging remains exactly CLOUD_LOGGING_ONLY — required for a custom build service account, and unchanged by this correction", () => {
  const optionsSectionMatch = yamlText.match(/\noptions:\n([\s\S]*?)\n(?:serviceAccount:|substitutions:)/);
  assert.ok(optionsSectionMatch, "could not locate options: section");
  assert.ok(/^\s*logging:\s*CLOUD_LOGGING_ONLY\s*$/m.test(optionsSectionMatch[1]), "options.logging must remain exactly CLOUD_LOGGING_ONLY");
});

test("Cloud Build execution identity: no logsBucket field is introduced anywhere in the file — this correction relies on the standard project Cloud Logging destination, never a new bucket", () => {
  assert.ok(!/\blogsBucket\s*:/.test(yamlText), "logsBucket: must never appear in this file");
});

test("Cloud Build execution identity: all 13 steps remain present, unchanged in id/name/waitFor/args/env/timeout by this correction (the serviceAccount: addition touches only build-level configuration, never step bodies)", () => {
  assert.equal(steps.length, 13, "step count must remain exactly 13");
  const stepIds = steps.map((s) => s.id);
  assert.deepEqual(
    stepIds,
    [
      "install-dependencies", "acquire-lock", "verify-source", "materialize-runtime-manifest",
      "verify-fixtures-integrity", "build-candidate", "verify-candidate-container", "push-candidate",
      "resolve-digest", "deploy-candidate", "verify-deployed-candidate", "promote", "release-lock",
    ],
    "step id list/order must be byte-identical to before this correction"
  );
});

test("Cloud Build execution identity: the waitFor dependency graph remains fully valid — every waitFor target exists, is unique, and is declared at a strictly lower physical index (regression guard, duplicating the file-wide DAG check locally to this correction's own section)", () => {
  for (const step of steps) {
    for (const dep of step.waitFor) {
      if (dep === "-") continue;
      assert.ok(stepIndexById[dep] !== undefined, `${step.id} waits for undeclared step ${dep}`);
      assert.ok(stepIndexById[dep] < stepIndexById[step.id], `${step.id} must be declared after its dependency ${dep}`);
    }
  }
});

test("Cloud Build execution identity: the scanner runtime SA substitution (_SCANNER_RUNTIME_SA) and monitoring SA substitution (_MONITORING_SA) remain wired exactly as before — never hardcoded to a literal SA email, never renamed, never pointed at the new CI execution identity itself", () => {
  const subsSectionMatch = yamlText.match(/\nsubstitutions:\n([\s\S]*?)\nsteps:/);
  assert.ok(subsSectionMatch);
  const subsText = subsSectionMatch[1];
  assert.ok(/^\s*_SCANNER_RUNTIME_SA:\s*""/m.test(subsText), "_SCANNER_RUNTIME_SA must remain a required, no-default substitution");
  assert.ok(/^\s*_MONITORING_SA:\s*""/m.test(subsText), "_MONITORING_SA must remain a required, no-default substitution");
  assert.ok(!nonCommentLines(yamlText).some((l) => l.includes("compliance-scanner-sa@") || l.includes("compliance-scanner-monitor-sa@")), "no executable line may hardcode either runtime SA's real email — both remain substitution-only");
  const deployText = scriptText("deploy-candidate.sh");
  assert.ok(deployText.includes('--service-account="${SCANNER_RUNTIME_SA}"'), "deploy-candidate.sh must still deploy using the SCANNER_RUNTIME_SA env var, unchanged");
  const verifyText = scriptText("verify-deployed-candidate.sh");
  assert.ok(verifyText.includes('--impersonate-service-account="${MONITORING_SA}"'), "verify-deployed-candidate.sh must still impersonate via the MONITORING_SA env var, unchanged");
});

test("Cloud Build execution identity: no IAM mutation command (add-iam-policy-binding / set-iam-policy / remove-iam-policy-binding) is introduced anywhere in the YAML or any ci/*.sh script — this correction is execution-identity configuration only, never a runtime IAM change performed BY the pipeline itself", () => {
  const iamMutationPattern = /add-iam-policy-binding|remove-iam-policy-binding|set-iam-policy\b/;
  assert.ok(!iamMutationPattern.test(yamlText), "cloudbuild.signature-refresh.yaml must never contain an IAM mutation command");
  for (const fname of fs.readdirSync(path.join(REPO_ROOT, "ci"))) {
    if (!fname.endsWith(".sh")) continue;
    const text = fs.readFileSync(path.join(REPO_ROOT, "ci", fname), "utf8");
    assert.ok(!iamMutationPattern.test(text), `${fname} must never contain an IAM mutation command`);
  }
});

test("Cloud Build execution identity: no --allow-unauthenticated is introduced by this correction (regression guard, local to this correction's own diff)", () => {
  assert.ok(
    !nonCommentLines(yamlText).some((l) => /(?<!--no-)--allow-unauthenticated/.test(l)),
    "no executable line in the YAML may contain a bare --allow-unauthenticated"
  );
});

test("Cloud Build execution identity: no project literal 'barkymatches-new' (or any other hardcoded project id) is ever introduced on any EXECUTABLE line — every project reference remains the built-in ${PROJECT_ID} substitution or a ${_...} custom substitution (the file's own top-of-file doc comment legitimately names barkymatches-new once, as a negative example of what it does NOT hardcode)", () => {
  const executable = nonCommentLines(yamlText).join("\n");
  assert.ok(!executable.includes("barkymatches-new"), "the forbidden production project id must never appear on an executable line in this file");
  assert.ok(!/petsupo-platform-staging/.test(executable), "the staging project id must never be hardcoded on an executable line either — the whole point of ${PROJECT_ID} is environment portability");
});

test("Cloud Build execution identity: an absent or malformed serviceAccount: field would be caught by the static checks above, not silently accepted (meta-check — proves the regex-based extractor itself cannot silently return a false positive for a missing field)", () => {
  assert.equal(extractTopLevelServiceAccount("options:\n  logging: CLOUD_LOGGING_ONLY\nsubstitutions:\n"), null, "sanity: the extractor must return null when no serviceAccount: field exists, not an empty string or a stale match");
  assert.equal(extractTopLevelServiceAccount('options:\n  logging: CLOUD_LOGGING_ONLY\nserviceAccount: ""\n'), "", "sanity: the extractor must return an empty string (which the non-empty test above would then reject) for a present-but-empty field, not null");
});

// ---------------------------------------------------------------------
// Builder-image assignment (Slice 2.2 final correction, then the
// single-authoritative-resolver correction). Each step's actual
// `name:` image must match what that step's own script actually needs
// — proven per-step, not asserted only in a prose comment. FOUR steps
// now use the ci-builder substitution image: push-candidate,
// deploy-candidate, and promote need it for combined lease-fencing +
// mutation (node + gcloud/docker in one script); verify-deployed-
// candidate needs it for a different reason — it is non-mutating and
// never renews the lease, but now invokes the single canonical
// ci/resolveCandidateTrafficEntry.js resolver (node) instead of a
// second, independently-maintained Python port, closing a real
// semantic-drift risk between two implementations of the same
// fail-closed security check. Every other step uses a single-purpose
// official image, pinned by the exact digest resolved during this
// review.
// ---------------------------------------------------------------------

const NODE_IMAGE = "node:20.18.1-bookworm-slim@sha256:b2c8e0eb8a6aeeae33b2711f8f516003e27ee45804e270468d937b3214f2f0cc";
const DOCKER_IMAGE = "gcr.io/cloud-builders/docker@sha256:2e8d40d8e48dc14fab4213d5e532d74f63fd403d9e8d7f6463096a75820286c3";
const CLOUD_SDK_IMAGE = "gcr.io/google.com/cloudsdktool/cloud-sdk@sha256:73906ef0503c3f0d7f32eae1ceb855cae80774d0fafcead5097f42285a8a86d9";
const CI_BUILDER_IMAGE = "${_CI_BUILDER_IMAGE_REF}";

const EXPECTED_IMAGE_BY_STEP = {
  "install-dependencies": NODE_IMAGE,
  "acquire-lock": NODE_IMAGE,
  "materialize-runtime-manifest": NODE_IMAGE,
  "verify-fixtures-integrity": NODE_IMAGE,
  "verify-source": NODE_IMAGE,
  "release-lock": NODE_IMAGE,
  "build-candidate": DOCKER_IMAGE,
  "verify-candidate-container": DOCKER_IMAGE,
  "resolve-digest": CLOUD_SDK_IMAGE,
  "verify-deployed-candidate": CI_BUILDER_IMAGE,
  "push-candidate": CI_BUILDER_IMAGE,
  "deploy-candidate": CI_BUILDER_IMAGE,
  "promote": CI_BUILDER_IMAGE,
};

test("every step's declared image matches the expected single-purpose or ci-builder assignment", () => {
  for (const [id, expected] of Object.entries(EXPECTED_IMAGE_BY_STEP)) {
    assert.equal(stepsById[id].name, expected, `${id} should use ${expected}`);
  }
});

test("no image reference uses a floating tag alone — every image is pinned by @sha256 digest or the explicit ci-builder substitution", () => {
  for (const step of steps) {
    const isDigestPinned = step.name.includes("@sha256:");
    const isCiBuilderSubstitution = step.name === CI_BUILDER_IMAGE;
    assert.ok(isDigestPinned || isCiBuilderSubstitution, `${step.id}'s image "${step.name}" must be digest-pinned or the ci-builder substitution`);
  }
});

test("only the four combined-tool steps (push-candidate, deploy-candidate, promote, verify-deployed-candidate) use the ci-builder image — every other step uses a single-purpose official image", () => {
  const usingCiBuilder = steps.filter((s) => s.name === CI_BUILDER_IMAGE).map((s) => s.id).sort();
  assert.deepEqual(usingCiBuilder, ["deploy-candidate", "promote", "push-candidate", "verify-deployed-candidate"]);
});

test("verify-deployed-candidate's step uses the SAME `${_CI_BUILDER_IMAGE_REF}` substitution literal every other combined-tool step uses — not a second, separately-spelled reference to the same image, and not a hardcoded digest", () => {
  assert.equal(stepsById["verify-deployed-candidate"].name, "${_CI_BUILDER_IMAGE_REF}");
  assert.equal(stepsById["verify-deployed-candidate"].name, stepsById["promote"].name);
  assert.equal(stepsById["verify-deployed-candidate"].name, stepsById["deploy-candidate"].name);
  assert.equal(stepsById["verify-deployed-candidate"].name, stepsById["push-candidate"].name);
});

test("_CI_BUILDER_IMAGE_REF is already a REQUIRED substitution (no default) — verify-deployed-candidate's move onto it introduces no new substitution and does not relax its no-default requirement", () => {
  const subsSectionMatch = yamlText.match(/\nsubstitutions:\n([\s\S]*?)\nsteps:/);
  assert.ok(subsSectionMatch, "could not locate substitutions: section");
  const subsText = subsSectionMatch[1];
  assert.ok(/_CI_BUILDER_IMAGE_REF:\s*""/.test(subsText), "_CI_BUILDER_IMAGE_REF must exist with an empty-string (no production-looking) default");
  assert.equal((subsText.match(/^\s*_CI_BUILDER_IMAGE_REF:/gm) || []).length, 1, "_CI_BUILDER_IMAGE_REF must be declared exactly once");
});

test("verify-deployed-candidate's step identity — id, waitFor, args, env, and timeout — is unchanged by the image switch; only its name: (image) changed", () => {
  const blockMatch = yamlText.match(/- id: verify-deployed-candidate[\s\S]*?(?=\n  - id: |\nimages:)/);
  assert.ok(blockMatch, "could not locate the verify-deployed-candidate step block");
  const block = blockMatch[0];
  assert.ok(block.startsWith("- id: verify-deployed-candidate\n"), "step id must be unchanged");
  assert.ok(block.includes('waitFor: ["deploy-candidate"]'), "waitFor must remain exactly [\"deploy-candidate\"] — unchanged by the image switch");
  assert.ok(block.includes('args: ["services/compliance-scanner/ci/verify-deployed-candidate.sh"]'), "args must be unchanged");
  for (const envVar of ["PROJECT_ID", "REGION", "SERVICE", "MONITORING_SA", "SYNTHETIC_TEST_BUCKET", "SCANNER_RUNTIME_SA", "BUILD_ID"]) {
    assert.ok(block.includes(`"${envVar}=`), `env var ${envVar} must remain wired through, unchanged`);
  }
  assert.equal((block.match(/^\s*- "[A-Z_]+=/gm) || []).length, 7, "exactly 7 env entries — no env entry added or removed by the image switch");
  assert.ok(block.includes("timeout: 600s"), "timeout must remain 600s — unchanged by the image switch");
});

test("ci-builder's own Dockerfile bakes in a sanity check for every tool verify-deployed-candidate.sh needs (gcloud, curl, sha256sum, node) — a build-time guarantee, not just an assumption this test suite makes; and it is built FROM the identical cloud-sdk base verify-deployed-candidate.sh used before, so gcloud/curl/sha256sum are provably unchanged, not re-derived", () => {
  const dockerfileText = fs.readFileSync(path.join(REPO_ROOT, "ci", "Dockerfile.ci-builder"), "utf8");
  assert.ok(
    /^FROM gcr\.io\/google\.com\/cloudsdktool\/cloud-sdk@sha256:73906ef0503c3f0d7f32eae1ceb855cae80774d0fafcead5097f42285a8a86d9$/m.test(dockerfileText),
    "ci-builder must be built FROM the exact same digest-pinned cloud-sdk image verify-deployed-candidate.sh used before the image switch — proves gcloud/curl/sha256sum are inherited unchanged, not a different/re-verified version"
  );
  for (const tool of ["node --version", "gcloud --version", "curl --version", "sha256sum --version"]) {
    assert.ok(dockerfileText.includes(tool), `Dockerfile.ci-builder's own build-time sanity check must verify ${tool.split(" ")[0]} is present and working`);
  }
});

test("resolve-digest is a separate, non-mutating, gcloud-only step between push-candidate and deploy-candidate", () => {
  assert.equal(stepsById["resolve-digest"].name, CLOUD_SDK_IMAGE);
  assert.deepEqual(stepsById["resolve-digest"].waitFor, ["push-candidate"]);
  assert.deepEqual(stepsById["deploy-candidate"].waitFor, ["resolve-digest"]);
});

test("push-candidate.sh no longer resolves the digest itself — that responsibility moved to resolve-digest.sh", () => {
  const text = scriptText("push-candidate.sh");
  assert.ok(!text.includes("gcloud artifacts docker images describe"), "push-candidate.sh must not itself call gcloud artifacts docker images describe");
  assert.ok(!text.includes("/workspace/.candidate-digest"), "push-candidate.sh must not write .candidate-digest — resolve-digest.sh does");
});

test("resolve-digest.sh is the only script that writes /workspace/.candidate-digest (Mandatory correction 5: digest files cannot be replaced by untrusted step output)", () => {
  const ciDir = __dirname;
  const writers = [];
  for (const fname of fs.readdirSync(ciDir)) {
    if (!fname.endsWith(".sh")) continue;
    const text = fs.readFileSync(path.join(ciDir, fname), "utf8");
    if (/>\s*\/workspace\/\.candidate-digest\b/.test(text)) writers.push(fname);
  }
  assert.deepEqual(writers, ["resolve-digest.sh"]);
});

// Matches a tool name only in COMMAND position — at the start of a
// (possibly indented) line, or immediately after a shell command
// separator/opener ($(, |, &&, ||, ;, `{`  followed by whitespace) —
// never inside prose such as an echo string. This is deliberately
// narrower than a bare `\btool\s` search specifically because that
// broader form false-positived on "node adapter" inside an error
// message string in verify-candidate-container.sh (caught by this
// suite failing against its own real script content, not assumed
// correct) — the same class of over-matching this file's
// --allow-unauthenticated test already had to guard against.
function invokesCommand(text, tool) {
  const pattern = new RegExp(`(^|\\n)\\s*${tool}\\s|[$(|;{]\\s*${tool}\\s|&&\\s*${tool}\\s|\\|\\|\\s*${tool}\\s`);
  return pattern.test(text);
}

test("no step's script under ci/ uses a tool its assigned image does not have: node-only steps never call gcloud/docker; docker-only steps never call gcloud/node; cloud-sdk steps never call docker/node", () => {
  const nodeOnlySteps = ["install-dependencies.sh", "acquire-lock.sh", "materialize-runtime-manifest.sh", "verify-fixtures.sh", "verify-source.sh", "release-lock.sh"];
  for (const fname of nodeOnlySteps) {
    const text = scriptText(fname);
    assert.ok(!invokesCommand(text, "gcloud"), `${fname} (node-only image) must not invoke gcloud`);
    assert.ok(!invokesCommand(text, "docker"), `${fname} (node-only image) must not invoke docker`);
  }

  const dockerOnlySteps = ["build-candidate.sh", "verify-candidate-container.sh"];
  for (const fname of dockerOnlySteps) {
    const text = scriptText(fname);
    assert.ok(!invokesCommand(text, "gcloud"), `${fname} (docker-only image) must not invoke gcloud`);
    assert.ok(!invokesCommand(text, "node"), `${fname} (docker-only image) must not invoke node`);
  }

  const cloudSdkOnlySteps = ["resolve-digest.sh"];
  for (const fname of cloudSdkOnlySteps) {
    const text = scriptText(fname);
    assert.ok(!invokesCommand(text, "docker"), `${fname} (cloud-sdk-only image) must not invoke docker`);
    assert.ok(!invokesCommand(text, "node"), `${fname} (cloud-sdk-only image) must not invoke node`);
  }

  // verify-deployed-candidate.sh now runs on the ci-builder image
  // (single-authoritative-resolver correction) and DOES legitimately
  // invoke node (for the shared resolver) — it is intentionally
  // excluded from cloudSdkOnlySteps above. It still has no reason to
  // invoke docker, which this check confirms.
  assert.ok(!invokesCommand(scriptText("verify-deployed-candidate.sh"), "docker"), "verify-deployed-candidate.sh (ci-builder image) must still never invoke docker — it does not need it");
  // Plain substring check, not invokesCommand: node is invoked here
  // via the `VAR=value node ...` env-var-prefix shell form (piped
  // after an env-var assignment), which invokesCommand's command-
  // position regex does not match by design (it looks for a tool at
  // the start of a line or after a shell separator, not after a
  // leading `NAME=value` token) — the exact same shape already proven
  // for promote.sh's own resolver invocation elsewhere in this file.
  assert.ok(scriptText("verify-deployed-candidate.sh").includes("node ci/resolveCandidateTrafficEntry.js"), "sanity: verify-deployed-candidate.sh must invoke node — it now runs the shared JS resolver");
});

test("sanity: invokesCommand actually detects real invocations (proves the helper isn't accidentally always-false)", () => {
  assert.ok(invokesCommand(scriptText("build-candidate.sh"), "docker"));
  assert.ok(invokesCommand(scriptText("acquire-lock.sh"), "node"));
  assert.ok(invokesCommand(scriptText("resolve-digest.sh"), "gcloud"));
  // And confirms the false-positive case is genuinely excluded now.
  assert.ok(!invokesCommand(scriptText("verify-candidate-container.sh"), "node"));
});

test("promote transitively depends on verify-deployed-candidate, verify-candidate-container, verify-source, verify-fixtures-integrity, and materialize-runtime-manifest", () => {
  for (const required of [
    "verify-deployed-candidate",
    "verify-candidate-container",
    "verify-source",
    "verify-fixtures-integrity",
    "materialize-runtime-manifest",
  ]) {
    assert.ok(transitiveDependsOn("promote", required), `promote must transitively depend on ${required}`);
  }
});

// ---------------------------------------------------------------------
// Runtime-manifest correction — dependency graph, substitutions, fixed
// output path.
// ---------------------------------------------------------------------

test("runtime-manifest: materialize-runtime-manifest depends on verify-source, not merely acquire-lock (Slice 2.2 dependency-graph correction, closing the real staging build failure 940e4f3a-2eb5-4e04-9568-6ad9d2059c1a — verify-fixtures-integrity: \"Cannot find module '@google-cloud/storage'\")", () => {
  assert.deepEqual(stepsById["materialize-runtime-manifest"].waitFor, ["verify-source"]);
});

test("dependency-graph race regression guard: materialize-runtime-manifest must never again be a direct, acquire-lock-only sibling of verify-source — that exact relationship let Cloud Build start both concurrently and is the confirmed root cause of build 940e4f3a-2eb5-4e04-9568-6ad9d2059c1a's failure", () => {
  assert.notDeepEqual(stepsById["materialize-runtime-manifest"].waitFor, ["acquire-lock"]);
  assert.ok(
    !stepsById["materialize-runtime-manifest"].waitFor.includes("acquire-lock"),
    "materialize-runtime-manifest must not directly waitFor acquire-lock — it must be gated behind verify-source instead"
  );
});

test("runtime-manifest: verify-fixtures-integrity now waits for materialize-runtime-manifest, not directly for acquire-lock (materialization precedes fixture verification)", () => {
  assert.deepEqual(stepsById["verify-fixtures-integrity"].waitFor, ["materialize-runtime-manifest"]);
});

test("runtime-manifest: the two new substitutions exist with no production-looking default (both empty string)", () => {
  const subsSectionMatch = yamlText.match(/\nsubstitutions:\n([\s\S]*?)\nsteps:/);
  assert.ok(subsSectionMatch, "could not locate substitutions: section");
  const subsText = subsSectionMatch[1];
  assert.ok(/_RUNTIME_FIXTURE_MANIFEST_GCS_URI:\s*""/.test(subsText));
  assert.ok(/_RUNTIME_FIXTURE_MANIFEST_GENERATION:\s*""/.test(subsText));
});

test("runtime-manifest: materialize-runtime-manifest's env wires the two new substitutions through (not hardcoded literal values)", () => {
  const step = stepsById["materialize-runtime-manifest"];
  assert.ok(step, "materialize-runtime-manifest step must exist");
  const blockMatch = yamlText.match(/- id: materialize-runtime-manifest[\s\S]*?(?=\n  - id: |\nimages:)/);
  assert.ok(blockMatch);
  const block = blockMatch[0];
  assert.ok(block.includes("RUNTIME_FIXTURE_MANIFEST_GCS_URI=${_RUNTIME_FIXTURE_MANIFEST_GCS_URI}"));
  assert.ok(block.includes("RUNTIME_FIXTURE_MANIFEST_GENERATION=${_RUNTIME_FIXTURE_MANIFEST_GENERATION}"));
});

test("runtime-manifest: the materialized-manifest output/input path is a single fixed literal in both steps' env, never a Cloud Build substitution", () => {
  const outLines = yamlText.match(/RUNTIME_FIXTURE_MANIFEST_(OUT|PATH)=[^"\n]*/g) || [];
  assert.ok(outLines.length >= 2, "expected both the writer (OUT) and reader (PATH) steps to set this literal");
  for (const line of outLines) {
    assert.ok(!/\$\{_/.test(line), `path literal must not reference a substitution: ${line}`);
    assert.ok(line.includes("/workspace/.runtime-fixture-manifest.json"), `expected the one fixed path, got: ${line}`);
  }
});

test("push-candidate directly depends on verify-fixtures-integrity, verify-source, AND verify-candidate-container (not just transitively)", () => {
  assert.deepEqual(
    stepsById["push-candidate"].waitFor.slice().sort(),
    ["verify-candidate-container", "verify-fixtures-integrity", "verify-source"]
  );
});

test("release-lock is the terminal step — nothing depends on it, and it depends on promote", () => {
  assert.deepEqual(stepsById["release-lock"].waitFor, ["promote"]);
  assert.ok(!steps.some((s) => s.waitFor.includes("release-lock")), "no step should wait for release-lock");
});

// ---------------------------------------------------------------------
// Dependency-provisioning correction — install-dependencies must run
// before every step whose script resolves a non-builtin npm package
// (acquire-lock, materialize-runtime-manifest, verify-fixtures-
// integrity, push-candidate, deploy-candidate, promote, release-lock —
// all reach ci/signatureRefreshLock.js and/or ci/fixtureManifest.js /
// ci/materializeRuntimeManifest.js, each of which requires
// @google-cloud/storage inside its own `require.main === module` CLI
// block), and must never run concurrently with verify-source.sh's own,
// separate `npm ci`.
// ---------------------------------------------------------------------

test("dependency-provisioning: exactly one install-dependencies step exists", () => {
  const matches = steps.filter((s) => s.id === "install-dependencies");
  assert.equal(matches.length, 1);
});

test("dependency-provisioning: install-dependencies uses the same digest-pinned Node image as every other node-only step", () => {
  assert.equal(stepsById["install-dependencies"].name, NODE_IMAGE);
});

test("dependency-provisioning: install-dependencies invokes exactly ci/install-dependencies.sh, no inline shell implementation", () => {
  const blockMatch = yamlText.match(/- id: install-dependencies[\s\S]*?(?=\n  - id: |\nimages:)/);
  assert.ok(blockMatch, "could not locate the install-dependencies step block");
  const block = blockMatch[0];
  assert.ok(/args:\s*\["services\/compliance-scanner\/ci\/install-dependencies\.sh"\]/.test(block));
});

test("dependency-provisioning: install-dependencies.sh uses `npm ci`, never `npm install`", () => {
  const text = scriptText("install-dependencies.sh");
  assert.ok(/\bnpm ci\b/.test(text), "must use npm ci");
  assert.ok(!/\bnpm install\b/.test(text), "must not use npm install anywhere, including in comments describing behavior");
});

test("dependency-provisioning: install-dependencies.sh never writes to package.json or package-lock.json", () => {
  const text = scriptText("install-dependencies.sh");
  assert.ok(!/>\s*package(-lock)?\.json/.test(text), "must not redirect output into either manifest file");
  assert.ok(!/npm (version|pkg|init)\b/.test(text), "must not invoke any npm subcommand that mutates package.json");
});

test("dependency-provisioning: acquire-lock depends directly on install-dependencies", () => {
  assert.deepEqual(stepsById["acquire-lock"].waitFor, ["install-dependencies"]);
});

test("dependency-provisioning: verify-source cannot run concurrently with install-dependencies (transitively sequenced behind it via acquire-lock, never a parallel/no-waitFor step)", () => {
  assert.ok(transitiveDependsOn("verify-source", "install-dependencies"), "verify-source must transitively depend on install-dependencies");
  assert.ok(stepsById["verify-source"].waitFor.length > 0, "verify-source must not be a root (no-waitFor) step");
});

test("dependency-provisioning: materialize-runtime-manifest transitively depends on install-dependencies", () => {
  assert.ok(transitiveDependsOn("materialize-runtime-manifest", "install-dependencies"));
});

test("dependency-provisioning: every step whose script resolves @google-cloud/storage transitively depends on install-dependencies", () => {
  // acquire-lock, materialize-runtime-manifest, verify-fixtures-integrity,
  // and release-lock invoke it directly on the plain node image;
  // push-candidate, deploy-candidate, and promote reach it indirectly
  // via `sh ci/renew-lease-or-fail.sh` on the ci-builder image, which
  // (confirmed by inspecting ci/Dockerfile.ci-builder) does not bake in
  // this service's own node_modules either.
  const dependents = [
    "acquire-lock",
    "materialize-runtime-manifest",
    "verify-fixtures-integrity",
    "push-candidate",
    "deploy-candidate",
    "promote",
    "release-lock",
  ];
  for (const id of dependents) {
    assert.ok(transitiveDependsOn(id, "install-dependencies"), `${id} must transitively depend on install-dependencies`);
  }
});

test("dependency-provisioning: install-dependencies and verify-source's own npm ci cannot overlap — install-dependencies has no waitFor of its own (runs first) and verify-source only starts once acquire-lock (which itself waits for install-dependencies) has fully completed", () => {
  assert.deepEqual(stepsById["install-dependencies"].waitFor, []);
  assert.deepEqual(stepsById["acquire-lock"].waitFor, ["install-dependencies"]);
  assert.deepEqual(stepsById["verify-source"].waitFor, ["acquire-lock"]);
});

test("dependency-provisioning: promote still transitively depends on verify-fixtures-integrity (fixture verification gate unweakened by this correction)", () => {
  assert.ok(transitiveDependsOn("promote", "verify-fixtures-integrity"));
});

test("dependency-provisioning: the existing fencing graph is unchanged — promote still transitively depends on acquire-lock, materialize-runtime-manifest, verify-deployed-candidate, and verify-candidate-container", () => {
  for (const required of ["acquire-lock", "materialize-runtime-manifest", "verify-deployed-candidate", "verify-candidate-container"]) {
    assert.ok(transitiveDependsOn("promote", required), `promote must still transitively depend on ${required}`);
  }
});

test("dependency-provisioning: no other step's args contain an inline `npm ci`/`npm install` — every dependency install is confined to the one dedicated install-dependencies.sh script", () => {
  for (const step of steps) {
    if (step.id === "install-dependencies") continue;
    const blockMatch = yamlText.match(new RegExp(`- id: ${step.id}[\\s\\S]*?(?=\\n  - id: |\\nimages:)`));
    assert.ok(blockMatch, `could not locate block for ${step.id}`);
    assert.ok(!/npm (ci|install)\b/.test(blockMatch[0]), `${step.id}'s YAML block must not contain an inline npm ci/install`);
  }
});

test("dependency-provisioning: install-dependencies' image is digest-pinned, not a floating tag", () => {
  assert.ok(stepsById["install-dependencies"].name.includes("@sha256:"));
});

// ---------------------------------------------------------------------
// Dependency-graph race fix (Slice 2.2, closing the real staging build
// failure 940e4f3a-2eb5-4e04-9568-6ad9d2059c1a — verify-fixtures-
// integrity: "Cannot find module '@google-cloud/storage'"). These
// tests inspect the ACTUAL extracted YAML graph and the ACTUAL
// ci/*.sh script contents — never a hand-duplicated imaginary graph —
// so a future edit that reintroduces the race fails these tests
// automatically, the same way the real build failed.
// ---------------------------------------------------------------------

// Every step whose own script (directly, or indirectly via
// ci/renew-lease-or-fail.sh) resolves @google-cloud/storage from the
// shared services/compliance-scanner/node_modules directory —
// i.e. every step that could, in principle, observe verify-source's
// npm ci mid-reinstall if the graph did not order it away.
const NODE_MODULES_CONSUMERS = [
  "acquire-lock",
  "materialize-runtime-manifest",
  "verify-fixtures-integrity",
  "push-candidate",
  "deploy-candidate",
  "promote",
  "release-lock",
];

test("dependency-graph race fix: every node_modules-consuming step is strictly ordered relative to verify-source's own npm ci — either it is an ancestor of verify-source (runs, and fully finishes, before verify-source even starts) or a waitFor-transitive descendant of verify-source (cannot start until verify-source, and therefore its npm ci, has fully finished) — never neither, which is exactly the sibling relationship that let materialize-runtime-manifest race verify-source in the real failure", () => {
  for (const id of NODE_MODULES_CONSUMERS) {
    const isAncestor = transitiveDependsOn("verify-source", id);
    const isDescendant = transitiveDependsOn(id, "verify-source");
    assert.ok(
      isAncestor || isDescendant,
      `${id} must be either an ancestor or a waitFor-transitive descendant of verify-source, but is neither — it could run concurrently with verify-source's npm ci`
    );
    assert.ok(
      !(isAncestor && isDescendant),
      `${id} cannot be both an ancestor and a descendant of verify-source — the graph would contain a cycle`
    );
  }
});

test("dependency-graph race fix: acquire-lock (and, transitively, install-dependencies) precede verify-source — they are the ONE node_modules consumer that is safe by preceding the second npm ci, not by following it", () => {
  assert.ok(transitiveDependsOn("verify-source", "acquire-lock"));
  assert.ok(transitiveDependsOn("verify-source", "install-dependencies"));
  assert.ok(!transitiveDependsOn("acquire-lock", "verify-source"), "acquire-lock must not depend on verify-source — it runs first, using install-dependencies' npm ci");
});

test("dependency-graph race fix: materialize-runtime-manifest, verify-fixtures-integrity, push-candidate, deploy-candidate, promote, and release-lock are all waitFor-transitive descendants of verify-source (they follow its npm ci, they do not precede it)", () => {
  const mustFollowVerifySource = [
    "materialize-runtime-manifest",
    "verify-fixtures-integrity",
    "push-candidate",
    "deploy-candidate",
    "promote",
    "release-lock",
  ];
  for (const id of mustFollowVerifySource) {
    assert.ok(transitiveDependsOn(id, "verify-source"), `${id} must transitively depend on verify-source`);
  }
});

test("dependency-graph race fix: exactly two ci/*.sh scripts invoke `npm ci` (install-dependencies.sh and verify-source.sh) — no third, undiscovered npm ci exists anywhere that this graph analysis could have missed", () => {
  const ciDir = __dirname;
  const writers = [];
  for (const fname of fs.readdirSync(ciDir)) {
    if (!fname.endsWith(".sh")) continue;
    const text = fs.readFileSync(path.join(ciDir, fname), "utf8");
    if (nonCommentLines(text).some((l) => /\bnpm ci\b/.test(l))) writers.push(fname);
  }
  assert.deepEqual(writers.sort(), ["install-dependencies.sh", "verify-source.sh"]);
});

test("dependency-graph race fix: the two npm ci invocations cannot overlap because verify-source is a waitFor-transitive descendant of install-dependencies (via acquire-lock), and a step only starts once every step in its waitFor list has fully completed", () => {
  assert.ok(transitiveDependsOn("verify-source", "install-dependencies"));
  assert.deepEqual(stepsById["install-dependencies"].waitFor, [], "install-dependencies must have no predecessor — it is the first npm ci to ever run");
});

test("dependency-graph race fix: build-candidate is proven independent of the shared, host-side services/compliance-scanner/node_modules directory, so it may safely remain parallel with verify-source", () => {
  const dockerignorePath = path.join(REPO_ROOT, ".dockerignore");
  assert.ok(fs.existsSync(dockerignorePath), "services/compliance-scanner/.dockerignore must exist");
  const dockerignore = fs.readFileSync(dockerignorePath, "utf8");
  assert.ok(
    nonCommentLines(dockerignore).some((l) => l.trim() === "node_modules"),
    "the Docker build context must exclude node_modules, so the daemon never reads the host's copy at all"
  );

  const dockerfile = fs.readFileSync(path.join(REPO_ROOT, "Dockerfile"), "utf8");
  // The "deps" build stage must install its OWN node_modules from the
  // lockfile inside the image, never COPY the host build-context's
  // node_modules into any stage.
  assert.ok(/FROM[^\n]*AS deps/.test(dockerfile), "expected a dedicated deps stage");
  assert.ok(/RUN npm ci --omit=dev/.test(dockerfile), "the deps stage must run its own npm ci, not reuse a host copy");
  assert.ok(
    !/COPY\s+(?!--from=)[^\n]*node_modules/.test(dockerfile),
    "no Dockerfile stage may COPY node_modules directly from the build context (only COPY --from=deps, an internal multi-stage copy, is allowed)"
  );

  const buildCandidateText = scriptText("build-candidate.sh");
  assert.ok(/docker build --platform linux\/amd64/.test(buildCandidateText), "build-candidate.sh must invoke docker build");
  assert.ok(!/node_modules/.test(buildCandidateText), "build-candidate.sh itself must never reference node_modules");
});

test("dependency-graph race fix: build-candidate's waitFor is unchanged (still just acquire-lock) — proven safe to remain parallel with verify-source, not sequenced behind it", () => {
  assert.deepEqual(stepsById["build-candidate"].waitFor, ["acquire-lock"]);
  assert.ok(!transitiveDependsOn("build-candidate", "verify-source"), "build-candidate must not be forced to wait for verify-source — it does not need to be, since it never reads shared node_modules");
});

test("dependency-graph race fix: promote remains transitively dependent on every required gate — acquire-lock, verify-source, materialize-runtime-manifest, verify-fixtures-integrity, verify-candidate-container (candidate verification), and verify-deployed-candidate (deployed-candidate verification)", () => {
  for (const required of [
    "acquire-lock",
    "verify-source",
    "materialize-runtime-manifest",
    "verify-fixtures-integrity",
    "verify-candidate-container",
    "verify-deployed-candidate",
  ]) {
    assert.ok(transitiveDependsOn("promote", required), `promote must transitively depend on ${required}`);
  }
});

test("dependency-graph race fix: the YAML's own Stage -1 comment states the real invariant and no longer claims transitive descent from acquire-lock alone prevents the race", () => {
  assert.ok(
    yamlText.includes("940e4f3a-2eb5-4e04-9568-6ad9d2059c1a"),
    "the corrected comment must reference the real staging build that exposed this defect"
  );
  assert.ok(
    !yamlText.includes("so gating ONLY\n  # acquire-lock on this step"),
    "the old, disproven claim (gating only on acquire-lock is sufficient) must not remain in the file"
  );
  assert.ok(
    yamlText.includes('waitFor: ["verify-source"], not merely ["acquire-lock"]'),
    "the corrected comment must state the real fix explicitly"
  );
});

// ---------------------------------------------------------------------
// Timeout / lease relationship — Mandatory correction 2, item 10
// ---------------------------------------------------------------------

test("every MUTATING step's timeout is strictly less than the default lease duration (900s), with real margin", () => {
  const LEASE_SECONDS_DEFAULT = 900;
  const mutatingSteps = ["push-candidate", "deploy-candidate", "promote", "release-lock"];
  for (const id of mutatingSteps) {
    const timeout = stepsById[id].timeout;
    assert.ok(timeout !== null, `${id} must have an explicit timeout`);
    assert.ok(timeout < LEASE_SECONDS_DEFAULT, `${id}'s timeout (${timeout}s) must be less than the lease (${LEASE_SECONDS_DEFAULT}s)`);
    assert.ok(LEASE_SECONDS_DEFAULT - timeout >= 300, `${id} must have at least 300s margin under the lease`);
  }
});

test("every step in the pipeline has an explicit timeout (no implicit/default reliance)", () => {
  for (const step of steps) {
    assert.ok(step.timeout !== null, `${step.id} must declare an explicit timeout:`);
  }
});

// ---------------------------------------------------------------------
// Fencing — Mandatory correction 2, items 7/8/9/11/12: every mutating
// step's OWN SCRIPT must call renew-lease-or-fail.sh, and must do so
// BEFORE its real mutating command (docker push / gcloud run deploy /
// gcloud run services update-traffic / node ...release).
// ---------------------------------------------------------------------

const MUTATING_SCRIPT_MUTATION_PATTERN = {
  "push-candidate.sh": /docker push/,
  "deploy-candidate.sh": /gcloud run deploy/,
  "promote.sh": /gcloud run services update-traffic/,
  "release-lock.sh": /signatureRefreshLock\.js release/,
};

for (const [scriptName, mutationPattern] of Object.entries(MUTATING_SCRIPT_MUTATION_PATTERN)) {
  test(`${scriptName}: calls renew-lease-or-fail.sh BEFORE its own real mutation (${mutationPattern})`, () => {
    const text = scriptText(scriptName);
    const renewIndex = text.indexOf("renew-lease-or-fail.sh");
    assert.ok(renewIndex !== -1, `${scriptName} must call renew-lease-or-fail.sh`);
    const mutationMatch = text.match(mutationPattern);
    assert.ok(mutationMatch, `${scriptName} must contain its expected mutation command`);
    const mutationIndex = text.indexOf(mutationMatch[0]);
    assert.ok(renewIndex < mutationIndex, `${scriptName} must renew the lease BEFORE ${mutationMatch[0]}, not after`);
  });
}

test("promote.sh renews the lease a SECOND, separate time before the rollback mutation specifically (item: rollback-related mutation is independently fenced)", () => {
  const text = scriptText("promote.sh");
  const occurrences = text.split("renew-lease-or-fail.sh").length - 1;
  assert.ok(occurrences >= 2, "promote.sh must call renew-lease-or-fail.sh at least twice (promotion shift + rollback shift)");
});

test("renew-lease-or-fail.sh failure is never swallowed by push/deploy/promote/release (no `renew-lease-or-fail.sh || true` anywhere)", () => {
  for (const scriptName of Object.keys(MUTATING_SCRIPT_MUTATION_PATTERN)) {
    const text = scriptText(scriptName);
    assert.ok(!/renew-lease-or-fail\.sh\s*\|\|\s*true/.test(text), `${scriptName} must not swallow a failed lease renewal`);
  }
});

test("renew-lease-or-fail.sh itself: a refused renewal (non-zero exit from the lock CLI) is never followed by a swallowing `|| true`, and the script uses set -eu", () => {
  const text = scriptText("renew-lease-or-fail.sh");
  assert.ok(/^set -eu$/m.test(text), "renew-lease-or-fail.sh must use set -eu");
  assert.ok(!/signatureRefreshLock\.js renew[^\n]*\|\|\s*true/.test(text), "a failed renew must not be swallowed");
});

// ---------------------------------------------------------------------
// No public/unauthenticated access anywhere
// ---------------------------------------------------------------------

function nonCommentLines(text) {
  return text.split("\n").filter((line) => !line.trim().startsWith("#") && !line.trim().startsWith("//"));
}

test("no --allow-unauthenticated on any EXECUTABLE line in the YAML or any ci/*.sh script (comment-only mentions, e.g. explaining the absence, are expected and excluded)", () => {
  // Matches a bare "--allow-unauthenticated" NOT immediately preceded
  // by the 5-character "--no-" prefix that makes it the safe, opposite
  // flag. Restricted to non-comment lines: several files intentionally
  // document "no --allow-unauthenticated is used" in prose, which would
  // otherwise be an over-broad false positive — this is exactly why the
  // check must inspect real command lines, not raw substring search
  // across the whole file (the same principle Mandatory correction 3
  // asks for regarding command construction generally).
  const bareFlagPattern = /(?<!--no-)--allow-unauthenticated/;
  assert.ok(
    !nonCommentLines(yamlText).some((l) => bareFlagPattern.test(l)),
    "YAML must never contain a bare --allow-unauthenticated on an executable line"
  );
  const ciDir = __dirname;
  for (const fname of fs.readdirSync(ciDir)) {
    if (!fname.endsWith(".sh")) continue;
    const text = fs.readFileSync(path.join(ciDir, fname), "utf8");
    assert.ok(
      !nonCommentLines(text).some((l) => bareFlagPattern.test(l)),
      `${fname} must never contain a bare --allow-unauthenticated on an executable line`
    );
  }
});

test("deploy-candidate.sh explicitly passes --no-allow-unauthenticated to gcloud run deploy", () => {
  const text = scriptText("deploy-candidate.sh");
  assert.ok(/gcloud run deploy[\s\S]*?--no-allow-unauthenticated/.test(text));
});

// ---------------------------------------------------------------------
// Digest integrity — Mandatory correction 5: "digest files cannot be
// replaced by untrusted step output". Superseded by resolve-digest.sh
// (Slice 2.2 final correction, builder-image split) — see the
// "resolve-digest.sh is the only script that writes
// /workspace/.candidate-digest" and "push-candidate.sh no longer
// resolves the digest itself" tests earlier in this file, which
// replace the two tests that used to live here asserting
// push-candidate.sh itself did this.
// ---------------------------------------------------------------------

test(".candidate-digest is derived from a fresh `gcloud artifacts docker images describe` call in resolve-digest.sh, not copied from another step's claim", () => {
  const text = scriptText("resolve-digest.sh");
  const digestLineIndex = text.indexOf("> /workspace/.candidate-digest");
  const describeIndex = text.indexOf("gcloud artifacts docker images describe");
  assert.ok(describeIndex !== -1 && describeIndex < digestLineIndex);
});

// ---------------------------------------------------------------------
// Project/region explicitness — every gcloud run/artifacts command
// contains explicit --project and --region (where region applies)
// ---------------------------------------------------------------------

test("every `gcloud run` and `gcloud artifacts` invocation across all ci/*.sh scripts includes --project=", () => {
  const ciDir = __dirname;
  for (const fname of fs.readdirSync(ciDir)) {
    if (!fname.endsWith(".sh")) continue;
    const text = fs.readFileSync(path.join(ciDir, fname), "utf8");
    const lines = text.split("\n");
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].trim().startsWith("#")) continue; // comment lines are prose, not commands
      if (/gcloud (run|artifacts)/.test(lines[i])) {
        // Commands may wrap across lines with trailing backslashes —
        // join forward until a line without a trailing backslash.
        let block = lines[i];
        let j = i;
        while (block.trim().endsWith("\\") && j + 1 < lines.length) {
          j += 1;
          block += "\n" + lines[j];
        }
        assert.ok(block.includes("--project="), `${fname} line ${i + 1}: gcloud run/artifacts command missing --project=\n${block}`);
      }
    }
  }
});

// ---------------------------------------------------------------------
// Secrets/tokens never printed
// ---------------------------------------------------------------------

test("verify-deployed-candidate.sh never echoes/prints the raw TOKEN variable directly", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  assert.ok(!/echo\s+"?\$\{?TOKEN\}?"?\s*$/m.test(text), "TOKEN must never be echoed on its own");
  assert.ok(!/console\.log.*TOKEN/.test(text));
  // Every use of ${TOKEN} must be inside an Authorization header
  // construction, not a bare print statement.
  const tokenUses = text.match(/\$\{TOKEN\}/g) || [];
  assert.ok(tokenUses.length > 0, "sanity: TOKEN should be used at least once");
  for (const line of text.split("\n")) {
    if (line.includes("${TOKEN}")) {
      assert.ok(line.includes("Authorization: Bearer"), `TOKEN used outside an Authorization header: ${line}`);
    }
  }
});

// ---------------------------------------------------------------------
// Rollback correctness — Mandatory correction 3
// ---------------------------------------------------------------------

test("deploy-candidate.sh captures the FULL traffic allocation (status.traffic, the whole array) before deploying, not a single presumed revision", () => {
  const text = scriptText("deploy-candidate.sh");
  assert.ok(text.includes('--format="json(status.traffic)"'));
  assert.ok(text.includes("/workspace/.previous-traffic-allocation.json"));
});

test("promote.sh reconstructs --to-revisions from the FULL captured allocation, not a single revisionName", () => {
  const text = scriptText("promote.sh");
  assert.ok(text.includes(".previous-traffic-allocation.json"));
  assert.ok(text.includes("PREVIOUS_TO_REVISIONS"));
  assert.ok(!/--to-revisions="\$\{?PREVIOUS_REVISION\}?=100"/.test(text), "must not use the old single-revision rollback form");
});

test("promote.sh verifies the restored traffic after rollback, not just the update-traffic command's exit code", () => {
  const text = scriptText("promote.sh");
  assert.ok(text.includes("RESTORED_OK"));
  assert.ok(text.includes("critical_terminal_failure"));
});

test("promote.sh never removes or alters the candidate's own traffic tag", () => {
  const text = scriptText("promote.sh");
  assert.ok(!/gcloud run services update-traffic[\s\S]*?--remove-tags/.test(text));
  assert.ok(!text.includes("tags remove"));
});

test("promote.sh verifies runtime service account before treating promotion as successful", () => {
  const text = scriptText("promote.sh");
  assert.ok(text.includes("SERVING_SA"));
  assert.ok(text.includes("SCANNER_RUNTIME_SA"));
});

// ---------------------------------------------------------------------
// Candidate traffic-tag length correction (Slice 2.2, closing a real
// staging deploy failure — build c90ebe89-5c04-424b-abaa-16bb25e7db6f:
// "traffic tag 'candidate-<40-char COMMIT_SHA>-<8-char BUILD_ID>' and
// service name 'compliance-scanner' together are too long. Combined
// traffic tag and service name cannot exceed 46 characters"). These
// tests extract and BEHAVIORALLY RUN the actual corrected block from
// deploy-candidate.sh (not a hand-duplicated imaginary version), the
// same technique acquire-lock.sh's own Correction A behavioral test
// already uses in this file.
// ---------------------------------------------------------------------

function extractCandidateTagBlock() {
  const text = scriptText("deploy-candidate.sh");
  const match = text.match(/case "\$COMMIT_SHA" in[\s\S]*?\necho "\$CANDIDATE_TRAFFIC_TAG" > \/workspace\/\.candidate-traffic-tag\n/);
  assert.ok(match, "could not extract the candidate-tag block from deploy-candidate.sh");
  return match[0];
}

function runCandidateTagBlock({ commitSha, buildId, service }) {
  const block = extractCandidateTagBlock().replace(/\/workspace\//g, "./");
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "candidate-tag-sim-"));
  const result = spawnSync("sh", ["-c", `cd ${JSON.stringify(tmpDir)} && set -eu\n${block}`], {
    env: { ...process.env, COMMIT_SHA: commitSha, BUILD_ID: buildId, SERVICE: service },
    encoding: "utf8",
  });
  let writtenTag = null;
  const tagFile = path.join(tmpDir, ".candidate-traffic-tag");
  if (fs.existsSync(tagFile)) writtenTag = fs.readFileSync(tagFile, "utf8").trim();
  fs.rmSync(tmpDir, { recursive: true, force: true });
  return { ...result, writtenTag };
}

const REAL_FAILING_COMMIT_SHA = "43364ccb168ec47f6c7a4a0988e4e470151febec";
const REAL_FAILING_BUILD_ID = "c90ebe89-5c04-424b-abaa-16bb25e7db6f";
const REAL_SERVICE_NAME = "compliance-scanner";

test("candidate traffic tag: the real service name plus the generated tag is within Cloud Run's 46-character combined limit, proven by actually running the real corrected block", () => {
  const { status, stderr, writtenTag } = runCandidateTagBlock({
    commitSha: REAL_FAILING_COMMIT_SHA,
    buildId: REAL_FAILING_BUILD_ID,
    service: REAL_SERVICE_NAME,
  });
  assert.equal(status, 0, `expected success, got status ${status}, stderr: ${stderr}`);
  assert.ok(writtenTag, "expected a tag to be written");
  assert.ok(REAL_SERVICE_NAME.length + writtenTag.length <= 46, `combined length ${REAL_SERVICE_NAME.length + writtenTag.length} exceeds 46`);
});

test("candidate traffic tag: the EXACT previously-failing COMMIT_SHA/BUILD_ID pair from build c90ebe89 now produces the expected short, safe tag", () => {
  const { status, writtenTag } = runCandidateTagBlock({
    commitSha: REAL_FAILING_COMMIT_SHA,
    buildId: REAL_FAILING_BUILD_ID,
    service: REAL_SERVICE_NAME,
  });
  assert.equal(status, 0);
  assert.equal(writtenTag, "candidate-43364ccb-c90ebe89");
});

test("candidate traffic tag: a malformed or missing COMMIT_SHA fails closed (never silently truncated into a plausible-looking fragment)", () => {
  const badCommitShas = [
    "",
    "short",
    "43364CCB168EC47F6C7A4A0988E4E470151FEBEC", // uppercase — real git SHAs are always lowercase
    "43364ccb168ec47f6c7a4a0988e4e470151febe", // 39 chars — one short
    "43364ccb168ec47f6c7a4a0988e4e470151febecc", // 41 chars — one too many
    "43364ccb168ec47f6c7a4a0988e4e470151feb$", // non-hex character
    "not-a-sha-at-all-not-a-sha-at-all-not-a",
  ];
  for (const badSha of badCommitShas) {
    const { status, stderr, writtenTag } = runCandidateTagBlock({
      commitSha: badSha,
      buildId: REAL_FAILING_BUILD_ID,
      service: REAL_SERVICE_NAME,
    });
    assert.notEqual(status, 0, `expected failure for COMMIT_SHA=${JSON.stringify(badSha)}`);
    assert.ok(stderr.includes("COMMIT_SHA"), `expected a COMMIT_SHA-specific error, got: ${stderr}`);
    assert.equal(writtenTag, null, `no tag file should be written for a rejected COMMIT_SHA=${JSON.stringify(badSha)}`);
  }
});

test("candidate traffic tag: a malformed or missing BUILD_ID fails closed (never silently truncated into a plausible-looking fragment)", () => {
  const badBuildIds = [
    "",
    "short",
    "C90EBE89-5C04-424B-ABAA-16BB25E7DB6F", // uppercase — Cloud Build's own BUILD_ID is always lowercase
    "c90ebe895c04424babaa16bb25e7db6f", // missing hyphens
    "not-a-uuid-at-all-not-a-uuid-at-al",
  ];
  for (const badBuildId of badBuildIds) {
    const { status, stderr, writtenTag } = runCandidateTagBlock({
      commitSha: REAL_FAILING_COMMIT_SHA,
      buildId: badBuildId,
      service: REAL_SERVICE_NAME,
    });
    assert.notEqual(status, 0, `expected failure for BUILD_ID=${JSON.stringify(badBuildId)}`);
    assert.ok(stderr.includes("BUILD_ID"), `expected a BUILD_ID-specific error, got: ${stderr}`);
    assert.equal(writtenTag, null, `no tag file should be written for a rejected BUILD_ID=${JSON.stringify(badBuildId)}`);
  }
});

test("candidate traffic tag: the generated tag uses only Cloud Run tag-safe lowercase characters (letters, digits, hyphens)", () => {
  const { writtenTag } = runCandidateTagBlock({
    commitSha: REAL_FAILING_COMMIT_SHA,
    buildId: REAL_FAILING_BUILD_ID,
    service: REAL_SERVICE_NAME,
  });
  assert.ok(/^[a-z0-9-]+$/.test(writtenTag), `tag contains a disallowed character: ${writtenTag}`);
});

test("candidate traffic tag: no collision-prone constant-only tag is used — two different commit/build pairs produce two different tags", () => {
  const first = runCandidateTagBlock({ commitSha: REAL_FAILING_COMMIT_SHA, buildId: REAL_FAILING_BUILD_ID, service: REAL_SERVICE_NAME });
  const second = runCandidateTagBlock({
    commitSha: "9d4a441a70809012f701f7ec99cf3acba0f5f764",
    buildId: "eb02b226-1f41-4029-a748-1a7d69810a4b",
    service: REAL_SERVICE_NAME,
  });
  assert.notEqual(first.writtenTag, second.writtenTag, "different commit/build pairs must never produce the same tag");
});

test("candidate traffic tag: the full, untruncated COMMIT_SHA and BUILD_ID remain available in this step's own audit log line, even though the traffic tag itself is shortened", () => {
  const text = scriptText("deploy-candidate.sh");
  const auditLineMatch = text.match(/echo "deploy-candidate: full COMMIT_SHA=[^\n]*"/);
  assert.ok(auditLineMatch, "could not locate the audit log line");
  assert.ok(auditLineMatch[0].includes("${COMMIT_SHA}"), "the audit line must include the full, untruncated COMMIT_SHA variable");
  assert.ok(auditLineMatch[0].includes("${BUILD_ID}"), "the audit line must include the full, untruncated BUILD_ID variable");
});

test("candidate traffic tag: gcloud run deploy receives the validated, shortened CANDIDATE_TRAFFIC_TAG variable via --tag=, never a separately reconstructed value", () => {
  const text = scriptText("deploy-candidate.sh");
  const deployBlockMatch = text.match(/gcloud run deploy "\$\{SERVICE\}"[\s\S]*?--tag="\$\{CANDIDATE_TRAFFIC_TAG\}"/);
  assert.ok(deployBlockMatch, "gcloud run deploy must pass --tag=\"${CANDIDATE_TRAFFIC_TAG}\"");
});

test("candidate traffic tag: verify-deployed-candidate.sh derives CANDIDATE_URL from the exact same tag file deploy-candidate.sh writes — no separate reconstruction of the tag anywhere downstream", () => {
  const deployText = scriptText("deploy-candidate.sh");
  const verifyText = scriptText("verify-deployed-candidate.sh");
  assert.ok(deployText.includes('echo "$CANDIDATE_TRAFFIC_TAG" > /workspace/.candidate-traffic-tag'), "deploy-candidate.sh must still write the single shared tag file");
  assert.ok(verifyText.includes('CANDIDATE_TRAFFIC_TAG="$(cat /workspace/.candidate-traffic-tag)"'), "verify-deployed-candidate.sh must still read the tag back from that same shared file, unmodified by this correction");
});

test("candidate traffic tag: push-candidate.sh's image tag and promote.sh's promoted Artifact Registry tag remain fully unmodified by this correction — both still use the FULL, untruncated COMMIT_SHA and BUILD_ID, which is safe because Artifact Registry's docker-tag length limit (128 chars) is far more permissive than Cloud Run's 46-character combined limit", () => {
  const pushText = scriptText("push-candidate.sh");
  assert.ok(pushText.includes('REMOTE_TAG="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${COMMIT_SHA}-${BUILD_ID}"'), "push-candidate.sh's image tag must still use the full COMMIT_SHA and BUILD_ID, unchanged");

  const promoteText = scriptText("promote.sh");
  assert.ok(promoteText.includes('PROMOTED_TAG="promoted-${COMMIT_SHA:?COMMIT_SHA is required}-${BUILD_ID:?BUILD_ID is required}"'), "promote.sh's promoted tag must still use the full COMMIT_SHA and BUILD_ID, unchanged");

  // Sanity: even the longest realistic promoted tag stays far under
  // Artifact Registry's 128-character docker-tag limit.
  const longestPlausiblePromotedTag = `promoted-${REAL_FAILING_COMMIT_SHA}-${REAL_FAILING_BUILD_ID}`;
  assert.ok(longestPlausiblePromotedTag.length < 128, `promoted tag (${longestPlausiblePromotedTag.length} chars) unexpectedly approaches the Artifact Registry limit`);
});

test("candidate traffic tag correction: no change to public access, digest pinning, or rollback behavior — deploy-candidate.sh still passes --no-allow-unauthenticated, still deploys the resolved DIGEST, and still captures the full traffic allocation before mutating anything (public-access-on-any-executable-line is exhaustively covered file-wide by the existing 'no --allow-unauthenticated on any EXECUTABLE line' test above, not duplicated here)", () => {
  const text = scriptText("deploy-candidate.sh");
  assert.ok(text.includes("--no-allow-unauthenticated"), "must still deploy with no unauthenticated access");
  assert.ok(text.includes('DIGEST="$(cat /workspace/.candidate-digest)"'), "must still deploy the digest resolved by resolve-digest.sh, unchanged");
  assert.ok(text.includes('--image="${IMAGE_REF}"'), "must still deploy by digest-pinned image reference");
  assert.ok(text.includes('--format="json(status.traffic)"'), "must still capture the full pre-existing traffic allocation before deploying, unchanged (regression guard alongside the Rollback correctness tests above)");
});

// ---------------------------------------------------------------------
// Fixture mandatory-ness — Mandatory correction 1: no silent skip
// ---------------------------------------------------------------------

test("verify-candidate-container.sh and verify-deployed-candidate.sh both scan all three mandatory fixtures unconditionally (no `if` guarding the encrypted-pdf check)", () => {
  for (const fname of ["verify-candidate-container.sh", "verify-deployed-candidate.sh"]) {
    const text = scriptText(fname);
    assert.ok(text.includes('scan_fixture "benign-text" "FIXTURE_BENIGN_TEXT" "clean"'));
    assert.ok(text.includes('scan_fixture "eicar-standard" "FIXTURE_EICAR_STANDARD" "infected"'));
    assert.ok(text.includes('scan_fixture "encrypted-pdf" "FIXTURE_ENCRYPTED_PDF" "error" "encrypted_document_unsupported"'));
    // The old bug's signature: a conditional existence check guarding
    // the encrypted-fixture scan. Must not reappear.
    assert.ok(!/if gcloud storage objects describe[\s\S]*encrypted/i.test(text), `${fname} must not conditionally skip the encrypted fixture`);
    assert.ok(!/WARNING:.*SKIPPED/i.test(text), `${fname} must not contain the old warn-and-skip message`);
  }
});

test("verify-fixtures.sh's node invocation exits non-zero on any integrity failure (no `|| true` swallowing it)", () => {
  const text = scriptText("verify-fixtures.sh");
  assert.ok(!/fixtureManifest\.js[^\n]*\|\|\s*true/.test(text));
});

// ---------------------------------------------------------------------
// Candidate network correction (Slice 2.2, closing a real staging build
// failure — build eb02b226-1f41-4029-a748-1a7d69810a4b, step
// verify-candidate-container: "candidate container never became
// healthy"). Root cause: 127.0.0.1 inside the step container that runs
// this script never reliably reached a -p-published port on the
// candidate, a SIBLING container under Cloud Build's nested-Docker
// model. Fix: run the candidate on Cloud Build's predefined `cloudbuild`
// network and address it only by container name. These tests inspect
// the ACTUAL script content, never a hand-duplicated imaginary version.
// ---------------------------------------------------------------------

test("candidate network: docker run attaches the candidate to --network=cloudbuild, a fixed literal, never a substitution", () => {
  const text = scriptText("verify-candidate-container.sh");
  assert.ok(/CLOUDBUILD_NETWORK="cloudbuild"/.test(text), "the network name must be the fixed literal \"cloudbuild\"");
  const runBlockMatch = text.match(/docker run -d --name[\s\S]*?"\$IMAGE_LOCAL"/);
  assert.ok(runBlockMatch, "could not locate the candidate's docker run invocation");
  assert.ok(/--network="\$CLOUDBUILD_NETWORK"/.test(runBlockMatch[0]), "docker run must attach the candidate via --network=\"$CLOUDBUILD_NETWORK\"");
});

test("candidate network: docker run never uses --network=host anywhere in the file", () => {
  const text = scriptText("verify-candidate-container.sh");
  assert.ok(!/--network[= ]host\b/.test(text), "must never use --network=host");
});

test("candidate network: the candidate has an explicit, Docker-safe --name derived from a sanitized BUILD_ID, unique per build", () => {
  const text = scriptText("verify-candidate-container.sh");
  assert.ok(/SAFE_BUILD_ID=\$\(printf '%s' "\$BUILD_ID" \| tr -c 'a-zA-Z0-9_\.-' '-'\)/.test(text), "BUILD_ID must be sanitized to Docker's safe container-name character class before use");
  assert.ok(/CONTAINER_NAME="verify-candidate-\$\{SAFE_BUILD_ID\}"/.test(text), "the container name must be built from the sanitized value, unique per build");
  const runBlockMatch = text.match(/docker run -d --name[\s\S]*?"\$IMAGE_LOCAL"/);
  assert.ok(runBlockMatch, "could not locate the candidate's docker run invocation");
  assert.ok(/--name "\$CONTAINER_NAME"/.test(runBlockMatch[0]), "docker run must pass --name \"$CONTAINER_NAME\" explicitly");
});

test("candidate network: no -p host-port publishing remains on any executable line — specifically no 18080, and no generic -p NUM:NUM flag at all (the correction's own comment legitimately quotes the old \"-p 18080:8080\" for documentation)", () => {
  const text = scriptText("verify-candidate-container.sh");
  const execLines = nonCommentLines(text);
  assert.ok(!execLines.some((l) => l.includes("18080")), "the old host-published port must not remain on any real command line");
  assert.ok(!execLines.some((l) => /(^|\s)-p\s+\d+:\d+/.test(l)), "no docker run invocation may publish a host port");
});

test("candidate network: the internal port is 8080, and CANDIDATE_BASE_URL is the single place the candidate's address is constructed", () => {
  const text = scriptText("verify-candidate-container.sh");
  assert.ok(/CANDIDATE_BASE_URL="http:\/\/\$\{CONTAINER_NAME\}:8080"/.test(text), "CANDIDATE_BASE_URL must be built from the container name and internal port 8080, in exactly one place");
  const assignments = text.match(/CANDIDATE_BASE_URL=/g) || [];
  assert.equal(assignments.length, 1, "CANDIDATE_BASE_URL must be assigned exactly once — no per-request drift");
});

test("candidate network: no localhost/127.0.0.1/host.docker.internal URL is ever actually constructed or requested over the network by the verifier (the diagnostic in-container `docker exec ... 127.0.0.1` probe, which runs INSIDE the candidate's own namespace rather than over the network, is explicitly excluded; English prose — comments and echoed diagnostic messages that merely mention \"localhost\" while explaining behavior — is not a URL construction and is excluded too)", () => {
  const text = scriptText("verify-candidate-container.sh");
  // Only real, non-comment lines that actually build a URL (an http://
  // literal) or invoke curl/wget are real address-construction sites;
  // prose (comments, including ones quoting a URL for documentation
  // purposes, and echoed human-readable diagnostic strings) merely
  // mentioning the word "localhost" while explaining behavior is not.
  const addressConstructionPattern = /https?:\/\/|curl\b|wget\b/;
  const forbiddenHostPattern = /127\.0\.0\.1|localhost|host\.docker\.internal/;
  for (const line of nonCommentLines(text)) {
    if (!forbiddenHostPattern.test(line)) continue;
    if (!addressConstructionPattern.test(line)) continue; // prose, not a request
    const isInContainerExecProbe = line.includes("docker exec");
    assert.ok(
      isInContainerExecProbe,
      `a real address-construction line referencing a forbidden host must only be the documented in-container docker-exec probe, found: ${line}`
    );
  }
});

test("candidate network: every real HTTP request the verifier sends (healthz, status, and every fixture scan) targets ${CANDIDATE_BASE_URL}, never a separately constructed address", () => {
  const text = scriptText("verify-candidate-container.sh");
  // Join backslash-continued lines first — the scan request's curl
  // invocation wraps its flags across two physical lines, and
  // ${CANDIDATE_BASE_URL} only appears on the continuation line.
  const lines = text.split("\n");
  const joinedLines = [];
  for (let i = 0; i < lines.length; i++) {
    let block = lines[i];
    let j = i;
    while (block.trimEnd().endsWith("\\") && j + 1 < lines.length) {
      j += 1;
      block += "\n" + lines[j];
    }
    joinedLines.push(block);
    i = j;
  }
  const requestLines = joinedLines.filter((l) => /curl\b/.test(l) && !l.trim().startsWith("#") && !l.includes("-v -s -o /dev/null -m 5"));
  // Sanity: at least the four real requests (healthz, status, and — via
  // the shared scan_fixture() body — the scan endpoint) must exist.
  assert.ok(requestLines.length >= 3, `expected at least 3 real request lines, found ${requestLines.length}`);
  for (const line of requestLines) {
    assert.ok(line.includes("${CANDIDATE_BASE_URL}"), `every real request must target \${CANDIDATE_BASE_URL}: ${line}`);
  }
});

test("candidate network: a missing cloudbuild network fails closed with a precise diagnostic before any candidate container is created — never falls back silently", () => {
  const text = scriptText("verify-candidate-container.sh");
  const checkMatch = text.match(/if ! docker network inspect "\$CLOUDBUILD_NETWORK"[\s\S]*?fi\n/);
  assert.ok(checkMatch, "could not locate the network-existence fail-closed check");
  assert.ok(/exit 1/.test(checkMatch[0]), "a missing network must exit 1");
  assert.ok(/does not exist/i.test(checkMatch[0]), "the diagnostic message must clearly state the network is missing");
  assert.ok(/refusing to fall back/i.test(checkMatch[0]), "the diagnostic must state no fallback is attempted");
  // This check must appear textually before the candidate's docker run
  // invocation — no container may be created before the network is
  // confirmed to exist.
  const checkIndex = text.indexOf(checkMatch[0]);
  const runIndex = text.indexOf("docker run -d --name");
  assert.ok(checkIndex !== -1 && runIndex !== -1 && checkIndex < runIndex, "the network-existence check must run before the candidate container is created");
});

test("candidate cleanup: the trap removes ONLY the exact named candidate container — never a broader match, never an image, on every exit path including signals", () => {
  const text = scriptText("verify-candidate-container.sh");
  assert.ok(/trap cleanup EXIT INT TERM/.test(text), "cleanup must be trapped on EXIT, INT, and TERM");
  const cleanupFnMatch = text.match(/cleanup\(\) \{[\s\S]*?\n\}/);
  assert.ok(cleanupFnMatch, "could not locate the cleanup() function body");
  assert.ok(/docker rm -f "\$CONTAINER_NAME"/.test(cleanupFnMatch[0]), "cleanup must remove exactly $CONTAINER_NAME, the exact named candidate — not a wildcard or prefix match");
  assert.ok(!/docker rm -f \$\(docker ps/.test(cleanupFnMatch[0]), "cleanup must never derive its target from a broader docker ps query");
  assert.ok(!/docker rmi/.test(cleanupFnMatch[0]), "cleanup must never delete an image");
});

test("candidate diagnostics: the final verbose connectivity probe filters out Authorization headers, Bearer tokens, and cookies before being logged, and never prints a response body", () => {
  const text = scriptText("verify-candidate-container.sh");
  const diagFnMatch = text.match(/dump_candidate_diagnostics\(\) \{[\s\S]*?\n\}/);
  assert.ok(diagFnMatch, "could not locate the dump_candidate_diagnostics() function body");
  assert.ok(/grep -viE 'Authorization:\|Bearer \|set-cookie:'/.test(diagFnMatch[0]), "the verbose curl diagnostic must filter Authorization/Bearer/set-cookie lines");
  assert.ok(/-o \/dev\/null/.test(diagFnMatch[0]), "the diagnostic curl call must discard the response body (-o /dev/null)");
  // The in-container reachability probe must report only its exit
  // status, never print the response body.
  const probeMatch = diagFnMatch[0].match(/docker exec "\$CONTAINER_NAME" wget[\s\S]*?fi/);
  assert.ok(probeMatch, "could not locate the in-container reachability probe");
  assert.ok(/-O \/dev\/null/.test(probeMatch[0]), "the in-container wget probe must discard its response body (-O /dev/null)");
});

test("candidate diagnostics: per-attempt healthz diagnostics are compact (attempt number, curl exit code, HTTP status, derived category) and never include a response body", () => {
  const text = scriptText("verify-candidate-container.sh");
  const echoLineMatch = text.match(/echo "verify-candidate-container: healthz attempt[^\n]*"/);
  assert.ok(echoLineMatch, "could not locate the per-attempt diagnostic echo line");
  const line = echoLineMatch[0];
  assert.ok(line.includes("attempt"), "must include the attempt number");
  assert.ok(line.includes("curl_exit"), "must include curl's own exit code");
  assert.ok(line.includes("http_status"), "must include the HTTP status when available");
  assert.ok(!/healthz\.json/.test(line), "the per-attempt diagnostic must never include the response body file");
});

test("candidate network: every loop in the script is explicitly bounded — the healthz wait loop iterates a fixed 30 times, and the server_started log-visibility retry iterates a fixed 3 times — neither is unbounded, and neither was widened as a way to paper over the network defect", () => {
  const text = scriptText("verify-candidate-container.sh");
  assert.ok(/for _ in \$\(seq 1 30\); do/.test(text), "the healthz wait loop must remain bounded to exactly 30 attempts");
  assert.ok(/for _ in 1 2 3; do/.test(text), "the server_started retry loop must remain bounded to exactly 3 attempts");
  // Sanity: no unbounded `while true`/`while :` loop exists anywhere.
  assert.ok(!/while (true|:)/.test(text), "no unbounded loop may exist in this script");
});

test("candidate network: every fixture verdict check remains mandatory, unaffected by the network correction (regression guard on the pre-existing Mandatory correction 1 test above)", () => {
  const text = scriptText("verify-candidate-container.sh");
  assert.ok(text.includes('scan_fixture "benign-text" "FIXTURE_BENIGN_TEXT" "clean"'));
  assert.ok(text.includes('scan_fixture "eicar-standard" "FIXTURE_EICAR_STANDARD" "infected"'));
  assert.ok(text.includes('scan_fixture "encrypted-pdf" "FIXTURE_ENCRYPTED_PDF" "error" "encrypted_document_unsupported"'));
});

// ---------------------------------------------------------------------
// scan_fixture() diagnostic correction (Slice 2.2, closing a real
// staging build failure — build bcf1e1fa-28a2-42d4-a910-651e873bf4ac,
// fixture "benign-text": a real HTTP 400 invalid_object_path response
// from the candidate was silently swallowed because
// `result=$(curl -fs ...)` failing under `set -e` aborted the script
// before the MANDATORY FIXTURE FAILED diagnostic could ever print).
// Root cause was a real fixture-path/production-validation shape
// mismatch (fixed separately, out of this file's scope, by
// re-provisioning the staging fixtures under the production-compatible
// three-segment path — see contract.js's own isSafeQuarantineObjectPath
// tests below), not a defect in this script; this section closes the
// SEPARATE diagnostic-visibility gap the real failure exposed.
// ---------------------------------------------------------------------

test("scan_fixture diagnostic fix: the scan request's exit code and HTTP status are captured explicitly (set +e/-e bracketing around the curl call), not left to mask a failure under set -e — the exact class of bug that swallowed the real staging failure in build bcf1e1fa-28a2-42d4-a910-651e873bf4ac", () => {
  const text = scriptText("verify-candidate-container.sh");
  const fnMatch = text.match(/scan_fixture\(\) \{[\s\S]*?\n\}/);
  assert.ok(fnMatch, "could not locate the scan_fixture() function body");
  const body = fnMatch[0];
  assert.ok(/ {2}set \+e\n {2}scan_http_code=\$\(curl/.test(body), "the scan curl call must be bracketed by set +e immediately before it");
  assert.ok(/scan_curl_exit=\$\?/.test(body), "the scan curl call's own exit code must be captured explicitly via $?");
  assert.ok(/ {2}scan_curl_exit=\$\?\n {2}set -e/.test(body), "set -e must be restored immediately after capturing the exit code");
  assert.ok(/set -e\n\n {2}if \[ "\$scan_curl_exit" -ne 0 \]/.test(body), "the failure branch must be checked right after set -e is restored");
});

test("scan_fixture diagnostic fix: a failed scan request (non-zero curl exit OR non-200 HTTP status) is never silently swallowed — it prints a bounded diagnostic (fixture id, curl exit code, HTTP status, and a safely-extracted classification) and exits non-zero, exactly like every other mandatory-fixture failure path", () => {
  const text = scriptText("verify-candidate-container.sh");
  const fnMatch = text.match(/scan_fixture\(\) \{[\s\S]*?\n\}/);
  assert.ok(fnMatch, "could not locate the scan_fixture() function body");
  const body = fnMatch[0];
  assert.ok(/if \[ "\$scan_curl_exit" -ne 0 \] \|\| \[ "\$scan_http_code" != "200" \]; then/.test(body), "must branch on either a non-zero curl exit or a non-200 HTTP status");
  const failureBranchMatch = body.match(/if \[ "\$scan_curl_exit" -ne 0 \][\s\S]*?\n {2}fi\n/);
  assert.ok(failureBranchMatch, "could not locate the scan-request failure branch");
  assert.ok(/MANDATORY FIXTURE FAILED \(\$\{fixture_id\}\)/.test(failureBranchMatch[0]), "the failure diagnostic must identify the fixture by id");
  assert.ok(/curl_exit=\$\{scan_curl_exit\}/.test(failureBranchMatch[0]), "the diagnostic must include the captured curl exit code");
  assert.ok(/http_status=\$\{scan_http_code:-none\}/.test(failureBranchMatch[0]), "the diagnostic must include the captured HTTP status");
  assert.ok(/exit 1/.test(failureBranchMatch[0]), "a failed scan request must exit non-zero, never continue to the verdict check");
});

test("scan_fixture diagnostic fix: the failure-path diagnostic never prints the raw response body — only a narrow, safely-extracted classification (error/reason/errorCode, the same closed field set RESPONSE_ALLOWED_KEYS documents), and never prints the request body, an Authorization header, or any credential", () => {
  const text = scriptText("verify-candidate-container.sh");
  const fnMatch = text.match(/scan_fixture\(\) \{[\s\S]*?\n\}/);
  assert.ok(fnMatch, "could not locate the scan_fixture() function body");
  const body = fnMatch[0];
  const failureBranchMatch = body.match(/if \[ "\$scan_curl_exit" -ne 0 \][\s\S]*?\n {2}fi\n/);
  assert.ok(failureBranchMatch, "could not locate the scan-request failure branch");
  assert.ok(/grep -oE '"\(error\|reason\|errorCode\)":"\[\^"\]\*"'/.test(failureBranchMatch[0]), "must extract only the error/reason/errorCode fields, never the body verbatim");
  assert.ok(!/cat \/tmp\/scan-fixture-response\.json/.test(failureBranchMatch[0]), "the failure branch must never cat the raw response body");
  // Restrict the Authorization/Bearer check to the actual EXECUTABLE
  // diagnostic line, not the surrounding prose comments (which
  // legitimately explain, in English, that no such header is ever
  // sent — a comment mentioning the word is not a leak).
  const echoLineMatch = failureBranchMatch[0].match(/echo "MANDATORY FIXTURE FAILED[^\n]*"/);
  assert.ok(echoLineMatch, "could not locate the failure diagnostic echo line");
  assert.ok(!/Authorization|Bearer/.test(echoLineMatch[0]), "the failure diagnostic's actual printed message must never reference an Authorization header or bearer token — this script sends none");
});

test("scan_fixture diagnostic fix: on success (HTTP 200), the response body is read from the same file the status code was captured from — no separate, potentially-inconsistent second request", () => {
  const text = scriptText("verify-candidate-container.sh");
  const fnMatch = text.match(/scan_fixture\(\) \{[\s\S]*?\n\}/);
  assert.ok(fnMatch, "could not locate the scan_fixture() function body");
  assert.ok(/result="\$\(cat \/tmp\/scan-fixture-response\.json\)"/.test(fnMatch[0]), "the success-path result must be read from the captured response file, not re-fetched");
});

// ---------------------------------------------------------------------
// Fixture-path/production-validation contract (Slice 2.2, closing the
// real staging root cause: the previously-provisioned staging fixture
// paths had only two segments after compliance_quarantine/, while
// src/contract.js's isSafeQuarantineObjectPath requires exactly three,
// mirroring the production {businessId}/{sessionId}/{objectId} shape).
// These tests invoke the REAL, unmodified production validator
// directly — proving no relaxation was introduced anywhere, and that
// the newly-provisioned three-segment staging paths are exactly what
// it already required, not a new allowance carved out for them.
// ---------------------------------------------------------------------

test("production validation unchanged: isSafeQuarantineObjectPath still requires EXACTLY three segments after compliance_quarantine/ — no relaxation, no CI-specific exception, invoked directly against the real, unmodified src/contract.js", () => {
  const { isSafeQuarantineObjectPath } = require(path.join(REPO_ROOT, "src", "contract.js"));

  // The newly-provisioned, production-compatible staging paths must
  // pass — this is the actual fix (fixture re-provisioning), not a
  // validator change.
  assert.equal(isSafeQuarantineObjectPath("compliance_quarantine/ci-fixtures/ci-run/benign.txt"), true);
  assert.equal(isSafeQuarantineObjectPath("compliance_quarantine/ci-fixtures/ci-run/eicar.txt"), true);
  assert.equal(isSafeQuarantineObjectPath("compliance_quarantine/ci-fixtures/ci-run/encrypted.pdf"), true);

  // The OLD, broken two-segment staging paths (the real root cause of
  // build bcf1e1fa's failure) must still be rejected — proving no
  // two-segment CI exception was carved into production validation as
  // an alternative fix.
  assert.equal(isSafeQuarantineObjectPath("compliance_quarantine/ci-fixtures/benign.txt"), false);
  assert.equal(isSafeQuarantineObjectPath("compliance_quarantine/ci-fixtures/eicar.txt"), false);
  assert.equal(isSafeQuarantineObjectPath("compliance_quarantine/ci-fixtures/encrypted.pdf"), false);

  // A four-segment path must also still be rejected — the requirement
  // is EXACTLY three, not "at least three" or "at most three".
  assert.equal(isSafeQuarantineObjectPath("compliance_quarantine/a/b/c/d.txt"), false);
});

test("production validation unchanged: src/contract.js's isSafeQuarantineObjectPath source still contains the exact `parts.length !== 3` shape check — a textual regression guard alongside the behavioral one above", () => {
  const contractText = fs.readFileSync(path.join(REPO_ROOT, "src", "contract.js"), "utf8");
  assert.ok(/parts\.length !== 3/.test(contractText), "the three-segment shape requirement must remain exactly as written, unweakened");
  assert.ok(!/ci-fixtures/.test(contractText), "production validation code must never special-case a CI-only path fragment");
});

// ---------------------------------------------------------------------
// ID-token audience correctness (Slice 2.2 final correction). Per
// https://docs.cloud.google.com/run/docs/authenticating/service-to-service:
// "the aud value must remain as the URL of the service, even when
// making requests to a specific traffic tag." CANDIDATE_URL is the
// HTTP request target; BASE_SERVICE_URL is the token audience — two
// separate variables, neither derived from the other.
// ---------------------------------------------------------------------

test("verify-deployed-candidate.sh declares CANDIDATE_URL and BASE_SERVICE_URL as two separately-sourced variables — CANDIDATE_URL from the resolved candidate traffic entry (Slice 2.2 correction: ci/resolveCandidateTrafficEntry.js, not a raw gcloud --format expression), BASE_SERVICE_URL from its own independent gcloud describe call", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  assert.ok(/CANDIDATE_URL=\$\(printf '%s\\n' "\$CANDIDATE_TRAFFIC_RESOLVED" \| sed -n '1p'\)/.test(text), "CANDIDATE_URL must be read from line 1 of the resolved-traffic-entry output");
  assert.ok(/BASE_SERVICE_URL=\$\(gcloud run services describe/.test(text));
  // Must not be textually derived from each other (e.g. string
  // substitution/sed on one to produce the other).
  assert.ok(!/BASE_SERVICE_URL=.*CANDIDATE_URL/.test(text), "BASE_SERVICE_URL must not be derived from CANDIDATE_URL");
  assert.ok(!/CANDIDATE_URL=.*BASE_SERVICE_URL/.test(text), "CANDIDATE_URL must not be derived from BASE_SERVICE_URL");
});

test("BASE_SERVICE_URL is read from status.url (Cloud Run's own base/default service URL field), never from a tag-filtered traffic entry", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  const baseUrlLineMatch = text.match(/BASE_SERVICE_URL=\$\(gcloud run services describe[\s\S]*?\)\n/);
  assert.ok(baseUrlLineMatch, "could not locate the BASE_SERVICE_URL assignment block");
  assert.ok(baseUrlLineMatch[0].includes("--format=\"value(status.url)\""), "BASE_SERVICE_URL must come from plain status.url");
  assert.ok(!baseUrlLineMatch[0].includes("tag=="), "BASE_SERVICE_URL's own query must not filter by tag");
});

test("the --audiences flag is set to \\${BASE_SERVICE_URL}, never \\${CANDIDATE_URL} — the tagged URL is never used as audience", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  const audienceMatches = text.match(/--audiences="\$\{[A-Z_]+\}"/g) || [];
  assert.ok(audienceMatches.length > 0, "sanity: at least one --audiences flag should exist");
  for (const m of audienceMatches) {
    assert.ok(m.includes("BASE_SERVICE_URL"), `--audiences must reference BASE_SERVICE_URL, found: ${m}`);
    assert.ok(!m.includes("CANDIDATE_URL"), `--audiences must never reference CANDIDATE_URL, found: ${m}`);
  }
});

test("every HTTP request (curl ... /status or /v1/scan, possibly wrapped across lines) targets CANDIDATE_URL, never BASE_SERVICE_URL — the base URL is never accidentally used as the candidate request target", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  const lines = text.split("\n");
  const curlBlocks = [];
  for (let i = 0; i < lines.length; i++) {
    if (!lines[i].includes("curl")) continue;
    let block = lines[i];
    let j = i;
    while (block.trim().endsWith("\\") && j + 1 < lines.length) {
      j += 1;
      block += "\n" + lines[j];
    }
    if (block.includes("/status") || block.includes("/v1/scan")) curlBlocks.push(block);
  }
  assert.ok(curlBlocks.length > 0, "sanity: at least one curl request block should exist");
  for (const block of curlBlocks) {
    assert.ok(block.includes("${CANDIDATE_URL}"), `HTTP request must target \${CANDIDATE_URL}:\n${block}`);
    assert.ok(!block.includes("${BASE_SERVICE_URL}"), `HTTP request must never target \${BASE_SERVICE_URL}:\n${block}`);
  }
});

test("CANDIDATE_URL, CANDIDATE_REVISION, and BASE_SERVICE_URL all fail closed (explicit non-empty check + exit) if resolution produces empty", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  assert.ok(/\[ -n "\$CANDIDATE_URL" \] \|\| \{ echo[^}]*exit 1; \}/.test(text), "CANDIDATE_URL must fail closed if empty");
  assert.ok(/\[ -n "\$CANDIDATE_REVISION" \] \|\| \{ echo[^}]*exit 1; \}/.test(text), "CANDIDATE_REVISION must fail closed if empty (Slice 2.2 correction — previously had no such check at all)");
  assert.ok(/\[ -n "\$BASE_SERVICE_URL" \] \|\| \{ echo[^}]*exit 1; \}/.test(text), "BASE_SERVICE_URL must fail closed if empty");
});

// ---------------------------------------------------------------------
// Candidate traffic-entry resolution correction (Slice 2.2, closing a
// real staging failure — build aa407156-0dea-4ed0-9e85-47354d3bbf3e,
// step verify-deployed-candidate: "could not resolve candidate tag
// URL"). Root cause: gcloud's --format resource-key language does not
// support the JMESPath-style embedded predicate
// `status.traffic[?tag=='...']` this step's two gcloud describe calls
// previously used — confirmed empirically (live, read-only) against
// the real deployed candidate, whose matching entry genuinely existed
// and was trivially resolvable via a plain JSON read.
//
// SECOND correction layered on top (build ea9bad30-d2e2-4aa1-9fdb-a765bde94372,
// step verify-source: "spawnSync git ENOENT" / python3 spawn
// failures): the original fix was a single Python helper,
// ci/resolveCandidateTrafficEntry.py, spawned by BOTH shell consumers.
// That broke verify-source, which runs `node --test test/ ci/*.test.js`
// — i.e. THIS FILE — on node:20.18.1-bookworm-slim, a minimal image
// with node but neither python3 nor git; every test here that spawned
// python3 failed with a null exit status (ENOENT), not a resolver
// logic failure. The fix at that point kept TWO independently-
// maintained resolver implementations: a canonical .js file (used by
// promote.sh, whose ci-builder image had node) and an UNCHANGED .py
// port (used by verify-deployed-candidate.sh, whose plain cloud-sdk
// image had python3 but not node, confirmed via local Docker
// inspection of that exact digest-pinned image).
//
// THIRD correction (this one — single-authoritative-resolver
// correction): that two-implementation split was accepted at the time
// as the only way to keep every consumer running on an image that
// actually had the interpreter it needed, but it left a real
// semantic-drift risk in place — two independently-maintained
// implementations of the same fail-closed security check (exactly-
// one-match, HTTPS-only, control-character rejection, Cloud Run
// revision-name shape), with nothing proving they stayed in sync if
// either was edited alone. Rather than accept that risk indefinitely,
// verify-deployed-candidate.sh was moved onto the SAME ci-builder
// image push-candidate.sh/deploy-candidate.sh/promote.sh already use
// (confirmed via local Docker inspection to already contain
// gcloud/curl/sha256sum — because ci-builder's own base IS the
// identical cloud-sdk image this step used before — plus node, added
// on top; no new image was built or published), and
// ci/resolveCandidateTrafficEntry.py was DELETED. Exactly one resolver
// implementation exists now:
//   - ci/resolveCandidateTrafficEntry.js — canonical, and the ONLY
//     candidate-traffic resolver in this repository. Fully
//     BEHAVIORALLY tested below via process.execPath (the exact Node
//     binary running this test suite — always present, can never
//     ENOENT). Invoked identically by BOTH verify-deployed-candidate.sh
//     and promote.sh, and directly required here for pure-function-
//     level tests.
// ---------------------------------------------------------------------

const JS_RESOLVE_MODULE_PATH = path.join(REPO_ROOT, "ci", "resolveCandidateTrafficEntry.js");
const { resolveCandidateTrafficEntry } = require(JS_RESOLVE_MODULE_PATH);

// Behavioral CLI test: spawns the ACTUAL Node binary running this test
// suite (process.execPath, never the bare string "node" — this can
// never ENOENT, by construction, since it IS the interpreter currently
// executing) against the real .js file's CLI entrypoint, exercising
// stdin reading, environment-variable reading, exit codes, and
// stdout/stderr framing exactly as the shell scripts invoke it — not
// merely the exported pure function.
function runResolveCandidateTrafficEntry({ trafficJson, tag }) {
  return spawnSync(process.execPath, [JS_RESOLVE_MODULE_PATH], {
    input: trafficJson,
    env: { ...process.env, CANDIDATE_TRAFFIC_TAG: tag },
    encoding: "utf8",
  });
}

// The exact traffic array captured live from the real deployed
// candidate in build aa407156-0dea-4ed0-9e85-47354d3bbf3e.
const REAL_CAPTURED_TRAFFIC_JSON = JSON.stringify({
  status: {
    traffic: [
      { percent: 100, revisionName: "compliance-scanner-00002-h9h" },
      {
        revisionName: "compliance-scanner-00003-wof",
        tag: "candidate-580e47e8-aa407156",
        url: "https://candidate-580e47e8-aa407156---compliance-scanner-k2hhuwvftq-ew.a.run.app",
      },
    ],
  },
});

test("resolveCandidateTrafficEntry.js (spawned via process.execPath): the REAL captured traffic structure from build aa407156 resolves the exact expected tag, URL, and revision", () => {
  const result = runResolveCandidateTrafficEntry({ trafficJson: REAL_CAPTURED_TRAFFIC_JSON, tag: "candidate-580e47e8-aa407156" });
  assert.equal(result.status, 0, `expected success, stderr: ${result.stderr}`);
  const [url, revisionName] = result.stdout.trim().split("\n");
  assert.equal(url, "https://candidate-580e47e8-aa407156---compliance-scanner-k2hhuwvftq-ew.a.run.app");
  assert.ok(url.endsWith(".a.run.app"), "URL must end in .a.run.app");
  assert.equal(revisionName, "compliance-scanner-00003-wof");
});

test("resolveCandidateTrafficEntry.js: stdout is EXACTLY two lines on success (url, then revisionName) — nothing else, no trailing blank lines, no logging noise", () => {
  const result = runResolveCandidateTrafficEntry({ trafficJson: REAL_CAPTURED_TRAFFIC_JSON, tag: "candidate-580e47e8-aa407156" });
  assert.equal(result.status, 0);
  const lines = result.stdout.split("\n");
  assert.equal(lines.length, 3, `expected exactly 2 content lines + trailing newline, got: ${JSON.stringify(result.stdout)}`);
  assert.equal(lines[2], "", "stdout must end with a single trailing newline, no extra content");
  assert.equal(result.stderr, "", "nothing may be printed to stderr on success");
});

test("resolveCandidateTrafficEntry.js: every failure path prints its diagnostic to stderr ONLY — stdout stays empty", () => {
  const result = runResolveCandidateTrafficEntry({ trafficJson: REAL_CAPTURED_TRAFFIC_JSON, tag: "candidate-does-not-exist-00000000" });
  assert.notEqual(result.status, 0);
  assert.equal(result.stdout, "", "stdout must stay empty on failure");
  assert.ok(result.stderr.length > 0, "a diagnostic must be printed to stderr");
});

test("resolveCandidateTrafficEntry.js: the 100%-traffic untagged baseline entry is never selected, even when it is the only entry present (no fallback)", () => {
  const onlyBaseline = JSON.stringify({ status: { traffic: [{ percent: 100, revisionName: "compliance-scanner-00002-h9h" }] } });
  const result = runResolveCandidateTrafficEntry({ trafficJson: onlyBaseline, tag: "candidate-580e47e8-aa407156" });
  assert.notEqual(result.status, 0, "must fail rather than silently fall back to the untagged baseline entry");
  assert.equal(result.stdout, "", "no output may be printed on failure");
});

test("resolveCandidateTrafficEntry.js: a previously-deployed, now-stale zero-percent candidate (a different tag) is never selected for a NEW candidate's tag", () => {
  const staleAndNew = JSON.stringify({
    status: {
      traffic: [
        { percent: 100, revisionName: "compliance-scanner-00002-h9h" },
        { revisionName: "compliance-scanner-00003-wof", tag: "candidate-580e47e8-aa407156", url: "https://old.a.run.app" },
      ],
    },
  });
  const result = runResolveCandidateTrafficEntry({ trafficJson: staleAndNew, tag: "candidate-93b0e305-newbuild1" });
  assert.notEqual(result.status, 0, "must fail rather than silently select an old candidate with a different tag");
  assert.ok(result.stderr.includes("no traffic entry has tag"), `expected a no-match diagnostic, got: ${result.stderr}`);
});

test("resolveCandidateTrafficEntry.js: no matching tag fails closed with a clear diagnostic", () => {
  const result = runResolveCandidateTrafficEntry({ trafficJson: REAL_CAPTURED_TRAFFIC_JSON, tag: "candidate-does-not-exist-00000000" });
  assert.notEqual(result.status, 0);
  assert.ok(result.stderr.includes("no traffic entry has tag"), `expected a no-match diagnostic, got: ${result.stderr}`);
});

test("resolveCandidateTrafficEntry.js: duplicate matching tags fail closed rather than picking either one arbitrarily", () => {
  const duplicateTag = JSON.stringify({
    status: {
      traffic: [
        { revisionName: "compliance-scanner-00003-wof", tag: "candidate-dup", url: "https://a.a.run.app" },
        { revisionName: "compliance-scanner-00004-xyz", tag: "candidate-dup", url: "https://b.a.run.app" },
      ],
    },
  });
  const result = runResolveCandidateTrafficEntry({ trafficJson: duplicateTag, tag: "candidate-dup" });
  assert.notEqual(result.status, 0);
  assert.ok(result.stderr.includes("2 traffic entries"), `expected a duplicate-match diagnostic, got: ${result.stderr}`);
});

test("resolveCandidateTrafficEntry.js: a matched entry with a missing or empty url fails closed", () => {
  for (const badUrl of [undefined, ""]) {
    const entry = { revisionName: "compliance-scanner-00003-wof", tag: "candidate-x" };
    if (badUrl !== undefined) entry.url = badUrl;
    const trafficJson = JSON.stringify({ status: { traffic: [entry] } });
    const result = runResolveCandidateTrafficEntry({ trafficJson, tag: "candidate-x" });
    assert.notEqual(result.status, 0, `expected failure for url=${JSON.stringify(badUrl)}`);
    assert.ok(result.stderr.includes("url"), `expected a url-specific diagnostic, got: ${result.stderr}`);
  }
});

test("resolveCandidateTrafficEntry.js: a matched entry with a missing or empty revisionName fails closed", () => {
  for (const badRevision of [undefined, ""]) {
    const entry = { tag: "candidate-x", url: "https://x.a.run.app" };
    if (badRevision !== undefined) entry.revisionName = badRevision;
    const trafficJson = JSON.stringify({ status: { traffic: [entry] } });
    const result = runResolveCandidateTrafficEntry({ trafficJson, tag: "candidate-x" });
    assert.notEqual(result.status, 0, `expected failure for revisionName=${JSON.stringify(badRevision)}`);
    assert.ok(result.stderr.includes("revisionName"), `expected a revisionName-specific diagnostic, got: ${result.stderr}`);
  }
});

test("resolveCandidateTrafficEntry.js: malformed JSON on stdin fails closed", () => {
  const result = runResolveCandidateTrafficEntry({ trafficJson: "{not valid json", tag: "candidate-x" });
  assert.notEqual(result.status, 0);
  assert.ok(result.stderr.includes("not valid JSON"), `expected a JSON-parse diagnostic, got: ${result.stderr}`);
});

test("resolveCandidateTrafficEntry.js: absent or non-array status.traffic fails closed", () => {
  for (const badTraffic of [
    JSON.stringify({ status: {} }),
    JSON.stringify({ status: { traffic: "not-an-array" } }),
    JSON.stringify({ status: { traffic: { tag: "x" } } }),
    JSON.stringify({}),
  ]) {
    const result = runResolveCandidateTrafficEntry({ trafficJson: badTraffic, tag: "candidate-x" });
    assert.notEqual(result.status, 0, `expected failure for traffic JSON: ${badTraffic}`);
  }
});

test("resolveCandidateTrafficEntry.js: a non-HTTPS (e.g. plain http) URL fails closed", () => {
  const trafficJson = JSON.stringify({ status: { traffic: [{ tag: "candidate-x", revisionName: "compliance-scanner-00003-wof", url: "http://insecure.a.run.app" }] } });
  const result = runResolveCandidateTrafficEntry({ trafficJson, tag: "candidate-x" });
  assert.notEqual(result.status, 0);
  assert.ok(result.stderr.includes("HTTPS"), `expected an HTTPS-specific diagnostic, got: ${result.stderr}`);
});

test("resolveCandidateTrafficEntry.js: a URL containing whitespace or a control character fails closed", () => {
  for (const badUrl of ["https://evil.a.run.app extra-arg", "https://evil.a.run.app\nInjected-Header: x", "https://evil.a.run.app\t"]) {
    const trafficJson = JSON.stringify({ status: { traffic: [{ tag: "candidate-x", revisionName: "compliance-scanner-00003-wof", url: badUrl }] } });
    const result = runResolveCandidateTrafficEntry({ trafficJson, tag: "candidate-x" });
    assert.notEqual(result.status, 0, `expected failure for url=${JSON.stringify(badUrl)}`);
    assert.ok(result.stderr.includes("whitespace or control"), `expected a whitespace/control-character diagnostic, got: ${result.stderr}`);
  }
});

test("resolveCandidateTrafficEntry.js: a malformed (non-Cloud-Run-safe) revision name fails closed", () => {
  for (const badRevision of ["UPPERCASE-not-allowed", "-starts-with-hyphen", "ends-with-hyphen-", "has spaces", "has_underscore", "semi;colon"]) {
    const trafficJson = JSON.stringify({ status: { traffic: [{ tag: "candidate-x", revisionName: badRevision, url: "https://x.a.run.app" }] } });
    const result = runResolveCandidateTrafficEntry({ trafficJson, tag: "candidate-x" });
    assert.notEqual(result.status, 0, `expected failure for revisionName=${JSON.stringify(badRevision)}`);
    assert.ok(result.stderr.includes("Cloud Run-safe shape"), `expected a shape-specific diagnostic, got: ${result.stderr}`);
  }
});

test("resolveCandidateTrafficEntry.js: CANDIDATE_TRAFFIC_TAG is read only from the environment — never interpolated into source, never taken from argv, no eval/Function usage anywhere in the module", () => {
  const jsText = fs.readFileSync(JS_RESOLVE_MODULE_PATH, "utf8");
  assert.ok(jsText.includes('process.env.CANDIDATE_TRAFFIC_TAG'), "the tag must be read via process.env, not embedded as a literal");
  assert.ok(!/process\.argv\[/.test(jsText), "the tag must not be taken from argv");
  assert.ok(!/\beval\s*\(/.test(jsText), "the module must never call eval()");
  assert.ok(!/new Function\s*\(/.test(jsText), "the module must never construct a Function from a string");
  assert.ok(
    !nonCommentLines(jsText).some((l) => /child_process|execSync|spawnSync|exec\(/.test(l)),
    "the module must never shell out to anything on any executable line (its own doc comment legitimately quotes 'spawnSync' once, describing the historical bug this file closes)"
  );
  // Sanity: the calling shell scripts pass it as an env-var prefix on
  // the invocation, never as a command-line argument.
  const promoteText = scriptText("promote.sh");
  assert.ok(/CANDIDATE_TRAFFIC_TAG="\$CANDIDATE_TRAFFIC_TAG" node ci\/resolveCandidateTrafficEntry\.js/.test(promoteText), "promote.sh must pass the tag as an environment variable prefix, not an argv value");
});

test("resolveCandidateTrafficEntry.js: shell metacharacters and command-substitution-shaped strings in a tag are treated as inert data — they cannot execute code or alter which entry matches", () => {
  const maliciousTag = "$(rm -rf /); echo pwned `id`";
  const trafficJson = JSON.stringify({
    status: {
      traffic: [
        { percent: 100, revisionName: "compliance-scanner-00002-h9h" },
        { tag: maliciousTag, revisionName: "compliance-scanner-00003-wof", url: "https://x.a.run.app" },
      ],
    },
  });
  const result = runResolveCandidateTrafficEntry({ trafficJson, tag: maliciousTag });
  assert.equal(result.status, 0, `expected the malicious-looking tag to be matched safely as plain data, stderr: ${result.stderr}`);
  const [url, revisionName] = result.stdout.trim().split("\n");
  assert.equal(url, "https://x.a.run.app");
  assert.equal(revisionName, "compliance-scanner-00003-wof");
  // The mere fact this test process is still running (nothing was
  // deleted, no subshell executed) is itself part of the proof; the
  // matched-value assertions above additionally confirm the string was
  // compared, not evaluated.
});

test("resolveCandidateTrafficEntry.js: the pure exported function (require()d directly, zero process spawns) agrees exactly with the CLI-spawned behavior above for the same inputs — proving the CLI wrapper does not alter the underlying decision logic", () => {
  const direct = resolveCandidateTrafficEntry(JSON.parse(REAL_CAPTURED_TRAFFIC_JSON), "candidate-580e47e8-aa407156");
  assert.deepEqual(direct, {
    ok: true,
    url: "https://candidate-580e47e8-aa407156---compliance-scanner-k2hhuwvftq-ew.a.run.app",
    revisionName: "compliance-scanner-00003-wof",
  });
});

// ---------------------------------------------------------------------
// Single-authoritative-resolver correction: exactly one candidate-
// traffic resolver implementation exists in this repository. The
// earlier ci/resolveCandidateTrafficEntry.py port (kept only because
// verify-deployed-candidate.sh's old image lacked node) is DELETED —
// verify-deployed-candidate.sh now runs on ci-builder and invokes the
// same ci/resolveCandidateTrafficEntry.js every other consumer uses.
// These checks are spawn-free and fs-only: they prove the .py file is
// gone and no reference to it survives anywhere in this repository's
// executable code or documentation, without ever launching python3
// (which is not present on the node:20.18.1-bookworm-slim image
// verify-source runs this test suite on).
// ---------------------------------------------------------------------

test("exactly one candidate-traffic resolver implementation exists: ci/resolveCandidateTrafficEntry.js is present; ci/resolveCandidateTrafficEntry.py does not exist anywhere in the repository", () => {
  assert.ok(fs.existsSync(JS_RESOLVE_MODULE_PATH), "the canonical .js resolver must exist");
  assert.ok(!fs.existsSync(path.join(REPO_ROOT, "ci", "resolveCandidateTrafficEntry.py")), "the .py resolver port must be deleted — single-authoritative-resolver correction");

  const resolverFilesInCiDir = fs.readdirSync(path.join(REPO_ROOT, "ci")).filter((f) => f.toLowerCase().includes("resolvecandidatetraffic"));
  assert.deepEqual(resolverFilesInCiDir, ["resolveCandidateTrafficEntry.js"], "exactly one resolver file (the canonical .js) may exist in ci/ — no second implementation, no leftover .py, no .pyc, no __pycache__ entry");
});

test("no .pyc or __pycache__ artifact from the deleted Python resolver remains anywhere under services/compliance-scanner", () => {
  const found = [];
  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (entry.name === "node_modules" || entry.name === ".git") continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        if (entry.name === "__pycache__") found.push(full);
        else walk(full);
      } else if (entry.name.endsWith(".pyc")) {
        found.push(full);
      }
    }
  }
  walk(REPO_ROOT);
  assert.deepEqual(found, [], `no __pycache__/.pyc artifact may remain: ${JSON.stringify(found)}`);
});

test("no executable line anywhere under ci/*.sh or the cloudbuild YAML references resolveCandidateTrafficEntry.py — no script or doc claims the deleted Python resolver is still authoritative on any EXECUTABLE line (comment-only historical mentions explaining the correction's own history are expected and excluded)", () => {
  for (const fname of fs.readdirSync(path.join(REPO_ROOT, "ci"))) {
    if (!fname.endsWith(".sh")) continue;
    const text = fs.readFileSync(path.join(REPO_ROOT, "ci", fname), "utf8");
    assert.ok(
      !nonCommentLines(text).some((l) => l.includes("resolveCandidateTrafficEntry.py")),
      `${fname}: no executable line may reference the deleted Python resolver`
    );
  }
  assert.ok(
    !nonCommentLines(yamlText).some((l) => l.includes("resolveCandidateTrafficEntry.py")),
    "cloudbuild.signature-refresh.yaml: no executable line may reference the deleted Python resolver"
  );
});

test("verify-deployed-candidate.sh calls gcloud run services describe exactly once to build the traffic JSON that supplies BOTH CANDIDATE_URL and CANDIDATE_REVISION — no second, separate traffic-fetching call exists", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  const trafficDescribeCalls = (text.match(/gcloud run services describe "\$\{SERVICE\}"[\s\S]*?--format="json\(status\.traffic\)"/g) || []).length;
  assert.equal(trafficDescribeCalls, 1, "exactly one gcloud describe call must fetch the traffic JSON");
  assert.ok(/CANDIDATE_URL=\$\(printf '%s\\n' "\$CANDIDATE_TRAFFIC_RESOLVED"/.test(text), "CANDIDATE_URL must come from the single resolved-traffic output");
  assert.ok(/CANDIDATE_REVISION=\$\(printf '%s\\n' "\$CANDIDATE_TRAFFIC_RESOLVED"/.test(text), "CANDIDATE_REVISION must come from the SAME single resolved-traffic output");
});

test("no repository-wide occurrence of the unsupported [?tag==...] predicate syntax remains in executable code — verify-deployed-candidate.sh AND promote.sh both closed (each file's own correction comment legitimately quotes it once, for documentation, explaining the historical defect)", () => {
  for (const fname of ["verify-deployed-candidate.sh", "promote.sh"]) {
    const text = scriptText(fname);
    assert.ok(
      !nonCommentLines(text).some((l) => l.includes("[?tag==")),
      `${fname}: no executable line may contain the unsupported [?tag==...] predicate syntax`
    );
  }
});

test("verify-deployed-candidate.sh's downstream checks (image digest, runtime SA, HTTP requests, final summary) consistently use the SAME resolved CANDIDATE_REVISION/CANDIDATE_URL — never a re-derived or separately fetched value", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  assert.ok(text.includes('ACTUAL_IMAGE=$(gcloud run revisions describe "$CANDIDATE_REVISION"'), "digest check must use the resolved CANDIDATE_REVISION");
  assert.ok(text.includes('ACTUAL_SA=$(gcloud run revisions describe "$CANDIDATE_REVISION"'), "runtime SA check must use the resolved CANDIDATE_REVISION");
  assert.ok(text.includes('echo "verify-deployed-candidate: all checks passed for revision ${CANDIDATE_REVISION} at digest ${DIGEST}"'), "the final summary must report the same resolved CANDIDATE_REVISION");
});

test("verify-deployed-candidate.sh: the traffic-resolution call fails closed via an explicit || exit 1 — never left to a bare, unguarded command substitution under set -e (the exact class of bug already fixed elsewhere in this pipeline for curl calls)", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  assert.ok(
    /CANDIDATE_TRAFFIC_RESOLVED=\$\([\s\S]*?\) \\\n\s*\|\| \{ echo "could not resolve candidate tag URL\/revision"; exit 1; \}/.test(text),
    "the resolveCandidateTrafficEntry.js call must be explicitly guarded with || { ...; exit 1; }"
  );
});

// ---------------------------------------------------------------------
// Generation-pinning SEQUENCING correction (closing a real staging
// failure — build 8b35480c-b19f-4aad-a0dd-9779a42d8b49, step
// verify-deployed-candidate: "generation-pinned read of old (EICAR)
// generation failed ... gcs_download_failed"). The prior version of
// this correction (direct-object GCS calls, replacing gcloud storage
// cp's own implicit bucket-list dependency) worked correctly, but
// bundled create+verify+cleanup into ONE invocation that ran BEFORE
// this script's own /v1/scan calls ever asked the deployed candidate
// to read the same generations — so cleanup deleted them first. Fixed
// Fixed by splitting ci/verifyGenerationPinning.js into `prepare` (creates
// both generations, verifies them locally, does NOT delete anything)
// and `cleanup` (reads a local receipt `prepare` wrote and deletes
// exactly those two generations). These checks prove the SHELL's own
// integration is correctly ordered: `prepare` runs once, before both
// HTTP verdict checks; `cleanup` is invoked (via one named function)
// only after both checks pass, with an EXIT/INT/TERM trap covering the
// window in between; and every OTHER previously-verified check in this
// script remains textually unaffected.
// ---------------------------------------------------------------------

test("verify-deployed-candidate.sh: prepare is invoked exactly once, cleanup is invoked via exactly one named function (never duplicated inline), and no gcloud storage cp/ls/rm/describe or wildcard storage operation remains anywhere in the file", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  const prepareInvocations = (text.match(/node ci\/verifyGenerationPinning\.js prepare\b/g) || []).length;
  assert.equal(prepareInvocations, 1, "prepare must be invoked exactly once");
  const cleanupFunctionDefinitions = (text.match(/generation_pinning_cleanup\(\)\s*\{/g) || []).length;
  assert.equal(cleanupFunctionDefinitions, 1, "the cleanup function must be defined exactly once");
  const cleanupInvocationsInsideFunction = (text.match(/node ci\/verifyGenerationPinning\.js cleanup\b/g) || []).length;
  assert.equal(cleanupInvocationsInsideFunction, 1, "the underlying `cleanup` subcommand must appear exactly once in the file — inside the named function, never duplicated inline elsewhere");
  assert.ok(
    !nonCommentLines(text).some((l) => /gcloud storage (cp|ls|rm)\b/.test(l)),
    "no executable line may contain gcloud storage cp/ls/rm"
  );
  assert.ok(
    !nonCommentLines(text).some((l) => /gcloud storage objects describe/.test(l)),
    "no executable line may contain gcloud storage objects describe"
  );
});

test("verify-deployed-candidate.sh: prepare passes PROJECT_ID, SYNTHETIC_TEST_BUCKET, and BUILD_ID as environment data, and its 3-line stdout (object path, gen1, gen2) is fail-closed non-empty-checked before use", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  assert.ok(text.includes('PROJECT_ID="$PROJECT_ID" SYNTHETIC_TEST_BUCKET="$SYNTHETIC_TEST_BUCKET" BUILD_ID="$BUILD_ID" V1_PAYLOAD_PATH=/tmp/v1.bin V2_PAYLOAD_PATH=/tmp/v2.bin node ci/verifyGenerationPinning.js prepare'), "prepare must be invoked with these exact env vars");
  assert.ok(text.includes('|| { echo "generation-pinning prepare failed"; exit 1; }'), "the prepare invocation must be explicitly guarded, fail-closed, under set -e");
  assert.ok(text.includes('[ -n "$GEN_PATH" ] || { echo "generation-pinning: missing object path"; exit 1; }'));
  assert.ok(text.includes('[ -n "$GEN1" ] || { echo "generation-pinning: missing first generation"; exit 1; }'));
  assert.ok(text.includes('[ -n "$GEN2" ] || { echo "generation-pinning: missing second generation"; exit 1; }'));
});

test("verify-deployed-candidate.sh: EXIT and INT/TERM use TWO SEPARATE handlers (adversarial correction) — a shared single trap cannot correctly satisfy both 'a caught signal must actually terminate the step' and 'cleanup must never run twice recursively' at once. The EXIT-only handler never calls exit itself (so it can never override a real primary failure's exit status); the signal handler disarms all three traps as its OWN first action (preventing its own exit call from recursively re-triggering the EXIT trap) before running cleanup and exiting with the conventional 128+signal status", () => {
  const text = scriptText("verify-deployed-candidate.sh");

  // Two distinct handler functions exist, each defined exactly once.
  assert.equal((text.match(/generation_pinning_exit_trap\(\) \{/g) || []).length, 1);
  assert.equal((text.match(/generation_pinning_signal_trap\(\) \{/g) || []).length, 1);

  // The EXIT-only handler's body never calls exit.
  const exitTrapBodyMatch = text.match(/generation_pinning_exit_trap\(\) \{\n([\s\S]*?)\n\}/);
  assert.ok(exitTrapBodyMatch, "could not locate generation_pinning_exit_trap's body");
  // Command-position only — the handler's own echoed diagnostic text
  // legitimately contains the WORD "exit" (e.g. "...handling script
  // exit..."), which a naive \bexit\b scan would wrongly flag.
  assert.ok(
    !/(?:^|\n|;|&&|\|\|)\s*exit(?:\s|$)/.test(exitTrapBodyMatch[1]),
    "the EXIT-only handler must never call exit itself, or it would override the real primary exit status"
  );
  assert.ok(/generation_pinning_cleanup \|\| echo "[^"]*" >&2/.test(exitTrapBodyMatch[1]), "the EXIT-only handler must invoke cleanup and, on its own failure, only echo a diagnostic");

  // The signal handler disarms first, then cleans up, then exits with
  // the exact conventional signal-specific status for each case.
  const signalTrapBodyMatch = text.match(/generation_pinning_signal_trap\(\) \{\n([\s\S]*?)\n\}/);
  assert.ok(signalTrapBodyMatch, "could not locate generation_pinning_signal_trap's body");
  const signalBody = signalTrapBodyMatch[1];
  assert.ok(signalBody.trim().startsWith("trap - EXIT INT TERM"), "the signal handler must disarm all three traps as its very first statement");
  assert.ok(signalBody.includes("INT) exit 130"), "SIGINT must exit with status 130 (128+2)");
  assert.ok(signalBody.includes("TERM) exit 143"), "SIGTERM must exit with status 143 (128+15)");

  // Arming: EXIT bound to the EXIT-only handler; INT/TERM each bound
  // to the signal handler with their own signal name argument.
  assert.ok(text.includes("trap generation_pinning_exit_trap EXIT"));
  assert.ok(text.includes("trap 'generation_pinning_signal_trap INT' INT"));
  assert.ok(text.includes("trap 'generation_pinning_signal_trap TERM' TERM"));

  const armIndex = text.indexOf("trap generation_pinning_exit_trap EXIT");
  const prepareIndex = text.indexOf("node ci/verifyGenerationPinning.js prepare");
  assert.ok(armIndex !== -1 && prepareIndex !== -1 && armIndex < prepareIndex, "all three traps must be armed before prepare runs");

  const disarmIndex = text.lastIndexOf("trap - EXIT INT TERM");
  assert.ok(disarmIndex > armIndex, "the success-path disarm must occur after arming");
  const explicitCleanupCallIndex = text.lastIndexOf('generation_pinning_cleanup || { echo "generation-pinning cleanup failed after successful verification"; exit 1; }');
  assert.ok(explicitCleanupCallIndex !== -1 && explicitCleanupCallIndex < disarmIndex, "on the success path, the trap must be disarmed only AFTER the explicit cleanup call — never before, per the required ordering: verification -> explicit cleanup succeeds -> traps disarmed -> exit 0");
});

test("verify-deployed-candidate.sh: prepare occurs strictly before BOTH /v1/scan generation-pinned HTTP verdict checks, and the explicit cleanup call occurs strictly AFTER both of them — the exact ordering this correction exists to fix (positions computed over EXECUTABLE lines only — the file's own doc comment legitimately quotes the historical failure message once, earlier in the file, as history)", () => {
  const text = nonCommentLines(scriptText("verify-deployed-candidate.sh")).join("\n");
  const prepareIndex = text.indexOf("node ci/verifyGenerationPinning.js prepare");
  const gen1CheckIndex = text.indexOf('generation-pinned read of old (EICAR) generation failed');
  const gen2CheckIndex = text.indexOf('generation-pinned read of new (benign) generation failed');
  const explicitCleanupIndex = text.indexOf('generation_pinning_cleanup || { echo "generation-pinning cleanup failed after successful verification"');

  assert.ok(prepareIndex !== -1 && gen1CheckIndex !== -1 && gen2CheckIndex !== -1 && explicitCleanupIndex !== -1, "all four anchors must be present on executable lines");
  assert.ok(prepareIndex < gen1CheckIndex, "prepare must occur before the GEN1/EICAR verdict check");
  assert.ok(gen1CheckIndex < gen2CheckIndex, "the GEN1 check must occur before the GEN2 check (unchanged order)");
  assert.ok(gen2CheckIndex < explicitCleanupIndex, "the explicit cleanup call must occur AFTER both HTTP verdict checks — never before, which was this correction's exact defect");
});

test("verify-deployed-candidate.sh: on normal success, cleanup's own exit status is explicitly checked and treated as fatal if it fails — success of the HTTP verification checks alone is never sufficient to report step success", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  assert.ok(
    text.includes('generation_pinning_cleanup || { echo "generation-pinning cleanup failed after successful verification"; exit 1; }'),
    "the post-verification cleanup call must be guarded with || { ...; exit 1; }, not left unchecked"
  );
});

test("verify-deployed-candidate.sh: every previously-verified check remains unchanged by the generation-pinning sequencing correction — resolver invocation, digest verification, runtime-SA verification, authenticated/unauthenticated/invalid-auth checks, and all three mandatory fixture verdicts are all still present, textually unaffected; and promotion/rollback/fencing files remain untouched by this correction", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  assert.ok(text.includes("node ci/resolveCandidateTrafficEntry.js"), "the shared resolver invocation must be unchanged");
  assert.ok(text.includes('echo "$ACTUAL_IMAGE" | grep -qF "$DIGEST"'), "digest verification must be unchanged");
  assert.ok(text.includes('[ "$ACTUAL_SA" = "${SCANNER_RUNTIME_SA}" ]'), "runtime-SA verification must be unchanged");
  assert.ok(text.includes('[ "$STATUS_CODE" = "200" ]'), "authenticated /status check must be unchanged");
  assert.ok(text.includes('[ "$NOAUTH_CODE" = "403" ]'), "unauthenticated-rejected check must be unchanged");
  assert.ok(text.includes('[ "$BADAUTH_CODE" = "401" ]'), "invalid-auth-rejected check must be unchanged");
  assert.ok(text.includes('scan_fixture "benign-text" "FIXTURE_BENIGN_TEXT" "clean"'));
  assert.ok(text.includes('scan_fixture "eicar-standard" "FIXTURE_EICAR_STANDARD" "infected"'));
  assert.ok(text.includes('scan_fixture "encrypted-pdf" "FIXTURE_ENCRYPTED_PDF" "error" "encrypted_document_unsupported"'));
  // No IAM command was introduced by this correction.
  assert.ok(!/add-iam-policy-binding|remove-iam-policy-binding|set-iam-policy\b/.test(text));
  // promote.sh untouched by this correction.
  const promoteText = scriptText("promote.sh");
  assert.ok(!promoteText.includes("verifyGenerationPinning"), "promote.sh must never reference the generation-pinning helper — promotion/rollback/fencing logic is unrelated to this correction");
});

// ---------------------------------------------------------------------
// Generation-pinning trap-lifecycle adversarial correction. Unlike
// every other test in this file, these EXECUTE the real, extracted
// trap-definition shell code (verbatim substrings of the committed
// verify-deployed-candidate.sh, not a reimplementation) as REAL child
// processes — including sending REAL SIGINT/SIGTERM signals — because
// signal-exit-status/recursion-prevention behavior cannot be proven by
// inspecting source text alone. A fake `node` binary on PATH intercepts
// `node ci/verifyGenerationPinning.js cleanup` calls (recording each
// invocation to a log file and exiting with a controllable code) so
// these tests never touch a real bucket or receipt file.
// ---------------------------------------------------------------------

function extractGenerationPinningTrapDefinitions() {
  const text = scriptText("verify-deployed-candidate.sh");
  const match = text.match(/generation_pinning_cleanup\(\) \{[\s\S]*?trap 'generation_pinning_signal_trap TERM' TERM\n/);
  assert.ok(match, "could not extract the generation-pinning trap-definition block");
  return match[0];
}

function extractGenerationPinningSuccessCleanupBlock() {
  const text = scriptText("verify-deployed-candidate.sh");
  const match = text.match(/generation_pinning_cleanup \|\| \{ echo "generation-pinning cleanup failed after successful verification"; exit 1; \}\ntrap - EXIT INT TERM\n/);
  assert.ok(match, 'could not extract the explicit success-path "cleanup then disarm" block');
  return match[0];
}

function buildTrapHarnessScript() {
  return [
    "#!/bin/sh",
    "set -eu",
    extractGenerationPinningTrapDefinitions(),
    'case "$TEST_SCENARIO" in',
    "  success)",
    extractGenerationPinningSuccessCleanupBlock(),
    '    echo "HARNESS_SUCCEEDED"',
    "    exit 0",
    "    ;;",
    "  command_failure)",
    '    echo "SIMULATED PRIMARY FAILURE" >&2',
    "    exit 17",
    "    ;;",
    "  await_signal)",
    '    echo "HARNESS_READY"',
    "    i=0",
    "    while [ \"$i\" -lt 60 ]; do",
    "      sleep 1",
    "      i=$((i + 1))",
    "    done",
    '    echo "UNEXPECTED: harness was not interrupted by a signal" >&2',
    "    exit 99",
    "    ;;",
    "  *)",
    '    echo "unknown TEST_SCENARIO: $TEST_SCENARIO" >&2',
    "    exit 98",
    "    ;;",
    "esac",
    "",
  ].join("\n");
}

// Real, spawned (async) subprocess harness — never a real bucket, never
// a real receipt on disk (the fake `node` intercepts the one command
// that would otherwise touch either). `signalToSend`, when supplied, is
// delivered shortly after the harness prints "HARNESS_READY" (the
// `await_signal` scenario's own readiness marker).
function runTrapHarness({ scenario, cleanupExitCode = 0, signalToSend = null, signalDelayMs = 200 }) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "generation-pinning-trap-test-"));
  const fakeBinDir = path.join(tmpDir, "bin");
  fs.mkdirSync(fakeBinDir);
  const cleanupLogPath = path.join(tmpDir, "cleanup.log");
  fs.writeFileSync(cleanupLogPath, "");
  fs.writeFileSync(
    path.join(fakeBinDir, "node"),
    [
      "#!/bin/sh",
      'case "$1" in',
      "  *verifyGenerationPinning.js)",
      '    if [ "$2" = "cleanup" ]; then',
      '      echo "cleanup-invoked" >> "$CLEANUP_LOG_PATH"',
      '      exit "$FAKE_CLEANUP_EXIT_CODE"',
      "    fi",
      "    ;;",
      "esac",
      "exit 0",
      "",
    ].join("\n"),
    { mode: 0o755 }
  );
  const harnessPath = path.join(tmpDir, "harness.sh");
  fs.writeFileSync(harnessPath, buildTrapHarnessScript(), { mode: 0o755 });

  return new Promise((resolve, reject) => {
    const child = spawn("sh", [harnessPath], {
      cwd: tmpDir,
      env: {
        ...process.env,
        PATH: `${fakeBinDir}:${process.env.PATH}`,
        // The extracted generation_pinning_cleanup() body references
        // these three under `set -eu` — the real script always has
        // them (its own required-args guard, earlier in the file,
        // fails closed first if they're missing); the fake `node`
        // above ignores their values entirely, but the shell itself
        // still needs them bound to avoid an "unbound variable" abort.
        PROJECT_ID: "fake-project",
        SYNTHETIC_TEST_BUCKET: "fake-bucket",
        BUILD_ID: "00000000-0000-0000-0000-000000000000",
        CLEANUP_LOG_PATH: cleanupLogPath,
        FAKE_CLEANUP_EXIT_CODE: String(cleanupExitCode),
        TEST_SCENARIO: scenario,
      },
    });

    let stdout = "";
    let stderr = "";
    let signalSent = false;
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
      if (!signalSent && signalToSend && stdout.includes("HARNESS_READY")) {
        signalSent = true;
        setTimeout(() => child.kill(signalToSend), signalDelayMs);
      }
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", reject);
    child.on("close", (code, signal) => {
      let cleanupInvocations = 0;
      try {
        cleanupInvocations = fs
          .readFileSync(cleanupLogPath, "utf8")
          .split("\n")
          .filter((l) => l === "cleanup-invoked").length;
      } catch (err) {
        // leave at 0
      }
      fs.rmSync(tmpDir, { recursive: true, force: true });
      resolve({ code, signal, stdout, stderr, cleanupInvocations });
    });
  });
}

test("trap harness: normal success runs the extracted real trap-definition + explicit-cleanup code, performs cleanup exactly ONCE, and exits 0 — proving the trap is correctly disarmed before the script's own normal completion (a bug here would show cleanupInvocations === 2)", async () => {
  const result = await runTrapHarness({ scenario: "success", cleanupExitCode: 0 });
  assert.equal(result.code, 0, `expected exit 0, got: ${JSON.stringify(result)}`);
  assert.equal(result.signal, null);
  assert.ok(result.stdout.includes("HARNESS_SUCCEEDED"));
  assert.equal(result.cleanupInvocations, 1, "cleanup must run exactly once on the normal success path");
});

test("trap harness: a primary command failure (exit 17) is preserved exactly — the EXIT trap runs cleanup exactly once, its handler never calls exit itself, so the original status is never overwritten", async () => {
  const result = await runTrapHarness({ scenario: "command_failure", cleanupExitCode: 0 });
  assert.equal(result.code, 17, `expected the primary exit status 17 to be preserved, got: ${JSON.stringify(result)}`);
  assert.equal(result.signal, null);
  assert.equal(result.cleanupInvocations, 1);
});

test("trap harness: primary exit 17 remains 17 even when the EXIT trap's OWN cleanup attempt also fails — both the primary failure diagnostic and the cleanup-failure diagnostic are visible on stderr, and the cleanup failure never replaces the primary exit status", async () => {
  const result = await runTrapHarness({ scenario: "command_failure", cleanupExitCode: 1 });
  assert.equal(result.code, 17, `the primary status must survive a failing cleanup attempt, got: ${JSON.stringify(result)}`);
  assert.ok(result.stderr.includes("SIMULATED PRIMARY FAILURE"), "the primary failure's own diagnostic must be visible");
  assert.ok(result.stderr.includes("generation-pinning: cleanup failed while handling script exit"), "the cleanup-failure diagnostic must ALSO be visible, as a distinct report");
  assert.equal(result.cleanupInvocations, 1);
});

test("trap harness: a cleanup failure AFTER otherwise-successful verification makes the step fail overall — the explicit post-verification cleanup call's own exit 1 is what the script reports, not exit 0", async () => {
  const result = await runTrapHarness({ scenario: "success", cleanupExitCode: 1 });
  assert.equal(result.code, 1, `success + failing cleanup must fail the step, got: ${JSON.stringify(result)}`);
  assert.ok(!result.stdout.includes("HARNESS_SUCCEEDED"), "the script must never reach its own success marker when cleanup itself fails");
  assert.ok(result.stdout.includes("generation-pinning cleanup failed after successful verification"), "this specific diagnostic is echoed to stdout (no >&2) in the real script, unlike the trap handlers' own echoes");
  // The explicit call fails before the trap is ever disarmed, so the
  // still-armed EXIT trap legitimately retries cleanup once more as a
  // best-effort second attempt (itself idempotent/safe against the
  // real Node helper) — this is a retry of a FAILED attempt, not a
  // repeat of a SUCCESSFUL one, and is therefore not the "successful
  // cleanup repeated" defect this correction closes.
  assert.equal(result.cleanupInvocations, 2, "the failed explicit attempt plus the EXIT trap's own best-effort retry");
});

test("trap harness: SIGINT performs cleanup exactly once, exits 130 (the conventional 128+SIGINT status), and execution never continues past the signal — the harness's own 'was not interrupted' fallback message never appears", async () => {
  const result = await runTrapHarness({ scenario: "await_signal", cleanupExitCode: 0, signalToSend: "SIGINT" });
  assert.equal(result.code, 130, `expected 130, got: ${JSON.stringify(result)}`);
  assert.equal(result.signal, null, "the shell's OWN trap must translate the signal into a controlled exit — the process must not be reported as raw-signal-killed");
  assert.equal(result.cleanupInvocations, 1);
  assert.ok(!result.stderr.includes("UNEXPECTED: harness was not interrupted"), "execution must never continue past the signal handler");
});

test("trap harness: SIGTERM performs cleanup exactly once, exits 143 (the conventional 128+SIGTERM status), and execution never continues past the signal", async () => {
  const result = await runTrapHarness({ scenario: "await_signal", cleanupExitCode: 0, signalToSend: "SIGTERM" });
  assert.equal(result.code, 143, `expected 143, got: ${JSON.stringify(result)}`);
  assert.equal(result.signal, null);
  assert.equal(result.cleanupInvocations, 1);
  assert.ok(!result.stderr.includes("UNEXPECTED: harness was not interrupted"));
});

test("trap harness: a SIGINT/SIGTERM cleanup failure does not change the signal's own exit status — 130/143 are reported unconditionally, with the cleanup failure only additionally visible as a distinct diagnostic", async () => {
  const intResult = await runTrapHarness({ scenario: "await_signal", cleanupExitCode: 1, signalToSend: "SIGINT" });
  assert.equal(intResult.code, 130);
  assert.ok(intResult.stderr.includes("generation-pinning: cleanup failed while handling signal INT"));
  assert.equal(intResult.cleanupInvocations, 1, "the signal handler disarms all traps before calling cleanup, so a failing cleanup here is never retried — it exits with the signal status regardless");

  const termResult = await runTrapHarness({ scenario: "await_signal", cleanupExitCode: 1, signalToSend: "SIGTERM" });
  assert.equal(termResult.code, 143);
  assert.ok(termResult.stderr.includes("generation-pinning: cleanup failed while handling signal TERM"));
  assert.equal(termResult.cleanupInvocations, 1);
});

test("trap harness: source-level proof that the signal handler disarms EXIT/INT/TERM as its OWN first action, before calling cleanup or exit — this is what prevents the handler's own exit call from recursively re-triggering the EXIT trap (no recursive trap execution)", () => {
  const block = extractGenerationPinningTrapDefinitions();
  const signalFnMatch = block.match(/generation_pinning_signal_trap\(\) \{\n([\s\S]*?)\n\}/);
  assert.ok(signalFnMatch, "could not locate generation_pinning_signal_trap's own body");
  const body = signalFnMatch[1];
  const disarmLine = body.indexOf("trap - EXIT INT TERM");
  const cleanupCallLine = body.indexOf("generation_pinning_cleanup");
  const exitCaseLine = body.indexOf("case \"$1\" in");
  assert.ok(disarmLine !== -1 && disarmLine < cleanupCallLine && disarmLine < exitCaseLine, "the disarm must be the first statement in the signal handler, before cleanup and before the exit case");
});
// ea9bad30-d2e2-4aa1-9fdb-a765bde94372, step verify-source: "spawnSync
// git ENOENT". A runtime `git diff` check was invalid on two counts:
// the minimal node:20.18.1-bookworm-slim image has no git binary at
// all, AND the Cloud Build source archive itself excludes .git
// entirely — even a hypothetical git-equipped image would have no
// repository history to diff against once uploaded. Replaced with
// deterministic, spawn-free fs.readFileSync-based checks (via the
// existing scriptText() helper) that verify the SPECIFIC invariants
// this correction must not disturb, rather than a blunt
// "nothing changed" proxy for them.
// ---------------------------------------------------------------------

test("deploy-candidate.sh: candidate-tag validation and the 46-character combined length enforcement remain present and unweakened (unaffected by the traffic-resolver correction in the other two files)", () => {
  const text = scriptText("deploy-candidate.sh");
  assert.ok(/case "\$COMMIT_SHA" in/.test(text), "COMMIT_SHA shape validation must still exist");
  assert.ok(/case "\$BUILD_ID" in/.test(text), "BUILD_ID shape validation must still exist");
  assert.ok(text.includes('CANDIDATE_TRAFFIC_TAG="candidate-${SHORT_COMMIT_SHA}-${SHORT_BUILD_ID}"'), "the short-tag construction must be unchanged");
  assert.ok(/CANDIDATE_TAG_COMBINED_LENGTH="?\$\(\(\$\{#SERVICE\} \+ \$\{#CANDIDATE_TRAFFIC_TAG\}\)\)/.test(text), "the combined-length calculation must be unchanged");
  assert.ok(/if \[ "\$CANDIDATE_TAG_COMBINED_LENGTH" -gt 46 \]; then/.test(text), "the 46-character limit enforcement must be unchanged");
});

test("deploy-candidate.sh: the deploy command uses the persisted, validated candidate tag — the SAME variable the length check above validated, never a re-derived value", () => {
  const text = scriptText("deploy-candidate.sh");
  assert.ok(text.includes('echo "$CANDIDATE_TRAFFIC_TAG" > /workspace/.candidate-traffic-tag'), "the validated tag must still be persisted for downstream consumers");
  assert.ok(text.includes('--tag="${CANDIDATE_TRAFFIC_TAG}"'), "gcloud run deploy must still use the same validated tag variable");
  const tagAssignments = (text.match(/^CANDIDATE_TRAFFIC_TAG=/gm) || []).length;
  assert.equal(tagAssignments, 1, "CANDIDATE_TRAFFIC_TAG must be assigned exactly once — no second, re-derived value");
});

test("deploy-candidate.sh: the immutable, digest-pinned image reference remains used for the deploy — never a mutable tag", () => {
  const text = scriptText("deploy-candidate.sh");
  assert.ok(text.includes('DIGEST="$(cat /workspace/.candidate-digest)"'), "must still deploy the digest resolved by resolve-digest.sh");
  assert.ok(text.includes('IMAGE_REF="${REGION_HOST}/${PROJECT_ID}/${REPOSITORY:?REPOSITORY is required}/${IMAGE_NAME:?IMAGE_NAME is required}@${DIGEST}"'), "the image reference must still be digest-pinned (@DIGEST, not a :tag)");
  assert.ok(text.includes('--image="${IMAGE_REF}"'), "gcloud run deploy must still deploy by the digest-pinned image reference");
});

test("deploy-candidate.sh: the expected scanner runtime service account is still supplied to the deploy command, unchanged", () => {
  const text = scriptText("deploy-candidate.sh");
  assert.ok(text.includes('--service-account="${SCANNER_RUNTIME_SA}"'), "gcloud run deploy must still supply the runtime service account");
});

test("deploy-candidate.sh: no --allow-unauthenticated behavior exists — --no-allow-unauthenticated is still present, and no bare --allow-unauthenticated appears anywhere", () => {
  const text = scriptText("deploy-candidate.sh");
  assert.ok(text.includes("--no-allow-unauthenticated"), "must still deploy with no unauthenticated access");
  assert.ok(
    !nonCommentLines(text).some((l) => /(?<!--no-)--allow-unauthenticated/.test(l)),
    "must never introduce a bare --allow-unauthenticated on an executable line"
  );
});

test("deploy-candidate.sh: no unrelated traffic mutation was added — --no-traffic is still present (the candidate must receive zero traffic at deploy time), and this file still contains no `gcloud run services update-traffic` call (that mutation belongs to promote.sh alone)", () => {
  const text = scriptText("deploy-candidate.sh");
  assert.ok(text.includes("--no-traffic"), "the candidate deploy must still request zero traffic");
  assert.ok(!text.includes("update-traffic"), "deploy-candidate.sh must never itself shift traffic — that is promote.sh's sole responsibility");
});

// ---------------------------------------------------------------------
// promote.sh candidate-revision resolution correction (Slice 2.2,
// eliminating the IDENTICAL [?tag==...] defect confirmed present in
// promote.sh — the same root cause as verify-deployed-candidate.sh's
// own correction. Never exercised in a real build (no build has ever
// reached promote.sh), but the construction was byte-identical to the
// one proven broken there.
//
// promote.sh uses ci/resolveCandidateTrafficEntry.**js** (node) — the
// SAME single authoritative resolver verify-deployed-candidate.sh now
// also uses (single-authoritative-resolver correction; see the large
// section comment above this file's other resolver tests for the full
// history). This means `sh`-spawned tests below, which run promote.sh's
// own extracted block (which itself invokes bare `node` on PATH,
// exactly as production does), work correctly here in verify-source's
// own node-only image.
//
// These tests extract and BEHAVIORALLY RUN the real corrected block
// from promote.sh against a fake `gcloud` on PATH and the REAL,
// unmocked resolveCandidateTrafficEntry.js helper — the same
// extract-and-execute technique this file's own acquire-lock.sh and
// deploy-candidate.sh Correction/behavioral tests already use.
// ---------------------------------------------------------------------

function extractPromoteCandidateResolutionBlock() {
  const text = scriptText("promote.sh");
  const match = text.match(/CANDIDATE_TRAFFIC_JSON=\$\(gcloud run services describe[\s\S]*?\[ -n "\$CANDIDATE_REVISION" \] \|\| \{ echo "could not resolve candidate revision name"; exit 1; \}\n/);
  assert.ok(match, "could not extract the candidate-resolution block from promote.sh");
  return match[0];
}

function runPromoteCandidateResolution({ trafficJson, tag }) {
  const block = extractPromoteCandidateResolutionBlock();
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "promote-resolve-sim-"));
  const fakeBinDir = path.join(tmpDir, "bin");
  fs.mkdirSync(fakeBinDir);
  // A fake `gcloud` that ignores its arguments and always emits the
  // supplied traffic JSON for a `services describe` call — this test
  // exercises the SHELL WIRING (pipe into the real resolver, env-var
  // tag passing, sed line extraction, fail-closed guards), not
  // gcloud's own argument handling, which is identical to the
  // already-proven verify-deployed-candidate.sh pattern.
  fs.writeFileSync(path.join(fakeBinDir, "gcloud"), `#!/bin/sh\ncat <<'TRAFFIC_JSON_EOF'\n${trafficJson}\nTRAFFIC_JSON_EOF\n`, { mode: 0o755 });
  const result = spawnSync(
    "sh",
    ["-c", `set -eu\n${block}\necho "RESOLVED_CANDIDATE_REVISION=$CANDIDATE_REVISION"\necho "RESOLVED_CANDIDATE_URL=$CANDIDATE_URL"`],
    {
      cwd: REPO_ROOT,
      env: {
        ...process.env,
        PATH: `${fakeBinDir}:${process.env.PATH}`,
        PROJECT_ID: "fake-project",
        REGION: "fake-region",
        SERVICE: "compliance-scanner",
        CANDIDATE_TRAFFIC_TAG: tag,
      },
      encoding: "utf8",
    }
  );
  fs.rmSync(tmpDir, { recursive: true, force: true });
  return result;
}

test("both shell consumers — promote.sh AND verify-deployed-candidate.sh — invoke the SAME single authoritative resolver, ci/resolveCandidateTrafficEntry.js via node; neither references a Python resolver anywhere in executable code, and no second resolver file of any kind exists", () => {
  const promoteText = scriptText("promote.sh");
  const verifyText = scriptText("verify-deployed-candidate.sh");
  assert.ok(promoteText.includes("node ci/resolveCandidateTrafficEntry.js"), "promote.sh must invoke the canonical Node resolver helper");
  assert.ok(verifyText.includes("node ci/resolveCandidateTrafficEntry.js"), "verify-deployed-candidate.sh must invoke the SAME canonical Node resolver helper");
  for (const [fname, text] of [["promote.sh", promoteText], ["verify-deployed-candidate.sh", verifyText]]) {
    assert.ok(
      !nonCommentLines(text).some((l) => l.includes("resolveCandidateTrafficEntry.py") || l.includes("python3 ci/resolveCandidateTrafficEntry")),
      `${fname} must never reference a Python resolver on any executable line — no python3 dependency remains for candidate traffic resolution`
    );
  }

  const otherJsResolvers = fs.readdirSync(path.join(REPO_ROOT, "ci")).filter((f) => f.endsWith(".js") && f.toLowerCase().includes("resolvecandidatetraffic") && f !== "resolveCandidateTrafficEntry.js");
  assert.deepEqual(otherJsResolvers, [], "no second Node resolver/parser file may exist alongside the canonical one");
  const anyPyResolvers = fs.readdirSync(path.join(REPO_ROOT, "ci")).filter((f) => f.endsWith(".py") && f.toLowerCase().includes("resolvecandidatetraffic"));
  assert.deepEqual(anyPyResolvers, [], "no Python resolver file may exist at all — single-authoritative-resolver correction");
});

test("promote.sh makes exactly one structured (json) gcloud describe call FOR CANDIDATE RESOLUTION specifically (CANDIDATE_TRAFFIC_JSON=...) — no second, separate candidate-traffic-fetching call exists. (A second, later --format=\"json(status.traffic)\" call does legitimately exist for an entirely different purpose — RESTORED=..., the rollback-verification read — and is correctly excluded by matching the CANDIDATE_TRAFFIC_JSON variable name specifically, not just the shared format string.)", () => {
  const text = scriptText("promote.sh");
  const candidateTrafficJsonAssignments = (text.match(/CANDIDATE_TRAFFIC_JSON=\$\(gcloud run services describe/g) || []).length;
  assert.equal(candidateTrafficJsonAssignments, 1, "exactly one gcloud describe call must fetch the traffic JSON for candidate resolution");
  // Sanity: the OTHER, unrelated json(status.traffic) read (rollback
  // verification) is confirmed to still exist too, proving this test
  // isn't accidentally passing because that read was removed.
  assert.ok(text.includes('RESTORED=$(gcloud run services describe "${SERVICE}"'), "the separate rollback-verification traffic read must still exist, unchanged");
});

test("promote.sh behavioral: the real captured traffic structure from build aa407156 resolves CANDIDATE_REVISION to the unique tag-matching entry, run through promote.sh's own extracted block and the REAL resolver — not a reimplementation", () => {
  const result = runPromoteCandidateResolution({ trafficJson: REAL_CAPTURED_TRAFFIC_JSON, tag: "candidate-580e47e8-aa407156" });
  assert.equal(result.status, 0, `expected success, stderr: ${result.stderr}`);
  assert.ok(result.stdout.includes("RESOLVED_CANDIDATE_REVISION=compliance-scanner-00003-wof"), `expected the candidate revision, got: ${result.stdout}`);
  assert.ok(result.stdout.includes("RESOLVED_CANDIDATE_URL=https://candidate-580e47e8-aa407156"), `expected the candidate url, got: ${result.stdout}`);
});

test("promote.sh behavioral: the untagged 100%-traffic baseline entry can never be selected as the candidate revision, even when it is the only entry present", () => {
  const onlyBaseline = JSON.stringify({ status: { traffic: [{ percent: 100, revisionName: "compliance-scanner-00002-h9h" }] } });
  const result = runPromoteCandidateResolution({ trafficJson: onlyBaseline, tag: "candidate-580e47e8-aa407156" });
  assert.notEqual(result.status, 0, "must fail rather than silently promote the untagged baseline");
  assert.ok(!result.stdout.includes("RESOLVED_CANDIDATE_REVISION="), "must exit before ever assigning CANDIDATE_REVISION");
});

test("promote.sh behavioral: duplicate matching tags fail closed rather than picking either candidate arbitrarily", () => {
  const duplicateTag = JSON.stringify({
    status: {
      traffic: [
        { revisionName: "compliance-scanner-00003-wof", tag: "candidate-dup", url: "https://a.a.run.app" },
        { revisionName: "compliance-scanner-00004-xyz", tag: "candidate-dup", url: "https://b.a.run.app" },
      ],
    },
  });
  const result = runPromoteCandidateResolution({ trafficJson: duplicateTag, tag: "candidate-dup" });
  assert.notEqual(result.status, 0);
  assert.ok(result.stderr.includes("2 traffic entries"), `expected a duplicate-match diagnostic, got: ${result.stderr}`);
});

test("promote.sh behavioral: no matching tag fails closed with a clear diagnostic, before any traffic mutation could ever be attempted", () => {
  const result = runPromoteCandidateResolution({ trafficJson: REAL_CAPTURED_TRAFFIC_JSON, tag: "candidate-does-not-exist-00000000" });
  assert.notEqual(result.status, 0);
  assert.ok(result.stderr.includes("no traffic entry has tag"), `expected a no-match diagnostic, got: ${result.stderr}`);
});

test("promote.sh behavioral: malformed traffic JSON fails closed", () => {
  const fakeBinDir = fs.mkdtempSync(path.join(os.tmpdir(), "promote-resolve-badjson-"));
  fs.writeFileSync(path.join(fakeBinDir, "gcloud"), "#!/bin/sh\necho '{not valid json'\n", { mode: 0o755 });
  const block = extractPromoteCandidateResolutionBlock();
  const result = spawnSync("sh", ["-c", `set -eu\n${block}`], {
    cwd: REPO_ROOT,
    env: { ...process.env, PATH: `${fakeBinDir}:${process.env.PATH}`, PROJECT_ID: "fake-project", REGION: "fake-region", SERVICE: "compliance-scanner", CANDIDATE_TRAFFIC_TAG: "candidate-x" },
    encoding: "utf8",
  });
  fs.rmSync(fakeBinDir, { recursive: true, force: true });
  assert.notEqual(result.status, 0);
});

test("promote.sh behavioral: shell-metacharacter-shaped tag content remains inert — matched only as plain string data, never executed, never able to alter which entry resolves", () => {
  const maliciousTag = "$(rm -rf /); echo pwned `id`";
  const trafficJson = JSON.stringify({
    status: {
      traffic: [
        { percent: 100, revisionName: "compliance-scanner-00002-h9h" },
        { tag: maliciousTag, revisionName: "compliance-scanner-00003-wof", url: "https://x.a.run.app" },
      ],
    },
  });
  const result = runPromoteCandidateResolution({ trafficJson, tag: maliciousTag });
  assert.equal(result.status, 0, `expected the malicious-looking tag to be matched safely as plain data, stderr: ${result.stderr}`);
  assert.ok(result.stdout.includes("RESOLVED_CANDIDATE_REVISION=compliance-scanner-00003-wof"), `expected the correct revision despite the malicious tag, got: ${result.stdout}`);
});

test("verify-deployed-candidate.sh and promote.sh integrate with the resolver IDENTICALLY — same gcloud call shape, same env-var tag passing, same output-parsing (sed -n '1p'/'2p'), same fail-closed guard wording, and the EXACT SAME invocation line (interpreter, file, and env-var passing all identical — no divergence of any kind remains between the two consumers)", () => {
  const verifyText = scriptText("verify-deployed-candidate.sh");
  const promoteText = scriptText("promote.sh");
  for (const text of [verifyText, promoteText]) {
    assert.ok(text.includes('--format="json(status.traffic)"'));
    assert.ok(text.includes("CANDIDATE_URL=$(printf '%s\\n' \"$CANDIDATE_TRAFFIC_RESOLVED\" | sed -n '1p')"));
    assert.ok(text.includes("CANDIDATE_REVISION=$(printf '%s\\n' \"$CANDIDATE_TRAFFIC_RESOLVED\" | sed -n '2p')"));
    assert.ok(text.includes('[ -n "$CANDIDATE_URL" ] || { echo "could not resolve candidate tag URL"; exit 1; }'));
    assert.ok(text.includes('[ -n "$CANDIDATE_REVISION" ] || { echo "could not resolve candidate revision name"; exit 1; }'));
  }
  const CANONICAL_INVOCATION = 'CANDIDATE_TRAFFIC_TAG="$CANDIDATE_TRAFFIC_TAG" node ci/resolveCandidateTrafficEntry.js';
  assert.ok(verifyText.includes(CANONICAL_INVOCATION), "verify-deployed-candidate.sh must use the exact canonical resolver invocation");
  assert.ok(promoteText.includes(CANONICAL_INVOCATION), "promote.sh must use the exact canonical resolver invocation");
});

// ---------------------------------------------------------------------
// Self-referential guards (Slice 2.2, closing build
// ea9bad30-d2e2-4aa1-9fdb-a765bde94372's verify-source failure at its
// root: THIS TEST FILE itself must never spawn python3 or git, since
// neither exists on the node:20.18.1-bookworm-slim image verify-source
// runs this file on). Scans this file's OWN source text — the
// strongest possible proof a future edit cannot silently reintroduce
// the exact class of bug this correction closes.
// ---------------------------------------------------------------------

const THIS_TEST_FILE_TEXT = fs.readFileSync(__filename, "utf8");

test("pipelineStatic.test.js never spawns python3 anywhere in its own source — the exact defect that broke verify-source in build ea9bad30", () => {
  assert.ok(
    !/spawnSync\(\s*["']python3["']|execFileSync\(\s*["']python3["']|execSync\(\s*["']python3/.test(THIS_TEST_FILE_TEXT),
    "this test file must never spawn a python3 process — python3 is not present on the node:20.18.1-bookworm-slim image verify-source runs it on"
  );
});

test("pipelineStatic.test.js never spawns git anywhere in its own source — the exact defect that broke verify-source in build ea9bad30", () => {
  assert.ok(
    !/spawnSync\(\s*["']git["']|execFileSync\(\s*["']git["']|execSync\(\s*["']git/.test(THIS_TEST_FILE_TEXT),
    "this test file must never spawn a git process — git is not present on the node:20.18.1-bookworm-slim image verify-source runs it on, and .git is excluded from the Cloud Build source archive regardless"
  );
});

test("this correction introduced no environment-dependent conditional test exclusion of any kind — every resolver test always runs and always asserts real behavior; process.execPath is used precisely so that no availability probe or conditional guard is ever needed", () => {
  // A conditional exclusion based on tool availability (the exact
  // anti-pattern this correction explicitly rejects) would surface as
  // one of a small number of Node test-runner option/method spellings.
  // This check excludes ITS OWN source lines from the scan (this test
  // necessarily discusses those spellings, so a naive whole-file scan
  // would self-match its own prose — a real trap this test itself
  // tripped over while being written, which is exactly why the
  // exclusion below exists rather than rewording around it forever).
  const ownTestNameFragment = "this correction introduced no environment-dependent conditional test exclusion";
  const bodyStart = THIS_TEST_FILE_TEXT.indexOf(ownTestNameFragment);
  const bodyEnd = THIS_TEST_FILE_TEXT.indexOf("\n});", bodyStart) + 4;
  const scanned = THIS_TEST_FILE_TEXT.slice(0, bodyStart) + THIS_TEST_FILE_TEXT.slice(bodyEnd);
  assert.ok(!/\{\s*skip\s*:/.test(scanned), "no test elsewhere in this file may declare a skip option");
  assert.ok(!/\.skip\(/.test(scanned), "no test elsewhere in this file may call the skip method");
  assert.ok(!/\btodo\s*:/.test(scanned), "no test elsewhere in this file may declare a todo option");
  // Sanity: confirm the actual resolver tests are real `test(...)`
  // calls that will run and assert, not accidentally excluded — a
  // representative sample, not exhaustive.
  assert.ok(THIS_TEST_FILE_TEXT.includes('test("resolveCandidateTrafficEntry.js (spawned via process.execPath): the REAL captured traffic structure'));
});

// NOTE: an earlier version of this correction included a test here that
// read the repo-root .gcloudignore file (two levels up from REPO_ROOT) to
// confirm both resolver files are included in the Cloud Build upload set.
// That test was REMOVED after local Docker reproduction (mirroring the
// real verify-source environment) proved it can never pass inside the
// actual pipeline: .gcloudignore governs what gets uploaded to
// /workspace, and under its own allowlist rules (`/*` then
// `!/services/compliance-scanner`), .gcloudignore itself is NOT part of
// the set it governs — so it is never present at the uploaded source
// root, in Cloud Build or in any faithful local reproduction of it. This
// was a genuine test design defect (assuming file content available at
// runtime that is structurally excluded by design), not an
// environment-dependent skip: the check has been moved out of this
// runtime test suite entirely and is instead performed as a manual,
// local, pre-submission verification (`gcloud meta list-files-for-upload`
// against the repo root), which is where such a check belongs — outside
// the uploaded source itself. See the final report for this correction's
// manual re-confirmation of that command's output.

test("promote.sh: the resolved CANDIDATE_REVISION is the exact value passed into the promotion traffic-shift command (--to-revisions) and every subsequent verification/critical-failure message — never re-derived or separately fetched", () => {
  const text = scriptText("promote.sh");
  assert.ok(text.includes('--to-revisions="${CANDIDATE_REVISION}=100"'), "the promotion shift must target the resolved CANDIDATE_REVISION");
  assert.ok(text.includes('t.revisionName === candidateRevision'), "post-promotion verification must compare traffic entries against the resolved CANDIDATE_REVISION (traffic-array-ordering correction — see that section's own tests for the full behavioral proof)");
  assert.ok(text.includes('SERVING_IMAGE=$(gcloud run revisions describe "$CANDIDATE_REVISION"'), "digest verification must describe the resolved CANDIDATE_REVISION directly, never a separately re-derived 'serving revision'");
  assert.ok(text.includes('echo "# Candidate revision: ${CANDIDATE_REVISION} (digest ${DIGEST})" >&2'), "critical_terminal_failure must report the resolved CANDIDATE_REVISION");
  // Only ONE assignment to CANDIDATE_REVISION exists in the whole file
  // — no second, later reassignment that could silently diverge from
  // the resolved value.
  const assignments = (text.match(/^CANDIDATE_REVISION=/gm) || []).length;
  assert.equal(assignments, 1, "CANDIDATE_REVISION must be assigned exactly once in the entire file");
});

// ---------------------------------------------------------------------
// Traffic-array-ordering correction (closing a real staging failure —
// build c2fdcda9-1b0a-4e88-8f90-760a6ad32a5b, step promote:
// "PROMOTION VERIFICATION FAILED", despite the just-promoted
// revision's own digest and runtime SA both being independently
// confirmed correct). Root cause: the previous post-promotion
// verification read `status.traffic[0].revisionName`/`.percent` — a
// fixed numeric array index — to identify the serving revision.
// Cloud Run's API does not guarantee the newly-100%-revision appears
// at index 0 once other tagged, zero-percent entries also exist.
// Replaced with a full-array, semantic-identity check (exactly one
// entry at 100% matching CANDIDATE_REVISION, no other entry with
// positive traffic), via a small inline Node block — extracted here
// verbatim and BEHAVIORALLY RUN (never a reimplementation) against
// fabricated traffic-array shapes, including the exact real shape
// that build c2fdcda9 hit: 5 pre-existing tagged candidates plus the
// newly-promoted revision, with the 100% entry LAST in the array, not
// first.
//
// Note: the SEPARATE, pre-existing rollback-verification block
// (RESTORED_OK, further below) was audited and found to ALREADY be
// order-independent — it parses the complete status.traffic array and
// checks that every entry in the expected PREVIOUS_TO_REVISIONS
// allocation has a matching entry in the actual restored allocation
// (and vice versa, via a length check), never touching a fixed index.
// It is therefore left completely unchanged by this correction — see
// the "rollback verification remains order-independent" test below
// for the direct proof.
// ---------------------------------------------------------------------

function extractPromotionTrafficVerificationBlock() {
  const text = scriptText("promote.sh");
  const match = text.match(/PROMOTION_OK=1\nif ! PROMOTION_TRAFFIC_CHECK=\$\(node -e '[\s\S]*?\n' -- "\$SERVING_TRAFFIC_JSON" "\$CANDIDATE_REVISION" 2>&1\); then\n  PROMOTION_OK=0\n  echo "promotion traffic verification failed: \$\{PROMOTION_TRAFFIC_CHECK\}" >&2\nfi\n/);
  assert.ok(match, "could not extract the promotion traffic verification block from promote.sh");
  return match[0];
}

function runPromotionTrafficVerification({ trafficJson, candidateRevision }) {
  const block = extractPromotionTrafficVerificationBlock();
  return spawnSync("sh", ["-c", `set -eu\n${block}\necho "RESULT_PROMOTION_OK=$PROMOTION_OK"`], {
    env: { ...process.env, SERVING_TRAFFIC_JSON: trafficJson, CANDIDATE_REVISION: candidateRevision },
    encoding: "utf8",
  });
}

function promotionOkFrom(result) {
  const m = result.stdout.match(/RESULT_PROMOTION_OK=(\d)/);
  assert.ok(m, `expected to find RESULT_PROMOTION_OK in stdout, got: ${JSON.stringify(result)}`);
  return m[1];
}

const CANDIDATE_REVISION_FOR_TESTS = "compliance-scanner-00007-xew";

test("promotion traffic verification: succeeds for the EXACT real failing shape from build c2fdcda9 — 5 pre-existing tagged candidates at 0%, plus the candidate at 100%, with the 100% entry LAST in the array (not first) — proving the fix genuinely closes the reported defect, not merely a simplified reproduction of it", () => {
  const trafficJson = JSON.stringify({
    status: {
      traffic: [
        { revisionName: "compliance-scanner-00003-wof", tag: "candidate-580e47e8-aa407156" },
        { revisionName: "compliance-scanner-00004-lix", tag: "candidate-2775ab3d-f3caf298" },
        { revisionName: "compliance-scanner-00005-bij", tag: "candidate-f5c9e1f6-9cb468c3" },
        { revisionName: "compliance-scanner-00006-qaf", tag: "candidate-baed6d70-8b35480c" },
        { revisionName: CANDIDATE_REVISION_FOR_TESTS, tag: "candidate-27cec0d1-c2fdcda9", percent: 100 },
      ],
    },
  });
  const result = runPromotionTrafficVerification({ trafficJson, candidateRevision: CANDIDATE_REVISION_FOR_TESTS });
  assert.equal(promotionOkFrom(result), "1", `expected verification to pass, got: ${JSON.stringify(result)}`);
});

test("promotion traffic verification: also succeeds when the SAME valid allocation is given in a different (fully reordered) sequence — proving the check is genuinely order-independent, not merely tolerant of one specific non-zero index", () => {
  const trafficJson = JSON.stringify({
    status: {
      traffic: [
        { revisionName: CANDIDATE_REVISION_FOR_TESTS, tag: "candidate-27cec0d1-c2fdcda9", percent: 100 },
        { revisionName: "compliance-scanner-00006-qaf", tag: "candidate-baed6d70-8b35480c" },
        { revisionName: "compliance-scanner-00003-wof", tag: "candidate-580e47e8-aa407156" },
        { revisionName: "compliance-scanner-00005-bij", tag: "candidate-f5c9e1f6-9cb468c3" },
        { revisionName: "compliance-scanner-00004-lix", tag: "candidate-2775ab3d-f3caf298" },
      ],
    },
  });
  const result = runPromotionTrafficVerification({ trafficJson, candidateRevision: CANDIDATE_REVISION_FOR_TESTS });
  assert.equal(promotionOkFrom(result), "1", `expected verification to pass regardless of order, got: ${JSON.stringify(result)}`);
});

test("promotion traffic verification: fails closed when ZERO traffic entries match the candidate revision at all", () => {
  const trafficJson = JSON.stringify({
    status: { traffic: [{ revisionName: "compliance-scanner-00002-h9h", percent: 100 }] },
  });
  const result = runPromotionTrafficVerification({ trafficJson, candidateRevision: CANDIDATE_REVISION_FOR_TESTS });
  assert.equal(promotionOkFrom(result), "0");
  assert.ok(result.stderr.includes("found 0"), `expected a zero-match diagnostic, got: ${result.stderr}`);
});

test("promotion traffic verification: fails closed when the candidate is present but BELOW 100% (a partial/interrupted shift)", () => {
  const trafficJson = JSON.stringify({
    status: {
      traffic: [
        { revisionName: CANDIDATE_REVISION_FOR_TESTS, percent: 50 },
        { revisionName: "compliance-scanner-00002-h9h", percent: 50 },
      ],
    },
  });
  const result = runPromotionTrafficVerification({ trafficJson, candidateRevision: CANDIDATE_REVISION_FOR_TESTS });
  assert.equal(promotionOkFrom(result), "0");
  assert.ok(result.stderr.includes("found 0"), `a 50% candidate must not count as the required 100% match, got: ${result.stderr}`);
});

test("promotion traffic verification: fails closed when the candidate correctly holds 100% but ANOTHER revision also has positive traffic (an impossible-in-theory but must-still-be-caught split)", () => {
  const trafficJson = JSON.stringify({
    status: {
      traffic: [
        { revisionName: CANDIDATE_REVISION_FOR_TESTS, percent: 100 },
        { revisionName: "compliance-scanner-00002-h9h", percent: 1 },
      ],
    },
  });
  const result = runPromotionTrafficVerification({ trafficJson, candidateRevision: CANDIDATE_REVISION_FOR_TESTS });
  assert.equal(promotionOkFrom(result), "0");
  assert.ok(result.stderr.includes("unexpected additional positive-traffic entries"), `expected an 'other positive traffic' diagnostic, got: ${result.stderr}`);
});

test("promotion traffic verification: fails closed on DUPLICATE candidate entries (two array entries both claiming the candidate revision at 100%) — a malformed API response this check must not silently accept as 'close enough'", () => {
  const trafficJson = JSON.stringify({
    status: {
      traffic: [
        { revisionName: CANDIDATE_REVISION_FOR_TESTS, percent: 100 },
        { revisionName: CANDIDATE_REVISION_FOR_TESTS, percent: 100 },
      ],
    },
  });
  const result = runPromotionTrafficVerification({ trafficJson, candidateRevision: CANDIDATE_REVISION_FOR_TESTS });
  assert.equal(promotionOkFrom(result), "0");
  assert.ok(result.stderr.includes("found 2"), `expected a duplicate-match diagnostic, got: ${result.stderr}`);
});

test("promotion traffic verification: fails closed on malformed/missing traffic data — invalid JSON, missing status.traffic, and status.traffic present but not an array", () => {
  const cases = [
    "{not valid json",
    JSON.stringify({ status: {} }),
    JSON.stringify({ status: { traffic: "not-an-array" } }),
    JSON.stringify({}),
  ];
  for (const trafficJson of cases) {
    const result = runPromotionTrafficVerification({ trafficJson, candidateRevision: CANDIDATE_REVISION_FOR_TESTS });
    assert.equal(promotionOkFrom(result), "0", `expected failure for malformed input: ${trafficJson}`);
  }
});

test("promotion traffic verification: no executable status.traffic[0] (or any other fixed numeric index) lookup remains anywhere in promote.sh — the file's own correction comment legitimately quotes the old index-based reads once, as history", () => {
  const text = scriptText("promote.sh");
  assert.ok(
    !nonCommentLines(text).some((l) => /status\.traffic\[\d+\]/.test(l)),
    "no executable line in promote.sh may reference a fixed numeric status.traffic index"
  );
  assert.ok(!nonCommentLines(text).some((l) => l.includes("SERVING_REVISION")), "the old SERVING_REVISION variable must be fully removed — the resolved CANDIDATE_REVISION is now used directly");
});

test("promotion traffic verification: introduces no jq, no additional Python usage, and no new file — it is a small inline Node block, using the interpreter and image this step already required for the candidate resolver and the fenced lease check", () => {
  const text = scriptText("promote.sh");
  assert.ok(!nonCommentLines(text).some((l) => /\bjq\b/.test(l)), "promote.sh must never invoke jq");
  // The two PRE-EXISTING python3 -c blocks (PREVIOUS_TO_REVISIONS
  // reconstruction and RESTORED_OK rollback verification) are
  // unrelated to this correction and must remain exactly as many as
  // before — never a third, new python3 usage introduced for the
  // promotion-traffic check itself.
  const python3Invocations = (text.match(/python3 -c "/g) || []).length;
  assert.equal(python3Invocations, 2, "exactly the two pre-existing python3 -c blocks must remain — no new Python usage introduced");
});

test("rollback verification (RESTORED_OK) remains order-independent and is completely UNCHANGED by this correction — it already parses the full status.traffic array and matches every expected PREVIOUS_TO_REVISIONS entry against the actual restored allocation by (revisionName, percent) identity, with a length check to also catch extras, never touching a fixed array index", () => {
  const text = scriptText("promote.sh");
  const restoredBlockMatch = text.match(/RESTORED_OK=\$\(python3 -c "\n([\s\S]*?)\n" "\$RESTORED"\)/);
  assert.ok(restoredBlockMatch, "could not locate the RESTORED_OK python3 block");
  const restoredBody = restoredBlockMatch[1];
  assert.ok(!/traffic\[0\]|actual\[0\]|data\[0\]/.test(restoredBody), "the rollback-verification body must never index into the traffic array by a fixed position");
  assert.ok(restoredBody.includes("for t in (data.get('status') or {}).get('traffic') or []"), "must still scan the COMPLETE traffic array, not a single element");
  assert.ok(restoredBody.includes("all(any(a['revisionName'] == e['revisionName'] and a['percent'] == e['percent'] for a in actual) for e in expected)"), "must still match every expected entry against the actual array by semantic identity, order-independent");
  assert.ok(restoredBody.includes("len(actual) == len(expected)"), "must still reject an actual allocation with extra/unexpected entries, not just missing ones");
});

test("promote.sh: pre-promotion traffic capture (PREVIOUS_TO_REVISIONS, the full captured allocation) is unchanged by this correction — still reconstructed from /workspace/.previous-traffic-allocation.json, still refuses to promote without a provable rollback target", () => {
  const text = scriptText("promote.sh");
  assert.ok(text.includes("/workspace/.previous-traffic-allocation.json"), "must still read the full captured allocation deploy-candidate.sh wrote");
  assert.ok(text.includes("no prior traffic allocation captured — refusing to promote without a provable rollback target"), "must still fail closed with no captured allocation");
  assert.ok(text.includes('PREVIOUS_TO_REVISIONS=$(python3 -c "'), "the reconstruction must still use the existing python3 -c block, unchanged");
});

test("promote.sh: rollback still reconstructs and restores the COMPLETE original traffic allocation (never a simplified single-revision guess), and rollback verification (RESTORED_OK) remains mandatory", () => {
  const text = scriptText("promote.sh");
  assert.ok(text.includes('--to-revisions="${PREVIOUS_TO_REVISIONS}"'), "rollback must restore the full captured allocation, unchanged");
  assert.ok(text.includes("RESTORED_OK"), "rollback verification (RESTORED_OK) must still exist, unchanged");
  assert.ok(text.includes('if [ "$RESTORED_OK" != "true" ]'), "a rollback that did not verifiably restore traffic must still be treated as critical, unchanged");
});

test("promote.sh: lease renewal still occurs immediately before EACH of the three real mutations (promotion shift, conditional rollback shift, promoted-tag mutation) — unchanged, still three separate fence checks, none inherited from the candidate-resolution step above (which performs no mutation and does not renew the lease at all)", () => {
  const text = scriptText("promote.sh");
  const renewalCount = (text.match(/renew-lease-or-fail\.sh/g) || []).length;
  assert.ok(renewalCount >= 3, `expected at least 3 renewal calls, found ${renewalCount} (unchanged from before this correction)`);
  // The candidate-resolution block itself must never call the lease
  // renewal script — it is read-only and must not be treated as, or
  // confused with, a fenced mutating phase.
  const resolutionBlock = extractPromoteCandidateResolutionBlock();
  assert.ok(!resolutionBlock.includes("renew-lease-or-fail"), "candidate resolution must not renew the lease itself — it is read-only, unlike the three real mutations below it");
});

test("promote.sh: candidate-resolution failure occurs strictly before the first lease renewal and the first traffic mutation — the resolution block is fully textually positioned before 'sh ci/renew-lease-or-fail.sh' and before 'gcloud run services update-traffic'", () => {
  const text = scriptText("promote.sh");
  const resolutionEndIndex = text.indexOf('[ -n "$CANDIDATE_REVISION" ] || { echo "could not resolve candidate revision name"; exit 1; }');
  const firstRenewIndex = text.indexOf("sh ci/renew-lease-or-fail.sh");
  const firstMutationIndex = text.indexOf("gcloud run services update-traffic");
  assert.ok(resolutionEndIndex !== -1 && firstRenewIndex !== -1 && firstMutationIndex !== -1);
  assert.ok(resolutionEndIndex < firstRenewIndex, "candidate resolution must complete before the first lease renewal");
  assert.ok(resolutionEndIndex < firstMutationIndex, "candidate resolution must complete before the first traffic mutation");
});

test("promote.sh: the promoted Artifact Registry tag block is completely unaffected by this correction — still uses the full COMMIT_SHA/BUILD_ID, still gated behind its own third, independent lease renewal, still runs only after traffic promotion is already verified serving", () => {
  const text = scriptText("promote.sh");
  assert.ok(text.includes('PROMOTED_TAG="promoted-${COMMIT_SHA:?COMMIT_SHA is required}-${BUILD_ID:?BUILD_ID is required}"'), "promoted tag construction must be unchanged");
  assert.ok(text.includes("gcloud artifacts docker tags add"), "the promoted-tag mutation must still exist, unchanged");
  const promotedTagIndex = text.indexOf('PROMOTED_TAG="promoted-');
  const lastRenewIndex = text.lastIndexOf("renew-lease-or-fail.sh");
  assert.ok(lastRenewIndex < promotedTagIndex, "the third, independent lease renewal must still precede the promoted-tag mutation");
});

test("promote.sh: no public-access or IAM behavior is introduced or changed by this correction — the file still contains no --allow-unauthenticated anywhere, and still never touches IAM policy bindings", () => {
  const text = scriptText("promote.sh");
  assert.ok(!/--allow-unauthenticated/.test(text), "promote.sh must never reference --allow-unauthenticated");
  assert.ok(!/set-iam-policy|add-iam-policy-binding|remove-iam-policy-binding/.test(text), "promote.sh must never touch IAM policy bindings");
});

// =======================================================================
// Read-only review, second pass — Corrections A, B, C, D
// =======================================================================

// ---------------------------------------------------------------------
// Correction A — acquire-lock.sh no longer masks acquisition failure
// behind `| tee`.
// ---------------------------------------------------------------------

test("Correction A: acquire-lock.sh no longer contains the unsafe `| tee` pattern on any executable line (the file's own comments legitimately quote the old pattern for documentation)", () => {
  const text = scriptText("acquire-lock.sh");
  assert.ok(
    !nonCommentLines(text).some((l) => /\|\s*tee\b/.test(l)),
    "acquire-lock.sh must not pipe the acquire command into tee on any real command line"
  );
});

test("Correction A: acquire-lock.sh checks the acquire command's own exit status directly via `if !`, with stdout/stderr redirected to separate files (not piped)", () => {
  const text = scriptText("acquire-lock.sh");
  assert.ok(/if ! node ci\/signatureRefreshLock\.js acquire/.test(text));
  assert.ok(/>\s*"\$ACQUIRE_STDOUT"\s+2>"\$ACQUIRE_STDERR"/.test(text));
});

test("Correction A: the failure branch appears BEFORE the JSON-parsing line, and exits before it can ever be reached on failure", () => {
  const text = scriptText("acquire-lock.sh");
  const ifIndex = text.indexOf("if ! node ci/signatureRefreshLock.js acquire");
  const exitIndex = text.indexOf("exit 1", ifIndex);
  const parseIndex = text.indexOf("JSON.parse");
  assert.ok(ifIndex !== -1 && exitIndex !== -1 && parseIndex !== -1);
  assert.ok(ifIndex < exitIndex && exitIndex < parseIndex, "acquire-lock.sh must exit on failure strictly before the JSON-parse line");
});

test("Correction A: the meaningful stderr reason is preserved and printed on failure", () => {
  const text = scriptText("acquire-lock.sh");
  assert.ok(/cat "\$ACQUIRE_STDERR" >&2/.test(text), "acquire-lock.sh must print the captured stderr on failure");
});

test("Correction A: /workspace/.lock-result.json is written ONLY via `mv` after a confirmed-successful acquisition — never as a direct redirect target that could contain partial output", () => {
  const text = scriptText("acquire-lock.sh");
  const directRedirects = text.match(/>\s*\/workspace\/\.lock-result\.json/g) || [];
  assert.deepEqual(directRedirects, [], "no direct `> .../.lock-result.json` redirect should exist — only the post-success mv");
  assert.ok(/mv "\$ACQUIRE_STDOUT" \/workspace\/\.lock-result\.json/.test(text));
});

test("Correction A: on failure, the temp stdout/stderr files are removed and no result/generation file is left behind", () => {
  const text = scriptText("acquire-lock.sh");
  const failureBlockMatch = text.match(/if ! node ci\/signatureRefreshLock\.js acquire[\s\S]*?fi\n/);
  assert.ok(failureBlockMatch, "could not locate the acquire failure-check block");
  const failureBlock = failureBlockMatch[0];
  assert.ok(/rm -f "\$ACQUIRE_STDOUT" "\$ACQUIRE_STDERR"/.test(failureBlock), "failure branch must clean up its own temp files");
});

test("Correction A behavioral simulation: a refused acquisition (exit 1, stderr-only) propagates exit 1, preserves the reason, and never creates a lock-result file — proven by running the ACTUAL corrected logic against a mock refusing 'node'", () => {
  const text = scriptText("acquire-lock.sh");
  // Extract the exact corrected acquire block from the real file so this
  // test exercises the real logic, not a hand-copied duplicate.
  const blockMatch = text.match(/ACQUIRE_STDOUT="[\s\S]*?\ncat \/workspace\/\.lock-result\.json\n/);
  assert.ok(blockMatch, "could not extract the acquire block from acquire-lock.sh");

  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "acquire-lock-sim-"));
  const workspace = path.join(tmpDir, "workspace");
  fs.mkdirSync(workspace);

  // A fake `node` on PATH that mimics signatureRefreshLock.js's own
  // refusal contract exactly: writes ONLY to stderr, exits 1, writes
  // nothing to stdout.
  const fakeNodeDir = path.join(tmpDir, "bin");
  fs.mkdirSync(fakeNodeDir);
  const fakeNodePath = path.join(fakeNodeDir, "node");
  fs.writeFileSync(
    fakeNodePath,
    '#!/bin/sh\necho \'signature-refresh-lock: refused to acquire — {"action":"refuse","reason":"live_lease_held"}\' >&2\nexit 1\n',
    { mode: 0o755 }
  );

  const script = `cd ${JSON.stringify(workspace)}\n${blockMatch[0].replace(/\/workspace\//g, "./")}`;
  const result = spawnSync("sh", ["-c", `set -eu\n${script}`], {
    env: {
      ...process.env,
      PATH: `${fakeNodeDir}:${process.env.PATH}`,
      // The extracted block references these directly in the node
      // command-line args; under `set -eu` an unset reference aborts
      // during word expansion before the fake `node` ever runs. The
      // real acquire-lock.sh guards these with `: "${VAR:?...}"` above
      // the extracted block, so this simulation must supply the same
      // preconditions the real script guarantees are already met.
      LOCK_BUCKET: "fake-lock-bucket",
      LOCK_OBJECT: "fake-lock-object",
      BUILD_ID: "fake-build-id",
      LOCK_LEASE_SECONDS: "60",
    },
    encoding: "utf8",
  });

  assert.equal(result.status, 1, `expected exit 1, got ${result.status}. stderr: ${result.stderr}`);
  assert.ok(result.stderr.includes("live_lease_held"), `stderr must preserve the real refusal reason, got: ${result.stderr}`);
  assert.ok(!fs.existsSync(path.join(workspace, ".lock-result.json")), ".lock-result.json must not exist after a refused acquisition");
});

// ---------------------------------------------------------------------
// Correction B — verify-deployed-candidate.sh no longer masks
// sha256sum failure behind `| awk`.
// ---------------------------------------------------------------------

test("Correction B: verify-deployed-candidate.sh no longer contains any `sha256sum ... | awk` pattern on any executable line (comments legitimately reference the old pattern for documentation)", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  assert.ok(
    !nonCommentLines(text).some((l) => /sha256sum[^\n]*\|\s*awk/.test(l)),
    "no real command line should pipe sha256sum into awk"
  );
});

test("Correction B: both SHA1/SHA2 assignments now use the sha256_of helper and fail closed via `|| exit 1`", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  assert.ok(/SHA1="\$\(sha256_of \/tmp\/v1\.bin\)" \|\| exit 1/.test(text));
  assert.ok(/SHA2="\$\(sha256_of \/tmp\/v2\.bin\)" \|\| exit 1/.test(text));
});

function extractSha256OfFunction() {
  const text = scriptText("verify-deployed-candidate.sh");
  const match = text.match(/sha256_of\(\) \{[\s\S]*?\n\}\n/);
  assert.ok(match, "could not extract sha256_of() from verify-deployed-candidate.sh");
  return match[0];
}

function runSha256Of(fnSource, arg) {
  return spawnSync("sh", ["-c", `${fnSource}\nsha256_of ${arg}`], { encoding: "utf8" });
}

test("Correction B behavioral: sha256_of, extracted from the real script, computes the correct digest for a real file", () => {
  const fnSource = extractSha256OfFunction();
  const tmpFile = path.join(os.tmpdir(), `sha256-of-test-${crypto.randomUUID()}.bin`);
  const content = "deterministic test content for sha256_of";
  fs.writeFileSync(tmpFile, content);
  const expected = crypto.createHash("sha256").update(content).digest("hex");

  const result = runSha256Of(fnSource, tmpFile);
  fs.rmSync(tmpFile, { force: true });

  assert.equal(result.status, 0, `expected exit 0, stderr: ${result.stderr}`);
  assert.equal(result.stdout.trim(), expected);
});

test("Correction B behavioral: sha256_of fails closed on a missing file, before any scanner request could be constructed", () => {
  const fnSource = extractSha256OfFunction();
  const result = runSha256Of(fnSource, "/nonexistent-path-for-sha256-of-test.bin");
  assert.notEqual(result.status, 0);
  assert.ok(result.stderr.includes("missing or unreadable"), `stderr: ${result.stderr}`);
  assert.equal(result.stdout.trim(), "", "no digest should be printed to stdout on failure");
});

test("Correction B behavioral: sha256_of fails closed when sha256sum produces empty output", () => {
  const fnSource = extractSha256OfFunction();
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "sha256-of-empty-"));
  const fakeBinDir = path.join(tmpDir, "bin");
  fs.mkdirSync(fakeBinDir);
  fs.writeFileSync(path.join(fakeBinDir, "sha256sum"), "#!/bin/sh\nexit 0\n", { mode: 0o755 }); // succeeds but prints nothing
  const realFile = path.join(tmpDir, "real.bin");
  fs.writeFileSync(realFile, "content");

  const result = spawnSync("sh", ["-c", `${fnSource}\nsha256_of ${realFile}`], {
    env: { ...process.env, PATH: `${fakeBinDir}:${process.env.PATH}` },
    encoding: "utf8",
  });
  assert.notEqual(result.status, 0);
  assert.ok(result.stderr.includes("empty output"), `stderr: ${result.stderr}`);
});

test("Correction B behavioral: sha256_of fails closed on a malformed (non-64-hex) digest — validated via a pure case pattern, no grep/pipe", () => {
  const fnSource = extractSha256OfFunction();
  assert.ok(!/echo "\$digest" \| grep/.test(fnSource), "digest validation must not use a grep pipe");
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "sha256-of-malformed-"));
  const fakeBinDir = path.join(tmpDir, "bin");
  fs.mkdirSync(fakeBinDir);
  // A fake sha256sum that "succeeds" but emits a garbage (too-short,
  // non-hex) digest — simulates corrupted/unexpected tool output.
  fs.writeFileSync(path.join(fakeBinDir, "sha256sum"), '#!/bin/sh\necho "not-a-real-digest  $1"\n', { mode: 0o755 });
  const realFile = path.join(tmpDir, "real.bin");
  fs.writeFileSync(realFile, "content");

  const result = spawnSync("sh", ["-c", `${fnSource}\nsha256_of ${realFile}`], {
    env: { ...process.env, PATH: `${fakeBinDir}:${process.env.PATH}` },
    encoding: "utf8",
  });
  assert.notEqual(result.status, 0);
  assert.ok(result.stderr.includes("malformed digest"), `stderr: ${result.stderr}`);
});

test("Correction B behavioral: sha256_of accepts a genuine 64-lowercase-hex digest even under an unusual but well-formed sha256sum output line", () => {
  const fnSource = extractSha256OfFunction();
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "sha256-of-valid-"));
  const fakeBinDir = path.join(tmpDir, "bin");
  fs.mkdirSync(fakeBinDir);
  const realHash = "a".repeat(64);
  fs.writeFileSync(path.join(fakeBinDir, "sha256sum"), `#!/bin/sh\necho "${realHash}  \\$1"\n`, { mode: 0o755 });
  const realFile = path.join(tmpDir, "real.bin");
  fs.writeFileSync(realFile, "content");

  const result = spawnSync("sh", ["-c", `${fnSource}\nsha256_of ${realFile}`], {
    env: { ...process.env, PATH: `${fakeBinDir}:${process.env.PATH}` },
    encoding: "utf8",
  });
  assert.equal(result.status, 0, `stderr: ${result.stderr}`);
  assert.equal(result.stdout.trim(), realHash);
});

// ---------------------------------------------------------------------
// Correction C — promote.sh fences the promoted-tag mutation with its
// own immediately-preceding renewal, not the earlier one.
// ---------------------------------------------------------------------

test("Correction C: promote.sh calls renew-lease-or-fail.sh at least THREE times (promotion shift, conditional rollback, promoted-tag mutation)", () => {
  const text = scriptText("promote.sh");
  const occurrences = text.split("renew-lease-or-fail.sh").length - 1;
  assert.ok(occurrences >= 3, `expected at least 3 renewal calls, found ${occurrences}`);
});

test("Correction C: a renewal call appears BETWEEN the promotion success message and the tag-add mutation, immediately before it", () => {
  const text = scriptText("promote.sh");
  const successIndex = text.indexOf('echo "promoted:');
  const renewBeforeTagMatch = text.slice(successIndex).match(/if ! sh ci\/renew-lease-or-fail\.sh; then/);
  const tagAddIndex = text.indexOf("gcloud artifacts docker tags add");
  assert.ok(successIndex !== -1 && renewBeforeTagMatch && tagAddIndex !== -1);
  const renewIndexAbsolute = successIndex + renewBeforeTagMatch.index;
  assert.ok(renewIndexAbsolute < tagAddIndex, "the renewal check must appear before the tag-add mutation");
  // And nothing else mutating sits between the renewal and the tag-add.
  const between = text.slice(renewIndexAbsolute, tagAddIndex);
  assert.ok(!/gcloud run services update-traffic/.test(between), "no other mutation should sit between the fence check and the tag-add");
});

test("Correction C: renewal failure immediately before the tag mutation exits non-zero and never reaches the tag-add command", () => {
  const text = scriptText("promote.sh");
  const block = text.match(/if ! sh ci\/renew-lease-or-fail\.sh; then\n([\s\S]*?)\nfi\n\n# Apply the stable/);
  assert.ok(block, "could not locate the pre-tag-add renewal-failure block");
  assert.ok(/exit 1/.test(block[1]), "the pre-tag-add renewal failure branch must exit 1");
});

test("Correction C: this specific renewal call's failure is never swallowed with `|| true` or similar", () => {
  const text = scriptText("promote.sh");
  const idx = text.indexOf('echo "promoted:');
  const segment = text.slice(idx, text.indexOf("gcloud artifacts docker tags add"));
  assert.ok(!/renew-lease-or-fail\.sh\s*\|\|\s*true/.test(segment));
});

test("Correction C: the tag-add mutation uses the CURRENT /workspace/.lock-generation implicitly via renew-lease-or-fail.sh (which always reads-then-overwrites that exact file) — never a separately cached/stale generation variable", () => {
  const text = scriptText("promote.sh");
  // promote.sh itself must not read .lock-generation into its own local
  // variable and pass it explicitly anywhere near the tag-add — the
  // renewal script is the sole owner of that file's read/write cycle.
  assert.ok(!/HELD_GENERATION.*lock-generation[\s\S]*gcloud artifacts docker tags add/.test(text));
});

test("Correction C: existing promotion-shift and rollback fencing are unchanged (still present, still ordered correctly) — this correction only ADDS a third fence, never weakens the first two", () => {
  const text = scriptText("promote.sh");
  const firstRenewIndex = text.indexOf("renew-lease-or-fail.sh");
  const promotionShiftIndex = text.indexOf("gcloud run services update-traffic");
  assert.ok(firstRenewIndex !== -1 && firstRenewIndex < promotionShiftIndex, "the original pre-promotion fence must still exist and precede the traffic shift");
  const rollbackRenewMatch = text.match(/Fenced AGAIN, separately[\s\S]*?renew-lease-or-fail\.sh/);
  assert.ok(rollbackRenewMatch, "the original pre-rollback fence must still exist");
});

// ---------------------------------------------------------------------
// Correction D — signatureRefreshLock.js's stale comment corrected,
// without changing runtime behavior.
// ---------------------------------------------------------------------

test("Correction D: signatureRefreshLock.js no longer claims to shell out to `gcloud storage`", () => {
  const text = fs.readFileSync(path.join(__dirname, "signatureRefreshLock.js"), "utf8");
  assert.ok(!/shelling out\s*\n?\s*\/\/\s*to `gcloud storage`/.test(text));
  assert.ok(!text.includes("shelling out to `gcloud storage`"));
});

test("Correction D: signatureRefreshLock.js's top comment accurately describes @google-cloud/storage with generation preconditions", () => {
  const text = fs.readFileSync(path.join(__dirname, "signatureRefreshLock.js"), "utf8");
  const topComment = text.slice(0, text.indexOf("const LOCK_SCHEMA_VERSION"));
  assert.ok(topComment.includes("@google-cloud/storage"));
  assert.ok(/ifGenerationMatch/.test(topComment) || /precondition/i.test(topComment));
});

test("Correction D: runtime behavior is unchanged — the CLI still uses @google-cloud/storage's Storage class and preconditionOpts, not the gcloud CLI binary, in the actual code (not just comments)", () => {
  const text = fs.readFileSync(path.join(__dirname, "signatureRefreshLock.js"), "utf8");
  assert.ok(text.includes('require("@google-cloud/storage")'));
  assert.ok(text.includes("preconditionOpts"));
  assert.ok(!/execFileSync\("gcloud"/.test(text), "no gcloud CLI shell-out should exist anywhere in this file");
});
