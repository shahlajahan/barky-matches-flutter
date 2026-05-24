import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/orders/order_detail_page.dart';

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return Scaffold(
        body: Center(child: Text(l10n.myOrdersLoginRequired)),
      );
    }

    debugPrint("👤 CURRENT USER ID: $userId");

    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('buyerUid', isEqualTo: userId)
        //.orderBy('createdAt', descending: true) // بعداً index بساز
        .snapshots();

    return Container(
  color: const Color(0xFFFDF2F5),
  child: StreamBuilder<QuerySnapshot>(
        stream: ordersStream,
        builder: (context, snapshot) {
          /// DEBUG
          debugPrint("📡 CONNECTION STATE: ${snapshot.connectionState}");

          if (snapshot.hasData) {
            debugPrint("📦 ORDERS COUNT: ${snapshot.data!.docs.length}");
          } else {
            debugPrint("📦 ORDERS COUNT: no data yet");
          }

          if (snapshot.hasError) {
            debugPrint("❌ FIRESTORE ERROR: ${snapshot.error}");
            return Center(
              child: Text(l10n.errorOccurred(snapshot.error.toString())),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            debugPrint("📭 NO ORDERS FOUND");
            return Center(child: Text(l10n.noOrdersYet));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data() as Map<String, dynamic>;

              /// 🔥 STATUS
              final rawStatus = data['status'] ?? 'pending';
              final status = normalizeStatus(rawStatus);
              final color = getStatusColor(status);

              /// 🔥 PRICE FIX (خیلی مهم)
              final pricing = data['pricing'] ?? {};
              final total = pricing['grandTotal'] ?? 0;

              /// 🔥 ITEMS FIX
              final items = data['items'] as List? ?? [];

              /// 🔥 SELLER ORDER IDS (کلیدی)
              final sellerOrderIds = data['sellerOrderIds'] as List?;

              debugPrint("🧾 UI BUILD → ${doc.id} | total=$total | status=$status");

              return InkWell(
                onTap: () {
                  final sellerOrderIds = List<String>.from(
                    data['sellerOrderIds'] ?? [],
                  );

                  if (sellerOrderIds.isEmpty) return;

                  /// فعلاً اولین seller order رو باز کن
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderDetailPage(
                        sellerOrderId: sellerOrderIds.first,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      /// 🟢 STATUS DOT
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// 📦 INFO
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['orderNumber'] ??
                                  l10n.orderNumberLabel(doc.id.substring(0, 6)),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.itemsCountLabel(items.length),
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              orderStatusLabel(status, l10n),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      /// 💰 PRICE
                      Text(
                        "$total ₺",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String normalizeStatus(String s) {
  if (s.contains("pending")) return "pending";
  if (s.contains("paid")) return "paid";
  if (s.contains("fail")) return "failed";
  return s;
}

Color getStatusColor(String status) {
  switch (status) {
    case "paid":
      return Colors.green;
    case "pending":
      return Colors.orange;
    case "failed":
      return Colors.red;
    default:
      return Colors.grey;
  }
}

String orderStatusLabel(String status, AppLocalizations l10n) {
  switch (status) {
    case "pending":
      return l10n.pendingStatusLabel;
    case "paid":
      return l10n.paidStatusLabel;
    case "failed":
      return l10n.failedStatusLabel;
    default:
      return status;
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final String status;
  final num total;
  final int itemCount;
  final dynamic createdAt;

  const _OrderCard({
    required this.orderId,
    required this.status,
    required this.total,
    required this.itemCount,
    required this.createdAt,
  });

  Color _statusColor() {
    switch (status) {
      case "paid":
        return Colors.green;
      case "preparing":
        return Colors.orange;
      case "shipped":
        return Colors.blue;
      case "delivered":
        return Colors.teal;
      case "payment_failed":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case "paid":
        return l10n.paidStatusLabel;
      case "preparing":
        return l10n.preparingStatusLabel;
      case "shipped":
        return l10n.shippedStatusLabel;
      case "delivered":
        return l10n.deliveredStatusLabel;
      case "payment_failed":
        return l10n.paymentFailedStatusLabel;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: () {
          // 👉 بعداً می‌بریم به Order Detail Page
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🧾 Order ID
              Text(
                l10n.orderNumberLabel(orderId.substring(0, 6)),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              /// 📦 Items count
              Text(l10n.itemsCountLabel(itemCount)),

              const SizedBox(height: 8),

              /// 💰 Total
              Text(
                "${total.toString()} ₺",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 10),

              /// 🟢 Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusText(context),
                      style: TextStyle(
                        color: _statusColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
