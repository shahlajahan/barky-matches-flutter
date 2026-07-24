import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/subscription/web_subscription_service.dart';

enum WebSubscriptionReturnState {
  verifying,
  success,
  failed,
  cancelled,
  pending,
}

WebSubscriptionReturnState webSubscriptionReturnState({
  required String returnPath,
  required WebSubscriptionPaymentStatus status,
}) {
  if (status.verified) return WebSubscriptionReturnState.success;
  if (status.isFailed) return WebSubscriptionReturnState.failed;
  if (returnPath.endsWith('/3d-fail')) {
    return WebSubscriptionReturnState.cancelled;
  }
  return WebSubscriptionReturnState.pending;
}

class WebSubscriptionReturnPage extends StatefulWidget {
  const WebSubscriptionReturnPage({
    super.key,
    required this.orderId,
    required this.returnPath,
  });

  final String orderId;
  final String returnPath;

  @override
  State<WebSubscriptionReturnPage> createState() =>
      _WebSubscriptionReturnPageState();
}

class _WebSubscriptionReturnPageState extends State<WebSubscriptionReturnPage> {
  final WebSubscriptionService _service = WebSubscriptionService();
  WebSubscriptionReturnState _state = WebSubscriptionReturnState.verifying;
  Timer? _timer;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!kIsWeb || widget.orderId.isEmpty) {
      if (mounted) {
        setState(() => _state = WebSubscriptionReturnState.failed);
      }
      return;
    }
    try {
      final status = await _service.readStatus(widget.orderId);
      final next = webSubscriptionReturnState(
        returnPath: widget.returnPath,
        status: status,
      );
      if (!mounted) return;
      if (next == WebSubscriptionReturnState.success) {
        await context.read<AppState>().loadSubscriptionFromFirestore();
        if (!mounted) return;
      }
      setState(() => _state = next);
      if (next == WebSubscriptionReturnState.pending && _attempts < 12) {
        _attempts++;
        _timer = Timer(const Duration(seconds: 2), _verify);
      }
    } catch (_) {
      if (!mounted) return;
      if (_attempts < 12) {
        _attempts++;
        _timer = Timer(const Duration(seconds: 2), _verify);
      } else {
        setState(() => _state = WebSubscriptionReturnState.failed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (icon, title, message, color) = switch (_state) {
      WebSubscriptionReturnState.verifying => (
        Icons.sync,
        l10n.webSubscriptionVerifyingTitle,
        l10n.webSubscriptionVerifyingMessage,
        Colors.orange,
      ),
      WebSubscriptionReturnState.success => (
        Icons.check_circle,
        l10n.webSubscriptionSuccessTitle,
        l10n.webSubscriptionSuccessMessage,
        Colors.green,
      ),
      WebSubscriptionReturnState.failed => (
        Icons.error,
        l10n.webSubscriptionFailedTitle,
        l10n.webSubscriptionFailedMessage,
        Colors.red,
      ),
      WebSubscriptionReturnState.cancelled => (
        Icons.cancel,
        l10n.webSubscriptionCancelledTitle,
        l10n.webSubscriptionCancelledMessage,
        Colors.orange,
      ),
      WebSubscriptionReturnState.pending => (
        Icons.hourglass_top,
        l10n.webSubscriptionPendingTitle,
        l10n.webSubscriptionPendingMessage,
        Colors.orange,
      ),
    };
    return Scaffold(
      backgroundColor: const Color(0xFF120914),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_state == WebSubscriptionReturnState.verifying ||
                      _state == WebSubscriptionReturnState.pending)
                    CircularProgressIndicator(color: color)
                  else
                    Icon(icon, color: color, size: 64),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  if (_state != WebSubscriptionReturnState.verifying &&
                      _state != WebSubscriptionReturnState.pending) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/', (_) => false),
                      child: Text(l10n.continueLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
