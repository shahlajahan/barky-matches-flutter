import 'package:barky_matches_fixed/welcome_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup gate keeps the normal entry page without a redirect', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: WebAuthStartupGate(child: Text('Welcome'))),
    );

    expect(find.text('Welcome'), findsOneWidget);
  });
}
