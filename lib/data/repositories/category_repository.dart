import '../../core/database/app_database.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final AppDatabase _dbHelper;

  CategoryRepository([AppDatabase? dbHelper])
      : _dbHelper = dbHelper ?? AppDatabase.instance;

  Future<List<CategoryModel>> getCategories({String? type}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps;
    if (type != null) {
      maps = await db.query(
        'categories',
        where: 'type = ?',
        whereArgs: [type],
        orderBy: 'is_default DESC, name ASC',
      );
    } else {
      maps = await db.query(
        'categories',
        orderBy: 'type DESC, is_default DESC, name ASC',
      );
    }
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<CategoryModel?> getCategoryById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CategoryModel.fromMap(maps.first);
  }

  Future<void> insertCategory(CategoryModel category) async {
    final db = await _dbHelper.database;
    await db.insert('categories', category.toMap());
  }

  Future<void> updateCategory(CategoryModel category) async {
    final db = await _dbHelper.database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'categories',
      where: 'id = ? AND is_default = 0',
      whereArgs: [id],
    );
  }
}
