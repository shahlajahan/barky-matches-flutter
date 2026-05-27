# Risk Assessment

## P0 Risks

### 1. Firestore Rules Must Be Reviewed

Critical areas:
- medical records
- business chats
- orders
- returns
- business ownership
- admin actions

Risk:
A user may access or update data they should not if rules are too broad.

Recommended action:
Review `firestore.rules` collection by collection.

---

### 2. Medical Record Growth

Risk:
If visits, vaccines, notes, and histories are stored as large arrays inside one document, Firestore document size limits can become a problem.

Recommended action:
Use subcollections:

medical_records/{recordId}
├── visits/{visitId}
├── vaccines/{vaccineId}
├── allergies/{allergyId}
└── documents/{documentId}

---

### 3. Business Chat Unread Counters

Risk:
Unread counters can become inconsistent if multiple devices update the same chat document.

Recommended action:
Use transactions or Cloud Functions for unread count updates.

---

### 4. Payment Production Readiness

Risk:
Marketplace and booking flows may exist in UI but payment gateway behavior must be verified for production.

Recommended action:
Audit:
- checkout service
- order service
- payment result pages
- refund/return service
- Cloud Function payment verification

---

## P1 Risks

### 1. `app_state.dart` Is Too Large

Risk:
Too many responsibilities in one file can make the app hard to maintain.

Recommended split:
- AuthStateController
- LocaleController
- SubscriptionController
- NotificationController
- BusinessAccessController

---

### 2. Duplicated Lost/Found Logic

Risk:
Lost and found report pages may duplicate image picking, location handling, and form validation.

Recommended action:
Create shared helpers:
- report_form_service.dart
- location_form_helper.dart
- image_upload_helper.dart

---

### 3. StreamBuilder Overuse

Risk:
Multiple dashboard tabs using StreamBuilder directly can increase Firestore reads and duplicate listeners.

Recommended action:
Move streams into services/controllers and cache where possible.

---

### 4. Async BuildContext Issues

Risk:
Navigator or ScaffoldMessenger after async calls can crash if widget is unmounted.

Recommended action:
Use:

if (!mounted) return;

before using context after await.

---

## P2 Risks

### 1. Localization Incompleteness

Risk:
Some languages may have missing or inconsistent strings.

Recommended action:
Run localization consistency check across:
- app_en.arb
- app_tr.arb
- app_fa.arb
- app_ru.arb

---

### 2. Dashboard Duplication

Risk:
Vet, groomy, pet hotel, and adoption dashboards may repeat similar UI patterns.

Recommended action:
Create shared dashboard components:
- DashboardStatCard
- DashboardSectionShell
- BusinessGalleryManager
- BusinessWorkingHoursEditor
- BusinessServiceEditor

---

### 3. Documentation Drift

Risk:
Architecture docs may become outdated as code changes.

Recommended action:
Update docs after major commits.