# ENG-001 — Startup Performance Audit

Status: ✅ CLOSED

Priority: P0

Owner: Codex

Reviewer: ChatGPT

Decision: Approved

Closed Date: 2026-07-08

---

# Objective

Determine why Android startup is significantly slower than iOS and identify the startup critical path without modifying any code.

---

# Result

Audit completed successfully.

The report was reviewed and accepted.

No code changes were made.

The engineering review concluded that the audit provides sufficient evidence for future implementation planning.

---

# Key Findings

## Confirmed

- Pre-runApp initialization performs significant blocking work.
- HomePage startup launches multiple expensive initialization tasks.
- AppState startup sequence contributes to startup latency.
- Startup work is now classified by execution phase, blocking behavior, and priority.

## Hypotheses

- Firestore persistence configuration may contribute to startup latency.
- Android renderer behavior requires runtime profiling before conclusions.

---

# Deliverables

- Executive Summary
- Startup Timeline
- Critical Path
- Main Thread Analysis
- Startup Cost Matrix
- Minimum Startup Requirements
- Root Cause Ranking
- Safe Implementation Plan

---

# Review Decision

Engineering Review: PASSED

The audit is accepted.

No further investigation is required before proceeding to the next engineering audit.

---

# Next Epic

ENG-002 — AppState Architecture Audit

Reason:

Startup analysis shows that AppState is one of the primary contributors to application startup complexity. AppState architecture should be audited before implementing startup optimizations.

---

# Notes

This document is an engineering audit.

It is intentionally implementation-free.

Implementation will be tracked separately under:

ENG-001-IMP — Startup Optimization