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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if ((action ?? trailing) != null) (action ?? trailing)!,
        ],
      ),
    );
  }
}
