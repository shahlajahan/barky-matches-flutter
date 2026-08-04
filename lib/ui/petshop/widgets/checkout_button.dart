import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import 'package:barky_matches_fixed/subscription/models/cart_item.dart';
import 'package:barky_matches_fixed/services/petshop_checkout_service.dart';
import 'package:barky_matches_fixed/ui/petshop/checkout_session_presenter.dart';

import 'package:barky_matches_fixed/services/order_service.dart';

import 'package:firebase_auth/firebase_auth.dart';

class CheckoutButton extends StatefulWidget {
  final List<CartItem> items;

  final Map<String, dynamic>? address;
  final Map<String, dynamic>? billing;
  final Map<String, dynamic>? legal;

  const CheckoutButton({
    super.key,
    required this.items,
    this.address,
    this.billing,
    this.legal,
  });
  @override
  State<CheckoutButton> createState() => _CheckoutButtonState();
}

class _CheckoutButtonState extends State<CheckoutButton> {
  bool _loading = false;
  final _service = PetshopCheckoutService();
  final _orderService = OrderService();

  Future<void> _startCheckout() async {
    debugPrint("🔥 CHECKOUT BUTTON CLICKED");
    if (_loading || widget.items.isEmpty) return;

    setState(() => _loading = true);

    try {
      debugPrint("🏪 ORDER BUSINESS: ${widget.items.first.shopId}");

      debugPrint("🟡 BEFORE createOrder");
      final user = FirebaseAuth.instance.currentUser;

      final orderId = await _orderService
          .createOrder(
            items: widget.items.map((e) => e.toJson()).toList(),
            subtotal: widget.items.fold<double>(
              0,
              (sum, item) => sum + (item.price * item.quantity),
            ),
            kdv: 0,
            shippingTotal: 0,
            grandTotal: widget.items.fold<double>(
              0,
              (sum, item) => sum + (item.price * item.quantity),
            ),
            currency: 'TRY',
            businessId: widget.items.first.shopId,
            address: widget.address ?? {},
            billing: widget.billing ?? {},
            legal: widget.legal ?? {},
            buyerName: user?.displayName ?? '',
            buyerPhone: user?.phoneNumber ?? '',
            buyerEmail: user?.email ?? '',
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception("createOrder TIMEOUT");
            },
          );

      final session = await _service
          .createCheckoutSession(
            orderId: orderId,
            items: widget.items.map((e) => e.toJson()).toList(),
            currency: 'TRY',
            successUrl: 'https://app.petsupo.com/payment-callback',
            cancelUrl: 'https://app.petsupo.com/payment-cancel',
            note: 'Order: $orderId',
            billingAddress: widget.billing ?? widget.address ?? {},
            shippingAddress: widget.address ?? widget.billing ?? {},
            carrier:
                (widget.address?['carrier'] ?? widget.billing?['carrier'] ?? '')
                    .toString(),
            buyer: {"uid": user?.uid, "email": user?.email},
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw Exception("createCheckoutSession timeout");
            },
          );
      if (!mounted) return;

      final result = await presentCheckoutSession(
        context: context,
        session: session,
        orderId: orderId,
        successUrlPrefix: 'https://app.petsupo.com/payment-callback',
        cancelUrlPrefix: 'https://app.petsupo.com/payment-cancel',
      );

      if (!mounted) return;

      if (result == 'verify') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.checkoutPaymentCompletedSuccessfully,
            ),
          ),
        );
      } else if (result == 'isbank_success_redirect') {
        final paymentState = await _service.waitForPaymentConfirmation(orderId);
        if (!mounted) return;

        final paymentStatus =
            paymentState?['paymentStatus']?.toString().trim().toLowerCase() ?? '';
        final orderStatus =
            paymentState?['orderStatus']?.toString().trim().toLowerCase() ?? '';
        final paid = paymentState?['paid'] == true ||
            paymentStatus == 'paid' ||
            orderStatus == 'paid';
        final failed = paymentStatus == 'failed' || orderStatus == 'payment_failed';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paid
                  ? AppLocalizations.of(
                      context,
                    )!.checkoutPaymentCompletedSuccessfully
                  : failed
                      ? AppLocalizations.of(
                          context,
                        )!.checkoutPaymentCancelledOrIncomplete
                  : AppLocalizations.of(context)!.processingLabel,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.checkoutPaymentCancelledOrIncomplete,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.checkoutFailed(e.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading ? null : _startCheckout,
      child: _loading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(AppLocalizations.of(context)!.checkoutProceedToPayment),
    );
  }
}
