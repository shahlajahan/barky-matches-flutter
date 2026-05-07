import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard/groomy_services_tab.dart';

class GroomyDashboardPage extends StatefulWidget {
  final String businessId;

  const GroomyDashboardPage({
    super.key,
    required this.businessId,
  });

  @override
  State<GroomyDashboardPage> createState() =>
      _GroomyDashboardPageState();
}

class _GroomyDashboardPageState
    extends State<GroomyDashboardPage> {

  int _tabIndex = 0;

  Map<String, dynamic>? businessData;
  bool isLoading = true;

  final tabs = const [
    "Bookings",
    "Services",
    "Earnings",
  ];

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    final doc = await FirebaseFirestore.instance
        .collection("businesses")
        .doc(widget.businessId)
        .get();

    businessData = doc.data();

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Groomy Dashboard"),
      ),
      body: Column(
        children: [

          // =========================
          // TAB BAR
          // =========================
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (_, i) {
                final selected = i == _tabIndex;

                return GestureDetector(
                  onTap: () {
                    setState(() => _tabIndex = i);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.orange
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tabs[i],
                      style: TextStyle(
                        color:
                            selected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // =========================
          // CONTENT
          // =========================
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_tabIndex) {

      case 0:
        return const Center(
          child: Text("Bookings coming soon"),
        );

      case 1:
        return GroomyServicesTab(
          businessId: widget.businessId,
          businessData: businessData!,
        );

      case 2:
        return const Center(
          child: Text("Earnings coming soon"),
        );

      default:
        return const SizedBox();
    }
  }
}