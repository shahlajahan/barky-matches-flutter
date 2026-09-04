import 'package:flutter/material.dart';
import 'admin_subscription_details_page.dart';
import 'admin_subscription_repository.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

class AdminSubscriptionPage extends StatefulWidget {
  const AdminSubscriptionPage({super.key, this.repository});

  final AdminSubscriptionRepository? repository;

  @override
  State<AdminSubscriptionPage> createState() => _AdminSubscriptionPageState();
}

class _AdminSubscriptionPageState extends State<AdminSubscriptionPage> {
  final TextEditingController _searchController = TextEditingController();
  Future<List<AdminSubscriptionRecord>>? _searchFuture;

  bool get _isSearching => _searchController.text.trim().isNotEmpty;

  AdminSubscriptionRepository get _repository =>
      widget.repository ?? AdminSubscriptionRepository();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      final query = value.trim();
      _searchFuture = query.isEmpty ? null : _repository.searchUsers(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.subscriptionManagement),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    '${AppLocalizations.of(context)!.searchUserIdHint} / username / email',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(
            child: _isSearching
                ? _SearchResults(future: _searchFuture!, onTap: _openDetails)
                : _RecentUsers(
                    stream: _repository.watchRecentUsers(),
                    onTap: _openDetails,
                  ),
          ),
        ],
      ),
    );
  }

  void _openDetails(AdminSubscriptionRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminSubscriptionDetailsPage(subscriptionId: record.userId),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.future, required this.onTap});

  final Future<List<AdminSubscriptionRecord>> future;
  final ValueChanged<AdminSubscriptionRecord> onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminSubscriptionRecord>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AdminSubscriptionStateMessage(
            message: _messageForError(snapshot.error),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!;
        if (records.isEmpty) {
          return const _AdminSubscriptionStateMessage(message: 'No user found');
        }
        return _AdminSubscriptionList(records: records, onTap: onTap);
      },
    );
  }
}

class _RecentUsers extends StatelessWidget {
  const _RecentUsers({required this.stream, required this.onTap});

  final Stream<List<AdminSubscriptionRecord>> stream;
  final ValueChanged<AdminSubscriptionRecord> onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminSubscriptionRecord>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _AdminSubscriptionStateMessage(
            message: _messageForError(snapshot.error),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!;
        if (records.isEmpty) {
          return Center(
            child: Text(AppLocalizations.of(context)!.noUsersFound),
          );
        }
        return _AdminSubscriptionList(records: records, onTap: onTap);
      },
    );
  }
}

class _AdminSubscriptionList extends StatelessWidget {
  const _AdminSubscriptionList({required this.records, required this.onTap});

  final List<AdminSubscriptionRecord> records;
  final ValueChanged<AdminSubscriptionRecord> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        return ListTile(
          leading: Icon(_iconForPlan(record.plan)),
          title: Text(record.displayName),
          subtitle: Text(_subtitleFor(record)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onTap(record),
        );
      },
    );
  }
}

class _AdminSubscriptionStateMessage extends StatelessWidget {
  const _AdminSubscriptionStateMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(child: Text(message));
}

IconData _iconForPlan(String plan) {
  switch (plan) {
    case 'gold':
      return Icons.workspace_premium;
    case 'premium':
      return Icons.star;
    default:
      return Icons.person_outline;
  }
}

String _subtitleFor(AdminSubscriptionRecord record) {
  if (!record.hasSubscription) {
    return '${record.userId} • No subscription';
  }
  final currency = record.currency;
  final subscription = '${record.plan} • ${record.status}';
  if (currency == null) return '${record.userId} • $subscription';
  return '${record.userId} • $subscription • ${record.price.toStringAsFixed(2)} $currency';
}

String _messageForError(Object? error) {
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return 'Permission denied';
  }
  return 'Unable to load subscription users: $text';
}
