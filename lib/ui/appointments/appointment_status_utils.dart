import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class AppointmentStatusUtils {
  const AppointmentStatusUtils._();

  static String statusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.appointmentStatusPending;
      case 'awaiting_payment':
        return l10n.appointmentStatusAwaitingPayment;
      case 'confirmed':
        return l10n.appointmentStatusConfirmed;
      case 'confirmed_paid':
        return l10n.appointmentStatusConfirmedPaid;
      case 'payment_expired':
        return l10n.appointmentStatusPaymentExpired;
      case 'rejected':
        return l10n.appointmentStatusRejected;
      case 'completed':
        return l10n.appointmentStatusCompleted;
      case 'cancelled_by_user':
        return l10n.appointmentStatusCancelledByUser;
      case 'cancelled_by_vet':
        return l10n.appointmentStatusCancelledByVet;
      case 'expired':
        return l10n.appointmentStatusExpired;
      default:
        return status;
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'awaiting_payment':
        return Colors.deepOrange;
      case 'confirmed':
        return Colors.blue;
      case 'confirmed_paid':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'completed':
        return Colors.teal;
      case 'payment_expired':
      case 'cancelled_by_user':
      case 'cancelled_by_vet':
      case 'expired':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  static String paymentStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'paid':
        return l10n.paidStatusLabel;
      case 'refunded':
        return l10n.refundCompletedStatusLabel;
      case 'pending':
      case 'payment_pending':
        return l10n.pendingStatusLabel;
      case 'unpaid':
        return l10n.unpaidStatusLabel;
      case 'not_required':
        return l10n.paymentNotRequiredStatusLabel;
      case 'expired':
        return l10n.appointmentStatusPaymentExpired;
      default:
        return status;
    }
  }

  static Color paymentStatusColor(String status) {
    switch (status) {
      case 'paid':
      case 'refunded':
        return Colors.green;
      case 'pending':
      case 'payment_pending':
        return Colors.orange;
      case 'not_required':
        return Colors.blueGrey;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  static String refundStatusLabel({
    required bool refundRequired,
    required String refundStatus,
    required AppLocalizations l10n,
  }) {
    final normalized = _normalizeRefundStatus(refundStatus);

    if (!refundRequired && normalized.isEmpty) {
      return '';
    }

    switch (normalized) {
      case 'pending_manual_review':
        return l10n.refundUnderReviewStatusLabel;
      case 'refund_requested':
      case 'refund_processing':
        return l10n.refundRequestedStatusLabel;
      case 'refunded':
        return l10n.refundCompletedStatusLabel;
      case 'refund_failed':
        return l10n.refundFailedStatusLabel;
      case 'rejected':
      case 'refund_rejected':
        return l10n.refundRejectedStatusLabel;
      case 'no_refund_required':
        return l10n.noRefundRequiredStatusLabel;
      case 'not_started':
        return l10n.refundNotProcessedStatusLabel;
      default:
        return refundRequired
            ? l10n.refundUnderReviewStatusLabel
            : refundStatus;
    }
  }

  static Color refundStatusColor({
    required bool refundRequired,
    required String refundStatus,
  }) {
    switch (_normalizeRefundStatus(refundStatus)) {
      case 'refunded':
        return Colors.green;
      case 'refund_failed':
        return Colors.red;
      case 'rejected':
      case 'refund_rejected':
        return Colors.red;
      case 'refund_requested':
      case 'refund_processing':
        return Colors.blue;
      case 'pending_manual_review':
      case 'not_started':
        return Colors.orange;
      case 'no_refund_required':
        return Colors.blueGrey;
      default:
        return refundRequired ? Colors.orange : Colors.grey;
    }
  }

  static bool requiresManualRefundReview(Map<String, dynamic> data) {
    return _normalizeRefundStatus(data['refundStatus']?.toString() ?? '') ==
        'pending_manual_review';
  }

  static bool isWithin24Hours(DateTime? scheduledAt, {DateTime? now}) {
    if (scheduledAt == null) return false;
    final base = now ?? DateTime.now();
    final hours = scheduledAt.difference(base).inMinutes / 60;
    return hours < 24;
  }

  static double? hoursBeforeAppointment({
    required DateTime? scheduledAt,
    required DateTime? cancelledAt,
  }) {
    if (scheduledAt == null || cancelledAt == null) return null;
    return scheduledAt.difference(cancelledAt).inMinutes / 60;
  }

  static String _normalizeRefundStatus(String refundStatus) {
    final value = refundStatus.trim().toLowerCase();
    switch (value) {
      case 'success':
        return 'refunded';
      case 'not_required':
        return 'no_refund_required';
      case 'reject':
        return 'refund_rejected';
      default:
        return value;
    }
  }
}
