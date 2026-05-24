import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

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
  final l10n = AppLocalizations.of(context)!;
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
      SnackBar(content: Text(l10n.orderStatusUpdated(orderStatusLabel(status, l10n)))),
    );
  } catch (e) {
    debugPrint("❌ ERROR: $e");

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.errorOccurred(e.toString()))),
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

String payoutLabel(String status, AppLocalizations l10n) {
  switch (status) {
    case "paid":
      return l10n.paidPayoutStatusLabel;
    case "ready":
      return l10n.readyForPayoutLabel;
    case "pending":
      return l10n.payoutPendingLabel;
    case "payment_pending":
      return l10n.waitingForPaymentLabel;
    default:
      return l10n.payoutNotSetLabel;
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

  String nextActionLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case "paid":
        return l10n.confirmOrderButton;
      case "confirmed":
        return l10n.startPreparingButton;

      // 🔥 مهم: برای preparing دیگر مستقیم ship نکن
      case "preparing":
        return l10n.openOrderButton;

      // 🔥 اگر خواستی delivered هم فقط از detail page انجام شود،
      // این case را هم حذف کن
      case "shipped":
        return l10n.openOrderButton;

      default:
        return "";
    }
  }

  String orderStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
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
      case "failed":
        return l10n.failedStatusLabel;
      default:
        return status;
    }
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
    final l10n = AppLocalizations.of(context)!;
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
    final actionLabel = nextActionLabel(status, l10n);
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
                        l10n.orderNumberLabel(
                          sellerOrderId.length > 6
                              ? sellerOrderId.substring(0, 6)
                              : sellerOrderId,
                        ),
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
                          l10n.invoiceSummaryLabel(
                            invoiceStatusLabel(invoiceStatus, l10n),
                            deadlineLabel,
                          ),
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
              payoutLabel(payoutStatus, l10n),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: payoutColor(payoutStatus),
              ),
            ),
            const SizedBox(height: 4),

            Text(
              l10n.sellerNetLabel("₺${payoutAmount.toString()}"),
              style: const TextStyle(fontSize: 12),
            ),

            if (payoutReference != null &&
                payoutReference.toString().isNotEmpty)
              Text(
                l10n.referenceLabel(payoutReference.toString()),
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
                  Text(l10n.buyerNameLabel(billingName),
                      style: const TextStyle(fontSize: 12)),
                  Text(l10n.buyerSurnameLabel(billingSurname),
                      style: const TextStyle(fontSize: 12)),
                  Text(l10n.buyerIdentityNumberLabel(billingId),
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
                    orderStatusLabel(status, l10n),
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
                    l10n.itemsCountLabel(items.length),
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
                      l10n.trackingLabel(tracking),
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
                        SnackBar(
                          content: Text(l10n.invoiceSimulatedAsUploaded),
                        ),
                      );
                    } catch (e) {
                      debugPrint("❌ Invoice simulate error: $e");

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.invoiceError(e.toString())),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(l10n.simulateUploadInvoiceButton),
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
