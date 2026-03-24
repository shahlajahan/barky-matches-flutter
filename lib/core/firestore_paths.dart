// lib/core/firestore_paths.dart
class FirestorePaths {
  // Root collections
  static const String users = 'users';
  static const String notifications = 'notifications';
  static const String businessRequests = 'business_requests';

  // ✅ New unified businesses root
  static const String businesses = 'businesses';

  // Legacy (for migration window only)
  static const String adoptionCentersLegacy = 'adoption_centers';

  // Business types (Firestore string values)
  static const String typeAdoptionCenter = 'adoption_center';
  static const String typePetShop = 'pet_shop';
  static const String typeGroomer = 'groomer';
  static const String typePetHotel = 'pet_hotel';
  static const String typeTrainer = 'trainer';
  static const String typeVeterinarian = 'veterinarian';

  // Business status values
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  // Subcollections under businesses/{businessId}
  static const String scDogs = 'dogs';
  static const String scProducts = 'products';
  static const String scAppointments = 'appointments';
  static const String scServices = 'services';
  static const String scReservations = 'reservations';
}