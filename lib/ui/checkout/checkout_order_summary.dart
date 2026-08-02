import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/subscription/models/cart_item.dart';
import 'package:barky_matches_fixed/utils/carrier_mapper.dart';
import 'package:flutter/material.dart';

class CheckoutSellerGroup {
  const CheckoutSellerGroup({
    required this.shopId,
    required this.items,
    required this.sellerName,
  });

  final String shopId;
  final List<CartItem> items;
  final String? sellerName;

  double get productsTotal =>
      items.fold(0, (total, item) => total + item.price * item.quantity);

  List<String> get availableCarriers {
    final carrierSets = items
        .map(
          (item) => item.product.allowedCarrierCodes
              .map((carrier) => carrier.trim().toUpperCase())
              .where((carrier) => carrier.isNotEmpty)
              .toSet(),
        )
        .where((carriers) => carriers.isNotEmpty)
        .toList();
    if (carrierSets.isEmpty) return const [];
    return carrierSets
        .skip(1)
        .fold<Set<String>>(
          Set<String>.from(carrierSets.first),
          (common, carriers) => common.intersection(carriers),
        )
        .toList(growable: false);
  }

  bool get requiresCarrier =>
      items.any((item) => item.product.requiresCarrierEstimate);

  int? get estimatedDeliveryDays {
    final estimates = items
        .map((item) => item.product.maxDeliveryDays)
        .whereType<int>()
        .toList();
    if (estimates.isEmpty) return null;
    return estimates.reduce(
      (current, value) => current > value ? current : value,
    );
  }
}

class SellerCheckoutPricing {
  const SellerCheckoutPricing({
    required this.productsTotal,
    required this.shippingTotal,
    required this.taxTotal,
    required this.grandTotal,
  });

  final double productsTotal;
  final double shippingTotal;
  final double taxTotal;
  final double grandTotal;

  double get sellerTotal => grandTotal;

  factory SellerCheckoutPricing.fromBackend(
    Map<String, dynamic> pricing, {
    required double fallbackProductsTotal,
  }) {
    final productsTotal = _asDouble(
      pricing['subtotal'],
      fallback: fallbackProductsTotal,
    );
    final shippingTotal = _asDouble(pricing['shippingTotal']);
    return SellerCheckoutPricing(
      productsTotal: productsTotal,
      shippingTotal: shippingTotal,
      taxTotal: _asDouble(pricing['taxTotal']),
      grandTotal: _asDouble(
        pricing['grandTotal'],
        fallback:
            productsTotal + shippingTotal + _asDouble(pricing['taxTotal']),
      ),
    );
  }

  static double _asDouble(Object? value, {double fallback = 0}) =>
      value is num ? value.toDouble() : fallback;
}

class CheckoutPricingTotals {
  const CheckoutPricingTotals({
    required this.productsTotal,
    required this.shippingTotal,
    required this.taxTotal,
    required this.grandTotal,
  });

  final double productsTotal;
  final double shippingTotal;
  final double taxTotal;
  final double grandTotal;

  factory CheckoutPricingTotals.fromSellerPricing(
    Iterable<SellerCheckoutPricing> sellerPricing,
  ) {
    return CheckoutPricingTotals(
      productsTotal: sellerPricing.fold(
        0,
        (total, pricing) => total + pricing.productsTotal,
      ),
      shippingTotal: sellerPricing.fold(
        0,
        (total, pricing) => total + pricing.shippingTotal,
      ),
      taxTotal: sellerPricing.fold(
        0,
        (total, pricing) => total + pricing.taxTotal,
      ),
      grandTotal: sellerPricing.fold(
        0,
        (total, pricing) => total + pricing.grandTotal,
      ),
    );
  }
}

List<CheckoutSellerGroup> groupCheckoutItemsBySeller(List<CartItem> items) {
  final groupedItems = <String, List<CartItem>>{};
  for (final item in items) {
    groupedItems.putIfAbsent(item.shopId, () => []).add(item);
  }

  return [
    for (final entry in groupedItems.entries)
      CheckoutSellerGroup(
        shopId: entry.key,
        items: List.unmodifiable(entry.value),
        sellerName: _sellerName(entry.value),
      ),
  ];
}

String? _sellerName(List<CartItem> items) {
  for (final field in const [
    'businessName',
    'displayName',
    'sellerBusinessName',
    'shopName',
  ]) {
    for (final item in items) {
      final productData = item.product.toJson();
      final candidate = field == 'businessName'
          ? item.product.businessName
          : productData[field]?.toString();
      final normalized = candidate?.trim() ?? '';
      if (normalized.isNotEmpty) return normalized;
    }
  }
  return null;
}

class CheckoutOrderSummary extends StatelessWidget {
  const CheckoutOrderSummary({
    super.key,
    required this.groups,
    required this.selectedCarriers,
    required this.pricingByShop,
    required this.pricingLoading,
    required this.onCarrierChanged,
  });

  final List<CheckoutSellerGroup> groups;
  final Map<String, String?> selectedCarriers;
  final Map<String, SellerCheckoutPricing> pricingByShop;
  final bool pricingLoading;
  final void Function(String shopId, String carrier) onCarrierChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('checkout-seller-order-sections'),
      children: [
        for (var groupIndex = 0; groupIndex < groups.length; groupIndex++)
          SellerCheckoutSection(
            group: groups[groupIndex],
            index: groupIndex,
            selectedCarrier: selectedCarriers[groups[groupIndex].shopId],
            pricing: pricingByShop[groups[groupIndex].shopId],
            pricingLoading: pricingLoading,
            onCarrierChanged: (carrier) =>
                onCarrierChanged(groups[groupIndex].shopId, carrier),
          ),
      ],
    );
  }
}

class SellerCheckoutSection extends StatelessWidget {
  const SellerCheckoutSection({
    super.key,
    required this.group,
    required this.index,
    required this.selectedCarrier,
    required this.pricing,
    required this.pricingLoading,
    required this.onCarrierChanged,
  });

  final CheckoutSellerGroup group;
  final int index;
  final String? selectedCarrier;
  final SellerCheckoutPricing? pricing;
  final bool pricingLoading;
  final ValueChanged<String> onCarrierChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sellerName =
        group.sellerName ?? l10n.checkoutSellerFallback(index + 1);
    final productsTotal = pricing?.productsTotal ?? group.productsTotal;
    final shippingTotal = pricing?.shippingTotal ?? 0;

    return Container(
      key: Key('checkout-seller-${group.shopId}'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.checkoutSellerSection(sellerName),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 14),
          for (
            var itemIndex = 0;
            itemIndex < group.items.length;
            itemIndex++
          ) ...[
            _CheckoutItemRow(item: group.items[itemIndex]),
            if (itemIndex != group.items.length - 1) const Divider(height: 18),
          ],
          const Divider(height: 24),
          _ShippingMethodField(
            group: group,
            selectedCarrier: selectedCarrier,
            onChanged: onCarrierChanged,
          ),
          const SizedBox(height: 12),
          _AmountRow(label: l10n.checkoutProductsTotal, amount: productsTotal),
          const SizedBox(height: 6),
          _AmountRow(
            key: Key('seller-shipping-${group.shopId}'),
            label: l10n.checkoutShippingCost,
            amount: shippingTotal,
            loading: pricingLoading && pricing == null,
          ),
          _AmountRow(
            key: Key('seller-tax-${group.shopId}'),
            label: l10n.checkoutVatLabel,
            amount: pricing?.taxTotal ?? 0,
            loading: pricingLoading && pricing == null,
          ),
          if (group.estimatedDeliveryDays case final days?) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: Colors.black54,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.checkoutEstimatedDelivery)),
                Text(l10n.daysLabel(days)),
              ],
            ),
          ],
          const Divider(height: 24),
          _AmountRow(
            key: Key('seller-total-${group.shopId}'),
            label: l10n.checkoutSellerTotal,
            amount: pricing?.grandTotal ?? productsTotal + shippingTotal,
            emphasize: true,
            loading: pricingLoading && pricing == null,
          ),
        ],
      ),
    );
  }
}

class MultiSellerCheckoutInfoCard extends StatelessWidget {
  const MultiSellerCheckoutInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      key: const Key('multi-seller-checkout-info'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.checkoutMultiSellerInfoTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(l10n.checkoutMultiSellerInfoBody),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShippingMethodField extends StatelessWidget {
  const _ShippingMethodField({
    required this.group,
    required this.selectedCarrier,
    required this.onChanged,
  });

  final CheckoutSellerGroup group;
  final String? selectedCarrier;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final carriers = group.availableCarriers;
    final deliveryType = group.items.first.product.deliveryType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.checkoutShippingMethod,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (carriers.isNotEmpty)
          DropdownButtonFormField<String>(
            key: Key('seller-carrier-${group.shopId}'),
            initialValue: selectedCarrier ?? carriers.first,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final carrier in carriers)
                DropdownMenuItem(
                  value: carrier,
                  child: Text(_carrierLabel(l10n, carrier)),
                ),
            ],
            onChanged: (carrier) {
              if (carrier != null) onChanged(carrier);
            },
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              deliveryType == 'pickup'
                  ? l10n.pickupLabel
                  : l10n.checkoutDeliveryTitle,
            ),
          ),
      ],
    );
  }

  String _carrierLabel(AppLocalizations l10n, String carrier) {
    if (carrier == 'PICKUP') return l10n.pickupLabel;
    return CarrierMapper.toDisplay(carrier);
  }
}

class _CheckoutItemRow extends StatelessWidget {
  const _CheckoutItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (item.imageUrl?.isNotEmpty == true) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              item.imageUrl!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.quantity} × ${item.price.toStringAsFixed(2)} ₺',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(item.price * item.quantity).toStringAsFixed(2)} ₺',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    super.key,
    required this.label,
    required this.amount,
    this.emphasize = false,
    this.loading = false,
  });

  final String label;
  final double amount;
  final bool emphasize;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.normal,
      color: emphasize ? const Color(0xFF9E1B4F) : Colors.black87,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        if (loading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Text('${amount.toStringAsFixed(2)} ₺', style: style),
      ],
    );
  }
}
