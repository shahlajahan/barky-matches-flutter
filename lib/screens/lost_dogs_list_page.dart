import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/lost_dog.dart';
import 'lost_dog_detail_page.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../ui/shell/nav_tab.dart';



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
      .collection('lost_dogs')
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

  double _calculateDistance(
      double lat, double lng) {
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
      bool isFound) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null ||
        currentUser.uid != reportedBy) return;

    try {
      await _firestore
          .collection('lost_dogs')
          .doc(docId)
          .update({'isFound': isFound});

      if (isFound) {
        await _sendFoundNotification(docId);
      }
    } catch (e) {
      if (kDebugMode) {
        print('LostDogsListPage error: $e');
      }
    }
  }

 Future<void> _sendFoundNotification(String lostDogId) async {
  print("🚀 _sendFoundNotification HTTP START");

  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      print("❌ USER NULL — aborting");
      return;
    }

    final idToken = await user.getIdToken(false);

    if (idToken == null) {
      print("❌ ID TOKEN NULL");
      return;
    }

    print("🔐 ID TOKEN OK");

    // 🔥 HTTP endpoint (region-safe)
    final uri = Uri.parse(
      "https://europe-west3-barkymatches-new.cloudfunctions.net/sendLostFoundNotificationHttp",
    );

    // 🐶 Fetch dog info first (مثل قبل)
    final snapshot = await _firestore
        .collection('lost_dogs')
        .doc(lostDogId)
        .get();

    if (!snapshot.exists) {
      print("❌ lost_dogs doc not found");
      return;
    }

    final lostDog = LostDog.fromMap(
      snapshot.data() as Map<String, dynamic>,
    ).copyWith(id: lostDogId);

    final bodyData = {
      "title": "Lost Dog Found! 🐾",
      "body":
          "${lostDog.name} (${lostDog.breed}) has been found near ${lostDog.latitude}, ${lostDog.longitude}",
      "lostDogId": lostDogId,
    };

    print("📡 Sending HTTP request...");

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

    print("📥 HTTP Status: ${response.statusCode}");
    print("📥 HTTP Body: ${response.body}");

    if (response.statusCode != 200) {
      print("❌ HTTP ERROR");
      return;
    }

    final decoded = jsonDecode(response.body);

    if (decoded["success"] == true) {
      print("✅ Lost/Found notification sent successfully");
    } else {
      print("⚠️ Server responded but success=false");
    }

  } catch (e, stack) {
    print("💥 _sendFoundNotification ERROR");
    print(e);
    print(stack);
  }

  print("🏁 _sendFoundNotification HTTP END");
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
      color: const Color(0xFFFFE4EC), // همون صورتی Playmate
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
      _searchController.clear(); // ← این هم اضافه شد
    }
  });
}

  // 🔥 DETAIL MODE
  if (activeLostDogId != null) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('lost_dogs')
          .doc(activeLostDogId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final data =
            snapshot.data!.data() as Map<String, dynamic>;

        final dog = LostDog.fromMap(data)
            .copyWith(id: snapshot.data!.id);

        return LostDogDetailPage(lostDog: dog);
      },
    );
  }

  // 🔥 LIST MODE
  return Container(
    color: AppTheme.bg, // ✅ مثل Playmate
    child: SafeArea(
      top: false,
      child: Column(
        children: [

          const SizedBox(height: 12),

          // 🔹 Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  "Lost Dogs",
                  style: AppTheme.h1(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 🔎 Search
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

          // 📋 LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('lost_dogs')
                  .orderBy('reportedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final lostDogs = snapshot.data!.docs
                    .map((doc) {
                      return LostDog.fromMap(
                        doc.data() as Map<String, dynamic>,
                      ).copyWith(id: doc.id);
                    })
                    .where((dog) =>
                        dog.name
                            .toLowerCase()
                            .contains(_searchQuery))
                    .toList();

                if (lostDogs.isEmpty) {
                  return Center(
                    child: Text(
                      "No lost dogs reported yet",
                      style: AppTheme.body(
                          color: AppTheme.muted),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: lostDogs.length,
                  itemBuilder: (context, index) {
                    final dog = lostDogs[index];
                    final user =
                        FirebaseAuth.instance.currentUser;
                    final isOwner =
                        user?.uid == dog.reportedBy;

                    return Container(
                      margin:
                          const EdgeInsets.only(bottom: 14),
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(20),
                        onTap: () {
                          context
                              .read<AppState>()
                              .openLostDogDetail(dog.id);
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
                                          color: Colors
                                              .grey,
                                        ),
                                      ),
                              ),

                              const SizedBox(width: 14),

                              // 🧠 INFO
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [

                                    Row(
                                      children: [
                                        Text(
                                          dog.name,
                                          style: AppTheme
                                              .h3(),
                                        ),
                                      ],
                                    ),

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
                                            "Gender",
                                            dog.gender),
                                        _pinkChip(
                                            "Health",
                                            dog.healthStatus),
                                        _pinkChip(
                                            "Color",
                                            dog.color),
                                        if (dog.weight !=
                                            null)
                                          _pinkChip(
                                              "Weight",
                                              "${dog.weight} kg"),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 10),

                              // 🟡 STATUS
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
                                      color: dog.isFound
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
                                      dog.isFound
                                          ? "Found"
                                          : "Missing",
                                      style: AppTheme
                                          .caption(
                                        color:
                                            dog.isFound
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
                                          dog.isFound,
                                      activeColor:
                                          AppTheme
                                              .accent,
                                      onChanged:
                                          (value) {
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
/*
class LostDogDetailPage extends StatelessWidget {
  final LostDog lostDog;

  const LostDogDetailPage({
    super.key,
    required this.lostDog,
  });

  @override
  Widget build(BuildContext context) {

    final isFound = lostDog.isFound;

    return SafeArea(
      top: false,
      child: Container(
        color: const Color(0xFFFFF6F8),
        child: ListView(
          padding: const EdgeInsets.all(16), // ✅ دقیقاً مثل Playdate
          children: [

            Card(
              margin: const EdgeInsets.symmetric(vertical: 16), // ✅ دقیقاً مثل Accept
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14), // ✅ دقیقاً 14
              ),
              color: const Color(0xFF9E1B4F),
              child: Padding(
                padding: const EdgeInsets.all(20), // ✅ دقیقاً 20
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    /// 🔥 EXACT ICON POSITION (same as accept)
                    Container(
  height: 56,
  width: 56,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: LinearGradient(
      colors: isFound
          ? [Colors.greenAccent, Colors.teal]
          : [Colors.orangeAccent, Colors.deepOrange],
    ),
  ),
  child: const Icon(
    Icons.pets,
    color: Colors.white,
    size: 28,
  ),
),

                    const SizedBox(height: 12), // ✅ همان فاصله

                    Text(
                      lostDog.name,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 18, // ✅ همان سایز title accept
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 8), // ✅ همان spacing subtitle

                    Text(
                      lostDog.breed,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 16),

Wrap(
  spacing: 6,
  runSpacing: 6,
  alignment: WrapAlignment.center,
  children: [
    _infoChip("Gender", lostDog.gender),
    _infoChip("Health", lostDog.healthStatus),
    _infoChip("Color", lostDog.color),
    if (lostDog.weight != null)
      _infoChip("Weight", "${lostDog.weight} kg"),
    _infoChip("Collar", lostDog.collarType),
    _infoChip("Clothing", lostDog.clothingColor),
  ],
),

const SizedBox(height: 12),

_infoText("Location: Near reported area"),

const SizedBox(height: 8),

TextButton.icon(
  onPressed: () async {
    final uri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=${lostDog.latitude},${lostDog.longitude}",
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  },
  icon: const Icon(Icons.location_on, size: 16),
  label: const Text("View on Map"),
  style: TextButton.styleFrom(
    foregroundColor: Colors.white70,
  ),
),

const SizedBox(height: 14),

ElevatedButton.icon(
  onPressed: () async {
  final contact = lostDog.contactInfo;

  if (contact == null) return;

  final type = contact["type"];
  final value = contact["value"];

  if (type == "Phone") {
    final uri = Uri.parse("tel:$value");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  if (type == "Email") {
    final uri = Uri.parse("mailto:$value");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  if (type == "Instagram") {
    final uri = Uri.parse("https://instagram.com/$value");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
},
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFFFC107), // 🔥 دقیق همونی که گفتی
foregroundColor: Colors.black,
    minimumSize: const Size(180, 38),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
  ),
  icon: const Icon(Icons.chat_bubble_outline, size: 18),
  label: const Text(
    "Contact Reporter",
    style: TextStyle(fontSize: 13),
  ),
),
                    const SizedBox(height: 12),

                    Text(
                      isFound ? "Dog Found 🐾" : "Still Missing",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _infoChip(String label, String? value) {
  if (value == null || value.isEmpty) {
    return const SizedBox.shrink();
  }

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 4,
    ),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      "$label: $value",
      style: GoogleFonts.poppins(
        fontSize: 11,
        color: Colors.white,
      ),
    ),
  );
}

  Widget _infoText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),
    );
  }
}
*/