import '../models/product.dart';
import '../models/seller_shipping_config.dart';

class ShippingResult {
  final double cost;
  final String payer;
  final String method;
  final double desi;

  ShippingResult({
    required this.cost,
    required this.payer,
    required this.method,
    required this.desi,
  });
}

class ShippingEngine {
  static double calculateDesi({
    required double length,
    required double width,
    required double height,
    double? fixedDesi,
  }) {
    if (fixedDesi != null && fixedDesi > 0) {
      return fixedDesi;
    }

    final desi = (length * width * height) / 3000;
    return double.parse(desi.toStringAsFixed(2));
  }

  static ShippingResult calculateShipping({
    required Product product,
    required SellerShippingConfig config,
    required double cartTotal,
  }) {
    // =========================
    // 🚫 NOT SHIPPABLE
    // =========================
    if (!product.isShippable || product.deliveryType != 'cargo') {
      return ShippingResult(
        cost: 0,
        payer: "none",
        method: "no_shipping",
        desi: 0,
      );
    }

    // =========================
    // 📦 DESI
    // =========================
    final desi = calculateDesi(
      length: product.lengthCm ?? 1,
      width: product.widthCm ?? 1,
      height: product.heightCm ?? 1,
      fixedDesi: product.fixedDesi,
    );

    // =========================
    // 🎯 FREE SHIPPING CHECK
    // =========================
    if (config.freeShippingThreshold != null &&
        cartTotal >= config.freeShippingThreshold!) {
      return ShippingResult(
        cost: 0,
        payer: "seller",
        method: "free_shipping",
        desi: desi,
      );
    }

    // =========================
    // 💰 FIXED MODEL
    // =========================
    if (config.pricingModel == "fixed") {
      final fee = config.fixedShippingFee ?? 0;

      return ShippingResult(
        cost: fee,
        payer: config.shippingPayer,
        method: "fixed",
        desi: desi,
      );
    }

    // =========================
    // 🚚 CARRIER BASED (FAKE MVP)
    // =========================
    if (config.pricingModel == "carrier_based") {
      final tariffs = [
        {"max": 1.0, "price": 59.9},
        {"max": 3.0, "price": 79.9},
        {"max": 5.0, "price": 94.9},
        {"max": 10.0, "price": 129.9},
        {"max": 20.0, "price": 169.9},
        {"max": 30.0, "price": 229.9},
      ];

      double price = tariffs.last["price"] as double;

      for (final t in tariffs) {
        if (desi <= (t["max"] as double)) {
          price = t["price"] as double;
          break;
        }
      }

      return ShippingResult(
        cost: double.parse(price.toStringAsFixed(2)),
        payer: config.shippingPayer,
        method: "carrier_estimated",
        desi: desi,
      );
    }

    // =========================
    // 🆓 FREE MODE
    // =========================
    if (config.pricingModel == "free") {
      return ShippingResult(
        cost: 0,
        payer: "seller",
        method: "free",
        desi: desi,
      );
    }

    // =========================
    // 🔥 FALLBACK
    // =========================
    return ShippingResult(
      cost: 0,
      payer: "buyer",
      method: "fallback",
      desi: desi,
    );
  }
}
