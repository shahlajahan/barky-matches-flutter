import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/debug/auth_boot_trace.dart';
import 'l10n/app_localizations.dart';
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
/// Routing now switches on [AuthRestorationPhase]. The distinction that
/// matters for security and UX is between *confirmed* signed out and merely
/// *unknown*: only a successful auth emission of null reaches WelcomePage. A
/// stream error or the defensive timeout leaves the state unknown and offers a
/// retry, because assuming "signed out" there would log a valid user out of
/// their own session in the UI.
///
/// AppState already owns the auth subscription, uid, guest state and profile
/// readiness, so this reads existing ownership rather than introducing a
/// second auth state system. Every downstream rule — guest, blocked/suspended,
/// profile-completion — is reached exactly as before.
class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🧨 AppEntry.build');

    final appState = context.watch<AppState>();

    AuthBootTrace.record(
      'app_entry_route',
      data: <String, Object?>{
        'phase': appState.authRestorationPhase.name,
        'profileReady': appState.isUserProfileReady,
        'isGuest': appState.isGuest,
        'destination': switch (appState.authRestorationPhase) {
          AuthRestorationPhase.restoring => 'loading',
          AuthRestorationPhase.failed => 'startup_error',
          AuthRestorationPhase.unauthenticated => 'welcome',
          AuthRestorationPhase.authenticated =>
            appState.isUserProfileReady ? 'home_gate' : 'loading_profile',
        },
      },
    );

    switch (appState.authRestorationPhase) {
      // Unknown, still in progress: keep the existing launch presentation.
      // Never WelcomePage (would falsely read as signed out) and never an
      // authenticated page (would be premature).
      case AuthRestorationPhase.restoring:
        return const _StartupLoading();

      // Unknown, and it stopped making progress. Still not a sign-out.
      case AuthRestorationPhase.failed:
        return const _StartupAuthError();

      // The only state permitted to show the signed-out entry point.
      case AuthRestorationPhase.unauthenticated:
        return const WelcomePage();

      // Settled authenticated (including an anonymous/guest session): fall
      // through to the unchanged profile-readiness gate and destination logic.
      case AuthRestorationPhase.authenticated:
        if (!appState.isUserProfileReady) {
          return const _StartupLoading();
        }
        return const HomeGate();
    }
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

/// Shown when restoration could not be determined.
///
/// Deliberately generic: it reuses the existing `somethingWentWrong` /
/// `retryButton` strings and never surfaces Firebase exception details. The
/// retry re-runs restoration rather than signing anyone out.
class _StartupAuthError extends StatelessWidget {
  const _StartupAuthError();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.somethingWentWrong, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    context.read<AppState>().retryAuthRestoration(),
                child: Text(l10n.retryButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
