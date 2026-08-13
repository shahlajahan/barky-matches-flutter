import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/services/business_search_matcher.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';

BusinessCardData business({
  required String name,
  required List<String> services,
  List<String> specialties = const [],
  BusinessType type = BusinessType.vet,
}) {
  return BusinessCardData(
    id: name,
    name: name,
    city: 'Istanbul',
    district: 'Kadıköy',
    address: 'Main Street',
    specialties: specialties,
    services: services,
    type: type,
  );
}

void main() {
  test('business-name search remains supported', () {
    expect(
      BusinessSearchMatcher.matches(
        business(name: 'Pera Veterinary Clinic', services: const []),
        'pera',
      ),
      isTrue,
    );
  });

  test('service-name and partial searches return the business', () {
    final clinic = business(
      name: 'Pera Veterinary Clinic',
      services: const ['Check-up', 'Vaccination', 'Microchip'],
    );

    expect(BusinessSearchMatcher.matches(clinic, 'check'), isTrue);
    expect(BusinessSearchMatcher.matches(clinic, 'micro'), isTrue);
    expect(BusinessSearchMatcher.matches(clinic, 'vaccination'), isTrue);
  });

  test('matching is case-insensitive, trimmed, and Turkish-aware', () {
    final groomer = business(
      name: 'İyi Patiler',
      services: const ['Tırnak Kesimi'],
    );

    expect(BusinessSearchMatcher.matches(groomer, '  tirnak  '), isTrue);
    expect(BusinessSearchMatcher.matches(groomer, 'İYİ'), isTrue);
  });

  test('empty query restores the complete result set', () {
    final clinic = business(name: 'Clinic', services: const ['Dental Care']);
    expect(BusinessSearchMatcher.matches(clinic, '   '), isTrue);
  });

  test('unrelated service does not match', () {
    final hotel = business(name: 'Paws Hotel', services: const ['VIP Room']);
    expect(BusinessSearchMatcher.matches(hotel, 'vaccination'), isFalse);
  });

  test('Groomy service fields are searchable', () {
    final groomer = business(
      name: 'Pati Kuaför',
      services: const ['Bath and Dry', 'Nail Trimming'],
      type: BusinessType.groomer,
    );

    expect(BusinessSearchMatcher.matches(groomer, 'nail'), isTrue);
  });

  test('Pet Hotel service fields are searchable', () {
    final hotel = business(
      name: 'Happy Paws Hotel',
      services: const ['VIP Room', 'Daily Care'],
      type: BusinessType.petHotel,
    );

    expect(BusinessSearchMatcher.matches(hotel, 'daily'), isTrue);
  });

  test('Pet Taxi and Pet Shop loaded labels remain searchable', () {
    final taxi = business(
      name: 'Safe Paws Transport',
      services: const ['Round trip', 'Vet'],
      type: BusinessType.petTaxi,
    );
    final shop = business(
      name: 'Paws Market',
      services: const ['Food', 'Accessories'],
      type: BusinessType.petShop,
    );

    expect(BusinessSearchMatcher.matches(taxi, 'round'), isTrue);
    expect(BusinessSearchMatcher.matches(shop, 'access'), isTrue);
  });

  test('one business remains one result when multiple services match', () {
    final clinic = business(
      name: 'Pera Veterinary Clinic',
      services: const ['Dental Care', 'Dental Cleaning'],
    );
    final businesses = [clinic].where((item) {
      return BusinessSearchMatcher.matches(item, 'dental');
    }).toList();

    expect(businesses, hasLength(1));
  });
}
