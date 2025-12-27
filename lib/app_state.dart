import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dog.dart';
import 'notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class AppState with ChangeNotifier {
  List<Dog> _dogsList;
  List<Dog> _favoriteDogs;
  final ValueNotifier<List<Dog>> favoriteDogsNotifier;
  final ValueNotifier<Map<String, List<String>>> likesNotifier;
  Map<String, List<Map<String, dynamic>>> _dogLikes; // اضافه کردن dogLikes
  Function(Dog) onToggleFavorite;
  final NotificationService notificationService;
  String _currentUserName;
  String? _currentUserId;
  String? _selectedRequesterDogId;

  String? get currentUserId => _currentUserId;

  set currentUserId(String? value) {
    if (_currentUserId == value) return;
    _currentUserId = value;
    notifyListeners();
  }

  Map<String, List<Map<String, dynamic>>> get dogLikes => _dogLikes; // Getter برای dogLikes

  AppState({
    required List<Dog> dogsList,
    required List<Dog> favoriteDogs,
    required this.favoriteDogsNotifier,
    required this.likesNotifier,
    required this.onToggleFavorite,
    required this.notificationService,
    required String currentUserName,
    String? currentUserId,
    String? selectedRequesterDogId,
  })  : _dogsList = dogsList,
        _favoriteDogs = favoriteDogs,
        _dogLikes = {}, // مقداردهی اولیه dogLikes
        _currentUserName = currentUserName,
        _currentUserId = currentUserId,
        _selectedRequesterDogId = selectedRequesterDogId;

  static AppState of(BuildContext context) {
    return Provider.of<AppState>(context, listen: false);
  }

  List<Dog> get dogsList => _dogsList;
  List<Dog> get favoriteDogs => _favoriteDogs;
  String get currentUserName => _currentUserName;
  String? get selectedRequesterDogId => _selectedRequesterDogId;

  void setSelectedRequesterDogId(String? value) {
    if (_selectedRequesterDogId != value) {
      _selectedRequesterDogId = value;
      notifyListeners();
    }
  }

  void updateDogs(List<Dog> newDogs) {
    _dogsList = newDogs;
    notifyListeners();
  }

  void updateFavorites(List<Dog> newFavorites) {
    _favoriteDogs = newFavorites;
    favoriteDogsNotifier.value = List<Dog>.from(newFavorites);
    notifyListeners();
  }

  void updateUserName(String newName) {
    _currentUserName = newName;
    notifyListeners();
  }

  void updateUserId(String? newId) {
    currentUserId = newId;
  }

  Future<void> toggleFavorite(Dog dog) async {
    final key = dog.id;
    final favoritesBox = Hive.box<Dog>('favoritesBox');
    bool isFavorite = favoritesBox.values.any((favDog) => favDog.id == dog.id);
    print('AppState - Checking if ${dog.name} (id: ${dog.id}) is favorite: $isFavorite, key: $key');

    if (isFavorite) {
      await removeFavorite(dog);
    } else {
      await addFavorite(dog);
    }
    notifyListeners();
  }

  Future<void> addFavorite(Dog dog) async {
    try {
      final key = dog.id;
      final favoritesBox = Hive.box<Dog>('favoritesBox');
      if (!favoritesBox.values.any((favDog) => favDog.id == dog.id)) {
        final newFavorites = List<Dog>.from(_favoriteDogs)..add(dog.copy());
        _favoriteDogs.clear();
        _favoriteDogs.addAll(newFavorites);
        await favoritesBox.put(key, dog.copy());
        favoriteDogsNotifier.value = List<Dog>.from(newFavorites);
        print('AppState - Added ${dog.name} (id: ${dog.id}) to favorites, key: $key');
        print('AppState - Updated favorite dogs count: ${_favoriteDogs.length}');
        print('AppState - Synced with Hive. Hive count: ${favoritesBox.length}');
        print('AppState - Favorite dogs: ${_favoriteDogs.map((d) => '${d.name}|${d.id}').toList()}');
      } else {
        print('AppState - ${dog.name} (id: ${dog.id}) already in favorites, key: $key');
      }
    } catch (e) {
      print('AppState - Error adding favorite: $e');
    }
  }

  Future<void> removeFavorite(Dog dog) async {
    try {
      final key = dog.id;
      final favoritesBox = Hive.box<Dog>('favoritesBox');
      final indexToRemove = favoritesBox.values.toList().indexWhere((favDog) => favDog.id == dog.id);
      if (indexToRemove != -1) {
        await favoritesBox.deleteAt(indexToRemove);
        _favoriteDogs.removeWhere((favDog) => favDog.id == dog.id);
        favoriteDogsNotifier.value = List<Dog>.from(_favoriteDogs);
        print('AppState - Removed ${dog.name} (id: ${dog.id}) from favorites, key: $key');
        print('AppState - Updated favorite dogs count: ${_favoriteDogs.length}');
        print('AppState - Synced with Hive. Hive count: ${favoritesBox.length}');
        print('AppState - Favorite dogs: ${_favoriteDogs.map((d) => '${d.name}|${d.id}').toList()}');
      } else {
        print('AppState - ${dog.name} (id: ${dog.id}) not found in favorites, key: $key');
      }
    } catch (e) {
      print('AppState - Error removing favorite: $e');
    }
  }

  Future<void> _storeNotification(String recipientUserId, String title, String body, String requestId) async {
    try {
      print('AppState - Attempting to store notification for user: $recipientUserId');
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientUserId': recipientUserId,
        'title': title,
        'body': body,
        'payload': jsonEncode({
          'type': 'playDateRequest',
          'requestId': requestId,
          'recipientUserId': recipientUserId,
        }),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      print('AppState - Stored notification in Firestore for user: $recipientUserId');
    } catch (e) {
      print('AppState - Error storing notification in Firestore: $e');
      rethrow;
    }
  }

  Future<void> addLike(String userId, Dog dog, BuildContext context) async {
    try {
      final dogKey = dog.id;
      final currentLikes = likesNotifier.value;
      final userLikes = currentLikes[userId] ?? [];

      if (userLikes.contains(dogKey)) return;

      final likeSnapshot = await FirebaseFirestore.instance
          .collection('likes')
          .where('likerUserId', isEqualTo: userId)
          .where('dogId', isEqualTo: dogKey)
          .get();
      if (likeSnapshot.docs.isNotEmpty) return;

      bool notificationSent = false;

      await FirebaseFirestore.instance.collection('likes').add({
        'likerUserId': userId,
        'dogId': dogKey,
        'timestamp': FieldValue.serverTimestamp(),
        'username': _currentUserName, // اضافه کردن نام کاربری
      });
      print('AppState - User $userId liked $dogKey in Firestore');

      final updatedLikes = Map<String, List<String>>.from(currentLikes);
      updatedLikes[userId] = [...userLikes, dogKey];
      likesNotifier.value = updatedLikes;
      print('AppState - Updated likesNotifier for user $userId');

      // به‌روزرسانی dogLikes
      final updatedDogLikes = Map<String, List<Map<String, dynamic>>>.from(_dogLikes);
      updatedDogLikes[dogKey] = [
        ...(updatedDogLikes[dogKey] ?? []),
        {'userId': userId, 'username': _currentUserName},
      ];
      _dogLikes = updatedDogLikes;
      notifyListeners();
      print('AppState - Updated dogLikes for dog $dogKey');

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = jsonEncode({
        'type': 'like',
        'likerUserId': userId,
        'dogKey': dogKey,
      });
      final localizations = AppLocalizations.of(context)!;
      final title = localizations.newLikeTitle;
      final body = localizations.newLikeBody(_currentUserName, dog.name);
      if (!notificationSent) {
        await notificationService.showNotification(
          id: notificationId,
          title: title,
          body: body,
          likerUserId: userId,
        );
        notificationSent = true;
      }
      await _storeNotification(dog.ownerId!, title, body, '');
      print('AppState - Stored notification for owner: ${dog.ownerId}');

      await _checkForMutualLike(userId, dog, context);
    } catch (e) {
      print('AppState - Error adding like: $e');
    }
  }

  Future<void> removeLike(String userId, Dog dog) async {
    try {
      final dogKey = dog.id;

      final likeSnapshot = await FirebaseFirestore.instance
          .collection('likes')
          .where('likerUserId', isEqualTo: userId)
          .where('dogId', isEqualTo: dogKey)
          .get();

      for (var doc in likeSnapshot.docs) {
        await doc.reference.delete();
        print('AppState - Removed like for $dogKey by user $userId from Firestore');
      }

      final currentLikes = Map<String, List<String>>.from(likesNotifier.value);
      final userLikes = List<String>.from(currentLikes[userId] ?? []);
      currentLikes[userId] = userLikes.where((key) => key != dogKey).toList();
      if (currentLikes[userId]!.isEmpty) {
        currentLikes.remove(userId);
      }
      likesNotifier.value = Map<String, List<String>>.from(currentLikes);
      print('AppState - Updated likesNotifier after removing like for user $userId');

      // به‌روزرسانی dogLikes
      final updatedDogLikes = Map<String, List<Map<String, dynamic>>>.from(_dogLikes);
      updatedDogLikes[dogKey] = (updatedDogLikes[dogKey] ?? []).where((liker) => liker['userId'] != userId).toList();
      if (updatedDogLikes[dogKey]!.isEmpty) {
        updatedDogLikes.remove(dogKey);
      }
      _dogLikes = updatedDogLikes;
      notifyListeners();
      print('AppState - Updated dogLikes after removing like for dog $dogKey');
    } catch (e) {
      print('AppState - Error removing like: $e');
    }
  }

  Future<void> toggleLike(String userId, Dog dog, BuildContext context) async {
    final currentLikes = likesNotifier.value;
    final dogKey = dog.id;
    final userLikes = currentLikes[userId] ?? [];
    bool isLiked = userLikes.contains(dogKey);
    if (isLiked) {
      await removeLike(userId, dog);
    } else {
      await addLike(userId, dog, context);
    }
  }

  Future<void> _checkForMutualLike(String likerUserId, Dog likedDog, BuildContext context) async {
    final likedDogKey = likedDog.id;
    final likedDogOwnerId = likedDog.ownerId;

    if (likedDogOwnerId == null) return;

    final ownerLikesSnapshot = await FirebaseFirestore.instance
        .collection('likes')
        .where('likerUserId', isEqualTo: likedDogOwnerId)
        .get();

    final ownerLikes = ownerLikesSnapshot.docs
        .map((doc) => doc['dogId'] as String)
        .toList();

    final likerDog = _dogsList.firstWhere(
      (dog) => dog.ownerId == likerUserId,
      orElse: () => Dog(
        id: 'unknown_${likerUserId}',
        name: 'Unknown',
        breed: '',
        age: 0,
        gender: '',
        healthStatus: '',
        isNeutered: false,
        description: '',
        traits: [],
        ownerGender: '',
        imagePaths: [],
        isAvailableForAdoption: false,
        isOwner: false,
        ownerId: likerUserId,
        latitude: 0.0,
        longitude: 0.0,
      ),
    );

    if (likerDog.ownerId == null) return;

    final likerDogKey = likerDog.id;

    if (ownerLikes.contains(likerDogKey) && likerUserId != likedDogOwnerId) {
      final requestId = '${likerUserId}_${likedDogOwnerId}_${DateTime.now().millisecondsSinceEpoch}';
      final existingRequests = await FirebaseFirestore.instance
          .collection('playDateRequests')
          .where('requesterUserId', isEqualTo: likerUserId)
          .where('requestedUserId', isEqualTo: likedDogOwnerId)
          .get();

      if (existingRequests.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('playDateRequests').doc(requestId).set({
          'requesterUserId': likerUserId,
          'requestedUserId': likedDogOwnerId,
          'requesterDog': {
            'name': likerDog.name,
            'id': likerDog.id,
            'ownerId': likerDog.ownerId,
          },
          'requestedDog': {
            'name': likedDog.name,
            'id': likedDog.id,
            'ownerId': likedDog.ownerId,
          },
          'status': 'pending',
          'requestDate': FieldValue.serverTimestamp(),
          'scheduledDateTime': null,
        });
        print('AppState - Created PlayDate request in Firestore: $requestId between ${likerDog.name} and ${likedDog.name}');

        final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final payload = jsonEncode({
          'type': 'playDateRequest',
          'requestId': requestId,
          'likerUserId': likerUserId,
        });
        final localizations = AppLocalizations.of(context)!;
        final title = localizations.newPlayDateRequestTitle;
        final body = localizations.newPlayDateRequestBody(likerDog.name);
        await notificationService.showNotification(
          id: notificationId,
          title: title,
          body: body,
          likerUserId: likerUserId,
        );
        await _storeNotification(likedDogOwnerId, title, body, requestId);
        print('AppState - Stored playdate notification for owner: $likedDogOwnerId');
      } else {
        print('AppState - PlayDate request already exists between $likerUserId and $likedDogOwnerId');
      }
    }
  }

  Future<void> deletePlayDateRequest(String requestId, BuildContext context) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      print('AppState - Current auth uid: $currentUserId');
      final docRef = FirebaseFirestore.instance.collection('playDateRequests').doc(requestId);
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        print('AppState - Request $requestId not found in Firestore');
        return;
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      final requesterUserId = data['requesterUserId'] as String;
      final requestedUserId = data['requestedUserId'] as String;
      final status = data['status'] as String;

      print('AppState - Deleting request $requestId with status: $status');
      print('AppState - Request data: $data');
      print('AppState - Comparing uids: current=$currentUserId, requester=$requesterUserId, requested=$requestedUserId');

      if (currentUserId != requesterUserId && currentUserId != requestedUserId) {
        print('AppState - User $currentUserId does not have permission to delete request $requestId');
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'User does not have permission to delete this request',
        );
      }

      await docRef.delete();
      print('AppState - Deleted PlayDate request from Firestore: $requestId');

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = jsonEncode({
        'type': 'playDateRequest',
        'requestId': requestId,
        'requesterUserId': requesterUserId,
      });
      final localizations = AppLocalizations.of(context)!;
      final title = localizations.playDateCanceledTitle;
      final body = localizations.playDateCanceledBody(data['requestedDog']['name'] as String);
      await notificationService.showNotification(
        id: notificationId,
        title: title,
        body: body,
        likerUserId: requesterUserId,
      );
      await _storeNotification(requesterUserId, title, body, requestId);
      await _storeNotification(requestedUserId, title, body, requestId);
      print('AppState - Stored cancellation notification for users: $requesterUserId, $requestedUserId');
    } catch (e) {
      print('AppState - Error deleting PlayDate request: $e');
      rethrow;
    }
  }

  Future<void> sendPlayDateStatusNotification({
    required String requesterUserId,
    required String requestedUserId,
    required String requestId,
    DateTime? scheduledDateTime,
    required String status,
    required BuildContext context,
  }) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      print('AppState - Current auth uid: $currentUserId');
      print('AppState - Sending notification for request: $requestId, status: $status, requester: $requesterUserId, requested: $requestedUserId');
      print('AppState - Comparing uids: current=$currentUserId, requester=$requesterUserId, requested=$requestedUserId');
      if (currentUserId.isEmpty) {
        print('AppState - No user logged in, cannot send notification');
        return;
      }

      final requesterDog = _dogsList.firstWhere(
        (dog) => dog.ownerId == requesterUserId,
        orElse: () => Dog(
          id: 'unknown_${requesterUserId}',
          name: 'Unknown',
          breed: '',
          age: 0,
          gender: '',
          healthStatus: '',
          isNeutered: false,
          description: '',
          traits: [],
          ownerGender: '',
          imagePaths: [],
          isAvailableForAdoption: false,
          isOwner: false,
          ownerId: requesterUserId,
          latitude: 0.0,
          longitude: 0.0,
        ),
      );

      final requestedDog = _dogsList.firstWhere(
        (dog) => dog.ownerId == requestedUserId,
        orElse: () => Dog(
          id: 'unknown_${requestedUserId}',
          name: 'Unknown',
          breed: '',
          age: 0,
          gender: '',
          healthStatus: '',
          isNeutered: false,
          description: '',
          traits: [],
          ownerGender: '',
          imagePaths: [],
          isAvailableForAdoption: false,
          isOwner: false,
          ownerId: requestedUserId,
          latitude: 0.0,
          longitude: 0.0,
        ),
      );

      String recipientUserId = currentUserId == requesterUserId ? requestedUserId : requesterUserId;
      final localizations = AppLocalizations.of(context)!;
      String title;
      String body;

      if (status.toLowerCase() == 'accepted') {
        title = localizations.playDateAcceptedTitle;
        body = currentUserId == requesterUserId
            ? localizations.playDateAcceptedBodyRequester(requestedDog.name)
            : localizations.playDateAcceptedBodyRequested(requestedDog.name, scheduledDateTime != null
                ? ' on ${scheduledDateTime.toLocal().toString().split(' ')[0]} at ${scheduledDateTime.toLocal().hour}:${scheduledDateTime.toLocal().minute}'
                : '');
      } else {
        title = localizations.playDateRejectedTitle;
        body = currentUserId == requesterUserId
            ? localizations.playDateRejectedBodyRequester(requestedDog.name)
            : localizations.playDateRejectedBodyRequested(requestedDog.name);
      }

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final payload = jsonEncode({
        'type': 'playDateRequest',
        'requestId': requestId,
        'requesterUserId': requesterUserId,
        'requestedUserId': requestedUserId,
      });

      await notificationService.showNotification(
        id: notificationId,
        title: title,
        body: body,
        likerUserId: currentUserId,
      );
      await _storeNotification(recipientUserId, title, body, requestId);
      print('AppState - Sent playdate $status notification to: $recipientUserId');
    } catch (e) {
      print('AppState - Error sending playdate status notification: $e');
      rethrow;
    }
  }

  Future<void> cleanOldPlayDateRequests() async {
    try {
      final currentTime = DateTime.now();
      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('playDateRequests')
          .where('status', whereIn: ['accepted', 'rejected'])
          .get();

      for (var doc in requestsSnapshot.docs) {
        final data = doc.data();
        final requestDate = (data['requestDate'] as Timestamp?)?.toDate();
        if (requestDate != null && requestDate.isBefore(currentTime.subtract(Duration(days: 1)))) {
          await FirebaseFirestore.instance.collection('playDateRequests').doc(doc.id).delete();
          print('AppState - Deleted old PlayDate request from Firestore: ${doc.id}');
        }
      }
    } catch (e) {
      print('AppState - Error cleaning old PlayDate requests: $e');
    }
  }
}