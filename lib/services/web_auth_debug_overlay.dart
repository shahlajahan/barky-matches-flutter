import 'package:flutter/material.dart';

import 'web_auth_debug_platform.dart';

final ValueNotifier<List<String>> webAuthDebugEntries =
    ValueNotifier<List<String>>(const []);

void initWebAuthDebugOverlay() {
  if (!webAuthDebugEnabled) return;
  webAuthDebugEntries.value = loadWebAuthDebugEntries();
}

void webAuthDebugLog(String event, [Map<String, Object?> details = const {}]) {
  if (!webAuthDebugEnabled) return;
  final suffix = details.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' ');
  final entry =
      '${DateTime.now().toIso8601String()} $event${suffix.isEmpty ? '' : ' $suffix'}';
  final entries = <String>[...webAuthDebugEntries.value, entry];
  webAuthDebugEntries.value = entries;
  persistWebAuthDebugEntries(entries);
}

void webAuthTrace(String event, [Map<String, Object?> details = const {}]) {
  final suffix = details.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' ');
  final message =
      '${DateTime.now().toIso8601String()} $event${suffix.isEmpty ? '' : ' $suffix'}';
  debugPrint(message);
  webAuthConsoleLog(message);
  if (webAuthDebugEnabled) {
    webAuthDebugLog(event, details);
  }
}

void clearWebAuthDebugEntries() {
  if (!webAuthDebugEnabled) return;
  webAuthDebugEntries.value = const [];
  persistWebAuthDebugEntries(const []);
}

class WebAuthDebugOverlay extends StatelessWidget {
  const WebAuthDebugOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!webAuthDebugEnabled) return child;
    return Stack(
      children: [
        child,
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _WebAuthDebugPanel(),
        ),
      ],
    );
  }
}

class _WebAuthDebugPanel extends StatelessWidget {
  const _WebAuthDebugPanel();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.92),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 220,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Auth diagnostics',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await copyWebAuthDebugEntries(
                          webAuthDebugEntries.value.join('\n'),
                        );
                      },
                      child: const Text('Copy'),
                    ),
                    TextButton(
                      onPressed: clearWebAuthDebugEntries,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white24),
              Expanded(
                child: ValueListenableBuilder<List<String>>(
                  valueListenable: webAuthDebugEntries,
                  builder: (context, entries, _) {
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[entries.length - index - 1];
                        return Text(
                          entry,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
