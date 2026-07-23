import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

class _IsbankCheckoutWebViewPageState
    extends State<IsbankCheckoutWebViewPage> {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _didFinish = false;

  static const String _successPath = '/isbank/3d-success';
  static const String _failPath = '/isbank/3d-fail';

  void _finish(String result) {
    debugPrint("🏁 FINISH CALLED: $result");

    if (_didFinish || !mounted) {
      debugPrint(
        "⚠️ FINISH IGNORED (_didFinish=$_didFinish mounted=$mounted)",
      );
      return;
    }

    _didFinish = true;

    debugPrint("⬅️ Navigator.pop($result)");
    Navigator.pop(context, result);
  }

  bool _matchesPath(String url, String needle) {
    final uri = Uri.tryParse(url);

    if (uri == null) {
      return url.contains(needle);
    }

    return uri.path.contains(needle) || url.contains(needle);
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

            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (url) {
            debugPrint("✅ PAGE FINISHED");
            debugPrint("🌍 $url");

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

            if (_matchesPath(url, _successPath)) {
              debugPrint("🎉 SUCCESS CALLBACK DETECTED");
              _finish('isbank_success_redirect');
              return NavigationDecision.prevent;
            }

            if (_matchesPath(url, _failPath)) {
              debugPrint("💥 FAIL CALLBACK DETECTED");
              _finish('isbank_cancel');
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
      appBar: AppBar(
        title: const Text('Secure Payment'),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}