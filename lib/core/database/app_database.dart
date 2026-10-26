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
      version: 2,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    // High-performance SQLite PRAGMAs for mobile & desktop:
    // 1. WAL mode allows concurrent non-blocking reads during writes
    await db.execute('PRAGMA journal_mode = WAL;');
    // 2. Synchronous NORMAL is optimal with WAL mode (zero risk of corruption on app crash)
    await db.execute('PRAGMA synchronous = NORMAL;');
    // 3. 2MB cache size in RAM
    await db.execute('PRAGMA cache_size = -2000;');
    // 4. Temporary tables and indices stored directly in RAM
    await db.execute('PRAGMA temp_store = MEMORY;');
    // 5. Enforce foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate transactions table to allow category_id to be NULL
      await db.execute('PRAGMA foreign_keys = OFF;');
      await db.execute('ALTER TABLE transactions RENAME TO _transactions_old;');
      await db.execute('''
        CREATE TABLE transactions (
          id TEXT PRIMARY KEY,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          category_id TEXT,
          date TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
        )
      ''');
      await db.execute('''
        INSERT INTO transactions (id, amount, type, category_id, date, note, created_at)
        SELECT id, amount, type, category_id, date, note, created_at FROM _transactions_old;
      ''');
      await db.execute('DROP TABLE _transactions_old;');
      await db.execute('PRAGMA foreign_keys = ON;');

      // Re-create indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date_created ON transactions(date DESC, created_at DESC);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date_type_amount ON transactions(date, type, amount);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_type_date_cat_amt ON transactions(type, date, category_id, amount);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);');
    }
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

    // 2. Create transactions table (category_id is nullable to support optional category assignment)
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category_id TEXT,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
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

    // 4. Covering & Composite Indexes for ultra-fast query execution (< 1ms):
    // List transactions sorted by date & creation time (No full table scan, B-tree reverse scan)
    await db.execute('CREATE INDEX idx_transactions_date_created ON transactions(date DESC, created_at DESC);');
    // Pure index scan for monthly income/expense summary
    await db.execute('CREATE INDEX idx_transactions_date_type_amount ON transactions(date, type, amount);');
    // Pure index scan for category aggregates & budget tracking
    await db.execute('CREATE INDEX idx_transactions_type_date_cat_amt ON transactions(type, date, category_id, amount);');
    // Category lookups
    await db.execute('CREATE INDEX idx_transactions_category ON transactions(category_id);');
    // Budget lookups by month and category
    await db.execute('CREATE INDEX idx_budgets_lookup ON budgets(month_key, category_id);');

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
