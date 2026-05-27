import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/vet/edit_vet_profile_page.dart';

import 'package:barky_matches_fixed/ui/business/dashboard/vet/vet_working_hours_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/add_services_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/vet_pre_visit_form_settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/client_messages/vet_client_messages_page.dart';

class VetSettingsPage extends StatefulWidget {
  final String businessId;

  const VetSettingsPage({super.key, required this.businessId});

  @override
  State<VetSettingsPage> createState() => _VetSettingsPageState();
}

class _VetSettingsPageState extends State<VetSettingsPage> {
  bool _autoApproveAppointments = false;
  bool _appointmentReminders = true;
  bool _emergencyAvailability = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .get();

      final data = doc.data();

      if (data == null) return;

      setState(() {
        _emergencyAvailability = data['emergencyAvailability'] ?? false;

        _autoApproveAppointments = data['autoApproveAppointments'] ?? false;

        _appointmentReminders = data['appointmentReminders'] ?? true;
      });

      debugPrint('✅ Vet settings loaded');
    } catch (e) {
      debugPrint('❌ Failed to load settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Clinic Settings'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderCard(
              icon: LucideIcons.settings,
              title: 'Clinic Settings',
              subtitle:
                  'Review clinic preferences, payments, and operating options',
            ),
            const SizedBox(height: 18),
            _SettingsSection(
              title: 'Clinic Profile',
              children: [
                _ActionTile(
                  icon: LucideIcons.building2,
                  title: 'Profile information',
                  subtitle: 'Clinic name, description, phone, and address',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditVetProfilePage(businessId: widget.businessId),
                      ),
                    );
                  },
                ),
                _ActionTile(
                  icon: LucideIcons.stethoscope,
                  title: 'Services and specialties',
                  subtitle: 'Manage visible veterinary services',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddServicesPage(
                          businessId: widget.businessId,
                          openedAsRoute: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Working Hours',
              children: [
                _ActionTile(
                  icon: LucideIcons.clock3,
                  title: 'Clinic hours',
                  subtitle: 'Set opening days and appointment windows',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VetWorkingHoursPage(businessId: widget.businessId),
                      ),
                    );
                  },
                ),
                _SwitchTile(
                  icon: LucideIcons.siren,
                  title: 'Emergency availability',
                  subtitle: 'Show emergency availability on your vet profile',
                  value: _emergencyAvailability,
                  onChanged: (value) async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() {
                      _emergencyAvailability = value;
                    });

                    try {
                      await FirebaseFirestore.instance
                          .collection('businesses')
                          .doc(widget.businessId)
                          .update({'emergencyAvailability': value});

                      debugPrint('🚨 Emergency availability updated: $value');
                    } catch (e) {
                      debugPrint(
                        '❌ Failed to update emergency availability: $e',
                      );

                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed to save emergency availability',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Appointment Preferences',
              children: [
                _SwitchTile(
                  icon: LucideIcons.checkCircle2,
                  title: 'Auto approve appointments',
                  subtitle:
                      'Automatically confirm eligible appointment requests',
                  value: _autoApproveAppointments,
                  onChanged: (value) {
                    setState(() {
                      _autoApproveAppointments = value;
                    });
                  },
                ),
                _ActionTile(
                  icon: LucideIcons.listChecks,
                  title: 'Pre-visit form',
                  subtitle:
                      'Request additional medical details before selected services',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VetPreVisitFormSettingsPage(
                          businessId: widget.businessId,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Notifications',
              children: [
                _SwitchTile(
                  icon: LucideIcons.bell,
                  title: 'Appointment reminders',
                  subtitle: 'Receive reminders for upcoming clinic visits',
                  value: _appointmentReminders,
                  onChanged: (value) {
                    setState(() {
                      _appointmentReminders = value;
                    });
                  },
                ),
                _ActionTile(
  icon: LucideIcons.messageCircle,
  title: 'Client messages',
  subtitle: 'Inbox, quick replies, auto messages, and emergency communication',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VetClientMessagesPage(
          businessId: widget.businessId,
        ),
      ),
    );
  },
),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Payments',
              children: [
                _ActionTile(
                  icon: LucideIcons.creditCard,
                  title: 'Payment setup',
                  subtitle: 'Review paid appointment and payout settings',
                  onTap: () => _showComingSoon(context, 'Payments'),
                ),
                _ActionTile(
                  icon: LucideIcons.receipt,
                  title: 'Invoices and receipts',
                  subtitle: 'Payment documents and transaction records',
                  onTap: () => _showComingSoon(context, 'Invoices'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsSection(
              title: 'Account',
              children: [
                _ActionTile(
                  icon: LucideIcons.shieldCheck,
                  title: 'Verification status',
                  subtitle: 'Clinic approval, documents, and safety review',
                  onTap: () => _showComingSoon(context, 'Verification'),
                ),
                _ActionTile(
                  icon: LucideIcons.helpCircle,
                  title: 'Support',
                  subtitle: 'Get help with your veterinary dashboard',
                  onTap: () => _showComingSoon(context, 'Support'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label management is not available yet')),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HeaderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.cardShadow(opacity: 0.12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.h2(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTheme.caption(
                    color: Colors.white.withValues(alpha: 0.78),
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

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(title, style: AppTheme.h2()),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTheme.cardShadow(opacity: 0.06),
          ),
          child: Column(
            children: [
              for (int index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1)
                  Divider(
                    height: 1,
                    indent: 64,
                    color: Colors.black.withValues(alpha: 0.07),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      leading: _TileIcon(icon: icon),
      title: Text(title, style: AppTheme.h3(size: 15)),
      subtitle: Text(subtitle, style: AppTheme.caption()),
      trailing: const Icon(LucideIcons.chevronRight, size: 18),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.only(left: 14, right: 10),
      secondary: _TileIcon(icon: icon),
      title: Text(title, style: AppTheme.h3(size: 15)),
      subtitle: Text(subtitle, style: AppTheme.caption()),
      value: value,
      activeThumbColor: AppTheme.accent,
      onChanged: onChanged,
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;

  const _TileIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.card.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 20, color: AppTheme.card),
    );
  }
}
