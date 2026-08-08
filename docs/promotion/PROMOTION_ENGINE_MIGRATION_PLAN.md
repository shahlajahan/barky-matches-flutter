# PetSupo Promotion / Boost Engine — Migration Plan

Design only. No migration, field deletion, Rules change, code change, or production write is authorized by this document.

## 1. Legacy inventory

The Pet Boost legacy fields are `dogs.isSponsored`, `dogs.boostScore`, `dogs.boostExpiresAt`, and `dogs.sponsorshipType`. They are written by the client attempt in `lib/dog_card.dart:591-626`, rejected for ordinary owners by `firestore.rules:458-494`, read by playmate ranking in `lib/playmate_page.dart:668-685`, and surfaced in `lib/dog_card.dart:255-293`. Ranking does not enforce `boostExpiresAt`.

Other overlapping fields are editorial or subsystem-specific: `offers.isSponsored`, `offers.priorityScore`, `featured_deals.isActive/order`, business `featuredScore`, service `isFeatured/sortOrder`, vet `featuredVet`, and adoption `isFeatured`. These are not automatically convertible to paid campaigns.

## 2. Migration principles

1. New campaigns become the only authority for paid activation.
2. Never loosen Rules to preserve the direct dog update.
3. Maintain read compatibility only for a bounded transition window.
4. Make expired legacy state harmless before deleting it.
5. Preserve financial/audit history; do not rewrite it into ambiguous dog fields.
6. Every phase has a rollback switch and measurable exit criteria.

## 3. Phased plan

### M4 implementation status — Pet purchase path

New Pet purchases now use the M3 Promotion checkout and verified activation
path. The Pet UI reads server plans and no longer writes legacy sponsorship
fields. Discovery uses one expiry-aware normalized signal: valid Promotion
state first, then valid legacy state for existing records only. Legacy fields
remain physically present and no production data was migrated. The remaining
work is the read-only legacy inventory, historical disposition, telemetry, and
eventual compatibility removal.

### M5 implementation status — central ranking/projection

Promotion ranking now consumes a target-agnostic normalized state and bounded
ranking policy. Playmate preloads safe PET `promotion_active` projections once
per dogs snapshot, applies read-time expiry/identity checks, and uses legacy
Pet fields only as a compatibility fallback. No campaign or payment reads are
performed per result. Editorial and domain-specific featured mechanisms remain
separate; no Product, Service, or Business surface is enabled.

### M6 implementation status — Product Boost

Product is now enabled as the second real target through the generic checkout,
server ownership/eligibility resolver, verified activation, and M5 ranking
projection. The canonical target is
`businesses/{businessId}/products/{productId}`; the seller is the business
`ownerUid`, and positive stock is required at checkout. `AllProductsPage` is a
bounded, non-paginated snapshot, so it performs one safe PRODUCT projection
read and in-memory ranking without campaign/payment N+1 reads. Active Product
repurchase is rejected server-side. Product legacy/editorial fields remain
separate from paid Promotion. Large-scale pagination-safe Product placement,
seller saturation, and Product analytics remain future work.

### M7 implementation status — Service Boost

Vet and Groomer/Groomy are enabled through one SERVICE resolver and the
canonical identity `service/{SECTOR}/{businessId}/{serviceId}`. The resolver
derives ownership from the business `ownerUid`, preserves approved/published/
active business checks, rejects invalid service state, and uses the generic
checkout, verified activation, projection, and M5 ranking paths. Pet Hotel is
deferred because its primary customer surface is business-level; Pet Taxi is
deferred because its domain exposes provider availability/booking rather than
an individual service entity. No Business Boost behavior was added.

### Phase A — Introduce engine and compatibility reads

Create campaign/plan models, the server state machine, strict Rules, provider adapter, and `promotion_active` projection. Add a feature flag for promotion ranking. Existing legacy fields are read only as a compatibility signal. During this temporary phase, a legacy record contributes only when `now < boostExpiresAt` and the target remains eligible; missing expiry contributes zero.

Rollback: disable the promotion feature flag and stop campaign checkout; keep campaign/payment history and projections for reconciliation.

### Phase B — Make the engine source of truth

Enable Pet campaigns only after payment verification and activation are proven in emulator/staging and controlled production-like tests. Ranking reads active campaigns/projections. New UI reads campaign status and never reports a direct dog-field write as activation.

Rollback: set global promotion lift to zero, preserve active campaign states, and revert ranking reads to the compatibility-safe path while investigating. Do not reactivate expired legacy records.

### Phase C — Disable legacy client writes

Remove the direct sponsorship update from the Pet Boost UI in a separately reviewed code change. Rules continue to reject protected fields. The UI becomes checkout/status only; existing dog fields remain untouched for compatibility.

Rollback: revert the UI change only if the engine path is disabled; do not restore client authority for activation.

### Phase D — Remove legacy ranking dependence

After all active historical boosts are accounted for, remove legacy sponsorship fields from ranking decisions. A compatibility reader may remain behind an emergency diagnostic flag, but it must not affect public ranking.

Rollback: restore a zero-lift diagnostic view, not ranking trust in stale fields.

### Phase E — Optional field cleanup

Only after a data inventory, support sign-off, and rollback snapshot should legacy fields be removed or left inert. Prefer leaving fields physically present but ignored until no clients, exports, admin tools, or analytics depend on them.

## 4. Existing sponsored dogs

Do not blindly convert every document with `isSponsored=true`. Build a read-only inventory of owner, timestamps, score, type, target status, and payment evidence.

- Valid, auditable, unexpired historical state may be converted to a time-limited campaign with `activationSource=legacy_migration`.
- State without payment evidence should not become a paid campaign; it may receive a short, explicitly labeled compatibility window or expire immediately according to product/support decision.
- Expired or ineligible targets contribute zero and are not converted.
- Conversion must snapshot the legacy source and be idempotent by dog ID/source version.
- No migration should grant indefinite active status.

## 5. Plan and price migration

Pet plans are fixed baseline values: `pet_24h=29 TRY`, `pet_3d=69 TRY`, `pet_7d=129 TRY`. Store server-owned plan versions and snapshot selected price/currency/duration in each campaign. Product and Service plans remain disabled or unset until pricing approval; the client must not invent defaults.

## 6. Ranking migration safeguards

Before switching any surface, test zero lift for expired/cancelled/refunded campaigns, unpublished/deleted/suspended targets, stale projections, and a global kill switch. Enforce owner/business saturation and consecutive-sponsored caps while preserving organic relevance as a hard component.

## 7. Payment and Rules safeguards

Promotion order/campaign relationships must be one-to-one and idempotent. Callback retries and out-of-order delivery must be safe. Provider success without activation becomes an operational reconciliation case. Refund/cancellation removes active projection and ranking immediately, subject to server timestamp checks.

Rules tests must prove owner denial for `status`, `paymentStatus`, `paidAt`, `verifiedAt`, `startsAt`, `expiresAt`, `price`, `pricingVersion`, `rankingWeight`, and trusted metrics. Admin/backend paths and public projection read/write boundaries are tested separately.

## 8. Rollback strategy

1. Kill promotion lift globally.
2. Disable new checkout creation.
3. Pause the affected target type or provider.
4. Preserve campaign/payment/audit records and repair projections from campaign truth.
5. Revert client UI or ranking code only after the server state is safe.

Never roll back by allowing direct client sponsorship writes or restoring expired legacy ranking state.

## 9. Test strategy

Unit: legacy expiry conversion, idempotent conversion, plan snapshots, transitions, caps, and zero lift for ineligible targets.

Rules: owner protected-field denial, admin authorization, public projection boundaries, and unknown-field rejection.

Integration: Pet checkout, verified activation, duplicate callback, provider timeout, payment success/activation retry, refund, cancellation, and app/browser abandonment.

Ranking: organic relevance, expired legacy state, migrated campaigns, multiple campaigns by one owner/business, unavailable targets, stale projections, and kill switch.

Operational: reconciliation reports, audit-log completeness, projection repair, and campaign/payment mismatch alerts.

## 10. Definition of migration complete

Campaign activation is server/payment-authoritative; no client can mutate protected promotion fields; all enabled ranking surfaces use the central projection/policy; legacy fields no longer affect ranking; historical records have an explicit disposition; expiry is enforced at read/rank time; provider reconciliation/refund behavior is tested; rollback/kill-switch procedures are exercised; and support/admin tooling can explain every active campaign.

## 11. M8 measurement boundary

M8 adds projection-bound, server-validated exposure telemetry and owner-isolated
campaign counters for PET, PRODUCT, VET, and GROOMY. Raw events are immutable,
deduplicated, and never client-writable through Rules. Historical spend is
derived from each campaign snapshot, not current plan prices. Product and
Vet/Groomy service revenue attribution now has a trusted, server-only
reconciliation boundary with item/service identity validation, currency checks,
deterministic attribution IDs, and refund deltas. The commercial multi-touch
attribution window remains unresolved; M9 uses only the conservative versioned
same-flow policy. Hotel, Taxi, and Business remain disabled.
