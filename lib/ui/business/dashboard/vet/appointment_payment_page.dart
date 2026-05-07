import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/ui/petshop/petshop_checkout_webview_page.dart';

class AppointmentPaymentPage extends StatefulWidget {
  final String appointmentId;

  const AppointmentPaymentPage({
    super.key,
    required this.appointmentId,
  });

  @override
  State<AppointmentPaymentPage> createState() =>
      _AppointmentPaymentPageState();
}

class _AppointmentPaymentPageState extends State<AppointmentPaymentPage> {
  static const Color primary = Color(0xFF9E1B4F);
  static const Color accent = Color(0xFFFFC107);
  static const Color bg = Color(0xFFFFF6F8);

  Map<String, dynamic>? appointment;
  bool loading = true;
  bool paying = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    _loadAppointment();
  }

  Future<void> _loadAppointment() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vet_appointments')
          .doc(widget.appointmentId)
          .get();

      if (!mounted) return;

      setState(() {
        appointment = snap.data();
        loading = false;
        errorText = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorText = e.toString();
      });
    }
  }

  Future<void> _startPayment() async {
    if (appointment == null || paying) return;

    setState(() => paying = true);

    try {
      debugPrint("🔥 SENDING appointmentId → ${widget.appointmentId}");

      final callable = FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable('createAppointmentOrder');

      final res = await callable.call({
        'appointmentId': widget.appointmentId,
      });

      final orderId = res.data['orderId'];
      final checkoutUrl = res.data['checkoutUrl'];

      debugPrint("💳 ORDER → $orderId");
      debugPrint("🌐 URL → $checkoutUrl");

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PetshopCheckoutWebViewPage(
            checkoutUrl: checkoutUrl,
            successUrlPrefix: "payment-success",
            cancelUrlPrefix: "payment-cancel",
            orderId: orderId,
          ),
        ),
      );

      if (result == "verify") {
        debugPrint("💳 VERIFY PAYMENT");

        final verifyCallable =
            FirebaseFunctions.instanceFor(region: 'europe-west3')
                .httpsCallable('verifyPayment');

        await verifyCallable.call({
          'orderId': orderId,
        });

        debugPrint("✅ PAYMENT VERIFIED");

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment successful")),
        );

        Navigator.pop(context, true);
      }

      if (result == "cancel") {
        debugPrint("❌ PAYMENT CANCELLED");

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment cancelled")),
        );
      }
    } catch (e) {
      debugPrint("❌ PAYMENT ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment failed: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => paying = false);
      }
    }
  }

  Future<void> _confirmAppointment() async {
    if (paying) return;

    setState(() => paying = true);

    try {
      debugPrint("🟢 CONFIRM WITHOUT PAYMENT");

      final callable = FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable('confirmAppointmentWithoutPayment');

      await callable.call({
        'appointmentId': widget.appointmentId,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Appointment confirmed")),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("❌ CONFIRM ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Confirm failed: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => paying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorText != null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _appBar(),
        body: _centerMessage(
          icon: LucideIcons.alertTriangle,
          title: "Something went wrong",
          subtitle: errorText!,
          buttonText: "Retry",
          onTap: _loadAppointment,
        ),
      );
    }

    if (appointment == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: _appBar(),
        body: _centerMessage(
          icon: LucideIcons.calendarX,
          title: "Appointment not found",
          subtitle: "This appointment may have been removed.",
          buttonText: "Go back",
          onTap: () => Navigator.pop(context),
        ),
      );
    }

    final serviceTitle =
        appointment!['serviceTitle']?.toString().trim().isNotEmpty == true
            ? appointment!['serviceTitle'].toString()
            : "Veterinary service";

    final businessName =
        appointment!['businessName']?.toString().trim().isNotEmpty == true
            ? appointment!['businessName'].toString()
            : "Vet clinic";

    final petName =
        appointment!['petName'] ?? appointment!['dogName'] ?? "Pet";
    final petType = appointment!['petType'] ?? "dog";
    final petBreed = appointment!['petBreed'] ?? "-";
    final petAge = appointment!['petAge'] ?? "-";

    final status = appointment!['status']?.toString() ?? "pending";
    final paymentStatus =
        appointment!['paymentStatus']?.toString() ?? "unpaid";

    final rawPrice = appointment!['price'];
    final double price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '') ?? 0;

    final hasPrice = price > 0;
    final isPaid = paymentStatus == "paid" ||
        status == "confirmed_paid" ||
        status == "paid";

    final ts = appointment!['scheduledAt'] ?? appointment!['scheduledDateTime'];
    final dt = ts is Timestamp ? ts.toDate() : null;
    final dateText = dt == null
        ? "Date not selected"
        : "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: bg,
      appBar: _appBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _heroCard(
                serviceTitle: serviceTitle,
                businessName: businessName,
                status: status,
                paymentStatus: paymentStatus,
                isPaid: isPaid,
              ),
              const SizedBox(height: 14),
              _sectionTitle("Appointment Details"),
              const SizedBox(height: 10),
              _infoCard(
                children: [
                  _infoRow(LucideIcons.calendarDays, "Date & Time", dateText),
                  _divider(),
                  _infoRow(LucideIcons.stethoscope, "Service", serviceTitle),
                  _divider(),
                  _infoRow(LucideIcons.building2, "Clinic", businessName),
                ],
              ),
              const SizedBox(height: 14),
              _sectionTitle("Pet Information"),
              const SizedBox(height: 10),
              _infoCard(
                children: [
                  _infoRow(Icons.pets, "Pet", "$petName • $petType"),
                  _divider(),
                  _infoRow(LucideIcons.badgeInfo, "Breed", petBreed.toString()),
                  _divider(),
                  _infoRow(LucideIcons.clock3, "Age", petAge.toString()),
                ],
              ),
              const SizedBox(height: 14),
              _sectionTitle("Payment Summary"),
              const SizedBox(height: 10),
              _paymentCard(
                hasPrice: hasPrice,
                price: price,
                isPaid: isPaid,
              ),
              const SizedBox(height: 24),
              _mainButton(
                hasPrice: hasPrice,
                isPaid: isPaid,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: primary,
      foregroundColor: Colors.white,
      centerTitle: true,
      title: Text(
        "Appointment Payment",
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
    );
  }

  Widget _heroCard({
    required String serviceTitle,
    required String businessName,
    required String status,
    required String paymentStatus,
    required bool isPaid,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primary, Color(0xFFC2185B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPaid ? LucideIcons.checkCircle2 : LucideIcons.creditCard,
            color: accent,
            size: 34,
          ),
          const SizedBox(height: 14),
          Text(
            serviceTitle,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            businessName,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                text: status.toUpperCase(),
                icon: LucideIcons.calendarCheck,
              ),
              _chip(
                text: paymentStatus.toUpperCase(),
                icon: LucideIcons.walletCards,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String text,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: Colors.black87,
      ),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Column(children: children),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentCard({
    required bool hasPrice,
    required double price,
    required bool isPaid,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPaid ? Colors.green.withOpacity(0.35) : Colors.black12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPaid ? LucideIcons.badgeCheck : LucideIcons.receipt,
            color: isPaid ? Colors.green : primary,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isPaid
                  ? "This appointment is already paid."
                  : hasPrice
                      ? "Total amount"
                      : "No online payment required",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Text(
            isPaid
                ? "PAID"
                : hasPrice
                    ? "₺${price.toStringAsFixed(2)}"
                    : "Free",
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: isPaid ? Colors.green : primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainButton({
    required bool hasPrice,
    required bool isPaid,
  }) {
    if (isPaid) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(LucideIcons.checkCircle2),
          label: Text(
            "Done",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: hasPrice ? primary : accent,
          foregroundColor: hasPrice ? Colors.white : Colors.black,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 3,
        ),
        onPressed: paying
            ? null
            : hasPrice
                ? _startPayment
                : _confirmAppointment,
        child: paying
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                hasPrice ? "Pay Now" : "Confirm Appointment",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        color: Colors.black.withOpacity(0.08),
      ),
    );
  }

  Widget _centerMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: primary),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
              onPressed: onTap,
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}