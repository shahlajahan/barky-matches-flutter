import 'package:cloud_functions/cloud_functions.dart';

class ComplaintService {

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west3');

  /// Create complaint
  static Future<String?> createComplaint({
    required String targetType,
    required String targetId,
    required String category,
    required String description,
    String? title,
  }) async {

    final callable = _functions.httpsCallable('createComplaint');

    final result = await callable.call({
      "targetType": targetType,
      "targetId": targetId,
      "category": category,
      "title": title ?? "",
      "description": description,
    });

    return result.data["complaintId"];
  }
}