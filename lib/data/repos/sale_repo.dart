import 'package:inventory_managment_sys/data/database/db_service.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/app_logger.dart';
import '../models/sale.dart';

class ProductDemandSummary {
  const ProductDemandSummary({
    required this.productId,
    required this.totalSold,
    required this.saleCount,
    this.lastSoldAt,
  });

  final int productId;
  final double totalSold;
  final int saleCount;
  final DateTime? lastSoldAt;

  double averageDailyDemand(int days) {
    if (days <= 0) return 0;
    return totalSold / days;
  }
}

class ProductProfitSummary {
  const ProductProfitSummary({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.revenue,
    required this.cost,
    required this.profit,
  });

  final int productId;
  final String productName;
  final double quantitySold;
  final double revenue;
  final double cost;
  final double profit;

  double get marginPercent => revenue <= 0 ? 0 : (profit / revenue) * 100;
}

class ProfitSummary {
  const ProfitSummary({
    required this.revenue,
    required this.cost,
    required this.profit,
  });

  final double revenue;
  final double cost;
  final double profit;

  double get marginPercent => revenue <= 0 ? 0 : (profit / revenue) * 100;
}

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
        final now = DateTime.now().toIso8601String();

        final saleId = await txn.insert(TableNames.sales, {
          'sale_date': now,
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

          final productRow = rows.first;
          final allowsFractional =
              ((productRow['allow_fractional_quantity'] as num?)?.toInt() ?? 0) == 1;
          if (!allowsFractional && item.quantity != item.quantity.roundToDouble()) {
            throw const ValidationException(
              'This product can only be sold in whole quantities',
            );
          }

          final current = (productRow['quantity'] as num).toDouble();
          if (current < item.quantity) {
            throw InsufficientStockException(item.productName);
          }

          final costPrice = (productRow['cost_price'] as num?)?.toDouble() ?? 0;
          if (costPrice <= 0) {
            throw ValidationException(
              'Cost price is missing for ${productRow['name'] as String? ?? item.productName}',
            );
          }

          final sellingPrice = item.unitPrice;
          final itemProfit = (sellingPrice - costPrice) * item.quantity;

          await txn.update(
            TableNames.products,
            {
              'quantity': current - item.quantity,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [item.productId],
          );

          await txn.insert(TableNames.stock, {
            'product_id': item.productId,
            'movement_type': 'OUT',
            'quantity': item.quantity,
            'stock_unit': item.stockUnit,
            'note': 'Sale #$saleId',
            'movement_date': now,
          });

          await txn.insert(TableNames.saleItems, {
            'sale_id': saleId,
            'product_id': item.productId,
            'quantity': item.quantity,
            'unit_price': sellingPrice,
            'cost_price_at_sale': costPrice,
            'selling_price_at_sale': sellingPrice,
            'profit': itemProfit,
            'stock_unit': item.stockUnit,
          });
        }

        appLogger.i('Sale #$saleId created. Total: $total. Items: ${cart.length}');
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

  Future<List<Map<String, Object?>>> getDailyProfit({int days = 14}) async {
    final db = await _db.db;
    return db.rawQuery(
      '''
      SELECT substr(s.sale_date, 1, 10) as day,
             SUM(si.profit) as profit
      FROM ${TableNames.saleItems} si
      JOIN ${TableNames.sales} s ON s.id = si.sale_id
      WHERE s.sale_date >= datetime('now', '-$days days')
      GROUP BY substr(s.sale_date, 1, 10)
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
             SUM(si.quantity * si.selling_price_at_sale) as total_revenue
      FROM ${TableNames.saleItems} si
      JOIN ${TableNames.products} p ON p.id = si.product_id
      GROUP BY si.product_id, p.name
      ORDER BY total_revenue DESC
      LIMIT ?
      ''',
      [limit],
    );
  }

  Future<double> getTotalProfitToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return getTotalProfitByDateRange(start, now);
  }

  Future<double> getTotalProfitByDateRange(DateTime start, DateTime end) async {
    final db = await _db.db;
    final rows = await db.rawQuery(
      '''
      SELECT SUM(si.profit) as total_profit
      FROM ${TableNames.saleItems} si
      JOIN ${TableNames.sales} s ON s.id = si.sale_id
      WHERE s.sale_date >= ? AND s.sale_date <= ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (rows.first['total_profit'] as num?)?.toDouble() ?? 0;
  }

  Future<List<ProductProfitSummary>> getProfitPerProduct({
    DateTime? start,
    DateTime? end,
  }) async {
    final db = await _db.db;
    final where = <String>[];
    final args = <Object?>[];
    if (start != null) {
      where.add('s.sale_date >= ?');
      args.add(start.toIso8601String());
    }
    if (end != null) {
      where.add('s.sale_date <= ?');
      args.add(end.toIso8601String());
    }
    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';

    final rows = await db.rawQuery(
      '''
      SELECT si.product_id,
             p.name,
             SUM(si.quantity) as quantity_sold,
             SUM(si.quantity * si.selling_price_at_sale) as revenue,
             SUM(si.quantity * si.cost_price_at_sale) as cost,
             SUM(si.profit) as profit
      FROM ${TableNames.saleItems} si
      JOIN ${TableNames.sales} s ON s.id = si.sale_id
      JOIN ${TableNames.products} p ON p.id = si.product_id
      $whereSql
      GROUP BY si.product_id, p.name
      ORDER BY profit DESC, p.name ASC
      ''',
      args,
    );

    return rows
        .map(
          (row) => ProductProfitSummary(
            productId: (row['product_id'] as num).toInt(),
            productName: row['name'] as String? ?? '',
            quantitySold: (row['quantity_sold'] as num?)?.toDouble() ?? 0,
            revenue: (row['revenue'] as num?)?.toDouble() ?? 0,
            cost: (row['cost'] as num?)?.toDouble() ?? 0,
            profit: (row['profit'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();
  }

  Future<List<ProductProfitSummary>> getTopProfitProducts({
    int limit = 5,
    DateTime? start,
    DateTime? end,
  }) async {
    final summaries = await getProfitPerProduct(start: start, end: end);
    return summaries.take(limit).toList();
  }

  Future<ProfitSummary> getProfitSummaryByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _db.db;
    final rows = await db.rawQuery(
      '''
      SELECT SUM(si.quantity * si.selling_price_at_sale) as revenue,
             SUM(si.quantity * si.cost_price_at_sale) as cost,
             SUM(si.profit) as profit
      FROM ${TableNames.saleItems} si
      JOIN ${TableNames.sales} s ON s.id = si.sale_id
      WHERE s.sale_date >= ? AND s.sale_date <= ?
      ''',
      [start.toIso8601String(), end.toIso8601String()],
    );
    final row = rows.first;
    return ProfitSummary(
      revenue: (row['revenue'] as num?)?.toDouble() ?? 0,
      cost: (row['cost'] as num?)?.toDouble() ?? 0,
      profit: (row['profit'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<ProductProfitSummary?> getProductProfitSummary(int productId) async {
    final summaries = await getProfitPerProduct();
    for (final summary in summaries) {
      if (summary.productId == productId) return summary;
    }
    return null;
  }

  Future<Map<int, ProductDemandSummary>> getRecentProductDemand({
    int days = 30,
  }) async {
    final db = await _db.db;
    final rows = await db.rawQuery(
      '''
      SELECT si.product_id,
             SUM(si.quantity) as total_sold,
             COUNT(DISTINCT si.sale_id) as sale_count,
             MAX(s.sale_date) as last_sold_at
      FROM ${TableNames.saleItems} si
      JOIN ${TableNames.sales} s ON s.id = si.sale_id
      WHERE s.sale_date >= datetime('now', '-$days days')
      GROUP BY si.product_id
      ''',
    );

    return {
      for (final row in rows)
        (row['product_id'] as num).toInt(): ProductDemandSummary(
          productId: (row['product_id'] as num).toInt(),
          totalSold: (row['total_sold'] as num?)?.toDouble() ?? 0,
          saleCount: (row['sale_count'] as num?)?.toInt() ?? 0,
          lastSoldAt: row['last_sold_at'] == null
              ? null
              : DateTime.tryParse(row['last_sold_at'] as String),
        ),
    };
  }
}
