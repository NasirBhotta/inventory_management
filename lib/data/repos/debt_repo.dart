import '../../core/errors/app_exceptions.dart';
import '../database/db_service.dart';
import '../models/debt_customer.dart';
import '../models/debt_entry.dart';

class DebtCustomerSummary {
  const DebtCustomerSummary({
    required this.customer,
    required this.totalDue,
    required this.unpaidCount,
    this.lastItemName,
    this.lastEntryDate,
  });

  final DebtCustomer customer;
  final double totalDue;
  final int unpaidCount;
  final String? lastItemName;
  final DateTime? lastEntryDate;
}

class DebtCustomerDetails {
  const DebtCustomerDetails({
    required this.customer,
    required this.entries,
    required this.totalDue,
  });

  final DebtCustomer customer;
  final List<DebtEntry> entries;
  final double totalDue;
}

class DebtRepository {
  const DebtRepository(this._db);

  final DatabaseService _db;

  Future<List<DebtCustomerSummary>> getCustomerSummaries() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        c.*,
        COALESCE(SUM(CASE WHEN e.is_paid = 0 THEN e.amount_due ELSE 0 END), 0) AS total_due,
        COALESCE(SUM(CASE WHEN e.is_paid = 0 THEN 1 ELSE 0 END), 0) AS unpaid_count,
        (
          SELECT e2.item_name
          FROM debt_entries e2
          WHERE e2.customer_id = c.id
          ORDER BY datetime(e2.entry_date) DESC, e2.id DESC
          LIMIT 1
        ) AS last_item_name,
        (
          SELECT e2.entry_date
          FROM debt_entries e2
          WHERE e2.customer_id = c.id
          ORDER BY datetime(e2.entry_date) DESC, e2.id DESC
          LIMIT 1
        ) AS last_entry_date
      FROM debt_customers c
      LEFT JOIN debt_entries e ON e.customer_id = c.id
      GROUP BY c.id
      ORDER BY total_due DESC, c.name COLLATE NOCASE ASC
    ''');

    return rows
        .map(
          (row) => DebtCustomerSummary(
            customer: DebtCustomer.fromMap(row),
            totalDue: (row['total_due'] as num?)?.toDouble() ?? 0,
            unpaidCount: row['unpaid_count'] as int? ?? 0,
            lastItemName: row['last_item_name'] as String?,
            lastEntryDate:
                row['last_entry_date'] == null
                    ? null
                    : DateTime.tryParse(row['last_entry_date'] as String),
          ),
        )
        .toList();
  }

  Future<DebtCustomerDetails?> getCustomerDetails(int customerId) async {
    final db = await _db.database;
    final customerRows = await db.query(
      'debt_customers',
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    if (customerRows.isEmpty) return null;

    final entryRows = await db.query(
      'debt_entries',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'datetime(entry_date) DESC, id DESC',
    );
    final entries = entryRows.map(DebtEntry.fromMap).toList();
    final totalDue = entries
        .where((entry) => !entry.isPaid)
        .fold<double>(0, (sum, entry) => sum + entry.amountDue);

    return DebtCustomerDetails(
      customer: DebtCustomer.fromMap(customerRows.first),
      entries: entries,
      totalDue: totalDue,
    );
  }

  Future<DebtCustomer> saveCustomer(DebtCustomer customer) async {
    final db = await _db.database;
    final normalizedPhone = customer.phone.trim();
    final existing = await db.query(
      'debt_customers',
      where: 'phone = ? AND (? IS NULL OR id != ?)',
      whereArgs: [normalizedPhone, customer.id, customer.id],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw const AppException('This phone number is already linked to another customer');
    }

    if (customer.id == null) {
      final id = await db.insert('debt_customers', {
        ...customer.toMap(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      return customer.copyWith(id: id);
    }

    await db.update(
      'debt_customers',
      {
        ...customer.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [customer.id],
    );
    return customer;
  }

  Future<void> addDebtEntry(DebtEntry entry) async {
    if (entry.amountDue <= 0) {
      throw const ValidationException('Debt amount must be greater than zero');
    }
    final db = await _db.database;
    await db.insert('debt_entries', {
      ...entry.toMap(),
      'entry_date': DateTime.now().toIso8601String(),
    });
  }

  Future<void> toggleEntryPaid(int entryId, bool isPaid) async {
    final db = await _db.database;
    await db.update(
      'debt_entries',
      {'is_paid': isPaid ? 1 : 0},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  Future<void> deleteEntry(int entryId) async {
    final db = await _db.database;
    await db.delete('debt_entries', where: 'id = ?', whereArgs: [entryId]);
  }
}
