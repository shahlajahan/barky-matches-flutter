# Promotion Engine M9 — Trusted Conversion Attribution & Reconciliation

Status: implemented as a server-authoritative foundation for Product, Vet, and Groomy. It is not a dashboard or billing milestone.

## 1. Domain lifecycle audit

| Domain | Qualified Source | Financial Source | Amount Truth | Reversal Source |
| --- | --- | --- | --- | --- |
| PRODUCT | Product line in `sellerOrders` after a validated Promotion interaction | Root/seller order payment state is paid and finalized | Item-level `totalPrice`/line subtotal, reported as attributed GMV in the order currency | `cancellationRefund` or authoritative refunded `order_returns`; ambiguous multi-line refunds remain pending reconciliation |
| VET | `vet_appointments/{appointmentId}` with the exact `serviceId` and business | `paymentStatus=paid`, payment finalization completed, verified canonical financial snapshot | `financial.grossAmount` / final paid price, not seller net | Appointment refund status/details and authoritative refund amount |
| GROOMY | `groomy_appointments/{appointmentId}` with the exact `serviceId` and business | Same domain’s paid/finalized verified financial snapshot | `financial.grossAmount` / final paid price, not seller net | Appointment refund status/details where present |
| PET | Promotion interaction only | Not applicable | Not applicable | Not applicable |

An order/appointment request is not automatically revenue. Qualified, paid financial, and reversed states are separate. Product attribution is line-level so an order containing an organic item does not transfer that item’s value to a promoted item. Seller payout/net amount is not called Promotion revenue; the M9 metric is explicitly attributed GMV/gross paid service value.

## 2. Attribution contract and correlation

Trusted records live in `promotion_attributions/{attributionId}`. The generic record contains `attributionId`, campaign/target identity, conversion/source type and ID, owner/business identity, the matched interaction event and placement, qualified/financial timestamps, gross/refunded/net amounts, currency, status, policy version, source state, and audit timestamps.

The deterministic ID is `sha256(campaignId | sourceType | sourceId)`. Product source IDs include seller-order and line identity; Vet/Groomy source IDs are appointment IDs. Reprocessing the same authoritative source therefore converges to the same record.

The correlation engine reads only interaction events for the exact target, filters to CLICK/DETAIL_VIEW, requires the same authenticated buyer/actor, and requires the interaction to precede the authoritative source time. A technical 30-minute same-flow bound (`m9_same_flow_v1`) prevents stale attribution; this is not a commercial 7-day/30-day policy. If multiple campaigns qualify, the result is ambiguous and no revenue is credited. A current active campaign is never substituted for the campaign in the interaction.

Campaign timestamps validate that the interaction occurred during the campaign. A campaign may expire before final payment/refund reconciliation; legitimate prior interaction attribution can still converge. Currency must match the campaign exactly; no FX is performed.

## 3. State machine

```text
PENDING / no final payment
        │ validated interaction + source
        ▼
QUALIFIED ── verified final payment ──► FINANCIAL
    │                                      │
    └── invalid / mismatch ───────────────► INVALID
                                           │
                              partial refund ▼
                                  PARTIALLY_REVERSED
                                           │
                                  full refund ▼
                                      REVERSED
```

State changes are server-controlled. Qualified conversion count remains a historical qualified action after a later refund; financial conversion count becomes zero for `REVERSED` and remains one for `PARTIALLY_REVERSED`. Net attributed revenue converges to gross less authoritative refund amount.

## 4. Reconciliation and aggregation

```text
Promotion Interaction
        │
        ▼
promotion_events  ── correlation only
        │
        ▼
Authoritative Domain Transaction
   ┌────┴────┐
   │         │
Product   Vet/Groomy
 Order    Appointment
   │         │
   └────┬────┘
        ▼
Domain Adapter / Resolver
        ▼
Trusted Attribution Engine
        ▼
promotion_attributions
        ▼
Delta Reconciliation
        ▼
promotion_campaign_stats
        ├── immutable campaign spend
        └── net attributed GMV/service revenue → ROAS
```

The transaction reads the previous attribution and campaign stats, computes the difference between old and desired qualified/financial/revenue/refund values, and writes the attribution plus absolute converged counters atomically. It never appends a second positive conversion for a retry. Concurrent reconciliation retries are serialized by the Firestore transaction. A source update failure is isolated from the underlying order/appointment payment and can be retried on the next source write or by an operational retry.

M9 adds `refundedRevenue`, `lastReconciledAt`, `lastAttributionStatus`, and `revenueAttributionStatus=server_attributed` to the existing stats read model. Impressions, clicks, detail views, and spend semantics remain unchanged.

## 5. Server integration

Trusted Firestore triggers observe `sellerOrders`, `vet_appointments`, and `groomy_appointments` writes and invoke the generic reconciliation boundary. Product returns are re-read from authoritative return documents by the seller-order adapter. The hooks are downstream measurement only; they cannot change whether a customer payment succeeds.

PET is explicitly excluded from financial attribution. Hotel, Taxi, and Business remain disabled.

## 6. Security and privacy

Clients cannot create, update, reverse, or read raw attribution records. Stats remain owner-isolated through the existing read model. No buyer contact data, card data, provider secrets, or raw payment payloads are copied into attribution. Structured logs identify source type/ID, campaign, target, and reconciliation status without sensitive financial credentials.

## 7. Limitations

No approved commercial multi-touch/last-click policy exists, so M9 uses the conservative same-flow policy only. Product partial refunds are applied only when return items expose authoritative product-level amounts; ambiguous multi-line refunds return `reconciliation_pending` rather than proportionally guessing. Appointment partial refunds are supported only where the domain exposes an authoritative refund amount. Cross-currency attribution, offline export, and warehouse reconciliation are deferred.

ROAS is valid only for server-attributed Product/Vet/Groomy records with matching currency, positive immutable spend, and converged refund state. PET ROAS remains N/A. No owner dashboard is included.

## 8. Tests and M10 handoff

M9 tests cover Product item-level attribution, mixed-order isolation, duplicate processing, full-refund convergence, Vet/Groomy canonical targets, wrong currency, missing/old/ambiguous interactions, default domain adapters, and owner/server Rules isolation. M8 exposure and analytics regressions remain covered.

M10 should be a performance UI only after the attribution-window decision and refund/reconciliation coverage are accepted. If those remain unresolved, hardening and operational reconciliation should precede any commercial ROAS display.
