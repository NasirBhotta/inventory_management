import 'package:inventory_managment_sys/core/constants/app_constants.dart';
import 'package:inventory_managment_sys/core/errors/app_exceptions.dart';
import 'package:inventory_managment_sys/data/database/db_service.dart';
import 'package:inventory_managment_sys/data/models/quotation.dart';
import 'package:inventory_managment_sys/data/models/sale.dart';

class QuotationRepository {
  const QuotationRepository(this._db);

  final DatabaseService _db;

  Future<List<Quotation>> getAll() async {
    final db = await _db.db;
    final rows = await db.query(
      TableNames.quotations,
      orderBy: "CASE status WHEN 'draft' THEN 0 WHEN 'sent' THEN 1 ELSE 2 END, created_at DESC",
    );
    return rows.map(Quotation.fromMap).toList();
  }

  Future<void> create({
    required String customerName,
    required String customerPhone,
    required String note,
    required List<CartItem> items,
  }) async {
    if (customerName.trim().isEmpty) {
      throw const ValidationException('Customer name is required');
    }
    if (items.isEmpty) {
      throw const ValidationException('Add at least one item to the quotation');
    }

    final db = await _db.db;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final total = items.fold<double>(0, (sum, item) => sum + item.total);
      final quoteId = await txn.insert(TableNames.quotations, {
        'customer_name': customerName.trim(),
        'customer_phone': customerPhone.trim(),
        'note': note.trim(),
        'total_amount': total,
        'item_count': items.length,
        'status': QuotationStatus.draft.dbValue,
        'created_at': now,
        'updated_at': now,
      });

      for (final item in items) {
        await txn.insert(TableNames.quotationItems, {
          'quotation_id': quoteId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'retail_unit_price': item.retailUnitPrice,
          'wholesale_unit_price': item.wholesaleUnitPrice,
          'wholesale_min_quantity': item.wholesaleMinQuantity,
          'stock_unit': item.stockUnit,
          'allow_fractional_quantity': item.allowFractionalQuantity ? 1 : 0,
        });
      }
    });
  }

  Future<QuotationDetails> getDetails(int quotationId) async {
    final db = await _db.db;
    final quoteRows = await db.query(
      TableNames.quotations,
      where: 'id = ?',
      whereArgs: [quotationId],
      limit: 1,
    );
    if (quoteRows.isEmpty) {
      throw const AppException('Quotation not found');
    }

    final itemRows = await db.query(
      TableNames.quotationItems,
      where: 'quotation_id = ?',
      whereArgs: [quotationId],
      orderBy: 'id ASC',
    );

    return QuotationDetails(
      quotation: Quotation.fromMap(quoteRows.first),
      items: itemRows.map(_cartItemFromMap).toList(),
    );
  }

  Future<void> markSent(int quotationId) async {
    await _updateStatus(quotationId, QuotationStatus.sent);
  }

  Future<void> markConverted(int quotationId) async {
    await _updateStatus(quotationId, QuotationStatus.converted);
  }

  Future<void> _updateStatus(int quotationId, QuotationStatus status) async {
    final db = await _db.db;
    await db.update(
      TableNames.quotations,
      {
        'status': status.dbValue,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [quotationId],
    );
  }

  CartItem _cartItemFromMap(Map<String, Object?> map) => CartItem(
    productId: (map['product_id'] as num).toInt(),
    productName: map['product_name'] as String? ?? '',
    quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
    retailUnitPrice: (map['retail_unit_price'] as num?)?.toDouble() ?? 0,
    stockUnit: (map['stock_unit'] as String? ?? 'unit').trim().isEmpty
        ? 'unit'
        : (map['stock_unit'] as String? ?? 'unit').trim(),
    allowFractionalQuantity:
        ((map['allow_fractional_quantity'] as num?)?.toInt() ?? 0) == 1,
    wholesaleUnitPrice: (map['wholesale_unit_price'] as num?)?.toDouble(),
    wholesaleMinQuantity: (map['wholesale_min_quantity'] as num?)?.toDouble(),
  );
}
