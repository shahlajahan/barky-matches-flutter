Task: Build the desktop-only Veterinary Web Dashboard and production Revenue analytics.

Project:
Flutter application: barky-matches-flutter

Critical constraints:
- Do not modify the existing mobile VetDashboardPage UI or behavior.
- Do not change iOS or Android dashboards.
- The new dashboard is only used by VetWebDashboardPage.
- Do not modify functions/index.js in this task.
- Do not use mock financial values.
- Do not infer surgery from serviceTitle or serviceId.
- Do not recalculate commissions in Flutter.
- Read persisted Commission Engine results from vet_appointments.financial.
- Preserve all unrelated working-tree changes.
- Use the existing AppTheme where practical.
- Run dart format and flutter analyze after implementation.

Existing mobile files that may be reused:
- lib/ui/business/dashboard/vet/vet_dashboard_page.dart
- lib/ui/business/dashboard/vet/sections/vet_dashboard_overview_tab.dart
- lib/ui/business/dashboard/vet/sections/vet_dashboard_appointments_tab.dart
- lib/ui/business/dashboard/vet/appointment_detail_page.dart
- lib/ui/business/dashboard/vet/add_services_page.dart
- lib/ui/business/dashboard/vet/add_service_detail_page.dart

Create:
1. lib/ui/business/dashboard/vet/vet_web_dashboard_page.dart
2. lib/ui/business/dashboard/vet/web/revenue/vet_revenue_model.dart
3. lib/ui/business/dashboard/vet/web/revenue/vet_revenue_repository.dart
4. lib/ui/business/dashboard/vet/web/revenue/vet_revenue_section.dart
5. lib/ui/business/dashboard/vet/web/revenue/vet_revenue_chart.dart
6. lib/ui/business/dashboard/vet/web/revenue/vet_revenue_table.dart

Dependency:
- Use fl_chart for charts.
- If fl_chart is not present in pubspec.yaml, add the latest version compatible with the current Flutter/Dart SDK using flutter pub add fl_chart.
- Do not add a second charting package.

==================================================
PART 1 — WEB DASHBOARD SHELL
==================================================

Implement VetWebDashboardPage as a StatefulWidget with:

Required constructor:
- String businessId
- Map<String, dynamic> businessData

Desktop layout:
- Full-height Row.
- Fixed left sidebar around 248 px.
- Expanded main content.
- Light professional background.
- Desktop-style top header.
- Content constrained to a sensible maximum width but usable on large screens.
- Minimum target width is 1100 px.
- Do not add kIsWeb checks inside this page; routing is already handled by BusinessDashboardPage.

Sections:
- Overview
- Appointments
- Revenue

Use an enum local to the Web dashboard:
VetWebDashboardSection { overview, appointments, revenue }

Sidebar:
- PetSupo/Veterinary identity area.
- Business name from businessData using safe fallbacks:
  profile.businessName
  businessName
  name
  "Veterinary Dashboard"
- Navigation entries with Lucide icons.
- Selected state must use the PetSupo brand burgundy color #9E1B4F.
- Smooth selected-state animation.
- Avoid mobile horizontal tabs.

Content:
- Overview reuses VetDashboardOverviewTab.
- Appointments reuses VetDashboardAppointmentsTab.
- Revenue uses VetRevenueSection.
- Preserve widget state with IndexedStack.

Overlay behavior:
Reproduce the existing VetDashboardPage overlay behavior:
- selectedAppointmentId → AppointmentDetailPage
- BusinessSubPage.addService → AddServicesPage
- BusinessSubPage.addServiceDetail → AddServiceDetailPage
- Use context.select so unrelated AppState changes do not rebuild the whole dashboard.
- Render overlays with Positioned.fill above the Web dashboard.
- Do not change AppState.

Top header:
- Display current section title.
- Display a short section subtitle.
- Show business name.
- Include a refresh action only for Revenue if the repository implementation needs explicit refresh.
- Do not invent notification counts or fake profile data.

Responsive safeguard:
- The dashboard should remain stable between 1100 and 2000+ px.
- Avoid hardcoded main-content widths.
- Use LayoutBuilder/Wrap where useful.
- No horizontal RenderFlex overflow.

==================================================
PART 2 — REVENUE DATA CONTRACT
==================================================

Source collection:
vet_appointments

Query:
where businessId == supplied businessId

Avoid requiring a composite Firestore index:
- Do not combine the businessId where query with orderBy.
- Sort documents client-side by paidAt/scheduledAt/createdAt descending.

Use realtime snapshots unless an existing repository convention strongly favors another approach.

Financial source of truth:
vet_appointments.financial

Known persisted fields:
financial.version
financial.sector
financial.finalPrice
financial.commissionType
financial.commissionRate
financial.commissionAmount
financial.businessNetAmount
financial.platformRevenue
financial.businessReceivable
financial.ruleSnapshot
financial.payoutStatus
financial.calculatedAt
financial.settlement.status
financial.settlement.eligibleAt
financial.settlement.scheduledPayoutDate
financial.settlement.processingAt
financial.settlement.paidAt
financial.settlement.bankReference
financial.settlement.attempts
financial.settlement.lastError

Appointment fields:
businessId
businessName
ownerProfile.ownerName
petName
dogName
serviceTitle
serviceCategory
scheduledAt
paidAt
price
servicePrice
paymentStatus
status
refundStatus
refundedAt
paymentId
paymentTransactionId
orderId
invoice.status
invoiceStatus

Rules:
1. Recognized paid revenue:
   paymentStatus == "paid"
   AND paidAt is present
   AND financial exists with valid numeric values.

2. Never calculate commission in Flutter.

3. Never derive Net as price minus the current commission config.

4. Gross:
   financial.finalPrice

5. Commission:
   financial.commissionAmount

6. Business Net:
   financial.businessNetAmount

7. Expired opportunity:
   paymentStatus == "expired" OR status == "payment_expired"
   Use price/servicePrice only for this non-revenue opportunity metric.

8. Refunded transaction:
   paymentStatus == "refunded" OR refundStatus == "refunded"
   It must not remain part of recognized revenue totals.
   Display it separately.

9. Pending:
   paymentStatus in:
   pending
   awaiting_payment
   payment_pending

10. Legacy paid appointment:
    If paymentStatus == paid but financial is absent, classify it as
    financialDataMissing.
    Do not include it in Gross, Commission, or Net totals.
    Show a warning/count in the Revenue UI.

11. Be defensive about Firestore types:
    int
    double
    num
    numeric String
    Timestamp
    ISO-8601 String
    null

12. Currency:
    TRY for current Vet records, but model it as a field and use existing payment currency when present.
    Do not support currency conversion.
    If mixed currencies exist, do not add them into one misleading total.

==================================================
PART 3 — MODEL
==================================================

Create immutable models with safe Firestore parsing.

Suggested types:
- VetRevenueTransaction
- VetRevenueSummary
- VetRevenuePoint
- VetRevenueStatus
- VetRevenueRange

VetRevenueRange:
- last7Days
- last30Days
- last90Days
- thisYear
- allTime

VetRevenueTransaction should include:
- appointmentId
- customerName
- petName
- serviceTitle
- serviceCategory
- eventDate
- paidAt
- scheduledAt
- currency
- grossAmount
- commissionAmount
- businessNetAmount
- paymentStatus
- appointmentStatus
- payoutStatus
- settlementStatus
- invoiceStatus
- paymentTransactionId
- status classification
- hasFinancialData

Provide pure helpers for:
- safe number parsing
- safe date parsing
- status normalization
- range filtering
- date bucketing
- totals

Do not put Firestore queries inside UI widgets.

==================================================
PART 4 — REPOSITORY
==================================================

VetRevenueRepository:
- Constructor accepts FirebaseFirestore optionally for testability.
- streamRevenue(String businessId) returns the parsed transaction list or a dedicated snapshot model.
- Query vet_appointments by businessId.
- Parse every document defensively.
- Sort client-side.
- Do not silently convert malformed paid records into zero-value revenue.
- Preserve legacy/missing-financial classification.
- Add useful debugPrint output only for malformed financial records; avoid noisy logs and avoid personal information in logs.

==================================================
PART 5 — REVENUE UI
==================================================

VetRevenueSection must be a production-quality desktop analytics page.

Header:
- Title: Revenue
- Description explaining it represents verified payment and settlement data.
- Range selector:
  7 days
  30 days
  90 days
  This year
  All time

Primary KPI cards:
- Gross Revenue
- PetSupo Commission
- Net Revenue
- Pending Settlement

Secondary operational metrics:
- Paid Transactions
- Pending Payments
- Refunded
- Expired Opportunities
- Missing Financial Data

Important:
- Never display fake percentage changes.
- Only display change versus previous period if it is calculated from actual records.
- Otherwise omit the comparison.

Main chart:
- Time-series chart using fl_chart.
- Show Gross and Net as two distinct series.
- Commission may be optional/hidden by default if three lines reduce clarity.
- Use meaningful tooltips.
- Handle zero-data state without exceptions.
- Bucket intelligently:
  7/30/90 days → daily or weekly as appropriate
  This year → monthly
  All time → monthly
- Do not generate fake points.

Breakdown:
- Show revenue by service category or service title using actual paid records.
- Prefer the top services by Gross.
- Group remaining services into “Other” when necessary.
- A compact bar chart or ranked table is acceptable.

Transaction table:
Columns:
- Date
- Customer
- Pet
- Service
- Gross
- Commission
- Net
- Payment
- Settlement
- Invoice
- Transaction reference

Features:
- Search customer, pet, service, appointmentId, or paymentTransactionId.
- Payment-status filter.
- Sort by date, Gross, Commission, or Net.
- Paginate locally.
- Default page size around 10–15.
- Horizontal scrolling is allowed only inside the table.
- Do not allow the entire page to overflow horizontally.
- Use SelectableText for transaction reference where appropriate.
- Empty state must distinguish:
  no appointments
  no records in selected range
  paid records missing financial data

Formatting:
- Display TRY in Turkish currency style, e.g. ₺5.500,00.
- Avoid adding intl dependency if the project already has intl transitively or directly.
- Reuse an existing currency formatter if the project has one.
- Otherwise create a small local formatter using intl only if intl is already available.
- Dates should respect the current app locale where practical.

States:
- Loading skeleton or professional loading indicator.
- Firestore error state with retry/reconnect guidance.
- Empty state.
- Missing financial data warning.
- Mixed currency warning.
- Do not expose raw Firestore errors directly to end users.

==================================================
PART 6 — CHART ACCESSIBILITY AND QUALITY
==================================================

- Use consistent PetSupo brand colors.
- Gross: burgundy/dark pink family.
- Net: green/teal family.
- Commission: amber if shown.
- Provide a visible legend.
- Ensure contrast is readable.
- Charts must not crash with one point, zero points, or identical values.
- Avoid excessively dense axis labels.
- Do not use 3D charts.
- Avoid decorative charts with no operational meaning.

==================================================
PART 7 — LOCALIZATION
==================================================

Inspect the existing ARB localization setup before adding strings.

Add all new Web dashboard and Revenue strings to every required ARB file:
- English
- Turkish
- Persian
- Russian

Do not hardcode user-facing English strings if the project localization architecture supports them.

After editing ARB files:
- Run the project’s localization generation command or flutter gen-l10n.
- Ensure generated localization code is current.
- Do not manually edit generated localization output unless the existing project intentionally does so.

==================================================
PART 8 — BUSINESS DASHBOARD ROUTING
==================================================

Inspect:
lib/ui/business/dashboard/business_dashboard_page.dart
or its actual existing path.

Ensure only desktop Web routes to VetWebDashboardPage:

final isDesktopWeb =
    kIsWeb && MediaQuery.sizeOf(context).width >= 1100;

For BusinessSector.vet:
- desktop Web → VetWebDashboardPage
- everything else → existing VetDashboardPage

Do not change routing for other business sectors in this task.
Do not create placeholder Web dashboards for Groomy, Hotel, Taxi, Petshop, or Adoption.

==================================================
PART 9 — TESTS
==================================================

Create model/repository-oriented unit tests where feasible.

Required pure parsing tests:
1. Valid paid Vet appointment with financial data.
2. Surgery financial data.
3. Fixed-per-lead financial data.
4. Expired appointment with price but no financial.
5. Refunded payment excluded from recognized totals.
6. Paid legacy record missing financial.
7. Numeric Firestore values as int, double, and String.
8. Timestamp and ISO String dates.
9. Range filtering.
10. Gross/Commission/Net aggregation.
11. Mixed currencies are detected.
12. Zero-data summary.

Avoid relying on the live Firestore project in unit tests.

==================================================
PART 10 — VERIFICATION
==================================================

Run:
dart format on touched Dart files
flutter pub get
flutter gen-l10n if applicable
flutter analyze

Run relevant tests.

Report:
- Files created
- Files modified
- Firestore query used
- Revenue recognition rules implemented
- How missing financial data is handled
- Any index requirement
- Analyzer/test results
- Confirmation that mobile iOS/Android dashboards were not modified
- Confirmation that Groomy/Hotel/Taxi/Petshop/Adoption routing was not changed

Do not deploy Hosting or Functions in this task.
Do not commit or push.