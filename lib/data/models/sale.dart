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
    this.stockUnit = 'unit',
  });

  final int? id;
  final int saleId;
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final String stockUnit;
  double get lineTotal => quantity * unitPrice;

  factory SaleItem.fromMap(Map<String, Object?> m) => SaleItem(
    id: m['id'] as int?,
    saleId: m['sale_id'] as int,
    productId: m['product_id'] as int,
    productName: m['name'] as String? ?? '',
    quantity: (m['quantity'] as num).toDouble(),
    unitPrice: (m['unit_price'] as num).toDouble(),
    stockUnit: (m['stock_unit'] as String? ?? 'unit').trim().isEmpty
        ? 'unit'
        : (m['stock_unit'] as String? ?? 'unit').trim(),
  );

  @override
  List<Object?> get props => [id, saleId, productId, quantity, unitPrice, stockUnit];
}

class CartItem extends Equatable {
  const CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.retailUnitPrice,
    this.stockUnit = 'unit',
    this.allowFractionalQuantity = false,
    this.wholesaleUnitPrice,
    this.wholesaleMinQuantity,
  });

  final int productId;
  final String productName;
  final double quantity;
  final double retailUnitPrice;
  final String stockUnit;
  final bool allowFractionalQuantity;
  final double? wholesaleUnitPrice;
  final double? wholesaleMinQuantity;

  bool get hasWholesalePricing =>
      wholesaleUnitPrice != null &&
      wholesaleMinQuantity != null &&
      wholesaleUnitPrice! > 0 &&
      wholesaleMinQuantity! > 0;
  bool get isWholesaleApplied =>
      hasWholesalePricing && quantity >= wholesaleMinQuantity!;
  double get unitPrice =>
      isWholesaleApplied ? wholesaleUnitPrice! : retailUnitPrice;
  String get pricingTierLabel => isWholesaleApplied ? 'Wholesale' : 'Retail';
  double get savings =>
      isWholesaleApplied ? (retailUnitPrice - unitPrice) * quantity : 0;
  double get lineTotal => quantity * unitPrice;
  double get total => lineTotal;
  double get quantityStep => allowFractionalQuantity ? 0.25 : 1.0;

  CartItem copyWith({
    int? productId,
    String? productName,
    double? quantity,
    double? retailUnitPrice,
    String? stockUnit,
    bool? allowFractionalQuantity,
    double? wholesaleUnitPrice,
    double? wholesaleMinQuantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      retailUnitPrice: retailUnitPrice ?? this.retailUnitPrice,
      stockUnit: stockUnit ?? this.stockUnit,
      allowFractionalQuantity:
          allowFractionalQuantity ?? this.allowFractionalQuantity,
      wholesaleUnitPrice: wholesaleUnitPrice ?? this.wholesaleUnitPrice,
      wholesaleMinQuantity: wholesaleMinQuantity ?? this.wholesaleMinQuantity,
    );
  }

  @override
  List<Object?> get props => [
    productId,
    productName,
    quantity,
    retailUnitPrice,
    stockUnit,
    allowFractionalQuantity,
    wholesaleUnitPrice,
    wholesaleMinQuantity,
  ];
}
