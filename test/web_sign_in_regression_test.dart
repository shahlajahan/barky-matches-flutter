import 'package:barky_matches_fixed/services/fcm_token_service.dart';
import 'package:barky_matches_fixed/widgets/ads/banner_ad_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BannerAdWidget is inert on web', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BannerAdWidget())),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SizedBox), findsWidgets);
  }, skip: !kIsWeb);

  test('mobile FCM token initialization is inert on web', () async {
    final token = await FcmTokenService.generateAndSaveForCurrentUser(
      source: 'web_regression_test',
    );

    expect(token, isNull);
  }, skip: !kIsWeb);
}
