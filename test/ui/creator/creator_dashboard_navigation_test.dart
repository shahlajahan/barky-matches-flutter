import 'package:barky_matches_fixed/ui/creator/creator_dashboard_navigation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const productionMobileDestination =
      'https://app.petsupo.com/creator/dashboard';

  test(
    'A. on barkymatches-new.web.app, resolves to same-origin internal navigation',
    () {
      final plan = resolveCreatorDashboardNavigation(
        isWeb: true,
        webOrigin: 'https://barkymatches-new.web.app',
        productionMobileDestination: productionMobileDestination,
      );

      expect(plan.mode, CreatorDashboardNavigationMode.internalWeb);
      expect(
        plan.destination,
        'https://barkymatches-new.web.app/creator/dashboard',
      );
    },
  );

  test(
    'B. on app.petsupo.com, resolves to same-origin internal navigation',
    () {
      final plan = resolveCreatorDashboardNavigation(
        isWeb: true,
        webOrigin: 'https://app.petsupo.com',
        productionMobileDestination: productionMobileDestination,
      );

      expect(plan.mode, CreatorDashboardNavigationMode.internalWeb);
      expect(plan.destination, 'https://app.petsupo.com/creator/dashboard');
    },
  );

  test('C. on iOS/Android (not web), resolves to the fixed production mobile '
      'destination in external mode regardless of webOrigin', () {
    final plan = resolveCreatorDashboardNavigation(
      isWeb: false,
      webOrigin: '',
      productionMobileDestination: productionMobileDestination,
    );

    expect(plan.mode, CreatorDashboardNavigationMode.externalMobile);
    expect(plan.destination, productionMobileDestination);
  });

  test('web mode never falls back to the mobile destination', () {
    final plan = resolveCreatorDashboardNavigation(
      isWeb: true,
      webOrigin: 'https://barkymatches-new.web.app',
      productionMobileDestination: productionMobileDestination,
    );

    expect(plan.destination, isNot(contains('app.petsupo.com')));
  });
}
