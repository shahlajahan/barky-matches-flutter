# Changelog

## 2026-08-01 — Creator Referral Engine: Sprint 1 (Creator Foundation)

Full report: `docs/SPRINT1_REPORT.md`. Architecture: `docs/architecture/creator-referral-engine.md`.

### Security

- **Fixed SEC-1**: `firestore.rules` previously let any signed-in user
  self-write their own `users/{uid}` document with no field restriction,
  including a `creator` map that gates the Creator Program. Closed for
  both the document owner and admin-via-client-SDK; only the four new
  Cloud Functions below (Admin SDK) can write it now. Verified against a
  running Firestore emulator with four targeted tests (exploit blocked,
  unrelated self-writes still work, self-create with `creator` baked in
  blocked, admin-via-client also blocked).

### Added

- Cloud Functions (admin-only): `createCreatorProfile`, `assignReferralCode`,
  `activateCreator`, `deactivateCreator`.
- `referralCodes/{code}` Firestore collection (public read, Functions-only write).
- `AppState.creatorStatus`, populated everywhere `creatorEnabled` already is.
- Visible "Sample data" indicator on every Creator Dashboard section still
  backed by mock data (mobile and Web).

### Changed

- `AppState.creatorReferralLink` is now derived from `creatorReferralCode`
  (`https://petsupo.com/r/{code}`) instead of being read from a separately
  stored Firestore field — removes a two-sources-of-truth risk flagged in
  the architecture doc.

### Not included (deferred to a later sprint, per the architecture doc)

Referral attribution, click tracking, campaigns, rewards, payouts,
creator applications, admin review UI.
