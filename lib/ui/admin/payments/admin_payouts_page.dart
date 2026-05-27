import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminPayoutsPage extends StatefulWidget {
  const AdminPayoutsPage({super.key});

  @override
  State<AdminPayoutsPage> createState() => _AdminPayoutsPageState();
}

class _AdminPayoutsPageState extends State<AdminPayoutsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _query = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _queryForStatus(String status) {
    return FirebaseFirestore.instance
        .collection("sellerOrders")
        .where("payout.status", isEqualTo: status)
        .orderBy("updatedAt", descending: true);
  }

  bool _matchesSearch(Map<String, dynamic> data, String docId) {
    if (_query.trim().isEmpty) return true;

    final q = _query.toLowerCase();

    final sellerSnapshot =
        (data["sellerSnapshot"] as Map<String, dynamic>?) ?? {};
    final payout = (data["payout"] as Map<String, dynamic>?) ?? {};

    final searchable = [
      docId,
      data["sellerOrderNumber"],
      data["rootOrderNumber"],
      data["buyerEmail"],
      data["buyerName"],
      sellerSnapshot["businessName"],
      sellerSnapshot["taxNumber"],
      payout["reference"],
    ].whereType<Object>().join(" ").toLowerCase();

    return searchable.contains(q);
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Widget _summaryCard({
    required String title,
    required double value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "₺${value.toStringAsFixed(2)}",
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String status) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _queryForStatus(status).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs;

        final docs = allDocs.where((doc) {
          return _matchesSearch(doc.data(), doc.id);
        }).toList();

        double totalAmount = 0;
        double totalCommission = 0;

        for (final doc in docs) {
          final data = doc.data();
          final payout = (data["payout"] as Map<String, dynamic>?) ?? {};
          final financial = (data["financial"] as Map<String, dynamic>?) ?? {};
          totalAmount += _num(payout["amount"] ?? financial["sellerNetAmount"]);
          totalCommission += _num(financial["commissionAmount"]);
        }

        if (docs.isEmpty) {
          return const Center(child: Text("No payouts found"));
        }

        return ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Row(
              children: [
                _summaryCard(
                  title: "Seller Payout",
                  value: totalAmount,
                  color: Colors.green,
                ),
                const SizedBox(width: 10),
                _summaryCard(
                  title: "Platform Fee",
                  value: totalCommission,
                  color: Colors.deepPurple,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...docs.map((doc) {
              return _AdminPayoutCard(
                sellerOrderId: doc.id,
                data: doc.data(),
                status: status,
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F7),
      appBar: AppBar(
        title: const Text("Payout Management"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Ready"),
            Tab(text: "Paid"),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) {
                setState(() => _query = v.trim());
              },
              decoration: InputDecoration(
                hintText: "Search order, seller, buyer, ref...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList("pending"),
                _buildList("ready"),
                _buildList("paid"),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPayoutCard extends StatefulWidget {
  final String sellerOrderId;
  final Map<String, dynamic> data;
  final String status;

  const _AdminPayoutCard({
    required this.sellerOrderId,
    required this.data,
    required this.status,
  });

  @override
  State<_AdminPayoutCard> createState() => _AdminPayoutCardState();
}

class _AdminPayoutCardState extends State<_AdminPayoutCard> {
  bool loading = false;

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _markReady() async {
    setState(() => loading = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: "europe-west3",
      ).httpsCallable("markSellerPayoutReady");

      await callable.call({"sellerOrderId": widget.sellerOrderId});

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Payout marked as ready")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _markPaid() async {
    final refController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Confirm Payout"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: refController,
                decoration: const InputDecoration(
                  labelText: "Bank Transfer Reference",
                  hintText: "EFT / FAST / Bank Ref",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: "Note",
                  hintText: "Optional",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final ref = refController.text.trim();
                if (ref.isEmpty) return;

                Navigator.pop(context, {
                  "reference": ref,
                  "note": noteController.text.trim(),
                });
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    setState(() => loading = true);

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: "europe-west3",
      ).httpsCallable("markSellerPayoutPaid");

      await callable.call({
        "sellerOrderId": widget.sellerOrderId,
        "reference": result["reference"],
        "note": result["note"],
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Payout marked as paid")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final payout = (data["payout"] as Map<String, dynamic>?) ?? {};
    final financial = (data["financial"] as Map<String, dynamic>?) ?? {};
    final pricing = (data["pricing"] as Map<String, dynamic>?) ?? {};
    final seller = (data["sellerSnapshot"] as Map<String, dynamic>?) ?? {};
    final billing = (data["billing"] as Map<String, dynamic>?) ?? {};

    final amount = _num(payout["amount"] ?? financial["sellerNetAmount"]);
    final commission = _num(financial["commissionAmount"]);
    final gross = _num(pricing["grandTotal"]);
    final reference = payout["reference"]?.toString();

    final orderNumber =
        (data["sellerOrderNumber"] ??
                data["rootOrderNumber"] ??
                widget.sellerOrderId)
            .toString();

    final sellerName =
        (seller["businessName"] ??
                seller["name"] ??
                data["shopId"] ??
                "Unknown")
            .toString();

    final buyerName = (billing["contactName"] ?? data["buyerName"] ?? "-")
        .toString();

    Color statusColor;
    switch (widget.status) {
      case "paid":
        statusColor = Colors.green;
        break;
      case "ready":
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.blueGrey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withOpacity(0.12),
                child: Icon(Icons.account_balance_wallet, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  orderNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                widget.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text("Seller: $sellerName"),
          Text("Buyer: $buyerName"),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _miniBox("Gross", gross)),
              const SizedBox(width: 8),
              Expanded(child: _miniBox("Commission", commission)),
              const SizedBox(width: 8),
              Expanded(child: _miniBox("Payout", amount)),
            ],
          ),

          if (reference != null && reference.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              "Ref: $reference",
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],

          if (widget.status != "paid") ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (widget.status == "pending")
                  Expanded(
                    child: OutlinedButton(
                      onPressed: loading ? null : _markReady,
                      child: const Text("Mark Ready"),
                    ),
                  ),
                if (widget.status == "pending") const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: loading ? null : _markPaid,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Mark Paid"),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniBox(String title, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            "₺${value.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
