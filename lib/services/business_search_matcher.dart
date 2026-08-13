import 'package:barky_matches_fixed/ui/business/business_card_data.dart';

/// Matches the searchable customer-facing text already loaded into a card.
///
/// This deliberately stays a local filter: it does not change Firestore
/// queries or require additional reads for service discovery.
class BusinessSearchMatcher {
  const BusinessSearchMatcher._();

  static bool matches(BusinessCardData business, String rawQuery) {
    final query = normalize(rawQuery);
    if (query.isEmpty) return true;

    final searchable = <String>[
      business.name,
      business.city,
      business.district,
      business.address,
      business.description ?? '',
      ...business.specialties,
      ...?business.services,
    ].map(normalize).join(' ');

    return searchable.contains(query);
  }

  static String normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c');
  }
}
