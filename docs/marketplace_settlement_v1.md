# Petsupo Marketplace Settlement v1

---

# Purpose

This document defines the official money lifecycle for Petsupo Marketplace transactions.

It explains how customer payments become platform revenue, how business receivables are calculated, when a business becomes eligible for payout, and how automatic settlement should work.

This document applies to all paid Petsupo sectors:

```text
taxi
vet
groomy
hotel
training
petshop
```

---

# Core Principle

Petsupo is a marketplace.

The customer pays Petsupo first.

Petsupo keeps the platform revenue and settles the business receivable later, only after the service/order is completed and the invoice is approved.

Settlement must not depend on a manual admin payout button.

Settlement should be automated.

---

# Marketplace Money Lifecycle

```text
Customer Payment Success

↓

Financial Object Created

↓

Service / Order Completed

↓

Invoice Uploaded

↓

Invoice Approved

↓

28-Day Hold Period

↓

Ready For Settlement

↓

Wednesday Batch Settlement

↓

Bank Transfer Processing

↓

Paid
```

---

# Settlement Eligibility Rule

A transaction becomes eligible for settlement only when both conditions are true:

```text
Service Completed
+
Invoice Approved
```

Payment success alone is not enough.

Invoice approval alone is not enough.

Service completion alone is not enough.

---

# Hold Period

Petsupo uses a settlement hold period.

```text
Hold Period = 28 days
```

The 28-day hold period starts from:

```text
serviceCompletedAt
```

not from payment time.

Example:

```text
Service completed: July 1
Invoice approved: July 2
Hold ends: July 29
First Wednesday after hold end: payout batch date
```

---

# Settlement Cycle

Settlement is processed weekly.

```text
Settlement Day = Wednesday
```

Every Wednesday, the automatic settlement engine should find all transactions that are:

```text
Service Completed
Invoice Approved
Hold Period Finished
Not Paid Yet
Not Disputed
```

and move them into payout processing.

---

# Financial Object

Every successful transaction must have a standardized financial object.

Example:

```json
{
  "version": 1,
  "sector": "taxi",

  "referencePrice": null,
  "sellerPrice": 1500,
  "finalPrice": 1500,
  "discountPercent": null,

  "commissionType": "percentage",
  "commissionRate": 10,
  "commissionAmount": 150,

  "businessNetAmount": 1350,

  "platformRevenue": 150,
  "businessReceivable": 1350,

  "payoutStatus": "awaiting_invoice",
  "payoutId": null,
  "payoutAt": null,

  "ruleSnapshot": {
    "configVersion": 1,
    "ruleId": "rule_1",
    "commissionType": "percentage",
    "commissionRate": 10
  },

  "settlement": {
    "status": "awaiting_invoice",
    "eligibleAt": null,
    "scheduledPayoutDate": null,
    "processingAt": null,
    "paidAt": null,
    "bankReference": null,
    "attempts": 0,
    "lastError": null
  },

  "calculatedAt": "timestamp"
}
```

---

# Financial Fields

## platformRevenue

The amount Petsupo keeps.

Usually equal to:

```text
commissionAmount
```

---

## businessReceivable

The amount owed to the business.

Usually equal to:

```text
businessNetAmount
```

---

## payoutStatus

Legacy-compatible settlement status field.

It should mirror:

```text
financial.settlement.status
```

---

# Settlement Statuses

## awaiting_invoice

Payment is successful, but the business has not uploaded an invoice yet.

---

## invoice_uploaded

Invoice has been uploaded but not yet reviewed or approved.

---

## invoice_rejected

Invoice was rejected.

Business can upload a corrected invoice again.

---

## invoice_approved

Invoice has been approved, but the transaction may still be waiting for service completion or hold period.

---

## waiting_hold_period

Service is completed and invoice is approved, but 28 days have not passed yet.

---

## ready_for_payout

The transaction is ready for automatic payout.

Conditions:

```text
paymentStatus == paid
serviceStatus == completed
invoice.status == approved
hold period finished
settlement.status != paid
```

---

## payment_processing

The transaction has been picked up by the Wednesday payout batch.

Bank transfer is being processed.

---

## paid

Business payout is completed.

---

## disputed

The transaction is blocked because of dispute, refund, invoice issue, fraud review, or manual investigation.

---

# Invoice Lifecycle

```text
pending_upload

↓

uploaded

↓

under_review

↓

approved

or

rejected
```

If rejected, business can upload again.

Invoice upload attempts are unlimited.

---

# Invoice Re-upload Rule

Business can correct and re-upload rejected invoices.

Every upload should be stored as a version.

Example:

```json
{
  "invoice": {
    "version": 3,
    "status": "approved",
    "uploads": [
      {
        "version": 1,
        "status": "rejected",
        "reason": "buyer_identity_not_found",
        "uploadedAt": "timestamp",
        "fileUrl": "..."
      },
      {
        "version": 2,
        "status": "rejected",
        "reason": "missing_tax_number",
        "uploadedAt": "timestamp",
        "fileUrl": "..."
      },
      {
        "version": 3,
        "status": "approved",
        "reason": null,
        "uploadedAt": "timestamp",
        "fileUrl": "..."
      }
    ]
  }
}
```

---

# Automatic Settlement Engine

Settlement must be automated.

No payout should depend on an admin clicking a button.

Admin may review invoices or disputes, but payout execution should be handled by scheduled backend logic.

---

# Automatic Settlement Flow

```text
Cloud Scheduler

↓

Find ready_for_payout transactions

↓

Create payout batch

↓

Call bank transfer API

↓

Update financial.settlement

↓

Update financial.payoutStatus

↓

Send notification to business
```

---

# Wednesday Batch Rule

Every Wednesday, the scheduled settlement function should:

1. Find all eligible transactions.
2. Group them by business.
3. Calculate total payable amount per business.
4. Create a payout batch record.
5. Send transfer request to bank API.
6. Mark transactions as payment_processing.
7. After success, mark them as paid.

---

# Payout Batch

Future collection:

```text
settlement_batches
```

Example:

```json
{
  "batchId": "SETTLEMENT-2026-07-29",
  "status": "processing",
  "scheduledDate": "2026-07-29",
  "createdAt": "timestamp",
  "totalGrossSales": 25000,
  "totalPlatformRevenue": 2500,
  "totalBusinessReceivable": 22500,
  "businessCount": 12,
  "transactionCount": 38
}
```

---

# Business Payout Record

Future collection:

```text
business_payouts
```

Example:

```json
{
  "businessId": "abc123",
  "batchId": "SETTLEMENT-2026-07-29",
  "status": "paid",
  "amount": 1350,
  "currency": "TRY",
  "transactionIds": [
    "booking_1",
    "booking_2"
  ],
  "bankReference": "EFT-20260729-00012",
  "paidAt": "timestamp"
}
```

---

# Dashboard Rules

Business dashboards should never calculate commission manually.

They should read from:

```text
financial.*
```

Recommended dashboard metrics:

```text
Gross Sales
Platform Revenue
Business Receivable
Pending Payout
Paid Out
```

---

# Dashboard Definitions

## Gross Sales

Sum of:

```text
financial.finalPrice
```

---

## Platform Revenue

Sum of:

```text
financial.platformRevenue
```

---

## Business Receivable

Sum of:

```text
financial.businessReceivable
```

---

## Pending Payout

Sum of business receivables where:

```text
financial.settlement.status != paid
```

or legacy fallback:

```text
financial.payoutStatus != paid
```

---

## Paid Out

Sum of business receivables where:

```text
financial.settlement.status == paid
```

or legacy fallback:

```text
financial.payoutStatus == paid
```

---

# Admin Role

Admin should not manually trigger normal payouts.

Admin may:

```text
Review invoice
Reject invoice
Approve invoice
Resolve dispute
Block suspicious payout
Retry failed payout
```

But the standard payout process should be automatic.

---

# Disputes

If a transaction has refund, complaint, fraud risk, invoice issue, or legal/accounting problem, settlement status should become:

```text
disputed
```

Disputed transactions must not be included in automatic payout batches.

---

# Refund Rule

If a refund happens before payout:

```text
settlement.status = disputed
or
settlement.status = cancelled
```

The business should not receive payout until the refund state is resolved.

If a refund happens after payout, it must be handled by a future recovery or adjustment system.

---

# Versioning

This document defines:

```text
Marketplace Settlement v1
```

Future versions may add:

```text
partial payouts
bank API integration
automatic reconciliation
tax reporting
business wallet
multi-currency
payout retry engine
settlement exports
```

---

# Final Rule

For every marketplace transaction:

```text
Payment Success creates financial object.

Service Completed + Invoice Approved creates settlement eligibility.

28-day hold period controls when money becomes payable.

Wednesday batch controls when money is sent.

Payout must be automatic.
```
