import 'package:flutter/material.dart';
import 'package:barky_matches_fixed/ui/common/smart_media.dart';

import 'adoption_pet_model.dart';

class AdoptionPetCard extends StatelessWidget {
  final AdoptionPetModel pet;

  final VoidCallback onEdit;

  final VoidCallback onDelete;

  final ValueChanged<String> onStatusChanged;

  const AdoptionPetCard({
    super.key,
    required this.pet,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  Color _statusColor(String status) {
    switch (status) {
      case AdoptionPetStatus.available:
        return Colors.green;

      case AdoptionPetStatus.reserved:
        return Colors.orange;

      case AdoptionPetStatus.adopted:
        return Colors.blue;

      case AdoptionPetStatus.paused:
        return Colors.grey;

      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case AdoptionPetStatus.available:
        return 'Available';

      case AdoptionPetStatus.reserved:
        return 'Reserved';

      case AdoptionPetStatus.adopted:
        return 'Adopted';

      case AdoptionPetStatus.paused:
        return 'Paused';

      default:
        return status;
    }
  }

  Widget _buildStatusChip() {
    final color = _statusColor(pet.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(pet.status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCover() {
    final image =
        pet.coverImageUrl ??
        (pet.gallery.isNotEmpty ? pet.gallery.first : null);

    if (image == null || image.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        child: Icon(Icons.pets, size: 52, color: Colors.grey.shade400),
      );
    }

    return SmartMedia(url: image, fit: BoxFit.cover);
  }

  Widget _buildPopupMenu(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit();
            break;

          case 'delete':
            onDelete();
            break;

          default:
            onStatusChanged(value);
        }
      },
      itemBuilder: (context) {
        return [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),

          const PopupMenuItem(value: 'delete', child: Text('Delete')),

          const PopupMenuDivider(),

          const PopupMenuItem(
            value: AdoptionPetStatus.available,
            child: Text('Set Available'),
          ),

          const PopupMenuItem(
            value: AdoptionPetStatus.reserved,
            child: Text('Set Reserved'),
          ),

          const PopupMenuItem(
            value: AdoptionPetStatus.adopted,
            child: Text('Set Adopted'),
          ),

          const PopupMenuItem(
            value: AdoptionPetStatus.paused,
            child: Text('Set Paused'),
          ),
        ];
      },
    );
  }

  String _updatedLabel() {
    final dt = pet.updatedAt;

    if (dt == null) {
      return 'Recently updated';
    }

    return '${dt.day}.${dt.month}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x12000000),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  child: SizedBox.expand(child: _buildCover()),
                ),

                Positioned(right: 10, top: 10, child: _buildPopupMenu(context)),

                Positioned(left: 12, top: 12, child: _buildStatusChip()),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pet.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(icon: Icons.pets, text: pet.species),

                    _InfoChip(icon: Icons.category_outlined, text: pet.breed),

                    _InfoChip(icon: Icons.cake_outlined, text: pet.ageLabel),

                    _InfoChip(icon: Icons.transgender, text: pet.gender),
                  ],
                ),

                if (pet.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),

                  Text(
                    pet.description,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                  ),
                ],

                const SizedBox(height: 14),

                Row(
                  children: [
                    Icon(Icons.update, size: 16, color: Colors.grey.shade600),

                    const SizedBox(width: 6),

                    Text(
                      _updatedLabel(),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;

  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF9E1B4F)),

          const SizedBox(width: 5),

          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
