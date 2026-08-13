import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin_detail_scaffold.dart';
import '../business_admin_actions.dart';
import '../pet_taxi_admin_review_panel.dart';

import '../../business/business_profile_section.dart';
import '../../business/business_contact_section.dart';
import '../../business/business_legal_section.dart';
import '../../business/business_trust_section.dart';
import '../../business/business_documents_section.dart';
import '../../business/business_header.dart';
import '../sections/business_audit_log_section.dart';
import 'package:barky_matches_fixed/l10n/app_localizations.dart';

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
          return Scaffold(
            body: Center(
              child: Text(AppLocalizations.of(context)!.businessNotFound),
            ),
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
            if (requestSnap.data!.docs.isNotEmpty) {
              requestId = requestSnap.data!.docs.first.id;
            }

            return AdminDetailScaffold(
              header: BusinessHeader(data: businessData),
              sections: [
                BusinessProfileSection(data: businessData),
                BusinessContactSection(data: businessData),
                BusinessLegalSection(data: businessData),
                BusinessDocumentsSection(data: businessData),
                if ((businessData['sectors'] as List?)?.contains('pet_taxi') ==
                    true)
                  PetTaxiAdminReviewPanel(
                    businessId: businessId,
                    businessData: businessData,
                  ),
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
