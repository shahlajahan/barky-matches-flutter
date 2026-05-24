import 'dart:math' as math;

class IstanbulTaxiTariffConfig {
  final double openingFee;
  final double pricePerKm;
  final double minimumFare;
  final String currency;

  const IstanbulTaxiTariffConfig({
    required this.openingFee,
    required this.pricePerKm,
    required this.minimumFare,
    this.currency = 'TRY',
  });
}

class PetTaxiPricingRules {
  final IstanbulTaxiTariffConfig yellowTaxi;
  final double smallPetMultiplier;
  final double mediumPetMultiplier;
  final double largePetMultiplier;
  final double giantPetMultiplier;
  final double carrierRequiredFee;
  final double specialAssistanceFee;
  final double airportServiceFee;
  final double roundTripMultiplier;
  final String city;

  const PetTaxiPricingRules({
    required this.yellowTaxi,
    required this.smallPetMultiplier,
    required this.mediumPetMultiplier,
    required this.largePetMultiplier,
    required this.giantPetMultiplier,
    required this.carrierRequiredFee,
    required this.specialAssistanceFee,
    required this.airportServiceFee,
    required this.roundTripMultiplier,
    required this.city,
  });

  static const istanbul = PetTaxiPricingRules(
    city: 'istanbul',
    yellowTaxi: IstanbulTaxiTariffConfig(
      openingFee: 65.40,
      pricePerKm: 43.56,
      minimumFare: 210.00,
      currency: 'TRY',
    ),
    smallPetMultiplier: 1.10,
    mediumPetMultiplier: 1.15,
    largePetMultiplier: 1.25,
    giantPetMultiplier: 1.40,
    carrierRequiredFee: 75,
    specialAssistanceFee: 150,
    airportServiceFee: 200,
    roundTripMultiplier: 1.75,
  );

  String get currency => yellowTaxi.currency;
}

class PetTaxiPriceEstimate {
  final int minPrice;
  final int maxPrice;
  final String currency;
  final double approximateDistanceKm;
  final Map<String, dynamic> rulesSnapshot;

  const PetTaxiPriceEstimate({
    required this.minPrice,
    required this.maxPrice,
    required this.currency,
    required this.approximateDistanceKm,
    required this.rulesSnapshot,
  });
}

class PetTaxiPricingInput {
  final double routeDistanceKm;
  final int routeDurationMinutes;
  final String tripType;
  final String serviceReason;
  final String petSize;
  final bool largeDog;
  final bool cageCarrierRequired;
  final bool specialAssistanceRequired;
  final DateTime? scheduledAt;
  final Map<String, dynamic>? businessData;

  const PetTaxiPricingInput({
    required this.routeDistanceKm,
    required this.routeDurationMinutes,
    required this.tripType,
    required this.serviceReason,
    required this.petSize,
    required this.largeDog,
    required this.cageCarrierRequired,
    required this.specialAssistanceRequired,
    required this.scheduledAt,
    required this.businessData,
  });
}

class PetTaxiPricingService {
  const PetTaxiPricingService();

  Future<PetTaxiPriceEstimate> estimate(PetTaxiPricingInput input) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));

    // TODO: Load official city tariff from remote config/admin tariff settings.
    final rules = PetTaxiPricingRules.istanbul;
    final distanceKm = input.routeDistanceKm;

    final tariff = rules.yellowTaxi;
    final normalTaxiFare = math.max(
      tariff.minimumFare,
      tariff.openingFee + (distanceKm * tariff.pricePerKm),
    );
    final petMultiplier = _petMultiplier(input.petSize, input.largeDog, rules);

    var estimate = normalTaxiFare * petMultiplier;
    if (input.cageCarrierRequired) estimate += rules.carrierRequiredFee;
    if (input.specialAssistanceRequired) {
      estimate += rules.specialAssistanceFee;
    }
    if (input.serviceReason == 'airport') estimate += rules.airportServiceFee;
    if (input.tripType == 'round_trip') {
      estimate *= rules.roundTripMultiplier;
    }

    final min = (estimate * 0.95).round();
    final max = (estimate * 1.20).round();

    return PetTaxiPriceEstimate(
      minPrice: min,
      maxPrice: max,
      currency: rules.currency,
      approximateDistanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      rulesSnapshot: {
        'city': rules.city,
        'taxiType': 'yellowTaxi',
        'openingFee': tariff.openingFee,
        'pricePerKm': tariff.pricePerKm,
        'minimumFare': tariff.minimumFare,
        'normalTaxiFare': double.parse(normalTaxiFare.toStringAsFixed(2)),
        'routeDistanceKm': distanceKm,
        'routeDurationMinutes': input.routeDurationMinutes,
        'petMultiplier': petMultiplier,
        'carrierRequiredFee': rules.carrierRequiredFee,
        'specialAssistanceFee': rules.specialAssistanceFee,
        'airportServiceFee': rules.airportServiceFee,
        'roundTripMultiplier': rules.roundTripMultiplier,
        'nightMultiplierApplied': false,
        'waitingTimeFeeIncluded': false,
        'tollsIncluded': false,
        'currency': rules.currency,
        'source': 'istanbul_yellow_taxi_tariff_pet_taxi_v1',
      },
    );
  }

  double _petMultiplier(
    String petSize,
    bool largeDog,
    PetTaxiPricingRules rules,
  ) {
    final size = petSize.toLowerCase();
    if (size == 'giant') return rules.giantPetMultiplier;
    if (largeDog || size == 'large') return rules.largePetMultiplier;
    if (size == 'small') return rules.smallPetMultiplier;
    return rules.mediumPetMultiplier;
  }
}
