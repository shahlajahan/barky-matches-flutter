import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'dog.dart';
import 'notification_model.dart';
// ❗ طبق درخواستت حذف نشده

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
  late Future<List<AppNotification>> _notificationsFuture;
  final Map<String, String> _notificationTypes = {};

  IconData _iconForType(String rawType) {
    if (rawType == 'vaccine_reminder') {
      return Icons.medical_services_outlined;
    }

    return Icons.notifications_none;
  }

  Color _iconColorForType(String rawType) {
    if (rawType == 'vaccine_reminder') {
      return Colors.pink[700]!;
    }

    return Colors.pink[500]!;
  }

  Color _cardColorForType(String rawType) {
    if (rawType == 'vaccine_reminder') {
      return Colors.pink[100]!;
    }

    return Colors.pink[50]!;
  }

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  Future<List<AppNotification>> _loadNotifications() async {
    try {
      _notificationTypes.clear();
      final userId = widget.currentUserId.trim();

      if (userId.isEmpty || userId == 'guest') {
        debugPrint('🚫 Guest → skip notifications load');
        return [];
      }

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

      final allNotifications = <AppNotification>[];

      for (final doc in [...personalSnapshot.docs, ...publicSnapshot.docs]) {
        final data = doc.data();
        final notification = AppNotification.fromMap(doc.id, data);
        allNotifications.add(notification);

        final rawType = (data['type'] ?? '').toString().toLowerCase().trim();
        if (rawType.isNotEmpty) {
          _notificationTypes[doc.id] = rawType;
        }
      }

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
      final coordinatesMatch = RegExp(
        r'near\s+([\d.]+),\s+([\d.]+)',
      ).firstMatch(body);
      if (coordinatesMatch == null) return null;

      final lat = double.tryParse(coordinatesMatch.group(1)!) ?? 0.0;
      final lng = double.tryParse(coordinatesMatch.group(2)!) ?? 0.0;

      final snapshot = await FirebaseFirestore.instance
          .collection('lost_pets')
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
                Map<String, dynamic> payload = {};

                try {
                  if (notification.payload != null &&
                      notification.payload!.isNotEmpty) {
                    payload = Map<String, dynamic>.from(
                      jsonDecode(notification.payload!),
                    );
                  }
                } catch (e) {
                  debugPrint('Notification payload parse error: $e');
                }

                final rawType =
                    (payload['type']?.toString().toLowerCase() ??
                            _notificationTypes[notification.id] ??
                            '')
                        .trim();

                return Card(
                  color: _cardColorForType(rawType),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      _iconForType(rawType),
                      color: _iconColorForType(rawType),
                    ),
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
                          DateFormat(
                            'yyyy-MM-dd – kk:mm',
                          ).format(notification.timestamp),
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

                        if (!mounted) return;
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

                      final title = notification.title?.toLowerCase() ?? '';
                      final body = notification.body?.toLowerCase() ?? '';

                      /// ✅ تشخیص امن Playdate (FIX قطعی)
                      final isPlaydate =
                          rawType.contains('playdate') ||
                          title.contains('playdate') ||
                          body.contains('play');
                      if (!context.mounted) return;
                      if (isPlaydate) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlayDateRequestsPageNew(
                              dogsList: widget.dogsList,
                              favoriteDogs: widget.favoriteDogs ?? [],
                              onToggleFavorite:
                                  widget.onToggleFavorite ?? (_) {},
                              initialRequestId: payload['requestId']
                                  ?.toString(),
                            ),
                          ),
                        );
                        return;
                      }

                      if (rawType == 'lost_dog' || rawType == 'lost_pet') {
                        String? lostDogId = payload['lostDogId']?.toString();
                        lostDogId ??= payload['lostPetId']?.toString();
                        if (lostDogId == null) {
                          final nameMatch = RegExp(
                            r'(\w+)\s*\(',
                          ).firstMatch(notification.body ?? '');
                          if (nameMatch != null) {
                            lostDogId = await _findLostDogId(
                              nameMatch.group(1)!,
                              notification.body ?? '',
                            );
                          }
                        }

                        if (lostDogId != null && context.mounted) {
                          final doc = await FirebaseFirestore.instance
                              .collection('lost_pets')
                              .doc(lostDogId)
                              .get();
                          if (!context.mounted) return;
                          if (doc.exists) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LostDogDetailPage(
                                  lostDog: LostDog.fromMap(
                                    doc.data()!,
                                  ).copyWith(id: doc.id),
                                ),
                              ),
                            );
                          }
                        }
                        return;
                      }

                      if (rawType == 'found_dog' || rawType == 'found_pet') {
                        final foundDogId =
                            payload['foundDogId']?.toString() ??
                            payload['foundPetId']?.toString();
                        if (foundDogId != null && context.mounted) {
                          final doc = await FirebaseFirestore.instance
                              .collection('found_pets')
                              .doc(foundDogId)
                              .get();
                          if (!context.mounted) return;
                          if (doc.exists) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FoundDogDetailPage(
                                  foundDog: FoundDog.fromMap(
                                    doc.data()!,
                                  ).copyWith(id: doc.id),
                                ),
                              ),
                            );
                          }
                        }
                        return;
                      }

                      if (rawType == 'vaccine_reminder') {
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
