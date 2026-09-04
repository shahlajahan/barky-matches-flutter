import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

typedef AdminSubscriptionUpdater =
    Future<void> Function(String uid, String action);

class AdminSubscriptionDetailsPage extends StatelessWidget {
  final String subscriptionId;
  final AdminSubscriptionUpdater updateSubscription;
  final FirebaseFirestore? firestore;

  const AdminSubscriptionDetailsPage({
    super.key,
    required this.subscriptionId,
    this.updateSubscription = _defaultAdminSubscriptionUpdater,
    this.firestore,
  });

  Future<void> _updateSubscription(String action) async {
    await updateSubscription(subscriptionId, action);
  }

  @override
  Widget build(BuildContext context) {
    final stream = (firestore ?? FirebaseFirestore.instance)
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

          if (!snapshot.data!.exists) {
            return _AdminSubscriptionDetailsBody(
              userId: subscriptionId,
              plan: 'normal',
              status: 'none',
              price: 0,
              currency: null,
              updateSubscription: _updateSubscription,
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          final userId = data["userId"] ?? subscriptionId;
          final plan = data["plan"] ?? "free";
          final status = data["status"] ?? "active";

          final price = (data["price"] as num?)?.toDouble() ?? 0.0;
          final currency = data["currency"]?.toString();

          return _AdminSubscriptionDetailsBody(
            userId: userId,
            plan: plan,
            status: status,
            price: price,
            currency: currency,
            updateSubscription: _updateSubscription,
          );
        },
      ),
    );
  }
}

Future<void> _defaultAdminSubscriptionUpdater(String uid, String action) async {
  await FirebaseFunctions.instanceFor(region: 'europe-west3')
      .httpsCallable('adminUpdateSubscription')
      .call({'uid': uid, 'action': action});
}

class _AdminSubscriptionDetailsBody extends StatefulWidget {
  const _AdminSubscriptionDetailsBody({
    required this.userId,
    required this.plan,
    required this.status,
    required this.price,
    required this.currency,
    required this.updateSubscription,
  });

  final String userId;
  final String plan;
  final String status;
  final double price;
  final String? currency;
  final Future<void> Function(String action) updateSubscription;

  @override
  State<_AdminSubscriptionDetailsBody> createState() =>
      _AdminSubscriptionDetailsBodyState();
}

class _AdminSubscriptionDetailsBodyState
    extends State<_AdminSubscriptionDetailsBody> {
  bool _isMutating = false;
  String? _message;

  Future<void> _run(String action) async {
    setState(() {
      _isMutating = true;
      _message = null;
    });
    try {
      await widget.updateSubscription(action);
      if (!mounted) return;
      setState(() {
        _message = 'Subscription updated successfully';
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.code == 'permission-denied'
            ? 'Permission denied'
            : 'Subscription update failed: ${error.message ?? error.code}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'Subscription update failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan == 'free' ? 'normal' : widget.plan;
    final noSubscription = widget.status == 'none';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.userValue(widget.userId),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            noSubscription
                ? 'No subscription'
                : AppLocalizations.of(context)!.planValue(plan),
          ),
          if (!noSubscription)
            Text(AppLocalizations.of(context)!.statusValue(widget.status)),
          if (!noSubscription)
            Text(
              AppLocalizations.of(context)!.priceValue(
                widget.currency == null
                    ? '-'
                    : '${widget.price.toStringAsFixed(2)} ${widget.currency}',
              ),
            ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!),
          ],
          const SizedBox(height: 30),
          if (_isMutating) const LinearProgressIndicator(),
          if (!noSubscription) ...[
            ElevatedButton(
              onPressed: _isMutating ? null : () => _run('cancel'),
              child: Text(AppLocalizations.of(context)!.cancelSubscription),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isMutating ? null : () => _run('expire'),
              child: Text(AppLocalizations.of(context)!.expireNow),
            ),
            const SizedBox(height: 20),
          ],
          if (plan == 'normal')
            ElevatedButton(
              onPressed: _isMutating ? null : () => _run('grant_premium'),
              child: Text(AppLocalizations.of(context)!.makePremium),
            ),
          if (plan == 'normal') const SizedBox(height: 10),
          if (plan == 'normal' || plan == 'premium')
            ElevatedButton(
              onPressed: _isMutating ? null : () => _run('grant_gold'),
              child: Text(AppLocalizations.of(context)!.upgradeToPartner),
            ),
          if (plan == 'gold')
            ElevatedButton(
              onPressed: _isMutating
                  ? null
                  : () => _run('downgrade_to_premium'),
              child: Text(AppLocalizations.of(context)!.downgradeToPremium),
            ),
          if (!noSubscription) ...[
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isMutating ? null : () => _run('extend'),
              child: Text(AppLocalizations.of(context)!.extendThirtyDays),
            ),
          ],
        ],
      ),
    );
  }
}
