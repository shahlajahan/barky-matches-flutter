import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:barky_matches_fixed/app_state.dart';
import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/shell/nav_tab.dart';

class AdoptionCenterDashboardOverviewTab extends StatelessWidget {
  final String businessId;

  final Map<String, dynamic> businessData;

  final VoidCallback? onOpenPets;

  final VoidCallback? onOpenRequests;

  final VoidCallback? onOpenSettings;

  const AdoptionCenterDashboardOverviewTab({
    super.key,
    required this.businessId,
    required this.businessData,
    this.onOpenPets,
    this.onOpenRequests,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(businessData['profile'] ?? {});

    final contact = Map<String, dynamic>.from(businessData['contact'] ?? {});

    debugPrint('🐾 OVERVIEW STREAM targetOwnerId=$businessId');

    final requestsStream = FirebaseFirestore.instance
        .collection('adoption_requests')
        .where('targetOwnerId', isEqualTo: businessId)
        //.orderBy('createdAt', descending: true)
        //.limit(5)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),

      children: [
        /// ================= PROFILE =================
        _SectionTitle("Adoption Center Profile"),

        const SizedBox(height: 10),

        _profileCard(context, profile, contact),

        const SizedBox(height: 20),

        /// ================= REQUESTS =================
        _SectionTitle("Recent Adoption Requests"),

        const SizedBox(height: 10),

        StreamBuilder<QuerySnapshot>(
          stream: requestsStream,

          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _emptyBox("Request error: ${snapshot.error}");
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return _emptyBox("Loading requests...");
            }

            if (!snapshot.hasData) {
              return _emptyBox("No request data");
            }

            final docs = snapshot.data!.docs.toList();

            if (docs.isEmpty) {
              return _emptyBox("No adoption requests yet");
            }

            final total = docs.length;

            final pendingCount = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;

              return data['status'] == 'pending';
            }).length;

            final approvedCount = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;

              return data['status'] == 'approved';
            }).length;

            final completedCount = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;

              return data['status'] == 'completed';
            }).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Row(
                  children: [
                    _KpiCard(
                      title: "Total",
                      value: "$total",
                      icon: LucideIcons.heartHandshake,
                    ),

                    const SizedBox(width: 10),

                    _KpiCard(
                      title: "Pending",
                      value: "$pendingCount",
                      icon: LucideIcons.clock,
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  children: [
                    _KpiCard(
                      title: "Approved",
                      value: "$approvedCount",
                      icon: LucideIcons.checkCircle,
                    ),

                    const SizedBox(width: 10),

                    _KpiCard(
                      title: "Completed",
                      value: "$completedCount",
                      icon: LucideIcons.check,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          _SectionTitle("Recent Adoption Requests"),

                          const SizedBox(height: 4),

                          Text(
                            "Latest adoption applications",

                            style: AppTheme.caption(color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),

                    TextButton(
                      onPressed: onOpenRequests,

                      child: const Text("View All"),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                if (docs.isEmpty)
                  _emptyBox("No adoption requests yet")
                else
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    return _requestItem(context, doc.id, data);
                  }),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        /// ================= QUICK ACTIONS =================
        _SectionTitle("Quick Actions"),

        const SizedBox(height: 10),

        Row(
          children: [
            _actionBtn("Add Pet", Icons.pets, onTap: onOpenPets),

            const SizedBox(width: 10),

            _actionBtn(
              "Requests",
              LucideIcons.heartHandshake,
              onTap: onOpenRequests,
            ),

            const SizedBox(width: 10),

            _actionBtn("Settings", LucideIcons.settings, onTap: onOpenSettings),
          ],
        ),
      ],
    );
  }

  Widget _requestItem(
BuildContext context,
String id,
Map<String,dynamic> data,
){

final status =
(data['status'] ?? 'pending')
.toString();

final requesterId =
(data['requesterId'] ?? '')
.toString();

final targetId =
(data['targetId'] ?? '')
.toString();

debugPrint(
'🐾 REQUEST DATA = $data',
);

debugPrint(
'🐾 REQUESTER ID = $requesterId',
);

debugPrint(
'🐾 TARGET ID = $targetId',
);

final ts = data['createdAt'];

final date =
ts is Timestamp
? ts.toDate()
: null;

final dateLabel =
date == null
? '-'
: '${date.day.toString().padLeft(2,'0')}.'
'${date.month.toString().padLeft(2,'0')}.'
'${date.year}';

return FutureBuilder<List<dynamic>>(

future: Future.wait([

FirebaseFirestore.instance
.collection('adoption_pets')
.doc(targetId)
.get(),

FirebaseFirestore.instance
.collection('users')
.doc(requesterId)
.get(),

FirebaseFirestore.instance
.collection('businesses')
.doc(requesterId)
.get(),

]),

builder:(context,snapshot){
  debugPrint(
'🐾 FUTURE HAS DATA = ${snapshot.hasData}',
);

String petName="Pet";
String breed="";
String requester="User";

if(snapshot.hasData){

final petSnap =
snapshot.data![0]
as DocumentSnapshot;

final userSnap =
snapshot.data![1]
as DocumentSnapshot;

if(
petSnap.exists &&
petSnap.data()!=null
){

final pet =
petSnap.data()
as Map<String,dynamic>;

petName =
(pet['name'] ?? 'Pet')
.toString();

breed =
(pet['breed'] ?? '')
.toString();

}

if(
userSnap.exists &&
userSnap.data()!=null
){

final userSnap =
snapshot.data![1]
as DocumentSnapshot;

final businessSnap =
snapshot.data![2]
as DocumentSnapshot;

debugPrint(
'🐾 USER EXISTS = ${userSnap.exists}',
);

debugPrint(
'🐾 BUSINESS EXISTS = ${businessSnap.exists}',
);

debugPrint(
'🐾 USER DATA = ${userSnap.data()}',
);

debugPrint(
'🐾 BUSINESS DATA = ${businessSnap.data()}',
);

if (
userSnap.exists &&
userSnap.data()!=null
) {

  final user =
      userSnap.data()
          as Map<String,dynamic>;

  requester =
      (
        user['displayName'] ??
        user['name'] ??
        user['username'] ??
        ''
      ).toString();

}

if (

(requester.isEmpty ||
 requester == 'User') &&

businessSnap.exists &&
businessSnap.data()!=null

) {

  final business =
      businessSnap.data()
          as Map<String,dynamic>;

  final profile =
      (business['profile'] as Map?)
          ?.cast<String,dynamic>() ??
      {};

  requester =
      (
        profile['displayName'] ??
        profile['businessName'] ??
        ''
      ).toString();

}

if (
requester.isEmpty
) {

  requester =
      (data['requesterName'] ?? 'User')
          .toString();

}
}

}

return GestureDetector(

onTap:(){

final appState =
context.read<AppState>();

appState
.setInitialAdoptionRequestId(id);

appState.setCurrentTab(
NavTab.profile,
);

appState.openProfileSubPage(
ProfileSubPage.adoptionInbox,
);

},

child: Container(

margin:
const EdgeInsets.only(
bottom:12,
),

decoration: BoxDecoration(

color: Colors.white,

borderRadius:
BorderRadius.circular(18),

border: Border.all(
color:
const Color(
0xFF9E1B4F,
).withOpacity(.10),
),

boxShadow:
AppTheme.cardShadow(
opacity:.06,
),

),

child: Padding(

padding:
const EdgeInsets.all(14),

child: Column(

crossAxisAlignment:
CrossAxisAlignment.start,

children:[

Row(

children:[

Container(

width:44,
height:44,

decoration:
BoxDecoration(

color:
const Color(
0xFF9E1B4F,
).withOpacity(.08),

borderRadius:
BorderRadius.circular(
12,
),

),

child: const Icon(
LucideIcons
.heartHandshake,

color:
Color(
0xFF9E1B4F,
),

),

),

const SizedBox(
width:12,
),

Expanded(

child: Column(

crossAxisAlignment:
CrossAxisAlignment
.start,

children:[

Text(

petName,

style:
AppTheme.body(
color:
AppTheme
.textDark,
).copyWith(
fontWeight:
FontWeight
.w700,
),

),

const SizedBox(
height:6,
),

Row(

children:[

_statusPill(
status,
),

const SizedBox(
width:8,
),

Expanded(

child: Text(

requester,

overflow:
TextOverflow
.ellipsis,

style:
AppTheme.caption(
color:
AppTheme
.muted,
),

),

),

],

),

const SizedBox(
height:6,
),

Text(

"$breed • $dateLabel",

style:
AppTheme.caption(
color:
AppTheme
.muted,
),

),

],

),

),

const Icon(
Icons.chevron_right,
color:
Colors.black38,
),

],

),

const SizedBox(
height:10,
),

Text(

"Tap for more details",

style:
AppTheme.caption(
color:
AppTheme.muted,
),

),

],

),

),

),

);

},

);

}

  Widget _statusPill(String status) {
    Color color;

    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        break;

      case 'completed':
        color = Colors.purple;
        break;

      case 'rejected':
        color = Colors.red;
        break;

      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

      decoration: BoxDecoration(
        color: color.withOpacity(0.12),

        borderRadius: BorderRadius.circular(999),
      ),

      child: Text(
        status.toUpperCase(),

        style: TextStyle(
          color: color,

          fontWeight: FontWeight.w700,

          fontSize: 10,
        ),
      ),
    );
  }

  Widget _profileCard(
    BuildContext context,
    Map<String, dynamic> profile,
    Map<String, dynamic> contact,
  ) {
    final name = profile['displayName'] ?? 'Adoption Center';

    final description = profile['description'] ?? "No description yet";

    return Container(
      padding: const EdgeInsets.all(16),

      decoration: _cardDecoration(),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child: Text(name, style: AppTheme.h3(weight: FontWeight.w800)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(description, style: AppTheme.body(color: AppTheme.muted)),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,

            runSpacing: 8,

            children: [
              _chip("📞 ${contact['phone'] ?? '-'}"),

              _chip("📍 ${contact['city'] ?? '-'}"),

              _chip("📍 ${contact['district'] ?? '-'}"),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,

      borderRadius: BorderRadius.circular(16),

      border: Border.all(color: Colors.black12),

      boxShadow: AppTheme.cardShadow(opacity: 0.06),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      padding: const EdgeInsets.all(14),

      decoration: _cardDecoration(),

      child: Text(text, style: AppTheme.body(color: AppTheme.muted)),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

      decoration: BoxDecoration(
        color: const Color(0xFF9E1B4F).withOpacity(0.08),

        borderRadius: BorderRadius.circular(10),
      ),

      child: Text(
        text,

        style: AppTheme.caption(color: const Color(0xFF9E1B4F)),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTheme.h2());
  }
}

class _KpiCard extends StatelessWidget {
  final String title;

  final String value;

  final IconData icon;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(color: const Color(0xFF9E1B4F).withOpacity(0.15)),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Icon(icon, size: 18, color: const Color(0xFF9E1B4F)),

            const SizedBox(height: 8),

            Text(value, style: AppTheme.h2(weight: FontWeight.w800)),

            Text(title, style: AppTheme.caption()),
          ],
        ),
      ),
    );
  }
}

class _actionBtn extends StatelessWidget {
  final String text;

  final IconData icon;

  final VoidCallback? onTap;

  const _actionBtn(this.text, this.icon, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,

        child: Container(
          padding: const EdgeInsets.all(12),

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(14),

            border: Border.all(color: Colors.black12),
          ),

          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF9E1B4F)),

              const SizedBox(height: 6),

              Text(text),
            ],
          ),
        ),
      ),
    );
  }
}
