import 'package:cloud_firestore/cloud_firestore.dart';

import 'appointment_service.dart';
import 'appointment_status.dart';

import '../config/appointment_source.dart';

class AppointmentItem {
  final String id;

  final AppointmentServiceType serviceType;

  final AppointmentStatusType status;

  final String businessName;

  final String serviceTitle;

  final String petName;

  final String petType;

  final double price;

  final DateTime? appointmentDate;

  final String collectionName;

  final Map<String, dynamic> rawData;

  const AppointmentItem({
    required this.id,
    required this.serviceType,
    required this.status,
    required this.businessName,
    required this.serviceTitle,
    required this.petName,
    required this.petType,
    required this.price,
    required this.appointmentDate,
    required this.collectionName,
    required this.rawData,
  });

  factory AppointmentItem.fromFirestore({
  required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  required AppointmentSource source,
  required AppointmentStatusType status,
}) {
    final data = doc.data();

    DateTime? date;

    final rawDate =
    data[source.dateField];

    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is DateTime) {
      date = rawDate;
    } else if (rawDate is String) {
      date = DateTime.tryParse(rawDate);
    }

    final priceRaw =
    data[source.priceField];

    final price = priceRaw is num
        ? priceRaw.toDouble()
        : double.tryParse(priceRaw?.toString() ?? '') ?? 0;

    return AppointmentItem(
      id: doc.id,
      serviceType: source.serviceType,
      status: status,
      businessName:
(data[source.businessNameField] ?? '')
.toString(),
      serviceTitle:
          (data['serviceTitle'] ?? '').toString(),
      petName:
(data[source.petNameField] ?? '')
.toString(),
      petType:
(data[source.petTypeField] ?? '')
.toString(),
      price: price,
      appointmentDate: date,
      collectionName: doc.reference.parent.id,
      rawData: data,
    );
  }
}