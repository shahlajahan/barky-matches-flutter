# Promotion Engine M10 — Read-only Performance UI

## Objective

M10 adds a small owner-facing performance experience for the enabled targets:
PET, PRODUCT, VET SERVICE, and GROOMY SERVICE. It is read-only and consumes
the normalized server-owned performance contract from M9.6.

## Read contract and authorization

The client calls `readPromotionCampaignStats(campaignId)`. The backend reads
only the owner-authorized `promotion_campaigns/{campaignId}` snapshot and
`promotion_campaign_stats/{campaignId}` aggregate. A different owner or an
unauthenticated caller is rejected. The response does not include raw
attribution records, payment/provider data, orders, appointments, buyer data,
or reconciliation-case internals.

```
promotion_campaigns
        │ campaign snapshot
promotion_campaign_stats
        │ normalized aggregates
        ▼
readPromotionCampaignStats
        ▼
PromotionCampaignStats
        ▼
read-only owner performance page
```

The first entry point is the confirmed-active post-checkout flow. After a
successful server-confirmed activation, the generic plan sheet offers the
same performance page for Pet, Product, Vet, and Groomy campaigns. Hotel,
Taxi, and Business have no entry point because they remain disabled.

## Target semantics

| Target | Exposure Metrics | Financial Conversion | Revenue | ROAS |
| --- | --- | --- | --- | --- |
| PET | Yes | N/A | N/A | N/A |
| PRODUCT | Yes | Yes when trusted | Yes when trusted | Yes when AVAILABLE |
| VET SERVICE | Yes | Yes when trusted | Yes when trusted | Yes when AVAILABLE |
| GROOMY SERVICE | Yes | Yes when trusted | Yes when trusted | Yes when AVAILABLE |

PET shows impressions, clicks, CTR, and detail views only. It does not show
zero-valued revenue or ROAS. Supported financial targets show financial cards
only under the server-derived capability/status contract.

## Campaign summary and metrics

The summary uses immutable campaign values: status, fixed duration, start/end,
currency, and purchase-time spend. Current plan prices cannot rewrite
historical spend. Exposure cards show impressions, clicks, CTR, and detail
views. Financial cards show financial conversions and net attributed revenue;
final ROAS is shown only when `financialMetricsStatus == AVAILABLE`.

`AVAILABLE` means supported, sufficiently reconciled financial truth.
`PROVISIONAL` means results may still change; the UI labels reconciliation in
progress and does not show final ROAS. `UNAVAILABLE` is a normal non-error
state for PET and for unsupported, invalid-spend, or currency-invalid data.

Zero semantics remain from M9.6: a fully reconciled supported campaign with
zero conversions may show revenue 0 and ROAS 0. PET, currency mismatch,
unresolved financial truth, and zero spend show N/A/not applicable rather than
pretending that the value is zero.

## UX and localization

The page uses existing dashboard metric cards and responsive grids. It uses a
scrollable layout and wraps summary fields so it remains safe on small phones,
large text settings, tablets, and desktop widths. Loading, retry, and generic
authorization/not-found/network failure states are provided. Provisional is
shown as processing, not as an error. User-facing strings were added to the
existing English, Turkish, Persian, and Russian localization files.

No charts are included: M8/M9 do not provide a trustworthy daily time-series
aggregate, and M10 does not scan raw events on-device.

## Privacy and performance

The owner sees aggregate campaign performance only. No buyer/customer PII,
raw attribution IDs, provider transaction IDs, payment credentials, or domain
transaction details are shown. The normal page requires one campaign read and
one stats read through the server callable. It performs no campaign-per-result
reads, payment reads, order reads, appointment reads, or raw-event scans.

## Tests

M10 coverage includes normalized model parsing, PET financial omission,
Product AVAILABLE and PROVISIONAL rendering, responsive widget behavior, and
server owner authorization, missing-stats handling, immutable spend, PET
UNAVAILABLE semantics, zero-spend ROAS N/A, and omission of sensitive fields.

## Known limitations and M11 recommendation

There is no campaign history/list, target metadata lookup, date-range filter,
or time-series chart in M10. The post-checkout entry point keeps scope small;
existing campaigns need a future owner campaign list before they can all be
browsed from one screen. Daily aggregates should precede chart work.

M11 should prioritize controlled production provisioning/rollout and admin
operations before expanding analytics breadth. A campaign history reader and
daily aggregates can follow once the rollout has operational evidence.
