import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../dog.dart';
import '../../app_state.dart';

import 'barky_app_bar.dart';
import 'barky_drawer.dart';
import 'barky_bottom_nav.dart';
import 'nav_tab.dart';

import 'package:barky_matches_fixed/notifications_page.dart';
import 'package:barky_matches_fixed/dog_card.dart';
import 'package:barky_matches_fixed/edit_dog_overlay.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/upgrade_page.dart';
import 'package:barky_matches_fixed/ui/business/business_card_data.dart';
import 'package:barky_matches_fixed/ui/business/business_detail_overlay.dart';
import 'package:barky_matches_fixed/ui/business/groomy/groomy_details_overlay.dart';
import 'package:barky_matches_fixed/ui/business/pet_hotel/pet_hotel_details_overlay.dart';
import 'package:flutter/rendering.dart';

import 'package:barky_matches_fixed/ui/chat/chat_list_page.dart';
import 'package:barky_matches_fixed/ui/business/adoption_center/adoption_center_details_overlay.dart';
import 'package:barky_matches_fixed/social/services/follow_service.dart';
import 'package:barky_matches_fixed/social/pages/followers_list_page.dart';
import 'package:barky_matches_fixed/social/pages/following_list_page.dart';
import 'package:barky_matches_fixed/social/widgets/petplore_profile_overlay_v2.dart';

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
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  VoidCallback? _callAction(BusinessCardData business) {
    if (business.phone == null || business.phone!.trim().isEmpty) return null;

    return () async {
      String phone = business.phone!.trim();
      phone = phone.replaceAll(' ', '').replaceAll('-', '');

      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    };
  }

  VoidCallback? _whatsAppAction(BusinessCardData business) {
    if (business.whatsapp == null || business.whatsapp!.trim().isEmpty) {
      return null;
    }

    return () async {
      String raw = business.whatsapp!.trim();
      raw = raw
          .replaceAll(' ', '')
          .replaceAll('-', '')
          .replaceAll('(', '')
          .replaceAll(')', '');

      if (raw.startsWith('+')) raw = raw.substring(1);
      if (raw.startsWith('0')) raw = '90${raw.substring(1)}';
      if (raw.length == 10) raw = '90$raw';

      final uri = Uri.parse('https://wa.me/$raw');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    };
  }

  VoidCallback? _directionsAction(BusinessCardData business) {
    if (business.address.trim().isEmpty && business.city.trim().isEmpty) {
      return null;
    }

    return () async {
      final query = Uri.encodeComponent(
        '${business.address}, ${business.city}'.trim(),
      );
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$query',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final showUpgradePage = context.select<AppState, bool>(
      (s) => s.showUpgradePage,
    );

    return PopScope(
      canPop: !showUpgradePage,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !showUpgradePage) return;
        context.read<AppState>().closeUpgradePage();
      },
      child: Scaffold(
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
          currentUserId: widget.currentUserId,
          unreadNotifications: widget.unreadNotifications,
          onMenuTap: () {
            scaffoldKey.currentState?.openDrawer();
          },
          onChatTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatListPage()),
            );
          },
          onNotificationTap: widget.onNotificationTap,
        ),

        // ─────────────────────────────
        // 📄 Body
        // ─────────────────────────────
        body: SafeArea(
          bottom: false,
          child: NotificationListener<UserScrollNotification>(
            onNotification: (notification) {
              final appState = context.read<AppState>();

              if (notification.direction == ScrollDirection.reverse) {
                appState.setBottomNavVisibility(false);
              }

              if (notification.direction == ScrollDirection.forward) {
                appState.setBottomNavVisibility(true);
              }

              return false;
            },

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
                    final business = context
                        .select<AppState, BusinessCardData?>(
                          (s) => s.activeBusiness,
                        );

                    if (business == null) return const SizedBox.shrink();

                    if (business.status != 'approved') {
                      return const SizedBox.shrink(); // یا Pending UI
                    }

                    final appState = context.read<AppState>();
                    final onCall = _callAction(business);
                    final onWhatsApp = _whatsAppAction(business);
                    final onDirections = _directionsAction(business);

                    if (business.type == BusinessType.groomer) {
                      debugPrint(
                        'GROOMY DETAIL OPEN id=${business.id} name=${business.name}',
                      );
                      return GroomyDetailsOverlay(
                        key: ValueKey('${business.type}-${business.id}'),
                        data: business,
                        onClose: appState.closeBusinessDetails,
                        onOpenAppointment: (service) {
                          appState.closeBusinessDetails();
                          appState.openBusinessAppointment(
                            business,
                            selectedService: service,
                          );
                        },
                        onCall: onCall,
                        onWhatsApp: onWhatsApp,
                        onDirections: onDirections,
                      );
                    }
                    if (business.type == BusinessType.adoptionCenter) {
                      debugPrint(
                        'ADOPTION CENTER DETAIL OPEN id=${business.id} name=${business.name}',
                      );

                      return AdoptionCenterDetailsOverlay(
                        key: ValueKey('${business.type}-${business.id}'),

                        data: business,

                        onClose: appState.closeBusinessDetails,

                        onOpenPet: (pet) {
                          debugPrint('OPEN ADOPTION PET => ${pet['title']}');
                        },

                        onCall: onCall,

                        onWhatsApp: onWhatsApp,

                        onDirections: onDirections,
                      );
                    }
                    if (business.type == BusinessType.petHotel) {
                      debugPrint(
                        'PET HOTEL DETAIL OPEN id=${business.id} name=${business.name}',
                      );
                      return PetHotelDetailsOverlay(
                        key: ValueKey('${business.type}-${business.id}'),
                        data: business,
                        onClose: appState.closeBusinessDetails,
                        onOpenBooking: (service) {
                          appState.closeBusinessDetails();
                          appState.openBusinessAppointment(
                            business,
                            selectedService: service,
                          );
                        },
                        onCall: onCall,
                        onWhatsApp: onWhatsApp,
                        onDirections: onDirections,
                      );
                    }

                    return BusinessDetailOverlay(
                      key: ValueKey(
                        '${business.type}-${business.id}',
                      ), // ✅ ریست state وقتی بیزنس عوض میشه
                      data: business,
                      onClose: appState.closeBusinessDetails,

                      // ✅ فقط Vet حق دارد appointment باز کند
                      onOpenAppointment:
                          business.type == BusinessType.vet ||
                              business.type == BusinessType.petHotel
                          ? () {
                              debugPrint(
                                '🔥 OPEN APPOINTMENT type=${business.type}',
                              );

                              appState.closeBusinessDetails();

                              appState.openBusinessAppointment(business);
                            }
                          : null,

                      // ✅ CALL
                      onCall: onCall,

                      // ✅ WHATSAPP (TR normalize)
                      onWhatsApp: onWhatsApp,

                      // ✅ DIRECTIONS
                      onDirections: onDirections,
                    );
                  },
                ),
                // ─────────────────────────────
                // 🔔 Notifications Overlay
                // ─────────────────────────────
                Builder(
                  builder: (context) {
                    final overlay = context.select<AppState, HomeOverlay>(
                      (s) => s.homeOverlay,
                    );

                    if (overlay != HomeOverlay.notifications) {
                      return const SizedBox.shrink();
                    }

                    final appState = context.read<AppState>();

                    return Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: appState.closeNotifications,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: SafeArea(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: GestureDetector(
                                onTap: () {},
                                child: Container(
                                  margin: const EdgeInsets.all(16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.72,
                                    width: double.infinity,
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed:
                                                  appState.closeNotifications,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.notifications,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: NotificationsPage(
                                            currentUserId: widget.currentUserId,
                                            onNotificationSelected: (payload) {
                                              appState.closeNotifications();
                                              Future.microtask(() {
                                                appState.handleNotificationTap(
                                                  payload,
                                                );
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
                    final Dog? editingDog = context.select<AppState, Dog?>(
                      (s) => s.editingDog,
                    );

                    if (editingDog == null) {
                      return const SizedBox.shrink();
                    }

                    final appState = context.read<AppState>();

                    return Positioned.fill(
                      child: EditDogOverlay(
                        dog: editingDog,
                        onClose: appState.closeEditDog,
                      ),
                    );
                  },
                ),
                // ─────────────────────────────
                // 🐾 Petplore Profile Overlay V2 (GLOBAL)
                // ─────────────────────────────
                Builder(
                  builder: (context) {
                    final targetUserId = context.select<AppState, String?>(
                      (s) => s.petploreProfileUserId,
                    );

                    if (targetUserId == null) {
                      return const SizedBox.shrink();
                    }

                    final appState = context.read<AppState>();

                    return Positioned.fill(
                      child: PetploreProfileOverlayV2(
                        userId: targetUserId,
                        dogs: appState.allDogs,
                      ),
                    );
                  },
                ),
                // ─────────────────────────────
                // 🐶 Playmate Profile Overlay (GLOBAL)
                // ─────────────────────────────
                Builder(
                  builder: (context) {
                    final String? targetUserId = context
                        .select<AppState, String?>(
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
                            child: Container(color: Colors.black54),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                        Expanded(
                                          child: Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.dogsOfThisUser,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        if (targetUserId !=
                                            appState.currentUserId) ...[
                                          const SizedBox(width: 10),
                                          _PlaymateFollowButton(
                                            targetUserId: targetUserId,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _PlaymateFollowStatsRow(
                                      targetUserId: targetUserId,
                                    ),
                                    const SizedBox(height: 16),
                                    if (userDogs.isEmpty)
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.noDogsFound,
                                        style: TextStyle(color: Colors.white70),
                                      )
                                    else
                                      ...userDogs.map(
                                        (dog) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 14,
                                          ),
                                          child: DogCard(
                                            dog: dog,
                                            mode: DogCardMode.playdate,
                                            allDogs: appState.allDogs,
                                            currentUserId:
                                                appState.currentUserId ?? '',
                                            favoriteDogs: appState.favoriteDogs,
                                            onToggleFavorite:
                                                appState.toggleFavorite,
                                            likers:
                                                appState.dogLikes[dog.id] ?? [],
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

                // ─────────────────────────────
                // ⭐ Upgrade Overlay (GLOBAL)
                // ─────────────────────────────
                Builder(
                  builder: (context) {
                    final isOpen = context.select<AppState, bool>(
                      (s) => s.showUpgradePage,
                    );

                    if (!isOpen) return const SizedBox.shrink();

                    final appState = context.read<AppState>();

                    return Positioned.fill(
                      child: Material(
                        color: const Color(0xFF120914),
                        child: Stack(
                          children: [
                            const UpgradePage(),
                            SafeArea(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                    onPressed: appState.closeUpgradePage,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        bottomNavigationBar: BarkyBottomNav(currentTab: widget.currentTab),
      ),
    );
  }

  String _titleForTab(NavTab tab) {
    switch (tab) {
      case NavTab.home:
        return AppLocalizations.of(context)!.homeNavItem;
      case NavTab.favorites:
        return AppLocalizations.of(context)!.favoritesNavItem;
      case NavTab.vet:
        return AppLocalizations.of(context)!.vetTitle;
      case NavTab.groomy:
        return AppLocalizations.of(context)!.groomyTitle;
      case NavTab.petHotel:
        return AppLocalizations.of(context)!.homePetHotelTitle;
      case NavTab.petTaxi:
        return AppLocalizations.of(context)!.homePetTaxiTitle;
      case NavTab.petplore:
        return 'Petplore';
      case NavTab.playdate:
        return AppLocalizations.of(context)!.playdatesTitle;
      case NavTab.profile:
        return AppLocalizations.of(context)!.profileNavItem;
      case NavTab.dogParks:
        return AppLocalizations.of(context)!.dogParkTitle;
      case NavTab.greenMemorial:
        return AppLocalizations.of(context)!.homeGreenMemorialTitle;
      case NavTab.playmates:
        return AppLocalizations.of(context)!.findPlaymates;

      case NavTab.adoption:
        return AppLocalizations.of(context)!.adoptionTitle;
      case NavTab.reportLost:
        return AppLocalizations.of(context)!.reportLostDogMenuItem;
      case NavTab.lostDogs:
        return AppLocalizations.of(context)!.lostPetTitle;
      case NavTab.foundDogs:
        return AppLocalizations.of(context)!.foundPetTitle;
      case NavTab.none:
        return '';
      case NavTab.reportFound:
        return AppLocalizations.of(context)!.reportFoundDogMenuItem;
      case NavTab.playdateScheduling:
        return AppLocalizations.of(context)!.schedulePlayDate;
    }
  }
}

class _PlaymateFollowButton extends StatelessWidget {
  final String targetUserId;

  const _PlaymateFollowButton({required this.targetUserId});

  @override
  Widget build(BuildContext context) {
    final followService = FollowService();

    return StreamBuilder<bool>(
      stream: followService.isFollowing(targetUserId),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              if (isFollowing) {
                await followService.unfollowUser(targetUserId: targetUserId);
              } else {
                await followService.followUser(targetUserId: targetUserId);
              }
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isFollowing
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isFollowing ? Colors.white24 : Colors.transparent,
                ),
              ),
              child: Text(
                isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  color: isFollowing ? Colors.white : const Color(0xFF9E1B4F),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaymateFollowStatsRow extends StatelessWidget {
  final String targetUserId;

  const _PlaymateFollowStatsRow({required this.targetUserId});

  @override
  Widget build(BuildContext context) {
    final followService = FollowService();

    return Row(
      children: [
        StreamBuilder<int>(
          stream: followService.followersCountStream(targetUserId),
          builder: (context, snapshot) {
            return _FollowStatChip(
              count: snapshot.data ?? 0,
              label: 'Followers',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FollowersListPage(userId: targetUserId),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(width: 10),
        StreamBuilder<int>(
          stream: followService.followingCountStream(targetUserId),
          builder: (context, snapshot) {
            return _FollowStatChip(
              count: snapshot.data ?? 0,
              label: 'Following',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FollowingListPage(userId: targetUserId),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _FollowStatChip extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback onTap;

  const _FollowStatChip({
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
