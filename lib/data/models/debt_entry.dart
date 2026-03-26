import 'package:equatable/equatable.dart';

class DebtEntry extends Equatable {
  const DebtEntry({
    this.id,
    required this.customerId,
    required this.itemName,
    required this.quantity,
    required this.amountDue,
    this.note = '',
    this.entryDate,
    this.isPaid = false,
  });

  final int? id;
  final int customerId;
  final String itemName;
  final int quantity;
  final double amountDue;
  final String note;
  final DateTime? entryDate;
  final bool isPaid;

  factory DebtEntry.fromMap(Map<String, Object?> map) => DebtEntry(
    id: map['id'] as int?,
    customerId: map['customer_id'] as int,
    itemName: map['item_name'] as String? ?? '',
    quantity: map['quantity'] as int? ?? 0,
    amountDue: (map['amount_due'] as num?)?.toDouble() ?? 0,
    note: map['note'] as String? ?? '',
    entryDate:
        map['entry_date'] == null
            ? null
            : DateTime.tryParse(map['entry_date'] as String),
    isPaid: (map['is_paid'] as int? ?? 0) == 1,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'customer_id': customerId,
    'item_name': itemName,
    'quantity': quantity,
    'amount_due': amountDue,
    'note': note,
    'is_paid': isPaid ? 1 : 0,
  };

  @override
  List<Object?> get props => [
    id,
    customerId,
    itemName,
    quantity,
    amountDue,
    note,
    entryDate,
    isPaid,
  ];
}
