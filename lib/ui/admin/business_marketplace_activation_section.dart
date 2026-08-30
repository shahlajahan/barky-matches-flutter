import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'admin_section.dart';

// Marketplace P1-A Step 21c2 (docs/plans/marketplace_p1a_compliance_
// review_implementation_plan_2026-08-21.md §10.1 "Admin UI boundary,
// exact", §13.1; closing-audit correction). The admin-only control
// surface for `marketplaceSellerActivation` — a dedicated section,
// deliberately not folded into `BusinessAdminActions`, since that
// widget's own structure is a `status`-switch tied to the
// business-approval workflow, a concept this gate is explicitly
// independent of.
//
// The `MarketplaceSellerActivationApi` abstraction/injection seam below
// mirrors `pet_taxi_admin_review_panel.dart`'s own already-established
// `PetTaxiAdminApprovalApi` pattern exactly — `HttpsCallable` itself has
// a private constructor and cannot be faked directly, so this is the
// same, already-precedented way this codebase makes an admin callable
// widget testable without touching production behavior.
//
// This widget deliberately does NOT read `AppState` for admin status
// itself — it takes `isAdmin` as a required, explicit constructor
// parameter, with its real caller (`BusinessAdminDetailPage`) supplying
// the value from the already-existing, unmodified `AppState.isAdmin`
// getter at the call site. This keeps the widget's own authorization
// input fully deterministic for tests without requiring any change to
// the shared, application-wide `AppState` class.
//
// This widget NEVER writes `marketplaceSellerActivation` directly —
// only the two authorized callables below may ever do so; a direct
// Firestore client-SDK write of any kind is denied by
// `firestore.rules`'s own protected-key list regardless.

abstract class MarketplaceSellerActivationApi {
  Future<void> grant(String businessId);
  Future<void> revoke(String businessId);
}

class FirebaseMarketplaceSellerActivationApi
    implements MarketplaceSellerActivationApi {
  HttpsCallable _callable(String name) =>
      FirebaseFunctions.instanceFor(region: 'europe-west3').httpsCallable(name);

  @override
  Future<void> grant(String businessId) async {
    await _callable('grantMarketplaceSellerActivation').call({
      'businessId': businessId,
    });
  }

  @override
  Future<void> revoke(String businessId) async {
    await _callable('revokeMarketplaceSellerActivation').call({
      'businessId': businessId,
    });
  }
}

class BusinessMarketplaceActivationSection extends StatefulWidget {
  final Map<String, dynamic> data;
  final String businessId;
  final bool isAdmin;
  final MarketplaceSellerActivationApi? api;

  const BusinessMarketplaceActivationSection({
    super.key,
    required this.data,
    required this.businessId,
    required this.isAdmin,
    this.api,
  });

  @override
  State<BusinessMarketplaceActivationSection> createState() =>
      _BusinessMarketplaceActivationSectionState();
}

class _BusinessMarketplaceActivationSectionState
    extends State<BusinessMarketplaceActivationSection> {
  bool _isLoading = false;

  MarketplaceSellerActivationApi get _api =>
      widget.api ?? FirebaseMarketplaceSellerActivationApi();

  bool get _isActive {
    final activation = widget.data['marketplaceSellerActivation'];
    return activation is Map && activation['active'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Non-admin users must never see or be able to invoke these
    // controls, at the widget level, independent of and in addition to
    // the Rules-layer/callable-layer `requireAdmin()`-class
    // authorization already required (§10.1 "Admin UI boundary,
    // exact"). `isAdmin` is supplied by the real caller from the
    // already-existing `AppState.isAdmin` getter — this widget never
    // derives admin authority from any test-only or otherwise
    // non-production state.
    if (!widget.isAdmin) {
      return const SizedBox.shrink();
    }

    final active = _isActive;

    return AdminSection(
      title: l10n.marketplaceSellerActivationSectionTitle,
      icon: Icons.storefront_outlined,
      accentColor: active ? Colors.green : Colors.grey,
      isLoading: _isLoading,
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle : Icons.cancel,
            color: active ? Colors.green : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              active
                  ? l10n.marketplaceSellerActivationStatusActive
                  : l10n.marketplaceSellerActivationStatusInactive,
            ),
          ),
          if (active)
            OutlinedButton(
              onPressed: _isLoading ? null : _handleRevoke,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: Text(l10n.marketplaceSellerActivationRevokeAction),
            )
          else
            ElevatedButton(
              onPressed: _isLoading ? null : _handleGrant,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(l10n.marketplaceSellerActivationGrantAction),
            ),
        ],
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmText,
    required Color confirmColor,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleGrant() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirm(
      title: l10n.marketplaceSellerActivationGrantConfirmTitle,
      message: l10n.marketplaceSellerActivationGrantConfirmMessage,
      confirmText: l10n.marketplaceSellerActivationGrantAction,
      confirmColor: Colors.green,
    );
    if (!confirmed || !mounted) return;

    // In-flight guard — a duplicate tap while the first call is still
    // pending results in exactly one callable invocation, never two.
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _api.grant(widget.businessId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.marketplaceSellerActivationGrantSucceeded),
          ),
        );
      }
    } catch (e) {
      _showError(e);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleRevoke() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await _confirm(
      title: l10n.marketplaceSellerActivationRevokeConfirmTitle,
      message: l10n.marketplaceSellerActivationRevokeConfirmMessage,
      confirmText: l10n.marketplaceSellerActivationRevokeAction,
      confirmColor: Colors.red,
    );
    if (!confirmed || !mounted) return;

    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _api.revoke(widget.businessId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.marketplaceSellerActivationRevokeSucceeded),
          ),
        );
      }
    } catch (e) {
      _showError(e);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(Object e) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final message = _messageForError(e, l10n);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _messageForError(Object e, AppLocalizations l10n) {
    if (e is FirebaseFunctionsException) {
      return switch (e.code) {
        'permission-denied' || 'unauthenticated' =>
          l10n.marketplaceSellerActivationPermissionDenied,
        'not-found' => l10n.marketplaceSellerActivationBusinessNotFound,
        'unavailable' || 'deadline-exceeded' =>
          l10n.marketplaceSellerActivationNetworkError,
        _ => l10n.marketplaceSellerActivationGeneralError,
      };
    }
    return l10n.marketplaceSellerActivationGeneralError;
  }
}
