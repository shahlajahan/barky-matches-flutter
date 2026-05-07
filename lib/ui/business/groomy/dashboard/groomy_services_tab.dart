import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GroomyServicesTab extends StatefulWidget {
  final String businessId;
  final Map<String, dynamic> businessData;

  const GroomyServicesTab({
    super.key,
    required this.businessId,
    required this.businessData,
  });

  @override
  State<GroomyServicesTab> createState() => _GroomyServicesTabState();
}

class _GroomyServicesTabState extends State<GroomyServicesTab> {

  @override
  Widget build(BuildContext context) {

    // ✅ services از register
    final initialServices =
        widget.businessData["sectorData"]?["groomer"]?["services"] ?? [];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("groomy_services")
          .where("businessId", isEqualTo: widget.businessId)
          .snapshots(),
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        // =========================
        // 🟢 اگر هنوز price تعریف نشده
        // =========================
        if (docs.isEmpty) {

          if (initialServices.isNotEmpty) {
            return ListView(
              children: initialServices.map<Widget>((s) {
                return ListTile(
                  title: Text(s),
                  subtitle: const Text("No price yet"),
                  trailing: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () =>
                        _addServiceWithName(context, s),
                  ),
                );
              }).toList(),
            );
          }

          return Center(
            child: ElevatedButton(
              onPressed: () => _addService(context),
              child: const Text("Add First Service"),
            ),
          );
        }

        // =========================
        // 🟢 services موجود
        // =========================
        return ListView(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            return ListTile(
              title: Text(data["name"] ?? ""),
              subtitle: Text("${data["price"] ?? 0} ₺"),

              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () =>
                        _editService(context, doc.id, data),
                  ),

                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () =>
                        _deleteService(doc.id),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // =========================
  // ADD WITH NAME (از register)
  // =========================
  Future<void> _addServiceWithName(
      BuildContext context,
      String name,
      ) async {

    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(name),
          content: TextField(
            controller: priceCtrl,
            decoration: const InputDecoration(labelText: "Price"),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () async {

                await FirebaseFirestore.instance
                    .collection("groomy_services")
                    .add({
                  "businessId": widget.businessId,
                  "name": name,
                  "price": int.parse(priceCtrl.text),
                  "createdAt": FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // =========================
  // ADD MANUAL
  // =========================
  Future<void> _addService(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("New Service"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: "Price"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {

                await FirebaseFirestore.instance
                    .collection("groomy_services")
                    .add({
                  "businessId": widget.businessId,
                  "name": nameCtrl.text,
                  "price": int.parse(priceCtrl.text),
                  "createdAt": FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // =========================
  // EDIT
  // =========================
  Future<void> _editService(
      BuildContext context,
      String id,
      Map<String, dynamic> data,
      ) async {

    final priceCtrl = TextEditingController(
      text: data["price"].toString(),
    );

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(data["name"]),
          content: TextField(
            controller: priceCtrl,
            decoration: const InputDecoration(labelText: "New Price"),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () async {

                await FirebaseFirestore.instance
                    .collection("groomy_services")
                    .doc(id)
                    .update({
                  "price": int.parse(priceCtrl.text),
                });

                Navigator.pop(context);
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }

  // =========================
  // DELETE
  // =========================
  Future<void> _deleteService(String id) async {
    await FirebaseFirestore.instance
        .collection("groomy_services")
        .doc(id)
        .delete();
  }
}