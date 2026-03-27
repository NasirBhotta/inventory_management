import 'package:equatable/equatable.dart';

class Product extends Equatable {
  const Product({
    this.id,
    required this.name,
    required this.category,
    required this.unitPrice,
    required this.quantity,
    required this.minimumStock,
    this.stockUnit = 'unit',
    this.allowFractionalQuantity = false,
  });

  final int? id;
  final String name;
  final String category;
  final double unitPrice;
  final double quantity;
  final double minimumStock;
  final String stockUnit;
  final bool allowFractionalQuantity;

  bool get isLowStock => quantity <= minimumStock;
  double get totalValue => quantity * unitPrice;

  factory Product.fromMap(Map<String, Object?> m) => Product(
    id: m['id'] as int?,
    name: m['name'] as String,
    category: m['category'] as String,
    unitPrice: (m['unit_price'] as num).toDouble(),
    quantity: (m['quantity'] as num).toDouble(),
    minimumStock: (m['minimum_stock'] as num).toDouble(),
    stockUnit: (m['stock_unit'] as String? ?? 'unit').trim().isEmpty
        ? 'unit'
        : (m['stock_unit'] as String? ?? 'unit').trim(),
    allowFractionalQuantity:
        ((m['allow_fractional_quantity'] as num?)?.toInt() ?? 0) == 1,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'category': category,
    'unit_price': unitPrice,
    'quantity': quantity,
    'minimum_stock': minimumStock,
    'stock_unit': stockUnit.trim().isEmpty ? 'unit' : stockUnit.trim(),
    'allow_fractional_quantity': allowFractionalQuantity ? 1 : 0,
  };

  Product copyWith({
    int? id,
    String? name,
    String? category,
    double? unitPrice,
    double? quantity,
    double? minimumStock,
    String? stockUnit,
    bool? allowFractionalQuantity,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    unitPrice: unitPrice ?? this.unitPrice,
    quantity: quantity ?? this.quantity,
    minimumStock: minimumStock ?? this.minimumStock,
    stockUnit: stockUnit ?? this.stockUnit,
    allowFractionalQuantity:
        allowFractionalQuantity ?? this.allowFractionalQuantity,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    unitPrice,
    quantity,
    minimumStock,
    stockUnit,
    allowFractionalQuantity,
  ];
}
