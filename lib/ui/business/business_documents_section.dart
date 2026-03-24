import 'package:flutter/material.dart';
import '../admin/admin_section.dart';

class BusinessDocumentsSection extends StatelessWidget {
  final Map<String, dynamic> data;

  const BusinessDocumentsSection({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final legal =
        (data['legal'] as Map?)?.cast<String, dynamic>() ?? {};

    final documents =
        (legal['documents'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    if (documents.isEmpty) {
      return const SizedBox.shrink();
    }

    return AdminSection(
      title: "Legal Documents",
      icon: Icons.description_outlined,
      child: Column(
        children: documents
            .map((doc) => _DocumentCard(document: doc))
            .toList(),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> document;

  const _DocumentCard({required this.document});

  @override
  Widget build(BuildContext context) {
    final type = document['type'] ?? "unknown";
    final url = document['url'];
    final uploadedAt = document['uploadedAt'];

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

          /// Thumbnail
          GestureDetector(
            onTap: () {
              if (url != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        _FullScreenImageViewer(imageUrl: url),
                  ),
                );
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: url != null
                  ? Image.network(
                      url,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image_not_supported),
                    ),
            ),
          ),

          const SizedBox(width: 14),

          /// Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _DocumentTypeBadge(type: type),

                const SizedBox(height: 6),

                if (uploadedAt != null)
                  Text(
                    "Uploaded: ${uploadedAt.toDate()}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTypeBadge extends StatelessWidget {
  final String type;

  const _DocumentTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final label = type.replaceAll("_", " ").toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1565C0),
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            child: Image.network(imageUrl),
          ),
        ),
      ),
    );
  }
}