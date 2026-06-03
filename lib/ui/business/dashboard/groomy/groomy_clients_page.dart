import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/chat/chat_detail_page.dart';

class GroomyClientsPage extends StatefulWidget {
  final String businessId;

  const GroomyClientsPage({super.key, required this.businessId});

  static Future<void> upsertClientFromAppointment({
    required String businessId,
    required String petId,
    required String ownerId,
    required String petName,
    required String ownerName,
    String? breed,
    String? phone,
    DateTime? appointmentDate,
  }) async {
    debugPrint(
      'UPSERT GROOMY CLIENT START '
      'businessId=$businessId petId=$petId ownerId=$ownerId',
    );

    final clientId = '${businessId}_${petId}_$ownerId';
    final ref = FirebaseFirestore.instance
        .collection('businesses')
        .doc(businessId)
        .collection('patients')
        .doc(clientId);

    final appointmentTimestamp = appointmentDate != null
        ? Timestamp.fromDate(appointmentDate)
        : FieldValue.serverTimestamp();

    await ref.set({
      'businessId': businessId,
      'clientId': clientId,
      'petId': petId,
      'ownerId': ownerId,
      'petName': petName,
      'ownerName': ownerName,
      'petBreed': breed,
      'ownerPhone': phone,
      'source': 'appointment_auto',
      'lastGroomingDate': appointmentTimestamp,
      'lastAppointmentAt': appointmentTimestamp,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('UPSERT GROOMY CLIENT FINISHED');
  }

  @override
  State<GroomyClientsPage> createState() => _GroomyClientsPageState();
}

class _GroomyClientsPageState extends State<GroomyClientsPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _petNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _clientsStream;

  String _query = '';

  @override
  void initState() {
    super.initState();
    _clientsStream = FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .collection('patients')
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _petNameController.dispose();
    _ownerNameController.dispose();
    _breedController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageContext = context;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Clients'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _query = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by pet or owner name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _clientsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load clients.',
                      style: AppTheme.body(color: AppTheme.muted),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  final data = doc.data();
                  final petName = _petName(data).toLowerCase();
                  final ownerName = _ownerName(data).toLowerCase();
                  if (_query.isEmpty) return true;
                  return petName.contains(_query) || ownerName.contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return _EmptyClientsState(onAddClient: _openAddClientSheet);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();

                    return _ClientCard(
                      petName: _petName(data),

                      breed: _breedName(data),

                      ownerName: _ownerName(data),

                      lastGroomingDate: _lastGroomingDateLabel(data),

                      onTap: () {
                        Navigator.push(
                          pageContext,
                          MaterialPageRoute(
                            builder: (_) => GroomyPatientDetailPage(
                              businessId: widget.businessId,
                              patientId: doc.id,
                              petId: _petId(data),
                              patientData: Map<String, dynamic>.from(data),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddClientSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Client'),
      ),
    );
  }

  Future<void> _openAddClientSheet() async {
    _petNameController.clear();
    _ownerNameController.clear();
    _breedController.clear();
    _phoneController.clear();
    _notesController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Add Client', style: AppTheme.h2()),
                const SizedBox(height: 16),
                TextField(
                  controller: _petNameController,
                  decoration: const InputDecoration(labelText: 'Pet Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ownerNameController,
                  decoration: const InputDecoration(labelText: 'Owner Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _breedController,
                  decoration: const InputDecoration(labelText: 'Breed'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveManualClient,
                    child: const Text('Save Client'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveManualClient() async {
    final petName = _petNameController.text.trim();
    final ownerName = _ownerNameController.text.trim();
    final breed = _breedController.text.trim();
    final phone = _phoneController.text.trim();
    final notes = _notesController.text.trim();

    if (petName.isEmpty || ownerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pet name and owner name are required')),
      );
      return;
    }

    final manualKey = _stableManualClientKey(
      petName: petName,
      ownerName: ownerName,
      phone: phone,
    );
    final patientId = '${widget.businessId}_manual_$manualKey';

    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .collection('patients')
        .doc(patientId)
        .set({
          'petName': petName,
          'ownerName': ownerName,
          'petBreed': breed,
          'ownerPhone': phone,
          'phone': phone,
          'notes': notes,
          'createdFrom': 'manual',
          'source': 'groomer_manual',
          'businessId': widget.businessId,
          'patientId': patientId,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Client saved')));
  }

  String _stableManualClientKey({
    required String petName,
    required String ownerName,
    required String phone,
  }) {
    final raw = [petName, ownerName, phone].join('_').toLowerCase().trim();
    final key = raw
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return key.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : key;
  }

  String _petName(Map<String, dynamic> data) {
    return (data['petName'] ??
            data['name'] ??
            data['dogName'] ??
            data['title'] ??
            'Unnamed Pet')
        .toString();
  }

  String _breedName(Map<String, dynamic> data) {
    return (data['breed'] ?? data['petBreed'] ?? data['animalBreed'] ?? '-')
        .toString();
  }

  String _ownerName(Map<String, dynamic> data) {
    return (data['ownerName'] ??
            data['clientName'] ??
            data['userName'] ??
            data['fullName'] ??
            data['name'] ??
            '-')
        .toString();
  }

  String? _petId(Map<String, dynamic> data) {
    final raw = data['petId'] ?? data['dogId'] ?? data['animalId'];
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String? _lastGroomingDateLabel(Map<String, dynamic> data) {
    final raw =
        data['lastGroomingDate'] ??
        data['lastGroomedAt'] ??
        data['lastVisitDate'] ??
        data['updatedAt'] ??
        data['createdAt'];
    final date = _readDate(raw);
    return date == null ? null : _formatDate(date);
  }
}

class _ClientCard extends StatelessWidget {
  final String petName;
  final String breed;
  final String ownerName;
  final String? lastGroomingDate;
  final VoidCallback onTap;

  const _ClientCard({
    required this.petName,
    required this.breed,
    required this.ownerName,
    required this.lastGroomingDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black12),
            boxShadow: AppTheme.cardShadow(opacity: 0.05),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF9E1B4F).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.scissors,
                  color: Color(0xFF9E1B4F),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      petName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyMedium().copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      breed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ownerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption(color: AppTheme.muted),
                    ),

                    if (lastGroomingDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last grooming: $lastGroomingDate',
                        style: AppTheme.caption(color: AppTheme.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyClientsState extends StatelessWidget {
  final VoidCallback onAddClient;

  const _EmptyClientsState({required this.onAddClient});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.scissors,
              size: 44,
              color: Color(0xFF9E1B4F),
            ),
            const SizedBox(height: 12),
            Text('No clients yet', style: AppTheme.h2(weight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(
              'Add your first grooming client to start tracking visits.',
              textAlign: TextAlign.center,
              style: AppTheme.body(color: AppTheme.muted),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAddClient,
              icon: const Icon(Icons.add),
              label: const Text('Add Client'),
            ),
          ],
        ),
      ),
    );
  }
}

class GroomyPatientDetailPage extends StatefulWidget {
  final String businessId;
  final String patientId;
  final String? petId;
  final Map<String, dynamic>? patientData;

  const GroomyPatientDetailPage({
    super.key,
    required this.businessId,
    required this.patientId,
    this.petId,
    this.patientData,
  });

  @override
  State<GroomyPatientDetailPage> createState() =>
      _GroomyPatientDetailPageState();
}

class _GroomyPatientDetailPageState extends State<GroomyPatientDetailPage> {
  final TextEditingController _visitTitleController = TextEditingController();
  final TextEditingController _visitPriceController = TextEditingController();
  final TextEditingController _visitNotesController = TextEditingController();
  final TextEditingController _editPetNameController = TextEditingController();
  final TextEditingController _editOwnerNameController =
      TextEditingController();
  final TextEditingController _editBreedController = TextEditingController();
  final TextEditingController _editPhoneController = TextEditingController();

  late Map<String, dynamic> _patientData;
  late final String? _resolvedPetIdForAppointments;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _appointmentStream;

  @override
  void initState() {
    super.initState();
    _patientData = Map<String, dynamic>.from(widget.patientData ?? {});
    _resolvedPetIdForAppointments = _resolvedPetId();
    _appointmentStream = FirebaseFirestore.instance
        .collection('groomy_appointments')
        .where('businessId', isEqualTo: widget.businessId)
        .where('petId', isEqualTo: _resolvedPetIdForAppointments ?? '')
        .snapshots();
  }

  @override
  void dispose() {
    _visitTitleController.dispose();
    _visitPriceController.dispose();
    _visitNotesController.dispose();
    _editPetNameController.dispose();
    _editOwnerNameController.dispose();
    _editBreedController.dispose();
    _editPhoneController.dispose();
    super.dispose();
  }

  String? _resolvedPetId() {
    final raw = _patientData['petId'] ?? _patientData['dogId'] ?? widget.petId;
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  DateTime? _appointmentDateTime(Map<String, dynamic> data) {
    final raw =
        data['statusUpdatedAt'] ??
        data['completedAt'] ??
        data['updatedAt'] ??
        data['scheduledAt'] ??
        data['scheduledDateTime'];
    return _readDate(raw);
  }

  String _dateLabel(DateTime? date) {
    return date == null ? '-' : _formatDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final petName =
        (_patientData['petName'] ?? _patientData['name'] ?? 'Client')
            .toString();
    final ownerName =
        (_patientData['ownerName'] ??
                _patientData['clientName'] ??
                _patientData['userName'] ??
                '-')
            .toString();
    final breed = (_patientData['petBreed'] ?? _patientData['breed'] ?? '-')
        .toString();
    final notes = (_patientData['notes'] ?? '').toString();
    final phone = (_patientData['ownerPhone'] ?? _patientData['phone'] ?? '-')
        .toString();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('Client Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(
              petName: petName,

              breed: breed,

              ownerName: ownerName,

              phone: phone,
            ),
            const SizedBox(height: 20),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _appointmentStream,
              builder: (context, snapshot) {
                final completedDocs = _completedDocs(snapshot);
                final totalVisits = completedDocs.length;
                num totalSpent = 0;
                DateTime? latestVisit;

                for (final doc in completedDocs) {
                  final data = doc.data();
                  final price = data['price'];
                  if (price is num) {
                    totalSpent += price;
                  }

                  final date = _appointmentDateTime(data);
                  if (date != null &&
                      (latestVisit == null || date.isAfter(latestVisit))) {
                    latestVisit = date;
                  }
                }

                final history = _buildHistorySection(snapshot, completedDocs);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _statCard('Visits', totalVisits.toString()),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard(
                            'Spent',
                            '₺${totalSpent.toStringAsFixed(0)}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _statCard('Last', _dateLabel(latestVisit)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _quickAction(
                            Icons.calendar_today,
                            'Schedule',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Open appointment booking from business page',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _quickAction(
                            Icons.add,
                            'Visit',
                            onTap: _openAddVisitSheet,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _quickAction(
                            Icons.message,
                            'Message',
                            onTap: _openMessage,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _quickAction(
                            Icons.edit,
                            'Edit',
                            onTap: _openEditClientSheet,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Text('Grooming History', style: AppTheme.h2()),
                    const SizedBox(height: 12),
                    history,
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            Text('Notes', style: AppTheme.h2()),
            const SizedBox(height: 12),
            _messageCard(notes.trim().isEmpty ? 'No notes' : notes),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _completedDocs(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  ) {
    final docs = snapshot.data?.docs ?? [];
    return docs.where((doc) {
      final status = (doc.data()['status'] ?? '').toString().toLowerCase();
      return status == 'completed';
    }).toList();
  }

  Widget _buildHistorySection(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> completedDocs,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return _messageCard('Could not load grooming visits.');
    }

    final sortedDocs = [...completedDocs]
      ..sort((a, b) {
        final aDate =
            _appointmentDateTime(a.data()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            _appointmentDateTime(b.data()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    if (sortedDocs.isEmpty) {
      return _messageCard('No grooming visits yet');
    }

    return Column(
      children: sortedDocs.map((doc) {
        final data = doc.data();
        final title =
            data['title'] ??
            data['serviceTitle'] ??
            data['serviceName'] ??
            'Visit';
        final price = data['price'] ?? data['servicePrice'];
        final formattedDate = _dateLabel(_appointmentDateTime(data));

        return _VisitHistoryCard(
          title: title.toString(),
          price: price,
          date: formattedDate,
        );
      }).toList(),
    );
  }

  Future<void> _openMessage() async {
    final ownerId = _patientData['ownerId']?.toString().trim();

    if (ownerId == null || ownerId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Owner not found')));
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in required')));
      return;
    }

    final ownerName = (_patientData['ownerName'] ?? 'Client').toString();
    final ids = [currentUser.uid, ownerId]..sort();
    final chatId = ids.join('_');
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final existing = await chatRef.get();

    if (!existing.exists) {
      await chatRef.set({
        'chatId': chatId,
        'participants': ids,
        'participantIds': ids,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
      });
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          chatId: chatId,
          otherUserId: ownerId,
          otherUserName: ownerName,
        ),
      ),
    );
  }

  Future<void> _openAddVisitSheet() async {
    _visitTitleController.clear();
    _visitPriceController.clear();
    _visitNotesController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 18,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Add Grooming Visit', style: AppTheme.h2()),
                const SizedBox(height: 16),
                TextField(
                  controller: _visitTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Service / Visit Title',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _visitPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Price'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _visitNotesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _saveVisit(context),
                    child: const Text('Save Visit'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveVisit(BuildContext sheetContext) async {
    final title = _visitTitleController.text.trim().isEmpty
        ? 'Grooming Visit'
        : _visitTitleController.text.trim();
    final price = num.tryParse(_visitPriceController.text.trim());
    final notes = _visitNotesController.text.trim();
    final now = FieldValue.serverTimestamp();
    final petId = widget.petId ?? _resolvedPetId() ?? '';

    await FirebaseFirestore.instance.collection('groomy_appointments').add({
      'appointmentType': 'grooming',
      'title': title,
      'serviceName': title,
      'serviceTitle': title,
      'price': price,
      'servicePrice': price,
      'notes': notes,
      'scheduledAt': now,
      'statusUpdatedAt': now,
      'completedAt': now,
      'status': 'completed',
      'businessId': widget.businessId,
      'patientId': widget.patientId,
      'petId': petId,
      'createdAt': now,
      'updatedAt': now,
    });

    await FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .collection('patients')
        .doc(widget.patientId)
        .set({
          'lastGroomingDate': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    if (!mounted || !sheetContext.mounted) return;

    Navigator.of(sheetContext).pop();
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Visit saved')));
  }

  Future<void> _openEditClientSheet() async {
    _editPetNameController.text = (_patientData['petName'] ?? '').toString();
    _editOwnerNameController.text = (_patientData['ownerName'] ?? '')
        .toString();
    _editBreedController.text =
        (_patientData['petBreed'] ?? _patientData['breed'] ?? '').toString();
    _editPhoneController.text =
        (_patientData['ownerPhone'] ?? _patientData['phone'] ?? '').toString();

    final result = await showModalBottomSheet<_ClientEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 18,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Edit Client', style: AppTheme.h2()),
                const SizedBox(height: 16),
                TextField(
                  controller: _editPetNameController,
                  decoration: const InputDecoration(labelText: 'Pet Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _editOwnerNameController,
                  decoration: const InputDecoration(labelText: 'Owner Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _editBreedController,
                  decoration: const InputDecoration(labelText: 'Breed'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _editPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final petName = _editPetNameController.text.trim();
                      final ownerName = _editOwnerNameController.text.trim();
                      final breed = _editBreedController.text.trim();
                      final phone = _editPhoneController.text.trim();
                      final result = _ClientEditResult(
                        petName: petName,
                        ownerName: ownerName,
                        breed: breed,
                        phone: phone,
                      );

                      await FirebaseFirestore.instance
                          .collection('businesses')
                          .doc(widget.businessId)
                          .collection('patients')
                          .doc(widget.patientId)
                          .set({
                            'petName': petName,
                            'ownerName': ownerName,
                            'petBreed': breed,
                            'ownerPhone': phone,
                            'phone': phone,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                      if (!sheetContext.mounted) return;

                      Navigator.of(sheetContext).pop(result);
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _patientData = {
        ..._patientData,
        'petName': result.petName,
        'ownerName': result.ownerName,
        'petBreed': result.breed,
        'ownerPhone': result.phone,
        'phone': result.phone,
      };
    });
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(value, style: AppTheme.h2()),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [Icon(icon), const SizedBox(height: 6), Text(text)],
        ),
      ),
    );
  }

  Widget _messageCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, style: AppTheme.body(color: AppTheme.muted)),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String petName;

  final String breed;

  final String ownerName;

  final String phone;

  const _HeaderCard({
    required this.petName,

    required this.breed,

    required this.ownerName,

    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(24),

        boxShadow: AppTheme.cardShadow(),
      ),

      child: Column(
        children: [
          Container(
            width: 90,

            height: 90,

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              color: const Color(0xFF9E1B4F).withValues(alpha: .10),
            ),

            child: const Icon(
              LucideIcons.scissors,

              size: 42,

              color: Color(0xFF9E1B4F),
            ),
          ),

          const SizedBox(height: 16),

          Text(petName, style: AppTheme.h1()),

          const SizedBox(height: 6),

          Text(breed, style: AppTheme.body(color: AppTheme.muted)),

          const SizedBox(height: 10),

          Text(ownerName, style: AppTheme.body(color: AppTheme.muted)),

          const SizedBox(height: 8),

          Text(phone, style: AppTheme.body(color: AppTheme.muted)),
        ],
      ),
    );
  }
}

class _ClientEditResult {
  final String petName;
  final String ownerName;
  final String breed;
  final String phone;

  const _ClientEditResult({
    required this.petName,
    required this.ownerName,
    required this.breed,
    required this.phone,
  });
}

class _VisitHistoryCard extends StatelessWidget {
  final String title;
  final Object? price;
  final String date;

  const _VisitHistoryCard({
    required this.title,
    required this.price,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.h2()),
                const SizedBox(height: 6),
                Text(price != null ? '₺$price' : '-'),
                const SizedBox(height: 4),
                Text(date, style: AppTheme.body(color: AppTheme.muted)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

DateTime? _readDate(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}
