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

## 6. Daily signature-refresh build

```
gcloud builds triggers create scheduled \
  --project=barkymatches-new \
  --name=compliance-scanner-signature-refresh \
  --schedule="0 3 * * *" \
  --build-config=services/compliance-scanner/cloudbuild.signature-refresh.yaml \
  --repo=<this repository> \
  --branch-pattern=^integration/mac-windows-2026-07-22$
```

(The referenced `cloudbuild.signature-refresh.yaml` does not exist yet —
tracked as a follow-up; its job is exactly "docker build (which re-runs
`docker/build-signatures.sh` via the Dockerfile's `signatures` stage),
push, deploy a new Cloud Run revision" — nothing beyond what a normal
image rebuild already does, run on a schedule instead of on every code
change.)

## 7. Monitoring / alerts

- Alert on the scanner's own error rate (Cloud Run built-in request
  metrics, filtered to 5xx and to `verdict: error` response bodies via a
  log-based metric on `scan_error` / `scan_completed` structured log
  lines).
- Alert on `/healthz` returning unhealthy for more than N consecutive
  minutes (signature staleness or clamd unreachability).
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
