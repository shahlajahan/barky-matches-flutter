import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_notification.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart'; // مسیر رو اگر فرق داره اصلاح کن

class NotificationsPage extends StatefulWidget {
  final String? currentUserId;
  final void Function(Map<String, dynamic> payload) onNotificationSelected;

  const NotificationsPage({
    super.key,
    required this.currentUserId,
    required this.onNotificationSelected,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {

  bool _handlingTap = false;

  static const Color _cardColor = Color(0xFF9E1B4F);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 NotificationsPage resumed');
      FirebaseFirestore.instance.enableNetwork();
    }
  }

  Widget _buildNotificationsBody(BuildContext context) {

    if (widget.currentUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      color: const Color(0xFFFFF6F8),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientUserId', isEqualTo: widget.currentUserId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.hasError) {
            debugPrint("🔥 FIRESTORE ERROR: ${snapshot.error}");
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No notifications available.',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            );
          }

          final notifications = docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return AppNotification.fromMap(doc.id, data);
              })
              .whereType<AppNotification>()
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: notifications.length,
            itemBuilder: (context, index) {

              final notification = notifications[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
  if (!mounted || _handlingTap) return;

  _handlingTap = true;

  try {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notification.id)
        .update({'isRead': true});

    final docSnap = await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notification.id)
        .get();

    final data = docSnap.data() ?? {};
    final rawType =
        (data['type'] ?? '').toString().toLowerCase().trim();

    debugPrint("🔔 Notification tapped → type=$rawType");

    // ✅ اول overlay بسته شود
    context.read<AppState>().closeNotifications();

    switch (rawType) {

      case 'lost_dog':
        widget.onNotificationSelected({
          'type': 'lost_dog',
          'lostDogId': data['lostDogId'],
        });
        break;

      case 'found_dog':
        widget.onNotificationSelected({
          'type': 'found_dog',
          'foundDogId': data['foundDogId'],
        });
        break;

      case 'playdaterequest':
      case 'playdate_request':
        widget.onNotificationSelected({
          'type': 'playdate_request',
          'requestId': data['requestId'],
        });
        break;

      case 'playdate_response':
        widget.onNotificationSelected({
          'type': 'playdate_response',
          'requestId': data['requestId'],
        });
        break;

      case 'playdate_reminder':
        widget.onNotificationSelected({
          'type': 'playdate_reminder',
          'requestId': data['requestId'],
        });
        break;

        case 'adoption_request': // ✅ این اضافه شد
    widget.onNotificationSelected({
      'type': 'adoption_request',
      'requestId': data['requestId'],
    });
    break;

    case 'business_resolution':
  widget.onNotificationSelected({
    'type': 'business_resolution',
    'status': data['status'],
    'centerId': data['centerId'],
    'reason': data['reason'],
  });
  break;

      default:
        debugPrint('⚠️ Unknown notification type: $rawType');
    }

  } finally {
    if (mounted) {
      _handlingTap = false;
    }
  }
},
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Icon(
                            notification.isRead
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: Colors.amber,
                            size: 26,
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                Text(
                                  notification.title,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  notification.body,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  notification.timestamp?.toString() ?? '',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.amber,
                            ),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('notifications')
                                  .doc(notification.id)
                                  .delete();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildNotificationsBody(context);
  }
}