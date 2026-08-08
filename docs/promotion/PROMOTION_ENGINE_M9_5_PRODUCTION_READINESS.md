# Promotion Engine M9.5 — Production Readiness & Reconciliation Hardening

Status: implemented locally. This milestone adds operational trust signals and
repair tooling; it does not add a dashboard or change Promotion commercial
behavior.

## Why M9.5 exists

M9 established trusted Product, Vet, and Groomy attribution, but M10 must not
infer financial trust from the existence of an attribution document or from
client analytics. M9.5 makes reconciliation health explicit, closes the unpaid
source test gap, removes Promotion fixture races, and defines the normalized
read contract that a future owner-facing surface may consume.

## Reconciliation health

Server-owned health values are:

| Status | Meaning |
| --- | --- |
| `CONVERGED` | The authoritative source is paid/finalized or authoritatively reversed and the attribution/stat delta was applied transactionally. |
| `PENDING` | The source is qualified but unpaid, or a retryable correlation/reconciliation step has not completed. |
| `AMBIGUOUS` | More than one campaign qualifies, or refund allocation is not authoritative. It is never guessed into success. |
| `FAILED` | Validation, currency, ledger, or transaction failure. The source can be retried. |

Attribution records are the trusted materialized ledger. Campaign stats are a
derived aggregate and now carry `reconciliationStatus` and
`financialMetricsStatus`.

## Financial metrics capability

The stats read model exposes:

`financialMetricsStatus`: `AVAILABLE`, `PROVISIONAL`, or `UNAVAILABLE`.

`AVAILABLE` requires a financially supported target, immutable campaign spend,
matching currency, and a converged server attribution state. `PROVISIONAL`
means the campaign may have a qualified, pending, ambiguous, or failed record;
ROAS is therefore null. `UNAVAILABLE` applies to PET and unsupported financial
cases. A valid converged campaign with zero financial conversions may report
zero revenue and ROAS zero; N/A is not represented as zero.

PET remains permanently non-financial in this milestone: revenue and ROAS are
N/A. No client field can change these capabilities.

## Retry and repair paths

The existing deterministic path remains:

```text
authoritative source ID
        ↓
domain adapter
        ↓
validated prior interaction
        ↓
transactional attribution delta
        ↓
campaign stats
```

Re-running `reconcilePromotionConversion` for a known Product seller order,
Vet appointment, or Groomy appointment uses the deterministic campaign/source
attribution ID and is safe after a timeout or transaction contention.

`repairPromotionCampaignStats({campaignId})` is a bounded backend helper for
one campaign. It reads at most 500 attribution records for that campaign,
recomputes only qualified/financial/revenue/refund counters, and transactionally
repairs the stats document. It does not rebuild impression/click telemetry and
does not scan all campaigns. Repeated repair is identical. No automatic sweep
is scheduled or deployed by M9.5; operational callers must provide a specific
campaign ID and bounded invocation.

Ambiguous records are not repaired into `AVAILABLE`. Currency mismatches fail
closed. A temporary write failure leaves the domain payment untouched and is
retryable through the same source-ID reconciliation path.

## Refund coverage

- Single Product item full refund: supported when the authoritative amount is present.
- Single Product item partial refund: supported when the return item amount is authoritative.
- Multi-item refund with item allocation: supported per item.
- Multi-item refund without item allocation: `AMBIGUOUS`/pending; no proportional allocation.
- Vet/Groomy refund: supported where the appointment exposes an authoritative refund amount.
- Unpaid Product, Vet, or Groomy source: `QUALIFIED`/`PENDING`; never financial revenue.

## Attribution-window boundary

`m9_same_flow_v1` and its 30-minute limit are a technical stale-correlation
safeguard. They are not an approved commercial attribution window, first-click
policy, or last-click policy. No 7-day, 14-day, or 30-day marketing policy has
been adopted. The distinction is intentionally preserved for future policy
approval.

## Normalized M10 read contract

M10 should read the existing server stats callable/read model, not raw events
or `promotion_attributions`:

```text
PromotionPerformance {
  campaignId
  spend
  currency
  impressions
  clicks
  detailViews
  qualifiedConversions
  financialConversions
  attributedRevenue
  refundedRevenue
  netAttributedRevenue
  ctr
  conversionRate
  roas
  financialMetricsStatus
  reconciliationStatus
  lastReconciledAt
}
```

Ratios are derived from server-owned counters. `roas` is null for PET,
unsupported targets, unresolved reconciliation, currency mismatch, or zero
spend. For an AVAILABLE supported campaign, zero attributed revenue is a real
zero and produces ROAS zero.

## Security and privacy

`promotion_attributions`, `promotion_events`, and stats mutations remain
backend-only. Owners receive only their normalized campaign stats. Attribution
records contain stable domain/campaign IDs and financial facts needed for audit,
not customer contact data, card data, or provider secrets.

## Test closure and isolation

The final M9 suite covers paid and unpaid Product/Vet/Groomy sources, duplicate
and concurrent reconciliation, full refund convergence, ambiguous refunds,
wrong currency, exact service identity, repair, and PET non-financial behavior.
M3/M4 plan fixtures now use private IDs; the prior combined failure was caused
by shared plan documents and M8's intentional historical-price mutation.
The Promotion suite passes when run sequentially together and when M3/M9 are
run independently.

## Performance

A normal reconciliation uses a bounded interaction query, one campaign read,
domain adapter reads, and a transaction containing one attribution read plus
one stats read and two writes. A campaign repair performs one bounded
attribution query and one stats transaction. A performance read performs one
campaign read and one stats read. No payment reads occur in ranking or the
performance read model.

## Remaining limitations and M10 recommendation

The commercial attribution window remains unapproved; ambiguous refund records
need operational follow-up; cross-currency attribution and large-scale export
remain deferred. M10 is **NO-GO for financial UI** until product owners approve
the attribution policy and an operational process exists for pending/ambiguous
records. The recommended next milestone is attribution policy approval plus
bounded operational reconciliation monitoring, not dashboard implementation.
