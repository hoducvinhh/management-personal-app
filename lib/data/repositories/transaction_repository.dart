import '../../core/database/app_database.dart';
import '../../core/utils/date_utils.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class MonthlySummary {
  final double income;
  final double expense;
  final double balance;

  const MonthlySummary({
    required this.income,
    required this.expense,
    required this.balance,
  });

  factory MonthlySummary.zero() =>
      const MonthlySummary(income: 0.0, expense: 0.0, balance: 0.0);
}

class CategoryExpenseItem {
  final CategoryModel category;
  final double totalAmount;
  final double percentage;

  const CategoryExpenseItem({
    required this.category,
    required this.totalAmount,
    required this.percentage,
  });
}

class MonthTrendItem {
  final String monthKey; // '2026-10'
  final String label; // 'T10'
  final double income;
  final double expense;
  final double savings;

  const MonthTrendItem({
    required this.monthKey,
    required this.label,
    required this.income,
    required this.expense,
    required this.savings,
  });
}

class TransactionRepository {
  final AppDatabase _dbHelper;

  TransactionRepository([AppDatabase? dbHelper])
      : _dbHelper = dbHelper ?? AppDatabase.instance;

  Future<List<TransactionModel>> getTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? categoryId,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('t.date >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('t.date <= ?');
      whereArgs.add(endDate.toIso8601String());
    }
    if (type != null && type.isNotEmpty && type != 'ALL') {
      whereClauses.add('t.type = ?');
      whereArgs.add(type);
    }
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'ALL') {
      whereClauses.add('t.category_id = ?');
      whereArgs.add(categoryId);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      // Search in note, category name, or exact amount match
      whereClauses.add('(t.note LIKE ? OR c.name LIKE ? OR CAST(t.amount AS TEXT) LIKE ?)');
      whereArgs.addAll([q, q, q]);
    }

    final whereString =
        whereClauses.isNotEmpty ? 'WHERE ${whereClauses.join(' AND ')}' : '';
    final limitString = limit != null ? 'LIMIT $limit' : '';
    final offsetString = offset != null ? 'OFFSET $offset' : '';

    final query = '''
      SELECT 
        t.id, t.amount, t.type, t.category_id, t.date, t.note, t.created_at,
        c.name as category_name, c.type as category_type, 
        c.icon_code as category_icon_code, c.color_hex as category_color_hex, 
        c.is_default as category_is_default
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      $whereString
      ORDER BY t.date DESC, t.created_at DESC
      $limitString $offsetString
    ''';

    final maps = await db.rawQuery(query, whereArgs);
    return maps.map((m) => TransactionModel.fromMap(m)).toList();
  }

  Future<MonthlySummary> getMonthlySummary(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT type, SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date <= ?
      GROUP BY type
    ''';

    final results = await db.rawQuery(query, [
      start.toIso8601String(),
      end.toIso8601String(),
    ]);

    double income = 0.0;
    double expense = 0.0;

    for (final row in results) {
      final type = row['type'] as String?;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      if (type == 'INCOME') {
        income = total;
      } else if (type == 'EXPENSE') {
        expense = total;
      }
    }

    return MonthlySummary(
      income: income,
      expense: expense,
      balance: income - expense,
    );
  }

  Future<List<CategoryExpenseItem>> getCategoryExpenseBreakdown(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        c.id, c.name, c.type, c.icon_code, c.color_hex, c.is_default,
        SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'EXPENSE' AND t.date >= ? AND t.date <= ?
      GROUP BY c.id
      ORDER BY total DESC
    ''';

    final results = await db.rawQuery(query, [
      start.toIso8601String(),
      end.toIso8601String(),
    ]);

    double grandTotal = 0.0;
    for (final row in results) {
      grandTotal += (row['total'] as num?)?.toDouble() ?? 0.0;
    }

    if (grandTotal == 0.0) return [];

    return results.map((row) {
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      final category = CategoryModel(
        id: row['id'] as String,
        name: row['name'] as String,
        type: row['type'] as String,
        iconCode: row['icon_code'] as String,
        colorHex: row['color_hex'] as String,
        isDefault: (row['is_default'] as int? ?? 0) == 1,
      );
      final percentage = grandTotal > 0 ? (total / grandTotal) * 100 : 0.0;
      return CategoryExpenseItem(
        category: category,
        totalAmount: total,
        percentage: percentage,
      );
    }).toList();
  }

  Future<List<MonthTrendItem>> getMonthlyTrends({
    required DateTime currentMonth,
    int monthsCount = 6,
  }) async {
    final db = await _dbHelper.database;
    final months = <DateTime>[];

    for (int i = monthsCount - 1; i >= 0; i--) {
      months.add(DateTime(currentMonth.year, currentMonth.month - i, 1));
    }

    final startDate = AppDateUtils.startOfMonth(months.first);
    final endDate = AppDateUtils.endOfMonth(months.last);

    final query = '''
      SELECT 
        strftime('%Y-%m', date) as m_key,
        type,
        SUM(amount) as total
      FROM transactions
      WHERE date >= ? AND date <= ?
      GROUP BY m_key, type
    ''';

    final results = await db.rawQuery(query, [
      startDate.toIso8601String(),
      endDate.toIso8601String(),
    ]);

    final Map<String, Map<String, double>> grouped = {};
    for (final row in results) {
      final mKey = row['m_key'] as String;
      final type = row['type'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      grouped.putIfAbsent(mKey, () => {'INCOME': 0.0, 'EXPENSE': 0.0});
      grouped[mKey]![type] = total;
    }

    return months.map((m) {
      final mKey = AppDateUtils.toMonthKey(m);
      final income = grouped[mKey]?['INCOME'] ?? 0.0;
      final expense = grouped[mKey]?['EXPENSE'] ?? 0.0;
      return MonthTrendItem(
        monthKey: mKey,
        label: 'T${m.month}',
        income: income,
        expense: expense,
        savings: income - expense,
      );
    }).toList();
  }

  Future<void> insertTransaction(TransactionModel transaction) async {
    final db = await _dbHelper.database;
    await db.insert('transactions', transaction.toMap());
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await _dbHelper.database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<TransactionModel?> getTransactionById(String id) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        t.id, t.amount, t.type, t.category_id, t.date, t.note, t.created_at,
        c.name as category_name, c.type as category_type, 
        c.icon_code as category_icon_code, c.color_hex as category_color_hex, 
        c.is_default as category_is_default
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.id = ?
      LIMIT 1
    ''';
    final results = await db.rawQuery(query, [id]);
    if (results.isEmpty) return null;
    return TransactionModel.fromMap(results.first);
  }
}
