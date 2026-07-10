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

class _IsbankCheckoutWebViewPageState extends State<IsbankCheckoutWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _didFinish = false;

  static const String _successPath = '/isbank/3d-success';
  static const String _failPath = '/isbank/3d-fail';

  void _finish(String result) {
    if (_didFinish || !mounted) return;
    _didFinish = true;
    Navigator.pop(context, result);
  }

  bool _matchesPath(String url, String needle) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url.contains(needle);
    return uri.path.contains(needle) || url.contains(needle);
  }

  @override
  void initState() {
    super.initState();
    debugPrint('🧾 ISBANK CHECKOUT WEBVIEW OPENED → orderId=${widget.orderId}');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          
          onPageStarted: (url) {
            debugPrint('🌐 ISBANK WEBVIEW START: $url');
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (url) async {
  debugPrint('✅ ISBANK WEBVIEW FINISH: $url');

  try {
    final html = await _controller.runJavaScriptReturningResult(
      'document.documentElement.outerHTML',
    );

    debugPrint(
  html.toString(),
  wrapWidth: 100000,
);
  } catch (e) {
    debugPrint('❌ HTML READ ERROR: $e');
  }

  if (mounted) {
    setState(() => _isLoading = false);
  }
},
          onWebResourceError: (error) {
  debugPrint(
    '❌ ISBANK WEBVIEW ERROR: ${error.errorCode} ${error.description}',
  );
},
          onNavigationRequest: (request) {
            final url = request.url;
            debugPrint('🌐 ISBANK WEBVIEW NAV URL: $url');

            if (_matchesPath(url, _successPath)) {
              _finish('verify');
              return NavigationDecision.prevent;
            }

            if (_matchesPath(url, _failPath)) {
              _finish('cancel');
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(widget.html);
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
