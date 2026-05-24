import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'blocked_users_page.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() =>
      _PrivacySettingsPageState();
}

class _PrivacySettingsPageState
    extends State<PrivacySettingsPage> {

  bool profileVisible = true;
  bool locationSharing = true;
  bool dogProfileVisible = true;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  /// LOAD SETTINGS FROM FIRESTORE
  Future<void> _loadPrivacySettings() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      final data = doc.data();

      if (data != null) {
        profileVisible =
            data["profileVisible"] ?? true;

        locationSharing =
            data["locationSharing"] ?? true;

        dogProfileVisible =
            data["dogProfileVisible"] ?? true;
      }
    } catch (e) {
      debugPrint("Privacy load error: $e");
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  /// SAVE SETTINGS
  Future<void> _savePrivacySettings() async {

    final uid =
        FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return;

    final db = FirebaseFirestore.instance;

    /// update user
    await db.collection("users").doc(uid).set({
      "profileVisible": profileVisible,
      "locationSharing": locationSharing,
      "dogProfileVisible": dogProfileVisible,
    }, SetOptions(merge: true));

    /// update all dogs of user
    final dogs = await db
        .collection("dogs")
        .where("ownerId", isEqualTo: uid)
        .get();

    for (final doc in dogs.docs) {
      await doc.reference.update({
        "ownerProfileVisible": profileVisible,
        "dogProfileVisible": dogProfileVisible,
      });
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Privacy settings updated"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Container(
      color: const Color(0xFFFDF2F5),

      child: Stack(
        children: [

          ListView(
            padding: const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              120,
            ),

            children: [

              // 🟣 HEADER
              Container(
                padding: const EdgeInsets.all(22),

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF9E1B4F),
                      Color(0xFFE91E63),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),

                  borderRadius:
                      BorderRadius.circular(28),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    const Icon(
                      LucideIcons.shield,
                      color: Color(0xFFFFC107),
                      size: 34,
                    ),

                    const SizedBox(height: 14),

                    Text(
                      "Privacy & Security",
                      style: GoogleFonts.poppins(
                        color:
                            const Color(0xFFFFC107),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Control your visibility, data sharing, and account privacy settings.",
                      style: GoogleFonts.poppins(
                        color:
                            Colors.white.withOpacity(.9),
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              _SectionTitle(
                title: "Profile",
                icon: LucideIcons.user,
              ),

              const SizedBox(height: 12),

              _ToggleTile(
                title: "Profile visibility",

                subtitle: profileVisible
                    ? "Other users can see your profile"
                    : "Your profile is hidden",

                icon: LucideIcons.eye,

                value: profileVisible,

                onChanged: (v) {
                  setState(() {
                    profileVisible = v;
                  });

                  _savePrivacySettings();
                },
              ),

              const SizedBox(height: 14),

              _ToggleTile(
                title: "Location sharing",

                subtitle: locationSharing
                    ? "Your approximate location is visible"
                    : "Your location is hidden",

                icon: LucideIcons.mapPin,

                value: locationSharing,

                onChanged: (v) {
                  setState(() {
                    locationSharing = v;
                  });

                  _savePrivacySettings();
                },
              ),

              const SizedBox(height: 28),

              _SectionTitle(
                title: "Dogs",
                icon: LucideIcons.dog,
              ),

              const SizedBox(height: 12),

              _ToggleTile(
                title: "Dog profile visibility",

                subtitle: dogProfileVisible
                    ? "Other users can see your dogs"
                    : "Your dogs are hidden",

                icon: LucideIcons.dog,

                value: dogProfileVisible,

                onChanged: (v) {
                  setState(() {
                    dogProfileVisible = v;
                  });

                  _savePrivacySettings();
                },
              ),

              const SizedBox(height: 28),

              _SectionTitle(
                title: "Account",
                icon: LucideIcons.settings,
              ),

              const SizedBox(height: 12),

              _ActionTile(
                title: "Blocked users",

                icon: LucideIcons.userX,

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const BlockedUsersPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              _ActionTile(
                title: "Download my data",

                icon: LucideIcons.download,

                onTap: () {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Data export request submitted",
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              _ActionTile(
                title: "Delete account",

                icon: LucideIcons.trash2,

                danger: true,

                onTap: () {
                  _showDeleteDialog();
                },
              ),
            ],
          ),

          if (loading)
            Container(
              color: Colors.black26,

              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF9E1B4F),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteDialog() {

    showDialog(
      context: context,

      builder: (_) {

        return Dialog(
          backgroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(24),
          ),

          child: Padding(
            padding: const EdgeInsets.all(24),

            child: Column(
              mainAxisSize: MainAxisSize.min,

              children: [

                Container(
                  width: 72,
                  height: 72,

                  decoration: BoxDecoration(
                    color:
                        Colors.red.withOpacity(.12),

                    shape: BoxShape.circle,
                  ),

                  child: const Icon(
                    LucideIcons.trash2,
                    color: Colors.red,
                    size: 34,
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  "Delete account",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  "This action cannot be undone and all your data will be permanently deleted.",
                  textAlign: TextAlign.center,

                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 26),

                Row(
                  children: [

                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Colors.black87,

                          side: BorderSide(
                            color: Colors.grey.shade300,
                          ),

                          minimumSize:
                              const Size(0, 52),

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    16),
                          ),
                        ),

                        onPressed: () {
                          Navigator.pop(context);
                        },

                        child: Text(
                          "Cancel",
                          style:
                              GoogleFonts.poppins(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton
                            .styleFrom(
                          backgroundColor:
                              Colors.red,

                          foregroundColor:
                              Colors.white,

                          elevation: 0,

                          minimumSize:
                              const Size(0, 52),

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    16),
                          ),
                        ),

                        onPressed: () {
                          Navigator.pop(context);
                        },

                        child: Text(
                          "Delete",
                          style:
                              GoogleFonts.poppins(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {

  final String title;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {

    return Row(
      children: [

        Icon(
          icon,
          size: 20,
          color: const Color(0xFF9E1B4F),
        ),

        const SizedBox(width: 10),

        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF9E1B4F),
          ),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {

  final String title;
  final String subtitle;
  final bool value;
  final Function(bool) onChanged;
  final IconData icon;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(24),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Row(
        children: [

          Container(
            width: 52,
            height: 52,

            decoration: BoxDecoration(
              color: const Color(0xFF9E1B4F)
                  .withOpacity(.1),

              borderRadius:
                  BorderRadius.circular(16),
            ),

            child: Icon(
              icon,
              color: const Color(0xFF9E1B4F),
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value: value,

            activeColor:
                const Color(0xFFFFC107),

            activeTrackColor:
                const Color(0xFF9E1B4F),

            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _ActionTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: onTap,

      child: Container(
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(24),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Row(
          children: [

            Container(
              width: 52,
              height: 52,

              decoration: BoxDecoration(
                color: danger
                    ? Colors.red.withOpacity(.1)
                    : const Color(0xFF9E1B4F)
                        .withOpacity(.1),

                borderRadius:
                    BorderRadius.circular(16),
              ),

              child: Icon(
                icon,
                color: danger
                    ? Colors.red
                    : const Color(0xFF9E1B4F),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: danger
                      ? Colors.red
                      : Colors.black87,
                ),
              ),
            ),

            Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }
}