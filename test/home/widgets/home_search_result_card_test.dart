import 'package:barky_matches_fixed/home/widgets/home_search_result_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the entire search-result card triggers its onTap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeSearchResultCard(
            type: HomeSearchResultType.business,
            title: 'Koray pet',
            subtitle: 'Pet Taxi',
            onTap: () => taps++,
          ),
        ),
      ),
    );

    final inkWell = find.byType(InkWell);
    final rect = tester.getRect(inkWell);
    final tapTargets = [
      rect.topLeft + const Offset(22, 22),
      rect.topLeft + Offset(rect.width * 0.35, rect.height * 0.35),
      rect.topLeft + Offset(rect.width * 0.7, rect.height * 0.7),
      rect.topRight + const Offset(-18, 22),
    ];

    for (final target in tapTargets) {
      await tester.tapAt(target);
      await tester.pump();
    }

    expect(taps, tapTargets.length);
  });
}
