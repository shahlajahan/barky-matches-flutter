import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_search_item.dart';

class AdminSearchService {
  final FirebaseFirestore _firestore;

  AdminSearchService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _indexRef =>
      _firestore.collection('admin_search_index');

  String normalizeSearchQuery(String input) {
    return input.trim().toLowerCase();
  }

  Future<List<AdminSearchItem>> search({
    required String query,
    AdminSearchEntityType? type,
    int limit = 30,
  }) async {
    final normalized = normalizeSearchQuery(query);

    if (normalized.isEmpty) {
      return loadRecent(type: type, limit: limit);
    }

    Query<Map<String, dynamic>> ref = _indexRef
        .where('searchPrefixes', arrayContains: normalized)
        .limit(limit);

    if (type != null) {
      ref = ref.where(
        'entityType',
        isEqualTo: adminSearchEntityTypeToString(type),
      );
    }

    final snapshot = await ref.get();

    final items = snapshot.docs
        .map((doc) => AdminSearchItem.fromDoc(doc))
        .toList();

    items.sort((a, b) {
      final aUpdated = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bUpdated = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bUpdated.compareTo(aUpdated);
    });

    return items;
  }

  Future<List<AdminSearchItem>> loadRecent({
    AdminSearchEntityType? type,
    int limit = 20,
  }) async {
    Query<Map<String, dynamic>> ref =
        _indexRef.orderBy('updatedAt', descending: true).limit(limit);

    if (type != null) {
      ref = ref.where(
        'entityType',
        isEqualTo: adminSearchEntityTypeToString(type),
      );
    }

    final snapshot = await ref.get();
    return snapshot.docs
        .map((doc) => AdminSearchItem.fromDoc(doc))
        .toList();
  }
}