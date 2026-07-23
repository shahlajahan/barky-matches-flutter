import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

import 'sections/diagnostics_section.dart';

class DeveloperToolsPage extends StatelessWidget {
  const DeveloperToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (kReleaseMode) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
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
