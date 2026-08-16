const Set<String> marketplaceServiceNotificationTypes = {
  'marketplace_business_delayed',
};

bool isMarketplaceServiceNotificationType(Object? value) {
  final type = value?.toString().toLowerCase().trim() ?? '';
  return marketplaceServiceNotificationTypes.contains(type);
}
