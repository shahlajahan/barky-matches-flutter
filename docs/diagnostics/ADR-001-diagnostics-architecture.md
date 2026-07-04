# ADR-001 — Diagnostics Architecture

Version: 1.0

Status: Approved

Owner: Petsupo Engineering

Date: 2026-07-04

---

# Context

Petsupo is a large Flutter + Firebase application composed of multiple
independent domains including:

- Veterinary
- Groomy
- Pet Hotel
- Pet Taxi
- Marketplace
- Adoption
- Medical Records
- Social Community
- Admin Systems

As the application grows, identifying production issues using console logs
or tester descriptions becomes increasingly difficult.

A dedicated diagnostics platform is required to provide structured,
session-aware error reporting without coupling feature code to backend
infrastructure.

---

# Problem Statement

The previous debugging workflow relied on:

- debugPrint()
- Flutter console
- manual tester feedback

This approach has several limitations:

- No access to tester logs in production.
- No session context.
- No structured diagnostics.
- Difficult reproduction of issues.
- Feature implementations become responsible for debugging.

This architecture does not scale.

---

# Decision

Petsupo introduces a dedicated Diagnostics Platform.

Diagnostics becomes an independent subsystem responsible for:

- structured logging
- diagnostics buffering
- diagnostics report generation
- diagnostics delivery
- production diagnostics collection

Feature modules are no longer responsible for diagnostics transport.

---

# Goals

The diagnostics platform shall:

- capture structured events
- preserve session context
- collect critical failures
- remain independent from business logic
- support future backend integrations
- minimize impact on feature development
- remain extensible

---

# Non-Goals

The diagnostics platform is NOT intended to:

- replace analytics
- replace business event tracking
- replace Crashlytics
- perform product telemetry
- perform user behavior analysis

Diagnostics focuses only on application health.

---

# Architecture

The diagnostics platform is composed of independent layers.

```
Feature
      │
      ▼
AppLog
      │
      ▼
DiagnosticsBuffer
      │
      ▼
DiagnosticsReporter
      │
      ▼
DiagnosticsUploader
      │
      ▼
Cloud Function
      │
      ▼
Firestore
      │
      ▼
Admin Diagnostics
```

Each layer owns a single responsibility.

---

# Component Responsibilities

## AppLog

Responsible for:

- structured log creation
- log categories
- log levels

AppLog never performs networking.

---

## DiagnosticsBuffer

Responsible for:

- maintaining current session logs
- bounded memory storage
- preserving event order

The buffer is memory-only.

---

## SessionManager

Responsible for:

- session identifier generation
- session lifetime

One application launch equals one session.

---

## DiagnosticsReporter

Responsible for:

- capturing diagnostics reports
- duplicate suppression
- immutable report generation

Reporter never performs uploads.

---

## DiagnosticsUploader

Responsible for:

- report delivery
- retry policy
- offline queue
- upload lifecycle

Uploader is the only component allowed to communicate with backend diagnostics services.

---

## Backend

Backend responsibilities include:

- validation
- storage
- rate limiting
- future enrichment
- diagnostics management

---

# Layer Boundaries

Feature code may:

- create logs
- report critical failures

Feature code may NOT:

- upload diagnostics
- write diagnostics to Firestore
- call diagnostics backend APIs directly

All diagnostics communication must pass through the Diagnostics Platform.

---

# Session Lifecycle

Application Launch

↓

Session Created

↓

Logs Generated

↓

Critical Failure (optional)

↓

Diagnostics Report Created

↓

Report Uploaded (future)

↓

Session Ends

---

# Design Principles

The platform follows:

- Single Responsibility Principle
- Separation of Concerns
- Architecture First
- Replaceable Infrastructure
- Composition over Coupling

---

# Architectural Constraints

The following are prohibited:

- direct Firestore writes from features
- diagnostics networking inside UI
- backend access from widgets
- feature-specific diagnostics pipelines

---

# Extensibility

The architecture allows future integrations including:

- Crashlytics
- BigQuery
- External Observability Platforms
- Performance Monitoring
- Network Diagnostics

without changing feature implementations.

---

# Alternatives Considered

## Direct Firestore writes

Rejected.

Reason:

Strong coupling between features and backend.

---

## Direct HTTP uploads

Rejected.

Reason:

No centralized validation or lifecycle management.

---

## Analytics-only approach

Rejected.

Reason:

Analytics and diagnostics serve different purposes.

---

# Consequences

Positive:

- clean architecture
- reusable diagnostics
- centralized debugging
- production-ready observability

Trade-offs:

- additional infrastructure
- more initial design effort
- extra backend components

These trade-offs are accepted.

---

# Future ADRs

Future architectural changes must extend this ADR instead of bypassing it.

Major revisions require a new ADR version.

---

# Final Decision

Petsupo adopts a centralized Diagnostics Platform.

Diagnostics is treated as an independent subsystem.

All future diagnostics capabilities must preserve this architecture.