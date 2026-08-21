const String partnerIntakeSource = 'partner_email';
const String partnerIntakeCampaign = 'partner_outreach_2026';
const String partnerIntakeContent = 'welcome_email';

const Map<String, String?> partnerIntakeInitialSectors = {
  'general': null,
  'veteriner': 'veterinary',
  'pet_otel': 'pet_hotel',
  'pet_taksi': 'pet_taxi',
  'groomer': 'groomer',
  'pet_shop': 'pet_shop',
  'sahiplendirme': 'adoption_center',
};

const Map<String, String> partnerIntakeCategoriesBySector = {
  'veterinary': 'veteriner',
  'pet_hotel': 'pet_otel',
  'pet_taxi': 'pet_taksi',
  'groomer': 'groomer',
  'pet_shop': 'pet_shop',
  'adoption_center': 'sahiplendirme',
};

class PartnerIntakeContext {
  const PartnerIntakeContext({
    required this.source,
    required this.campaign,
    required this.content,
    required this.partnerCategory,
    this.initialSector,
  });

  factory PartnerIntakeContext.forCategory(String partnerCategory) {
    final initialSector = partnerIntakeInitialSectors[partnerCategory];
    if (!partnerIntakeInitialSectors.containsKey(partnerCategory)) {
      throw ArgumentError.value(
        partnerCategory,
        'partnerCategory',
        'Unsupported partner category',
      );
    }
    return PartnerIntakeContext(
      source: partnerIntakeSource,
      campaign: partnerIntakeCampaign,
      content: partnerIntakeContent,
      partnerCategory: partnerCategory,
      initialSector: initialSector,
    );
  }

  factory PartnerIntakeContext.forSelectedSectors(
    List<String> selectedSectors,
  ) {
    final category = selectedSectors.length == 1
        ? partnerIntakeCategoriesBySector[selectedSectors.single] ?? 'general'
        : 'general';
    return PartnerIntakeContext.forCategory(category);
  }

  final String source;
  final String campaign;
  final String content;
  final String partnerCategory;
  final String? initialSector;

  bool get isValid {
    if (source != partnerIntakeSource ||
        campaign != partnerIntakeCampaign ||
        content != partnerIntakeContent) {
      return false;
    }
    if (!partnerIntakeInitialSectors.containsKey(partnerCategory)) {
      return false;
    }
    return partnerIntakeInitialSectors[partnerCategory] == initialSector;
  }

  Map<String, Object?> toJson() {
    return {
      'source': source,
      'campaign': campaign,
      'content': content,
      'partnerCategory': partnerCategory,
      if (initialSector != null) 'initialSector': initialSector,
    };
  }

  Map<String, Object?> toRegisterBusinessPayload() {
    return {
      'source': source,
      'campaign': campaign,
      'content': content,
      'partnerCategory': partnerCategory,
      if (initialSector != null) 'initialSector': initialSector,
    };
  }

  PartnerIntakeContext forSubmittedSectors(List<String> selectedSectors) {
    return PartnerIntakeContext.forSelectedSectors(selectedSectors);
  }

  static PartnerIntakeContext? tryParse(Map<Object?, Object?>? value) {
    if (value == null) return null;
    if (value.keys.any((key) {
      return key != 'source' &&
          key != 'campaign' &&
          key != 'content' &&
          key != 'partnerCategory' &&
          key != 'initialSector';
    })) {
      return null;
    }

    final context = PartnerIntakeContext(
      source: value['source']?.toString() ?? '',
      campaign: value['campaign']?.toString() ?? '',
      content: value['content']?.toString() ?? '',
      partnerCategory: value['partnerCategory']?.toString() ?? '',
      initialSector: value['initialSector']?.toString(),
    );
    return context.isValid ? context : null;
  }
}
