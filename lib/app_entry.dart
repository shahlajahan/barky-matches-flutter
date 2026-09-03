import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'welcome_page.dart';
import 'home_gate.dart';
import 'app_state.dart';

/// Startup routing.
///
/// This used to decide from a single direct read of
/// `FirebaseAuth.instance.currentUser`. Firebase restores a persisted session
/// asynchronously, so at launch that read is briefly null even for a signed-in
/// user — and the null branch sent them straight to WelcomePage, which is the
/// "signed out after reopening the app" report.
///
/// Routing now waits for AppState to report a *settled* auth result. AppState
/// already owns the auth subscription, uid, guest state and profile readiness,
/// so this reads existing ownership rather than introducing a second auth
/// state system. Every downstream rule — guest, blocked/suspended,
/// profile-completion — is reached exactly as before, only no longer skipped
/// by a premature WelcomePage.
class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🧨 AppEntry.build');

    final appState = context.watch<AppState>();

    // Restoring / unknown: keep the existing launch presentation. Never
    // WelcomePage (would falsely read as signed out) and never an
    // authenticated page (would be premature).
    if (!appState.authRestorationSettled) {
      return const _StartupLoading();
    }

    // Settled unauthenticated.
    if (!appState.hasRestoredAuthUser) {
      return const WelcomePage();
    }

    // Settled authenticated (including an anonymous/guest session): fall
    // through to the unchanged profile-readiness gate and destination logic.
    if (!appState.isUserProfileReady) {
      return const _StartupLoading();
    }

    return const HomeGate();
  }
}

/// The same loading presentation this file already used for the
/// profile-readiness wait — reused so startup visuals are unchanged.
class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
