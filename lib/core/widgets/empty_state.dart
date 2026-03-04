import 'package:flutter/material.dart';
import 'package:inventory_managment_sys/core/constants/app_constants.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon});
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? Icons.inbox_outlined,
            size: 56,
            color: cs.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
