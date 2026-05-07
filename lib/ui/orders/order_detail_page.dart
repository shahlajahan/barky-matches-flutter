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

class OrderDetailPage extends StatefulWidget {
  final String sellerOrderId;

  const OrderDetailPage({
    super.key,
    required this.sellerOrderId,
  });

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

  return DateFormat('d MMMM yyyy, HH:mm', 'tr_TR')
      .format(dt.toLocal());
}

String validationLabel(String code) {
  switch (code) {
    case 'seller_tax_number_not_found':
      return 'Satıcı vergi numarası eksik';
    case 'buyer_identity_not_found':
      return 'Alıcı kimlik numarası eksik';
    case 'buyer_tax_number_not_found':
      return 'Alıcı vergi numarası eksik';
    case 'invoice_system_mismatch':
      return 'Fatura tipi uyuşmuyor';
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
  
  

  String invoiceStatusLabel(String status) {
  switch (status) {
    case 'pending_upload':
      return 'Fatura bekleniyor';
    case 'uploaded_valid':
  return 'Fatura yüklendi';
case 'uploaded_with_issues':
  return 'Kontrol gerekli';
case 'late':
  return 'Geç kaldı';
    case 'approved':
      return 'Fatura onaylandı';
    case 'rejected':
      return 'Fatura reddedildi';
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

  Future<void> _uploadInvoice(String orderId) async {
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
      throw Exception("File is empty");
    }

    if (fileBytes.length > 5 * 1024 * 1024) {
      throw Exception("File too large");
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Invoice uploaded successfully")),
    );
  } catch (e) {
    debugPrint("❌ upload error: $e");

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Upload failed: $e")),
    );
  }
}

  Widget buildTimeline(List timeline) {
    if (timeline.isEmpty) {
      return const Text("No timeline yet");
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
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.grey.shade300,
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
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
        SnackBar(content: Text("Updated to $newStatus")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
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

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
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
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildSellerActions(Map<String, dynamic> data) {
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
            child: const Text("Confirm Order"),
          ),
        ),

      if (status == "confirmed")
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => updateStatus("preparing"),
            child: const Text("Start Preparing"),
          ),
        ),

      /// ✅ SHIPPING (بدون انتخاب کارگو)
      if (status == "preparing") ...[

        /// 👇 فقط نمایش
        Text(
          "Carrier: ${carrier.isEmpty ? '-' : carrier.toUpperCase()}",
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _trackingController,
          decoration: InputDecoration(
            labelText: "Tracking Number",
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
                      showError("Carrier missing from order");
                      return;
                    }

                    if (tracking.isEmpty) {
                      showError("Enter tracking number");
                      return;
                    }

                    updateStatusWithShipping(
                      "shipped",
                      tracking,
                      carrier,
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
            ),
            child: const Text("Ship Order"),
          ),
        ),
      ],

      if (status == "shipped")
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => updateStatus("delivered"),
            child: const Text("Mark as Delivered"),
          ),
        ),
    ],
  );
}

  Future<void> updateStatusWithShipping(
    String newStatus,
    String trackingNumber,
    String carrier,
  ) async {
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Order shipped")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
Widget build(BuildContext context) {
  final docId = widget.sellerOrderId;

  return Scaffold(
    appBar: AppBar(
      title: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("sellerOrders")
.doc(widget.sellerOrderId)
.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Text("Order");
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

/// 🔥 ADD THIS HERE


          final label = (data['sellerOrderNumber'] ??
                  data['rootOrderNumber'] ??
                  docId)
              .toString();

          return Text("Order #$label");
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
          return Center(child: Text("🔥 Error: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.data!.exists) {
          return const Center(child: Text("❌ Order not found"));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

final sellerBusinessId =
    (data['businessId'] ?? data['shopId'] ?? '').toString();

final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

final sellerOwnerUid =
    (data['sellerSnapshot']?['ownerUid'] ??
     data['sellerUid'] ??
     data['shopId'] ??
     '').toString();
     

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
final compliance = (data['compliance'] as Map<String, dynamic>?) ?? {};
final deadlines = (data['deadlines'] as Map<String, dynamic>?) ?? {};
final billing = (data['billing'] as Map<String, dynamic>?) ?? {};
final String invoiceSystem =
    (invoice['invoiceSystem'] ?? '').toString().isNotEmpty
        ? invoice['invoiceSystem'].toString()
        : (billing['invoiceType'] == 'company' ? 'e-Fatura' : 'e-Arşiv');

// 🔥 FIELDS
final String invoiceStatus =
    (invoice['status'] ?? 'pending_upload').toString();

final String? invoiceNumber =
    invoice['invoiceNumber']?.toString();

final String? invoiceDateRaw =
    invoice['invoiceDate']?.toString();

final String invoiceDate =
    invoiceDateRaw != null && invoiceDateRaw.isNotEmpty
        ? invoiceDateRaw.split('T').first
        : "-";

final String? invoicePdfUrl =
    invoice['pdfUrl']?.toString();

final String? invoiceDeadline =
    deadlines['invoiceUploadDeadlineAt']?.toString() ??
    invoice['uploadDeadlineAt']?.toString();

final int warningCount =
    (compliance['warningCount'] as num?)?.toInt() ?? 0;

final int penaltyPoints =
    (compliance['penaltyPoints'] as num?)?.toInt() ?? 0;

final bool invoiceLate =
    compliance['invoiceLate'] == true;
    final List<dynamic> invoiceRiskFlags =
    (invoice['validation']?['riskFlags'] as List<dynamic>?) ?? [];
        final status = normalizeStatus(data['status'] ?? '');
        final timeline = data['timeline'] ?? [];
final payout = (data['payout'] as Map<String, dynamic>?) ?? {};

final payoutStatus = (payout['status'] ?? 'payment_pending').toString();

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
                title: "Status",
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: getStatusColor(status),
                  ),
                ),
              ),

              /// 📦 ITEMS
              _sectionCard(
                title: "Items",
                child: Column(
                  children: List.generate(items.length, (i) {
                    final item = items[i];

                    return ListTile(
                      title: Text(item['name'] ?? ''),
                      subtitle: Text("Qty: ${item['quantity']}"),
                      trailing: Text("${item['price']}"),
                    );
                  }),
                ),
              ),

              /// 💰 TOTAL
              _sectionCard(
                title: "Total",
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
  title: "Shipping",
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      
      /// 🚚 Carrier
      Text(
        "Carrier: ${shipping['carrier'] ?? '-'}",
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),

      const SizedBox(height: 6),

      /// 🔢 Tracking Number
      Text(
        "Tracking: ${shipping['trackingNumber'] ?? '-'}",
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),

      const SizedBox(height: 10),
      /// 🌐 Carrier Website (🔥 جدید)
if (shipping['carrier'] != null) ...[
  const SizedBox(height: 10),

  GestureDetector(
    onTap: () async {
      final url = buildCarrierWebsite(shipping['carrier']);

      if (url.isNotEmpty) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Row(
        children: const [
          Icon(Icons.public, size: 18, color: Colors.green),
          SizedBox(width: 8),
          Text(
            "Go to Carrier Website",
            style: TextStyle(
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: const [
          Icon(Icons.local_shipping, size: 18, color: Colors.blue),
          SizedBox(width: 8),
          Text(
            "Track Shipment",
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  ),
]
    ],
  ),
),

if (isSeller)
  _sectionCard(
    title: "Buyer Info",
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Name: ${billing['contactName'] ?? '-'}"),
        Text("City: ${billing['city'] ?? '-'}"),
        Text("Address: ${billing['address'] ?? '-'}"),
        Text("ID: ${billing['identityNumber'] ?? '-'}"),
        Text(
  "Fatura Tipi: ${billing['invoiceType'] == 'company' ? 'Kurumsal' : 'Bireysel'}",
),
      ],
    ),
  ),

/// 🧾 INVOICE
if (isSeller)
_sectionCard(
  title: "Invoice",
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      /// STATUS
      Row(
        children: [
          const Text(
            "Status: ",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            invoiceStatusLabel(invoiceStatus),
            style: TextStyle(
              color: invoiceStatusColor(invoiceStatus, invoiceLate),
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
            const Text(
              "Upload Deadline: ",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Expanded(
              child: Text(
  formatDeadline(invoiceDeadline),
  style: TextStyle(
    color: invoiceLate ? Colors.red : Colors.black87,
  ),
),
            ),
          ],
        ),

      const SizedBox(height: 8),

      /// WARNING
      Row(
        children: [
          const Text(
            "Warnings: ",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Text("$warningCount"),
        ],
      ),

      const SizedBox(height: 6),

      /// PENALTY
      Row(
        children: [
          const Text(
            "Penalty: ",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Text("$penaltyPoints"),
        ],
      ),

      const SizedBox(height: 10),

      Row(
  children: [
    const Text(
      "Invoice System: ",
      style: TextStyle(fontWeight: FontWeight.w600),
    ),
    Text(
  invoiceSystem == 'eArsiv'
      ? 'e-Arşiv'
      : (invoiceSystem == 'eFatura'
          ? 'e-Fatura'
          : invoiceSystem),
),
  ],
),

const SizedBox(height: 6),

      /// INVOICE NUMBER
      Row(
        children: [
          const Text(
            "Invoice No: ",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(invoiceNumber ?? "-"),
        ],
      ),

      const SizedBox(height: 6),

      /// INVOICE DATE
      Row(
        children: [
          const Text(
            "Date: ",
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
    onPressed: invoicePdfUrl != null && invoicePdfUrl.isNotEmpty
        ? () async {
            try {
              final uri = Uri.parse(invoicePdfUrl);

              final canLaunch = await canLaunchUrl(uri);

              if (!canLaunch) {
                throw Exception("Cannot launch URL");
              }

              await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
            } catch (e) {
              debugPrint("❌ View PDF error: $e");

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Cannot open invoice file"),
                ),
              );
            }
          }
        : null,
    child: Text(
  invoicePdfUrl != null && invoicePdfUrl.isNotEmpty
      ? "View Invoice"
      : "No Invoice",
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
                setState(() => _isUploadingInvoice = true);

                await _uploadInvoice(widget.sellerOrderId);

                if (mounted) {
                  setState(() => _isUploadingInvoice = false);
                }
              }),
    child: Text(
      _isUploadingInvoice
          ? "Uploading..."
          : (invoiceStatus.startsWith('uploaded')
              ? "Invoice Uploaded"
              : "Upload Invoice"),
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
      "• ${validationLabel(e.toString())}",
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
        const Text(
          "Invoice upload deadline passed!",
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
  title: "Timeline",
  child: buildTimeline(timeline),
),

/// 💰 PAYOUT (🔥 درست شده)
_sectionCard(
  title: "Payout",
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      /// STATUS
      Row(
        children: [
          const Text(
            "Status: ",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            payoutStatus.toUpperCase(),
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
        "Amount: ₺$payoutAmount",
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),

      if (payoutRef != null) ...[
        const SizedBox(height: 6),
        Text("Ref: $payoutRef"),
      ],

      /// INFO MESSAGE
      if (payoutStatus == "pending") ...[
        const SizedBox(height: 10),
        Text(
          isSeller
              ? "Payment will be transferred by Petsupo"
              : "Pending payout",
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],

      if (payoutStatus == "payment_pending") ...[
        const SizedBox(height: 10),
        const Text(
          "Waiting for customer payment",
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    ],
  ),
),

const SizedBox(height: 12),

/// 🧑‍💼 ACTIONS
if (isSeller)
  _sectionCard(
    title: "Actions",
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
  try {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west3',
    ).httpsCallable('markSellerPayoutPaid');

    await callable.call({
      "sellerOrderId": widget.sellerOrderId,
      "reference": "manual-${DateTime.now().millisecondsSinceEpoch}",
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payout marked as paid")),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  }
}
}