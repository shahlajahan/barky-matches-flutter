import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Marketplace Revision 43 §0.41 (Slice 7D) — the durable guard that stops
// customer-facing discovery regressing to direct Firestore product reads.
//
// WHY A SOURCE GUARD. The security property is architectural: publishability
// is decided by `evaluateLiveProductEligibility` on the server, using the
// compliance decision, pilot approval, evidence validity, business generation
// and pilot class — none of which a client can read. A single reintroduced
// `collection('products')` query in a customer surface silently reinstates
// the client-side `isActive`/`moderationStatus` approximation that Slice 7B
// already proved insufficient, and no behavioural test of the migrated
// screens would necessarily catch it.
//
// The guard is an ALLOWLIST of justified private readers, not a denylist of
// forbidden strings, so a NEW customer-facing file is covered the moment it
// is added — the failure mode of a denylist (add a file, forget the rule) is
// exactly what must not happen here.
void main() {
  /// Modules permitted to read product documents directly, each with the
  /// authority that makes it legitimate. These are Seller-owned, Admin-only
  /// or historical-order paths — never public discovery.
  const allowedDirectReaders = <String, String>{
    // The seller managing their OWN inventory. Rules prove ownership; the
    // reader intentionally sees pending/rejected/inactive products, which no
    // customer surface may ever see.
    'lib/services/product_service.dart':
        'Seller-owned inventory management (all statuses) and seller writes.',
    'lib/ui/business/petshop/add_product_page.dart':
        'Seller create/edit of their own product, scoped to their business.',
    // Admin compliance review. Authorized by the admin Rules branch.
    'lib/ui/admin/pages/pilot_product_approval_list_page.dart':
        'Admin pilot-approval queue (admin-only Rules branch).',
    'lib/ui/admin/pages/pilot_product_approval_detail_page.dart':
        'Admin classification/approval detail (admin-only Rules branch).',
    // Historical order support. Reads the live product only to resolve a
    // return shipping policy for an order already placed, and already treats
    // an unreadable product as absent.
    'lib/services/order_return_service.dart':
        'Return shipping policy for an existing order; fails closed when the '
        'product is no longer readable.',
  };

  /// Patterns that constitute a direct product read. Deliberately matched on
  /// STRUCTURE (a products collection, or a product document path) rather
  /// than on any single spelling, so renaming a variable or wrapping the
  /// call in a helper does not evade the guard.
  final directProductReadPatterns = <RegExp>[
    RegExp(r"""collection\(\s*['"]products['"]\s*\)"""),
    RegExp(r"""collectionGroup\(\s*['"]products['"]\s*\)"""),
    // A products subcollection reached through a variable business ref.
    RegExp(r"""\.collection\(\s*[a-zA-Z_][\w.]*\s*\)\s*\.doc\([^)]*\)\s*\.collection\(\s*['"]products['"]"""),
  ];

  List<File> dartFilesUnder(String path) => Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String repoRelative(File f) =>
      f.path.replaceFirst('${Directory.current.path}/', '');

  /// Strips `//` line comments so an explanatory comment mentioning a query
  /// cannot trip the guard, and — more importantly — so a real read cannot
  /// hide behind one.
  String withoutLineComments(String source) => source
      .split('\n')
      .map((line) {
        final idx = line.indexOf('//');
        return idx == -1 ? line : line.substring(0, idx);
      })
      .join('\n');

  test('no lib/ file outside the allowlist reads product documents directly', () {
    final offenders = <String>[];
    for (final file in dartFilesUnder('lib')) {
      final rel = repoRelative(file);
      if (allowedDirectReaders.containsKey(rel)) continue;
      final code = withoutLineComments(file.readAsStringSync());
      for (final pattern in directProductReadPatterns) {
        if (pattern.hasMatch(code)) {
          offenders.add('$rel matches ${pattern.pattern}');
          break;
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'A customer-facing surface must hydrate products through '
          'MarketplaceCatalogService (the trusted callables), never through a '
          'direct Firestore read. If this file is genuinely a Seller, Admin or '
          'historical-order reader, add it to allowedDirectReaders WITH its '
          'authority — do not delete this test.\n'
          'Offenders:\n  ${offenders.join('\n  ')}',
    );
  });

  test('every allowlisted reader still exists and still reads products', () {
    // Keeps the allowlist honest: a stale entry would silently widen the
    // guard, and a renamed file would leave a hole.
    for (final entry in allowedDirectReaders.entries) {
      final file = File(entry.key);
      expect(
        file.existsSync(),
        isTrue,
        reason: '${entry.key} is allowlisted but missing — remove or update it',
      );
      final code = withoutLineComments(file.readAsStringSync());
      final reads = directProductReadPatterns.any((p) => p.hasMatch(code));
      expect(
        reads,
        isTrue,
        reason:
            '${entry.key} no longer performs a direct product read, so its '
            'allowlist entry is stale and must be removed.',
      );
      expect(entry.value.trim(), isNotEmpty);
    }
  });

  test('the migrated public surfaces reach products only through the callable service', () {
    // Named explicitly so a future edit that reintroduces a read into one of
    // these exact journeys fails loudly, rather than relying on the sweep
    // above alone.
    const publicSurfaces = <String>[
      'lib/ui/petshop/all_products_page.dart',
      'lib/ui/petshop/petshop_products_page.dart',
      'lib/ui/petshop/pet_shop_customer_details_page.dart',
      'lib/ui/petshop/seller_product_availability.dart',
      'lib/ui/product/seller_profile_page.dart',
      'lib/ui/product/favorite_products_page.dart',
      'lib/ui/product/product_detail_page.dart',
      'lib/ui/marketplace/marketplace_products_builder.dart',
    ];
    for (final path in publicSurfaces) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is missing');
      final code = withoutLineComments(file.readAsStringSync());
      for (final pattern in directProductReadPatterns) {
        expect(
          pattern.hasMatch(code),
          isFalse,
          reason: '$path performs a direct product read (${pattern.pattern})',
        );
      }
    }
  });

  test('the discovery service and controller perform no Firestore access at all', () {
    // These two files are the whole client-side discovery boundary. If either
    // ever imports Firestore, the boundary has a hole by construction.
    for (final path in const [
      'lib/services/marketplace_catalog_service.dart',
      'lib/services/marketplace_discovery_controller.dart',
      'lib/models/public_marketplace_product_adapter.dart',
    ]) {
      final code = File(path).readAsStringSync();
      expect(
        code.contains('cloud_firestore'),
        isFalse,
        reason: '$path must not import Firestore',
      );
      expect(
        code.contains('FirebaseFirestore'),
        isFalse,
        reason: '$path must not touch Firestore',
      );
    }
  });

  test('the guard itself is non-vacuous: a planted read is detected', () {
    // Proves the patterns actually match the shapes this migration removed,
    // so the sweep above cannot pass merely because nothing matches anything.
    const planted = <String>[
      "FirebaseFirestore.instance.collection('products').get();",
      'FirebaseFirestore.instance.collectionGroup("products").snapshots();',
      "FirebaseFirestore.instance.collection('businesses').doc(shopId).collection('products').doc(id).get();",
      "db.collection( 'products' )",
    ];
    for (final sample in planted) {
      expect(
        directProductReadPatterns.any((p) => p.hasMatch(sample)),
        isTrue,
        reason: 'the guard failed to detect: $sample',
      );
    }
  });
}
