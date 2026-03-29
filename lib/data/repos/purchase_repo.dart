import 'package:inventory_managment_sys/core/constants/app_constants.dart';
import 'package:inventory_managment_sys/core/errors/app_exceptions.dart';
import 'package:inventory_managment_sys/data/database/db_service.dart';
import 'package:inventory_managment_sys/data/models/purchase_order.dart';

class PurchaseOrderRepository {
  const PurchaseOrderRepository(this._db);

  final DatabaseService _db;

  Future<List<PurchaseOrder>> getAll() async {
    final db = await _db.db;
    final rows = await db.rawQuery('''
      SELECT po.*,
             p.name as product_name,
             p.category as product_category
      FROM ${TableNames.purchases} po
      JOIN ${TableNames.products} p ON p.id = po.product_id
      ORDER BY
        CASE po.status
          WHEN 'draft' THEN 0
          WHEN 'ordered' THEN 1
          WHEN 'received' THEN 2
          ELSE 3
        END,
        po.created_at DESC
    ''');
    return rows.map(PurchaseOrder.fromMap).toList();
  }

  Future<void> create({
    required int productId,
    required String supplierName,
    required double quantity,
    required double unitCost,
    required String note,
  }) async {
    if (supplierName.trim().isEmpty) {
      throw const ValidationException('Supplier name is required');
    }
    if (quantity <= 0) {
      throw const ValidationException('Ordered quantity must be greater than 0');
    }
    if (unitCost <= 0) {
      throw const ValidationException('Unit cost must be greater than 0');
    }

    final db = await _db.db;
    final productRows = await db.query(
      TableNames.products,
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (productRows.isEmpty) {
      throw const AppException('Product not found');
    }

    final product = productRows.first;
    final allowsFractional =
        ((product['allow_fractional_quantity'] as num?)?.toInt() ?? 0) == 1;
    if (!allowsFractional && quantity != quantity.roundToDouble()) {
      throw const ValidationException(
        'This product can only be ordered in whole quantities',
      );
    }

    await db.insert(TableNames.purchases, {
      'product_id': productId,
      'supplier_name': supplierName.trim(),
      'ordered_quantity': quantity,
      'unit_cost': unitCost,
      'stock_unit': product['stock_unit'] as String? ?? 'unit',
      'note': note.trim(),
      'status': PurchaseOrderStatus.draft.dbValue,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> place(int orderId) async {
    await _transition(orderId, to: PurchaseOrderStatus.ordered);
  }

  Future<void> cancel(int orderId) async {
    await _transition(orderId, to: PurchaseOrderStatus.cancelled);
  }

  Future<void> receive(int orderId) async {
    final db = await _db.db;
    await db.transaction((txn) async {
      final rows = await txn.rawQuery('''
        SELECT po.*, p.name as product_name, p.stock_unit, p.quantity
        FROM ${TableNames.purchases} po
        JOIN ${TableNames.products} p ON p.id = po.product_id
        WHERE po.id = ?
        LIMIT 1
      ''', [orderId]);

      if (rows.isEmpty) {
        throw const AppException('Purchase order not found');
      }

      final order = PurchaseOrder.fromMap(rows.first);
      if (!order.canReceive) {
        throw AppException(
          'Purchase order is already ${order.status.label.toLowerCase()}',
        );
      }

      final now = DateTime.now().toIso8601String();
      final currentQuantity = (rows.first['quantity'] as num?)?.toDouble() ?? 0;
      final stockUnit = rows.first['stock_unit'] as String? ?? 'unit';

      await txn.update(
        TableNames.products,
        {
          'quantity': currentQuantity + order.orderedQuantity,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [order.productId],
      );

      await txn.insert(TableNames.stock, {
        'product_id': order.productId,
        'movement_type': 'IN',
        'quantity': order.orderedQuantity,
        'stock_unit': stockUnit,
        'note': 'Purchase order #$orderId received from ${order.supplierName}',
        'movement_date': now,
      });

      await txn.update(
        TableNames.purchases,
        {
          'status': PurchaseOrderStatus.received.dbValue,
          'ordered_at': order.orderedAt?.toIso8601String() ?? now,
          'received_at': now,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });
  }

  Future<void> _transition(
    int orderId, {
    required PurchaseOrderStatus to,
  }) async {
    final db = await _db.db;
    final rows = await db.query(
      TableNames.purchases,
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AppException('Purchase order not found');
    }

    final order = PurchaseOrder.fromMap(rows.first);
    if (to == PurchaseOrderStatus.ordered && !order.canPlace) {
      throw AppException(
        'Only draft purchase orders can be marked as ordered',
      );
    }
    if (to == PurchaseOrderStatus.cancelled && !order.canCancel) {
      throw AppException(
        'Only draft or ordered purchase orders can be cancelled',
      );
    }

    final now = DateTime.now().toIso8601String();
    await db.update(
      TableNames.purchases,
      {
        'status': to.dbValue,
        if (to == PurchaseOrderStatus.ordered) 'ordered_at': now,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
}
