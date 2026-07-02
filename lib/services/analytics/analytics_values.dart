/// Standard analytics values used across the app.
///
/// Keep all common analytics values here to avoid typos
/// and inconsistent reporting in Firebase Analytics.
class AnalyticsValues {
  AnalyticsValues._();

  // ===========================================================================
  // User Types
  // ===========================================================================

  static const guest = 'guest';
  static const user = 'user';
  static const business = 'business';
  static const admin = 'admin';

  // ===========================================================================
  // Business Types
  // ===========================================================================

  static const vet = 'vet';
  static const grooming = 'grooming';
  static const petHotel = 'pet_hotel';
  static const petTaxi = 'pet_taxi';
  static const petShop = 'pet_shop';
  static const adoptionCenter = 'adoption_center';

  // ===========================================================================
  // Pet Types
  // ===========================================================================

  static const dog = 'dog';
  static const cat = 'cat';
  static const bird = 'bird';
  static const rabbit = 'rabbit';
  static const hamster = 'hamster';
  static const fish = 'fish';
  static const reptile = 'reptile';
  static const other = 'other';

  // ===========================================================================
  // Gender
  // ===========================================================================

  static const male = 'male';
  static const female = 'female';
  static const unknown = 'unknown';

  // ===========================================================================
  // Appointment Types
  // ===========================================================================

  static const clinic = 'clinic';
  static const homeVisit = 'home_visit';
  static const online = 'online';

  // ===========================================================================
  // Payment Providers
  // ===========================================================================

  static const iyzico = 'iyzico';
  static const eft = 'eft';
  static const cash = 'cash';

  // ===========================================================================
  // Payment Status
  // ===========================================================================

  static const success = 'success';
  static const failed = 'failed';
  static const pending = 'pending';

  // ===========================================================================
  // Currency
  // ===========================================================================

  static const tryCurrency = 'TRY';
  static const usd = 'USD';
  static const eur = 'EUR';

  // ===========================================================================
  // Platforms
  // ===========================================================================

  static const android = 'android';
  static const ios = 'ios';
  static const web = 'web';
  static const macos = 'macos';
  static const windows = 'windows';

  // ===========================================================================
  // Languages
  // ===========================================================================

  static const tr = 'tr';
  static const en = 'en';
  static const fa = 'fa';
  static const ru = 'ru';
}