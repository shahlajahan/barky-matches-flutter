import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class TelegramUsersPage extends StatelessWidget {
  const TelegramUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.telegramUsers)),
      body: Center(child: Text(AppLocalizations.of(context)!.comingSoon)),
    );
  }
}
