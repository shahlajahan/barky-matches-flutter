import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/ui/petshop/isbank_checkout_webview_page.dart';

enum PetshopReturnNavigation { success, failure, none }

PetshopReturnNavigation classifyPetshopReturnNavigation(
  String url, {
  required String expectedOrderId,
}) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme || expectedOrderId.isEmpty) {
    return PetshopReturnNavigation.none;
  }

  final host = uri.host.toLowerCase();
  final path = uri.path.replaceAll(RegExp(r'/+$'), '').toLowerCase();

  final isLegacySuccess =
      uri.scheme.toLowerCase() == 'barkymatches' && host == 'payment-success';
  final isLegacyFailure =
      uri.scheme.toLowerCase() == 'barkymatches' && host == 'payment-cancel';

  final isCanonicalHost = host == 'app.petsupo.com';
  final isCanonicalSuccess =
      isCanonicalHost &&
      (path == '/payment-callback' ||
          path == '/payment-success' ||
          path == '/promotion-payment-return');
  final isCanonicalFailure = isCanonicalHost && path == '/payment-cancel';

  if (isLegacySuccess || isCanonicalSuccess) {
    return PetshopReturnNavigation.success;
  }
  if (isLegacyFailure || isCanonicalFailure) {
    return PetshopReturnNavigation.failure;
  }

  // İş Bank has separate provider return routes. Reuse the existing strict
  // host/path allowlist; this only classifies the navigation and never proves
  // that payment succeeded.
  final isbank = classifyIsbankReturnNavigation(
    url,
    expectedOrderId: expectedOrderId,
  );
  switch (isbank) {
    case IsbankReturnNavigation.success:
      return PetshopReturnNavigation.success;
    case IsbankReturnNavigation.failure:
      return PetshopReturnNavigation.failure;
    case IsbankReturnNavigation.none:
      return PetshopReturnNavigation.none;
  }
}

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

            switch (classifyPetshopReturnNavigation(
              url,
              expectedOrderId: widget.orderId,
            )) {
              case PetshopReturnNavigation.success:
                _finish("verify");
                return NavigationDecision.prevent;
              case PetshopReturnNavigation.failure:
                _finish("cancel");
                return NavigationDecision.prevent;
              case PetshopReturnNavigation.none:
                break;
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
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.securePayment)),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
