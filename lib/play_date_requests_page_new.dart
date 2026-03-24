import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import 'dog.dart';
import 'play_date_request.dart';
import 'l10n/app_localizations.dart';
import 'package:barky_matches_fixed/app_state.dart';

import 'dog_card.dart';
import 'package:collection/collection.dart';

import 'package:cloud_functions/cloud_functions.dart';




class PlayDateRequestsPageNew extends StatefulWidget {
  final List<Dog> dogsList;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;
 


  /// اگر از notification باز شده باشد
  final String? initialRequestId;

  /// برای مصرف ONE-SHOT requestId در AppState
  final VoidCallback? onConsumedInitialRequest;

  const PlayDateRequestsPageNew({
    super.key,
    required this.dogsList,
    required this.favoriteDogs,
    required this.onToggleFavorite,
    this.initialRequestId,
    this.onConsumedInitialRequest,
  });

  @override
  State<PlayDateRequestsPageNew> createState() =>
      _PlayDateRequestsPageNewState();
}

class _PlayDateRequestsPageNewState extends State<PlayDateRequestsPageNew> {

   final Map<String, GlobalKey> _itemKeys = {};

bool _initialRequestConsumed = false;

String _formatPlaydateDate(DateTime date) {
  return DateFormat('EEEE, MMM d • HH:mm').format(date);
}

String? _notificationRequestId;

StreamSubscription<QuerySnapshot>? _remindersSub;
final Set<String> _myReminders = {};




AppState? _appState;

  Stream<List<PlayDateRequest>>? _requestsStream;
  String? currentUserId;

bool _isFirstSnapshot = true;
//bool _isDirectFromNotification = false;

  bool _isUpdating = false;
  final Set<String> _lockedRequestIds = {};

  int _unreadNotificationsCount = 0;
  StreamSubscription<QuerySnapshot>? _notificationsSub;

  //bool _handledInitialRequest = false;

  //PlayDateRequest? _localRequest; // برای ذخیره وضعیت محلی در notification مستقیم

  @override
void didChangeDependencies() {
  super.didChangeDependencies();
  _appState = Provider.of<AppState>(context, listen: false);
}

  @override
void initState() {
  super.initState();

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint('❌ PlayDateRequestsPageNew: user not logged in');
    return;
  }

  currentUserId = user.uid;
  _remindersSub = FirebaseFirestore.instance
    .collection('playdate_reminders')
    .where('userId', isEqualTo: currentUserId)
    .snapshots()
    .listen((snap) {

  if (!mounted) return;

  setState(() {
    _myReminders.clear();
    for (final doc in snap.docs) {
      _myReminders.add(
        '${doc['requestId']}_${doc['minutesBefore']}',
      );
    }
  });

});
  // 🔔 unread notifications counter
  _notificationsSub = FirebaseFirestore.instance
    .collection('notifications')
    .where('recipientUserId', isEqualTo: currentUserId)
    .where('isRead', isEqualTo: false)
    .snapshots()
    .listen((snap) {

  if (!mounted) return;
  if (FirebaseAuth.instance.currentUser == null) return;

  setState(() {
    _unreadNotificationsCount = snap.docs.length;
  });

});

  final appState = Provider.of<AppState>(context, listen: false);

  //final requestId = widget.initialRequestId;

//_notificationRequestId = widget.initialRequestId;
if (_notificationRequestId == null) {
  _notificationRequestId = widget.initialRequestId;
}


final requestId = _notificationRequestId;


if (requestId != null && requestId.isNotEmpty) {
  debugPrint("🔥 initState: notification mode → requestId=$requestId");

  _requestsStream = FirebaseFirestore.instance
      .collection('playDateRequests')
      .doc(requestId)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) {
      debugPrint("❌ Notification request not found: $requestId");
      return <PlayDateRequest>[];
    }

    final request = PlayDateRequest.fromFirestore(
      doc.id,
      doc.data() as Map<String, dynamic>,
    );

    debugPrint("✅ Notification request loaded → status=${request.status}");

    
   // WidgetsBinding.instance.addPostFrameCallback((_) {
  //final appState = context.read<AppState>();
  //appState.clearInitialPlaydateRequest();
//});


    return [request];
  });

  return; // ⛔ خیلی مهم — نره pending mode
}

//WidgetsBinding.instance.addPostFrameCallback((_) {
  //context.read<AppState>().clearInitialPlaydateRequest();
//});


  /*
final requestId = appState.initialPlaydateRequestId;

  _isDirectFromNotification = requestId != null && requestId.isNotEmpty;

  if (_isDirectFromNotification) {
    debugPrint("→ initState: from notification → requestId=$requestId");

    


    // برای notification نتیجه (accepted/rejected)، دستی لود کن تا گیر نکنه
    _loadRequestManually(requestId!);
  //_consumeAfterFrame();  // ✅ اینجا

    // ✅ consume ONE-SHOT در AppState
//WidgetsBinding.instance.addPostFrameCallback((_) {
  //widget.onConsumedInitialRequest?.call();
//});

    // stream رو هم نگه دار (برای آپدیت زنده اگر لازم شد)
    _requestsStream = FirebaseFirestore.instance
        .collection('playDateRequests')
        .doc(requestId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        debugPrint("→ Request doc not found or empty: $requestId");
        return [PlayDateRequest.deleted(requestId)];
      }

      final data = doc.data() as Map<String, dynamic>;
      debugPrint("→ Single request loaded (stream): status=${data['status']}");

      // اگر stream data آورد، _localRequest رو آپدیت کن
      if (!mounted) return [];

setState(() {
  _localRequest = PlayDateRequest.fromFirestore(doc.id, data);
});


      return [PlayDateRequest.fromFirestore(doc.id, data)];
    });

    return;
  }
  */

  // حالت عادی (pending list)
  debugPrint("→ initState: normal pending mode");
  

if (user == null) {
  _requestsStream = const Stream.empty();
} else {
  _requestsStream = FirebaseFirestore.instance
      .collection('playDateRequests')
      .where('requestedUserId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) {
    final list = snap.docs.map((doc) {
      return PlayDateRequest.fromFirestore(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
    }).toList();

    debugPrint("→ Loaded ${list.length} pending requests");
    return list;
  });
}
}
  @override
void dispose() {
  _notificationsSub?.cancel();
  _remindersSub?.cancel();
  super.dispose();
}
void _consumeAfterFrame() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    Future.microtask(() {
      if (!mounted) return;
     // widget.onConsumedInitialRequest?.call();
    });
  });
}

/*
  Future<void> _loadRequestManually(String requestId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('playDateRequests')
        .doc(requestId)
        .get();

    // 🔒 اگر ویجت dispose شده باشد، ادامه نده
    if (!mounted) return;

    if (doc.exists && doc.data() != null) {
      final request = PlayDateRequest.fromFirestore(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );

      setState(() {
        _localRequest = request;
      });

      debugPrint(
        "→ Manual load success: status=${request.status}",
      );
    } else {
      debugPrint("→ Manual load: doc not found");

      setState(() {
        _localRequest = PlayDateRequest.deleted(requestId);
      });
    }
  } catch (e) {
    debugPrint("→ Manual load failed: $e");

    // 🔒 باز هم قبل از setState چک کن
    if (!mounted) return;

    setState(() {
      _localRequest = PlayDateRequest.deleted(requestId);
    });
  }
}
*/

@override
void didUpdateWidget(covariant PlayDateRequestsPageNew oldWidget) {
  super.didUpdateWidget(oldWidget);

  final newId = widget.initialRequestId;

  // اگر requestId جدید آمد، برو notification mode (همون کاری که initState می‌کرد)
 if (newId != null && newId.isNotEmpty) {
    debugPrint("🟣 didUpdateWidget: notification id received → $newId");
    setState(() {
      _notificationRequestId = newId;

      _requestsStream = FirebaseFirestore.instance
          .collection('playDateRequests')
          .doc(newId)
          .snapshots()
          .map((doc) {
        if (!doc.exists || doc.data() == null) return <PlayDateRequest>[];
        final req = PlayDateRequest.fromFirestore(
          doc.id,
          doc.data() as Map<String, dynamic>,
        );
        debugPrint("✅ Notification request loaded → status=${req.status}");
        return [req];
      });
    });
    return;
  }

  // ✅ اصل فیکس: sticky notification mode
  if ((newId == null || newId.isEmpty) &&
      _notificationRequestId != null &&
      _notificationRequestId!.isNotEmpty) {
    debugPrint("🛑 didUpdateWidget: ignore null initialRequestId (sticky)");
    return;
  }
}


void _switchToPendingMode() {
  if (currentUserId == null || currentUserId!.isEmpty) return;

  // 🛑 اگر در حالت notification / reminder هستیم، سوییچ نکن
  if (_notificationRequestId != null) {
    debugPrint('🛑 Skip switching to pending mode (notification active)');
    return;
  }

  debugPrint('🟣 Switching back to normal pending list mode');

  _requestsStream = FirebaseFirestore.instance
      .collection('playDateRequests')
      .where('requestedUserId', isEqualTo: currentUserId)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) {
    final list = snap.docs.map((doc) {
      return PlayDateRequest.fromFirestore(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
    }).toList();

    debugPrint("→ Loaded ${list.length} pending requests");
    return list;
  });
}


  // ─────────────────────────────────────────────
  // ACTION: accept / reject
  // ─────────────────────────────────────────────

  Future<void> _setRequestStatus({
  required String requestId,
  required String status,
  required String requesterUserId,
  required String requestedUserId,
  required String requesterDogId,
  required String requestedDogId,
  required String requesterDogName,
  required String requestedDogName,
}) async {
  if (_lockedRequestIds.contains(requestId)) return;

  if (!_initialRequestConsumed &&
      widget.initialRequestId == requestId) {
    _initialRequestConsumed = true;
  }

  setState(() {
    _isUpdating = true;
    _lockedRequestIds.add(requestId);
  });

  final loc = AppLocalizations.of(context)!;

  try {
    debugPrint('🔥 START $status');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    await user.reload();
    final idToken = await user.getIdToken();

    final functionName =
        status == 'accepted'
            ? 'acceptPlayDateRequestHttp'
            : 'rejectPlayDateRequestHttp';

    final url = Uri.parse(
      'https://europe-west3-barkymatches-new.cloudfunctions.net/$functionName',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'requestId': requestId,
        'status': status,
        'requesterUserId': requesterUserId,
        'requestedUserId': requestedUserId,
        'requesterDogId': requesterDogId,
        'requestedDogId': requestedDogId,
        'requesterDogName': requesterDogName,
        'requestedDogName': requestedDogName,
      }),
    );

    debugPrint('✅ HTTP ${response.statusCode}');
    debugPrint('✅ BODY: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.body}');
    }

    debugPrint('✅ $status Success');

    
//if (widget.initialRequestId != null) {
  //context.read<AppState>().clearInitialPlaydateRequest();
//}

if (widget.initialRequestId != null &&
    _notificationRequestId == null) {
  context.read<AppState>().clearInitialPlaydateRequest();
}


// ✅ اگر این کاربر REQUESTED است (یعنی گیرنده درخواست بوده)
// بعد از accept/reject باید برگرده به لیست pending
final bool iAmRequestedUser = (currentUserId == requestedUserId);

if (iAmRequestedUser) {
  setState(() {
    _switchToPendingMode();
  });
} else {
  // ✅ اگر REQUESTER هست (درخواست‌دهنده)
  // همون notification mode بمونه تا Reminder card رو ببینه
  setState(() {});
}


    setState(() {});
  } catch (e) {
    debugPrint('❌ ERROR in _setRequestStatus: $e');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.errorRespondingToRequestUnexpected(e.toString()),
          ),
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isUpdating = false;
      });
    }
  }
}

// ─────────────────────────────────────────────
// ACTION: create reminder
// ─────────────────────────────────────────────
Future<void> _createReminder(
  String requestId,
  int minutesBefore,
) async {
  try {
    debugPrint('⏰ Calling createPlaydateReminder');
debugPrint("🌐 Firestore network enabled test...");
await FirebaseFirestore.instance.enableNetwork();
debugPrint("🌐 Firestore network forced ON");

    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west3',
    ).httpsCallable('createPlaydateReminder');

    final result = await callable.call({
      'requestId': requestId,
      'minutesBefore': minutesBefore,
    });

    debugPrint('✅ Reminder created: ${result.data}');

    setState(() {
  _myReminders.add('${requestId}_$minutesBefore');
});

debugPrint("🔥 FUNCTION RESULT = ${result.data}");
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder set for $minutesBefore minutes before 🐾',
        ),
      ),
    );
  } catch (e) {
    debugPrint('❌ Failed to create reminder: $e');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to set reminder ❌'),
      ),
    );
  }
}



  Future<bool> _confirmRejectDialog() async {
    final loc = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.rejectConfirmation),
        content: Text(loc.areYouSure),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.reject),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Map<String, dynamic>? _parseLocation(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  Future<String> _loadDogName(String dogId) async {
    final snap =
        await FirebaseFirestore.instance.collection('dogs').doc(dogId).get();
    return snap.data()?['name'] ?? '';
  }



  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  Widget _buildRequestCard(PlayDateRequest request) {

    final bool isRequester = currentUserId == request.requesterUserId;
final bool isRequested = currentUserId == request.requestedUserId;

    final loc = AppLocalizations.of(context)!;
    final locationMap = _parseLocation(request.location);

    final isReceiver = currentUserId == request.requestedUserId;
    final canSeeReminder = request.status == 'accepted';
    final isFromNotification = _notificationRequestId != null &&
    _notificationRequestId!.isNotEmpty;


    if ((request.status == 'accepted' || request.status == 'rejected') 
    && currentUserId == request.requesterUserId) {
    
    // اگر از notification آمده و pending نیست، باز هم نمایش بده
    //if (isFromNotification && request.status != 'pending') {
  return Card(
    margin: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    color: const Color(0xFF9E1B4F),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 🔑 خیلی مهم
        children: [
          Icon(
            request.status == 'accepted'
                ? Icons.favorite
                : Icons.heart_broken,
            color: request.status == 'accepted'
                ? Colors.greenAccent
                : Colors.orangeAccent,
            size: 42,
          ),
          const SizedBox(height: 12),

          /// ───────────────── Tabs Section ─────────────────
          

          const SizedBox(height: 16),

          /// ───────────────── Status Text ─────────────────
          Text(
            request.status == 'accepted'
                ? 'Playdate Accepted 🐾'
                : 'Playdate Not This Time',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            request.status == 'accepted'
                ? '${request.requestedDog.name} accepted your playdate request.\n'
                  'Be happy — a tail-wagging meeting awaits! 🐶💖'
                : '${request.requestedDog.name} couldn’t accept this time.\n'
                  'No worries — try again and keep the paws moving 🐾',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

    // در حالت normal فقط pending نمایش داده بشه
    //if (!isFromNotification && request.status != 'pending') {
      //return const SizedBox.shrink();
    //}

    final scheduledText = request.scheduledDateTime != null
        ? DateFormat('yyyy-MM-dd – HH:mm')
  .format(request.scheduledDateTime!.toLocal())

        : loc.notScheduled;

    final isLocked =
        _isUpdating || _lockedRequestIds.contains(request.requestId);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF9E1B4F),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: _loadDogName(request.requesterDogId),
              builder: (context, snap1) {
                if (!snap1.hasData) {
                  return const SizedBox(
                    height: 18,
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }

                return FutureBuilder<String>(
                  future: _loadDogName(request.requestedDogId),
                  builder: (context, snap2) {
                    if (!snap2.hasData) {
                      return const SizedBox(
                        height: 18,
                        child: LinearProgressIndicator(minHeight: 2),
                      );
                    }

                    return Text(
                      loc.playdateRequestMessage(
                        snap1.data!,
                        snap2.data!,
                      ),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 6),
            Text(
              '${loc.scheduledLabel} $scheduledText',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),

            if (canSeeReminder) ...[
  const SizedBox(height: 12),

  DefaultTabController(
    length: 2,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.pets), text: 'Dog'),
            Tab(icon: Icon(Icons.alarm), text: 'Reminder'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 260,
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildDogTab(request),
              _buildAlarmTab(request),
            ],
          ),
        ),
      ],
    ),
  ),
],


            if (locationMap != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.location_on, color: Colors.white),
                label: Text(
                  locationMap['text'] ?? 'View location',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                onPressed: () async {
                  final lat = locationMap['lat'];
                  final lng = locationMap['lng'];
                  final text = locationMap['text'];

                  Uri uri;

                  if (lat != null && lng != null) {
                    uri = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                    );
                  } else if (text != null) {
                    uri = Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(text)}',
                    );
                  } else {
                    return;
                  }

                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],

            const SizedBox(height: 12),

            if (isReceiver && request.status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLocked
                          ? null
                          : () => _setRequestStatus(
                                requestId: request.requestId,
                                status: 'accepted',
                                requesterUserId: request.requesterUserId,
                                requestedUserId: request.requestedUserId ?? '',
                                requesterDogId: request.requesterDogId,
                                requestedDogId: request.requestedDogId,
                                requesterDogName: request.requesterDog.name,
                                requestedDogName: request.requestedDog.name,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(loc.accept, style: GoogleFonts.poppins()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLocked
                          ? null
                          : () async {
                              final ok = await _confirmRejectDialog();
                              if (!ok) return;

                              await _setRequestStatus(
                                requestId: request.requestId,
                                status: 'rejected',
                                requesterUserId: request.requesterUserId,
                                requestedUserId: request.requestedUserId ?? '',
                                requesterDogId: request.requesterDogId,
                                requestedDogId: request.requestedDogId,
                                requesterDogName: request.requesterDog.name,
                                requestedDogName: request.requestedDog.name,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(loc.reject, style: GoogleFonts.poppins()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            Text(
              '${loc.status}: ${request.status}',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaydateBody(BuildContext context) {
  final loc = AppLocalizations.of(context)!;

  return Container(
    color: const Color(0xFFFFF6F8),
    child: StreamBuilder<List<PlayDateRequest>>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              loc.errorLoadingRequestsStream(
                snapshot.error.toString(),
              ),
              style: GoogleFonts.poppins(),
            ),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Text(
              loc.noPlaydateRequests,
              style: GoogleFonts.poppins(),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (_, i) {
            final request = requests[i];

            _itemKeys.putIfAbsent(
              request.requestId,
              () => GlobalKey(),
            );

            if (request.requestId == _notificationRequestId) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) {
                final ctx = _itemKeys[
                        request.requestId]
                    ?.currentContext;

                if (ctx != null) {
                  Scrollable.ensureVisible(
                    ctx,
                    duration: const Duration(
                        milliseconds: 400),
                  );
                }
              });
            }

            return Container(
              key: _itemKeys[request.requestId],
              child:
                  _buildRequestCard(request),
            );
          },
        );
      },
    ),
  );
}


  @override
Widget build(BuildContext context) {
debugPrint("PlayDateRequestsPageNew build → notificationRequestId=$_notificationRequestId");


  if (_requestsStream == null || currentUserId == null) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
  return _buildPlaydateBody(context);
}


Widget _buildAlarmTab(PlayDateRequest request) {
 final bool hasSchedule = request.scheduledDateTime != null;
final bool reminder30Set =
    _myReminders.contains('${request.requestId}_30');
final bool reminder60Set =
    _myReminders.contains('${request.requestId}_60');


  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // 📅 Playdate time info
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          hasSchedule
              ? '📅 ${_formatPlaydateDate(request.scheduledDateTime!)}'
              : '⏳ Playdate time not scheduled yet',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),

      // ⏰ 30 minutes before
      ElevatedButton.icon(
        onPressed: hasSchedule && !reminder30Set
    ? () => _createReminder(request.requestId, 30)
    : null,

        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          minimumSize: const Size(220, 48),
          disabledBackgroundColor: Colors.grey.shade400,
        ),
        icon: const Icon(Icons.alarm),
        label: Text(
  reminder30Set
      ? 'Reminder set ✅'
      : '30 minutes before',
),

      ),

      const SizedBox(height: 12),

      // ⏰ 1 hour before
      ElevatedButton.icon(
        onPressed: hasSchedule && !reminder60Set
    ? () => _createReminder(request.requestId, 60)
    : null,

        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          minimumSize: const Size(220, 48),
          disabledBackgroundColor: Colors.grey.shade400,
        ),
        icon: const Icon(Icons.alarm),
        label: Text(
  reminder60Set
      ? 'Reminder set ✅'
      : '1 hour before',
),

      ),
    ],
  );
}

Widget _buildDogTab(PlayDateRequest request) {
  // 1️⃣ resolve Dog واقعی از dogsList
  final Dog? realDog = widget.dogsList.firstWhereOrNull(
    (d) => d.id == request.requesterDogId,
  );

  // 2️⃣ اگر هنوز Dog لود نشده، loader نشون بده
  if (realDog == null) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }

  // 3️⃣ DogCard فقط با Dog واقعی
  return ConstrainedBox(
    constraints: const BoxConstraints(
      maxHeight: 220, // 👈 200–230 هم می‌تونی تست کنی
    ),
    child: SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: DogCard(
        dog: realDog, // ✅ مهم: NOT request.requesterDog
        allDogs: widget.dogsList,
        currentUserId: currentUserId!,
        favoriteDogs: widget.favoriteDogs,
        onToggleFavorite: widget.onToggleFavorite,
        likers: const [],

        // 🔒 Playdate-only mode
        showDogSelection: false,
        enableChat: true,
        enableLike: false,
        enableNavigation: false,
        enableEdit: false,
        enablePlaydate: false,
        mode: DogCardMode.playdate,
      ),
    ),
  );
}

}