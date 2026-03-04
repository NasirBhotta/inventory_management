import 'package:flutter/material.dart';
import 'package:inventory_managment_sys/core/constants/app_constants.dart';

/// Section title row
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, this.trailing, this.action, required this.title});
  final String title;
  final Widget? trailing;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final trailingWidget = action ?? trailing;
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedWidth = constraints.maxWidth.isFinite;
          if (hasBoundedWidth) {
            return Row(
              children: [
                Expanded(child: titleText),
                if (trailingWidget != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailingWidget,
                ],
              ],
            );
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              titleText,
              if (trailingWidget != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailingWidget,
              ],
            ],
          );
        },
      ),
    );
  }
}
