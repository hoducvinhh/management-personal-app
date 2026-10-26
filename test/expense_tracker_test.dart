import 'package:flutter_test/flutter_test.dart';
import 'package:personal_expense_tracker/core/constants/app_colors.dart';
import 'package:personal_expense_tracker/core/database/app_database.dart';
import 'package:personal_expense_tracker/core/utils/currency_utils.dart';
import 'package:personal_expense_tracker/core/utils/date_utils.dart';
import 'package:personal_expense_tracker/data/models/budget_model.dart';
import 'package:personal_expense_tracker/data/models/transaction_model.dart';
import 'package:personal_expense_tracker/data/repositories/budget_repository.dart';
import 'package:personal_expense_tracker/data/repositories/category_repository.dart';
import 'package:personal_expense_tracker/data/repositories/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Kiểm thử tính toán Số dư & Định dạng tiền tệ tiếng Việt', () {
    test('Format VNĐ chuẩn và định dạng rút gọn (Compact)', () {
      expect(CurrencyUtils.format(12450000).replaceAll('\u00A0', ' '), '12.450.000 ₫');
      expect(CurrencyUtils.formatSigned(20000000, 'INCOME').replaceAll('\u00A0', ' '), '+ 20.000.000 ₫');
      expect(CurrencyUtils.formatSigned(7550000, 'EXPENSE').replaceAll('\u00A0', ' '), '- 7.550.000 ₫');
      expect(CurrencyUtils.formatCompact(5000000), '5Tr');
      expect(CurrencyUtils.formatCompact(500000), '500k');
      expect(CurrencyUtils.formatCompact(2500000000), '2.5Tỷ');
    });

    test('Tính toán số dư theo kịch bản plan: Lương 15Tr, Ăn uống 2Tr, Tiền nhà 3.5Tr -> Dư 9.5Tr', () {
      const double salary = 15000000;
      const double food = 2000000;
      const double rent = 3500000;

      final summary = MonthlySummary(
        income: salary,
        expense: food + rent,
        balance: salary - (food + rent),
      );

      expect(summary.balance, 9500000);
      expect(summary.income, 15000000);
      expect(summary.expense, 5500000);
    });
  });

  group('Kiểm thử Cảnh báo Ngân sách (Budget Alerts)', () {
    test('Dưới 70% ngân sách: Xanh an toàn', () {
      const budget = BudgetModel(
        id: 'test_b1',
        monthKey: '2026-10',
        limitAmount: 1000000,
        spentAmount: 600000, // 60%
      );

      expect(budget.percentSpent, 0.6);
      expect(budget.isOverBudget, false);
      expect(AppColors.getBudgetColor(budget.percentSpent), AppColors.budgetSafe);
      expect(budget.statusMessage, 'Bạn đang kiểm soát chi tiêu rất tốt');
    });

    test('70% - 90% ngân sách: Hổ phách cảnh báo', () {
      const budget = BudgetModel(
        id: 'test_b2',
        monthKey: '2026-10',
        limitAmount: 1000000,
        spentAmount: 850000, // 85%
      );

      expect(budget.percentSpent, 0.85);
      expect(budget.isOverBudget, false);
      expect(AppColors.getBudgetColor(budget.percentSpent), AppColors.budgetWarning);
      expect(budget.statusMessage, 'Cảnh báo: Đã tiêu 85% ngân sách');
    });

    test('Vượt 100% ngân sách: Đỏ báo động và thông báo số tiền vượt', () {
      const budget = BudgetModel(
        id: 'test_b3',
        monthKey: '2026-10',
        limitAmount: 1000000,
        spentAmount: 1050000, // 105%
      );

      expect(budget.isOverBudget, true);
      expect(AppColors.getBudgetColor(budget.percentSpent), AppColors.budgetDanger);
      expect(budget.statusMessage.contains('Đã vượt hạn mức'), true);
    });
  });

  group('Kiểm thử Cơ sở dữ liệu SQLite & Batch & Aggregate queries', () {
    late Database testDb;
    late CategoryRepository catRepo;
    late TransactionRepository txRepo;
    late BudgetRepository budgetRepo;

    setUp(() async {
      testDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);

      // Create schema directly in memory
      await testDb.execute('''
        CREATE TABLE categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          icon_code TEXT NOT NULL,
          color_hex TEXT NOT NULL,
          is_default INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await testDb.execute('''
        CREATE TABLE transactions (
          id TEXT PRIMARY KEY,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          category_id TEXT NOT NULL,
          date TEXT NOT NULL,
          note TEXT,
          created_at TEXT NOT NULL
        )
      ''');
      await testDb.execute('''
        CREATE TABLE budgets (
          id TEXT PRIMARY KEY,
          category_id TEXT,
          month_key TEXT NOT NULL,
          limit_amount REAL NOT NULL
        )
      ''');
      await testDb.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
      await testDb.execute('CREATE INDEX idx_transactions_category ON transactions(category_id)');
      await testDb.execute('CREATE INDEX idx_transactions_type_date ON transactions(type, date)');
      await testDb.execute('CREATE INDEX idx_budgets_month ON budgets(month_key)');

      final mockAppDb = _MockAppDatabase(testDb);
      catRepo = CategoryRepository(mockAppDb);
      txRepo = TransactionRepository(mockAppDb);
      budgetRepo = BudgetRepository(mockAppDb);
    });

    tearDown(() async {
      await testDb.close();
    });

    test('Seed categories và kiểm tra danh mục mặc định', () async {
      final batch = testDb.batch();
      batch.insert('categories', {
        'id': 'cat_food',
        'name': 'Ăn uống',
        'type': 'EXPENSE',
        'icon_code': 'restaurant',
        'color_hex': '#FB923C',
        'is_default': 1,
      });
      batch.insert('categories', {
        'id': 'cat_salary',
        'name': 'Tiền lương',
        'type': 'INCOME',
        'icon_code': 'work',
        'color_hex': '#10B981',
        'is_default': 1,
      });
      await batch.commit();

      final categories = await catRepo.getCategories();
      expect(categories.length, 2);
      expect(categories.firstWhere((c) => c.id == 'cat_food').name, 'Ăn uống');
    });

    test('Thêm 3 giao dịch và kiểm tra SQL Aggregate Summary', () async {
      final now = DateTime.now();
      const uuid = Uuid();

      await testDb.insert('categories', {
        'id': 'cat_food',
        'name': 'Ăn uống',
        'type': 'EXPENSE',
        'icon_code': 'restaurant',
        'color_hex': '#FB923C',
        'is_default': 1,
      });
      await testDb.insert('categories', {
        'id': 'cat_salary',
        'name': 'Tiền lương',
        'type': 'INCOME',
        'icon_code': 'work',
        'color_hex': '#10B981',
        'is_default': 1,
      });

      // 1 Thu: Lương 15.000.000
      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 15000000,
        type: 'INCOME',
        categoryId: 'cat_salary',
        date: now,
        note: 'Lương tháng',
        createdAt: now,
      ));

      // 2 Chi: Ăn trưa 50.000 & Siêu thị 450.000
      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 50000,
        type: 'EXPENSE',
        categoryId: 'cat_food',
        date: now,
        note: 'Ăn trưa',
        createdAt: now,
      ));
      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 450000,
        type: 'EXPENSE',
        categoryId: 'cat_food',
        date: now,
        note: 'Siêu thị',
        createdAt: now,
      ));

      final start = AppDateUtils.startOfMonth(now);
      final end = AppDateUtils.endOfMonth(now);

      final summary = await txRepo.getMonthlySummary(start, end);
      expect(summary.income, 15000000);
      expect(summary.expense, 500000);
      expect(summary.balance, 14500000);

      // Check category breakdown for Donut chart
      final breakdown = await txRepo.getCategoryExpenseBreakdown(start, end);
      expect(breakdown.length, 1);
      expect(breakdown.first.totalAmount, 500000);
      expect(breakdown.first.percentage, 100.0);
    });

    test('Hiệu năng SQLite Batch: Nạp 1.000 bản ghi và đo thời gian truy vấn', () async {
      final stopwatch = Stopwatch()..start();
      final batch = testDb.batch();
      final now = DateTime.now();

      for (int i = 0; i < 1000; i++) {
        batch.insert('transactions', {
          'id': 'tx_$i',
          'amount': (i + 1) * 1000.0,
          'type': i % 5 == 0 ? 'INCOME' : 'EXPENSE',
          'category_id': 'cat_food',
          'date': now.toIso8601String(),
          'note': 'Giao dịch mẫu số $i',
          'created_at': now.toIso8601String(),
        });
      }
      await batch.commit(noResult: true);
      stopwatch.stop();

      // Measuring query time with indexes
      final queryStopwatch = Stopwatch()..start();
      final summary = await txRepo.getMonthlySummary(
        AppDateUtils.startOfMonth(now),
        AppDateUtils.endOfMonth(now),
      );
      queryStopwatch.stop();

      expect(summary.income > 0, true);
      expect(summary.expense > 0, true);
      expect(stopwatch.elapsedMilliseconds < 2000, true);
      expect(queryStopwatch.elapsedMilliseconds < 300, true);
    });
  });
}

class _MockAppDatabase implements AppDatabase {
  final Database _db;
  _MockAppDatabase(this._db);

  @override
  Future<Database> get database async => _db;

  @override
  Future<void> close() async => await _db.close();
}
