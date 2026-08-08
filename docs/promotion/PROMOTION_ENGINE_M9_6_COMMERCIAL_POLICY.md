# Promotion Engine M9.6 — Commercial Attribution Policy & Operations Gate

Status: implemented locally. This is a policy and operations milestone, not an
M10 UI milestone.

## 1. V1 commercial attribution decision

PetSupo V1 adopts `petsupo_same_flow_v1`.

Financial attribution requires a validated same-flow chain:

```text
Promotion CLICK/DETAIL_VIEW
        ↓ exact target and actor
checkout or booking flow
        ↓ authoritative domain identity
paid/final commercial source
        ↓ server reconciliation
campaign financial metrics
```

V1 deliberately prefers under-attribution over financially over-crediting a
campaign. There is no 7-day, 14-day, 30-day, first-click, last-click, or
multi-touch policy.

## 2. Technical correlation TTL

`m9_same_flow_v1` remains the technical correlation policy and its 30-minute
limit is a technical correlation TTL. It prevents stale or weak interaction
correlation from being treated as same-flow proof. It is not a commercial
marketing attribution window. Both values are preserved on new attribution
records:

- `commercialAttributionPolicyVersion`: `petsupo_same_flow_v1`
- `technicalCorrelationPolicyVersion`: `m9_same_flow_v1`
- `technicalCorrelationTtlMinutes`: `30`

The existing `attributionPolicyVersion` field remains `m9_same_flow_v1` for
historical compatibility and is not reinterpreted.

## 3. Domain policy

PRODUCT requires exact Product identity, a prior same-flow interaction,
matching seller/business, paid authoritative order state, matching currency,
and a valid item-level amount. Revenue is attributed Product GMV for the
promoted order item only; unrelated order items receive no credit.

VET requires the exact canonical Vet SERVICE target, matching business,
authoritative paid appointment state and financial amount, and matching
currency.

GROOMY follows the same principle through Groomy’s own appointment lifecycle;
Vet field/status assumptions are not imported into the Groomy adapter.

PET remains non-financial. It may report impressions, clicks, and detail views,
but `financialMetricsStatus` is `UNAVAILABLE`, with revenue and ROAS N/A.

## 4. Reconciliation operations

| Status | V1 meaning | Operational action |
| --- | --- | --- |
| `CONVERGED` | Authoritative financial or reversal truth was applied transactionally. | May contribute to final campaign metrics. |
| `PENDING` | Retryable source reread, missing same-flow proof, or unpaid source. | Retry deterministically by source ID. |
| `FAILED` | Validation, currency, transaction, or write failure. | Investigate safe error category and retry. |
| `AMBIGUOUS` | Authoritative attribution/refund allocation is not unique. | Do not guess; wait for authoritative domain resolution. |

`PENDING` and `FAILED` remain provisional. `AMBIGUOUS` never becomes success by
repeated blind retry. A source may converge only when its authoritative data
becomes unambiguous.

The deterministic retry path is:

```text
known source ID → reread domain state → revalidate interaction/campaign
→ transactional delta → CONVERGED when resolvable
```

No manual arbitrary revenue override exists. Staff must not proportionally
allocate an ambiguous refund or type financial amounts into Promotion records.

## 5. Operational monitoring

Backend/admin health is exposed through the bounded
`readPromotionReconciliationHealth` callable/helper. It reads operational
`promotion_reconciliation_cases`, not raw payment data, and reports:

- pending, failed, ambiguous, and converged counts;
- oldest unresolved attempt;
- last reconciliation attempt;
- bounded affected campaign IDs;
- policy and technical TTL versions.

The helper is admin/server-authorized. Cases use deterministic source identity,
attempt counts, safe error categories, and no customer PII or secrets. The
query is bounded at 500 records per status. No automatic sweep is scheduled by
M9.6.

## 6. Campaign financial status

The backend derives:

- `AVAILABLE`: financial target supported, spend and currency valid, and no
  material unresolved attribution remains;
- `PROVISIONAL`: pending, failed, or ambiguous truth may change the result;
- `UNAVAILABLE`: PET, unsupported target, invalid financial basis, currency
  mismatch, or zero spend for ROAS purposes.

Clients cannot select or mark these states.

## 7. Zero, N/A, and provisional semantics

For a supported, fully reconciled campaign with zero conversions:

```text
attributedRevenue = 0
roas = 0
```

PET revenue/ROAS is N/A. Currency mismatch, unresolved truth, unsupported
targets, and zero spend produce null/N/A ROAS rather than a misleading zero.

## 8. M10 read contract

M10 must consume the normalized campaign stats read model only:

```text
PromotionPerformance {
  campaignId, spend, currency,
  impressions, clicks, detailViews,
  qualifiedConversions, financialConversions,
  attributedRevenue, refundedRevenue, netAttributedRevenue,
  ctr, conversionRate, roas,
  financialMetricsStatus, reconciliationStatus, lastReconciledAt
}
```

M10 must not read `promotion_attributions`, raw payment records, or
`promotion_events`, and must not understand Product/Vet/Groomy lifecycle or
decide financial trust.

## 9. Security and limitations

Attribution, reconciliation cases, and stats remain server-owned. Business
owners can read only their normalized campaign stats. Hotel, Taxi, and
Business remain disabled. Cross-currency and multi-touch attribution remain
future work.

The commercial policy is now explicit, but operational monitoring is bounded
and requires staff/admin action. Historical records preserve the policy used
at attribution time; future policy versions cannot reinterpret them.

## 10. M10 gate

M9.6 removes the policy ambiguity and defines the operations contract. M10 is
**GO only for a read-only performance surface after an operations owner accepts
the bounded monitoring/retry process**. No dashboard is implemented here.
