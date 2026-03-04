import 'package:equatable/equatable.dart';

class Sale extends Equatable {
  const Sale({
    this.id,
    required this.saleDate,
    required this.totalAmount,
    this.items = const [],
  });

  final int? id;
  final DateTime saleDate;
  final double totalAmount;
  final List<SaleItem> items;

  factory Sale.fromMap(Map<String, Object?> m) => Sale(
    id: m['id'] as int?,
    saleDate: DateTime.parse(m['sale_date'] as String),
    totalAmount: (m['total_amount'] as num).toDouble(),
  );

  @override
  List<Object?> get props => [id, saleDate, totalAmount];
}

class SaleItem extends Equatable {
  const SaleItem({
    this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final int? id;
  final int saleId;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  double get lineTotal => quantity * unitPrice;

  factory SaleItem.fromMap(Map<String, Object?> m) => SaleItem(
    id: m['id'] as int?,
    saleId: m['sale_id'] as int,
    productId: m['product_id'] as int,
    productName: m['name'] as String? ?? '',
    quantity: m['quantity'] as int,
    unitPrice: (m['unit_price'] as num).toDouble(),
  );

  @override
  List<Object?> get props => [id, saleId, productId, quantity, unitPrice];
}

class CartItem extends Equatable {
  const CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  double get lineTotal => quantity * unitPrice;
  double get total => lineTotal;

  CartItem copyWith({
    int? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  @override
  List<Object?> get props => [productId, productName, quantity, unitPrice];
}
