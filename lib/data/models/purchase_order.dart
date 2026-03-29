import 'package:equatable/equatable.dart';

enum PurchaseOrderStatus { draft, ordered, received, cancelled }

extension PurchaseOrderStatusX on PurchaseOrderStatus {
  String get label => switch (this) {
    PurchaseOrderStatus.draft => 'Draft',
    PurchaseOrderStatus.ordered => 'Ordered',
    PurchaseOrderStatus.received => 'Received',
    PurchaseOrderStatus.cancelled => 'Cancelled',
  };

  String get dbValue => name;

  static PurchaseOrderStatus fromDb(String value) {
    return PurchaseOrderStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => PurchaseOrderStatus.draft,
    );
  }
}

class PurchaseOrder extends Equatable {
  const PurchaseOrder({
    this.id,
    required this.productId,
    required this.productName,
    required this.productCategory,
    required this.supplierName,
    required this.orderedQuantity,
    required this.unitCost,
    required this.stockUnit,
    required this.note,
    required this.status,
    required this.createdAt,
    this.orderedAt,
    this.receivedAt,
  });

  final int? id;
  final int productId;
  final String productName;
  final String productCategory;
  final String supplierName;
  final double orderedQuantity;
  final double unitCost;
  final String stockUnit;
  final String note;
  final PurchaseOrderStatus status;
  final DateTime createdAt;
  final DateTime? orderedAt;
  final DateTime? receivedAt;

  double get totalCost => orderedQuantity * unitCost;
  bool get canPlace => status == PurchaseOrderStatus.draft;
  bool get canReceive =>
      status == PurchaseOrderStatus.draft || status == PurchaseOrderStatus.ordered;
  bool get canCancel =>
      status == PurchaseOrderStatus.draft || status == PurchaseOrderStatus.ordered;

  factory PurchaseOrder.fromMap(Map<String, Object?> map) => PurchaseOrder(
    id: map['id'] as int?,
    productId: (map['product_id'] as num).toInt(),
    productName: map['product_name'] as String? ?? '',
    productCategory: map['product_category'] as String? ?? '',
    supplierName: map['supplier_name'] as String? ?? '',
    orderedQuantity: (map['ordered_quantity'] as num?)?.toDouble() ?? 0,
    unitCost: (map['unit_cost'] as num?)?.toDouble() ?? 0,
    stockUnit: (map['stock_unit'] as String? ?? 'unit').trim().isEmpty
        ? 'unit'
        : (map['stock_unit'] as String? ?? 'unit').trim(),
    note: map['note'] as String? ?? '',
    status: PurchaseOrderStatusX.fromDb(
      map['status'] as String? ?? PurchaseOrderStatus.draft.name,
    ),
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    orderedAt: DateTime.tryParse(map['ordered_at'] as String? ?? ''),
    receivedAt: DateTime.tryParse(map['received_at'] as String? ?? ''),
  );

  @override
  List<Object?> get props => [
    id,
    productId,
    productName,
    productCategory,
    supplierName,
    orderedQuantity,
    unitCost,
    stockUnit,
    note,
    status,
    createdAt,
    orderedAt,
    receivedAt,
  ];
}
