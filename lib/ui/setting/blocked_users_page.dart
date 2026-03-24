import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

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
        return AlertDialog(
          title: const Text("Unblock user"),
          content: Text(
            "Are you sure you want to unblock $blockedName?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Unblock"),
            ),
          ],
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
        SnackBar(
          content: Text("$blockedName has been unblocked"),
        ),
      );
    } catch (e) {
      debugPrint("Unblock error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to unblock user"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = currentUserId;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text("Blocked Users"),
        backgroundColor: AppTheme.primary,
        elevation: 0,
      ),
      body: uid == null
          ? const Center(
              child: Text("You must be signed in"),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(uid)
                  .collection("blockedUsers")
                  .orderBy("blockedAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Failed to load blocked users.\n${snapshot.error}",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const _BlockedUsersEmptyState();
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>? ?? {};

                    final blockedUserId = doc.id;
                    final name = (data["name"] ?? "Unknown User").toString();
                    final username = (data["username"] ?? "").toString();
                    final photoUrl = (data["photoUrl"] ?? "").toString();

                    final Timestamp? blockedAtTs = data["blockedAt"];
                    final DateTime? blockedAt = blockedAtTs?.toDate();

                    return _BlockedUserCard(
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
                    );
                  },
                );
              },
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block_outlined,
              size: 72,
              color: AppTheme.primary.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            Text(
              "No blocked users",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Users you block will appear here. You can unblock them anytime.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
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
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primary.withOpacity(0.12),
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      color: AppTheme.primary,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (username.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      "@$username",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    "Blocked on ${_formatDate(blockedAt)}",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onUnblock,
              child: const Text("Unblock"),
            ),
          ],
        ),
      ),
    );
  }
}