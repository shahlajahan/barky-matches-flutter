import 'package:flutter/material.dart';

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Success")),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 80),
            SizedBox(height: 20),
            Text("Payment completed successfully ✅"),
          ],
        ),
      ),
    );
  }
}

class PaymentFailedPage extends StatelessWidget {
  const PaymentFailedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Failed")),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 80),
            SizedBox(height: 20),
            Text("Payment verification failed ❌"),
          ],
        ),
      ),
    );
  }
}

class PaymentCancelledPage extends StatelessWidget {
  const PaymentCancelledPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Cancelled")),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel, color: Colors.orange, size: 80),
            SizedBox(height: 20),
            Text("Payment was cancelled ⚠️"),
          ],
        ),
      ),
    );
  }
}