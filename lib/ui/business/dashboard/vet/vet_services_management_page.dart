import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class VetServicesManagementPage extends StatefulWidget {
  final String businessId;

  const VetServicesManagementPage({
    super.key,
    required this.businessId,
  });

  @override
  State<VetServicesManagementPage> createState() =>
      _VetServicesManagementPageState();
}

class _VetServicesManagementPageState
    extends State<VetServicesManagementPage> {
  final List<Map<String, dynamic>> _services = [
    {
      'title': 'General Checkup',
      'price': '₺1200',
      'duration': '30 min',
    },
    {
      'title': 'Vaccination',
      'price': '₺850',
      'duration': '15 min',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Services'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.card,
        child: const Icon(Icons.add),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Add service flow coming next'),
            ),
          );
        },
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Clinic Services',
              style: AppTheme.h1(),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage visible veterinary services',
              style: AppTheme.body(),
            ),
            const SizedBox(height: 20),

            ..._services.map(
              (service) => Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.cardShadow(opacity: 0.06),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppTheme.card.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        LucideIcons.stethoscope,
                        color: AppTheme.card,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service['title'],
                            style: AppTheme.h3(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${service['price']} • ${service['duration']}',
                            style: AppTheme.caption(),
                          ),
                        ],
                      ),
                    ),

                    IconButton(
                      icon: const Icon(LucideIcons.pencil),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}