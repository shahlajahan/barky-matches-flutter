Goal:

Determine why every Firestore read in Guest mode returns PERMISSION_DENIED while the equivalent REST query succeeds.

Do not restart previous investigations.

PROVEN

✓ Firebase project = barkymatches-new

✓ FirebaseApp correct

✓ FirebaseFirestore.instance used everywhere

✓ No secondary FirebaseApp

✓ No Firestore emulator

✓ No Firestore wrapper

✓ No App Check activation

✓ REST runQuery succeeds

✓ Flutter sends the exact expected query

✓ Query shape is NOT modified

✓ arrayContains is NOT the cause

✓ orderBy is NOT the cause

✓ Adoption is NOT a unique failure

✓ Vet also receives PERMISSION_DENIED but swallows the exception

Current work:

Instrumentation has started.

Created:

lib/debug/auth_timing_trace.dart

Imported into main.dart

AuthTimingTrace.start() added during startup.

Instrumentation is NOT complete.

Continue wiring AuthTimingTrace into:

- Firebase.initializeApp

- authStateChanges

- idTokenChanges

- userChanges

- signOut

- setGuestUser

- first Firestore request

- first PERMISSION_DENIED

Do not modify behavior.

Stop after instrumentation.

Wait for runtime logs.

Do NOT:

- investigate Firestore Rules again

- investigate query shape again

- investigate Adoption query again

- investigate REST again

- suggest fixes

- restart the audit

