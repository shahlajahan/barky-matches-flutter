// lib/constants/vaccine_catalog.dart

class VaccineCatalogItem {
  final String id;

  final Map<String, String> name;

  final List<String> petTypes;

  final String frequencyType;

  final int defaultIntervalDays;

  final String category;

  final bool isActive;

  const VaccineCatalogItem({
    required this.id,
    required this.name,
    required this.petTypes,
    required this.frequencyType,
    required this.defaultIntervalDays,
    required this.category,
    this.isActive = true,
  });

  String localizedName(String langCode) {
    return name[langCode] ?? name['en'] ?? name.values.first;
  }
}

class VaccineCatalog {
  static const List<VaccineCatalogItem> all = [
    // =========================
    // 🐶 DOG
    // =========================
    VaccineCatalogItem(
      id: 'dog_rabies',

      name: {'tr': 'Kuduz', 'en': 'Rabies', 'fa': 'هاری', 'ru': 'Бешенство'},

      petTypes: ['dog'],

      frequencyType: 'yearly',

      defaultIntervalDays: 365,

      category: 'core',
    ),

    VaccineCatalogItem(
      id: 'dog_parvo',

      name: {
        'tr': 'Parvovirüs',
        'en': 'Parvovirus',
        'fa': 'پاروویروس',
        'ru': 'Парвовирус',
      },

      petTypes: ['dog'],

      frequencyType: 'yearly',

      defaultIntervalDays: 365,

      category: 'core',
    ),

    VaccineCatalogItem(
      id: 'dog_distemper',

      name: {
        'tr': 'Gençlik Hastalığı',
        'en': 'Distemper',
        'fa': 'دیستمپر',
        'ru': 'Чума плотоядных',
      },

      petTypes: ['dog'],

      frequencyType: 'yearly',

      defaultIntervalDays: 365,

      category: 'core',
    ),

    VaccineCatalogItem(
      id: 'dog_internal_parasite',

      name: {
        'tr': 'İç Parazit',
        'en': 'Internal Parasite',
        'fa': 'انگل داخلی',
        'ru': 'Внутренние паразиты',
      },

      petTypes: ['dog'],

      frequencyType: 'monthly',

      defaultIntervalDays: 30,

      category: 'parasite',
    ),

    VaccineCatalogItem(
      id: 'dog_external_parasite',

      name: {
        'tr': 'Dış Parazit',
        'en': 'External Parasite',
        'fa': 'انگل خارجی',
        'ru': 'Внешние паразиты',
      },

      petTypes: ['dog'],

      frequencyType: 'monthly',

      defaultIntervalDays: 30,

      category: 'parasite',
    ),

    // =========================
    // 🐱 CAT
    // =========================
    VaccineCatalogItem(
      id: 'cat_rabies',

      name: {'tr': 'Kuduz', 'en': 'Rabies', 'fa': 'هاری', 'ru': 'Бешенство'},

      petTypes: ['cat'],

      frequencyType: 'yearly',

      defaultIntervalDays: 365,

      category: 'core',
    ),

    VaccineCatalogItem(
      id: 'cat_fvrcp',

      name: {'tr': 'FVRCP', 'en': 'FVRCP', 'fa': 'واکسن FVRCP', 'ru': 'FVRCP'},

      petTypes: ['cat'],

      frequencyType: 'yearly',

      defaultIntervalDays: 365,

      category: 'core',
    ),

    VaccineCatalogItem(
      id: 'cat_leukemia',

      name: {
        'tr': 'Lösemi',
        'en': 'Feline Leukemia',
        'fa': 'لوسمی گربه',
        'ru': 'Лейкемия кошек',
      },

      petTypes: ['cat'],

      frequencyType: 'yearly',

      defaultIntervalDays: 365,

      category: 'core',
    ),

    VaccineCatalogItem(
      id: 'cat_internal_parasite',

      name: {
        'tr': 'İç Parazit',
        'en': 'Internal Parasite',
        'fa': 'انگل داخلی',
        'ru': 'Внутренние паразиты',
      },

      petTypes: ['cat'],

      frequencyType: 'monthly',

      defaultIntervalDays: 30,

      category: 'parasite',
    ),

    VaccineCatalogItem(
      id: 'cat_external_parasite',

      name: {
        'tr': 'Dış Parazit',
        'en': 'External Parasite',
        'fa': 'انگل خارجی',
        'ru': 'Внешние паразиты',
      },

      petTypes: ['cat'],

      frequencyType: 'monthly',

      defaultIntervalDays: 30,

      category: 'parasite',
    ),

    // =========================
    // 🐦 BIRD
    // =========================
    VaccineCatalogItem(
      id: 'bird_polyoma',

      name: {
        'tr': 'Polyomavirus',
        'en': 'Polyomavirus',
        'fa': 'پولیومای پرندگان',
        'ru': 'Полиомавирус',
      },

      petTypes: ['bird'],

      frequencyType: 'yearly',

      defaultIntervalDays: 365,

      category: 'core',
    ),

    // =========================
    // 🐰 RABBIT
    // =========================
    VaccineCatalogItem(
      id: 'rabbit_myxo',

      name: {
        'tr': 'Miksomatozis',
        'en': 'Myxomatosis',
        'fa': 'میکسوماتوز',
        'ru': 'Миксоматоз',
      },

      petTypes: ['rabbit'],

      frequencyType: 'yearly',

      defaultIntervalDays: 365,

      category: 'core',
    ),
  ];

  // =========================
  // HELPERS
  // =========================

  static List<VaccineCatalogItem> byPetType(String petType) {
    return all
        .where((v) => v.petTypes.contains(petType.toLowerCase()))
        .toList();
  }

  static VaccineCatalogItem? byId(String id) {
    try {
      return all.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }
}
