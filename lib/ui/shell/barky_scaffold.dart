
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../dog.dart';
import '../../app_state.dart';

import 'barky_app_bar.dart';
import 'barky_drawer.dart';
import 'barky_bottom_nav.dart';
import 'nav_tab.dart';

//import '../vet/vet_card_data.dart';
//import '../vet/vet_detail_overlay.dart';
import 'package:barky_matches_fixed/notifications_page.dart';
import 'package:barky_matches_fixed/adoption_page.dart';
import 'package:barky_matches_fixed/dog_card.dart';
import 'package:barky_matches_fixed/dog_card.dart' show DogCardMode;
import 'package:barky_matches_fixed/edit_dog_overlay.dart';
import 'package:barky_matches_fixed/play_date_scheduling_page.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:barky_matches_fixed/ui/business/business_detail_overlay.dart';


class BarkyScaffold extends StatefulWidget {
  final Widget body;
  final NavTab currentTab;

  final String currentUserId;
  final List<Dog> dogs;
  final List<Dog> favoriteDogs;
  final void Function(Dog) onToggleFavorite;

  final int unreadNotifications;
  final VoidCallback onNotificationTap;

  const BarkyScaffold({
    super.key,
    required this.body,
    required this.currentTab,
    required this.currentUserId,
    required this.dogs,
    required this.favoriteDogs,
    required this.onToggleFavorite,
    required this.onNotificationTap,
    this.unreadNotifications = 0,
  });

  @override
  State<BarkyScaffold> createState() => _BarkyScaffoldState();
}

class _BarkyScaffoldState extends State<BarkyScaffold> {
  // 🔒 فقط این تغییر انجام شده — key ثابت شد
  final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,

      // ─────────────────────────────
      // ☰ Drawer
      // ─────────────────────────────
      drawer: BarkyDrawer(
        currentUserId: widget.currentUserId,
        dogs: widget.dogs,
        favoriteDogs: widget.favoriteDogs,
        onToggleFavorite: widget.onToggleFavorite,
      ),

      // ─────────────────────────────
      // 🔝 AppBar
      // ─────────────────────────────
      appBar: BarkyAppBar(
        title: _titleForTab(widget.currentTab),
        unreadNotifications: widget.unreadNotifications,
        onMenuTap: () {
          scaffoldKey.currentState?.openDrawer();
        },
        onChatTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat coming soon')),
          );
        },
        onNotificationTap: widget.onNotificationTap,
      ),

      // ─────────────────────────────
      // 📄 Body
      // ─────────────────────────────
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            widget.body,
/*
            // ─────────────────────────────
            // 🩺 Vet Detail Overlay
            // ─────────────────────────────
            Builder(
              builder: (context) {
                final vet =
    context.select<AppState, BusinessCardData?>(
  (s) => s.activeBusiness,
);

                if (vet == null) return const SizedBox.shrink();

                final appState = context.read<AppState>();

                return VetDetailOverlay(
                  data: vet,
                  onClose: appState.closeBusinessDetails,
                  onOpenAppointment: () {
                    appState.closeBusinessDetails();
                    appState.openBusinessAppointment(vet);
                  },
                  onCall: vet.phone == null
                      ? null
                      : () async {
                          final uri =
                              Uri.parse('tel:${vet.phone}');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                  onWhatsApp: vet.whatsapp == null
                      ? null
                      : () async {
                          final phone = vet.whatsapp!
                              .replaceAll('+', '')
                              .replaceAll(' ', '');
                          final uri =
                              Uri.parse('https://wa.me/$phone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode:
                                  LaunchMode.externalApplication,
                            );
                          }
                        },
                  onDirections: () async {
                    final query = Uri.encodeComponent(
                        '${vet.address}, ${vet.city}');
                    final uri = Uri.parse(
                        'https://www.google.com/maps/search/?api=1&query=$query');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode:
                            LaunchMode.externalApplication,
                      );
                    }
                  },
                );
              },
            ),

            */

// ─────────────────────────────
// 🧩 Business Detail Overlay (GLOBAL)
// ─────────────────────────────
Builder(
  builder: (context) {
    final business = context.select<AppState, BusinessCardData?>(
      (s) => s.activeBusiness,
    );

    if (business == null) return const SizedBox.shrink();

    final appState = context.read<AppState>();

    return BusinessDetailOverlay(
  key: ValueKey('${business.type}-${business.id}'), // ✅ ریست state وقتی بیزنس عوض میشه
  data: business,
  onClose: appState.closeBusinessDetails,

  // ✅ فقط Vet حق دارد appointment باز کند
  onOpenAppointment: business.type == BusinessType.vet
      ? () {
          appState.closeBusinessDetails();
          appState.openBusinessAppointment(business);
        }
      : null,

  // ✅ CALL
  onCall: (business.phone == null || business.phone!.trim().isEmpty)
      ? null
      : () async {
          String phone = business.phone!.trim();
          phone = phone.replaceAll(' ', '').replaceAll('-', '');

          final uri = Uri(scheme: 'tel', path: phone);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          }
        },

  // ✅ WHATSAPP (TR normalize)
  onWhatsApp: (business.whatsapp == null || business.whatsapp!.trim().isEmpty)
      ? null
      : () async {
          String raw = business.whatsapp!.trim();

          // remove spaces, dashes, parentheses
          raw = raw
              .replaceAll(' ', '')
              .replaceAll('-', '')
              .replaceAll('(', '')
              .replaceAll(')', '');

          // remove leading +
          if (raw.startsWith('+')) raw = raw.substring(1);

          // ✅ اگر با 0 شروع شد، ترکیه: 0xxx... -> 90xxx...
          if (raw.startsWith('0')) {
            raw = '90${raw.substring(1)}';
          }

          // ✅ اگر 10 رقم بود (مثلاً 5466577827)، فرض کن ترکیه است
          if (raw.length == 10) {
            raw = '90$raw';
          }

          final uri = Uri.parse('https://wa.me/$raw');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },

  // ✅ DIRECTIONS
  onDirections: (business.address.trim().isEmpty && business.city.trim().isEmpty)
      ? null
      : () async {
          final query =
              Uri.encodeComponent('${business.address}, ${business.city}'.trim());
          final uri = Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$query',
          );

          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
);
  },
),
            // ─────────────────────────────
            // 🔔 Notifications Overlay
            // ─────────────────────────────
            Builder(
              builder: (context) {
                final overlay =
                    context.select<AppState, HomeOverlay>(
                        (s) => s.homeOverlay);

                if (overlay !=
                    HomeOverlay.notifications) {
                  return const SizedBox.shrink();
                }

                final appState =
                    context.read<AppState>();

                return Positioned.fill(
                  child: GestureDetector(
                    behavior:
                        HitTestBehavior.opaque,
                    onTap:
                        appState.closeNotifications,
                    child: Material(
                      color: Colors.black
                          .withOpacity(0.35),
                      child: SafeArea(
                        child: Align(
                          alignment:
                              Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () {},
                            child: Container(
                              margin:
                                  const EdgeInsets
                                      .all(16),
                              padding:
                                  const EdgeInsets
                                      .all(16),
                              decoration:
                                  BoxDecoration(
                                color:
                                    Colors.white,
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                            20),
                              ),
                              child: SizedBox(
                                height: MediaQuery.of(
                                            context)
                                        .size
                                        .height *
                                    0.72,
                                width: double.infinity,
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          icon:
                                              const Icon(
                                                  Icons
                                                      .close),
                                          onPressed:
                                              appState
                                                  .closeNotifications,
                                        ),
                                        const SizedBox(
                                            width:
                                                6),
                                        const Expanded(
                                          child: Text(
                                            'Notifications',
                                            style:
                                                TextStyle(
                                              fontSize:
                                                  18,
                                              fontWeight:
                                                  FontWeight
                                                      .w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                        height: 8),
                                    Expanded(
                                      child:
                                          NotificationsPage(
                                        currentUserId:
                                            widget
                                                .currentUserId,
                                        onNotificationSelected:
                                            (payload) {
                                          appState
                                              .closeNotifications();
                                          Future
                                              .microtask(
                                                  () {
                                            appState
                                                .handleNotificationTap(
                                                    payload);
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ─────────────────────────────
            // 🐶 Edit Dog Overlay
            // ─────────────────────────────
            Builder(
              builder: (context) {
                final Dog? editingDog =
                    context.select<AppState,
                        Dog?>(
                  (s) => s.editingDog,
                );

                if (editingDog == null) {
                  return const SizedBox.shrink();
                }

                final appState =
                    context.read<AppState>();

                return Positioned.fill(
                  child: EditDogOverlay(
                    dog: editingDog,
                    onClose:
                        appState.closeEditDog,
                  ),
                );
              },
            ),
            // ─────────────────────────────
// 🐶 Playmate Profile Overlay (GLOBAL)
// ─────────────────────────────
Builder(
  builder: (context) {
    final String? targetUserId =
        context.select<AppState, String?>(
      (s) => s.playmateProfileUserId,
    );

    if (targetUserId == null) {
      return const SizedBox.shrink();
    }

    final appState = context.read<AppState>();

    final userDogs = appState.allDogs
        .where((d) => d.ownerId == targetUserId)
        .toList();

    return Positioned.fill(
      child: Stack(
        children: [
          // 🔲 Dim background
          GestureDetector(
            onTap: appState.closePlaymateProfile,
            child: Container(
              color: Colors.black54,
            ),
          ),

          // 🐶 Center Card
          Center(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF9E1B4F),
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                          ),
                          onPressed:
                              appState.closePlaymateProfile,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Dogs of this User",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (userDogs.isEmpty)
                      const Text(
                        "No dogs found",
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      )
                    else
                      ...userDogs.map(
                        (dog) => Padding(
                          padding:
                              const EdgeInsets.only(
                                  bottom: 14),
                          child: DogCard(
                            dog: dog,
                            mode:
                                DogCardMode.playdate,
                            allDogs:
                                appState.allDogs,
                            currentUserId:
                                appState
                                        .currentUserId ??
                                    '',
                            favoriteDogs:
                                appState.favoriteDogs,
                            onToggleFavorite:
                                appState
                                    .toggleFavorite,
                            likers:
                                appState.dogLikes[
                                        dog.id] ??
                                    [],
                            enableEdit: false,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  },
),
          ],
        ),
      ),

      bottomNavigationBar: BarkyBottomNav(
        currentTab: widget.currentTab,
      ),
    );
  }

  String _titleForTab(NavTab tab) {
    switch (tab) {
      case NavTab.home:
        return 'HOME';
      case NavTab.favorites:
        return 'FAVORITES';
      case NavTab.vet:
        return 'VET';
      case NavTab.playdate:
        return 'PLAYDATES';
      case NavTab.profile:
        return 'PROFILE';
      case NavTab.dogParks:
        return 'DOG PARKS';
      case NavTab.playmates:
        return 'PLAYMATES';
      case NavTab.adoption:
        return 'ADOPTION';
      case NavTab.reportLost:
        return 'REPORT LOST';
      case NavTab.lostDogs:
        return 'LOST DOGS';
      case NavTab.foundDogs:
        return 'FOUND DOGS';
      case NavTab.none:
        return '';
      case NavTab.reportFound:
        return 'REPORT FOUND';
        case NavTab.playdateScheduling:
  return 'PLAY SCHEDULE';
    }
  }
}