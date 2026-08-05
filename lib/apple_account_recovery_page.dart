import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'services/social_auth_service.dart';

enum AppleRecoveryChoice { createNewAccount, existingAccount }

class AppleAccountRecoveryChoicePage extends StatelessWidget {
  const AppleAccountRecoveryChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to PetSupo',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                "This Apple account hasn't been set up yet.",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                "If you're new to PetSupo, create a new account.\n\n"
                "If you've used PetSupo before, sign into your existing account "
                "and we'll connect your Apple ID.",
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(AppleRecoveryChoice.createNewAccount),
                child: const Text('Create New Account'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(AppleRecoveryChoice.existingAccount),
                child: const Text('I Already Have a PetSupo Account'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppleAccountRecoveryProviderPage extends StatefulWidget {
  const AppleAccountRecoveryProviderPage({super.key});

  @override
  State<AppleAccountRecoveryProviderPage> createState() =>
      _AppleAccountRecoveryProviderPageState();
}

class _AppleAccountRecoveryProviderPageState
    extends State<AppleAccountRecoveryProviderPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } on SocialAuthCancelled {
      if (mounted) {
        _showError(AppLocalizations.of(context)!.authenticationCancelled);
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showError(
          error.code == 'account-exists-with-different-credential' ||
                  error.code == 'credential-already-in-use'
              ? AppLocalizations.of(context)!.emailRegisteredWithAnotherProvider
              : AppLocalizations.of(context)!.unableToSignIn,
        );
      }
    } catch (_) {
      if (mounted) _showError(AppLocalizations.of(context)!.unableToSignIn);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    await _authenticate(() async {
      await SocialAuthService().authenticateGoogleForAccountRecovery();
    });
  }

  Future<void> _email() async {
    await _authenticate(
      () => FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in to PetSupo')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _google,
            icon: const Icon(Icons.login),
            label: Text(l10n.continueWithGoogle),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.emailLabel),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.passwordLabel),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loading ? null : _email,
            child: Text(l10n.signInButton),
          ),
          if (_loading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
