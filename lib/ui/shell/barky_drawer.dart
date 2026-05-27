import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../dog.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:barky_matches_fixed/welcome_page.dart';
import 'package:barky_matches_fixed/debug/auth_trap.dart';


import 'package:barky_matches_fixed/ui/support/about_us_page.dart';
import 'package:barky_matches_fixed/ui/legal/privacy_policy_page.dart';
import 'package:barky_matches_fixed/ui/legal/terms_page.dart';

class BarkyDrawer extends StatelessWidget {
  final String currentUserId;
  final List<Dog> dogs;
  final List<Dog> favoriteDogs;
  final void Function(Dog) onToggleFavorite;

  const BarkyDrawer({
    super.key,
    required this.currentUserId,
    required this.dogs,
    required this.favoriteDogs,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 260,
      child: Container(
        color: const Color(0xFFF5F5F5),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [

            /// 🔴 HEADER
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF9E1B4F), Color(0xFFD81B60)],
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'PetSupo',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            /// 🟣 MAIN
            _sectionTitle("Main"),

            _tile(
              context,
              LucideIcons.home,
              "Playmate",
              onTap: () {
                context.read<AppState>().setCurrentTab(NavTab.playmates);
              },
            ),

            const Divider(height: 32),

            /// 🟣 SUPPORT
            _sectionTitle("Support"),

_tile(
  context,
  LucideIcons.messageSquare,
  "Send Feedback",
  onTap: () {

    final appState =
        context.read<AppState>();

    appState.setCurrentTab(
      NavTab.profile,
    );

    appState.openProfileSubPage(
      ProfileSubPage.feedback,
    );
  },
),

_tile(
  context,
  LucideIcons.bug,
  "Report Problem",
  onTap: () {

    final appState =
        context.read<AppState>();

    appState.setCurrentTab(
      NavTab.profile,
    );

    appState.openProfileSubPage(
      ProfileSubPage.reportProblem,
    );
  },
),

_tile(
  context,
  LucideIcons.helpCircle,
  "FAQ",
  onTap: () {

    final appState =
        context.read<AppState>();

    appState.setCurrentTab(
      NavTab.profile,
    );

    appState.openProfileSubPage(
      ProfileSubPage.faq,
    );
  },
),

const Divider(height: 32),

_sectionTitle("Legal"),

_tile(
  context,
  LucideIcons.shield,
  "Privacy Policy",
  onTap: () {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
    );
  },
),

_tile(
  context,
  LucideIcons.fileText,
  "Terms of Service",
  onTap: () {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const TermsPage()),
    );
  },
),

_tile(
  context,
  LucideIcons.info,
  "About Us",
  onTap: () {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const AboutUsPage()),
    );
  },
),

            const Divider(height: 32),

            /// 🔴 LOGOUT
            _tile(
              context,
              LucideIcons.logOut,
              "Logout",
              isDestructive: true,
              onTap: () async {
                await AuthTrap.signOut(reason: 'drawer_logout');

                if (!context.mounted) return;

                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomePage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 🧩 TILE
  Widget _tile(
    BuildContext context,
    IconData icon,
    String title, {
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return Builder(
      builder: (innerContext) {
        return ListTile(
          leading: Icon(
            icon,
            size: 20,
            color: isDestructive ? Colors.red : const Color(0xFF9E1B4F),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDestructive ? Colors.red : const Color(0xFF333333),
            ),
          ),
          onTap: () async {
            Navigator.pop(innerContext); // 👈 فقط بستن drawer

            await Future.delayed(const Duration(milliseconds: 200));

            if (!innerContext.mounted) return;

            onTap?.call(); // 👈 فقط state تغییر می‌ده
          },
        );
      },
    );
  }

  /// 🧩 SECTION TITLE
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _FaqCard extends StatefulWidget {

  final String question;
  final String answer;

  const _FaqCard({
    required this.question,
    required this.answer,
  });

  @override
  State<_FaqCard> createState() =>
      _FaqCardState();
}

class _FaqCardState
    extends State<_FaqCard> {

  bool expanded = false;

  @override
  Widget build(BuildContext context) {

    return InkWell(
      borderRadius:
          BorderRadius.circular(24),

      onTap: () {
        setState(() {
          expanded = !expanded;
        });
      },

      child: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            Row(
              children: [

                Container(
                  width: 44,
                  height: 44,

                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF9E1B4F,
                    ).withOpacity(.10),

                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),

                  child: const Icon(
                    LucideIcons.helpCircle,
                    color:
                        Color(0xFF9E1B4F),
                    size: 22,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Text(
                    widget.question,

                    style:
                        GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w700,

                      color: const Color(
                        0xFF9E1B4F,
                      ),
                    ),
                  ),
                ),

                AnimatedRotation(
                  turns:
                      expanded ? 0.5 : 0,

                  duration:
                      const Duration(
                    milliseconds: 220,
                  ),

                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color:
                        Color(0xFF9E1B4F),
                    size: 28,
                  ),
                ),
              ],
            ),

            AnimatedCrossFade(
              firstChild:
                  const SizedBox.shrink(),

              secondChild: Padding(
                padding:
                    const EdgeInsets.only(
                  top: 18,
                ),

                child: Text(
                  widget.answer,

                  style:
                      GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.6,
                  ),
                ),
              ),

              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,

              duration: const Duration(
                milliseconds: 220,
              ),
            ),
          ],
        ),
      ),
    );
  }
}