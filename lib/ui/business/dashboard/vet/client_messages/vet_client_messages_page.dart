import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/client_messages/vet_inbox_page.dart';
import 'package:barky_matches_fixed/ui/business/dashboard/vet/client_messages/quick_replies/vet_quick_replies_page.dart';

class VetClientMessagesPage extends StatelessWidget {
  final String businessId;

  const VetClientMessagesPage({super.key, required this.businessId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Client Messages'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MessageCard(
            icon: LucideIcons.inbox,
            title: 'Inbox',
            subtitle: 'View and reply to pet owner messages',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VetInboxPage(businessId: businessId),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _MessageCard(
            icon: LucideIcons.reply,
            title: 'Quick replies',
            subtitle: 'Manage saved responses for common questions',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VetQuickRepliesPage(businessId: businessId),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _MessageCard(
            icon: LucideIcons.bot,
            title: 'Auto messages',
            subtitle: 'Automatic reminders and follow-up messages',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _MessageCard(
            icon: LucideIcons.siren,
            title: 'Emergency messages',
            subtitle: 'Priority settings for urgent pet owner messages',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppTheme.cardShadow(opacity: 0.06),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.card.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppTheme.card),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.h3(size: 15)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTheme.caption()),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 18),
          ],
        ),
      ),
    );
  }
}
