# PetSupo Technical Architecture

## Repository Overview

PetSupo is a Flutter + Firebase application with modular UI sections, business dashboards, Firebase backend logic, Firestore rules, localization, chat, booking, marketplace, adoption, medical records, and admin systems.

## Core Files

- `lib/main.dart`
- `lib/app_state.dart`
- `lib/home_gate.dart`
- `lib/ui/shell/barky_scaffold.dart`
- `lib/ui/shell/barky_drawer.dart`
- `lib/ui/shell/nav_tab.dart`

## Core Flow

HomeGate
├── Authentication flow
├── User / consumer shell
├── Business dashboard access
├── Admin access
└── Role-based navigation

## Main App Sections

lib/
├── home_page.dart
├── vet_page.dart
├── playmate_page.dart
├── adoption_page.dart
├── notifications_page.dart
├── all_notifications_page.dart
├── ui/
│   ├── business/
│   ├── vet/
│   ├── petshop/
│   ├── cart/
│   ├── checkout/
│   ├── orders/
│   ├── returns/
│   ├── adoption/
│   ├── admin/
│   ├── medical_records/
│   ├── setting/
│   ├── legal/
│   └── support/
├── services/
├── models/
├── constants/
└── l10n/

## Navigation Tree

HomeGate
├── BarkyScaffold
│   ├── HomePage
│   │   └── BusinessDetailOverlay
│   ├── PlaymatePage
│   │   └── DogInfoPage
│   ├── VetPage
│   │   └── VetDetail / BusinessDetailOverlay
│   ├── AdoptionPage
│   │   └── Adoption request flow
│   └── Drawer
│       ├── Notifications
│       ├── Lost & Found
│       ├── Orders
│       ├── Settings
│       ├── Legal
│       ├── Support
│       └── Feedback
└── Business Dashboards
    ├── Vet Dashboard
    ├── Groomy Dashboard
    ├── Pet Hotel Dashboard
    ├── Petshop Dashboard
    └── Adoption Center Dashboard

## Important Architecture Notes

- `app_state.dart` is a large central state holder.
- `home_gate.dart` controls major access routing.
- Business dashboards follow mirrored patterns.
- Vet dashboard is the most developed professional dashboard.
- Medical records and business chat are major new systems.
- Marketplace/payment flows exist but need careful production validation.