import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_managment_sys/data/models/quotation.dart';

void main() {
  test('quotation status falls back to draft for unknown values', () {
    expect(QuotationStatusX.fromDb('unknown'), QuotationStatus.draft);
  });

  test('quotation maps summary fields correctly', () {
    final quote = Quotation.fromMap({
      'id': 3,
      'customer_name': 'Farmer Ali',
      'customer_phone': '03001234567',
      'note': 'Seasonal booking',
      'total_amount': 5400,
      'item_count': 2,
      'status': 'sent',
      'created_at': '2026-03-30T10:00:00.000',
    });

    expect(quote.customerName, 'Farmer Ali');
    expect(quote.totalAmount, 5400);
    expect(quote.itemCount, 2);
    expect(quote.status, QuotationStatus.sent);
  });
}
