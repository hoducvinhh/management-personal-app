import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../constants/default_categories.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // If running on desktop (Windows, Linux, macOS), use sqflite_common_ffi
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final appDocDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(appDocDir.path, 'ExpenseTracker', 'personal_expense_tracker.db');
      final file = File(dbPath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
    } else {
      final databasesPath = await getDatabasesPath();
      dbPath = p.join(databasesPath, 'personal_expense_tracker.db');
    }

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Create categories table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        icon_code TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Create transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');

    // 3. Create budgets table
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category_id TEXT,
        month_key TEXT NOT NULL,
        limit_amount REAL NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');

    // 4. Create Indexes as specified in plan.md
    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_transactions_category ON transactions(category_id)');
    await db.execute('CREATE INDEX idx_transactions_type_date ON transactions(type, date)');
    await db.execute('CREATE INDEX idx_budgets_month ON budgets(month_key)');

    // 5. Seed default categories via single batch
    final batch = db.batch();
    for (final cat in DefaultCategories.all) {
      batch.insert('categories', {
        'id': cat.id,
        'name': cat.name,
        'type': cat.type,
        'icon_code': cat.iconCode,
        'color_hex': cat.colorHex,
        'is_default': 1,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
