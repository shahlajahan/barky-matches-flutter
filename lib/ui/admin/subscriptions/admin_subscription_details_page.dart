import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class AdminSubscriptionDetailsPage extends StatelessWidget {
  final String subscriptionId;

  const AdminSubscriptionDetailsPage({super.key, required this.subscriptionId});

  Future<void> _updateSubscription(Map<String, dynamic> data) async {
    final ref = FirebaseFirestore.instance
        .collection("subscriptions")
        .doc(subscriptionId);

    final doc = await ref.get();

    if (doc.exists) {
      await ref.update(data);
    } else {
      await ref.set(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection("subscriptions")
        .doc(subscriptionId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.subscriptionDetails),
      ),

      body: StreamBuilder<DocumentSnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.genericError('${snapshot.error}'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final userId = data["userId"] ?? subscriptionId;
          final plan = data["plan"] ?? "free";
          final status = data["status"] ?? "active";

          final price = (data["price"] as num?)?.toDouble() ?? 0.0;

          return Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  AppLocalizations.of(context)!.userValue(userId),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(AppLocalizations.of(context)!.planValue(plan)),
                Text(AppLocalizations.of(context)!.statusValue(status)),
                Text(
                  AppLocalizations.of(
                    context,
                  )!.priceValue('\$${price.toStringAsFixed(2)}'),
                ),

                const SizedBox(height: 30),

                /// Cancel
                ElevatedButton(
                  onPressed: () {
                    _updateSubscription({
                      "userId": userId,
                      "status": "cancelled",
                    });
                  },
                  child: Text(
                    AppLocalizations.of(context)!.cancelSubscription,
                  ),
                ),

                const SizedBox(height: 10),

                /// Expire
                ElevatedButton(
                  onPressed: () {
                    _updateSubscription({
                      "userId": userId,
                      "status": "expired",
                    });
                  },
                  child: Text(AppLocalizations.of(context)!.expireNow),
                ),

                const SizedBox(height: 20),

                /// FREE → PREMIUM
                if (plan == "free")
                  ElevatedButton(
                    onPressed: () {
                      _updateSubscription({
                        "userId": userId,
                        "plan": "premium",
                        "status": "active",
                        "price": 9.99,
                        "expiresAt": Timestamp.fromDate(
                          DateTime.now().add(const Duration(days: 30)),
                        ),
                      });
                    },
                    child: Text(AppLocalizations.of(context)!.makePremium),
                  ),

                /// PREMIUM → GOLD
                if (plan == "premium")
                  ElevatedButton(
                    onPressed: () {
                      _updateSubscription({"plan": "gold", "price": 19.99});
                    },
                    child: Text(
                      AppLocalizations.of(context)!.upgradeToPartner,
                    ),
                  ),

                /// GOLD → PREMIUM
                if (plan == "gold")
                  ElevatedButton(
                    onPressed: () {
                      _updateSubscription({"plan": "premium", "price": 9.99});
                    },
                    child: Text(
                      AppLocalizations.of(context)!.downgradeToPremium,
                    ),
                  ),

                const SizedBox(height: 10),

                /// Extend
                ElevatedButton(
                  onPressed: () {
                    _updateSubscription({
                      "expiresAt": Timestamp.fromDate(
                        DateTime.now().add(const Duration(days: 30)),
                      ),
                    });
                  },
                  child: Text(AppLocalizations.of(context)!.extendThirtyDays),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
