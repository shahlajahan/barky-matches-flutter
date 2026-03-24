import 'package:flutter/material.dart';

class AdminSection extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData? icon;
  final Color? accentColor;
  final Widget? trailing;
  final bool isLoading;

  const AdminSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.accentColor,
    this.trailing,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: accentColor != null
            ? Border.all(color: accentColor!, width: 1.2)
            : null,
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x12000000),
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// 🔷 HEADER ROW
          Row(
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 18,
                  color: accentColor ?? Colors.black87,
                ),

              if (icon != null)
                const SizedBox(width: 8),

              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (trailing != null) trailing!,
            ],
          ),

          const SizedBox(height: 14),

          /// 🔷 CONTENT
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : child,
          ),
        ],
      ),
    );
  }
}