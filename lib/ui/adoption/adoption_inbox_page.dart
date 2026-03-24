import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../services/adoption_request_service.dart';
import '../../app_state.dart';

class AdoptionInboxPage extends StatefulWidget {
  const AdoptionInboxPage({super.key});

  @override
  State<AdoptionInboxPage> createState() => _AdoptionInboxPageState();
}

class _AdoptionInboxPageState extends State<AdoptionInboxPage> {
  int _tab = 0; // 0=pending, 1=approved
  String? _busyRequestId;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text("Not authenticated")),
      );
    }
print("🔥 ADOPTION INBOX BUILD for user=$userId");
    return Scaffold(
      appBar: AppBar(
        title: const Text("Adoption Requests"),
        backgroundColor: Colors.pink[400],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.read<AppState>().closeProfileSubPage();
          },
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildTabs(),
          Expanded(
            child: _tab == 0
                ? _buildList(userId, status: 'pending')
                : _buildList(userId, status: 'approved'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _tab == 0 ? Colors.pink : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      "Pending",
                      style: AppTheme.body(
                        color: _tab == 0 ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _tab == 1 ? Colors.pink : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      "Approved",
                      style: AppTheme.body(
                        color: _tab == 1 ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String ownerId, {required String status}) {
    final query = FirebaseFirestore.instance
        .collection('adoption_requests')
        .where('targetOwnerId', isEqualTo: ownerId)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true);
print("📡 ADOPTION QUERY owner=$ownerId status=$status");
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {

        print("🧪 SNAPSHOT state="
      "${snapshot.connectionState} "
      "hasData=${snapshot.hasData} "
      "docs=${snapshot.data?.docs.length}");

      if (snapshot.hasError) {
  print("❌ ADOPTION ERROR: ${snapshot.error}");
  return Center(child: Text("Error: ${snapshot.error}"));
}
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Text(
              status == 'pending' ? "No pending requests" : "No approved requests",
              style: AppTheme.body(color: AppTheme.muted),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = (doc.data() as Map<String, dynamic>);

            // ✅ Schema صحیح: targetId == dogId (برای dog request)
            final targetType = (data['targetType'] ?? '').toString(); // "dog" | "center"
            final targetId = (data['targetId'] ?? '').toString();
            final dogName = (data['dogName'] ?? '').toString();

            final form = (data['form'] is Map)
                ? Map<String, dynamic>.from(data['form'])
                : <String, dynamic>{};

            final isBusy = _busyRequestId == doc.id;

            // فقط درخواست‌های dog در این UI
            final isDogRequest = targetType == 'dog';

            final personal =
    Map<String, dynamic>.from(form['personalInfo'] ?? {});
final housing =
    Map<String, dynamic>.from(form['housing'] ?? {});
final exp =
    Map<String, dynamic>.from(form['experience'] ?? {});
final fin =
    Map<String, dynamic>.from(form['financialAndCommitment'] ?? {});
final uploads =
    Map<String, dynamic>.from(form['uploads'] ?? {});

            return Opacity(
  opacity: isBusy ? 0.6 : 1,
  child: Container(
    margin: const EdgeInsets.only(bottom: 18),
    decoration: BoxDecoration(
      color: const Color(0xFF9E1B4F),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.15),
          blurRadius: 12,
          offset: const Offset(0, 6),
        )
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // 🔹 HEADER
          Row(
            children: [
              Expanded(
                child: Text(
                  dogName.isEmpty ? "Adoption Request" : dogName,
                  style: AppTheme.h2(color: Colors.white),
                ),
              ),
              _buildStatusBadge(status),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white24),
          const SizedBox(height: 16),

          _sectionTitle("👤 Personal"),
          _whiteText("Name: ${personal['fullName'] ?? '-'}"),
          _whiteText("Gender: ${personal['gender'] ?? '-'}"),
          _whiteText("Phone: ${personal['phone'] ?? '-'}"),
          _whiteText("Income: ${personal['monthlyIncomeRange'] ?? '-'}"),

          const SizedBox(height: 14),
          Divider(color: Colors.white24),
          const SizedBox(height: 14),

          _sectionTitle("🏠 Housing"),
          _whiteText(
              "${housing['housingType'] ?? '-'} (${housing['ownership'] ?? '-'})"),
          _whiteText(
              "Garden: ${housing['hasGarden'] == true ? 'Yes' : 'No'}"),
          if (housing['hasGarden'] == true)
            _whiteText("Fence: ${housing['fenceHeightCm'] ?? '-'} cm"),

          const SizedBox(height: 14),
          Divider(color: Colors.white24),
          const SizedBox(height: 14),

          _sectionTitle("🐾 Experience"),
          _whiteText("Experience: ${exp['years'] ?? 0} years"),
          _whiteText(
              "Previous dog: ${exp['previousDog'] == true ? 'Yes' : 'No'}"),
          _whiteText(
              "Other pets: ${exp['otherPets'] == true ? 'Yes' : 'No'}"),

          const SizedBox(height: 10),

          _sectionTitle("💬 Motivation"),
          Text(
            (exp['motivationMessage'] ?? '-').toString(),
            style: AppTheme.body(color: Colors.white70),
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.white24),
          const SizedBox(height: 14),

          _sectionTitle("💰 Financial"),
          _whiteText(
              "Vet expenses: ${fin['canAffordVetExpenses'] == true ? 'Yes' : 'No'}"),
          _whiteText(
              "Emergency savings: ${fin['emergencySavings'] == true ? 'Yes' : 'No'}"),
          _whiteText(
              "Contract agreed: ${fin['agreeToContract'] == true ? 'Yes' : 'No'}"),

          const SizedBox(height: 16),

          _buildPhotoPreview(uploads),

          const SizedBox(height: 20),

          _buildActionButtons(
            status,
            isDogRequest,
            targetId,
            doc.id,
            isBusy,
          ),
        ],
      ),
    ),
  ),
);
          },
        );
      },
    );
  }

Widget _whiteText(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: AppTheme.body(color: Colors.white),
    ),
  );
}

Widget _sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: AppTheme.h3(color: Colors.white),
    ),
  );
}

Widget _buildStatusBadge(String status) {
  Color color = Colors.orange;

  if (status == 'approved') color = Colors.green;
  if (status == 'rejected') color = Colors.red;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status.toUpperCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget _buildPhotoPreview(Map<String, dynamic> uploads) {
  final housePhotos = (uploads['housePhotos'] as List?) ?? [];
  final idPhoto = uploads['idPhoto'];
  final proof = uploads['proofOfIncome'];

  if (housePhotos.isEmpty && idPhoto == null && proof == null) {
    return const SizedBox();
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      _sectionTitle("📎 Documents"),
      const SizedBox(height: 10),

      // 🏠 House Photos
      if (housePhotos.isNotEmpty) ...[
        _docLabel("🏡 House Photos"),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: housePhotos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              return _imageThumb(housePhotos[i]);
            },
          ),
        ),
        const SizedBox(height: 14),
      ],

      // 🪪 ID Card
      if (idPhoto != null) ...[
        _docLabel("🪪 ID Card"),
        const SizedBox(height: 8),
        _imageThumb(idPhoto),
        const SizedBox(height: 14),
      ],

      // 💰 Proof of Income
      if (proof != null) ...[
        _docLabel("💰 Proof of Income"),
        const SizedBox(height: 8),
        _imageThumb(proof),
      ],
    ],
  );
}



  Future<void> _runSafe(String requestId, Future<void> Function() fn) async {
    if (!mounted) return;
    setState(() => _busyRequestId = requestId);
    try {
      await fn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Done")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Failed: $e")),
      );
    } finally {
      if (!mounted) return;
      setState(() => _busyRequestId = null);
    }
  }

  Widget _buildActionButtons(
  String status,
  bool isDogRequest,
  String targetId,
  String requestId,
  bool isBusy,
) {
  if (status == 'pending') {
    return Row(
      children: [
        Expanded(
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.green,
      foregroundColor: Colors.white, // ✅ مهم
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      elevation: 0,
    ),
    onPressed: isBusy ? null : () async {},
    child: const Text(
      "Approve",
      style: TextStyle(
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
),
        const SizedBox(width: 12),
        Expanded(
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white, // ✅ مهم
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      elevation: 0,
    ),
    onPressed: isBusy ? null : () async {},
    child: const Text(
      "Reject",
      style: TextStyle(
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
),
      ],
    );
  }

  return const SizedBox();
}

Widget _docLabel(String text) {
  return Text(
    text,
    style: AppTheme.body(
      color: Colors.white,
    ).copyWith(
      fontWeight: FontWeight.w600,
    ),
  );
}

Widget _imageThumb(String url) {
  return GestureDetector(
    onTap: () {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(
            child: Image.network(url),
          ),
        ),
      );
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 90,
        height: 90,
        fit: BoxFit.cover,
      ),
    ),
  );
}
}