import 'package:cloud_functions/cloud_functions.dart';

class ReferralAttributionService {
  const ReferralAttributionService._();

  static Future<bool> attributeCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return false;

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('attributeReferral');
      await callable.call(<String, dynamic>{'referralCode': normalized});
      return true;
    } on FirebaseFunctionsException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
