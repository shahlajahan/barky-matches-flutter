# PRD — Diagnostics Reporting Platform

Version: 1.0

Status: Draft

Owner: Petsupo Engineering

Last Updated: 2026-07-04

Related Documents:

- PROJECT_RULES.md
- TECHNICAL_ARCHITECTURE.md
- PRODUCT_MAP.md
- ADR-001 Diagnostics Architecture

---

# Purpose

Provide a production-ready diagnostics platform capable of collecting
technical information automatically while remaining invisible to normal users.

The platform improves issue investigation without changing the existing
Support experience.

---

# Product Vision

Users should be able to report problems naturally.

Engineers should receive enough technical information to reproduce issues.

The reporting experience must remain simple.

The diagnostics process must remain automatic.

---

# Existing Support

Petsupo already provides:

• Send Feedback

• Report Problem

The Diagnostics Platform extends these features.

It does not replace them.

---

# Product Goals

The platform shall:

• reduce reproduction time

• reduce communication with testers

• automatically attach technical context

• support production debugging

• remain invisible to normal users

---

# Non Goals

The platform is NOT intended to:

• replace analytics

• replace customer support

• replace Crashlytics

• expose technical information to users

---

# Existing User Flow

Report Problem

↓

Description

↓

Optional Screenshot

↓

Submit

This flow remains unchanged.

---

# Future User Flow

Report Problem

↓

Description

↓

Optional Screenshot

↓

Automatic Diagnostics Collection

↓

Submit

The user does not perform any additional action.

---

# Automatic Diagnostics

When a report is submitted the platform may attach:

• Session ID

• App Version

• Build Number

• Platform

• Device Model

• Current Route

• Current Screen

• Diagnostics Logs

• Error Context

The attachment is automatic.

---

# User Experience Principles

The reporting experience must remain:

• simple

• fast

• silent

The user must never be required to understand diagnostics.

---

# Screenshot

Screenshot remains optional.

Diagnostics must never depend on screenshots.

---

# Diagnostics Collection

Diagnostics may be generated from:

• Unhandled Flutter errors

• Platform errors

• Critical feature failures

• Explicit calls to DiagnosticsReporter

Normal informational logs are not uploaded.

---

# Diagnostics Severity

The platform classifies diagnostics into:

Info

Warning

Critical

Only Critical diagnostics are eligible for automatic upload.

---

# Integration with Support

Support remains responsible for:

• communication

• feedback

• feature requests

Diagnostics remains responsible for:

• technical context

• application state

• structured logs

These responsibilities remain separated.

---

# Feedback

Send Feedback continues supporting:

• General Feedback

• Feature Request

• Product Suggestions

Diagnostics is not attached by default.

Bug Report may optionally include diagnostics.

---

# Bug Reports

Bug Reports may include:

User Description

+

Optional Screenshot

+

Automatic Diagnostics

This attachment happens without user interaction.

---

# Privacy

Diagnostics must never collect:

Passwords

Payment information

Authentication tokens

Personal conversations

Private media

Sensitive personal information

Only technical application data is collected.

---

# Performance Requirements

Diagnostics must:

• never block UI

• never delay navigation

• never freeze the application

• minimize battery usage

• minimize network usage

---

# Offline Behaviour

If upload cannot be completed:

The report remains queued.

Upload is retried later.

The user is not interrupted.

---

# Duplicate Handling

Multiple identical failures during the same application session
should not generate unlimited reports.

Duplicate suppression is handled by the Diagnostics Platform.

---

# Admin Experience

Administrators should receive:

Problem Description

Screenshot (if attached)

Technical Diagnostics

Application Version

Device Information

Session Information

Structured Logs

This information should be available from a single report.

---

# Success Metrics

Success is measured by:

Reduced issue reproduction time

Reduced back-and-forth communication

Faster production debugging

Higher quality bug reports

Lower engineering investigation time

---

# Future Roadmap

Future versions may include:

Crashlytics integration

Performance diagnostics

Network diagnostics

Background upload optimization

Diagnostics Dashboard

Report status management

Automatic issue grouping

---

# Definition of Success

A tester should only need to describe the problem.

Petsupo should automatically provide engineers with the technical
context required to investigate it.

# Delivery Behaviour

Diagnostics reports are not uploaded directly from Reporter.

Flow:

DiagnosticsReporter
→ DiagnosticsQueue
→ DiagnosticsUploader
→ submitDiagnosticsReport
→ Firestore

Reports must be queued locally before upload.

Queue storage: Hive.

Uploader triggers:

- App launch
- App resume
- Network available
- Manual retry

Uploader must not block UI.

Max queued reports: 30.

Retry schedule:

1 min → 5 min → 15 min → 1 hour → 6 hours → 24 hours

Max retries: 7.

If max retries are exceeded, the report may be discarded.