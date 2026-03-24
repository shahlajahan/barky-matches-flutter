
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'dog.dart';
import 'notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:barky_matches_fixed/ui/vet/vet_card_data.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'theme/app_theme.dart';
import 'main.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:barky_matches_fixed/subscription/models/user_subscription.dart';
import 'package:barky_matches_fixed/subscription/helpers/subscription_access.dart';
import 'package:barky_matches_fixed/subscription/models/subscription_plan.dart';
import 'package:barky_matches_fixed/utils/location_utils.dart';

enum BusinessSubPage {
  none,
  appointment,
}

enum HomeOverlay {
  none,
  parkPlaydateEntry,
  notifications,
}


enum ProfileSubPage {
  none,
  savedParks,
  adoptionInbox,
  businessRegister,
  businessDashboard,   // ✅ اضافه
  businessStatus,      // ✅ اضافه
}

class AppState with ChangeNotifier {

  // ─────────────────────────────
// 🌍 LANGUAGE / LOCALE
// ─────────────────────────────

Locale _locale = const Locale('en');

Locale get locale => _locale;
void setGuestUser() {
  currentUserId = 'guest';
  notifyListeners();

  debugPrint("👤 Guest mode activated");
}
void setLocale(String languageCode) {
  _locale = Locale(languageCode);
  notifyListeners();
}
bool get isGuest => currentUserId == 'guest';
  // ─────────────────────────────────────
  // HOME OVERLAY (ParkPlaydate Entry)
  // ─────────────────────────────────────
  HomeOverlay _homeOverlay = HomeOverlay.none;
  Map<String, dynamic>? _selectedPark;

  HomeOverlay get homeOverlay => _homeOverlay;
  Map<String, dynamic>? get selectedPark => _selectedPark;

  // ─────────────────────────────────────
// 🔁 LEGACY PARK API (DO NOT REMOVE)
// ─────────────────────────────────────
Map<String, dynamic>? get park => _selectedPark;

void selectSavedPark(Map<String, dynamic> park) {
  _selectedPark = park;
  notifyListeners();
}

void clearSelectedParkLegacy() {
  _selectedPark = null;
  notifyListeners();
}

String? _handledResultRequestId;

bool hasHandledResult(String requestId) {
  return _handledResultRequestId == requestId;
}

void markResultHandled(String requestId) {
  _handledResultRequestId = requestId;
}

void openBusinessRegister() {
  if (!canRegisterBusiness) {
    debugPrint('🚫 Business register blocked (not gold)');
    return;
  }

  if (!canAccessBusinessDashboard) {
  return;
}

NavTab? pendingTab;

void setPendingTab(NavTab tab) {
  pendingTab = tab;
}

  _profileSubPage = ProfileSubPage.businessRegister;
  notifyListeners();
}
bool _ignoreNextClose = false;
String? activeLostDogId;
StreamSubscription<DocumentSnapshot>? _userDocSub;

// ─────────────────────────────
// BUSINESS STATE (ENTERPRISE)
// ─────────────────────────────

String? _businessStatus; // none / pending / approved / rejected
String? _businessId;
bool _isBusinessVerified = false;
// 🔔 BUSINESS RESOLUTION (one-shot from notification)
String? _initialBusinessCenterId;
String? _initialBusinessResolutionStatus;
String? _initialBusinessResolutionReason;

String? get initialBusinessCenterId => _initialBusinessCenterId;
String? get initialBusinessResolutionStatus => _initialBusinessResolutionStatus;
String? get initialBusinessResolutionReason => _initialBusinessResolutionReason;


void setApprovedBusiness({required String businessId}) {
  _businessId = businessId;
  _businessStatus = "approved";
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

bool get hasApprovedBusiness => _businessStatus == 'approved';
bool get hasPendingBusiness => _businessStatus == 'pending';

BusinessSubPage _businessSubPage = BusinessSubPage.none;
BusinessCardData? _activeBusiness;
BusinessCardData? _businessAppointment;
BusinessSubPage get businessSubPage => _businessSubPage;
BusinessCardData? get activeBusiness => _activeBusiness;
BusinessCardData? get businessAppointment => _businessAppointment;

void setBusinessStatus(String status) {
  _businessStatus = status;
  notifyListeners();
}

  bool _vetLoaded = false;
bool get vetLoaded => _vetLoaded;



void openBusinessDetails(BusinessCardData business) {
  debugPrint('🟣 openBusinessDetails name=${business.name}');
  _activeBusiness = business;
  notifyListeners();
}

void closeBusinessDetails() {
  _activeBusiness = null;
  notifyListeners();
}

void openBusinessAppointment(BusinessCardData business) {
  _businessAppointment = business;
  _businessSubPage = BusinessSubPage.appointment;
  notifyListeners();
}



void closeBusinessAppointment() {
  _businessAppointment = null;
  _businessSubPage = BusinessSubPage.none;
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
bool get shouldConsumeInitialPlaydateRequest => _shouldConsumeInitialPlaydateRequest;
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
  
  bool _savedParksLoaded = false;

  bool _isUserProfileReady = false;
bool get isUserProfileReady => _isUserProfileReady;

  ProfileSubPage _profileSubPage = ProfileSubPage.none;

ProfileSubPage get profileSubPage => _profileSubPage;

bool _isHandlingPlaydateResult = false;

String? _userRole;
String? get userRole => _userRole;

bool get isAdmin => _userRole == 'admin';
int get unreadNotificationsCount => _unreadNotificationsCount;

//bool _isPlaydateParkStepOpen = false;
static String? _lastHandledPlaydateRequestId;

Map<String, dynamic>? get selectedParkForPlaydate =>
    _selectedParkForPlaydate;
Map<String, dynamic>? _selectedSavedPark;
Map<String, dynamic>? get selectedSavedPark => _selectedSavedPark;
//Map<String, dynamic>? _pendingPlaydatePark;
Map<String, dynamic>? _selectedParkForPlaydate;

Map<String, dynamic>? _pendingPlaydatePark; // موقت

// ─────────────────────────────
// DOGS STATE (SINGLE SOURCE)
// ─────────────────────────────
List<Dog> _myDogs = [];
List<Dog> _allDogs = [];

List<Dog> get myDogs => List.unmodifiable(_myDogs);
List<Dog> get allDogs => List.unmodifiable(_allDogs);

// AppState fields
Dog? editingDog; // یا فقط editingDogId اگر ترجیح میدی
bool get isEditDogOpen => editingDog != null;

StreamSubscription<User?>? _authSub;

bool canConsumePlaydateRequest(String requestId) {
  return _lastConsumedPlaydateRequestId != requestId;
}

void calculateDistances(double userLat, double userLng) {
  for (final dog in _allDogs) {
    if (dog.latitude != null && dog.longitude != null) {
      dog.distanceKm = LocationUtils.calculateDistanceKm(
        userLat,
        userLng,
        dog.latitude!,
        dog.longitude!,
      );
    }
  }
}
void sortDogsByDistance() {
  _allDogs.sort((a, b) {
    final da = a.distanceKm ?? 9999;
    final db = b.distanceKm ?? 9999;
    return da.compareTo(db);
  });
}

void openProfileSubPage(ProfileSubPage page) {
  if (_profileSubPage == page) return;
  _profileSubPage = page;
  notifyListeners();
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
  notifyListeners();
}

void openEditDog(Dog dog) {
  editingDog = dog;
  notifyListeners();
}

void closeEditDog() {
  editingDog = null;
  notifyListeners();
}

Future<void> saveEditedDog(Dog updatedDog) async {
  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("User not authenticated");
    }

    final uid = user.uid;

    debugPrint("🐶 saveEditedDog START");
    debugPrint("🐶 currentUserUid => $uid");
    debugPrint("🐶 dogId => ${updatedDog.id}");

    final docRef =
        FirebaseFirestore.instance.collection('dogs').doc(updatedDog.id);

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
      'age': updatedDog.age,
      'healthStatus': updatedDog.healthStatus,
      'isNeutered': updatedDog.isNeutered,
      'description': updatedDog.description,
      'traits': updatedDog.traits,
      'ownerGender': updatedDog.ownerGender,
      'imagePaths': updatedDog.imagePaths,
      'isAvailableForAdoption': updatedDog.isAvailableForAdoption,

      // 🔐 برای عبور از rules
      'ownerUid': ownerUid,
      'ownerRole': data['ownerRole'],
      'centerId': data['centerId'],
    });

    final myIndex = _myDogs.indexWhere((d) => d.id == updatedDog.id);
    if (myIndex != -1) {
      _myDogs[myIndex] = updatedDog;
    }

    final allIndex = _allDogs.indexWhere((d) => d.id == updatedDog.id);
    if (allIndex != -1) {
      _allDogs[allIndex] = updatedDog;
    }

    editingDog = null;

    notifyListeners();

    debugPrint("✅ Dog updated safely");
  } catch (e, stack) {
    debugPrint("❌ saveEditedDog error: $e");
    debugPrint("STACK: $stack");
    rethrow;
  }
}
String? _initializedForUid;



void startAuthListener() {

  if (_authSub != null) {
    debugPrint('🛑 Auth listener already active');
    return;
  }

  debugPrint('🧨 startAuthListener INITIALIZED');

  _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {

    // ─────────────────────────────
    // USER LOGGED OUT
    // ─────────────────────────────
    if (user == null) {

  debugPrint('🚨 Auth state changed to NULL');

  if (FirebaseAuth.instance.currentUser != null) {
    debugPrint('⚠️ Ignoring false auth null state');
    return;
  }

  stopFirestoreListeners();

  _initializedForUid = null;

  // 🔥🔥🔥 THIS IS THE FIX
  _currentUserId = 'guest';

  _isUserInitialized = true;   // 👈 مهم
  _isUserProfileReady = true;  // 👈 مهم

  debugPrint('👤 Guest mode activated from auth listener');

  notifyListeners();

  return;
}

    // ─────────────────────────────
    // USER LOGGED IN
    // ─────────────────────────────
    if (_initializedForUid == user.uid) {
      debugPrint('🛑 initUser skipped (same uid)');
      return;
    }

    debugPrint('✅ Auth user detected → ${user.uid}');

    _initializedForUid = user.uid;

    initUser();
  });
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

void openAdoptionDogOverlay(String dogId) {
  adoptionDogOverlayId = dogId;
  notifyListeners();
}

void closeAdoptionDogOverlay() {
  adoptionDogOverlayId = null;
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

Future<void> initUser() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint('⚠️ AppState.initUser → no user');
    _isUserProfileReady = false;
    return;
  }

  _currentUserId = user.uid;

  debugPrint('🧩 AppState.initUser start → uid=$_currentUserId');
  debugPrint('🔥 initUser CALLED AFTER LOGIN uid=$_currentUserId');

// ✅ ENSURE TOPIC SUBSCRIPTION (NO REFACTOR)
try {
  await FirebaseMessaging.instance.subscribeToTopic('all_users');
  debugPrint('✅ Subscribed to topic: all_users');
} catch (e) {
  debugPrint('❌ Topic subscribe failed: $e');
}

  try {
   // await Future.delayed(const Duration(milliseconds: 300));

    await loadUsernameFromFirebase();
final uid = _currentUserId;
if (uid == null || uid.isEmpty) return;

_userDocSub?.cancel();

_userDocSub = FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .snapshots()
    .listen((doc) {
  final business = doc.data()?['business'];

  final newStatus = business?['status'];
  final newId = business?['businessId'];
  final newVerified = business?['isVerified'] == true;

  if (_businessStatus != newStatus ||
      _businessId != newId ||
      _isBusinessVerified != newVerified) {

    _businessStatus = newStatus;
    _businessId = newId;
    _isBusinessVerified = newVerified;

    debugPrint('🏢 Business state updated realtime → $_businessStatus');

    notifyListeners();
  }
});

    await loadMyDogs();
    await loadAllDogsForDiscovery();
    await loadSavedParksFromFirebase();

    startUnreadNotificationsListener();
    startLostFoundListeners();


    _isUserProfileReady = true;
    _isUserInitialized = true;
    

    debugPrint('✅ initUser finished → checking pending navigation');
    await checkInitialNotification(); 

    if (_pendingNotificationNavigation != null) {
      _handlePendingNavigation();
    }

  } catch (e, s) {
    debugPrint('❌ AppState.initUser error: $e');
    debugPrint('$s');
    _isUserProfileReady = false;
  }

  notifyListeners();
  
}


Future<void> checkInitialNotification() async {
  final initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    debugPrint('🔥 TERMINATED MESSAGE FOUND');
    await Future.delayed(const Duration(milliseconds: 500));
  handleNotificationTap(initialMessage.data);

  }
}


Future<void> loadUsernameFromFirebase() async {
  final uid = _currentUserId;
  if (uid == null || uid.isEmpty) return;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final data = doc.data();
_userRole = data?['role'];

// ─────────────────────────────
// SUBSCRIPTION LOAD
// ─────────────────────────────

_subscription = UserSubscription.fromMap(
  data?['subscription'],
);
debugPrint('👑 User role → $_userRole');
    _username = data?['username'];
    _currentUserName = data?['username'];

    // ─────────────────────────────
    // 🏢 BUSINESS STATE LOAD
    // ─────────────────────────────
    final business = data?['business'];

    _businessStatus = business?['status'];
    _businessId = business?['businessId'];
    _isBusinessVerified = business?['isVerified'] == true;

    debugPrint('👤 Username → $_username');
    debugPrint('🏢 Business status → $_businessStatus');
debugPrint(
  '💳 Subscription → ${_subscription.plan} / ${_subscription.status}',
);
    notifyListeners();
  } catch (e) {
    debugPrint('❌ loadUsernameFromFirebase error: $e');
  }
}

Future<void> _updateFcmToken(String uid) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();

    if (token == null) {
      debugPrint('⚠️ FCM token is null');
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );

    debugPrint('📲 FCM token updated in Firestore');
  } catch (e) {
    debugPrint('❌ _updateFcmToken error: $e');
  }
}


Future<void> loadMyDogs() async {
  final uid = _currentUserId;
  if (uid == null || uid.isEmpty) {
    debugPrint('🐾 loadMyDogs skipped (no uid)');
    return;
  }

  debugPrint('🐾 Loading dogs for user $uid');

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('dogs')
        .where('ownerId', isEqualTo: uid)
        .get();

    _myDogs = snapshot.docs
        .map((doc) => Dog.fromFirestore(doc))
        .toList();

    debugPrint('🐾 Loaded ${_myDogs.length} my dogs');
    notifyListeners();
  } catch (e, s) {
    debugPrint('❌ loadMyDogs error: $e');
    debugPrint('$s');
  }
}

Future<void> loadAllDogsForDiscovery() async {
  final uid = _currentUserId;

  if (uid == null || uid.isEmpty) {
    debugPrint('🐕 loadAllDogsForDiscovery skipped (no uid)');
    return;
  }

  debugPrint('🐕 Loading ALL dogs for discovery');

  try {

    final snapshot = await FirebaseFirestore.instance
    .collection('dogs')
    .where('isHidden', isEqualTo: false)
    .where('dogProfileVisible', isEqualTo: true)
    .where('ownerProfileVisible', isEqualTo: true)
    .limit(200)
    .get();

    final dogs = snapshot.docs
        .map((doc) {
          try {
            return Dog.fromFirestore(doc);
          } catch (e) {
            debugPrint('❌ Dog parsing error for doc ${doc.id}: $e');
            return null;
          }
        })
        .whereType<Dog>()
        .where((dog) => dog.ownerId != uid)   // 🔥 مهم
       // .where((dog) => dog.isHidden != true)
        .toList();

    _allDogs = dogs;

// 📍 TEMP user location (بعداً GPS می‌زنیم)
const userLat = 41.0082;   // Istanbul
const userLng = 28.9784;

// 🔥 calculate + sort
calculateDistances(userLat, userLng);
sortDogsByDistance();

debugPrint('🐕 Loaded ${_allDogs.length} discovery dogs');

notifyListeners();
  } catch (e, s) {
    debugPrint('❌ loadAllDogsForDiscovery error: $e');
    debugPrint('$s');
  }
}
void startLostFoundListeners() {

  if (_currentUserId == null) {
    debugPrint("🚫 Lost/Found listeners skipped (no user)");
    return;
  }

  _lostSub?.cancel();
  _foundSub?.cancel();

  _lostSub = FirebaseFirestore.instance
      .collection('lost_dogs')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .listen((snapshot) {
    _lostDogsCount = snapshot.docs.length;
    notifyListeners();
  });

  _foundSub = FirebaseFirestore.instance
      .collection('found_dogs')
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

String? _initialAdoptionRequestId;
String? get initialAdoptionRequestId => _initialAdoptionRequestId;

void setInitialAdoptionRequestId(String id) {
  _initialAdoptionRequestId = id;
  notifyListeners();
}

void consumeInitialAdoptionRequest() {
  _initialAdoptionRequestId = null;
}

void handleNotificationTap(Map<String, dynamic> payload) {
  debugPrint('🔥🔥🔥 TAP HANDLER EXECUTED');
  debugPrint('🔔 handleNotificationTap payload=$payload');

  final rawType = payload['type']?.toString() ?? '';
  final type = rawType.toLowerCase().trim();
  final requestId = payload['requestId']?.toString();
  final likerUserId = payload['likerUserId']?.toString();
  final lostDogId = payload['lostDogId']?.toString();
  final foundDogId = payload['foundDogId']?.toString();

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

  // ───────────────── LOST DOG ─────────────────
  if (type == 'lost_dog' && lostDogId != null && lostDogId.isNotEmpty) {
    closeNotifications();
    setCurrentTab(NavTab.lostDogs);
    openLostDogDetail(lostDogId);
    return;
  }

  // ───────────────── FOUND DOG ─────────────────
  if (type == 'found_dog' && foundDogId != null && foundDogId.isNotEmpty) {
    closeNotifications();
    setCurrentTab(NavTab.foundDogs);
    openFoundDogDetail(foundDogId);
    return;
  }

  // ───────────────── ADOPTION REQUEST ✅ ─────────────────
  if (type == 'adoption_request' && requestId != null && requestId.isNotEmpty) {
    debugPrint('🟢 Adoption REQUEST notification → $requestId');

    closeNotifications();

    setCurrentTab(NavTab.profile);
    openProfileSubPage(ProfileSubPage.adoptionInbox);
    setInitialAdoptionRequestId(requestId);

    return;
  }

    // ───────────────── BUSINESS RESOLUTION ✅ ─────────────────
  if (type == 'business_resolution') {
    final status = payload['status']?.toString().toLowerCase().trim(); // approved/rejected
    final centerId = payload['centerId']?.toString();
    final reason = payload['reason']?.toString();

    closeNotifications();
    _ignoreNextNotificationTap = true;
    ignoreNotificationIconTapFor(const Duration(milliseconds: 700));

    // ✅ همیشه ببر روی Profile چون “Business” ماهیت حساب/نقش دارد
    setCurrentTab(NavTab.profile);

    // 👇 پیشنهاد UX:
    // - اگر approved → برو به داشبورد سنتر
    // - اگر rejected → برو به صفحه وضعیت + نمایش reason
    if (status == 'approved') {
      // اگر داری: داشبورد اختصاصی
      openProfileSubPage(ProfileSubPage.businessDashboard);

      // Optional: برای اینکه داشبورد بدونه کدوم سنتره
      if (centerId != null && centerId.isNotEmpty) {
        setInitialBusinessCenterId(centerId); // اینو در AppState اضافه می‌کنی
      }
      return;
    }

    if (status == 'rejected') {
      openProfileSubPage(ProfileSubPage.businessStatus);

      // Optional: reason را one-shot ذخیره کن
      setInitialBusinessResolution(
        status: 'rejected',
        centerId: centerId,
        reason: reason,
      );
      return;
    }

    // اگر status نبود (قدیمی‌ها) → برو صفحه وضعیت business
    openProfileSubPage(ProfileSubPage.businessStatus);
    return;
  }

  debugPrint('⚠️ Unknown notification type: $rawType');
}
    // ─────────────────────────────────────
  // BOTTOM NAV STATE  ✅ (جدید)
  // ─────────────────────────────────────
  NavTab _currentTab = NavTab.home;

  NavTab get currentTab => _currentTab;

 void setCurrentTab(NavTab tab) {
  debugPrint('🧭 setCurrentTab CALLED → $tab');

  // 🟣 اگر داخل playdate هستیم و park فعاله → نادیده بگیر
  if (_currentTab == NavTab.playdate &&
      tab == NavTab.playdate &&
      _activePlaydatePark != null) {
    debugPrint('🛑 setCurrentTab ignored (active park flow)');
    return;
  }

  // 🟣 اگر داریم از playdate خارج میشیم → park رو پاک کن
  if (_currentTab == NavTab.playdate &&
      tab != NavTab.playdate) {
    _activePlaydatePark = null;
    _selectedRequesterDogId = null;
  }

  // 🟡 اگر داریم از تب lostDogs خارج میشیم
  // هر نوع detail باز (lost یا found) رو ببند
  if (_currentTab == NavTab.lostDogs &&
      tab != NavTab.lostDogs) {
    activeLostDogId = null;
    activeFoundDogId = null;
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

SubscriptionAccess get subscriptionAccess =>
    SubscriptionAccess(_subscription);

    // ─────────────────────────────
// SUBSCRIPTION ACCESS HELPERS
// ─────────────────────────────

bool get isGold =>
    subscription.plan == SubscriptionPlan.gold &&
    subscription.status.isActive;

bool get canRegisterBusiness =>
    subscriptionAccess.canRegisterBusiness;

bool get canUseAdvancedFilters =>
    subscriptionAccess.canUseAdvancedFilters;

bool get canUsePremiumChat =>
    subscriptionAccess.canUsePremiumChat;

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
  notifyListeners();
}

Future<void> handleRemoteMessage(RemoteMessage message) async {
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


  // ─── شروع Listener واقعی برای unread notifications ───
  void startUnreadNotificationsListener() {

  final uid = _currentUserId;

  if (uid == null || uid.isEmpty) {
    debugPrint("🔕 Notifications listener skipped (no user)");
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


void setSelectedRequesterDogId(String? dogId) {
  _selectedRequesterDogId = dogId;
  notifyListeners();
}

void clearPlaydateFlow() {
  _activePlaydatePark = null;
  _selectedRequesterDogId = null;
  notifyListeners();
}

void setMyDogs(List<Dog> dogs) {
  _myDogs = dogs;
  notifyListeners();
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
    if (uid == null) return;
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
  _favoriteParks.add({
    'name': parkName,
    'lat': parkLat,
    'lng': parkLng,
  });
}


    notifyListeners();

    // Sync با Firestore
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
       'savedParks': _favoriteParks,

      },
      SetOptions(merge: true),
    );
  }

  Map<String, dynamic>? getParkByName(String name) {
    try {
      return _favoriteParks.firstWhere((p) => p['name'] == name);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadSavedParksFromFirebase() async {
  final uid = _currentUserId;
  if (uid == null || uid.isEmpty) {
    _savedParksLoaded = true;
    return;
  }

  try {
    debugPrint('🏞 loadSavedParksFromFirebase start uid=$uid');

    DocumentSnapshot<Map<String, dynamic>> doc;

    // 1️⃣ اول cache
    try {
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.cache));

      debugPrint('🏞 Loaded savedParks from CACHE');
    } catch (_) {
      // ignore
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
    }

    // 2️⃣ اگر cache خالی بود → server
    if (!doc.exists || doc.data()?['savedParks'] == null) {
      debugPrint('🏞 Cache empty → loading from SERVER');

      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
    }

    final data = doc.data();
    final List<dynamic>? parks = data?['savedParks'];

_favoriteParks
  ..clear()
  ..addAll((parks ?? []).map((p) {
    if (p is Map<String, dynamic>) {
      return p;
    } else {
      return {'name': p}; // برای compatibility قدیمی
    }
  }));


    debugPrint('🏞 Loaded ${_favoriteParks.length} saved parks');

  } catch (e, s) {
    debugPrint('❌ loadSavedParksFromFirebase error: $e');
    debugPrint('$s');
  } finally {
    _savedParksLoaded = true;
    notifyListeners();
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
})  : _favoriteDogs = favoriteDogs,
      _dogLikes = {},
      _currentUserId = currentUserId,

      // ⬇️⬇️⬇️ ASSIGN
      _currentUserName = currentUserName,

      _selectedRequesterDogId = selectedRequesterDogId,
      _isPremium = isPremium;



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
    currentUserId = newId;
  }

  // ─── dispose تمیز کردن subscription ───
  @override
  void dispose() {
    _unreadNotificationsSub?.cancel();
    _unreadNotificationsSub = null;
    _lostSub?.cancel();
    _foundSub?.cancel();

    super.dispose();
  }

  // ─── بقیه متدها بدون تغییر (toggleFavorite, addLike, removeLike و ...) ───
  // فقط loadUnreadNotificationsCount رو حذف کردیم چون دیگه نیاز نیست

  Future<void> toggleFavorite(Dog dog) async {
    final key = dog.id;
    final favoritesBox = Hive.box<Dog>('favoritesBox');
    bool isFavorite =
        favoritesBox.values.any((favDog) => favDog.id == dog.id);

    if (isFavorite) {
      await removeFavorite(dog);
    } else {
      await addFavorite(dog);
    }
    notifyListeners();
  }

  Future<void> addFavorite(Dog dog) async {
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
      final indexToRemove =
          favoritesBox.values.toList().indexWhere((favDog) => favDog.id == dog.id);
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

  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientUserId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();

    _unreadNotificationsCount = snapshot.docs.length;
    notifyListeners();

    debugPrint(
      '🔔 AppState unreadNotificationsCount = $_unreadNotificationsCount',
    );
  } catch (e) {
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
        'username': _username ?? 'User'
, // اضافه کردن نام کاربری
      });
      print('AppState - User $userId liked $dogKey in Firestore');

      final updatedLikes = Map<String, List<String>>.from(currentLikes);
      updatedLikes[userId] = [...userLikes, dogKey];
      likesNotifier.value = updatedLikes;
      print('AppState - Updated likesNotifier for user $userId');

      // به‌روزرسانی dogLikes
      final updatedDogLikes = Map<String, List<Map<String, dynamic>>>.from(_dogLikes);
      updatedDogLikes[dogKey] = [
        ...(updatedDogLikes[dogKey] ?? []),
        {'userId': userId, 'username': _username ?? 'User'},
      ];
      _dogLikes = updatedDogLikes;
      notifyListeners();
      print('AppState - Updated dogLikes for dog $dogKey');

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
      print('AppState - Stored notification for owner: ${dog.ownerId}');

      await _checkForMutualLike(userId, dog, context);
    } catch (e) {
      print('AppState - Error adding like: $e');
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
        print('AppState - Removed like for $dogKey by user $userId from Firestore');
      }

      final currentLikes = Map<String, List<String>>.from(likesNotifier.value);
      final userLikes = List<String>.from(currentLikes[userId] ?? []);
      currentLikes[userId] = userLikes.where((key) => key != dogKey).toList();
      if (currentLikes[userId]!.isEmpty) {
        currentLikes.remove(userId);
      }
      likesNotifier.value = Map<String, List<String>>.from(currentLikes);
      print('AppState - Updated likesNotifier after removing like for user $userId');

      // به‌روزرسانی dogLikes
      final updatedDogLikes = Map<String, List<Map<String, dynamic>>>.from(_dogLikes);
      updatedDogLikes[dogKey] = (updatedDogLikes[dogKey] ?? []).where((liker) => liker['userId'] != userId).toList();
      if (updatedDogLikes[dogKey]!.isEmpty) {
        updatedDogLikes.remove(dogKey);
      }
      _dogLikes = updatedDogLikes;
      notifyListeners();
      print('AppState - Updated dogLikes after removing like for dog $dogKey');
    } catch (e) {
      print('AppState - Error removing like: $e');
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

  Future<void> _checkForMutualLike(String likerUserId, Dog likedDog, BuildContext context) async {
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
        id: 'unknown_${likerUserId}',
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
      final requestId = '${likerUserId}_${likedDogOwnerId}_${DateTime.now().millisecondsSinceEpoch}';
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
        final title = localizations.newPlayDateRequestTitle;
        final body = localizations.newPlayDateRequestBody(likerDog.name);
      


       // await _storeNotification(likedDogOwnerId, title, body, requestId);
        print('AppState - Stored playdate notification for owner: $likedDogOwnerId');
      } else {
        print('AppState - PlayDate request already exists between $likerUserId and $likedDogOwnerId');
      }
    }
  

  Future<void> deletePlayDateRequest(String requestId, BuildContext context) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      print('AppState - Current auth uid: $currentUserId');
      final docRef = FirebaseFirestore.instance.collection('playDateRequests').doc(requestId);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        print('AppState - Request $requestId not found in Firestore');
        return;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      final requesterUserId = data['requesterUserId'] as String;
      final requestedUserId = data['requestedUserId'] as String;
      final status = data['status'] as String;

      print('AppState - Deleting request $requestId with status: $status');
      print('AppState - Request data: $data');
      print('AppState - Comparing uids: current=$currentUserId, requester=$requesterUserId, requested=$requestedUserId');

      if (currentUserId != requesterUserId && currentUserId != requestedUserId) {
        print('AppState - User $currentUserId does not have permission to delete request $requestId');
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'User does not have permission to delete this request',
        );
      }

      await docRef.delete();
      print('AppState - Deleted PlayDate request from Firestore: $requestId');

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = jsonEncode({
        'type': 'playDateRequest',
        'requestId': requestId,
        'requesterUserId': requesterUserId,
      });
      final localizations = AppLocalizations.of(context)!;
      final title = localizations.playDateCanceledTitle;
      final body = localizations.playDateCanceledBody(data['requestedDog']['name'] as String);
     



      //await _storeNotification(requesterUserId, title, body, requestId);
      //await _storeNotification(requestedUserId, title, body, requestId);
      print('AppState - Stored cancellation notification for users: $requesterUserId, $requestedUserId');
    } catch (e) {
      print('AppState - Error deleting PlayDate request: $e');
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
      print('AppState - Current auth uid: $currentUserId');
      print('AppState - Sending notification for request: $requestId, status: $status, requester: $requesterUserId, requested: $requestedUserId');
      print('AppState - Comparing uids: current=$currentUserId, requester=$requesterUserId, requested=$requestedUserId');
      if (currentUserId.isEmpty) {
        print('AppState - No user logged in, cannot send notification');
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

      String recipientUserId = currentUserId == requesterUserId ? requestedUserId : requesterUserId;
      final localizations = AppLocalizations.of(context)!;
      String title;
      String body;

      if (status.toLowerCase() == 'accepted') {
        title = localizations.playDateAcceptedTitle;
        body = currentUserId == requesterUserId
            ? localizations.playDateAcceptedBodyRequester(requestedDog.name)
            : localizations.playDateAcceptedBodyRequested(requestedDog.name, scheduledDateTime != null
                ? ' on ${scheduledDateTime.toLocal().toString().split(' ')[0]} at ${scheduledDateTime.toLocal().hour}:${scheduledDateTime.toLocal().minute}'
                : '');
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
      print('AppState - Sent playdate $status notification to: $recipientUserId');
    } catch (e) {
      print('AppState - Error sending playdate status notification: $e');
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
        if (requestDate != null && requestDate.isBefore(currentTime.subtract(Duration(days: 1)))) {
          await FirebaseFirestore.instance.collection('playDateRequests').doc(doc.id).delete();
          print('AppState - Deleted old PlayDate request from Firestore: ${doc.id}');
        }
      }
    } catch (e) {
      print('AppState - Error cleaning old PlayDate requests: $e');
    }
  }
}