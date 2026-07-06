import 'package:flutter/material.dart';

import '../models/appointment_service.dart';

class AppointmentServiceMetadata {
  final String title;

  final IconData icon;

  const AppointmentServiceMetadata({
    required this.title,
    required this.icon,
  });
}

const Map<AppointmentServiceType, AppointmentServiceMetadata>
    appointmentServiceMetadata = {
  AppointmentServiceType.veterinary: AppointmentServiceMetadata(
    title: 'Veterinary',
    icon: Icons.local_hospital,
  ),

  AppointmentServiceType.groomy: AppointmentServiceMetadata(
    title: 'Groomy',
    icon: Icons.content_cut,
  ),

  AppointmentServiceType.hotel: AppointmentServiceMetadata(
    title: 'Pet Hotel',
    icon: Icons.hotel,
  ),

  AppointmentServiceType.petTaxi: AppointmentServiceMetadata(
    title: 'Pet Taxi',
    icon: Icons.local_taxi,
  ),

  AppointmentServiceType.training: AppointmentServiceMetadata(
    title: 'Pet Training',
    icon: Icons.school,
  ),

  AppointmentServiceType.walking: AppointmentServiceMetadata(
    title: 'Pet Walking',
    icon: Icons.directions_walk,
  ),
};