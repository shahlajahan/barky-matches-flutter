import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'welcome_page.dart';
import 'home_gate.dart';
import 'app_state.dart';

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🧨 AppEntry.build');

    final appState = context.watch<AppState>();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const WelcomePage();
    }

    if (!appState.isUserProfileReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const HomeGate();
  }
}
