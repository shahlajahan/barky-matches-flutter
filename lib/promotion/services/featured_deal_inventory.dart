import '../../models/featured_deal.dart';

const legacyDemoFeaturedDealDocumentId = 'petshop';

bool isLegacyDemoFeaturedDealDocument(String documentId) =>
    documentId == legacyDemoFeaturedDealDocumentId;

List<FeaturedDeal> composeFeaturedDealInventory({
  required List<FeaturedDeal> editorialDeals,
  List<FeaturedDeal>? promotedDeals,
  List<FeaturedDeal> previousPromotedDeals = const [],
  required FeaturedDeal placeholder,
}) {
  final inventory = <FeaturedDeal>[
    ...editorialDeals,
    ...(promotedDeals ?? previousPromotedDeals),
  ];
  return inventory.isEmpty ? <FeaturedDeal>[placeholder] : inventory;
}
