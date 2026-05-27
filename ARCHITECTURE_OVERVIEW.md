# PetSupo Architecture Overview

## Project Summary

PetSupo is a Flutter + Firebase based pet-tech platform focused on Turkey and international expansion.

The platform combines:
- veterinary systems
- pet business management
- adoption systems
- social/community features
- pet owner tools
- booking/payment systems
- chat/messaging
- subscription systems
- NGO/social impact modules

Main business types:
- Veterinarians
- Groomers (Groomy)
- Pet Hotels
- Pet Shops
- Adoption Centers
- Pet Taxi (planned)

---

# Core Architecture

## Frontend
- Flutter
- Modular UI structure
- Overlay-based navigation
- Shared dashboard architecture
- Multi-language support

## Backend
- Firebase Auth
- Cloud Firestore
- Cloud Functions
- Firebase Messaging
- Firebase Analytics
- Firebase Storage

---

# Main Navigation

## Entry Points

Main files:
- lib/main.dart
- lib/home_gate.dart
- lib/app_state.dart

Navigation is primarily handled through:
- NavTab system
- overlays
- dashboard routing
- state-driven navigation

---

# Main App Sections

## Home
Main discovery and navigation hub.

Contains:
- nearby businesses
- promotions
- social modules
- emergency features
- quick actions

---

## Veterinary System

### User Side
- Vet discovery
- Vet detail overlays
- Appointment booking
- Reviews
- Emergency availability
- Messaging

### Vet Dashboard
Located under:
lib/ui/business/dashboard/vet/

Main modules:
- Overview
- Revenue
- Appointments
- Client Messages
- Services
- Gallery
- Emergency Availability
- Medical Profiles

---

## Groomy System

Architecture mirrors veterinary dashboard structure.

Contains:
- booking system
- groomer dashboard
- customer requests
- gallery/services

---

## Pet Hotel System

Includes:
- hotel booking
- availability management
- hotel dashboard
- payment flow

---

## Adoption System

### User Features
- adoption listings
- adoption request forms
- shelter browsing

### Adoption Center Dashboard
- applicant management
- pet listings
- adoption workflows

---

## Social Features

Includes:
- Pet profiles
- User profiles
- Social feed
- Chat/messaging
- Likes/interactions
- Community engagement

---

## Lost & Found

Features:
- lost pet reports
- found pet reports
- emergency alerts
- location-based visibility

---

## Green Memorial

Social responsibility module.

Allows:
- memorial pages
- tree planting awareness
- public/private memorial visibility

---

# Dashboard Architecture

The project uses a mirrored dashboard architecture.

Shared patterns exist between:
- vet
- groomy
- pet hotel
- adoption center

Common patterns:
- overview tabs
- revenue tabs
- messaging
- gallery management
- booking management

---

# Firebase Architecture

## Main Collections

Examples:
- users
- businesses
- vet_appointments
- groomy_appointments
- hotel_bookings
- notifications
- subscriptions
- reviews
- adoption_requests
- playDateRequests

---

# Cloud Functions

Main purposes:
- notifications
- booking updates
- payment workflows
- scheduled jobs
- moderation
- reminder systems

Region:
- europe-west3

---

# Localization

Supported languages:
- Turkish
- English
- Persian
- Russian

---

# Subscription System

Plans:
- normal
- premium
- gold

Used for:
- advanced filters
- premium messaging
- business access
- additional platform tools

---

# Important Architecture Notes

## Overlay-Based UX
The app heavily uses overlays instead of full page transitions.

## Shared Dashboard Strategy
Many business systems mirror veterinary architecture.

## Firebase-Centric Backend
Most business logic is driven through Firestore + Cloud Functions.

## Scalability Focus
The architecture is designed for future expansion into:
- additional pet services
- international markets
- business partnerships
- NGO collaborations

---

# Important Directories

## UI
lib/ui/

## Business Dashboards
lib/ui/business/dashboard/

## Services
lib/services/

## Models
lib/models/

## Shared Widgets
lib/widgets/

## Cloud Functions
functions/

---

# Current Focus Areas

Active development includes:
- dashboard improvements
- business messaging
- booking/payment flows
- adoption workflows
- medical profile systems
- notification reliability
- architecture stabilization
