import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'pages/business_admin_detail_page.dart';

class AdminApprovalPage extends StatelessWidget {
  const AdminApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pending Business Approvals"),
        backgroundColor: Colors.pink,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('business_requests')
              .where('status', isEqualTo: 'pending')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildError(snapshot.error.toString());
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final requestDoc = docs[index];
                final requestData =
                    requestDoc.data() as Map<String, dynamic>;

                final businessId =
                    requestData['businessId'] as String?;

                if (businessId == null) {
                  return const ListTile(
                    title: Text("Invalid request"),
                  );
                }

                return _BusinessListTile(businessId: businessId);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        "No pending business requests",
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}

class _BusinessListTile extends StatelessWidget {
  final String businessId;

  const _BusinessListTile({
    required this.businessId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .get(),
      builder: (context, businessSnap) {
        if (!businessSnap.hasData) {
          return const ListTile(
            title: Text("Loading..."),
          );
        }

        if (!businessSnap.data!.exists) {
          return const ListTile(
            title: Text("Business not found"),
          );
        }

        final businessData =
            businessSnap.data!.data() as Map<String, dynamic>;

        final profile =
            (businessData['profile'] as Map?)?.cast<String, dynamic>() ?? {};

        final contact =
            (businessData['contact'] as Map?)?.cast<String, dynamic>() ?? {};

        final trust =
            (businessData['trust'] as Map?)?.cast<String, dynamic>() ?? {};

        final verification =
            (businessData['verification'] as Map?)?.cast<String, dynamic>() ?? {};

        final displayName =
            profile['displayName'] ?? 'No Name';

        final city = contact['city'] ?? '';
        final district = contact['district'] ?? '';

        final riskFlags =
            (trust['riskFlags'] as List?)?.cast<String>() ?? [];

        final isVerified =
            verification['isVerified'] == true;

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),

          title: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (riskFlags.isNotEmpty)
                _RiskBadge(count: riskFlags.length),

              const SizedBox(width: 8),

              if (isVerified)
                _VerifiedBadge(),
            ],
          ),

          subtitle: Text(
            [district, city]
                .where((e) => e.toString().isNotEmpty)
                .join(", "),
          ),

          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey,
          ),

          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BusinessAdminDetailPage(
                  businessId: businessId,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final int count;

  const _RiskBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$count RISK",
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        "VERIFIED",
        style: TextStyle(
          color: Colors.blue,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}