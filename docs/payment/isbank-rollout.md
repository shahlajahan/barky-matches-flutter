# İş Bank Sanal POS Rollout Plan

## Overview

This document tracks the implementation of İş Bank Sanal POS integration into the existing PetSupo payment system.

### Goals

* Integrate İş Bank Sanal POS.
* Keep the existing iyzico implementation fully operational.
* Avoid any payment refactoring.
* Preserve the current Flutter payment flow.
* Make all changes backend-first.
* Allow switching providers from backend configuration.

---

# Architecture Decision

## Selected Strategy

Backend-first incremental integration.

Flutter should remain unchanged during the first rollout.

The backend will decide which payment provider is active.

Current callable function names will remain unchanged.

Current checkout flow will remain unchanged.

Current Firestore schema will remain unchanged.

---

# Non Goals

The following are intentionally out of scope:

* Payment refactor
* Payment gateway abstraction
* paymentAttempts redesign
* paymentEvents redesign
* Order schema redesign
* Flutter payment UI redesign

These may be implemented in a future version.

---

# Implementation Principles

* Every patch must compile.
* Every patch must be deployable.
* Every patch must be testable.
* Existing iyzico flow must continue working.
* Existing Firestore documents must remain compatible.
* No breaking API changes.

---

# Rollout Checklist

| Patch | Description                 | Status | Tested | Deployed |
| ----- | --------------------------- | ------ | ------ | -------- |
| 1     | İş Bank Config              | ☐      | ☐      | ☐        |
| 2     | Pure Helpers                | ☐      | ☐      | ☐        |
| 3     | 3DS Start Endpoint          | ☐      | ☐      | ☐        |
| 4     | Callback Skeleton           | ☐      | ☐      | ☐        |
| 5     | Finalization Helpers        | ☐      | ☐      | ☐        |
| 6     | Callback Integration        | ☐      | ☐      | ☐        |
| 7     | Marketplace Provider Branch | ☐      | ☐      | ☐        |
| 8     | Appointment Provider Branch | ☐      | ☐      | ☐        |
| 9     | Pet Taxi Provider Branch    | ☐      | ☐      | ☐        |
| 10    | Marketplace Verify Guard    | ☐      | ☐      | ☐        |
| 11    | Generic Verify Guard        | ☐      | ☐      | ☐        |
| 12    | Pet Taxi Verify Guard       | ☐      | ☐      | ☐        |

---

# Regression Tests

After every patch verify:

* Marketplace payment (iyzico)
* Vet appointment payment
* Groomy payment
* Hotel payment
* Pet Taxi payment

All existing payment flows must continue working.

---

# Rollback Strategy

If any patch causes regression:

1. Revert only that patch.
2. Deploy previous Functions version.
3. Confirm iyzico payments work.
4. Continue after root cause analysis.

---

# Definition of Done

The rollout is complete when:

* İş Bank checkout works.
* İş Bank callback finalizes payments.
* Existing iyzico payments continue working.
* No Flutter payment flow changes are required.
* Existing Firestore schema remains compatible.
* All regression tests pass.
