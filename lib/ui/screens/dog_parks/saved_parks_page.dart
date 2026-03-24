import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';


class SavedParksPage extends StatelessWidget {
  const SavedParksPage({super.key});

  static const Color _cardColor = Color(0xFF9E1B4F); // زرشکی
  static const Color _bgColor = Color(0xFFFFF6F8); // صورتی خیلی روشن

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final savedParks = appState.favoriteParks;
    final bool isGoldOrPremium = appState.isPremium;

    return Material(
      color: _bgColor,
      child: Column(
        children: [
          // ─────────────────────────────
          // 🔙 HEADER (Back to Profile)
          // ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    context.read<AppState>().closeProfileSubPage();
                  },
                ),
                Text(
                  'Saved Parks',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ─────────────────────────────
          // 📄 BODY
          // ─────────────────────────────
          Expanded(
            child: savedParks.isEmpty
                ? Center(
                    child: Text(
                      'No saved parks yet',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: savedParks.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final park = savedParks[index];

                      final String parkName =
                          park['name'] ?? 'Unknown park';
                      final bool premiumOnly =
                          park['premiumOnly'] == true;
                      final bool canSchedule =
                          isGoldOrPremium || !premiumOnly;

                      return InkWell(
  borderRadius: BorderRadius.circular(16),
  onTap: canSchedule
    ? () {
      debugPrint('🟢 SavedPark tapped: ${park['name']}');
        final appState = context.read<AppState>();

        // 1️⃣ فقط state
        appState.startPlaydateAtPark(park);

        // 2️⃣ فقط tab (نه Navigator)
        WidgetsBinding.instance.addPostFrameCallback((_) {
           debugPrint('🟡 Switching tab to PLAYDATE');
          if (!context.mounted) return;

          appState.closeProfileSubPage();
          appState.setCurrentTab(NavTab.playdate);
        });
      }
    : null,


                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.park,
                                color: Colors.greenAccent,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      parkName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      canSchedule
                                          ? 'Available for playdate'
                                          : 'Gold / Premium required',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: canSchedule
                                            ? Colors.white70
                                            : Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              canSchedule
                                  ? const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : const Icon(
                                      Icons.lock,
                                      color: Colors.white70,
                                    ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
