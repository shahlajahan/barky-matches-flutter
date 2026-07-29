import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../debug/auth_trap.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Shown instead of the normal app shell whenever the signed-in user's
/// account is currently suspended or blocked (AppState.isAccountSuspended).
/// Non-dismissable by design - the only way out is signing out, or an
/// admin reactivating the account (which the live listener picks up
/// immediately and this screen disappears on its own).
class SuspendedAccountPage extends StatelessWidget {
  const SuspendedAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final reason = appState.accountModerationReason;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.primary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.block, color: Colors.white, size: 72),
                  const SizedBox(height: 24),
                  Text(
                    l10n.suspendedAccountTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    (reason != null && reason.trim().isNotEmpty)
                        ? reason
                        : l10n.suspendedAccountDefaultReason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    onPressed: () =>
                        AuthTrap.signOut(reason: 'account_suspended'),
                    child: Text(l10n.suspendedAccountSignOut),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
