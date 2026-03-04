import 'dart:io';
import 'package:inventory_managment_sys/core/errors/app_exceptions.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide DatabaseException;
import '../../core/constants/app_constants.dart';

import '../../core/utils/app_logger.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> get db => database;

  Future<String> get dbPath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, AppConstants.dbName);
  }

  Future<Database> _open() async {
    final path = await dbPath;
    await Directory(p.dirname(path)).create(recursive: true);
    appLogger.d('Opening database at $path');
    try {
      return await openDatabase(
        path,
        version: AppConstants.dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );
    } catch (e) {
      throw DatabaseException('Failed to open database', e);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _ensureSchema(db);
  }

  Future<void> _onOpen(Database db) async {
    // Self-heal old/local DB files that are missing newly added tables.
    await _ensureSchema(db);
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        name           TEXT    NOT NULL,
        category       TEXT    NOT NULL,
        unit_price     REAL    NOT NULL DEFAULT 0,
        quantity       INTEGER NOT NULL DEFAULT 0,
        minimum_stock  INTEGER NOT NULL DEFAULT 0,
        created_at     TEXT    NOT NULL DEFAULT (datetime('now')),
        updated_at     TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_date     TEXT    NOT NULL DEFAULT (datetime('now')),
        total_amount  REAL    NOT NULL DEFAULT 0,
        note          TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id     INTEGER NOT NULL REFERENCES sales(id),
        product_id  INTEGER NOT NULL REFERENCES products(id),
        quantity    INTEGER NOT NULL,
        unit_price  REAL    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id     INTEGER NOT NULL REFERENCES products(id),
        movement_type  TEXT    NOT NULL CHECK(movement_type IN ('IN','OUT')),
        quantity       INTEGER NOT NULL,
        note           TEXT,
        movement_date  TEXT    NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Indexes for common queries
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(sale_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_product ON stock_movements(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id)',
    );

    await _ensureLegacyColumns(db);
  }

  Future<void> _ensureLegacyColumns(Database db) async {
    await _ensureColumn(
      db,
      table: 'products',
      column: 'minimum_stock',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'created_at',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'updated_at',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'stock_movements',
      column: 'movement_date',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'stock_movements',
      column: 'movement_type',
      definition: 'TEXT NOT NULL DEFAULT \'IN\'',
    );
    await _ensureColumn(
      db,
      table: 'stock_movements',
      column: 'note',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'sales',
      column: 'sale_date',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'sales',
      column: 'total_amount',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'sales',
      column: 'note',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'sale_items',
      column: 'sale_id',
      definition: 'INTEGER',
    );
    await _ensureColumn(
      db,
      table: 'sale_items',
      column: 'product_id',
      definition: 'INTEGER',
    );
    await _ensureColumn(
      db,
      table: 'sale_items',
      column: 'quantity',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'sale_items',
      column: 'unit_price',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
  }

  Future<void> _ensureColumn(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    final exists = rows.any((r) => r['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    appLogger.i('Added missing column $table.$column');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    appLogger.i('Upgrading database from $oldVersion to $newVersion');
    // Add migration scripts here as app evolves
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<String> backup() async {
    final db = await database;
    final src = await dbPath;
    final dir = await getApplicationSupportDirectory();
    final bDir = Directory(p.join(dir.path, AppConstants.backupFolder))
      ..createSync(recursive: true);
    final dest = p.join(
      bDir.path,
      'inventory_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    await db.close();
    _db = null;
    await File(src).copy(dest);
    appLogger.i('Backup created at $dest');
    return dest;
  }

  Future<String> restoreLatest() async {
    final dir = await getApplicationSupportDirectory();
    final bDir = Directory(p.join(dir.path, AppConstants.backupFolder));
    if (!bDir.existsSync()) throw const AppException('No backup folder found');
    final files =
        bDir.listSync().whereType<File>().toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    if (files.isEmpty) throw const AppException('No backup files found');
    final src = await dbPath;
    await _db?.close();
    _db = null;
    await files.first.copy(src);
    _db = await _open();
    appLogger.i('Restored from ${files.first.path}');
    return files.first.path;
  }

  Future<void> reopenFrom(String sourcePath) async {
    final src = File(sourcePath);
    if (!src.existsSync()) {
      throw const AppException('Backup file not found');
    }
    final dest = await dbPath;
    await _db?.close();
    _db = null;
    await src.copy(dest);
    _db = await _open();
  }

  Future<List<Map<String, Object?>>> listBackups() async {
    final dir = await getApplicationSupportDirectory();
    final bDir = Directory(p.join(dir.path, AppConstants.backupFolder));
    if (!bDir.existsSync()) return [];
    return bDir
        .listSync()
        .whereType<File>()
        .map((f) => {'path': f.path, 'size': f.lengthSync()})
        .toList()
      ..sort((a, b) => (b['path'] as String).compareTo(a['path'] as String));
  }
}
