import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/lost_dog.dart';
import 'lost_dog_detail_page.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ui/shell/nav_tab.dart';
import 'package:barky_matches_fixed/ui/common/smart_media.dart';

class LostDogsListPage extends StatefulWidget {
  const LostDogsListPage({super.key});

  @override
  State<LostDogsListPage> createState() => _LostDogsListPageState();
}

class _LostDogsListPageState extends State<LostDogsListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Position? _currentPosition;
  String? _notificationLostDogId;
  Stream<QuerySnapshot>? _lostDogsStream;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  /*
Future<void> _openLostDogFromNotification(String dogId) async {
  final doc = await _firestore
      .collection('lost_pets')
      .doc(dogId)
      .get();

  if (!doc.exists || doc.data() == null) return;

  final lostDog = LostDog.fromMap(
    doc.data() as Map<String, dynamic>,
  ).copyWith(id: doc.id);

  if (!mounted) return;

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => LostDogDetailPage(
        lostDog: lostDog,
      ),
    ),
  );
}

*/
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (_) {}
  }

  double _calculateDistance(double lat, double lng) {
    if (_currentPosition == null) return 0;

    return Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        ) /
        1000; // km
  }

  Future<void> _updateFoundStatus(
    String docId,
    String reportedBy,
    bool isFound,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != reportedBy) {
      return;
    }

    try {
      await _firestore.collection('lost_pets').doc(docId).update({
        'isFound': isFound,
      });

      if (isFound) {
        await _sendFoundNotification(docId);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LostDogsListPage error: $e');
      }
    }
  }

  Future<void> _sendFoundNotification(String lostDogId) async {
    debugPrint("🚀 _sendFoundNotification HTTP START");

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        debugPrint("❌ USER NULL — aborting");
        return;
      }

      final idToken = await user.getIdToken(false);

      if (idToken == null) {
        debugPrint("❌ ID TOKEN NULL");
        return;
      }

      debugPrint("🔐 ID TOKEN OK");

      // 🔥 HTTP endpoint (region-safe)
      final uri = Uri.parse(
        "https://europe-west3-barkymatches-new.cloudfunctions.net/sendLostFoundNotificationHttp",
      );

      // 🐶 Fetch dog info first (مثل قبل)
      final snapshot = await _firestore
          .collection('lost_pets')
          .doc(lostDogId)
          .get();

      if (!snapshot.exists) {
        debugPrint("❌ lost_pets doc not found");
        return;
      }

      final lostDog = LostDog.fromMap(
        snapshot.data() as Map<String, dynamic>,
      ).copyWith(id: lostDogId);

      final bodyData = {
        "title": "Lost Pet Found! 🐾",
        "body":
            "${lostDog.name} (${lostDog.breed}) has been found near ${lostDog.latitude}, ${lostDog.longitude}",
        "lostDogId": lostDogId,
      };

      debugPrint("📡 Sending HTTP request...");

      final response = await http
          .post(
            uri,
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $idToken",
            },
            body: jsonEncode(bodyData),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("📥 HTTP Status: ${response.statusCode}");
      debugPrint("📥 HTTP Body: ${response.body}");

      if (response.statusCode != 200) {
        debugPrint("❌ HTTP ERROR");
        return;
      }

      final decoded = jsonDecode(response.body);

      if (decoded["success"] == true) {
        debugPrint("✅ Lost/Found notification sent successfully");
      } else {
        debugPrint("⚠️ Server responded but success=false");
      }
    } catch (e, stack) {
      debugPrint("💥 _sendFoundNotification ERROR");
      debugPrint('$e');
      debugPrint('$stack');
    }

    debugPrint("🏁 _sendFoundNotification HTTP END");
  }

  Widget _pinkChip(String label, String? value) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white, // ✅ سفید مثل Playmate
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF9E1B4F).withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        "$label: $value",
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF9E1B4F),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final activeLostDogId = appState.activeLostDogId;
    final currentTab = appState.currentTab;

    if (currentTab != NavTab.lostDogs && _searchQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _searchQuery = '';
          });
          _searchController.clear();
        }
      });
    }

    // 🔥 DETAIL MODE — منطق دست نخورده
    if (activeLostDogId != null) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('lost_pets')
            .doc(activeLostDogId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final dog = LostDog.fromMap(data).copyWith(id: snapshot.data!.id);

          return LostDogDetailPage(lostDog: dog);
        },
      );
    }

    // 🔥 LIST MODE
    return Container(
      color: AppTheme.bg,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),

            // 🔹 HEADER — Playmate style
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Lost Pets",
                        style: AppTheme.h1().copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: const Color(0xFF9E1B4F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Help lost pets find their way home",
                        style: AppTheme.caption().copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 🔎 SEARCH BAR — Playmate style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: AppTheme.body(),
                        decoration: InputDecoration(
                          hintText: "Search by name...",
                          hintStyle: AppTheme.body(color: Colors.grey.shade500),
                          border: InputBorder.none,
                          isCollapsed: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 📋 LIST — منطق Stream دست نخورده
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('lost_pets')
                    .orderBy('reportedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    );
                  }

                  final lostDogs = snapshot.data!.docs
                      .map((doc) {
                        return LostDog.fromMap(
                          doc.data() as Map<String, dynamic>,
                        ).copyWith(id: doc.id);
                      })
                      .where(
                        (dog) => dog.name.toLowerCase().contains(_searchQuery),
                      )
                      .toList();

                  if (lostDogs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pets,
                            size: 56,
                            color: const Color(0xFF9E1B4F).withOpacity(0.4),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "No lost pets reported yet",
                            style: AppTheme.h2().copyWith(
                              color: const Color(0xFF9E1B4F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Reported lost pets will appear here",
                            style: AppTheme.caption().copyWith(
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: lostDogs.length,
                    itemBuilder: (context, index) {
                      final dog = lostDogs[index];
                      final user = FirebaseAuth.instance.currentUser;
                      final isOwner = user?.uid == dog.reportedBy;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            context.read<AppState>().openLostDogDetail(dog.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white, // ✅ دقیق مثل Playmate
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: AppTheme.cardShadow(opacity: 0.05),
                            ),
                            child: Row(
                              children: [
                                // 🐶 IMAGE
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child:
                                      dog.imageUrl != null &&
                                          dog.imageUrl!.isNotEmpty
                                      ? SmartMedia(
                                          url: dog.imageUrl!,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          height: 64,
                                          width: 64,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF9E1B4F,
                                              ).withOpacity(0.08),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.pets,
                                            color: Color(0xFF9E1B4F),
                                          ),
                                        ),
                                ),

                                const SizedBox(width: 14),

                                // 🧠 INFO
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dog.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.h3().copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF9E1B4F),
                                        ),
                                      ),

                                      const SizedBox(height: 4),

                                      Text(
                                        dog.breed,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTheme.body(
                                          color: AppTheme.muted,
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _pinkChip("Gender", dog.gender),
                                          _pinkChip("Health", dog.healthStatus),
                                          _pinkChip("Color", dog.color),
                                          if (dog.weight != null)
                                            _pinkChip(
                                              "Weight",
                                              "${dog.weight} kg",
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // 🟡 STATUS + OWNER SWITCH
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: dog.isFound
                                            ? Colors.green.withOpacity(0.15)
                                            : Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        dog.isFound ? "Found" : "Missing",
                                        style: AppTheme.caption(
                                          color: dog.isFound
                                              ? Colors.green
                                              : Colors.orange,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),

                                    if (isOwner)
                                      Switch(
                                        value: dog.isFound,
                                        activeThumbColor: AppTheme.accent,
                                        onChanged: (value) {
                                          _updateFoundStatus(
                                            dog.id,
                                            dog.reportedBy,
                                            value,
                                          );
                                        },
                                      ),
                                  ],
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
