import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/vet/appointment_payment_page.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_booking_detail_page.dart';

/// Resolves user-facing appointment documents to the existing detail pages.
/// Unknown collections intentionally fail closed instead of being treated as a
/// different service.
Widget? buildUserAppointmentDetailPage({
  required String collection,
  required String appointmentId,
}) {
  final normalizedCollection = collection.trim();
  final normalizedId = appointmentId.trim();
  if (normalizedId.isEmpty) return null;

  switch (normalizedCollection) {
    case 'pet_taxi_bookings':
      return PetTaxiBookingDetailPage(bookingId: normalizedId);
    case 'vet_appointments':
      return _buildAppointmentPaymentPage(
        appointmentId: normalizedId,
        collection: normalizedCollection,
        appointmentType: 'veterinary',
        updateStatus: 'updateVetAppointmentStatus',
        createOrder: 'createAppointmentOrder',
        verifyPayment: 'verifyPayment',
        service: 'Veterinary service',
        business: 'Vet clinic',
        label: 'Clinic',
      );
    case 'groomy_appointments':
      return _buildAppointmentPaymentPage(
        appointmentId: normalizedId,
        collection: normalizedCollection,
        appointmentType: 'grooming',
        updateStatus: 'updateGroomyAppointmentStatus',
        createOrder: 'createAppointmentOrder',
        verifyPayment: 'verifyPayment',
        service: 'Grooming service',
        business: 'Grooming studio',
        label: 'Groomy',
      );
    case 'hotel_bookings':
      return _buildAppointmentPaymentPage(
        appointmentId: normalizedId,
        collection: normalizedCollection,
        appointmentType: 'pet_hotel',
        updateStatus: 'updateHotelBookingStatus',
        createOrder: 'createHotelBookingOrder',
        verifyPayment: 'verifyHotelBookingPayment',
        service: 'Hotel stay',
        business: 'Pet hotel',
        label: 'Hotel',
      );
    default:
      return null;
  }
}

AppointmentPaymentPage _buildAppointmentPaymentPage({
  required String appointmentId,
  required String collection,
  required String appointmentType,
  required String updateStatus,
  required String createOrder,
  required String verifyPayment,
  required String service,
  required String business,
  required String label,
}) {
  return AppointmentPaymentPage(
    appointmentId: appointmentId,
    appointmentCollection: collection,
    appointmentType: appointmentType,
    updateStatusFunctionName: updateStatus,
    createOrderFunctionName: createOrder,
    verifyPaymentFunctionName: verifyPayment,
    serviceFallbackName: service,
    businessFallbackName: business,
    businessInfoLabel: label,
  );
}
