/// All custom Firebase Analytics event names.
///
/// Keep every event name in one place to avoid typos and make refactoring easy.
class AnalyticsEvents {
  AnalyticsEvents._();

  // Authentication
  static const appStarted = 'app_started';
  static const guestModeEntered = 'guest_mode_entered';
  static const userSignup = 'user_signup';
  static const userLogin = 'user_login';
  static const userLogout = 'user_logout';
  static const emailVerified = 'email_verified';

  // Pet Profile
  static const petCreated = 'pet_created';
  static const petUpdated = 'pet_updated';
  static const petDeleted = 'pet_deleted';
  static const petAvatarChanged = 'pet_avatar_changed';

  // Veterinary
  static const vetProfileViewed = 'vet_profile_viewed';
  static const vetBookingStarted = 'vet_booking_started';
  static const vetBookingCompleted = 'vet_booking_completed';
  static const vetBookingCancelled = 'vet_booking_cancelled';
  static const vetReviewAdded = 'vet_review_added';
  static const vetListViewed = 'vet_list_viewed';

  // Grooming
  static const groomingProfileViewed = 'grooming_profile_viewed';
static const groomingBookingStarted = 'grooming_booking_started';
static const groomingBookingCompleted = 'grooming_booking_completed';
static const groomingBookingCancelled = 'grooming_booking_cancelled';
static const groomingReviewAdded = 'grooming_review_added';

  // Pet Hotel
  static const hotelProfileViewed = 'hotel_profile_viewed';
  static const hotelBookingStarted = 'hotel_booking_started';
  static const hotelBookingCompleted = 'hotel_booking_completed';

  // Pet Taxi
  static const taxiRequestStarted = 'taxi_request_started';
  static const taxiPriceReceived = 'taxi_price_received';
  static const taxiRequestCompleted = 'taxi_request_completed';
  static const driverAssigned = 'driver_assigned';
  static const rideCompleted = 'ride_completed';

  // Adoption
  static const adoptionPetViewed = 'adoption_pet_viewed';
  static const adoptionApplicationStarted =
      'adoption_application_started';
  static const adoptionApplicationSubmitted =
      'adoption_application_submitted';

  // Petplore
  static const postCreated = 'post_created';
  static const postLiked = 'post_liked';
  static const postCommented = 'post_commented';
  static const postShared = 'post_shared';
  static const storyViewed = 'story_viewed';
  static const profileFollowed = 'profile_followed';

  // Lost & Found
  static const lostPetReported = 'lost_pet_reported';
  static const foundPetReported = 'found_pet_reported';
  static const lostPetViewed = 'lost_pet_viewed';

  // Chat
  static const chatOpened = 'chat_opened';
  static const messageSent = 'message_sent';
  static const imageSent = 'image_sent';

  // Payment
  static const paymentStarted = 'payment_started';
  static const paymentSuccess = 'payment_success';
  static const paymentFailed = 'payment_failed';
  static const refundRequested = 'refund_requested';

  // Subscription
  static const subscriptionViewed = 'subscription_viewed';
  static const subscriptionStarted = 'subscription_started';
  static const subscriptionSuccess = 'subscription_success';
  static const subscriptionCancelled = 'subscription_cancelled';

  // Dashboard
  static const dashboardOpened = 'dashboard_opened';
  static const invoiceUploaded = 'invoice_uploaded';
  static const settlementRequested = 'settlement_requested';
  static const settlementCompleted = 'settlement_completed';

  // Notifications
  static const notificationReceived = 'notification_received';
  static const notificationOpened = 'notification_opened';
  static const notificationClicked = 'notification_clicked';

  // Search
  static const searchStarted = 'search_started';
  static const searchCompleted = 'search_completed';
  static const filterUsed = 'filter_used';

  // Maps
  static const mapOpened = 'map_opened';
  static const locationPermissionGranted =
      'location_permission_granted';
  static const locationPermissionDenied =
      'location_permission_denied';

  // Errors
  static const bookingFailed = 'booking_failed';
  static const paymentError = 'payment_error';
  static const firebaseError = 'firebase_error';
  static const networkError = 'network_error';

  // Engagement
  static const dailyActive = 'daily_active';
  static const weeklyActive = 'weekly_active';
  static const onboardingCompleted = 'onboarding_completed';
  static const languageChanged = 'language_changed';
}