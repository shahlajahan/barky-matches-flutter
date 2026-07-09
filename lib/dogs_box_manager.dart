import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'dog.dart';

enum DogsSnapshotPhase {
  loading,
  readyEmpty,
  readyData,
  error,
}

@immutable
class DogsSnapshot {
  final DogsSnapshotPhase phase;
  final int dogCount;
  final Object? error;
  final StackTrace? stackTrace;

  const DogsSnapshot._({
    required this.phase,
    this.dogCount = 0,
    this.error,
    this.stackTrace,
  });

  const DogsSnapshot.loading() : this._(phase: DogsSnapshotPhase.loading);

  const DogsSnapshot.readyEmpty() : this._(phase: DogsSnapshotPhase.readyEmpty);

  const DogsSnapshot.readyData({required int dogCount})
      : this._(phase: DogsSnapshotPhase.readyData, dogCount: dogCount);

  const DogsSnapshot.error({
    required Object error,
    StackTrace? stackTrace,
  }) : this._(
          phase: DogsSnapshotPhase.error,
          error: error,
          stackTrace: stackTrace,
        );

  bool get isLoading => phase == DogsSnapshotPhase.loading;

  bool get isReady =>
      phase == DogsSnapshotPhase.readyEmpty ||
      phase == DogsSnapshotPhase.readyData;

  bool get hasData => phase == DogsSnapshotPhase.readyData;

  bool get isEmpty => phase == DogsSnapshotPhase.readyEmpty;
}

class DogsBoxManager extends ChangeNotifier {
  DogsBoxManager._();

  static final DogsBoxManager instance = DogsBoxManager._();

  final Completer<Box<Dog>> _readyCompleter = Completer<Box<Dog>>();

  Box<Dog>? _box;
  DogsSnapshot _snapshot = const DogsSnapshot.loading();

  /// Internal migration snapshot used by AppState in later phases.
  ///
  /// This is not intended as a UI-facing contract yet.
  DogsSnapshot get snapshot => _snapshot;

  /// Backward-compatible alias for the internal snapshot.
  DogsSnapshot get state => _snapshot;

  DogsSnapshotPhase get phase => _snapshot.phase;

  bool get isLoading => _snapshot.isLoading;

  bool get isReady => _snapshot.isReady;

  bool get hasData => _snapshot.hasData;

  bool get hasError => _snapshot.phase == DogsSnapshotPhase.error;

  Object? get error => _snapshot.error;

  StackTrace? get stackTrace => _snapshot.stackTrace;

  /// Internal migration API.
  ///
  /// Temporary compatibility hook for startup and legacy call sites.
  Future<Box<Dog>> ready() => _readyCompleter.future;

  void attach(Box<Dog> box) {
    _box = box;

    if (!_readyCompleter.isCompleted) {
      _readyCompleter.complete(box);
    }

    if (!box.isOpen) {
      _setSnapshot(DogsSnapshot.error(
        error: StateError('dogsBox is not open'),
      ));
      return;
    }

    final dogCount = box.length;
    _setSnapshot(
      dogCount == 0
          ? const DogsSnapshot.readyEmpty()
          : DogsSnapshot.readyData(dogCount: dogCount),
    );
  }

  void markError(Object error, [StackTrace? stackTrace]) {
    if (!_readyCompleter.isCompleted) {
      _readyCompleter.completeError(error, stackTrace);
    }

    _setSnapshot(DogsSnapshot.error(
      error: error,
      stackTrace: stackTrace,
    ));
  }

  List<Dog> getDogsForOwner(String? userId) {
    final box = _box;
    if (box == null || !box.isOpen) {
      return const <Dog>[];
    }

    final uid = (userId ?? '').trim();
    return box.values
        .where((dog) => (dog.ownerId ?? '').trim() == uid)
        .toList();
  }

  List<Dog> getCachedMyDogs(String userId) {
    return getDogsForOwner(userId);
  }

  List<Dog> getCachedDiscoveryDogs(String userId) {
    final box = _box;
    if (box == null || !box.isOpen) {
      return const <Dog>[];
    }

    final uid = userId.trim();
    return box.values
        .where(
          (dog) =>
              (dog.ownerId ?? '').trim() != uid &&
              !dog.isHidden &&
              dog.dogProfileVisible &&
              dog.ownerProfileVisible,
        )
        .toList();
  }

  Future<void> clearIfReady() async {
    final box = _box;
    if (box == null || !box.isOpen) {
      return;
    }

    await box.clear();
    _setSnapshot(const DogsSnapshot.readyEmpty());
  }

  void _setSnapshot(DogsSnapshot newState) {
    _snapshot = newState;
    notifyListeners();
  }
}
