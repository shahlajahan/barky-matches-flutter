class ShippingEstimateInput {
  final double weightKg;
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final double? fixedDesi;

  final bool isFragile;
  final bool isOversize;

  final String carrierCode;
  final double? itemPrice;
  final double? freeShippingThreshold;

  ShippingEstimateInput({
    required this.weightKg,
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
    required this.carrierCode,
    this.fixedDesi,
    this.isFragile = false,
    this.isOversize = false,
    this.itemPrice,
    this.freeShippingThreshold,
  });
}

class ShippingEstimateResult {
  final double computedDesi;
  final double effectiveUnit;
  final double basePrice;
  final double surcharge;
  final double total;
  final bool isFreeShipping;

  ShippingEstimateResult({
    required this.computedDesi,
    required this.effectiveUnit,
    required this.basePrice,
    required this.surcharge,
    required this.total,
    required this.isFreeShipping,
  });
}

class ShippingEstimator {
  /// 📦 DESI
  static double computeDesi(double l, double w, double h) {
    if (l <= 0 || w <= 0 || h <= 0) return 0;
    return (l * w * h) / 3000;
  }

  /// ⚖️ BILLABLE UNIT
  static double effectiveUnit({
    required double weight,
    required double desi,
  }) {
    return weight > desi ? weight : desi;
  }

  /// 💰 TARIF TABLE (قابل تغییر بعداً از Firestore)
  static final Map<String, List<Map<String, dynamic>>> tariffs = {
    "Yurtici": [
      {"max": 1, "price": 59.9},
      {"max": 3, "price": 79.9},
      {"max": 5, "price": 94.9},
      {"max": 10, "price": 129.9},
      {"max": 20, "price": 169.9},
      {"max": 30, "price": 229.9},
    ],
  };

  static ShippingEstimateResult calculate(ShippingEstimateInput input) {
    final desi = input.fixedDesi != null && input.fixedDesi! > 0
        ? input.fixedDesi!
        : computeDesi(
            input.lengthCm,
            input.widthCm,
            input.heightCm,
          );

    final unit = effectiveUnit(
      weight: input.weightKg,
      desi: desi,
    );

    final carrierTariff = tariffs[input.carrierCode] ?? tariffs["Yurtici"]!;

    double basePrice = carrierTariff.last["price"];

    for (final bracket in carrierTariff) {
      if (unit <= bracket["max"]) {
        basePrice = bracket["price"];
        break;
      }
    }

    double surcharge = 0;

    if (input.isFragile) surcharge += 15;
    if (input.isOversize) surcharge += 25;

    double total = basePrice + surcharge;

    bool isFree = false;

    if (input.freeShippingThreshold != null &&
        input.itemPrice != null &&
        input.itemPrice! >= input.freeShippingThreshold!) {
      total = 0;
      isFree = true;
    }

    return ShippingEstimateResult(
      computedDesi: desi,
      effectiveUnit: unit,
      basePrice: basePrice,
      surcharge: surcharge,
      total: total,
      isFreeShipping: isFree,
    );
  }
}