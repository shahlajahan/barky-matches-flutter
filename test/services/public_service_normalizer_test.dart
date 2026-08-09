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

  test('preserves legacy services without identity for display fallback', () {
    final source = PublicServiceNormalizer.toMaps([
      {'title': 'Laboratory', 'isActive': true},
      {'title': 'Vaccination', 'isActive': true},
    ]);

    final merged = PublicServiceNormalizer.mergeRankedWithLegacyServices(
      ranked: const [],
      source: source,
    );

    expect(merged.map((service) => service['title']), [
      'Laboratory',
      'Vaccination',
    ]);
    expect(
      merged.every(
        (service) => PublicServiceNormalizer.serviceId(service) == null,
      ),
      isTrue,
    );
  });

  test(
    'merges ranked canonical services without duplicating legacy records',
    () {
      final source = PublicServiceNormalizer.toMaps([
        {'id': 'laboratory', 'title': 'Laboratory'},
        {'title': 'Legacy service'},
      ]);

      final merged = PublicServiceNormalizer.mergeRankedWithLegacyServices(
        ranked: [source.first],
        source: source,
      );

      expect(merged.map((service) => service['title']), [
        'Laboratory',
        'Legacy service',
      ]);
    },
  );

  test('preserves empty and missing service sources as empty', () {
    expect(PublicServiceNormalizer.toMaps(const []), isEmpty);
    expect(PublicServiceNormalizer.toMaps(null), isEmpty);
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
