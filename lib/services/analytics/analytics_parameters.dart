/// Standard parameter keys used across analytics events.


class AnalyticsParameters {
  AnalyticsParameters._();

  // User
  static const userType = 'user_type';

  // Business
  static const businessType = 'business_type';
  static const businessId = 'business_id';

  // Location
  static const city = 'city';
  static const country = 'country';

  // App
  static const language = 'language';
  static const platform = 'platform';
  static const appVersion = 'app_version';

  // Pet
  static const petType = 'pet_type';
  static const breed = 'breed';
  static const age = 'age';
  static const gender = 'gender';

  // Booking
  static const appointmentType = 'appointment_type';
  static const vetId = 'vet_id';

  // Payment
  static const amount = 'amount';
  static const currency = 'currency';
  static const paymentProvider = 'payment_provider';

  // Search
  static const keyword = 'keyword';
  static const category = 'category';
}