import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import '../../app_state.dart';
import '../../subscription/models/cart_item.dart';
//import 'package:barky_matches_fixed/ui/petshop/widgets/checkout_button.dart';
import 'package:barky_matches_fixed/ui/checkout/checkout_page.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final items = appState.cartItems;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cartTitle)),
      body: items.isEmpty
          ? Center(child: Text(l10n.cartIsEmpty))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return _CartItemTile(item: item);
                    },
                  ),
                ),

                _CartSummary(),
              ],
            ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;

  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (item.imageUrl != null)
              Image.network(
                item.imageUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text("${item.price} ₺"),

                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (item.quantity > 1) {
                            appState.updateCartQuantity(
                              item.productId,
                              item.quantity - 1,
                            );
                          }
                        },
                        icon: const Icon(Icons.remove),
                      ),

                      Text(item.quantity.toString()),

                      IconButton(
                        onPressed: () {
                          appState.updateCartQuantity(
                            item.productId,
                            item.quantity + 1,
                          );
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            IconButton(
              onPressed: () {
                appState.removeFromCart(item.productId);
              },
              icon: const Icon(Icons.delete, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.totalLabel),
              Text("${appState.cartTotal.toStringAsFixed(2)} ₺"),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final appState = context.read<AppState>();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutPage(items: appState.cartItems),
                  ),
                );
              },
              child: Text(l10n.checkoutButton),
            ),
          ),
        ],
      ),
    );
  }
}
