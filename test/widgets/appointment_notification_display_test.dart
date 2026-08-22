import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/appointment_notification_contract.dart';
import 'package:barky_matches_fixed/widgets/appointment_notification_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _testApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

AppointmentNotificationDisplay _display({
  required Future<AppointmentNotificationAvailability> Function(
    String notificationId,
  )
  resolveAvailability,
}) {
  return AppointmentNotificationDisplay(
    notificationId: 'notification-1',
    rawType: 'vet_appointment_response',
    title: 'Appointment Confirmed',
    body: 'Emergency is confirmed',
    resolveAvailability: resolveAvailability,
    builder: (context, title, body) {
      return Column(
        textDirection: TextDirection.ltr,
        children: [Text(title), Text(body)],
      );
    },
  );
}

void main() {
  testWidgets(
    'missing appointment notification renders neutral unavailable copy',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          _display(
            resolveAvailability: (_) async =>
                AppointmentNotificationAvailability.missing,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appointment'), findsOneWidget);
      expect(
        find.text('This appointment is no longer available.'),
        findsOneWidget,
      );
      expect(find.text('Appointment Confirmed'), findsNothing);
      expect(find.text('Emergency is confirmed'), findsNothing);
    },
  );

  testWidgets('valid appointment notification preserves current copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        _display(
          resolveAvailability: (_) async =>
              AppointmentNotificationAvailability.available,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Appointment Confirmed'), findsOneWidget);
    expect(find.text('Emergency is confirmed'), findsOneWidget);
    expect(find.text('This appointment is no longer available.'), findsNothing);
  });

  testWidgets('network or permission failures do not claim confirmed absence', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        _display(
          resolveAvailability: (_) async =>
              AppointmentNotificationAvailability.unknown,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Appointment'), findsOneWidget);
    expect(
      find.text("We couldn't check this appointment. Please try again."),
      findsOneWidget,
    );
    expect(find.text('This appointment is no longer available.'), findsNothing);
    expect(find.text('Appointment Confirmed'), findsNothing);
  });

  testWidgets('lookup exceptions do not claim confirmed absence', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        _display(
          resolveAvailability: (_) async => throw Exception('local failure'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("We couldn't check this appointment. Please try again."),
      findsOneWidget,
    );
    expect(find.text('This appointment is no longer available.'), findsNothing);
  });

  testWidgets(
    'explicit appointmentCollection marks generic payment as appointment',
    (tester) async {
      await tester.pumpWidget(
        _testApp(
          AppointmentNotificationDisplay(
            notificationId: 'notification-1',
            rawType: 'appointment_paid',
            title: 'Payment Completed',
            body: 'Payment completed successfully',
            notificationData: const {
              'type': 'appointment_paid',
              'appointmentCollection': 'groomy_appointments',
              'appointmentId': 'appointment-1',
            },
            resolveAvailability: (_) async =>
                AppointmentNotificationAvailability.missing,
            builder: (context, title, body) => Text('$title\n$body'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('This appointment is no longer available.'),
        findsOneWidget,
      );
      expect(find.textContaining('Payment Completed'), findsNothing);
    },
  );

  testWidgets('rebuilds reuse the same availability lookup future', (
    tester,
  ) async {
    var lookups = 0;
    late StateSetter rebuild;

    await tester.pumpWidget(
      _testApp(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _display(
              resolveAvailability: (_) async {
                lookups += 1;
                return AppointmentNotificationAvailability.available;
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    rebuild(() {});
    await tester.pumpAndSettle();

    expect(lookups, 1);
    expect(find.text('Appointment Confirmed'), findsOneWidget);
  });

  testWidgets('malformed appointment notification fails closed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        AppointmentNotificationDisplay(
          notificationId: null,
          rawType: 'vet_appointment_response',
          title: 'Appointment Confirmed',
          body: 'Emergency is confirmed',
          builder: (context, title, body) => Text('$title\n$body'),
        ),
      ),
    );

    expect(
      find.textContaining('This appointment is no longer available.'),
      findsOneWidget,
    );
    expect(find.textContaining('Appointment Confirmed'), findsNothing);
  });
}
