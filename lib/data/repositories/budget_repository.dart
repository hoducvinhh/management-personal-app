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
    final results = await db.query(
      'budgets',
      where: 'month_key = ? AND (category_id IS NULL OR category_id = "")',
      whereArgs: [monthKey],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final monthDate = AppDateUtils.fromMonthKey(monthKey);
    final startDate = AppDateUtils.startOfMonth(monthDate);
    final endDate = AppDateUtils.endOfMonth(monthDate);

    // Calculate total spent in month
    final spentResult = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE type = 'EXPENSE' AND date >= ? AND date <= ?
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    final spent = (spentResult.first['total'] as num?)?.toDouble() ?? 0.0;
    return BudgetModel.fromMap(results.first, spentAmount: spent);
  }

  Future<List<BudgetModel>> getCategoryBudgets(String monthKey) async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT 
        b.id, b.category_id, b.month_key, b.limit_amount,
        c.name as category_name, c.type as category_type, 
        c.icon_code as category_icon_code, c.color_hex as category_color_hex, 
        c.is_default as category_is_default
      FROM budgets b
      JOIN categories c ON b.category_id = c.id
      WHERE b.month_key = ? AND b.category_id IS NOT NULL AND b.category_id != ""
      ORDER BY b.limit_amount DESC
    ''', [monthKey]);

    final monthDate = AppDateUtils.fromMonthKey(monthKey);
    final startDate = AppDateUtils.startOfMonth(monthDate);
    final endDate = AppDateUtils.endOfMonth(monthDate);

    // Query spent per category
    final spentRows = await db.rawQuery('''
      SELECT category_id, SUM(amount) as total
      FROM transactions
      WHERE type = 'EXPENSE' AND date >= ? AND date <= ?
      GROUP BY category_id
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    final Map<String, double> categorySpentMap = {};
    for (final row in spentRows) {
      final catId = row['category_id'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      categorySpentMap[catId] = total;
    }

    return results.map((row) {
      final catId = row['category_id'] as String;
      final category = CategoryModel(
        id: catId,
        name: row['category_name'] as String,
        type: row['category_type'] as String,
        iconCode: row['category_icon_code'] as String,
        colorHex: row['category_color_hex'] as String,
        isDefault: (row['category_is_default'] as int? ?? 0) == 1,
      );
      final spent = categorySpentMap[catId] ?? 0.0;
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
      where: cleanCatId == null
          ? 'month_key = ? AND (category_id IS NULL OR category_id = "")'
          : 'month_key = ? AND category_id = ?',
      whereArgs: cleanCatId == null ? [monthKey] : [monthKey, cleanCatId],
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
