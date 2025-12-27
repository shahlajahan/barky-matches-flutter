import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'app_notification.dart';
import 'app_state.dart';
import 'other_user_dog_page.dart';
import 'dart:convert';

class NotificationsPage extends StatefulWidget {
  final String? currentUserId;

  const NotificationsPage({super.key, required this.currentUserId});

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    if (widget.currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Notifications',
            style: GoogleFonts.dancingScript(color: const Color(0xFFFFC107)),
          ),
          backgroundColor: Colors.pink,
        ),
        body: Center(
          child: Text(
            'User not logged in.',
            style: GoogleFonts.poppins(
              color: const Color(0xFFFFC107),
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    return DefaultTextStyle.merge(
      style: GoogleFonts.poppins(),
      child: Builder(
        builder: (context) {
          return Theme(
            data: Theme.of(context).copyWith(
              textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
            ),
            child: DefaultTextStyle(
              style: GoogleFonts.poppins(
                textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 16,
                      color: const Color(0xFFFFC107),
                    ),
              ),
              child: Scaffold(
                appBar: AppBar(
                  title: Text(
                    'Notifications',
                    style: GoogleFonts.dancingScript(color: const Color(0xFFFFC107)),
                  ),
                  backgroundColor: Colors.pink,
                ),
                backgroundColor: Colors.pink, // تنظیم رنگ پس‌زمینه به‌صورت یکنواخت
                body: Container(
                  color: Colors.pink, // تنظیم رنگ کونتینر به‌صورت یکنواخت
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Test Font',
                          style: GoogleFonts.poppins(color: Colors.red, fontSize: 24),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: Colors.pink,
                          child: DefaultTextStyle(
                            style: GoogleFonts.poppins(
                              textStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                    color: const Color(0xFFFFC107),
                                  ),
                            ),
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('notifications')
                                  .where('recipientUserId', isEqualTo: widget.currentUserId)
                                  .orderBy('timestamp', descending: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (snapshot.hasError) {
                                  print('NotificationsPage - Error loading notifications: ${snapshot.error}');
                                  return Center(child: Text('Error: ${snapshot.error}'));
                                }
                                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                  return Container(
                                    color: Colors.pink,
                                    child: Center(
                                      child: Text(
                                        'No notifications available.',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFFFC107),
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final notifications = snapshot.data!.docs
                                    .map((doc) => AppNotification.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                                    .toList();
                                return Container(
                                  color: Colors.pink,
                                  child: ListView.builder(
                                    itemCount: notifications.length,
                                    itemBuilder: (context, index) {
                                      final notification = notifications[index];
                                      final payload = notification.payload != null ? jsonDecode(notification.payload!) : {};
                                      return ListTile(
                                        leading: Icon(
                                          notification.isRead ? Icons.notifications_outlined : Icons.notifications_active,
                                          color: const Color(0xFFFFC107),
                                        ),
                                        title: Text(
                                          notification.title,
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFFFFC107),
                                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              notification.body,
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFFFFC107),
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              notification.timestamp.toString(),
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFFFFC107).withOpacity(0.7),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        tileColor: notification.isRead ? Colors.pink.withOpacity(0.2) : Colors.pink.withOpacity(0.5),
                                        onTap: () async {
                                          if (!mounted) return;
                                          await FirebaseFirestore.instance
                                              .collection('notifications')
                                              .doc(notification.id)
                                              .update({'isRead': true});
                                          print('NotificationsPage - Marked notification ${notification.id} as read');

                                          // بررسی نوع نوتیفیکیشن و هدایت به DogCard کاربر مقابل
                                          String? targetUserId;
                                          if (payload['type'] == 'playDateRequest' && payload['requesterUserId'] != null) {
                                            targetUserId = payload['requesterUserId'] as String;
                                          } else if (payload['type'] == 'like' && payload['likerUserId'] != null) {
                                            targetUserId = payload['likerUserId'] as String;
                                          } else if (payload['type'] == 'favorite' && payload['likerUserId'] != null) {
                                            targetUserId = payload['likerUserId'] as String;
                                          } else if (payload['type'] == 'dislike' && payload['likerUserId'] != null) { // اضافه کردن پشتیبانی از dislike
                                            targetUserId = payload['likerUserId'] as String;
                                          }

                                          if (targetUserId != null && targetUserId != widget.currentUserId && targetUserId.isNotEmpty) {
                                            if (mounted) {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => OtherUserDogPage(
                                                    targetUserId: targetUserId!,
                                                    dogsList: Provider.of<AppState>(context, listen: false).dogsList,
                                                    favoriteDogs: Provider.of<AppState>(context, listen: false).favoriteDogs,
                                                    onToggleFavorite: Provider.of<AppState>(context, listen: false).onToggleFavorite,
                                                  ),
                                                ),
                                              );
                                            }
                                          } else if (payload['type'] == 'instant_notification') {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Opened: ${notification.title}')),
                                              );
                                            }
                                          } else {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Unsupported notification type: ${payload['type']}')),
                                              );
                                            }
                                          }
                                        },
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.yellow),
                                          onPressed: () async {
                                            if (!mounted) return;
                                            try {
                                              await FirebaseFirestore.instance
                                                  .collection('notifications')
                                                  .doc(notification.id)
                                                  .delete();
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Notification deleted')),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Error: $e')),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}