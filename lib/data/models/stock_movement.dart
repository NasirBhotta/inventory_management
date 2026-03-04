import 'package:equatable/equatable.dart';

enum MovementType { in_, out }

extension MovementTypeX on MovementType {
  String get label => this == MovementType.in_ ? 'IN' : 'OUT';
  static MovementType fromString(String s) =>
      s == 'IN' ? MovementType.in_ : MovementType.out;
}

class StockMovement extends Equatable {
  const StockMovement({
    this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.note,
    required this.movementDate,
  });

  final int? id;
  final int productId;
  final String productName;
  final MovementType type;
  final int quantity;
  final String note;
  final DateTime movementDate;

  factory StockMovement.fromMap(Map<String, Object?> m) => StockMovement(
    id: m['id'] as int?,
    productId: m['product_id'] as int,
    productName: m['name'] as String? ?? '',
    type: MovementTypeX.fromString(m['movement_type'] as String),
    quantity: m['quantity'] as int,
    note: m['note'] as String? ?? '',
    movementDate: DateTime.parse(m['movement_date'] as String),
  );

  @override
  List<Object?> get props => [id, productId, type, quantity, movementDate];
}
