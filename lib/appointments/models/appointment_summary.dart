import 'appointment_service.dart';
import 'package:flutter/material.dart';

import 'appointment_service.dart';

class AppointmentSummary {
  final AppointmentServiceType serviceType;

  final int total;

  final int pending;

  final int approved;

  final int completed;

  final int cancelled;

  const AppointmentSummary({
    required this.serviceType,
    required this.total,
    required this.pending,
    required this.approved,
    required this.completed,
    required this.cancelled,
  });

  bool get hasAppointments => total > 0;

  AppointmentService toService({
    required String title,
    required IconData icon,
  }) {
    return AppointmentService(
      type: serviceType,
      title: title,
      icon: icon,
      totalCount: total,
    );
  }
}