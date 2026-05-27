import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _unblockUser({
    required String blockedUserId,
    required String blockedName,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
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
                    color: const Color(0xFF9E1B4F).withOpacity(.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.userCheck,
                    color: Color(0xFF9E1B4F),
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Unblock user",
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF9E1B4F),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Are you sure you want to unblock $blockedName?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: BorderSide(color: Colors.grey.shade300),
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9E1B4F),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          "Unblock",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
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

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .collection("blockedUsers")
          .doc(blockedUserId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("$blockedName has been unblocked")),
      );
    } catch (e) {
      debugPrint("Unblock error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to unblock user")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUserId;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF2F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE91E63),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Blocked Users",
          style: GoogleFonts.poppins(
            color: const Color(0xFFFFC107),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: uid == null
          ? const Center(child: Text("You must be signed in"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(uid)
                  .collection("blockedUsers")
                  .orderBy("blockedAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: "Failed to load blocked users.\n${snapshot.error}",
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF9E1B4F)),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const _BlockedUsersEmptyState();
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                  children: [
                    _HeaderCard(count: docs.length),
                    const SizedBox(height: 22),
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};

                      final blockedUserId = doc.id;
                      final name = (data["name"] ?? "Unknown User").toString();
                      final username = (data["username"] ?? "").toString();
                      final photoUrl = (data["photoUrl"] ?? "").toString();

                      final Timestamp? blockedAtTs = data["blockedAt"];
                      final DateTime? blockedAt = blockedAtTs?.toDate();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _BlockedUserCard(
                          name: name,
                          username: username,
                          photoUrl: photoUrl,
                          blockedAt: blockedAt,
                          onUnblock: () {
                            _unblockUser(
                              blockedUserId: blockedUserId,
                              blockedName: name,
                            );
                          },
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int count;

  const _HeaderCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9E1B4F), Color(0xFFE91E63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              LucideIcons.userX,
              color: Color(0xFFFFC107),
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$count blocked user${count == 1 ? '' : 's'}",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFC107),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Manage users you have blocked from interacting with you.",
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedUsersEmptyState extends StatelessWidget {
  const _BlockedUsersEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: const Color(0xFF9E1B4F).withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.userX,
                  size: 38,
                  color: Color(0xFF9E1B4F),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "No blocked users",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9E1B4F),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Users you block will appear here. You can unblock them anytime.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _BlockedUserCard extends StatelessWidget {
  final String name;
  final String username;
  final String photoUrl;
  final DateTime? blockedAt;
  final VoidCallback onUnblock;

  const _BlockedUserCard({
    required this.name,
    required this.username,
    required this.photoUrl,
    required this.blockedAt,
    required this.onUnblock,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return "Unknown date";

    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();

    return "$d/$m/$y";
  }

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
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF9E1B4F).withOpacity(.10),
            backgroundImage: photoUrl.isNotEmpty
                ? NetworkImage(photoUrl)
                : null,
            child: photoUrl.isEmpty
                ? const Icon(LucideIcons.user, color: Color(0xFF9E1B4F))
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                if (username.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "@$username",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.calendar,
                      size: 14,
                      color: Colors.black38,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Blocked on ${_formatDate(blockedAt)}",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: onUnblock,
            icon: const Icon(LucideIcons.userCheck, size: 16),
            label: const Text("Unblock"),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF9E1B4F),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
