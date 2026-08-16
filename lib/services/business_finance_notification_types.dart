const Set<String> businessFinanceNotificationTypes = {
  'finance_waiting_period_started',
};

bool isBusinessFinanceNotificationType(Object? value) {
  final type = value?.toString().toLowerCase().trim() ?? '';
  return businessFinanceNotificationTypes.contains(type);
}
