import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'vet_revenue_model.dart';

class VetRevenueRepository {
  VetRevenueRepository({
    FirebaseFirestore? firestore,
    this.collectionName = 'vet_appointments',
    this.businessIdField = 'businessId',
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String collectionName;
  final String businessIdField;

  Stream<List<VetRevenueTransaction>> streamRevenue(String businessId) {
    return _firestore
        .collection(collectionName)
        .where(businessIdField, isEqualTo: businessId)
        .snapshots(includeMetadataChanges: false)
        .map((snapshot) {
          final transactions =
              snapshot.docs.map((document) {
                final transaction = VetRevenueTransaction.fromMap(
                  document.id,
                  document.data(),
                );
                if (transaction.status ==
                    VetRevenueStatus.financialDataMissing) {
                  debugPrint(
                    'VetRevenueRepository: paid appointment has missing or malformed '
                    'financial data (appointmentId=${document.id})',
                  );
                }
                return transaction;
              }).toList()..sort((a, b) {
                final aDate = a.paidAt ?? a.scheduledAt ?? a.eventDate;
                final bDate = b.paidAt ?? b.scheduledAt ?? b.eventDate;
                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                return bDate.compareTo(aDate);
              });
          return transactions;
        });
  }
}
