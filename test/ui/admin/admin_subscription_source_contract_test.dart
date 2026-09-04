import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'admin subscription UI uses the trusted callable and no direct writes',
    () {
      final page = File(
        'lib/ui/admin/subscriptions/admin_subscription_page.dart',
      ).readAsStringSync();
      final details = File(
        'lib/ui/admin/subscriptions/admin_subscription_details_page.dart',
      ).readAsStringSync();
      final repository = File(
        'lib/ui/admin/subscriptions/admin_subscription_repository.dart',
      ).readAsStringSync();
      final combined = '$page\n$details\n$repository';

      expect(details, contains("httpsCallable('adminUpdateSubscription')"));
      expect(combined, isNot(contains('.set(')));
      expect(combined, isNot(contains('.update(')));
    },
  );
}
