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
<<<<<<< HEAD
import 'package:mobile_scanner/mobile_scanner.dart';


=======
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
>>>>>>> 823c872 (ci: add flutter github actions workflow)

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

  String _carrierLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'YURTICI':
        return l10n.carrierYurticiKargo;
      case 'ARAS':
        return l10n.carrierArasKargo;
      case 'MNG':
        return l10n.carrierMngKargo;
      case 'SURAT':
        return l10n.carrierSuratKargo;
      case 'PTT':
        return l10n.carrierPttKargo;
      case 'HEPSIJET':
        return l10n.carrierHepsiJet;
      case 'KOLAYGELSIN':
        return l10n.carrierKolayGelsin;
      case 'UPS':
        return l10n.carrierUpsTurkiye;
      case 'DHL':
        return l10n.carrierDhlExpress;
      default:
        return code;
    }
  }

  String _categoryLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Food':
        return l10n.categoryFood;
      case 'Accessories':
        return l10n.categoryAccessories;
      case 'Health':
        return l10n.categoryHealth;
      case 'Toys':
        return l10n.categoryToys;
      default:
        return value;
    }
  }

  String _subCategoryLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Dry Food':
        return l10n.subCategoryDryFood;
      case 'Wet Food':
        return l10n.subCategoryWetFood;
      case 'Treats':
        return l10n.subCategoryTreats;
      case 'Collar':
        return l10n.subCategoryCollar;
      case 'Leash':
        return l10n.subCategoryLeash;
      case 'Clothing':
        return l10n.subCategoryClothing;
      case 'Vitamins':
        return l10n.subCategoryVitamins;
      case 'Medicine':
        return l10n.subCategoryMedicine;
      case 'Chew Toy':
        return l10n.subCategoryChewToy;
      case 'Interactive':
        return l10n.subCategoryInteractive;
      default:
        return value;
    }
  }

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
    final desi = manualDesi != null && manualDesi > 0
        ? manualDesi
        : _computeDesi();
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
    final weight = double.tryParse(_weightKg.text.replaceAll(",", ".")) ?? 0;

    final l = double.tryParse(_lengthCm.text.trim().replaceAll(",", ".")) ?? 0;
    final w = double.tryParse(_widthCm.text.trim().replaceAll(",", ".")) ?? 0;
    final h = double.tryParse(_heightCm.text.trim().replaceAll(",", ".")) ?? 0;

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
        fixedDesi: double.tryParse(_fixedDesi.text.trim().replaceAll(",", ".")),
        isFragile: _isFragile,
        isOversize: _isOversize,
        carrierCode: best["carrier"], // 🔥 BEST carrier
        itemPrice: double.tryParse(_price.text.trim().replaceAll(",", ".")),
        freeShippingThreshold: double.tryParse(_freeShippingThreshold.text),
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
     debugPrint('$e'); // 👈 خیلی مهم (نه debugPrint)
      debugPrint('$stack');

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
    final l10n = AppLocalizations.of(context)!;
    final recommendedMin = (data["recommendedPriceMin"] as num?)?.toDouble();
    final recommendedMax = (data["recommendedPriceMax"] as num?)?.toDouble();

    final recommendedMid = (recommendedMin != null && recommendedMax != null)
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
        _priceSuggestionText = l10n.smartPriceSuggestedRangeLabel(
          recommendedMin.toStringAsFixed(0),
          recommendedMax.toStringAsFixed(0),
          _currency,
        );
      } else if (recommendedMid != null) {
        _priceSuggestionText = l10n.smartPriceSuggestedPriceLabel(
          recommendedMid.toStringAsFixed(0),
          _currency,
        );
      } else {
        _priceSuggestionText = null;
      }
    });
  }

  String _pricingStrategyLabel(AppLocalizations l10n, String strategy) {
    switch (strategy) {
      case 'best_price':
        return l10n.bestPriceStrategyLabel;
      case 'aggressive_low':
        return l10n.aggressiveLowStrategyLabel;
      case 'competitive':
        return l10n.competitiveStrategyLabel;
      case 'slightly_high':
        return l10n.slightlyHighStrategyLabel;
      case 'overpriced':
        return l10n.tooExpensiveStrategyLabel;
      case 'manual_no_market':
        return l10n.manualPricingLabel;
      case 'manual':
        return l10n.manualPricingLabel;
      default:
        return strategy;
    }
  }

  String _marketPositionLabel(AppLocalizations l10n, String position) {
    switch (position) {
      case 'Best Price 🏆':
        return l10n.bestPricePositionLabel;
      case 'Aggressive Low ⚡':
        return l10n.aggressiveLowPositionLabel;
      case 'Competitive ✅':
        return l10n.competitivePositionLabel;
      case 'Slightly High 📈':
        return l10n.slightlyHighPositionLabel;
      case 'Too Expensive ⚠️':
        return l10n.tooExpensivePositionLabel;
      default:
        return position;
    }
  }

  String _marketSourceLabel(AppLocalizations l10n, String source) {
    switch (source) {
      case 'aggregate':
        return l10n.marketSourceAggregateLabel;
      case 'fallback_products':
        return l10n.marketSourceFallbackProductsLabel;
      case 'none':
        return l10n.marketSourceNoneLabel;
      case 'invalid_prices':
        return l10n.marketSourceInvalidPricesLabel;
      case 'error':
        return l10n.marketSourceErrorLabel;
      default:
        return source;
    }
  }

  void _runPriceEngine() {
    final userPrice = double.tryParse(_price.text);

    if (userPrice == null) return;

    final referenceMarket = _marketMedian ?? _marketAverage ?? _suggestedPrice;

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
    final l10n = AppLocalizations.of(context)!;

    if (!mounted) return;

    // ✅ SHOW PROFESSIONAL DIALOG (UX FIX)
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                child: const Icon(Icons.check, color: Colors.green, size: 26),
              ),

              const SizedBox(height: 14),

              // 🔥 TITLE
              Text(
                l10n.productAlreadyExistsTitle,
                style: AppTheme.h2(),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 6),

              // 🔥 DESCRIPTION
              Text(
                l10n.productAlreadyExistsDescription,
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
                  child: Text(l10n.continueButton),
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
      _wholesalePrice.text = p.wholesalePrice?.toString() ?? "";
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
      _returnShippingPayer =
          p.returnShippingPayer ?? "seller_if_contract_carrier";
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
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text.trim();

    if (name.length < 4) {
      _snack(l10n.productNameMustBeAtLeast4Chars);
      return false;
    }

    if (_barcode.text.isNotEmpty && _barcode.text.length < 8) {
      _snack(l10n.invalidBarcode);
      return false;
    }

    final sku = _sku.text.trim();
    if (sku.isNotEmpty) {
      final cleaned = sku
          .toUpperCase()
          .replaceAll(" ", "-")
          .replaceAll(RegExp(r'[^A-Z0-9-_]'), '');

      if (cleaned.length < 4) {
        _snack(l10n.invalidSku);
        return false;
      }

      _sku.text = cleaned;
    }

    if (_wholesalePrice.text.isNotEmpty) {
      final wp = double.tryParse(_wholesalePrice.text.replaceAll(",", "."));
      if (wp == null || wp <= 0) {
        _snack(l10n.invalidWholesalePrice);
        return false;
      }
    }

    if (_wholesalePrice.text.isNotEmpty) {
      final minQty = int.tryParse(_wholesaleMinQty.text);
      if (minQty == null || minQty < 2) {
        _snack(l10n.wholesaleMinQuantityMustBeAtLeast2);
        return false;
      }
    }

    if (_kdvRate == null) {
      _snack(l10n.kdvRateIsRequired);
      return false;
    }

    final price = double.tryParse(_price.text.trim().replaceAll(",", "."));
    if (price == null || price <= 0) {
      _snack(l10n.invalidPrice);
      return false;
    }

    if (_hasDiscount) {
      final salePrice = double.tryParse(
        _salePrice.text.trim().replaceAll(",", "."),
      );
      if (salePrice == null || salePrice <= 0) {
        _snack(l10n.invalidDiscountPrice);
        return false;
      }

      if (salePrice >= price) {
        _snack(l10n.discountMustBeLowerThanOriginalPrice);
        return false;
      }
    }

    final wholesale = double.tryParse(
      _wholesalePrice.text.trim().replaceAll(",", "."),
    );
    if (wholesale != null && wholesale >= price) {
      _snack(l10n.wholesalePriceMustBeLowerThanRetailPrice);
      return false;
    }

    final stock = int.tryParse(_stock.text.trim());
    if (stock == null || stock < 0) {
      _snack(l10n.invalidStock);
      return false;
    }

    final minQty = int.tryParse(_wholesaleMinQty.text);
    if (minQty != null && stock < minQty) {
      _snack(l10n.stockMustBeAtLeastWholesaleMinQuantity);
      return false;
    }

    final minStockText = _minStock.text.trim();
    if (minStockText.isNotEmpty) {
      final minStock = int.tryParse(minStockText);
      if (minStock == null || minStock < 0) {
        _snack(l10n.invalidLowStockAlert);
        return false;
      }
    }

    if (_media.isEmpty && !isEdit) {
      _snack(l10n.addAtLeast1Media);
      return false;
    }

    if (_desc.text.trim().length < 10) {
      _snack(l10n.descriptionMustBeAtLeast10Characters);
      return false;
    }

    if (_mainCategory.isEmpty || _subCategory.isEmpty) {
      _snack(l10n.selectCategory);
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
      _snack(l10n.weightOrDesiIsRequired);
      return false;
    }

    // 📏 DIMENSIONS (only if desi NOT provided)
    final length = double.tryParse(_lengthCm.text.trim().replaceAll(",", "."));
    final width = double.tryParse(_widthCm.text.trim().replaceAll(",", "."));
    final height = double.tryParse(_heightCm.text.trim().replaceAll(",", "."));

    if (fixedDesi == null || fixedDesi <= 0) {
      if (length == null || length <= 0) {
        _snack(l10n.lengthIsRequired);
        return false;
      }

      if (width == null || width <= 0) {
        _snack(l10n.widthIsRequired);
        return false;
      }

      if (height == null || height <= 0) {
        _snack(l10n.heightIsRequired);
        return false;
      }
    }

    // 📦 VALIDATE DESI VALUE
    if (_fixedDesi.text.trim().isNotEmpty &&
        (fixedDesi == null || fixedDesi <= 0)) {
      _snack(l10n.invalidDesiValue);
      return false;
    }

    final shippingFee = _shippingFee.text.trim().isEmpty
        ? null
        : double.tryParse(_shippingFee.text.trim().replaceAll(",", "."));

    if (_shippingMode == "fixed_price") {
      if (shippingFee == null || shippingFee < 0) {
        _snack(l10n.fixedShippingFeeIsRequired);
        return false;
      }
    }

    if (shippingFee != null && shippingFee < 0) {
      _snack(l10n.invalidShippingFee);
      return false;
    }

    final threshold = _freeShippingThreshold.text.trim().isEmpty
        ? null
        : double.tryParse(
            _freeShippingThreshold.text.trim().replaceAll(",", "."),
          );

    // فقط وقتی conditional هست threshold لازمه
    if (_shippingPayer == "conditional") {
      if (threshold == null || threshold <= 0) {
        _snack(l10n.freeShippingThresholdIsRequired);
        return false;
      }
    }

    final prepDays = int.tryParse(_prepDays.text.trim());
    if (prepDays == null || prepDays < 0 || prepDays > 30) {
      _snack(l10n.invalidPreparationTime);
      return false;
    }

    final maxDeliveryDays = int.tryParse(_maxDeliveryDays.text.trim());
    if (maxDeliveryDays == null ||
        maxDeliveryDays < 1 ||
        maxDeliveryDays > 30) {
      _snack(l10n.invalidMaxDeliveryDays);
      return false;
    }
    debugPrint("🚚 carriers = $_selectedCarriers");
    debugPrint("📦 weight = ${_weightKg.text}");
    debugPrint("📦 prepDays = ${_prepDays.text}");
    if (_selectedCarriers.isEmpty) {
      _snack(l10n.selectAtLeast1CargoCarrier);
      return false;
    }

    if (_allowReturns) {
      final returnDays = int.tryParse(_returnWindowDays.text.trim());
      if (returnDays == null || returnDays < 14) {
        _snack(l10n.returnWindowCannotBeLessThan14Days);
        return false;
      }

      if (_hasContractedReturnCarrier &&
          _selectedReturnCarrier.trim().isEmpty) {
        _snack(l10n.returnCarrierIsRequired);
        return false;
      }
    }

    if (_shippingMode == "seller_absorbs" && _shippingPayer != "seller") {
      _snack(l10n.shippingPayerMismatch);
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

    final rand = DateTime.now().millisecondsSinceEpoch.toString().substring(7);

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
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      final businessId = authUid ?? widget.businessId;

      debugPrint("👤 auth uid = ${authUid ?? 'null'}");
      debugPrint("🏪 widget.businessId = ${widget.businessId}");
      debugPrint("🧭 resolved businessId = $businessId");

      if (authUid != null && widget.businessId != authUid) {
        debugPrint(
          "⚠️ businessId mismatch → widget=${widget.businessId} auth=$authUid",
        );
      }

      if (authUid == null) {
        throw Exception("Missing authenticated business uid");
      }

      final rawSku = _sku.text.trim().toUpperCase();
      final sku = rawSku.replaceAll(" ", "-");
      final barcode = _barcode.text.trim();
      final docId = "${businessId}_$sku";

      debugPrint("📦 businessId = $businessId");
      debugPrint("📦 sku = $sku");
      debugPrint("📦 barcode = $barcode");
      debugPrint("📦 docId = $docId");

      final docRef = firestore
          .collection("businesses")
          .doc(businessId)
          .collection("products")
          .doc(docId);
      debugPrint(
        "🧭 Firestore product path = businesses/$businessId/products/$docId",
      );

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

        final fixedDesiValue = double.tryParse(
          _fixedDesi.text.replaceAll(",", "."),
        );

        final lengthValue =
            double.tryParse(_lengthCm.text.replaceAll(",", ".")) ?? 0;

        final widthValue =
            double.tryParse(_widthCm.text.replaceAll(",", ".")) ?? 0;

        final heightValue =
            double.tryParse(_heightCm.text.replaceAll(",", ".")) ?? 0;

        final calculatedDesiValue =
            (lengthValue * widthValue * heightValue) / 3000;

        final finalDesi = (fixedDesiValue != null && fixedDesiValue > 0)
            ? fixedDesiValue
            : calculatedDesiValue;

        debugPrint("📦 FINAL DESI = $finalDesi");
        // 🏪 GET BUSINESS DATA
        final businessDoc = await FirebaseFirestore.instance
            .collection('businesses')
            .doc(businessId)
            .get();
        final businessData = businessDoc.data();

        final businessCity = businessData?['contact']?['city'];
        final businessName = businessData?['profile']?['displayName'];
        final businessLogo = businessData?['profile']?['logoUrl'];

        debugPrint("🚨 FINAL CARRIERS BEFORE SAVE: $_selectedCarriers");

        final product = Product(
          id: docId,

          businessId: businessId,

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
              ? double.tryParse(
                  _wholesalePrice.text.trim().replaceAll(",", "."),
                )
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
        debugPrint("🧪 DOC PATH = businesses/$businessId/products/$docId");
        debugPrint("🧪 PRODUCT ID = ${product.id}");
        debugPrint("🧪 PRODUCT JSON = ${product.toJson()}");
        tx.set(docRef, product.toJson());
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
                    "attributes": {"weightKg": parseNum(_weightKg.text)},
                  },
                });

            debugPrint("🌍 GLOBAL PRODUCT UPDATED");
          } catch (e) {
            debugPrint("❌ GLOBAL SAVE ERROR: $e");
          }
        }
      });

      debugPrint("✅ TRANSACTION SUCCESS");

      if (!mounted) return;

      _snack(AppLocalizations.of(context)!.productSavedStatus);
      context.read<AppState>().closeBusinessSubPage();
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

<<<<<<< HEAD
Future<void> _scanBarcode() async {
  try {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const _BarcodeScannerPage(),
      ),
    );

    if (result == null || result.isEmpty) return;
=======
      final ext = originalPath.split('.').last; // 🔥 از original بگیر

      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.$ext";
>>>>>>> 823c872 (ci: add flutter github actions workflow)

      // 🔥 RAW STORAGE PATH (خیلی مهم)
      final ref = FirebaseStorage.instance
          .ref()
          .child('products_raw')
          .child(widget.businessId)
          .child(fileName);
      final bytes = await file.readAsBytes();

      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: isVideo ? 'video/mp4' : 'image/jpeg'),
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
      final result = await FlutterBarcodeScanner.scanBarcode(
        "#ff6666",
        AppLocalizations.of(context)!.cancelButton,
        true,
        ScanMode.BARCODE,
      );

      if (result == "-1") return;

      setState(() {
        _barcode.text = result;
      });

      await _handleBarcodeInput(result);
    } catch (e) {
      debugPrint("❌ SCAN ERROR: $e");
      _snack(AppLocalizations.of(context)!.scanFailed, isError: true);
    }
  }

  Future<void> _fetchFromOpenFoodFacts(String code) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      debugPrint("🌍 CALLING API...");

      final url = Uri.parse(
        "https://world.openfoodfacts.org/api/v0/product/$code.json",
      );

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
              _priceSuggestionText = l10n.estimatedPriceLabel(
                fallbackPrice.toStringAsFixed(0),
                _currency,
              );
            }

            if (_sku.text.trim().isEmpty && code.length >= 5) {
              _sku.text = "BC-${code.substring(code.length - 5)}";
            }
          });

          _snack(l10n.loadedFromGlobalApi);

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
                    "attributes": {"weightKg": double.tryParse(_weightKg.text)},
                  },
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

              _name.text = l10n.productFallbackName(short);
            }

            final fallbackPrice = 120.0;

            // ❗ فقط UI
            if (_price.text.isEmpty) {
              _price.text = fallbackPrice.toStringAsFixed(0);
            }

            if (_priceSuggestionText == null) {
              _priceSuggestionText = l10n.fallbackEstimateLabel(
                fallbackPrice.toStringAsFixed(0),
                _currency,
              );
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
            _priceSuggestionText = l10n.offlineEstimateLabel(
              fallbackPrice.toStringAsFixed(0),
              _currency,
            );
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
          _priceSuggestionText = l10n.errorEstimateLabel(
            fallbackPrice.toStringAsFixed(0),
            _currency,
          );
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
    final l10n = AppLocalizations.of(context)!;
    final name = _name.text;
    final brand = _brand.text;

    final desc = l10n.smartDescriptionDefault(
      name,
      brand.isEmpty ? l10n.trustedBrand : brand,
    );

    setState(() {
      _desc.text = desc;
    });
  }

  Future<void> _fetchProductFromBarcode(String code) async {
    final l10n = AppLocalizations.of(context)!;
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

        _snack(l10n.productDetectedStatus);
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

      _snack(l10n.noProductFoundAnywhere);
    } catch (e) {
      debugPrint("❌ BARCODE FETCH ERROR: $e");
      _snack(AppLocalizations.of(context)!.barcodeLookupFailed, isError: true);
    }
  }

  Future<void> _generateSuggestedDescription() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isGeneratingDescription = true);

    try {
      final name = _name.text.trim();
      final brand = _brand.text.trim();
      final category = _mainCategory;
      final subCategory = _subCategory;

      if (name.isEmpty) {
        _snack(l10n.enterProductNameFirst);
        return;
      }

      String text;

      if (category == "Food") {
        text = l10n.smartDescriptionFood(
          name,
          brand.isEmpty ? l10n.trustedBrand : brand,
          _subCategoryLabel(l10n, subCategory),
        );
      } else if (category == "Accessories") {
        text = l10n.smartDescriptionAccessories(
          name,
          brand.isEmpty ? l10n.trustedBrand : brand,
          _subCategoryLabel(l10n, subCategory),
        );
      } else if (category == "Health") {
        text = l10n.smartDescriptionHealth(
          name,
          brand.isEmpty ? l10n.trustedBrand : brand,
          _subCategoryLabel(l10n, subCategory),
        );
      } else if (category == "Toys") {
        text = l10n.smartDescriptionToys(
          name,
          brand.isEmpty ? l10n.trustedBrand : brand,
          _subCategoryLabel(l10n, subCategory),
        );
      } else {
        text = l10n.smartDescriptionDefault(
          name,
          brand.isEmpty ? l10n.trustedBrand : brand,
        );
      }

      setState(() {
        if (_desc.text.trim().isEmpty) {
          _desc.text = text;
        } else {
          _desc.text = "${_desc.text}\n\n$text";
        }
      });

      _snack(l10n.descriptionSuggestionAdded);
    } finally {
      setState(() => _isGeneratingDescription = false);
    }
  }

  Widget _buildPriceSuggestionBox() {
    final l10n = AppLocalizations.of(context)!;
    final hasData = _priceSuggestionText != null;

    final text = _priceSuggestionText ?? l10n.noPricingDataYet;
    final color = hasData ? const Color(0xFFFFC107) : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
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
                    ? l10n.smartPriceSuggestionTitle
                    : l10n.waitingForPricingData,
                style: AppTheme.body().copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(text, style: AppTheme.caption(color: Colors.black87)),

          // 🔥 WOW UX: quick apply
          if (_suggestedPrice != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _price.text = _suggestedPrice!.toStringAsFixed(0);
                });
                _runPriceEngine();
              },
              child: Text(
                l10n.tapToApplySuggestedPrice,
                style: AppTheme.caption(color: Colors.green),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinalPriceBox() {
    final l10n = AppLocalizations.of(context)!;
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
            l10n.smartPricingEngineTitle,
            style: AppTheme.body().copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            "${l10n.recommendedLabel}: ${_finalRecommendedPrice!.toStringAsFixed(0)} $_currency",
            style: AppTheme.bodyMedium(color: Colors.green),
          ),
          const SizedBox(height: 4),
          Text(
            "${l10n.modeLabel}: ${_pricingStrategy == "manual_no_market" ? l10n.noMarketDataLabel : _pricingStrategyLabel(l10n, _pricingStrategy ?? "")}",
            style: AppTheme.caption(),
          ),
          if (_marketAverage == null)
            Text(
              l10n.usingSmartEstimationLabel,
              style: AppTheme.caption(color: Colors.orange),
            ),
        ],
      ),
    );
  }

  Widget _buildMarketInsights() {
    final l10n = AppLocalizations.of(context)!;
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
            l10n.marketIntelligenceTitle,
            style: AppTheme.body().copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),

          if (_marketAverage != null)
            Text(
              "${l10n.avgPriceLabel}: ${_marketAverage!.toStringAsFixed(0)} $_currency",
            ),

          if (_marketMedian != null)
            Text(
              "${l10n.medianPriceLabel}: ${_marketMedian!.toStringAsFixed(0)} $_currency",
            ),

          if (_marketSellerCount != null)
            Text("${l10n.sellerCountLabel}: $_marketSellerCount"),

          if (_bestMarketPrice != null)
            Text(
              "${l10n.bestPriceLabel}: ${_bestMarketPrice!.toStringAsFixed(0)} $_currency",
            ),

          if (_highestMarketPrice != null)
            Text(
              "${l10n.highestPriceLabel}: ${_highestMarketPrice!.toStringAsFixed(0)} $_currency",
            ),

          if (_priceGapPercent != null)
            Text(
              "${l10n.yourGapVsMarketLabel}: ${_priceGapPercent!.toStringAsFixed(1)}%",
            ),

          if (_marketPosition != null)
            Text(
              "${l10n.positionLabel}: ${_marketPositionLabel(l10n, _marketPosition!)}",
            ),

          if (_profitMargin != null)
            Text(
              "${l10n.profitMarginLabel}: ${_profitMargin!.toStringAsFixed(1)}%",
            ),

          if (_marketSource != null)
            Text(
              "${l10n.sourceLabel}: ${_marketSourceLabel(l10n, _marketSource!)}",
            ),
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
    final l10n = AppLocalizations.of(context)!;
    final code = value.trim();

    debugPrint("🔍 BARCODE INPUT: $code");

    if (code.length < 8) return;
    if (_loading) return;

    setState(() {
      _loading = true;
      _isBarcodeLoading = true;

      // 🔥 UI: start state
      _barcodeStatusText = l10n.searchingProductStatus;
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
          _barcodeStatusText = l10n.productAlreadyExistsOpeningEditStatus;
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
        _barcodeStatusText = l10n.fetchingProductDataStatus;
        _barcodeStatusColor = Colors.blue;
      });

      await _fetchProductFromBarcode(code);

      await Future.delayed(const Duration(milliseconds: 150));

      // =========================
      // 3) MARKET DATA
      // =========================
      setState(() {
        _barcodeStatusText = l10n.analyzingMarketStatus;
        _barcodeStatusColor = Colors.purple;
      });

      await _loadMarketData(code);

      if (_marketAverage != null) {
        final bestText = _bestMarketPrice != null
            ? " | ${l10n.bestPriceLabel}: ${_bestMarketPrice!.toStringAsFixed(0)} $_currency"
            : "";

        setState(() {
          _suggestedPrice = _marketMedian ?? _marketAverage;

          _priceSuggestionText =
              "${l10n.marketAvgLabel}: ${_marketAverage!.toStringAsFixed(0)} $_currency"
              "${_marketMedian != null ? " | ${l10n.marketMedianLabel}: ${_marketMedian!.toStringAsFixed(0)} $_currency" : ""}"
              "$bestText"
              "${_marketSellerCount != null ? " | ${l10n.marketSellersLabel}: $_marketSellerCount" : ""}";
        });
      }

      // =========================
      // 4) FAILSAFE PRICE
      // =========================
      if (_suggestedPrice == null) {
        final fallbackPrice = _estimateSmartPrice();

        setState(() {
          _suggestedPrice = fallbackPrice;
          _priceSuggestionText = l10n.emergencyFallbackLabel(
            fallbackPrice.toStringAsFixed(0),
            _currency,
          );

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
        _barcodeStatusText = l10n.productReadyStatus;
        _barcodeStatusColor = Colors.green;
      });

      debugPrint("SUGGESTED: $_suggestedPrice");
    } catch (e) {
      debugPrint("❌ BARCODE ERROR: $e");

      setState(() {
        _barcodeStatusText = l10n.failedToLoadProductStatus;
        _barcodeStatusColor = Colors.red;
      });

      _snack(l10n.barcodeLookupFailed, isError: true);
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
        border: Border.all(color: _barcodeStatusColor!.withOpacity(0.3)),
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
            Icon(LucideIcons.info, size: 18, color: _barcodeStatusColor),

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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
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
    final l10n = AppLocalizations.of(context)!;
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
                border: Border(bottom: BorderSide(color: Colors.black12)),
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
                    isEdit ? l10n.editProductTitle : l10n.addProductTitle,
                    style: AppTheme.h2(),
                  ),
                ],
              ),
            ),

            // 🔽 BODY
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: _media.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.imagePlus,
                                    color: Colors.grey.shade600,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isEdit
                                        ? l10n.tapToReplaceOrAddMedia
                                        : l10n.tapToAddMedia,
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
                  _sectionHeader(
                    l10n.basicInfoSectionTitle,
                    LucideIcons.package,
                  ),
                  const SizedBox(height: 12),

                  _input(_name, l10n.productNameMinCharsLabel),
                  const SizedBox(height: 12),
                  _input(_brand, l10n.brandLabel),
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

                                _barcodeTimer = Timer(
                                  const Duration(milliseconds: 600),
                                  () async {
                                    final clean = value.trim();

                                    // فقط عدد
                                    if (!RegExp(r'^\d+$').hasMatch(clean))
                                      return;

                                    if (!RegExp(r'^\d{12,13}$').hasMatch(clean))
                                      return;

                                    await _handleBarcodeInput(clean);
                                  },
                                );
                              },
                              decoration: InputDecoration(
                                labelText: l10n.barcodeFieldLabel,
                                prefixIcon: const Icon(LucideIcons.scanLine),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            _buildBarcodeStatus(),
                            const SizedBox(height: 6),
                            Text(
                              l10n.enterBarcodeHint,
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
                                  l10n.noBarcodeSkuHint,
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
                                Text(
                                  l10n.scanButtonLabel,
                                  style: AppTheme.caption(),
                                ),
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
                          labelText: l10n.skuCodeLabel,
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.95),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      Text(
                        l10n.autoGeneratedSkuHint,
                        style: AppTheme.caption(color: Colors.grey),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 🔥 PRICE SECTION (FIXED + PRO)
                  _sectionHeader(
                    l10n.shippingAndDeliverySectionTitle,
                    LucideIcons.truck,
                  ),
                  const SizedBox(height: 12),

                  // 🔥 DISCOUNT TOGGLE
                  SwitchListTile(
                    title: Text(l10n.thisProductHasADiscount),
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
                              _hasDiscount
                                  ? l10n.originalPriceLabel
                                  : l10n.priceLabel,
                              isNumber: true,
                              onChanged: (_) => _runPriceEngine(),
                            ),
                            const SizedBox(height: 12),

                            // 🔹 WHOLESALE PRICE (B2B)
                            _input(
                              _wholesalePrice,
                              l10n.wholesalePriceLabel,
                              isNumber: true,
                            ),
                            const SizedBox(height: 12),
                            _input(
                              _wholesaleMinQty,
                              l10n.minimumQuantityForWholesaleLabel,
                              isNumber: true,
                            ),

                            const SizedBox(height: 4),

                            Text(
                              l10n.wholesaleAppliesHint,
                              style: AppTheme.caption(color: Colors.grey),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              l10n.visibleOnlyToBusinessAccountsHint,
                              style: AppTheme.caption(color: Colors.grey),
                            ),

                            // 🔥 LEVEL 3: PRICE ANCHOR
                            if (_hasDiscount && _salePrice.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  l10n.usersWillSeeDiscountHint,
                                  style: AppTheme.caption(color: Colors.green),
                                ),
                              ),
                            if (_hasDiscount) ...[
                              const SizedBox(height: 12),
                              _input(
                                _salePrice,
                                l10n.discountPriceLabel,
                                isNumber: true,
                              ),
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
                            labelText: l10n.kdvLabel,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 1,
                              child: Text(l10n.discountRate1Label),
                            ),
                            DropdownMenuItem(
                              value: 10,
                              child: Text(l10n.discountRate10Label),
                            ),
                            DropdownMenuItem(
                              value: 20,
                              child: Text(l10n.discountRate20Label),
                            ),
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
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
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
                          l10n.tapToApplySuggestedPrice,
                          style: AppTheme.caption(color: Colors.green),
                        ),
                      ),
                    ),

                  // =============================
                  // 🚚 SHIPPING SYSTEM (TRENDYOL LEVEL)
                  // =============================
                  Text(
                    l10n.shippingAndDeliverySectionTitle,
                    style: AppTheme.h2(),
                  ),
                  const SizedBox(height: 12),

                  // 📦 WEIGHT
                  _input(
                    _weightKg,
                    l10n.weightLabel,
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
                              l10n.lengthLabel,
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
                          l10n.widthLabel,
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
                          l10n.heightLabel,
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
                      l10n.calculatedDesiLabel(
                        (_calculatedDesi ?? _computeDesi()).toStringAsFixed(2),
                      ),
                      style: AppTheme.caption(),
                    ),
                  ),

                  _input(
                    _fixedDesi,
                    l10n.manualDesiOverrideOptionalLabel,
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
                      labelText: l10n.shippingModeLabel,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: "carrier_calculated",
                        child: Text(l10n.carrierCalculatedLabel),
                      ),
                      DropdownMenuItem(
                        value: "fixed_price",
                        child: Text(l10n.fixedShippingFeeLabel),
                      ),
                      DropdownMenuItem(
                        value: "seller_absorbs",
                        child: Text(l10n.sellerPaysShippingLabel),
                      ),
                      DropdownMenuItem(
                        value: "free_shipping",
                        child: Text(l10n.freeShippingLabel),
                      ),
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
                    },
                  ),

                  const SizedBox(height: 12),

                  // 💵 FIXED PRICE
                  if (_shippingMode == "fixed_price")
                    _input(
                      _shippingFee,
                      l10n.fixedShippingFeeLabel,
                      isNumber: true,
                    ),

                  // 🎯 FREE SHIPPING
                  SwitchListTile(
                    title: Text(l10n.enableFreeShippingCampaignLabel),
                    value: _allowFreeShipping,
                    onChanged: (v) {
                      setState(() => _allowFreeShipping = v);
                      _updateShippingPreview();
                    },
                  ),

                  if (_shippingPayer == "conditional" || _allowFreeShipping)
                    _input(
                      _freeShippingThreshold,
                      l10n.freeShippingThresholdLabel,
                      isNumber: true,
                      onChanged: (_) => _updateShippingPreview(),
                    ),

                  const SizedBox(height: 12),

                  // ⏱ DELIVERY TIME
                  _input(
                    _prepDays,
                    l10n.preparationTimeDaysLabel,
                    isNumber: true,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    _maxDeliveryDays,
                    l10n.maxDeliveryTimeDaysLabel,
                    isNumber: true,
                  ),
                  _buildShippingPreview(),
                  const SizedBox(height: 12),

                  // 🚛 CARRIERS
                  Text(l10n.cargoCompaniesTitle, style: AppTheme.h2()),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 6,
                    children: _carrierOptions.map((carrier) {
                      final code = carrier["code"]!;
                      final label = _carrierLabel(l10n, code);
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
                    title: Text(l10n.allowReturnsLabel),
                    value: _allowReturns,
                    onChanged: (v) => setState(() => _allowReturns = v),
                  ),

                  if (_allowReturns) ...[
                    _input(
                      _returnWindowDays,
                      l10n.returnWindowDaysLabel,
                      isNumber: true,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _returnShippingPayer,
                      decoration: InputDecoration(
                        labelText: l10n.returnShippingPayerLabel,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: "seller_always",
                          child: Text(l10n.sellerOptionLabel),
                        ),
                        DropdownMenuItem(
                          value: "buyer",
                          child: Text(l10n.buyerOptionLabel),
                        ),
                        DropdownMenuItem(
                          value: "seller_if_contract_carrier",
                          child: Text(l10n.sellerContractedCarrierOnlyLabel),
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
                  Text(l10n.inventoryTitle, style: AppTheme.h2()),
                  const SizedBox(height: 12),

                  _input(_stock, l10n.inventoryStockFieldLabel, isNumber: true),
                  const SizedBox(height: 12),
                  _input(_minStock, l10n.lowStockAlertLabel, isNumber: true),

                  const SizedBox(height: 12),

                  // 🔹 CATEGORY
                  Text(l10n.categoryLabel, style: AppTheme.h2()),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _mainCategory,
                    decoration: InputDecoration(
                      labelText: l10n.mainCategoryLabel,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: categories.keys
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(_categoryLabel(l10n, e)),
                          ),
                        )
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
                      labelText: l10n.subCategoryLabel,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: categories[_mainCategory]!
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(_subCategoryLabel(l10n, e)),
                          ),
                        )
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
                      Text(l10n.descriptionLabel, style: AppTheme.h2()),
                      TextButton.icon(
                        onPressed: _isGeneratingDescription
                            ? null
                            : _generateSuggestedDescription,
                        icon: const Icon(LucideIcons.sparkles, size: 16),
                        label: Text(
                          _isGeneratingDescription
                              ? l10n.generatingLabel
                              : l10n.suggestLabel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _input(_desc, l10n.descriptionLabel, maxLines: 4),

                  const SizedBox(height: 30),

                  // 🔹 LOADING
                  if (_loading) LinearProgressIndicator(value: _uploadProgress),

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
                      isEdit ? l10n.updateProductTitle : l10n.addProductTitle,
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
                    child: Text(l10n.sellInstantlyButtonLabel),
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
    final l10n = AppLocalizations.of(context)!;
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
          Text(
            l10n.shippingEstimateTitle,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),

          Text(
            l10n.desiLabel(s.computedDesi.toStringAsFixed(2)),
            style: const TextStyle(color: Colors.white70),
          ),

          Text(
            l10n.billableLabel(s.effectiveUnit.toStringAsFixed(2)),
            style: const TextStyle(color: Colors.white70),
          ),

          Text(
            l10n.basePriceLabel(s.basePrice.toStringAsFixed(2), _currency),
            style: const TextStyle(color: Colors.white70),
          ),

          if (s.surcharge > 0)
            Text(
              l10n.extraLabel(s.surcharge.toStringAsFixed(2), _currency),
              style: const TextStyle(color: Colors.orangeAccent),
            ),

          const SizedBox(height: 6),

          Text(
            s.isFreeShipping
                ? l10n.freeShippingLabel.toUpperCase()
                : l10n.totalPriceLabel(s.total.toStringAsFixed(2), _currency),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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

    return {"carrier": bestCarrier, "price": bestPrice};
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

    return {"buyerPays": buyerPays, "sellerPays": sellerPays};
  }
}
<<<<<<< HEAD
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
=======
>>>>>>> 823c872 (ci: add flutter github actions workflow)
