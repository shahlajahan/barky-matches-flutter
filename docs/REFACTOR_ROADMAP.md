# Refactor Roadmap

## P0 — Critical

### 1. Firestore Rule Audit

Review and tighten:
- users
- businesses
- medical_records
- business_chats
- orders
- order_returns
- adoption_requests
- notifications
- admin collections

Goal:
Prevent unauthorized reads/writes.

---

### 2. Medical Records Subcollection Refactor

Current risk:
Long medical histories can grow too large.

Target structure:

medical_records/{recordId}
├── profile
├── visits/{visitId}
├── vaccines/{vaccineId}
├── medications/{medicationId}
├── allergies/{allergyId}
└── documents/{documentId}

---

### 3. Business Chat Reliability

Improve:
- unread counters
- message delivery status
- notification triggers
- offline behavior
- sender/receiver validation

Recommended:
Use Firestore transactions or Cloud Functions for critical counters.

---

### 4. Payment and Return Verification

Audit:
- petshop checkout
- appointment payment
- order creation
- return request
- refund trigger
- payment result screens

Goal:
Separate demo/mock flows from production-ready flows.

---

## P1 — Important

### 1. Split `app_state.dart`

Suggested controllers:

lib/state/
├── auth_state_controller.dart
├── locale_controller.dart
├── subscription_controller.dart
├── notification_controller.dart
├── business_access_controller.dart
└── app_state_facade.dart

---

### 2. Shared Business Dashboard Components

Create:

lib/ui/business/dashboard/shared/
├── dashboard_shell.dart
├── dashboard_stat_card.dart
├── business_gallery_manager.dart
├── working_hours_editor.dart
├── service_editor.dart
└── dashboard_empty_state.dart

Goal:
Reduce duplication across vet, groomy, pet hotel, and adoption center dashboards.

---

### 3. Shared Lost & Found Form Logic

Create:

lib/services/report_form_service.dart
lib/ui/common/report_location_picker.dart
lib/ui/common/report_image_picker.dart

Goal:
Reduce duplication in lost/found pages.

---

### 4. Extract Medical Record Services

Create:

lib/services/medical_records/
├── medical_record_service.dart
├── visit_service.dart
├── vaccine_service.dart
└── medical_record_validator.dart

---

## P2 — Nice To Have

### 1. Documentation Expansion

Add:

docs/
├── PRODUCT_MAP.md
├── TECHNICAL_ARCHITECTURE.md
├── FIREBASE_ARCHITECTURE.md
├── DASHBOARD_HIERARCHY.md
├── RISK_ASSESSMENT.md
└── REFACTOR_ROADMAP.md

---

### 2. Mermaid Diagrams

Add diagrams for:
- navigation
- dashboard hierarchy
- Firebase collections
- medical records
- chat
- marketplace

---

### 3. CI Improvements

Recommended checks:
- dart format
- flutter analyze
- flutter test
- Firebase rules test
- dependency audit

---

### 4. Localization Quality Check

Add script to verify all ARB files contain the same keys.

---

## Suggested Next Sprint Order

1. Firestore rules audit
2. Medical record subcollection planning
3. Business chat reliability
4. Payment/return verification
5. AppState split planning
6. Shared dashboard components
7. Lost/found shared form extraction
8. Documentation commit