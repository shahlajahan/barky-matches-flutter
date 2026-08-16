typedef InitialNotificationGetter =
    Future<InitialNotificationMessage?> Function();

typedef InitialNotificationHandler =
    Future<void> Function(Map<String, dynamic> data);

class InitialNotificationMessage {
  const InitialNotificationMessage({required this.data, this.messageId});

  final Map<String, dynamic> data;
  final String? messageId;
}

class InitialNotificationReadiness {
  const InitialNotificationReadiness({
    required this.navigatorReady,
    required this.appStateReady,
    required this.authReady,
    required this.isGuest,
    required this.currentUserId,
  });

  final bool navigatorReady;
  final bool appStateReady;
  final bool authReady;
  final bool isGuest;
  final String? currentUserId;

  bool get canProcess {
    final uid = currentUserId?.trim();
    return navigatorReady &&
        appStateReady &&
        authReady &&
        !isGuest &&
        uid != null &&
        uid.isNotEmpty;
  }
}

class InitialNotificationCoordinator {
  bool _retrievalStarted = false;
  bool _processing = false;
  String? _handledMessageKey;
  InitialNotificationMessage? _pendingMessage;

  bool get retrievalStarted => _retrievalStarted;
  bool get hasPendingMessage => _pendingMessage != null;

  Future<void> retrieveOnce({
    required InitialNotificationGetter getInitialMessage,
    required InitialNotificationReadiness readiness,
    required InitialNotificationHandler handle,
  }) async {
    if (_retrievalStarted) return;
    _retrievalStarted = true;

    final message = await getInitialMessage();
    if (message == null) return;

    await _processOrStore(
      message: message,
      readiness: readiness,
      handle: handle,
    );
  }

  Future<void> processPendingIfReady({
    required InitialNotificationReadiness readiness,
    required InitialNotificationHandler handle,
  }) async {
    final message = _pendingMessage;
    if (message == null) return;

    await _processOrStore(
      message: message,
      readiness: readiness,
      handle: handle,
    );
  }

  Future<void> _processOrStore({
    required InitialNotificationMessage message,
    required InitialNotificationReadiness readiness,
    required InitialNotificationHandler handle,
  }) async {
    if (_processing) return;

    final key = _messageKey(message);
    if (_handledMessageKey == key) {
      _pendingMessage = null;
      return;
    }

    if (readiness.isGuest) {
      _pendingMessage = null;
      return;
    }

    if (!_matchesAuthenticatedRecipient(
      message.data,
      readiness.currentUserId,
    )) {
      _pendingMessage = null;
      return;
    }

    if (!readiness.canProcess) {
      _pendingMessage = message;
      return;
    }

    _processing = true;
    try {
      await handle(Map<String, dynamic>.from(message.data));
      _handledMessageKey = key;
      _pendingMessage = null;
    } finally {
      _processing = false;
    }
  }

  String _messageKey(InitialNotificationMessage message) {
    final messageId = message.messageId?.trim();
    if (messageId != null && messageId.isNotEmpty) return messageId;

    final data = message.data;
    final type = data['type']?.toString() ?? '';
    final entityId =
        data['messageId'] ??
        data['appointmentId'] ??
        data['bookingId'] ??
        data['requestId'] ??
        data['orderId'] ??
        data['chatId'] ??
        data['vaccineId'] ??
        '';
    return '$type:$entityId';
  }

  bool _matchesAuthenticatedRecipient(
    Map<String, dynamic> data,
    String? currentUserId,
  ) {
    final recipient = data['recipientUserId']?.toString().trim();
    if (recipient == null || recipient.isEmpty) return true;

    final uid = currentUserId?.trim();
    if (uid == null || uid.isEmpty) return true;

    return recipient == uid;
  }
}
