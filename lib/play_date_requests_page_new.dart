import 'dart:async';
import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:barky_matches_fixed/play_date_request.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:barky_matches_fixed/notification_model.dart';
import 'package:barky_matches_fixed/firebase_options.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';


Future<void> ensureFirebase() async {
  if (Firebase.apps.isEmpty) {
    print('Initializing Firebase...');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
    print('Firebase initialized successfully');
  }
}

class PlayDateRequestsPageNew extends StatefulWidget {
  final List<Dog> dogsList;
  final List<Dog> favoriteDogs;
  final Function(Dog) onToggleFavorite;
  final String? initialRequestId;

  const PlayDateRequestsPageNew({
    super.key,
    required this.dogsList,
    required this.favoriteDogs,
    required this.onToggleFavorite,
    this.initialRequestId,
  });

  @override
  State<PlayDateRequestsPageNew> createState() => _PlayDateRequestsPageNewState();
}

class _PlayDateRequestsPageNewState extends State<PlayDateRequestsPageNew> {
  String? selectedRequesterDogId;
  String? selectedRequestedDogId;
  final NotificationService _notificationService = NotificationService();
  late List<PlayDateRequest> requests;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    requests = [];
    _initializeAndLoadRequests();
    if (widget.initialRequestId != null) {
      print('PlayDateRequestsPageNew - Loading initial request with ID: ${widget.initialRequestId}');
      _loadSpecificRequest(widget.initialRequestId!);
    }
  }

  Future<void> _initializeAndLoadRequests() async {
    try {
      await ensureFirebase();
      await _notificationService.init();
      print('NotificationService initialized');
      await _loadRequests();
    } catch (e) {
      print('Error initializing or loading requests: $e');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorInitializingOrLoadingRequests(e.toString()))),
        );
      }
    }
  }

  Future<void> _loadRequests() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) {
      print('PlayDateRequestsPageNew - No user logged in');
      return;
    }

    try {
      final requesterSnapshot = await FirebaseFirestore.instance
          .collection('playDateRequests')
          .where('requesterUserId', isEqualTo: currentUserId)
          .limit(10)
          .get();
      final requestedSnapshot = await FirebaseFirestore.instance
          .collection('playDateRequests')
          .where('requestedUserId', isEqualTo: currentUserId)
          .limit(10)
          .get();

      print('PlayDateRequestsPageNew - Requester snapshot docs: ${requesterSnapshot.docs.length}');
      print('PlayDateRequestsPageNew - Requested snapshot docs: ${requestedSnapshot.docs.length}');
      print('PlayDateRequestsPageNew - Requester snapshot data: ${requesterSnapshot.docs.map((doc) => doc.data()).toList()}');
      print('PlayDateRequestsPageNew - Requested snapshot data: ${requestedSnapshot.docs.map((doc) => doc.data()).toList()}');

      final allDocs = <dynamic>{...requesterSnapshot.docs, ...requestedSnapshot.docs}.toList();
      final loadedRequests = allDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) {
          print('PlayDateRequestsPageNew - Skipping null data for request: ${doc.id}');
          return null;
        }
        print('PlayDateRequestsPageNew - Processing request: ${doc.id}, data: $data');
        if (data['requesterDog'] == null ||
            data['requestedDog'] == null ||
            data['requesterDog']['id'] == null ||
            data['requesterDog']['ownerId'] == null ||
            data['requestedDog']['id'] == null ||
            data['requestedDog']['ownerId'] == null ||
            data['requesterUserId'] == null ||
            data['requestedUserId'] == null) {
          print('PlayDateRequestsPageNew - Skipping invalid request: ${doc.id}, data: $data');
          return null;
        }
        try {
          return PlayDateRequest.fromFirestore(doc.id, data);
        } catch (e) {
          print('PlayDateRequestsPageNew - Error parsing request ${doc.id}: $e');
          return null;
        }
      }).whereType<PlayDateRequest>().toList();

      if (mounted) {
        setState(() {
          requests = loadedRequests;
          print('Loaded ${requests.length} requests for user $currentUserId');
        });
      }
    } catch (e) {
      print('Error loading requests: $e');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingRequests(e.toString()))),
        );
      }
    }
  }

  Future<void> _loadSpecificRequest(String requestId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('playDateRequests')
          .doc(requestId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data == null) {
          print('PlayDateRequestsPageNew - Skipping null data for request: ${doc.id}');
          return;
        }
        print('PlayDateRequestsPageNew - Loading specific request: ${doc.id}, data: $data');
        if (data['requesterDog'] == null ||
            data['requestedDog'] == null ||
            data['requesterDog']['id'] == null ||
            data['requesterDog']['ownerId'] == null ||
            data['requestedDog']['id'] == null ||
            data['requestedDog']['ownerId'] == null ||
            data['requesterUserId'] == null ||
            data['requestedUserId'] == null) {
          print('PlayDateRequestsPageNew - Skipping invalid request: ${doc.id}');
          return;
        }
        try {
          final request = PlayDateRequest.fromFirestore(doc.id, data);
          print('Found request: ${request.toString()}');
          setState(() {
            if (!requests.any((r) => r.requestId == request.requestId)) {
              requests.add(request);
            }
          });
        } catch (e) {
          print('PlayDateRequestsPageNew - Error parsing request ${doc.id}: $e');
        }
      } else {
        print('Request with ID $requestId not found');
      }
    } catch (e) {
      print('Error loading specific request: $e');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorLoadingSpecificRequest(e.toString()))),
        );
      }
    }
  }

  Future<void> _createPlayDateRequest() async {
    print('DogsList in PlayDateRequestsPageNew: ${widget.dogsList.map((dog) => 'Name: ${dog.name}, ID: ${dog.id}, OwnerId: ${dog.ownerId}').toList()}');
    print('CurrentUserId: ${FirebaseAuth.instance.currentUser?.uid}');
    print('SelectedRequesterDogId: $selectedRequesterDogId');
    print('SelectedRequestedDogId: $selectedRequestedDogId');

    if (selectedRequesterDogId == null || selectedRequestedDogId == null) {
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectBothDogs)),
      );
      return;
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) {
      print('PlayDateRequestsPageNew - No user logged in');
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseLoginToCreateRequest)),
      );
      return;
    }

    final requesterDog = widget.dogsList.firstWhere(
      (dog) => dog.ownerId == currentUserId && dog.id == selectedRequesterDogId,
      orElse: () => throw Exception('Selected requester dog not found: $selectedRequesterDogId'),
    );

    final requestedDog = widget.dogsList.firstWhere(
      (dog) => dog.ownerId != currentUserId && dog.id == selectedRequestedDogId,
      orElse: () => throw Exception('Selected requested dog not found: $selectedRequestedDogId'),
    );

    String? requesterName = 'Unknown User';
    try {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      requesterName = userData.exists ? (userData.data()?['username']?.toString() ?? 'Unknown User') : 'Unknown User';
      print('PlayDateRequestsPageNew - Fetched requesterName: $requesterName for userId: $currentUserId');
    } catch (e) {
      print('PlayDateRequestsPageNew - Error fetching requesterName: $e');
    }

    final String? selectedDogOwnerId = requestedDog.ownerId;

    final newRequest = PlayDateRequest(
      requestId: '',
      requesterUserId: FirebaseAuth.instance.currentUser!.uid,
      requestedUserId: selectedDogOwnerId,
      requesterDog: requesterDog,
      requestedDog: requestedDog,
      status: 'pending',
      requestDate: DateTime.now(),
      scheduledDateTime: DateTime.now().add(const Duration(days: 1)),
      requesterName: requesterName,
      message: AppLocalizations.of(context)!.playdateRequestMessage(requesterDog.name, requestedDog.name),
      location: 'Lat: 41.0103, Long: 28.6724',
    );

    print('Creating request with requesterDog: ${newRequest.requesterDog.name}, ID: ${newRequest.requesterDog.id}, requestedDog: ${newRequest.requestedDog.name}, ID: ${newRequest.requestedDog.id}');
    print('requesterUserId: ${newRequest.requesterUserId}');
    print('requestedUserId: ${newRequest.requestedUserId}');

    final printableRequest = newRequest.toMap();
    printableRequest['requestDate'] = newRequest.requestDate != null ? Timestamp.fromDate(newRequest.requestDate!) : null;
    printableRequest['scheduledDateTime'] = newRequest.scheduledDateTime != null ? Timestamp.fromDate(newRequest.scheduledDateTime!) : null;

    print('🔥 Creating playdate request 🔥');
    print('currentUserId: $currentUserId');
    print('newRequest: ${jsonEncode(printableRequest)}');

    try {
      final docRef = await FirebaseFirestore.instance.collection('playDateRequests').add(printableRequest);
      print('✅ Request created with ID: ${docRef.id}');

      final localizations = AppLocalizations.of(context)!;
      await _notificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: localizations.newPlayDateRequestTitle,
        body: localizations.newPlayDateRequestBody(newRequest.requesterDog.name),
        likerUserId: currentUserId,
        payload: jsonEncode({
          'type': 'playDateRequest',
          'requestId': docRef.id,
          'requesterUserId': FirebaseAuth.instance.currentUser!.uid,
        }),
      );

      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientUserId': requestedDog.ownerId,
        'timestamp': FieldValue.serverTimestamp(),
        'title': localizations.newPlayDateRequestTitle,
        'body': localizations.newPlayDateRequestBody(newRequest.requesterDog.name),
        'payload': jsonEncode({
          'type': 'playdateRequest',
          'requestId': docRef.id,
          'requesterUserId': FirebaseAuth.instance.currentUser!.uid,
        }),
        'isRead': false,
      });

      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(localizations.requestCreatedSuccess)),
      );

      setState(() {
        selectedRequesterDogId = null;
        selectedRequestedDogId = null;
      });
      _loadRequests();
      Navigator.pop(context);
    } catch (e) {
      print('❌ Error creating request: $e');
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorCreatingRequest(e.toString()))),
      );
    }
  }

  Future<void> updatePlayDateStatus({
    required String requestId,
    required String newStatus,
  }) async {
    print('PlayDateRequestsPageNew - Updating playdate status for requestId: $requestId to status: $newStatus');
    final dynamic appCheckToken = await FirebaseAppCheck.instance.getToken();
    String? token;
    if (appCheckToken is Map<String, dynamic> && appCheckToken.containsKey('token')) {
      token = appCheckToken['token'] as String?;
    } else if (appCheckToken is String) {
      token = appCheckToken;
    } else {
      print('PlayDateRequestsPageNew - Unexpected AppCheckToken format, falling back to null');
      token = null;
    }
    print('PlayDateRequestsPageNew - App Check token retrieved: ${token ?? "null"}');
    if (token == null) {
      print('PlayDateRequestsPageNew - App Check token is null, using empty token as fallback');
    }
    final url = Uri.parse('https://updateplaydatestatus-5w36h7diwa-uc.a.run.app');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Firebase-AppCheck': token ?? '',
        },
        body: jsonEncode({
          'requestId': requestId,
          'status': newStatus,
        }),
      );
      print('PlayDateRequestsPageNew - HTTP response status: ${response.statusCode}, body: ${response.body}');
      if (response.statusCode == 200) {
        print('PlayDateRequestsPageNew - Status updated: $newStatus');
      } else {
        print('PlayDateRequestsPageNew - Error: ${response.statusCode} => ${response.body}');
      }
    } on FirebaseFunctionsException catch (e) {
      print('PlayDateRequestsPageNew - FirebaseFunctionsException: Code: ${e.code}, Message: ${e.message}, Details: ${e.details}');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingStatus(e.message ?? ''))),
        );
      }
    } catch (e) {
      print('PlayDateRequestsPageNew - Unexpected error updating status: $e');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorUpdatingStatusUnexpected(e.toString()))),
        );
      }
    }
  }

  Future<void> respondToPlayDateRequest({
    required String requestId,
    required String status,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('PlayDateRequestsPageNew - User is not logged in');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseLoginToRespond)),
        );
      }
      return;
    }

    print('PlayDateRequestsPageNew - Responding to request ID: $requestId with status: $status');
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('updatePlayDateRequestStatusV2');
      final response = await callable.call({
        'requestId': requestId,
        'status': status,
        'requesterUserId': user.uid,
        'requestedUserId': requests.firstWhere((r) => r.requestId == requestId).requestedUserId!,
      });
      print('PlayDateRequestsPageNew - Callable response for respond: ${response.data}');
      await Provider.of<AppState>(context, listen: false).sendPlayDateStatusNotification(
        requesterUserId: requests.firstWhere((r) => r.requestId == requestId).requesterUserId,
        requestedUserId: requests.firstWhere((r) => r.requestId == requestId).requestedUserId!,
        requestId: requestId,
        status: status,
        context: context,
      );
      if (mounted) {
        setState(() {
          requests.removeWhere((r) => r.requestId == requestId);
        });
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.requestStatusUpdated(status))),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      print('PlayDateRequestsPageNew - FirebaseFunctionsException: Code: ${e.code}, Message: ${e.message}, Details: ${e.details}');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorRespondingToRequest(e.message ?? ''))),
        );
      }
    } catch (e) {
      print('PlayDateRequestsPageNew - Unexpected error responding to request: $e');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorRespondingToRequestUnexpected(e.toString()))),
        );
      }
    }
  }

  Future<bool> confirmRejectDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.rejectConfirmation),
        content: Text(localizations.areYouSure),
        actions: [
          TextButton(
            child: Text(localizations.cancel),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text(localizations.reject),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _acceptRequest(BuildContext context, PlayDateRequest request) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('PlayDateRequestsPageNew - User is not logged in');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseLoginToAccept)),
        );
      }
      return;
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      if (!mounted) return;
      print('PlayDateRequestsPageNew - Accepting request with ID: ${request.requestId}');
      print('Data sent to updatePlayDateRequestStatusV2: {requestId: ${request.requestId}, status: accepted, requesterUserId: ${request.requesterUserId}, requestedUserId: ${request.requestedUserId}}');

      if (request.requestedUserId == null) {
        print('PlayDateRequestsPageNew - Invalid parameters: ${request.toMap()}');
        scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Invalid request data')));
        return;
      }

      await _requestExactAlarmPermission();

      final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('updatePlayDateRequestStatusV2');
      final response = await callable.call({
        'requestId': request.requestId,
        'status': 'accepted',
        'requesterUserId': request.requesterUserId,
        'requestedUserId': request.requestedUserId!,
      });
      print('PlayDateRequestsPageNew - Callable response for accept: ${response.data}');

      final playDateData = PlayDateRequest(
        requestId: request.requestId,
        requesterUserId: request.requesterUserId,
        requestedUserId: user.uid,
        requesterDog: Dog(
          name: request.requesterDog.name,
          breed: request.requesterDog.breed,
          age: request.requesterDog.age,
          gender: request.requesterDog.gender,
          healthStatus: request.requesterDog.healthStatus,
          isNeutered: request.requesterDog.isNeutered,
          description: request.requesterDog.description,
          traits: request.requesterDog.traits,
          ownerGender: request.requesterDog.ownerGender,
          imagePaths: request.requesterDog.imagePaths,
          isAvailableForAdoption: request.requesterDog.isAvailableForAdoption,
          isOwner: false,
          ownerId: request.requesterDog.ownerId,
          latitude: request.requesterDog.latitude,
          longitude: request.requesterDog.longitude,
          id: request.requesterDog.id, // اضافه کردن id
        ),
        requestedDog: Dog(
          name: request.requestedDog.name,
          breed: request.requestedDog.breed,
          age: request.requestedDog.age,
          gender: request.requestedDog.gender,
          healthStatus: request.requestedDog.healthStatus,
          isNeutered: request.requestedDog.isNeutered,
          description: request.requestedDog.description,
          traits: request.requestedDog.traits,
          ownerGender: request.requestedDog.ownerGender,
          imagePaths: request.requestedDog.imagePaths,
          isAvailableForAdoption: request.requestedDog.isAvailableForAdoption,
          isOwner: false,
          ownerId: request.requestedDog.ownerId,
          latitude: request.requestedDog.latitude,
          longitude: request.requestedDog.longitude,
          id: request.requestedDog.id, // اضافه کردن id
        ),
        status: 'accepted',
        requestDate: request.requestDate,
        scheduledDateTime: request.scheduledDateTime,
        requesterName: request.requesterName,
        message: request.message,
        location: request.location,
      );

      await FirebaseFirestore.instance.collection('playDates').add(playDateData.toMap());

      final localizations = AppLocalizations.of(context)!;
      await _notificationService.sendInstantNotificationToUser(
        request.requesterUserId,
        localizations.playDateAcceptedTitle,
        localizations.playDateAcceptedBodyRequester(request.requestedDog.name),
      );

      if (request.scheduledDateTime != null) {
        final scheduledTime = request.scheduledDateTime!.subtract(Duration(hours: 2));
        try {
          await _notificationService.scheduleReminderNotification(
            id: '${request.requestId}_reminder',
            scheduledTime: scheduledTime,
            title: localizations.upcomingPlaydateTitle,
            body: localizations.upcomingPlaydateBodyRequester(request.requestedDog.name),
          );
          await _notificationService.scheduleReminderNotification(
            id: '${request.requestId}_requested_reminder',
            scheduledTime: scheduledTime,
            title: localizations.upcomingPlaydateTitle,
            body: localizations.upcomingPlaydateBodyRequested(request.requesterDog.name),
          );
          print('PlayDateRequestsPageNew - Scheduled notifications for request ${request.requestId} at $scheduledTime');
        } catch (e) {
          print('PlayDateRequestsPageNew - Failed to schedule notification: $e');
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.failedToScheduleReminder)),
          );
        }
      }

      if (mounted) {
        setState(() {
          requests.removeWhere((r) => r.requestId == request.requestId);
        });
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(localizations.requestAcceptedSuccess)),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      print('PlayDateRequestsPageNew - FirebaseFunctionsException: Code: ${e.code}, Message: ${e.message}, Details: ${e.details}');
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorAcceptingRequest(e.message ?? ''))),
      );
    } catch (e) {
      print('PlayDateRequestsPageNew - Unexpected error accepting request: $e');
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorAcceptingRequestUnexpected(e.toString()))),
      );
    }
  }

  Future<void> _rejectRequest(BuildContext context, PlayDateRequest request) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('PlayDateRequestsPageNew - User is not logged in');
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseLoginToReject)),
        );
      }
      return;
    }

    final confirmed = await confirmRejectDialog(context);
    if (confirmed == true && mounted) {
      try {
        print('PlayDateRequestsPageNew - Rejecting request with ID: ${request.requestId}');
        print('Data sent to updatePlayDateRequestStatusV2: {requestId: ${request.requestId}, status: rejected, requesterUserId: ${request.requesterUserId}, requestedUserId: ${request.requestedUserId}}');

        if (request.requestedUserId == null) {
          print('PlayDateRequestsPageNew - Invalid parameters: ${request.toMap()}');
          _scaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Invalid request data')));
          return;
        }

        final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('updatePlayDateRequestStatusV2');
        final response = await callable.call({
          'requestId': request.requestId,
          'status': 'rejected',
          'requesterUserId': request.requesterUserId,
          'requestedUserId': request.requestedUserId!,
        });
        print('PlayDateRequestsPageNew - Callable response for reject: ${response.data}');

        final localizations = AppLocalizations.of(context)!;
        await _notificationService.sendInstantNotificationToUser(
          request.requesterUserId,
          localizations.playDateRejectedTitle,
          localizations.playDateRejectedBodyRequester(request.requestedDog.name),
        );

        if (mounted) {
          setState(() {
            requests.removeWhere((r) => r.requestId == request.requestId);
            _loadRequests();
          });
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(localizations.requestRejectedSuccess)),
          );
        }
      } on FirebaseFunctionsException catch (e) {
        print('PlayDateRequestsPageNew - FirebaseFunctionsException: Code: ${e.code}, Message: ${e.message}, Details: ${e.details}');
        if (mounted) {
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorRejectingRequest(e.message ?? ''))),
          );
        }
      } catch (e) {
        print('PlayDateRequestsPageNew - Unexpected error rejecting request: $e');
        if (mounted) {
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.errorRejectingRequestUnexpected(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _requestExactAlarmPermission() async {
    if (await Permission.scheduleExactAlarm.isDenied) {
      print('PlayDateRequestsPageNew - Requesting SCHEDULE_EXACT_ALARM permission');
      final status = await Permission.scheduleExactAlarm.request();
      print('PlayDateRequestsPageNew - SCHEDULE_EXACT_ALARM permission status: $status');
    }
  }

  Widget buildPlayDateRequestItem(PlayDateRequest request) {
    final formattedDate = request.scheduledDateTime != null
        ? DateFormat('yyyy-MM-dd – kk:mm').format(request.scheduledDateTime!)
        : AppLocalizations.of(context)!.notScheduled;
    print('PlayDateRequestsPageNew - Rendering request ${request.requestId}: status=${request.status}, scheduledDateTime=${request.scheduledDateTime}, requesterDogId=${request.requesterDog.id}, requestedDogId=${request.requestedDog.id}');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.playdateRequestMessage(request.requesterDog.name, request.requestedDog.name),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${AppLocalizations.of(context)!.scheduledLabel} $formattedDate',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            if (request.location != null) ...[
              const SizedBox(height: 4),
              Text(
                '${AppLocalizations.of(context)!.locationLabel} ${request.location}',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: request.status == 'pending' ? () => _acceptRequest(context, request) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 36),
                  ),
                  child: Text(AppLocalizations.of(context)!.accept, style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: request.status == 'pending' ? () => _rejectRequest(context, request) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 36),
                  ),
                  child: Text(AppLocalizations.of(context)!.reject, style: GoogleFonts.poppins()),
                ),
                Text(
                  '${AppLocalizations.of(context)!.status}: ${request.status ?? AppLocalizations.of(context)!.unknownStatus}',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRelativeTime(DateTime? timestamp) {
    if (timestamp == null) return AppLocalizations.of(context)!.unknownTime;
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 60) return AppLocalizations.of(context)!.minutesAgo(difference.inMinutes.toString());
    if (difference.inHours < 24) return AppLocalizations.of(context)!.hoursAgo(difference.inHours.toString());
    return AppLocalizations.of(context)!.daysAgo(difference.inDays.toString());
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    print('PlayDateRequestsPageNew - Current User ID: $currentUserId');
    final appState = AppState.of(context);

    if (currentUserId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.playdateRequestsTitle, style: GoogleFonts.poppins()),
          backgroundColor: Colors.pink,
        ),
        body: const Center(
          child: Text(
            'Please log in to view playdate requests.',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldMessengerKey,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.playdateRequestsTitle, style: GoogleFonts.poppins()),
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
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text(AppLocalizations.of(context)!.selectYourDog, style: GoogleFonts.poppins(fontSize: 12)),
                          value: selectedRequesterDogId,
                          items: widget.dogsList
                              .where((dog) => dog.ownerId == currentUserId)
                              .map<DropdownMenuItem<String>>((dog) => DropdownMenuItem<String>(
                                    value: dog.id,
                                    child: Text(dog.name, style: GoogleFonts.poppins(fontSize: 12)),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedRequesterDogId = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Text(AppLocalizations.of(context)!.selectFriendsDog, style: GoogleFonts.poppins(fontSize: 12)),
                          value: selectedRequestedDogId,
                          items: widget.dogsList
                              .where((dog) => dog.ownerId != currentUserId)
                              .map<DropdownMenuItem<String>>((dog) => DropdownMenuItem<String>(
                                    value: dog.id,
                                    child: Text(dog.name, style: GoogleFonts.poppins(fontSize: 12)),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedRequestedDogId = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _createPlayDateRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.pink,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.sendRequestButton,
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    AppLocalizations.of(context)!.notificationsSection,
                    style: GoogleFonts.dancingScript(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where('recipientUserId', isEqualTo: currentUserId)
                        .orderBy('timestamp', descending: true)
                        .limit(10)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (snapshot.hasError) {
                        print('PlayDateRequestsPageNew - Error in StreamBuilder: ${snapshot.error}');
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            AppLocalizations.of(context)!.errorLoadingNotificationsStream(snapshot.error.toString()),
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
                          ),
                        );
                      }
                      final notifications = snapshot.data?.docs
                              .map((doc) => AppNotification.fromMap(doc.id, doc.data() as Map<String, dynamic>))
                              .toList() ??
                          [];
                      print('PlayDateRequestsPageNew - Loaded notifications: ${notifications.map((n) => n.toMap()).toList()}');
                      if (notifications.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            AppLocalizations.of(context)!.noNotifications,
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          final payload = jsonDecode(notification.payload ?? '{}') as Map<String, dynamic>;
                          final requestId = payload['requestId'] ?? '';
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 8.0),
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              title: Text(
                                notification.title ?? AppLocalizations.of(context)!.noTitle,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification.body ?? AppLocalizations.of(context)!.noBody,
                                    style: GoogleFonts.poppins(color: Colors.white70),
                                  ),
                                  Text(
                                    DateFormat('yyyy-MM-dd – kk:mm').format(notification.timestamp),
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.grey),
                                onPressed: () async {
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('notifications')
                                        .doc(notification.id)
                                        .delete();
                                    if (mounted) {
                                      _scaffoldMessengerKey.currentState?.showSnackBar(
                                        SnackBar(content: Text(AppLocalizations.of(context)!.notificationDeleted)),
                                      );
                                    }
                                  } catch (e) {
                                    print('PlayDateRequestsPageNew - Error deleting notification: $e');
                                    if (mounted) {
                                      _scaffoldMessengerKey.currentState?.showSnackBar(
                                        SnackBar(content: Text(AppLocalizations.of(context)!.errorDeletingNotification(e.toString()))),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    AppLocalizations.of(context)!.playdateRequestsSection,
                    style: GoogleFonts.dancingScript(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('playDateRequests')
                        .where('requestedUserId', isEqualTo: currentUserId)
                        .limit(10)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (snapshot.hasError) {
                        print('PlayDateRequestsPageNew - Error in StreamBuilder: ${snapshot.error}');
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            AppLocalizations.of(context)!.errorLoadingRequestsStream(snapshot.error.toString()),
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
                          ),
                        );
                      }
                      final allDocs = snapshot.data?.docs ?? [];
                      print('PlayDateRequestsPageNew - StreamBuilder docs: ${allDocs.length}');
                      print('PlayDateRequestsPageNew - StreamBuilder data: ${allDocs.map((doc) => doc.data()).toList()}');
                      requests = allDocs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>?;
                        if (data == null) {
                          print('PlayDateRequestsPageNew - Skipping null data for request: ${doc.id}');
                          return null;
                        }
                        print('PlayDateRequestsPageNew - Processing request: ${doc.id}, data: $data');
                        if (data['requesterDog'] == null ||
                            data['requestedDog'] == null ||
                            data['requesterDog']['id'] == null ||
                            data['requesterDog']['ownerId'] == null ||
                            data['requestedDog']['id'] == null ||
                            data['requestedDog']['ownerId'] == null ||
                            data['requesterUserId'] == null ||
                            data['requestedUserId'] == null) {
                          print('PlayDateRequestsPageNew - Skipping invalid request: ${doc.id}, data: $data');
                          return null;
                        }
                        try {
                          return PlayDateRequest.fromFirestore(doc.id, data);
                        } catch (e) {
                          print('PlayDateRequestsPageNew - Error parsing request ${doc.id}: $e');
                          return null;
                        }
                      }).whereType<PlayDateRequest>().toList();
                      if (requests.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            AppLocalizations.of(context)!.noPlaydateRequests,
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          return buildPlayDateRequestItem(requests[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}