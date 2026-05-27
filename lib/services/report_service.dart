import 'package:cloud_functions/cloud_functions.dart';

class ReportService {
  static Future<void> submitReport({
    required String type,
    required String targetId,
    required String reason,
    String? targetOwnerId,
    String? message,
  }) async {

    final callable =
    FirebaseFunctions.instance.httpsCallable('createReport');

await callable.call({
  "type": type,
  "targetId": targetId,
  "targetOwnerId": ?targetOwnerId,

  "reasonCode": reason,
  "reasonText": reason,
  "message": message ?? "",
});

  }
}
