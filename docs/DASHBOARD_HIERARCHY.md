# Dashboard Hierarchy

## Business Dashboard System

PetSupo includes multiple business-facing dashboards.

Business Dashboards
├── Vet Dashboard
├── Groomy Dashboard
├── Pet Hotel Dashboard
├── Petshop Dashboard
└── Adoption Center Dashboard

---

## Vet Dashboard

Path:

- `lib/ui/business/dashboard/vet/`

Vet Dashboard
├── Overview
│   └── `sections/vet_dashboard_overview_tab.dart`
├── Appointments
│   └── `sections/vet_dashboard_appointments_tab.dart`
├── Gallery
│   ├── `sections/vet_dashboard_gallery_tab.dart`
│   └── `vet_gallery_management_page.dart`
├── Services
│   ├── `add_services_page.dart`
│   ├── `add_service_detail_page.dart`
│   └── `vet_services_management_page.dart`
├── Working Hours
│   └── `vet_working_hours_page.dart`
├── Schedule
│   └── `vet_schedule_page.dart`
├── Settings
│   └── `vet_settings_page.dart`
├── Client Messages
│   ├── `client_messages/vet_inbox_page.dart`
│   ├── `client_messages/vet_client_messages_page.dart`
│   └── `client_messages/quick_replies/vet_quick_replies_page.dart`
└── Patients
    ├── `vet_patients_page.dart`
    ├── `patients/vet_patient_detail_page.dart`
    ├── `patients/edit_medical_profile_page.dart`
    └── `patients/edit_visit_page.dart`

---

## Medical Records

Path:

- `lib/ui/medical_records/`
- `lib/social/services/patient_service.dart`
- `lib/constants/vaccine_catalog.dart`
- `lib/constants/pet_breeds.dart`

Medical Records
├── Medical Records Page
├── Medical Record Pet Card
├── Medical Record Flow Button
├── Patient Service
├── Vaccine Catalog
└── Pet Breed Catalog

---

## Groomy Dashboard

Path:

- `lib/ui/business/groomy/`

Groomy Dashboard
├── Overview
├── Appointments
├── Gallery
├── Profile Editing
└── Groomy Details Overlay

Status:
Functional but less complete than vet dashboard.

---

## Pet Hotel Dashboard

Path:

- `lib/ui/business/pet_hotel/`
- `lib/ui/business/dashboard/pet_hotel/`

Pet Hotel Dashboard
├── Overview
├── Bookings
├── Reviews
├── Booking Page
└── Details Overlay

Status:
Experimental / functional but incomplete.

---

## Petshop Dashboard

Path:

- `lib/ui/business/petshop/`
- `lib/ui/petshop/`

Petshop Dashboard
├── Product Management
├── Add Product
├── Edit Petshop Profile
├── Seller Offers
├── Product Cards
├── Orders
└── Returns

Status:
Functional but payment/stock/shipping must be production verified.

---

## Adoption Center Dashboard

Path:

- `lib/ui/business/adoption_center/`
- `lib/ui/business/dashboard/adoption_center/`

Adoption Center Dashboard
├── Overview
├── Gallery
├── Adoption Listings
├── Adoption Requests
└── Applicant Review

Status:
Functional but legal/signature/background screening flows are not fully confirmed.