import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/order_return.dart';
import '../../returns/order_return_card.dart';

class AdminReturnDisputesPage extends StatelessWidget {
  const AdminReturnDisputesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminReturnDisputesTitle)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('order_returns')
            .where('status', isEqualTo: 'dispute')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.errorOccurred('${snapshot.error}')));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data!.docs
              .map(OrderReturnRecord.fromDoc)
              .toList();
          if (records.isEmpty) {
            return Center(child: Text(l10n.noReturnDisputes));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) => OrderReturnCard(
              record: records[index],
              isSeller: false,
              isBuyer: false,
            ),
          );
        },
      ),
    );
  }
}
