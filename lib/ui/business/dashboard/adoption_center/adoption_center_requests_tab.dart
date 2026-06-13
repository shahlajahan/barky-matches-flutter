import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/common/smart_media.dart';

class AdoptionCenterRequestsTab extends StatefulWidget {
  final String businessId;

  const AdoptionCenterRequestsTab({
    super.key,
    required this.businessId,
  });

  @override
  State<AdoptionCenterRequestsTab> createState() =>
      _AdoptionCenterRequestsTabState();
}

class _AdoptionCenterRequestsTabState
    extends State<AdoptionCenterRequestsTab> {
  int _tab = 0;

  String? _busyRequestId;

  final List<String> _statuses = [
    'pending',
    'approved',
    'rejected',
  ];

 @override
Widget build(BuildContext context) {
  return SafeArea(
    top: false,
    bottom: false,
    child: Column(
      children: [

        const SizedBox(height: 12),

        _buildTabs(),

        Flexible(
          child: _buildList(
            status: _statuses[_tab],
          ),
        ),

      ],
    ),
  );
}

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal:16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [

            _tabButton(
              title: "Pending",
              index: 0,
            ),

            _tabButton(
              title: "Approved",
              index: 1,
            ),

            _tabButton(
              title: "Rejected",
              index: 2,
            ),

          ],
        ),
      ),
    );
  }

  Widget _tabButton({
    required String title,
    required int index,
  }) {
    final selected = _tab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {

          setState(() {

            _tab = index;

          });

        },
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds:200,
          ),
          padding: const EdgeInsets.symmetric(
            vertical:12,
          ),
          decoration: BoxDecoration(
            color: selected
                ? Colors.pink
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              title,
              style: AppTheme.body(
                color: selected
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList({
    required String status,
  }) {

   final query =
FirebaseFirestore.instance
    .collection(
      'adoption_requests',
    )
    .where(
      'targetOwnerId',
      isEqualTo:
          widget.businessId,
    )
    .where(
      'status',
      isEqualTo: status,
    )
    .orderBy(
      'createdAt',
      descending:true,
    );

debugPrint(
  "🐾 REQUEST QUERY targetOwnerId=${widget.businessId} status=$status",
);

return StreamBuilder<QuerySnapshot>(
  stream: query.snapshots(),

  builder:(context,snapshot){

    debugPrint(
      "🐾 REQUEST ERROR = ${snapshot.error}"
    );

    debugPrint(
      "🐾 REQUEST DOC COUNT = ${snapshot.data?.docs.length}"
    );

        if(snapshot.hasError){

          return Center(
            child: Text(
              snapshot.error.toString(),
            ),
          );

        }

        if(!snapshot.hasData){

          return const Center(
            child:
                CircularProgressIndicator(),
          );

        }

        final docs =
            snapshot.data!.docs;

        if(docs.isEmpty){

          return Center(
            child: Text(
              "No requests",
              style: AppTheme.body(
                color: AppTheme.muted,
              ),
            ),
          );

        }

        return ListView.builder(

          padding:
              const EdgeInsets.all(16),

          itemCount: docs.length,

          itemBuilder:(context,index){

            final doc = docs[index];

            final data =
                doc.data()
                    as Map<String,dynamic>;

            final form =
                Map<String,dynamic>.from(
              data["form"] ?? {},
            );

            final personal =
                Map<String,dynamic>.from(
              form["personalInfo"] ?? {},
            );

            final uploads =
                Map<String,dynamic>.from(
              form["uploads"] ?? {},
            );

            final dogName =
                data["dogName"] ?? "";

            final dogPhoto =
                data["dogPhoto"];

            final requester =
                personal["fullName"]
                    ?? "Unknown";

            final busy =
                _busyRequestId ==
                    doc.id;

            return Opacity(

              opacity:
                  busy ? .5 : 1,

              child: Container(

                margin:
                    const EdgeInsets.only(
                  bottom:20,
                ),

                decoration:
                    BoxDecoration(

                  color:
                      const Color(
                    0xFF9E1B4F,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    24,
                  ),

                ),

                child: Padding(

                  padding:
                      const EdgeInsets.all(
                    20,
                  ),

                  child: Column(

                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [

                      Row(

                        children:[

                          CircleAvatar(

                            radius:30,

                            backgroundColor:
                                Colors.white,

                            child:
                                ClipOval(
                              child:
                                  dogPhoto ==
                                          null
                                      ? Icon(
                                          Icons
                                              .pets,
                                        )
                                      : SmartMedia(
                                          url:
                                              dogPhoto,
                                          width:
                                              60,
                                          height:
                                              60,
                                          fit:
                                              BoxFit.cover,
                                        ),
                            ),

                          ),

                          const SizedBox(
                            width:16,
                          ),

                          Expanded(

                            child:
                                Column(

                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children:[

                                Text(
                                  dogName,
                                  style:
                                      AppTheme.h2(
                                    color:
                                        Colors.white,
                                  ),
                                ),

                                const SizedBox(
                                  height:4,
                                ),

                                Text(
                                  requester,
                                  style:
                                      AppTheme.body(
                                    color:
                                        Colors.white70,
                                  ),
                                ),

                              ],

                            ),

                          ),

                          _statusBadge(
                            status,
                          ),

                        ],

                      ),

                      const SizedBox(
                        height:20,
                      ),

                      Text(
                        "Phone: ${personal["phone"] ?? "-"}",
                        style:
                            AppTheme.body(
                          color:
                              Colors.white,
                        ),
                      ),

                      Text(
                        "Gender: ${personal["gender"] ?? "-"}",
                        style:
                            AppTheme.body(
                          color:
                              Colors.white,
                        ),
                      ),

                      const SizedBox(
                        height:20,
                      ),

                      _documents(
                        uploads,
                      ),

                      const SizedBox(
                        height:20,
                      ),

                      if(status=="pending")

                        Row(

                          children:[

                            Expanded(

                              child:
                                  ElevatedButton(

                                onPressed:
                                    busy
                                        ? null
                                        : ()=>_updateStatus(
                                              doc.id,
                                              "approved",
                                            ),

                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.green,
                                ),

                                child:
                                    const Text(
                                  "Approve",
                                ),

                              ),

                            ),

                            const SizedBox(
                              width:12,
                            ),

                            Expanded(

                              child:
                                  ElevatedButton(

                                onPressed:
                                    busy
                                        ? null
                                        : ()=>_updateStatus(
                                              doc.id,
                                              "rejected",
                                            ),

                                style:
                                    ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.red,
                                ),

                                child:
                                    const Text(
                                  "Reject",
                                ),

                              ),

                            ),

                          ],

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

  Future<void> _updateStatus(
    String requestId,
    String status,
  ) async {

    setState(() {

      _busyRequestId =
          requestId;

    });

    try {

      await FirebaseFirestore
          .instance
          .collection(
            "adoption_requests",
          )
          .doc(
            requestId,
          )
          .update({

        "status":status,

        "updatedAt":
            FieldValue.serverTimestamp(),

      });

    } finally {

      if(mounted){

        setState(() {

          _busyRequestId =
              null;

        });

      }

    }

  }

  Widget _statusBadge(
    String status,
  ){

    Color color =
        Colors.orange;

    if(status=="approved"){
      color=Colors.green;
    }

    if(status=="rejected"){
      color=Colors.red;
    }

    return Container(

      padding:
          const EdgeInsets.symmetric(
        horizontal:10,
        vertical:4,
      ),

      decoration:
          BoxDecoration(

        color:color,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

      ),

      child: Text(

        status.toUpperCase(),

        style:
            const TextStyle(
          color:
              Colors.white,
          fontSize:11,
        ),

      ),

    );
  }

  Widget _documents(
    Map uploads,
  ){

    final housePhotos =
        uploads["housePhotos"]
            as List? ??
            [];

    if(housePhotos.isEmpty){

      return const SizedBox();

    }

    return SizedBox(

      height:90,

      child:
          ListView.builder(

        scrollDirection:
            Axis.horizontal,

        itemCount:
            housePhotos.length,

        itemBuilder:
            (context,index){

          return Padding(

            padding:
                const EdgeInsets.only(
              right:8,
            ),

            child:
                ClipRRect(

              borderRadius:
                  BorderRadius.circular(
                12,
              ),

              child:
                  SmartMedia(
                url:
                    housePhotos[index],
                width:
                    90,
                height:
                    90,
                fit:
                    BoxFit.cover,
              ),

            ),

          );

        },

      ),

    );

  }
}