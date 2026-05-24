import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';
import 'package:barky_matches_fixed/services/order_return_service.dart';
import 'package:barky_matches_fixed/models/order_return.dart';
import 'package:barky_matches_fixed/ui/returns/order_return_card.dart';
import 'package:barky_matches_fixed/ui/orders/return_request_sheet.dart';

class OrderDetailPage extends StatefulWidget {
  final String sellerOrderId;

  const OrderDetailPage({super.key, required this.sellerOrderId});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final TextEditingController _trackingController = TextEditingController();

  bool _isLoading = false;
  String? _selectedCarrier;

  bool _isUploadingInvoice = false;

  String formatDeadline(String? raw) {
    if (raw == null) return "-";

    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;

    return DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(dt.toLocal());
  }

  String validationLabel(String code, AppLocalizations l10n) {
    switch (code) {
      case 'seller_tax_number_not_found':
        return l10n.sellerTaxNumberMissing;
      case 'buyer_identity_not_found':
        return l10n.buyerIdentityNumberMissing;
      case 'buyer_tax_number_not_found':
        return l10n.buyerTaxNumberMissing;
      case 'invoice_system_mismatch':
        return l10n.invoiceSystemMismatch;
      default:
        return code;
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint("🔥 OPEN ORDER ID: ${widget.sellerOrderId}");
  }

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  String invoiceStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending_upload':
        return l10n.invoiceStatusPendingUploadLabel;
      case 'uploaded_valid':
        return l10n.invoiceStatusUploadedValidLabel;
      case 'uploaded_with_issues':
        return l10n.invoiceStatusUploadedWithIssuesLabel;
      case 'late':
        return l10n.invoiceStatusLateLabel;
      case 'approved':
        return l10n.invoiceStatusApprovedLabel;
      case 'rejected':
        return l10n.invoiceStatusRejectedLabel;
      default:
        return status;
    }
  }

  Color invoiceStatusColor(String status, bool late) {
    if (late) return Colors.red;

    switch (status) {
      case 'approved':
        return Colors.green;
      case 'uploaded':
        return Colors.blue;
      case 'pending_upload':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String normalizeStatus(String s) {
    final lower = s.toLowerCase();

    if (lower.contains("pending")) return "pending";
    if (lower.contains("paid")) return "paid";
    if (lower.contains("confirmed")) return "confirmed";
    if (lower.contains("preparing")) return "preparing";
    if (lower.contains("shipped")) return "shipped";
    if (lower.contains("delivered")) return "delivered";
    if (lower.contains("completed")) return "completed";
    if (lower.contains("fail")) return "failed";
    if (lower.contains("cancel")) return "cancelled";

    return lower;
  }

  Color getStatusColor(String status) {
    switch (status) {
      case "paid":
        return Colors.green;
      case "confirmed":
        return Colors.teal;
      case "preparing":
        return Colors.orange;
      case "shipped":
        return Colors.blue;
      case "delivered":
        return Colors.purple;
      case "failed":
        return Colors.red;
      case "cancelled":
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String orderStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case "pending":
        return l10n.pendingStatusLabel;
      case "paid":
        return l10n.paidStatusLabel;
      case "confirmed":
        return l10n.confirmedStatusLabel;
      case "preparing":
        return l10n.preparingStatusLabel;
      case "shipped":
        return l10n.shippedStatusLabel;
      case "delivered":
        return l10n.deliveredStatusLabel;
      case "completed":
        return l10n.completedStatusLabel;
      case "failed":
        return l10n.failedStatusLabel;
      case "cancelled":
        return l10n.cancelledStatusLabel;
      default:
        return status;
    }
  }

  String payoutStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case "paid":
        return l10n.paidPayoutStatusLabel;
      case "pending":
        return l10n.pendingPayoutLabel;
      case "payment_pending":
        return l10n.waitingForCustomerPayment;
      case "not_set":
        return l10n.payoutNotSetLabel;
      default:
        return status;
    }
  }

  Future<void> _uploadInvoice(String orderId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'png'],
      );

      if (result == null) return;

      final file = result.files.first;

      Uint8List? fileBytes = file.bytes;

      if (fileBytes == null && file.path != null) {
        final f = File(file.path!);
        fileBytes = await f.readAsBytes();
      }

      if (fileBytes == null) {
        throw Exception(l10n.fileIsEmpty);
      }

      if (fileBytes.length > 5 * 1024 * 1024) {
        throw Exception(l10n.fileTooLarge);
      }

      final fileName = file.name;

      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('uploadInvoiceAndValidate');

      await callable.call({
        "sellerOrderId": orderId,
        "fileBytes": fileBytes,
        "fileName": fileName,
      });
      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.invoiceUploadedSuccessfully)));
    } catch (e) {
      debugPrint("❌ upload error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.uploadFailed(e.toString()))));
    }
  }

  Widget buildTimeline(List timeline, AppLocalizations l10n) {
    if (timeline.isEmpty) {
      return Text(l10n.noTimelineYet);
    }

    return Column(
      children: timeline.map<Widget>((step) {
        final status = normalizeStatus(step['status'] ?? '');
        final color = getStatusColor(status);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(width: 2, height: 40, color: Colors.grey.shade300),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orderStatusLabel(status, l10n),
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step['at']?.toString() ?? '',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Future<void> updateStatus(String newStatus) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      setState(() => _isLoading = true);

      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('updateSellerOrderStatusV2');

      await callable.call({
        "sellerOrderId": widget.sellerOrderId,
        "status": newStatus,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.orderStatusUpdated(orderStatusLabel(newStatus, l10n)),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorOccurred(e.toString()))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String buildCarrierWebsite(String carrier) {
    switch (carrier.toLowerCase()) {
      case "aras":
        return "https://www.araskargo.com.tr";
      case "yurtici":
        return "https://www.yurticikargo.com";
      case "mng":
        return "https://www.mngkargo.com.tr";
      case "ptt":
        return "https://www.ptt.gov.tr";
      case "hepsijet":
        return "https://www.hepsijet.com";
      case "sendeo":
        return "https://www.sendeo.com.tr";
      case "ups":
        return "https://www.ups.com/tr";
      case "dhl":
        return "https://www.dhl.com/tr-tr/home.html";
      default:
        return "";
    }
  }

  String buildTrackingUrl(String carrier, String code) {
    switch (carrier.toLowerCase()) {
      case "aras":
        return "https://kargotakip.araskargo.com.tr/mainpage.aspx?code=$code";
      case "yurtici":
        return "https://www.yurticikargo.com/tr/online-servisler/gonderi-sorgula?code=$code";
      case "mng":
        return "https://www.mngkargo.com.tr/gonderi-takip?code=$code";
      case "ptt":
        return "https://gonderitakip.ptt.gov.tr/Track/Verify?q=$code";
      case "hepsijet":
        return "https://www.hepsijet.com/gonderi-takibi/$code";
      case "sendeo":
        return "https://sendeo.com.tr/tracking/$code";
      case "ups":
        return "https://www.ups.com/track?tracknum=$code";
      case "dhl":
        return "https://www.dhl.com/tr-tr/home/tracking.html?tracking-id=$code";
      default:
        return "";
    }
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildSellerActions(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final rawStatus = data['status'] ?? 'pending_payment';
    final status = normalizeStatus(rawStatus);

    final carrier = data['shipping']?['carrier'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status == "paid")
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => updateStatus("confirmed"),
              child: Text(l10n.confirmOrderButton),
            ),
          ),

        if (status == "confirmed")
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => updateStatus("preparing"),
              child: Text(l10n.startPreparingButton),
            ),
          ),

        /// ✅ SHIPPING (بدون انتخاب کارگو)
        if (status == "preparing") ...[
          /// 👇 فقط نمایش
          Text(
            l10n.carrierLabel(carrier.isEmpty ? '-' : carrier.toUpperCase()),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _trackingController,
            decoration: InputDecoration(
              labelText: l10n.trackingNumberLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      final tracking = _trackingController.text.trim();

                      if (carrier.isEmpty) {
                        showError(l10n.carrierMissingFromOrder);
                        return;
                      }

                      if (tracking.isEmpty) {
                        showError(l10n.enterTrackingNumber);
                        return;
                      }

                      updateStatusWithShipping("shipped", tracking, carrier);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
              ),
              child: Text(l10n.shipOrderButton),
            ),
          ),
        ],

        if (status == "shipped")
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => updateStatus("delivered"),
              child: Text(l10n.markAsDeliveredButton),
            ),
          ),
      ],
    );
  }

  Widget _buildReturnSection(
    BuildContext context,
    Map<String, dynamic> data,
    bool isSeller,
    String currentUserId,
    String orderStatus,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final buyerUid = (data['buyerUid'] ?? '').toString();

    return StreamBuilder<List<OrderReturnRecord>>(
      stream: OrderReturnService.instance.watchSellerOrderReturns(
        sellerOrderId: widget.sellerOrderId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _sectionCard(
            title: l10n.returnRequestsTitle,
            child: Text(l10n.errorOccurred(snapshot.error.toString())),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _sectionCard(
            title: l10n.returnRequestsTitle,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final returns = snapshot.data ?? [];
        final hasActiveReturn = returns.any(
          (r) =>
              r.status == OrderReturnStatus.pending ||
              r.status == OrderReturnStatus.approved ||
              r.status == OrderReturnStatus.shippedBack ||
              r.status == OrderReturnStatus.receivedBySeller ||
              r.status == OrderReturnStatus.refundPending ||
              r.status == OrderReturnStatus.refundFailed,
        );
        final normalizedStatus = normalizeStatus(orderStatus);
        final canRequestReturn =
            normalizedStatus == 'delivered' || normalizedStatus == 'completed';

        debugPrint('🧾 Return CTA visible check');
        debugPrint('🧾 order status = $orderStatus');
        debugPrint('🧾 normalized status = $normalizedStatus');
        debugPrint('🧾 return eligible = $canRequestReturn');
        debugPrint('🧾 existing return count = ${returns.length}');
        debugPrint('🧾 active return exists = $hasActiveReturn');

        return _sectionCard(
          title: l10n.returnRequestsTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isSeller && buyerUid == currentUserId) ...[
                if (canRequestReturn && returns.isEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => ReturnRequestSheet(
                            sellerOrderId: widget.sellerOrderId,
                            rootOrderId: (data['rootOrderId'] ?? '').toString(),
                            buyerUid: buyerUid,
                            sellerUid:
                                (data['sellerUid'] ??
                                        data['sellerSnapshot']?['ownerUid'] ??
                                        data['shopId'] ??
                                        '')
                                    .toString(),
                            businessId:
                                (data['businessId'] ?? data['shopId'] ?? '')
                                    .toString(),
                            items: List<Map<String, dynamic>>.from(
                              (data['items'] as List? ?? const [])
                                  .whereType<Map>()
                                  .map((e) => Map<String, dynamic>.from(e)),
                            ),
                          ),
                        );

                        if (result == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.returnRequestSubmitted),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.keyboard_return_rounded),
                      label: Text(l10n.requestReturnButton),
                    ),
                  ),
                if (returns.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...returns.map(
                    (record) => OrderReturnCard(
                      record: record,
                      isSeller: false,
                      isBuyer: true,
                      onChanged: () {},
                    ),
                  ),
                ] else if (returns.isEmpty && !canRequestReturn) ...[
                  Text(l10n.returnAvailableAfterDeliveryMessage),
                ] else if (returns.isEmpty) ...[
                  Text(l10n.noReturnsYet),
                ],
              ] else ...[
                if (returns.isEmpty)
                  Text(l10n.noReturnsYet)
                else
                  ...returns.map(
                    (record) => OrderReturnCard(
                      record: record,
                      isSeller: true,
                      isBuyer: false,
                      onChanged: () {},
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> updateStatusWithShipping(
    String newStatus,
    String trackingNumber,
    String carrier,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      setState(() => _isLoading = true);

      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('updateSellerOrderStatusV2');

      final data = <String, dynamic>{
        "sellerOrderId": widget.sellerOrderId,
        "status": newStatus,
      };

      if (trackingNumber.isNotEmpty) {
        data["trackingNumber"] = trackingNumber;
      }

      if (carrier.isNotEmpty) {
        data["carrier"] = carrier;
      }

      await callable.call(data);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.orderShipped)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorOccurred(e.toString()))));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final docId = widget.sellerOrderId;

    return Scaffold(
      appBar: AppBar(
  backgroundColor: const Color(0xFFE91E63),
  elevation: 0,
  centerTitle: false,
  iconTheme: const IconThemeData(color: Colors.white),

  title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("sellerOrders")
              .doc(widget.sellerOrderId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text(
  l10n.orderLabel,
  style: const TextStyle(
  color: Color(0xFFFFC107),
    fontSize: 20,
    fontWeight: FontWeight.w700,
  ),
);
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;

            /// 🔥 ADD THIS HERE
            final label =
                (data['sellerOrderNumber'] ?? data['rootOrderNumber'] ?? docId)
                    .toString();

            return Text(
  l10n.orderNumberLabel(label),
  style: const TextStyle(
  color: Color(0xFFFFC107),
    fontSize: 20,
    fontWeight: FontWeight.w700,
  ),
);
          },
        ),
      ),

      /// 🔥 BODY
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("sellerOrders")
            .doc(docId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(l10n.errorOccurred(snapshot.error.toString())),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return Center(child: Text(l10n.orderNotFound));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final sellerBusinessId = (data['businessId'] ?? data['shopId'] ?? '')
              .toString();

          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

          final sellerOwnerUid =
              (data['sellerSnapshot']?['ownerUid'] ??
                      data['sellerUid'] ??
                      data['shopId'] ??
                      '')
                  .toString();

          final isSeller = currentUserId == sellerOwnerUid;
          debugPrint("🧪 sellerOwnerUid = $sellerOwnerUid");
          debugPrint("🧪 currentUserId = $currentUserId");
          debugPrint("🧪 ORDER DETAIL sellerBusinessId = $sellerBusinessId");
          debugPrint("🧪 ORDER DETAIL currentUserId = $currentUserId");
          debugPrint("🧪 ORDER DETAIL isSeller = $isSeller");

          final shipping = (data['shipping'] as Map<String, dynamic>?) ?? {};
          final items = data['items'] ?? [];
          final pricing = data['pricing'] ?? {};
          final total = pricing['grandTotal'] ?? 0;
          // 🔥 INVOICE DATA
          final invoice = (data['invoice'] as Map<String, dynamic>?) ?? {};
          final compliance =
              (data['compliance'] as Map<String, dynamic>?) ?? {};
          final deadlines = (data['deadlines'] as Map<String, dynamic>?) ?? {};
          final billing = (data['billing'] as Map<String, dynamic>?) ?? {};
          final String invoiceSystem =
              (invoice['invoiceSystem'] ?? '').toString().isNotEmpty
              ? invoice['invoiceSystem'].toString()
              : (billing['invoiceType'] == 'company' ? 'e-Fatura' : 'e-Arşiv');

          // 🔥 FIELDS
          final String invoiceStatus = (invoice['status'] ?? 'pending_upload')
              .toString();

          final String? invoiceNumber = invoice['invoiceNumber']?.toString();

          final String? invoiceDateRaw = invoice['invoiceDate']?.toString();

          final String invoiceDate =
              invoiceDateRaw != null && invoiceDateRaw.isNotEmpty
              ? invoiceDateRaw.split('T').first
              : "-";

          final String? invoicePdfUrl = invoice['pdfUrl']?.toString();

          final String? invoiceDeadline =
              deadlines['invoiceUploadDeadlineAt']?.toString() ??
              invoice['uploadDeadlineAt']?.toString();

          final int warningCount =
              (compliance['warningCount'] as num?)?.toInt() ?? 0;

          final int penaltyPoints =
              (compliance['penaltyPoints'] as num?)?.toInt() ?? 0;

          final bool invoiceLate = compliance['invoiceLate'] == true;
          final List<dynamic> invoiceRiskFlags =
              (invoice['validation']?['riskFlags'] as List<dynamic>?) ?? [];
          final status = normalizeStatus(data['status'] ?? '');
          final timeline = data['timeline'] ?? [];
          final payout = (data['payout'] as Map<String, dynamic>?) ?? {};

          final payoutStatus = (payout['status'] ?? 'payment_pending')
              .toString();

          final payoutAmount =
              payout['amount'] ?? data['financial']?['sellerNetAmount'] ?? 0;

          final payoutRef = payout['reference'];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🟢 STATUS
                _sectionCard(
                  title: l10n.status,
                  child: Text(
                    orderStatusLabel(status, l10n),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: getStatusColor(status),
                    ),
                  ),
                ),

                /// 📦 ITEMS
                _sectionCard(
                  title: l10n.itemsTitle,
                  child: Column(
                    children: List.generate(items.length, (i) {
                      final item = items[i];

                      return ListTile(
                        title: Text(item['name'] ?? ''),
                        subtitle: Text(
                          l10n.qtyLabel(item['quantity'].toString()),
                        ),
                        trailing: Text("${item['price']}"),
                      );
                    }),
                  ),
                ),

                /// 💰 TOTAL
                _sectionCard(
                  title: l10n.totalLabel,
                  child: Text(
                    "$total TRY",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                /// 🚚 SHIPPING
                _sectionCard(
                  title: l10n.shippingLabel,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// 🚚 Carrier
                      Text(
                        l10n.carrierLabel(
                          (shipping['carrier'] ?? '-').toString(),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 6),

                      /// 🔢 Tracking Number
                      Text(
                        l10n.trackingLabel(
                          (shipping['trackingNumber'] ?? '-').toString(),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),

                      const SizedBox(height: 10),

                      /// 🌐 Carrier Website (🔥 جدید)
                      if (shipping['carrier'] != null) ...[
                        const SizedBox(height: 10),

                        GestureDetector(
                          onTap: () async {
                            final url = buildCarrierWebsite(
                              shipping['carrier'],
                            );

                            if (url.isNotEmpty) {
                              await launchUrl(
                                Uri.parse(url),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.public,
                                  size: 18,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.goToCarrierWebsiteButton,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      /// 🔗 Track Button
                      if (shipping['trackingNumber'] != null &&
                          shipping['carrier'] != null) ...[
                        const SizedBox(height: 8),

                        GestureDetector(
                          onTap: () async {
                            final url = buildTrackingUrl(
                              shipping['carrier'],
                              shipping['trackingNumber'],
                            );

                            if (url.isNotEmpty) {
                              await launchUrl(
                                Uri.parse(url),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.local_shipping,
                                  size: 18,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.trackShipmentButton,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                _buildReturnSection(
                  context,
                  data,
                  isSeller,
                  currentUserId,
                  status,
                ),

                if (isSeller)
                  _sectionCard(
                    title: l10n.buyerInfoTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.buyerNameLabel(
                            (billing['contactName'] ?? '-').toString(),
                          ),
                        ),
                        Text(
                          l10n.buyerCityLabel(
                            (billing['city'] ?? '-').toString(),
                          ),
                        ),
                        Text(
                          l10n.buyerAddressLabel(
                            (billing['address'] ?? '-').toString(),
                          ),
                        ),
                        Text(
                          l10n.buyerIdentityNumberLabel(
                            (billing['identityNumber'] ?? '-').toString(),
                          ),
                        ),
                        Text(
                          l10n.invoiceTypeLabel(
                            billing['invoiceType'] == 'company'
                                ? l10n.checkoutCompanyOption
                                : l10n.checkoutIndividualOption,
                          ),
                        ),
                      ],
                    ),
                  ),

                /// 🧾 INVOICE
                if (isSeller)
                  _sectionCard(
                    title: l10n.invoiceTitle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// STATUS
                        Row(
                          children: [
                            Text(
                              "${l10n.status}: ",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              invoiceStatusLabel(invoiceStatus, l10n),
                              style: TextStyle(
                                color: invoiceStatusColor(
                                  invoiceStatus,
                                  invoiceLate,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        /// DEADLINE
                        if (invoiceDeadline != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${l10n.uploadDeadlineLabel}: ",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Expanded(
                                child: Text(
                                  formatDeadline(invoiceDeadline),
                                  style: TextStyle(
                                    color: invoiceLate
                                        ? Colors.red
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 8),

                        /// WARNING
                        Row(
                          children: [
                            Text(
                              "${l10n.warningsLabel}: ",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text("$warningCount"),
                          ],
                        ),

                        const SizedBox(height: 6),

                        /// PENALTY
                        Row(
                          children: [
                            Text(
                              "${l10n.penaltyLabel}: ",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text("$penaltyPoints"),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Text(
                              "${l10n.invoiceSystemLabel}: ",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              invoiceSystem == 'eArsiv'
                                  ? l10n.eArsivLabel
                                  : (invoiceSystem == 'eFatura'
                                        ? l10n.eFaturaLabel
                                        : invoiceSystem),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        /// INVOICE NUMBER
                        Row(
                          children: [
                            Text(
                              "${l10n.invoiceNoLabel}: ",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(invoiceNumber ?? "-"),
                          ],
                        ),

                        const SizedBox(height: 6),

                        /// INVOICE DATE
                        Row(
                          children: [
                            Text(
                              "${l10n.dateLabel}: ",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(invoiceDate),
                          ],
                        ),

                        const SizedBox(height: 14),

                        /// ACTIONS
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed:
                                    invoicePdfUrl != null &&
                                        invoicePdfUrl.isNotEmpty
                                    ? () async {
                                        try {
                                          final uri = Uri.parse(invoicePdfUrl);

                                          final canLaunch = await canLaunchUrl(
                                            uri,
                                          );

                                          if (!canLaunch) {
                                            throw Exception(
                                              "Cannot launch URL",
                                            );
                                          }

                                          await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        } catch (e) {
                                          debugPrint("❌ View PDF error: $e");

                                          if (!mounted) return;

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l10n.cannotOpenInvoiceFile,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                child: Text(
                                  invoicePdfUrl != null &&
                                          invoicePdfUrl.isNotEmpty
                                      ? l10n.viewInvoiceButton
                                      : l10n.noInvoiceLabel,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            /// UPLOAD (مرحله بعدی)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isUploadingInvoice
                                    ? null
                                    : (invoiceStatus.startsWith('uploaded')
                                          ? null
                                          : () async {
                                              setState(
                                                () =>
                                                    _isUploadingInvoice = true,
                                              );

                                              await _uploadInvoice(
                                                widget.sellerOrderId,
                                              );

                                              if (mounted) {
                                                setState(
                                                  () => _isUploadingInvoice =
                                                      false,
                                                );
                                              }
                                            }),
                                child: Text(
                                  _isUploadingInvoice
                                      ? l10n.uploadingLabel
                                      : (invoiceStatus.startsWith('uploaded')
                                            ? l10n.invoiceUploadedLabel
                                            : l10n.uploadInvoiceButton),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (invoiceRiskFlags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: invoiceRiskFlags.map<Widget>((e) {
                              return Text(
                                "• ${validationLabel(e.toString(), l10n)}",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        /// LATE WARNING
                        if (invoiceLate) ...[
                          const SizedBox(height: 10),
                          Text(
                            l10n.invoiceUploadDeadlinePassed,
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                /// 📊 TIMELINE
                _sectionCard(
                  title: l10n.timelineTitle,
                  child: buildTimeline(timeline, l10n),
                ),

                /// 💰 PAYOUT (🔥 درست شده)
                _sectionCard(
                  title: l10n.payoutTitle,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// STATUS
                      Row(
                        children: [
                          Text(
                            "${l10n.status}: ",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            payoutStatusLabel(payoutStatus, l10n),
                            style: TextStyle(
                              color: payoutStatus == "paid"
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      /// AMOUNT
                      Text(
                        l10n.amountLabel("₺$payoutAmount"),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),

                      if (payoutRef != null) ...[
                        const SizedBox(height: 6),
                        Text(l10n.referenceLabel(payoutRef.toString())),
                      ],

                      /// INFO MESSAGE
                      if (payoutStatus == "pending") ...[
                        const SizedBox(height: 10),
                        Text(
                          isSeller
                              ? l10n.paymentWillBeTransferredByPetsupo
                              : l10n.pendingPayoutLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],

                      if (payoutStatus == "payment_pending") ...[
                        const SizedBox(height: 10),
                        Text(
                          l10n.waitingForCustomerPayment,
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                /// 🧑‍💼 ACTIONS
                if (isSeller)
                  _sectionCard(
                    title: l10n.actionsTitle,
                    child: _buildSellerActions(data),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _markPayoutPaid() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('markSellerPayoutPaid');

      await callable.call({
        "sellerOrderId": widget.sellerOrderId,
        "reference": "manual-${DateTime.now().millisecondsSinceEpoch}",
      });

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.payoutMarkedAsPaid)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorOccurred(e.toString()))));
    }
  }
}
