import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum IsbankReturnNavigation { none, success, failure }

IsbankReturnNavigation classifyIsbankReturnNavigation(
  String url, {
  required String expectedOrderId,
}) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    return IsbankReturnNavigation.none;
  }

  final host = uri.host.toLowerCase();
  final isConfiguredHost =
      host == 'app.petsupo.com' ||
      host == 'barkymatches-new.web.app' ||
      (host.endsWith('.a.run.app') &&
          (host.startsWith('isbank3dsuccessreturn-') ||
              host.startsWith('isbank3dfailreturn-'))) ||
      (host == 'europe-west3-barkymatches-new.cloudfunctions.net');
  if (!isConfiguredHost) {
    return IsbankReturnNavigation.none;
  }

  final callbackOrderId = uri.queryParameters['oid'];
  if (callbackOrderId != null &&
      callbackOrderId.isNotEmpty &&
      callbackOrderId != expectedOrderId) {
    return IsbankReturnNavigation.none;
  }

  final normalizedPath = uri.path.length > 1 && uri.path.endsWith('/')
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  final webReturn = uri.queryParameters['webSubscriptionReturn'];

  if (normalizedPath == '/isbank/3d-success' ||
      normalizedPath == '/isbank3DSuccessReturn' ||
      webReturn == 'success') {
    return IsbankReturnNavigation.success;
  }
  if (normalizedPath == '/isbank/3d-fail' ||
      normalizedPath == '/isbank3DFailReturn' ||
      webReturn == 'fail') {
    return IsbankReturnNavigation.failure;
  }
  return IsbankReturnNavigation.none;
}

class IsbankCheckoutWebViewPage extends StatefulWidget {
  final String html;
  final String orderId;

  const IsbankCheckoutWebViewPage({
    super.key,
    required this.html,
    required this.orderId,
  });

  @override
  State<IsbankCheckoutWebViewPage> createState() =>
      _IsbankCheckoutWebViewPageState();
}

class _IsbankCheckoutWebViewPageState extends State<IsbankCheckoutWebViewPage> {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _didFinish = false;

  void _finish(String result) {
    debugPrint("🏁 FINISH CALLED: $result");

    if (_didFinish || !mounted) {
      debugPrint("⚠️ FINISH IGNORED (_didFinish=$_didFinish mounted=$mounted)");
      return;
    }

    _didFinish = true;

    debugPrint("⬅️ Navigator.pop($result)");
    Navigator.pop(context, result);
  }

  bool _handleReturnNavigation(String url) {
    final navigation = classifyIsbankReturnNavigation(
      url,
      expectedOrderId: widget.orderId,
    );
    switch (navigation) {
      case IsbankReturnNavigation.success:
        debugPrint('🎉 SUCCESS CALLBACK DETECTED');
        _finish('isbank_success_redirect');
        return true;
      case IsbankReturnNavigation.failure:
        debugPrint('💥 FAIL CALLBACK DETECTED');
        _finish('isbank_cancel');
        return true;
      case IsbankReturnNavigation.none:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint("🚀 PAGE STARTED");
            debugPrint("🌍 $url");

            // Android WebView can surface an HTTP 302 target here without
            // invoking onNavigationRequest for the redirect.
            if (_handleReturnNavigation(url)) return;
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (url) {
            debugPrint("✅ PAGE FINISHED");
            debugPrint("🌍 $url");

            if (_handleReturnNavigation(url)) return;
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            debugPrint("❌ WEB RESOURCE ERROR");
            debugPrint("Code: ${error.errorCode}");
            debugPrint("Type: ${error.errorType}");
            debugPrint("Description: ${error.description}");
            debugPrint("URL: ${error.url}");
          },
          onNavigationRequest: (request) {
            final url = request.url;

            debugPrint("➡️ NAVIGATION REQUEST");
            debugPrint("🌍 $url");

            if (_handleReturnNavigation(url)) {
              return NavigationDecision.prevent;
            }

            debugPrint("➡️ Navigation allowed");

            return NavigationDecision.navigate;
          },
        ),
      );

    debugPrint("📄 Loading HTML into WebView...");
    _controller.loadHtmlString(widget.html);
  }

  @override
  void dispose() {
    debugPrint("🧹 ISBANK WEBVIEW DISPOSE");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Payment')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
