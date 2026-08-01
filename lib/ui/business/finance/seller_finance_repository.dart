import 'package:barky_matches_fixed/ui/business/finance/seller_finance_summary.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class SellerFinanceRepository {
  SellerFinanceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<SellerFinanceSummary?> watchSummary(String businessId) {
    final path = 'sellerFinanceSummaries/$businessId';
    return _firestore
        .collection('sellerFinanceSummaries')
        .doc(businessId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? SellerFinanceSummary.fromMap(snapshot.data()!)
              : null,
        )
        .handleError((Object error, StackTrace stack) {
          debugPrint(
            '[SellerFinance] summary read failed path=$path '
            'code=${error is FirebaseException ? error.code : 'unknown'} '
            'error=$error',
          );
        });
  }
}
