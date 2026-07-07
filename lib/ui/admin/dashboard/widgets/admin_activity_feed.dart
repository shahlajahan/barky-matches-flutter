import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminActivityFeed extends StatelessWidget {
  const AdminActivityFeed({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("📜 AdminActivityFeed BUILD");

    final stream = FirebaseFirestore.instance
        .collection("admin_logs")
        .orderBy("createdAt", descending: true)
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        debugPrint("📡 AdminActivity snapshot:");
        debugPrint("hasData: ${snapshot.hasData}");
        debugPrint("hasError: ${snapshot.hasError}");
        debugPrint("connectionState: ${snapshot.connectionState}");

        /// ERROR
        if (snapshot.hasError) {
          debugPrint("❌ AdminActivity ERROR → ${snapshot.error}");

          return Center(
            child: Text(
              "Activity error:\n${snapshot.error}",
              textAlign: TextAlign.center,
            ),
          );
        }

        /// LOADING
        if (!snapshot.hasData) {
          debugPrint("⏳ waiting for admin logs...");

          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        debugPrint("✅ Admin logs loaded: ${docs.length}");

        /// EMPTY
        if (docs.isEmpty) {
          return const Center(child: Text("No admin activity yet"));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final item = _AdminActivityItem.fromMap(data);
            final presentation = _AdminActivityPresentation.fromItem(item);

            debugPrint("📌 activity → ${item.action} / ${item.entityType}");

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: presentation.color.withValues(alpha: 0.12),
                child: Icon(presentation.icon, color: presentation.color),
              ),
              title: Text(
                presentation.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final detail in presentation.details)
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                ],
              ),
              trailing: item.createdAt == null
                  ? null
                  : Text(
                      _formatActivityTime(item.createdAt!),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
            );
          },
        );
      },
    );
  }

  static String _formatActivityTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (!difference.isNegative && difference < const Duration(hours: 24)) {
      if (difference.inMinutes < 1) {
        return 'Just now';
      }

      if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      }

      return '${difference.inHours}h ago';
    }

    return DateFormat("MMM d • HH:mm").format(time);
  }
}

class _AdminActivityItem {
  const _AdminActivityItem({
    required this.action,
    required this.entityType,
    required this.metadata,
    this.createdAt,
    this.businessName,
    this.appointmentNumber,
  });

  factory _AdminActivityItem.fromMap(Map<String, dynamic> data) {
    final metadata = _mapValue(data['metadata']);

    return _AdminActivityItem(
      action: _stringValue(
        data['action'] ?? data['type'] ?? data['event'],
      ).ifEmpty('activity'),
      entityType: _stringValue(data['entityType'] ?? data['targetType']),
      metadata: metadata,
      createdAt: _dateValue(data['createdAt']),
      businessName: _firstNonEmptyString([
        data['businessName'],
        data['businessTitle'],
        _mapValue(data['business'])['name'],
        _mapValue(data['business'])['title'],
        metadata['businessName'],
        metadata['businessTitle'],
      ]),
      appointmentNumber: _firstNonEmptyString([
        data['appointmentNumber'],
        data['appointmentNo'],
        data['appointmentCode'],
        data['bookingNumber'],
        metadata['appointmentNumber'],
        metadata['appointmentNo'],
        metadata['appointmentCode'],
        metadata['bookingNumber'],
      ]),
    );
  }

  final String action;
  final String entityType;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final String? businessName;
  final String? appointmentNumber;
}

class _AdminActivityPresentation {
  const _AdminActivityPresentation({
    required this.title,
    required this.icon,
    required this.color,
    required this.details,
  });

  factory _AdminActivityPresentation.fromItem(_AdminActivityItem item) {
    return _AdminActivityPresentation(
      title: _titleFor(item.action, item.entityType),
      icon: _iconFor(item.action),
      color: _colorFor(item.action),
      details: _detailsFor(item),
    );
  }

  final String title;
  final IconData icon;
  final Color color;
  final List<String> details;

  static String _titleFor(String action, String entityType) {
    switch (action) {
      case 'developer_tools_permission_test':
        return 'Developer tools permission';
      case 'approved':
        return entityType == 'business' ? 'Business approved' : 'Approved';
      case 'rejected':
        return entityType == 'business' ? 'Business rejected' : 'Rejected';
      case 'business_suspend':
      case 'suspended':
        return 'Business suspended';
      case 'business_restore':
      case 'restored':
        return 'Business restored';
      case 'vet_refund_approved':
        return 'Vet refund approved';
      case 'vet_refund_rejected':
        return 'Vet refund rejected';
      case 'vet_refund_approve_failed':
        return 'Vet refund approval failed';
      case 'case_reviewed':
        return 'Moderation case reviewed';
      case 'report':
        return 'Content reported';
      case 'fraud_flag':
        return 'Fraud alert';
      default:
        return _humanizeAction(action);
    }
  }

  static IconData _iconFor(String action) {
    if (_isFailure(action)) return Icons.error_outline;

    switch (action) {
      case 'developer_tools_permission_test':
        return Icons.developer_mode;
      case 'approved':
      case 'vet_refund_approved':
        return Icons.check_circle_outline;
      case 'rejected':
      case 'vet_refund_rejected':
        return Icons.cancel_outlined;
      case 'business_suspend':
      case 'suspended':
        return Icons.block;
      case 'business_restore':
      case 'restored':
        return Icons.restore;
      case 'case_reviewed':
        return Icons.gavel_outlined;
      case 'report':
        return Icons.flag_outlined;
      case 'fraud_flag':
        return Icons.warning_amber_outlined;
      default:
        return Icons.history;
    }
  }

  static Color _colorFor(String action) {
    if (_isFailure(action)) return Colors.red;

    switch (action) {
      case 'developer_tools_permission_test':
        return Colors.indigo;
      case 'approved':
      case 'vet_refund_approved':
        return Colors.green;
      case 'rejected':
      case 'vet_refund_rejected':
        return Colors.red;
      case 'business_suspend':
      case 'suspended':
        return Colors.deepOrange;
      case 'business_restore':
      case 'restored':
        return Colors.blue;
      case 'case_reviewed':
        return Colors.purple;
      case 'report':
      case 'fraud_flag':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  static List<String> _detailsFor(_AdminActivityItem item) {
    final details = <String>[];

    if (item.businessName?.isNotEmpty == true) {
      details.add(item.businessName!);
    }

    if (item.appointmentNumber?.isNotEmpty == true) {
      details.add('Appointment ${item.appointmentNumber}');
    }

    return details;
  }

  static bool _isFailure(String action) {
    return action.endsWith('_failed') || action.endsWith('_failure');
  }

  static String _humanizeAction(String action) {
    final normalized = action.trim();
    if (normalized.isEmpty) {
      return 'Activity';
    }

    final words = normalized
        .split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) {
      return 'Activity';
    }

    final label = words.join(' ');
    return label[0].toUpperCase() + label.substring(1);
  }
}

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }

  return <String, dynamic>{};
}

DateTime? _dateValue(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  return null;
}

String _stringValue(Object? value) {
  return value?.toString().trim() ?? '';
}

String? _firstNonEmptyString(List<Object?> values) {
  for (final value in values) {
    final stringValue = _stringValue(value);
    if (stringValue.isNotEmpty) {
      return stringValue;
    }
  }

  return null;
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
