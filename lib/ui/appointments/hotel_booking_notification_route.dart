enum HotelBookingNotificationDestination { payment, detail }

const Set<String> hotelBookingTerminalStatuses = {
  'rejected',
  'cancelled_by_user',
  'cancelled_by_hotel',
  'completed',
  'payment_expired',
  'expired',
};

const Set<String> hotelBookingOwnerCancellableStatuses = {
  'pending',
  'awaiting_payment',
  'confirmed',
  'confirmed_paid',
};

String normalizeHotelBookingStatus(String? status) {
  return (status ?? '').trim().toLowerCase();
}

HotelBookingNotificationDestination hotelBookingResponseDestination(
  String? status,
) {
  return normalizeHotelBookingStatus(status) == 'awaiting_payment'
      ? HotelBookingNotificationDestination.payment
      : HotelBookingNotificationDestination.detail;
}

bool hotelBookingResponseOpensPayment(String? status) {
  return hotelBookingResponseDestination(status) ==
      HotelBookingNotificationDestination.payment;
}

bool hotelBookingCanShowPaymentAction(String? status) {
  return normalizeHotelBookingStatus(status) == 'awaiting_payment';
}

bool hotelBookingCanShowCancelAction(String? status) {
  final normalizedStatus = normalizeHotelBookingStatus(status);
  return hotelBookingOwnerCancellableStatuses.contains(normalizedStatus) &&
      !hotelBookingTerminalStatuses.contains(normalizedStatus);
}
