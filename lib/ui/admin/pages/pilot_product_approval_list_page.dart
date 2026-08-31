import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'pilot_product_approval_detail_page.dart';

/// Revision 28 pilot product approval contract — the admin review queue.
/// Every product a seller submits starts `isActive: false,
/// moderationStatus: 'pending_review'` (`add_product_page.dart`); this is
/// the sole state a product returns to after a revoke, an
/// unpublish-for-revision, or a cascade deactivation. Filtering on both
/// fields reuses the pre-existing collection-group composite index
/// (`isActive ASC, moderationStatus ASC` in `firestore.indexes.json`) —
/// no new index is required.
class PilotProductApprovalListPage extends StatelessWidget {
  /// Test-only seam — production call sites never supply this, always
  /// getting the real `FirebaseFirestore.instance`. Mirrors
  /// `AddProductPage.firestoreOverride`.
  @visibleForTesting
  final FirebaseFirestore? firestoreOverride;

  const PilotProductApprovalListPage({
    super.key,
    @visibleForTesting this.firestoreOverride,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final firestore = firestoreOverride ?? FirebaseFirestore.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pilotAdminListTitle),
        backgroundColor: Colors.pink,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collectionGroup('products')
            .where('isActive', isEqualTo: false)
            .where('moderationStatus', isEqualTo: 'pending_review')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.errorOccurred('${snapshot.error}')));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Text(
                l10n.pilotAdminListEmpty,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final businessId = data['businessId'] as String?;
              if (businessId == null) {
                return const SizedBox.shrink();
              }
              return _PendingProductTile(
                businessId: businessId,
                productId: doc.id,
                data: data,
              );
            },
          );
        },
      ),
    );
  }
}

class _PendingProductTile extends StatelessWidget {
  final String businessId;
  final String productId;
  final Map<String, dynamic> data;

  const _PendingProductTile({
    required this.businessId,
    required this.productId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] as String?)?.trim();
    final price = data['price'];
    final currency = (data['currency'] as String?) ?? '';
    final media = data['media'];
    final firstMedia = (media is List && media.isNotEmpty && media.first is Map)
        ? Map<String, dynamic>.from(media.first as Map)
        : null;
    final thumbnailUrl =
        (firstMedia?['thumbnailUrl'] as String?) ??
        (firstMedia?['originalUrl'] as String?);
    final approval = data['pilotProductApproval'];
    final wasRevoked = approval is Map && approval['revokedAt'] != null;

    return ListTile(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: thumbnailUrl == null
            ? const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.inventory_2_outlined),
              )
            : Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.inventory_2_outlined),
                    ),
              ),
      ),
      title: Text(
        (name == null || name.isEmpty) ? productId : name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        [
          if (price != null) '$price $currency'.trim(),
          if (wasRevoked) AppLocalizations.of(context)!.pilotStatusRevoked,
        ].where((e) => e.isNotEmpty).join(' • '),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PilotProductApprovalDetailPage(
              businessId: businessId,
              productId: productId,
            ),
          ),
        );
      },
    );
  }
}
