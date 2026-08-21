# PETSUPO MARKETPLACE — ADD PRODUCT PRODUCTION AUDIT

Firebase project: `barkymatches-new`. Repository: `~/projects/barky-matches-flutter`. Audit type: read-only. **No code, Firestore data, Storage objects, indexes, or Security Rules were modified in the course of this audit.**

---

## 1. Executive verdict

# **NO-GO** for enabling real Marketplace product sales in the current state.

This is not a marginal call. Independently, any one of the following would be disqualifying; together they compound:

- A deployed, **unauthenticated** Cloud Function (`createProduct`) writes an attacker-controlled payload straight into a products collection with zero field validation.
- The atomic stock-reservation system is **fully built but verified switched off** for all real traffic — meaning stock is never authoritatively reserved, decremented, or restored by the backend today. Oversell is not a risk to mitigate; it is the default behavior.
- **No seller-authority or supply-chain document capability exists anywhere** — client, server, or storage. None of items 1–4 in your stated concern (stock declaration enforcement, proof of acquisition, proof of entitlement to sell, supplier/manufacturer traceability) are implemented at all, not even partially.
- **No admin compliance review exists.** There is no draft/pending/approved state machine; the client hardcodes every new product to `isActive: true` immediately.
- **Veterinary medicinal products are not distinguished from toys.** "Medicine" is an ordinary dropdown subcategory with identical handling to "Chew Toy."

The one piece of genuinely good news: **zero real products exist in production today** (verified live). This is a pre-launch gap, not an active incident — every finding below is prospective risk, not yet realized harm, and there is no migration/grandfathering burden.

---

## 2. Current end-to-end Add Product flow (verified)

```
Flutter UI (add_product_page.dart)
   │  client-side Dart validators only (name non-empty, price>0, stock ≥ 0, VAT selected, ownership check)
   ▼
Client uploads images/video directly to Firebase Storage
   │  paths: products/{businessId}/{ts}.jpg , products_raw/{businessId}/{ts}_{uuid}.{ext}
   │  ⚠ storage.rules has NO matching block for these paths → falls to global `allow read, write: if false`
   ▼
Client runs a Firestore **client-SDK transaction** directly
   │  tx.set(businesses/{businessId}/products/{productId}, {...isActive:true, ...})
   │  NO Cloud Function is called for the write itself
   │  (the only Cloud Function invoked in this flow is saveGlobalProduct, a barcode-catalog
   │   side-effect that is fire-and-forget and does not gate the save)
   ▼
Firestore Security Rules (only enforcement point in this path)
   │  allow create/update: if isAdmin() || (businessId ownership match) — nothing else is checked
   ▼
Product document exists, isActive:true, immediately publicly readable
   │  (products read rule: any registered OR anonymous user, no status/published filter)
   ▼
[NO REVIEW STEP EXISTS]
   ▼
Order placed → createMarketplaceOrderV2
   │  inventory-reservation module (m3) verified OFF in production env vars
   │  → order created via plain batch.commit(), classified "legacy"
   ▼
Payment confirmed
   │  commitVerifiedMarketplaceInventory only runs for non-legacy ("managed") orders
   │  → for today's traffic, stock field is never touched
```

**Every arrow above is a verified fact from code/config, not an inference from UI labels.**

---

## 3. Entry-point inventory

| Path | File | Verified role |
|---|---|---|
| Add/Edit Product (only live UI) | `lib/ui/business/petshop/add_product_page.dart` (4505 lines) | Single widget for both create and edit (`isEdit = existingProduct != null`). Direct `firestore.runTransaction` write. |
| Save-plan/ownership helper | `lib/ui/business/petshop/product_save_plan.dart` | `isAuthorizedBusinessEditor()` — **Dart-level check only**, not proof of server enforcement. |
| Product exception type | `lib/ui/business/petshop/product_submit_exception.dart` | — |
| Product model | `lib/models/product.dart` | Canonical Dart schema (§4). |
| Product media model | `lib/models/product_media.dart` | — |
| **Dead code**: alternate service | `lib/services/product_service.dart` | `ProductService.addProduct/updateProduct/deleteProduct` exist, have weaker validation (allows `stock==0`, no ownership check), and are **never called anywhere in the app** — confirmed by repo-wide call-site search. Live risk if ever wired up later. |
| **Deployed but unused-by-app**: Cloud Function | `functions/index.js:19674` `exports.createProduct` | Reachable independently of the app (any HTTPS caller). **No auth check, spreads client payload unvalidated.** See Finding F-01. |
| Barcode catalog side-effect | `functions/globalProducts/saveGlobalProduct.js` | Writes to `global_products/{barcode}` only; also unauthenticated but lower severity (crowdsourced catalog, not a live listing). |
| Video transcode trigger | `functions/index.js:19462` `exports.processProductVideo` | Storage-triggered, unrelated to compliance. |
| Price aggregation trigger | `functions/index.js:19735` `exports.aggregateProductPrices` | Triggers off `products/{id}` writes for price stats only. |
| Admin panel product UI | — | **Does not exist.** No admin product-creation/review page found anywhere in `lib/`. |
| Bulk upload / CSV import / clone / duplicate | — | **Does not exist.** No such feature found anywhere in the repository. |

**Bypass confirmation:** the primary form is *not* the only path capable of writing a product — `createProduct` (Cloud Function) is a fully independent, unauthenticated bypass of the entire client, reachable by anyone with the project's public API key.

---

## 4. Current product schema and missing fields

Collection: **`businesses/{businessId}/products/{productId}`** (subcollection; confirmed canonical by both the client write path and the inventory module's `inventoryRepository.js`). Document ID: `${businessId}_${sku}`.

*(Two other, empty, disconnected product-shaped collections exist — top-level `products/{businessId}_{sku}` (target of the unauthenticated `createProduct` function) and top-level `business_products` — neither currently holds data, but their mere existence is a schema-fragmentation risk in its own right.)*

| Field | Exists | Required | Validated | Editable post-"approval" | Rules-protected | Used in ordering/inventory |
|---|---|---|---|---|---|---|
| `id` | Yes | derived | client | — | no | yes (doc key) |
| `businessId` | Yes | derived | client | any value the owner sets | **yes** (create/update key check) | yes |
| `name` | Yes | client: non-empty | client only | yes, freely | no | display only |
| `description` | Yes | not enforced | none confirmed | yes | no | no |
| `price` | Yes | client: `>0` | client only | yes, freely, **even after orders exist** | no | yes |
| `salePrice`/`wholesalePrice` | Yes | conditional | client only | yes | no | yes |
| `kdvRate` (VAT) | Yes | client: required | client only | yes | no | tax calc |
| **`stock`** | Yes | client: rejects null/negative/decimal; **`0` is accepted** | **client only** — server module validates "non-negative number" but not integer, and only when inventory module is enabled (verified off) | yes, freely | no | nominally, but never authoritatively decremented in production today |
| `minStock` | Yes | optional | none | yes | no | display alert only |
| **reserved quantity** | **Missing** | — | — | — | — | — |
| **available quantity** | **Missing** (derived client-side as `stock - reserved` only when the disabled inventory module runs) | — | — | — | — | — |
| `category`/`subcategory` | Yes | client: dropdown always populated (closed 4×12 enum) | client only, no server enum check | yes, freely | no | promotion eligibility only |
| `brand` | Yes | optional, free text | none | yes | no | display |
| `barcode`/GTIN | Yes | optional | none | yes | no | catalog lookup only |
| `sku` | Yes | required (forms doc ID) | client only | — | no | no |
| **manufacturer** | **Missing** | — | — | — | — | — |
| **supplier** | **Missing** | — | — | — | — | — |
| **importer** | **Missing** | — | — | — | — | — |
| **country of origin** | **Missing** | — | — | — | — | — |
| **batch/lot number** | **Missing** | — | — | — | — | — |
| **expiration date** (product) | **Missing** | — | — | — | — | — |
| **product type / seller-authority relationship** | **Missing** | — | — | — | — | — |
| **compliance/document references** | **Missing** | — | — | — | — | — |
| **moderation/review status** | **Missing** | — | — | — | — | — |
| **rejection reason** | **Missing** | — | — | — | — | — |
| `isActive` | Yes | **hardcoded `true`** by client on every write | none | yes, by anyone with write access | no | product visibility |
| **createdBy** | **Missing** | — | — | — | — | — |
| **reviewedBy** | **Missing** | — | — | — | — | — |
| `createdAt`/`updatedAt` | Yes | client `Timestamp.now()` (**not** `FieldValue.serverTimestamp()` in the live path) — client-forgeable | none | yes | no | — |
| **soft-delete/suspension** | **Missing** | live `ProductService.deleteProduct` (dead code) does a **hard delete** | — | — | — | — |

**Every "Missing" row above corresponds directly to one of your five stated concerns.** Concerns 1–5 in your context section are each independently confirmed unimplemented, not merely weakly implemented.

---

## 5. Findings table

| ID | Severity | Verified evidence | Exact location | Exploit/failure scenario | Affected | Remediation |
|---|---|---|---|---|---|---|
| **F-01** | **Critical** | `exports.createProduct` has no `request.auth` check and spreads `...data` into the document unvalidated | `functions/index.js:19674-19706` | Anonymous HTTP caller creates a product under any `businessId`, with any price/stock/`isActive`/status field, at zero cost, with no app involved at all | All businesses, all buyers, platform integrity | Require `request.auth.uid`, verify business ownership server-side, allowlist writable fields, reject unless caller is the true business owner or admin |
| **F-02** | **Critical** | Firestore rule for `products` (all levels, wildcard `{path=**}/products/{productId}`) gates create/update solely on `businessId` ownership; no `hasOnly()`/type/range constraint on any field | `firestore.rules` products block | A compromised or malicious seller sets `stock:-999999`, `price:0.01`, `category:"anything"`, or a self-invented `moderationStatus:"approved"` via raw SDK/REST, bypassing the Flutter app entirely | All marketplace buyers/sellers | Add field-level locks (`diff().affectedKeys().hasOnly([...])`), type/range validators for `stock`/`price`, an enum check for `category`, and lock any status/approval-shaped field to admin-only writes |
| **F-03** | **Critical** | `products` read rule: `isRegisteredUser() || isAnonymousUser()` with no status/published condition — confirmed no `isPublicProduct()`-style helper exists, unlike the analogous `isPublicBusiness()` used elsewhere in the same file | `firestore.rules` products block | Even if a draft/pending/rejected state existed, it would still be publicly readable via direct document reads, search indexes, or cache — rejected/suspended products cannot be hidden today | All users, brand/IP/consumer-protection exposure | Add a read gate requiring `resource.data.moderationStatus == 'approved' && resource.data.isActive == true` (or equivalent), mirroring the existing `isPublicBusiness()` pattern |
| **F-04** | **Critical** | Inventory reservation/commit/release module (`functions/src/inventory/*`) is feature-flagged via `M3_INVENTORY_RESERVATION_ENABLED`/`M5_*`/`INVENTORY_*` env vars; live deployed function's environment variables contain **none of these keys** (verified via `gcloud functions describe`) | `functions/src/inventory/inventoryCheckoutCoordinator.js:663-677`, `inventoryReleaseCoordinator.js:31-41`, cross-checked against deployed config | Every real order today takes the "legacy" path (`index.js` checkout ~line 21105-21143): `stock` is never reserved at checkout, never decremented on payment, never restored on cancel/refund/expiry. Two simultaneous buyers can both "successfully" purchase the last unit | All marketplace orders, inventory integrity, customer trust | Enable the M3/M5 flags in production configuration (the code itself appears sound per its dedicated test suite) and remove/widen the canary allowlist once verified |
| **F-05** | **High** | No seller-authority (`sellerProductRelationship`), supplier/invoice, trademark/manufacturer, or importer field/upload exists anywhere — confirmed absent in client model, client form, Cloud Functions, and Storage | `lib/models/product.dart`, `lib/ui/business/petshop/add_product_page.dart`, full `functions/` grep | A seller with no legal right to distribute a branded product lists and sells it; Petsupo has no record establishing supply-chain legitimacy for any product, ever | Brand owners (IP), Petsupo (counterfeit/liability exposure), consumers | Build the compliance-document data model and upload flow described in §13; make it a hard gate before `isActive`/publish |
| **F-06** | **High** | No admin review/approval Cloud Function or UI exists anywhere; `isActive` is hardcoded `true` by the client on every create | `add_product_page.dart` (isActive:true on save), full repo search for admin product UI (none found) | Every product is live the instant a seller saves it — there is no human-in-the-loop compliance step for any product, of any risk category | All buyers, regulatory exposure | Implement the state machine in §14 with a genuine `pending_compliance_review` gate before `isActive` can become true |
| **F-07** | **High** | "Medicine" is an ordinary subcategory under "Health," identically handled to "Chew Toy" — no dedicated veterinary-medicinal-product category, no blocking logic, client or server | `add_product_page.dart` categories map (Health → [Vitamins, Medicine]) | A seller lists an actual veterinary medicinal product as an ordinary Marketplace item with none of the controls a regulated product would require | Consumers (product safety), Petsupo (regulatory exposure — **requires Turkish legal review** to determine exact prohibitions/requirements) | Add a distinct, gated category (or a `productType` flag) that hard-blocks publish pending specific compliance review; **confirm exact legal boundary with Turkish counsel before implementing** |
| **F-08** | **High** | `storage.rules` has no match block for `products/` or `products_raw/`; both fall through to the global `allow read, write: if false` catch-all | `storage.rules` (full file read, no matching block found) | As literally written, product image upload is non-functional in production (distinct from the security gaps — this is a functional/availability defect, **unless the deployed rules differ from the repo file**, which should be independently confirmed) | Sellers attempting to list products; also means no `hasAllowedMedia()`/type-size validation is currently wired to this path even if the block were added naively | Add an explicit `products/{businessId}/**` and `products_raw/{businessId}/**` rule block reusing the existing `hasAllowedMedia()` validator, scoped to the authenticated business owner |
| **F-09** | **Medium** | Dead code: `lib/services/product_service.dart` (`ProductService`) has weaker validation (`stock==0` allowed, no ownership check) and is not called by the live app, but still exists and compiles | `lib/services/product_service.dart` | If a future feature (quick-edit, admin tool, bulk action) is wired to this class without noticing it bypasses the real validation/ownership path, gaps silently reappear | Future maintainers | Delete the dead class, or bring it up to parity and add a regression test asserting only one write path exists |
| **F-10** | **Medium** | `createdAt`/`updatedAt` set via client `Timestamp.now()` in the live save path, not `FieldValue.serverTimestamp()` | `add_product_page.dart` save transaction | A malicious client can forge product age (e.g., to appear as an established listing, or to manipulate any future "listing age" trust signal) | Trust/ranking signals, audit accuracy | Switch to `FieldValue.serverTimestamp()` and lock the field server-side |
| **F-11** | **Medium** | No food/feed/expiry-controlled compliance fields exist for ANY category (ingredients, net quantity, batch/lot, production/expiry dates, storage conditions, warnings, Turkish label info) | `lib/models/product.dart` full field audit | A seller lists pet food with no ingredient/expiry/label data at all — no way for Petsupo or buyers to verify basic food-safety information | Consumers, Petsupo (consumer-protection exposure — **requires Turkish legal/regulatory confirmation** of exact mandatory label fields for pet food/feed) | Add category-conditional required fields per §13; confirm exact mandatory set with counsel |
| **F-12** | **Low** | `applyStockAdjustment` (the one primitive that requires `actor`/`reason`/`sourceEvidence` for a manual stock change) has no confirmed caller anywhere outside its own test suite | `functions/src/inventory/inventoryTransactions.js:1318-1320` and repo-wide caller search | The one well-audited manual-stock-change guardrail in the codebase may be unreachable/unused, i.e. effectively dead code today | Future implementers | Confirm intended call sites when wiring up the admin/seller manual-adjustment feature; add an integration test asserting it's reachable |
| **F-13** | **Low** | Schema fragmentation: three disconnected product-shaped collections exist (`businesses/{id}/products` — canonical/empty, top-level `products` — target of F-01, empty, `business_products` — empty, purpose unconfirmed) | Live Firestore read + code grep | Future code (or a careless fix to F-01) could write to the wrong collection, creating orphaned or duplicate product records invisible to the canonical read path | Data integrity | Consolidate to one canonical collection; delete or explicitly repurpose the unused ones before this feature goes live |

---

## 6. Stock concurrency and overselling assessment

- **Integer/positive-quantity enforcement:** Client rejects `null`/negative/decimal input for `stock`, but **accepts `0`**. There is no client or server requirement that stock be `> 0` to publish. Server-side (`productQuantities` in the inventory module) validates "non-negative finite number" but **not integer** — and this check only runs when the inventory module executes, which is currently never for real traffic.
- **Bypassable via raw SDK/REST:** Yes, confirmed (F-02) — no server-side type/range constraint exists in Firestore Rules for `stock`.
- **Atomic decrement on order confirmation:** Code exists and is transaction-safe (`commitInventory`, verified payment cross-check against both root order and seller order) **but is not active for any real order today** (F-04).
- **Reservation during checkout:** Same — implemented, transaction-safe, sound test coverage, **not active**.
- **Restoration on cancel/expiry/refund/failed payment:** Same pattern — implemented per-scenario (`releaseInventory`, `expireAndReleaseInventory`, `restoreReturnedInventory` — the latter correctly gated on `physicallyReceived && restockable`), **not active**.
- **Concurrent-purchase oversell:** When the module is active, Firestore transaction semantics plus an explicit `stock - reservedStock < quantity` check prevent oversell — this is genuinely well-built. When inactive (today's real state), the question is moot because nothing enforces stock at all; two, ten, or a thousand simultaneous "purchases" of a single-unit product would all nominally succeed since stock is never checked or touched by any order-path code.
- **Manual stock increase audit trail:** A primitive exists that requires actor/reason/evidence (`applyStockAdjustment`), but no caller was found — unclear if it is reachable by any seller or admin action today.
- **Consistency across cart/checkout/payment/seller-order/return/cancellation:** Not consistent — it's binary: fully consistent and safe when the (currently disabled) module runs, completely absent otherwise. There is no partial/legacy stock enforcement anywhere as a fallback.

**Overall: stock cannot currently be trusted as authoritative anywhere in the live system.**

---

## 7. Seller-authority and invoice/document assessment

**Fully unimplemented**, confirmed across all three layers (client, Cloud Functions, Storage):

- No `sellerProductRelationship` field or selector (brand_owner/manufacturer/authorized_distributor/authorized_dealer/importer/reseller) exists.
- No supplier legal name, tax number, invoice, invoice date/number, or document-expiry field exists.
- No trademark/manufacturer proof or importer-information field exists.
- No document upload mechanism (Storage path, UI, or rule) exists for any compliance document — only product photo/video upload exists, and even that currently fails per F-08.
- Because no document concept exists, there is **no mechanism to reuse a seller-level or brand-level approved document across products** — the question is moot; nothing to reuse.
- Because no document exists, there is **no linkage model** (business/seller/brand/product/category/validity-period) to audit — this entire capability needs to be designed from scratch (see §13).

This is the largest structural gap relative to your stated five concerns — concerns 2, 3, and 4 have literally zero implementation, not a weak one.

---

## 8. Product-category and prohibited-product assessment

**Repository finding:** Category is a closed 4×12 dropdown (Food/Accessories/Health/Toys, 3 subcategories each) — a seller cannot free-text a novel category, which does prevent naive category-name evasion. However:

- **No dedicated, gated "Veterinary Medicinal Product" category exists.** "Medicine" sits as an ordinary `Health` subcategory alongside "Vitamins," with identical form fields, identical validation, identical instant-publish behavior as any toy or accessory.
- **A seller could still bypass intent-based detection via the product *name/description* free-text fields** — e.g., listing an actual prescription veterinary drug under `Health → Vitamins` or even `Toys` with a misleading name; nothing in the code inspects name/description content for restricted-product signals (no keyword/ML screening found anywhere).
- **Food/feed and expiry-controlled products have no supporting fields at all** — no ingredients, net quantity, batch/lot, production/expiration dates, storage conditions, warnings, or Turkish label information exist in the schema for any category, confirmed by full field audit in §4.

**Recommended platform control (not a legal conclusion):** a distinct, non-bypassable `productType`/category value for veterinary medicinal products that hard-blocks the publish transition pending a dedicated compliance review path, plus keyword/manual-review screening on name/description for the general catalog.

**Requires Turkish legal review — do not treat the following as settled:**
- The exact legal definition and boundary of "veterinary medicinal product" under Turkish law, and whether *any* marketplace-style sale of such products is legally permissible at all versus requiring licensed-pharmacy-only distribution.
- The exact mandatory label/disclosure fields for pet food/feed under Turkish consumer-protection and food-safety regulation.
- Whether cosmetics/hygiene and flea/tick/parasite products require category-specific registration or approval numbers under Turkish law.
- Tax/VAT treatment implications tied to product category or seller type.

---

## 9. Firestore Rules assessment

Full rule block (`match /{path=**}/products/{productId}`):
```
allow read: if isRegisteredUser() || isAnonymousUser();
allow create: if isAdmin() || (request.resource.data.businessId is string && isBusinessOwner(request.resource.data.businessId));
allow update, delete: if isAdmin() || (resource.data.businessId is string && isBusinessOwner(resource.data.businessId));
```
This is the widest-open ruleset of any financially/legally sensitive collection in the file — by direct contrast, `businesses` explicitly field-locks `status`/`published`/`verification`/`trust`/`riskFlags`/`ownerUid`/`createdAt` from owner edits (`canOwnerUpdateBusinessDocument()`), and `orders`/`sellerOrders`/`order_returns` are either fully immutable or fully server-only. Products has neither protection.

**Adversarial-write reasoning (as requested):**

| Attack | Prevented by |
|---|---|
| Seller sets another business as owner | **Firestore Rules** — `isBusinessOwner()` genuinely checks the caller against the target `businessId`'s real `ownerUid` |
| Seller self-approves (sets status/published/visible) | **Not prevented** — no field lock exists |
| Seller publishes without documents | **Not prevented** — no required-field/document check exists |
| Seller sets invalid stock | **Not prevented** — no type/range constraint |
| Seller edits fields that should be immutable post-approval | **Not prevented** — no field lock, unlike the sibling `businesses` collection |
| Seller replaces document reference | **Not prevented** (moot today — no document field exists yet, but the gap will persist once one is added unless explicitly locked) |
| Seller lists a prohibited category | **Not prevented** — no category allowlist/enum check in rules |
| Seller modifies price/identity after an order references the product | **Not prevented** — no cross-check against `orders`/`sellerOrders` |
| Non-admin reads private compliance record | **N/A today** (no such collection exists); if ever added as a field on the product document itself, it would inherit the product's open read rule — a real future risk to flag now |

Admin is determined via a **Firestore document field** (`users/{uid}.role == 'admin'`), not Firebase custom claims — its trustworthiness is only as strong as the `users` collection's own write protection (not re-audited here, but worth confirming as part of remediation).

---

## 10. Firebase Storage privacy assessment

- No Storage path or rule exists for compliance documents at all (nothing to audit for privacy — the capability doesn't exist).
- Product image paths (`products/{businessId}/...`, `products_raw/{businessId}/...`) have **no matching rule block** and fall through to the global `allow read, write: if false` — meaning, as literally written in the repo, nobody (not even the owning seller) can currently read or write product images. This should be independently reconciled against the actually-deployed rules (a repo/deployment drift is possible) before being treated as either "broken" or "safe."
- Reusable, already-built validators exist elsewhere in the same file (`hasAllowedMedia()` — size/type/extension allowlist for media, `hasAllowedDocument()` — size/type/extension allowlist for PDFs/images) but are **not wired to any product path** — they are the right building blocks for both the image-path fix and the future compliance-document path.
- Executable/HTML/SVG upload-and-later-serve risk: not currently exploitable (nothing can be uploaded to these paths at all under the current rule), but would need explicit `contentType`/extension allowlisting (via the existing validators) the moment the path gap is fixed, to avoid reintroducing this risk.
- Download-URL leakage: no compliance document exists to leak. Product image URLs are expected to be public (they're listing photos) — not a leak by design, though this should be re-confirmed once the Storage rule gap is fixed and images are actually readable.

---

## 11. Admin review and audit-log assessment

**Does not exist.** No admin panel product-review UI was found anywhere in `lib/`. No Cloud Function sets, validates, or checks a moderation/approval/rejection state for products. No reviewer identity or timestamp is recorded anywhere. There is therefore no evidence to show reviewers, no audit log to inspect, and no way today to answer "who approved this product and when" for any product, because approval as a concept does not exist in the current implementation.

---

## 12. Existing-data migration impact

**Verified live, read-only, on 2026-08-20:**
- `businesses/{id}/products` subcollection: **does not exist for any of the 3 real business documents** in production (their only subcollections are `patients` and `services`, unrelated to Marketplace).
- Top-level `products` collection: **0 documents.**
- Top-level `business_products` collection: **0 documents.**
- No other plausible product-collection name (`marketplace_products`, `shopProducts`, `shop_products`, `storeProducts`, `sellerProducts`, `listings`, `marketplaceListings`, `petshop_products`) exists in production.

**Conclusion: zero existing Marketplace products in production.** There are no records missing stock/ownership/barcode/brand/manufacturer to count, no already-published-without-review records to grandfather, and no records that would fail a new, stricter rule set — because there are no records at all. **Migration risk is effectively zero.** This is the ideal time to implement the missing controls, before any real seller or buyer data exists to be disrupted.

---

## 13. Proposed target data model (not implemented)

```
businesses/{businessId}/products/{productId}
  # identity
  id, businessId, sku, gtin/barcode, name, description, category, subcategory, productType
  brand, manufacturer, countryOfOrigin

  # commercial
  price, salePrice, wholesalePrice, kdvRate

  # inventory (server-authoritative once M3/M5 enabled)
  stock (int, >=0), reservedStock (int, >=0), availableStock (derived, server-computed)
  minStock

  # perishable/food-specific (conditionally required by category)
  ingredients, netQuantity, batchLotNumber, productionDate, expirationDate,
  storageConditions, warnings, turkishLabelInfo

  # seller-authority / supply-chain (new)
  sellerProductRelationship: enum[brand_owner, manufacturer, authorized_distributor,
                                   authorized_dealer, importer, reseller]
  supplierLegalName, supplierTaxNumber
  complianceDocuments: [{
     documentId, type: enum[invoice, authorization_letter, trademark_proof,
                             importer_document, conformity_certificate],
     storagePath, uploadedBy, uploadedAt, expiresAt,
     scope: { businessId, brandId?, productIds?: [], categoryId? },
     invoiceNumber?, invoiceDate?,
     reviewStatus: enum[pending, approved, rejected], reviewedBy, reviewedAt
  }]

  # lifecycle
  moderationStatus: enum[draft, pending_compliance_review, approved, published,
                          suspended, rejected, expired]
  rejectionReason
  isActive (derived from moderationStatus == published, never client-set directly)
  createdBy, reviewedBy
  createdAt, updatedAt, publishedAt   (all FieldValue.serverTimestamp(), server-set)
  suspendedAt, suspensionReason        (soft-delete/suspension, no hard delete)

businesses/{businessId}/complianceDocuments/{documentId}   # OR a top-level collection
  # first-class document entity, referenced by productId/brandId/categoryId, with
  # its own validity period, so a brand/seller-level doc can be reused without re-upload
```

Compliance documents live in Storage under an owner-scoped, non-public path (e.g. `business_docs/{businessId}/marketplace_compliance/{documentId}`), reusing the existing `hasAllowedDocument()` validator pattern, readable only by the owning business and admins.

---

## 14. Proposed product state machine (not implemented)

```
        create (seller)
            │
            ▼
         [draft]  ──────────────► seller can freely edit
            │  seller submits for review
            ▼
[pending_compliance_review]  ──► admin sees product + all linked compliance docs
       │            │
   approve       reject ──────────────► [rejected] (rejectionReason set, seller can edit → resubmit)
       │
       ▼
    [approved]
       │  publish (server sets isActive/publishedAt)
       ▼
    [published]  ◄─── visible to buyers, orderable
       │
       ├── seller edits a "material" field (price, stock, category, brand, barcode,
       │   images, supplier/compliance docs, description) ──► back to
       │   [pending_compliance_review] automatically, product stays published
       │   with last-approved data until re-review completes (or is hidden, per
       │   risk tolerance — a product decision, not purely technical)
       │
       ├── admin/system suspends (policy violation, expired document,
       │   out-of-stock too long, seller request) ──► [suspended]
       │
       └── linked compliance document expires ──► [expired] (auto-suspend,
           notify seller, require document renewal to return to published)
```

Only a server (Cloud Function with admin-claim check, or Firestore Rules restricted to `isAdmin()`) may transition a product into `approved`/`published`. Sellers may only ever move a product into `draft` or `pending_compliance_review`.

---

## 15. Recommended phased remediation plan

**P0 — block unsafe publication immediately (before any real seller onboarding):**
- Remove or lock down `createProduct` (F-01): require auth + ownership + field allowlist, or delete it if genuinely unused.
- Add Firestore Rules field locks on `products` (F-02): type/range-validate `stock`/`price`, enum-validate `category`, lock any status-shaped field to admin-only.
- Add a read gate so unapproved/suspended products are not publicly readable (F-03).
- Fix or confirm the Storage rules gap for product images (F-08).
- Enable the M3/M5 inventory flags in production, starting with an internal canary, then general rollout (F-04) — this code already exists and is tested; this is a configuration change, not new development.

**P1 — compliance document and review workflow:**
- Implement the data model in §13 and state machine in §14.
- Build the seller-facing document upload UI and the admin review UI (does not exist today).
- Require `sellerProductRelationship` + the appropriate document type before a product can leave `draft`.

**P2 — category-specific compliance:**
- Add a distinct, hard-gated category/productType for veterinary medicinal products, pending the Turkish-legal-review items flagged in §8.
- Add conditional required fields for food/feed/expiry-controlled categories (§4, F-11), pending the same legal confirmation.
- Add name/description screening for restricted-product-name evasion.

**P3 — monitoring, expiry, renewal, audit reporting:**
- Document-expiry monitoring and seller renewal notifications.
- Immutable audit log for every approval/rejection/suspension action (reviewer identity + timestamp, append-only).
- Periodic reconciliation reporting (stock vs. reservations, expired documents still published, etc.).

---

## 16. Exact files likely to require modification in the implementation phase

- `functions/index.js` — `createProduct` (lock down or remove), new admin-approval callable, wire M3/M5 env vars.
- `functions/src/inventory/*` — enable in production config; no code changes expected if the existing test suite is trusted, but a fresh full-suite run before flipping the flag is essential.
- `firestore.rules` — `products` block: field locks, type/range/enum validation, read gate, new `complianceDocuments` collection rules.
- `storage.rules` — add `products/`/`products_raw/` blocks (reuse `hasAllowedMedia()`); add a new compliance-document path (reuse `hasAllowedDocument()`).
- `lib/models/product.dart` — extend schema per §13.
- `lib/ui/business/petshop/add_product_page.dart` — add seller-authority/document UI, remove hardcoded `isActive:true`, submit into `draft`/`pending_compliance_review` instead.
- `lib/services/product_service.dart` — delete or reconcile with the real write path (F-09).
- New: admin review UI (does not exist — net-new feature).
- New: `functions/subscription/` or a new `functions/marketplace/` module for document-linked, admin-gated approval transitions, mirroring the existing pattern already used for business document review elsewhere in this codebase.

---

## 17. Tests required before release

- **Unit:** stock/price/category validators (client and server), state-machine transition rules, document-scope/reuse logic.
- **Widget/UI:** Add Product form field-by-field validation, draft-vs-submit flow, document upload UI, admin review screen.
- **Firestore Rules emulator:** every adversarial write in §9's table, as literal `assertFails`/`assertSucceeds` cases; confirm read-gate hides non-published products from an anonymous/other-seller context.
- **Storage Rules emulator:** cross-business document read denial, size/type/extension rejection, admin-only compliance-doc read.
- **Cloud Functions:** `createProduct` auth/ownership rejection cases, approval/rejection callable admin-claim enforcement, document-expiry auto-suspend logic.
- **Stock-concurrency:** parallel-reservation race test on a single-unit product (this test suite already exists for the inventory module — re-run and extend to cover the newly-enabled production path end-to-end, not just the module in isolation).
- **Integration:** full draft→review→approve→publish→order→payment→stock-decrement→(cancel/refund→stock-restore) round trip.
- **Negative/adversarial:** raw SDK/REST attempts for every row in the Findings table (§5), confirming each is now blocked at the Rules or Function layer, not merely hidden by the UI.

---

## 18. Final release gates and rollback plan

**Release gates (all must pass before enabling Marketplace to real sellers):**
1. F-01 through F-04 (all Critical findings) closed and verified via the emulator/adversarial test suite above.
2. M3/M5 inventory flags confirmed enabled in the actual production environment (not just present in code) via a live `gcloud functions describe` check, mirroring how this audit verified they were off.
3. At least the P1 compliance-document workflow live for any category identified as high-risk in §8, with Turkish-legal-review items resolved or explicitly accepted as a documented business risk by Petsupo leadership — not silently shipped as an assumption.
4. Firestore/Storage Rules emulator suite passing with zero regressions against the adversarial cases in §9/§10.

**Rollback plan:** because zero real product data exists today (§12), rollback is low-risk by construction — reverting the M3/M5 flags to off, reverting Rules to a prior deployed version, and disabling the Add Product entry point client-side (feature flag) fully returns the system to its current (also broken, but non-actively-harmful, since no data exists yet) state with no data-loss or migration concerns. This should be re-evaluated once real product/order data exists, at which point a rollback plan will need to additionally address in-flight orders and reserved stock.

---

## Addendum — P0 gap review (2026-08-20, second pass)

A follow-up strict gap review was performed on the initial P0 implementation before it was considered ready to commit. This addendum records the decisions and additional findings from that pass. It supersedes the original P0 section (§15's P0 bullet list) wherever the two disagree.

### A1. Product Storage: raster images only, not `hasAllowedMedia()`

The initial P0 pass reused `hasAllowedMedia()` (images *and* video) for `products/`/`products_raw/`. A dedicated `hasAllowedProductImage()` was added to `storage.rules`, scoped only to the exact raster types `add_product_page.dart`'s own `_contentTypeFor()` produces (`image/jpeg`, `image/png`, `image/webp`, `image/heic`), with a 10MB cap and a matching extension check. `video/*`, `image/svg+xml`, `text/html`, and `application/*` are all rejected by omission from an allowlist, not by a blacklist. **Known, deliberate gap:** the Flutter client (`_uploadMedia()`) can still pick and attempt to upload video for a product; that upload now fails at the Storage layer. Video product media is unsupported until a dedicated, reviewed video validator is designed — this is a P0 safety-over-completeness tradeoff, not an oversight.

### A2. Closed product-field schema

`firestore.rules`' `productAllowedFields()` is the exact, closed set of 59 fields `Product.toJson()` (`lib/models/product.dart`) ever writes, generated directly from that method (not hand-guessed). Both `isSafeNewProductSubmission()` and `isSafeProductResubmission()` now require `data.keys().hasOnly(productAllowedFields())` in addition to the existing explicit protected-field blacklist (kept for defense-in-depth and readability, even though the closed schema makes it technically redundant). 26 new adversarial tests in `marketplaceProductRules.test.js` prove every named injection target (`approved`, `published`, `publicationStatus`, `moderation`, `adminApproved`, `inventoryOverride`, `customStatus`, `ownerUid`, `sellerUid`, `reviewedBy`, `reviewedAt`, `complianceStatus`, `documentUrls`, and a generic unknown-field case) is rejected on both create and update.

### A3. Inventory schema contract — approved P0 decision

**Decision: `stock`/`reservedStock` are retained as the canonical field names. `stockQuantity`/`reservedQuantity`/`availableQuantity` were explicitly NOT introduced**, to avoid forking the schema the already-built (currently-disabled) inventory module in `functions/src/inventory/*` depends on. This module's own test suite (64 tests, `inventoryTransactions.test.js` + 5 other files) directly asserts these exact field names; introducing different ones now would either fork the schema or require touching that module, both out of P0 scope.

Traced directly from `functions/src/inventory/inventoryTransactions.js` (verified against the code, not assumed):

| Field | Meaning |
|---|---|
| `stock` | The seller's declared sellable quantity. Physical-on-hand and sellable are the same concept in this model — there is no separate warehouse/physical-count field. |
| `reservedStock` | Quantity currently held by in-flight (not yet paid) reservations. Defaults to 0 when absent. Never negative; `stock` can never be less than `reservedStock` (enforced invariant, `productQuantities()`). |
| Available (not a stored field) | `stock - reservedStock`, computed at read time. |

**Which component may change each field, and when:**

| Event | `stock` | `reservedStock` |
|---|---|---|
| `reserveInventory` (checkout hold) | unchanged | `+= quantity` |
| `commitInventory` (verified payment) | `-= quantity` | `-= quantity` |
| `releaseInventory` (cancel before payment) | unchanged | `-= quantity` |
| `expireAndReleaseInventory` (lease timeout) | unchanged | `-= quantity` |
| `restoreReturnedInventory` (return) | `+= quantity`, **only if** the linked return's `restockable === true` | unchanged (already released at commit time) |
| `applyStockAdjustment` (manual) | `+= delta` (signed, non-zero) | unchanged | requires non-empty `actor`, `reason`, `sourceEvidence` — no caller of this exists anywhere in the codebase today (confirmed by repo-wide search); it is a well-built but currently unreachable primitive. |

A non-restockable return intentionally does **not** restore `stock` — the unit was received damaged/unsellable, or was never returned at all (approved-but-not-received), so putting it back on sale would be incorrect.

**Seller cannot write `reservedStock`:** proven at two independent layers — (1) no production caller of `applyStockAdjustment` exists at all, so no seller-facing path can touch inventory fields even via the trusted module; (2) `firestore.rules`' `productProtectedKeysUntouched()` explicitly blocks `reservedStock` from ever appearing in a direct seller write to the product document, closed further by A2's `hasOnly()` check.

**New concurrency contract test:** `inventoryTransactions.test.js` — "available stock cannot go negative under 5-way concurrent reservation" (5 simultaneous 1-unit reservation attempts against `stock:2`) explicitly asserts `stock - reservedStock >= 0` after all attempts settle, exactly 2 succeed, and the other 3 fail with `insufficient_stock`. This complements the pre-existing 2-attempt race test with a wider fan-out and an explicit invariant assertion.

A pre-existing, independent audit (`docs/INVENTORY_ARCHITECTURE_AUDIT.md`, 2026-08-02) reached the same architectural conclusion about this module before this engagement began, corroborating the "well-built but currently disabled" characterization.

### A4. Real Marketplace query compatibility — a genuine break was found and fixed

The new public-read rule (`moderationStatus == 'approved' && isActive == true`) is **not** satisfiable by a Firestore list query that only filters `isActive == true` — Firestore rejects the entire query (not just the non-matching documents) unless every field the rule depends on is also constrained by the query itself. Every public product query in the app filtered only on `isActive`, meaning **all of them would have broken outright** the moment these rules were deployed against real data:

- `lib/ui/petshop/all_products_page.dart` (both the seller-scoped and cross-business streams)
- `lib/ui/product/seller_profile_page.dart` (two occurrences)
- `lib/ui/petshop/petshop_products_page.dart`
- `lib/ui/petshop/seller_offers_page.dart`
- `lib/ui/petshop/pet_shop_customer_details_page.dart`

All five were fixed by adding `.where('moderationStatus', isEqualTo: 'approved')` alongside the existing `isActive` filter.

Two further, non-query call sites were found to newly throw (rather than gracefully treat as "not found") once a referenced product is no longer publicly readable, and were hardened to catch `FirebaseException` and fall back to their existing not-found handling: `lib/ui/petshop/all_products_page.dart`'s cart-restore product lookup, and `lib/services/order_return_service.dart`'s return-shipping-policy product lookup (a buyer, not the owner, reads the product here).

`lib/ui/product/favorite_products_page.dart` was carrying a separate, pre-existing problem exposed by this review: it ran an **unfiltered `collectionGroup("products").get()`** (fetching every product across every business on every tap) and searched the results client-side for a matching ID. Besides being unrelated to rules correctness, an unconstrained query with no path to satisfying the new rule would be rejected outright for any non-owner. It was rewritten to a direct, scoped `businesses/{shopId}/products/{productId}.get()` using the `shopId` already stored on the favorite document — both a correctness fix and a compatibility fix.

**Discovered constraint for future work (not fixed, because no such query exists in the app today):** an owner's own *unfiltered* product-list query (e.g., a future "my full inventory, any status" seller page) also cannot rely on path-scoping alone — `businesses/{businessId}/products` with no `where()` clause is rejected too, because the ownership branch of the read rule checks `resource.data.businessId` (a data field), which Firestore cannot statically prove without an explicit `.where('businessId', '==', ownBusinessId)` in the query, even though it looks redundant with the path. Proven in `marketplaceProductRules.test.js`; no admin/seller review UI exists yet to apply this to.

`firestore.indexes.json` gained three new index entries for `products` (two `COLLECTION_GROUP` scope, one `COLLECTION` scope, covering `isActive`+`moderationStatus`[+`businessId`]) — collection-group queries require an explicit index in production even for equality-only filters, unlike single-collection queries. Verified against the Firestore emulator (all three query shapes succeed); **not independently verified against production**, since these are new indexes with no live traffic exercising them yet.

### A5. Full Cloud Functions suite accounting

See the final gap-review report (delivered in-conversation) for the complete, exact pass/fail/skip breakdown of all 659 tests (583 pre-existing + 76 new), including proof that 19 of the 23 failures seen only under full-suite parallel execution are a pre-existing test-infrastructure fragility unrelated to this work (confirmed absent when the affected file runs in isolation, and confirmed present in the same reduced form on the untouched baseline).

### A6. Storage Rules verification stabilized — root cause, not dismissal

The one flaky Storage Rules test from the original P0 report was root-caused, not dismissed as contention. `firebase emulators:exec --project X` runs the Firestore emulator in `--single_project_mode` locked to `X` (confirmed by inspecting the running emulator process directly). `storage.rules`' `isBusinessOwner()` calls `firestore.get()` cross-service; that call resolves against the emulator's own locked project, not whatever project `rules-unit-testing` happens to create internally. A dynamic, timestamp-suffixed `projectId` in the test file therefore never matched, so the cross-service lookup returned "Null value error" for the *entire* run, not just a cold-start window — proven by a 20-second/80-attempt retry that never once succeeded, and by the fact that no other test in the file ever exercised an `isBusinessOwner()`-must-return-true path, so the one test that did was the only one able to reveal it. Fixed by deriving the test's `projectId` from `GCLOUD_PROJECT` (set automatically by `emulators:exec --project`), which the dedicated `npm run test:marketplace-storage-rules` script relies on. Verified stable across 5 consecutive isolated runs (8/8 passing each time) after the fix. `marketplaceProductRules.test.js` deliberately keeps its own unique per-run project ID rather than also sharing `GCLOUD_PROJECT` — it has no cross-service calls, and sharing a fixed project with the Storage test file would let the two files' `clearFirestore()` calls collide when both run concurrently in the same `node --test` batch (confirmed: this exact collision was observed and fixed during this review).

### A7. Edit behavior on approved products

`isSafeProductResubmission()` already made this a single, unconditional rule with no field-specific exception: `incoming.isActive == false && incoming.moderationStatus == 'pending_review'` is required for *every* seller update, regardless of which field changed. 10 new tests (2 each for price, stock, category, title/description, and image-reference changes) prove this for an already-approved product: an update that changes any of these fields while also trying to preserve `isActive:true`/`moderationStatus:'approved'` is rejected; the same update correctly resetting both fields succeeds.

## Addendum — P0 final corrections (post code-review pass)

Three confirmed defects from the final read-only code-review pass were fixed. No other files were touched.

**Seller dashboard inventory query (`lib/services/product_service.dart`).** `getProducts()` is live — called by the seller's own dashboard (`petshop_dashboard_page.dart`, 3 sites) and feeding `deleteProduct()`'s call sites — not dead code as the original F-09 finding characterized it. It previously filtered `isActive == true` only, which (a) hid a seller's own pending/rejected products from their own dashboard, the opposite of the intended behavior, and (b) would have been rejected outright by the new read rule once real data exists, since it satisfied neither the public-approved branch nor the owner branch (missing the explicit `businessId` data-field constraint a list query needs — see A4). Changed to `.where('businessId', isEqualTo: businessId)` with no `isActive` filter, so the owner sees every status. `businessId` is sourced from `AppState`'s server-resolved canonical business ID (`_resolveCanonicalBusinessId`), the same trust boundary every other owner-scoped query in this codebase already relies on — not a client-arbitrary value. 7 new Firestore Rules emulator tests (`marketplaceProductRules.test.js`, "18a"–"18g") prove: owner sees its own pending and approved products, does not see another business's products, another seller and an unauthenticated caller are both rejected running the same query shape, and the public path (same collection, no auth) still requires the approved+active filters and still works when they're present. No Dart-level test was added: `getProducts()` calls the `FirebaseFirestore.instance` singleton directly rather than an injected instance, so a Dart/`fake_cloud_firestore` test would either need a disproportionate constructor-injection refactor (out of scope for this correction) or would only prove query shape/no-crash — `fake_cloud_firestore` does not evaluate Security Rules at all, so it cannot prove the ownership boundary the fix is actually for. The Rules emulator is the only harness that proves the property that matters here.

**Missing `seller_offers_page.dart` indexes (`firestore.indexes.json`).** Added two `products` `COLLECTION_GROUP` indexes — `(isActive, moderationStatus, barcode)` and `(isActive, moderationStatus, name)` — matching the query's exact field set and order (`isActive == true`, `moderationStatus == 'approved'`, then either `barcode ==` or `name ==`, all equality/ascending). Without these, that query would fail in production with a "the query requires an index" error the first time a real product exists. Also removed the third, `COLLECTION`-scope `(isActive, moderationStatus)` index: Cloud Firestore does not require a composite index for queries composed only of equality (`==`)/`in` clauses on a single collection — its automatic per-field indexes cover this via merge join — and this is documented, stable platform behavior, not something that depends on this repository's configuration, so removal is definite rather than a guess. The two `COLLECTION_GROUP` `products` indexes from the P0 gap-review pass are unaffected and still required (collection-group queries always need an explicit composite index, even for equality-only filters). Verified: `firestore.indexes.json` parses, 4 `products` entries total, no duplicates.

**Storage extension case-sensitivity (`storage.rules`).** `hasAllowedProductImage()`'s filename regex only matched lowercase extensions, so a client-declared-correct upload named e.g. `Photo.JPG` (common from iOS/Android camera rolls) would have been rejected on filename casing alone despite a valid `contentType`. Fixed with explicit per-letter character classes (`[jJ][pP][gG]`, etc.) rather than an inline `(?i)` flag, so the fix does not depend on assuming RE2 support for that flag inside Firebase Storage Rules — 6 new emulator tests against the real rules engine are the actual proof, not an assumption: uppercase `.JPG`/`.PNG` with matching content-type succeed, uppercase `.SVG`/`.HTML` still fail, cross-business isolation still holds with an uppercase extension, and an oversized uppercase-extension file still fails. No MIME type was added or broadened.

**HEIC — unchanged, still flagged, not claimed as fully supported.** This correction pass did not touch HEIC/HEIF acceptance or add any transcoding. It may upload successfully (contentType `image/heic` is accepted, matching the client's existing `_contentTypeFor()`), but it may not render on Chrome/Firefox or other non-Safari Flutter Web clients — this is a known, general web-platform limitation this patch inherited rather than introduced, and end-to-end verification/normalization remains an explicit, separate, later media-pipeline task.

**Verification for this pass:** `dart format` (0 changes), `flutter analyze` on the changed file (no issues), `test/models/product_moderation_status_test.dart` (4/4), `functions/test/createProduct.test.js` (3/3), the complete `npm run test:marketplace-firestore-rules` suite (71/71, up from 64 — 7 new), the isolated `npm run test:marketplace-storage-rules` suite run 3 consecutive times (14/14 every time, up from 8 — 6 new), an isolated `inventoryTransactions.test.js` run (24/24, no flakiness observed), `firestore.indexes.json` JSON validation, `git diff --check` (clean), and a heuristic secret scan of every changed file (clean). The full, unscoped `test/*.test.js` batch was not re-run in this pass — its pre-existing, batch-size-correlated instability was already root-caused and documented in the prior review as independent of this work; none of this pass's changes touch any of the files or mechanisms implicated in that instability.
