import 'package:inventory_managment_sys/data/database/db_service.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/app_logger.dart';

import '../models/sale.dart';

class SalesRepository {
  SalesRepository(this._db);
  final DatabaseService _db;

  Future<int> createSale(List<CartItem> cart, {String? note}) async {
    if (cart.isEmpty) {
      throw const ValidationException('Cart is empty');
    }
    try {
      final db = await _db.db;
      return await db.transaction((txn) async {
        final total = cart.fold<double>(0, (s, i) => s + i.lineTotal);

        final saleId = await txn.insert(TableNames.sales, {
          'sale_date': DateTime.now().toIso8601String(),
          'total_amount': total,
          'note': note,
        });

        for (final item in cart) {
          final rows = await txn.query(
            TableNames.products,
            where: 'id = ?',
            whereArgs: [item.productId],
          );
          if (rows.isEmpty) {
            throw DatabaseException('Product not found: ${item.productName}');
          }

          final current = rows.first['quantity'] as int;
          if (current < item.quantity) {
            throw InsufficientStockException(item.productName);
          }

          await txn.update(
            TableNames.products,
            {
              'quantity': current - item.quantity,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [item.productId],
          );

          await txn.insert(TableNames.stock, {
            'product_id': item.productId,
            'movement_type': 'OUT',
            'quantity': item.quantity,
            'note': 'Sale #$saleId',
            'movement_date': DateTime.now().toIso8601String(),
          });

          await txn.insert(TableNames.saleItems, {
            'sale_id': saleId,
            'product_id': item.productId,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
          });
        }

        appLogger.i(
          'Sale #$saleId created. Total: $total. Items: ${cart.length}',
        );
        return saleId;
      });
    } on AppException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Failed to record sale', e);
    }
  }

  Future<List<Sale>> getSales({DateTime? from, DateTime? to}) async {
    final sb = StringBuffer('SELECT * FROM ${TableNames.sales} WHERE 1=1');
    final args = <Object?>[];

    if (from != null) {
      sb.write(' AND sale_date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      sb.write(' AND sale_date <= ?');
      args.add(to.toIso8601String());
    }
    sb.write(' ORDER BY sale_date DESC');

    final db = await _db.db;
    final rows = await db.rawQuery(sb.toString(), args);
    return rows.map(Sale.fromMap).toList();
  }

  Future<Map<String, double>> getSalesSummary() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final monthStart = DateTime(now.year, now.month).toIso8601String();

    Future<double> query(String start) async {
      final db = await _db.db;
      final rows = await db.rawQuery(
        'SELECT SUM(total_amount) as total FROM ${TableNames.sales} WHERE sale_date >= ?',
        [start],
      );
      return (rows.first['total'] as num?)?.toDouble() ?? 0;
    }

    return {
      'today': await query(todayStart),
      'monthly': await query(monthStart),
    };
  }

  Future<void> recordSale(List<CartItem> cart, {String? note}) async {
    await createSale(cart, note: note);
  }

  Future<Map<String, double>> getSummary() async {
    final db = await _db.db;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final monthStart = DateTime(now.year, now.month).toIso8601String();
    final yearStart = DateTime(now.year).toIso8601String();

    Future<double> sumSince(String start) async {
      final rows = await db.rawQuery(
        'SELECT SUM(total_amount) as total FROM ${TableNames.sales} WHERE sale_date >= ?',
        [start],
      );
      return (rows.first['total'] as num?)?.toDouble() ?? 0;
    }

    return {
      'today': await sumSince(todayStart),
      'month': await sumSince(monthStart),
      'year': await sumSince(yearStart),
    };
  }

  Future<List<Map<String, Object?>>> getDailySales({int days = 14}) async {
    final db = await _db.db;
    return db.rawQuery(
      '''
      SELECT substr(sale_date, 1, 10) as day, SUM(total_amount) as total
      FROM ${TableNames.sales}
      WHERE sale_date >= datetime('now', '-$days days')
      GROUP BY substr(sale_date, 1, 10)
      ORDER BY day ASC
      ''',
    );
  }

  Future<List<Map<String, Object?>>> getTopProducts({int limit = 10}) async {
    final db = await _db.db;
    return db.rawQuery(
      '''
      SELECT p.name,
             SUM(si.quantity) as total_qty,
             SUM(si.quantity * si.unit_price) as total_revenue
      FROM ${TableNames.saleItems} si
      JOIN ${TableNames.products} p ON p.id = si.product_id
      GROUP BY si.product_id, p.name
      ORDER BY total_revenue DESC
      LIMIT ?
      ''',
      [limit],
    );
  }
}
