import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SellerOrderCard extends StatelessWidget {

  final String sellerOrderId;

  final Map<String, dynamic> data;

  final VoidCallback? onTap;



  const SellerOrderCard({

    super.key,

    required this.sellerOrderId,

    required this.data,
  this.onTap,
});

 Future<void> updateStatus(BuildContext context, String status) async {
  try {
    final callable = FirebaseFunctions.instanceFor(
      region: 'europe-west3',
    ).httpsCallable('updateSellerOrderStatusV2');

    await callable.call({
      "sellerOrderId": sellerOrderId, // ✅ اصلاح شد
      "status": status,
    });

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Updated → $status")),
    );
  } catch (e) {
    debugPrint("❌ ERROR: $e");

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  }
}

Color payoutColor(String status) {
  switch (status) {
    case "paid":
      return Colors.green;
    case "ready":
      return Colors.orange;
    case "pending":
      return Colors.amber;
    case "payment_pending":
      return Colors.grey;
    default:
      return Colors.blueGrey;
  }
}

String payoutLabel(String status) {
  switch (status) {
    case "paid":
      return "Paid";
    case "ready":
      return "Ready for payout";
    case "pending":
      return "Payout pending";
    case "payment_pending":
      return "Waiting for payment";
    default:
      return "Payout not set";
  }
}

  String normalizeStatus(String s) {
    s = s.toLowerCase();

    if (s.contains("pending")) return "pending";
    if (s.contains("paid")) return "paid";
    if (s.contains("confirmed")) return "confirmed";
    if (s.contains("preparing")) return "preparing";
    if (s.contains("shipped")) return "shipped";
    if (s.contains("delivered")) return "delivered";
    if (s.contains("fail")) return "failed";

    return s;
  }

  Color statusColor(String status) {
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
      default:
        return Colors.grey;
    }
  }

  String nextActionLabel(String status) {
    switch (status) {
      case "paid":
        return "Confirm Order";
      case "confirmed":
        return "Start Preparing";

      // 🔥 مهم: برای preparing دیگر مستقیم ship نکن
      case "preparing":
        return "Open Order";

      // 🔥 اگر خواستی delivered هم فقط از detail page انجام شود،
      // این case را هم حذف کن
      case "shipped":
        return "Open Order";

      default:
        return "";
    }
  }

  String nextActionStatus(String status) {
    switch (status) {
      case "paid":
        return "confirmed";
      case "confirmed":
        return "preparing";

      // 🔥 برای اینها دیگر status مستقیم نداریم
      case "preparing":
        return "";
      case "shipped":
        return "";

      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawStatus = data['status'] ?? 'pending';
    final status = normalizeStatus(rawStatus.toString());
    debugPrint("🔥 SELLER ORDER DATA: $data");
final invoice = data['invoice'] as Map<String, dynamic>? ?? {};
final billing = data['billing'] as Map<String, dynamic>? ?? {};

final contactName = billing['contactName'] ?? '';

final billingName = contactName.split(' ').isNotEmpty
    ? contactName.split(' ')[0]
    : '-';

final billingSurname = contactName.split(' ').length > 1
    ? contactName.split(' ')[1]
    : '-';


final billingId = billing['identityNumber'] ?? '-';
final invoiceStatus = (invoice['status'] ?? 'none').toString();

final deadlineRaw = invoice['uploadDeadlineAt'];
String deadlineLabel = "-";

if (deadlineRaw is Timestamp) {
  final d = deadlineRaw.toDate();
  deadlineLabel =
      "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
}
    final rawTotal = data['pricing']?['grandTotal'] ?? data['total'] ?? 0;
    final total = rawTotal is num
        ? rawTotal.toDouble()
        : double.tryParse(rawTotal.toString()) ?? 0;

    final items = data['items'] as List? ?? [];
    final createdAt = data['createdAt'];

    String createdLabel = "-";
    if (createdAt != null && createdAt.runtimeType.toString() == 'Timestamp') {
      final d = createdAt.toDate();
      createdLabel =
          "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
    }

    final color = statusColor(status);
    final actionLabel = nextActionLabel(status);
    final actionStatus = nextActionStatus(status);

    final shipping = data['shipping'] as Map<String, dynamic>? ?? {};
    final carrier = (shipping['carrier'] ?? '').toString().trim();
    final tracking = (shipping['trackingNumber'] ?? '').toString().trim();

           final payout = data['payout'] as Map<String, dynamic>? ?? {};
final financial = data['financial'] as Map<String, dynamic>? ?? {};

final payoutStatus = (payout['status'] ?? 'not_set').toString();

final payoutAmount =
    payout['amount'] ?? financial['sellerNetAmount'] ?? 0;

final payoutReference = payout['reference'];

    return Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: color.withOpacity(0.12)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  ),
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.package,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Order #${sellerOrderId.length > 6 ? sellerOrderId.substring(0, 6) : sellerOrderId}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        createdLabel,
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "₺${total.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            /// 🔥 INVOICE BOX (FIXED)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Invoice: $invoiceStatus • Deadline: $deadlineLabel",
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  const SizedBox(height: 12),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: payoutColor(payoutStatus).withOpacity(0.08),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: payoutColor(payoutStatus).withOpacity(0.2),
    ),
  ),
  child: Row(
    children: [
      Icon(
        Icons.account_balance_wallet_outlined,
        color: payoutColor(payoutStatus),
        size: 20,
      ),
      const SizedBox(width: 10),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              payoutLabel(payoutStatus),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: payoutColor(payoutStatus),
              ),
            ),
            const SizedBox(height: 4),

            Text(
              "Seller net: ₺${payoutAmount.toString()}",
              style: const TextStyle(fontSize: 12),
            ),

            if (payoutReference != null &&
                payoutReference.toString().isNotEmpty)
              Text(
                "Ref: $payoutReference",
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
              ),
          ],
        ),
      ),
    ],
  ),
),

                  Text("Name: $billingName",
                      style: const TextStyle(fontSize: 12)),
                  Text("Surname: $billingSurname",
                      style: const TextStyle(fontSize: 12)),
                  Text("ID: $billingId",
                      style: const TextStyle(fontSize: 12)),
                      
                ],
              ),
            ),

            const SizedBox(height: 12),

     

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    "${items.length} item${items.length == 1 ? '' : 's'}",
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),

                if (carrier.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      carrier.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),

                if (tracking.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      "Tracking: $tracking",
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),

            if (invoiceStatus == "pending_upload" ||
                invoiceStatus == "late") ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection("sellerOrders")
                          .doc(sellerOrderId)
                          .update({
                        "invoice.status": "uploaded",
                        "invoice.uploadedAt":
                            FieldValue.serverTimestamp(),
                      });

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text("Invoice simulated as uploaded"),
                        ),
                      );
                    } catch (e) {
                      debugPrint("❌ Invoice simulate error: $e");

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Invoice error: $e"),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Simulate Upload Invoice"),
                ),
              ),
            ],

            if (actionLabel.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (status == "preparing" ||
                        status == "shipped") {
                      onTap?.call();
                      return;
                    }

                    if (actionStatus.isNotEmpty) {
                      updateStatus(context, actionStatus);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  ),
);
  }
}