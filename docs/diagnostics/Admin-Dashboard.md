# Admin Dashboard — Diagnostics Platform

Version: 1.0

Status: Draft

Owner: Petsupo Engineering

Last Updated: 2026-07-04

Related Documents:

- docs/diagnostics/PRD-diagnostics-reporting-platform.md
- docs/diagnostics/API-diagnostics-contract.md
- docs/diagnostics/Backend-Architecture.md
- docs/diagnostics/Firestore-Schema.md
- docs/diagnostics/Cloud-Functions.md

---

# Purpose

This document defines the Diagnostics section of the Petsupo Admin Dashboard.

It specifies:

- Dashboard layout
- Report list
- Filters
- Report details
- Review workflow
- Status management

This document does not define UI implementation details.

---

# Goal

Allow administrators to quickly:

- Identify critical issues
- Find duplicate reports
- Review technical logs
- Track investigation progress
- Close resolved issues

---

# Navigation

```text
Admin Dashboard

↓

Diagnostics

    • Reports
    • Statistics
```

---

# Dashboard Layout

The Diagnostics page contains:

```text
----------------------------------------------------
Filters
----------------------------------------------------

Statistics Cards

----------------------------------------------------

Reports Table

----------------------------------------------------
```

---

# Statistics Cards

Version 1 displays:

```text
New Reports

Investigating

Duplicates

Closed

Critical Reports

Today's Reports
```

Each card opens the filtered report list.

---

# Reports Table

Columns:

```text
Status

Severity

Reason

Platform

App Version

Feature

Created At

Duplicate

Actions
```

Default sorting:

```text
Newest First
```

---

# Filters

Supported filters:

```text
Status

Severity

Platform

App Version

Feature

Reason

Date Range

Duplicate
```

Multiple filters may be combined.

---

# Search

Global search supports:

- reportId
- clientReportId
- sessionId
- Firebase UID
- route
- feature
- app version

Search is case-insensitive.

---

# Report Details

Selecting a report opens a details panel.

Sections:

```text
Overview

Application

Device

User

Screen

Logs

Timeline

Admin
```

---

# Overview Section

Displays:

```text
Report ID

Client Report ID

Status

Severity

Reason

Created At

Received At

Duplicate

Duplicate Of
```

---

# Application Section

Displays:

```text
Platform

App Version

Build Number

Flavor
```

---

# Device Section

Displays:

```text
Manufacturer

Model

Operating System

OS Version

Locale

Timezone
```

---

# User Section

Displays:

```text
Firebase UID

Guest

Anonymous

Role
```

---

# Screen Section

Displays:

```text
Current Route

Current Feature
```

---

# Logs Section

Displays all log entries.

Columns:

```text
Timestamp

Level

Category

Message
```

Selecting a log expands:

- metadata
- stack trace
- structured data

---

# Timeline

Displays backend lifecycle.

Example:

```text
Created

↓

Queued

↓

Uploaded

↓

Stored

↓

Triaged

↓

Investigating

↓

Fixed

↓

Closed
```

---

# Status Management

Allowed status transitions:

```text
new

↓

triaged

↓

investigating

↓

fixed

↓

closed
```

Alternative outcomes:

```text
duplicate

ignored
```

Only administrators may change status.

---

# Duplicate Handling

If a report is marked duplicate:

Display:

```text
Original Report

Duplicate Report

Fingerprint

Duplicate Count
```

Allow navigation to the original report.

---

# Admin Notes

Administrators may add notes.

Examples:

```text
Confirmed bug

Needs reproduction

Fixed in build 1.2.8

Waiting for QA
```

Notes are visible only to administrators.

---

# Screenshot

If a screenshot URL exists:

Display:

```text
View Screenshot
```

Version 1 does not support screenshot upload.

---

# Report Actions

Available actions:

```text
Mark Triaged

Mark Investigating

Mark Fixed

Close

Mark Duplicate

Ignore

Copy Report ID
```

---

# Export

Version 1:

No export.

Future versions may support:

```text
CSV

JSON
```

---

# Permissions

Administrators:

```text
Read

Update

Add Notes

Change Status
```

Non-admin users:

```text
No Access
```

---

# Performance

Target load time:

```text
< 2 seconds
```

Pagination required.

Default page size:

```text
50 reports
```

---

# Empty State

If no reports exist:

```text
No diagnostics reports found.
```

---

# Error State

If loading fails:

```text
Unable to load diagnostics reports.
```

Provide:

```text
Retry
```

button.

---

# Future Features

Planned additions:

```text
AI Classification

GitHub Issue Link

Telegram Alert

Slack Alert

BigQuery Export

Crash Grouping

Regression Detection

Trend Charts

Heatmaps

Advanced Search
```

These features are intentionally excluded from Version 1.

---

# Final Rule

The Diagnostics Dashboard is a read-and-review interface.

It must never:

- generate reports
- modify client payloads
- edit logs
- overwrite backend metadata

Only administrative review fields may be updated.