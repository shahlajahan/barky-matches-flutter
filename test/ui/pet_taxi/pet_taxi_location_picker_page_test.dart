import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/pet_taxi_location_service.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_location_picker_page.dart';

void main() {
  const point = PetTaxiLocationPoint(
    formattedAddress: 'Laboratory Street 1, Istanbul',
    lat: 41.0082,
    lng: 28.9784,
  );

  testWidgets('search suggestion selection enables location confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PetTaxiLocationPickerPage(
          title: 'Select Pickup Location',
          initializeLocation: false,
          locationSearch: (_) async => [point],
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Istanbul');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text(point.formattedAddress), findsOneWidget);
    await tester.tap(find.byType(ListTile).first);
    await tester.pump();

    expect(find.text(point.formattedAddress), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
}
