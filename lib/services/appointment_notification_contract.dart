import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentNotificationReference {
  const AppointmentNotificationReference({
    required this.collection,
    required this.documentId,
    required this.family,
  });

  final String collection;
  final String documentId;
  final String family;
}

enum AppointmentNotificationAvailability {
  available,
  missing,
  malformed,
  unknown,
}

class AppointmentNotificationContract {
  static const Set<String> supportedCollections = {
    'vet_appointments',
    'groomy_appointments',
    'hotel_bookings',
    'pet_taxi_bookings',
  };

  static const Map<String, String> _collectionByType = {
    'vet_appointment_request': 'vet_appointments',
    'vet_appointment_response': 'vet_appointments',
    'appointment_cancelled_confirmation': 'vet_appointments',
    'vet_appointment_refunded': 'vet_appointments',
    'appointment_reminder': 'vet_appointments',
    'vet_appointment_payment_expired': 'vet_appointments',
    'appointment_paid': 'vet_appointments',
    'groomy_appointment_request': 'groomy_appointments',
    'groomy_appointment_response': 'groomy_appointments',
    'groomy_appointment_cancelled_by_user': 'groomy_appointments',
    'groomy_appointment_payment_expired': 'groomy_appointments',
    'hotel_booking_request': 'hotel_bookings',
    'hotel_booking_response': 'hotel_bookings',
    'hotel_booking_cancelled_by_user': 'hotel_bookings',
    'hotel_booking_payment_expired': 'hotel_bookings',
    'hotel_booking_payment_completed': 'hotel_bookings',
    'pet_taxi_booking_request': 'pet_taxi_bookings',
    'pet_taxi_price_proposed': 'pet_taxi_bookings',
    'pet_taxi_payment_success': 'pet_taxi_bookings',
    'pet_taxi_payment_completed': 'pet_taxi_bookings',
    'pet_taxi_driver_on_the_way': 'pet_taxi_bookings',
    'pet_taxi_driver_arrived': 'pet_taxi_bookings',
    'pet_taxi_pet_picked_up': 'pet_taxi_bookings',
    'pet_taxi_trip_started': 'pet_taxi_bookings',
    'pet_taxi_trip_completed': 'pet_taxi_bookings',
    'pet_taxi_booking_cancelled': 'pet_taxi_bookings',
    'pet_taxi_status_update': 'pet_taxi_bookings',
    'pet_taxi_booking_cancelled_by_user': 'pet_taxi_bookings',
    'pet_taxi_booking_payment_expired': 'pet_taxi_bookings',
  };

  static bool isAppointmentNotificationType(String? rawType) {
    final type = _normalize(rawType);
    return _collectionByType.containsKey(type);
  }

  static AppointmentNotificationReference? resolve(Map<String, dynamic> data) {
    final type = _normalize(data['type']);
    final explicitCollection = _normalize(data['appointmentCollection']);
    final collection = explicitCollection.isEmpty
        ? _collectionByType[type]
        : supportedCollections.contains(explicitCollection)
        ? explicitCollection
        : null;

    if (collection == null) {
      return null;
    }

    final documentId =
        _stringValue(data['bookingId']) ?? _stringValue(data['appointmentId']);
    if (documentId == null) {
      return null;
    }

    return AppointmentNotificationReference(
      collection: collection,
      documentId: documentId,
      family: _familyForCollection(collection),
    );
  }

  static Future<bool> exists(
    FirebaseFirestore firestore,
    AppointmentNotificationReference reference,
  ) async {
    final snap = await firestore
        .collection(reference.collection)
        .doc(reference.documentId)
        .get();
    return snap.exists;
  }

  static Future<AppointmentNotificationAvailability> availability(
    FirebaseFirestore firestore,
    Map<String, dynamic> data,
  ) async {
    final reference = resolve(data);
    if (reference == null) {
      return AppointmentNotificationAvailability.malformed;
    }

    try {
      final sourceExists = await exists(firestore, reference);
      return sourceExists
          ? AppointmentNotificationAvailability.available
          : AppointmentNotificationAvailability.missing;
    } catch (_) {
      return AppointmentNotificationAvailability.unknown;
    }
  }

  static String _normalize(Object? value) =>
      value?.toString().trim().toLowerCase() ?? '';

  static String? _stringValue(Object? value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String _familyForCollection(String collection) {
    switch (collection) {
      case 'vet_appointments':
        return 'vet';
      case 'groomy_appointments':
        return 'groomy';
      case 'hotel_bookings':
        return 'hotel';
      case 'pet_taxi_bookings':
        return 'pet_taxi';
    }
    return 'unknown';
  }
}
