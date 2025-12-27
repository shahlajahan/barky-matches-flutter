import 'dart:async'; // اضافه کردن این خط برای دسترسی به StreamSubscription

StreamSubscription? dogsSubscription;
StreamSubscription? notificationsSubscription;

void stopListeners() {
  dogsSubscription?.cancel();
  dogsSubscription = null; // پاک کردن اشاره‌گر
  notificationsSubscription?.cancel();
  notificationsSubscription = null; // پاک کردن اشاره‌گر
  print('Globals - All listeners stopped');
}