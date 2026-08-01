import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/home_gate.dart';
import 'package:barky_matches_fixed/ui/orders/order_detail_page.dart';
import 'package:flutter/material.dart';

class MultiOrderConfirmationPage extends StatefulWidget {
  const MultiOrderConfirmationPage({
    super.key,
    required this.sellerOrderIds,
    required this.sellerNames,
  }) : assert(sellerOrderIds.length > 1),
       assert(sellerNames.length == sellerOrderIds.length);

  final List<String> sellerOrderIds;
  final List<String?> sellerNames;

  @override
  State<MultiOrderConfirmationPage> createState() =>
      _MultiOrderConfirmationPageState();
}

class _MultiOrderConfirmationPageState
    extends State<MultiOrderConfirmationPage> {
  bool _navigating = false;

  Future<void> _openOrder(String sellerOrderId) async {
    if (_navigating) return;
    setState(() => _navigating = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailPage(sellerOrderId: sellerOrderId),
      ),
    );
    if (mounted) setState(() => _navigating = false);
  }

  void _exit() {
    if (_navigating) return;
    _navigating = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomeGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.check_circle, size: 72, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    l10n.checkoutMultiOrderSuccessTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.checkoutMultiOrderSuccessBody,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  for (
                    var index = 0;
                    index < widget.sellerOrderIds.length;
                    index++
                  )
                    Card(
                      key: Key('seller-order-${widget.sellerOrderIds[index]}'),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(
                          widget.sellerNames[index]?.trim().isNotEmpty == true
                              ? widget.sellerNames[index]!.trim()
                              : l10n.checkoutSellerOrderLabel(index + 1),
                        ),
                        subtitle: Text(widget.sellerOrderIds[index]),
                        trailing: TextButton(
                          onPressed: _navigating
                              ? null
                              : () => _openOrder(widget.sellerOrderIds[index]),
                          child: Text(l10n.checkoutOpenOrder),
                        ),
                        onTap: _navigating
                            ? null
                            : () => _openOrder(widget.sellerOrderIds[index]),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const Key('multi-order-exit'),
                    onPressed: _navigating ? null : _exit,
                    child: Text(l10n.checkoutMultiOrderExit),
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
