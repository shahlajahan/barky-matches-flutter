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
  final List<Dog> dogs;
  final int dogCount;
  final Object? error;
  final StackTrace? stackTrace;

  DogsSnapshot._({
    required this.phase,
    List<Dog> dogs = const <Dog>[],
    int? dogCount,
    this.error,
    this.stackTrace,
  }) : dogs = List<Dog>.unmodifiable(dogs),
       dogCount = dogCount ?? dogs.length;

  DogsSnapshot.loading() : this._(phase: DogsSnapshotPhase.loading);

  DogsSnapshot.readyEmpty()
    : this._(phase: DogsSnapshotPhase.readyEmpty, dogs: const <Dog>[]);

  DogsSnapshot.readyData({required List<Dog> dogs})
    : this._(phase: DogsSnapshotPhase.readyData, dogs: dogs);

  DogsSnapshot.error({
    required Object error,
    StackTrace? stackTrace,
  }) : this._(
          phase: DogsSnapshotPhase.error,
          dogs: const <Dog>[],
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
  DogsSnapshot _snapshot = DogsSnapshot.loading();

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
    final dogs = box.values.toList();
    _setSnapshot(
      dogCount == 0
          ? DogsSnapshot.readyEmpty()
          : DogsSnapshot.readyData(dogs: dogs),
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

  Future<void> clearIfReady() async {
    final box = await ready();

    if (!box.isOpen) {
      throw StateError('dogsBox is not open');
    }

    await box.clear();
    _setSnapshot(DogsSnapshot.readyEmpty());
  }

  Future<void> replaceAllCanonicalDogs(List<Dog> dogs) async {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('dogsBox is not open');
    }

    final uniqueDogs = {for (final dog in dogs) dog.id: dog};

    await box.clear();
    await box.putAll(uniqueDogs);

    _setSnapshot(
      uniqueDogs.isEmpty
          ? DogsSnapshot.readyEmpty()
          : DogsSnapshot.readyData(dogs: uniqueDogs.values.toList()),
    );
  }

  Future<void> upsertDog(Dog dog) async {
    final box = await ready();

    if (!box.isOpen) {
      throw StateError('dogsBox is not open');
    }

    await box.put(dog.id, dog);

    final dogs = box.values.toList();
    _setSnapshot(
      dogs.isEmpty
          ? DogsSnapshot.readyEmpty()
          : DogsSnapshot.readyData(dogs: dogs),
    );
  }

  void _setSnapshot(DogsSnapshot newState) {
    _snapshot = newState;
    notifyListeners();
  }
}
