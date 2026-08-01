import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

enum ReturnShippingDisplayType { buyer, seller, contractedCarrier }

class ReturnShippingSummaryCard extends StatelessWidget {
  final ReturnShippingDisplayType type;
  final String? carrierCode;
  final bool shipBackContext;

  const ReturnShippingSummaryCard({
    super.key,
    required this.type,
    this.carrierCode,
    this.shipBackContext = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final (accent, background, icon, message) = switch (type) {
      ReturnShippingDisplayType.buyer => (
        colorScheme.error,
        colorScheme.errorContainer,
        Icons.warning_amber_rounded,
        shipBackContext
            ? l10n.returnShippingBuyerShipBackMessage
            : l10n.returnShippingBuyerMessage,
      ),
      ReturnShippingDisplayType.seller => (
        colorScheme.primary,
        colorScheme.primaryContainer,
        Icons.verified_rounded,
        shipBackContext
            ? l10n.returnShippingSellerShipBackMessage
            : l10n.returnShippingSellerMessage,
      ),
      ReturnShippingDisplayType.contractedCarrier => (
        colorScheme.tertiary,
        colorScheme.tertiaryContainer,
        Icons.local_shipping_rounded,
        l10n.returnShippingContractedCarrierMessage,
      ),
    };

    return Semantics(
      container: true,
      label: l10n.returnShippingTitle,
      child: Card(
        margin: EdgeInsets.zero,
        color: background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.returnShippingTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
                    if ((carrierCode ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        l10n.returnShippingCarrierValue(carrierCode!.trim()),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
