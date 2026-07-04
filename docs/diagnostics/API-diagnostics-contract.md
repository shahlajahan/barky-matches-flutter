# API Contract — Diagnostics Platform

Version: 1.0

Status: Approved

Owner: Petsupo Engineering

Last Updated: 2026-07-04

Related Documents

- PROJECT_RULES.md
- TECHNICAL_ARCHITECTURE.md
- ADR-001 Diagnostics Architecture
- PRD Diagnostics Reporting Platform

---

# Purpose

This document defines the communication contract between the Flutter
Diagnostics Platform and the backend diagnostics services.

It specifies:

- communication path
- request schema
- response schema
- validation
- ownership
- versioning
- Firestore persistence model

This contract is the single source of truth for all diagnostics communication.

---

# Communication Flow

Flutter Feature

↓

AppLog

↓

DiagnosticsBuffer

↓

DiagnosticsReporter

↓

DiagnosticsUploader

↓

Firebase Callable Function

↓

Firestore

↓

Admin Dashboard

No alternative communication path is permitted.

---

# Callable Function

Function Name

submitDiagnosticsReport

Platform

Firebase Functions v2

Invocation

Callable Function

Region

europe-west1

Authentication

Authenticated user:
Firebase Authentication UID

Guest user:
Anonymous diagnostics supported

---

# Upload Conditions

Uploader may upload only when:

• report severity is Critical

OR

• report was explicitly requested by Report Problem

Uploader must never upload:

Info

Warning

Debug

unless explicitly enabled by future configuration.

---

# Client Report Model

Flutter owns this model.

```json
{
  "schemaVersion": "1.0",

  "sessionId": "...",

  "createdAt": "...",

  "reason": "...",

  "severity": "critical",

  "app": {

      "version": "...",

      "buildNumber": "...",

      "buildMode": "...",

      "packageName": "..."
  },

  "device": {

      "platform": "...",

      "manufacturer": "...",

      "model": "...",

      "osVersion": "...",

      "locale": "...",

      "timezone": "..."
  },

  "user": {

      "uid": "...",

      "isGuest": false,

      "language": "..."
  },

  "screen": {

      "route": "...",

      "screenName": "...",

      "feature": "..."
  },

  "logs":[]
}
```

---

# Log Model

```json
{
    "timestamp":"...",

    "level":"info",

    "category":"map",

    "message":"GoogleMap created",

    "data":{

    }
}
```

---

# Server Report Model

Backend owns this model.

```json
{
    "reportId":"...",

    "receivedAt":"...",

    "status":"new",

    "fingerprint":"...",

    "duplicate":false,

    "assignedTo":null,

    "processedAt":null,

    "schemaVersion":"1.0",

    "clientReport":{

    }
}
```

---

# Ownership

| Field | Owner |
|--------|-------|
| schemaVersion | Flutter |
| sessionId | Flutter |
| createdAt | Flutter |
| reason | Flutter |
| severity | Flutter |
| logs | Flutter |
| reportId | Backend |
| receivedAt | Backend |
| fingerprint | Backend |
| duplicate | Backend |
| status | Backend |
| assignedTo | Backend |
| processedAt | Backend |

Flutter must never modify backend-owned fields.

Backend must never modify client-owned fields.

---

# Immutable Fields

The following fields are immutable after report creation:

schemaVersion

sessionId

createdAt

reason

severity

logs

---

# Mutable Fields

Only backend may update:

status

assignedTo

processedAt

duplicate

notes

---

# Request Validation

Backend validates:

schemaVersion

sessionId

createdAt

severity

required objects

maximum log count

maximum payload size

required app information

required device information

Malformed reports are rejected.

---

# Limits

Maximum payload size

256 KB

Maximum logs

500

Maximum log message

1000 characters

Maximum stack trace

4000 characters

Maximum attachment count

1

Maximum screenshot size

5 MB

---

# Duplicate Detection

Backend calculates a report fingerprint.

Duplicate reports from the same session may be ignored.

Fingerprint implementation is backend responsibility.

Flutter must not calculate fingerprints.

---

# Retry Behaviour

Uploader retries failed uploads.

Retry policy:

1 minute

5 minutes

15 minutes

1 hour

Maximum retries:

5

Uploader stops retrying after successful upload.

---

# Offline Behaviour

If upload is impossible:

Store report locally

Retry automatically

User interaction is not required.

---

# Response

Success

```json
{
    "success":true,

    "reportId":"..."
}
```

Failure

```json
{
    "success":false,

    "code":"INVALID_REPORT",

    "message":"..."
}
```

---

# Error Codes

INVALID_REPORT

INVALID_SCHEMA

UNAUTHORIZED

PAYLOAD_TOO_LARGE

RATE_LIMITED

SERVER_ERROR

---

# Firestore Collection

debug_reports

Each document represents one diagnostics report.

---

# Firestore Document

```json
{
    "reportId":"...",

    "receivedAt":"...",

    "status":"new",

    "fingerprint":"...",

    "duplicate":false,

    "processedAt":null,

    "clientReport":{

    }
}
```

---

# Status Lifecycle

new

↓

investigating

↓

fixed

or

duplicate

or

ignored

Status changes are backend-only.

---

# Security

The backend rejects:

invalid authentication

invalid schema

oversized payloads

unsupported versions

malformed reports

tampered backend fields

---

# Privacy

Diagnostics must never contain:

passwords

payment information

authentication tokens

private conversations

private media

sensitive personal information

Diagnostics contains only technical application data.

---

# Versioning

Every report contains:

schemaVersion

Breaking schema changes require:

new uploader support

new backend validation

documentation update

---

# Future Compatibility

The contract allows future extensions including:

Crashlytics identifiers

performance metrics

network diagnostics

memory usage

battery information

AI classification

without breaking existing clients.

---

# Final Rules

Feature modules never communicate directly with Firestore.

Feature modules never upload diagnostics.

Only DiagnosticsUploader may communicate with backend diagnostics services.

This contract is mandatory for all future diagnostics implementations.

# Delivery Pipeline

Flutter must never upload directly from AppLog or DiagnosticsReporter.

Only DiagnosticsUploader may call submitDiagnosticsReport.

Reports must pass through DiagnosticsQueue before upload.

DiagnosticsQueue uses Hive for offline persistence.

Backend must treat uploads as idempotent.

Duplicate detection is backend responsibility.