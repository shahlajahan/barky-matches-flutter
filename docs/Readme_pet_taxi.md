# 🐾 Petsupo Documentation

Welcome to the Petsupo technical documentation.

This directory contains architecture, product decisions, UI wireframes,
backend planning, and development roadmaps for major features.

---

# Documentation Rules

1. Product comes before implementation.
2. Architecture comes before coding.
3. Every major decision must be documented.
4. ADR files record irreversible architecture decisions.
5. UI prototypes should be approved before backend implementation.

---

# Pet Taxi V2

Current Status

🟢 Planning

Vision

Pet Taxi is a real-time transportation platform for pets.

It is inspired by Uber and BiTaksi and follows a Map First UX approach.

The user should request a ride instead of browsing businesses.

---

# Reading Order

For new developers:

1. pet_taxi_prd.md
2. pet_taxi_v2_architecture.md
3. pet_taxi_ui_wireframe.md
4. pet_taxi_state_machine.md
5. pet_taxi_firestore_schema.md
6. pet_taxi_api_flow.md
7. pet_taxi_sprint_plan.md
8. pet_taxi_design_system.md

Finally:

Read all files inside /decisions

---

# Current Architecture

PetTaxiPage

↓

Full Screen Google Map

↓

Driver Layer

↓

Floating Actions

↓

Draggable Bottom Sheet

↓

Request Ride

---

# Development Philosophy

Prototype First

↓

Validate UX

↓

Implement Backend

↓

Production

---

# Core Principles

✅ Map First

✅ One Primary Action

✅ Real-time Experience

✅ State Machine Driven

✅ Modular Architecture

❌ Business Directory Home

❌ Complex Forms

❌ Multiple Primary CTAs

---

# Module Structure

ui/

pet_taxi/

pages/

widgets/

services/

models/

---

# Sprint Status

Sprint 1

Documentation ✅

Architecture ✅

Wireframe ✅

Planning ✅

Next:

Interactive Prototype

---

# Long-term Vision

Pet Taxi should become one of the flagship features of Petsupo.

Future integrations:

- Veterinary
- Grooming
- Pet Hotel
- Adoption
- Marketplace
- AI Assistant

Every implementation should follow the documented architecture.

If implementation and documentation differ,
documentation must be updated before new development starts.

---

Last Updated

2026-06-22