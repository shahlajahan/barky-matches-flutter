# Payout Engine V2
**Status:** Approved
**Version:** 2.0
**Date:** 2026-07-26

---

# Purpose

This document defines the final architecture for the PetSupo platform-wide payout system.

It replaces the Pet Shop specific payout implementation with a shared payout engine that supports every business sector while keeping a single source of truth for financial state.

This document intentionally contains **architecture only**.

No implementation details.

No code examples.

---

# Goals

The platform must support:

- Veterinary
- Grooming
- Pet Hotel
- Pet Taxi
- Pet Shop

using one shared payout engine.

The architecture must support future:

- Accounting
- Tax reporting
- Bank reconciliation
- Business analytics
- Financial audits

without changing the source-of-truth model.

---

# Architecture Overview

```
                     Source Documents
                            │
                            │
                            ▼
                  Shared Payout Engine
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
      payoutIndex                  financialEvents
   (Read Projection)            (Immutable Ledger)
```

---

# Core Principles

## 1. Single Source of Truth

The current payout state always lives inside the original business document.

Examples:

```
sellerOrders/{id}.payout

vet_appointments/{id}.payout

groomy_appointments/{id}.payout

hotel_bookings/{id}.payout

pet_taxi_bookings/{id}.payout
```

No other collection is allowed to become authoritative.

---

## 2. Shared Payout Engine

All payout operations are executed through one shared engine.

No sector-specific payout implementations should exist.

The engine is parameterized by:

- collection
- document
- sector configuration

Business rules may differ by sector.

Infrastructure must remain shared.

---

## 3. Read Projection

A rebuildable read model exists for:

- Admin dashboard
- Reporting
- Excel export
- Weekly payout batches
- BI

Projection name:

```
payoutIndex
```

Properties:

- rebuildable
- disposable
- eventually consistent

The projection is NEVER used for financial decisions.

Deleting the entire projection must never affect financial correctness.

---

## 4. Immutable Financial Ledger

Every financial state transition creates one immutable event.

Collection:

```
financialEvents
```

Purpose:

- audit
- accounting
- investigations
- tax reporting
- bank reconciliation

Events are append-only.

Events are never updated.

Events are never deleted during normal operation.

---

# Source of Truth

| Concept | Source |
|----------|--------|
| Current payout status | Source document |
| Current payout amount | Source document |
| Hold state | Source document |
| Recovery state | Source document |
| Debt state | Source document / debt records |
| Admin reporting | payoutIndex |
| Audit history | financialEvents |

---

# Architectural Rules

## Rule 1

Business logic MUST read payout state only from the source document.

Never from payoutIndex.

Never from financialEvents.

---

## Rule 2

financialEvents is history.

It is NOT state.

---

## Rule 3

payoutIndex is a projection.

It is NOT state.

---

## Rule 4

If payoutIndex is deleted completely,
the platform must continue operating correctly.

---

## Rule 5

If financialEvents is unavailable,
new payouts must still be blocked until event logging is restored.

Financial events are mandatory for auditing.

---

## Rule 6

Every payout transition generates one financial event.

No exceptions.

---

# Supported State Machine

Example:

```
pending

↓

eligible

↓

scheduled

↓

ready

↓

paid
```

Possible side states:

```
hold

recovery_required
```

Transitions are controlled only by the shared payout engine.

---

# Shared Components

The following services are shared across every business sector.

- payout engine
- payout scheduler
- payout validator
- payout calculator
- refund handler
- debt handler
- payout notifier
- bank account validator

---

# Sector Adapter

Each sector defines only its configuration.

Example:

- collection
- anchor timestamp
- business id field
- payout eligibility rules

The engine never contains sector-specific branching.

---

# Refunds

Refund policies remain sector-specific.

Financial consequences are shared.

Examples:

- hold payout
- reduce payout
- create debt
- recover debt

These actions are performed through one shared refund pipeline.

---

# Debts

Outstanding debts are platform-wide.

Debt records are independent financial entities.

They are not projections.

---

# Weekly Scheduler

One scheduler runs for every sector.

Responsibilities:

- detect eligibility
- calculate payout date
- prepare payout batch

The scheduler is parameterized through the sector adapter.

---

# Admin

The admin system operates exclusively on:

```
payoutIndex
```

Actions initiated by admins are executed through the shared payout engine.

Admin pages never modify payoutIndex directly.

---

# Business Dashboard

Business users read current payout information directly from their source documents.

Dashboard summaries may optionally use payoutIndex for reporting.

---

# Financial Events

Each event records:

- event type
- source collection
- source document
- sector
- business
- actor
- previous state
- new state
- amount
- currency
- timestamps
- reason
- metadata

Events are immutable.

---

# Non-Goals

This architecture is NOT:

- Event Sourcing
- Double-entry accounting
- ERP
- General Ledger

These may be introduced later without changing the payout source-of-truth model.

---

# Future Extensions

This architecture is designed to support:

- automatic bank transfers
- accounting exports
- ERP integration
- BI pipelines
- fraud detection
- payout analytics
- tax reporting

without changing the current architecture.

---

# Design Invariants

The following statements must always remain true.

1.

There is exactly one source of truth for current payout state.

2.

Business logic never depends on projections.

3.

Business logic never depends on historical events.

4.

Every financial transition is recorded exactly once.

5.

Financial history is immutable.

6.

The projection is always rebuildable.

7.

The payout engine is shared by every business sector.

---

# Final Decision

Current State

→ Source Documents

Shared Logic

→ Shared Payout Engine

Read Model

→ payoutIndex

Historical Ledger

→ financialEvents

This architecture is approved as the platform-wide payout architecture for PetSupo.

---

# Phase 1 Implementation — Standardized Payable Contract

**Implemented:** 2026-07-28

Every supported revenue-generating source document exposes a canonical
`payout` object. The source document remains authoritative.

## Canonical `payout` fields

- `version`
- `sector`
- `businessId`
- `status`
- `amount`
- `currency`
- `currencyRaw`
- `requestedAt`
- `readyAt`
- `paidAt`
- `reference`
- `note`
- `previousStatus`
- `holdAt`
- `holdReason`
- `recoveryRequiredAt`
- `recoveryReason`
- `outstandingDebt`
- `relatedReturnIds`
- `updatedAt`

`amount` is the normalized business receivable produced by the existing
commission snapshot. Existing Pet Shop payout values are preserved when legacy
records are normalized.

## Adapter contract

Each sector registers:

- its source collection
- its payout normalizer
- its business identifier extractor
- optional sector-specific payout guards or recovery identity extractors

Registered Phase 1 sectors:

| Sector | Source collection |
|---|---|
| Pet Shop | `sellerOrders` |
| Veterinary | `vet_appointments` |
| Grooming | `groomy_appointments` |
| Pet Hotel | `hotel_bookings` |
| Pet Taxi | `pet_taxi_bookings` |

Collection-to-sector resolution is derived from the adapter registry. The
shared payout engine consumes only the selected adapter and normalized payable
contract.

This phase does not introduce `payoutIndex`, scheduling, payout batches, bank
settlement, debt recovery, or UI changes.

---

# Payment and Settlement Finalization

Verified payment finalization and settlement are independent stages.

## Payment

```text
payment_pending → processing → completed
                              ↘ failed
```

After a verified bank callback, the order/appointment payment fields and the
financial snapshot are persisted before any payout contract is attempted.
`payment.finalizationStatus: completed` is never reverted by settlement.

## Settlement

```text
not_started → processing → completed
                        ↘ failed
                        ↘ blocked
```

Settlement consumes the persisted financial snapshot. It never recalculates
commission. A negative `businessNetAmount` is recorded as
`settlement.status: blocked` with `reason: NEGATIVE_PAYABLE`; it is not clamped
and does not create a payout contract.

Settlement failures record `failureCode`, `failureMessage`, `attempts`, and
`lastAttemptAt` without changing payment state. Settlement retries inspect the
already-completed payment and never contact a payment provider.

# Payout Index Projection

`payoutIndex` is a read-only projection. Canonical ownership remains on
`sellerOrders`, `vet_appointments`, `groomy_appointments`, `hotel_bookings`,
and `pet_taxi_bookings`.

Each index row is keyed by `buildPayoutIndexId(sourceCollection,
sourceDocumentId)` and contains independent `payoutStatus`, `settlementStatus`,
`settlementFailureCode`, and `settlementFailureMessage` fields. Rows also
carry `sourceUpdatedAt`, `projectedAt`, `payoutContractVersion`, and
`projectionVersion`; stale source events are ignored.

The initial admin views query `pending`, `ready`, and `paid` payout statuses.
The schema also supports `hold`, `recovery_required`, `awaiting_invoice`,
`blocked`, and `failed`. Blocked and awaiting-invoice settlements remain
indexable even when hidden from those tabs.

The first search implementation uses normalized exact-token fields and local
filtering. It does not claim partial full-text search support from Firestore.
`functions/scripts/backfillPayoutIndex.js` is an Admin SDK-only, dry-run,
paginated, resumable backfill and never modifies source documents.
