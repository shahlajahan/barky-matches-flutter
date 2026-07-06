import '../models/appointment_service.dart';

class AppointmentSource {
  final AppointmentServiceType serviceType;

  final String collection;

  final String businessNameField;

  final String petNameField;

  final String petTypeField;

  final String priceField;

  final String dateField;

  final String statusField;

  const AppointmentSource({
    required this.serviceType,
    required this.collection,
    required this.businessNameField,
    required this.petNameField,
    required this.petTypeField,
    required this.priceField,
    required this.dateField,
    required this.statusField,
  });
}

const appointmentSources = [

  AppointmentSource(
    serviceType: AppointmentServiceType.veterinary,
    collection: 'vet_appointments',
    businessNameField: 'businessName',
    petNameField: 'petName',
    petTypeField: 'petType',
    priceField: 'price',
    dateField: 'scheduledAt',
    statusField: 'status',
  ),

  AppointmentSource(
    serviceType: AppointmentServiceType.groomy,
    collection: 'groomy_appointments',
    businessNameField: 'businessName',
    petNameField: 'petName',
    petTypeField: 'petType',
    priceField: 'price',
    dateField: 'scheduledAt',
    statusField: 'status',
  ),

  AppointmentSource(
    serviceType: AppointmentServiceType.hotel,
    collection: 'hotel_bookings',
    businessNameField: 'businessName',
    petNameField: 'petName',
    petTypeField: 'petType',
    priceField: 'totalPrice',
    dateField: 'checkInDate',
    statusField: 'status',
  ),

  AppointmentSource(
    serviceType: AppointmentServiceType.petTaxi,
    collection: 'pet_taxi_bookings',
    businessNameField: 'businessName',
    petNameField: 'petName',
    petTypeField: 'petType',
    priceField: 'finalPrice',
    dateField: 'scheduledAt',
    statusField: 'status',
  ),
];