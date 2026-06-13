import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/dog.dart';
import 'package:barky_matches_fixed/dog_card.dart';
import 'package:barky_matches_fixed/ui/common/smart_media.dart';
import 'package:barky_matches_fixed/services/adoption_request_service.dart';
import 'package:barky_matches_fixed/ui/chat/chat_detail_page.dart';
import 'package:barky_matches_fixed/services/chat_service.dart';

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
    final initialRequestId = context.watch<AppState>().initialAdoptionRequestId;

    if (userId == null) {
      return const Center(child: Text("Not authenticated"));
    }

    if (initialRequestId != null && initialRequestId.isNotEmpty) {
      return _buildSelectedRequest(userId, initialRequestId);
    }

    return Container(
      color: const Color(0xFFFDF2F5),
      child: Column(
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

  Widget _buildList(String currentUid, {required String status}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('businesses')
          .where('ownerUid', isEqualTo: currentUid)
          .snapshots(),
      builder: (context, businessesSnapshot) {
        if (businessesSnapshot.hasError) {
          return Center(child: Text("Error: ${businessesSnapshot.error}"));
        }

        if (!businessesSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final ownerTargetIds = <String>{
          currentUid,
          ...businessesSnapshot.data!.docs.map((doc) => doc.id),
        }.toList();

        final requesterQuery = FirebaseFirestore.instance
            .collection('adoption_requests')
            .where('requesterId', isEqualTo: currentUid)
            .where('status', isEqualTo: status);

        final ownerQuery = FirebaseFirestore.instance
            .collection('adoption_requests')
            .where('targetOwnerId', whereIn: ownerTargetIds)
            .where('status', isEqualTo: status);

        return StreamBuilder<QuerySnapshot>(
          stream: requesterQuery.snapshots(),
          builder: (context, requesterSnapshot) {
            if (requesterSnapshot.hasError) {
              return Center(child: Text("Error: ${requesterSnapshot.error}"));
            }

            return StreamBuilder<QuerySnapshot>(
              stream: ownerQuery.snapshots(),
              builder: (context, ownerSnapshot) {
                if (ownerSnapshot.hasError) {
                  return Center(child: Text("Error: ${ownerSnapshot.error}"));
                }

                final requesterReady = requesterSnapshot.hasData;
                final ownerReady = ownerSnapshot.hasData;
                if (!requesterReady || !ownerReady) {
                  return const Center(child: CircularProgressIndicator());
                }

                final byId = <String, QueryDocumentSnapshot>{};
                for (final doc in requesterSnapshot.data!.docs) {
                  byId[doc.id] = doc;
                }
                for (final doc in ownerSnapshot.data!.docs) {
                  byId[doc.id] = doc;
                }

                final docs =
                    byId.values.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data['status'] ?? '').toString() == status;
                    }).toList()..sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aCreatedAt = aData['createdAt'];
                      final bCreatedAt = bData['createdAt'];
                      final aDate = aCreatedAt is Timestamp
                          ? aCreatedAt.toDate()
                          : DateTime.fromMillisecondsSinceEpoch(0);
                      final bDate = bCreatedAt is Timestamp
                          ? bCreatedAt.toDate()
                          : DateTime.fromMillisecondsSinceEpoch(0);
                      return bDate.compareTo(aDate);
                    });

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      status == 'pending'
                          ? "No pending requests"
                          : "No approved requests",
                      style: AppTheme.body(color: AppTheme.muted),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _buildRequestCard(
                      docs[index],
                      currentUid,
                      ownerTargetIds: ownerTargetIds.toSet(),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSelectedRequest(
  String currentUid,
  String requestId,
) {
  return Container(
    color: const Color(0xFFFDF2F5),

    child: StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('adoption_requests')
          .doc(requestId)
          .snapshots(),

      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final doc = snapshot.data!;

        if (!doc.exists || doc.data() == null) {
          return Center(
            child: Text(
              "Adoption request not found",
              style: AppTheme.body(
                color: AppTheme.muted,
              ),
            ),
          );
        }

        final data =
            doc.data() as Map<String, dynamic>;

        final targetOwnerId =
            (data['targetOwnerId'] ?? '')
                .toString();

        final targetId =
            (data['targetId'] ?? '')
                .toString();

        final ownerTargetIds = <String>{

          currentUid,

          targetOwnerId,

          targetId,

        };

        debugPrint(
          "🐾 SELECTED REQUEST OWNER IDS = "
          "$ownerTargetIds",
        );

        return ListView(
          padding: const EdgeInsets.all(16),

          children: [

            Align(
              alignment: Alignment.centerLeft,

              child: TextButton.icon(
                onPressed: () {
                  context
                      .read<AppState>()
                      .consumeInitialAdoptionRequest();
                },

                icon: const Icon(
                  Icons.arrow_back,
                ),

                label: const Text(
                  "Back to requests",
                ),
              ),
            ),

            _buildRequestCard(
              doc,

              currentUid,

              ownerTargetIds:
                  ownerTargetIds,
            ),
          ],
        );
      },
    ),
  );
}

  Widget _buildRequestCard(
    DocumentSnapshot doc,
    String currentUid, {
    required Set<String> ownerTargetIds,
  }) {
    final data = doc.data() as Map<String, dynamic>;

    final status = (data['status'] ?? 'pending').toString();
    final targetType = (data['targetType'] ?? '').toString();
    final targetId = (data['targetId'] ?? '').toString();
    final targetOwnerId = (data['targetOwnerId'] ?? '').toString();
    debugPrint(
  "🐾 INBOX DEBUG "
  "targetOwnerId=$targetOwnerId "
  "currentUid=$currentUid "
  "ownerTargetIds=$ownerTargetIds",
);
    final requesterId = (data['requesterId'] ?? '').toString();
    final openedFromOverview =

context
   .read<AppState>()
   .initialAdoptionRequestId !=
null;

final isOwnerView =

ownerTargetIds.contains(targetOwnerId) ||

ownerTargetIds.contains(targetId) ||

openedFromOverview;
    final isRequesterView = requesterId == currentUid;

    final form = (data['form'] is Map)
        ? Map<String, dynamic>.from(data['form'])
        : <String, dynamic>{};

    final isBusy = _busyRequestId == doc.id;

    final personal = Map<String, dynamic>.from(form['personalInfo'] ?? {});
    final housing = Map<String, dynamic>.from(form['housing'] ?? {});
    final exp = Map<String, dynamic>.from(form['experience'] ?? {});
    final fin = Map<String, dynamic>.from(form['financialAndCommitment'] ?? {});
    final uploads = Map<String, dynamic>.from(form['uploads'] ?? {});

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
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRequestPetHeader(
                currentUid: currentUid,
                status: status,
                targetType: targetType,
                targetId: targetId,
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
                "${housing['housingType'] ?? '-'} (${housing['ownership'] ?? '-'})",
              ),
              _whiteText(
                "Garden: ${housing['hasGarden'] == true ? 'Yes' : 'No'}",
              ),
              if (housing['hasGarden'] == true)
                _whiteText("Fence: ${housing['fenceHeightCm'] ?? '-'} cm"),

              const SizedBox(height: 14),
              Divider(color: Colors.white24),
              const SizedBox(height: 14),

              _sectionTitle("🐾 Experience"),
              _whiteText("Experience: ${exp['years'] ?? 0} years"),
              _whiteText(
                "Previous dog: ${exp['previousDog'] == true ? 'Yes' : 'No'}",
              ),
              _whiteText(
                "Other pets: ${exp['otherPets'] == true ? 'Yes' : 'No'}",
              ),

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
                "Vet expenses: ${fin['canAffordVetExpenses'] == true ? 'Yes' : 'No'}",
              ),
              _whiteText(
                "Emergency savings: ${fin['emergencySavings'] == true ? 'Yes' : 'No'}",
              ),
              _whiteText(
                "Contract agreed: ${fin['agreeToContract'] == true ? 'Yes' : 'No'}",
              ),

              const SizedBox(height: 16),

              _buildPhotoPreview(uploads),

              const SizedBox(height: 20),

              if (status == "pending" && isOwnerView)
  _buildActionButtons(
    requestId: doc.id,
    isBusy: isBusy,
    targetOwnerId: targetOwnerId,
    requesterId: requesterId,
  )
else if (status == "pending" && isRequesterView)
  _buildWaitingForOwnerMessage()
else if (status == "pending")
  _buildWaitingForOwnerMessage(),

if (isOwnerView && requesterId.isNotEmpty) ...[

  const SizedBox(
    height: 12,
  ),

  SizedBox(

    width: double.infinity,

    child: ElevatedButton.icon(

     onPressed: () async {

  final currentUser =
      FirebaseAuth.instance.currentUser;

  if (currentUser == null) {
    return;
  }

  final myUid = currentUser.uid;

  /// ============================
  /// Load requester name from users
  /// ============================

  String requesterName = "User";

  final userSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(requesterId)
      .get();

  if (userSnap.exists) {

    final userData = userSnap.data()!;

    requesterName =
        (userData['username'] ??
                userData['displayName'] ??
                userData['name'] ??
                "User")
            .toString();

    debugPrint(
      "🐾 REQUESTER USER DATA = $userData",
    );

  }

  /// ============================
  /// Current user name
  /// ============================

  /// ============================
/// Current user name
/// Prefer business name
/// ============================

String myName = "User";

final businessSnap = await FirebaseFirestore.instance
    .collection('businesses')
    .doc(myUid)
    .get();

if (businessSnap.exists) {

  final businessData = businessSnap.data()!;

  myName =
      (businessData['profile']?['displayName'] ??
       businessData['profile']?['businessName'] ??
       "User")
          .toString();

  debugPrint(
    "🐾 MY BUSINESS DATA = $businessData",
  );

} else {

  final myUserSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(myUid)
      .get();

  if (myUserSnap.exists) {

    final myData = myUserSnap.data()!;

    myName =
        (myData['username'] ??
         myData['displayName'] ??
         myData['name'] ??
         currentUser.displayName ??
         "User")
            .toString();

  } else {

    myName =
        currentUser.displayName
            ?.trim()
            .isNotEmpty ==
        true
            ? currentUser.displayName!.trim()
            : "User";
  }
}

debugPrint(
  "🐾 MY CHAT NAME = $myName",
);

  /// ============================
  /// Create / Get chat
  /// ============================

  final chatId =
      await ChatService.instance
          .getOrCreateChat(

    currentUserId: myUid,

    otherUserId: requesterId,

    currentUserName: myName,

    otherUserName: requesterName,

  );

  debugPrint(
    "🐾 CHAT ID = $chatId",
  );

  if (!context.mounted) {
    return;
  }

  Navigator.push(

    context,

    MaterialPageRoute(

      builder: (_) => ChatDetailPage(

        chatId: chatId,

        otherUserId: requesterId,

        otherUserName: requesterName,

      ),

    ),

  );

},
      icon: const Icon(
        Icons.message,
      ),

      label: const Text(
        "Message Applicant",
      ),

      style: ElevatedButton.styleFrom(

        backgroundColor:
            Colors.white,

        foregroundColor:
            const Color(
              0xFF9E1B4F,
            ),

        padding:
            const EdgeInsets.symmetric(
          vertical: 12,
        ),

        shape:
            RoundedRectangleBorder(

          borderRadius:
              BorderRadius.circular(
            14,
          ),

        ),

      ),

    ),

  ),

],
            ],
          ),
        ),
      ),
    );
  }

  Widget _whiteText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: AppTheme.body(color: Colors.white)),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(title, style: AppTheme.h3(color: Colors.white)),
    );
  }

  Widget _buildRequestPetHeader({
  required String currentUid,
  required String status,
  required String targetType,
  required String targetId,
}) {

  if (targetId.isEmpty) {

    return _buildUnknownPetHeader(
      status,
    );

  }

  return StreamBuilder<DocumentSnapshot>(

    stream:
        FirebaseFirestore.instance
            .collection(
              'adoption_pets',
            )
            .doc(
              targetId,
            )
            .snapshots(),

    builder: (
      context,
      snapshot,
    ) {

      if (
      !snapshot.hasData ||
      !snapshot.data!.exists ||
      snapshot.data!.data()==null
      ) {

        return _buildUnknownPetHeader(
          status,
        );

      }

      final pet = Map<String,dynamic>.from(
        snapshot.data!.data()
        as Map<String,dynamic>,
      );

      final petName =
      (
      pet['name'] ??
      'Unknown Pet'
      ).toString();

      final breed =
      (
      pet['breed'] ??
      ''
      ).toString();

      final image =
      (
      pet['coverImageUrl'] ??
      ''
      ).toString();

      return Row(

        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Container(
            width: 70,
            height: 70,

            decoration:
                BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                    16,
                  ),

              color:
                  Colors.white
                      .withOpacity(
                        .16,
                      ),
            ),

            clipBehavior:
                Clip.hardEdge,

            child:

            image.isNotEmpty

            ? SmartMedia(
                url: image,
                fit: BoxFit.cover,
              )

            : const Icon(
                Icons.pets,
                color: Colors.white,
              ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(

                  petName,

                  style:
                      AppTheme.h2(
                    color:
                        Colors.white,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(

                  breed,

                  style:
                      AppTheme.body(
                    color:
                        Colors.white70,
                  ),
                ),

              ],
            ),
          ),

          _buildStatusBadge(
            status,
          ),

        ],
      );
    },
  );
}

  Widget _buildUnknownPetHeader(String status) {
    return Row(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.pets, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Unknown Pet", style: AppTheme.h2(color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                "Adoption Request",
                style: AppTheme.body(color: Colors.white70),
              ),
            ],
          ),
        ),
        _buildStatusBadge(status),
      ],
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

  Widget _buildWaitingForOwnerMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "Waiting for owner response",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("✅ Done")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Failed: $e")));
    } finally {
      if (!mounted) return;
      setState(() => _busyRequestId = null);
    }
  }

  Widget _buildActionButtons({
    required String requestId,
    required bool isBusy,
    required String targetOwnerId,
    required String requesterId,
  }) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),

            onPressed: isBusy
                ? null
                : () async {
                    debugPrint("🟢 APPROVE CLICK");
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    print("APPROVE CURRENT UID = $uid");
                    print("REQUEST ID = $requestId");
                    print("REQUEST TARGET OWNER = $targetOwnerId");
                    print("REQUEST REQUESTER = $requesterId");

                    await _runSafe(requestId, () async {
                      await AdoptionRequestService.decideRequest(
                        requestId: requestId,
                        status: "approved",
                      );
                    });
                  },

            child: const Text(
              "Approve",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 0,
            ),

            onPressed: isBusy
                ? null
                : () async {
                    debugPrint("🔴 REJECT CLICK");
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    print("APPROVE CURRENT UID = $uid");
                    print("REQUEST ID = $requestId");
                    print("REQUEST TARGET OWNER = $targetOwnerId");
                    print("REQUEST REQUESTER = $requesterId");

                    await _runSafe(requestId, () async {
                      await AdoptionRequestService.decideRequest(
                        requestId: requestId,
                        status: "rejected",
                      );
                    });
                  },

            child: const Text(
              "Reject",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _docLabel(String text) {
    return Text(
      text,
      style: AppTheme.body(
        color: Colors.white,
      ).copyWith(fontWeight: FontWeight.w600),
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
            child: InteractiveViewer(child: SmartMedia(url: url)),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SmartMedia(url: url, width: 90, height: 90, fit: BoxFit.cover),
      ),
    );
  }
}
