import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip.success(this.label, {super.key})
    : color = null,
      isSuccess = true;
  const StatusChip.warning(this.label, {super.key})
    : color = null,
      isSuccess = false;
  const StatusChip({super.key, required this.label, this.color})
    : isSuccess = true;

  final String label;
  final Color? color;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = color ?? (isSuccess ? cs.primaryContainer : cs.errorContainer);
    final fg =
        color != null
            ? Colors.white
            : (isSuccess ? cs.onPrimaryContainer : cs.onErrorContainer);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
