# Cloud Functions — Diagnostics Platform

Version: 1.0

Status: Draft

Owner: Petsupo Engineering

Last Updated: 2026-07-04

Related Documents:

- docs/diagnostics/PRD-diagnostics-reporting-platform.md
- docs/diagnostics/API-diagnostics-contract.md
- docs/diagnostics/Backend-Architecture.md
- docs/diagnostics/Firestore-Schema.md
- docs/diagnostics/ADR-001-diagnostics-architecture.md

---

# Purpose

This document defines the Cloud Functions layer for the Diagnostics Platform.

It specifies:

- Callable functions
- Responsibilities
- Validation
- Firestore writes
- Duplicate detection
- Error handling
- Logging
- Security

It does not define Flutter implementation.

---

# Cloud Functions

Version 1 contains a single callable function.

```text
submitDiagnosticsReport
```

Additional functions may be introduced in future versions.

---

# Region

```text
europe-west1
```

All diagnostics functions must use the same region.

---

# Runtime

```text
Cloud Functions v2
```

---

# Entry Point

```text
submitDiagnosticsReport
```

Type

```text
Callable
```

---

# Responsibility

The function must:

- Authenticate the request (if available)
- Validate payload
- Normalize data
- Generate backend metadata
- Detect duplicates
- Store the report
- Return a structured response

The function must never expose internal errors to the client.

---

# Request Flow

```text
Flutter

↓

DiagnosticsUploader

↓

submitDiagnosticsReport

↓

Validate

↓

Normalize

↓

Fingerprint

↓

Duplicate Detection

↓

Firestore

↓

Response
```

---

# Authentication

The function accepts requests from:

- authenticated users
- anonymous users
- guest users

Authentication is optional.

If authentication exists:

```text
uid = context.auth.uid
```

Otherwise:

```text
uid = null
```

Diagnostics collection must work even without authentication.

---

# Validation

The function validates:

- schemaVersion
- clientReportId
- sessionId
- createdAt
- reason
- severity
- app
- device
- user
- screen
- logs

Validation occurs before any Firestore write.

---

# Payload Limits

Reject requests exceeding:

```text
256 KB
```

Reject reports containing:

```text
More than 500 logs
```

Reject log messages longer than:

```text
1000 characters
```

Reject stack traces longer than:

```text
4000 characters
```

---

# Normalization

The backend owns:

```text
reportId

receivedAt

status

fingerprint

duplicate

duplicateOf

processedAt

reviewedAt

reviewedBy

adminNotes
```

The client must never overwrite backend-owned fields.

---

# Fingerprint Generation

Fingerprint generation occurs only on the backend.

Flutter must never calculate fingerprints.

Possible fingerprint inputs:

- reason
- severity
- top exception
- stack trace
- app version
- platform
- feature
- current route

Implementation may change without affecting Flutter.

---

# Duplicate Detection

Duplicate detection occurs after validation.

Version 1 behavior:

```text
Existing issue found

↓

Create new document

↓

duplicate = true

↓

duplicateOf = originalReportId
```

Reports are never discarded because they are duplicates.

---

# Firestore Write

Destination collection:

```text
debug_reports
```

Document ID:

```text
Auto-generated
```

The complete client payload is stored under:

```text
clientReport
```

Backend metadata is stored at the document root.

---

# Response

Success:

```json
{
  "success": true,
  "reportId": "...",
  "duplicate": false
}
```

Duplicate:

```json
{
  "success": true,
  "reportId": "...",
  "duplicate": true,
  "duplicateOf": "..."
}
```

Failure:

```json
{
  "success": false,
  "code": "...",
  "message": "..."
}
```

---

# Error Codes

Supported codes:

```text
INVALID_SCHEMA

INVALID_REPORT

INVALID_PAYLOAD

PAYLOAD_TOO_LARGE

RATE_LIMITED

UNAUTHORIZED

SERVER_ERROR
```

Error messages should be stable and machine-readable.

---

# Retry Semantics

Retryable:

```text
SERVER_ERROR

Temporary Firestore failure

Network failure
```

Not Retryable:

```text
INVALID_SCHEMA

INVALID_REPORT

INVALID_PAYLOAD
```

Flutter decides retry behavior.

Cloud Function simply returns the error.

---

# Logging

Cloud Functions should log:

```text
Report received

Validation failed

Duplicate detected

Firestore write succeeded

Firestore write failed

Unexpected exception
```

Sensitive user data must never be written to Cloud Logging.

---

# Security

Clients:

```text
Cannot write directly to debug_reports
```

Only Cloud Functions create diagnostics documents.

Firestore Rules enforce this.

---

# Rate Limiting

Version 1 minimum protection:

Limit excessive reports by:

- uid
- sessionId
- IP (if available)

The exact algorithm is implementation-specific.

---

# Idempotency

Repeated uploads of the same report must not corrupt data.

The backend may use:

```text
clientReportId

+

sessionId
```

to detect exact retries.

Fingerprint is used only for issue grouping.

---

# Failure Handling

If Firestore fails:

```text
Return retryable SERVER_ERROR
```

If validation fails:

```text
Return INVALID_REPORT
```

If payload exceeds limits:

```text
Return PAYLOAD_TOO_LARGE
```

---

# Performance Targets

Target execution time:

```text
< 500 ms
```

Cold starts are acceptable during Version 1.

---

# Monitoring

The backend should expose metrics for:

- Reports received
- Reports stored
- Duplicate reports
- Validation failures
- Upload failures

Monitoring implementation is outside Version 1.

---

# Future Functions

Potential future functions:

```text
listDiagnosticsReports

getDiagnosticsReport

updateDiagnosticsStatus

markDuplicate

addAdminNote

deleteOldDiagnostics

exportDiagnostics
```

These are intentionally excluded from Version 1.

---

# Non-Goals

Version 1 does not include:

- Crashlytics integration
- Slack notifications
- Telegram alerts
- AI classification
- GitHub issue creation
- BigQuery export
- Email notifications
- Automatic issue assignment

---

# Final Rule

The Cloud Functions layer is the only component allowed to create documents in:

```text
debug_reports
```

Flutter uploads diagnostics only through:

```text
DiagnosticsUploader

↓

submitDiagnosticsReport
```

No Flutter code may bypass this path.