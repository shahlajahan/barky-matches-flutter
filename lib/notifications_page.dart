import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_notification.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart'; // مسیر رو اگر فرق داره اصلاح کن

import 'package:firebase_auth/firebase_auth.dart';

import 'package:barky_matches_fixed/ui/chat/chat_detail_page.dart';

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
  static const Color _cardColor = Color(0xFF9E1B4F);
  static const Color _vaccineReminderColor = Color(0xFF5A9E9B);
  final Map<String, String> _notificationTypes = {};

  IconData _iconForType(String rawType) {
    if (rawType == 'vaccine_reminder') {
      return Icons.medical_services_outlined;
    }

    return Icons.notifications_active;
  }

  Color _iconColorForType(String rawType) {
    if (rawType == 'vaccine_reminder') {
      return _vaccineReminderColor;
    }

    return Colors.amber;
  }

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
      debugPrint('🌐 FIRESTORE PASSIVE MODE ACTIVE → resume no network toggle');
    }
  }

  Widget _buildNotificationsBody(BuildContext context) {
    final userId = widget.currentUserId;

    if (userId == null || userId.isEmpty || userId == 'guest') {
      return _buildGuestNotification();
    }

    return Container(
      color: const Color(0xFFFFF6F8),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientUserId', isEqualTo: userId)
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

          _notificationTypes.clear();

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
                final rawType = (data['type'] ?? '')
                    .toString()
                    .toLowerCase()
                    .trim();
                if (rawType.isNotEmpty) {
                  _notificationTypes[doc.id] = rawType;
                }
                return AppNotification.fromMap(doc.id, data);
              })
              .whereType<AppNotification>()
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final appState = Provider.of<AppState>(context, listen: false);
              final navigator = Navigator.of(context);

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Material(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      if (widget.currentUserId == null ||
                          widget.currentUserId == 'guest') {
                        debugPrint('🚫 Guest → tap ignored');
                        return;
                      }

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
                        final rawType = (data['type'] ?? '')
                            .toString()
                            .toLowerCase()
                            .trim();

                        debugPrint("🔔 Notification tapped → type=$rawType");

                        // ✅ اول overlay بسته شود
                        //context.read<AppState>().closeNotifications();

                        switch (rawType) {
                          case 'appointment_paid':
                          case 'hotel_booking_payment_completed':
                          case 'pet_taxi_payment_completed':
                            widget.onNotificationSelected({
                              'type': rawType,
                              'appointmentId':
                                  data['appointmentId'] ?? data['bookingId'],
                              'bookingId': data['bookingId'],
                              'appointmentCollection':
                                  data['appointmentCollection'],
                            });
                            break;

                          case 'lost_dog':
                          case 'lost_pet':
                            widget.onNotificationSelected({
                              // ✅ unified type
                              'type': 'lost_pet',

                              // ✅ backward compatibility
                              'lostPetId':
                                  data['lostPetId'] ?? data['lostDogId'],
                            });

                            break;

                          case 'found_dog':
                          case 'found_pet':
                            widget.onNotificationSelected({
                              // ✅ unified type
                              'type': 'found_pet',

                              // ✅ backward compatibility
                              'foundPetId':
                                  data['foundPetId'] ?? data['foundDogId'],
                            });

                            break;

                          case 'vet_appointment_request':
                          case 'groomy_appointment_request':
                          case 'groomy_appointment_cancelled_by_user':
                          case 'groomy_appointment_payment_expired':
                          case 'hotel_booking_request':
                          case 'hotel_booking_cancelled_by_user':
                          case 'hotel_booking_payment_expired':
                          case 'pet_taxi_booking_request':
                          case 'pet_taxi_booking_cancelled_by_user':
                          case 'pet_taxi_booking_payment_expired':
                            widget.onNotificationSelected({
                              'type': rawType,
                              'appointmentId':
                                  data['appointmentId'] ?? data['bookingId'],
                              'bookingId': data['bookingId'],
                              'appointmentCollection':
                                  data['appointmentCollection'],
                              'businessId': data['businessId'],
                            });
                            break;

                          case 'vet_appointment_response':
                          case 'groomy_appointment_response':
                          case 'hotel_booking_response':
                          case 'pet_taxi_price_proposed':
                          case 'pet_taxi_payment_success':
                          case 'pet_taxi_driver_on_the_way':
                          case 'pet_taxi_driver_arrived':
                          case 'pet_taxi_pet_picked_up':
                          case 'pet_taxi_trip_started':
                          case 'pet_taxi_trip_completed':
                          case 'pet_taxi_booking_cancelled':
                          case 'pet_taxi_status_update':
                            widget.onNotificationSelected({
                              'type': rawType,
                              'appointmentId':
                                  data['appointmentId'] ?? data['bookingId'],
                              'bookingId': data['bookingId'],
                              'appointmentCollection':
                                  data['appointmentCollection'],
                              'status': data['status'], // 🔥 خیلی مهم
                            });
                            break;

                          case 'appointment_cancelled_confirmation':
                          case 'vet_appointment_refunded':
                            widget.onNotificationSelected({
                              'type': rawType,
                              'appointmentId': data['appointmentId'],
                              'status': data['status'],
                              'refundStatus': data['refundStatus'],
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
                          case 'invoice_reminder':
                          case 'payment_window_expired':
                            Future.microtask(() {
                              if (mounted) {
                                appState.closeNotifications();
                              }
                            });

                            widget.onNotificationSelected({
                              'type': rawType,

                              'sellerOrderId': data['sellerOrderId'],
                              'orderId': data['orderId'],

                              // بعضی flow ها اینو میفرستن
                              'appointmentId': data['appointmentId'],
                            });

                            break;
                          case 'new_order':
                          case 'order_paid':
                          case 'order_update':
                          case 'order_created':
                          case 'new_paid_order':
                            Future.microtask(() {
                              if (mounted) {
                                appState.closeNotifications();
                              }
                            });

                            widget.onNotificationSelected({
                              'type': rawType,

                              // ✅ هر دو رو بفرست
                              'orderId': data['orderId'],
                              'sellerOrderId': data['sellerOrderId'],
                            });

                            break;

                          case 'playdate_reminder':
                            widget.onNotificationSelected({
                              'type': 'playdate_reminder',
                              'requestId': data['requestId'],
                            });
                            break;

                          case 'vaccine_reminder':
                            widget.onNotificationSelected({
                              'type': 'vaccine_reminder',
                              'petId': data['petId'],
                              'patientId': data['patientId'],
                              'vaccineId': data['vaccineId'],
                              'businessId': data['businessId'],
                            });
                            break;

                          case 'vaccine_completed':
                            widget.onNotificationSelected({
                              'type': 'vaccine_completed',
                              'petId': data['petId'],
                              'patientId': data['patientId'],
                              'vaccineId': data['vaccineId'],
                              'businessId': data['businessId'],
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

                          case 'story_reply':
                            final senderId = data['senderId'];

                            final senderName =
                                data['senderUsername'] ?? 'Pet User';

                            if (senderId == null) return;

                            final chatsQuery = await FirebaseFirestore.instance
                                .collection('chats')
                                .where(
                                  'participants',
                                  arrayContains:
                                      FirebaseAuth.instance.currentUser!.uid,
                                )
                                .get();

                            String? existingChatId;

                            for (final doc in chatsQuery.docs) {
                              final participants = List<String>.from(
                                doc['participants'] ?? [],
                              );

                              if (participants.contains(senderId)) {
                                existingChatId = doc.id;
                                break;
                              }
                            }

                            if (existingChatId == null) {
                              final newChat = await FirebaseFirestore.instance
                                  .collection('chats')
                                  .add({
                                    'participants': [
                                      FirebaseAuth.instance.currentUser!.uid,
                                      senderId,
                                    ],

                                    'participantNames': {
                                      FirebaseAuth.instance.currentUser!.uid:
                                          'You',

                                      senderId: senderName,
                                    },

                                    'lastMessage': '',

                                    'lastMessageAt':
                                        FieldValue.serverTimestamp(),

                                    'createdAt': FieldValue.serverTimestamp(),
                                  });

                              existingChatId = newChat.id;
                            }

                            if (!mounted) return;

                            navigator.push(
                              MaterialPageRoute(
                                builder: (_) => ChatDetailPage(
                                  chatId: existingChatId!,
                                  otherUserId: senderId,
                                  otherUserName: senderName,
                                ),
                              ),
                            );

                            break;

                          default:
                            if (rawType != 'vaccine_reminder') {
                              debugPrint(
                                '⚠️ Unknown notification type: $rawType',
                              );
                            }
                        }
                      } finally {}
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            notification.isRead
                                ? Icons.notifications_none
                                : _iconForType(
                                    _notificationTypes[notification.id ?? ''] ??
                                        '',
                                  ),
                            color: _iconColorForType(
                              _notificationTypes[notification.id ?? ''] ?? '',
                            ),
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
                                  notification.timestamp.toString(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.amber),
                            onPressed: () async {
                              if (widget.currentUserId == null ||
                                  widget.currentUserId == 'guest') {
                                debugPrint('🚫 Guest → delete blocked');
                                return;
                              }

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

  Widget _buildGuestNotification() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_off, size: 80, color: Colors.grey),

            const SizedBox(height: 20),

            const Text(
              "No notifications for Guest",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            const Text(
              "Login to receive updates and alerts",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildNotificationsBody(context);
  }
}
