# Backend Architecture — Diagnostics Platform

Version: 1.0

Status: Draft

Owner: Petsupo Engineering

Last Updated: 2026-07-04

Related Documents:

- docs/PROJECT_RULES.md
- docs/TECHNICAL_ARCHITECTURE.md
- docs/PRODUCT_MAP.md
- docs/diagnostics/ADR-001-diagnostics-architecture.md
- docs/diagnostics/PRD-diagnostics-reporting-platform.md
- docs/diagnostics/API-diagnostics-contract.md

---

# Purpose

This document defines the backend architecture for the Petsupo Diagnostics Platform.

It explains how diagnostics reports move from the Flutter application to Firestore and later to the Admin Dashboard.

This document does not define the full Firestore schema or full Cloud Function implementation details. Those are covered in separate documents.

---

# Background

Petsupo already has user-facing support and reporting flows, including:

- Send Feedback
- Report Problem
- User moderation reports stored in `reports`
- Push/debug token testing stored in `debug_tokens`

The Diagnostics Platform must not conflict with these existing systems.

Diagnostics reports are technical application reports, not user moderation reports.

---

# Collection Boundary Decision

The existing Firestore collection:

```text
reports
```

is used for user-generated reports, moderation reports, abuse reports, and content-related reporting.

Diagnostics must not use this collection.

Diagnostics backend storage uses a separate collection:

```text
debug_reports
```

Existing debug/testing collections such as:

```text
debug_tokens
```

remain separate and unrelated.

Final collection separation:

```text
reports
    User / moderation reports

debug_reports
    Technical diagnostics reports

debug_tokens
    Push / APNs / notification debugging
```

---

# High-Level Backend Flow

```text
Flutter App
    ↓
DiagnosticsReporter
    ↓
DiagnosticsQueue
    ↓
DiagnosticsUploader
    ↓
submitDiagnosticsReport
    ↓
Validation
    ↓
Normalization
    ↓
Fingerprinting
    ↓
Firestore debug_reports
    ↓
Admin Diagnostics Dashboard
```

---

# Backend Components

## DiagnosticsUploader

Location:

Flutter client.

Responsibility:

- Read pending reports from DiagnosticsQueue.
- Submit eligible reports to the backend.
- Retry failed uploads.
- Remove successfully uploaded reports from the local queue.

DiagnosticsUploader must not write directly to Firestore.

---

## submitDiagnosticsReport

Location:

Firebase Cloud Functions v2.

Type:

Callable Function.

Region:

```text
europe-west1
```

Responsibility:

- Accept diagnostics reports from Flutter.
- Validate payload.
- Reject malformed reports.
- Normalize server-owned fields.
- Generate backend report ID.
- Generate fingerprint.
- Check for duplicates.
- Store report in `debug_reports`.
- Return success or structured failure.

---

## debug_reports

Location:

Cloud Firestore.

Responsibility:

- Store one diagnostics report per document.
- Preserve the original client report.
- Store backend metadata.
- Support admin filtering and review.

---

## Admin Diagnostics Dashboard

Location:

Petsupo Admin UI.

Responsibility:

- List diagnostics reports.
- View details.
- Filter by status, reason, platform, severity.
- Inspect logs.
- Update report status.
- Mark reports as duplicate, ignored, investigating, fixed, or closed.

---

# Data Ownership

The backend owns:

- reportId
- receivedAt
- status
- fingerprint
- duplicate
- duplicateOf
- processedAt
- reviewedAt
- reviewedBy
- adminNotes

The Flutter client owns:

- schemaVersion
- sessionId
- clientReportId
- createdAt
- reason
- severity
- app
- device
- user
- screen
- logs

The backend must store the original client payload under:

```text
clientReport
```

Backend-generated metadata must live at the root of the Firestore document.

---

# Firestore Document Shape

```json
{
  "reportId": "...",
  "receivedAt": "...",
  "status": "new",
  "fingerprint": "...",
  "duplicate": false,
  "duplicateOf": null,
  "processedAt": null,
  "reviewedAt": null,
  "reviewedBy": null,
  "adminNotes": null,
  "clientReport": {}
}
```

The full schema is defined in:

```text
docs/diagnostics/Firestore-Schema.md
```

---

# Report Lifecycle

## 1. Report Created on Client

A critical error or user bug report causes Flutter to create a diagnostics report.

The report is stored locally in DiagnosticsQueue.

---

## 2. Report Queued Locally

All reports must pass through DiagnosticsQueue.

Queue storage:

```text
Hive
```

Maximum queue size:

```text
30 reports
```

Queue behavior:

```text
FIFO
```

If the queue exceeds the limit, the oldest report may be removed.

---

## 3. Report Upload Attempt

DiagnosticsUploader attempts upload when one of the following occurs:

- App launch
- App resume
- Network becomes available
- Manual retry from internal tools

Uploader must never block UI.

---

## 4. Backend Validation

Cloud Function validates:

- schemaVersion
- sessionId
- createdAt
- severity
- app
- device
- user
- screen
- logs
- payload size
- log count

Invalid reports are rejected.

---

## 5. Backend Fingerprint

Backend calculates a fingerprint.

Fingerprint is backend-owned.

Flutter must never generate or submit fingerprint.

Fingerprint may be based on:

- reason
- severity
- platform
- app version
- top error message
- top stack trace lines
- current feature
- current route

---

## 6. Duplicate Detection

Backend checks whether a similar report already exists.

Version 1 decision:

```text
Create a new document with duplicate=true and duplicateOf=<originalReportId>
```

---

## 7. Report Stored

If accepted, the report is stored in:

```text
debug_reports
```

Initial status:

```text
new
```

---

## 8. Uploader Removes Local Copy

After backend success, Flutter removes the report from DiagnosticsQueue.

If upload fails, the report remains queued for retry.

---

# Retry Policy

Uploader retry schedule:

```text
1 minute
5 minutes
15 minutes
1 hour
6 hours
24 hours
```

Maximum retries:

```text
7
```

After maximum retries, the report may be discarded.

Retry state is client-owned.

Backend must remain idempotent.

---

# Idempotency

Backend must tolerate repeated uploads of the same report.

Client may retry the same report multiple times.

Backend should use:

```text
clientReportId + sessionId
```

to detect exact repeated uploads.

Backend should use fingerprint to detect similar issue duplicates.

---

# Authentication

Reports may come from:

- authenticated users
- guest users
- anonymous sessions

Authenticated reports include Firebase Auth UID when available.

Guest reports must still be accepted if structurally valid.

Authentication must not block diagnostics from guest flows.

---

# Security Model

Flutter must not write directly to:

```text
debug_reports
```

Only Cloud Functions may create diagnostics reports.

Firestore Security Rules should deny direct client writes to `debug_reports`.

Admin read/update access should be restricted to admin users only.

---

# Rate Limiting

Backend should protect against abuse.

Version 1 minimum:

```text
Limit excessive reports per uid/session in Cloud Function.
```

---

# Payload Limits

```text
Maximum payload size: 256 KB

Maximum logs: 500

Maximum log message length: 1000 characters

Maximum stack trace length: 4000 characters

Maximum screenshot references: 1
```

---

# Screenshot Handling

Version 1 diagnostics backend does not require screenshots.

If available, diagnostics may store only the screenshot URL.

Raw image bytes must never be embedded in the report payload.

---

# Status Lifecycle

```text
new
triaged
investigating
fixed
closed
duplicate
ignored
```

Only backend/admin systems may update status.

Flutter must never update report status.

---

# Retention Policy

During beta:

```text
Do not automatically delete diagnostics reports.
```

Recommended production retention:

```text
180 days
```

---

# Indexing Strategy

Version 1 should support queries by:

- newest reports
- status
- duplicate
- reason
- platform
- app version

Indexes are defined in:

```text
docs/diagnostics/Firestore-Schema.md
```

---

# Admin Dashboard Requirements

The Admin Dashboard should support:

- list reports
- filter by status
- filter by severity
- filter by app version
- filter by platform
- open report details
- inspect logs
- view screenshot URL
- update status
- add admin notes
- mark duplicate
- mark ignored
- mark fixed

Implementation details are defined in:

```text
docs/diagnostics/Admin-Dashboard.md
```

---

# Observability

Cloud Function should log:

- report received
- validation failed
- duplicate detected
- report stored
- upload rejected
- rate limit triggered

Sensitive payloads must never be written to backend logs.

---

# Privacy Requirements

Diagnostics must never store:

- passwords
- payment card data
- authentication tokens
- private messages
- private media
- highly sensitive personal information

Diagnostics may store:

- app version
- build number
- platform
- device model
- route
- feature
- technical logs
- user UID

---

# Failure Handling

If upload fails:

- client keeps report in queue
- backend returns structured error

If validation fails:

- backend returns non-retryable error

If Firestore fails:

- backend returns retryable error

---

# Backend Error Codes

```text
INVALID_REPORT
INVALID_SCHEMA
UNAUTHORIZED
PAYLOAD_TOO_LARGE
RATE_LIMITED
DUPLICATE_ACCEPTED
SERVER_ERROR
```

---

# Non-Goals

Version 1 does not include:

- Crashlytics integration
- AI classification
- BigQuery export
- GitHub issue creation
- Slack notifications
- Real-time alerting

---

# Future Extensions

Possible future additions:

- AI classification
- Duplicate grouping
- BigQuery export
- Telegram alerts
- Crashlytics linking
- Performance traces
- Network diagnostics
- Automatic severity scoring

---

# Architecture Rules

The following are prohibited:

```text
Feature → Firestore debug_reports

Widget → Cloud Function

AppLog → Network

DiagnosticsReporter → Network

DiagnosticsQueue → Network
```

Only this path is allowed:

```text
DiagnosticsUploader
    ↓
submitDiagnosticsReport
    ↓
debug_reports
```

---

# Final Decision

Diagnostics backend uses:

```text
debug_reports
```

The existing `reports` collection remains dedicated to user moderation reports.

The existing `debug_tokens` collection remains dedicated to notification debugging.

All diagnostics reports must follow this path:

```text
DiagnosticsUploader
    ↓
submitDiagnosticsReport
    ↓
debug_reports
```