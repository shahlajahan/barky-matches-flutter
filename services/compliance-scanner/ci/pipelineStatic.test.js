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
const { spawnSync } = require("node:child_process");
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
// Builder-image assignment (Slice 2.2 final correction). Each step's
// actual `name:` image must match what that step's own script actually
// needs — proven per-step, not asserted only in a prose comment. The
// three genuinely combined-tool steps use the digest-pinned
// ci-builder image; every other step uses a single-purpose official
// image, pinned by the exact digest resolved during this review.
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
  "verify-deployed-candidate": CLOUD_SDK_IMAGE,
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

test("only the three genuinely combined-tool steps (push-candidate, deploy-candidate, promote) use the ci-builder image — every other step uses a single-purpose official image", () => {
  const usingCiBuilder = steps.filter((s) => s.name === CI_BUILDER_IMAGE).map((s) => s.id).sort();
  assert.deepEqual(usingCiBuilder, ["deploy-candidate", "promote", "push-candidate"]);
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

  const cloudSdkOnlySteps = ["resolve-digest.sh", "verify-deployed-candidate.sh"];
  for (const fname of cloudSdkOnlySteps) {
    const text = scriptText(fname);
    assert.ok(!invokesCommand(text, "docker"), `${fname} (cloud-sdk-only image) must not invoke docker`);
    assert.ok(!invokesCommand(text, "node"), `${fname} (cloud-sdk-only image) must not invoke node`);
  }
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
// ID-token audience correctness (Slice 2.2 final correction). Per
// https://docs.cloud.google.com/run/docs/authenticating/service-to-service:
// "the aud value must remain as the URL of the service, even when
// making requests to a specific traffic tag." CANDIDATE_URL is the
// HTTP request target; BASE_SERVICE_URL is the token audience — two
// separate variables, neither derived from the other.
// ---------------------------------------------------------------------

test("verify-deployed-candidate.sh declares CANDIDATE_URL and BASE_SERVICE_URL as two separate variables, from two separate gcloud describe calls", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  assert.ok(/CANDIDATE_URL=\$\(gcloud run services describe/.test(text));
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

test("both CANDIDATE_URL and BASE_SERVICE_URL fail closed (explicit non-empty check + exit) if gcloud resolves them to empty", () => {
  const text = scriptText("verify-deployed-candidate.sh");
  assert.ok(/\[ -n "\$CANDIDATE_URL" \] \|\| \{ echo[^}]*exit 1; \}/.test(text), "CANDIDATE_URL must fail closed if empty");
  assert.ok(/\[ -n "\$BASE_SERVICE_URL" \] \|\| \{ echo[^}]*exit 1; \}/.test(text), "BASE_SERVICE_URL must fail closed if empty");
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
