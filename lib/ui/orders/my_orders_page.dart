import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/orders/buyer_order_list_item.dart';
import 'package:barky_matches_fixed/ui/orders/buyer_orders_repository.dart';
import 'package:barky_matches_fixed/ui/orders/order_detail_page.dart';
import 'package:barky_matches_fixed/utils/carrier_mapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({
    super.key,
    this.repository,
    this.buyerUid,
    this.focusRootOrderId,
  });

  final BuyerOrdersDataSource? repository;
  final String? buyerUid;
  final String? focusRootOrderId;

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  late final BuyerOrdersDataSource _repository;
  late final String? _buyerUid;
  Stream<List<BuyerOrderListItem>>? _ordersStream;
  BuyerOrderSort _sort = BuyerOrderSort.newest;
  BuyerOrderStatusFilter _statusFilter = BuyerOrderStatusFilter.all;
  String? _focusedRootOrderId;
  String? _focusedReturnId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BuyerOrdersRepository();
    _buyerUid = widget.buyerUid ?? FirebaseAuth.instance.currentUser?.uid;
    _focusedRootOrderId = _normalizeId(widget.focusRootOrderId);
    if (_buyerUid case final buyerUid?) {
      _ordersStream = _repository
          .watchBuyerOrders(buyerUid)
          .asBroadcastStream();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = context.read<AppState?>();
    final pendingRootOrderId = appState?.takePendingBuyerOrdersRootOrderId();
    if (pendingRootOrderId != null && pendingRootOrderId.trim().isNotEmpty) {
      _focusedRootOrderId = pendingRootOrderId.trim();
      _statusFilter = BuyerOrderStatusFilter.all;
    }
    final pendingReturnId = appState?.takePendingBuyerOrdersReturnId();
    if (pendingReturnId != null && pendingReturnId.trim().isNotEmpty) {
      _focusedReturnId = pendingReturnId.trim();
    }
  }

  @override
  void didUpdateWidget(covariant MyOrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextFocus = _normalizeId(widget.focusRootOrderId);
    if (nextFocus != null && nextFocus != _focusedRootOrderId) {
      _focusedRootOrderId = nextFocus;
      _statusFilter = BuyerOrderStatusFilter.all;
    }
  }

  Future<void> _refresh() async {
    final buyerUid = _buyerUid;
    if (buyerUid == null) return;
    final refreshed = _repository
        .watchBuyerOrders(buyerUid)
        .asBroadcastStream();
    setState(() => _ordersStream = refreshed);
    await refreshed.first.timeout(
      const Duration(seconds: 10),
      onTimeout: () => const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_buyerUid == null || _ordersStream == null) {
      return Center(child: Text(l10n.myOrdersLoginRequired));
    }

    return ColoredBox(
      color: const Color(0xFFFDF2F5),
      child: StreamBuilder<List<BuyerOrderListItem>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (_focusedRootOrderId != null) {
              return const _FocusedOrderUnavailableView();
            }
            return Center(
              child: Text(l10n.errorOccurred(snapshot.error.toString())),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = presentBuyerOrders(
            snapshot.data!,
            sort: _sort,
            statusFilter: _statusFilter,
          );
          final focusedRootOrderId = _focusedRootOrderId;
          final focusedOrderFound =
              focusedRootOrderId != null &&
              snapshot.data!.any(
                (order) => order.rootOrderId == focusedRootOrderId,
              );
          final visibleOrders = focusedRootOrderId == null
              ? orders
              : _focusRootOrderFirst(orders, focusedRootOrderId);
          return Column(
            children: [
              if (focusedRootOrderId != null && !focusedOrderFound)
                const _OrderFocusUnavailableBanner(),
              _OrderControls(
                sort: _sort,
                statusFilter: _statusFilter,
                onSortChanged: (sort) => setState(() => _sort = sort),
                onStatusChanged: (filter) =>
                    setState(() => _statusFilter = filter),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: visibleOrders.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 160),
                            Center(
                              child: Text(
                                snapshot.data!.isEmpty
                                    ? l10n.noOrdersYet
                                    : l10n.noMatchingOrders,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          key: const Key('buyer-orders-list'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                          itemCount: visibleOrders.length,
                          itemBuilder: (context, index) => BuyerOrderCard(
                            key: Key(
                              'buyer-order-${visibleOrders[index].sellerOrderId}',
                            ),
                            order: visibleOrders[index],
                            highlighted:
                                focusedRootOrderId != null &&
                                visibleOrders[index].rootOrderId ==
                                    focusedRootOrderId,
                            onTap: visibleOrders[index].canOpenDetail
                                ? () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => OrderDetailPage(
                                          sellerOrderId: visibleOrders[index]
                                              .sellerOrderId,
                                          returnId: _focusedReturnId,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String? _normalizeId(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

List<BuyerOrderListItem> _focusRootOrderFirst(
  List<BuyerOrderListItem> orders,
  String rootOrderId,
) {
  final focused = <BuyerOrderListItem>[];
  final rest = <BuyerOrderListItem>[];
  for (final order in orders) {
    if (order.rootOrderId == rootOrderId) {
      focused.add(order);
    } else {
      rest.add(order);
    }
  }
  return [...focused, ...rest];
}

class _OrderFocusUnavailableBanner extends StatelessWidget {
  const _OrderFocusUnavailableBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('buyer-order-focus-unavailable'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: const Text(
        'Order not found or unavailable.',
        style: TextStyle(color: Color(0xFF6D4C00), fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FocusedOrderUnavailableView extends StatelessWidget {
  const _FocusedOrderUnavailableView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _OrderFocusUnavailableBanner(),
        Expanded(child: Center(child: Text('Order not found or unavailable.'))),
      ],
    );
  }
}

class _OrderControls extends StatelessWidget {
  const _OrderControls({
    required this.sort,
    required this.statusFilter,
    required this.onSortChanged,
    required this.onStatusChanged,
  });

  final BuyerOrderSort sort;
  final BuyerOrderStatusFilter statusFilter;
  final ValueChanged<BuyerOrderSort> onSortChanged;
  final ValueChanged<BuyerOrderStatusFilter> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<BuyerOrderSort>(
              key: const Key('buyer-order-sort'),
              initialValue: sort,
              onSelected: onSortChanged,
              itemBuilder: (context) => [
                for (final option in BuyerOrderSort.values)
                  PopupMenuItem(
                    value: option,
                    child: Text(_sortLabel(option, l10n)),
                  ),
              ],
              child: _ControlChip(
                icon: Icons.sort,
                label: _sortLabel(sort, l10n),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PopupMenuButton<BuyerOrderStatusFilter>(
              key: const Key('buyer-order-filter'),
              initialValue: statusFilter,
              onSelected: onStatusChanged,
              itemBuilder: (context) => [
                for (final option in BuyerOrderStatusFilter.values)
                  PopupMenuItem(
                    value: option,
                    child: Text(_filterLabel(option, l10n)),
                  ),
              ],
              child: _ControlChip(
                icon: Icons.filter_list,
                label: _filterLabel(statusFilter, l10n),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  const _ControlChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    );
  }
}

class BuyerOrderCard extends StatelessWidget {
  const BuyerOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.highlighted = false,
  });

  final BuyerOrderListItem order;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusColor = _statusColor(order.status);
    final productTitle = order.primaryProductName?.trim().isNotEmpty == true
        ? order.primaryProductName!.trim()
        : l10n.myOrdersUnknownProduct;
    final title = order.additionalItemCount > 0
        ? l10n.myOrdersProductAndMore(productTitle, order.additionalItemCount)
        : productTitle;
    final orderNumber = order.orderNumber?.trim().isNotEmpty == true
        ? order.orderNumber!.trim()
        : l10n.myOrdersOrderNumberUnavailable;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: highlighted
              ? const Color(0xFFE91E63)
              : const Color(0xFFEDE7EA),
          width: highlighted ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OrderThumbnail(imageUrl: order.productImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.sellerName?.trim().isNotEmpty == true
                          ? order.sellerName!.trim()
                          : l10n.myOrdersUnknownSeller,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          order.createdAt == null
                              ? l10n.myOrdersDateUnavailable
                              : MaterialLocalizations.of(
                                  context,
                                ).formatMediumDate(order.createdAt!),
                          style: _metadataStyle,
                        ),
                        Text(
                          l10n.orderNumberLabel(orderNumber),
                          style: _metadataStyle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            buyerOrderStatusLabel(order.status, l10n),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _amount(order.total, order.currency),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    if (order.carrier != null ||
                        order.trackingNumber != null) ...[
                      const Divider(height: 20),
                      Text(
                        _shippingSummary(order, l10n),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _metadataStyle,
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

  static const _metadataStyle = TextStyle(color: Colors.black54, fontSize: 12);
}

class _OrderThumbnail extends StatelessWidget {
  const _OrderThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 64,
      height: 64,
      color: const Color(0xFFF5EEF1),
      alignment: Alignment.center,
      child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF9E1B4F)),
    );
    final url = imageUrl?.trim() ?? '';
    if (url.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: fallback,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

String buyerOrderStatusLabel(String status, AppLocalizations l10n) {
  return switch (normalizeBuyerOrderStatus(status)) {
    'pending' => l10n.pendingStatusLabel,
    'paid' => l10n.paidStatusLabel,
    'processing' => l10n.myOrdersProcessingStatus,
    'preparing' => l10n.preparingStatusLabel,
    'shipped' => l10n.shippedStatusLabel,
    'delivered' => l10n.deliveredStatusLabel,
    'cancelled' => l10n.cancelledStatusLabel,
    'failed' => l10n.failedStatusLabel,
    'refunded' => l10n.myOrdersRefundedStatus,
    'returned' => l10n.myOrdersReturnedStatus,
    final value => value,
  };
}

String _sortLabel(BuyerOrderSort sort, AppLocalizations l10n) {
  return switch (sort) {
    BuyerOrderSort.newest => l10n.myOrdersSortNewest,
    BuyerOrderSort.oldest => l10n.myOrdersSortOldest,
    BuyerOrderSort.productAscending => l10n.myOrdersSortProductAz,
    BuyerOrderSort.productDescending => l10n.myOrdersSortProductZa,
    BuyerOrderSort.sellerAscending => l10n.myOrdersSortSellerAz,
    BuyerOrderSort.sellerDescending => l10n.myOrdersSortSellerZa,
    BuyerOrderSort.amountDescending => l10n.myOrdersSortAmountHigh,
    BuyerOrderSort.amountAscending => l10n.myOrdersSortAmountLow,
  };
}

String _filterLabel(BuyerOrderStatusFilter filter, AppLocalizations l10n) {
  return switch (filter) {
    BuyerOrderStatusFilter.all => l10n.allFilterLabel,
    BuyerOrderStatusFilter.pending => l10n.pendingStatusLabel,
    BuyerOrderStatusFilter.paid => l10n.paidStatusLabel,
    BuyerOrderStatusFilter.processing => l10n.myOrdersProcessingStatus,
    BuyerOrderStatusFilter.shipped => l10n.shippedStatusLabel,
    BuyerOrderStatusFilter.delivered => l10n.deliveredStatusLabel,
    BuyerOrderStatusFilter.cancelled => l10n.cancelledStatusLabel,
    BuyerOrderStatusFilter.failed => l10n.failedStatusLabel,
    BuyerOrderStatusFilter.refundedOrReturned =>
      l10n.myOrdersRefundedOrReturnedStatus,
  };
}

String _amount(double amount, String currency) {
  final symbol = currency.toUpperCase() == 'TRY' ? '₺' : currency.toUpperCase();
  return '${amount.toStringAsFixed(2)} $symbol';
}

String _shippingSummary(BuyerOrderListItem order, AppLocalizations l10n) {
  final parts = <String>[];
  if (order.carrier case final carrier?) {
    parts.add(l10n.carrierLabel(CarrierMapper.toDisplay(carrier)));
  }
  if (order.trackingNumber case final tracking?) {
    parts.add(l10n.trackingLabel(tracking));
  }
  return parts.join(' • ');
}

Color _statusColor(String status) {
  return switch (normalizeBuyerOrderStatus(status)) {
    'paid' || 'delivered' => Colors.green,
    'pending' => Colors.orange,
    'processing' || 'preparing' => Colors.deepOrange,
    'shipped' => Colors.blue,
    'cancelled' || 'failed' => Colors.red,
    'refunded' || 'returned' => Colors.purple,
    _ => Colors.grey,
  };
}
