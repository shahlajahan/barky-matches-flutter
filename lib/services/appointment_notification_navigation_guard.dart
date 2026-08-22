import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:barky_matches_fixed/services/appointment_notification_contract.dart';

enum AppointmentNotificationNavigationDecision {
  notAppointment,
  available,
  missingOrMalformed,
  lookupFailedOrUnresolved,
}

typedef AppointmentAvailabilityResolver =
    Future<AppointmentNotificationAvailability> Function(
      Map<String, dynamic> payload,
    );

class AppointmentNotificationNavigationGuard {
  const AppointmentNotificationNavigationGuard._();

  static bool isAppointmentPayload(Map<String, dynamic> payload) {
    final rawType = payload['type']?.toString();
    final rawCollection = payload['appointmentCollection']?.toString().trim();
    return AppointmentNotificationContract.isAppointmentNotificationType(
          rawType,
        ) ||
        AppointmentNotificationContract.supportedCollections.contains(
          rawCollection,
        );
  }

  static Future<AppointmentNotificationNavigationDecision> evaluate(
    Map<String, dynamic> payload, {
    FirebaseFirestore? firestore,
    AppointmentAvailabilityResolver? resolveAvailability,
  }) async {
    if (!isAppointmentPayload(payload)) {
      return AppointmentNotificationNavigationDecision.notAppointment;
    }

    final reference = AppointmentNotificationContract.resolve(payload);
    if (reference == null) {
      return AppointmentNotificationNavigationDecision.missingOrMalformed;
    }

    try {
      final availability = resolveAvailability == null
          ? await AppointmentNotificationContract.availability(
              firestore ?? FirebaseFirestore.instance,
              payload,
            )
          : await resolveAvailability(payload);

      switch (availability) {
        case AppointmentNotificationAvailability.available:
          return AppointmentNotificationNavigationDecision.available;
        case AppointmentNotificationAvailability.missing:
        case AppointmentNotificationAvailability.malformed:
          return AppointmentNotificationNavigationDecision.missingOrMalformed;
        case AppointmentNotificationAvailability.unknown:
          return AppointmentNotificationNavigationDecision
              .lookupFailedOrUnresolved;
      }
    } catch (_) {
      return AppointmentNotificationNavigationDecision.lookupFailedOrUnresolved;
    }
  }
}
