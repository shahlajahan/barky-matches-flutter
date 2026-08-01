# PHAROS FINANCE OS
## Finance Operations Center V2
### Production Implementation Specification

# Implementation Status

- [ ] Phase 1 – Eligibility Engine
- [ ] Phase 2 – Admin Overview
- [ ] Phase 3 – Waiting
- [ ] Phase 4 – Batch Engine
- [ ] Phase 5 – Excel Export
- [ ] Phase 6 – Exceptions
- [ ] Phase 7 – Seller Dashboards
- [ ] Phase 8 – Migration
- [ ] Phase 9 – Tests & Validation

This is a production redesign of the Admin financial operations system and the seller-facing payout visibility across all supported business sectors.

Do NOT patch only the current Admin Payout UI.

Do NOT build a finance workflow that exists only for Admin.

The payout lifecycle must be consistently represented in:

- Admin Finance Operations Center
- Seller dashboards for every supported sector

Supported sectors include at minimum:

- Pet Shop
- Vet
- Groomy / Groomer
- Pet Hotel
- Pet Taxi
- Training
- Adoption or other monetized business sectors if they already participate in payout architecture

Use the existing canonical sector identifiers in the repository.

==========================================================
CORE PRINCIPLE
==========================================================

The unit of payment is not an individual sellerOrder.

The operational payment unit is a Seller Aggregate.

One seller receives one payout instruction containing all eligible underlying records for the selected payout period.

Each underlying sellerOrder or monetized source document must remain individually traceable.

==========================================================
MANDATORY 21-DAY PAYOUT RULE
==========================================================

A paid source record becomes payout-eligible only after 21 complete days have passed since successful payment verification.

Eligibility date:

successfulPaymentAt + 21 days

==========================================================
CALENDAR DAY RULE
==========================================================

The 21-day protection period is calendar-day based.

Eligibility begins at the start of the 22nd calendar day
using the platform timezone.

Do not calculate eligibility using 21 × 24 hours.

This avoids releasing payouts at arbitrary hours
depending on payment time.

Do not use:

- order creation date
- booking creation date
- checkout start date
- pending date
- settlement start date
- updatedAt as a fallback when successful payment timestamp exists

The countdown must begin only after payment has been successfully verified.

A record must never enter an eligible payout batch before its eligibility date.

This rule must be enforced server-side.

UI-only enforcement is not sufficient.

==========================================================
CANONICAL PAYOUT ELIGIBILITY STATES
==========================================================

Use existing canonical statuses where appropriate.

Normalize the lifecycle conceptually as:

WAITING_PERIOD

Payment verified and settlement valid, but the 21-day protection period has not completed.

ELIGIBLE

21-day waiting period completed and all payout requirements are satisfied.

BLOCKED

Cannot proceed because of refund, return, dispute, settlement failure, compliance issue, invalid banking details, or another blocking condition.

BATCHED

Reserved inside an active payout batch.

PAID

Seller payment has been completed.

REVERSED / CANCELLED

Liability is no longer payable because of refund, cancellation, reversal, or corrective accounting.

Do not invent duplicate status systems when an equivalent canonical status already exists.

==========================================================
CASH FLOW FOREVIEW
==========================================================

Admin Overview must also display:

Tomorrow Becoming Eligible

Next 7 Days

Next 30 Days

Estimated Payable

Example:

Tomorrow

₺8,200

Next 7 Days

₺92,500

Next 30 Days

₺618,400


==========================================================
FROZEN BATCH SNAPSHOT
==========================================================

Every payout batch must preserve:

Batch Version

Projection Version

Snapshot Timestamp

Snapshot Hash

The exported Excel must always represent
the frozen snapshot.

Future source changes must not silently mutate
an exported batch.

==========================================================
ADMIN FINANCE OPERATIONS CENTER
==========================================================

Rename or conceptually evolve the current Payout Management page into a real Finance Operations Center.

Recommended tabs:

1. Overview
2. Eligible
3. Waiting
4. Batches
5. Paid
6. Exceptions

==========================================================
ADMIN OVERVIEW
==========================================================

The Overview must immediately show operational totals without requiring scrolling through filters.

Display at minimum:

- Eligible Sellers
- Eligible Records / Orders
- Net Payable
- Waiting Sellers
- Waiting Records
- Waiting Amount
- Blocked Records
- Exception Count
- Draft Batches
- Exported Batches
- Paid Today
- Paid This Week
- Next Eligibility Date
- Amount Becoming Eligible Next

All totals must come from normalized payout projections and must not include refunded, reversed, already-paid, or invalid records.

==========================================================
ADMIN ELIGIBLE TAB
==========================================================

Group eligible payout records by the canonical business/seller identifier.

One primary card per seller aggregate.

Each seller card must show:

- business name
- legal name when available
- account holder name
- masked IBAN
- bank name
- tax number or legal reference when available
- sector
- number of eligible records
- gross total
- commission total
- net payable
- oldest eligible date
- newest eligible date
- payout period
- validation status
- selection checkbox
- expand action

Expanded detail must show every underlying record with:

- order / booking / source number
- source type
- customer payment amount
- commission
- net payout
- successful payment date
- eligibility date
- settlement status
- refund/dispute state
- source document ID

Admin must be able to:

- select one seller
- select multiple sellers
- select all valid sellers
- create one payout batch

==========================================================
ADMIN WAITING TAB
==========================================================

The Waiting tab must show seller-level aggregates for records still inside the 21-day protection window.

Each seller card must display this exact information hierarchy:

Koray Pet

Waiting Amount
₺8,420

12 Orders

Next Eligible Date
18 Aug 2026

Days Remaining
8

Oldest Waiting Order
28 Jul 2026

Also display when available:

- sector
- newest waiting order date
- earliest successful payment date
- latest successful payment date
- number becoming eligible on the next date
- amount becoming eligible on the next date
- masked IBAN validation state
- any active refund/dispute warning

Important calculation rules:

- Waiting Amount is the sum of current net seller liabilities still inside the 21-day period.
- Next Eligible Date is the earliest eligibility date among the seller’s waiting records.
- Days Remaining is calculated from the current server date/time to that earliest eligibility date.
- Oldest Waiting Order is the oldest successful payment date among waiting records.
- Refunded, cancelled, reversed, disputed, or blocked records must not inflate Waiting Amount.
- If a record becomes blocked while waiting, move it to Exceptions and recalculate the seller aggregate.

The Waiting card should optionally support expansion to show the underlying records and their individual eligibility countdowns.

==========================================================
ADMIN BATCH WORKFLOW
==========================================================

Workflow:

Eligible Sellers
→ Select Sellers
→ Create Batch
→ Batch Preview
→ Freeze Batch
→ Export XLSX
→ Send to Bank / Accounting
→ Receive Confirmation
→ Mark Seller Items or Whole Batch Paid
→ History
Finance Approver

Frozen batches are immutable.

No seller

No amount

No IBAN

No source record

may be edited after freeze.

Any modification requires creating a new batch version.

Approved By

Approved At

Approval Notes

Rejected

Returned For Review

A batch must be created from frozen, validated seller aggregates.

Do not generate an unmanaged Excel file directly from live query data.

==========================================================
PAYOUT BATCH MODEL
==========================================================

Use a production-safe batch structure.

Suggested top-level document:

payoutBatches/{batchId}

Include:

- batchNumber
- createdAt
- createdBy
- periodStart
- periodEnd
- currency
- status
- sellerCount
- payoutRecordCount
- grossTotal
- commissionTotal
- netTotal
- exportVersion
- exportFileName
- exportedAt
- paidAt
- notes
- checksum or deterministic totals metadata if appropriate

Suggested lifecycle:

draft
ready
exported
processing
partially_paid
paid
failed
cancelled
invalidated

Each seller aggregate should be represented as a batch item.

Suggested:

payoutBatches/{batchId}/items/{sellerBusinessId}

Include:

- businessId
- sector
- businessName
- legalBusinessName
- accountHolderName
- iban
- bankName
- taxNumber
- contactEmail
- contactPhone
- currency
- payoutCount
- grossTotal
- commissionTotal
- netTotal
- payoutIndexIds
- sourceDocumentIds
- status
- paymentReference
- paidAt
- failureReason

Do not silently mutate an exported batch.

If underlying liabilities change after export, invalidate or require regeneration through an explicit corrective workflow.

==========================================================
DOUBLE-PAYMENT PROTECTION
==========================================================

When records are added to a batch:

- reserve them atomically
- store batchId on the payout projection
- prevent inclusion in another active batch
- preserve idempotency
- reject concurrent duplicate batching
- never allow the same payout liability to be paid twice

Enforce this server-side with transactions or equivalent safe logic.

==========================================================
EXCEL EXPORT
==========================================================

Generate a real XLSX workbook.

Sheet 1: Payment Instructions

One row per seller aggregate:

- Row Number
- Batch Number
- Payment Date
- Sector
- Seller / Business Name
- Legal Name
- Account Holder Name
- IBAN
- Bank Name
- Tax Number
- Email
- Phone
- Currency
- Included Record Count
- Gross Total
- Commission Total
- Net Payment Amount
- Payment Description
- Payment Reference
- Status

Sheet 2: Payout Details

One row per underlying source record:

- Batch Number
- Business ID
- Seller Name
- Sector
- Source Collection
- Source Document ID
- Root Order ID where applicable
- Order / Booking Number
- Successful Payment Date
- Eligibility Date
- Gross Amount
- Commission Amount
- Net Payout Amount
- Currency
- Settlement Status
- Payout Status
- Created Date
- Updated Date

Sheet 3: Exceptions

Include records excluded from the batch and their reasons when relevant.

Formatting:

- frozen header
- auto-filter
- useful column widths
- numeric money cells with two decimals
- real Excel dates
- totals row
- Turkish characters preserved
- stable filename containing batch number and export date

==========================================================
ADMIN EXCEPTIONS TAB
==========================================================

Exceptions must be task-oriented, not raw error text.

Examples:

Missing IBAN
→ Open Seller

Missing Account Holder
→ Open Seller

Settlement Incomplete
→ Open Source Record

Refund Pending
→ Open Refund

Dispute Active
→ Open Dispute

Already Batched
→ View Batch

Already Paid
→ View Payment

Each exception must show:

- seller name
- sector
- affected amount
- affected record count
- exact blocking reason
- recommended next action
- action button

==========================================================
SELLER DASHBOARD REQUIREMENTS
==========================================================

Simultaneously update seller dashboards for every payout-enabled sector.

Do not implement this only for Pet Shop.

Each sector dashboard must include a consistent seller-facing Finance / Earnings area using the existing sector design language.

At minimum, every seller dashboard must display:

1. Available Balance

Amount currently eligible for payout.

2. Waiting Balance

Amount still inside the 21-day protection period.

3. Next Eligible Date

Earliest date on which part of the waiting balance becomes eligible.

4. Amount Becoming Eligible Next

Amount that will become eligible on the next eligibility date.

5. Pending Batch / Processing Amount

Amount already reserved in an active payout batch but not yet paid.

6. Paid This Month

Completed seller payouts for the current month.

7. Total Earnings

Lifetime or configured-period seller net earnings.

8. Blocked Amount

Amounts affected by refund, dispute, settlement failure, or another blocking condition.

9. Last Payout

- amount
- date
- status
- reference when available

10. Bank Account Status

- valid
- missing
- invalid
- verification required

==========================================================
SELLER WAITING CARD
==========================================================

Each seller dashboard must include a prominent waiting-period card when waiting funds exist.

Use this information hierarchy:

Waiting Amount
₺8,420

12 Orders

Next Eligible Date
18 Aug 2026

Days Remaining
8

Oldest Waiting Order
28 Jul 2026

Adapt “Orders” to the sector where appropriate:

Pet Shop:
Orders

Vet:
Appointments

Groomy:
Appointments or Bookings

Hotel:
Bookings

Taxi:
Rides or Bookings

Training:
Sessions or Bookings

Use existing localized sector terminology.

Also show:

- amount becoming eligible next
- count becoming eligible next
- explanation that earnings become eligible 21 days after successful payment
- link to payout details/history

Do not expose internal payoutIndex IDs or Firestore document IDs to the seller.

==========================================================
SELLER FINANCE DETAIL PAGE
==========================================================

Each sector should link to a common or shared Finance Detail page where feasible.

Suggested sections:

Overview

- Available
- Waiting
- Batched / Processing
- Paid
- Blocked

Waiting Schedule

Group future eligibility by date:

18 Aug 2026
₺2,100
3 orders

19 Aug 2026
₺1,450
2 orders

22 Aug 2026
₺4,870
7 orders

Eligible Records

Show source records already eligible but not yet batched.

Payout History

Show completed payouts:

- payout amount
- payout date
- batch/payment reference
- bank account suffix
- included record count
- status

Exceptions

Seller-visible issues such as:

- missing IBAN
- invalid account holder
- refund under review
- dispute
- compliance block

Only show seller-appropriate information.

Do not expose internal admin notes, other sellers, platform-wide totals, or sensitive reconciliation data.

==========================================================
SECTOR CONSISTENCY
==========================================================

Build shared finance presentation components where possible.

Avoid duplicating payout logic separately in every sector dashboard.

Prefer a reusable architecture such as:

SellerFinanceSummary
SellerFinanceWaitingCard
SellerFinancePayoutHistory
SellerFinanceExceptionBanner
SellerFinanceProjectionService

Sector dashboards should provide only:

- sector identifier
- terminology
- navigation placement
- sector-specific source labels

Financial calculations and payout eligibility logic must remain canonical and shared.

==========================================================
SELLER NOTIFICATIONS
==========================================================

Use existing notification infrastructure where appropriate.

Potential notification events:

- funds entered 21-day waiting period
- funds became eligible
- payout batch created
- payout processing
- payout completed
- payout failed
- bank information missing
- payout blocked due to refund/dispute

Do not implement noisy daily countdown notifications.

==========================================================
SELLER BANK INFORMATION
==========================================================

If a seller has missing or invalid bank details:

Admin:
record appears in Exceptions.

Seller dashboard:
show a clear action banner.

Example:

Your payout is blocked because your bank account information is incomplete.

Action:
Update Bank Account

Do not allow the seller to think the money is lost.

Waiting and available balances should still remain visible, with the blocked reason clearly stated.

==========================================================
REFUND, RETURN, AND DISPUTE RULES
==========================================================

Before payout:

- refunded/reversed liabilities must be removed from Waiting or Eligible totals
- recalculate seller aggregates
- move affected records to blocked/reversed state
- never reduce the buyer refund because of seller commission

After payout:

- preserve recovery/debt/clawback accounting
- do not silently erase historical payment
- show seller-appropriate adjustment information
- do not expose sensitive internal recovery mechanics unnecessarily

==========================================================
SEARCH AND FILTERS
==========================================================

Admin search:

- seller name
- legal name
- business ID
- order / booking number
- batch number
- IBAN
- tax number
- phone
- email
- payment reference

Admin filters:

- date range
- sector
- seller
- bank
- payout status
- eligibility status
- settlement status
- bank-account validity
- min/max amount
- waiting days remaining
- batched/not batched
- currency

Useful presets:

- Today
- Yesterday
- This Week
- Last Week
- This Month
- Custom Range

Do not show all filters permanently expanded.

Use a compact filter button/sheet and show active filter chips.

==========================================================
AUTHORIZATION
==========================================================

Admin/Finance permissions must be enforced server-side.

Only authorized finance admins may:

- view full IBAN
- create batches
- export XLSX
- mark payments paid
- add transaction references
- invalidate batches
- view full audit details

Sellers may only view their own finance data.

==========================================================
ACCOUNTING REFERENCES
==========================================================

Each payout batch must support:

Accounting Reference

ERP Reference

Bank Transfer Reference

Manual Notes

These references must remain editable
without changing financial totals.

==========================================================
SELLER PAYOUT TIMELINE
==========================================================

Every seller dashboard must show
the payout lifecycle.

Paid

↓

Waiting (21 Days)

↓

Eligible

↓

Included in Batch

↓

Transferred

↓

Completed

Current stage must be highlighted.

==========================================================
ESTIMATED NEXT PAYOUT
==========================================================

Seller dashboard should display:

Estimated Next Payout

Amount

Estimated Date

Example

Estimated Next Payout

₺8,420

18 Aug 2026

This is an estimate.

Actual payout depends on
batch creation.

==========================================================
FAILED PAYOUT RETRY
==========================================================

If only part of a batch fails:

98 Paid

2 Failed

Admin must be able to retry
only failed seller items.

Already-paid items must never
be paid again.

==========================================================
SAVED FILTERS
==========================================================

Finance users may save filter presets.

Examples:

Today's Eligible

Tomorrow

Missing IBAN

Large Payouts

Pet Shops

Hotels

Saved filters should be reusable.

==========================================================
FINANCE NOTIFICATIONS
==========================================================

Notify seller when:

Waiting completed

Funds became eligible

Included in payout batch

Transferred

Payout failed

Missing bank information

Refund affected payout

==========================================================
CANONICAL FINANCE COMPONENTS
==========================================================

Admin and Seller dashboards must never
calculate financial values independently.

Every amount displayed anywhere
must originate from the same canonical
Finance Projection.

The following values must always be identical
across the platform:

Available Balance

Waiting Balance

Blocked Balance

Net Payable

Paid Amount

Lifetime Earnings

No dashboard may calculate
its own financial totals.

==========================================================
AUDIT TRAIL
==========================================================

Append audit/financial events for:

- eligibility reached
- payout blocked
- batch created
- record reserved
- batch exported
- seller item marked processing
- seller item marked paid
- batch completed
- batch invalidated
- payout reversed
- bank details changed when relevant to a pending batch

Every event should preserve:

- actor
- timestamp
- reason
- seller/business ID
- source record IDs
- batch ID where applicable
- previous state
- new state
- amounts
- currency

==========================================================
PERFORMANCE
==========================================================

No N+1 reads.

Use projection-based summaries.

Do not load every source record until detail/expand is opened.

Use server-derived aggregates or safely cached projections where appropriate.

All financial totals must use deterministic two-decimal money arithmetic.

==========================================================
MIGRATION / BACKFILL
==========================================================

Existing payoutIndex records may not contain all required seller and eligibility fields.

Implement a safe migration/backfill plan for:

- successfulPaymentAt
- eligibilityDate
- eligibilityStatus
- seller/business name
- account holder
- IBAN
- bank name
- sector
- gross amount
- commission amount
- net payout
- source number
- batch linkage

Do not overwrite valid historical financial snapshots.

Report records that cannot be safely backfilled.

==========================================================
TESTS
==========================================================

Add tests covering at minimum:

1. A record is not eligible before 21 complete days.

2. A record becomes eligible exactly when the 21-day period completes.

3. Payment creation date is not used when successful payment date differs.

4. Waiting seller aggregate displays:
   - waiting amount
   - record count
   - next eligible date
   - days remaining
   - oldest waiting order

5. Refunded/reversed records are excluded from waiting and eligible totals.

6. Different sellers do not aggregate together.

7. Different currencies do not aggregate together.

8. Multiple records for one seller aggregate correctly.

9. Missing IBAN blocks batching/export.

10. Same payout cannot enter two batches.

11. Seller dashboard shows only that seller’s finance data.

12. Every supported sector receives the finance summary.

13. Sector-specific terminology is correct.

14. Seller available/waiting/blocked/paid totals match canonical projections.

15. XLSX totals match frozen batch totals.

16. Export does not automatically mark payment paid.

17. Partial batch payment works.

18. Duplicate mark-paid requests are idempotent.

19. Refund after export invalidates or flags the batch safely.

20. Legacy records fail gracefully or are backfilled correctly.

==========================================================
VALIDATION
==========================================================

Run all relevant:

- Flutter tests
- Cloud Functions tests
- Functions lint
- Firestore rules tests if applicable
- flutter analyze for modified files
- XLSX generation and parse-back test
- migration/backfill dry run
- authorization tests

Manually verify at least one seller in every supported sector.

==========================================================
FINANCE LEDGER
==========================================================

Every financial movement must be recorded in an immutable ledger.

Ledger entries include:

Order Payment

Commission

Refund

Adjustment

Payout Reservation

Payout Completion

Chargeback

Correction

Manual Adjustment

Ledger entries must never be edited or deleted.

Historical balances must always be reproducible from the ledger.

Dashboard totals are projections.

The ledger is the source of truth.

==========================================================
OUTPUT
==========================================================

Return:

1. Architecture changes

2. Files modified

3. Collections and fields added/updated

4. Exact 21-day eligibility logic

5. Waiting aggregate calculations

6. Admin Finance Operations workflow

7. Seller dashboard changes by sector

8. Batch lifecycle and double-payment protection

9. XLSX structure and sample filename

10. Migration/backfill results

11. Test and validation results

12. Remaining limitations


Export Providers

XLSX

CSV

XML

Bank-specific formats

The exporter must be provider-pluggable.

Currencies must never aggregate together.

One payout batch = one currency.

IMPORTANT:

This implementation must provide one canonical payout lifecycle across Admin and all seller dashboards.

Do not build separate or inconsistent financial calculations for each sector.

The Admin Finance Operations Center and seller-facing finance summaries must use the same underlying payout projections and eligibility rules.


==========================================================
ACCOUNTING PERIOD
==========================================================

Every payout belongs to exactly one accounting period.

Suggested examples:

Weekly

01 Aug - 07 Aug

or

Monthly

August 2026

The accounting period must remain immutable
after the payout batch is frozen.

Every exported XLSX,
financial report,
audit event,
and payout history
must reference the accounting period.

Accounting periods are independent
from payment dates.

Payment eligibility determines
when a record may enter a period.

The accounting period determines
how it is reported.