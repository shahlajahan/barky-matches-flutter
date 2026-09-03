import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dog.dart';
import 'notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/core/debug/firestore_permission_diagnostics.dart';
import 'package:barky_matches_fixed/firestore_recovery.dart';
import 'package:barky_matches_fixed/firebase_options.dart';
import 'package:barky_matches_fixed/debug/auth_trap.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:barky_matches_fixed/ui/business/partner_intake_context.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'main.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:barky_matches_fixed/subscription/models/user_subscription.dart';
import 'package:barky_matches_fixed/subscription/helpers/subscription_access.dart';
import 'package:barky_matches_fixed/subscription/models/subscription_plan.dart';
import 'package:barky_matches_fixed/utils/location_utils.dart';

import 'package:barky_matches_fixed/subscription/models/cart_item.dart';
import 'package:barky_matches_fixed/services/firestore_readiness_gate.dart';
import 'package:barky_matches_fixed/services/fcm_token_service.dart';
import 'package:barky_matches_fixed/ui/orders/order_detail_page.dart';
import 'package:barky_matches_fixed/ui/business/finance/business_revenue_dashboard.dart';
import 'package:barky_matches_fixed/utils/firestore_cleaner.dart';
import 'offers_manager.dart';
import 'package:barky_matches_fixed/models/product.dart';
import 'package:barky_matches_fixed/dogs_box_manager.dart';
import 'package:barky_matches_fixed/services/dog_sync_service.dart';
import 'package:barky_matches_fixed/services/analytics/analytics_service.dart';
import 'package:barky_matches_fixed/services/analytics/analytics_values.dart';
import 'package:barky_matches_fixed/services/marketplace_order_notification_types.dart';
import 'package:barky_matches_fixed/services/business_finance_notification_types.dart';
import 'package:barky_matches_fixed/services/marketplace_service_notification_types.dart';
import 'package:barky_matches_fixed/services/appointment_notification_navigation_guard.dart';
import 'package:barky_matches_fixed/appointments/models/appointment_service.dart';
import 'package:barky_matches_fixed/appointments/models/appointment_status.dart';
import 'package:barky_matches_fixed/ui/appointments/hotel_booking_notification_route.dart';

/// Selects a single canonical approved business owned by [ownerUid].
/// Published businesses are preferred when that field is present. A caller
/// must handle null as either no match or an ambiguous match.
String? selectCanonicalOwnedBusinessId(
  String ownerUid,
  Iterable<Map<String, dynamic>> businesses,
) {
  final owned = businesses.where(
    (business) => business['ownerUid']?.toString() == ownerUid,
  );
  final approved = owned
      .where((business) => business['status']?.toString() == 'approved')
      .toList();
  if (approved.isEmpty) return null;

  final published = approved
      .where((business) => business['published'] == true)
      .toList();
  final preferred = published.isNotEmpty ? published : approved;
  if (preferred.length != 1) return null;
  return preferred.single['__documentId']?.toString();
}

bool isValidStoredBusinessReference(
  String ownerUid,
  String storedBusinessId,
  Map<String, dynamic> business,
) {
  return storedBusinessId.isNotEmpty &&
      business['ownerUid']?.toString() == ownerUid;
}

enum BusinessSubPage {
  none,
  appointment,
  addProduct,
  addService,
  addServiceDetail,
  editProduct,
  petshopProducts,
  petshopOrders,
  petshopReturns,
  petshopSettings,
  petshopMedia,
}

enum HomeOverlay { none, parkPlaydateEntry, notifications }

/// Outcome of restoring a persisted Firebase session at startup.
///
/// A single value rather than a pair of booleans, so the invalid combinations
/// are unrepresentable by construction: restoration cannot be simultaneously
/// restoring and failed, nor authenticated and unauthenticated, and a failure
/// can never be read as a confirmed sign-out.
enum AuthRestorationPhase {
  /// No auth event has arrived yet and nothing has failed.
  restoring,

  /// A Firebase user (including an anonymous/guest user) is present.
  authenticated,

  /// The auth stream successfully emitted null — a real signed-out state.
  /// This is the only outcome that may route to WelcomePage.
  unauthenticated,

  /// The stream errored, or the defensive timeout fired, before any
  /// successful emission. The user's actual auth state is still unknown, so
  /// this must never be treated as signed out.
  failed,
}

enum StartupPhase {
  coldStart,
  firebaseInitialized,
  authUserDetected,
  tokenStable,
  firebaseInstallationsReady,
  firestoreReady,
  noncriticalReadsAllowed,
  degradedMode,
}

enum ProfileSubPage {
  none,
  savedParks,
  adoptionInbox,
  businessRegister,
  appointments,
  myAppointments,
  myOrders,
  feedback,
  privacy,
  reportProblem,
  upgrade,
  changePassword,
  deleteAccount,
  businessDashboard,
  businessStatus,
  helpCenter,
  faq,
  appointmentStatus,
  appointmentHistory,
  creatorDashboard,
}

enum GlobalRoute { none, feedback, reportProblem, privacy }

class BusinessRegistrationIntent {
  const BusinessRegistrationIntent({
    this.initialSector,
    this.partnerIntakeContext,
  });

  final String? initialSector;
  final PartnerIntakeContext? partnerIntakeContext;

  bool get isPartnerIntake => partnerIntakeContext?.isValid == true;
}

class AppState with ChangeNotifier {
  static const Duration _firestoreReadTimeout = Duration(seconds: 20);
  static const Duration _startupProbeTimeout = Duration(seconds: 12);
  static const DogSyncService _dogSyncService = DogSyncService();

  bool _disposed = false;

  @visibleForTesting
  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  bool _showBottomNav = true;

  bool get showBottomNav => _showBottomNav;
  int unreadChatsCount = 0;

  bool get shouldShowAds {
    return !_subscription.hasValidPaidAccess && !isAdmin;
  }

  bool showGuestFeatureGate = false;

  //GuestFeatureGateData? activeGuestFeatureGate;

  void openGuestFeatureGate() {
    showGuestFeatureGate = true;
    notifyListeners();
  }

  void closeGuestFeatureGate() {
    showGuestFeatureGate = false;
    notifyListeners();
  }

  void setBottomNavVisibility(bool visible) {
    if (_showBottomNav == visible) return;

    _showBottomNav = visible;
    notifyListeners();
  }

  // ─────────────────────────────
  // 🌍 LANGUAGE / LOCALE
  // ─────────────────────────────
  //
  // AppState is the canonical owner of the active locale. UI language
  // selectors must go through [setLocale] and must never read or write the
  // preference key themselves.

  /// The single SharedPreferences key for the user's language choice.
  ///
  /// Deliberately kept as `'language'` — the key already shipped in released
  /// versions (previously read/written directly by WelcomePage). Renaming it
  /// would strand every existing user's saved choice.
  static const String localePreferenceKey = 'language';

  /// The application's supported languages. Must stay in sync with
  /// `AppLocalizations.supportedLocales`.
  static const List<String> supportedLanguageCodes = <String>[
    'en',
    'fa',
    'ru',
    'tr',
  ];

  static const String fallbackLanguageCode = 'en';

  /// Reduces an arbitrary value to a supported language code, or `null`.
  ///
  /// Accepts a bare code or a regional variant in either separator style, so
  /// `tr_TR`, `fa-IR`, `en_US`, `ru_RU` all normalize to their base language.
  /// Anything malformed, empty, non-String, or unsupported yields `null` so
  /// callers can fall through rather than adopting a broken value.
  static String? normalizeLanguageCode(Object? raw) {
    if (raw is! String) return null;

    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    final base = trimmed.split(RegExp(r'[_-]')).first;
    return supportedLanguageCodes.contains(base) ? base : null;
  }

  /// Pure startup resolution: saved preference, else device locale, else
  /// English. Kept free of plugin/platform access so it is directly testable.
  ///
  /// [deviceLocales] is the platform's ordered preference list; the first
  /// supported entry wins. Country, timezone, SIM and IP are deliberately not
  /// consulted — only an explicit choice or the device language may select a
  /// language.
  static String resolveInitialLanguageCode({
    Object? savedValue,
    List<Locale> deviceLocales = const <Locale>[],
  }) {
    final saved = normalizeLanguageCode(savedValue);
    if (saved != null) return saved;

    for (final locale in deviceLocales) {
      final code = normalizeLanguageCode(locale.languageCode);
      if (code != null) return code;
    }

    return fallbackLanguageCode;
  }

  /// Resolves the startup language, reading the saved preference. Called
  /// before `runApp` so the first frame already paints the correct language —
  /// there is no English flash and no extra loading state.
  static Future<String> loadInitialLanguageCode({
    List<Locale>? deviceLocales,
  }) async {
    Object? saved;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getString(localePreferenceKey);
    } catch (e) {
      // A preferences failure must never block startup; fall through to the
      // device locale.
      debugPrint('⚠️ Could not read saved language: $e');
      saved = null;
    }

    return resolveInitialLanguageCode(
      savedValue: saved,
      deviceLocales:
          deviceLocales ?? WidgetsBinding.instance.platformDispatcher.locales,
    );
  }

  Locale _locale = const Locale(fallbackLanguageCode);

  Locale get locale => _locale;

  bool get isGuestUser => isGuest;

  void setGuestUser() {
    debugPrint("👤 ENTER GUEST MODE");

    _currentUserId = 'guest';

    _username = null;
    _currentUserName = null;
    _userRole = null;

    // ---------- USER DATA ----------
    _myDogs.clear();
    _allDogs.clear();
    _discoveryDogs.clear();
    _invalidateAllDogsView();

    _favoriteDogs.clear();
    favoriteDogsNotifier.value = [];

    _favoriteParks.clear();

    // ---------- PROFILE ----------
    editingDog = null;

    playmateProfileUserId = null;
    playmateDogsSnapshot = null;

    // ---------- BUSINESS ----------
    clearBusinessState();

    // ---------- STATE ----------
    _isUserInitialized = true;
    _isUserProfileReady = true;

    notifyListeners();
  }

  void _activateGuestSessionState() {
    _clearAuthMemoryState();
    _suppressGuestModeOnce = false;
    _hasSeenAuthenticatedUser = true;
    setGuestUser();
    if (Hive.isBoxOpen('currentUserBox')) {
      unawaited(
        Hive.box<String>('currentUserBox').put('currentUserId', 'guest'),
      );
    }
    FirestoreReadinessGate.instance.markAuthStabilized('guest');
    _completeNoncriticalGate(false);
  }

  Future<void> enterGuestMode() async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;

    if (currentUser?.isAnonymous == true) {
      _activateGuestSessionState();
      return;
    }

    if (currentUser != null && !currentUser.isAnonymous) {
      _suppressGuestModeOnce = true;
      await auth.signOut();
    }

    if (auth.currentUser == null) {
      final credential = await auth.signInAnonymously();
      if (credential.user == null) {
        throw StateError('Anonymous sign-in returned null user');
      }
    }

    if (auth.currentUser?.isAnonymous != true) {
      throw StateError('Anonymous session was not established');
    }

    _activateGuestSessionState();
  }

  /// The canonical path for an explicit, user-triggered language change.
  ///
  /// Distinct from startup initialization ([resolveInitialLanguageCode]),
  /// which never writes: only a deliberate user selection is persisted.
  ///
  /// State is updated and listeners notified synchronously so MaterialApp
  /// rebuilds immediately, then the choice is persisted. Callers should await
  /// this so the write is not lost. An unsupported code is ignored rather than
  /// applied, so a bad value can never strand the UI in an unlocalized state.
  Future<void> setLocale(String languageCode) async {
    final normalized = normalizeLanguageCode(languageCode);
    if (normalized == null) {
      debugPrint('⚠️ Ignoring unsupported language code: $languageCode');
      return;
    }

    if (_locale.languageCode != normalized) {
      _locale = Locale(normalized);
      // notifyListeners() is disposal-guarded above.
      notifyListeners();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(localePreferenceKey, normalized);
    } catch (e) {
      // The in-memory change stands; only persistence failed.
      debugPrint('❌ Failed to persist language "$normalized": $e');
    }
  }

  bool get isGuest => _currentUserId == 'guest';
  // ─────────────────────────────────────
  // HOME OVERLAY (ParkPlaydate Entry)
  // ─────────────────────────────────────
  HomeOverlay _homeOverlay = HomeOverlay.none;
  Map<String, dynamic>? _selectedPark;

  HomeOverlay get homeOverlay => _homeOverlay;
  Map<String, dynamic>? get selectedPark => _selectedPark;

  String? _selectedServiceTitle;
  String? get selectedServiceTitle => _selectedServiceTitle;

  // ─────────────────────────────────────
  // 🔁 LEGACY PARK API (DO NOT REMOVE)
  // ─────────────────────────────────────
  Map<String, dynamic>? get park => _selectedPark;

  Map<String, dynamic>? _editingServiceData;

  Map<String, dynamic>? get editingServiceData => _editingServiceData;

  List<String> _existingServices = [];

  List<String> get existingServices => _existingServices;

  String? _editingServiceId;

  String? get editingServiceId => _editingServiceId;

  void setExistingServices(List<String> list) {
    _existingServices = list;
    notifyListeners();
  }

  void openEditService(String id, Map<String, dynamic> data) {
    _editingServiceId = id;
    _editingServiceData = data;
    _businessSubPage = BusinessSubPage.addServiceDetail;
    notifyListeners();
  }

  void openAddServiceDetail(
    String title, {

    String? serviceId,

    Map<String, dynamic>? existingData,
  }) {
    _selectedServiceTitle = title;

    _editingServiceId = serviceId;

    _editingServiceData = existingData;

    _businessSubPage = BusinessSubPage.addServiceDetail;

    notifyListeners();
  }

  void selectSavedPark(Map<String, dynamic> park) {
    _selectedPark = park;
    notifyListeners();
  }

  void clearSelectedParkLegacy() {
    _selectedPark = null;
    notifyListeners();
  }

  final List<CartItem> _cartItems = [];

  List<CartItem> get cartItems => List.unmodifiable(_cartItems);

  void closeBusinessSubPage() {
    _editingProduct = null;
    _businessSubPage = BusinessSubPage.none;

    /// 🔥 RESET EDIT STATE
    _editingServiceId = null;
    _editingServiceData = null;

    notifyListeners();
  }

  void openAddProduct() {
    _editingProduct = null;
    _businessSubPage = BusinessSubPage.addProduct;
    notifyListeners();
  }

  void openEditProduct(Product product) {
    _editingProduct = product;
    _businessSubPage = BusinessSubPage.editProduct;
    notifyListeners();
  }

  void openPetShopProducts() {
    _businessSubPage = BusinessSubPage.petshopProducts;
    notifyListeners();
  }

  void openPetShopOrders() {
    _businessSubPage = BusinessSubPage.petshopOrders;
    notifyListeners();
  }

  void openPetShopReturns() {
    _businessSubPage = BusinessSubPage.petshopReturns;
    notifyListeners();
  }

  void openPetShopSettings() {
    _businessSubPage = BusinessSubPage.petshopSettings;
    notifyListeners();
  }

  /// Opens the Pet Shop Business Media sub-page (logo, cover, gallery).
  void openPetShopMedia() {
    _businessSubPage = BusinessSubPage.petshopMedia;
    notifyListeners();
  }

  void addToCart(CartItem item) {
    debugPrint("🧠 APPSTATE ADD → ${item.allowedCarrierCodes}");
    final index = _cartItems.indexWhere((e) => e.productId == item.productId);

    if (index >= 0) {
      final existing = _cartItems[index];

      _cartItems[index] = existing.copyWith(
        quantity: existing.quantity + 1,

        // 🔥 اینا رو اضافه کن (خیلی مهم)
        product: item.product,
        imageUrl: item.imageUrl,
        allowedCarrierCodes: item.allowedCarrierCodes,
        price: item.price,
        name: item.name,
        shopId: item.shopId,
      );
    } else {
      _cartItems.add(item);
    }

    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cartItems.removeWhere((e) => e.productId == productId);
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  void removePurchasedCartItems(Iterable<CartItem> purchasedItems) {
    for (final purchased in purchasedItems) {
      final index = _cartItems.indexWhere(
        (item) => item.productId == purchased.productId,
      );
      if (index == -1) continue;

      final remaining = _cartItems[index].quantity - purchased.quantity;
      if (remaining > 0) {
        _cartItems[index] = _cartItems[index].copyWith(quantity: remaining);
      } else {
        _cartItems.removeAt(index);
      }
    }
    notifyListeners();
  }

  void updateCartQuantity(String productId, int qty) {
    final index = _cartItems.indexWhere((e) => e.productId == productId);

    if (index == -1) return;

    _cartItems[index] = _cartItems[index].copyWith(quantity: qty);

    notifyListeners();
  }

  double get cartTotal {
    return _cartItems.fold(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );
  }

  String? _handledResultRequestId;

  bool hasHandledResult(String requestId) {
    return _handledResultRequestId == requestId;
  }

  void markResultHandled(String requestId) {
    _handledResultRequestId = requestId;
  }

  void openBusinessRegister() {
    openBusinessRegisterWithInitialSector();
  }

  String? _businessRegistrationInitialSector;
  BusinessRegistrationIntent? _pendingBusinessRegistrationIntent;

  String? get businessRegistrationInitialSector =>
      _businessRegistrationInitialSector;

  void setPendingBusinessRegistrationIntent({
    String? initialSector,
    PartnerIntakeContext? partnerIntakeContext,
  }) {
    _pendingBusinessRegistrationIntent = BusinessRegistrationIntent(
      initialSector: initialSector,
      partnerIntakeContext: partnerIntakeContext,
    );
  }

  BusinessRegistrationIntent? consumePendingBusinessRegistrationIntent() {
    final intent = _pendingBusinessRegistrationIntent;
    _pendingBusinessRegistrationIntent = null;
    return intent;
  }

  PartnerIntakeContext? _businessRegistrationPartnerIntakeContext;

  PartnerIntakeContext? get businessRegistrationPartnerIntakeContext =>
      _businessRegistrationPartnerIntakeContext;

  void openBusinessRegisterWithInitialSector({
    String? initialSector,
    PartnerIntakeContext? partnerIntakeContext,
  }) {
    _businessRegistrationInitialSector = initialSector;
    _businessRegistrationPartnerIntakeContext = partnerIntakeContext;
    _profileSubPage = ProfileSubPage.businessRegister;
    notifyListeners();
  }

  bool _ignoreNextClose = false;
  String? activeLostDogId;
  String? activeVaccineBusinessId;
  String? activeVaccinePatientId;
  String? activeVaccineId;
  String? activeVaccinePetId;
  StreamSubscription<DocumentSnapshot>? _userDocSub;

  // ─────────────────────────────
  // ACCOUNT MODERATION STATE
  // ─────────────────────────────
  bool _isAccountSuspended = false;
  String? _accountModerationReason;

  /// True once the signed-in user's own `users/{uid}` doc reports
  /// accountStatus suspended/blocked. Watched in real time by the same
  /// _userDocSub listener that already tracks business status, so a
  /// moderation suspension takes effect immediately - not on next token
  /// refresh (see HomeGate, which redirects to SuspendedAccountPage).
  bool get isAccountSuspended => _isAccountSuspended;
  String? get accountModerationReason => _accountModerationReason;

  // ─────────────────────────────
  // BUSINESS STATE (ENTERPRISE)
  // ─────────────────────────────

  String? _businessStatus; // none / pending / approved / rejected
  String? _businessId;
  Future<String?>? _businessIdentityResolution;
  String? _businessIdentityResolutionUid;
  String? _businessIdentityResolutionStoredId;
  bool _isBusinessVerified = false;
  List<String> _businessSectors = [];
  // 🔔 BUSINESS RESOLUTION (one-shot from notification)
  String? _initialBusinessCenterId;
  String? _initialBusinessResolutionStatus;
  String? _initialBusinessResolutionReason;

  String? get initialBusinessCenterId => _initialBusinessCenterId;
  String? get initialBusinessResolutionStatus =>
      _initialBusinessResolutionStatus;
  String? get initialBusinessResolutionReason =>
      _initialBusinessResolutionReason;
  void setApprovedBusiness({
    required String businessId,
    required List<String> sectors,
  }) {
    debugPrint("✅ setApprovedBusiness CALLED");

    _businessId = businessId;
    _businessSectors = sectors;

    _businessStatus = 'approved';

    notifyListeners();
  }

  void setInitialBusinessCenterId(String id) {
    _initialBusinessCenterId = id;
    notifyListeners();
  }

  void setInitialBusinessResolution({
    required String status,
    String? centerId,
    String? reason,
  }) {
    _initialBusinessResolutionStatus = status;
    _initialBusinessCenterId = centerId;
    _initialBusinessResolutionReason = reason;
    notifyListeners();
  }

  void consumeBusinessResolution() {
    _initialBusinessResolutionStatus = null;
    _initialBusinessResolutionReason = null;
  }

  String? get businessStatus => _businessStatus;
  String? get businessId => _businessId;
  bool get isBusinessVerified => _isBusinessVerified;
  List<String> get businessSectors => List.unmodifiable(_businessSectors);

  bool get hasApprovedBusiness =>
      _businessStatus == 'approved' && _businessId != null;
  bool get hasPendingBusiness => _businessStatus == 'pending';

  Future<String?> _resolveCanonicalBusinessId({
    required String uid,
    required String? storedBusinessId,
  }) {
    if (_businessIdentityResolution != null &&
        _businessIdentityResolutionUid == uid &&
        _businessIdentityResolutionStoredId == storedBusinessId) {
      return _businessIdentityResolution!;
    }

    final resolution = _resolveCanonicalBusinessIdFromFirestore(
      uid: uid,
      storedBusinessId: storedBusinessId,
    );
    _businessIdentityResolutionUid = uid;
    _businessIdentityResolutionStoredId = storedBusinessId;
    _businessIdentityResolution = resolution;
    return resolution;
  }

  Future<String?> _resolveCanonicalBusinessIdFromFirestore({
    required String uid,
    required String? storedBusinessId,
  }) async {
    final firestore = FirebaseFirestore.instance;

    if (storedBusinessId != null && storedBusinessId.trim().isNotEmpty) {
      try {
        final storedSnapshot = await firestore
            .collection('businesses')
            .doc(storedBusinessId)
            .get();
        final storedData = storedSnapshot.data() ?? <String, dynamic>{};
        if (storedSnapshot.exists &&
            isValidStoredBusinessReference(uid, storedBusinessId, storedData)) {
          return storedBusinessId;
        }
      } on FirebaseException catch (error) {
        debugPrint(
          'BUSINESS ID VALIDATION FALLBACK uid=$uid '
          'storedBusinessId=$storedBusinessId code=${error.code}',
        );
      }
    }

    try {
      final ownedSnapshot = await firestore
          .collection('businesses')
          .where('ownerUid', isEqualTo: uid)
          .get();
      final candidates = ownedSnapshot.docs
          .map(
            (doc) => <String, dynamic>{...doc.data(), '__documentId': doc.id},
          )
          .toList();
      final resolvedId = selectCanonicalOwnedBusinessId(uid, candidates);

      if (resolvedId == null) {
        if (candidates.isNotEmpty) {
          debugPrint(
            'BUSINESS ID UNRESOLVED uid=$uid '
            'candidateIds=${candidates.map((item) => item['__documentId']).toList()}',
          );
        }
        return null;
      }

      if (resolvedId != storedBusinessId) {
        try {
          await firestore.collection('users').doc(uid).update({
            'business.businessId': resolvedId,
          });
          debugPrint(
            'BUSINESS ID SELF-HEALED uid=$uid '
            'from=$storedBusinessId to=$resolvedId',
          );
        } catch (error) {
          debugPrint(
            'BUSINESS ID SELF-HEAL WRITE FAILED uid=$uid '
            'resolvedId=$resolvedId error=$error',
          );
        }
      }
      return resolvedId;
    } on FirebaseException catch (error) {
      debugPrint(
        'BUSINESS ID OWNER QUERY FAILED uid=$uid '
        'code=${error.code} message=${error.message}',
      );
      return null;
    }
  }

  BusinessSubPage _businessSubPage = BusinessSubPage.none;
  BusinessCardData? _activeBusiness;
  BusinessCardData? _businessAppointment;
  BusinessSubPage get businessSubPage => _businessSubPage;
  BusinessCardData? get activeBusiness => _activeBusiness;
  BusinessCardData? get businessAppointment => _businessAppointment;

  Product? _editingProduct;
  Product? get editingProduct => _editingProduct;

  void openAddService() {
    _businessSubPage = BusinessSubPage.addService;
    notifyListeners();
  }

  void setBusinessStatus(String status) {
    _businessStatus = status;
    notifyListeners();
  }

  void clearBusinessState() {
    debugPrint("🚨 CLEAR BUSINESS STATE CALLED");
    debugPrint("🚨 OLD businessId=$businessId");
    debugPrint("🚨 OLD approved=$hasApprovedBusiness");
    _businessId = null;
    _businessStatus = null;
    _isBusinessVerified = false;
    _businessSectors = [];
    notifyListeners();
  }

  // ─────────────────────────────
  // CREATOR STATE (CREATOR PROGRAM)
  // ─────────────────────────────
  // Mirrors the BUSINESS STATE section above: populated from the same
  // users/{uid} document (a sibling `creator` map next to `business`), by
  // the same live snapshot listener and cached-profile path, and gates
  // Profile page access the same way `hasApprovedBusiness` gates the
  // Business Dashboard card.

  bool _creatorEnabled = false;
  String? _creatorStatus;
  String? _creatorLevel;
  String? _creatorReferralCode;
  String? _creatorCampaign;

  bool get creatorEnabled => _creatorEnabled;
  String? get creatorStatus => _creatorStatus;
  String? get creatorLevel => _creatorLevel;
  String? get creatorReferralCode => _creatorReferralCode;
  String? get creatorCampaign => _creatorCampaign;

  // Derived, not stored (docs/architecture/creator-referral-engine.md,
  // "Refinement over the current shipped contract"): the link is always
  // this exact template applied to the canonical referral code, so there
  // is only ever one source of truth for it. Public marketing domain, not
  // app.petsupo.com — a referral link's job is to land a logged-out
  // visitor on a conversion page, which is a marketing-site concern
  // distinct from the authenticated Flutter Web app.
  String? get creatorReferralLink => _creatorReferralCode == null
      ? null
      : 'https://petsupo.com/r/$_creatorReferralCode';

  void _applyCreatorMap(dynamic creator) {
    _creatorEnabled = creator?['enabled'] == true;
    _creatorStatus = creator?['status']?.toString();
    _creatorLevel = creator?['level']?.toString();
    _creatorReferralCode = creator?['referralCode']?.toString();
    _creatorCampaign = creator?['currentCampaign']?.toString();
  }

  void clearCreatorState() {
    _creatorEnabled = false;
    _creatorStatus = null;
    _creatorLevel = null;
    _creatorReferralCode = null;
    _creatorCampaign = null;
    notifyListeners();
  }

  bool _vetLoaded = false;
  bool get vetLoaded => _vetLoaded;

  GlobalRoute activeRoute = GlobalRoute.none;
  bool showUpgradePage = false;

  void openRoute(GlobalRoute route) {
    activeRoute = route;
    notifyListeners();
  }

  void closeRoute() {
    activeRoute = GlobalRoute.none;
    notifyListeners();
  }

  void openUpgradePage() {
    if (showUpgradePage) return;
    showUpgradePage = true;
    notifyListeners();
  }

  void closeUpgradePage() {
    if (!showUpgradePage) return;
    showUpgradePage = false;
    notifyListeners();
  }

  void openBusinessDetails(BusinessCardData business) {
    // 🔒 BLOCK non-approved
    if (business.status != 'approved') {
      debugPrint('⛔ BLOCKED: business not approved → ${business.status}');
      return;
    }

    debugPrint('🟣 openBusinessDetails name=${business.name}');
    if (business.type == BusinessType.groomer) {
      debugPrint(
        'GROOMY OPEN BUSINESS DETAILS id=${business.id} name=${business.name}',
      );
    }
    closeVetDetails();
    _activeBusiness = business;
    notifyListeners();
  }

  void closeBusinessDetails() {
    final wasAdoptionCenter =
        _activeBusiness?.type == BusinessType.adoptionCenter;
    if (wasAdoptionCenter) {
      debugPrint('CLOSE ADOPTION DETAIL OVERLAY');
    }
    _activeBusiness = null;
    _businessAppointment = null;
    _appointmentService = null;
    _businessSubPage = BusinessSubPage.none;
    _selectedVet = null;
    if (wasAdoptionCenter) {
      debugPrint('ADOPTION SCREEN RESTORED');
    }
    notifyListeners();
  }

  // ==========================
  // VET DETAILS STATE
  // ==========================

  BusinessCardData? _selectedVet;
  BusinessCardData? _selectedPetShop;

  BusinessCardData? get selectedVet => _selectedVet;
  BusinessCardData? get selectedPetShop => _selectedPetShop;

  void openVetDetails(BusinessCardData vet) {
    _selectedVet = vet;
    notifyListeners();
  }

  void closeVetDetails() {
    _selectedVet = null;
    notifyListeners();
  }

  void openPetShopDetails(BusinessCardData shop) {
    _selectedPetShop = shop;
    notifyListeners();
  }

  void closePetShopDetails() {
    _selectedPetShop = null;
    notifyListeners();
  }

  Map<String, dynamic>? _appointmentService;
  Map<String, dynamic>? get appointmentService => _appointmentService;

  void openBusinessAppointment(
    BusinessCardData business, {
    Map<String, dynamic>? selectedService,
  }) {
    closeVetDetails();
    _businessAppointment = business;
    _appointmentService = selectedService; // 👈 مهم
    _businessSubPage = BusinessSubPage.appointment;
    notifyListeners();
  }

  void closeVaccineNotification() {
    activeVaccineBusinessId = null;

    activeVaccinePatientId = null;

    activeVaccineId = null;

    activeVaccinePetId = null;

    closeVetDetails(); // 👈 add this

    notifyListeners();
  }

  void closeBusinessAppointment() {
    _businessAppointment = null;
    _businessSubPage = BusinessSubPage.none;
    closeVetDetails();
    notifyListeners();
  }

  bool _notificationNavigationConsumed = false;

  bool consumeNotificationNavigation() {
    if (_notificationNavigationConsumed) return false;
    _notificationNavigationConsumed = true;
    return true;
  }

  void resetNotificationNavigation() {
    _notificationNavigationConsumed = false;
  }

  List<Dog> _favoriteDogs;
  final ValueNotifier<List<Dog>> favoriteDogsNotifier;
  final ValueNotifier<Map<String, List<String>>> likesNotifier;
  Map<String, List<Map<String, dynamic>>> _dogLikes;

  Function(Dog) onToggleFavorite;
  final NotificationService notificationService;
  String? _initialPlaydateRequestId;
  String? get initialPlaydateRequestId => _initialPlaydateRequestId;
  bool _shouldConsumeInitialPlaydateRequest = true;
  bool get shouldConsumeInitialPlaydateRequest =>
      _shouldConsumeInitialPlaydateRequest;
  String? _otherUserProfileId;
  String? get otherUserProfileId => _otherUserProfileId;
  String? _lastHandledRequestId;
  String? _lastHandledStatus;
  String? _lastHandledType;
  String? _lastConsumedPlaydateRequestId;
  bool _ignoreNextNotificationTap = false;
  DateTime? _ignoreNotificationIconUntil;

  Map<String, dynamic>? _pendingNotificationNavigation;
  bool _isUserInitialized = false;

  bool get isUserInitialized => _isUserInitialized;

  // ─────────────────────────────
  // LOST / FOUND DOGS COUNT
  // ─────────────────────────────

  int _lostDogsCount = 0;
  int _foundDogsCount = 0;

  int get lostDogsCount => _lostDogsCount;
  int get foundDogsCount => _foundDogsCount;

  StreamSubscription<QuerySnapshot>? _lostSub;
  StreamSubscription<QuerySnapshot>? _foundSub;

  String? _pendingRoute;
  Map<String, dynamic>? _pendingRouteArgs;

  String? get pendingRoute => _pendingRoute;
  Map<String, dynamic>? get pendingRouteArgs => _pendingRouteArgs;

  String? get currentUserId => _currentUserId;

  String? _username;
  String? get username => _username;

  String? _currentUserName;
  String? get currentUserName => _currentUserName;

  String? _currentUserId;
  static bool enableDiagnosticsAuthReset = true;
  bool _authRecoveryAttempted = false;
  final bool _authResetInProgress = false;
  bool _suppressGuestModeOnce = false;
  bool _hasSeenAuthenticatedUser = false;
  bool _pendingSessionRecoveryNotice = false;

  bool _savedParksLoaded = false;

  bool _isUserProfileReady = false;
  bool get isUserProfileReady => _isUserProfileReady;

  // ─────────────────────────────
  // 🔐 STARTUP AUTH RESTORATION
  // ─────────────────────────────
  //
  // Firebase restores a persisted session asynchronously, so
  // `FirebaseAuth.instance.currentUser` is briefly null at launch even for a
  // signed-in user. Routing on that transient null is what made a returning
  // user land on WelcomePage.
  //
  // These two flags are owned here — the same object that already owns the
  // auth subscription, the uid, guest state and profile readiness — so no
  // second auth state system is introduced. They describe only *whether the
  // auth stream has spoken yet* and *what it last said*; every existing
  // guest/blocked/suspended/profile-completion rule is untouched.

  AuthRestorationPhase _authRestorationPhase = AuthRestorationPhase.restoring;

  /// The authoritative startup auth outcome. Routing switches on this.
  AuthRestorationPhase get authRestorationPhase => _authRestorationPhase;

  /// True once restoration has reached any terminal outcome — including
  /// [AuthRestorationPhase.failed]. Deliberately *not* a permission to show
  /// WelcomePage: only [hasConfirmedNoAuthUser] grants that.
  bool get authRestorationSettled =>
      _authRestorationPhase != AuthRestorationPhase.restoring;

  /// A Firebase user (including anonymous/guest) is present.
  bool get hasRestoredAuthUser =>
      _authRestorationPhase == AuthRestorationPhase.authenticated;

  /// The auth stream successfully reported "no user". This is the only state
  /// that may route to WelcomePage — a failure or timeout must not.
  bool get hasConfirmedNoAuthUser =>
      _authRestorationPhase == AuthRestorationPhase.unauthenticated;

  /// Restoration could not be determined. The user's real state is unknown,
  /// so the UI offers a retry rather than assuming they are signed out.
  bool get authRestorationFailed =>
      _authRestorationPhase == AuthRestorationPhase.failed;

  Timer? _authRestorationTimeoutTimer;

  /// Defensive liveness guard only. Firebase reliably emits an initial event,
  /// but a missed event must not strand the app on a splash screen forever.
  /// This never decides *whether* a user is authenticated — it only stops
  /// waiting, and the resulting state is `failed` (unknown, retryable), never
  /// `unauthenticated`.
  static const Duration defaultAuthRestorationTimeout = Duration(seconds: 10);

  Duration _authRestorationTimeout = defaultAuthRestorationTimeout;

  /// The active liveness-guard duration. Per-instance rather than a mutable
  /// global, so a test shortening it cannot leak into another test or into
  /// production.
  Duration get authRestorationTimeout => _authRestorationTimeout;

  @visibleForTesting
  set authRestorationTimeout(Duration value) => _authRestorationTimeout = value;

  void _setAuthRestorationPhase(
    AuthRestorationPhase phase, {
    required String reason,
  }) {
    if (_disposed || _authRestorationPhase == phase) return;

    _authRestorationPhase = phase;

    // Any terminal outcome makes the liveness guard redundant.
    if (phase != AuthRestorationPhase.restoring) {
      _authRestorationTimeoutTimer?.cancel();
      _authRestorationTimeoutTimer = null;
    }

    debugPrint('🔐 AUTH RESTORATION → ${phase.name} ($reason)');
    notifyListeners();
  }

  /// Records that restoration could not be determined.
  ///
  /// Only an in-progress restoration can fail: once the stream has
  /// successfully reported a user or a genuine null, that confirmed outcome is
  /// preserved and a later error/timeout changes nothing. This is what keeps a
  /// failure from ever being read as a sign-out.
  void _markAuthRestorationFailed({required String reason}) {
    if (_authRestorationPhase != AuthRestorationPhase.restoring) {
      debugPrint(
        '🔐 AUTH RESTORATION failure ignored ($reason) → '
        'keeping ${_authRestorationPhase.name}',
      );
      return;
    }

    _setAuthRestorationPhase(AuthRestorationPhase.failed, reason: reason);
  }

  /// Re-attempts restoration after a failure.
  ///
  /// Replaces — never duplicates — the subscription and the liveness timer, so
  /// repeated retries cannot accumulate listeners or timers.
  /// Synchronous by design: the UI returns to the loading state on the same
  /// frame as the tap, and there is no async gap during which a second retry
  /// could start a parallel subscription.
  ///
  /// The previous subscription is cancelled without awaiting completion —
  /// `cancel()` stops event delivery immediately, so the dropped subscription
  /// cannot route a late event — and `_authSub` is cleared first so
  /// [startAuthListener] subscribes exactly once.
  void retryAuthRestoration() {
    if (_disposed) return;

    debugPrint('🔐 AUTH RESTORATION retry requested');

    final previous = _authSub;
    _authSub = null;
    unawaited(previous?.cancel() ?? Future<void>.value());

    _authRestorationTimeoutTimer?.cancel();
    _authRestorationTimeoutTimer = null;

    _setAuthRestorationPhase(
      AuthRestorationPhase.restoring,
      reason: 'retry requested',
    );

    startAuthListener();
  }

  StartupPhase _startupPhase = StartupPhase.coldStart;
  StartupPhase get startupPhase => _startupPhase;
  bool _firebaseInitialized = false;
  bool _authUserDetected = false;
  bool _tokenStable = false;
  bool _firebaseInstallationsReady = false;
  bool _firestoreReady = false;
  bool _noncriticalReadsAllowed = false;
  bool _startupDegradedMode = false;
  bool _noncriticalStartupStarted = false;
  bool _startupFirestoreStabilizationApplied = false;
  bool _firestoreStartupDiagnosticsRan = false;
  static const bool _startupFirestoreDiagnosticsEnabled = false;
  bool _startupAuthWasRestored = false;
  bool _startupAuthRestoreDelayApplied = false;
  String? _scheduledInitUserForUid;
  String? _transitioningToUid;
  Future<void>? _authenticatedSessionTransition;
  bool _startupSuccessFinalized = false;
  int _startupSessionGeneration = 0;
  Completer<bool>? _noncriticalReadsCompleter;
  Timer? _startupReadinessRetryTimer;
  bool _startupReadinessRetryRunning = false;
  int _startupReadinessRetryCount = 0;

  bool get firebaseInitialized => _firebaseInitialized;
  bool get authUserDetected => _authUserDetected;
  bool get tokenStable => _tokenStable;
  bool get firebaseInstallationsReady => _firebaseInstallationsReady;
  bool get firestoreReady => _firestoreReady;
  bool get noncriticalReadsAllowed => _noncriticalReadsAllowed;
  bool get startupDegradedMode => _startupDegradedMode;
  int get startupSessionGeneration => _startupSessionGeneration;
  bool get startupSuccessFinalized => _startupSuccessFinalized;

  ProfileSubPage _profileSubPage = ProfileSubPage.none;

  ProfileSubPage get profileSubPage => _profileSubPage;

  String? _pendingBuyerOrdersRootOrderId;
  String? _pendingBuyerOrdersReturnId;

  @visibleForTesting
  String? get pendingBuyerOrdersRootOrderId => _pendingBuyerOrdersRootOrderId;

  String? takePendingBuyerOrdersRootOrderId() {
    final value = _pendingBuyerOrdersRootOrderId;
    _pendingBuyerOrdersRootOrderId = null;
    return value;
  }

  @visibleForTesting
  String? get pendingBuyerOrdersReturnId => _pendingBuyerOrdersReturnId;

  String? takePendingBuyerOrdersReturnId() {
    final value = _pendingBuyerOrdersReturnId;
    _pendingBuyerOrdersReturnId = null;
    return value;
  }

  AppointmentService? _selectedAppointmentService;
  AppointmentStatus? _selectedAppointmentStatus;

  AppointmentService? get selectedAppointmentService =>
      _selectedAppointmentService;
  AppointmentStatus? get selectedAppointmentStatus =>
      _selectedAppointmentStatus;

  final bool _isHandlingPlaydateResult = false;

  String? _userRole;
  String? get userRole => _userRole;

  bool get isAdmin => _userRole == 'admin';
  int get unreadNotificationsCount => _unreadNotificationsCount;

  //bool _isPlaydateParkStepOpen = false;
  static String? _lastHandledPlaydateRequestId;

  Map<String, dynamic>? get selectedParkForPlaydate => _selectedParkForPlaydate;
  Map<String, dynamic>? _selectedSavedPark;
  Map<String, dynamic>? get selectedSavedPark => _selectedSavedPark;
  //Map<String, dynamic>? _pendingPlaydatePark;
  Map<String, dynamic>? _selectedParkForPlaydate;

  Map<String, dynamic>? _pendingPlaydatePark; // موقت

  // ─────────────────────────────
  // DOGS STATE (SINGLE SOURCE)
  // ─────────────────────────────
  DogsSnapshot _dogsSnapshot = DogsSnapshot.loading();
  List<Dog> _myDogs = [];
  List<Dog> _allDogs = [];
  List<Dog> _discoveryDogs = [];
  List<Dog>? _allDogsView;
  List<Dog>? _discoveryDogsView;
  Object? _dogsError;
  bool _isDogsLoading = true;

  List<Dog> get myDogs => List.unmodifiable(_myDogs);
  List<Dog> get allDogs => _allDogsView ??= List.unmodifiable(_allDogs);
  List<Dog> get discoveryDogs =>
      _discoveryDogsView ??= List.unmodifiable(_discoveryDogs);
  bool get isDogsLoading => _isDogsLoading;
  bool get hasDogs => _myDogs.isNotEmpty || _allDogs.isNotEmpty;
  Object? get dogsError => _dogsError;

  void _invalidateAllDogsView() {
    _allDogsView = null;
    _discoveryDogsView = null;
  }

  // AppState fields
  Dog? editingDog; // یا فقط editingDogId اگر ترجیح میدی
  bool get isEditDogOpen => editingDog != null;

  StreamSubscription<User?>? _authSub;

  bool canConsumePlaydateRequest(String requestId) {
    return _lastConsumedPlaydateRequestId != requestId;
  }

  void calculateDistances(double userLat, double userLng) {
    for (final dog in _discoveryDogs) {
      if (dog.latitude != null && dog.longitude != null) {
        dog.distanceKm = LocationUtils.calculateDistanceKm(
          userLat,
          userLng,
          dog.latitude!,
          dog.longitude!,
        );
      }
    }
    _invalidateAllDogsView();
  }

  void sortDogsByDistance() {
    _discoveryDogs.sort((a, b) {
      final da = a.distanceKm ?? 9999;
      final db = b.distanceKm ?? 9999;
      return da.compareTo(db);
    });
    _invalidateAllDogsView();
  }

  Future<T> _firestoreRetry<T>(
    Future<T> Function() operation, {
    String operationName = 'Firestore operation',
    int maxAttempts = 3,
    FirestoreRecoveryScope recoveryScope = FirestoreRecoveryScope.background,
  }) async {
    return FirestoreReadinessGate.instance.runSerial(operationName, () async {
      Object? lastError;
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          return await operation();
        } catch (e) {
          lastError = e;
          await FirestorePermissionDiagnostics.reportIfNeeded(
            e,
            failurePath: '_firestoreRetry:$operationName',
            message: 'Firestore permission denied during retry operation',
          );
          if (!FirestoreRecovery.isConnectivityError(e)) rethrow;
          if (attempt < maxAttempts) {
            debugPrint(
              '⚠️ $operationName failed (attempt $attempt/$maxAttempts) → $e',
            );
            await Future.delayed(Duration(milliseconds: 700 * attempt));
          }
        }
      }
      throw Exception('$operationName failed: $lastError');
    }, uid: _currentUserId);
  }

  Future<T> _criticalFirestoreRetry<T>(
    Future<T> Function() operation, {
    required String operationName,
  }) async {
    return FirestoreReadinessGate.instance.runSerial(operationName, () async {
      Object? lastError;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          final result = await operation();
          if (attempt > 1) {
            debugPrint('🌐 CRITICAL READ RECOVERED → $operationName');
          }
          return result;
        } catch (e) {
          lastError = e;
          await FirestorePermissionDiagnostics.reportIfNeeded(
            e,
            failurePath: '_criticalFirestoreRetry:$operationName',
            message:
                'Firestore permission denied during critical retry operation',
          );
          if (!FirestoreRecovery.isConnectivityError(e)) rethrow;
          if (attempt < 3) {
            debugPrint('🌐 CRITICAL READ RETRY $attempt/3 → $operationName');
            await Future.delayed(
              attempt == 1
                  ? const Duration(seconds: 2)
                  : const Duration(seconds: 5),
            );
          }
        }
      }
      debugPrint('🌐 CRITICAL READ DEGRADED FALLBACK → $operationName');
      throw Exception(
        '$operationName failed after critical retries: $lastError',
      );
    }, uid: _currentUserId);
  }

  void openProfileSubPage(ProfileSubPage page) {
    if (_profileSubPage == page) return;
    if (page == ProfileSubPage.appointments ||
        page == ProfileSubPage.myAppointments) {
      _clearAppointmentFlowSelection();
    } else if (page != ProfileSubPage.appointmentStatus &&
        page != ProfileSubPage.appointmentHistory) {
      _clearAppointmentFlowSelection();
    }
    _profileSubPage = page;
    notifyListeners();
  }

  void openAppointmentServices() {
    _selectedAppointmentService = null;
    _selectedAppointmentStatus = null;
    _profileSubPage = ProfileSubPage.appointments;
    notifyListeners();
  }

  void openAppointmentStatuses(AppointmentService service) {
    _selectedAppointmentService = service;
    _selectedAppointmentStatus = null;
    _profileSubPage = ProfileSubPage.appointmentStatus;
    notifyListeners();
  }

  void openAppointmentHistory(AppointmentStatus status) {
    if (_selectedAppointmentService == null) return;
    _selectedAppointmentStatus = status;
    _profileSubPage = ProfileSubPage.appointmentHistory;
    notifyListeners();
  }

  void backFromAppointmentFlow() {
    switch (_profileSubPage) {
      case ProfileSubPage.appointmentHistory:
        _selectedAppointmentStatus = null;
        _profileSubPage = ProfileSubPage.appointmentStatus;
        break;
      case ProfileSubPage.appointmentStatus:
        _selectedAppointmentService = null;
        _profileSubPage = ProfileSubPage.appointments;
        break;
      case ProfileSubPage.appointments:
        _clearAppointmentFlowSelection();
        _profileSubPage = ProfileSubPage.none;
        break;
      case ProfileSubPage.myAppointments:
        _profileSubPage = ProfileSubPage.none;
        break;
      default:
        closeProfileSubPage();
        return;
    }
    notifyListeners();
  }

  void _clearAppointmentFlowSelection() {
    _selectedAppointmentService = null;
    _selectedAppointmentStatus = null;
  }

  void markPlaydateRequestConsumed(String requestId) {
    _lastConsumedPlaydateRequestId = requestId;
  }

  String? _initialLostDogId;
  String? get initialLostDogId => _initialLostDogId;

  String? activeFoundDogId;

  void openFoundDogDetail(String id) {
    activeFoundDogId = id;
    notifyListeners();
  }

  void closeFoundDogDetail() {
    activeFoundDogId = null;
    notifyListeners();
  }

  void setInitialLostDog(String? dogId) {
    _initialLostDogId = dogId;
    notifyListeners();
  }

  void clearInitialLostDogId() {
    _initialLostDogId = null;
    notifyListeners();
  }

  String? playmateProfileUserId;
  List<Dog>? playmateDogsSnapshot;
  String? _petploreProfileUserId;
  String? get petploreProfileUserId => _petploreProfileUserId;

  void openPetploreProfile(String userId) {
    if (userId.trim().isEmpty) return;
    _petploreProfileUserId = userId;
    notifyListeners();
  }

  void closePetploreProfile() {
    _petploreProfileUserId = null;
    notifyListeners();
  }

  void setPlaymateProfile(String userId, List<Dog> dogs) {
    debugPrint("🔥 SWITCH PROFILE → $userId");

    _ignoreNextClose = true;

    // 🔥 snapshot
    playmateDogsSnapshot = List<Dog>.from(dogs);

    // ✅ فقط یک بار set
    playmateProfileUserId = userId;

    notifyListeners();
  }

  void closePlaymateProfile() {
    if (_ignoreNextClose) {
      debugPrint("🛑 IGNORE FIRST CLOSE");
      _ignoreNextClose = false;
      return;
    }

    debugPrint("❌ CLOSE PROFILE");

    playmateProfileUserId = null;
    notifyListeners();
  }

  void setAllDogs(List<Dog> dogs) {
    _allDogs = dogs; // 🔥 این مهمه
    _invalidateAllDogsView();
    notifyListeners();
  }

  Future<void> refreshDogs() async {
    try {
      if (isGuest) {
        debugPrint('AppState - Skipping canonical dog refresh for guest');
        return;
      }

      final canonicalDogs = await _dogSyncService.fetchCanonicalDogs();
      await DogsBoxManager.instance.replaceAllCanonicalDogs(canonicalDogs);
      debugPrint(
        'AppState - Synced ${canonicalDogs.length} unique dogs from Firestore to Hive',
      );
    } catch (e) {
      debugPrint('AppState - Error syncing dogs with Firestore: $e');
    }
  }

  Future<void> addDogToLocalState(Dog dog) async {
    await DogsBoxManager.instance.upsertDog(dog);
  }

  Future<void> clearDogLocalState() async {
    await DogsBoxManager.instance.clearIfReady();
  }

  void openEditDog(Dog dog) {
    editingDog = dog;
    notifyListeners();
  }

  void closeEditDog() {
    editingDog = null;
    notifyListeners();
  }

  Future<void> saveEditedDog(
    Dog updatedDog, {
    bool avatarChanged = false,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("User not authenticated");
      }

      final uid = user.uid;

      debugPrint("🐶 saveEditedDog START");
      debugPrint("🐶 currentUserUid => $uid");
      debugPrint("🐶 dogId => ${updatedDog.id}");

      final docRef = FirebaseFirestore.instance
          .collection('dogs')
          .doc(updatedDog.id);

      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        throw Exception("Dog document not found");
      }

      final data = snapshot.data()!;

      final ownerUid = data['ownerUid'] ?? data['ownerId'];

      debugPrint("🐶 ownerUid in document => $ownerUid");

      if (ownerUid != uid) {
        throw Exception("User is not owner of this dog");
      }

      await docRef.update({
        'name': updatedDog.name,
        'petName': updatedDog.name,
        'age': updatedDog.age,
        'healthStatus': updatedDog.healthStatus,
        'isNeutered': updatedDog.isNeutered,
        'description': updatedDog.description,
        'traits': updatedDog.traits,
        'ownerGender': updatedDog.ownerGender,
        'imagePaths': updatedDog.imagePaths,
        'isAvailableForAdoption': updatedDog.isAvailableForAdoption,
      });

      debugPrint(
        '🐾 PET NAME SYNC → name=${updatedDog.name} petName=${updatedDog.name}',
      );

      final myIndex = _myDogs.indexWhere((d) => d.id == updatedDog.id);
      if (myIndex != -1) {
        _myDogs[myIndex] = updatedDog;
      }

      final allIndex = _allDogs.indexWhere((d) => d.id == updatedDog.id);
      if (allIndex != -1) {
        _allDogs[allIndex] = updatedDog;
        _invalidateAllDogsView();
      }

      editingDog = null;

      notifyListeners();

      // ✅ Analytics (only after successful update)
      if (avatarChanged) {
        await AnalyticsService.petAvatarChanged(petType: updatedDog.petType);
      } else {
        await AnalyticsService.petUpdated(
          petType: updatedDog.petType,
          breed: updatedDog.breed,
          age: updatedDog.age,
          gender: updatedDog.gender.toLowerCase() == 'male'
              ? AnalyticsValues.male
              : AnalyticsValues.female,
        );
      }

      debugPrint("✅ Dog updated safely");
    } catch (e, stack) {
      debugPrint("❌ saveEditedDog error: $e");
      debugPrint("STACK: $stack");
      rethrow;
    }
  }

  String? _initializedForUid;
  String? _initializingForUid;

  Future<void> loadSubscriptionFromFirestore() async {
    final uid = _currentUserId;
    if (uid == null) return;

    final generation = _startupSessionGeneration;

    debugPrint('🔄 subscription reload started');

    final usedCache =
        FirestoreRecovery.passiveMode && _applyCachedSubscription(uid);

    if (usedCache) {
      if (!isUserSessionCurrent(uid, generation)) {
        debugPrint('🛑 SKIP cached subscription notify → old session');
        return;
      }

      notifyListeners();
    }

    try {
      debugPrint(
        '🌐 SERVER-FORCED READ SKIPPED → loadSubscriptionFromFirestore',
      );

      final reads = await _criticalFirestoreRetry(
        () => Future.wait([
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get(const GetOptions(source: Source.server))
              .timeout(_firestoreReadTimeout),
          FirebaseFirestore.instance
              .collection('subscriptions')
              .doc(uid)
              .get(const GetOptions(source: Source.server))
              .timeout(_firestoreReadTimeout),
        ]),
        operationName: 'loadSubscriptionFromFirestore',
      );

      if (!isUserSessionCurrent(uid, generation)) {
        debugPrint('🛑 SKIP subscription update → old session');
        return;
      }

      final userDoc = reads[0];
      final canonicalDoc = reads[1];
      final data = userDoc.data();
      final canonicalData = canonicalDoc.data();

      debugPrint('🔥 firestore subscription fetched');

      // subscriptions/{uid} is authoritative. users/* fields are compatibility
      // projections for older readers and are used only as a legacy fallback.
      final subscriptionData = canonicalDoc.exists
          ? canonicalData
          : data?['subscription'];

      debugPrint(
        '🔥 raw subscription data=${subscriptionData ?? <String, dynamic>{}} '
        'rootPlan=${data?['subscriptionPlan']} '
        'rootStatus=${data?['subscriptionStatus']}',
      );

      if (canonicalDoc.exists && canonicalData != null) {
        _subscription = UserSubscription.fromMap(
          Map<String, dynamic>.from(canonicalData),
        );
      } else if (data == null) {
        _subscription = UserSubscription.normal();
      } else if (subscriptionData is Map) {
        _subscription = UserSubscription.fromMap(
          Map<String, dynamic>.from(subscriptionData),
        );
      } else {
        _subscription = UserSubscription.fromMap({
          'plan': data['subscriptionPlan'],
          'status': data['subscriptionStatus'],
        });
      }

      _isPremium = _subscription.hasValidPaidAccess;

      debugPrint(
        'RAW SUBSCRIPTION STATUS: top=${subscriptionData?['status']} '
        'mobile=${subscriptionData?['mobile'] is Map ? (subscriptionData?['mobile'] as Map)['status'] : null}',
      );
      debugPrint(
        'RAW PLAN: top=${subscriptionData?['plan']} '
        'mobile=${subscriptionData?['mobile'] is Map ? (subscriptionData?['mobile'] as Map)['plan'] : null}',
      );
      debugPrint('MAPPED PLAN: ${_subscription.plan}');
      debugPrint('MAPPED STATUS: ${_subscription.status}');
      debugPrint('CAN_REGISTER: $canRegisterBusiness');

      await _refreshSubscriptionHiveCache(uid);

      if (!isUserSessionCurrent(uid, generation)) {
        debugPrint('🛑 SKIP after hive refresh → old session');
        return;
      }

      debugPrint(
        '💳 Loaded subscription → '
        '${_subscription.plan} / ${_subscription.status}',
      );

      debugPrint('✅ app state updated');
    } catch (e) {
      if (!isUserSessionCurrent(uid, generation)) {
        debugPrint('🛑 SKIP fallback → old session');
        return;
      }

      debugPrint('⚠️ subscription fallback → $e');

      if (!usedCache) {
        _subscription = UserSubscription.normal();
        _isPremium = false;
      }
    }

    // آخرین guard مخصوص Flutter Web
    if (!isUserSessionCurrent(uid, generation)) {
      debugPrint('🛑 FINAL SKIP notify → old session');
      return;
    }

    if (kIsWeb) {
      notifyListeners();
      debugPrint('📣 subscription listeners notified');
      return;
    }

    // Preserve the existing mobile post-frame notification timing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !isUserSessionCurrent(uid, generation)) return;
      notifyListeners();
      debugPrint('📣 subscription listeners notified');
    });
  }

  Future<void> _refreshSubscriptionHiveCache(String uid) async {
    if (!Hive.isBoxOpen('userDataBox')) return;

    final userDataBox = Hive.box<Map<dynamic, dynamic>>('userDataBox');
    final cached = userDataBox.get(uid);
    if (cached == null) return;

    final updated = Map<dynamic, dynamic>.from(cached)
      ..['isPremium'] = _isPremium
      ..['subscriptionPlan'] = _subscription.plan.toFirestore()
      ..['subscriptionStatus'] = _subscription.status.toFirestore()
      ..['subscription'] = {
        'plan': _subscription.plan.toFirestore(),
        'status': _subscription.status.toFirestore(),
        'startedAt': _subscription.startedAt,
        'expiresAt': _subscription.expiresAt,
        'autoRenew': _subscription.autoRenew,
        'source': _subscription.source.toFirestore(),
        'lastUpdatedAt': _subscription.lastUpdatedAt,
      };

    await userDataBox.put(uid, cleanDeep(updated));
  }

  Map<dynamic, dynamic>? _cachedUserData(String uid) {
    if (!Hive.isBoxOpen('userDataBox')) return null;
    final cached = Hive.box<Map<dynamic, dynamic>>('userDataBox').get(uid);
    if (cached == null) return null;
    return Map<dynamic, dynamic>.from(cached);
  }

  bool _applyCachedUserProfile(String uid) {
    final cached = _cachedUserData(uid);
    if (cached == null || cached.isEmpty) return false;

    debugPrint('🌐 CACHE-FIRST USER LOAD → profile');
    debugPrint('🌐 DEGRADED STARTUP CACHE MODE → profile');

    _userRole = cached['role']?.toString();
    final cachedUsername = cached['username']?.toString();
    if (cachedUsername != null && cachedUsername.trim().isNotEmpty) {
      _username = cachedUsername;
      _currentUserName = cachedUsername;
    }

    final business = cached['business'];
    if (business is Map) {
      _businessStatus = business['status']?.toString();
      _businessId = business['businessId']?.toString();
      _isBusinessVerified = business['isVerified'] == true;
      _businessSectors =
          (business['sectors'] as List?)?.map((e) => e.toString()).toList() ??
          [];
    }

    _applyCreatorMap(cached['creator']);

    return true;
  }

  bool _applyCachedSubscription(String uid) {
    final cached = _cachedUserData(uid);
    if (cached == null || cached.isEmpty) return false;

    debugPrint('🌐 DEGRADED STARTUP CACHE MODE → subscription');

    final subscriptionData = cached['subscription'];
    if (subscriptionData is Map) {
      _subscription = UserSubscription.fromMap(
        Map<String, dynamic>.from(subscriptionData),
      );
    } else if (cached.containsKey('subscriptionPlan') ||
        cached.containsKey('subscriptionStatus')) {
      _subscription = UserSubscription.fromMap({
        'plan': cached['subscriptionPlan'],
        'status': cached['subscriptionStatus'],
      });
    } else if (cached['isPremium'] == true) {
      _subscription = UserSubscription.fromMap({
        'plan': SubscriptionPlan.premium.toFirestore(),
        'status': 'active',
      });
    } else {
      return false;
    }

    _isPremium = _subscription.hasValidPaidAccess;
    return true;
  }

  bool _applyCachedSavedParks(String uid) {
    final cached = _cachedUserData(uid);
    final parks = cached?['savedParks'];
    if (parks is! List) return false;

    debugPrint('🌐 DEGRADED STARTUP CACHE MODE → saved parks');

    _favoriteParks
      ..clear()
      ..addAll(
        parks.map((p) {
          if (p is Map) return Map<String, dynamic>.from(p);
          return {'name': p.toString()};
        }),
      );
    _savedParksLoaded = true;
    return true;
  }

  bool _applyCachedMyDogs(String uid) {
    if (_dogsSnapshot.isLoading) return false;

    final dogs = _dogsSnapshot.dogs
        .where((dog) => (dog.ownerId ?? '').trim() == uid)
        .toList();
    if (dogs.isEmpty) return false;

    debugPrint('🌐 DEGRADED STARTUP CACHE MODE → my dogs');
    _myDogs = dogs;
    return true;
  }

  bool _applyCachedDiscoveryDogs(String uid) {
    if (_dogsSnapshot.isLoading) return false;

    final dogs = _dogsSnapshot.dogs
        .where(
          (dog) =>
              (dog.ownerId ?? '').trim() != uid &&
              !dog.isHidden &&
              dog.dogProfileVisible &&
              dog.ownerProfileVisible,
        )
        .toList();
    if (dogs.isEmpty) return false;

    debugPrint('🌐 DEGRADED STARTUP CACHE MODE → discovery dogs');
    _discoveryDogs = dogs;
    _invalidateAllDogsView();
    const userLat = 41.0082;
    const userLng = 28.9784;
    calculateDistances(userLat, userLng);
    sortDogsByDistance();
    return true;
  }

  bool _suppressPassiveStartupRead(String operationName) {
    if (!FirestoreRecovery.passiveMode ||
        !FirestoreRecovery.isRecoveryCooldownActive) {
      return false;
    }

    debugPrint(
      '🌐 STARTUP RETRY SUPPRESSED → $operationName '
      'cooldown=${FirestoreRecovery.recoveryCooldownRemaining.inSeconds}s',
    );
    return true;
  }

  void queueSessionRecoveryNotice() {
    _pendingSessionRecoveryNotice = true;
  }

  bool consumeSessionRecoveryNotice() {
    if (!_pendingSessionRecoveryNotice) return false;
    _pendingSessionRecoveryNotice = false;
    return true;
  }

  void _clearAuthMemoryState({bool notify = true}) {
    stopFirestoreListeners();

    _initializedForUid = null;
    _initializingForUid = null;
    _scheduledInitUserForUid = null;
    _currentUserId = null;
    _currentUserName = null;
    _username = null;
    _userRole = null;

    _subscription = UserSubscription.normal();
    _isPremium = false;

    _businessStatus = null;
    _businessId = null;
    _businessIdentityResolution = null;
    _businessIdentityResolutionUid = null;
    _businessIdentityResolutionStoredId = null;
    _isBusinessVerified = false;
    _businessSectors = [];
    _isAccountSuspended = false;
    _accountModerationReason = null;

    _creatorEnabled = false;
    _creatorStatus = null;
    _creatorLevel = null;
    _creatorReferralCode = null;
    _creatorCampaign = null;

    _favoriteDogs.clear();
    favoriteDogsNotifier.value = <Dog>[];
    _favoriteParks.clear();
    _myDogs.clear();
    _allDogs.clear();
    _cartItems.clear();
    _dogLikes.clear();
    likesNotifier.value = <String, List<String>>{};
    _discoveryDogs.clear();
    _invalidateAllDogsView();
    _savedParksLoaded = false;

    favoriteDogsNotifier.value = [];

    if (notify) notifyListeners();

    _unreadNotificationsCount = 0;
    _selectedPark = null;
    _selectedServiceTitle = null;
    _editingServiceId = null;
    _editingServiceData = null;
    _activeBusiness = null;
    _businessAppointment = null;
    _appointmentService = null;
    centerDogsId = null;
    adoptionDogOverlayId = null;
    playmateProfileUserId = null;
    playmateDogsSnapshot = null;
    activeLostDogId = null;
    activeFoundDogId = null;
    _pendingRoute = null;
    _pendingRouteArgs = null;
    _pendingNotificationNavigation = null;
    _handledResultRequestId = null;
    _lastConsumedPlaydateRequestId = null;
    _lastHandledRequestId = null;
    _lastHandledStatus = null;
    _lastHandledType = null;
    _notificationNavigationConsumed = false;
    _ignoreNextNotificationTap = false;
    _ignoreNotificationIconUntil = null;
    _initialLostDogId = null;
    _initialPlaydateRequestId = null;
    _shouldConsumeInitialPlaydateRequest = true;
    _otherUserProfileId = null;
    _ignoreNextClose = false;
    _initialBusinessCenterId = null;
    _initialBusinessResolutionStatus = null;
    _initialBusinessResolutionReason = null;

    clearBusinessState();

    _savedParksLoaded = false;
    _isUserInitialized = false;
    _isUserProfileReady = false;
    _resetStartupReadiness();
  }

  void markFirebaseInitialized() {
    _firebaseInitialized = true;
    FirestoreReadinessGate.instance.markFirebaseInitialized();
    _setStartupPhase(StartupPhase.firebaseInitialized);
  }

  void _resetStartupReadiness() {
    _startupSessionGeneration++;
    _startupSuccessFinalized = false;
    _authUserDetected = false;
    _tokenStable = false;
    _firebaseInstallationsReady = false;
    _firestoreReady = false;
    _noncriticalReadsAllowed = false;
    _startupDegradedMode = false;
    _noncriticalStartupStarted = false;
    _startupFirestoreStabilizationApplied = false;
    _firestoreStartupDiagnosticsRan = false;
    _startupReadinessRetryTimer?.cancel();
    _startupReadinessRetryTimer = null;
    _startupReadinessRetryRunning = false;
    _startupReadinessRetryCount = 0;
    _noncriticalReadsCompleter = null;
    FirestoreReadinessGate.instance.reset(reason: 'AppState startup reset');
    _setStartupPhase(
      _firebaseInitialized
          ? StartupPhase.firebaseInitialized
          : StartupPhase.coldStart,
    );
  }

  void _setStartupPhase(StartupPhase phase) {
    if (_startupPhase == phase) return;
    _startupPhase = phase;
    debugPrint('🌐 STARTUP PHASE → ${phase.name}');
  }

  void _enterStartupDegradedMode(String reason) {
    _startupDegradedMode = true;
    _setStartupPhase(StartupPhase.degradedMode);
    debugPrint('🌐 STARTUP DEGRADED MODE → $reason');
    _completeNoncriticalGate(false);
  }

  void _cancelStartupWatchdogs() {
    if (_startupSuccessFinalized) return;
    _startupSessionGeneration++;
    _startupReadinessRetryTimer?.cancel();
    _startupReadinessRetryTimer = null;
    _startupReadinessRetryRunning = false;
    _startupReadinessRetryCount = 0;
    _startupSuccessFinalized = true;
    debugPrint('🌐 STARTUP WATCHDOG CANCELLED');
    debugPrint('🌐 RECOVERY TIMERS CLEARED');
    debugPrint('🌐 STARTUP SUCCESS PATH FINALIZED');
    _loadOffersAfterStartupFinalized();
  }

  void _loadOffersAfterStartupFinalized() {
    final startupReady =
        (_authUserDetected || isGuest) &&
        _noncriticalReadsAllowed &&
        _startupSuccessFinalized;

    unawaited(
      OffersManager.loadOffersOnce(
        startupReady: startupReady,
        forceRefresh: true,
        recoveryScope: FirestoreRecoveryScope.startup,
      ),
    );
  }

  void _scheduleStartupReadinessRetry(User user) {
    if (_noncriticalReadsAllowed || _startupSuccessFinalized) return;
    if (_startupReadinessRetryTimer != null) {
      debugPrint(
        '🌐 RECOVERY LOOP SUPPRESSED → startup readiness retry already scheduled',
      );
      return;
    }

    _startupReadinessRetryCount = (_startupReadinessRetryCount + 1).clamp(1, 6);
    final delay = Duration(seconds: 10 * _startupReadinessRetryCount);
    final generation = _startupSessionGeneration;
    debugPrint('🌐 STARTUP DEGRADED MODE → retry in ${delay.inSeconds}s');

    _startupReadinessRetryTimer = Timer(delay, () {
      _startupReadinessRetryTimer = null;
      if (generation != _startupSessionGeneration || _startupSuccessFinalized) {
        return;
      }
      unawaited(_retryStartupReadiness(user));
    });
  }

  Future<void> _retryStartupReadiness(User user) async {
    if (_startupSuccessFinalized) return;
    if (_startupReadinessRetryRunning) {
      debugPrint(
        '🌐 RECOVERY LOOP SUPPRESSED → startup readiness retry already running',
      );
      return;
    }
    if (_noncriticalReadsAllowed) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != user.uid) {
      debugPrint('🌐 STARTUP DEGRADED MODE → retry skipped (auth changed)');
      return;
    }

    _startupReadinessRetryRunning = true;
    try {
      _startupDegradedMode = false;
      if (_startupSuccessFinalized) return;
      final ready = await _establishStartupReadiness(currentUser);
      if (ready) {
        _startupReadinessRetryCount = 0;
        _startNoncriticalStartupReads();
      } else {
        _scheduleStartupReadinessRetry(currentUser);
      }
    } finally {
      _startupReadinessRetryRunning = false;
    }
  }

  void _completeNoncriticalGate(bool allowed) {
    final completer = _noncriticalReadsCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(allowed);
    }
  }

  bool _isValidStartupGeneration(int generation) {
    return generation == _startupSessionGeneration;
  }

  Future<bool> waitForNoncriticalReadsAllowed({
    Duration timeout = const Duration(seconds: 20),
    int? generation,
  }) async {
    if (_noncriticalReadsAllowed || _startupSuccessFinalized) return true;
    if (_startupDegradedMode) return false;

    final completer = _noncriticalReadsCompleter ??= Completer<bool>();
    try {
      return await completer.future.timeout(timeout);
    } catch (_) {
      if (generation != null && !_isValidStartupGeneration(generation)) {
        return true;
      }
      debugPrint('🌐 STARTUP DEGRADED MODE → noncritical gate timeout');
      return false;
    }
  }

  Duration _startupBackoff(int attempt) {
    final millis = 500 * (1 << attempt);
    return Duration(milliseconds: millis.clamp(500, 8000));
  }

  Future<bool> _waitForTokenStable(User user) async {
    if (AuthTrap.authProbeMinimalMode) {
      debugPrint('🌐 AUTH MINIMAL MODE ACTIVE → token stability probe skipped');
      debugPrint('🌐 TOKEN PROBES DISABLED');
      return false;
    }

    for (int attempt = 0; attempt < 6; attempt++) {
      if (AuthTrap.shouldSuppressTokenProbe('AppState._waitForTokenStable')) {
        return false;
      }

      try {
        final token = await user
            .getIdToken(false)
            .timeout(_startupProbeTimeout);
        if (token != null && token.isNotEmpty) {
          AuthTrap.recordTokenProbeSuccess('AppState._waitForTokenStable');
          _tokenStable = true;
          _setStartupPhase(StartupPhase.tokenStable);
          debugPrint('🌐 TOKEN STABLE');
          return true;
        }
      } catch (e) {
        AuthTrap.recordTokenProbeFailure('AppState._waitForTokenStable', e);
        debugPrint('🌐 token stability probe failed (${attempt + 1}/6) → $e');
      }

      await Future.delayed(_startupBackoff(attempt));
    }

    return false;
  }

  Future<bool> _waitForFirebaseInstallationsReady() async {
    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
        final token = await FirebaseMessaging.instance.getToken().timeout(
          _startupProbeTimeout,
        );

        if (token != null && token.isNotEmpty) {
          _firebaseInstallationsReady = true;
          _setStartupPhase(StartupPhase.firebaseInstallationsReady);
          debugPrint('🌐 FIREBASE INSTALLATIONS READY');
          return true;
        }

        debugPrint(
          '🌐 Firebase Installations probe returned empty token (${attempt + 1}/5)',
        );
      } catch (e) {
        debugPrint(
          '🌐 Firebase Installations probe failed (${attempt + 1}/5) → $e',
        );
      }

      await Future.delayed(_startupBackoff(attempt));
    }

    return false;
  }

  Future<bool> _waitForFirestoreReachable(String uid) async {
    final ready = await FirestoreReadinessGate.instance.waitUntilReady(
      reason: 'AppState startup readiness',
      uid: uid,
    );
    if (ready) {
      _firestoreReady = true;
      _setStartupPhase(StartupPhase.firestoreReady);
    }
    return ready;
  }

  Future<bool> _establishStartupReadiness(User user) async {
    _authUserDetected = true;
    _setStartupPhase(StartupPhase.authUserDetected);
    final generation = _startupSessionGeneration;

    if (AuthTrap.authProbeMinimalMode) {
      debugPrint('🌐 AUTH MINIMAL MODE ACTIVE → passive auth accepted');
      debugPrint('🌐 TOKEN PROBES DISABLED');
      debugPrint('🌐 MINIMAL AUTH GATE OPEN');
      await _awaitStartupFirestoreStabilization(generation);
      if (!_isValidStartupGeneration(generation)) return false;
      FirestoreReadinessGate.instance.markAuthStabilized(user.uid);
      if (!await _waitForFirestoreReachable(user.uid)) {
        _enterStartupDegradedMode('Firestore not reachable');
        return false;
      }
      _tokenStable = false;
      _firebaseInstallationsReady = false;
      _startupDegradedMode = false;
      _noncriticalReadsAllowed = true;
      _setStartupPhase(StartupPhase.noncriticalReadsAllowed);
      debugPrint('🌐 NONCRITICAL READS ENABLED → auth minimal mode');
      _completeNoncriticalGate(true);
      _cancelStartupWatchdogs();
      return true;
    }

    if (!await _waitForTokenStable(user)) {
      _enterStartupDegradedMode('auth token did not stabilize');
      return false;
    }

    if (!await _waitForFirebaseInstallationsReady()) {
      _enterStartupDegradedMode('Firebase Installations did not stabilize');
      return false;
    }

    if (!await _waitForFirestoreReachable(user.uid)) {
      _enterStartupDegradedMode('Firestore not reachable');
      return false;
    }

    _noncriticalReadsAllowed = true;
    _setStartupPhase(StartupPhase.noncriticalReadsAllowed);
    debugPrint('🌐 NONCRITICAL READS ENABLED');
    _completeNoncriticalGate(true);
    _cancelStartupWatchdogs();
    return true;
  }

  Future<void> _awaitStartupFirestoreStabilization(int generation) async {
    if (_startupFirestoreStabilizationApplied ||
        !_isValidStartupGeneration(generation)) {
      return;
    }

    _startupFirestoreStabilizationApplied = true;
    debugPrint('🌐 FIRST FIRESTORE TOUCH DELAY ACTIVE');
    debugPrint('🌐 STARTUP FIRESTORE STABILIZATION WINDOW → 2500ms');
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!_isValidStartupGeneration(generation)) return;
  }

  void _startNoncriticalStartupReads() {
    if (!_noncriticalReadsAllowed) {
      debugPrint('🌐 RECOVERY LOOP SUPPRESSED → noncritical reads gated');
      return;
    }
    if (_noncriticalStartupStarted) {
      debugPrint(
        '🌐 RECOVERY LOOP SUPPRESSED → noncritical reads already running',
      );
      return;
    }

    _noncriticalStartupStarted = true;
    final generation = _startupSessionGeneration;
    unawaited(_loadRemainingDataInBackground(generation));
  }

  Future<void> _clearAuthDependentCaches([String? previousUid]) async {
    if (Hive.isBoxOpen('currentUserBox')) {
      final box = Hive.box<String>('currentUserBox');
      await box.delete('currentUserId');
      await box.delete('emailVerified');
      await box.delete('savedEmail');
      await box.delete('savedPassword');
      await box.delete('rememberMe');
      await box.delete('receiveNews');
      if (previousUid != null) {
        await box.delete('username_$previousUid');
      }
    }

    if (Hive.isBoxOpen('userBox')) {
      await Hive.box<String>('userBox').clear();
    }

    if (Hive.isBoxOpen('userDataBox')) {
      final box = Hive.box<Map<dynamic, dynamic>>('userDataBox');
      if (previousUid == null) {
        await box.clear();
      } else {
        await box.delete(previousUid);
        await box.delete(previousUid.toLowerCase());
      }
    }

    await DogsBoxManager.instance.clearIfReady();

    if (Hive.isBoxOpen('favoritesBox')) {
      await Hive.box<Dog>('favoritesBox').clear();
    }
  }

  bool synchronizeAuthenticatedUid(String authoritativeUid) {
    if (_currentUserId == authoritativeUid) return false;

    final previousUid = _currentUserId;
    final changedAuthenticatedUser =
        previousUid != null && previousUid != 'guest';

    if (changedAuthenticatedUser) {
      _clearAuthMemoryState(notify: false);
    }

    _currentUserId = authoritativeUid;
    _savedParksLoaded = false;
    notifyListeners();
    return changedAuthenticatedUser;
  }

  @visibleForTesting
  bool isUserSessionCurrent(String uid, int generation) {
    return _currentUserId == uid && _startupSessionGeneration == generation;
  }

  Future<void> initializeAuthenticatedUser(
    User user, {
    String source = 'freshLogin',
  }) async {
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw StateError(
        'Firebase authentication changed before initialization.',
      );
    }

    final pending = _authenticatedSessionTransition;
    if (pending != null && _transitioningToUid == user.uid) {
      await pending;
      return;
    }

    if (_initializedForUid == user.uid) return;

    final previousUid = _currentUserId;
    final uidChanged = synchronizeAuthenticatedUid(user.uid);
    await _coordinateAuthenticatedSession(
      user,
      previousUid: uidChanged ? previousUid : null,
      source: source,
    );
  }

  Future<void> _coordinateAuthenticatedSession(
    User user, {
    required String source,
    String? previousUid,
  }) {
    final pending = _authenticatedSessionTransition;
    if (pending != null && _transitioningToUid == user.uid) return pending;

    late final Future<void> trackedTransition;
    trackedTransition =
        _startAuthenticatedSessionAfterUidSync(
          user,
          previousUid: previousUid,
          source: source,
        ).whenComplete(() {
          if (identical(_authenticatedSessionTransition, trackedTransition)) {
            _authenticatedSessionTransition = null;
            _transitioningToUid = null;
          }
        });
    _transitioningToUid = user.uid;
    _authenticatedSessionTransition = trackedTransition;
    return trackedTransition;
  }

  Future<void> resetAuthSessionForDiagnostics({required String reason}) async {
    debugPrint(
      '⚠️ FirebaseAuth diagnostic reset disabled → preserving session ($reason)',
    );
  }

  /// Test seam, mirroring the existing `PostCommentService(currentUser: ...)`
  /// convention: supplies the auth event stream so startup restoration can be
  /// driven deterministically. Production leaves it null and uses the real
  /// FirebaseAuth streams selected below, unchanged.
  @visibleForTesting
  Stream<User?> Function()? authEventsOverride;

  /// Companion seam to [authEventsOverride] for the "false null" guard, which
  /// must consult the SDK's own current user. Production reads the real
  /// singleton exactly as before.
  @visibleForTesting
  User? Function()? currentUserOverride;

  /// Restoration-only test seam. Downstream authenticated-session
  /// coordination (profile load, token refresh retries) reaches the real
  /// Firebase singletons, which is out of scope for startup-restoration tests
  /// and unreachable in a unit test. Setting this exercises the restoration
  /// state machine and routing without that coordination.
  ///
  /// Production never sets this: it stays false, so the authenticated session
  /// is coordinated exactly as before. It does not gate, relax, or bypass any
  /// verification, blocked/suspended, or profile-completion rule — those all
  /// live inside the coordination this flag merely defers in tests.
  @visibleForTesting
  bool debugSkipAuthenticatedSessionCoordination = false;

  User? _currentUser() {
    // Presence of the override decides, not its result — a legitimately null
    // override result must not fall through to the real singleton.
    final override = currentUserOverride;
    if (override != null) return override();
    return FirebaseAuth.instance.currentUser;
  }

  void startAuthListener() {
    if (_authSub != null) {
      debugPrint('🛑 Auth listener already active');
      return;
    }

    // Starts the moment we begin listening, so a stream that never delivers
    // its initial event cannot leave startup stuck in `restoring` forever.
    _authRestorationTimeoutTimer?.cancel();
    _authRestorationTimeoutTimer = Timer(_authRestorationTimeout, () {
      if (_disposed) return;
      _markAuthRestorationFailed(reason: 'timeout — no initial auth event');
    });

    debugPrint('🧨 startAuthListener INITIALIZED');
    _startupAuthWasRestored = _currentUser() != null;
    _startupAuthRestoreDelayApplied = false;
    if (_startupAuthWasRestored) {
      debugPrint(
        '🌐 AUTH RESTORE START → '
        'uid=${_currentUser()?.uid} '
        'source=startup currentUser preloaded',
      );
    }
    if (AuthTrap.authProbeMinimalMode) {
      debugPrint('🌐 PASSIVE AUTH OBSERVER ACTIVE');
    }

    final authEvents =
        authEventsOverride?.call() ??
        (AuthTrap.authProbeMinimalMode
            ? FirebaseAuth.instance.authStateChanges()
            : FirebaseAuth.instance.idTokenChanges());

    _authSub = authEvents.listen(
      (user) {
        // A successful emission — the only thing that may establish a
        // confirmed outcome. Recorded before the branches below, all of which
        // can return early.
        if (user != null) {
          _setAuthRestorationPhase(
            AuthRestorationPhase.authenticated,
            reason: 'auth event uid=${user.uid}',
          );
        } else if (_currentUser() == null) {
          _setAuthRestorationPhase(
            AuthRestorationPhase.unauthenticated,
            reason: 'auth event reported no user',
          );
        } else {
          // "False null": the stream said null while the SDK still holds a
          // user. Not a sign-out — the session is intact.
          _setAuthRestorationPhase(
            AuthRestorationPhase.authenticated,
            reason: 'false null while SDK still holds a user',
          );
        }

        debugPrint(
          'AUTH STATE CHANGED → user=${user?.uid ?? "NULL"} source=${AuthTrap.authProbeMinimalMode ? "authStateChanges" : "idTokenChanges"}',
        );
        // ─────────────────────────────
        // USER LOGGED OUT
        // ─────────────────────────────

        debugPrint(
          '🔥 AUTH LISTENER USER = ${user?.uid} / current=${_currentUser()?.uid}',
        );
        if (user == null) {
          _resetStartupReadiness();
          if (_hasSeenAuthenticatedUser) {
            debugPrint(
              '⚠️ Auth state changed to NULL after authenticated session',
            );
          } else {
            debugPrint('ℹ️ Auth state is NULL on startup → signed out');
          }

          if (_currentUser() != null) {
            debugPrint('⚠️ Ignoring false auth null state');
            return;
          }

          if (_suppressGuestModeOnce) {
            debugPrint(
              '🧹 Forced auth reset consumed → clearing session state',
            );
            _suppressGuestModeOnce = false;
            _clearAuthMemoryState();
            notifyListeners();
            return;
          }

          _clearAuthMemoryState();

          return;
        }

        if (user.isAnonymous) {
          _authRecoveryAttempted = false;
          _suppressGuestModeOnce = false;
          _hasSeenAuthenticatedUser = true;
          _resetStartupReadiness();
          debugPrint(
            '👤 ANONYMOUS AUTH DETECTED → uid=${user.uid} source=${AuthTrap.authProbeMinimalMode ? "authStateChanges" : "idTokenChanges"}',
          );
          _activateGuestSessionState();
          debugPrint("👤 Guest mode activated from anonymous auth");
          return;
        }

        // ─────────────────────────────
        // USER LOGGED IN
        // ─────────────────────────────
        final previousUid = _currentUserId;
        final uidChanged = synchronizeAuthenticatedUid(user.uid);

        if (!uidChanged &&
            (_initializedForUid == user.uid ||
                _initializingForUid == user.uid)) {
          debugPrint('🌐 INITUSER DUPLICATE SKIPPED → uid=${user.uid}');
          return;
        }

        if (!uidChanged && _scheduledInitUserForUid == user.uid) {
          debugPrint('🌐 INITUSER DUPLICATE SKIPPED → uid=${user.uid}');
          return;
        }

        _authRecoveryAttempted = false;
        _suppressGuestModeOnce = false;
        _hasSeenAuthenticatedUser = true;
        if (!uidChanged) _resetStartupReadiness();
        final now = DateTime.now().toIso8601String();
        debugPrint(
          '🌐 AUTH USER DETECTED → uid=${user.uid} source=authStateChanges time=$now',
        );
        if (AuthTrap.authProbeMinimalMode) {
          debugPrint('🌐 AUTH MINIMAL MODE ACTIVE → skip token diagnostics');
        } else {
          AuthTrap.scheduleTokenDiagnostics();
        }

        _scheduledInitUserForUid = user.uid;
        debugPrint('🌐 INITUSER SCHEDULED → uid=${user.uid}');
        if (debugSkipAuthenticatedSessionCoordination) return;
        unawaited(
          _coordinateAuthenticatedSession(
            user,
            previousUid: uidChanged ? previousUid : null,
            source: 'authStateChanges',
          ),
        );
      },
      onError: (e, stack) {
        debugPrint('⚠️ idTokenChanges listener error → $e');
        // Never a sign-out: if restoration had already confirmed an
        // outcome that outcome is preserved, and if it had not, the state
        // becomes `failed` (unknown + retryable), never `unauthenticated`.
        // No signOut() is performed here.
        _markAuthRestorationFailed(reason: 'auth stream error');
      },
    );

    // The hot-restart resync reconciles against the real FirebaseAuth
    // singleton, which is meaningless (and unreachable) when the auth stream
    // has been injected for a test. Production always runs it.
    if (authEventsOverride == null) {
      unawaited(_resyncAuthAfterHotRestart());
    }
  }

  Future<void> _startAuthenticatedSessionAfterUidSync(
    User user, {
    required String source,
    String? previousUid,
  }) async {
    if (previousUid != null) {
      await _clearAuthDependentCaches(previousUid);
    }

    if (_currentUserId != user.uid ||
        FirebaseAuth.instance.currentUser?.uid != user.uid) {
      debugPrint('🌐 AUTH SESSION START ABORTED → stale uid=${user.uid}');
      return;
    }

    if (previousUid != null && Hive.isBoxOpen('currentUserBox')) {
      await Hive.box<String>('currentUserBox').put('currentUserId', user.uid);
      if (_currentUserId != user.uid ||
          FirebaseAuth.instance.currentUser?.uid != user.uid) {
        return;
      }
    }

    await _startAuthenticatedSession(user, source: source);
  }

  Future<void> _resyncAuthAfterHotRestart() async {
    final generation = _startupSessionGeneration;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_isValidStartupGeneration(generation)) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (user.isAnonymous) {
      _activateGuestSessionState();
      return;
    }
    if (_currentUserId == user.uid ||
        _initializedForUid == user.uid ||
        _initializingForUid == user.uid ||
        _scheduledInitUserForUid == user.uid) {
      return;
    }

    debugPrint('🌐 HOT RESTART AUTH RESYNC → ${user.uid}');
    _hasSeenAuthenticatedUser = true;
    _resetStartupReadiness();
    _scheduledInitUserForUid = user.uid;
    debugPrint('🌐 INITUSER SCHEDULED → uid=${user.uid}');
    unawaited(_startAuthenticatedSession(user, source: 'hotRestart'));
  }

  Future<void> _startAuthenticatedSession(
    User user, {
    required String source,
  }) async {
    if (user.isAnonymous) {
      _activateGuestSessionState();
      return;
    }

    final generation = _startupSessionGeneration;
    final restoredSession =
        _startupAuthWasRestored &&
        !_startupAuthRestoreDelayApplied &&
        source != 'freshLogin';

    if (restoredSession) {
      _startupAuthRestoreDelayApplied = true;
      debugPrint(
        '🌐 AUTH RESTORE STABILIZATION WINDOW → 1500ms '
        '(source=$source uid=${user.uid})',
      );
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!_isValidStartupGeneration(generation)) {
        debugPrint(
          '🌐 AUTH RESTORE STABILIZATION ABORTED → generation changed',
        );
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != user.uid) {
        debugPrint(
          '🌐 AUTH RESTORE STABILIZATION ABORTED → '
          'uid=${user.uid} current=${currentUser?.uid ?? "NULL"}',
        );
        return;
      }
    }

    await initUser(authUser: user);
  }

  void stopFirestoreListeners() {
    debugPrint('🛑 Cancelling Firestore listeners');

    _unreadNotificationsSub?.cancel();
    _unreadNotificationsSub = null;

    _lostSub?.cancel();
    _lostSub = null;

    _foundSub?.cancel();
    _foundSub = null;

    _userDocSub?.cancel();
    _userDocSub = null;
  }

  String? centerDogsId;

  void openCenterDogs(String centerId) {
    centerDogsId = centerId;
    notifyListeners();
  }

  void closeCenterDogs() {
    centerDogsId = null;
    notifyListeners();
  }

  String? adoptionDogOverlayId;
  Dog? adoptionDogOverlayDog;

  void openAdoptionDogOverlay(String dogId, {Dog? dog}) {
    adoptionDogOverlayId = dogId;
    adoptionDogOverlayDog = dog;
    notifyListeners();
  }

  void closeAdoptionDogOverlay() {
    adoptionDogOverlayId = null;
    adoptionDogOverlayDog = null;
    notifyListeners();
  }

  void setPendingRoute(String route, {Map<String, dynamic>? args}) {
    _pendingRoute = route;
    _pendingRouteArgs = args;
    notifyListeners();
  }

  void clearPendingRoute() {
    _pendingRoute = null;
    _pendingRouteArgs = null;
    notifyListeners(); // ✅ این خط
  }

  void startPlaydateAtPark(Map<String, dynamic> park) {
    setActivePlaydatePark(park); // فقط این
    //_selectedParkForPlaydate = park;
    //_isPlaydateParkStepOpen = true;
    //notifyListeners();
  }

  void closePlaydateParkStep() {
    //_isPlaydateParkStepOpen = false;
    //notifyListeners();
  }

  Future<void>? _vetLoadFuture;

  Future<void> ensureVetLoaded() {
    if (_vetLoaded) return Future.value();
    _vetLoadFuture ??= _loadVetData();
    return _vetLoadFuture!;
  }

  Future<void> _loadVetData() async {
    // TODO: اینجا همون Firestore queryها / permissionها / locationها
    // را انجام بده
    _vetLoaded = true;
    notifyListeners();
  }

  Future<void> waitForFirestoreReady() async {
    final firestore = FirebaseFirestore.instance;

    debugPrint('🔄 [Firestore] Waiting for readiness...');

    for (int i = 0; i < 5; i++) {
      try {
        debugPrint('🌐 FIRESTORE PASSIVE MODE ACTIVE');
        await firestore
            .collection('users')
            .limit(1)
            .get()
            .timeout(_startupProbeTimeout);

        debugPrint('✅ [Firestore] NETWORK READY');
        return;
      } catch (e) {
        debugPrint('⏳ [Firestore] retry ${i + 1} → $e');

        await Future.delayed(Duration(seconds: i + 1));
      }
    }

    debugPrint('⚠️ [Firestore] unavailable');
  }

  Future<User?> _waitForStableAuthUser(
    String expectedUid, {
    User? initialUser,
  }) async {
    final auth = FirebaseAuth.instance;
    User? user = initialUser?.uid == expectedUid
        ? initialUser
        : auth.currentUser;

    if (AuthTrap.authProbeMinimalMode) {
      final passiveUser = user?.uid == expectedUid ? user : auth.currentUser;
      if (passiveUser != null && passiveUser.uid == expectedUid) {
        debugPrint('🌐 AUTH MINIMAL MODE ACTIVE → currentUser accepted');
        debugPrint('🌐 TOKEN PROBES DISABLED');
        return passiveUser;
      }
    }

    for (int i = 0; i < 8; i++) {
      user ??= auth.currentUser;

      if (user != null && user.uid == expectedUid) {
        if (AuthTrap.shouldSuppressTokenProbe(
          'AppState._waitForStableAuthUser',
        )) {
          debugPrint(
            '🌐 TOKEN PROBE COOLDOWN ACTIVE → preserving currentUser without token probe',
          );
          return user;
        }

        var tokenCompleted = false;
        unawaited(
          Future.delayed(const Duration(seconds: 15)).then((_) {
            if (!tokenCompleted) {
              debugPrint(
                '⏳ Auth token still resolving on native side '
                '(${i + 1}/8) → uid=${user?.uid}',
              );
            }
          }),
        );

        try {
          final token = await user.getIdToken(false);
          tokenCompleted = true;
          if (token == null || token.isEmpty) {
            debugPrint('⚠️ Auth token empty (${i + 1}/8) → uid=${user.uid}');
          } else {
            AuthTrap.recordTokenProbeSuccess('AppState._waitForStableAuthUser');
            debugPrint('✅ Auth token ready → uid=${user.uid}');
            return user;
          }
        } on FirebaseAuthException catch (e) {
          tokenCompleted = true;
          AuthTrap.recordTokenProbeFailure(
            'AppState._waitForStableAuthUser',
            e,
          );
          debugPrint(
            '⚠️ Auth token not ready yet (${i + 1}/8) '
            '[plugin=${e.plugin} code=${e.code}] → ${e.message ?? e}',
          );
        } catch (e) {
          tokenCompleted = true;
          AuthTrap.recordTokenProbeFailure(
            'AppState._waitForStableAuthUser',
            e,
          );
          debugPrint('⚠️ Auth token not ready yet (${i + 1}/8) → $e');
        } finally {
          tokenCompleted = true;
        }
      }

      try {
        user = await auth
            .idTokenChanges()
            .where((u) => u != null && u.uid == expectedUid)
            .first
            .timeout(Duration(seconds: i == 0 ? 8 : 4));

        debugPrint('🔁 idTokenChanges emitted expected uid → ${user?.uid}');
      } catch (e) {
        user = auth.currentUser;
        debugPrint('⏳ Waiting for idTokenChanges (${i + 1}/8) → $e');
        // Keep polling below; auth can briefly lag app startup on iOS.
      }

      await Future.delayed(Duration(milliseconds: 500 + (i * 150)));
    }

    final stableUser = auth.currentUser;
    if (stableUser != null && stableUser.uid == expectedUid) {
      debugPrint(
        '⚠️ Auth user never stabilized, but currentUser is still valid → '
        'preserving session expectedUid=$expectedUid authUid=${stableUser.uid}',
      );
      return stableUser;
    }

    debugPrint(
      '❌ Auth user never stabilized '
      '(expectedUid=$expectedUid authUid=${FirebaseAuth.instance.currentUser?.uid})',
    );
    return null;
  }

  Future<void> initUser({User? authUser}) async {
    final user = authUser ?? FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (user?.isAnonymous == true) {
      _activateGuestSessionState();
      debugPrint('🌐 INITUSER SKIPPED → anonymous guest session');
      return;
    }

    if (uid != null && _initializingForUid == uid) {
      debugPrint('🌐 INITUSER DUPLICATE SKIPPED → uid=$uid');
      return;
    }

    if (uid != null && _scheduledInitUserForUid == uid) {
      debugPrint('🌐 INITUSER START ALLOWED → uid=$uid');
      _scheduledInitUserForUid = null;
    }

    final freshUser = user == null
        ? null
        : await _waitForStableAuthUser(user.uid, initialUser: user);

    if (freshUser == null) {
      if (user != null && FirebaseAuth.instance.currentUser?.uid == user.uid) {
        _currentUserId = user.uid;
        _initializedForUid = user.uid;
      }
      if (_scheduledInitUserForUid == uid) {
        _scheduledInitUserForUid = null;
      }
      _isUserProfileReady = true;
      _isUserInitialized = true;
      debugPrint('🌐 INITUSER FINISHED → uid=${uid ?? "n/a"}');
      unawaited(_clearAuthDependentCaches());
      notifyListeners();
      return;
    }

    _currentUserId = freshUser.uid;
    _initializedForUid = freshUser.uid;
    _initializingForUid = freshUser.uid;
    FirestoreReadinessGate.instance.markAuthStabilized(freshUser.uid);
    debugPrint('🧩 AppState.initUser start → uid=$_currentUserId');

    if (!_isUserProfileReady) {
      _isUserProfileReady = true;
      _isUserInitialized = true;
      notifyListeners();
      debugPrint('🌐 FIRST RENDER UNBLOCKED → uid=$_currentUserId');
    }

    try {
      final startupReady = await _establishStartupReadiness(freshUser);

      if (!startupReady) {
        _isUserProfileReady = true;
        _isUserInitialized = true;
        debugPrint('🌐 STARTUP DEGRADED MODE → heavy startup reads deferred');
        if (!AuthTrap.authProbeMinimalMode) {
          _scheduleStartupReadinessRetry(freshUser);
        }
        return;
      }

      unawaited(() async {
        try {
          debugPrint(
            '🌐 FIRST FIRESTORE READ START → loadUsernameFromFirebase',
          );

          final usernameLoaded = await loadUsernameFromFirebase();
          if (usernameLoaded) {
            debugPrint(
              '🌐 FIRST FIRESTORE READ RESULT → '
              'username=$_username premium=$_isPremium',
            );
            debugPrint(
              '✅ Username & business loaded → $_username / status=$_businessStatus',
            );
            debugPrint('🌐 SESSION FULLY STABLE → uid=$_currentUserId');
            _cancelStartupWatchdogs();
          } else {
            debugPrint(
              '🌐 CRITICAL READ DEGRADED FALLBACK → '
              'loadUsernameFromFirebase',
            );
          }
          if (_startupFirestoreDiagnosticsEnabled) {
            await _runFirestoreStartupDiagnostics(freshUser.uid);
          } else {
            debugPrint(
              '🌐 FIRESTORE STARTUP SERIAL MODE → diagnostics disabled by default',
            );
            debugPrint(
              '🌐 STARTUP PROBE SKIPPED → diagnostics disabled by default',
            );
            debugPrint('🌐 STARTUP PROBE REDUCED → serial mode');
          }
          notifyListeners();
        } catch (e) {
          debugPrint(
            '🌐 FIRST FIRESTORE READ RESULT → loadUsernameFromFirebase failed: $e',
          );
          debugPrint('❌ loadUsernameFromFirebase failed: $e');
        }
      }());

      final currentUid = _currentUserId!;
      final currentGeneration = _startupSessionGeneration;
      _userDocSub?.cancel();
      _userDocSub = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .snapshots()
          .listen(
            (doc) {
              if (!isUserSessionCurrent(currentUid, currentGeneration)) {
                return;
              }
              final business = doc.data()?['business'];
              final newStatus = business?['status'];
              final newBusinessId = business?['businessId']?.toString();
              final newVerified = business?['isVerified'] == true;

              final creator = doc.data()?['creator'];
              final newCreatorEnabled = creator?['enabled'] == true;
              final newCreatorStatus = creator?['status']?.toString();
              final newCreatorLevel = creator?['level']?.toString();
              final newCreatorReferralCode = creator?['referralCode']
                  ?.toString();
              final newCreatorCampaign = creator?['currentCampaign']
                  ?.toString();

              final accountStatus = doc.data()?['accountStatus'];
              final newSuspended =
                  accountStatus == 'suspended' || accountStatus == 'blocked';
              final newReason = doc.data()?['moderationReason'] as String?;

              if (_businessStatus != newStatus ||
                  _isBusinessVerified != newVerified ||
                  _isAccountSuspended != newSuspended ||
                  _accountModerationReason != newReason ||
                  _creatorEnabled != newCreatorEnabled ||
                  _creatorStatus != newCreatorStatus ||
                  _creatorLevel != newCreatorLevel ||
                  _creatorReferralCode != newCreatorReferralCode ||
                  _creatorCampaign != newCreatorCampaign) {
                _businessStatus = newStatus;
                _isBusinessVerified = newVerified;
                _isAccountSuspended = newSuspended;
                _accountModerationReason = newReason;
                _creatorEnabled = newCreatorEnabled;
                _creatorStatus = newCreatorStatus;
                _creatorLevel = newCreatorLevel;
                _creatorReferralCode = newCreatorReferralCode;
                _creatorCampaign = newCreatorCampaign;
                notifyListeners();
              }

              if (newBusinessId == null || newBusinessId.isEmpty) {
                if (_businessId != null) {
                  _businessId = null;
                  notifyListeners();
                }
              } else {
                if (_businessId != newBusinessId) {
                  _businessId = newBusinessId;
                  notifyListeners();
                }
              }
            },
            onError: (error) {
              debugPrint('❌ user doc listener error: $error');
            },
          );

      _startNoncriticalStartupReads();

      _isUserProfileReady = true;
      _isUserInitialized = true;
      debugPrint('✅ initUser completed');
    } catch (e) {
      debugPrint('❌ initUser error: $e');
      _isUserProfileReady = true;
      _isUserInitialized = true;
    } finally {
      if (_initializingForUid == uid) {
        _initializingForUid = null;
      }
      debugPrint('🌐 INITUSER FINISHED → uid=${uid ?? "n/a"}');
      notifyListeners();
    }
  }

  // متد جدید برای لود بقیه داده‌ها در پس‌زمینه
  Future<void> _loadRemainingDataInBackground([int? generation]) async {
    if (generation != null && !_isValidStartupGeneration(generation)) {
      debugPrint(
        '🌐 RECOVERY LOOP SUPPRESSED → background reads stale session',
      );
      return;
    }
    if (!_noncriticalReadsAllowed) {
      debugPrint('🌐 RECOVERY LOOP SUPPRESSED → background reads before gate');
      return;
    }

    debugPrint('🔄 Starting background data loading...');
    if (FirestoreRecovery.passiveMode) {
      debugPrint('🌐 OFFLINE STARTUP SURVIVAL MODE');
      if (FirestoreRecovery.isRecoveryCooldownActive) {
        debugPrint('🌐 DEGRADED STARTUP CACHE MODE → background loaders');
      }
    }

    try {
      if (generation != null && !_isValidStartupGeneration(generation)) {
        debugPrint(
          '🌐 RECOVERY LOOP SUPPRESSED → background reads stale session',
        );
        return;
      }
      await loadMyDogs();
      if (generation != null && !_isValidStartupGeneration(generation)) return;
      await Future.delayed(const Duration(milliseconds: 600));

      if (generation != null && !_isValidStartupGeneration(generation)) return;
      await loadAllDogsForDiscovery();
      if (generation != null && !_isValidStartupGeneration(generation)) return;
      await Future.delayed(const Duration(milliseconds: 1200));

      if (generation != null && !_isValidStartupGeneration(generation)) return;
      await loadSavedParksFromFirebase();
      if (generation != null && !_isValidStartupGeneration(generation)) return;
      await Future.delayed(const Duration(milliseconds: 2400));

      if (generation != null && !_isValidStartupGeneration(generation)) return;
      await loadSubscriptionFromFirestore();
    } catch (e) {
      debugPrint('❌ Background loading error: $e');
    }

    debugPrint('✅ Background data loading completed');
  }

  Future<void> _runFirestoreStartupDiagnostics(String uid) async {
    if (_firestoreStartupDiagnosticsRan) return;
    _firestoreStartupDiagnosticsRan = true;

    debugPrint('🌐 FIRESTORE STARTUP SERIAL MODE');
    if (!_startupFirestoreDiagnosticsEnabled) {
      debugPrint('🌐 STARTUP PROBE SKIPPED → diagnostics disabled by default');
      return;
    }

    final runtimeOptions = Firebase.app().options;
    final configuredOptions = DefaultFirebaseOptions.currentPlatform;

    debugPrint(
      '🌐 FIREBASE RUNTIME OPTIONS → projectId=${runtimeOptions.projectId} appId=${runtimeOptions.appId} iosBundleId=${runtimeOptions.iosBundleId ?? "n/a"}',
    );
    debugPrint(
      '🌐 FIREBASE CONFIG OPTIONS → projectId=${configuredOptions.projectId} appId=${configuredOptions.appId} iosBundleId=${configuredOptions.iosBundleId ?? "n/a"}',
    );
    debugPrint(
      '🌐 GOOGLE SERVICE IOS BUNDLE TARGET → ${configuredOptions.iosBundleId ?? "n/a"}',
    );
    debugPrint(
      '🌐 FIREBASE OPTIONS IOS BUNDLE TARGET → ${runtimeOptions.iosBundleId ?? "n/a"}',
    );

    final firestore = FirebaseFirestore.instance;

    debugPrint('🌐 GLOBAL FIRESTORE PROBE START');
    try {
      final snapshot = await firestore.collection('ping').limit(1).get();
      debugPrint(
        '🌐 GLOBAL FIRESTORE PROBE SUCCESS → collection=ping docs=${snapshot.size} source=default',
      );
    } on FirebaseException catch (e) {
      debugPrint('🌐 GLOBAL FIRESTORE PROBE FAILED');
      debugPrint('🌐 GLOBAL FIRESTORE ERROR CODE → ${e.code}');
      debugPrint(
        '🌐 GLOBAL FIRESTORE ERROR MESSAGE → ${e.message ?? e.toString()}',
      );
      await _logFirestoreCacheProbe(
        firestore: firestore,
        uid: uid,
        globalProbeFailed: true,
      );
      return;
    } catch (e) {
      debugPrint('🌐 GLOBAL FIRESTORE PROBE FAILED');
      debugPrint('🌐 GLOBAL FIRESTORE ERROR CODE → unknown');
      debugPrint('🌐 GLOBAL FIRESTORE ERROR MESSAGE → $e');
      await _logFirestoreCacheProbe(
        firestore: firestore,
        uid: uid,
        globalProbeFailed: true,
      );
      return;
    }

    await _logFirestoreCacheProbe(
      firestore: firestore,
      uid: uid,
      globalProbeFailed: false,
    );
  }

  Future<void> _logFirestoreCacheProbe({
    required FirebaseFirestore firestore,
    required String uid,
    required bool globalProbeFailed,
  }) async {
    if (globalProbeFailed) {
      debugPrint('🌐 CORE DATA PROBES SKIPPED → global probe failed');
      return;
    }

    Future<void> probeDoc(
      String label,
      DocumentReference<Map<String, dynamic>> docRef, {
      String? docDescription,
      List<String>? fieldChecks,
    }) async {
      debugPrint(
        '🌐 CORE DATA PROBE $label → path=${docDescription ?? docRef.path} source=default',
      );
      try {
        final defaultDoc = await docRef.get();
        debugPrint(
          '🌐 CORE DATA PROBE $label → default exists=${defaultDoc.exists} hasData=${defaultDoc.data() != null}',
        );
        if (fieldChecks != null && defaultDoc.data() != null) {
          for (final field in fieldChecks) {
            debugPrint(
              '🌐 CORE DATA PROBE $label → default field $field=${defaultDoc.data()![field] != null}',
            );
          }
        }
      } on FirebaseException catch (e) {
        debugPrint(
          '🌐 CORE DATA PROBE $label → default failed code=${e.code} message=${e.message ?? e.toString()}',
        );
      } catch (e) {
        debugPrint(
          '🌐 CORE DATA PROBE $label → default failed code=unknown message=$e',
        );
      }

      debugPrint(
        '🌐 CORE DATA PROBE $label → path=${docDescription ?? docRef.path} source=cache',
      );
      try {
        final cacheDoc = await docRef.get(
          const GetOptions(source: Source.cache),
        );
        debugPrint(
          '🌐 CORE DATA PROBE $label → cache exists=${cacheDoc.exists} hasData=${cacheDoc.data() != null}',
        );
        if (fieldChecks != null && cacheDoc.data() != null) {
          for (final field in fieldChecks) {
            debugPrint(
              '🌐 CORE DATA PROBE $label → cache field $field=${cacheDoc.data()![field] != null}',
            );
          }
        }
      } on FirebaseException catch (e) {
        debugPrint(
          '🌐 CORE DATA PROBE $label → cache failed code=${e.code} message=${e.message ?? e.toString()}',
        );
      } catch (e) {
        debugPrint(
          '🌐 CORE DATA PROBE $label → cache failed code=unknown message=$e',
        );
      }
    }

    Future<void> probeRawUserDoc() async {
      final docRef = firestore.collection('users').doc(uid);
      debugPrint('🌐 USER DOC RAW READ START → users/$uid source=default');
      try {
        final defaultDoc = await docRef.get();
        debugPrint('🌐 USER DOC RAW EXISTS → ${defaultDoc.exists}');
        debugPrint(
          '🌐 USER DOC RAW KEYS → ${defaultDoc.data()?.keys.toList() ?? const []}',
        );
      } on FirebaseException catch (e) {
        debugPrint(
          '🌐 USER DOC RAW READ FAILED → code=${e.code} message=${e.message ?? e.toString()}',
        );
      } catch (e) {
        debugPrint('🌐 USER DOC RAW READ FAILED → code=unknown message=$e');
      }
    }

    Future<void> probeDogQuery(
      String label,
      Query<Map<String, dynamic>> query,
      String description,
    ) async {
      debugPrint('🌐 DOGS PROBE $label → $description source=default');
      try {
        final defaultSnap = await query.limit(5).get();
        debugPrint(
          '🌐 DOGS PROBE $label → default docs=${defaultSnap.size} empty=${defaultSnap.docs.isEmpty}',
        );
      } on FirebaseException catch (e) {
        debugPrint(
          '🌐 DOGS PROBE $label → default failed code=${e.code} message=${e.message ?? e.toString()}',
        );
      } catch (e) {
        debugPrint(
          '🌐 DOGS PROBE $label → default failed code=unknown message=$e',
        );
      }

      debugPrint('🌐 DOGS PROBE $label → $description source=cache');
      try {
        final cacheSnap = await query
            .limit(5)
            .get(const GetOptions(source: Source.cache));
        debugPrint(
          '🌐 DOGS PROBE $label → cache docs=${cacheSnap.size} empty=${cacheSnap.docs.isEmpty}',
        );
      } on FirebaseException catch (e) {
        debugPrint(
          '🌐 DOGS PROBE $label → cache failed code=${e.code} message=${e.message ?? e.toString()}',
        );
      } catch (e) {
        debugPrint(
          '🌐 DOGS PROBE $label → cache failed code=unknown message=$e',
        );
      }
    }

    Future<void> probeRawDogsSample() async {
      final dogsRef = firestore.collection('dogs');
      debugPrint('🌐 DOGS RAW SAMPLE START → collection=dogs source=default');
      try {
        final snap = await dogsRef.limit(5).get();
        debugPrint('🌐 DOGS RAW SAMPLE → default docs=${snap.size}');
        for (final doc in snap.docs.take(3)) {
          debugPrint(
            '🌐 DOGS RAW SAMPLE DOC → id=${doc.id} keys=${doc.data().keys.toList()}',
          );
        }
      } on FirebaseException catch (e) {
        debugPrint(
          '🌐 DOGS RAW SAMPLE FAILED → code=${e.code} message=${e.message ?? e.toString()}',
        );
      } catch (e) {
        debugPrint('🌐 DOGS RAW SAMPLE FAILED → code=unknown message=$e');
      }
    }

    Future<void> probeCollectionCount(
      String label,
      String collectionName,
    ) async {
      final ref = firestore.collection(collectionName);
      debugPrint(
        '🌐 CORE DATA PROBE $label → collection=$collectionName source=default',
      );
      try {
        final defaultSnap = await ref.limit(5).get();
        debugPrint(
          '🌐 CORE DATA PROBE $label → default docs=${defaultSnap.size} empty=${defaultSnap.docs.isEmpty}',
        );
      } on FirebaseException catch (e) {
        debugPrint(
          '🌐 CORE DATA PROBE $label → default failed code=${e.code} message=${e.message ?? e.toString()}',
        );
      } catch (e) {
        debugPrint(
          '🌐 CORE DATA PROBE $label → default failed code=unknown message=$e',
        );
      }

      debugPrint(
        '🌐 CORE DATA PROBE $label → collection=$collectionName source=cache',
      );
      try {
        final cacheQuery = ref.limit(5);
        final cacheSnap = await cacheQuery.get(
          const GetOptions(source: Source.cache),
        );
        debugPrint(
          '🌐 CORE DATA PROBE $label → cache docs=${cacheSnap.size} empty=${cacheSnap.docs.isEmpty}',
        );
      } on FirebaseException catch (e) {
        debugPrint(
          '🌐 CORE DATA PROBE $label → cache failed code=${e.code} message=${e.message ?? e.toString()}',
        );
      } catch (e) {
        debugPrint(
          '🌐 CORE DATA PROBE $label → cache failed code=unknown message=$e',
        );
      }
    }

    Future<void> probeCollectionSample(
      String label,
      String collectionName, {
      String? keyField,
    }) async {
      final ref = firestore.collection(collectionName);
      debugPrint(
        '🌐 ${label.toUpperCase()} COLLECTION SAMPLE → collection=$collectionName source=default',
      );
      try {
        final defaultQuery = ref.limit(3);
        final defaultSnap = await defaultQuery.get();
        debugPrint(
          '🌐 ${label.toUpperCase()} COLLECTION SAMPLE → default docs=${defaultSnap.size} empty=${defaultSnap.docs.isEmpty}',
        );
        for (final doc in defaultSnap.docs) {
          final keys = doc.data().keys.toList();
          final keyValue = keyField == null ? 'n/a' : doc.data()[keyField];
          debugPrint(
            '🌐 ${label.toUpperCase()} SAMPLE DOC → id=${doc.id} key=$keyValue keys=$keys',
          );
        }
      } on FirebaseException catch (e) {
        debugPrint(
          '🌐 ${label.toUpperCase()} COLLECTION SAMPLE → default failed code=${e.code} message=${e.message ?? e.toString()}',
        );
      } catch (e) {
        debugPrint(
          '🌐 ${label.toUpperCase()} COLLECTION SAMPLE → default failed code=unknown message=$e',
        );
      }
    }

    Future<void> probeKnownUserDoc(String knownUid) async {
      final docRef = firestore.collection('users').doc(knownUid);
      debugPrint('🌐 KNOWN USER DOC PROBE → users/$knownUid source=default');
      try {
        final defaultDoc = await docRef.get();
        debugPrint(
          '🌐 KNOWN USER DOC PROBE → default exists=${defaultDoc.exists}',
        );
        debugPrint(
          '🌐 KNOWN USER DOC PROBE → keys=${defaultDoc.data()?.keys.toList() ?? const []}',
        );
      } on FirebaseException catch (e) {
        debugPrint(
          '🌐 KNOWN USER DOC PROBE FAILED → code=${e.code} message=${e.message ?? e.toString()}',
        );
      } catch (e) {
        debugPrint('🌐 KNOWN USER DOC PROBE FAILED → code=unknown message=$e');
      }
    }

    await probeRawUserDoc();
    await probeCollectionSample('users', 'users', keyField: 'username');
    await probeCollectionSample(
      'businesses',
      'businesses',
      keyField: 'ownerUid',
    );
    await probeKnownUserDoc('vHz4bf2WYJhCyx3iMWYWBbi436R2');
    await probeDoc(
      'users/{uid}',
      firestore.collection('users').doc(uid),
      docDescription: 'users/$uid',
    );
    await probeDogQuery(
      'ownerId',
      firestore.collection('dogs').where('ownerId', isEqualTo: uid),
      "collection('dogs').where('ownerId', isEqualTo: '$uid')",
    );
    await probeDogQuery(
      'userId',
      firestore.collection('dogs').where('userId', isEqualTo: uid),
      "collection('dogs').where('userId', isEqualTo: '$uid')",
    );
    await probeDogQuery(
      'ownerUid',
      firestore.collection('dogs').where('ownerUid', isEqualTo: uid),
      "collection('dogs').where('ownerUid', isEqualTo: '$uid')",
    );
    await probeDogQuery(
      'uid',
      firestore.collection('dogs').where('uid', isEqualTo: uid),
      "collection('dogs').where('uid', isEqualTo: '$uid')",
    );
    await probeDogQuery(
      'subcollection',
      firestore.collection('users').doc(uid).collection('dogs'),
      "collection('users').doc('$uid').collection('dogs')",
    );
    await probeRawDogsSample();
    await probeCollectionCount('offers', 'offers');
    await probeCollectionCount('campaigns', 'campaigns');
    await probeCollectionCount('businessOffers', 'businessOffers');
    await probeCollectionCount('promotions', 'promotions');
    await probeCollectionCount('petshop_offers', 'petshop_offers');
    await probeDoc(
      'subscription',
      firestore.collection('users').doc(uid),
      docDescription: 'users/$uid',
      fieldChecks: const [
        'subscription',
        'subscriptionPlan',
        'subscriptionStatus',
        'isPremium',
      ],
    );
    await probeDoc(
      'savedParks',
      firestore.collection('users').doc(uid),
      docDescription: 'users/$uid',
      fieldChecks: const ['savedParks'],
    );
  }

  Future<void> openOrderSmart(
    String? sellerOrderId,
    String? rootOrderId, {
    String? returnId,
  }) async {
    final cleanSellerOrderId = sellerOrderId?.trim();
    final cleanRootOrderId = rootOrderId?.trim();

    if (cleanSellerOrderId != null && cleanSellerOrderId.isNotEmpty) {
      try {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => OrderDetailPage(
              sellerOrderId: cleanSellerOrderId,
              returnId: returnId,
            ),
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('❌ OPEN SELLER ORDER FAILED: $error');
        debugPrint('$stackTrace');
      }
      return;
    }

    if (cleanRootOrderId != null && cleanRootOrderId.isNotEmpty) {
      debugPrint("📦 OPEN BUYER ORDER ROOT IN MY ORDERS → $cleanRootOrderId");
      _pendingBuyerOrdersRootOrderId = cleanRootOrderId;
      _pendingBuyerOrdersReturnId = returnId?.trim().isEmpty == true
          ? null
          : returnId?.trim();
      setCurrentTab(NavTab.profile, preserveProfileSubPage: true);
      openProfileSubPage(ProfileSubPage.myOrders);
      return;
    }

    debugPrint("❌ NO ORDER ID AT ALL");
  }

  Future<bool> loadUsernameFromFirebase() async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return false;
    final generation = _startupSessionGeneration;

    final usedCache =
        FirestoreRecovery.passiveMode && _applyCachedUserProfile(uid);
    if (usedCache) notifyListeners();

    try {
      debugPrint(
        '📡 Loading user profile... '
        '(appUid=$uid authUid=${FirebaseAuth.instance.currentUser?.uid})',
      );
      debugPrint('🌐 FIRESTORE GATED READ → loadUsernameFromFirebase');

      var doc = await _criticalFirestoreRetry(
        () => FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get()
            .timeout(_firestoreReadTimeout),
        operationName: 'loadUsernameFromFirebase',
      );

      if (!isUserSessionCurrent(uid, generation)) return false;

      if (!doc.exists) {
        // Self-heal: the Auth account exists but its users/{uid} profile
        // does not (e.g. an interrupted signup, or an older client version
        // whose self-create payload was rejected by Firestore Rules — see
        // functions/user/ensureUserProfileCore.js). Provision it via the
        // trusted, idempotent server-side path and retry the read once.
        // Never falls back to writing protected/entitlement fields from
        // the client.
        debugPrint(
          '🌐 USER PROFILE MISSING → attempting self-heal via ensureUserProfile',
        );
        final healed = await _ensureUserProfileSelfHeal(uid);
        if (!isUserSessionCurrent(uid, generation)) return false;
        if (healed) {
          doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get()
              .timeout(_firestoreReadTimeout);
          if (!isUserSessionCurrent(uid, generation)) return false;
        }
      }

      final data = doc.data();
      var loadedFromNetwork = false;
      if (data != null) {
        _userRole = data['role'];
        _username = data['username'];
        _currentUserName = data['username'];

        final business = data['business'];
        _businessStatus = business?['status'];
        final storedBusinessId = business?['businessId']?.toString();
        if (storedBusinessId == null || storedBusinessId.isEmpty) {
          _businessId = await _resolveCanonicalBusinessId(
            uid: uid,
            storedBusinessId: null,
          );
        } else {
          try {
            final storedBusiness = await FirebaseFirestore.instance
                .collection('businesses')
                .doc(storedBusinessId)
                .get();
            if (storedBusiness.exists) {
              _businessId = storedBusinessId;
            } else {
              _businessId = await _resolveCanonicalBusinessId(
                uid: uid,
                storedBusinessId: null,
              );
            }
          } catch (error) {
            // Preserve the previous startup behavior when the reference
            // cannot be read: do not reject an existing business solely
            // because ownership validation is unavailable at login.
            debugPrint(
              'BUSINESS ID STARTUP READ FAILED; preserving stored ID '
              'uid=$uid businessId=$storedBusinessId error=$error',
            );
            _businessId = storedBusinessId;
          }
        }
        _isBusinessVerified = business?['isVerified'] == true;
        _businessSectors =
            (business?['sectors'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        _applyCreatorMap(data['creator']);

        debugPrint(
          '✅ Username & business loaded → $_username / status=$_businessStatus',
        );
        loadedFromNetwork = true;
      }
      notifyListeners();
      return loadedFromNetwork || usedCache;
    } catch (e) {
      if (!isUserSessionCurrent(uid, generation)) return false;
      debugPrint('❌ loadUsernameFromFirebase failed: $e');
      if (!usedCache) {
        debugPrint('🌐 OFFLINE STARTUP SURVIVAL MODE → profile unavailable');
      }
      return usedCache;
    }
  }

  /// Calls the trusted, idempotent `ensureUserProfile` Cloud Function to
  /// repair an Auth-only account that is missing its users/{uid} profile.
  /// Never writes protected/entitlement fields from the client; the
  /// function derives every field from the caller's own Auth record. Safe
  /// to call repeatedly — returns false (does not throw) on any failure so
  /// callers can fall back to existing degraded-mode behavior.
  Future<bool> _ensureUserProfileSelfHeal(String uid) async {
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('ensureUserProfile').call();
      debugPrint('🌐 ENSURE_USER_PROFILE self-heal succeeded → uid=$uid');
      return true;
    } catch (e) {
      debugPrint('❌ ensureUserProfile self-heal failed uid=$uid error=$e');
      return false;
    }
  }

  Future<void> _updateFcmToken(String uid) async {
    if (isGuest) {
      debugPrint('🚫 skip FCM update (guest)');
      return;
    }
    try {
      debugPrint('📲 FCM token update requested for $uid');
      final token = await FcmTokenService.generateAndSaveForCurrentUser(
        source: 'app_state',
      );

      if (token == null || token.isEmpty) {
        debugPrint('⚠️ FCM token is null');
        return;
      }

      debugPrint('📲 FCM token updated in Firestore');
    } catch (e) {
      debugPrint('❌ _updateFcmToken error: $e');
    }
  }

  Future<void> loadMyDogs() async {
    final uid = _currentUserId;

    if (isGuest || uid == null || uid.isEmpty) {
      debugPrint('🐾 Guest mode → clear my dogs');

      _myDogs.clear();

      notifyListeners();

      return;
    }
    final generation = _startupSessionGeneration;

    final usedCache = FirestoreRecovery.passiveMode && _applyCachedMyDogs(uid);
    if (usedCache) notifyListeners();

    try {
      debugPrint('🐾 Loading dogs for user $uid (passive Firestore)');

      final snapshot = await _criticalFirestoreRetry(
        () => FirebaseFirestore.instance
            .collection('dogs')
            .where('ownerId', isEqualTo: uid)
            .get(),
        operationName: 'loadMyDogs',
      );

      if (!isUserSessionCurrent(uid, generation)) return;

      _myDogs = snapshot.docs.map((doc) => Dog.fromFirestore(doc)).toList();

      debugPrint('🐾 Loaded ${_myDogs.length} my dogs');

      notifyListeners();
    } catch (e) {
      if (!isUserSessionCurrent(uid, generation)) return;
      debugPrint('❌ loadMyDogs failed: $e');

      if (!usedCache) {
        debugPrint('🌐 OFFLINE STARTUP SURVIVAL MODE → my dogs empty');

        _myDogs = [];

        notifyListeners();
      }
    }
  }

  Future<void> loadAllDogsForDiscovery() async {
    if (!_noncriticalReadsAllowed) {
      debugPrint(
        '🌐 RECOVERY LOOP SUPPRESSED → discovery dogs load before gate',
      );
      return;
    }

    final uid = _currentUserId;
    if (isGuest || uid == null || uid.isEmpty) {
      debugPrint("🐕 Guest mode → clear discovery dogs");

      _allDogs.clear();
      _invalidateAllDogsView();

      _savedParksLoaded = true;

      notifyListeners();

      return;
    }
    final generation = _startupSessionGeneration;

    final usedCache =
        FirestoreRecovery.passiveMode && _applyCachedDiscoveryDogs(uid);
    if (usedCache) notifyListeners();

    if (_suppressPassiveStartupRead('loadAllDogsForDiscovery')) {
      if (!usedCache) {
        debugPrint('🌐 OFFLINE STARTUP SURVIVAL MODE → discovery dogs empty');
        _discoveryDogs = [];
        _invalidateAllDogsView();
        notifyListeners();
      }
      return;
    }

    try {
      debugPrint('🐕 Loading ALL dogs for discovery (passive Firestore)');

      final snapshot = await _firestoreRetry(
        () => FirebaseFirestore.instance
            .collection('dogs')
            .where('isHidden', isEqualTo: false)
            .where('dogProfileVisible', isEqualTo: true)
            .where('ownerProfileVisible', isEqualTo: true)
            .limit(200)
            .get(),
        operationName: 'loadAllDogsForDiscovery',
      );

      if (!isUserSessionCurrent(uid, generation)) return;

      final dogs = snapshot.docs
          .map((doc) => Dog.fromFirestore(doc))
          .whereType<Dog>()
          .where((dog) => dog.ownerId != uid)
          .toList();

      _discoveryDogs = dogs;
      _invalidateAllDogsView();
      // محاسبه فاصله (موقعیت موقت)
      const userLat = 41.0082;
      const userLng = 28.9784;
      calculateDistances(userLat, userLng);
      sortDogsByDistance();

      debugPrint('🐕 Loaded ${_discoveryDogs.length} discovery dogs');
      notifyListeners();
    } catch (e) {
      if (!isUserSessionCurrent(uid, generation)) return;
      debugPrint('❌ loadAllDogsForDiscovery failed: $e');
      if (!usedCache) {
        debugPrint('🌐 OFFLINE STARTUP SURVIVAL MODE → discovery dogs empty');
        _discoveryDogs = [];
        _invalidateAllDogsView();
      }
    }
  }

  void startLostFoundListeners() {
    final appState = this;

    if (!_noncriticalReadsAllowed) {
      debugPrint(
        '🌐 RECOVERY LOOP SUPPRESSED → lost/found listeners before gate',
      );
      return;
    }

    if (appState.isGuestUser || _currentUserId == null) {
      debugPrint('🚫 Lost/Found listeners skipped (guest or no user)');
      return;
    }

    _lostSub?.cancel();
    _foundSub?.cancel();

    _lostSub = FirebaseFirestore.instance
        .collection('lost_pets')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          _lostDogsCount = snapshot.docs.length;
          notifyListeners();
        });

    _foundSub = FirebaseFirestore.instance
        .collection('found_pets')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          _foundDogsCount = snapshot.docs.length;
          notifyListeners();
        });
  }

  void openAdoptionInbox() => openProfileSubPage(ProfileSubPage.adoptionInbox);
  void selectParkForPlaydate(Map<String, dynamic> park) {
    _selectedSavedPark = park;
    notifyListeners();
  }

  void clearSelectedSavedPark() {
    _selectedSavedPark = null;
  }

  void openSavedParks() {
    if (_profileSubPage == ProfileSubPage.savedParks) return;
    _profileSubPage = ProfileSubPage.savedParks;
    notifyListeners();
  }

  void closeProfileSubPage() {
    debugPrint("🔥 closeProfileSubPage()");
    _clearAppointmentFlowSelection();
    _profileSubPage = ProfileSubPage.none;
    notifyListeners();
  }

  void openOtherUserProfile(String userId) {
    _otherUserProfileId = userId;
    notifyListeners();
  }

  void clearOtherUserProfile() {
    if (_otherUserProfileId == null) return; // ⛔️ حیاتی
    _otherUserProfileId = null;
    notifyListeners();
  }

  void openDogParks() {
    setCurrentTab(NavTab.dogParks);
  }

  bool get shouldIgnoreNotificationIconTap {
    return _shouldIgnoreNotificationIconTap() || _ignoreNextNotificationTap;
  }

  // ─────────────────────────────────────
  // 🔔 NOTIFICATIONS OVERLAY
  // ─────────────────────────────────────

  void openNotifications() {
    if (_shouldIgnoreNotificationIconTap()) {
      debugPrint('🛑 Notification icon tap ignored (cooldown)');
      return;
    }

    if (_ignoreNextNotificationTap) {
      debugPrint('🛑 Ghost notification tap ignored');
      _ignoreNextNotificationTap = false;
      return;
    }

    // 🛑 اگر الان داخل playdate flow هستیم، اجازه باز کردن overlay نده

    if (_homeOverlay == HomeOverlay.notifications) {
      debugPrint('🛑 Notifications already open');
      return;
    }

    debugPrint('🔔 openNotifications CALLED');

    _homeOverlay = HomeOverlay.notifications;
    _selectedPark = null;

    notifyListeners();
  }

  void ignoreNotificationIconTapFor(Duration duration) {
    _ignoreNotificationIconUntil = DateTime.now().add(duration);
    debugPrint(
      '🛑 Will ignore notification icon taps until $_ignoreNotificationIconUntil',
    );
  }

  bool _shouldIgnoreNotificationIconTap() {
    if (_ignoreNotificationIconUntil == null) return false;
    return DateTime.now().isBefore(_ignoreNotificationIconUntil!);
  }

  void ignoreNextNotificationTap() {
    _ignoreNextNotificationTap = true;
  }

  void closeNotifications() {
    if (_homeOverlay != HomeOverlay.notifications) return;

    _homeOverlay = HomeOverlay.none;
    notifyListeners();
  }

  void closeOverlay() {
    _homeOverlay = HomeOverlay.none;
    notifyListeners();
  }

  void setInitialPlaydateRequest(String? requestId) {
    final newId = requestId?.trim();

    if (newId == null || newId.isEmpty) return;

    _initialPlaydateRequestId = newId;

    notifyListeners();
  }

  void setShouldConsumeInitialPlaydateRequest(bool value) {
    _shouldConsumeInitialPlaydateRequest = value;
    debugPrint("→ setShouldConsumeInitialPlaydateRequest: $value");
    notifyListeners();
  }

  void clearInitialPlaydateRequest() {
    if (_initialPlaydateRequestId == null) return;
    _initialPlaydateRequestId = null;
    notifyListeners();
  }

  void openLostDogDetail(String id) {
    activeLostDogId = id;
    notifyListeners();
  }

  void closeLostDogDetail() {
    activeLostDogId = null;
    notifyListeners();
  }

  void openDedicatedVaccinePage({
    required String businessId,
    required String patientId,
    required String vaccineId,
    String? petId,
  }) {
    activeVaccineBusinessId = businessId;
    activeVaccinePatientId = patientId;
    activeVaccineId = vaccineId;
    activeVaccinePetId = petId;
    notifyListeners();
  }

  void clearActiveVaccine() {
    activeVaccineBusinessId = null;
    activeVaccinePatientId = null;
    activeVaccineId = null;
    activeVaccinePetId = null;
    notifyListeners();
  }

  String? _initialAdoptionRequestId;
  String? get initialAdoptionRequestId => _initialAdoptionRequestId;

  String? _selectedAppointmentId;
  String? _selectedAppointmentCollection;

  String? _pendingUserAppointmentId;
  String? _pendingUserAppointmentCollection;

  String? get pendingUserAppointmentId => _pendingUserAppointmentId;
  String? get pendingUserAppointmentCollection =>
      _pendingUserAppointmentCollection;

  void requestUserAppointmentDetail({
    required String collection,
    required String appointmentId,
  }) {
    final normalizedCollection = collection.trim();
    final normalizedId = appointmentId.trim();
    const supportedCollections = {
      'vet_appointments',
      'groomy_appointments',
      'hotel_bookings',
      'pet_taxi_bookings',
    };

    if (!supportedCollections.contains(normalizedCollection) ||
        normalizedId.isEmpty) {
      debugPrint(
        '❌ APPOINTMENT ROUTE FAILED → collection=$normalizedCollection id=$normalizedId',
      );
      return;
    }

    if (_pendingUserAppointmentId == normalizedId &&
        _pendingUserAppointmentCollection == normalizedCollection) {
      return;
    }

    debugPrint(
      '🔔 ROUTE INTENT → collection=$normalizedCollection appointmentId=$normalizedId',
    );
    _pendingUserAppointmentId = normalizedId;
    _pendingUserAppointmentCollection = normalizedCollection;
    closeNotifications();
    setCurrentTab(NavTab.profile, preserveProfileSubPage: true);
    openProfileSubPage(ProfileSubPage.myAppointments);
    notifyListeners();
  }

  void consumePendingUserAppointmentDetail() {
    _pendingUserAppointmentId = null;
    _pendingUserAppointmentCollection = null;
  }

  String? get selectedAppointmentId => _selectedAppointmentId;
  String? get selectedAppointmentCollection => _selectedAppointmentCollection;

  void openBusinessDashboard() {
    debugPrint("🏥 OPEN BUSINESS DASHBOARD");

    openProfileSubPage(ProfileSubPage.businessDashboard);

    setCurrentTab(NavTab.profile);

    notifyListeners();
  }

  void setSelectedAppointmentId(String? id, {String? collection}) {
    _selectedAppointmentId = id;
    _selectedAppointmentCollection = collection;
    notifyListeners();
  }

  void setInitialAdoptionRequestId(String id) {
    _initialAdoptionRequestId = id;
    notifyListeners();
  }

  void consumeInitialAdoptionRequest() {
    _initialAdoptionRequestId = null;
  }

  bool _handleMarketplaceInvoiceNotification(
    String type,
    Map<String, dynamic> payload,
  ) {
    const invoiceTypes = {
      'invoice_issued',
      'invoice_approved',
      'invoice_rejected',
      'invoice_pending',
      'invoice_ready',
    };

    if (!invoiceTypes.contains(type)) return false;

    debugPrint('MARKETPLACE NOTIFICATION ROUTE type=$type payload=$payload');
    debugPrint('INVOICE ROUTE START');

    final collection =
        payload['appointmentCollection']?.toString().trim().isNotEmpty == true
        ? payload['appointmentCollection']!.toString().trim()
        : payload['collectionName']?.toString().trim().isNotEmpty == true
        ? payload['collectionName']!.toString().trim()
        : payload['collection']?.toString().trim().isNotEmpty == true
        ? payload['collection']!.toString().trim()
        : null;
    final appointmentId =
        payload['appointmentId']?.toString().trim().isNotEmpty == true
        ? payload['appointmentId']!.toString().trim()
        : payload['bookingId']?.toString().trim().isNotEmpty == true
        ? payload['bookingId']!.toString().trim()
        : payload['transactionId']?.toString().trim().isNotEmpty == true
        ? payload['transactionId']!.toString().trim()
        : null;

    debugPrint('INVOICE ROUTE COLLECTION=$collection');
    debugPrint('INVOICE ROUTE APPOINTMENT=$appointmentId');

    if (appointmentId == null || appointmentId.isEmpty) {
      debugPrint('MARKETPLACE NOTIFICATION ROUTE missing appointment id');
      setCurrentTab(NavTab.profile);
      openProfileSubPage(ProfileSubPage.appointments);
      return true;
    }

    closeNotifications();
    _ignoreNextNotificationTap = true;
    ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

    if (collection != null && collection.isNotEmpty) {
      setSelectedAppointmentId(appointmentId, collection: collection);
      setCurrentTab(NavTab.home);
    } else {
      setOpenAppointmentId(appointmentId);
      openBusinessDashboard();
    }

    debugPrint('INVOICE ROUTE SUCCESS');
    return true;
  }

  void _handleBusinessFinanceNotification(Map<String, dynamic> payload) {
    closeNotifications();
    _ignoreNextNotificationTap = true;
    ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

    final requestedBusinessId = payload['businessId']?.toString().trim();
    final ownedBusinessId = _businessId?.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null ||
        uid.isEmpty ||
        isGuestUser ||
        requestedBusinessId == null ||
        requestedBusinessId.isEmpty ||
        ownedBusinessId == null ||
        ownedBusinessId.isEmpty ||
        requestedBusinessId != ownedBusinessId) {
      setCurrentTab(NavTab.profile, preserveProfileSubPage: true);
      openProfileSubPage(ProfileSubPage.businessDashboard);
      return;
    }

    try {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => BusinessRevenueDetailPage(
            businessId: ownedBusinessId,
            recordLabel: 'orders',
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('BUSINESS FINANCE NOTIFICATION NAVIGATION FAILED: $error');
      debugPrint('$stackTrace');
      setCurrentTab(NavTab.profile, preserveProfileSubPage: true);
      openProfileSubPage(ProfileSubPage.businessDashboard);
    }
  }

  void _handleMarketplaceBusinessDelayedNotification(
    Map<String, dynamic> payload,
  ) {
    closeNotifications();
    _ignoreNextNotificationTap = true;
    ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final collection = payload['appointmentCollection']?.toString().trim();
    final appointmentId =
        payload['appointmentId']?.toString().trim().isNotEmpty == true
        ? payload['appointmentId']!.toString().trim()
        : payload['bookingId']?.toString().trim();

    void fallback() {
      setCurrentTab(NavTab.profile, preserveProfileSubPage: true);
      openProfileSubPage(ProfileSubPage.myAppointments);
    }

    if (uid == null ||
        uid.isEmpty ||
        isGuestUser ||
        collection == null ||
        !{
          'vet_appointments',
          'groomy_appointments',
          'hotel_bookings',
          'pet_taxi_bookings',
        }.contains(collection) ||
        appointmentId == null ||
        appointmentId.isEmpty) {
      fallback();
      return;
    }

    requestUserAppointmentDetail(
      collection: collection,
      appointmentId: appointmentId,
    );
  }

  Future<AppointmentNotificationNavigationDecision>
  handleNotificationTapGuarded(
    Map<String, dynamic> payload, {
    AppointmentAvailabilityResolver? resolveAvailability,
    void Function()? onMissingOrMalformed,
    void Function()? onLookupFailedOrUnresolved,
  }) async {
    final decision = await AppointmentNotificationNavigationGuard.evaluate(
      payload,
      resolveAvailability: resolveAvailability,
    );

    switch (decision) {
      case AppointmentNotificationNavigationDecision.notAppointment:
      case AppointmentNotificationNavigationDecision.available:
        handleNotificationTap(payload);
        break;
      case AppointmentNotificationNavigationDecision.missingOrMalformed:
        onMissingOrMalformed?.call();
        break;
      case AppointmentNotificationNavigationDecision.lookupFailedOrUnresolved:
        onLookupFailedOrUnresolved?.call();
        break;
    }

    return decision;
  }

  void handleNotificationTap(Map<String, dynamic> payload) {
    debugPrint("🧪 ENTERED NEW HANDLER VERSION");
    debugPrint('🔥🔥🔥 TAP HANDLER EXECUTED');
    debugPrint('🔔 handleNotificationTap payload=$payload');

    final rawType = payload['type']?.toString() ?? '';
    final type = normalizeNotificationType(rawType);
    debugPrint("🔥 TYPE LENGTH = ${type.length}");
    debugPrint("🧪 FULL PAYLOAD = $payload");
    debugPrint("🧪 TYPE RAW = [$rawType]");
    debugPrint("🧪 TYPE CLEAN = [$type]");
    final requestId = payload['requestId']?.toString();
    final likerUserId = payload['likerUserId']?.toString();
    final lostDogId =
        payload['lostDogId']?.toString() ?? payload['lostPetId']?.toString();
    final foundDogId =
        payload['foundDogId']?.toString() ?? payload['foundPetId']?.toString();

    if (_handleMarketplaceInvoiceNotification(type, payload)) {
      return;
    }

    if (isBusinessFinanceNotificationType(type)) {
      _handleBusinessFinanceNotification(payload);
      return;
    }

    if (isMarketplaceServiceNotificationType(type)) {
      _handleMarketplaceBusinessDelayedNotification(payload);
      return;
    }

    // ───────────────── PLAYDATE REQUEST ─────────────────
    if (type == 'playdate_request') {
      if (requestId == null || requestId.isEmpty) return;

      closeNotifications();
      _ignoreNextNotificationTap = true;
      ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

      setInitialPlaydateRequest(requestId);
      setCurrentTab(NavTab.playdate);
      return;
    }

    // ───────────────── PLAYDATE RESPONSE ─────────────────
    if (type == 'playdate_response') {
      if (requestId == null || requestId.isEmpty) return;

      closeNotifications();
      _ignoreNextNotificationTap = true;
      ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

      setInitialPlaydateRequest(requestId);
      setCurrentTab(NavTab.playdate);
      return;
    }

    // ───────────────── LOST PET ─────────────────
    if ((type == 'lost_dog' || type == 'lost_pet') &&
        lostDogId != null &&
        lostDogId.isNotEmpty) {
      closeNotifications();
      setCurrentTab(NavTab.lostDogs);
      openLostDogDetail(lostDogId);
      return;
    }

    // ───────────────── FOUND PET ─────────────────
    if ((type == 'found_dog' || type == 'found_pet') &&
        foundDogId != null &&
        foundDogId.isNotEmpty) {
      closeNotifications();
      setCurrentTab(NavTab.foundDogs);
      openFoundDogDetail(foundDogId);
      return;
    }

    // ───────────────── ADOPTION REQUEST ✅ ─────────────────
    if (type == 'adoption_request' &&
        requestId != null &&
        requestId.isNotEmpty) {
      debugPrint('🟢 Adoption REQUEST notification → $requestId');

      closeNotifications();

      setCurrentTab(NavTab.profile);
      openProfileSubPage(ProfileSubPage.adoptionInbox);
      setInitialAdoptionRequestId(requestId);

      return;
    }

    // ───────────────── VET APPOINTMENT 🔥 ─────────────────
    if (type == 'vet_appointment_request') {
      final appointmentId = payload['appointmentId']?.toString();

      debugPrint("🐾 VET APPOINTMENT TAP → $appointmentId");

      closeNotifications();

      setOpenAppointmentId(appointmentId);
      openBusinessDashboard();

      return;
    }

    if (type == 'groomy_appointment_request') {
      final appointmentId = payload['appointmentId']?.toString();

      debugPrint(
        "✂️ GROOMY APPOINTMENT TAP → $appointmentId openedFromNotification=true",
      );

      closeNotifications();

      setOpenAppointmentId(appointmentId);
      openBusinessDashboard();

      return;
    }

    if (type == 'hotel_booking_request') {
      final appointmentId =
          payload['appointmentId']?.toString() ??
          payload['bookingId']?.toString();

      debugPrint("🏨 HOTEL BOOKING TAP → $appointmentId");

      closeNotifications();

      setOpenAppointmentId(appointmentId);
      openBusinessDashboard();

      return;
    }

    if (type == 'pet_taxi_booking_request' ||
        type == 'pet_taxi_payment_completed') {
      final appointmentId =
          payload['appointmentId']?.toString() ??
          payload['bookingId']?.toString();

      debugPrint("🚕 PET TAXI BOOKING TAP → $appointmentId");

      closeNotifications();

      setOpenAppointmentId(appointmentId);
      openBusinessDashboard();

      return;
    }

    if (type == 'invoice_reminder' || type == 'payment_window_expired') {
      final sellerOrderId = payload['sellerOrderId']?.toString();
      final rootOrderId = payload['orderId']?.toString();

      debugPrint("🧾 INVOICE NOTIF sellerOrderId = $sellerOrderId");
      debugPrint("🧾 INVOICE NOTIF rootOrderId = $rootOrderId");

      if ((sellerOrderId == null || sellerOrderId.isEmpty) &&
          (rootOrderId == null || rootOrderId.isEmpty)) {
        debugPrint("❌ INVOICE NOTIF HAS NO ORDER ID");
        return;
      }

      closeNotifications();

      _ignoreNextNotificationTap = true;
      ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

      debugPrint(
        "🧾 OPEN ORDER FROM INVOICE → ${sellerOrderId ?? rootOrderId}",
      );
      openOrderSmart(sellerOrderId, rootOrderId);

      return;
    }

    if (type == 'groomy_appointment_cancelled_by_user' ||
        type == 'groomy_appointment_payment_expired') {
      final appointmentId = payload['appointmentId']?.toString();

      debugPrint("✂️ GROOMY DASHBOARD NOTIFICATION TAP → $appointmentId");

      closeNotifications();

      setOpenAppointmentId(appointmentId);
      openBusinessDashboard();

      return;
    }

    if (type == 'hotel_booking_cancelled_by_user' ||
        type == 'hotel_booking_payment_expired') {
      final appointmentId =
          payload['appointmentId']?.toString() ??
          payload['bookingId']?.toString();

      debugPrint("🏨 HOTEL DASHBOARD NOTIFICATION TAP → $appointmentId");

      closeNotifications();

      setOpenAppointmentId(appointmentId);
      openBusinessDashboard();

      return;
    }

    if (type == 'pet_taxi_booking_cancelled_by_user' ||
        type == 'pet_taxi_booking_payment_expired') {
      final appointmentId =
          payload['appointmentId']?.toString() ??
          payload['bookingId']?.toString();

      debugPrint("🚕 PET TAXI DASHBOARD TAP → $appointmentId");

      closeNotifications();

      setOpenAppointmentId(appointmentId);
      openBusinessDashboard();

      return;
    }

    // ───────────────── VET RESPONSE (USER SIDE) 🔥🔥🔥 ─────────────────
    if (type.contains('vet_appointment_response')) {
      final appointmentId = payload['appointmentId']?.toString();
      final status = payload['status']?.toString().toLowerCase();

      debugPrint("🐾 VET RESPONSE TAP → $appointmentId / $status");

      if (appointmentId == null || appointmentId.isEmpty) return;

      closeNotifications();

      _ignoreNextNotificationTap = true;
      ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

      // 🔥 فقط یک بار
      setSelectedAppointmentId(
        appointmentId,
        collection:
            payload['appointmentCollection']?.toString() ?? 'vet_appointments',
      );

      if (status == 'confirmed') {
        debugPrint("💳 GO TO PAYMENT FLOW");

        setCurrentTab(NavTab.home);
      } else {
        requestUserAppointmentDetail(
          collection:
              payload['appointmentCollection']?.toString() ??
              'vet_appointments',
          appointmentId: appointmentId,
        );
      }

      return;
    }

    if (type.contains('groomy_appointment_response')) {
      final appointmentId = payload['appointmentId']?.toString();
      final status = payload['status']?.toString().toLowerCase();

      debugPrint(
        "✂️ GROOMY RESPONSE TAP → $appointmentId / $status openedFromNotification=true",
      );

      if (appointmentId == null || appointmentId.isEmpty) return;

      closeNotifications();

      _ignoreNextNotificationTap = true;
      ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

      final shouldOpenPayment =
          status == 'awaiting_payment' ||
          status == 'confirmed' ||
          status == 'confirmed_paid';

      if (shouldOpenPayment) {
        setSelectedAppointmentId(
          appointmentId,
          collection:
              payload['appointmentCollection']?.toString() ??
              'groomy_appointments',
        );
        debugPrint("💳 GROOMY RESPONSE → open payment flow");
        setCurrentTab(NavTab.home);
      } else {
        requestUserAppointmentDetail(
          collection:
              payload['appointmentCollection']?.toString() ??
              'groomy_appointments',
          appointmentId: appointmentId,
        );
      }

      return;
    }

    if (type.contains('hotel_booking_response')) {
      final appointmentId =
          payload['appointmentId']?.toString() ??
          payload['bookingId']?.toString();
      final status = payload['status']?.toString().toLowerCase();

      debugPrint("🏨 HOTEL RESPONSE TAP → $appointmentId / $status");

      if (appointmentId == null || appointmentId.isEmpty) return;

      closeNotifications();

      _ignoreNextNotificationTap = true;
      ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

      if (hotelBookingResponseOpensPayment(status)) {
        setSelectedAppointmentId(appointmentId, collection: 'hotel_bookings');
        setCurrentTab(NavTab.home);
      } else {
        requestUserAppointmentDetail(
          collection:
              payload['appointmentCollection']?.toString() ?? 'hotel_bookings',
          appointmentId: appointmentId,
        );
      }

      return;
    }

    const petTaxiUserTypes = [
      'pet_taxi_price_proposed',
      'pet_taxi_payment_success',
      'pet_taxi_driver_on_the_way',
      'pet_taxi_driver_arrived',
      'pet_taxi_pet_picked_up',
      'pet_taxi_trip_started',
      'pet_taxi_trip_completed',
      'pet_taxi_booking_cancelled',
      'pet_taxi_status_update',
    ];

    if (petTaxiUserTypes.contains(type) ||
        type.contains('pet_taxi_status_update')) {
      final appointmentId =
          payload['appointmentId']?.toString() ??
          payload['bookingId']?.toString();

      final status = payload['status']?.toString().toLowerCase();

      debugPrint("🚕 PET TAXI RESPONSE TAP → $appointmentId / $status");

      if (appointmentId == null || appointmentId.isEmpty) return;

      closeNotifications();

      _ignoreNextNotificationTap = true;
      ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

      requestUserAppointmentDetail(
        collection:
            payload['appointmentCollection']?.toString() ?? 'pet_taxi_bookings',
        appointmentId: appointmentId,
      );

      return;
    }

    // ───────────────── VET CANCELLATION / REFUND ─────────────────
    if (type.contains('appointment_cancelled_confirmation') ||
        type.contains('vet_appointment_refunded')) {
      final appointmentId = payload['appointmentId']?.toString();
      debugPrint("🐾 VET REFUND TAP → $appointmentId / $type");

      if (appointmentId == null || appointmentId.isEmpty) return;

      closeNotifications();

      _ignoreNextNotificationTap = true;
      ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

      setSelectedAppointmentId(
        appointmentId,
        collection:
            payload['appointmentCollection']?.toString() ?? 'vet_appointments',
      );
      setCurrentTab(NavTab.home);
      return;
    }

    // ───────────────── PAYMENT DONE 🔥🔥🔥 ─────────────────
    if (type == 'appointment_paid' ||
        type == 'hotel_booking_payment_completed' ||
        type == 'pet_taxi_payment_completed') {
      final appointmentId =
          payload['appointmentId']?.toString() ??
          payload['bookingId']?.toString();

      debugPrint("💰 PAYMENT DONE TAP → $appointmentId");

      if (appointmentId == null || appointmentId.isEmpty) return;

      closeNotifications();

      _ignoreNextNotificationTap = true;
      ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

      // 👉 برو به داشبورد vet یا appointment
      setCurrentTab(NavTab.profile);
      openProfileSubPage(ProfileSubPage.businessDashboard);

      return;
    }

    // ───────────────── VACCINE FLOW 💉 ─────────────────

    if (type == 'vaccine_reminder' || type == 'vaccine_completed') {
      final patientId = payload['patientId']?.toString();
      final vaccineId = payload['vaccineId']?.toString();
      final businessId = payload['businessId']?.toString();
      final petId = payload['petId']?.toString();

      debugPrint(
        "💉 VACCINE TAP → business=$businessId patient=$patientId vaccine=$vaccineId type=$type",
      );

      if (patientId == null || patientId.isEmpty) {
        debugPrint("❌ vaccine notification missing patientId");
        return;
      }

      if (businessId == null || businessId.isEmpty) {
        debugPrint("❌ vaccine notification missing businessId");
        return;
      }

      if (vaccineId == null || vaccineId.isEmpty) {
        debugPrint("❌ vaccine notification missing vaccineId");
        return;
      }

      closeNotifications();

      _ignoreNextNotificationTap = true;

      ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

      setCurrentTab(NavTab.vet);

      openVaccineDetail(
        vaccineId: vaccineId,
        patientId: patientId,
        businessId: businessId,
        petId: petId,
      );

      return;
    }

    // ───────────────── ORDER FLOW 🔥 ─────────────────

    if (isMarketplaceOrderNotificationType(type)) {
      final sellerOrderId = payload['sellerOrderId']?.toString();
      final rootOrderId =
          payload['rootOrderId']?.toString() ?? payload['orderId']?.toString();
      final returnId = payload['returnId']?.toString();

      debugPrint("📦 NOTIF sellerOrderId = $sellerOrderId");
      debugPrint("📦 NOTIF rootOrderId = $rootOrderId");

      if ((sellerOrderId == null || sellerOrderId.isEmpty) &&
          (rootOrderId == null || rootOrderId.isEmpty)) {
        debugPrint("❌ NO ORDER ID AT ALL");
        if (isSellerReturnNotificationType(type)) {
          setCurrentTab(NavTab.petShop);
          openPetShopOrders();
        } else {
          setCurrentTab(NavTab.profile, preserveProfileSubPage: true);
          openProfileSubPage(ProfileSubPage.myOrders);
        }
        return;
      }

      closeNotifications();

      _ignoreNextNotificationTap = true;
      ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

      final idToOpen = (sellerOrderId != null && sellerOrderId.isNotEmpty)
          ? sellerOrderId
          : rootOrderId!;

      debugPrint("📦 OPEN ORDER → $idToOpen");

      if ((sellerOrderId == null || sellerOrderId.isEmpty) &&
          isSellerReturnNotificationType(type)) {
        setCurrentTab(NavTab.petShop);
        openPetShopOrders();
        return;
      }

      openOrderSmart(sellerOrderId, rootOrderId, returnId: returnId);

      return;
    }
    // ───────────────── BUSINESS RESOLUTION ✅ ─────────────────
    if (type == 'business_resolution') {
      final status = payload['status']?.toString().toLowerCase().trim();
      final centerId = payload['centerId']?.toString();
      final reason = payload['reason']?.toString();

      closeNotifications();
      _ignoreNextNotificationTap = true;
      ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

      if (status == 'approved') {
        if (centerId != null && centerId.isNotEmpty) {
          setInitialBusinessCenterId(centerId);
        }

        debugPrint('🚀 BUSINESS RESOLUTION APPROVED → NAV TO VET');
        closeProfileSubPage();
        setCurrentTab(NavTab.vet);
        return;
      }

      setCurrentTab(NavTab.profile);

      if (status == 'rejected') {
        openProfileSubPage(ProfileSubPage.businessStatus);
        setInitialBusinessResolution(
          status: 'rejected',
          centerId: centerId,
          reason: reason,
        );
        return;
      }

      openProfileSubPage(ProfileSubPage.businessStatus);
      return;
    }

    debugPrint('⚠️ Unknown notification type: $rawType');
  }

  void openVaccineDetail({
    required String vaccineId,
    required String patientId,
    required String businessId,
    String? petId,
  }) {
    activeVaccineId = vaccineId;
    activeVaccinePatientId = patientId;
    activeVaccineBusinessId = businessId;
    activeVaccinePetId = petId;

    notifyListeners();
  }

  void closeVaccineDetail() {
    activeVaccineId = null;
    activeVaccinePatientId = null;
    activeVaccineBusinessId = null;
    activeVaccinePetId = null;

    notifyListeners();
  }

  void applyPlaymateFilters(Map<String, dynamic> filters) {
    playmateFilters = filters;
    showPlaymateFilter = false;
    notifyListeners();
  }

  void clearPlaymateFilters() {
    playmateFilters = null;
    notifyListeners();
  }

  Map<String, dynamic>? playmateFilters;

  bool showPlaymateFilter = false;

  void openPlaymateFilter() {
    showPlaymateFilter = true;
    notifyListeners();
  }

  void closePlaymateFilter() {
    showPlaymateFilter = false;
    notifyListeners();
  }

  void openAppointmentPayment(String appointmentId) {
    debugPrint("💳 OPEN PAYMENT PAGE → $appointmentId");

    _selectedAppointmentId = appointmentId;
    _selectedAppointmentCollection = 'vet_appointments';

    // 👇 اینجا بعداً میشه route واقعی
    setCurrentTab(NavTab.home);

    notifyListeners();
  }

  void consumeSelectedAppointment() {
    _selectedAppointmentId = null;
    _selectedAppointmentCollection = null;
  }

  String? _openAppointmentId;

  String? get openAppointmentId => _openAppointmentId;

  void setOpenAppointmentId(String? id) {
    _openAppointmentId = id;
    notifyListeners();
  }

  void consumeOpenAppointment() {
    _openAppointmentId = null;
  }

  // ─────────────────────────────────────
  // BOTTOM NAV STATE  ✅ (جدید)
  // ─────────────────────────────────────
  NavTab _currentTab = NavTab.home;

  NavTab get currentTab => _currentTab;

  void setCurrentTab(NavTab tab, {bool preserveProfileSubPage = false}) {
    debugPrint('🧭 setCurrentTab CALLED → $tab');

    // 🔥 اگر دوباره روی PROFILE زد
    if (_currentTab == NavTab.profile && tab == NavTab.profile) {
      if (!preserveProfileSubPage) {
        closeProfileSubPage();
      }

      notifyListeners();

      return;
    }

    // 🟣 اگر داخل playdate هستیم و park فعاله → نادیده بگیر
    if (_currentTab == NavTab.playdate &&
        tab == NavTab.playdate &&
        _activePlaydatePark != null) {
      debugPrint('🛑 setCurrentTab ignored (active park flow)');
      return;
    }

    // 🟣 اگر داریم از PROFILE خارج میشیم
    if (_currentTab == NavTab.profile && tab != NavTab.profile) {
      closeProfileSubPage();
    }

    // 🟣 اگر داریم از playdate خارج میشیم
    if (_currentTab == NavTab.playdate && tab != NavTab.playdate) {
      _activePlaydatePark = null;
      _selectedRequesterDogId = null;
    }

    // 🟡 اگر داریم از تب lostDogs خارج میشیم
    if (_currentTab == NavTab.lostDogs && tab != NavTab.lostDogs) {
      activeLostDogId = null;
      activeFoundDogId = null;
    }

    // 💉 اگر داریم از vaccine notification خارج میشیم

    if (_currentTab == NavTab.vet &&
        tab != NavTab.vet &&
        activeVaccineId != null) {
      closeVaccineNotification();
    }

    if (_currentTab == NavTab.petShop && tab != NavTab.petShop) {
      closePetShopDetails();
    }

    // هر بار tab عوض میشه overlay بسته بشه
    _homeOverlay = HomeOverlay.none;
    _selectedPark = null;

    // اگر همون تب فعلیه فقط refresh کن
    if (_currentTab == tab) {
      notifyListeners();
      return;
    }

    _currentTab = tab;

    debugPrint('🧭 currentTab NOW → $_currentTab');

    notifyListeners();
  }

  // ─── تعداد نوتیفیکیشن‌های خوانده‌نشده (realtime) ───
  int _unreadNotificationsCount = 0;
  StreamSubscription<QuerySnapshot>? _unreadNotificationsSub;

  // ─────────────────────────────────────
  // PREMIUM STATE
  // ─────────────────────────────────────
  bool _isPremium = false;
  bool get isPremium => _isPremium;
  // ─────────────────────────────
  // SUBSCRIPTION STATE
  // ─────────────────────────────

  UserSubscription _subscription = UserSubscription.normal();

  UserSubscription get subscription => _subscription;

  /// Test-only seam for driving the real entitlement getters below.
  ///
  /// The production subscription is set exclusively by
  /// `loadSubscriptionFromFirestore` and `_applyCachedSubscription`, both of
  /// which require Firestore and Hive. Widget tests need a way to place a
  /// genuine [UserSubscription] into a real [AppState] so the shipping
  /// `isGold`/`canRegisterBusiness` getters — not a reimplementation — decide
  /// the Business quick action. This setter grants no entitlement of its own:
  /// the value still passes through the same [SubscriptionAccess] policy.
  @visibleForTesting
  void debugSetSubscription(UserSubscription value) {
    _subscription = value;
    _isPremium = value.hasValidPaidAccess;
    notifyListeners();
  }

  SubscriptionAccess get subscriptionAccess =>
      SubscriptionAccess(_subscription);

  // ─────────────────────────────
  // SUBSCRIPTION ACCESS HELPERS
  // ─────────────────────────────

  bool get isGold =>
      subscription.plan == SubscriptionPlan.gold &&
      subscription.hasValidPaidAccess;

  bool get canRegisterBusiness => subscriptionAccess.canRegisterBusiness;

  bool get canUseAdvancedFilters => subscriptionAccess.canUseAdvancedFilters;

  bool get canUsePremiumChat => subscriptionAccess.canUsePremiumChat;

  bool get canAccessBusinessDashboard =>
      subscriptionAccess.canAccessBusinessDashboard;

  set isPremium(bool value) {
    if (_isPremium == value) return;
    _isPremium = value;
    notifyListeners();
  }

  set currentUserId(String? value) {
    if (_currentUserId == value) return;

    _currentUserId = value;
    _savedParksLoaded = false;
    _syncDogsFromManager();
    notifyListeners();
  }

  Future<void> handleRemoteMessage(RemoteMessage message) async {
    if (isGuest) {
      debugPrint("🚫 Guest → skip remote message");
      return;
    }
    try {
      final data = message.data;

      debugPrint("🟨 HANDLE REMOTE MESSAGE: $data");

      if (data.isEmpty) return;

      if (data['requestId'] != null) {
        setPendingNotificationNavigation(data);
        openNotifications();
      }
    } catch (e) {
      debugPrint("❌ handleRemoteMessage error: $e");
    }
  }

  BusinessCardData? selectedGroomy;

  void openGroomyDetails(BusinessCardData groomy) {
    selectedGroomy = groomy;

    notifyListeners();
  }

  void closeGroomyDetails() {
    selectedGroomy = null;

    notifyListeners();
  }

  // ─── شروع Listener واقعی برای unread notifications ───
  void startUnreadNotificationsListener() {
    final uid = _currentUserId;

    if (!_noncriticalReadsAllowed) {
      debugPrint('🌐 RECOVERY LOOP SUPPRESSED → unread listener before gate');
      return;
    }
    final generation = _startupSessionGeneration;

    if (isGuest || uid == null || uid.isEmpty) {
      debugPrint("🚫 Notifications listener skipped (guest)");
      return;
    }

    _unreadNotificationsSub?.cancel();

    _unreadNotificationsSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientUserId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
            if (!isUserSessionCurrent(uid, generation)) return;
            final newCount = snapshot.docs.length;

            // 🛑 اگر عدد تغییر نکرده → هیچ کاری نکن
            if (_unreadNotificationsCount == newCount) return;

            _unreadNotificationsCount = newCount;

            debugPrint(
              '🔔 Realtime unread count updated → $_unreadNotificationsCount',
            );

            notifyListeners();
          },

          onError: (error) {
            if (!isUserSessionCurrent(uid, generation)) return;
            debugPrint('❌ Unread notifications listener error: $error');
            _unreadNotificationsCount = 0;
            notifyListeners();
          },
        );
  }

  Future<void> markAllNotificationsAsRead() async {
    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUserId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ markAllNotificationsAsRead error: $e');
    }
  }

  void setSavedParks(List<String> parkNames) {
    _favoriteParks
      ..clear()
      ..addAll(parkNames.map((name) => {'name': name}));
    _savedParksLoaded = true;
    notifyListeners();
  }

  // ─────────────────────────────
  // PLAYDATE FLOW (ONLY SOURCE)
  // ─────────────────────────────
  Map<String, dynamic>? _activePlaydatePark;
  String? _selectedRequesterDogId;

  Map<String, dynamic>? get activePlaydatePark => _activePlaydatePark;
  String? get selectedRequesterDogId => _selectedRequesterDogId;

  void setActivePlaydatePark(Map<String, dynamic> park) {
    debugPrint('🔥 ActivePlaydatePark SET → ${park['name']}');
    _activePlaydatePark = park;
    notifyListeners();
  }

  Future<void> reloadMyDogs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _currentUserId = uid;
    _syncDogsFromManager();
  }

  void setSelectedRequesterDogId(String? dogId) {
    _selectedRequesterDogId = dogId;
    notifyListeners();
  }

  void openPlaydateScheduling({
    Map<String, dynamic>? activePlaydatePark,
    String? selectedRequesterDogId,
  }) {
    debugPrint(
      '🧹 CLOSE PROFILE BEFORE SCHEDULE → '
      'userId=$playmateProfileUserId',
    );

    // بستن هر دو Overlay:
    // barky_scaffold.dart و playmate_page.dart
    playmateProfileUserId = null;
    playmateDogsSnapshot = null;

    // اولین close بعدی نباید اشتباهی ignore شود
    _ignoreNextClose = false;

    _activePlaydatePark = activePlaydatePark;
    _selectedRequesterDogId = selectedRequesterDogId;
    _currentTab = NavTab.playdateScheduling;

    debugPrint(
      '🧭 currentTab NOW → $_currentTab | '
      'profileUserId=$playmateProfileUserId',
    );

    notifyListeners();
  }

  void clearPlaydateFlow() {
    _activePlaydatePark = null;
    _selectedRequesterDogId = null;
    notifyListeners();
  }

  void setMyDogs(List<Dog> dogs) {
    _myDogs = List<Dog>.from(dogs);
    notifyListeners();
  }

  void _handleDogsSnapshotChanged() {
    _syncDogsFromManager();
  }

  void _syncDogsFromManager({bool notify = true}) {
    _dogsSnapshot = DogsBoxManager.instance.snapshot;

    if (_dogsSnapshot.isLoading) {
      _isDogsLoading = true;
      _dogsError = null;
      _myDogs.clear();
      _allDogs.clear();
      _discoveryDogs.clear();
      _invalidateAllDogsView();
      if (notify) notifyListeners();
      return;
    }

    if (_dogsSnapshot.phase == DogsSnapshotPhase.error) {
      _isDogsLoading = false;
      _dogsError = _dogsSnapshot.error;
      _myDogs.clear();
      _allDogs.clear();
      _discoveryDogs.clear();
      _invalidateAllDogsView();
      if (notify) notifyListeners();
      return;
    }

    _isDogsLoading = false;
    _dogsError = null;

    final uid = _currentUserId;
    if (uid == null || uid.isEmpty || isGuest) {
      _myDogs.clear();
      _allDogs.clear();
      _discoveryDogs.clear();
      _invalidateAllDogsView();
      if (notify) notifyListeners();
      return;
    }

    _allDogs = List<Dog>.from(_dogsSnapshot.dogs);
    _myDogs = _allDogs
        .where((dog) => (dog.ownerId ?? '').trim() == uid)
        .toList();
    _discoveryDogs = _allDogs
        .where(
          (dog) =>
              (dog.ownerId ?? '').trim() != uid &&
              !dog.isHidden &&
              dog.dogProfileVisible &&
              dog.ownerProfileVisible,
        )
        .toList();
    _invalidateAllDogsView();

    if (notify) notifyListeners();
  }

  void setPendingNotificationNavigation(Map<String, dynamic> data) {
    _pendingNotificationNavigation = data;

    debugPrint('📌 Pending notification stored → $data');

    if (_isUserInitialized) {
      _handlePendingNavigation();
    }
  }

  void _handlePendingNavigation() {
    final data = _pendingNotificationNavigation;
    if (data == null) return;

    final type = (data['type'] ?? '').toString();
    final requestId = data['requestId']?.toString();

    if ((type == 'playdate_request' || type == 'playdate_response') &&
        requestId != null) {
      openNotifications();
    }

    _pendingNotificationNavigation = null;
  }

  // 🔧 legacy bridge (برای build سبز)
  Map<String, dynamic>? get pendingPlaydatePark => _activePlaydatePark;

  // ─────────────────────────────────────
  // FAVORITE PARKS
  // ─────────────────────────────────────
  final List<Map<String, dynamic>> _favoriteParks = [];
  List<Map<String, dynamic>> get favoriteParks =>
      List.unmodifiable(_favoriteParks);

  bool isParkFavorite(String parkName) {
    return _favoriteParks.any((p) => p['name'] == parkName);
  }

  Set<String> get favoriteParkNames => _favoriteParks
      .map((p) => (p['name'] ?? '').toString())
      .where((n) => n.isNotEmpty)
      .toSet();

  Future<void> toggleFavoritePark(Map<String, dynamic> park) async {
    final uid = _currentUserId;

    if (isGuest || uid == null) {
      debugPrint('🚫 Guest cannot save parks');
      return;
    }

    if (!_savedParksLoaded) {
      await loadSavedParksFromFirebase();
    }

    final parkName = park['name'];
    final parkLat = park['lat'];
    final parkLng = park['lng'];

    final exists = _favoriteParks.any((p) => p['name'] == parkName);

    if (exists) {
      _favoriteParks.removeWhere((p) => p['name'] == parkName);
    } else {
      _favoriteParks.add({'name': parkName, 'lat': parkLat, 'lng': parkLng});
    }

    notifyListeners();

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'savedParks': _favoriteParks,
    }, SetOptions(merge: true));
  }

  Map<String, dynamic>? getParkByName(String name) {
    try {
      return _favoriteParks.firstWhere((p) => p['name'] == name);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadSavedParksFromFirebase() async {
    if (!_noncriticalReadsAllowed) {
      debugPrint('🌐 RECOVERY LOOP SUPPRESSED → saved parks load before gate');
      return;
    }

    final uid = _currentUserId;
    if (uid == null || uid.isEmpty) {
      _savedParksLoaded = true;
      return;
    }
    final generation = _startupSessionGeneration;

    final usedCache =
        FirestoreRecovery.passiveMode && _applyCachedSavedParks(uid);
    if (usedCache) notifyListeners();

    if (_suppressPassiveStartupRead('loadSavedParks')) {
      if (!usedCache) {
        debugPrint('🌐 OFFLINE STARTUP SURVIVAL MODE → saved parks empty');
        _favoriteParks.clear();
        _savedParksLoaded = true;
        notifyListeners();
      }
      return;
    }

    try {
      debugPrint(
        '🏞 Loading saved parks from Firestore... '
        '(appUid=$uid authUid=${FirebaseAuth.instance.currentUser?.uid})',
      );
      debugPrint('🌐 SERVER-FORCED READ SKIPPED → loadSavedParks');

      final doc = await _firestoreRetry(
        () => FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get()
            .timeout(_firestoreReadTimeout),
        operationName: 'loadSavedParks',
      );

      if (!isUserSessionCurrent(uid, generation)) return;

      final data = doc.data();
      final List<dynamic>? parks = data?['savedParks'];

      _favoriteParks.clear();
      if (parks != null) {
        _favoriteParks.addAll(
          parks.map((p) {
            if (p is Map<String, dynamic>) return p;
            return {'name': p.toString()};
          }),
        );
      }

      debugPrint('🏞 Loaded ${_favoriteParks.length} saved parks');
    } catch (e) {
      if (!isUserSessionCurrent(uid, generation)) return;
      debugPrint('❌ loadSavedParksFromFirebase failed: $e');
      if (!usedCache) {
        debugPrint('🌐 OFFLINE STARTUP SURVIVAL MODE → saved parks empty');
        _favoriteParks.clear();
      }
    } finally {
      if (isUserSessionCurrent(uid, generation)) {
        _savedParksLoaded = true;
        notifyListeners();
      }
    }
  }

  // ─── بقیه getterها و setterها ───
  Map<String, List<Map<String, dynamic>>> get dogLikes => _dogLikes;

  AppState({
    required List<Dog> favoriteDogs,
    required this.favoriteDogsNotifier,
    required this.likesNotifier,
    required this.onToggleFavorite,
    required this.notificationService,
    String? currentUserId,

    // ⬇️⬇️⬇️ ADD (legacy)
    String? currentUserName,

    String? selectedRequesterDogId,
    bool isPremium = false,

    /// Startup language resolved by [loadInitialLanguageCode] before
    /// `runApp`. Unsupported/absent values keep the English default.
    String? initialLanguageCode,
  }) : _favoriteDogs = favoriteDogs,
       _dogLikes = {},
       _currentUserId = currentUserId,

       // ⬇️⬇️⬇️ ASSIGN
       _currentUserName = currentUserName,

       _selectedRequesterDogId = selectedRequesterDogId,
       _isPremium = isPremium {
    final resolvedLanguage = normalizeLanguageCode(initialLanguageCode);
    if (resolvedLanguage != null) {
      // Initialization, not a user choice — deliberately does not persist.
      _locale = Locale(resolvedLanguage);
    }

    DogsBoxManager.instance.addListener(_handleDogsSnapshotChanged);
    _syncDogsFromManager(notify: false);
  }

  static AppState of(BuildContext context) {
    return Provider.of<AppState>(context, listen: false);
  }

  List<Dog> get favoriteDogs => _favoriteDogs;

  void updateFavorites(List<Dog> newFavorites) {
    _favoriteDogs = newFavorites;
    favoriteDogsNotifier.value = List<Dog>.from(newFavorites);
    notifyListeners();
  }

  void updateUserId(String? newId) {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null) {
      synchronizeAuthenticatedUid(authUid);
      return;
    }

    currentUserId = newId;
  }

  // ─── dispose تمیز کردن subscription ───
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _startupSessionGeneration++;
    DogsBoxManager.instance.removeListener(_handleDogsSnapshotChanged);

    _unreadNotificationsSub?.cancel();
    _unreadNotificationsSub = null;

    _lostSub?.cancel();
    _lostSub = null;

    _foundSub?.cancel();
    _foundSub = null;

    _authSub?.cancel();
    _authSub = null;

    _userDocSub?.cancel();
    _userDocSub = null;

    _startupReadinessRetryTimer?.cancel();
    _startupReadinessRetryTimer = null;

    _authRestorationTimeoutTimer?.cancel();
    _authRestorationTimeoutTimer = null;

    super.dispose();
  }

  // ─── بقیه متدها بدون تغییر (toggleFavorite, addLike, removeLike و ...) ───
  // فقط loadUnreadNotificationsCount رو حذف کردیم چون دیگه نیاز نیست

  Future<void> toggleFavorite(Dog dog) async {
    final key = dog.id;
    final favoritesBox = Hive.box<Dog>('favoritesBox');
    bool isFavorite = favoritesBox.values.any((favDog) => favDog.id == dog.id);

    if (isFavorite) {
      await removeFavorite(dog);
    } else {
      await addFavorite(dog);
    }
    notifyListeners();
  }

  Future<void> addFavorite(Dog dog) async {
    if (isGuest) {
      debugPrint("🚫 Guest cannot add favorites");
      return;
    }

    try {
      final key = dog.id;
      final favoritesBox = Hive.box<Dog>('favoritesBox');
      if (!favoritesBox.values.any((favDog) => favDog.id == dog.id)) {
        final newFavorites = List<Dog>.from(_favoriteDogs)..add(dog.copy());
        _favoriteDogs.clear();
        _favoriteDogs.addAll(newFavorites);
        await favoritesBox.put(key, dog.copy());
        favoriteDogsNotifier.value = List<Dog>.from(newFavorites);
      }
    } catch (e) {
      debugPrint('Error adding favorite: $e');
    }
  }

  Future<void> removeFavorite(Dog dog) async {
    try {
      final key = dog.id;
      final favoritesBox = Hive.box<Dog>('favoritesBox');
      final indexToRemove = favoritesBox.values.toList().indexWhere(
        (favDog) => favDog.id == dog.id,
      );
      if (indexToRemove != -1) {
        await favoritesBox.deleteAt(indexToRemove);
        _favoriteDogs.removeWhere((favDog) => favDog.id == dog.id);
        favoriteDogsNotifier.value = List<Dog>.from(_favoriteDogs);
      }
    } catch (e) {
      debugPrint('Error removing favorite: $e');
    }
  }

  Future<void> loadUnreadNotificationsCount() async {
    final uid = _currentUserId;
    if (uid == null) return;
    final generation = _startupSessionGeneration;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUserId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      if (!isUserSessionCurrent(uid, generation)) return;

      _unreadNotificationsCount = snapshot.docs.length;
      notifyListeners();

      debugPrint(
        '🔔 AppState unreadNotificationsCount = $_unreadNotificationsCount',
      );
    } catch (e) {
      if (!isUserSessionCurrent(uid, generation)) return;
      debugPrint('❌ Error loading unread notifications: $e');
      _unreadNotificationsCount = 0;
      notifyListeners();
    }
  }

  Future<void> addLike(String userId, Dog dog, BuildContext context) async {
    try {
      final dogKey = dog.id;
      final currentLikes = likesNotifier.value;
      final userLikes = currentLikes[userId] ?? [];

      if (userLikes.contains(dogKey)) return;

      final likeSnapshot = await FirebaseFirestore.instance
          .collection('likes')
          .where('likerUserId', isEqualTo: userId)
          .where('dogId', isEqualTo: dogKey)
          .get();
      if (likeSnapshot.docs.isNotEmpty) return;

      bool notificationSent = false;

      await FirebaseFirestore.instance.collection('likes').add({
        'likerUserId': userId,
        'dogId': dogKey,
        'timestamp': FieldValue.serverTimestamp(),
        'username': _username ?? 'User', // اضافه کردن نام کاربری
      });
      debugPrint('AppState - User $userId liked $dogKey in Firestore');

      final updatedLikes = Map<String, List<String>>.from(currentLikes);
      updatedLikes[userId] = [...userLikes, dogKey];
      likesNotifier.value = updatedLikes;
      debugPrint('AppState - Updated likesNotifier for user $userId');

      // به‌روزرسانی dogLikes
      final updatedDogLikes = Map<String, List<Map<String, dynamic>>>.from(
        _dogLikes,
      );
      updatedDogLikes[dogKey] = [
        ...(updatedDogLikes[dogKey] ?? []),
        {'userId': userId, 'username': _username ?? 'User'},
      ];
      _dogLikes = updatedDogLikes;
      notifyListeners();
      debugPrint('AppState - Updated dogLikes for dog $dogKey');

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = jsonEncode({
        'type': 'like',
        'likerUserId': userId,
        'dogKey': dogKey,
      });
      final localizations = AppLocalizations.of(context)!;
      final title = localizations.newLikeTitle;
      final body = localizations.newLikeBody(_username ?? 'User', dog.name);

      // await _storeNotification(dog.ownerId!, title, body, '');
      debugPrint('AppState - Stored notification for owner: ${dog.ownerId}');

      await _checkForMutualLike(userId, dog, context);
    } catch (e) {
      debugPrint('AppState - Error adding like: $e');
    }
  }

  Future<void> removeLike(String userId, Dog dog) async {
    try {
      final dogKey = dog.id;

      final likeSnapshot = await FirebaseFirestore.instance
          .collection('likes')
          .where('likerUserId', isEqualTo: userId)
          .where('dogId', isEqualTo: dogKey)
          .get();

      for (var doc in likeSnapshot.docs) {
        await doc.reference.delete();
        debugPrint(
          'AppState - Removed like for $dogKey by user $userId from Firestore',
        );
      }

      final currentLikes = Map<String, List<String>>.from(likesNotifier.value);
      final userLikes = List<String>.from(currentLikes[userId] ?? []);
      currentLikes[userId] = userLikes.where((key) => key != dogKey).toList();
      if (currentLikes[userId]!.isEmpty) {
        currentLikes.remove(userId);
      }
      likesNotifier.value = Map<String, List<String>>.from(currentLikes);
      debugPrint(
        'AppState - Updated likesNotifier after removing like for user $userId',
      );

      // به‌روزرسانی dogLikes
      final updatedDogLikes = Map<String, List<Map<String, dynamic>>>.from(
        _dogLikes,
      );
      updatedDogLikes[dogKey] = (updatedDogLikes[dogKey] ?? [])
          .where((liker) => liker['userId'] != userId)
          .toList();
      if (updatedDogLikes[dogKey]!.isEmpty) {
        updatedDogLikes.remove(dogKey);
      }
      _dogLikes = updatedDogLikes;
      notifyListeners();
      debugPrint(
        'AppState - Updated dogLikes after removing like for dog $dogKey',
      );
    } catch (e) {
      debugPrint('AppState - Error removing like: $e');
    }
  }

  Future<void> toggleLike(String userId, Dog dog, BuildContext context) async {
    final currentLikes = likesNotifier.value;
    final dogKey = dog.id;
    final userLikes = currentLikes[userId] ?? [];
    bool isLiked = userLikes.contains(dogKey);
    if (isLiked) {
      await removeLike(userId, dog);
    } else {
      await addLike(userId, dog, context);
    }
  }

  Future<void> _checkForMutualLike(
    String likerUserId,
    Dog likedDog,
    BuildContext context,
  ) async {
    final likedDogKey = likedDog.id;
    final likedDogOwnerId = likedDog.ownerId;

    if (likedDogOwnerId == null) return;

    final ownerLikesSnapshot = await FirebaseFirestore.instance
        .collection('likes')
        .where('likerUserId', isEqualTo: likedDogOwnerId)
        .get();

    final ownerLikes = ownerLikesSnapshot.docs
        .map((doc) => doc['dogId'] as String)
        .toList();

    final likerDog = _myDogs.firstWhere(
      (dog) => dog.ownerId == likerUserId,
      orElse: () => Dog(
        id: 'unknown_$likerUserId',
        name: 'Unknown',
        breed: '',
        age: 0,
        gender: '',
        healthStatus: '',
        isNeutered: false,
        description: '',
        traits: [],
        ownerGender: '',
        imagePaths: [],
        isAvailableForAdoption: false,
        isOwner: false,
        ownerId: likerUserId,
        latitude: 0.0,
        longitude: 0.0,
      ),
    );

    if (likerDog.ownerId == null) return;

    final likerDogKey = likerDog.id;

    if (ownerLikes.contains(likerDogKey) && likerUserId != likedDogOwnerId) {
      final requestId =
          '${likerUserId}_${likedDogOwnerId}_${DateTime.now().millisecondsSinceEpoch}';
      final existingRequests = await FirebaseFirestore.instance
          .collection('playDateRequests')
          .where('requesterUserId', isEqualTo: likerUserId)
          .where('requestedUserId', isEqualTo: likedDogOwnerId)
          .get();

      if (existingRequests.docs.isEmpty) {
        await FirebaseFirestore.instance
            .collection('playDateRequests')
            .doc(requestId)
            .set({
              'requesterUserId': likerUserId,
              'requestedUserId': likedDogOwnerId,
              'requesterDog': {
                'name': likerDog.name,
                'id': likerDog.id,
                'ownerId': likerDog.ownerId,
              },
              'requestedDog': {
                'name': likedDog.name,
                'id': likedDog.id,
                'ownerId': likedDog.ownerId,
              },
              'status': 'pending',
              'requestDate': FieldValue.serverTimestamp(),
              'scheduledDateTime': null,
            });

        debugPrint(
          'AppState - Created PlayDate request $requestId '
          'between ${likerDog.name} and ${likedDog.name}',
        );
      }

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = jsonEncode({
        'type': 'playDateRequest',
        'requestId': requestId,
        'likerUserId': likerUserId,
      });
      final localizations = AppLocalizations.of(context)!;

      final title = localizations.newPlaydateRequestTitle;

      final body = localizations.newPlaydateRequestBody(
        likerDog.name,
        likedDog.name,
      );
      // await _storeNotification(likedDogOwnerId, title, body, requestId);
      debugPrint(
        'AppState - Stored playdate notification for owner: $likedDogOwnerId',
      );
    } else {
      debugPrint(
        'AppState - PlayDate request already exists between $likerUserId and $likedDogOwnerId',
      );
    }
  }

  Future<void> deletePlayDateRequest(
    String requestId,
    BuildContext context,
  ) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      debugPrint('AppState - Current auth uid: $currentUserId');
      final docRef = FirebaseFirestore.instance
          .collection('playDateRequests')
          .doc(requestId);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        debugPrint('AppState - Request $requestId not found in Firestore');
        return;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      final requesterUserId = data['requesterUserId'] as String;
      final requestedUserId = data['requestedUserId'] as String;
      final status = data['status'] as String;

      debugPrint('AppState - Deleting request $requestId with status: $status');
      debugPrint('AppState - Request data: $data');
      debugPrint(
        'AppState - Comparing uids: current=$currentUserId, requester=$requesterUserId, requested=$requestedUserId',
      );

      if (currentUserId != requesterUserId &&
          currentUserId != requestedUserId) {
        debugPrint(
          'AppState - User $currentUserId does not have permission to delete request $requestId',
        );
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'User does not have permission to delete this request',
        );
      }

      await docRef.delete();
      debugPrint(
        'AppState - Deleted PlayDate request from Firestore: $requestId',
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = jsonEncode({
        'type': 'playDateRequest',
        'requestId': requestId,
        'requesterUserId': requesterUserId,
      });
      final localizations = AppLocalizations.of(context)!;
      final title = localizations.playDateCanceledTitle;
      final body = localizations.playDateCanceledBody(
        data['requestedDog']['name'] as String,
      );

      //await _storeNotification(requesterUserId, title, body, requestId);
      //await _storeNotification(requestedUserId, title, body, requestId);
      debugPrint(
        'AppState - Stored cancellation notification for users: $requesterUserId, $requestedUserId',
      );
    } catch (e) {
      debugPrint('AppState - Error deleting PlayDate request: $e');
      rethrow;
    }
  }

  Future<void> sendPlayDateStatusNotification({
    required String requesterUserId,
    required String requestedUserId,
    required String requestId,
    DateTime? scheduledDateTime,
    required String status,
    required BuildContext context,
  }) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      debugPrint('AppState - Current auth uid: $currentUserId');
      debugPrint(
        'AppState - Sending notification for request: $requestId, status: $status, requester: $requesterUserId, requested: $requestedUserId',
      );
      debugPrint(
        'AppState - Comparing uids: current=$currentUserId, requester=$requesterUserId, requested=$requestedUserId',
      );
      if (currentUserId.isEmpty) {
        debugPrint('AppState - No user logged in, cannot send notification');
        return;
      }

      final requesterDog = _myDogs.firstWhere(
        (dog) => dog.ownerId == requesterUserId,
        orElse: () => Dog(
          id: 'unknown_$requesterUserId',
          name: 'Unknown',
          breed: '',
          age: 0,
          gender: '',
          healthStatus: '',
          isNeutered: false,
          description: '',
          traits: [],
          ownerGender: '',
          imagePaths: [],
          isAvailableForAdoption: false,
          isOwner: false,
          ownerId: requesterUserId,
          latitude: 0.0,
          longitude: 0.0,
        ),
      );

      final requestedDog = _allDogs.firstWhere(
        (dog) => dog.ownerId == requestedUserId,
        orElse: () => Dog(
          id: 'unknown_$requestedUserId',
          name: 'Unknown',
          breed: '',
          age: 0,
          gender: '',
          healthStatus: '',
          isNeutered: false,
          description: '',
          traits: [],
          ownerGender: '',
          imagePaths: [],
          isAvailableForAdoption: false,
          isOwner: false,
          ownerId: requestedUserId,
          latitude: 0.0,
          longitude: 0.0,
        ),
      );

      String recipientUserId = currentUserId == requesterUserId
          ? requestedUserId
          : requesterUserId;
      final localizations = AppLocalizations.of(context)!;
      String title;
      String body;

      if (status.toLowerCase() == 'accepted') {
        title = localizations.playDateAcceptedTitle;
        body = currentUserId == requesterUserId
            ? localizations.playDateAcceptedBodyRequester(requestedDog.name)
            : localizations.playDateAcceptedBodyRequested(
                requestedDog.name,
                scheduledDateTime != null
                    ? ' on ${scheduledDateTime.toLocal().toString().split(' ')[0]} at ${scheduledDateTime.toLocal().hour}:${scheduledDateTime.toLocal().minute}'
                    : '',
              );
      } else {
        title = localizations.playDateRejectedTitle;
        body = currentUserId == requesterUserId
            ? localizations.playDateRejectedBodyRequester(requestedDog.name)
            : localizations.playDateRejectedBodyRequested(requestedDog.name);
      }

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = jsonEncode({
        'type': 'playDateRequest',
        'requestId': requestId,
        'requesterUserId': requesterUserId,
        'requestedUserId': requestedUserId,
      });

      // await _storeNotification(recipientUserId, title, body, requestId);
      debugPrint(
        'AppState - Sent playdate $status notification to: $recipientUserId',
      );
    } catch (e) {
      debugPrint('AppState - Error sending playdate status notification: $e');
      rethrow;
    }
  }

  Future<void> cleanOldPlayDateRequests() async {
    try {
      final currentTime = DateTime.now();
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('playDateRequests')
          .where('status', whereIn: ['accepted', 'rejected'])
          .get();

      for (var doc in requestsSnapshot.docs) {
        final data = doc.data();
        final requestDate = (data['requestDate'] as Timestamp?)?.toDate();
        if (requestDate != null &&
            requestDate.isBefore(currentTime.subtract(Duration(days: 1)))) {
          await FirebaseFirestore.instance
              .collection('playDateRequests')
              .doc(doc.id)
              .delete();
          debugPrint(
            'AppState - Deleted old PlayDate request from Firestore: ${doc.id}',
          );
        }
      }
    } catch (e) {
      debugPrint('AppState - Error cleaning old PlayDate requests: $e');
    }
  }
}
