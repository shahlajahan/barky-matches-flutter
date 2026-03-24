import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/home_page.dart';
import 'package:barky_matches_fixed/favorites_page.dart';
import 'package:barky_matches_fixed/vet_page.dart';
import 'package:barky_matches_fixed/play_date_requests_page_new.dart';
import 'package:barky_matches_fixed/user_profile_page.dart';
import 'package:barky_matches_fixed/dog_park_page.dart';
import 'package:barky_matches_fixed/park_playdate_entry_page.dart';
import 'package:barky_matches_fixed/playmate_page.dart';

import 'package:barky_matches_fixed/ui/shell/barky_scaffold.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';

import 'dog.dart';
import 'adoption_page.dart';
import 'package:barky_matches_fixed/screens/found_dog_report_page.dart';
import 'package:barky_matches_fixed/screens/lost_dog_report_page.dart';
import 'package:barky_matches_fixed/screens/lost_dogs_list_page.dart';
import 'package:barky_matches_fixed/screens/found_dogs_list_page.dart';
import 'app_state.dart';
import 'package:barky_matches_fixed/play_date_scheduling_page.dart';
import 'package:barky_matches_fixed/ui/adoption/adoption_inbox_page.dart';
import 'package:barky_matches_fixed/playmate_page.dart';

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

  Future<void> _handleInitialNotification() async {
    final message =
        await FirebaseMessaging.instance.getInitialMessage();

    if (message == null) return;

    await Future.doWhile(() async {
      final uid = context.read<AppState>().currentUserId;
      if (uid != null && uid.isNotEmpty) return false;
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    });

    if (!mounted) return;

    final data = message.data;
    final type = (data['type'] ?? '').toString();

    if ((type == 'playdateRequest' ||
            type == 'playdateResponse') &&
        data['requestId'] != null) {

      final appState = context.read<AppState>();

      if (!appState.consumeNotificationNavigation()) return;

      appState.setInitialPlaydateRequest(
          data['requestId'].toString());

      appState.setCurrentTab(NavTab.playdate);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🧱 HomeGate build hash=${identityHashCode(this)}');
    return const _HomeBody();
  }
}


// ─────────────────────────────────────────────
// HomeBody
// ─────────────────────────────────────────────

class _HomeBody extends StatefulWidget {
  const _HomeBody({super.key});

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  //late final List<Widget> _pages;
bool _isTransitioning = false;
bool _firstLoad = true;
NavTab? _lastTab;
  @override
void initState() {
  super.initState();

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

    case NavTab.playdate:
      return const _PlaydateTab(key: PageStorageKey('playdate'));

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
      return const PlayDateSchedulingPage(
        key: PageStorageKey('schedule'),
      );

    case NavTab.none:
      return const SizedBox();
  }
}

void _startTransition() {
  if (!mounted) return;

  setState(() {
    _isTransitioning = true;
  });

  Future.delayed(const Duration(milliseconds: 800), () {
    if (!mounted) return;

    setState(() {
      _isTransitioning = false;
    });
  });
}
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
var currentTab = appState.currentTab;

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
    final currentUserId =
        context.select<AppState, String?>((s) => s.currentUserId);

    final unreadNotifications =
        context.select<AppState, int>((s) => s.unreadNotificationsCount);

    final allDogs =
        context.select<AppState, List<Dog>>((s) => s.allDogs);

    final favoriteDogs =
        context.select<AppState, List<Dog>>((s) => s.favoriteDogs);

    final onToggleFavorite =
        context.read<AppState>().onToggleFavorite;

    final openNotifications =
        context.read<AppState>().openNotifications;

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
        _buildCurrentTab(
          currentTab,
          currentUserId,
          allDogs,
          favoriteDogs,
          onToggleFavorite,
        )
      else
        const SizedBox(), // یا placeholder ساده

      // 🔥 OVERLAY همیشه قابل نمایش
      if (_isTransitioning)
        Container(
          color: Colors.white.withOpacity(0.4),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
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

    case NavTab.playdate:
      return 3;

    case NavTab.playmates:
      return 4;

    case NavTab.profile:
      return 5;

    case NavTab.dogParks:
    case NavTab.none:
      return 6;

    case NavTab.adoption:
      return 7;

    case NavTab.reportLost:
      return 8;

    case NavTab.reportFound:
      return 9;

    case NavTab.lostDogs:
      return 10;

    case NavTab.foundDogs:
      return 11;

    case NavTab.playdateScheduling:
      return 12; // 👈 فقط این اضافه شد
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

    final activePark =
        context.select<AppState, Map<String, dynamic>?>(
            (s) => s.activePlaydatePark);

    final requestId =
        context.select<AppState, String?>(
            (s) => s.initialPlaydateRequestId);

    if (activePark != null) {
      return ParkPlaydateEntryView(
        park: activePark,
        onClose: () => appState.clearPlaydateFlow(),
      );
    }

    if (requestId != null && requestId.isNotEmpty) {
      return PlayDateRequestsPageNew(
        key: ValueKey(requestId),
        dogsList: appState.allDogs,
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

  @override
  Widget build(BuildContext context) {
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
      return  AdoptionInboxPage();
    }

    // 🟢 Saved Parks (اگر بعداً بخوای)
    //if (subPage == ProfileSubPage.savedParks) {
      //return  SavedParksPage(); // اگر داری
    //}

    // 🟢 Default Profile
    return UserProfilePage(
      dogs: myDogs,
      favoriteDogs: favoriteDogs,
      onToggleFavorite: onToggleFavorite,
      userId: uid,
    );
  }
}