import 'package:flutter/material.dart';
import 'package:inventory_managment_sys/core/constants/app_constants.dart';

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onDismiss});
  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: TextStyle(color: cs.onErrorContainer)),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, color: cs.onErrorContainer),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}

/// Confirmation dialog helper
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style:
                  destructive
                      ? FilledButton.styleFrom(backgroundColor: cs.error)
                      : null,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
  );
  return result ?? false;
}
