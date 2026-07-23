import 'package:flutter/material.dart';

import 'package:barky_matches_fixed/theme/app_theme.dart';

class BusinessQuickActionItem {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? badge;

  const BusinessQuickActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badge,
  });
}

class BusinessQuickActionsSection extends StatelessWidget {
  final String title;
  final List<BusinessQuickActionItem> actions;
  final Color accentColor;

  const BusinessQuickActionsSection({
    super.key,
    required this.title,
    required this.actions,
    this.accentColor = AppTheme.card,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.h2()),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = switch (constraints.maxWidth) {
              < 600 => 2,
              < 1000 => 3,
              _ => 4,
            };

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: 82,
              ),
              itemBuilder: (context, index) {
                return _BusinessQuickActionCard(
                  action: actions[index],
                  accentColor: accentColor,
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _BusinessQuickActionCard extends StatefulWidget {
  final BusinessQuickActionItem action;
  final Color accentColor;

  const _BusinessQuickActionCard({
    required this.action,
    required this.accentColor,
  });

  @override
  State<_BusinessQuickActionCard> createState() =>
      _BusinessQuickActionCardState();
}

class _BusinessQuickActionCardState extends State<_BusinessQuickActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.action.onTap != null;
    final accent = widget.accentColor;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.action.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: enabled ? (_) => setState(() => _hovered = true) : null,
        onExit: enabled ? (_) => setState(() => _hovered = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: _hovered ? accent.withValues(alpha: 0.045) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered
                  ? accent.withValues(alpha: 0.32)
                  : const Color(0xFFE9E1E4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.075 : 0.04),
                blurRadius: _hovered ? 16 : 10,
                offset: Offset(0, _hovered ? 6 : 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.action.onTap,
              focusColor: accent.withValues(alpha: 0.08),
              hoverColor: Colors.transparent,
              splashColor: accent.withValues(alpha: 0.10),
              highlightColor: accent.withValues(alpha: 0.06),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      14,
                      12,
                      12,
                      12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            widget.action.icon,
                            color: accent,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.action.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.body(
                              size: 14,
                              weight: FontWeight.w600,
                              color: enabled
                                  ? AppTheme.textDark
                                  : AppTheme.muted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 19,
                          color: enabled
                              ? const Color(0xFF9B8D93)
                              : const Color(0xFFCBC3C7),
                        ),
                      ],
                    ),
                  ),
                  if (widget.action.badge case final badge?)
                    PositionedDirectional(top: 6, end: 6, child: badge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
