import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VetDashboardServicesTab extends StatelessWidget {
  final String businessId;

  const VetDashboardServicesTab({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header (Responsive)
        LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 420;

            if (isTight) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Services & Pricing',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showEditServiceSheet(context, businessId: businessId);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Service'),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                const Expanded(
                  child: Text(
                    'Services & Pricing',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _showEditServiceSheet(context, businessId: businessId);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Service'),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 18),

        // لیست خدمات - بخش اصلاح‌شده
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('businesses')
                .doc(businessId)
                .collection('services')
                .orderBy('sortOrder')
                .snapshots(),
            builder: (context, snapshot) {
              debugPrint("🔥 SERVICES SNAPSHOT CALLED");
              if (snapshot.hasError) {
                debugPrint("❌ FIRESTORE ERROR: ${snapshot.error}");
              }
              debugPrint("📦 Docs count: ${snapshot.data?.docs.length}");
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No services yet.'));
              }

              final docs = snapshot.data!.docs;

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] ?? 'Untitled',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${data['price'] ?? 0} ${data['currency'] ?? 'TRY'} • ${data['durationMin'] ?? 0} min',
                          ),
                          if ((data['description'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(data['description']),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                                onPressed: () {
                                  _showEditServiceSheet(
                                    context,
                                    businessId: businessId,
                                    serviceId: doc.id,
                                    initialData: data,
                                  );
                                },
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Delete'),
                                onPressed: () async {
                                  await doc.reference.delete();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditServiceSheet(
    BuildContext context, {
    required String businessId,
    String? serviceId,
    Map<String, dynamic>? initialData,
  }) {
    final titleController = TextEditingController(
      text: initialData?['title'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: initialData?['description'] ?? '',
    );
    final priceController = TextEditingController(
      text: initialData?['price'] != null
          ? initialData!['price'].toString()
          : '',
    );
    final durationController = TextEditingController(
      text: initialData?['durationMin'] != null
          ? initialData!['durationMin'].toString()
          : '',
    );
    bool isFeatured = initialData?['isFeatured'] == true;
    bool isActive = initialData?['isActive'] != false;
    bool requiresDeposit = initialData?['requiresDeposit'] == true;
    final depositController = TextEditingController(
      text: '${initialData?['depositAmount'] ?? ''}',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceId == null ? 'Add Service' : 'Edit Service',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Service title',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Price'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration (min)',
                      ),
                    ),
                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: requiresDeposit,
                      onChanged: (value) {
                        setModalState(() {
                          requiresDeposit = value;
                        });
                      },
                      title: const Text('Require deposit'),
                    ),

                    if (requiresDeposit) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: depositController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Deposit amount (₺)',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isFeatured,
                      onChanged: (value) {
                        setModalState(() {
                          isFeatured = value;
                        });
                      },
                      title: const Text('Featured'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isActive,
                      onChanged: (value) {
                        setModalState(() {
                          isActive = value;
                        });
                      },
                      title: const Text('Active'),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          FocusManager.instance.primaryFocus?.unfocus();
                          debugPrint("🔥 SAVE CLICKED");

                          try {
                            final title = titleController.text.trim();

                            if (title.isEmpty) {
                              debugPrint("❌ TITLE EMPTY");
                              return;
                            }

                            final priceText = priceController.text.trim();

                            double? price;
                            if (priceText.isNotEmpty) {
                              price = double.tryParse(
                                priceText.replaceAll(',', '.'),
                              );
                            }

                            final duration =
                                int.tryParse(durationController.text.trim()) ??
                                0;
                            final depositAmount = double.tryParse(
                              depositController.text.trim().replaceAll(
                                ',',
                                '.',
                              ),
                            );

                            final payload = {
                              'title': title,
                              'price': price,
                              'currency': 'TRY',
                              'durationMin': duration,
                              'description': descriptionController.text.trim(),
                              'isActive': isActive,
                              'isFeatured': isFeatured,
                              'requiresDeposit': requiresDeposit,
                              'depositAmount': requiresDeposit
                                  ? depositAmount
                                  : null,
                              'sortOrder':
                                  initialData?['sortOrder'] ??
                                  DateTime.now().millisecondsSinceEpoch,
                              if (serviceId == null)
                                'createdAt': FieldValue.serverTimestamp(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            };

                            debugPrint("📦 PAYLOAD: $payload");

                            final ref = FirebaseFirestore.instance
                                .collection('businesses')
                                .doc(businessId)
                                .collection('services');

                            final docId =
                                serviceId ??
                                title.toLowerCase().replaceAll(' ', '_');

                            await ref
                                .doc(docId)
                                .set(payload, SetOptions(merge: true));

                            debugPrint("✅ SAVE DONE");

                            if (sheetContext.mounted) {
                              FocusManager.instance.primaryFocus?.unfocus();

                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (Navigator.canPop(sheetContext)) {
                                  Navigator.of(sheetContext).pop();
                                }
                              });
                            }
                          } catch (e) {
                            debugPrint("❌ SAVE ERROR: $e");
                          }
                        },
                        child: Text(
                          serviceId == null ? 'Create Service' : 'Save Changes',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
      titleController.dispose();
      descriptionController.dispose();
      priceController.dispose();
      durationController.dispose();
      depositController.dispose();
    });
  }
}
