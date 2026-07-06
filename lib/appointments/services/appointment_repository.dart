import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/appointment_item.dart';
import '../models/appointment_service.dart';
import '../models/appointment_status.dart';
import 'package:flutter/material.dart';

import '../config/appointment_source.dart';
import '../mappers/appointment_status_mapper.dart';
import '../models/appointment_summary.dart';

import '../config/appointment_service_metadata.dart';

class AppointmentRepository {
  AppointmentRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;

  final FirebaseAuth _auth;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _vetAppointments =>
      _firestore.collection('vet_appointments');

  CollectionReference<Map<String, dynamic>> get _groomyAppointments =>
      _firestore.collection('groomy_appointments');

  CollectionReference<Map<String, dynamic>> get _hotelBookings =>
      _firestore.collection('hotel_bookings');

  CollectionReference<Map<String, dynamic>> get _petTaxiBookings =>
      _firestore.collection('pet_taxi_bookings');

      AppointmentSource _sourceFor(AppointmentServiceType type) {
  return appointmentSources.firstWhere(
    (e) => e.serviceType == type,
  );
}

AppointmentStatusType _statusFromDocument(
  AppointmentSource source,
  Map<String, dynamic> data,
) {
  return AppointmentStatusMapper.fromFirestore(
    data[source.statusField]?.toString(),
  );
}

  Future<List<AppointmentService>> getServices() async {
  final uid = currentUserId;

  if (uid == null) {
    return [];
  }

  final List<AppointmentService> services = [];

  for (final source in appointmentSources) {
    final snapshot = await _firestore
        .collection(source.collection)
        .where('userId', isEqualTo: uid)
        .get();

    final meta = appointmentServiceMetadata[source.serviceType]!;

    services.add(
      AppointmentService(
        type: source.serviceType,
        title: meta.title,
        icon: meta.icon,
        totalCount: snapshot.docs.length,
      ),
    );
  }

  return services;
}

  Future<List<AppointmentStatus>> getStatuses(
  AppointmentServiceType service,
) async {
  final uid = currentUserId;

  if (uid == null) {
    return [];
  }

  final source = _sourceFor(service);

  final snapshot = await _firestore
      .collection(source.collection)
      .where('userId', isEqualTo: uid)
      .get();

  int pending = 0;
  int approved = 0;
  int completed = 0;
  int cancelled = 0;

  for (final doc in snapshot.docs) {
    final status = AppointmentStatusMapper.fromFirestore(
      doc.data()[source.statusField]?.toString(),
    );

    switch (status) {
      case AppointmentStatusType.pending:
        pending++;
        break;

      case AppointmentStatusType.approved:
        approved++;
        break;

      case AppointmentStatusType.completed:
        completed++;
        break;

      case AppointmentStatusType.cancelled:
        cancelled++;
        break;
    }
  }

  return [
    AppointmentStatus(
      type: AppointmentStatusType.pending,
      title: AppointmentStatusMapper.title(
        AppointmentStatusType.pending,
      ),
      count: pending,
    ),

    AppointmentStatus(
      type: AppointmentStatusType.approved,
      title: AppointmentStatusMapper.title(
        AppointmentStatusType.approved,
      ),
      count: approved,
    ),

    AppointmentStatus(
      type: AppointmentStatusType.completed,
      title: AppointmentStatusMapper.title(
        AppointmentStatusType.completed,
      ),
      count: completed,
    ),

    AppointmentStatus(
      type: AppointmentStatusType.cancelled,
      title: AppointmentStatusMapper.title(
        AppointmentStatusType.cancelled,
      ),
      count: cancelled,
    ),
  ];
}

  Future<List<AppointmentItem>> getAppointments({
  required AppointmentServiceType service,
  required AppointmentStatusType status,
}) async {
  final uid = currentUserId;

  if (uid == null) {
    return [];
  }

  final source = _sourceFor(service);

  final snapshot = await _firestore
      .collection(source.collection)
      .where('userId', isEqualTo: uid)
      .get();

  final List<AppointmentItem> items = [];

  for (final doc in snapshot.docs) {
    final data = doc.data();

    final mappedStatus = _statusFromDocument(
      source,
      data,
    );

    if (mappedStatus != status) {
      continue;
    }

    items.add(
      AppointmentItem.fromFirestore(
    doc: doc,
    source: source,
    status: mappedStatus,
)
    );
  }

  items.sort((a, b) {
    final da = a.appointmentDate;
    final db = b.appointmentDate;

    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;

    return db.compareTo(da);
  });

  return items;
}
}