import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin_detail_scaffold.dart';
import '../business_admin_actions.dart';

import '../../business/business_profile_section.dart';
import '../../business/business_contact_section.dart';
import '../../business/business_legal_section.dart';
import '../../business/business_trust_section.dart';
import '../../business/business_documents_section.dart';
import '../../business/business_header.dart';
import '../sections/business_audit_log_section.dart';
import '../admin_section.dart';
import 'package:barky_matches_fixed/ui/common/smart_media.dart';

class BusinessAdminDetailPage extends StatelessWidget {
  final String businessId;

  const BusinessAdminDetailPage({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection("businesses").doc(businessId).snapshots(),
      builder: (context, businessSnap) {
        if (!businessSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!businessSnap.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Business not found")),
          );
        }

        final businessData = businessSnap.data!.data() as Map<String, dynamic>;

        final status = businessData["status"] ?? "unknown";

        return FutureBuilder<QuerySnapshot>(
          future: db
              .collection("business_requests")
              .where("businessId", isEqualTo: businessId)
              .limit(1)
              .get(),
          builder: (context, requestSnap) {
            if (!requestSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            String? requestId;
            Map<String, dynamic> requestData = {};

            if (requestSnap.data!.docs.isNotEmpty) {
              requestId = requestSnap.data!.docs.first.id;
              requestData =
                  requestSnap.data!.docs.first.data() as Map<String, dynamic>;
            }

            return AdminDetailScaffold(
              header: BusinessHeader(data: businessData),
              sections: [
                BusinessProfileSection(data: businessData),
                BusinessContactSection(data: businessData),
                BusinessLegalSection(data: businessData),
                BusinessDocumentsSection(data: businessData),
                _PetTaxiDocumentsSection(requestData: requestData),
                BusinessTrustSection(
                  data: businessData,
                  businessId: businessId,
                ),
                BusinessAuditLogSection(businessId: businessId),
              ],
              bottomActions: requestId != null
                  ? BusinessAdminActions(
                      businessId: businessId,
                      requestId: requestId,
                      status: status,
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

class _PetTaxiDocumentsSection extends StatelessWidget {
  final Map<String, dynamic> requestData;

  const _PetTaxiDocumentsSection({required this.requestData});

  @override
  Widget build(BuildContext context) {
    final sectorData =
        (requestData['sectorData'] as Map?)?.cast<String, dynamic>() ?? {};
    final taxi =
        (sectorData['pet_taxi'] as Map?)?.cast<String, dynamic>() ?? {};
    final docs = (taxi['documents'] as Map?)?.cast<String, dynamic>() ?? {};
    final entries = docs.entries
        .where(
          (entry) =>
              entry.value is Map &&
              ((entry.value as Map)['url']?.toString().isNotEmpty ?? false),
        )
        .toList();

    if (entries.isEmpty) return const SizedBox.shrink();

    return AdminSection(
      title: 'Pet Taxi Compliance Documents',
      icon: Icons.local_taxi_outlined,
      child: Column(
        children: entries.map((entry) {
          final document = (entry.value as Map).cast<String, dynamic>();
          final url = document['url']?.toString() ?? '';
          final status = document['status']?.toString() ?? 'pending_review';
          final verified = document['verified'] == true;
          final number = document['documentNumber']?.toString();
          final storagePath = document['storagePath']?.toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SmartMedia(
                    url: url,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text('Status: $status'),
                      Text('Verified: ${verified ? 'yes' : 'no'}'),
                      if (number != null && number.isNotEmpty)
                        Text('Document no: $number'),
                      if (storagePath != null && storagePath.isNotEmpty)
                        Text(
                          storagePath,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _PetTaxiDocumentPreview(url: url),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PetTaxiDocumentPreview extends StatelessWidget {
  final String url;

  const _PetTaxiDocumentPreview({required this.url});

  @override
  Widget build(BuildContext context) {
    final isPdf =
        Uri.tryParse(url)?.path.toLowerCase().endsWith('.pdf') == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Pet Taxi Document')),
      backgroundColor: Colors.black,
      body: Center(
        child: isPdf
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton(
                  onPressed: () {
                    launchUrl(
                      Uri.parse(url),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: const Text('Open PDF'),
                ),
              )
            : InteractiveViewer(child: SmartMedia(url: url)),
      ),
    );
  }
}
