import 'package:cloud_functions/cloud_functions.dart';

import '../models/report_model.dart';

enum ReportSubmitResult {
  success,
  alreadyReported,
  rateLimited,
  targetNotFound,
  unauthenticated,
  unavailable,
  error,
}

class ReportSubmitOutcome {
  final ReportSubmitResult result;
  final String? message;

  const ReportSubmitOutcome(this.result, [this.message]);
}

class ReportReviewOutcome {
  final bool success;
  final bool targetFound;
  final String? errorCode;
  final String? message;

  const ReportReviewOutcome({
    required this.success,
    this.targetFound = true,
    this.errorCode,
    this.message,
  });
}

/// Thin, typed wrapper around the report-related Cloud Functions
/// (createReport, reviewReport, restoreModerationTarget). No Firestore
/// writes happen from the client - every mutation goes through these
/// admin-authorized/rate-limited server endpoints.
class ReportService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west3',
  );

  static Future<ReportSubmitOutcome> submitReport({
    required String targetType,
    required String targetId,
    String? targetOwnerId,
    required ReportReasonCode reasonCode,
    String? description,
  }) async {
    try {
      await _functions.httpsCallable('createReport').call({
        'targetType': targetType,
        'targetId': targetId,
        'targetOwnerId': targetOwnerId,
        'reasonCode': reasonCode.firestoreValue,
        'description': description,
      });
      return const ReportSubmitOutcome(ReportSubmitResult.success);
    } on FirebaseFunctionsException catch (e) {
      return ReportSubmitOutcome(_mapSubmitError(e.code), e.message);
    } catch (e) {
      return ReportSubmitOutcome(ReportSubmitResult.error, e.toString());
    }
  }

  static ReportSubmitResult _mapSubmitError(String code) {
    switch (code) {
      case 'already-exists':
        return ReportSubmitResult.alreadyReported;
      case 'resource-exhausted':
        return ReportSubmitResult.rateLimited;
      case 'not-found':
        return ReportSubmitResult.targetNotFound;
      case 'unauthenticated':
        return ReportSubmitResult.unauthenticated;
      case 'unavailable':
        return ReportSubmitResult.unavailable;
      default:
        return ReportSubmitResult.error;
    }
  }

  static Future<ReportReviewOutcome> reviewReport({
    required String reportId,
    required String action,
    String? moderationAction,
    String? notes,
  }) async {
    try {
      final result = await _functions.httpsCallable('reviewReport').call({
        'reportId': reportId,
        'action': action,
        'moderationAction': ?moderationAction,
        'notes': notes ?? '',
      });
      final data = Map<String, dynamic>.from(result.data as Map? ?? {});
      return ReportReviewOutcome(
        success: true,
        targetFound: data['targetFound'] as bool? ?? true,
      );
    } on FirebaseFunctionsException catch (e) {
      return ReportReviewOutcome(
        success: false,
        errorCode: e.code,
        message: e.message,
      );
    } catch (e) {
      return ReportReviewOutcome(
        success: false,
        errorCode: 'unknown',
        message: e.toString(),
      );
    }
  }

  static Future<ReportReviewOutcome> restoreModerationTarget({
    required String targetType,
    required String targetId,
    String? notes,
  }) async {
    try {
      await _functions.httpsCallable('restoreModerationTarget').call({
        'targetType': targetType,
        'targetId': targetId,
        'notes': notes ?? '',
      });
      return const ReportReviewOutcome(success: true);
    } on FirebaseFunctionsException catch (e) {
      return ReportReviewOutcome(
        success: false,
        errorCode: e.code,
        message: e.message,
      );
    } catch (e) {
      return ReportReviewOutcome(
        success: false,
        errorCode: 'unknown',
        message: e.toString(),
      );
    }
  }
}
