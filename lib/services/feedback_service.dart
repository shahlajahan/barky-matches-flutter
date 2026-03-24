import 'package:cloud_functions/cloud_functions.dart';

class FeedbackService {

  static Future<void> submitFeedback({
    required int rating,
    required String category,
    required String message,
    required String context,
    required String platform,
    required String appVersion,
  }) async {

    final callable = FirebaseFunctions.instance
        .httpsCallable('submitUserFeedback');

    await callable.call({
      "rating": rating,
      "category": category,
      "message": message,
      "context": context,
      "platform": platform,
      "appVersion": appVersion,
    });

  }

}