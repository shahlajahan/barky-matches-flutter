import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PetshopCheckoutWebViewPage extends StatefulWidget {
  final String checkoutUrl;
  final String successUrlPrefix;
  final String cancelUrlPrefix;
  final String orderId;

  const PetshopCheckoutWebViewPage({
    super.key,
    required this.checkoutUrl,
    required this.successUrlPrefix,
    required this.cancelUrlPrefix,
    required this.orderId,
  });

  @override
  State<PetshopCheckoutWebViewPage> createState() =>
      _PetshopCheckoutWebViewPageState();
}

class _PetshopCheckoutWebViewPageState
    extends State<PetshopCheckoutWebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _didFinish = false;

  void _finish(String result) {
    if (_didFinish || !mounted) return;
    _didFinish = true;
    Navigator.pop(context, result);
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint("🌐 WEBVIEW START: $url");
            if (mounted) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (url) {
            debugPrint("✅ WEBVIEW FINISH: $url");
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            debugPrint("❌ WEBVIEW ERROR: ${error.description}");
          },
          onNavigationRequest: (request) {
  final url = request.url;
  debugPrint("🌐 WEBVIEW NAV URL: $url");

  if (url.contains(widget.successUrlPrefix)) {
    _finish("verify");
    return NavigationDecision.prevent;
  }

  if (url.contains(widget.cancelUrlPrefix)) {
    _finish("cancel");
    return NavigationDecision.prevent;
  }

  return NavigationDecision.navigate;
},
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
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