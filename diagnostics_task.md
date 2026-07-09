# Diagnostics Infrastructure Upgrade (Safe Refactor)

## Objective

Upgrade the diagnostics infrastructure ONLY.

This is NOT a feature task.

This is NOT a project refactor.

The Flutter application behavior must remain 100% unchanged.

---

# STRICT SAFETY RULES

You may ONLY modify files inside:

lib/core/debug/

You may create new files ONLY inside:

lib/core/debug/

DO NOT modify ANY file outside this directory.

Specifically DO NOT touch:

- lib/main.dart
- pubspec.yaml
- Firebase
- Firestore
- Authentication
- Navigation
- UI
- Widgets
- Business logic
- Existing Features

Do NOT add packages.

Do NOT remove any public APIs.

Do NOT rename any public methods.

Maintain full backward compatibility.

---

# Goals

Upgrade the diagnostics infrastructure.

The existing API such as:

AppLog.auth(...)
AppLog.nav(...)
AppLog.firestore(...)
AppLog.storage(...)
AppLog.network(...)
AppLog.payment(...)
AppLog.map(...)
AppLog.location(...)
AppLog.image(...)
AppLog.notification(...)
AppLog.ui(...)
AppLog.performance(...)
AppLog.error(...)

must continue working exactly as before.

---

# Task 1

Create:

log_level.dart

Enum:

- debug
- info
- warning
- error

---

# Task 2

Create:

session_manager.dart

Requirements:

Generate one random Session ID lazily.

The Session ID must be created the first time AppLog is used.

DO NOT require initialization from main.dart.

DO NOT require initialization from any application file.

Example Session ID:

A4F8-91BC

The Session ID remains constant until app restart.

---

# Task 3

Update LogEntry

Add:

- sessionId
- level

Update toMap().

---

# Task 4

Improve console formatting.

Readable output.

Example:

══════════════════════════════════════

🔵 FIRESTORE

Level:
INFO

Session:
A4F8-91BC

Time:
09:18:21

Message:
Load businesses

Data:
collection: businesses
count: 18

══════════════════════════════════════

Do NOT use ANSI colors.

Unicode characters are allowed.

---

# Task 5

DiagnosticsBuffer

Keep current behavior.

Keep snapshot() compatible.

---

# Task 6

AppLog

Keep all current public methods.

Internally support LogLevel.

Default level:

info

---

# Documentation

Update documentation comments where necessary.

---

# Final Verification

Before finishing verify:

- Only lib/core/debug changed.
- No files outside lib/core/debug changed.
- Existing AppLog API is fully backward compatible.
- Flutter application behavior is unchanged.
- No compile errors introduced.

If ANY requested improvement requires modifying files outside lib/core/debug,

STOP.

Explain why.

Do NOT make changes outside the allowed directory.
