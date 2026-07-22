import 'dart:async';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppState UID changes from User A to User B', () {
    final appState = _buildAppState(currentUserId: 'old-uid');

    final changed = appState.synchronizeAuthenticatedUid('new-uid');

    expect(changed, isTrue);
    expect(appState.currentUserId, 'new-uid');
  });

  test('a UID transition clears stale previous-user data', () {
    final appState = _buildAppState(
      currentUserId: 'old-uid',
      currentUserName: 'old-user-name',
    );
    appState.setSavedParks(['Old User Park']);

    appState.synchronizeAuthenticatedUid('new-uid');

    expect(appState.currentUserName, isNull);
    expect(appState.favoriteParks, isEmpty);
    expect(appState.favoriteDogs, isEmpty);
    expect(appState.cartItems, isEmpty);
  });

  test('User B session data is accepted after the transition', () {
    final appState = _buildAppState(currentUserId: 'user-a');

    appState.synchronizeAuthenticatedUid('user-b');
    final userBGeneration = appState.startupSessionGeneration;
    if (appState.isUserSessionCurrent('user-b', userBGeneration)) {
      appState.setSavedParks(['User B Park']);
    }

    expect(appState.currentUserId, 'user-b');
    expect(appState.favoriteParkNames, contains('User B Park'));
  });

  test('a stale User A callback cannot overwrite User B state', () async {
    final appState = _buildAppState(currentUserId: 'user-a');
    final userAGeneration = appState.startupSessionGeneration;
    final staleCallback = Completer<void>();

    final delayedUserAWrite = () async {
      await staleCallback.future;
      if (appState.isUserSessionCurrent('user-a', userAGeneration)) {
        appState.setSavedParks(['Stale User A Park']);
      }
    }();

    appState.synchronizeAuthenticatedUid('user-b');
    appState.setSavedParks(['User B Park']);
    staleCallback.complete();
    await delayedUserAWrite;

    expect(appState.favoriteParkNames, contains('User B Park'));
    expect(appState.favoriteParkNames, isNot(contains('Stale User A Park')));
  });

  test('disposing AppState invalidates the active session generation', () {
    final appState = _buildAppState(currentUserId: 'user-a');
    final generation = appState.startupSessionGeneration;

    appState.dispose();

    expect(appState.isDisposed, isTrue);
    expect(appState.isUserSessionCurrent('user-a', generation), isFalse);
  });

  test('late notifications are ignored after AppState is disposed', () {
    final appState = _buildAppState(currentUserId: 'user-a');
    var notifications = 0;
    appState.addListener(() => notifications++);

    appState.dispose();
    appState.notifyListeners();

    expect(notifications, 0);
  });
}

AppState _buildAppState({
  required String currentUserId,
  String? currentUserName,
}) {
  return AppState(
    favoriteDogs: <Dog>[],
    favoriteDogsNotifier: ValueNotifier<List<Dog>>(<Dog>[]),
    likesNotifier: ValueNotifier<Map<String, List<String>>>(
      <String, List<String>>{},
    ),
    onToggleFavorite: (_) async {},
    notificationService: NotificationService(),
    currentUserId: currentUserId,
    currentUserName: currentUserName,
  );
}
