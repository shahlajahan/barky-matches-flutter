import 'package:flutter_test/flutter_test.dart';
import 'package:barky_matches_fixed/services/public_service_normalizer.dart';

void main() {
  test('normalizes canonical projected service list', () {
    final services = PublicServiceNormalizer.toMaps([
      {'id': 'dental', 'title': 'Dental care'},
      {'id': 'surgery', 'name': 'Surgery'},
    ]);

    expect(services, hasLength(2));
    expect(PublicServiceNormalizer.toTitles(services), [
      'Dental care',
      'Surgery',
    ]);
  });

  test('normalizes legacy offeredServices map', () {
    final services = PublicServiceNormalizer.toMaps({
      'offeredServices': ['Dental care', 'Surgery'],
    });

    expect(services, hasLength(2));
    expect(PublicServiceNormalizer.toTitles(services), [
      'Dental care',
      'Surgery',
    ]);
  });

  test('normalizes legacy nested service maps and ignores empty values', () {
    final services = PublicServiceNormalizer.toMaps({
      'services': {
        'dental': {'title': 'Dental care'},
      },
    });

    expect(services.single['id'], 'dental');
    expect(PublicServiceNormalizer.toTitles(services), ['Dental care']);
  });
}
