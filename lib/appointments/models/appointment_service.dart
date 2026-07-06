import 'package:flutter/material.dart';

enum AppointmentServiceType {
  veterinary,
  groomy,
  hotel,
  petTaxi,
  training,
  walking,
}

class AppointmentService {
  final AppointmentServiceType type;

  final String title;

  final IconData icon;

  final int totalCount;

  const AppointmentService({
    required this.type,
    required this.title,
    required this.icon,
    required this.totalCount,
  });

  String get id => type.name;

  bool get hasAppointments => totalCount > 0;
}