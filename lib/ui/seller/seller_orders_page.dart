import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/seller/order_card.dart';
import 'package:barky_matches_fixed/ui/orders/order_detail_page.dart';

class SellerOrdersPage extends StatefulWidget {
  final String businessId;

  const SellerOrdersPage({
    super.key,
    required this.businessId,
  });

  @override
  State<SellerOrdersPage> createState() => _SellerOrdersPageState();
}

class _SellerOrdersPageState extends State<SellerOrdersPage> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = "all";

  String normalizeStatus(String s) {
    final lower = s.toLowerCase();

    if (lower.contains("pending")) return "pending";
    if (lower.contains("paid")) return "paid";
    if (lower.contains("confirmed")) return "confirmed";
    if (lower.contains("preparing")) return "preparing";
    if (lower.contains("shipped")) return "shipped";
    if (lower.contains("delivered")) return "delivered";
    if (lower.contains("fail")) return "failed";

    return lower;
  }

  List<QueryDocumentSnapshot> _applyClientFilters(
    List<QueryDocumentSnapshot> docs,
  ) {
    final q = _searchController.text.trim().toLowerCase();

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = normalizeStatus((data['status'] ?? '').toString());
      final items = data['items'] as List? ?? [];

      final orderIdMatch = doc.id.toLowerCase().contains(q);

      final itemNameMatch = items.any((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        return name.contains(q);
      });

      final matchesSearch = q.isEmpty || orderIdMatch || itemNameMatch;
      final matchesFilter =
          _selectedFilter == "all" ? true : status == _selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _selectedFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: const Color(0xFF9E1B4F).withOpacity(0.14),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF9E1B4F) : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected
            ? const Color(0xFF9E1B4F).withOpacity(0.20)
            : Colors.black12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F7),
      appBar: AppBar(
        title: Text(l10n.ordersTitle),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            color: Colors.transparent,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.searchByOrderIdOrProductNameHint,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip(l10n.allFilterLabel, "all"),
                      const SizedBox(width: 8),
                      _buildFilterChip(l10n.pendingStatusLabel, "pending"),
                      const SizedBox(width: 8),
                      _buildFilterChip(l10n.paidStatusLabel, "paid"),
                      const SizedBox(width: 8),
                      _buildFilterChip(l10n.confirmedStatusLabel, "confirmed"),
                      const SizedBox(width: 8),
                      _buildFilterChip(l10n.preparingStatusLabel, "preparing"),
                      const SizedBox(width: 8),
                      _buildFilterChip(l10n.shippedStatusLabel, "shipped"),
                      const SizedBox(width: 8),
                      _buildFilterChip(l10n.deliveredStatusLabel, "delivered"),
                      const SizedBox(width: 8),
                      _buildFilterChip(l10n.failedStatusLabel, "failed"),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
    .collection("sellerOrders") // 🔥 FIX
    .where("shopId", isEqualTo: widget.businessId)
    .orderBy("createdAt", descending: true)
    .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint("❌ SELLER ORDERS ERROR: ${snapshot.error}");
                  return Center(
                    child: Text(l10n.errorOccurred(snapshot.error.toString())),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!snapshot.hasData || snapshot.data == null) {
                  return Center(
                    child: Text(l10n.noDataLabel),
                  );
                }

                final docs = snapshot.data!.docs;
                final filteredOrders = _applyClientFilters(docs);

                if (docs.isEmpty) {
                  return Center(
                    child: Text(l10n.noOrdersYet),
                  );
                }

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Text(l10n.noMatchingOrders),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    final data = order.data() as Map<String, dynamic>;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SellerOrderCard(
                        sellerOrderId: order.id,
                        data: data,
                        onTap: () {
                          Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => OrderDetailPage(
     
      sellerOrderId: order.id,          // 👈 🔥 مهم‌ترین
    ),
  ),
);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
