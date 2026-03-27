import 'package:equatable/equatable.dart';

class DebtEntry extends Equatable {
  const DebtEntry({
    this.id,
    required this.customerId,
    required this.productId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.amountDue,
    this.note = '',
    this.entryDate,
    this.isPaid = false,
    this.stockUnit = 'unit',
  });

  final int? id;
  final int customerId;
  final int productId;
  final String itemName;
  final double quantity;
  final double unitPrice;
  final double amountDue;
  final String note;
  final DateTime? entryDate;
  final bool isPaid;
  final String stockUnit;

  factory DebtEntry.fromMap(Map<String, Object?> map) => DebtEntry(
    id: map['id'] as int?,
    customerId: map['customer_id'] as int,
    productId: map['product_id'] as int? ?? 0,
    itemName: map['item_name'] as String? ?? '',
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
    unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
    amountDue: (map['amount_due'] as num?)?.toDouble() ?? 0,
    note: map['note'] as String? ?? '',
    entryDate:
        map['entry_date'] == null
            ? null
            : DateTime.tryParse(map['entry_date'] as String),
    isPaid: (map['is_paid'] as int? ?? 0) == 1,
    stockUnit: (map['stock_unit'] as String? ?? 'unit').trim().isEmpty
        ? 'unit'
        : (map['stock_unit'] as String? ?? 'unit').trim(),
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'customer_id': customerId,
    'product_id': productId,
    'item_name': itemName,
    'quantity': quantity,
    'unit_price': unitPrice,
    'amount_due': amountDue,
    'note': note,
    'is_paid': isPaid ? 1 : 0,
    'stock_unit': stockUnit.trim().isEmpty ? 'unit' : stockUnit.trim(),
  };

  @override
  List<Object?> get props => [
    id,
    customerId,
    productId,
    itemName,
    quantity,
    unitPrice,
    amountDue,
    note,
    entryDate,
    isPaid,
    stockUnit,
  ];
}
