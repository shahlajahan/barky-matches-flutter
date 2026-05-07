import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/subscription/models/cart_item.dart';
import 'package:barky_matches_fixed/services/petshop_checkout_service.dart';

import 'package:barky_matches_fixed/services/order_service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:barky_matches_fixed/ui/petshop/petshop_checkout_webview_page.dart';

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

final orderId = await _orderService
    .createOrder(
      items: widget.items.map((e) => e.toJson()).toList(),
      totalPrice: widget.items.fold<double>(
        0,
        (sum, item) => sum + (item.price * item.quantity),
      ),
      currency: 'TRY',
      businessId: widget.items.first.shopId,
      address: widget.address ?? {},
      billing: widget.billing ?? {},
      legal: widget.legal ?? {},
    )
    .timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw Exception("createOrder TIMEOUT");
      },
    );

debugPrint("🟢 AFTER createOrder → orderId: $orderId");

    for (final item in widget.items) {
      debugPrint("🔥 ITEM JSON → ${item.toJson()}");
    }

    final user = FirebaseAuth.instance.currentUser;
debugPrint("🚀 CALLING CHECKOUT SESSION...");
debugPrint("🔥 FINAL BUYER: $buyer");

final session = await _service.createCheckoutSession(
      items: widget.items.map((e) => e.toJson()).toList(),
      currency: 'TRY',
      successUrl: 'https://barkymatches.app/payment-success',
      cancelUrl: 'https://barkymatches.app/payment-cancel',
      note: 'Order: $orderId',
      billingAddress: widget.billing ?? widget.address ?? {},
      shippingAddress: widget.address ?? widget.billing ?? {},
      buyer: {
        "uid": user?.uid,
        "email": user?.email,
      },
    )
    .timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        throw Exception("createCheckoutSession timeout");
      },
    );
debugPrint("✅ SESSION RECEIVED: ${session.checkoutUrl}");
    if (!mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PetshopCheckoutWebViewPage(
          checkoutUrl: session.checkoutUrl,
          successUrlPrefix: 'https://barkymatches.app/payment-success',
          cancelUrlPrefix: 'https://barkymatches.app/payment-cancel',
          orderId: orderId,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment completed successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment was cancelled or not completed')),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Checkout failed: $e')),
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
          : const Text('Proceed to Payment'),
    );
  }
}