import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_managment_sys/data/models/debt_customer.dart';
import 'package:inventory_managment_sys/data/models/debt_entry.dart';
import 'package:inventory_managment_sys/data/repos/debt_repo.dart';
import 'package:inventory_managment_sys/features/debts/debt_message.dart';

void main() {
  test('normalizeWhatsAppPhone formats local Pakistan numbers', () {
    expect(normalizeWhatsAppPhone('0300-1234567'), '923001234567');
    expect(normalizeWhatsAppPhone('+92 300 1234567'), '923001234567');
    expect(normalizeWhatsAppPhone('3001234567'), '923001234567');
  });

  test('buildDebtReminderMessage includes total and items', () {
    final message = buildDebtReminderMessage(
      DebtCustomerDetails(
        customer: const DebtCustomer(name: 'Ali', phone: '03001234567'),
        totalDue: 1500,
        entries: const [
          DebtEntry(
            customerId: 1,
            itemName: 'Urea Bag',
            quantity: 2,
            amountDue: 1000,
          ),
          DebtEntry(
            customerId: 1,
            itemName: 'Spray Bottle',
            quantity: 1,
            amountDue: 500,
          ),
        ],
      ),
    );

    expect(message, contains('Ali'));
    expect(message, contains('PKR 1,500.00'));
    expect(message, contains('Urea Bag x2'));
    expect(message, contains('Spray Bottle x1'));
  });
}
