import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/auth_page.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/home_gate.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/partner_intake_context.dart';
import 'package:barky_matches_fixed/ui/business/partner_intake_session_store.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';

class BusinessPartnerLandingPage extends StatelessWidget {
  const BusinessPartnerLandingPage({
    required this.partnerCategory,
    required this.initialSector,
    super.key,
  });

  final String partnerCategory;
  final String? initialSector;

  String get _categoryLabel {
    switch (partnerCategory) {
      case 'veteriner':
        return 'Veteriner kliniği';
      case 'pet_otel':
        return 'Pet otel';
      case 'pet_taksi':
        return 'Pet taksi';
      case 'groomer':
        return 'Groomer';
      case 'pet_shop':
        return 'Pet shop';
      case 'sahiplendirme':
        return 'Sahiplendirme merkezi';
      default:
        return 'Genel işletme';
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final signedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F4),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Petsupo işletme başvurusu',
                    style: AppTheme.h1(size: 30),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'İşletmenizi Petsupo’ya eklemek için başvurunuzu oluşturabilirsiniz. Seçilen işletme kategorisini başvuru formunda değiştirebilirsiniz.',
                    style: AppTheme.body().copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE8DDD6)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Algılanan kategori',
                            style: AppTheme.body().copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_categoryLabel, style: AppTheme.body()),
                          const SizedBox(height: 12),
                          Text(
                            'Bu kategori başvuru formunda başlangıç seçimi olarak kullanılabilir. Formda kategoriyi değiştirebilir ve tüm zorunlu bilgileri tamamlamanız gerekir.',
                            style: AppTheme.body().copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Lansman döneminde bu bağlantı üzerinden başvuran ve onaylanan işletmelere ilk ay Gold üyelik ücretsiz olarak tanımlanır.',
                    style: AppTheme.body().copyWith(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Başvuru ücretsizdir. Gold üyelik, işletme başvurusu incelenip onaylandıktan sonra Petsupo ekibi tarafından tanımlanır.',
                    style: AppTheme.body().copyWith(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _continue(context, appState, signedIn),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9E1B4F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      signedIn
                          ? 'İşletme başvurusuna devam et'
                          : 'Giriş yap veya hesap oluştur',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _continue(BuildContext context, AppState appState, bool signedIn) {
    final intakeContext = PartnerIntakeContext.forCategory(partnerCategory);
    PartnerIntakeSessionStore.save(intakeContext);
    appState.setPendingBusinessRegistrationIntent(
      initialSector: intakeContext.initialSector,
      partnerIntakeContext: intakeContext,
    );

    if (signedIn) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeGate()));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthPage(
          isLogin: false,
          favoriteDogs: const <Dog>[],
          onToggleFavorite: (_) {},
          onAuthSuccess: () {
            appState.setCurrentTab(NavTab.profile);
          },
        ),
      ),
    );
  }
}
