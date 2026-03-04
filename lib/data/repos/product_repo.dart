import 'package:inventory_managment_sys/core/errors/app_exceptions.dart';
import 'package:inventory_managment_sys/data/database/db_service.dart';

import '../models/product.dart';

class ProductRepository {
  const ProductRepository(this._db);
  final DatabaseService _db;

  Future<List<Product>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('products', orderBy: 'name ASC');
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query('products', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  Future<Product> insert(Product product) async {
    final db = await _db.database;
    final id = await db.insert('products', product.toMap());
    return product.copyWith(id: id);
  }

  Future<void> update(Product product) async {
    if (product.id == null) throw const AppException('Product has no ID');
    final db = await _db.database;
    await db.update(
      'products',
      {...product.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getLowStock() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT * FROM products WHERE quantity <= minimum_stock ORDER BY name',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<List<String>> getCategories() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT category FROM products ORDER BY category',
    );
    return rows.map((r) => r['category'] as String).toList();
  }
}
