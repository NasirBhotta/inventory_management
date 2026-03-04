import 'package:inventory_managment_sys/core/errors/app_exceptions.dart';
import 'package:inventory_managment_sys/data/database/db_service.dart';
import 'package:inventory_managment_sys/data/models/stock_movement.dart';

class StockRepository {
  const StockRepository(this._db);
  final DatabaseService _db;

  Future<void> move({
    required int productId,
    required MovementType type,
    required int quantity,
    required String note,
  }) async {
    if (quantity <= 0) throw const AppException('Quantity must be > 0');
    final db = await _db.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (rows.isEmpty) throw const AppException('Product not found');
      final current = rows.first['quantity'] as int;
      final next =
          type == MovementType.in_ ? current + quantity : current - quantity;
      if (next < 0)
        throw InsufficientStockException(rows.first['name'] as String);

      await txn.update(
        'products',
        {'quantity': next, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [productId],
      );
      await txn.insert('stock_movements', {
        'product_id': productId,
        'movement_type': type.label,
        'quantity': quantity,
        'note': note.trim(),
        'movement_date': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<StockMovement>> getRecent({int limit = 100}) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT sm.*, p.name
      FROM stock_movements sm
      JOIN products p ON p.id = sm.product_id
      ORDER BY sm.movement_date DESC
      LIMIT ?
    ''',
      [limit],
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<List<StockMovement>> getMovements({
    DateTime? from,
    DateTime? to,
    int limit = 500,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('sm.movement_date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('sm.movement_date <= ?');
      args.add(to.toIso8601String());
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final rows = await db.rawQuery(
      '''
      SELECT sm.*, p.name
      FROM stock_movements sm
      JOIN products p ON p.id = sm.product_id
      $whereSql
      ORDER BY sm.movement_date DESC
      LIMIT ?
      ''',
      [...args, limit],
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<List<StockMovement>> getForProduct(int productId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '''
      SELECT sm.*, p.name
      FROM stock_movements sm
      JOIN products p ON p.id = sm.product_id
      WHERE sm.product_id = ?
      ORDER BY sm.movement_date DESC
    ''',
      [productId],
    );
    return rows.map(StockMovement.fromMap).toList();
  }
}
