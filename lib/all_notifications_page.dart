import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:barky_matches_fixed/play_date_request.dart';
import 'dog.dart';
import 'notification_model.dart';
import 'dog_card.dart';
import 'other_user_dog_page.dart';
import 'notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'screens/lost_dog_detail_page.dart';
import 'screens/found_dog_detail_page.dart';
import '../models/lost_dog.dart';
import '../models/found_dog.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';


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
  _AllNotificationsPageState createState() => _AllNotificationsPageState();
}

class _AllNotificationsPageState extends State<AllNotificationsPage> {
  late Future<List<AppNotification>> _notificationsFuture;
  late Future<List<PlayDateRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _notificationsFuture = _loadNotifications();
    _requestsFuture = _loadPlayDateRequests();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.scheduleExactAlarm.request().isGranted) {
      print('AllNotificationsPage - Exact alarm permission granted');
    } else {
      print('AllNotificationsPage - Exact alarm permission denied');
    }
  }

  Future<List<AppNotification>> _loadNotifications() async {
    try {
      final userId = widget.currentUserId;
      final personalSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUserId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
      final publicSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientUserId', isNull: true)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final allNotifications = [
        ...personalSnapshot.docs.map((doc) => AppNotification.fromMap(doc.id, doc.data())),
        ...publicSnapshot.docs.map((doc) => AppNotification.fromMap(doc.id, doc.data())),
      ];

      final uniqueNotifications = <String, AppNotification>{};
      for (var notification in allNotifications) {
        uniqueNotifications[notification.id!] = notification;
      }
      return uniqueNotifications.values.toList();
    } catch (e) {
      print('AllNotificationsPage - Error loading notifications: $e');
      return [];
    }
  }

  Future<List<PlayDateRequest>> _loadPlayDateRequests() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('playDateRequests')
          .where('requestedUserId', isEqualTo: widget.currentUserId)
          .orderBy('requestDate', descending: true)
          .limit(10)
          .get();
      final currentTime = DateTime.now();
      return snapshot.docs
          .map((doc) => PlayDateRequest.fromFirestore(doc.id, doc.data()))
          .where((request) => request != null)
          .cast<PlayDateRequest>()
          .where((request) => request.scheduledDateTime?.isAfter(currentTime) == true)
          .toList();
    } catch (e) {
      print('AllNotificationsPage - Error loading playdate requests: $e');
      return [];
    }
  }

  Future<String?> _findLostDogId(String name, String body) async {
    try {
      final coordinatesMatch = RegExp(r'near\s+([\d.]+),\s+([\d.]+)').firstMatch(body);
      if (coordinatesMatch == null) {
        print('AllNotificationsPage - No coordinates found in body: $body');
        return null;
      }
      final latitude = double.tryParse(coordinatesMatch.group(1)!) ?? 0.0;
      final longitude = double.tryParse(coordinatesMatch.group(2)!) ?? 0.0;

      final snapshot = await FirebaseFirestore.instance
          .collection('lost_dogs')
          .where('name', isEqualTo: name)
          .where('latitude', isEqualTo: latitude)
          .where('longitude', isEqualTo: longitude)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      } else {
        print('AllNotificationsPage - No matching lost dog found for name: $name, lat: $latitude, long: $longitude');
        return null;
      }
    } catch (e) {
      print('AllNotificationsPage - Error finding lostDogId: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.appTitle,
          style: TextStyle(
            color: Colors.yellow[700],
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
        backgroundColor: Colors.pink,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink, Colors.pinkAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.notifications,
                  style: TextStyle(
                    color: Color(0xFFFFC107),
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
              FutureBuilder<List<AppNotification>>(
                future: _notificationsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)));
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(
                          color: Color(0xFFFFC107),
                          fontFamily: 'Poppins',
                          height: 1.2,
                        ),
                      ),
                    );
                  }
                  final notifications = snapshot.data ?? [];
                  print('AllNotificationsPage - Loaded ${notifications.length} notifications');
                  if (notifications.isEmpty) {
                    return Container(
                      color: Colors.pink,
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          l10n.noNotifications,
                          style: TextStyle(
                            color: Color(0xFFFFC107),
                            fontFamily: 'Poppins',
                            height: 1.2,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final payload = notification.payload != null
                          ? Map<String, dynamic>.from(jsonDecode(notification.payload!))
                          : {};
                      print('Rendering notification ${notification.id}: title=${notification.title}, body=${notification.body}, payload=$payload');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12.0),
                          title: Text(
                            notification.title ?? '',
                            style: TextStyle(
                              color: Colors.yellow[700],
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.body ?? '',
                                style: TextStyle(
                                  color: Colors.pink[100],
                                  fontFamily: 'Poppins',
                                  height: 1.2,
                                ),
                              ),
                              Text(
                                DateFormat('yyyy-MM-dd – kk:mm').format(notification.timestamp),
                                style: TextStyle(
                                  color: Colors.pink[100]?.withOpacity(0.7),
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.yellow),
                            onPressed: () async {
                              print('AllNotificationsPage - Delete button pressed for notification ${notification.id}, mounted: $mounted');
                              if (!mounted) return;
                              try {
                                print('AllNotificationsPage - Attempting to delete notification ${notification.id}');
                                await FirebaseFirestore.instance
                                    .collection('notifications')
                                    .doc(notification.id)
                                    .delete();
                                print('AllNotificationsPage - Notification ${notification.id} deleted successfully');
                                if (mounted) {
                                  setState(() {
                                    _notificationsFuture = _loadNotifications();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Notification deleted')),
                                  );
                                }
                              } catch (e) {
                                print('AllNotificationsPage - Error deleting notification ${notification.id}: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error deleting notification: $e')),
                                  );
                                }
                              }
                            },
                          ),
                          onTap: () async {
                            if (!mounted) return;
                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(notification.id)
                                .update({'isRead': true});
                            print('AllNotificationsPage - Marked notification ${notification.id} as read');

                            String notificationType = payload['type']?.toString().toLowerCase() ?? '';
                            if (notificationType.isEmpty && (notification.title?.contains('Lost Dog') ?? false)) {
                              notificationType = 'lost_dog';
                            } else if (notificationType.isEmpty && (notification.title?.contains('Found Dog') ?? false)) {
                              notificationType = 'found_dog';
                            }

                            if (notificationType == 'playdate_request' || notificationType == 'playDateRequest') {
                              final targetUserId = payload['requesterUserId'] as String?;
                              print('AllNotificationsPage - PlayDateRequest navigation, targetUserId: $targetUserId');
                              if (targetUserId != null && targetUserId != widget.currentUserId && targetUserId.isNotEmpty) {
                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OtherUserDogPage(
                                        targetUserId: targetUserId,
                                        dogsList: widget.dogsList,
                                        favoriteDogs: widget.favoriteDogs ?? [],
                                        onToggleFavorite: widget.onToggleFavorite ?? (dog) {},
                                      ),
                                    ),
                                  );
                                  print('AllNotificationsPage - Navigated to OtherUserDogPage for userId: $targetUserId');
                                }
                              } else {
                                print('AllNotificationsPage - Invalid or missing requesterUserId: $targetUserId');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Cannot open user profile: Invalid or missing user ID')),
                                  );
                                }
                              }
                            } else if (notificationType == 'lost_dog') {
                              String? lostDogId = payload['lostDogId'] as String?;
                              print('AllNotificationsPage - Lost dog navigation, lostDogId: $lostDogId');

                              if (lostDogId == null || lostDogId.isEmpty) {
                                final nameMatch = RegExp(r'(\w+)\s*\(').firstMatch(notification.body ?? '');
                                final dogName = nameMatch?.group(1);
                                if (dogName != null && notification.body != null) {
                                  lostDogId = await _findLostDogId(dogName, notification.body!);
                                }
                              }

                              if (lostDogId != null && lostDogId.isNotEmpty) {
                                try {
                                  final doc = await FirebaseFirestore.instance
                                      .collection('lost_dogs')
                                      .doc(lostDogId)
                                      .get();
                                  if (doc.exists && mounted) {
                                    final lostDog = LostDog.fromMap(doc.data()!).copyWith(id: doc.id);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => LostDogDetailPage(lostDog: lostDog),
                                      ),
                                    );
                                    print('AllNotificationsPage - Navigated to LostDogDetailPage for lostDogId: $lostDogId');
                                  } else {
                                    print('AllNotificationsPage - No data found for lostDogId: $lostDogId');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('No details found for this lost dog')),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  print('AllNotificationsPage - Error fetching lost dog details: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error loading lost dog details: $e')),
                                    );
                                  }
                                }
                              } else {
                                print('AllNotificationsPage - Missing lostDogId in payload: $payload');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Missing lost dog ID in notification')),
                                  );
                                }
                              }
                            } else if (notificationType == 'found_dog') {
                              final foundDogId = payload['foundDogId'] as String?;
                              print('AllNotificationsPage - Found dog navigation, foundDogId: $foundDogId');
                              if (foundDogId != null && foundDogId.isNotEmpty) {
                                try {
                                  final doc = await FirebaseFirestore.instance
                                      .collection('found_dogs')
                                      .doc(foundDogId)
                                      .get();
                                  if (doc.exists && mounted) {
                                    final foundDog = FoundDog.fromMap(doc.data()!).copyWith(id: doc.id);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FoundDogDetailPage(foundDog: foundDog),
                                      ),
                                    );
                                    print('AllNotificationsPage - Navigated to FoundDogDetailPage for foundDogId: $foundDogId');
                                  } else {
                                    print('AllNotificationsPage - No data found for foundDogId: $foundDogId');
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('No details found for this found dog')),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  print('AllNotificationsPage - Error fetching found dog details: $e');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error loading found dog details: $e')),
                                    );
                                  }
                                }
                              } else {
                                print('AllNotificationsPage - Missing foundDogId in payload: $payload');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Missing found dog ID in notification')),
                                  );
                                }
                              }
                            } else if (notificationType == 'instant_notification') {
                              print('AllNotificationsPage - Instant notification opened: ${notification.title}');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Opened: ${notification.title}')),
                                );
                              }
                            } else {
                              print('AllNotificationsPage - Unsupported notification type: $notificationType');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Unsupported notification type: ${notificationType.isEmpty ? 'unknown' : notificationType}')),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.playdateRequests,
                  style: TextStyle(
                    color: Color(0xFFFFC107),
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
              FutureBuilder<List<PlayDateRequest>>(
                future: _requestsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFFC107)));
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(
                          color: Color(0xFFFFC107),
                          fontFamily: 'Poppins',
                          height: 1.2,
                        ),
                      ),
                    );
                  }
                  final requests = snapshot.data ?? [];
                  print('AllNotificationsPage - Loaded ${requests.length} playdate requests');
                  for (var request in requests) {
                    print('Request ${request.requestId}: status=${request.status}, scheduledDateTime=${request.scheduledDateTime}, requesterDog=${request.requesterDog.name}, requestedDog=${request.requestedDog.name}, location=${request.location}');
                  }
                  if (requests.isEmpty) {
                    return Container(
                      color: Colors.pink,
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          l10n.noPlaydateRequests,
                          style: TextStyle(
                            color: Color(0xFFFFC107),
                            fontFamily: 'Poppins',
                            height: 1.2,
                          ),
                        ),
                      ),
                    );
                  }
                  return SizedBox(
                    width: double.infinity,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: requests.length,
                      separatorBuilder: (context, index) => const Divider(color: Color(0xFFFFC107), thickness: 1.0),
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        print('AllNotificationsPage - Rendering request ${request.requestId}, status: ${request.status}');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          child: Card(
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            color: Colors.pink[50],
                            child: InkWell(
                              onTap: () {
                                if (request.requesterUserId != widget.currentUserId && request.requesterUserId.isNotEmpty && mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OtherUserDogPage(
                                        targetUserId: request.requesterUserId,
                                        dogsList: widget.dogsList,
                                        favoriteDogs: widget.favoriteDogs ?? [],
                                        onToggleFavorite: widget.onToggleFavorite ?? (dog) {},
                                      ),
                                    ),
                                  );
                                  print('AllNotificationsPage - Navigated to OtherUserDogPage for playdate request: ${request.requestId}');
                                } else {
                                  print('AllNotificationsPage - Invalid or missing requesterUserId for playdate request: ${request.requestId}');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Cannot open user profile: Invalid or missing user ID')),
                                    );
                                  }
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${request.requesterDog.name} wants to play with ${request.requestedDog.name}!',
                                      style: TextStyle(
                                        color: Colors.pink[900],
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Scheduled: ${request.scheduledDateTime != null ? DateFormat('yyyy-MM-dd – kk:mm').format(request.scheduledDateTime!) : 'Not scheduled'}',
                                      style: TextStyle(
                                        color: Colors.pink[700],
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        height: 1.2,
                                      ),
                                    ),
                                    if (request.location != null) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Location: ${request.location}',
                                              style: TextStyle(
                                                color: Colors.pink[700],
                                                fontFamily: 'Poppins',
                                                fontSize: 14,
                                                height: 1.2,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.map, color: Color(0xFF880E4F)),
                                            onPressed: () {
                                              if (request.location != null) {
                                                final parts = request.location!.split(', ');
                                                final lat = double.tryParse(parts[0].replaceAll('Lat: ', '')) ?? 0.0;
                                                final lng = double.tryParse(parts[1].replaceAll('Long: ', '')) ?? 0.0;
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => MapPickerPage(
                                                      initialLocation: LatLng(lat, lng),
                                                    ),
                                                  ),
                                                );
                                                print('AllNotificationsPage - Navigated to MapPickerPage for location: ${request.location}');
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (request.status == 'pending') ...[
                                          Flexible(
                                            fit: FlexFit.loose,
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 4.0),
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  if (!mounted) return;
                                                  try {
                                                    print('AllNotificationsPage - Accepting request with ID: ${request.requestId}');
                                                    final callable = FirebaseFunctions.instanceFor(region: 'europe-west3').httpsCallable('updatePlayDateRequestStatusV2');
                                                    await callable.call({
                                                      'requestId': request.requestId,
                                                      'status': 'accepted',
                                                      'requesterUserId': request.requesterUserId,
                                                      'requestedUserId': request.requestedUserId,
                                                    });
                                                    await FirebaseFirestore.instance.collection('playDates').add(request.toMap()..['status'] = 'accepted');

                                                    final notificationService = NotificationService();
                                                    final reminderTime = request.scheduledDateTime!.subtract(const Duration(hours: 2));
                                                    if (reminderTime.isAfter(DateTime.now())) {
                                                      await notificationService.scheduleReminderNotification(
                                                        id: request.requestId,
                                                        scheduledTime: reminderTime,
                                                        title: 'Playdate Reminder',
                                                        body: 'Your playdate with ${request.requesterDog.name} is starting in 2 hours!',
                                                      );
                                                      print('AllNotificationsPage - Reminder scheduled for ${request.requestId} at $reminderTime');
                                                    } else {
                                                      print('AllNotificationsPage - Reminder time $reminderTime is in the past, skipping scheduling');
                                                    }

                                                    if (mounted) {
                                                      setState(() {
                                                        _requestsFuture = _loadPlayDateRequests();
                                                      });
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Request accepted and added to playdates')),
                                                      );
                                                    }
                                                  } catch (e) {
                                                    print('AllNotificationsPage - Error accepting request: $e');
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Error accepting request: $e')),
                                                      );
                                                    }
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(80, 36),
                                                ),
                                                child: const Text('Accept', style: TextStyle(fontFamily: 'Poppins')),
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            fit: FlexFit.loose,
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 4.0),
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  if (!mounted) return;
                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Reject Confirmation'),
                                                      content: const Text('Are you sure you want to reject this request?'),
                                                      actions: [
                                                        TextButton(
                                                          child: const Text('Cancel'),
                                                          onPressed: () => Navigator.pop(context, false),
                                                        ),
                                                        TextButton(
                                                          child: const Text('Reject'),
                                                          onPressed: () => Navigator.pop(context, true),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirmed == true && mounted) {
                                                    try {
                                                      print('AllNotificationsPage - Rejecting request with ID: ${request.requestId}');
                                                      final callable = FirebaseFunctions.instanceFor(region: 'europe-west3').httpsCallable('updatePlayDateRequestStatusV2');
                                                      await callable.call({
                                                        'requestId': request.requestId,
                                                        'status': 'rejected',
                                                        'requesterUserId': request.requesterUserId,
                                                        'requestedUserId': request.requestedUserId,
                                                      });
                                                      if (mounted) {
                                                        setState(() {
                                                          _requestsFuture = _loadPlayDateRequests();
                                                        });
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Request rejected')),
                                                        );
                                                      }
                                                    } catch (e) {
                                                      print('AllNotificationsPage - Error rejecting request: $e');
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Error rejecting request: $e')),
                                                        );
                                                      }
                                                    }
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(80, 36),
                                                ),
                                                child: const Text('Reject', style: TextStyle(fontFamily: 'Poppins')),
                                              ),
                                            ),
                                          ),
                                        ] else ...[
                                          Flexible(
                                            fit: FlexFit.loose,
                                            child: Text(
                                              'Status: ${request.status ?? 'unknown'}',
                                              style: TextStyle(
                                                color: Colors.pink[700],
                                                fontFamily: 'Poppins',
                                                fontStyle: FontStyle.italic,
                                                height: 1.2,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
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
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}