# Promotion Engine M7 — Service Boost Integration

Status: implemented locally for Vet and Groomer/Groomy service records.
Pet Hotel and Pet Taxi remain deferred; Business Boost and all usage-based or
dynamic commercial models remain disabled.

## Sector audit

| Sector | Canonical entity | Target ID | Owner | Discovery | Boost enabled |
|---|---|---|---|---|---|
| Vet | `businesses/{businessId}/services/{serviceId}` | `service/VET/{businessId}/{serviceId}` | business `ownerUid` | Vet details service tab, nested service query | Yes |
| Groomer/Groomy | `businesses/{businessId}/services/{serviceId}` | `service/GROOMER/{businessId}/{serviceId}` | business `ownerUid` | Groomy details overlay, nested service stream | Yes |
| Pet Hotel | nested service records exist and reuse service management, but primary customer surface is business-level | identity is representable but no service-level discovery integration | business `ownerUid` | business-level hotel cards/booking | No — PARTIALLY READY |
| Pet Taxi | business sector availability, driver/location, and booking records; no individual promotable service record found | no legitimate service target | business `ownerUid` | taxi/driver availability and booking flow | No — NOT READY |

Vet and Groomy are the only M7-ready sectors because both have a stable
service document, business management surface, and service-level customer
consumer. Hotel is structurally close but its main discovery surface ranks
businesses, which would turn a service Boost into Business Boost. Taxi is not
an individual service catalogue.

## Canonical SERVICE contract and collision protection

```text
ServicePromotionTarget
  targetType = SERVICE
  sector = VET | GROOMER | (future deferred sector)
  targetId = service/{SECTOR}/{businessId}/{serviceId}
  businessId = owning business document ID
  ownerUid = businesses/{businessId}.ownerUid
```

The service document ID is preserved as the final path segment, while sector
and business identity are included in the Promotion target. This prevents a
Vet `abc` from colliding with a Groomer `abc`, a service under another
business, or a PET/PRODUCT target with the same raw ID. Display names,
localized titles, and mutable categories are never identity.

```text
                         Promotion Engine
                                │
                         targetType SERVICE
                                │
                     Service Target Resolver
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
             Vet             Groomer            Hotel / Taxi
              │                 │                 │
        domain adapter     domain adapter     deferred adapter
              └─────────────────┼─────────────────┘
                                │
                         normalized target
                                │
                    checkout / activation
                                │
                       promotion_active
                                │
                   PromotionRankingEngine
                                │
                         discovery surface
```

## Ownership and eligibility

The trusted resolver loads the business document and derives the seller from
`ownerUid` (with the existing repository owner-field compatibility). The
business must be approved, published, active, and not suspended. The nested
service must exist, belong to the business when it declares `businessId`, and
not be explicitly inactive, hidden, removed, unbookable, or unavailable.
Sector in the request and canonical target ID must agree with the business
sector. Staff permissions are not broadened beyond the existing business
owner contract.

Promotion is ranking metadata, not publication or availability authority. A
service that becomes unavailable after activation is filtered/treated as
organic by the discovery adapter; `promotion_active` alone cannot resurrect
it.

## Purchase and activation

```text
Service management
        ↓
Boost selected Vet/Groomer service
        ↓
SERVICE PromotionPlan
        ↓
createPromotionCheckout
        ↓
trusted provider verification
        ↓
PromotionCampaign ACTIVE
        ↓
promotion_active
        ↓
service discovery ranking
```

The generic `PromotionPlanSheet`, `PromotionCheckoutService`, provider
integration, status reader, idempotency, verified activation, and projection
are reused. V1 prices remain 49 TRY / 119 TRY / 219 TRY for 24 hours / 3 days
/ 7 days. Prices and activation timestamps remain server-owned and campaign
snapshots remain immutable. Redirect success is not activation proof.

A valid active SERVICE projection rejects another checkout for the same
canonical target. Expired projections do not permanently block a new attempt.

## Discovery and ranking

Vet details and Groomy details consume one SERVICE projection query per view,
join by canonical target ID, and apply the M5 `PromotionRankingEngine` with the
bounded lift cap of 40. Existing candidate filtering and service ordering are
retained as the organic input. Ranking performs no campaign or payment reads
and no network access inside the engine.

Location, distance, business publication, and service availability remain
hard candidate constraints. The two audited service-detail surfaces do not
perform a paid global sort across unrelated businesses; no promoted service is
allowed to bypass the selected business's discovery or booking gates.

Existing `isFeatured` on managed services and business-level `featuredVet` /
`featuredGroomer` signals remain editorial/domain mechanisms. They are not
converted to paid Promotion and do not stack with paid ranking lift.

Business identity is carried in normalized ranking inputs for future
saturation policy. M7 does not apply an arbitrary business cap because no
approved pagination/window policy exists.

## Pagination and performance

Vet and Groomy service-detail lists are bounded snapshot/stream lists without
cursor pagination. For N visible services in either enabled sector: one
`promotion_active` query per view, zero PromotionCampaign reads, zero payment
reads, and O(N log N) in-memory ranking. The engine itself is network-free.

These surfaces are safe at their current bounded scale. A future marketplace
service directory with hundreds/thousands of candidates will require a
server-side, geo-aware, availability-aware projection/ranking boundary before
paid placement is enabled there. Pet Hotel and Pet Taxi have no M7 ranking
query because they are deferred.

## Security and tests

Existing Promotion Rules remain backend-only for authoritative campaigns and
projections; no Rules change was required. Server tests cover ownership,
canonical identity, sector mismatch, inactive services, 49/119/219 pricing,
verified activation, projection privacy, overlap, expiry, collision
protection, and SERVICE/BUSINESS separation. Flutter tests cover the service
sector/identity abstraction, prices, expiry, bounded ranking, unavailable
services, and target-type separation. Existing Pet and Product suites remain
regression coverage.

## Known limitations and M8 handoff

- Pet Hotel checkout/ranking is deferred until an individual service-level
  customer discovery surface is selected.
- Pet Taxi requires a canonical promotable offering separate from provider
  availability and driver state.
- No business saturation or geo-aware server ranking policy is implemented.
- Existing service featured flags remain separate and are not migrated.

M8 can address the deferred service sectors or a server-side service discovery
boundary; it must preserve the canonical SERVICE contract and must not enable
Business Boost by targeting a business document.
