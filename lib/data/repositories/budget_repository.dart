import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/date_utils.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';

class BudgetRepository {
  final AppDatabase _dbHelper;
  static const _uuid = Uuid();

  BudgetRepository([AppDatabase? dbHelper])
      : _dbHelper = dbHelper ?? AppDatabase.instance;

  Future<BudgetModel?> getOverallBudget(String monthKey) async {
    final db = await _dbHelper.database;
    final monthDate = AppDateUtils.fromMonthKey(monthKey);
    final startDate = AppDateUtils.startOfMonth(monthDate).toIso8601String();
    final endDate = AppDateUtils.endOfMonth(monthDate).toIso8601String();

    // Single atomic query: fetches budget limit and spent amount simultaneously
    final query = '''
      SELECT 
        b.id, b.category_id, b.month_key, b.limit_amount,
        (
          SELECT COALESCE(SUM(amount), 0.0) 
          FROM transactions 
          WHERE type = 'EXPENSE' AND date >= ? AND date <= ?
        ) as spent_amount
      FROM budgets b
      WHERE b.month_key = ? AND (b.category_id IS NULL OR b.category_id = '')
      LIMIT 1
    ''';

    final results = await db.rawQuery(query, [startDate, endDate, monthKey]);
    if (results.isEmpty) return null;

    final spent = (results.first['spent_amount'] as num?)?.toDouble() ?? 0.0;
    return BudgetModel.fromMap(results.first, spentAmount: spent);
  }

  Future<List<BudgetModel>> getCategoryBudgets(String monthKey) async {
    final db = await _dbHelper.database;
    final monthDate = AppDateUtils.fromMonthKey(monthKey);
    final startDate = AppDateUtils.startOfMonth(monthDate).toIso8601String();
    final endDate = AppDateUtils.endOfMonth(monthDate).toIso8601String();

    // Single optimized query with indexed LEFT JOIN & GROUP BY:
    // Computes spent per category on SQLite engine level without loading extra records
    final query = '''
      SELECT 
        b.id, b.category_id, b.month_key, b.limit_amount,
        c.name as category_name, c.type as category_type, 
        c.icon_code as category_icon_code, c.color_hex as category_color_hex, 
        c.is_default as category_is_default,
        COALESCE(SUM(t.amount), 0.0) as spent_amount
      FROM budgets b
      JOIN categories c ON b.category_id = c.id
      LEFT JOIN transactions t ON t.category_id = b.category_id 
        AND t.type = 'EXPENSE' 
        AND t.date >= ? AND t.date <= ?
      WHERE b.month_key = ? AND b.category_id IS NOT NULL AND b.category_id != ''
      GROUP BY b.id
      ORDER BY b.limit_amount DESC
    ''';

    final results = await db.rawQuery(query, [startDate, endDate, monthKey]);

    return results.map((row) {
      final category = CategoryModel(
        id: row['category_id'] as String,
        name: row['category_name'] as String,
        type: row['category_type'] as String,
        iconCode: row['category_icon_code'] as String,
        colorHex: row['category_color_hex'] as String,
        isDefault: (row['category_is_default'] as int? ?? 0) == 1,
      );
      final spent = (row['spent_amount'] as num?)?.toDouble() ?? 0.0;
      return BudgetModel.fromMap(row, spentAmount: spent, category: category);
    }).toList();
  }

  Future<void> setBudget({
    String? categoryId,
    required String monthKey,
    required double limitAmount,
  }) async {
    final db = await _dbHelper.database;
    final cleanCatId = (categoryId != null && categoryId.isNotEmpty) ? categoryId : null;

    final existing = await db.query(
      'budgets',
      columns: ['id'],
      where: cleanCatId == null
          ? "month_key = ? AND (category_id IS NULL OR category_id = '')"
          : 'month_key = ? AND category_id = ?',
      whereArgs: cleanCatId == null ? [monthKey] : [monthKey, cleanCatId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.update(
        'budgets',
        {'limit_amount': limitAmount},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('budgets', {
        'id': _uuid.v4(),
        'category_id': cleanCatId,
        'month_key': monthKey,
        'limit_amount': limitAmount,
      });
    }
  }

  Future<void> deleteBudget(String id) async {
    final db = await _dbHelper.database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }
}
