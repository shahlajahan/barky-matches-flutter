import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/found_dog.dart';
import 'found_dog_detail_page.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../theme/app_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../ui/shell/nav_tab.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


class FoundDogsListPage extends StatefulWidget {
  const FoundDogsListPage({super.key});

  @override
  _FoundDogsListPageState createState() => _FoundDogsListPageState();
}

class _FoundDogsListPageState extends State<FoundDogsListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
Position? _currentPosition;
String _searchQuery = '';
final TextEditingController _searchController = TextEditingController();

@override
void initState() {
  super.initState();
  _getCurrentLocation();
}

@override
void dispose() {
  _searchController.dispose();
  super.dispose();
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

  Future<void> _updateClaimedStatus(String docId, String reportedBy, bool isClaimed) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid != reportedBy) return;

    try {
      await _firestore.collection('found_dogs').doc(docId).update({'isClaimed': isClaimed});
      if (kDebugMode) print('FoundDogsListPage - Updated status for docId: $docId to isClaimed: $isClaimed');

      if (isClaimed) {
        await _sendClaimedNotification(docId);
      }
    } catch (e) {
      if (kDebugMode) print('FoundDogsListPage - Error updating status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e', style: GoogleFonts.poppins(color: const Color(0xFFFFC107)))),
      );
    }
  }

  Future<void> _sendClaimedNotification(String foundDogId) async {
  print("🚀 _sendClaimedNotification HTTP START");

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final idToken = await user.getIdToken(false);

    final uri = Uri.parse(
      "https://europe-west3-barkymatches-new.cloudfunctions.net/sendLostFoundNotificationHttp",
    );

    final snapshot = await _firestore
        .collection('found_dogs')
        .doc(foundDogId)
        .get();

    if (!snapshot.exists) return;

    final foundDog = FoundDog.fromMap(
      snapshot.data() as Map<String, dynamic>,
    ).copyWith(id: foundDogId);

    final bodyData = {
      "title": "Found Dog Claimed! 🐾",
      "body":
          "${foundDog.name} (${foundDog.breed}) has been claimed near ${foundDog.latitude}, ${foundDog.longitude}",
      "foundDogId": foundDogId,
    };

    final response = await http.post(
      uri,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $idToken",
      },
      body: jsonEncode(bodyData),
    );

    print("📥 HTTP Status: ${response.statusCode}");
    print("📥 HTTP Body: ${response.body}");
  } catch (e) {
    print("💥 _sendClaimedNotification ERROR");
    print(e);
  }

  print("🏁 _sendClaimedNotification HTTP END");
}
  @override
Widget build(BuildContext context) {
  final appState = context.watch<AppState>();
  final activeFoundDogId = appState.activeFoundDogId;
  final currentTab = appState.currentTab;

  if (currentTab != NavTab.foundDogs && _searchQuery.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _searchQuery = '');
        _searchController.clear();
      }
    });
  }

  // 🔥 DETAIL MODE
  if (activeFoundDogId != null) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('found_dogs')
          .doc(activeFoundDogId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final dog = FoundDog.fromMap(
          snapshot.data!.data() as Map<String, dynamic>,
        ).copyWith(id: snapshot.data!.id);

        return FoundDogDetailPage(foundDog: dog);
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text("Found Dogs", style: AppTheme.h1()),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Search by name...",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('found_dogs')
                  .orderBy('reportedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final foundDogs = snapshot.data!.docs
                    .map((doc) => FoundDog.fromMap(
                          doc.data() as Map<String, dynamic>,
                        ).copyWith(id: doc.id))
                    .where((dog) =>
                        dog.name.toLowerCase().contains(_searchQuery))
                    .toList();

                if (foundDogs.isEmpty) {
                  return Center(
                    child: Text(
                      "No found dogs reported yet",
                      style:
                          AppTheme.body(color: AppTheme.muted),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: foundDogs.length,
                  itemBuilder: (context, index) {

                    final dog = foundDogs[index];
                    final user =
                        FirebaseAuth.instance.currentUser;
                    final isOwner =
                        user?.uid == dog.reportedBy;

                    final distance = _calculateDistance(
                        dog.latitude, dog.longitude);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(20),
                        onTap: () {
                          context
                              .read<AppState>()
                              .openFoundDogDetail(dog.id);
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius:
                                BorderRadius.circular(
                                    20),
                            boxShadow:
                                AppTheme.cardShadow(),
                          ),
                          child: Row(
                            children: [

                              // 🐶 IMAGE
                              ClipRRect(
                                borderRadius:
                                    BorderRadius
                                        .circular(14),
                                child: dog.imageUrl !=
                                            null &&
                                        dog.imageUrl!
                                            .isNotEmpty
                                    ? Image.network(
                                        dog.imageUrl!,
                                        height: 64,
                                        width: 64,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        height: 64,
                                        width: 64,
                                        decoration:
                                            BoxDecoration(
                                          color: AppTheme
                                              .muted
                                              .withOpacity(
                                                  0.1),
                                          borderRadius:
                                              BorderRadius
                                                  .circular(
                                                      14),
                                        ),
                                        child: const Icon(
                                          Icons.pets,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),

                              const SizedBox(width: 14),

                              // INFO
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [

                                    Text(dog.name,
                                        style:
                                            AppTheme.h3()),

                                    const SizedBox(
                                        height: 4),

                                    Text(
                                      dog.breed,
                                      style:
                                          AppTheme.body(
                                        color: AppTheme
                                            .muted,
                                      ),
                                    ),

                                    const SizedBox(
                                        height: 8),

                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _pinkChip(
                                            "Color",
                                            dog.color),
                                        if (dog.weight !=
                                            null)
                                          _pinkChip(
                                              "Weight",
                                              "${dog.weight} kg"),
                                        _pinkChip(
                                            "Collar",
                                            dog.collarType),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .end,
                                children: [

                                  Container(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color: dog.isClaimed
                                          ? Colors.green
                                              .withOpacity(
                                                  0.15)
                                          : Colors.orange
                                              .withOpacity(
                                                  0.15),
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                                  50),
                                    ),
                                    child: Text(
                                      dog.isClaimed
                                          ? "Claimed"
                                          : "Open",
                                      style: AppTheme
                                          .caption(
                                        color:
                                            dog.isClaimed
                                                ? Colors
                                                    .green
                                                : Colors
                                                    .orange,
                                      ),
                                    ),
                                  ),

                                  if (isOwner)
                                    Switch(
                                      value:
                                          dog.isClaimed,
                                      activeColor:
                                          AppTheme
                                              .accent,
                                      onChanged:
                                          (value) {
                                        _updateClaimedStatus(
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
Widget _pinkChip(String label, String? value) {
  if (value == null || value.isEmpty) {
    return const SizedBox.shrink();
  }

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 4,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFFFE4EC),
      borderRadius: BorderRadius.circular(20),
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
}