# Petsupo Universal Commission Engine v1

---

# Overview

The Petsupo Commission Engine is a centralized, configurable commission calculation system used across all Petsupo business sectors.

Instead of hardcoding commission logic inside Cloud Functions or Flutter, every commission rule is stored as configuration and executed by a dedicated strategy.

The engine is designed to be:

* configurable
* extensible
* strategy-based
* versioned
* testable
* production-ready

---

# Supported Sectors

```text
vet
petshop
taxi
hotel
groomy
training
```

---

# Architecture

```text
Cloud Function

        │

        ▼

calculateCommission()

        │

        ▼

Commission Repository

        │

        ▼

Firestore Config

        │

        ▼

Strategy Registry

        │

        ├───────────────┐
        │               │
        ▼               ▼

Taxi Strategy      Vet Strategy

        │

        ▼

Discount Strategy

        ▲
        │
 ┌──────┼─────────┐
 │      │         │
 ▼      ▼         ▼

Hotel Groomy Training

        │

        ▼

Petshop Strategy
```

The Commission Engine itself never contains business-specific logic.

Each sector owns its own strategy.

Adding a new sector only requires:

* new strategy
* strategy registration
* configuration document

No changes are required inside the engine.

---

# Firestore Collection

```text
commission_configs

    vet

    petshop

    taxi

    hotel

    groomy

    training
```

Every document represents one sector.

---

# Configuration Versioning

Every configuration document contains a version.

Example:

```json
{
    "version":1,
    "sector":"taxi",
    "enabled":true
}
```

The repository validates:

* document exists
* sector matches document id
* supported configuration version

This allows future migrations without breaking older configurations.

---

# Seeder

Configurations are never created manually.

They are stored inside Git:

```text
functions/

    commission/

        configs/

            taxi.json
            vet.json
            petshop.json
            groomy.json
            hotel.json
            training.json

    scripts/

        seedCommissionConfigs.js
```

Deployment flow:

```text
JSON

↓

Seeder

↓

Firestore
```

Running:

```bash
npm run seed:commission
```

will synchronize every configuration into Firestore.

---

# Strategy Registry

The engine never uses switch statements.

Instead it resolves the strategy from a registry.

```text
strategyRegistry.js

↓

taxiStrategy

vetStrategy

petshopStrategy

discountStrategy
```

The registry is the only place where sectors are mapped to strategies.

---

# Strategy Responsibilities

Each strategy is responsible for:

* validating its own inputs
* selecting the correct rule
* calculating commission
* calculating business net amount
* returning the standardized financial object

The engine itself performs none of these calculations.

It simply loads configuration and delegates execution to the proper strategy.

---

# Commission Types

The engine currently supports three commission calculation models.

## Percentage

Commission is calculated as a percentage of the transaction amount.

Example:

```json
{
    "type": "percentage",
    "commissionRate": 10
}
```

---

## Fixed

Commission is always a fixed amount.

Example:

```json
{
    "type": "fixed",
    "amount": 150
}
```

---

## Fixed Per Lead

Used when Petsupo charges a fixed fee for every lead.

Example:

```json
{
    "type": "fixed_per_lead",
    "amount": 80
}
```

---

# Sector Configurations

## Taxi

Taxi commission is calculated from the **final paid price**.

The reference price is only used during price negotiation between the platform, driver and customer.

It is **not** used for commission calculation.

Configuration:

```json
{
    "version":1,
    "sector":"taxi",
    "enabled":true,
    "rules":{
        "default":{
            "type":"percentage",
            "commissionRate":10
        }
    }
}
```

---

## Vet

Vet uses two different commission models.

### Surgery

Percentage commission.

### Other Services

Fixed amount per lead.

Configuration:

```json
{
    "version":1,
    "sector":"vet",
    "enabled":true,
    "rules":{
        "surgery":{
            "type":"percentage",
            "commissionRate":10,
            "conditions":{
                "serviceCategory":"surgery"
            }
        },
        "default":{
            "type":"fixed_per_lead",
            "amount":80,
            "conditions":{
                "serviceCategory":"default"
            }
        }
    }
}
```

---

## Groomy

Groomy uses discount-based percentage commission.

Configuration:

```json
{
    "version":1,
    "sector":"groomy",
    "enabled":true,
    "rules":{
        "rule_1":{
            "type":"percentage",
            "commissionRate":10,
            "conditions":{
                "discountFrom":0,
                "discountTo":15
            }
        },
        "rule_2":{
            "type":"percentage",
            "commissionRate":7,
            "conditions":{
                "discountFrom":15.01,
                "discountTo":100
            }
        }
    }
}
```

---

## Hotel

Hotel currently uses the same pricing strategy as Groomy.

```json
{
    "version":1,
    "sector":"hotel",
    "enabled":true,
    "rules":{
        "rule_1":{
            "type":"percentage",
            "commissionRate":10,
            "conditions":{
                "discountFrom":0,
                "discountTo":15
            }
        },
        "rule_2":{
            "type":"percentage",
            "commissionRate":7,
            "conditions":{
                "discountFrom":15.01,
                "discountTo":100
            }
        }
    }
}
```

---

## Training

Training currently uses the same pricing strategy as Groomy.

```json
{
    "version":1,
    "sector":"training",
    "enabled":true,
    "rules":{
        "rule_1":{
            "type":"percentage",
            "commissionRate":10,
            "conditions":{
                "discountFrom":0,
                "discountTo":15
            }
        },
        "rule_2":{
            "type":"percentage",
            "commissionRate":7,
            "conditions":{
                "discountFrom":15.01,
                "discountTo":100
            }
        }
    }
}
```

---

## Petshop

Petshop supports multiple product categories.

Each category contains its own commission rules.

Current categories:

* food
* non_food

Food:

```json
{
    "rules":{
        "rule_1":{
            "type":"percentage",
            "commissionRate":10,
            "conditions":{
                "discountFrom":0,
                "discountTo":15
            }
        },
        "rule_2":{
            "type":"percentage",
            "commissionRate":7,
            "conditions":{
                "discountFrom":15.01,
                "discountTo":25
            }
        },
        "rule_3":{
            "type":"percentage",
            "commissionRate":0,
            "conditions":{
                "discountFrom":25.01,
                "discountTo":100
            }
        }
    }
}
```

Non-food:

```json
{
    "rules":{
        "rule_1":{
            "type":"percentage",
            "commissionRate":12,
            "conditions":{
                "discountFrom":0,
                "discountTo":15
            }
        },
        "rule_2":{
            "type":"percentage",
            "commissionRate":9,
            "conditions":{
                "discountFrom":15.01,
                "discountTo":25
            }
        },
        "rule_3":{
            "type":"percentage",
            "commissionRate":0,
            "conditions":{
                "discountFrom":25.01,
                "discountTo":100
            }
        }
    }
}
```
---

# Financial Object

Every successful payment, booking, appointment or order must store a standardized `financial` object.

Depending on the sector, some fields may be `null`.

Example:

```json
{
    "sector":"taxi",

    "referencePrice":null,

    "sellerPrice":1200,

    "finalPrice":1200,

    "discountPercent":null,

    "commissionType":"percentage",

    "commissionRate":10,

    "commissionAmount":120,

    "businessNetAmount":1080,

    "calculatedAt":"serverTimestamp"
}
```

---

## Field Definitions

| Field             | Description                              |
| ----------------- | ---------------------------------------- |
| sector            | Business sector                          |
| referencePrice    | Platform reference price (if applicable) |
| sellerPrice       | Seller's accepted price                  |
| finalPrice        | Final amount paid by customer            |
| discountPercent   | Discount compared to reference price     |
| commissionType    | percentage / fixed / fixed_per_lead      |
| commissionRate    | Percentage value when applicable         |
| commissionAmount  | Petsupo platform fee                     |
| businessNetAmount | Amount belonging to business             |
| calculatedAt      | Commission calculation timestamp         |

---

# Calculation Models

The engine currently supports three calculation strategies.

---

## Final Price Strategy

Used by:

* Taxi

Formula:

```text
commissionAmount =
finalPrice × commissionRate / 100

businessNetAmount =
finalPrice − commissionAmount
```

---

## Discount Strategy

Used by:

* Groomy
* Hotel
* Training

Formula:

```text
discountPercent =
((referencePrice - sellerPrice)
/ referencePrice) × 100
```

The calculated discount determines which commission rule should be used.

After selecting the matching rule:

```text
commissionAmount =
sellerPrice × commissionRate / 100

businessNetAmount =
sellerPrice − commissionAmount
```

---

## Product Strategy

Used by:

* Petshop

Flow:

```text
Product Category

↓

Food / Non-Food

↓

Discount Calculation

↓

Rule Selection

↓

Commission Calculation
```

---

## Service Strategy

Used by:

* Vet

Flow:

```text
Service Category

↓

Surgery ?

      │

      ├── Yes → Percentage

      └── No → Fixed Per Lead
```

---

# Engine Flow

```text
Payment Completed

↓

calculateCommission()

↓

Load Firestore Configuration

↓

Resolve Strategy

↓

Execute Strategy

↓

Return Financial Object

↓

Save financial
```

---

# Dashboard Rules

Every dashboard must use the standardized `financial` object.

Required fields:

```text
financial.finalPrice

financial.sellerPrice

financial.commissionAmount

financial.businessNetAmount
```

Example metrics:

```text
Gross Sales

Platform Fee

Net Revenue
```

No dashboard should perform commission calculations.

All calculations must come from the Commission Engine.

---

# Design Principles

The Commission Engine follows these principles:

* Single Responsibility
* Strategy Pattern
* Configuration Driven
* Firestore Configurable
* Versioned Configurations
* No Hardcoded Commission Rules
* Testable
* Extensible

---

# Future Improvements (v2)

Possible future enhancements include:

* Rule priority
* Rule effective dates
* Campaign-specific rules
* Business-specific overrides
* Region-specific commission rules
* Promotional commission campaigns
* Seasonal commission rules
* Loyalty program integration
* Settlement engine
* Provider payout scheduling
* Revenue reporting
* Admin commission editor
* Audit logs
* Commission simulation API
* A/B testing of commission rules

---

# Summary

The Petsupo Universal Commission Engine provides a unified, extensible and configuration-driven architecture for calculating commissions across all Petsupo business sectors.

Business rules are stored in Firestore, synchronized from version-controlled JSON configuration files, executed through sector-specific strategies, and persisted as a standardized financial object.

This architecture minimizes code duplication, isolates sector-specific logic, and allows new sectors or commission models to be introduced with minimal changes to the core engine.
