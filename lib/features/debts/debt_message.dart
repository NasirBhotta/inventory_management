import '../../core/utils/formatters.dart';
import '../../data/repos/debt_repo.dart';

String normalizeWhatsAppPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) return digits.substring(2);
  if (digits.startsWith('92')) return digits;
  if (digits.startsWith('0') && digits.length >= 11) {
    return '92${digits.substring(1)}';
  }
  if (digits.length == 10) return '92$digits';
  return digits;
}

String buildDebtReminderMessage(DebtCustomerDetails details) {
  final unpaidEntries = details.entries.where((entry) => !entry.isPaid).toList();
  final lines = <String>[
    'Assalam-o-Alaikum ${details.customer.name},',
    'This is a reminder from the shop about your outstanding balance.',
    'Total due: ${Fmt.currency(details.totalDue)}',
  ];

  if (unpaidEntries.isNotEmpty) {
    lines.add('Pending items:');
    for (final entry in unpaidEntries.take(5)) {
      lines.add('- ${entry.itemName} x${entry.quantity} - ${Fmt.currency(entry.amountDue)}');
    }
    if (unpaidEntries.length > 5) {
      lines.add('- and ${unpaidEntries.length - 5} more item(s)');
    }
  }

  lines.add('Please clear the payment when convenient. Thank you.');
  return lines.join('\n');
}
