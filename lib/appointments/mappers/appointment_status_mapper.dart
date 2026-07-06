import '../models/appointment_status.dart';

class AppointmentStatusMapper {
  const AppointmentStatusMapper._();

  static AppointmentStatusType fromFirestore(String? status) {
    switch ((status ?? '').toLowerCase()) {
      // Pending
      case 'pending':
      case 'awaiting_payment':
      case 'pending_payment':
      case 'payment_pending':
      case 'pending_review':
        return AppointmentStatusType.pending;

      // Approved
      case 'approved':
      case 'confirmed':
      case 'accepted':
        return AppointmentStatusType.approved;

      // Completed
      case 'completed':
      case 'finished':
      case 'done':
        return AppointmentStatusType.completed;

      // Cancelled
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'payment_expired':
      case 'expired':
        return AppointmentStatusType.cancelled;

      default:
        return AppointmentStatusType.pending;
    }
  }

  static String title(AppointmentStatusType type) {
    switch (type) {
      case AppointmentStatusType.pending:
        return 'Pending';

      case AppointmentStatusType.approved:
        return 'Approved';

      case AppointmentStatusType.completed:
        return 'Completed';

      case AppointmentStatusType.cancelled:
        return 'Cancelled';
    }
  }

  static bool matches(
    AppointmentStatusType type,
    String? firestoreStatus,
  ) {
    return fromFirestore(firestoreStatus) == type;
  }
}