# CODEX_HANDOFF.md

# PetSupo – Engineering Handoff

Last Updated: 2026-07-10

---

# Project

PetSupo is a Flutter application backed by Firebase.

Current architectural direction:

Firestore
        ↓
DogSyncService
        ↓
DogsBoxManager (Canonical Owner)
        ↓
AppState (Projection Layer)
        ↓
UI

The UI must never directly own or synchronize canonical dog state.

---

# Current Refactor Status

## Completed

### DogsBoxManager

Implemented:

- upsertDog(Dog)
- replaceAllCanonicalDogs(...)
- clearIfReady()

DogsBoxManager is now the canonical owner of local dog persistence.

---

### AppState

Added:

- addDogToLocalState()
- clearDogLocalState()

AppState delegates to DogsBoxManager.

AppState must not manually mutate canonical dog lists after writes.

---

### Migrated UI write paths

Completed:

- DogDetailsPage
- AddDogPage
- UserProfilePage (single dog writes)
- PlaymatePage (single dog writes)

These pages no longer write directly to Hive dogsBox.

---

### Logout

Completed.

UI now calls:

AppState.clearDogLocalState()

instead of

Hive.box('dogsBox').clear()

---

# Guest Mode

Guest Mode exists.

Guest user is represented by:

currentUserId = "guest"

Guest is NOT Firebase authenticated.

Therefore:

request.auth == null

Firestore rules apply normally.

---

# IMPORTANT

Do NOT solve Guest Mode by loosening Firestore rules unless explicitly required.

Guest Mode should avoid executing authenticated startup tasks.

---

# Current Bug

Guest Mode enters HomePage successfully.

Current startup sequence:

HomePage.initState()

↓

refreshDogs()

↓

_loadFeaturedDeals()

↓

_applyFiltersAsync()

refreshDogs() currently calls:

DogSyncService.fetchCanonicalDogs()

which reads:

Firestore
collection("dogs")

Guest receives:

PERMISSION_DENIED

because dogs collection is protected.

Current call site:

lib/home_page.dart

WidgetsBinding.instance.addPostFrameCallback(...)

↓

await context.read<AppState>().refreshDogs();

---

# Startup Policy

Desired architecture:

Authenticated startup tasks

↓

only for authenticated users

Guest-safe startup tasks

↓

run for everyone

Do NOT scatter guest checks throughout the codebase.

Prefer one centralized startup policy.

---

# Firestore Rules

Business rules were investigated.

Current adoption_center rule is NOT the blocker anymore.

REST verification confirmed the rule works.

Do not modify Firestore rules unless a new investigation proves otherwise.

---

# Things that MUST NOT change

Do NOT modify:

- DogsBoxManager architecture
- AppState ownership model
- Firestore schema
- Firestore Rules (unless explicitly requested)
- UI navigation
- Analytics
- Startup ordering (unless required for Guest policy)
- Adoption logic

---

# Preferred Engineering Style

Always:

1. Audit first.
2. Explain root cause.
3. Implement the smallest possible change.
4. Preserve behavior for authenticated users.
5. Stop after requested scope.

Never perform unrelated refactors.

---

# Open Task

Implement a centralized Guest startup policy.

Goal:

Guest must not execute authenticated startup tasks.

Authenticated behavior must remain unchanged.

No Firestore rule changes.

No UI guest checks scattered across pages.