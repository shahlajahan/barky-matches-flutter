import 'package:barky_matches_fixed/services/web_advertising_service.dart';
import 'package:barky_matches_fixed/widgets/ads/web_ad_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('disabled web slot leaves no layout gap in widget tests', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WebAdvertisingService>.value(
            value: WebAdvertisingService(
              configuration: WebAdConfiguration.disabled(),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: WebAdSlot(
              placementKey: 'home_footer_banner',
              shouldShowAds: true,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Ad test placeholder'), findsNothing);
    expect(tester.getSize(find.byType(WebAdSlot)), Size.zero);
  });
}
