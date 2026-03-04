import 'package:equatable/equatable.dart';

class Product extends Equatable {
  const Product({
    this.id,
    required this.name,
    required this.category,
    required this.unitPrice,
    required this.quantity,
    required this.minimumStock,
  });

  final int? id;
  final String name;
  final String category;
  final double unitPrice;
  final int quantity;
  final int minimumStock;

  bool get isLowStock => quantity <= minimumStock;
  double get totalValue => quantity * unitPrice;

  factory Product.fromMap(Map<String, Object?> m) => Product(
    id: m['id'] as int?,
    name: m['name'] as String,
    category: m['category'] as String,
    unitPrice: (m['unit_price'] as num).toDouble(),
    quantity: m['quantity'] as int,
    minimumStock: m['minimum_stock'] as int,
  );

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'category': category,
    'unit_price': unitPrice,
    'quantity': quantity,
    'minimum_stock': minimumStock,
  };

  Product copyWith({
    int? id,
    String? name,
    String? category,
    double? unitPrice,
    int? quantity,
    int? minimumStock,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    unitPrice: unitPrice ?? this.unitPrice,
    quantity: quantity ?? this.quantity,
    minimumStock: minimumStock ?? this.minimumStock,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    unitPrice,
    quantity,
    minimumStock,
  ];
}
