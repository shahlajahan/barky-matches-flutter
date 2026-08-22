import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/services/web_advertising_service.dart';

class WebAdSlot extends StatefulWidget {
  const WebAdSlot({
    super.key,
    required this.placementKey,
    required this.shouldShowAds,
    this.width = double.infinity,
    this.height = 90,
  });

  final String placementKey;
  final bool shouldShowAds;
  final double width;
  final double height;

  @override
  State<WebAdSlot> createState() => _WebAdSlotState();
}

class _WebAdSlotState extends State<WebAdSlot> {
  late final String _elementId;
  WebAdvertisingService? _service;
  WebAdDecision _decision = const WebAdDecision.suppressed('not_started');

  @override
  void initState() {
    super.initState();
    _elementId = 'petsupo-ad-${widget.placementKey}-${identityHashCode(this)}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _service = context.read<WebAdvertisingService>();
    _scheduleRequest();
  }

  @override
  void didUpdateWidget(covariant WebAdSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placementKey != widget.placementKey ||
        oldWidget.shouldShowAds != widget.shouldShowAds) {
      _service?.disposeSlot(_elementId);
      _scheduleRequest();
    }
  }

  void _scheduleRequest() {
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final service = _service;
      if (service == null) return;
      final decision = await service.requestSlot(
        placementKey: widget.placementKey,
        elementId: _elementId,
        shouldShowAds: widget.shouldShowAds,
      );
      if (!mounted) return;
      setState(() {
        _decision = decision;
      });
    });
  }

  @override
  void dispose() {
    _service?.disposeSlot(_elementId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_decision.reserveSpace) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Semantics(
        label: _decision.showPlaceholder
            ? 'Ad test placeholder'
            : 'Advertisement',
        container: true,
        child: Container(
          width: widget.width,
          height: widget.height,
          constraints: const BoxConstraints(maxWidth: 728, minHeight: 90),
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: _decision.showPlaceholder
              ? BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  border: Border.all(color: const Color(0xFFD8D8D8)),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: _decision.showPlaceholder
              ? const Text(
                  'Ad test placeholder',
                  style: TextStyle(
                    color: Color(0xFF606060),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : HtmlElementPlaceholder(elementId: _elementId),
        ),
      ),
    );
  }
}

class HtmlElementPlaceholder extends StatelessWidget {
  const HtmlElementPlaceholder({super.key, required this.elementId});

  final String elementId;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(key: ValueKey<String>(elementId));
  }
}
