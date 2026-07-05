import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'sections/diagnostics_section.dart';

class DeveloperToolsPage extends StatelessWidget {
  const DeveloperToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Tools'),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: DiagnosticsSection(),
        ),
      ),
    );
  }
}
