// lib/admin/moderation/moderation_case_detail_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'models/moderation_case.dart';
import 'widgets/case_reports_section.dart';
import 'widgets/moderation_action_bar.dart';
import 'widgets/moderation_audit_timeline.dart';

class ModerationCaseDetailPage extends StatelessWidget {
  final ModerationCase c;

  const ModerationCaseDetailPage({
    super.key,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Moderation Case"),
        backgroundColor: Colors.pink,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [

            _caseHeader(),

            CaseReportsSection(
              targetId: c.targetId,
            ),

            ModerationActionBar(
              caseId: c.id,
              targetId: c.targetId,
              type: c.type,
            ),

            ModerationAuditTimeline(
              targetId: c.targetId,
              type: c.type,
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _caseHeader() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              "Target: ${c.type}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text("Target ID: ${c.targetId}"),

            const SizedBox(height: 10),

            Text("Reports: ${c.reportCount}"),

            const SizedBox(height: 10),

            Text("Risk Score: ${c.riskScore}"),

            const SizedBox(height: 10),

            Text("Priority: ${c.priority}"),
          ],
        ),
      ),
    );
  }
}