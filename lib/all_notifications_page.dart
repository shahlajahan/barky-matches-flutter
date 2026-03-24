import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'dog.dart';
import 'notification_model.dart';
import 'dog_card.dart'; // ❗ طبق درخواستت حذف نشده
import 'other_user_dog_page.dart';

import 'screens/lost_dog_detail_page.dart';
import 'screens/found_dog_detail_page.dart';
import '../models/lost_dog.dart';
import '../models/found_dog.dart';

import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'play_date_requests_page_new.dart';

class AllNotificationsPage extends StatefulWidget {
  final String currentUserId;
  final List<Dog> dogsList;
  final List<Dog>? favoriteDogs;
  final void Function(Dog)? onToggleFavorite;

  const AllNotificationsPage({
    super.key,
    required this.currentUserId,
    required this.dogsList,
    this.favoriteDogs,
    this.onToggleFavorite,
  });

  @override
  State<AllNotificationsPage> createState() => _AllNotificationsPageState();
}

class _AllNotificationsPageState extends State<AllNotificationsPage> {
 // late Future<List<AppNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  Future<List<AppNotification>> _loadNotifications() async {
    try {
      final userId = widget.currentUserId;

      final personalSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUserId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final publicSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUserId', isNull: true)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();

      final allNotifications = [
        ...personalSnapshot.docs.map(
          (doc) => AppNotification.fromMap(doc.id, doc.data()),
        ),
        ...publicSnapshot.docs.map(
          (doc) => AppNotification.fromMap(doc.id, doc.data()),
        ),
      ];

      final unique = <String, AppNotification>{};
      for (final n in allNotifications) {
        if (n.id != null) {
          unique[n.id!] = n;
        }
      }

      return unique.values.toList();
    } catch (e) {
      debugPrint('AllNotificationsPage - load error: $e');
      return [];
    }
  }

  Future<String?> _findLostDogId(String name, String body) async {
    try {
      final coordinatesMatch =
          RegExp(r'near\s+([\d.]+),\s+([\d.]+)').firstMatch(body);
      if (coordinatesMatch == null) return null;

      final lat = double.tryParse(coordinatesMatch.group(1)!) ?? 0.0;
      final lng = double.tryParse(coordinatesMatch.group(2)!) ?? 0.0;

      final snapshot = await FirebaseFirestore.instance
          .collection('lost_dogs')
          .where('name', isEqualTo: name)
          .where('latitude', isEqualTo: lat)
          .where('longitude', isEqualTo: lng)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.id;
    } catch (e) {
      debugPrint('findLostDogId error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pink,
        title: Text(
          l10n.appTitle,
          style: TextStyle(
            color: Colors.yellow[700],
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<List<AppNotification>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFFFC107)),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            final notifications = snapshot.data ?? [];

            if (notifications.isEmpty) {
              return Center(
                child: Text(
                  l10n.noNotifications,
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontFamily: 'Poppins',
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final payload = notification.payload != null
                    ? Map<String, dynamic>.from(
                        jsonDecode(notification.payload!),
                      )
                    : <String, dynamic>{};

                return Card(
                  color: Colors.pink[50],
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      notification.title ?? '',
                      style: TextStyle(
                        color: Colors.pink[900],
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.body ?? '',
                          style: TextStyle(
                            color: Colors.pink[700],
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('yyyy-MM-dd – kk:mm')
                              .format(notification.timestamp),
                          style: TextStyle(
                            color: Colors.pink[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(notification.id)
                            .delete();

                        setState(() {
                          _notificationsFuture = _loadNotifications();
                        });
                      },
                    ),
                    onTap: () async {
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(notification.id)
                          .update({'isRead': true});

                      final rawType =
                          payload['type']?.toString().toLowerCase() ?? '';
                      final title =
                          notification.title?.toLowerCase() ?? '';
                      final body =
                          notification.body?.toLowerCase() ?? '';

                      /// ✅ تشخیص امن Playdate (FIX قطعی)
                      final isPlaydate =
                          rawType.contains('playdate') ||
                          title.contains('playdate') ||
                          body.contains('play');

                      if (isPlaydate) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayDateRequestsPageNew(
                              dogsList: widget.dogsList,
                              favoriteDogs: widget.favoriteDogs ?? [],
                              onToggleFavorite:
                                  widget.onToggleFavorite ?? (_) {},
                              initialRequestId:
                                  payload['requestId']?.toString(),
                            ),
                          ),
                        );
                        return;
                      }

                      if (rawType == 'lost_dog') {
                        String? lostDogId = payload['lostDogId'];
                        if (lostDogId == null) {
                          final nameMatch =
                              RegExp(r'(\w+)\s*\(')
                                  .firstMatch(notification.body ?? '');
                          if (nameMatch != null) {
                            lostDogId = await _findLostDogId(
                              nameMatch.group(1)!,
                              notification.body ?? '',
                            );
                          }
                        }

                        if (lostDogId != null && mounted) {
                          final doc = await FirebaseFirestore.instance
                              .collection('lost_dogs')
                              .doc(lostDogId)
                              .get();
                          if (doc.exists) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LostDogDetailPage(
                                  lostDog:
                                      LostDog.fromMap(doc.data()!)
                                          .copyWith(id: doc.id),
                                ),
                              ),
                            );
                          }
                        }
                        return;
                      }

                      if (rawType == 'found_dog') {
                        final foundDogId = payload['foundDogId'];
                        if (foundDogId != null && mounted) {
                          final doc = await FirebaseFirestore.instance
                              .collection('found_dogs')
                              .doc(foundDogId)
                              .get();
                          if (doc.exists) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FoundDogDetailPage(
                                  foundDog:
                                      FoundDog.fromMap(doc.data()!)
                                          .copyWith(id: doc.id),
                                ),
                              ),
                            );
                          }
                        }
                        return;
                      }

                      /// ❌ هیچ SnackBar برای unsupported نداریم
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
