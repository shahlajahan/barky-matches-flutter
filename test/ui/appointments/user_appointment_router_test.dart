import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/ui/appointments/user_appointment_router.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/appointment_payment_page.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_booking_detail_page.dart';

void main() {
  test('resolves every supported appointment collection', () {
    expect(
      buildUserAppointmentDetailPage(
        collection: 'vet_appointments',
        appointmentId: 'vet-1',
      ),
      isA<AppointmentPaymentPage>(),
    );
    expect(
      buildUserAppointmentDetailPage(
        collection: 'groomy_appointments',
        appointmentId: 'groomy-1',
      ),
      isA<AppointmentPaymentPage>(),
    );
    expect(
      buildUserAppointmentDetailPage(
        collection: 'hotel_bookings',
        appointmentId: 'hotel-1',
      ),
      isA<AppointmentPaymentPage>(),
    );
    expect(
      buildUserAppointmentDetailPage(
        collection: 'pet_taxi_bookings',
        appointmentId: 'taxi-1',
      ),
      isA<PetTaxiBookingDetailPage>(),
    );
  });

  test('fails closed for unknown collections and empty IDs', () {
    expect(
      buildUserAppointmentDetailPage(
        collection: 'unknown_appointments',
        appointmentId: 'appointment-1',
      ),
      isNull,
    );
    expect(
      buildUserAppointmentDetailPage(
        collection: 'pet_taxi_bookings',
        appointmentId: '   ',
      ),
      isNull,
    );
  });
}
