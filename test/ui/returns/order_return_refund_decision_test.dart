import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/models/order_return.dart';
import 'package:barky_matches_fixed/ui/returns/order_return_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('buyer sees refund decision reason and explanation', (
    tester,
  ) async {
    final record = OrderReturnRecord.fromMap('return-1', {
      'returnId': 'return-1',
      'status': 'refund_rejected',
      'refundAmount': 0,
      'refundDecisionType': 'REJECTED',
      'refundReasonCode': 'customer_caused_damage',
      'refundExplanation': 'The returned item was damaged after delivery.',
      'refundDifference': 100,
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: OrderReturnCard(
              record: record,
              isSeller: false,
              isBuyer: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Reject Refund'), findsOneWidget);
    expect(find.text('Customer caused damage'), findsOneWidget);
    expect(
      find.text('The returned item was damaged after delivery.'),
      findsOneWidget,
    );
    expect(find.text('100.00 TRY'), findsOneWidget);
  });
}
