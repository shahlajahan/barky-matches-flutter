import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

Future<void> getAppCheckToken() async {
  try {
    print('GetToken - در حال گرفتن توکن App Check');
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
    final token = await FirebaseAppCheck.instance.getToken(true);
    if (token != null) {
      print('GetToken - Debug Token: $token');
    } else {
      print('GetToken - توکنی دریافت نشد');
    }
  } catch (e, stackTrace) {
    print('GetToken - خطا در گرفتن توکن: $e');
    print('GetToken - StackTrace: $stackTrace');
  }
}

void main() {
  getAppCheckToken();
}