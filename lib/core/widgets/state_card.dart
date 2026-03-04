import 'package:flutter/material.dart';
import 'package:inventory_managment_sys/core/constants/app_constants.dart';

/// Stat card used on the dashboard
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardColor = color ?? cs.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: cardColor.withOpacity(isDark ? 0.3 : 0.1),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardColor.withOpacity(0.15),
                cardColor.withOpacity(0.02),
              ],
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Container(
                     padding: const EdgeInsets.all(8),
                     decoration: BoxDecoration(
                       color: cardColor.withOpacity(0.2),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Icon(icon, color: cardColor, size: 24),
                   ),
                   Flexible(
                     child: Text(
                       value,
                       style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                         fontWeight: FontWeight.w800,
                         color: cs.onSurface,
                         letterSpacing: -0.5,
                       ),
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                ],
              ),
              const Spacer(),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
