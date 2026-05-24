import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../app_state.dart';
import '../../ui/shell/nav_tab.dart';
import '../../theme/app_theme.dart';

class PetploreSearchOverlay extends StatefulWidget {
  const PetploreSearchOverlay({super.key});

  @override
  State<PetploreSearchOverlay> createState() =>
      _PetploreSearchOverlayState();
}

class _PetploreSearchOverlayState
    extends State<PetploreSearchOverlay> {

  final TextEditingController _controller =
      TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final appState = context.read<AppState>();

    return Material(
      color: AppTheme.bg,

      child: SafeArea(
        bottom: false,

        child: Column(
          children: [

            // ───────────────── HEADER ─────────────────

            Padding(
  padding: const EdgeInsets.fromLTRB(
    18,
    14,
    18,
    12,
  ),

  child: Row(
    children: [

      // BACK

      GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },

        child: Container(
          height: 48,
          width: 48,

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.circular(16),

            border: Border.all(
              color:
                  Colors.black.withOpacity(
                0.05,
              ),
            ),
          ),

          child: const Icon(
            LucideIcons.arrowLeft,
            color: AppTheme.textDark,
            size: 22,
          ),
        ),
      ),

      const SizedBox(width: 14),

      // SEARCH FIELD

      Expanded(
        child: Container(
          height: 52,

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.circular(18),

            border: Border.all(
              color:
                  Colors.black.withOpacity(
                0.05,
              ),
            ),
          ),

          child: TextField(
            controller: _controller,
            autofocus: true,

            style: TextStyle(
              color: AppTheme.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),

            cursorColor:
                const Color(0xFFFF4D8D),

            decoration: InputDecoration(
              border: InputBorder.none,

              hintText:
                  'Search users...',

              hintStyle: TextStyle(
                color: AppTheme.muted,
              ),

              prefixIcon: const Icon(
                LucideIcons.search,
                color: AppTheme.muted,
                size: 20,
              ),

              suffixIcon:
                  _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {

                            _controller.clear();

                            setState(() {
                              _query = '';
                            });
                          },

                          icon: const Icon(
                            LucideIcons.x,
                            color: AppTheme.muted,
                          ),
                        ),
            ),

            onChanged: (value) {
              setState(() {
                _query =
                    value.trim()
                        .toLowerCase();
              });
            },
          ),
        ),
      ),
    ],
  ),
),

            // ───────────────── RESULTS ─────────────────

            Expanded(
              child: _query.isEmpty
                  ? _buildEmptyState()
                  : StreamBuilder<QuerySnapshot>(

                      stream: FirebaseFirestore
                          .instance
                          .collection('users')
                          .where(
                            'username',
                            isGreaterThanOrEqualTo:
                                _query,
                          )
                          .where(
                            'username',
                            isLessThan:
                                '$_query\uf8ff',
                          )
                          .limit(20)
                          .snapshots(),

                      builder:
                          (context, snapshot) {

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {

                          return const Center(
                            child:
                                CircularProgressIndicator(
                              color: Color(
                                0xFFFF4D8D,
                              ),
                            ),
                          );
                        }

                        final docs =
                            snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {

                          return Center(
                            child: Text(
                              'No users found',

                              style: TextStyle(
                                color:
                                    Colors.white
                                        .withOpacity(
                                  0.5,
                                ),

                                fontSize: 15,
                                fontWeight:
                                    FontWeight.w500,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(

                          padding:
                              const EdgeInsets.only(
                            top: 6,
                            bottom: 120,
                          ),

                          itemCount: docs.length,

                          itemBuilder:
                              (context, index) {

                            final data =
                                docs[index].data()
                                    as Map<String,
                                        dynamic>;

                            final userId =
                                docs[index].id;

                            final username =
                                data['username'] ??
                                    'Unknown';

                            final photoUrl =
                                data['photoUrl'];

                            return Material(
                              color: Colors.transparent,

                              child: InkWell(

                                onTap: () {

                                  appState
                                      .setPlaymateProfile(
                                    userId,
                                    appState.allDogs,
                                  );

                                  appState
                                      .setCurrentTab(
                                    NavTab.playmates,
                                  );

                                  Navigator.pop(
                                    context,
                                  );
                                },

                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),

                                  child: Row(
                                    children: [

                                      // AVATAR

                                      CircleAvatar(
                                        radius: 28,

                                        backgroundColor: Colors.white,

                                        backgroundImage:
                                            photoUrl !=
                                                    null
                                                ? NetworkImage(
                                                    photoUrl,
                                                  )
                                                : null,

                                        child: photoUrl ==
                                                null
                                            ? const Icon(
                                                LucideIcons
                                                    .dog,
                                                color: Colors
                                                    .white,
                                              )
                                            : null,
                                      ),

                                      const SizedBox(
                                        width: 14,
                                      ),

                                      // USERNAME

                                      Expanded(
  child: Text(
    username,

    style: TextStyle(
      color: AppTheme.textDark,

      fontSize: 18,

      fontWeight:
          FontWeight.w700,
    ),
  ),
),

                                      Icon(
                                        LucideIcons
                                            .chevronRight,

                                        color: AppTheme.muted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {

    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [

          Icon(
            LucideIcons.search,

            color:
                AppTheme.textDark,

            size: 54,
          ),

          const SizedBox(height: 18),

          Text(
            'Search pets & users',

            style: TextStyle(
              color:
                  AppTheme.textDark,

              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Find pet lovers around you',

            style: TextStyle(
              color:
                 AppTheme.textDark,

              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}