# Marketplace P1-A Slice 2.1 — compliance-scanner deployment readiness

Documentation only. No command in this file has been executed. Every
`gcloud`/`firebase` command below is a future action requiring explicit
authorization — this document exists so that authorization, when
granted, can be executed precisely and in the right order, not so it can
be run now.

Baseline this document assumes (verified read-only during Slice 2.1):
project `barkymatches-new` (#188282684447), region `europe-west3`,
compliance bucket `barkymatches-new.firebasestorage.app` (single-region,
`EUROPE-WEST3`), all required APIs already enabled (`run`,
`artifactregistry`, `cloudbuild`, `eventarc`, `cloudfunctions`,
`storage`, `secretmanager`, `iam`, `logging`, `monitoring`), no existing
custom Cloud Run service, no existing dedicated service accounts for
this feature, `vpcaccess.googleapis.com` not enabled (no VPC connector
exists or is required by this design).

## 1. Artifact Registry repository

```
gcloud artifacts repositories create compliance-scanner \
  --repository-format=docker \
  --location=europe-west3 \
  --project=barkymatches-new \
  --description="Petsupo Marketplace P1-A compliance-scanner images"
```

## 2. Service accounts

```
gcloud iam service-accounts create compliance-functions-sa \
  --project=barkymatches-new \
  --display-name="Compliance Functions runtime identity (Marketplace P1-A)"

gcloud iam service-accounts create compliance-scanner-sa \
  --project=barkymatches-new \
  --display-name="compliance-scanner Cloud Run runtime identity (Marketplace P1-A)"
```

## 3. IAM bindings

Scanner invocation restricted to exactly one identity — never public:

```
gcloud run services add-iam-policy-binding compliance-scanner \
  --region=europe-west3 \
  --project=barkymatches-new \
  --member="serviceAccount:compliance-functions-sa@barkymatches-new.iam.gserviceaccount.com" \
  --role="roles/run.invoker"
```

Explicitly confirm `allUsers`/`allAuthenticatedUsers` hold NO binding on
this service (contrast with the project's existing `onCall` functions,
where a public `run.invoker` binding is correct because auth is enforced
in-application — that pattern must NOT be copied here):

```
gcloud run services get-iam-policy compliance-scanner \
  --region=europe-west3 --project=barkymatches-new
```

Prefix-scoped, read-only object access for the scanner identity (GCS IAM
Conditions on `resource.name.startsWith(...)`) — read-only, and scoped to
the quarantine prefix only, never `compliance_docs/`:

```
gcloud storage buckets add-iam-policy-binding \
  gs://barkymatches-new.firebasestorage.app \
  --member="serviceAccount:compliance-scanner-sa@barkymatches-new.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer" \
  --condition='expression=resource.name.startsWith("projects/_/buckets/barkymatches-new.firebasestorage.app/objects/compliance_quarantine/"),title=compliance-quarantine-read-only'
```

Assign the dedicated runtime identity to the four compliance Functions
at deploy time (Firebase Functions v2 accepts a `serviceAccount` option
per export — this changes `functions/index.js`'s existing export
configs, a code change, not something this document executes):

```js
// Future functions/index.js change (not made in Slice 2.1):
exports.createComplianceUploadSession = onCall(
  { region: "europe-west3", serviceAccount: "compliance-functions-sa@barkymatches-new.iam.gserviceaccount.com" },
  ...
);
// ...same serviceAccount option added to processComplianceQuarantineUpload,
// complianceUploadOrphanCleanup, complianceUploadReconciliation.
```

Deployment identity (human/CI, never a long-lived key) needs
`roles/run.developer`, `roles/artifactregistry.writer`, and
`roles/iam.serviceAccountUser` on both new service accounts to deploy as
them — granted to whichever CI identity or authorized operator account
performs the deploy, not documented as a specific principal here.

### 3a. IAM boundary — what it proves and what it cannot (Slice 2.1 correction, part F)

Stated explicitly, not left implicit:

- **This codebase cannot validate IAM locally.** Nothing in
  `services/compliance-scanner`'s code or test suite exercises Cloud
  Run's own IAM enforcement — `server.js` deliberately implements zero
  application-level authentication (see its own doc comment) precisely
  because that boundary is Cloud Run's job, not this container's. That
  also means this container's tests cannot prove the boundary works;
  only a real deployment can.
- **Staging must prove it, not assume it.** Before any production
  traffic, the staging verification plan must include: an
  unauthenticated request to the deployed Cloud Run URL receiving
  `401`/`403` (Cloud Run's own rejection, before the container is ever
  invoked — confirm via Cloud Run request logs showing zero container
  start for that request), and a request bearing a valid ID token for
  some OTHER, non-`compliance-functions-sa` identity also being rejected.
  Only after both are proven does a request from the real
  `compliance-functions-sa` identity get tried.
- **The scanner still validates everything itself, even though IAM
  already authenticated the caller.** `contract.js`'s bucket/prefix/
  path-traversal/generation/SHA-256/size checks, and `scanHandler.js`'s
  independent re-download-and-recompute, all run unconditionally on
  every request — IAM proves *who* is calling, not that the call's
  *content* is trustworthy. Defense in depth, not redundancy: a
  compromised or buggy caller with valid IAM credentials still cannot
  make this service scan or promote something it wasn't supposed to.
- **`allUsers`/`allAuthenticatedUsers` must never hold `run.invoker`** on
  this service, at any point, for any reason — including temporarily
  "for testing". §3's verification command must be re-run after every
  IAM change to this service, not only at initial setup.
- **Only `compliance-functions-sa` ever receives `run.invoker`** on this
  service. No other identity, human or service account, is granted
  invocation rights as part of this design.
- **No application-level shared secret exists or is planned** — not a
  bearer token, not an API key, not a header-based secret. This is a
  deliberate choice (see `server.js`'s comment): a leaked shared secret
  would be a strictly worse, harder-to-rotate boundary than IAM, and
  maintaining two overlapping auth mechanisms is more attack surface,
  not less.

## 4. Cloud Run deployment

```
gcloud run deploy compliance-scanner \
  --project=barkymatches-new \
  --region=europe-west3 \
  --image=europe-west3-docker.pkg.dev/barkymatches-new/compliance-scanner/compliance-scanner:<TAG> \
  --service-account=compliance-scanner-sa@barkymatches-new.iam.gserviceaccount.com \
  --no-allow-unauthenticated \
  --cpu=2 \
  --memory=4Gi \
  --concurrency=1 \
  --min-instances=0 \
  --max-instances=2 \
  --cpu-boost \
  --timeout=120s \
  --set-env-vars="COMPLIANCE_BUCKET_NAME=barkymatches-new.firebasestorage.app,CLAMD_SCAN_TIMEOUT_MS=45000"
```

`minInstances=0` is the deliberate Slice 2.1 cost decision — see §15.
Raising to `minInstances=1` is a later operational option, not a default,
and requires the two preconditions in §15 to be satisfied first.

### 4a. Cloud Run writable filesystem and capabilities — local Docker parity is NOT proven (Slice 2.1 review corrections 2 & 3)

Stated explicitly, not left implicit: the local Docker verification that
passed during Slice 2.1 proved the container's own process/permission
model is internally consistent under a specific, deliberately hardened
**local Docker** posture. It did **not** prove anything about how Cloud
Run's own container runtime enforces that same posture — Cloud Run is
not "Docker with different flags"; some of the flags below have no Cloud
Run equivalent at all, and this must be verified against the real
platform during staging, never assumed from local success.

**What the local test actually verified.** The container was run with
`docker run --read-only`, a tmpfs mount at `/tmp`, and a tmpfs mount at
`/var/run/clamav` — i.e. the entire root filesystem was read-only
*except* those two explicitly-provided in-memory mounts, and the
container started, clamd initialized, and a scan completed successfully
under that posture. This is meaningful evidence that the image's runtime
writes are correctly confined to exactly those two paths (see the
Dockerfile's own "Root filesystem expectation" comment) — but it is
evidence about the **image**, not a proof about **Cloud Run**.

**`docker run --tmpfs` is not itself a Cloud Run deployment command.**
Cloud Run does not accept Docker's `--read-only` / `--tmpfs` flags
verbatim; whatever mechanism Cloud Run actually exposes for a read-only
root filesystem and in-memory writable mounts (if it exposes one at
all, for the execution environment this service ends up deployed under)
has a different name, different flags/API fields, and possibly different
semantics or size limits. **The staging verification plan must
explicitly re-derive and confirm, against current official Cloud Run
documentation at the time of staging, which paths are actually writable
under Cloud Run's container filesystem model for the selected execution
environment** — do not assume the local Docker result transfers
unchanged.

**If Cloud Run enforces a read-only root filesystem for this service's
configuration**, then before any traffic is routed to it, staging must
confirm all of the following, as concretely observed facts about the
real deployed revision, not inferred from the local Docker run:

- Writable in-memory volumes/mounts exist for exactly the paths this
  image actually writes to at runtime: `/tmp` (the adapter's per-scan
  temp file and clamd's own scratch space) and `/var/run/clamav` (the
  clamd socket, PID file, and — per `docker/clamd.conf`'s `LogFile`
  directive — `/tmp/clamd.log`, which is under `/tmp` and therefore
  covered by the same mount, not a separate one).
- Mount ownership/permissions allow `clamd` (running as the `clamav`
  user per `clamd.conf`'s `User clamav` directive) to create its socket
  (`/var/run/clamav/clamd.sock`, `LocalSocketMode 660`,
  `LocalSocketGroup clamav`) and PID file, **and** allow the Node
  adapter (running as `node-adapter`, a supplementary member of the
  `clamav` group per the Dockerfile) to connect to that
  group-owned socket. A writable mount alone is not sufficient if its
  ownership doesn't match what `entrypoint.sh` and `clamd.conf` already
  assume — verify actual ownership/mode on the running Cloud Run
  instance, not just that the mount exists.
- These volumes are **ephemeral, in-memory, and scoped to a single
  container instance's lifetime** — nothing written to them may be
  treated as retained compliance evidence; the durable record of any
  scan is exclusively what Functions writes to Firestore/GCS via the
  existing `compliance_docs`/quarantine flow, never anything left inside
  the scanner container itself. This must remain true regardless of
  which Cloud Run writable-mount mechanism is actually used.
- **No GCS bucket, Cloud Storage FUSE mount, or host directory may be
  substituted as "the writable path" instead of an in-memory mount.**
  A durable or network-backed writable path here would silently expand
  this container's blast radius and audit surface beyond what Slice
  2.1's design assumes (the scanner has zero durable state by design —
  see `contract.js`/`scanHandler.js`) and must not be introduced as a
  workaround if the in-memory approach proves inconvenient to configure.
- **The exact `gcloud run deploy` flags or Cloud Run API fields needed
  to configure this are deliberately NOT specified in this document.**
  They must be looked up against current official Cloud Run
  documentation at the time staging actually happens — Cloud Run's
  configuration surface for this has changed across product iterations,
  and inventing or guessing a flag here would be worse than leaving it
  marked pending. **Staging verification pending: exact writable-volume
  configuration syntax for the execution environment selected at
  deploy time.**
- **Failure to provide the required writable runtime paths must
  surface as a startup or health-check failure, never as a clean scan
  result.** `entrypoint.sh` already fails outright (non-zero exit) if
  clamd's socket never appears within its 60s bound (see its own doc
  comment), and the Dockerfile's `HEALTHCHECK` polls `/healthz` — if
  Cloud Run's writable-mount configuration is wrong or missing, the
  correct, already-designed-for outcome is the container failing to
  become healthy and Cloud Run declining to route traffic to it, not a
  silent fallback to some other behavior. Staging must explicitly
  exercise this failure mode once (deploy with a deliberately wrong/
  missing mount, confirm the container fails health checks and receives
  no traffic) so this fail-closed behavior is proven, not assumed.

**Capabilities — CHOWN/SETUID/SETGID/DAC_OVERRIDE are a local Docker
test artifact, not a Cloud Run deployment requirement (correction 3).**
The local verification ran the container with `docker run --cap-drop
ALL`, then empirically re-added exactly the four capabilities
(`CHOWN`, `SETUID`, `SETGID`, `DAC_OVERRIDE`) that the entrypoint's
root-to-`clamav`/root-to-`node-adapter` privilege-drop sequence (see
`entrypoint.sh`'s own comment: `chown` on `/var/run/clamav`, then
`su-exec node-adapter` for the Node process, plus clamd's own internal
drop to the `clamav` user via `clamd.conf`'s `User clamav`) turned out
to actually need under a `--cap-drop ALL` starting posture. That is a
true and useful fact about **what this container's own startup sequence
does**, and it is the reason the local test could be run with `ALL`
capabilities dropped rather than the Docker default set — it is not,
and must not be presented as, a Cloud Run deployment configuration
requirement. **Cloud Run does not expose Docker-style `--cap-add`/
`--cap-drop` configuration in the same way** — its own container
security/sandboxing model (gVisor or an equivalent, depending on the
selected execution environment) governs what a container process can do
at a different layer, and there is no confirmed Cloud Run mechanism to
request "these four Linux capabilities and nothing else" the way a
local Docker run can.

Because of that mismatch, **the real Cloud Run staging test must prove
outcomes, not request capabilities**: that the entrypoint starts and
reaches its normal running state; that the required directories
(`/tmp`, `/var/run/clamav`) are writable to the processes that need
them; that the root-started entrypoint can still perform whatever
`chown`/user-switch operations `entrypoint.sh` and `clamd.conf` require
to initialize clamd and drop it to the `clamav` user; that the Node
adapter successfully starts as `node-adapter` (not root); and that the
resulting socket's ownership and mode are correct and connectable by
the adapter. All of that is externally observable from a successful
health check plus a successful end-to-end scan against the deployed
revision — none of it requires knowing which underlying capability
model Cloud Run used to make it possible.

**If Cloud Run's runtime restrictions turn out to prevent this exact
process/user-switching model** (for example, if the selected execution
environment disallows the root-starts-then-drops-privileges pattern
entirely), **the correct response is to redesign the container's
startup/user model** — e.g. restructuring what runs as which user, or
what needs to be prepared at build time instead of at container start —
**never to request privileged/elevated execution as a workaround.**
This does not weaken or supersede the local hardened Docker run
guidance above (`--read-only`, `--cap-drop ALL` plus the four
empirically-required capabilities, tmpfs mounts) as the correct
**local** verification posture — that guidance stands unchanged as the
baseline the image was actually built and tested against. It only means
Cloud Run's own equivalent, once verified, may end up expressed through
a different mechanism than Docker's flags, and that difference must be
resolved by adapting the deployment configuration (or, if necessary, the
container's own startup model) to whatever Cloud Run actually supports —
not by discovering during a production incident that an assumed-safe
local posture doesn't have a Cloud Run equivalent at all.

## 5. Scanner URL/audience configuration (Functions side)

```
firebase functions:config:set \
  --project=barkymatches-new \
  compliance.clamav_cloud_run_url="<the deployed Cloud Run service URL>" \
  compliance.clamav_cloud_run_audience="<the same URL, or an explicit audience>"
```

(Or, matching this repo's actual `defineString`-based convention rather
than the older `functions:config`, set `CLAMAV_CLOUD_RUN_URL` and
`CLAMAV_CLOUD_RUN_AUDIENCE` via the Functions v2 params mechanism at
deploy time — whichever matches the deploy pipeline actually in use.)

## 6. Daily signature-refresh build (Slice 2.2, corrected per adversarial review)

`services/compliance-scanner/cloudbuild.signature-refresh.yaml` now
exists — a definition only, never submitted, never triggered against
any project. It is environment-neutral (every project/region/
repository/service/service-account/bucket value is a substitution, no
literal `barkymatches-new` or any staging identifier anywhere in the
file) and implements a 10-stage sequence: acquire-lock →
verify-fixtures-integrity (mandatory security-fixture gate, runs in
parallel with build-candidate) → build-candidate → verify-source /
verify-candidate-container (parallel) → push-candidate → deploy-candidate
(zero-traffic, tagged) → verify-deployed-candidate → promote (with
self-contained fenced rollback) → release-lock. Each stage's logic lives
in its own narrowly-scoped, independently syntax-checked script under
`services/compliance-scanner/ci/`, not inline in the YAML.

### 6a. Verification-tier classification (Mandatory correction 6 — read before trusting any claim below)

Every claim about this pipeline falls into exactly one of four tiers.
Conflating them is the specific failure mode this section exists to
prevent:

- **Locally verified** (deterministic, run and passing on this
  machine, no live GCP dependency): the fenced-lease decision logic
  (`ci/signatureRefreshLock.test.js`), the fixture-manifest decision
  logic (`ci/fixtureManifest.test.js`), and the pipeline's own command
  construction/dependency-graph properties
  (`ci/pipelineStatic.test.js` — e.g. every mutating step's script
  calls lease renewal before its real mutation, no bare
  `--allow-unauthenticated` on any executable line, `.candidate-digest`
  is written in exactly one place from a fresh registry query, rollback
  reconstructs the full prior traffic allocation rather than assuming
  one revision).
- **Statically validated** (structurally checked, not executed):
  `cloudbuild.signature-refresh.yaml` parses as valid YAML and every
  embedded script passes `sh -n`/`node --check`; the Artifact Registry
  and GCS lifecycle JSON templates were checked field-by-field against
  the schemas documented at
  `docs.cloud.google.com/artifact-registry/docs/repositories/cleanup-policy`
  and `gcloud storage buckets update --help`'s own worked example
  respectively (this review caught and fixed two real schema errors —
  see the Slice 2.2 correction report). None of this proves the YAML is
  *accepted* by the real Cloud Build API, which validates more than
  local structural parsing can.
- **Requires staging execution** (design is complete and reviewed, but
  unproven without a real project): whether GCS generation-precondition
  writes are actually atomic under real concurrent load (the DECISION
  logic that USES that atomicity is locally proven; the atomicity
  itself is a GCS platform guarantee this repository does not
  re-verify); whether the chosen builder image
  (`_CI_BUILDER_IMAGE` substitution) actually provides `gcloud`,
  `docker`, and `node` together — NOT verified in this review, no
  network access was used to inspect any image's real contents, and no
  default is provided specifically so this is never silently assumed;
  whether Application Default Credentials are reachable from inside the
  nested Docker container `ci/verify-candidate-container.sh` starts
  (a known but non-trivial Cloud-Build-in-Docker pattern); the full
  end-to-end pipeline run itself.
- **Blocked** (identified, not resolved, requires a decision before
  this pipeline can run for real): none currently — the earlier
  "warn-and-skip" fixture gap and the earlier non-renewing 45-minute
  lease were both corrected into locally-verified/statically-validated
  designs, not left as approximations. The builder-image gap above is
  the closest remaining item to a blocker; it is a concrete
  prerequisite (build and publish a dedicated CI image, or confirm the
  stock `cloud-sdk` image suffices) rather than an unresolved design
  question.

**Never state, about this pipeline: that local YAML parsing proves
Cloud Build acceptance; that local lease tests prove live GCS atomic
behavior; that a tag alone (mutable, reassignable by anyone with write
access) protects a deployed digest — protection here is what the tag
currently points at, reinforced by every promoted digest getting its
own permanent, never-reused tag name rather than a moved/shared one
(see `ci/artifact-registry-cleanup-policy.template.json`'s own
"moved-tag risk" note); that a fixture check being present in the code
means it ran and passed on any given real execution — only that
execution's own logs prove that; or that commands appearing in the
correct order in a script proves the pipeline is safe — the ordering is
necessary, not sufficient, which is why `ci/pipelineStatic.test.js`
asserts the ordering AND the fencing AND the digest provenance AND the
rollback-completeness as separate, independently-failing checks rather
than inferring safety from readability alone.**

Full architecture, IAM, scheduling, and retention details are in the
Slice 2.2 correction report; §13 below covers the IAM specification.

### 6b. Three release-blocking corrections resolved (second adversarial review)

1. **ID-token audience.** Every ID token minted against the candidate's
   traffic-tag URL is audienced for `status.url` (the service's base
   URL), never the tag URL itself — per
   `docs.cloud.google.com/run/docs/authenticating/service-to-service`:
   "the aud value must remain as the URL of the service, even when
   making requests to a specific traffic tag." `CANDIDATE_URL` (the
   HTTP request target) and `BASE_SERVICE_URL` (the token audience) are
   two separate variables in `ci/verify-deployed-candidate.sh`, neither
   derived from the other, both explicitly fail-closed if empty.
2. **Builder-image gap resolved, not left open.** Empirical local
   inspection (pulled and ran `which`/`--version` against the real
   images, no GCP resource touched) found neither the official Cloud
   SDK image nor the official Docker builder image includes Node.js.
   Every step was re-mapped to the minimum single-purpose official
   image it actually needs; the three steps (`push-candidate`,
   `deploy-candidate`, `promote`) that must, within one script, both
   verify the fenced lease (Node-based) and perform a gcloud/docker
   mutation use `services/compliance-scanner/ci/Dockerfile.ci-builder`
   — built and its 7 tools (node, npm, gcloud, docker, curl, sha256sum,
   python3) verified locally in this review, via `COPY --from=` of
   already-pinned official images (the same technique the main
   Dockerfile already uses for Node), never a dynamic package install.
   Not pushed to any registry — `_CI_BUILDER_IMAGE_REF` remains a
   required substitution until that publishing step is separately
   authorized.
3. **Raw EICAR removed from repository storage.** The canonical EICAR
   bytes are no longer committed in the clear —
   `services/compliance-scanner/ci/fixtures/eicar.b64` holds a base64
   encoding instead, decoded and hash-verified exactly once per
   pipeline run (`ci/verify-fixtures.sh`, Node-based) into
   `/workspace/.eicar-materialized.bin` (Cloud Build's own ephemeral
   per-build shared volume), which every later step that needs the
   real bytes reads read-only. `ci/materializeEicarFixture.js`'s
   `decodeAndVerify` fails closed on missing/corrupted encoded input or
   a hash mismatch; the pipeline still proves clamd returns `infected`
   against the real decoded bytes (confirmed locally via `docker exec`
   against a real clamd process in this same review).

`gcloud builds triggers create scheduled` (the single-command form
below) is convenience syntax, not one native resource — it provisions a
Cloud Scheduler job, a Cloud Build trigger, and wires them together
using the SCHEDULER INVOCATION IDENTITY (§13), never the Cloud Build
execution identity or the scanner's own runtime identity. See
`services/compliance-scanner/ci/scheduler.template.yaml` for the full
identity chain this actually involves (four distinct identities,
documented, never conflated) and the freshness-margin reasoning behind
the daily cadence:

```
gcloud builds triggers create scheduled \
  --project=<target project — never hardcoded in the pipeline file itself> \
  --name=compliance-scanner-signature-refresh \
  --schedule="0 3 * * *" \
  --build-config=services/compliance-scanner/cloudbuild.signature-refresh.yaml \
  --repo=<this repository> \
  --branch-pattern=^integration/mac-windows-2026-07-22$ \
  --substitutions=_REGION=...,_REPOSITORY=...,_IMAGE_NAME=...,_SERVICE=...,_SCANNER_RUNTIME_SA=...,_MONITORING_SA=...,_SYNTHETIC_TEST_BUCKET=...,_LOCK_BUCKET=...,_ENVIRONMENT=...
```

Not executed in this task — creating this trigger is a future, separately-authorized action.

## 7. Monitoring / alerts

### 7a. `/healthz` vs `/status` — which path does what (Slice 2.2 correction)

Two paths exist on this service, deliberately kept distinct, not
redundant:

- **`/healthz`** is reserved exclusively for **Cloud Run's own internal
  startup probe** (`spec.containers[0].startupProbe.httpGet`, configured
  with `path=/healthz, port=8080`). This is the ONLY consumer of this
  path. Staging verification confirmed Cloud Run's internal probe
  mechanism successfully reaches this path and evaluates the real
  handler (`"STARTUP HTTP probe succeeded... path /healthz"` in Cloud
  Run's own logs) — but **staging also found that the exact literal
  path `/healthz` is not reachable through the service's public Cloud
  Run URL**: every external request to it (authenticated or not, via
  direct HTTPS, `gcloud run services proxy`, forced HTTP/1.1,
  cache-busting query params) received a generic Google 404 page and,
  critically, produced **zero entries in Cloud Run's own request logs**
  — while every other path tested (`/`, `/v1/scan`, `/HEALTHZ`,
  `/healthzz`, deliberately-wrong paths) correctly reached Cloud Run's
  IAM layer and was logged with its real status. A trailing-slash
  control (`/healthz/`) also correctly reached the IAM layer and was
  logged. This isolates the effect to the exact literal path,
  independent of method, query string, or auth state — application
  routing, Cloud Run IAM, and test methodology were all directly
  exonerated by this evidence.

  **This behavior's root cause is `UNRESOLVED — NEEDS CONTROLLED
  FOLLOW-UP`.** An official-documentation search (Cloud Run health-check
  docs, ingress docs, troubleshooting docs, App Engine's own documented
  `/_ah/health` reserved-path precedent, issuetracker.google.com, and
  the GoogleCloudPlatform GitHub org) found no `cloud.google.com` or
  `docs.cloud.google.com` page that confirms or denies a reserved
  `/healthz` interception at Cloud Run's edge for fully-managed
  services. **Do not state that Cloud Run reserves `/healthz`** — no
  authoritative source establishes this. Cloud Run's troubleshooting
  documentation does confirm, as a general documented pattern
  independent of this specific path, that a request blocked before
  reaching the container "leads to a 404 error" that "you can't find...
  in Cloud Logging" — structurally consistent with what was observed,
  but not a citable confirmation of *why* `/healthz` specifically
  triggers it. A handful of third-party reports (GitHub issues on other
  projects, one open/unanswered Google Developer Forums thread
  describing an apparently identical symptom) exist but **are not
  authoritative platform documentation** and must not be presented as
  such. Recommended next step: file a report on
  `issuetracker.google.com` (Cloud Run component) with the reproduction
  evidence above, since it is more rigorous than the existing
  unresolved community reports.

- **`/status`** is the **IAM-protected operational monitoring path**
  (Slice 2.2). It calls the exact same `handleHealthCheck` function and
  returns the exact same closed response contract as `/healthz`
  (`{status, checks: {clamdReachable, signaturesLoaded,
  signaturesFresh}}`) — no application-level authentication code was
  introduced to build it; it is reached through the identical private
  Cloud Run IAM boundary that already gates `/v1/scan`. External
  monitoring (uptime checks, alerting) must call `/status`, never
  `/healthz`, and must authenticate as a **dedicated monitoring
  identity** — not `compliance-functions-sa` (whose only granted
  purpose is invoking `/v1/scan` on behalf of the compliance Functions)
  and not a human account. See §13 (IAM specification) for the exact
  role this monitoring identity requires: `roles/run.invoker` on this
  service only, nothing broader.

  This service's private Cloud Run URL is deliberately **not printed
  in this document** — retrieve it at operation time via `gcloud run
  services describe <service> --region=<region> --project=<project>
  --format="value(status.url)"`, per this repository's existing
  convention of not committing live infrastructure endpoints to
  version control.

### 7b. Alerts

- Alert on the scanner's own error rate (Cloud Run built-in request
  metrics, filtered to 5xx and to `verdict: error` response bodies via a
  log-based metric on `scan_error` / `scan_completed` structured log
  lines).
- Alert on `/status` (never `/healthz` — see §7a) returning unhealthy
  for more than N consecutive minutes, called by the dedicated
  monitoring identity. **This alert must fail closed**: an
  unreachable/erroring `/status` check (timeout, 5xx, auth failure) must
  itself be treated as unhealthy for alerting purposes, never
  interpreted as "no news is good news" — the same fail-closed principle
  the scanner's own signature-freshness and clamd-availability logic
  already follows.
- Alert on the signature-refresh build (§6) failing.
- Alert on reconciliation backlog size (a log-based metric on
  `compliance_reconciliation_run`'s `candidateCount` fields staying high
  across multiple runs).

## 8. Budget alert

```
gcloud billing budgets create \
  --billing-account=<billing account id — deliberately not looked up or
    printed in this session per the read-only audit's own instruction not
    to output billing identifiers> \
  --display-name="compliance-scanner" \
  --budget-amount=50USD \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0
```

## 9. Formal canary enablement

Purely a configuration change, no code/Rules/Functions redeploy needed
once the Function is already live with the Slice 2.1 gate in place:

```
# Update the deployed Function's COMPLIANCE_UPLOAD_CANARY_BUSINESS_IDS
# param to the exact internal test business's Firestore document ID —
# via whichever Functions v2 params mechanism this repo's deploy
# pipeline uses (.env.<project> file, or an explicit --set-env-vars-
# equivalent at deploy time). No business is enabled by this document.
```

## 10. Rollback

- **Scanner outage**: `gcloud run services update-traffic compliance-scanner --to-revisions=<prior-revision>=100`.
- **Bad signature update**: same traffic rollback — the prior revision's
  baked-in signatures are untouched.
- **High false positives**: same rollback; if root-caused to a specific
  signature set, hold the signature-refresh trigger (§6) until upstream
  stabilizes.
- **Function errors**: `firebase deploy --only functions:<name>` of the
  prior committed revision (standard Cloud Functions rollback).
- **Reconciliation backlog**: not a rollback scenario by itself — a
  monitoring signal (§7) to investigate the scanner or raise
  `maxInstances`.
- **Unexpected costs**: `maxInstances=2` already bounds worst case;
  reduce further or scale to `minInstances=0`/pause the canary allowlist
  (§9, reverting to an empty value) as an immediate mitigation.
- **IAM misconfiguration**: the scanner's non-public, narrowly-scoped
  design means a misconfiguration's failure mode is "scanner becomes
  uncallable" (fails closed, safe), not "scanner becomes overexposed" —
  fix and redeploy the specific binding, no data-safety rollback needed.

## 11. Deployment order (never opens unsafe uploads)

1. Build and deploy the scanner to Cloud Run (§1–§4), IAM applied (§3).
2. Run the full staging verification plan (see the Slice 2.1 audit's
   §I / this task's Part F Docker section) against a **staging** project,
   not production.
3. Deploy `firestore.indexes.json` (additive, no behavior change alone).
4. Deploy `firestore.rules` and `storage.rules` together. **Storage
   Rules must remain the current deny-all-except-session-gated-create
   state until this exact step** — there is no reason to loosen it
   earlier, and every step before this one works correctly with the
   Rules exactly as already committed.
5. Deploy the four compliance Functions (with the dedicated
   `compliance-functions-sa` — §3 — and `CLAMAV_CLOUD_RUN_URL`/`_AUDIENCE`
   pointed at the now-verified **production** scanner, not staging).
6. Confirm via `firebase functions:list` (read-only) that all four are
   live and the canary allowlist (§9) is still empty/unset.
7. Formal canary enablement (§9) for exactly one internal test business.
8. Monitor (§7) before considering any wider rollout — which is Slice 3
   scope, not addressed here.

## 12. Cost posture reminder

`minInstances=0` now (§4). `minInstances=1` is deferred, tracked as a
later operational option only, contingent on both: (a) real staging
cold-start latency measurements showing it's genuinely needed (not
assumed from the earlier audit's estimate alone), and (b) independently
re-verifying current official Cloud Run idle-instance billing rates at
the time that decision is made (pricing can change; the earlier audit's
~$150/month figure was an explicitly-marked upper-bound estimate, not a
quote).

## 13. Least-privilege IAM for the signature-refresh pipeline (Slice 2.2)

Five distinct identities, never conflated, never reused across roles:

| Identity | Purpose | Roles | Explicitly NOT granted |
|---|---|---|---|
| **Scheduler invocation identity** | Fires the Cloud Build trigger on schedule — nothing else | `roles/cloudbuild.builds.editor` scoped to triggering this one build config, or the narrower trigger-invocation permission if the platform exposes one | Any Artifact Registry, Cloud Run, or IAM role — it never touches those services directly |
| **Cloud Build execution identity** (dedicated, third SA — never `compliance-scanner-sa`, never `compliance-functions-sa`) | Runs every step of `cloudbuild.signature-refresh.yaml`: build, test, push, deploy-candidate, promote | `roles/artifactregistry.writer` scoped to the one repository (§1) where possible; `roles/run.developer` scoped to the one service; `roles/iam.serviceAccountUser` **on `_SCANNER_RUNTIME_SA` only** (needed to deploy Cloud Run revisions running as that identity — this is the one place a token-minting-adjacent permission is required, and it is narrowly scoped to exactly the one SA it must impersonate-as-runtime-identity-for, never a broader `serviceAccountUser` grant); read/write on `_LOCK_BUCKET` and `_SYNTHETIC_TEST_BUCKET` (the latter scoped to `compliance_quarantine/ci-*` and `compliance_quarantine/ci-fixtures/` only, mirroring the existing prefix-condition pattern from §3) | Owner, Editor, Storage Admin, Firebase Admin, Project IAM Admin; `serviceAccountUser` on any SA other than `_SCANNER_RUNTIME_SA`; no role on `compliance-functions-sa` at all |
| **Scanner runtime identity** (`compliance-scanner-sa`, §2 — unchanged, reused as-is) | What the deployed Cloud Run revision actually runs as | Exactly as already specified in §3: `roles/storage.objectViewer` conditioned to `compliance_quarantine/` only | Everything else, as already documented |
| **Candidate-verification / monitoring identity** (`_MONITORING_SA`, dedicated — never a human account, never `compliance-functions-sa`) | Mints ID tokens to call the candidate's tag URL (`/status`, `/v1/scan`) during Stage 5, and is the intended identity for ongoing external `/status` monitoring/alerting per §7a | `roles/run.invoker` on this Cloud Run service only | Any Storage, Artifact Registry, or IAM role |
| **Functions caller identity** (`compliance-functions-sa`, §2/§3 — unchanged) | Invokes `/v1/scan` at real request time, on behalf of the compliance Functions | Exactly as already specified in §3: `roles/run.invoker` only, on this service | Anything related to the refresh pipeline itself — it plays no role in building, testing, or promoting images |

**Human Token Creator access must not be reintroduced.** The Slice 2.1
staging hardening pass explicitly removed the operator's temporary
`roles/iam.serviceAccountTokenCreator` grants on both runtime SAs after
verification concluded (see that report) — none of the identities or
roles above re-grant any human account impersonation rights on any
service account. The Cloud Build execution identity's `serviceAccountUser`
grant is the only impersonation-adjacent permission in this entire
design, and it is a service-to-service grant (Cloud Build's own runtime
identity acting as `_SCANNER_RUNTIME_SA` when deploying), not a human
credential.

## 14. Retention, fixture manifest, and lifecycle templates (Slice 2.2, corrected per adversarial review)

Three declarative artifacts exist, none applied to any real resource:

- `services/compliance-scanner/ci/artifact-registry-cleanup-policy.template.json`
  — corrected against the real schema at
  `docs.cloud.google.com/artifact-registry/docs/repositories/cleanup-policy`
  (an earlier draft incorrectly wrapped the policy in a `{"rules": [...]}`
  object; the real format is a **bare JSON array**, and `condition`/
  `mostRecentVersions` are mutually exclusive within one rule — both
  errors are now fixed). Confirmed via that same source: Artifact
  Registry's cleanup engine has **no native awareness of Cloud Run
  serving state** — a Keep rule can only match on tag/age/count, never
  on "is this digest currently deployed". Protection is therefore: (a)
  an unconditional Keep rule matching every `promoted-` tag, applied by
  `ci/promote.sh` only after verified traffic shift, with each promoted
  digest receiving its own permanent, never-reused tag name (so no
  later promotion can move an earlier tag and silently un-protect an
  older digest); and (b) a documented-but-not-implemented periodic
  inventory-reconciliation process for safely bounding `promoted-` tag
  growth, since that bounding genuinely requires comparing against real
  Cloud Run state, which the JSON policy alone cannot do (see the
  template's own `_comment_bounding_promoted_history` field). Failed
  candidates (`candidate-` tags) age out automatically after 7 days —
  they carry no such protection requirement.
- `services/compliance-scanner/ci/fixtureManifest.json` +
  `ci/fixtureManifest.js` — the mandatory security-fixture manifest
  (Mandatory correction 1). Every fixture the pipeline treats as
  trusted (benign text, the standard EICAR test string, a synthetic
  encrypted PDF) is pinned here by real, checked-in-repository content
  hash (`ci/fixtures/*`); the `generation` field for each is the
  literal sentinel `PENDING_PROVISIONING` until a separate, documented
  provisioning process uploads each fixture once and records its real
  GCS generation here. A fixture missing, mismatched, or still carrying
  that sentinel fails the pipeline outright — see §6a for the exact
  "never silently skip" guarantee and `ci/fixtureManifest.test.js` for
  the 20 deterministic tests proving it.

  **Fixture provisioning process (separate, authorized, not performed
  in this task):** an operator with write access to `_SYNTHETIC_TEST_BUCKET`
  uploads each `ci/fixtures/*` file, byte-for-byte as checked into this
  repository, to its manifest-pinned `objectPath` under
  `compliance_quarantine/ci-fixtures/` — a one-time action per fixture,
  never repeated by the pipeline itself. Immediately after each upload,
  the operator records the real GCS generation `gcloud storage objects
  describe` reports back into `ci/fixtureManifest.json`, replacing that
  fixture's `PENDING_PROVISIONING` sentinel with the real value, and
  commits that change through the normal review process — the manifest
  update is itself a reviewable, auditable code change, not a runtime
  side effect of any pipeline execution. Re-provisioning (e.g. rotating
  a fixture's content) means uploading a new object at the same path,
  recomputing its real sha256/sizeBytes, and updating all four pinned
  fields (`generation`, `sha256`, `sizeBytes`, and the checked-in
  `localPath` file itself) together in one reviewed change — never
  updating only the generation while leaving a stale hash pinned, which
  `ci/fixtureManifest.test.js`'s "manifest and real file must match"
  test exists specifically to catch.
- `services/compliance-scanner/ci/staging-bucket-lifecycle.template.json`
  — for the dedicated staging synthetic-object bucket only: live
  fixtures deleted after 7 days, noncurrent generations after 2 days.
  Schema confirmed against `gcloud storage buckets update --help`'s own
  worked example (`{"rule": [...]}`, singular — a GENUINELY DIFFERENT
  top-level shape from Artifact Registry's bare array above; the two
  were checked separately rather than assumed to match by analogy).
  Deliberately not parameterized with a bucket name, so it cannot be
  copy-pasted onto a production bucket without a deliberate, explicit
  apply step naming the correct one. Production compliance documents
  are excluded structurally — this policy is only ever attached to a
  bucket resource that holds nothing but synthetic test fixtures.
