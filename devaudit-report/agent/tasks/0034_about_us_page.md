# Task 0034: lib/ui/support/about_us_page.dart

## Target file

lib/ui/support/about_us_page.dart

## Findings

- `12:27` **warning** Probable user-visible hardcoded string in Text(data: ...). ("About Us") `[flutter.localization.hardcoded-ui-string]`
- `17:21` **warning** Probable user-visible hardcoded string in Text(data: ...). ("""
PetSupo is a digital platform designed to connect pet owners and improve the social lives of pets.

The application enables users to find suitable playmates for their dogs, discover nearby veterinary services, and access pet-related businesses such as pet shops, groomers, and pet hotels.

PetSupo does not act as a service provider but as a facilitator between users and third-party services. Users are responsible for their interactions and decisions made through the platform.

Our mission is to provide a safe, efficient, and user-friendly environment for pet owners worldwide.
""") `[flutter.localization.hardcoded-ui-string]`

## Suggested objective

Only make the changes described below. Do not alter unrelated logic, tests, or formatting.
- Move this text into the project's localization resources instead of hardcoding it.
