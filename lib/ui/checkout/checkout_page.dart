import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/subscription/models/cart_item.dart';
import 'package:barky_matches_fixed/services/petshop_checkout_service.dart';
import 'package:barky_matches_fixed/services/order_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:barky_matches_fixed/ui/petshop/petshop_checkout_webview_page.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:barky_matches_fixed/utils/carrier_mapper.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckoutPage extends StatefulWidget {
  final List<CartItem> items;

  const CheckoutPage({super.key, required this.items});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _checkoutService = PetshopCheckoutService();
  final _orderService = OrderService();

  /// 📦 ADDRESS
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(); // user enters 5xxxxxxxxx
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _addressController = TextEditingController();

  /// 🧾 BILLING
  final _identityNumberController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _taxOfficeController = TextEditingController();

  String invoiceType = "individual"; // individual | company
  String notificationPreference = "sms"; // sms | email | both

  /// ⚖️ LEGAL
  bool kvkkAccepted = false;
  bool preInfoAccepted = false;
  bool distanceSalesAccepted = false;
  bool marketingConsent = false;

  String? _selectedCarrier;

  bool _loading = false;
  bool _pricingLoading = true;

  double get subtotal {
    return widget.items.fold<double>(
      0,
      (sum, item) => sum + item.price * item.quantity,
    );
  }

  double backendSubtotal = 0;
  double backendShipping = 0;
  double backendTax = 0;
  double backendTotal = 0;

  bool _addressExpanded = false;
  bool _shippingExpanded = false;

  List<String> availableCarriers = [];

  int _step = 0;

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF9E1B4F), width: 1.2),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    final shopIds = widget.items.map((e) => e.shopId).toSet();

    if (shopIds.length > 1) {
      throw Exception("Multiple sellers in one checkout not supported yet");
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user?.displayName != null && user!.displayName!.trim().isNotEmpty) {
      _fullNameController.text = user.displayName!.trim();
    }

    if (user?.email != null && user!.email!.trim().isNotEmpty) {
      _emailController.text = user.email!.trim();
    }

    // ✅ FIXED
    // 🔥 FIX REAL
    debugPrint("🧪 CHECKOUT ITEMS COUNT: ${widget.items.length}");

    if (widget.items.isEmpty) {
      debugPrint("❌ CHECKOUT OPENED WITH EMPTY ITEMS");

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.cartIsEmpty)),
        );

        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil("/home", (route) => false);
      });

      return;
    }

    final carriers = widget.items.first.product.allowedCarrierCodes ?? [];

    availableCarriers = List<String>.from(carriers);

    if (availableCarriers.isNotEmpty) {
      _selectedCarrier = availableCarriers.first;
    }

    for (var item in widget.items) {
      debugPrint("🚚 CART ITEM CARRIERS: ${item.product.allowedCarrierCodes}");
    }

    debugPrint("🧪 FINAL availableCarriers: $availableCarriers");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPricing();
    });
  }

  Future<void> _loadPricing() async {
    try {
      debugPrint("💰 LOADING PRICING FROM BACKEND...");

      final result = await _checkoutService.calculatePricing(
        items: widget.items.map((e) => e.toJson()).toList(),
        carrier: _selectedCarrier ?? "",
      );

      final pricing = result["pricing"];

      if (pricing != null) {
        setState(() {
          backendSubtotal = (pricing['subtotal'] ?? 0).toDouble();
          backendShipping = (pricing['shippingTotal'] ?? 0).toDouble();
          backendTax = (pricing['taxTotal'] ?? 0).toDouble();
          backendTotal = (pricing['grandTotal'] ?? 0).toDouble();
          _pricingLoading = false;
        });
      }

      debugPrint("✅ PRICING LOADED: $pricing");
    } catch (e) {
      debugPrint("❌ PRICING ERROR: $e");
      setState(() {
        _pricingLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _addressController.dispose();
    _identityNumberController.dispose();
    _companyNameController.dispose();
    _taxNumberController.dispose();
    _taxOfficeController.dispose();
    super.dispose();
  }

  bool isValidName(String name) {
    return name.trim().split(RegExp(r'\s+')).length >= 2;
  }

  bool isValidPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final regex = RegExp(r'^5\d{9}$');
    return regex.hasMatch(digits);
  }

  bool isValidText(String text) {
    return text.trim().length >= 2;
  }

  bool isValidAddress(String text) {
    return text.trim().length >= 10;
  }

  bool isValidEmail(String email) {
    final value = email.trim();
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(value);
  }

  bool isValidTcIdentity(String value) {
    return RegExp(r'^\d{11}$').hasMatch(value.trim());
  }

  bool isValidTaxNumber(String value) {
    return RegExp(r'^\d{10}$').hasMatch(value.trim());
  }

  String _normalizedPhoneDigits() {
    return _phoneController.text.replaceAll(RegExp(r'\D'), '');
  }

  String _gsmNumber() {
    final digits = _normalizedPhoneDigits(); // 5xxxxxxxxx
    return '+90$digits';
  }

  Map<String, String> _splitFullName() {
    final parts = _fullNameController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    final name = parts.isNotEmpty ? parts.first : '';
    final surname = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return {'name': name, 'surname': surname};
  }

  Widget _buildStepHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepItem(l10n.checkoutStepAddressTitle, 0),
          _stepItem(l10n.checkoutStepPaymentTitle, 1),
          _stepItem(l10n.checkoutStepConfirmTitle, 2),
        ],
      ),
    );
  }

  Widget _stepItem(String title, int index) {
    final active = _step == index;

    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: active
              ? const Color(0xFF9E1B4F)
              : Colors.grey.shade300,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: active ? Colors.black : Colors.grey,
          ),
        ),
      ],
    );
  }

  Future<String> _getUserIp() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://api.ipify.org'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();
      return body.trim().isNotEmpty ? body.trim() : '0.0.0.0';
    } catch (_) {
      return '0.0.0.0';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _validate() {
    final l10n = AppLocalizations.of(context)!;
    debugPrint("🚚 SELECTED CARRIER: $_selectedCarrier");
    if (!isValidName(_fullNameController.text)) {
      _showError(l10n.checkoutEnterNameSurname);
      return false;
    }

    if (_selectedCarrier == null) {
      _showError(l10n.checkoutPleaseSelectCargoCompany);
      return false;
    }

    if (!isValidEmail(_emailController.text)) {
      _showError(l10n.checkoutEnterValidEmail);
      return false;
    }

    if (!isValidPhone(_phoneController.text)) {
      _showError(l10n.checkoutEnterValidPhone);
      return false;
    }

    if (!isValidText(_cityController.text)) {
      _showError(l10n.checkoutEnterCity);
      return false;
    }

    if (!isValidText(_districtController.text)) {
      _showError(l10n.checkoutEnterDistrict);
      return false;
    }

    if (!isValidAddress(_addressController.text)) {
      _showError(l10n.checkoutEnterFullAddress);
      return false;
    }

    if (invoiceType == "individual") {
      if (!isValidTcIdentity(_identityNumberController.text)) {
        _showError(l10n.checkoutEnterValidIdentityNumber);
        return false;
      }
    }

    if (invoiceType == "company") {
      if (!isValidText(_companyNameController.text)) {
        _showError(l10n.checkoutEnterCompanyName);
        return false;
      }
      if (!isValidTaxNumber(_taxNumberController.text)) {
        _showError(l10n.checkoutEnterValidTaxNumber);
        return false;
      }
      if (!isValidText(_taxOfficeController.text)) {
        _showError(l10n.checkoutEnterTaxOffice);
        return false;
      }
    }

    if (!kvkkAccepted || !preInfoAccepted || !distanceSalesAccepted) {
      _showError(l10n.checkoutAcceptRequiredAgreements);
      return false;
    }

    return true;
  }

  /// 🔥 MAIN CHECKOUT LOGIC
  Future<void> _startCheckout() async {
    if (_loading) return;

    if (!_validate()) return;

    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      final names = _splitFullName();
      final ip = await _getUserIp();

      /// ✅ FIX: همه فیلدها trim + fallback
      final email = _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : (user.email ?? "${_gsmNumber()}@barky.fake");

      final phone = _gsmNumber(); // already +90 formatted

      final buyer = {
        "buyerId": user.uid, // ❗ قبلاً id بود
        "name": names["name"] ?? "",
        "surname": names["surname"] ?? "",
        "email": _emailController.text.trim(),

        "gsmNumber": _gsmNumber(), // ok برای iyzico

        "identityNumber": invoiceType == "company"
            ? "11111111111"
            : _identityNumberController.text.trim(),

        "registrationAddress": _addressController.text.trim(),
        "city": _cityController.text.trim(),
        "country": "Turkey",
        "ip": ip,
      };

      /// 🔥 DEBUG (خیلی مهم)
      debugPrint("🔥 FINAL BUYER: $buyer");

      /// 🚨 VALIDATION BEFORE CALL
      if (buyer["name"] == "" ||
          buyer["surname"] == "" ||
          buyer["email"] == "" ||
          buyer["gsmNumber"] == "") {
        throw Exception("Buyer fields are empty → $buyer");
      }

      /// -------------------------
      /// ADDRESSES
      /// -------------------------
      final shippingAddress = {
        "contactName": _fullNameController.text.trim(),
        "city": _cityController.text.trim(),
        "district": _districtController.text.trim(),
        "address": _addressController.text.trim(),
        "country": "Turkey",
      };

      final billingAddress = {
        "contactName": invoiceType == "company"
            ? _companyNameController.text.trim()
            : _fullNameController.text.trim(),
        "city": _cityController.text.trim(),
        "district": _districtController.text.trim(),
        "address": _addressController.text.trim(),
        "country": "Turkey",
      };

      /// -------------------------
      /// ORDER DATA
      /// -------------------------
      final orderAddress = {
        "fullName": _fullNameController.text.trim(),
        "email": email,
        "phoneLocal": _normalizedPhoneDigits(),
        "gsmNumber": phone,
        "city": _cityController.text.trim(),
        "district": _districtController.text.trim(),
        "address": _addressController.text.trim(),
        "country": "Turkey",
        "notificationPreference": notificationPreference,
      };

      final orderBilling = {
        "invoiceType": invoiceType,
        "contactName": billingAddress["contactName"],
        "city": billingAddress["city"],
        "district": billingAddress["district"],
        "address": billingAddress["address"],
        "country": billingAddress["country"],
        "identityNumber": invoiceType == "individual"
            ? _identityNumberController.text.trim()
            : null,
        "companyName": invoiceType == "company"
            ? _companyNameController.text.trim()
            : null,
        "taxNumber": invoiceType == "company"
            ? _taxNumberController.text.trim()
            : null,
        "taxOffice": invoiceType == "company"
            ? _taxOfficeController.text.trim()
            : null,
        "invoiceDeliveryPreference": notificationPreference,
      };

      final legalPayload = {
        "kvkkAccepted": kvkkAccepted,
        "preInfoAccepted": preInfoAccepted,
        "distanceSalesAccepted": distanceSalesAccepted,
        "marketingConsent": marketingConsent,
        "notificationPreference": notificationPreference,
        "acceptedAt": DateTime.now().toIso8601String(),
      };

      final buyerName = (orderAddress["fullName"] ?? "").toString();
      final buyerPhone = (orderAddress["gsmNumber"] ?? "").toString();
      final buyerEmail = (orderAddress["email"] ?? "").toString();

      /// -------------------------
      /// 1) CREATE ORDER
      /// -------------------------

      final orderItems = widget.items.map<Map<String, dynamic>>((item) {
        return {
          "shopId": item.shopId,
          "productId": item.productId,
          "name": item.name,
          "quantity": item.quantity,
          "unitPrice": item.price,
          "price": item.price,
          "shippingFeeTotal": 0, // backend override می‌کنه
          "taxTotal": 0, // backend override
          "imageUrl": item.imageUrl,
        };
      }).toList();

      final result = await _orderService.createMarketplaceOrderV2(
        buyer: {"name": buyerName, "email": buyerEmail, "phone": buyerPhone},
        billing: {
          // 🔥🔥🔥 این دو خط رو اضافه کن
          "name": buyerName,
          "surname": names["surname"],

          // بقیه کد تو
          "invoiceType": invoiceType,
          "contactName": orderBilling["contactName"],
          "companyName": orderBilling["companyName"],
          "identityNumber": orderBilling["identityNumber"],
          "taxNumber": orderBilling["taxNumber"],
          "taxOffice": orderBilling["taxOffice"],
          "city": orderBilling["city"],
          "district": orderBilling["district"],
          "address": orderBilling["address"],
          "country": "Turkey",
        },
        delivery: {
          "fullName": orderAddress["fullName"],
          "phone": orderAddress["gsmNumber"],
          "city": orderAddress["city"],
          "district": orderAddress["district"],
          "address": orderAddress["address"],
        },
        payment: {"status": "pending", "provider": "iyzico"},
        carrier: _selectedCarrier!, // 🔥🔥🔥 این خط
        legal: legalPayload,
        items: orderItems,
      );

      final orderId = result["orderId"];
      final orderNumber = result["orderNumber"];

      debugPrint("🧪 WAITING FOR ORDER VISIBILITY...");

      // ✅ FIXED ORDER READ
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get(GetOptions(source: Source.server));

      debugPrint("✅ NEW ROOT ORDER: $orderId");
      debugPrint("✅ ORDER NUMBER: $orderNumber");
      debugPrint("🟢 ORDER CREATED: $orderId");

      /// -------------------------
      /// 2) CHECKOUT SESSION
      /// -------------------------
      final session = await _checkoutService.createCheckoutSession(
        orderId: orderId, // ✅ اینو اضافه کن

        items: widget.items.map((e) => e.toJson()).toList(),
        currency: 'TRY',
        carrier: _selectedCarrier!,

        successUrl:
            'barkymatches://payment-success?orderId=$orderId&orderNumber=$orderNumber',
        cancelUrl: 'barkymatches://payment-cancel?orderId=$orderId',

        note: orderId,
        buyer: buyer,
        shippingAddress: shippingAddress,
        billingAddress: billingAddress,
      );
      final pricing = session.pricing;

      if (pricing != null) {
        setState(() {
          backendSubtotal = (pricing['subtotal'] ?? 0).toDouble();
          backendShipping = (pricing['shippingTotal'] ?? 0).toDouble();
          backendTax = (pricing['taxTotal'] ?? 0).toDouble();
          backendTotal = (pricing['grandTotal'] ?? 0).toDouble();
        });
      }
      debugPrint("🔥 BACKEND RESPONSE: ${session.checkoutUrl}");
      debugPrint("🌐 CHECKOUT URL: ${session.checkoutUrl}");

      debugPrint("💰 REAL TOTAL FROM BACKEND: ${pricing?['grandTotal']}");

      if (!mounted) return;

      /// -------------------------
      /// 3) WEBVIEW
      /// -------------------------
      await Future.delayed(const Duration(milliseconds: 300));
      FocusScope.of(context).unfocus();

      final checkoutUri = Uri.parse(session.checkoutUrl);

      final launched = await launchUrl(
        checkoutUri,
        mode: LaunchMode.externalApplication, // 🔥 مهم
      );

      if (!launched) {
        throw Exception("Could not launch checkout URL");
      }

      if (!mounted) return;

      // debugPrint("🔁 RESULT: $result");

      /// -------------------------
      /// 4) VERIFY
      /// -------------------------
      if (!mounted) return;

      _showError(
        AppLocalizations.of(context)!.checkoutPaymentPageOpenedMessage,
      );
    } catch (e) {
      debugPrint("❌ CHECKOUT ERROR: $e");
      if (!mounted) return;
      _showError(AppLocalizations.of(context)!.errorOccurred(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> verifyPayment(String orderId) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('verifyPaymentByOrderId');

      final result = await callable.call({"orderId": orderId});

      debugPrint("✅ VERIFY RESPONSE: ${result.data}");

      final data = Map<String, dynamic>.from(result.data as Map);

      final success = data["success"] == true;
      final pending = data["pending"] == true;

      if (success) {
        debugPrint("🎉 PAYMENT SUCCESS");
        return true;
      }

      if (pending) {
        debugPrint("⏳ PAYMENT STILL PENDING");
        return false;
      }

      debugPrint("❌ PAYMENT FAILED");
      return false;
    } catch (e, st) {
      debugPrint("💥 VERIFY ERROR: $e");
      debugPrint("📍 STACK: $st");
      return false;
    }
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildOrderItemsSection() {
    final item = widget.items.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          /// 🖼️ (اختیاری: اگر عکس داری)
          if (item.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                item.imageUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),

          if (item.imageUrl != null) const SizedBox(width: 10),

          /// 📦 info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "${item.quantity} × ${item.price.toStringAsFixed(2)} ₺",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),

          /// 💰 price
          Text(
            "${(item.price * item.quantity).toStringAsFixed(2)} ₺",
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    final l10n = AppLocalizations.of(context)!;
    final hasData = _fullNameController.text.isNotEmpty;

    return GestureDetector(
      onTap: () {
        setState(() => _addressExpanded = !_addressExpanded);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            /// 🔹 HEADER (compact)
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.checkoutDeliveryAddressTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (hasData)
                  Expanded(
                    child: Text(
                      _fullNameController.text,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Icon(
                  _addressExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ],
            ),

            /// 🔹 FORM (expand)
            if (_addressExpanded) ...[
              const SizedBox(height: 12),

              TextField(
                controller: _fullNameController,
                decoration: _inputDecoration(
                  l10n.checkoutFullNameLabel,
                  l10n.checkoutFullNameHint,
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _emailController,
                decoration: _inputDecoration(
                  l10n.emailLabel,
                  l10n.emailAddressHint,
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _phoneController,
                decoration: _inputDecoration(
                  l10n.phoneLabel,
                  l10n.checkoutPhoneHint,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cityController,
                      decoration: _inputDecoration(
                        l10n.checkoutCityLabel,
                        l10n.checkoutCityHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _districtController,
                      decoration: _inputDecoration(
                        l10n.checkoutDistrictLabel,
                        l10n.checkoutDistrictHint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _addressController,
                maxLines: 3,
                decoration: _inputDecoration(
                  l10n.checkoutAddressLabel,
                  l10n.checkoutAddressHint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBillingSection() {
    final l10n = AppLocalizations.of(context)!;
    return _buildSectionCard(
      title: l10n.checkoutInvoiceDetailsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  value: "individual",
                  groupValue: invoiceType,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.checkoutIndividualOption),
                  onChanged: (v) => setState(() => invoiceType = v!),
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  value: "company",
                  groupValue: invoiceType,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.checkoutCompanyOption),
                  onChanged: (v) => setState(() => invoiceType = v!),
                ),
              ),
            ],
          ),
          if (invoiceType == "individual") ...[
            TextField(
              controller: _identityNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: InputDecoration(
                labelText: l10n.checkoutIdentityNumberLabel,
                hintText: l10n.checkoutIdentityNumberHint,
              ),
            ),
          ],
          if (invoiceType == "company") ...[
            TextField(
              controller: _companyNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.checkoutCompanyNameLabel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taxNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: l10n.checkoutTaxNumberLabel,
                hintText: l10n.checkoutTaxNumberHint,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _taxOfficeController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.checkoutTaxOfficeLabel,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationSection() {
    final l10n = AppLocalizations.of(context)!;
    return _buildSectionCard(
      title: l10n.checkoutCargoUpdatesTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.checkoutCargoUpdatesQuestion),
          const SizedBox(height: 10),
          RadioListTile<String>(
            value: "sms",
            groupValue: notificationPreference,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.checkoutSmsOption),
            onChanged: (v) => setState(() => notificationPreference = v!),
          ),
          RadioListTile<String>(
            value: "email",
            groupValue: notificationPreference,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.checkoutEmailOption),
            onChanged: (v) => setState(() => notificationPreference = v!),
          ),
          RadioListTile<String>(
            value: "both",
            groupValue: notificationPreference,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.checkoutSmsEmailOption),
            onChanged: (v) => setState(() => notificationPreference = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalSection() {
    final l10n = AppLocalizations.of(context)!;
    return _buildSectionCard(
      title: l10n.checkoutAgreementsTitle,
      child: Column(
        children: [
          /// KVKK
          Row(
            children: [
              Checkbox(
                value: kvkkAccepted,
                onChanged: (v) => setState(() => kvkkAccepted = v!),
              ),
              Expanded(child: Text(l10n.checkoutKvkkDisclosure)),
              TextButton(
                onPressed: () async {
                  final url = Uri.parse(
                    "https://petsupo.com/kvkk-aydinlatma-metni",
                  );
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
                child: Text(l10n.checkoutViewButton),
              ),
            ],
          ),

          /// PRE INFORMATION
          Row(
            children: [
              Checkbox(
                value: preInfoAccepted,
                onChanged: (v) => setState(() => preInfoAccepted = v!),
              ),
              Expanded(child: Text(l10n.checkoutPreInfoForm)),
              TextButton(
                onPressed: () async {
                  final url = Uri.parse(
                    "https://petsupo.com/on-bilgilendirme-formu",
                  );
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
                child: Text(l10n.checkoutViewButton),
              ),
            ],
          ),

          /// DISTANCE SALES
          Row(
            children: [
              Checkbox(
                value: distanceSalesAccepted,
                onChanged: (v) => setState(() => distanceSalesAccepted = v!),
              ),
              Expanded(child: Text(l10n.checkoutDistanceSalesAgreement)),
              TextButton(
                onPressed: () async {
                  final url = Uri.parse(
                    "https://petsupo.com/mesafeli-satis-sozlesmesi",
                  );
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
                child: Text(l10n.checkoutViewButton),
              ),
            ],
          ),

          /// MARKETING (OPTIONAL)
          Row(
            children: [
              Checkbox(
                value: marketingConsent,
                onChanged: (v) => setState(() => marketingConsent = v!),
              ),
              Expanded(child: Text(l10n.checkoutMarketingOptional)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarrierSelection() {
    final l10n = AppLocalizations.of(context)!;
    final carriers = availableCarriers;

    if (carriers.isEmpty) {
      return const SizedBox();
    }

    return GestureDetector(
      onTap: () {
        setState(() => _shippingExpanded = !_shippingExpanded);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.checkoutDeliveryTitle,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  CarrierMapper.toDisplay(_selectedCarrier ?? ""),
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(width: 6),
                Icon(
                  _shippingExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ],
            ),

            if (_shippingExpanded) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCarrier ?? carriers.first,
                items: carriers
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(CarrierMapper.toDisplay(c)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedCarrier = v;
                    _pricingLoading = true;
                  });
                  _loadPricing();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsSection() {
    final l10n = AppLocalizations.of(context)!;
    if (_pricingLoading) {
      return _buildSectionCard(
        title: l10n.checkoutPaymentSummaryTitle,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // 🔥 light yellow
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.checkoutPaymentSummaryTitle,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 12),

          _row(l10n.checkoutSubtotalLabel, backendSubtotal),
          _row(l10n.checkoutVatLabel, backendTax),
          _row(l10n.checkoutShippingLabel, backendShipping),

          const Divider(height: 20),

          _row(l10n.totalLabel, backendTotal, isTotal: true),
        ],
      ),
    );
  }

  Widget _row(String title, double value, {bool isTotal = false}) {
    final style = isTotal
        ? const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: Color(0xFF9E1B4F),
          )
        : const TextStyle(fontSize: 14, color: Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: style),
          Text("${value.toStringAsFixed(2)} ₺", style: style),
        ],
      ),
    );
  }

  bool _validateStep() {
    final l10n = AppLocalizations.of(context)!;

    /// STEP 0 → Address + Carrier
    if (_step == 0) {
      if (_selectedCarrier == null) {
        _showError(l10n.checkoutPleaseSelectCargoCompany);
        return false;
      }

      if (!isValidName(_fullNameController.text)) {
        _showError(l10n.checkoutEnterNameSurname);
        return false;
      }

      if (!isValidEmail(_emailController.text)) {
        _showError(l10n.checkoutEnterValidEmail);
        return false;
      }

      if (!isValidPhone(_phoneController.text)) {
        _showError(l10n.checkoutEnterValidPhone);
        return false;
      }

      if (!isValidText(_cityController.text)) {
        _showError(l10n.checkoutEnterCity);
        return false;
      }

      if (!isValidText(_districtController.text)) {
        _showError(l10n.checkoutEnterDistrict);
        return false;
      }

      if (!isValidAddress(_addressController.text)) {
        _showError(l10n.checkoutEnterFullAddress);
        return false;
      }
    }

    /// STEP 1 → Billing + Legal
    if (_step == 1) {
      if (invoiceType == "individual") {
        if (!isValidTcIdentity(_identityNumberController.text)) {
          _showError(l10n.checkoutEnterValidIdentityNumber);
          return false;
        }
      }

      if (invoiceType == "company") {
        if (!isValidText(_companyNameController.text)) {
          _showError(l10n.checkoutEnterCompanyName);
          return false;
        }

        if (!isValidTaxNumber(_taxNumberController.text)) {
          _showError(l10n.checkoutEnterValidTaxNumber);
          return false;
        }

        if (!isValidText(_taxOfficeController.text)) {
          _showError(l10n.checkoutEnterTaxOffice);
          return false;
        }
      }

      if (!kvkkAccepted || !preInfoAccepted || !distanceSalesAccepted) {
        _showError(l10n.checkoutAcceptRequiredAgreements);
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.checkoutButton)),
        body: Center(child: Text(l10n.cartIsEmpty)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkoutButton)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          children: [
            /// 🧾 Order (compact)
            _buildOrderItemsSection(),

            /// 🔢 Step Header
            _buildStepHeader(),

            const SizedBox(height: 10),

            /// 🟢 STEP 0 → Address + Shipping
            if (_step == 0) ...[
              _buildCarrierSelection(),
              _buildAddressSection(),
            ],

            /// 🟡 STEP 1 → Billing + Legal
            if (_step == 1) ...[
              _buildBillingSection(),
              _buildNotificationSection(),
              _buildLegalSection(),
            ],

            /// 🔴 STEP 2 → Summary
            if (_step == 2) ...[_buildTotalsSection()],

            const SizedBox(height: 12),

            /// 🔙 BACK BUTTON
            if (_step > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _step--);
                    },
                    child: Text(l10n.checkoutBackButton),
                  ),
                ),
              ),

            /// 🔘 CONTINUE / PAY BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

                onPressed: (_loading || _pricingLoading)
                    ? null
                    : () {
                        if (_step < 2) {
                          if (!_validateStep()) return;

                          setState(() => _step++);
                        } else {
                          _startCheckout();
                        }
                      },

                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _step == 2
                            ? l10n.checkoutProceedToPayment
                            : l10n.checkoutContinueButton,
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
