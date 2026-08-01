import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:barky_matches_fixed/subscription/models/cart_item.dart';
import 'package:barky_matches_fixed/ui/checkout/checkout_completion_guard.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed payment leaves basket untouched', () {
    final appState = _buildAppState();
    addCartQuantity(appState, productId: 'purchased', quantity: 2);
    final guard = CheckoutCompletionGuard();

    final sellerOrderIds = guard.claimPaidSellerOrders(<String, dynamic>{
      'paid': false,
      'cartReconciled': false,
      'sellerOrderIds': ['seller-order-1'],
    });
    if (sellerOrderIds.isNotEmpty) {
      appState.removePurchasedCartItems([cartItem('purchased', 1)]);
    }

    expect(appState.cartItems.single.quantity, 2);
    appState.dispose();
  });

  test('paid payment removes purchased quantity and preserves new items', () {
    final appState = _buildAppState();
    addCartQuantity(appState, productId: 'purchased', quantity: 3);
    addCartQuantity(appState, productId: 'new-item', quantity: 1);
    final purchasedSnapshot = [cartItem('purchased', 2)];
    final guard = CheckoutCompletionGuard();
    final paidState = <String, dynamic>{
      'paid': true,
      'cartReconciled': true,
      'sellerOrderIds': ['seller-order-1'],
    };

    if (guard.claimPaidSellerOrders(paidState).isNotEmpty) {
      appState.removePurchasedCartItems(purchasedSnapshot);
    }
    if (guard.claimPaidSellerOrders(paidState).isNotEmpty) {
      appState.removePurchasedCartItems(purchasedSnapshot);
    }

    expect(
      appState.cartItems
          .singleWhere((item) => item.productId == 'purchased')
          .quantity,
      1,
    );
    expect(
      appState.cartItems.singleWhere((item) => item.productId == 'new-item'),
      isNotNull,
    );
    appState.dispose();
  });
}

AppState _buildAppState() {
  return AppState(
    favoriteDogs: <Dog>[],
    favoriteDogsNotifier: ValueNotifier<List<Dog>>(<Dog>[]),
    likesNotifier: ValueNotifier<Map<String, List<String>>>(
      <String, List<String>>{},
    ),
    onToggleFavorite: (_) async {},
    notificationService: NotificationService(),
    currentUserId: 'buyer-1',
  );
}

void addCartQuantity(
  AppState appState, {
  required String productId,
  required int quantity,
}) {
  for (var index = 0; index < quantity; index++) {
    appState.addToCart(cartItem(productId, 1));
  }
}

CartItem cartItem(String productId, int quantity) {
  return CartItem(
    productId: productId,
    shopId: 'shop-1',
    name: productId,
    price: 10,
    quantity: quantity,
    product: Product.empty(productId),
  );
}
