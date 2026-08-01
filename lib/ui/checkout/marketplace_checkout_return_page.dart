import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/home_gate.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/petshop_checkout_service.dart';
import 'package:barky_matches_fixed/ui/checkout/checkout_completion_guard.dart';
import 'package:barky_matches_fixed/ui/checkout/multi_order_confirmation_page.dart';
import 'package:barky_matches_fixed/ui/orders/order_detail_page.dart';
import 'package:barky_matches_fixed/ui/petshop/marketplace_checkout_browser.dart';

enum _MarketplaceReturnState { verifying, success, failed, pending }

/// Reached when İş Bank's browser redirect lands back on `app.petsupo.com`
/// for a *marketplace* order (as opposed to a `web_subscription` order,
/// which uses WebSubscriptionReturnPage). Both share the same backend
/// browser-return callback (`isbank3DSuccessReturn`/`isbank3DFailReturn` —
/// see functions/index.js), so main.dart's routing distinguishes them by
/// order-id prefix before either page is ever built. This page uses only
/// the marketplace order's own authoritative status
/// (`readPaymentStatusByOrderId`) — it never trusts the `webSubscriptionReturn`
/// query string by itself, matching the exact reconciliation logic already
/// used by CheckoutPage for the native-WebView path.
class MarketplaceCheckoutReturnPage extends StatefulWidget {
  const MarketplaceCheckoutReturnPage({
    super.key,
    required this.orderId,
    required this.returnKind,
  });

  final String orderId;
  final String returnKind; // 'success' | 'fail'

  @override
  State<MarketplaceCheckoutReturnPage> createState() =>
      _MarketplaceCheckoutReturnPageState();
}

class _MarketplaceCheckoutReturnPageState
    extends State<MarketplaceCheckoutReturnPage> {
  final _checkoutService = PetshopCheckoutService();
  final _completionGuard = CheckoutCompletionGuard();

  _MarketplaceReturnState _state = _MarketplaceReturnState.verifying;
  List<String> _paidSellerOrderIds = const [];
  Timer? _timer;
  int _attempts = 0;
  bool _continuing = false;
  bool _markedFailedOnce = false;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _markFailedOnce(String reason) async {
    if (_markedFailedOnce) return;
    _markedFailedOnce = true;
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable('markMarketplaceCheckoutFailed')
          .call({'orderId': widget.orderId, 'reason': reason});
    } catch (e) {
      debugPrint('⚠️ markMarketplaceCheckoutFailed failed (non-fatal): $e');
    }
  }

  Future<void> _verify() async {
    if (!kIsWeb || widget.orderId.isEmpty) {
      if (mounted) setState(() => _state = _MarketplaceReturnState.failed);
      return;
    }

    // İş Bank's own fail redirect landed here directly — no need to poll
    // backend status first; still record it the same idempotent way
    // CheckoutPage does for the native path ('isbank_cancel').
    if (widget.returnKind == 'fail') {
      await _markFailedOnce('isbank_cancel');
      if (!mounted) return;
      setState(() => _state = _MarketplaceReturnState.failed);
      clearMarketplaceCheckoutReturnQueryParams();
      return;
    }

    try {
      final paymentState = await _checkoutService.readPaymentStatusByOrderId(
        widget.orderId,
      );
      if (!mounted) return;

      final paymentStatus =
          paymentState['paymentStatus']?.toString().trim().toLowerCase() ?? '';
      final orderStatus =
          paymentState['orderStatus']?.toString().trim().toLowerCase() ?? '';
      final paid = paymentState['paid'] == true;
      final failed =
          paymentStatus == 'failed' || orderStatus == 'payment_failed';

      if (paid) {
        final sellerOrderIds = _completionGuard.claimPaidSellerOrders(
          paymentState,
        );
        if (sellerOrderIds.isEmpty) {
          // Paid but the backend hasn't finished cart reconciliation yet —
          // keep polling rather than declaring success prematurely.
          _scheduleRetry();
          return;
        }
        setState(() {
          _paidSellerOrderIds = sellerOrderIds;
          _state = _MarketplaceReturnState.success;
        });
        clearMarketplaceCheckoutReturnQueryParams();
        return;
      }

      if (failed) {
        await _markFailedOnce('isbank_verification_failed');
        if (!mounted) return;
        setState(() => _state = _MarketplaceReturnState.failed);
        clearMarketplaceCheckoutReturnQueryParams();
        return;
      }

      _scheduleRetry();
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (!mounted) return;
    if (_attempts < 12) {
      _attempts++;
      setState(() => _state = _MarketplaceReturnState.pending);
      _timer = Timer(const Duration(seconds: 2), _verify);
    } else {
      setState(() => _state = _MarketplaceReturnState.pending);
      clearMarketplaceCheckoutReturnQueryParams();
    }
  }

  // Root-entry page reached by a full browser redirect — there is no
  // previous Flutter Navigator route to pop back to, matching
  // WebSubscriptionReturnPage's identical constraint.
  Future<void> _handleContinue() async {
    if (_continuing) return;
    setState(() => _continuing = true);
    clearMarketplaceCheckoutReturnQueryParams();
    if (!mounted) return;

    if (_state == _MarketplaceReturnState.success) {
      final destination = _paidSellerOrderIds.length == 1
          ? OrderDetailPage(sellerOrderId: _paidSellerOrderIds.single)
          : MultiOrderConfirmationPage(
              sellerOrderIds: _paidSellerOrderIds,
              sellerNames: List<String?>.filled(
                _paidSellerOrderIds.length,
                null,
              ),
            );
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => destination),
        (route) => false,
      );
      return;
    }

    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (icon, title, color) = switch (_state) {
      _MarketplaceReturnState.verifying => (
        Icons.sync,
        l10n.processingLabel,
        Colors.orange,
      ),
      _MarketplaceReturnState.success => (
        Icons.check_circle,
        l10n.checkoutPaymentCompletedSuccessfully,
        Colors.green,
      ),
      _MarketplaceReturnState.failed => (
        Icons.error,
        l10n.checkoutPaymentCancelledOrIncomplete,
        Colors.red,
      ),
      _MarketplaceReturnState.pending => (
        Icons.hourglass_top,
        l10n.processingLabel,
        Colors.orange,
      ),
    };
    final showContinue =
        _state == _MarketplaceReturnState.success ||
        _state == _MarketplaceReturnState.failed;

    return Scaffold(
      backgroundColor: const Color(0xFF120914),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_state == _MarketplaceReturnState.verifying ||
                      _state == _MarketplaceReturnState.pending)
                    CircularProgressIndicator(color: color)
                  else
                    Icon(icon, color: color, size: 64),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (showContinue) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _continuing ? null : _handleContinue,
                      child: _continuing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.continueLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
