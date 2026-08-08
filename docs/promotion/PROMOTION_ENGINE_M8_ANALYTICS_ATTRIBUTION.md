# Promotion Engine M8 — Analytics & Attribution Foundation

Status: implemented as a measurement foundation; commercial attribution and ROAS are not yet complete.

## 1. Audit and trust boundary

PetSupo already has a Flutter `AnalyticsService` backed by Firebase Analytics. Existing Vet, Groomy, and payment events are useful product telemetry, but they do not prove a Promotion exposure or a financial outcome. Trusted marketplace payment state is held in `orders`/`sellerOrders`; paid appointment state is held in `vet_appointments` and `groomy_appointments`, with final financial snapshots produced by server payment finalization.

M8 reuses the existing Flutter analytics wrapper for telemetry and adds a Promotion-specific callable ingestion path. Client events may describe exposure, click, and detail-view interaction. They may never declare spend, revenue, payment success, or conversion truth. Spend is read from the immutable campaign price snapshot. Revenue can only be added by a future trusted domain-state hook.

## 2. Event contract

`promotion_events/{eventId}` is an immutable, server-created event record. The generic contract includes `eventId`, `eventType`, `source`, `trust`, `campaignId`, `targetType`, `targetId`, owner/business/sector context from the projection, `placement`, optional session/actor identifiers, `occurredAt`, `receivedAt`, and a small metadata allow-list. No payment payload, price, spend, card data, or client-supplied revenue is stored.

| Event | Source | Trust | Financial | Deduplication | Targets |
| --- | --- | --- | --- | --- | --- |
| IMPRESSION | Flutter visibility callback + callable | telemetry | no | campaign/target/placement/session/window key | PET, PRODUCT, VET, GROOMER |
| CLICK | Flutter meaningful card/service action + callable | telemetry | no | campaign/target/placement/session key | PET, PRODUCT, VET, GROOMER |
| DETAIL_VIEW | Flutter successful detail/appointment entry + callable | telemetry | no | campaign/target/placement/session key | PET, PRODUCT, VET, GROOMER |
| PRODUCT_ORDER | trusted order finalization | server | yes | campaign + order ID | foundation hook; not wired to finalization yet |
| SERVICE_BOOKING | trusted appointment finalization | server | potentially | campaign + booking ID | foundation hook; not wired to finalization yet |
| PET_INTERACTION | trusted domain interaction | no revenue by default | server/domain-specific | campaign + interaction ID | foundation only; no fabricated revenue |

Hotel, Taxi, and Business are rejected by the M8 exposure contract because they are not enabled Promotion consumers.

## 3. Placements and semantics

Real placement IDs are `playmate_discovery`, `marketplace_product_list`, `vet_service_list`, and `groomy_service_list`. They are stable wire identifiers, not localized labels.

An impression means a promoted card/service row was reported at least 50% visible by `VisibilityDetector`; a query result alone is not an impression. The Flutter service uses a ten-minute per-session exposure key and the server transaction makes retries idempotent. Click means the promoted result opened its meaningful target flow. Detail view is the corresponding successful detail/appointment entry signal. These are telemetry signals and are not billing events.

New exposures are accepted only when `promotion_active/{campaignId}` matches the supplied target and is active at trusted server time. Expired and future projections are rejected. The campaign ID is taken from the already-loaded backend-owned projection; discovery performs no campaign or payment reads per result.

## 4. Storage and aggregation

Raw events are append-only documents in `promotion_events`. Bounded per-campaign counters are materialized in `promotion_campaign_stats/{campaignId}`. Transactions create the dedupe event and increment exactly one counter together, so concurrent distinct events do not use an unsafe read/increment/write sequence.

The stats reader returns impressions, clicks, detail views, qualified/financial conversion counters, attributed revenue, currency, immutable campaign spend, pricing version, and safe derived values. Zero impressions produces a null CTR. Spend zero, unavailable revenue, and PET revenue all produce null ROAS rather than a misleading zero.

Retention is currently the normal Firestore application retention boundary; no production backfill or warehouse pipeline is introduced in M8. A later scale boundary may move raw events to a purpose-built analytics store while keeping the campaign stats read model.

## 5. Attribution and financial semantics

Spend is `PromotionCampaign.price` plus its campaign currency/pricingVersion. A later plan price cannot rewrite historical spend.

Product financial conversion must eventually use a verified paid/final order and its authoritative product, seller, amount, currency, cancellation, and refund state. Vet and Groomy must use their respective appointment records and server-finalized payment/financial snapshots; a booking request is not automatically revenue. The current M8 release provides the validated event and stats contract but does not wire a client-callable conversion endpoint or claim revenue from existing client events. This is deliberate until a versioned click-through attribution window and finalization triggers are approved.

PET supports exposure, click, detail view, and future qualified-interaction measurement. PET Promotion does not fabricate revenue and reports ROAS as not applicable.

Attribution after campaign expiry is distinct from exposure after expiry: new exposure events are rejected, while a future server conversion hook can validate a prior click, campaign timing, target relationship, and its versioned window. No unapproved 7-day or 30-day policy is silently applied.

## 6. Server authority and privacy

`recordPromotionEvent` validates event type, target, projection identity, enabled sector, placement, timestamp skew, active window, and dedupe identity. Clients cannot write raw events or aggregates through Rules. `readPromotionCampaignStats` is owner-isolated; spend is read from the private campaign document and is never client supplied. Raw telemetry stores only the identifiers needed for dedupe and attribution, not names, email, phone, addresses, card data, or secrets.

The Flutter transport is best effort and does not block rendering, navigation, or checkout. Firebase Analytics remains a product-telemetry mirror; the callable is the validated Promotion measurement source.

## 7. Architecture

```text
promotion_active
      │ campaignId + target identity
      ▼
visible promoted target
      │ visibility / meaningful action
      ▼
PromotionAnalyticsService
      ▼
recordPromotionEvent
      ▼
promotion_events ─────► promotion_campaign_stats
                              │
                      spend from campaign snapshot
                              │
      orders / Vet appointments / Groomy appointments
             trusted future finalization hooks
                              ▼
                      validated revenue attribution
                              ▼
                              ROAS
```

## 8. Performance, Rules, and data quality

For a rendered list of N promoted results, the ranking/projection layer adds
zero campaign reads and zero payment reads because M5 already preloads one
`promotion_active` query per target type. Each qualifying visible exposure or
meaningful action produces at most one best-effort callable write; the UI does
not await it. The server transaction performs one raw-event create and one
aggregate update. Ranking remains network-free and O(N log N) for the existing
bounded client-sorted surfaces. Product and service lists with server-side
pagination will eventually need a server candidate/aggregate boundary before
large-scale promotion reporting is claimed.

Rules deny all direct raw-event mutation and all aggregate mutation. Stats are
owner-isolated. Rejections are observable in structured
`promotion_event_rejected` logs with event type/campaign ID/reason, while raw
metadata is allow-listed and sensitive identity/payment data is omitted.

## 9. Validation and limitations

M8 tests cover enabled target acceptance, Hotel/Taxi/Business rejection, projection/target mismatch, expiry, placement validation, client financial injection rejection, duplicate events, concurrent counter updates, owner-isolated stats, immutable spend, and null ROAS semantics. Flutter tests cover the generic event contract, dedupe key, and stats model.

Known limitations: product/order and Vet/Groomy/appointment conversion triggers are not yet wired to final server state; refunds/cancellations therefore cannot yet be reconciled into Promotion aggregates; anonymous session telemetry is accepted only with a session ID; stats are campaign-owner read-only and there is no dashboard.

M9 should choose between a small owner performance surface and trusted conversion finalization/reconciliation based on product requirements, with scalable raw-event retention and a versioned attribution window resolved before commercial ROAS claims.
