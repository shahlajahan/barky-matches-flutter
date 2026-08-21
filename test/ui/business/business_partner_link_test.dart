import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/notification_service.dart';
import 'package:barky_matches_fixed/services/analytics/web_campaign_attribution.dart';
import 'package:barky_matches_fixed/ui/business/business_register_page.dart';
import 'package:barky_matches_fixed/ui/business/partner_intake_context.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('category preselection uses canonical sector and remains editable', () {
    final sectors = BusinessRegisterPage.initialSelectedSectors('pet_shop');

    expect(sectors, ['pet_shop']);
    sectors
      ..remove('pet_shop')
      ..add('groomer');
    expect(sectors, ['groomer']);
  });

  test(
    'unsupported preselection is ignored and validation can still require sector',
    () {
      expect(BusinessRegisterPage.initialSelectedSectors('unknown'), isEmpty);
      expect(BusinessRegisterPage.initialSelectedSectors(null), isEmpty);
    },
  );

  test('bounded registration intent survives login and is consumed once', () {
    final appState = _buildAppState();
    final intake = PartnerIntakeContext.forCategory('pet_otel');

    appState.setPendingBusinessRegistrationIntent(
      initialSector: intake.initialSector,
      partnerIntakeContext: intake,
    );
    final first = appState.consumePendingBusinessRegistrationIntent();
    final second = appState.consumePendingBusinessRegistrationIntent();

    expect(first, isNotNull);
    expect(first!.initialSector, 'pet_hotel');
    expect(first.partnerIntakeContext, intake);
    expect(first.isPartnerIntake, isTrue);
    expect(second, isNull);
  });

  test('open business register stores initial sector on existing flow', () {
    final appState = _buildAppState();

    appState.openBusinessRegisterWithInitialSector(initialSector: 'pet_taxi');

    expect(appState.currentTab, NavTab.home);
    expect(appState.profileSubPage, ProfileSubPage.businessRegister);
    expect(appState.businessRegistrationInitialSector, 'pet_taxi');
    expect(appState.businessRegistrationPartnerIntakeContext, isNull);
  });

  test(
    'partner intake context can open register without changing subscription',
    () {
      final appState = _buildAppState();
      final intake = PartnerIntakeContext.forCategory('veteriner');

      appState.openBusinessRegisterWithInitialSector(
        initialSector: intake.initialSector,
        partnerIntakeContext: intake,
      );

      expect(appState.profileSubPage, ProfileSubPage.businessRegister);
      expect(appState.businessRegistrationInitialSector, 'veterinary');
      expect(appState.businessRegistrationPartnerIntakeContext, intake);
      expect(appState.isGold, isFalse);
    },
  );

  test(
    'normal app entry paths remain outside business partner route mapping',
    () {
      expect(WebCampaignAttribution.partnerCategoryForPath('/'), isNull);
      expect(
        WebCampaignAttribution.partnerCategoryForPath('/creator/dashboard'),
        isNull,
      );
      expect(
        WebCampaignAttribution.partnerCategoryForPath('/isbank/3d-success'),
        isNull,
      );
    },
  );

  test('partner intake context serializes bounded session values only', () {
    final intake = PartnerIntakeContext.forCategory('sahiplendirme');
    final restored = PartnerIntakeContext.tryParse(intake.toJson());

    expect(restored, isNotNull);
    expect(restored!.source, partnerIntakeSource);
    expect(restored.campaign, partnerIntakeCampaign);
    expect(restored.content, partnerIntakeContent);
    expect(restored.partnerCategory, 'sahiplendirme');
    expect(restored.initialSector, 'adoption_center');
  });

  test('editable submitted category keeps partner context pairing valid', () {
    final original = PartnerIntakeContext.forCategory('veteriner');
    final changed = original.forSubmittedSectors(['groomer']);
    final multiSector = original.forSubmittedSectors(['veterinary', 'groomer']);

    expect(changed.partnerCategory, 'groomer');
    expect(changed.initialSector, 'groomer');
    expect(changed.isValid, isTrue);
    expect(multiSector.partnerCategory, 'general');
    expect(multiSector.initialSector, isNull);
    expect(multiSector.isValid, isTrue);
  });

  test('tampered partner intake session values are rejected', () {
    expect(
      PartnerIntakeContext.tryParse({
        'source': partnerIntakeSource,
        'campaign': partnerIntakeCampaign,
        'content': partnerIntakeContent,
        'partnerCategory': 'veteriner',
        'initialSector': 'pet_shop',
      }),
      isNull,
    );
    expect(
      PartnerIntakeContext.tryParse({
        'source': partnerIntakeSource,
        'campaign': partnerIntakeCampaign,
        'content': partnerIntakeContent,
        'partnerCategory': 'veteriner',
        'initialSector': 'veterinary',
        'redirectUrl': 'https://example.com',
      }),
      isNull,
    );
  });
}

AppState _buildAppState() {
  return AppState(
    favoriteDogs: <Dog>[],
    favoriteDogsNotifier: ValueNotifier<List<Dog>>(<Dog>[]),
    likesNotifier: ValueNotifier<Map<String, List<String>>>(
      <String, List<String>>{},
    ),
    onToggleFavorite: (_) async {},
    notificationService: NotificationService(),
    currentUserId: 'test-user',
  );
}
