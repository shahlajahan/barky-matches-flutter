import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ✅ FIXED PATHS
import '../../../models/product.dart';
import '../../../services/product_service.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../../models/product_media.dart';
import 'package:uuid/uuid.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../theme/app_theme.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/shipping_estimator.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../app_state.dart';
import 'package:mobile_scanner/mobile_scanner.dart';



class AddProductPage extends StatefulWidget {
  final String businessId;

final Product? existingProduct;

const AddProductPage({
  super.key,
  required this.businessId,
  this.existingProduct,
});
  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _desc = TextEditingController();
  final _stock = TextEditingController();
  final _barcode = TextEditingController();
final _brand = TextEditingController();
final _sku = TextEditingController();
final _salePrice = TextEditingController();
final _minStock = TextEditingController();
final _wholesalePrice = TextEditingController();
final _wholesaleMinQty = TextEditingController();
final _shippingFee = TextEditingController();
final _freeShippingThreshold = TextEditingController();
final _weightKg = TextEditingController();
final _lengthCm = TextEditingController();
final _widthCm = TextEditingController();
final _heightCm = TextEditingController();
final _fixedDesi = TextEditingController();
final _prepDays = TextEditingController();
final _maxDeliveryDays = TextEditingController();
final _returnWindowDays = TextEditingController();
ShippingEstimateResult? _shippingPreview;

String _shippingMode = "carrier_calculated"; 
// carrier_calculated | fixed_price | seller_absorbs | free_shipping

String _shippingPayer = "buyer"; 
// buyer | seller | conditional

String _returnShippingPayer = "seller_if_contract_carrier";
// seller_if_contract_carrier | buyer | seller_always

bool _allowFreeShipping = false;
bool _allowPickup = false;
bool _allowSameDay = false;
bool _isFragile = false;
bool _isPerishable = false;
bool _isOversize = false;
bool _allowReturns = true;
bool _cashOnDelivery = false; // only if later legally/operationally supported
bool _hasContractedReturnCarrier = true;

bool _isBarcodeLoading = false;
String? _barcodeStatusText;
Color? _barcodeStatusColor;

String _selectedReturnCarrier = "Yurtici";
List<String> _selectedCarriers = ["Yurtici"];
List<String> _excludedCities = [];

double? _calculatedDesi;

double? _kdvRate;



final List<Map<String, String>> _carrierOptions = [
  {"code": "YURTICI", "label": "Yurtiçi Kargo"},
  {"code": "ARAS", "label": "Aras Kargo"},
  {"code": "MNG", "label": "MNG Kargo"},
  {"code": "SURAT", "label": "Sürat Kargo"},
  {"code": "PTT", "label": "PTT Kargo"},
  {"code": "HEPSIJET", "label": "HepsiJET"},
  {"code": "KOLAYGELSIN", "label": "Kolay Gelsin"},
  {"code": "UPS", "label": "UPS Türkiye"},
  {"code": "DHL", "label": "DHL Express"},
];

final Map<String, List<String>> categories = {
  "Food": ["Dry Food", "Wet Food", "Treats"],
  "Accessories": ["Collar", "Leash", "Clothing"],
  "Health": ["Vitamins", "Medicine"],
  "Toys": ["Chew Toy", "Interactive"],
};

  File? _image;
  bool _loading = false;
 List<XFile> _media = [];
 bool _picking = false;
 Map<String, double> _progressMap = {};
 double _uploadProgress = 0;
 bool _hasDiscount = false;

  final _picker = ImagePicker();
  final _service = ProductService();
  bool get isEdit => widget.existingProduct != null;

String _mainCategory = "Food";
String _subCategory = "Dry Food";
String _currency = "TRY";

bool _barcodeMatched = false;
String? _priceSuggestionText;
double? _suggestedPrice;
double? _suggestedMinPrice;
double? _suggestedMaxPrice;
bool _isGeneratingDescription = false;
String? _barcodeSource;
double? _finalRecommendedPrice;
String? _pricingStrategy;
Timer? _barcodeTimer;
double? _marketAverage;
double? _marketMedian;
int? _marketSellerCount;

double? _bestMarketPrice;
double? _highestMarketPrice;

double? _competitorMin; // temporary backward compatibility
double? _competitorMax; // temporary backward compatibility

double? _profitMargin;
String? _marketPosition;

double? _priceGapPercent;
String? _marketSource;
Timestamp? _marketLastUpdatedAt;

bool _isSubmitting = false;

double _computeDesi() {
  final l = double.tryParse(_lengthCm.text.trim().replaceAll(",", ".")) ?? 0;
  final w = double.tryParse(_widthCm.text.trim().replaceAll(",", ".")) ?? 0;
  final h = double.tryParse(_heightCm.text.trim().replaceAll(",", ".")) ?? 0;

  if (l <= 0 || w <= 0 || h <= 0) return 0;

  final desi = (l * w * h) / 3000.0;
  return double.parse(desi.toStringAsFixed(3));
}

double _effectiveShippingUnit() {
  final weight = double.tryParse(_weightKg.text.replaceAll(",", ".")) ?? 0;
  final manualDesi = double.tryParse(_fixedDesi.text.replaceAll(",", "."));
  final desi = manualDesi != null && manualDesi > 0 ? manualDesi : _computeDesi();
  return desi > weight ? desi : weight;
}

void _refreshCalculatedDesi() {
  final desi = _computeDesi();

  setState(() {
    _calculatedDesi = desi;
  });

  debugPrint("📦 DESI CALCULATED = $_calculatedDesi");
}

Future<DocumentSnapshot<Map<String, dynamic>>> _getGlobalProductByBarcode(
  String barcode,
) {
  return FirebaseFirestore.instance
      .collection("global_products")
      .doc(barcode)
      .get();
}

void _updateShippingPreview() {
  final weight =
      double.tryParse(_weightKg.text.replaceAll(",", ".")) ?? 0;

  final l =
      double.tryParse(_lengthCm.text.trim().replaceAll(",", ".")) ?? 0;
  final w =
      double.tryParse(_widthCm.text.trim().replaceAll(",", ".")) ?? 0;
  final h =
      double.tryParse(_heightCm.text.trim().replaceAll(",", ".")) ?? 0;

  if (weight <= 0 ||
      ((l <= 0 || w <= 0 || h <= 0) && _fixedDesi.text.isEmpty)) {
    setState(() => _shippingPreview = null);
    return;
  }

  // 🔥 BEST CARRIER CALCULATION
  final best = getBestCarrier(
    carriers: _selectedCarriers,
    desi: _effectiveShippingUnit(),
  );

  final result = ShippingEstimator.calculate(
    ShippingEstimateInput(
      weightKg: weight,
      lengthCm: l,
      widthCm: w,
      heightCm: h,
      fixedDesi:
          double.tryParse(_fixedDesi.text.trim().replaceAll(",", ".")),
      isFragile: _isFragile,
      isOversize: _isOversize,
      carrierCode: best["carrier"], // 🔥 BEST carrier
      itemPrice:
          double.tryParse(_price.text.trim().replaceAll(",", ".")),
      freeShippingThreshold:
          double.tryParse(_freeShippingThreshold.text),
    ),
  );

  setState(() {
    _shippingPreview = result;
  });
}

Future<void> _loadMarketData(String barcode) async {
    if (FirebaseAuth.instance.currentUser == null) {
  debugPrint("⛔ NO AUTH → SKIP MARKET LOAD");
  return;
}
  debugPrint("🟡 ENTER _loadMarketData: $barcode");
  debugPrint("👤 USER: ${FirebaseAuth.instance.currentUser?.uid}");

  if (!mounted) return;

  try {
    // =========================
    // 📊 1. TRY AGGREGATE FIRST
    // =========================
    final aggregateDoc = await FirebaseFirestore.instance
        .collection("global_product_aggregates")
        .doc(barcode)
        .get();

    debugPrint("📦 AGGREGATE DOC EXISTS: ${aggregateDoc.exists}");

    if (aggregateDoc.exists) {
      final data = aggregateDoc.data();

      if (data != null) {
        final avg = (data["avgPrice"] as num?)?.toDouble();
        final median = (data["medianPrice"] as num?)?.toDouble();
        final best = (data["bestPrice"] as num?)?.toDouble();
        final highest = (data["maxPrice"] as num?)?.toDouble();
        final sellerCount = (data["sellerCount"] as num?)?.toInt();
        final updatedAt = data["lastUpdatedAt"] as Timestamp?;

        setState(() {
          _marketAverage = avg;
          _marketMedian = median;
          _marketSellerCount = sellerCount;
          _bestMarketPrice = best;
          _highestMarketPrice = highest;

          // backward compatibility
          _competitorMin = best;
          _competitorMax = highest;

          _marketSource = "aggregate";
          _marketLastUpdatedAt = updatedAt;
        });

        debugPrint("🧠 MARKET DATA LOADED FROM AGGREGATE");
        return;
      }
    }

    // =========================
    // 📦 2. FALLBACK → PRODUCTS
    // =========================
    debugPrint("🚀 RUNNING COLLECTION GROUP QUERY...");
    final snapshot = await FirebaseFirestore.instance
    
        .collectionGroup("products")
        .where("barcode", isEqualTo: barcode)
        .get();
        

    debugPrint("📊 FALLBACK PRODUCTS COUNT: ${snapshot.docs.length}");

    if (snapshot.docs.isEmpty) {
      debugPrint("⚠️ NO MARKET DATA FOUND");

      setState(() {
        _marketAverage = null;
        _marketMedian = null;
        _marketSellerCount = 0;
        _bestMarketPrice = null;
        _highestMarketPrice = null;

        _competitorMin = null;
        _competitorMax = null;

        _marketSource = "none";
        _marketLastUpdatedAt = null;
      });

      return;
    }

    final prices = snapshot.docs
        .map((e) => (e.data()["price"] as num?)?.toDouble() ?? 0)
        .where((p) => p > 0)
        .toList();

    if (prices.isEmpty) {
      debugPrint("⚠️ NO VALID PRICES");

      setState(() {
        _marketAverage = null;
        _marketMedian = null;
        _marketSellerCount = 0;
        _bestMarketPrice = null;
        _highestMarketPrice = null;

        _competitorMin = null;
        _competitorMax = null;

        _marketSource = "invalid_prices";
        _marketLastUpdatedAt = null;
      });

      return;
    }

    prices.sort();

    final avg = prices.reduce((a, b) => a + b) / prices.length;

    double median;
    if (prices.length % 2 == 1) {
      median = prices[prices.length ~/ 2];
    } else {
      final mid = prices.length ~/ 2;
      median = (prices[mid - 1] + prices[mid]) / 2;
    }

    setState(() {
      _marketAverage = avg;
      _marketMedian = median;
      _marketSellerCount = prices.length;
      _bestMarketPrice = prices.first;
      _highestMarketPrice = prices.last;

      _competitorMin = prices.first;
      _competitorMax = prices.last;

      _marketSource = "fallback_products";
      _marketLastUpdatedAt = null;
    });

    debugPrint("🟡 MARKET DATA LOADED FROM PRODUCTS FALLBACK");

  } catch (e, stack) {
  debugPrint("🔥🔥🔥 FIRESTORE RAW ERROR:");
  print(e); // 👈 خیلی مهم (نه debugPrint)
  print(stack);

  if (e is FirebaseException) {
    debugPrint("📛 CODE: ${e.code}");
    debugPrint("📛 MESSAGE: ${e.message}");
  }

  if (!mounted) return;

  setState(() {
    _marketAverage = null;
    _marketMedian = null;
    _marketSellerCount = 0;
    _bestMarketPrice = null;
    _highestMarketPrice = null;
    _marketSource = "error";
  });
}
}

Future<QuerySnapshot<Map<String, dynamic>>> _getSellerProductByBarcode(
  String barcode,
) {
  return FirebaseFirestore.instance
      .collection("businesses")
.doc(widget.businessId)
.collection("products")
      .where("businessId", isEqualTo: widget.businessId)
      .where("barcode", isEqualTo: barcode)
      .limit(1)
      .get();
}

Future<QuerySnapshot<Map<String, dynamic>>> _getSellerProductBySku(
  String sku,
) {
  return FirebaseFirestore.instance
      .collection("businesses")
.doc(widget.businessId)
.collection("products")
      .where("businessId", isEqualTo: widget.businessId)
      .where("sku", isEqualTo: sku)
      .limit(1)
      .get();
}

void _fillFromSellerProduct(Map<String, dynamic> data) {
  setState(() {
    _name.text = (data["name"] ?? "").toString();
    _brand.text = (data["brand"] ?? "").toString();
    _desc.text = (data["description"] ?? "").toString();
    _price.text = (data["price"] ?? "").toString();
    _stock.text = (data["stock"] ?? "").toString();

    if ((data["salePrice"]) != null) {
      _salePrice.text = data["salePrice"].toString();
      _hasDiscount = true;
    }

    if ((data["wholesalePrice"]) != null) {
      _wholesalePrice.text = data["wholesalePrice"].toString();
    }

    if ((data["minStock"]) != null) {
      _minStock.text = data["minStock"].toString();
    }

    if ((data["currency"] ?? "").toString().isNotEmpty) {
      _currency = (data["currency"] ?? "TRY").toString();
    }

    final category = (data["category"] ?? "").toString();
    if (category.contains(">")) {
      final parts = category.split(">");
      _mainCategory = parts[0].trim();

      final candidateSub = parts.length > 1 ? parts[1].trim() : "";
      if (categories[_mainCategory]?.contains(candidateSub) ?? false) {
        _subCategory = candidateSub;
      } else {
        _subCategory = categories[_mainCategory]!.first;
      }
    }

    _barcodeMatched = true;
    _barcodeSource = "catalog";
    _priceSuggestionText = null;
    _suggestedPrice = null;
    _suggestedMinPrice = null;
    _suggestedMaxPrice = null;
  });
}

void _fillFromGlobalProduct(Map<String, dynamic> data, String barcode) {
  final recommendedMin =
      (data["recommendedPriceMin"] as num?)?.toDouble();
  final recommendedMax =
      (data["recommendedPriceMax"] as num?)?.toDouble();

  final recommendedMid =
      (recommendedMin != null && recommendedMax != null)
          ? ((recommendedMin + recommendedMax) / 2)
          : null;

  setState(() {
    _barcodeMatched = true;
    _barcodeSource = "global";

    _name.text = (data["name"] ?? "").toString();
    _brand.text = (data["brand"] ?? "").toString();

    if (_desc.text.trim().isEmpty) {
      _desc.text = (data["description"] ?? "").toString();
    }

    if (_sku.text.trim().isEmpty) {
      _sku.text = "BC-${barcode.substring(barcode.length - 5)}";
    }

    if (data["currency"] != null &&
        ["TRY", "USD", "EUR"].contains(data["currency"])) {
      _currency = data["currency"];
    }

    if (data["category"] != null &&
        data["category"].toString().contains(">")) {
      final parts = data["category"].toString().split(">");
      _mainCategory = parts[0].trim();

      final candidateSub = parts.length > 1 ? parts[1].trim() : "";
      if (categories[_mainCategory]?.contains(candidateSub) ?? false) {
        _subCategory = candidateSub;
      } else {
        _subCategory = categories[_mainCategory]!.first;
      }
    }

    _suggestedMinPrice = recommendedMin;
    _suggestedMaxPrice = recommendedMax;
    _suggestedPrice = recommendedMid;

    if (_price.text.trim().isEmpty && recommendedMid != null) {
      _price.text = recommendedMid.toStringAsFixed(0);
    }

    if (recommendedMin != null && recommendedMax != null) {
      _priceSuggestionText =
          "Suggested range: ${recommendedMin.toStringAsFixed(0)} - ${recommendedMax.toStringAsFixed(0)} $_currency";
    } else if (recommendedMid != null) {
      _priceSuggestionText =
          "Suggested price: ${recommendedMid.toStringAsFixed(0)} $_currency";
    } else {
      _priceSuggestionText = null;
    }
  });
}

void _runPriceEngine() {
  final userPrice = double.tryParse(_price.text);

  if (userPrice == null) return;

  final referenceMarket =
      _marketMedian ?? _marketAverage ?? _suggestedPrice;

  double finalPrice = userPrice;
  String strategy = "manual";
  String? position;
  double? gapPercent;
  double? profitMargin;

  if (referenceMarket != null && referenceMarket > 0) {
    gapPercent = ((userPrice - referenceMarket) / referenceMarket) * 100;

    final bestPrice = _bestMarketPrice;

    if (bestPrice != null && userPrice <= bestPrice) {
      strategy = "best_price";
      position = "Best Price 🏆";
    } else if (gapPercent < -12) {
      strategy = "aggressive_low";
      position = "Aggressive Low ⚡";
    } else if (gapPercent <= 8) {
      strategy = "competitive";
      position = "Competitive ✅";
    } else if (gapPercent <= 20) {
      strategy = "slightly_high";
      position = "Slightly High 📈";
    } else {
      strategy = "overpriced";
      position = "Too Expensive ⚠️";
      finalPrice = referenceMarket * 1.05;
    }

    final cost = double.tryParse(_wholesalePrice.text);
    if (cost != null && cost > 0) {
      profitMargin = ((userPrice - cost) / cost) * 100;
    }
  }

  setState(() {
    _finalRecommendedPrice = finalPrice;
    _pricingStrategy = strategy;
    _marketPosition = position;
    _priceGapPercent = gapPercent;
    _profitMargin = profitMargin;
  });
}
Future<void> _openExistingSellerProduct(DocumentSnapshot doc) async {
  final data = doc.data() as Map<String, dynamic>;
  final existingProduct = Product.fromJson(doc.id, data);

  if (!mounted) return;

  // ✅ SHOW PROFESSIONAL DIALOG (UX FIX)
  await showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔥 ICON
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                color: Colors.green,
                size: 26,
              ),
            ),

            const SizedBox(height: 14),

            // 🔥 TITLE
            Text(
              "Product already exists",
              style: AppTheme.h2(),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 6),

            // 🔥 DESCRIPTION
            Text(
              "You already added this product.\nOpening edit mode...",
              style: AppTheme.caption(color: Colors.grey),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // 🔥 BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context); // close dialog
                },
                child: const Text("Continue"),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  if (!mounted) return;

  // ✅ NAVIGATION (unchanged logic)
  context.read<AppState>().openAddProduct();
}

@override
void initState() {
  super.initState();

  if (isEdit) {
  final p = widget.existingProduct!;

  _name.text = p.name;
  _price.text = p.price.toString();
  _desc.text = p.description;
  _stock.text = p.stock.toString();

  _barcode.text = p.barcode ?? "";
  _brand.text = p.brand ?? "";
  _sku.text = p.sku ?? "";
  _salePrice.text = p.salePrice?.toString() ?? "";
  _minStock.text = p.minStock?.toString() ?? "";
    _wholesalePrice.text =
      p.wholesalePrice?.toString() ?? "";
  _hasDiscount = p.salePrice != null && p.salePrice! < p.price;

  if (p.category.contains(">")) {
  final parts = p.category.split(">");
  _mainCategory = parts[0].trim();
  _subCategory = parts[1].trim();
} else {
  _mainCategory = categories.keys.first;
_subCategory = categories[_mainCategory]!.first;
}
  _currency = p.currency;
  _weightKg.text = p.weightKg?.toString() ?? "";
_lengthCm.text = p.lengthCm?.toString() ?? "";
_widthCm.text = p.widthCm?.toString() ?? "";
_heightCm.text = p.heightCm?.toString() ?? "";
_fixedDesi.text = p.fixedDesi?.toString() ?? "";
_shippingFee.text = p.shippingFee?.toString() ?? "";
_freeShippingThreshold.text = p.freeShippingThreshold?.toString() ?? "";
_prepDays.text = p.preparationDays?.toString() ?? "1";
_maxDeliveryDays.text = p.maxDeliveryDays?.toString() ?? "4";
_returnWindowDays.text = p.returnWindowDays?.toString() ?? "14";

_shippingMode = p.shippingMode ?? "carrier_calculated";
_shippingPayer = p.shippingPayer ?? "buyer";
_returnShippingPayer = p.returnShippingPayer ?? "seller_if_contract_carrier";
_allowFreeShipping = p.allowFreeShipping ?? false;
_allowPickup = p.allowPickup ?? false;
_allowSameDay = p.allowSameDay ?? false;
_isFragile = p.isFragile ?? false;
_isPerishable = p.isPerishable ?? false;
_isOversize = p.isOversize ?? false;
_allowReturns = p.allowReturns ?? true;
_hasContractedReturnCarrier = p.hasContractedReturnCarrier ?? true;
_selectedReturnCarrier = p.returnCarrierCode ?? "Yurtici";
_selectedCarriers = List<String>.from(p.allowedCarrierCodes);
_excludedCities = List<String>.from(p.excludedCities ?? []);
_calculatedDesi = _computeDesi();
}
_calculatedDesi ??= _computeDesi();
 Future.microtask(() {
    _refreshCalculatedDesi(); // ✅ IMPORTANT
  });
}

void _snack(String message, {bool isError = false}) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: isError ? Colors.red : Colors.black87,
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

bool _validate() {
  final name = _name.text.trim();

  if (name.length < 4) {
    _snack("Product name must be at least 4 characters");
    return false;
  }

  if (_barcode.text.isNotEmpty && _barcode.text.length < 8) {
    _snack("Invalid barcode");
    return false;
  }

  final sku = _sku.text.trim();
  if (sku.isNotEmpty) {
    final cleaned = sku
        .toUpperCase()
        .replaceAll(" ", "-")
        .replaceAll(RegExp(r'[^A-Z0-9-_]'), '');

    if (cleaned.length < 4) {
      _snack("Invalid SKU");
      return false;
    }

    _sku.text = cleaned;
  }

  if (_wholesalePrice.text.isNotEmpty) {
    final wp = double.tryParse(_wholesalePrice.text.replaceAll(",", "."));
    if (wp == null || wp <= 0) {
      _snack("Invalid wholesale price");
      return false;
    }
  }

  if (_wholesalePrice.text.isNotEmpty) {
    final minQty = int.tryParse(_wholesaleMinQty.text);
    if (minQty == null || minQty < 2) {
      _snack("Wholesale min quantity must be at least 2");
      return false;
    }
  }

  if (_kdvRate == null) {
  _snack("KDV rate is required");
  return false;
}

  final price = double.tryParse(_price.text.trim().replaceAll(",", "."));
  if (price == null || price <= 0) {
    _snack("Invalid price");
    return false;
  }

  if (_hasDiscount) {
    final salePrice = double.tryParse(_salePrice.text.trim().replaceAll(",", "."));
    if (salePrice == null || salePrice <= 0) {
      _snack("Invalid discount price");
      return false;
    }

    if (salePrice >= price) {
      _snack("Discount must be lower than original price");
      return false;
    }
  }

  final wholesale = double.tryParse(_wholesalePrice.text.trim().replaceAll(",", "."));
  if (wholesale != null && wholesale >= price) {
    _snack("Wholesale price must be lower than retail price");
    return false;
  }

  final stock = int.tryParse(_stock.text.trim());
  if (stock == null || stock < 0) {
    _snack("Invalid stock");
    return false;
  }

  final minQty = int.tryParse(_wholesaleMinQty.text);
  if (minQty != null && stock < minQty) {
    _snack("Stock must be ≥ wholesale minimum quantity");
    return false;
  }

  final minStockText = _minStock.text.trim();
  if (minStockText.isNotEmpty) {
    final minStock = int.tryParse(minStockText);
    if (minStock == null || minStock < 0) {
      _snack("Invalid low stock alert");
      return false;
    }
  }

  if (_media.isEmpty && !isEdit) {
    _snack("Add at least 1 media");
    return false;
  }

  if (_desc.text.trim().length < 10) {
    _snack("Description must be at least 10 characters");
    return false;
  }

  if (_mainCategory.isEmpty || _subCategory.isEmpty) {
    _snack("Select category");
    return false;
  }

  // =========================
// SHIPPING VALIDATION
// =========================

// 📦 WEIGHT
final weight = double.tryParse(_weightKg.text.trim().replaceAll(",", "."));

// 📦 DESI (optional)
final fixedDesi = _fixedDesi.text.trim().isEmpty
    ? null
    : double.tryParse(_fixedDesi.text.trim().replaceAll(",", "."));

// ✅ RULE 1: either weight OR desi is required
if ((weight == null || weight <= 0) &&
    (fixedDesi == null || fixedDesi <= 0)) {
  _snack("Weight or desi is required");
  return false;
}

// 📏 DIMENSIONS (only if desi NOT provided)
final length = double.tryParse(_lengthCm.text.trim().replaceAll(",", "."));
final width = double.tryParse(_widthCm.text.trim().replaceAll(",", "."));
final height = double.tryParse(_heightCm.text.trim().replaceAll(",", "."));

if (fixedDesi == null || fixedDesi <= 0) {
  if (length == null || length <= 0) {
    _snack("Length is required");
    return false;
  }

  if (width == null || width <= 0) {
    _snack("Width is required");
    return false;
  }

  if (height == null || height <= 0) {
    _snack("Height is required");
    return false;
  }
}

// 📦 VALIDATE DESI VALUE
if (_fixedDesi.text.trim().isNotEmpty &&
    (fixedDesi == null || fixedDesi <= 0)) {
  _snack("Invalid desi value");
  return false;
}

  final shippingFee = _shippingFee.text.trim().isEmpty
      ? null
      : double.tryParse(_shippingFee.text.trim().replaceAll(",", "."));

  if (_shippingMode == "fixed_price") {
    if (shippingFee == null || shippingFee < 0) {
      _snack("Fixed shipping fee is required");
      return false;
    }
  }

  if (shippingFee != null && shippingFee < 0) {
    _snack("Invalid shipping fee");
    return false;
  }

  final threshold = _freeShippingThreshold.text.trim().isEmpty
      ? null
      : double.tryParse(_freeShippingThreshold.text.trim().replaceAll(",", "."));

  // فقط وقتی conditional هست threshold لازمه
if (_shippingPayer == "conditional") {
  if (threshold == null || threshold <= 0) {
    _snack("Free shipping threshold is required");
    return false;
  }
}

  final prepDays = int.tryParse(_prepDays.text.trim());
  if (prepDays == null || prepDays < 0 || prepDays > 30) {
    _snack("Invalid preparation time");
    return false;
  }

  final maxDeliveryDays = int.tryParse(_maxDeliveryDays.text.trim());
  if (maxDeliveryDays == null || maxDeliveryDays < 1 || maxDeliveryDays > 30) {
    _snack("Invalid max delivery days");
    return false;
  }
debugPrint("🚚 carriers = $_selectedCarriers");
debugPrint("📦 weight = ${_weightKg.text}");
debugPrint("📦 prepDays = ${_prepDays.text}");
  if (_selectedCarriers.isEmpty) {
    _snack("Select at least 1 cargo carrier");
    return false;
  }

  if (_allowReturns) {
    final returnDays = int.tryParse(_returnWindowDays.text.trim());
    if (returnDays == null || returnDays < 14) {
      _snack("Return window cannot be less than 14 days");
      return false;
    }

    if (_hasContractedReturnCarrier && _selectedReturnCarrier.trim().isEmpty) {
      _snack("Return carrier is required");
      return false;
    }
  }

  if (_shippingMode == "seller_absorbs" && _shippingPayer != "seller") {
  _snack("Shipping payer mismatch");
  return false;
}

  return true;
}



@override
void dispose() {
  _name.dispose();
  _price.dispose();
  _desc.dispose();
  _stock.dispose();
  _barcode.dispose();
  _brand.dispose();
  _sku.dispose();
  _salePrice.dispose();
  _minStock.dispose();
  _wholesalePrice.dispose();
  _wholesaleMinQty.dispose();
  _shippingFee.dispose();
_freeShippingThreshold.dispose();
_weightKg.dispose();
_lengthCm.dispose();
_widthCm.dispose();
_heightCm.dispose();
_fixedDesi.dispose();
_prepDays.dispose();
_maxDeliveryDays.dispose();
_returnWindowDays.dispose();
  super.dispose();
}

Future<void> _tryOpenExistingProductBySku(String value) async {
  final sku = value.trim().toUpperCase();
  if (sku.isEmpty) return;

  final result = await _getSellerProductBySku(sku);
  if (result.docs.isEmpty) return;

  await _openExistingSellerProduct(result.docs.first);
}

Future<void> _tryOpenExistingProductByBarcode(String value) async {
  final barcode = value.trim();
  if (barcode.isEmpty) return;

  final result = await _getSellerProductByBarcode(barcode);
  if (result.docs.isEmpty) return;

  await _openExistingSellerProduct(result.docs.first);
}

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _image = File(file.path));
    }
  }

  Future<void> _pickMedia() async {
  if (_picking) return;

  _picking = true;

  try {
    final file = await _picker.pickMedia();

    if (file != null) {
      setState(() {
        _media.add(file);
      });
    }
  } catch (e) {
    debugPrint("❌ PICK ERROR: $e");
  } finally {
    _picking = false;
  }
}

  Future<String?> _uploadImage() async {
  if (_image == null) return null;

  try {
    debugPrint("📸 UPLOADING IMAGE...");

    final fileName = DateTime.now().millisecondsSinceEpoch.toString();

    final ref = FirebaseStorage.instance
        .ref()
        .child('products')
        .child(widget.businessId)
        .child('$fileName.jpg');

    await ref.putFile(_image!);

    final url = await ref.getDownloadURL();

    debugPrint("✅ IMAGE UPLOADED: $url");

    return url;
  } catch (e) {
    debugPrint("❌ IMAGE UPLOAD ERROR: $e");
    return null;
  }
}

String generateSku() {
  final cleanName = _name.text
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9 ]'), '')
      .replaceAll(" ", "-");

  final rand = DateTime.now().millisecondsSinceEpoch
      .toString()
      .substring(7);

  return "$cleanName-$rand";
}

   Future<void> _submit() async {
        double? parseNum(String text) {
      if (text.trim().isEmpty) return null;
      return double.tryParse(text.replaceAll(",", "."));
    }
  if (_isSubmitting) {
    debugPrint("⛔ BLOCKED");
    return;
  }

  if (!_validate()) {
    debugPrint("❌ VALIDATION FAILED");
    return;
  }

  setState(() {
    _isSubmitting = true;
    _loading = true;
  });

  debugPrint("🚀 SUBMIT STARTED");

  // 🔥 AUTO SKU
  if (_sku.text.trim().isEmpty) {
    _sku.text = generateSku();
    debugPrint("🆕 AUTO SKU GENERATED = ${_sku.text}");
  }

  try {
    final firestore = FirebaseFirestore.instance;

    final rawSku = _sku.text.trim().toUpperCase();
    final sku = rawSku.replaceAll(" ", "-");
    final barcode = _barcode.text.trim();
    final docId = "${widget.businessId}_$sku";

    debugPrint("📦 businessId = ${widget.businessId}");
    debugPrint("📦 sku = $sku");
    debugPrint("📦 barcode = $barcode");
    debugPrint("📦 docId = $docId");

    final docRef = firestore
        .collection("businesses")
        .doc(widget.businessId)
        .collection("products")
        .doc(docId);

        // 🚚 ENSURE SHIPPING PREVIEW IS READY
if (_shippingPreview == null) {
  _updateShippingPreview();
}

    debugPrint("🧠 BEFORE TRANSACTION");

    await firestore.runTransaction((tx) async {
      debugPrint("🔥 TRANSACTION START");

      final existingSkuDoc = await tx.get(docRef);
      debugPrint("📦 exists = ${existingSkuDoc.exists}");

      if (existingSkuDoc.exists &&
          (!isEdit || widget.existingProduct?.id != docId)) {
        throw Exception("SKU already exists ⚠️");
      }

      final mediaItems = _media.isNotEmpty
          ? await _uploadMedia()
          : widget.existingProduct?.media ?? [];


final fixedDesiValue =
    double.tryParse(_fixedDesi.text.replaceAll(",", "."));

final lengthValue =
    double.tryParse(_lengthCm.text.replaceAll(",", ".")) ?? 0;

final widthValue =
    double.tryParse(_widthCm.text.replaceAll(",", ".")) ?? 0;

final heightValue =
    double.tryParse(_heightCm.text.replaceAll(",", ".")) ?? 0;

final calculatedDesiValue =
    (lengthValue * widthValue * heightValue) / 3000;

final finalDesi =
    (fixedDesiValue != null && fixedDesiValue > 0)
        ? fixedDesiValue
        : calculatedDesiValue;

debugPrint("📦 FINAL DESI = $finalDesi");
// 🏪 GET BUSINESS DATA
final businessDoc = await FirebaseFirestore.instance
    .collection('businesses')
    .doc(widget.businessId)
    .get();
final businessData = businessDoc.data();

final businessCity = businessData?['contact']?['city'];
final businessName = businessData?['profile']?['displayName'];
final businessLogo = businessData?['profile']?['logoUrl'];

        debugPrint("🚨 FINAL CARRIERS BEFORE SAVE: $_selectedCarriers");

      final product = Product(
  id: docId,
  
  businessId: widget.businessId,

  // 🔥 core
  name: _name.text.trim(),
  description: _desc.text.trim(),
  price: double.parse(_price.text.trim().replaceAll(",", ".")),
  currency: _currency,

  // 🔥 pricing
  salePrice: _hasDiscount && _salePrice.text.trim().isNotEmpty
      ? double.tryParse(_salePrice.text.trim().replaceAll(",", "."))
      : null,
  wholesalePrice: _wholesalePrice.text.trim().isNotEmpty
      ? double.tryParse(_wholesalePrice.text.trim().replaceAll(",", "."))
      : null,
      kdvRate: _kdvRate,

  // 🔥 media
  media: mediaItems,

  // 🔥 inventory
  stock: int.tryParse(_stock.text.trim()) ?? 0,
  minStock: _minStock.text.trim().isNotEmpty
      ? int.tryParse(_minStock.text.trim())
      : null,

  // 🔥 classification
  category: "$_mainCategory > $_subCategory",
  brand: _brand.text.trim().isNotEmpty ? _brand.text.trim() : null,

  // 🔥 identifiers
  sku: sku,
  barcode: barcode.isEmpty ? null : barcode,

  // 🔥 status
  isActive: true,

  // 🔥 shipping dimensions
  weightKg: parseNum(_weightKg.text),
  lengthCm: parseNum(_lengthCm.text),
  widthCm: parseNum(_widthCm.text),
  heightCm: parseNum(_heightCm.text),
  fixedDesi: finalDesi,

  originCity: businessCity,

  // 🔥 shipping pricing
  shippingMode: _shippingMode,
  shippingPayer: _shippingPayer,
  shippingFee: parseNum(_shippingFee.text),
  freeShippingThreshold: parseNum(_freeShippingThreshold.text),

  // 🔥 delivery timing
  preparationDays: int.tryParse(_prepDays.text),
  maxDeliveryDays: int.tryParse(_maxDeliveryDays.text),

  // 🔥 shipping options
  allowFreeShipping: _allowFreeShipping,
  allowPickup: _allowPickup,
  allowSameDay: _allowSameDay,

  isFragile: _isFragile,
  isPerishable: _isPerishable,
  isOversize: _isOversize,

  

taxIncluded: true,

  // 🔥 returns
  allowReturns: _allowReturns,
returnWindowDays: int.tryParse(_returnWindowDays.text),
returnShippingPayer: _returnShippingPayer,
hasContractedReturnCarrier: _hasContractedReturnCarrier,
returnCarrierCode: _selectedReturnCarrier,

// ✅ FIXED
allowedCarrierCodes: _selectedCarriers
    .map((e) => e.toUpperCase())
    .toSet()
    .toList(),

excludedCities: _excludedCities,
  // 🔥 business snapshot
  businessName: businessName,
  businessLogo: businessLogo,

  // 🔥 timestamps
  createdAt: isEdit
      ? widget.existingProduct?.createdAt ?? Timestamp.now()
      : Timestamp.now(),
  updatedAt: Timestamp.now(),
);
debugPrint("🧪 DOC PATH = businesses/${widget.businessId}/products/$docId");
debugPrint("🧪 PRODUCT ID = ${product.id}");
debugPrint("🧪 PRODUCT JSON = ${product.toJson()}");
tx.set(docRef, product.toJson());

final rootDocRef = firestore.collection("products").doc(docId);
tx.set(rootDocRef, product.toJson());
// 🔥 SAVE TO GLOBAL (VERY IMPORTANT)
if (barcode.isNotEmpty) {
  try {
    await FirebaseFunctions.instance
        .httpsCallable('saveGlobalProduct')
        .call({
      "code": barcode,
      "data": {
        "name": _name.text,
        "brand": _brand.text,
        "category": "$_mainCategory > $_subCategory",
        "imageUrl": mediaItems.isNotEmpty
            ? mediaItems.first.originalUrl
            : null,
        "attributes": {
          "weightKg": parseNum(_weightKg.text),
        }
      }
    });

    debugPrint("🌍 GLOBAL PRODUCT UPDATED");
  } catch (e) {
    debugPrint("❌ GLOBAL SAVE ERROR: $e");
  }
}
    });

    debugPrint("✅ TRANSACTION SUCCESS");

    if (!mounted) return;

    _snack("Product saved ✅");
    Navigator.pop(context);

  } catch (e, stack) {
    debugPrint("💥 SUBMIT ERROR: $e");
    debugPrint("📍 STACK: $stack");
    _snack(e.toString());
  } finally {
    if (mounted) {
      setState(() {
        _loading = false;
        _isSubmitting = false;
      });
    }
    debugPrint("🏁 SUBMIT FINISHED");
  }
}
  Future<List<ProductMedia>> _uploadMedia() async {

    
  final result = <ProductMedia>[];

  for (final file in _media) {
    final originalPath = file.path;
final lowerPath = originalPath.toLowerCase();

final isVideo =
    lowerPath.endsWith('.mp4') ||
    lowerPath.endsWith('.mov') ||
    lowerPath.endsWith('.hevc') ||
    lowerPath.endsWith('.webm') ||
    lowerPath.endsWith('.m4v');

final ext = originalPath.split('.').last; // 🔥 از original بگیر

final fileName =
    "${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.$ext";

    // 🔥 RAW STORAGE PATH (خیلی مهم)
    final ref = FirebaseStorage.instance
        .ref()
        .child('products_raw')
        .child(widget.businessId)
        .child(fileName);
final bytes = await file.readAsBytes();

final uploadTask = ref.putData(
  bytes,
  SettableMetadata(
    contentType: isVideo ? 'video/mp4' : 'image/jpeg',
  ),
);

    uploadTask.snapshotEvents.listen((snapshot) {
      double progress = 0;

      if (snapshot.totalBytes > 0) {
        progress = snapshot.bytesTransferred / snapshot.totalBytes;
      }

      progress = progress.clamp(0.0, 1.0);

      if (mounted) {
        setState(() {
          _uploadProgress = progress;
        });
      }
    });

    

    await uploadTask;

    final rawUrl = await ref.getDownloadURL();

    // 🔥 IMAGE
    if (!isVideo) {
      result.add(
        ProductMedia(
          type: 'image',
          originalUrl: rawUrl,
          thumbnailUrl: rawUrl,
          playbackUrl: null,
          status: 'ready',
        ),
      );
    }

    // 🔥 VIDEO (بدون convert)
    else {
      result.add(
        ProductMedia(
          type: 'video',
          originalUrl: rawUrl,
          playbackUrl: null,
          thumbnailUrl: null,
          status: 'processing', // 🔥 مهم
        ),
      );
    }
  }

  return result;
}



Future<void> _scanBarcode() async {
  try {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const _BarcodeScannerPage(),
      ),
    );

    if (result == null || result.isEmpty) return;

    setState(() {
      _barcode.text = result;
    });

    await _handleBarcodeInput(result);
  } catch (e) {
    debugPrint("❌ SCAN ERROR: $e");
    _snack("Scan failed", isError: true);
  }
}

Future<void> _fetchFromOpenFoodFacts(String code) async {
  try {
    debugPrint("🌍 CALLING API...");

    final url = Uri.parse(
        "https://world.openfoodfacts.org/api/v0/product/$code.json");

    final res = await http.get(url);

    debugPrint("🌍 RESPONSE: ${res.statusCode}");

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      // =========================
      // ✅ CASE 1: API HAS DATA
      // =========================
      if (data["status"] == 1 && data["product"] != null) {
        final product = data["product"];

        setState(() {
          _barcodeSource = "api";
          _barcodeMatched = true;

          _name.text = product["product_name"] ?? "";
          _brand.text = product["brands"] ?? "";
          _desc.text = product["ingredients_text"] ?? "";

          final fallbackPrice = 120.0;

          // ❗ فقط UI (نه AI)
          if (_price.text.isEmpty) {
            _price.text = fallbackPrice.toStringAsFixed(0);
          }

          if (_priceSuggestionText == null) {
            _priceSuggestionText =
                "Estimated price: ${fallbackPrice.toStringAsFixed(0)} $_currency";
          }

          if (_sku.text.trim().isEmpty && code.length >= 5) {
            _sku.text = "BC-${code.substring(code.length - 5)}";
          }
        });

        _snack("Loaded from Global API 🌍");

        // 🔥 save global (non-blocking)
        try {
          await FirebaseFunctions.instance
              .httpsCallable('saveGlobalProduct')
              .call({
            "code": code,
            "data": {
  "name": _name.text,
  "brand": _brand.text,
  "category": "$_mainCategory > $_subCategory",
  "imageUrl": null,
  "attributes": {
    "weightKg": double.tryParse(_weightKg.text),
  }
}
          });

          debugPrint("✅ Saved to global_products");
        } catch (e) {
          debugPrint("❌ FUNCTION ERROR: $e");
        }
      }

      // =========================
      // ❌ CASE 2: API EMPTY
      // =========================
      else {
        debugPrint("⚠️ API returned NO DATA");

        setState(() {
          _barcodeSource = "fallback";
          _barcodeMatched = true;

          if (_name.text.trim().isEmpty) {
            final short = code.length >= 6
                ? code.substring(code.length - 6)
                : code;

            _name.text = "Product #$short";
          }

          final fallbackPrice = 120.0;

          // ❗ فقط UI
          if (_price.text.isEmpty) {
            _price.text = fallbackPrice.toStringAsFixed(0);
          }

          if (_priceSuggestionText == null) {
            _priceSuggestionText =
                "Fallback estimate: ${fallbackPrice.toStringAsFixed(0)} $_currency";
          }

          if (_sku.text.trim().isEmpty && code.length >= 5) {
            _sku.text = "BC-${code.substring(code.length - 5)}";
          }
        });
      }
    }

    // =========================
    // ❌ CASE 3: API ERROR
    // =========================
    else {
      debugPrint("❌ API STATUS NOT 200");

      setState(() {
        final fallbackPrice = 120.0;

        if (_price.text.isEmpty) {
          _price.text = fallbackPrice.toStringAsFixed(0);
        }

        if (_priceSuggestionText == null) {
          _priceSuggestionText =
              "Offline estimate: ${fallbackPrice.toStringAsFixed(0)} $_currency";
        }
      });
    }
  } catch (e) {
    debugPrint("❌ GLOBAL API ERROR: $e");

    setState(() {
      final fallbackPrice = 120.0;

      if (_price.text.isEmpty) {
        _price.text = fallbackPrice.toStringAsFixed(0);
      }

      if (_priceSuggestionText == null) {
        _priceSuggestionText =
            "Error estimate: ${fallbackPrice.toStringAsFixed(0)} $_currency";
      }
    });
  }
}
/*
Future<Map<String, dynamic>?> _getFromMarket(String code) async {
  final snap = await FirebaseFirestore.instance
      .collection("business_products")
      .where("barcode", isEqualTo: code)
      .limit(10)
      .get();

  if (snap.docs.isEmpty) return null;

  // 🔥 aggregate
  double total = 0;
  int count = 0;
  String? name;

  for (var d in snap.docs) {
    final data = d.data();
    total += (data["price"] ?? 0).toDouble();
    count++;

    name ??= data["name"];
  }

  return {
    "name": name,
    "avgPrice": total / count,
    "count": count,
  };
}
*/
void _generateSmartDescription() {
  final name = _name.text;
  final brand = _brand.text;

  final desc = "$name by $brand. High quality pet product designed for comfort, durability and daily use. Perfect choice for pet owners who want reliability.";

  setState(() {
    _desc.text = desc;
  });
}

Future<void> _fetchProductFromBarcode(String code) async {
  try {
    final globalDoc = await _getGlobalProductByBarcode(code);

    // =========================
    // 1) GLOBAL PRODUCT
    // =========================
    if (globalDoc.exists) {
      final data = globalDoc.data()!;
      _fillFromGlobalProduct(data, code);

      // 🔥 description fallback
      if (_desc.text.trim().isEmpty) {
        _generateSuggestedDescription();
      }

      // 🔥 run engine بعد از fill
      Future.microtask(() {
        _runPriceEngine();
      });

      _snack("Product detected ✅");
      return;
    }

    // =========================
    // 2) API FALLBACK
    // =========================
    debugPrint("🌍 Not in Firestore → fetching from global API...");
    await _fetchFromOpenFoodFacts(code);

    // اگر API موفق بود (name پر شده)
    if (_name.text.trim().isNotEmpty) {
      if (_sku.text.trim().isEmpty && code.length >= 5) {
        setState(() {
          _sku.text = "BC-${code.substring(code.length - 5)}";
          _barcodeMatched = true;
        });
      }

      if (_desc.text.trim().isEmpty) {
        _generateSuggestedDescription();
      }

      // 🔥 مهم: price engine اجرا بشه
      Future.microtask(() {
        _runPriceEngine();
      });

      debugPrint("⚡ AUTO READY PRODUCT");

      // ❗ خیلی مهم: اینجا دیگه reset نکن
      return;
    }

    if (_mainCategory.isEmpty || _mainCategory == "Food") {
  final name = _name.text.toLowerCase();

  if (name.contains("puppy") || name.contains("dog")) {
    _mainCategory = "Food";
    _subCategory = "Dry Food";
  } else if (name.contains("toy")) {
    _mainCategory = "Toys";
    _subCategory = "Chew Toy";
  } else if (name.contains("collar")) {
    _mainCategory = "Accessories";
    _subCategory = "Collar";
  }
}

    // =========================
    // 3) NOTHING FOUND (REAL FAIL)
    // =========================
    setState(() {
      _barcodeMatched = false;
      _barcodeSource = null;
      _priceSuggestionText = null;
      _suggestedPrice = null;
      _suggestedMinPrice = null;
      _suggestedMaxPrice = null;
    });

    _snack("No product found anywhere ❌");

  } catch (e) {
    debugPrint("❌ BARCODE FETCH ERROR: $e");
    _snack("Barcode lookup failed", isError: true);
  }
}
Future<void> _generateSuggestedDescription() async {
  setState(() => _isGeneratingDescription = true);

  try {
    final name = _name.text.trim();
    final brand = _brand.text.trim();
    final category = _mainCategory;
    final subCategory = _subCategory;

    if (name.isEmpty) {
      _snack("Enter product name first");
      return;
    }

    String text;

    if (category == "Food") {
      text =
          "$name by ${brand.isEmpty ? "a trusted brand" : brand} is a $subCategory product developed for daily use. Suitable for pet owners looking for reliable quality, balanced nutrition, and practical feeding support.";
    } else if (category == "Accessories") {
      text =
          "$name by ${brand.isEmpty ? "a trusted brand" : brand} is a practical $subCategory item designed for comfort, daily use, and convenience. A good choice for pet owners who value both function and style.";
    } else if (category == "Health") {
      text =
          "$name by ${brand.isEmpty ? "a trusted brand" : brand} is a $subCategory product intended to support pet care routines. Suitable for owners looking for practical and reliable wellness support.";
    } else if (category == "Toys") {
      text =
          "$name by ${brand.isEmpty ? "a trusted brand" : brand} is a fun $subCategory product designed to support play, engagement, and daily activity for pets.";
    } else {
      text =
          "$name by ${brand.isEmpty ? "a trusted brand" : brand} is a quality pet product designed for everyday use. Suitable for owners looking for reliability, convenience, and trusted performance.";
    }

    setState(() {
  if (_desc.text.trim().isEmpty) {
    _desc.text = text;
  } else {
    _desc.text = "${_desc.text}\n\n$text";
  }
});

    _snack("Description suggestion added ✅");
  } finally {
    setState(() => _isGeneratingDescription = false);
  }
}

Widget _buildPriceSuggestionBox() {
  final hasData = _priceSuggestionText != null;

  final text = _priceSuggestionText ?? "No pricing data yet";
  final color = hasData ? const Color(0xFFFFC107) : Colors.grey;

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: color.withOpacity(0.4),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hasData ? LucideIcons.sparkles : LucideIcons.info,
              size: 16,
              color: Colors.black87,
            ),
            const SizedBox(width: 8),
            Text(
              hasData
                  ? "Smart Price Suggestion"
                  : "Waiting for pricing data...",
              style: AppTheme.body().copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        Text(
          text,
          style: AppTheme.caption(color: Colors.black87),
        ),

        // 🔥 WOW UX: quick apply
        if (_suggestedPrice != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _price.text =
                    _suggestedPrice!.toStringAsFixed(0);
              });
              _runPriceEngine();
            },
            child: Text(
              "Tap to apply suggested price",
              style: AppTheme.caption(color: Colors.green),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildFinalPriceBox() {
  if (_finalRecommendedPrice == null) return const SizedBox();

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.green.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.green.withOpacity(0.4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Smart Pricing Engine",
          style: AppTheme.body().copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          "Recommended: ${_finalRecommendedPrice!.toStringAsFixed(0)} $_currency",
          style: AppTheme.bodyMedium(color: Colors.green),
        ),
        const SizedBox(height: 4),
        Text(
         "Mode: ${_pricingStrategy == "manual_no_market" ? "No market data" : _pricingStrategy}",
          style: AppTheme.caption(),
        ),
        if (_marketAverage == null)
  Text(
    "Using smart estimation 🧠",
    style: AppTheme.caption(color: Colors.orange),
  ),
      ],
    ),
  );
}

Widget _buildMarketInsights() {
  if (_marketAverage == null && _marketMedian == null) {
    return const SizedBox();
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blue.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blue.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Market Intelligence",
          style: AppTheme.body().copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),

        if (_marketAverage != null)
          Text("Avg Price: ${_marketAverage!.toStringAsFixed(0)} $_currency"),

        if (_marketMedian != null)
          Text("Median Price: ${_marketMedian!.toStringAsFixed(0)} $_currency"),

        if (_marketSellerCount != null)
          Text("Seller Count: $_marketSellerCount"),

        if (_bestMarketPrice != null)
          Text("Best Price: ${_bestMarketPrice!.toStringAsFixed(0)} $_currency"),

        if (_highestMarketPrice != null)
          Text("Highest Price: ${_highestMarketPrice!.toStringAsFixed(0)} $_currency"),

        if (_priceGapPercent != null)
          Text("Your Gap vs Market: ${_priceGapPercent!.toStringAsFixed(1)}%"),

        if (_marketPosition != null)
          Text("Position: $_marketPosition"),

        if (_profitMargin != null)
          Text("Profit Margin: ${_profitMargin!.toStringAsFixed(1)}%"),

        if (_marketSource != null)
          Text("Source: $_marketSource"),
      ],
    ),
  );
}

double _estimateSmartPrice() {
  final weight = double.tryParse(_weightKg.text);

  final category = "$_mainCategory > $_subCategory";

  // 🔥 category logic
  if (category.startsWith("Food")) {
    final perKg = 80.0;
    return (weight ?? 1) * perKg;
  }

  if (category.contains("Accessory")) {
    return 120;
  }

  if (category.contains("Toy")) {
    return 90;
  }

  return 100;
}

Future<void> _handleBarcodeInput(String value) async {
  final code = value.trim();

  debugPrint("🔍 BARCODE INPUT: $code");

  if (code.length < 8) return;
  if (_loading) return;

  setState(() {
    _loading = true;
    _isBarcodeLoading = true;

    // 🔥 UI: start state
    _barcodeStatusText = "Searching product...";
    _barcodeStatusColor = Colors.blue;
  });

  try {
    // =========================
    // 1) LOCAL CHECK
    // =========================
    final local = await _getSellerProductByBarcode(code);

    debugPrint("LOCAL FOUND: ${local.docs.length}");

    if (local.docs.isNotEmpty) {
      setState(() {
        _barcodeStatusText = "Product already exists → opening edit...";
        _barcodeStatusColor = Colors.orange;
      });

      await Future.delayed(const Duration(milliseconds: 400));
      await _openExistingSellerProduct(local.docs.first);
      return;
    }

    // =========================
    // 2) FETCH PRODUCT
    // =========================
    setState(() {
      _barcodeStatusText = "Fetching product data...";
      _barcodeStatusColor = Colors.blue;
    });

    await _fetchProductFromBarcode(code);

    await Future.delayed(const Duration(milliseconds: 150));

    // =========================
    // 3) MARKET DATA
    // =========================
    setState(() {
      _barcodeStatusText = "Analyzing market...";
      _barcodeStatusColor = Colors.purple;
    });

    await _loadMarketData(code);

    if (_marketAverage != null) {
      final bestText = _bestMarketPrice != null
          ? " | Best: ${_bestMarketPrice!.toStringAsFixed(0)} $_currency"
          : "";

      setState(() {
        _suggestedPrice = _marketMedian ?? _marketAverage;

        _priceSuggestionText =
            "Market avg: ${_marketAverage!.toStringAsFixed(0)} $_currency"
            "${_marketMedian != null ? " | Median: ${_marketMedian!.toStringAsFixed(0)} $_currency" : ""}"
            "$bestText"
            "${_marketSellerCount != null ? " | Sellers: $_marketSellerCount" : ""}";
      });
    }

    // =========================
    // 4) FAILSAFE PRICE
    // =========================
    if (_suggestedPrice == null) {
      final fallbackPrice = _estimateSmartPrice();

      setState(() {
        _suggestedPrice = fallbackPrice;
        _priceSuggestionText =
            "Emergency fallback: ${fallbackPrice.toStringAsFixed(0)} $_currency";

        if (_price.text.isEmpty) {
          _price.text = fallbackPrice.toStringAsFixed(0);
        }
      });

      debugPrint("🔥 EMERGENCY FALLBACK TRIGGERED");
    }

    // =========================
    // 5) DESCRIPTION
    // =========================
    if (_desc.text.trim().isEmpty) {
      _generateSuggestedDescription();
    }

    // =========================
    // 6) PRICE ENGINE
    // =========================
    Future.microtask(() {
      _runPriceEngine();
    });

    // =========================
    // ✅ SUCCESS UI
    // =========================
    setState(() {
      _barcodeStatusText = "Product ready ✅";
      _barcodeStatusColor = Colors.green;
    });

    debugPrint("SUGGESTED: $_suggestedPrice");

  } catch (e) {
    debugPrint("❌ BARCODE ERROR: $e");

    setState(() {
      _barcodeStatusText = "Failed to load product";
      _barcodeStatusColor = Colors.red;
    });

    _snack("Barcode lookup failed", isError: true);

  } finally {
    if (mounted) {
      setState(() {
        _loading = false;
        _isBarcodeLoading = false;
      });
    }
  }
}

Widget _buildBarcodeStatus() {
  if (_barcodeStatusText == null) return const SizedBox();

  return AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    margin: const EdgeInsets.only(top: 8, bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _barcodeStatusColor!.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: _barcodeStatusColor!.withOpacity(0.3),
      ),
    ),
    child: Row(
      children: [
        if (_isBarcodeLoading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _barcodeStatusColor,
            ),
          )
        else
          Icon(
            LucideIcons.info,
            size: 18,
            color: _barcodeStatusColor,
          ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            _barcodeStatusText!,
            style: AppTheme.caption(color: _barcodeStatusColor),
          ),
        ),
      ],
    ),
  );
}



Widget _buildNumberField({
  required TextEditingController controller,
  required String label,
  String? suffix,
  VoidCallback? onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) {
        if (onChanged != null) onChanged();
      },
      decoration: InputDecoration(
  labelText: label,
  prefixIcon: const Icon(LucideIcons.hash, size: 18),
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Colors.black),
  ),
),
    ),
  );
}
Widget _sectionHeader(String title, IconData icon) {
  return Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.black87),
        const SizedBox(width: 6),
        Text(title, style: AppTheme.h2()),
      ],
    ),
  );
}

Widget _buildSwitchTile({
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppTheme.body()),
      value: value,
      onChanged: onChanged,
    ),
  );
}

  @override
Widget build(BuildContext context) {
  return Material(
    color: AppTheme.bg,
    child: SafeArea(
      child: Column(
        children: [

          // 🔝 HEADER (جایگزین AppBar)
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.black12),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    context.read<AppState>().closeBusinessSubPage();
                  },
                ),
                const SizedBox(width: 4),
                Text(
                  isEdit ? "Edit Product" : "Add Product",
                  style: AppTheme.h2(),
                ),
              ],
            ),
          ),

          // 🔽 BODY
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [

                // 📸 MEDIA
                GestureDetector(
                  onTap: _pickMedia,
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _media.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.imagePlus,
                                    color: Colors.grey.shade600, size: 28),
                                const SizedBox(height: 8),
                                Text(
                                  isEdit
                                      ? "Tap to replace or add media"
                                      : "Tap to add media",
                                  style: AppTheme.caption(),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            scrollDirection: Axis.horizontal,
                            children: _media.map((file) {
                              final path = file.path.toLowerCase();

                              final isVideo =
                                  path.endsWith('.mp4') ||
                                  path.endsWith('.mov') ||
                                  path.endsWith('.hevc') ||
                                  path.endsWith('.webm') ||
                                  path.endsWith('.m4v');

                              return Padding(
                                padding: const EdgeInsets.all(6),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: isVideo
                                          ? Container(
                                              width: 100,
                                              color: Colors.black,
                                              child: const Center(
                                                child: Icon(
                                                  Icons.play_circle_fill,
                                                  color: Colors.white,
                                                  size: 40,
                                                ),
                                              ),
                                            )
                                          : Image.file(
                                              File(file.path),
                                              width: 100,
                                              fit: BoxFit.cover,
                                            ),
                                    ),

                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => _media.remove(file));
                                        },
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            LucideIcons.x,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🔹 BASIC INFO
                _sectionHeader("Basic Info", LucideIcons.package),
                const SizedBox(height: 12),

                _input(_name, "Product Name (min 4 chars)"),
                const SizedBox(height: 12),
                _input(_brand, "Brand"),
                const SizedBox(height: 12),

                _buildPriceSuggestionBox(),
                const SizedBox(height: 12),
                _buildFinalPriceBox(),
                const SizedBox(height: 12),
                _buildMarketInsights(),

        Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
     TextField(
  controller: _barcode,
 onChanged: (value) {
  _barcodeTimer?.cancel();

  _barcodeTimer = Timer(const Duration(milliseconds: 600), () async {
    final clean = value.trim();

    // فقط عدد
    if (!RegExp(r'^\d+$').hasMatch(clean)) return;

    if (!RegExp(r'^\d{12,13}$').hasMatch(clean)) return;

    await _handleBarcodeInput(clean);
  });
},
 decoration: InputDecoration(
  labelText: "Barcode",
  prefixIcon: const Icon(LucideIcons.scanLine),
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Colors.black),
  ),
),
),
_buildBarcodeStatus(),
const SizedBox(height: 6),
      Text(
  "Enter 8-13 digit barcode (EAN/UPC)",
  style: AppTheme.caption(color: Colors.grey),
),

      if (_barcode.text.isEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "No barcode? You can still sell this product using SKU.",
            style: AppTheme.caption(color: Colors.orange),
          ),
        ),
    ],
  ),
),
    const SizedBox(width: 8),
    Column(
      children: [
        Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.grey.shade300),
  ),
  child: Column(
    children: [
      Icon(LucideIcons.scanLine, size: 20),
      const SizedBox(height: 4),
      Text("Scan", style: AppTheme.caption()),
    ],
  ),
),
      ],
    ),
  ],
),

        Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    TextField(
  controller: _sku,
  onEditingComplete: () async {
    final value = _sku.text.trim().toUpperCase();

    if (value.isNotEmpty) {
      await _tryOpenExistingProductBySku(value);
    }
  },
  decoration: InputDecoration(
    labelText: "SKU Code",
    filled: true,
    fillColor: Colors.white.withOpacity(0.95),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
),

    Text(
      "Auto-generated if empty • Use A-Z, 0-9, -",
      style: AppTheme.caption(color: Colors.grey),
    ),
  ],
),

        const SizedBox(height: 12),

        // 🔥 PRICE SECTION (FIXED + PRO)

_sectionHeader("Shipping & Delivery", LucideIcons.truck),
const SizedBox(height: 12),

// 🔥 DISCOUNT TOGGLE
SwitchListTile(
  title: const Text("This product has a discount"),
  value: _hasDiscount,
  onChanged: (v) {
    setState(() {
      _hasDiscount = v;
      if (!v) _salePrice.clear();
    });
  },
),

const SizedBox(height: 12),

Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 NORMAL PRICE
          _input(
  _price,
  _hasDiscount ? "Original Price" : "Price",
  isNumber: true,
  onChanged: (_) => _runPriceEngine(),
),
          const SizedBox(height: 12),

          // 🔹 WHOLESALE PRICE (B2B)
          _input(
            _wholesalePrice,
            "Wholesale Price (only for shops)",
            isNumber: true,
          ),
const SizedBox(height: 12),
          _input(
  _wholesaleMinQty,
  "Minimum quantity for wholesale",
  isNumber: true,
),

const SizedBox(height: 4),

Text(
  "Wholesale applies when customer buys ≥ this quantity",
  style: AppTheme.caption(color: Colors.grey),
),

          const SizedBox(height: 4),

          Text(
            "Visible only to business accounts",
            style: AppTheme.caption(color: Colors.grey),
          ),

          // 🔥 LEVEL 3: PRICE ANCHOR
          if (_hasDiscount && _salePrice.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "Users will see discount → higher conversion 🚀",
                style: AppTheme.caption(color: Colors.green),
              ),
            ),
            if (_hasDiscount) ...[
  const SizedBox(height: 12),
  _input(_salePrice, "Discount Price", isNumber: true),
],
        ],
      ),
    ),

    const SizedBox(width: 10),

SizedBox(
  width: 90, // 🔥 مهم
  child: DropdownButtonFormField<double>(
    value: _kdvRate,
    decoration: InputDecoration(
      labelText: "KDV",
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    items: const [
      DropdownMenuItem(value: 1, child: Text("1%")),
      DropdownMenuItem(value: 10, child: Text("10%")),
      DropdownMenuItem(value: 20, child: Text("20%")),
    ],
    onChanged: (v) {
      setState(() => _kdvRate = v);
    },
  ),
),

const SizedBox(width: 10),

SizedBox(
  width: 90,
  child: DropdownButtonFormField<String>(
    value: _currency,
    decoration: InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    items: ["TRY", "USD", "EUR"]
        .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e),
            ))
        .toList(),
    onChanged: (v) {
      if (v != null) {
        setState(() => _currency = v);
      }
    },
  ),
),
  ],
),

// 🔥 DISCOUNT PRICE


// 🔥 SMART PRICE SUGGESTION
_buildPriceSuggestionBox(),
_buildFinalPriceBox(),

if (_suggestedPrice != null)
  Padding(
    padding: const EdgeInsets.only(top: 6),
    child: GestureDetector(
      onTap: () {
        setState(() {
          _price.text = _suggestedPrice!.toStringAsFixed(0);
        });
      },
      child: Text(
        "Tap to apply suggested price",
        style: AppTheme.caption(color: Colors.green),
      ),
    ),
  ),

// =============================
// 🚚 SHIPPING SYSTEM (TRENDYOL LEVEL)
// =============================

Text("Shipping & Delivery", style: AppTheme.h2()),
const SizedBox(height: 12),

// 📦 WEIGHT
_input(
  _weightKg,
  "Weight (kg)",
  isNumber: true,
  onChanged: (_) {
    _refreshCalculatedDesi();
    _updateShippingPreview();
  },
),

// 📏 DIMENSIONS
Row(
  children: [
    Expanded(
  child: Column(
    children: [
      _input(
        _lengthCm,
        "Length (cm)",
        isNumber: true,
        onChanged: (_) {
          _refreshCalculatedDesi();
          _updateShippingPreview();
        },
      ),
      const SizedBox(height: 12), // ✅ اینجا درست
    ],
  ),
),
    Expanded(
      child: _input(
        _widthCm,
        "Width (cm)",
        isNumber: true,
       onChanged: (_) {
  _refreshCalculatedDesi();
  _updateShippingPreview();
},
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: _input(
        _heightCm,
        "Height (cm)",
        isNumber: true,
        onChanged: (_) {
  _refreshCalculatedDesi();
  _updateShippingPreview();
},
      ),
    ),
  ],
),

const SizedBox(height: 8),

// 🧠 DESI CALCULATION
Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: Colors.grey.withOpacity(0.08),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Text(
    "Calculated desi: ${(_calculatedDesi ?? _computeDesi()).toStringAsFixed(2)}",
    style: AppTheme.caption(),
  ),
),

_input(
  _fixedDesi,
  "Manual desi override (optional)",
  isNumber: true,
  onChanged: (_) {
  _refreshCalculatedDesi();
  _updateShippingPreview();
},
),

const SizedBox(height: 12),

// 🚚 SHIPPING MODE
DropdownButtonFormField<String>(
  value: _shippingMode,
  decoration: InputDecoration(
    labelText: "Shipping Mode",
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
  items: const [
    DropdownMenuItem(value: "carrier_calculated", child: Text("Carrier Calculated")),
    DropdownMenuItem(value: "fixed_price", child: Text("Fixed Shipping Fee")),
    DropdownMenuItem(value: "seller_absorbs", child: Text("Seller Pays Shipping")),
    DropdownMenuItem(value: "free_shipping", child: Text("Free Shipping")),
  ],
  onChanged: (v) {
  if (v != null) {
    setState(() {
      _shippingMode = v;

      // 🔥 AUTO FIX
      if (v == "seller_absorbs") {
        _shippingPayer = "seller";
      }
    });
  }
}
),

const SizedBox(height: 12),



// 💵 FIXED PRICE
if (_shippingMode == "fixed_price")
  _input(_shippingFee, "Fixed Shipping Fee", isNumber: true),

// 🎯 FREE SHIPPING
SwitchListTile(
  title: const Text("Enable Free Shipping Campaign"),
  value: _allowFreeShipping,
  onChanged: (v) {
  setState(() => _allowFreeShipping = v);
  _updateShippingPreview();
},
),

if (_shippingPayer == "conditional" || _allowFreeShipping)
  _input(
  _freeShippingThreshold,
  "Free Shipping Threshold",
  isNumber: true,
  onChanged: (_) => _updateShippingPreview(),
),

const SizedBox(height: 12),

// ⏱ DELIVERY TIME
_input(_prepDays, "Preparation Time (days)", isNumber: true),
const SizedBox(height: 12),
_input(_maxDeliveryDays, "Max Delivery Time (days)", isNumber: true),
_buildShippingPreview(),
const SizedBox(height: 12),

// 🚛 CARRIERS
Text("Cargo Companies", style: AppTheme.h2()),
const SizedBox(height: 8),

Wrap(
  spacing: 6,
  children: _carrierOptions.map((carrier) {
    final code = carrier["code"]!;
    final label = carrier["label"]!;
    final selected = _selectedCarriers.contains(code);

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() {
          if (v) {
            _selectedCarriers.add(code);
          } else {
            _selectedCarriers.remove(code);
          }
        });
      },
    );
  }).toList(),
),

const SizedBox(height: 12),

// 🔄 RETURNS
SwitchListTile(
  title: const Text("Allow Returns"),
  value: _allowReturns,
  onChanged: (v) => setState(() => _allowReturns = v),
),

if (_allowReturns) ...[
  _input(_returnWindowDays, "Return Window (days)", isNumber: true),
const SizedBox(height: 12),
  DropdownButtonFormField<String>(
    value: _returnShippingPayer,
    decoration: InputDecoration(
      labelText: "Return Shipping Payer",
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    items: const [
      DropdownMenuItem(value: "seller_always", child: Text("Seller")),
      DropdownMenuItem(value: "buyer", child: Text("Buyer")),
      DropdownMenuItem(
        value: "seller_if_contract_carrier",
        child: Text("Seller (contracted carrier only)"),
      ),
    ],
    onChanged: (v) {
      if (v != null) {
        setState(() => _returnShippingPayer = v);
      }
    },
  ),
],
        // 🔹 INVENTORY
        Text("Inventory", style: AppTheme.h2()),
        const SizedBox(height: 12),

        _input(_stock, "Stock", isNumber: true),
        const SizedBox(height: 12),
        _input(_minStock, "Low Stock Alert", isNumber: true),

        const SizedBox(height: 12),

        // 🔹 CATEGORY
        Text("Category", style: AppTheme.h2()),
        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: _mainCategory,
          decoration: InputDecoration(
            labelText: "Main Category",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: categories.keys
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _mainCategory = v;
                _subCategory = categories[v]!.first;
              });
            }
          },
        ),

        const SizedBox(height: 12),

        DropdownButtonFormField<String>(
          value: _subCategory,
          decoration: InputDecoration(
            labelText: "Sub Category",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: categories[_mainCategory]!
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) {
              setState(() => _subCategory = v);
            }
          },
        ),

        const SizedBox(height: 12),

        // 🔹 DESCRIPTION
        Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text("Description", style: AppTheme.h2()),
    TextButton.icon(
      onPressed: _isGeneratingDescription
          ? null
          : _generateSuggestedDescription,
      icon: const Icon(LucideIcons.sparkles, size: 16),
      label: Text(
        _isGeneratingDescription ? "Generating..." : "Suggest",
      ),
    ),
  ],
),
const SizedBox(height: 12),
_input(_desc, "Description", maxLines: 4),

        const SizedBox(height: 30),

        // 🔹 LOADING
        if (_loading)
          LinearProgressIndicator(value: _uploadProgress),

        const SizedBox(height: 12),

        // 🔹 SUBMIT
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFFFC107),
    foregroundColor: Colors.black,
    padding: const EdgeInsets.symmetric(vertical: 14),
  ),
  onPressed: (_loading || _isSubmitting) ? null : _submit,
  child: Text(
    isEdit ? "Update Product" : "Add Product",
    style: AppTheme.button(color: Colors.black),
  ),
),

const SizedBox(height: 12),

// ⚡ SELL INSTANTLY
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.green,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14),
  ),
  onPressed: () async {
  _runPriceEngine();
  await _submit();
},
  child: const Text("⚡ Sell Instantly"),
),
      ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildShippingPreview() {
  if (_shippingPreview == null) return const SizedBox();

  final s = _shippingPreview!;

  return Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "🚚 Shipping Estimate",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 8),

        Text("Desi: ${s.computedDesi.toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.white70)),

        Text("Billable: ${s.effectiveUnit.toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.white70)),

        Text("Base: ${s.basePrice.toStringAsFixed(2)} TRY",
            style: const TextStyle(color: Colors.white70)),

        if (s.surcharge > 0)
          Text("Extra: ${s.surcharge.toStringAsFixed(2)} TRY",
              style: const TextStyle(color: Colors.orangeAccent)),

        const SizedBox(height: 6),

        Text(
          s.isFreeShipping
              ? "FREE SHIPPING"
              : "Total: ${s.total.toStringAsFixed(2)} TRY",
          style: const TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget _input(
  TextEditingController controller,
  String label, {
  bool isNumber = false,
  int maxLines = 1,
  String? hint,
  ValueChanged<String>? onChanged,
}) {
  return TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: isNumber
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    onChanged: (value) {
      debugPrint("✏️ INPUT CHANGED → $label = $value");
      onChanged?.call(value);
    },
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}

static double getCarrierPrice(String carrier, double desi) {
  double base;

  if (desi <= 1) {
    base = 60;
  } else if (desi <= 5) {
    base = 75;
  } else if (desi <= 10) {
    base = 95;
  } else {
    base = 120;
  }

  // slight variation per carrier
  switch (carrier) {
    case "Yurtici":
      return base;
    case "Aras":
      return base + 5;
    case "MNG":
      return base + 8;
    default:
      return base + 10;
  }
}
static Map<String, dynamic> getBestCarrier({
  required List<String> carriers,
  required double desi,
}) {
  double bestPrice = double.infinity;
  String? bestCarrier;

  for (final c in carriers) {
    final price = getCarrierPrice(c, desi);

    if (price < bestPrice) {
      bestPrice = price;
      bestCarrier = c;
    }
  }

  return {
    "carrier": bestCarrier,
    "price": bestPrice,
  };
}
static Map<String, dynamic> calculateFinalShipping({
  required double productPrice,
  required double shippingPrice,
  required String shippingMode,
  required String shippingPayer,
  double? freeThreshold,
}) {
  double buyerPays = 0;
  double sellerPays = 0;

  // 🚚 seller absorbs
  if (shippingMode == "seller_absorbs") {
    sellerPays = shippingPrice;
  }

  // 💰 fixed price
  else if (shippingMode == "fixed_price") {
    buyerPays = shippingPrice;
  }

  // 🔄 conditional
  else if (shippingPayer == "conditional") {
    if (productPrice >= (freeThreshold ?? 0)) {
      sellerPays = shippingPrice;
    } else {
      buyerPays = shippingPrice;
    }
  }

  // default
  else {
    buyerPays = shippingPrice;
  }

  return {
    "buyerPays": buyerPays,
    "sellerPays": sellerPays,
  };
}
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MobileScanner(
        onDetect: (capture) {
          if (_handled) return;

          final barcode = capture.barcodes.first.rawValue;

          if (barcode == null || barcode.isEmpty) return;

          _handled = true;

          Navigator.pop(context, barcode);
        },
      ),
    );
  }
}
