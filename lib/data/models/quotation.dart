import 'package:equatable/equatable.dart';
import 'package:inventory_managment_sys/data/models/sale.dart';

enum QuotationStatus { draft, sent, converted }

extension QuotationStatusX on QuotationStatus {
  String get label => switch (this) {
    QuotationStatus.draft => 'Draft',
    QuotationStatus.sent => 'Sent',
    QuotationStatus.converted => 'Converted',
  };

  String get dbValue => name;

  static QuotationStatus fromDb(String value) {
    return QuotationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => QuotationStatus.draft,
    );
  }
}

class Quotation extends Equatable {
  const Quotation({
    this.id,
    required this.customerName,
    required this.customerPhone,
    required this.note,
    required this.totalAmount,
    required this.itemCount,
    required this.status,
    required this.createdAt,
  });

  final int? id;
  final String customerName;
  final String customerPhone;
  final String note;
  final double totalAmount;
  final int itemCount;
  final QuotationStatus status;
  final DateTime createdAt;

  factory Quotation.fromMap(Map<String, Object?> map) => Quotation(
    id: map['id'] as int?,
    customerName: map['customer_name'] as String? ?? '',
    customerPhone: map['customer_phone'] as String? ?? '',
    note: map['note'] as String? ?? '',
    totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
    itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
    status: QuotationStatusX.fromDb(
      map['status'] as String? ?? QuotationStatus.draft.name,
    ),
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
  );

  @override
  List<Object?> get props => [
    id,
    customerName,
    customerPhone,
    note,
    totalAmount,
    itemCount,
    status,
    createdAt,
  ];
}

class QuotationDetails extends Equatable {
  const QuotationDetails({required this.quotation, required this.items});

  final Quotation quotation;
  final List<CartItem> items;

  @override
  List<Object?> get props => [quotation, items];
}
