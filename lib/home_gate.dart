import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/home_page.dart';
import 'package:barky_matches_fixed/favorites_page.dart';
import 'package:barky_matches_fixed/vet_page.dart';
import 'package:barky_matches_fixed/groomy_page.dart';
import 'package:barky_matches_fixed/pet_hotel_page.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_page.dart';
import 'package:barky_matches_fixed/ui/common/pages/petshop_list_page.dart';
import 'package:barky_matches_fixed/ui/pet_taxi/pet_taxi_booking_detail_page.dart';
import 'package:barky_matches_fixed/ui/green_memorial/green_memorial_page.dart';
import 'package:barky_matches_fixed/play_date_requests_page_new.dart';
import 'package:barky_matches_fixed/user_profile_page.dart';
import 'package:barky_matches_fixed/dog_park_page.dart';
import 'package:barky_matches_fixed/park_playdate_entry_page.dart';
import 'package:barky_matches_fixed/playmate_page.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/web_auth_debug_overlay.dart';

import 'package:barky_matches_fixed/ui/shell/barky_scaffold.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';

import 'dog.dart';
import 'adoption_page.dart';
import 'package:barky_matches_fixed/screens/found_dog_report_page.dart';
import 'package:barky_matches_fixed/screens/lost_dog_report_page.dart';
import 'package:barky_matches_fixed/screens/lost_dogs_list_page.dart';
import 'package:barky_matches_fixed/screens/found_dogs_list_page.dart';
import 'package:barky_matches_fixed/play_date_scheduling_page.dart';
import 'package:barky_matches_fixed/ui/adoption/adoption_inbox_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/vet/appointment_payment_page.dart';

import 'package:barky_matches_fixed/ui/orders/my_orders_page.dart';
//import 'package:barky_matches_fixed/ui/appointments/my_appointments_page.dart';
import 'package:barky_matches_fixed/appointments/pages/appointment_status_page.dart';
import 'package:barky_matches_fixed/ui/feedback/feedback_form_page.dart';
import 'package:barky_matches_fixed/ui/setting/privacy_settings_page.dart';
import 'package:barky_matches_fixed/ui/support/report_problem_page.dart';
import 'package:barky_matches_fixed/upgrade_page.dart';
import 'package:barky_matches_fixed/ui/profile/change_password_page.dart';
import 'package:barky_matches_fixed/ui/setting/delete_account_page.dart';
import 'package:barky_matches_fixed/ui/business/business_register_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/business_dashboard_page.dart';
import 'package:barky_matches_fixed/ui/help/help_center_page.dart';

import 'package:barky_matches_fixed/ui/support/faq_page.dart';

import 'package:barky_matches_fixed/social/pages/petplore_page.dart';

import 'package:barky_matches_fixed/appointments/pages/service_categories_page.dart';
import 'package:barky_matches_fixed/ui/appointments/my_appointments_page.dart';
import 'package:barky_matches_fixed/screens/suspended_account_page.dart';

// ─────────────────────────────────────────────
// HomeGate
// ─────────────────────────────────────────────

class HomeGate extends StatefulWidget {
  const HomeGate({super.key});

  @override
  State<HomeGate> createState() => _HomeGateState();
}

class _HomeGateState extends State<HomeGate> {
  @override
  void initState() {
    super.initState();
    _handleInitialNotification();
    debugPrint('🧩 HomeGate initState hash=${identityHashCode(this)}');
  }

  @override
  void activate() {
    super.activate();
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _handleInitialNotification() async {
    final appState = context.read<AppState>();

    if (appState.isGuestUser) {
      debugPrint('🚫 Guest → skip initial notification handling');
      return;
    }

    final message = await FirebaseMessaging.instance.getInitialMessage();

    if (message == null) return;

    final start = DateTime.now();

    await Future.doWhile(() async {
      if (!mounted) return false;

      final appState = context.read<AppState>();
      final uid = appState.currentUserId;

      if (appState.isGuestUser) return false;

      if (uid != null && uid.isNotEmpty) return false;

      if (DateTime.now().difference(start).inSeconds >= 8) {
        debugPrint('⛔ Initial notification wait timeout');
        return false;
      }

      await Future.delayed(const Duration(milliseconds: 100));

      return true;
    });
    if (!mounted) return;

    final data = message.data;
    final type = (data['type'] ?? '').toString();
    if (context.read<AppState>().isGuestUser) {
      debugPrint('🚫 Guest → skip notification navigation');
      return;
    }

    // 🔥 FIXED POSITION
    if (type == 'vet_appointment_request' && data['appointmentId'] != null) {
      final appState = context.read<AppState>();

      if (!appState.consumeNotificationNavigation()) return;

      appState.setCurrentTab(NavTab.vet);

      debugPrint("🐾 Navigate to vet from notification");
    }

    if ((type == 'playdateRequest' || type == 'playdateResponse') &&
        data['requestId'] != null) {
      final appState = context.read<AppState>();

      if (!appState.consumeNotificationNavigation()) return;

      appState.setInitialPlaydateRequest(data['requestId'].toString());

      appState.setCurrentTab(NavTab.playdate);
    }
  }

  @override
  Widget build(BuildContext context) {
    webAuthTrace('HOME_GATE_BUILD', {'identity': identityHashCode(this)});
    debugPrint('🧱 HomeGate build hash=${identityHashCode(this)}');

    final isAccountSuspended = context.select<AppState, bool>(
      (s) => s.isAccountSuspended,
    );
    if (isAccountSuspended) {
      return const SuspendedAccountPage();
    }

    return const _HomeBody();
  }
}

// ─────────────────────────────────────────────
// HomeBody
// ─────────────────────────────────────────────

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  late final List<Widget> _pages;
  bool _isTransitioning = false;
  final bool _firstLoad = true;
  NavTab? _lastTab;
  @override
  void initState() {
    super.initState();

    _pages = const [
      HomePage(key: PageStorageKey('home')),
      FavoritesPage(key: PageStorageKey('favorites')),
      VetPage(key: PageStorageKey('vet')),
      PetShopListPage(key: PageStorageKey('petShop')),
      GroomyPage(key: PageStorageKey('groomy')),
      PetHotelPage(key: PageStorageKey('petHotel')),
      PetTaxiPage(key: PageStorageKey('petTaxi')),
    ];

    // 🔥 FIRST LOAD SPINNER
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTransition();
    });
  }

  Widget _buildCurrentTab(
    NavTab tab,
    String currentUserId,
    List<Dog> allDogs,
    List<Dog> favoriteDogs,
    Function(Dog) onToggleFavorite,
  ) {
    switch (tab) {
      case NavTab.home:
        return const HomePage(key: PageStorageKey('home'));

      case NavTab.favorites:
        return const FavoritesPage(key: PageStorageKey('favorites'));

      case NavTab.vet:
        return const VetPage(key: PageStorageKey('vet'));

      case NavTab.petShop:
        return const PetShopListPage(key: PageStorageKey('petShop'));

      case NavTab.groomy:
        return const GroomyPage(key: PageStorageKey('groomy'));

      case NavTab.petHotel:
        return const PetHotelPage(key: PageStorageKey('petHotel'));

      case NavTab.petTaxi:
        return const PetTaxiPage(key: PageStorageKey('petTaxi'));

      case NavTab.playdate:
        return const _PlaydateTab(key: PageStorageKey('playdate'));

      case NavTab.petplore:
        return const PetplorePage(key: PageStorageKey('petplore'));

      case NavTab.playmates:
        return PlaymatePage(
          key: const PageStorageKey('playmates'),
          dogs: allDogs,
          currentUserId: currentUserId,
          favoriteDogs: favoriteDogs,
          onToggleFavorite: onToggleFavorite,
        );

      case NavTab.profile:
        return const _ProfileTab(key: PageStorageKey('profile'));

      case NavTab.dogParks:
        return const DogParkPage(key: PageStorageKey('dogParks'));

      case NavTab.greenMemorial:
        return const GreenMemorialPage(key: PageStorageKey('greenMemorial'));

      case NavTab.adoption:
        return AdoptionPage(
          dogs: allDogs,
          favoriteDogs: favoriteDogs,
          onToggleFavorite: onToggleFavorite,
        );

      case NavTab.reportLost:
        return const LostDogReportPage();

      case NavTab.reportFound:
        return const FoundDogReportPage();

      case NavTab.lostDogs:
        return const LostDogsListPage();

      case NavTab.foundDogs:
        return const FoundDogsListPage();

      case NavTab.playdateScheduling:
        return const PlayDateSchedulingPage(key: PageStorageKey('schedule'));

      case NavTab.none:
        return const SizedBox();
    }
  }

  void _startTransition() {
    if (!mounted) return;

    if (_isTransitioning) return;

    setState(() {
      _isTransitioning = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;

      if (_isTransitioning) {
        setState(() {
          _isTransitioning = false;
        });
      }
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;

      if (_isTransitioning) {
        debugPrint('⛔ Transition timeout recovery');

        setState(() {
          _isTransitioning = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedAppointmentId = context.select<AppState, String?>(
      (s) => s.selectedAppointmentId,
    );

    final selectedAppointmentCollection = context.select<AppState, String?>(
      (s) => s.selectedAppointmentCollection,
    );

    final currentTab = context.select<AppState, NavTab>((s) => s.currentTab);

    final appState = context.read<AppState>();

    // ==========================
    // 🔥 APPOINTMENT PAYMENT NAVIGATION
    // ==========================
    if (selectedAppointmentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final appointmentId = selectedAppointmentId;
        final collection = selectedAppointmentCollection ?? 'vet_appointments';
        final isPetTaxi = collection == 'pet_taxi_bookings';
        final isGroomy = collection == 'groomy_appointments';
        final isHotel = collection == 'hotel_bookings';
        debugPrint("💳 NAVIGATE TO PAYMENT PAGE → $appointmentId");

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isPetTaxi
                ? PetTaxiBookingDetailPage(bookingId: appointmentId)
                : AppointmentPaymentPage(
                    appointmentId: appointmentId,
                    appointmentCollection: collection,
                    appointmentType: isHotel
                        ? 'pet_hotel'
                        : isGroomy
                        ? 'grooming'
                        : 'veterinary',
                    updateStatusFunctionName: isHotel
                        ? 'updateHotelBookingStatus'
                        : isGroomy
                        ? 'updateGroomyAppointmentStatus'
                        : 'updateVetAppointmentStatus',
                    createOrderFunctionName: isHotel
                        ? 'createHotelBookingOrder'
                        : 'createAppointmentOrder',
                    verifyPaymentFunctionName: isHotel
                        ? 'verifyHotelBookingPayment'
                        : 'verifyPayment',
                    serviceFallbackName: isHotel
                        ? 'Hotel stay'
                        : isGroomy
                        ? 'Grooming service'
                        : 'Veterinary service',
                    businessFallbackName: isHotel
                        ? 'Pet hotel'
                        : isGroomy
                        ? 'Grooming studio'
                        : 'Vet clinic',
                    businessInfoLabel: isHotel
                        ? 'Hotel'
                        : isGroomy
                        ? 'Groomy'
                        : 'Clinic',
                  ),
          ),
        );

        appState.consumeSelectedAppointment();
      });
    }

    if (_lastTab != null && _lastTab != currentTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startTransition();
      });
    }

    _lastTab = currentTab;
    /*
if (appState.isGuest) {
  if (currentTab != NavTab.adoption) {
    debugPrint("⛔ Guest blocked → forcing adoption tab");
    currentTab = NavTab.adoption;
  }
}
*/
    final currentUserId = context.select<AppState, String?>(
      (s) => s.currentUserId,
    );

    final unreadNotifications = context.select<AppState, int>(
      (s) => s.unreadNotificationsCount,
    );

    final allDogs = context.select<AppState, List<Dog>>((s) => s.allDogs);

    final favoriteDogs = context.select<AppState, List<Dog>>(
      (s) => s.favoriteDogs,
    );

    final onToggleFavorite = context.read<AppState>().onToggleFavorite;

    final openNotifications = context.read<AppState>().openNotifications;

    // if (currentUserId == null || currentUserId.isEmpty) {
    //return const Center(
    //child: CircularProgressIndicator(),
    //);
    //}

    return BarkyScaffold(
      currentTab: currentTab,
      currentUserId: currentUserId ?? "",
      unreadNotifications: unreadNotifications,
      dogs: allDogs,
      favoriteDogs: favoriteDogs,
      onToggleFavorite: onToggleFavorite,
      onNotificationTap: openNotifications,
      body: Stack(
        children: [
          // 🟢 MAIN
          if (currentUserId != null && currentUserId.isNotEmpty)
            switch (currentTab) {
              NavTab.home => _pages[0],
              NavTab.favorites => _pages[1],
              NavTab.vet => _pages[2],
              NavTab.petShop => _pages[3],
              NavTab.groomy => _pages[4],
              NavTab.petHotel => _pages[5],
              NavTab.petTaxi => _pages[6],
              _ => _buildCurrentTab(
                currentTab,
                currentUserId,
                allDogs,
                favoriteDogs,
                onToggleFavorite,
              ),
            }
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),

                  const SizedBox(height: 16),

                  Text(l10n.loadingAccount),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      // optional retry
                      setState(() {});
                    },
                    child: Text(l10n.retryButton),
                  ),
                ],
              ),
            ),

          // 🔥 OVERLAY
          // 🔥 OVERLAY
          if (_isTransitioning && currentTab != NavTab.petTaxi)
            Container(
              color: Colors.white.withOpacity(0.4),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

int _tabToIndex(NavTab tab) {
  switch (tab) {
    case NavTab.home:
      return 0;

    case NavTab.favorites:
      return 1;

    case NavTab.vet:
      return 2;

    case NavTab.petShop:
      return 3;

    case NavTab.groomy:
      return 4;

    case NavTab.petHotel:
      return 5;

    case NavTab.petTaxi:
      return 6;

    case NavTab.playdate:
      return 5;

    case NavTab.playmates:
      return 6;

    case NavTab.profile:
      return 7;

    case NavTab.dogParks:
    case NavTab.none:
      return 8;

    case NavTab.adoption:
      return 9;

    case NavTab.reportLost:
      return 10;

    case NavTab.reportFound:
      return 11;

    case NavTab.lostDogs:
      return 12;

    case NavTab.foundDogs:
      return 13;

    case NavTab.playdateScheduling:
      return 14; // 👈 فقط این اضافه شد

    case NavTab.greenMemorial:
      return 15;
    case NavTab.petplore:
      return _tabToIndex(NavTab.home);
  }
}

// ─────────────────────────────────────────────
// Playdate Tab Wrapper
// ─────────────────────────────────────────────

class _PlaydateTab extends StatelessWidget {
  const _PlaydateTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();

    final activePark = context.select<AppState, Map<String, dynamic>?>(
      (s) => s.activePlaydatePark,
    );

    final requestId = context.select<AppState, String?>(
      (s) => s.initialPlaydateRequestId,
    );

    if (activePark != null) {
      return ParkPlaydateEntryView(
        park: activePark,
        onClose: () => appState.clearPlaydateFlow(),
      );
    }

    if (requestId != null && requestId.isNotEmpty) {
      return PlayDateRequestsPageNew(
        key: ValueKey(requestId),
        dogsList: appState.myDogs,
        favoriteDogs: appState.favoriteDogs,
        onToggleFavorite: appState.onToggleFavorite,
        initialRequestId: requestId,
      );
    }

    return PlayDateRequestsPageNew(
      dogsList: appState.allDogs,
      favoriteDogs: appState.favoriteDogs,
      onToggleFavorite: appState.onToggleFavorite,
    );
  }
}

// ─────────────────────────────────────────────
// Profile Tab Wrapper
// ─────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({super.key});

  Widget _buildAppointmentSubPage(BuildContext context, AppState appState) {
    final service = appState.selectedAppointmentService;
    final status = appState.selectedAppointmentStatus;

    Widget child;
    switch (appState.profileSubPage) {
      case ProfileSubPage.appointmentStatus:
        child = service == null
            ? const ServiceCategoriesPage()
            : AppointmentStatusPage(service: service);
        break;
      case ProfileSubPage.appointmentHistory:
        child = service == null || status == null
            ? const ServiceCategoriesPage()
            : AppointmentHistoryPage(
                service: service.type,
                status: status.type,
              );
        break;
      case ProfileSubPage.appointments:
      default:
        child = const ServiceCategoriesPage();
        break;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.read<AppState>().backFromAppointmentFlow();
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedSubPage = context.select<AppState, ProfileSubPage>(
      (state) => state.profileSubPage,
    );
    if (selectedSubPage == ProfileSubPage.businessDashboard) {
      return const _BusinessDashboardTab();
    }

    final appState = context.watch<AppState>();

    final uid = appState.currentUserId;
    final myDogs = appState.myDogs;
    final favoriteDogs = appState.favoriteDogs;
    final onToggleFavorite = appState.onToggleFavorite;
    final subPage = appState.profileSubPage;

    if (uid == null || uid.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 🟢 Adoption Inbox
    if (subPage == ProfileSubPage.adoptionInbox) {
      return AdoptionInboxPage();
    }

    // 🟢 My Orders
    if (subPage == ProfileSubPage.myOrders) {
      return const MyOrdersPage();
    }

    // 🟢 Appointments
    if (subPage == ProfileSubPage.appointments ||
        subPage == ProfileSubPage.appointmentStatus ||
        subPage == ProfileSubPage.appointmentHistory) {
      return _buildAppointmentSubPage(context, appState);
    }

    // 🟢 Feedback
    if (subPage == ProfileSubPage.feedback) {
      return const FeedbackFormPage();
    }

    // 🟢 Privacy
    if (subPage == ProfileSubPage.privacy) {
      return const PrivacySettingsPage();
    }

    // 🟢 Report Problem
    if (subPage == ProfileSubPage.reportProblem) {
      return const ReportProblemPage();
    }

    // 🟢 Upgrade
    if (subPage == ProfileSubPage.upgrade) {
      return UpgradePage(
        onClose: () {
          debugPrint("🔥 PROFILE onClose");
          context.read<AppState>().closeProfileSubPage();
        },
      );
    }

    // 🟢 Change Password
    if (subPage == ProfileSubPage.changePassword) {
      return const ChangePasswordPage();
    }

    // 🟢 Delete Account
    if (subPage == ProfileSubPage.deleteAccount) {
      return const DeleteAccountPage();
    }

    // 🟢 Business Register
    if (subPage == ProfileSubPage.businessRegister) {
      return const BusinessRegisterPage();
    }

    // 🟢 Business Dashboard

    if (subPage == ProfileSubPage.helpCenter) {
      return const HelpCenterPage();
    }

    if (subPage == ProfileSubPage.faq) {
      return const FAQPage();
    }

    // 🟢 Default Profile
    return UserProfilePage(
      dogs: myDogs,
      favoriteDogs: favoriteDogs,
      onToggleFavorite: onToggleFavorite,
      userId: uid,
    );
  }
}

class _BusinessDashboardTab extends StatelessWidget {
  const _BusinessDashboardTab();

  @override
  Widget build(BuildContext context) {
    final businessId = context.select<AppState, String?>(
      (state) => state.businessId,
    );
    if (businessId == null || businessId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return BusinessDashboardPage(
      key: ValueKey(businessId),
      businessId: businessId,
    );
  }
}
