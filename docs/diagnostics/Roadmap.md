# Diagnostics Platform Roadmap

Version: 1.0

Status: Living Document

Owner: Petsupo Engineering

Last Updated: 2026-07-04

Related Documents:

- ADR-001-diagnostics-architecture.md
- PRD-diagnostics-reporting-platform.md
- API-diagnostics-contract.md
- Backend-Architecture.md
- Firestore-Schema.md
- Cloud-Functions.md
- Admin-Dashboard.md

---

# Purpose

This roadmap defines the planned evolution of the Petsupo Diagnostics Platform.

It separates completed work from future enhancements and prevents unnecessary scope expansion during implementation.

---

# Version 1 — Foundation

Status:

```text
In Progress
```

Goal:

Build a complete diagnostics pipeline from Flutter to Firebase.

Includes:

- AppLog
- DiagnosticsBuffer
- SessionManager
- DiagnosticsReport
- DiagnosticsContextProvider
- DiagnosticsQueue (Hive)
- DiagnosticsReporter
- DiagnosticsUploader
- submitDiagnosticsReport()
- Firestore debug_reports
- Admin Diagnostics Dashboard
- Offline Queue
- Retry mechanism
- Status workflow

Does NOT include:

- Screenshot upload
- AI classification
- Crashlytics
- BigQuery
- GitHub integration
- Slack
- Telegram
- Analytics

---

# Version 2 — Developer Experience

Goal:

Improve debugging and issue triage.

Planned features:

- Screenshot upload
- Device memory usage
- Network information
- Battery level
- Crash grouping improvements
- Search enhancements
- Dashboard statistics
- Export JSON
- Export CSV

---

# Version 3 — Intelligent Diagnostics

Goal:

Reduce manual investigation.

Planned features:

- AI issue classification
- Automatic severity scoring
- Duplicate clustering
- Suggested root causes
- Suggested fixes
- Regression detection

---

# Version 4 — Team Workflow

Goal:

Integrate diagnostics into engineering workflow.

Planned features:

- GitHub Issue creation
- Jira integration
- Slack notifications
- Telegram alerts
- Team assignments
- Internal comments
- Watchers

---

# Version 5 — Analytics

Goal:

Long-term product quality monitoring.

Planned features:

- BigQuery export
- Trend analysis
- Crash rate dashboards
- Release comparison
- Platform comparison
- Feature stability reports
- Adoption metrics

---

# Future Ideas

Potential future additions:

- Session replay
- Video reproduction
- Performance traces
- Automatic log compression
- Remote diagnostics
- Feature flag snapshots
- User journey reconstruction

These items are exploratory and not scheduled.

---

# Development Rules

Before starting any roadmap item:

- Update ADR if architecture changes.
- Update PRD if product scope changes.
- Update API Contract if payload changes.
- Update Firestore Schema if storage changes.

No implementation should begin without corresponding documentation updates.

---

# Completion Criteria

Version 1 is complete when:

- Flutter diagnostics are stable.
- Offline queue works.
- Cloud Function accepts reports.
- Reports are stored in Firestore.
- Admin Dashboard can review reports.
- Retry mechanism works.
- Security rules are enforced.
- Documentation is complete.

---

# Current Focus

Active milestone:

```text
Version 1 — Foundation
```

No Version 2 or later work should begin until Version 1 is production-ready.