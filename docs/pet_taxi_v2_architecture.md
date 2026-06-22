# 🐾 Pet Taxi V2 Architecture

No implementation should start before the documentation is updated.

Status: Planning

Last Update: 2026-06-22

Owner: Petsupo

---

# Vision

Pet Taxi is NOT a business directory.

Pet Taxi is a real-time ride dispatch system similar to Uber and BiTaksi,
designed specifically for pet transportation.

---

# Product Principles

✅ Request first

❌ Browse first

---

# User Journey

User opens Pet Taxi

↓

Map opens

↓

Nearby available drivers are visible

↓

User enters destination

↓

User selects pet

↓

Request Ride

↓

Request is sent to nearby drivers

↓

First accepted driver is assigned

↓

Live tracking starts

↓

Ride completed

↓

Rating

---

# Screen Flow

PetTaxiPage

↓

PetTaxiMapPage

↓

SearchingBottomSheet

↓

DriverAcceptedBottomSheet

↓

TrackingBottomSheet

↓

CompletedBottomSheet

---

# UI Layout

Full Screen Google Map

+ Driver Layer

+ User Location Layer

+ Route Layer

+ Floating Buttons

+ Draggable Bottom Sheet

---

# Bottom Sheet States

Idle

Searching

Driver Accepted

Driver Arriving

Ride Started

Completed

---

# Driver States

offline

online

available

busy

arriving

driving

---

# Ride States

draft

searching

accepted

driver_arriving

picked_up

completed

cancelled

---

# Firestore Collections

businesses

pet_taxi_requests

pet_taxi_driver_locations

pet_taxi_history

---

# Architecture

UI

↓

Service

↓

Repository

↓

Firestore

↓

Cloud Functions

↓

FCM

---

# Phase 1 (MVP)

✅ Full Screen Map

✅ Nearby Drivers

✅ Request Ride

✅ Driver Accept

✅ Live Status

---

# Phase 2

Route Preview

ETA

Animated Driver Movement

Driver Rating

Ride History

---

# Phase 3

Scheduled Ride

Favorite Drivers

Promo Codes

Ride Sharing

Dynamic Pricing

Multiple Stops

---

# UX Rules

No business list on home screen.

Map is always visible.

Bottom sheet controls the whole experience.

One primary CTA:

Request Pet Taxi

---

# Future Integrations

Vet

Need transportation?

Request Pet Taxi

---

Groomy

Need transportation?

Request Pet Taxi

---

Hotel

Need transportation?

Request Pet Taxi

---

Adoption

Bring your new pet home

Request Pet Taxi

---

# Notes

Pet Taxi is one of the flagship features of Petsupo.

Every implementation must follow this architecture.

No UI should be added outside this document without updating this roadmap.