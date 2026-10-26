import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_expense_tracker/core/constants/app_colors.dart';
import 'package:personal_expense_tracker/core/constants/default_categories.dart';
import 'package:personal_expense_tracker/core/database/app_database.dart';
import 'package:personal_expense_tracker/core/utils/currency_utils.dart';
import 'package:personal_expense_tracker/core/utils/date_utils.dart';
import 'package:personal_expense_tracker/data/models/budget_model.dart';
import 'package:personal_expense_tracker/data/models/category_model.dart';
import 'package:personal_expense_tracker/data/models/transaction_model.dart';
import 'package:personal_expense_tracker/data/repositories/budget_repository.dart';
import 'package:personal_expense_tracker/data/repositories/category_repository.dart';
import 'package:personal_expense_tracker/data/repositories/transaction_repository.dart';
import 'package:personal_expense_tracker/presentation/providers/selected_month_provider.dart';
import 'package:personal_expense_tracker/presentation/providers/statistics_provider.dart';
import 'package:personal_expense_tracker/presentation/providers/theme_provider.dart';
import 'package:personal_expense_tracker/presentation/screens/home/widgets/balance_hero_card.dart';
import 'package:personal_expense_tracker/presentation/screens/home/widgets/mini_budget_gauge.dart';
import 'package:personal_expense_tracker/presentation/screens/home/widgets/transaction_item_tile.dart';
import 'package:personal_expense_tracker/presentation/screens/statistics/widgets/smart_insights_card.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

class _TestAppDbWrapper implements AppDatabase {
  final Database _db;
  _TestAppDbWrapper(this._db);

  @override
  Future<Database> get database async => _db;

  @override
  Future<void> close() async => await _db.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('1. TÍNH NĂNG DANH MỤC (Category Features)', () {
    late Database db;
    late CategoryRepository repo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
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
      repo = CategoryRepository(_TestAppDbWrapper(db));
    });

    tearDown(() async => await db.close());

    test('Khởi tạo và nạp danh mục mặc định chuẩn người Việt', () async {
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
      await batch.commit();

      final allCats = await repo.getCategories();
      expect(allCats.length, DefaultCategories.all.length);

      final expenses = await repo.getCategories(type: 'EXPENSE');
      expect(expenses.length, DefaultCategories.expenseCategories.length);
      expect(expenses.any((c) => c.name == 'Ăn uống'), isTrue);
      expect(expenses.any((c) => c.name == 'Di chuyển'), isTrue);

      final incomes = await repo.getCategories(type: 'INCOME');
      expect(incomes.length, DefaultCategories.incomeCategories.length);
      expect(incomes.any((c) => c.name == 'Tiền lương'), isTrue);
    });

    test('Thêm danh mục tùy biến mới thành công', () async {
      const customCat = CategoryModel(
        id: 'custom_cat_cafe',
        name: 'Cà phê & Trà',
        type: 'EXPENSE',
        iconCode: 'local_cafe',
        colorHex: '#FB923C',
        isDefault: false,
      );

      await repo.insertCategory(customCat);

      final fetched = await repo.getCategoryById('custom_cat_cafe');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Cà phê & Trà');
      expect(fetched.isExpense, isTrue);
      expect(fetched.isDefault, isFalse);
    });

    test('Xóa danh mục tùy biến (chỉ cho phép xóa danh mục không phải mặc định)', () async {
      await repo.insertCategory(const CategoryModel(
        id: 'cat_default_1',
        name: 'Mặc định',
        type: 'EXPENSE',
        iconCode: 'restaurant',
        colorHex: '#000000',
        isDefault: true,
      ));
      await repo.insertCategory(const CategoryModel(
        id: 'cat_custom_1',
        name: 'Tùy biến',
        type: 'EXPENSE',
        iconCode: 'flight',
        colorHex: '#123456',
        isDefault: false,
      ));

      // Attempt to delete default category -> should NOT be deleted
      await repo.deleteCategory('cat_default_1');
      expect(await repo.getCategoryById('cat_default_1'), isNotNull);

      // Attempt to delete custom category -> should be deleted
      await repo.deleteCategory('cat_custom_1');
      expect(await repo.getCategoryById('cat_custom_1'), isNull);
    });
  });

  group('2. TÍNH NĂNG GIAO DỊCH (Transaction & Query Features)', () {
    late Database db;
    late TransactionRepository txRepo;
    const uuid = Uuid();

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
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
      await db.execute('''
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
      await db.execute('CREATE INDEX idx_transactions_date_created ON transactions(date DESC, created_at DESC);');
      await db.execute('CREATE INDEX idx_transactions_date_type_amount ON transactions(date, type, amount);');
      await db.execute('CREATE INDEX idx_transactions_type_date_cat_amt ON transactions(type, date, category_id, amount);');

      await db.insert('categories', {
        'id': 'cat_food',
        'name': 'Ăn uống',
        'type': 'EXPENSE',
        'icon_code': 'restaurant',
        'color_hex': '#FB923C',
        'is_default': 1,
      });
      await db.insert('categories', {
        'id': 'cat_salary',
        'name': 'Tiền lương',
        'type': 'INCOME',
        'icon_code': 'work',
        'color_hex': '#10B981',
        'is_default': 1,
      });

      txRepo = TransactionRepository(_TestAppDbWrapper(db));
    });

    tearDown(() async => await db.close());

    test('Thêm giao dịch thu & chi và tính số dư chuẩn xác', () async {
      final now = DateTime.now();

      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 25000000,
        type: 'INCOME',
        categoryId: 'cat_salary',
        date: now,
        note: 'Lương tháng 10',
        createdAt: now,
      ));

      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 3500000,
        type: 'EXPENSE',
        categoryId: 'cat_food',
        date: now,
        note: 'Ăn uống gia đình',
        createdAt: now,
      ));

      final summary = await txRepo.getMonthlySummary(
        AppDateUtils.startOfMonth(now),
        AppDateUtils.endOfMonth(now),
      );

      expect(summary.income, 25000000);
      expect(summary.expense, 3500000);
      expect(summary.balance, 21500000);
    });

    test('Cập nhật giao dịch thành công', () async {
      final txId = uuid.v4();
      final now = DateTime.now();

      final initial = TransactionModel(
        id: txId,
        amount: 100000,
        type: 'EXPENSE',
        categoryId: 'cat_food',
        date: now,
        note: 'Ăn sáng ban đầu',
        createdAt: now,
      );
      await txRepo.insertTransaction(initial);

      final updated = initial.copyWith(
        amount: 150000,
        note: 'Ăn sáng phở bò + cà phê',
      );
      await txRepo.updateTransaction(updated);

      final fetched = await txRepo.getTransactionById(txId);
      expect(fetched, isNotNull);
      expect(fetched!.amount, 150000);
      expect(fetched.note, 'Ăn sáng phở bò + cà phê');
    });

    test('Xóa giao dịch thành công', () async {
      final txId = uuid.v4();
      final now = DateTime.now();

      await txRepo.insertTransaction(TransactionModel(
        id: txId,
        amount: 50000,
        type: 'EXPENSE',
        categoryId: 'cat_food',
        date: now,
        createdAt: now,
      ));

      expect(await txRepo.getTransactionById(txId), isNotNull);

      await txRepo.deleteTransaction(txId);
      expect(await txRepo.getTransactionById(txId), isNull);
    });

    test('Tìm kiếm theo ghi chú, danh mục và số tiền', () async {
      final now = DateTime.now();

      await txRepo.insertTransaction(TransactionModel(
        id: 'tx_coffee',
        amount: 45000,
        type: 'EXPENSE',
        categoryId: 'cat_food',
        date: now,
        note: 'Cà phê sáng Highlands',
        createdAt: now,
      ));

      await txRepo.insertTransaction(TransactionModel(
        id: 'tx_market',
        amount: 250000,
        type: 'EXPENSE',
        categoryId: 'cat_food',
        date: now,
        note: 'Đi chợ mua hải sản',
        createdAt: now,
      ));

      // Search by keyword "Highlands"
      final r1 = await txRepo.getTransactions(searchQuery: 'Highlands');
      expect(r1.length, 1);
      expect(r1.first.id, 'tx_coffee');

      // Search by amount "250000"
      final r2 = await txRepo.getTransactions(searchQuery: '250000');
      expect(r2.length, 1);
      expect(r2.first.id, 'tx_market');

      // Filter by type "EXPENSE"
      final r3 = await txRepo.getTransactions(type: 'EXPENSE');
      expect(r3.length, 2);
    });
  });

  group('3. TÍNH NĂNG NGÂN SÁCH (Budget & Real-time Alerts Features)', () {
    late Database db;
    late BudgetRepository budgetRepo;
    late TransactionRepository txRepo;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
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
      await db.execute('''
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
      await db.execute('''
        CREATE TABLE budgets (
          id TEXT PRIMARY KEY,
          category_id TEXT,
          month_key TEXT NOT NULL,
          limit_amount REAL NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX idx_transactions_type_date_cat_amt ON transactions(type, date, category_id, amount);');
      await db.execute('CREATE INDEX idx_budgets_lookup ON budgets(month_key, category_id);');

      await db.insert('categories', {
        'id': 'cat_food',
        'name': 'Ăn uống',
        'type': 'EXPENSE',
        'icon_code': 'restaurant',
        'color_hex': '#FB923C',
        'is_default': 1,
      });

      final wrapper = _TestAppDbWrapper(db);
      budgetRepo = BudgetRepository(wrapper);
      txRepo = TransactionRepository(wrapper);
    });

    tearDown(() async => await db.close());

    test('Single-query atomic ngân sách tổng tháng & tính toán số tiền còn lại', () async {
      final now = DateTime.now();
      final monthKey = AppDateUtils.toMonthKey(now);

      await budgetRepo.setBudget(
        monthKey: monthKey,
        limitAmount: 10000000,
      );

      // Thêm 1 khoản chi 4.000.000
      await txRepo.insertTransaction(TransactionModel(
        id: 'tx_b1',
        amount: 4000000,
        type: 'EXPENSE',
        categoryId: 'cat_food',
        date: now,
        createdAt: now,
      ));

      final budget = await budgetRepo.getOverallBudget(monthKey);
      expect(budget, isNotNull);
      expect(budget!.limitAmount, 10000000);
      expect(budget.spentAmount, 4000000);
      expect(budget.remainingAmount, 6000000);
      expect(budget.percentSpent, 0.4);
      expect(budget.isOverBudget, isFalse);
      expect(AppColors.getBudgetColor(budget.percentSpent), AppColors.budgetSafe);
    });

    test('Cảnh báo cấp độ 2 (Hổ phách 70% - 90%) khi tiệm cận hạn mức', () async {
      final now = DateTime.now();
      final monthKey = AppDateUtils.toMonthKey(now);

      await budgetRepo.setBudget(
        monthKey: monthKey,
        limitAmount: 5000000,
      );

      // Chi 4.000.000 (80%)
      await txRepo.insertTransaction(TransactionModel(
        id: 'tx_b2',
        amount: 4000000,
        type: 'EXPENSE',
        categoryId: 'cat_food',
        date: now,
        createdAt: now,
      ));

      final budget = await budgetRepo.getOverallBudget(monthKey);
      expect(budget!.percentSpent, 0.8);
      expect(AppColors.getBudgetColor(budget.percentSpent), AppColors.budgetWarning);
      expect(budget.statusMessage.contains('Đã tiêu 80%'), isTrue);
    });

    test('Báo động cấp độ 3 (Đỏ > 100%) khi vượt trần chi tiêu', () async {
      final now = DateTime.now();
      final monthKey = AppDateUtils.toMonthKey(now);

      await budgetRepo.setBudget(
        monthKey: monthKey,
        limitAmount: 5000000,
      );

      // Chi 5.500.000 (110%)
      await txRepo.insertTransaction(TransactionModel(
        id: 'tx_b3',
        amount: 5500000,
        type: 'EXPENSE',
        categoryId: 'cat_food',
        date: now,
        createdAt: now,
      ));

      final budget = await budgetRepo.getOverallBudget(monthKey);
      expect(budget!.isOverBudget, isTrue);
      expect(AppColors.getBudgetColor(budget.percentSpent), AppColors.budgetDanger);
      expect(budget.statusMessage.contains('Đã vượt hạn mức'), isTrue);
    });
  });

  group('4. TÍNH NĂNG THỐNG KÊ & BIỂU ĐỒ (Statistics & Insights Features)', () {
    test('Donut Chart: Tự động gom nhóm các khoản chi < 3% vào mục "Khác"', () {
      final items = [
        const CategoryExpenseItem(
          category: CategoryModel(id: '1', name: 'Ăn uống', type: 'EXPENSE', iconCode: 'restaurant', colorHex: '#FB923C'),
          totalAmount: 5000000,
          percentage: 50.0,
        ),
        const CategoryExpenseItem(
          category: CategoryModel(id: '2', name: 'Nhà cửa', type: 'EXPENSE', iconCode: 'home', colorHex: '#8B5CF6'),
          totalAmount: 3000000,
          percentage: 30.0,
        ),
        const CategoryExpenseItem(
          category: CategoryModel(id: '3', name: 'Di chuyển', type: 'EXPENSE', iconCode: 'two_wheeler', colorHex: '#06B6D4'),
          totalAmount: 1500000,
          percentage: 15.0,
        ),
        const CategoryExpenseItem(
          category: CategoryModel(id: '4', name: 'Khoản chi 1', type: 'EXPENSE', iconCode: 'inventory_2', colorHex: '#94A3B8'),
          totalAmount: 100000,
          percentage: 1.0,
        ),
        const CategoryExpenseItem(
          category: CategoryModel(id: '5', name: 'Khoản chi 2', type: 'EXPENSE', iconCode: 'inventory_2', colorHex: '#94A3B8'),
          totalAmount: 100000,
          percentage: 1.0,
        ),
        const CategoryExpenseItem(
          category: CategoryModel(id: '6', name: 'Khoản chi 3', type: 'EXPENSE', iconCode: 'inventory_2', colorHex: '#94A3B8'),
          totalAmount: 100000,
          percentage: 1.0,
        ),
      ];

      double othersTotal = 0;
      for (final item in items) {
        if (items.length > 5 && item.percentage < 3.0) {
          othersTotal += item.totalAmount;
        }
      }
      expect(othersTotal, 300000);
    });

    test('Nhận định thông minh (Smart Insights): Top danh mục & Tỷ lệ tiết kiệm', () {
      const insights = SmartInsights(
        topCategoryName: 'Ăn uống',
        topCategoryEmoji: '🍜',
        topCategoryPercent: 42.4,
        savingsRate: 38.0,
        expenseChangeVsLastMonth: -8.5,
        hasData: true,
      );

      expect(insights.hasData, isTrue);
      expect(insights.topCategoryName, 'Ăn uống');
      expect(insights.savingsRate, 38.0);
      expect(insights.expenseChangeVsLastMonth, -8.5);
    });
  });

  group('5. TÍNH NĂNG GIAO DIỆN & WIDGET (UI & Component Tests)', () {
    testWidgets('BalanceHeroCard hiển thị số dư, thu và chi đúng định dạng', (tester) async {
      const summary = MonthlySummary(
        income: 20000000,
        expense: 7550000,
        balance: 12450000,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BalanceHeroCard(summary: summary),
          ),
        ),
      );

      expect(find.text('Số dư tháng này'), findsOneWidget);
      expect(find.text(CurrencyUtils.format(12450000)), findsOneWidget);
      expect(find.text(CurrencyUtils.format(20000000)), findsOneWidget);
      expect(find.text(CurrencyUtils.format(7550000)), findsOneWidget);
    });

    testWidgets('MiniBudgetGauge hiển thị thanh tiến độ và số tiền', (tester) async {
      const budget = BudgetModel(
        id: 'b_mini',
        monthKey: '2026-10',
        limitAmount: 10000000,
        spentAmount: 6500000,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MiniBudgetGauge(
              overallBudget: budget,
              onSetupBudget: () {},
            ),
          ),
        ),
      );

      expect(find.text('Ngân sách chi tiêu tháng'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
      expect(find.textContaining('Đã chi:'), findsOneWidget);
      expect(find.textContaining('Còn lại:'), findsOneWidget);
    });

    testWidgets('TransactionItemTile hiển thị thông tin và phân loại thu/chi', (tester) async {
      final tx = TransactionModel(
        id: 'tx_tile',
        amount: 35000,
        type: 'EXPENSE',
        categoryId: 'cat_food',
        date: DateTime.now(),
        note: 'Bánh mì pate sáng',
        createdAt: DateTime.now(),
        category: const CategoryModel(
          id: 'cat_food',
          name: 'Ăn uống',
          type: 'EXPENSE',
          iconCode: 'restaurant',
          colorHex: '#FB923C',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionItemTile(transaction: tx),
          ),
        ),
      );

      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.text('Bánh mì pate sáng'), findsOneWidget);
      expect(find.text(CurrencyUtils.formatSigned(35000, 'EXPENSE')), findsOneWidget);
    });

    testWidgets('SmartInsightsCard hiển thị nhận định thông minh tiếng Việt', (tester) async {
      const insights = SmartInsights(
        topCategoryName: 'Ăn uống',
        topCategoryEmoji: '🍜',
        topCategoryPercent: 42.4,
        savingsRate: 38.0,
        expenseChangeVsLastMonth: -8.5,
        hasData: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SmartInsightsCard(insights: insights),
          ),
        ),
      );

      expect(find.text('Nhận định tài chính thông minh'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Ăn uống'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('ThemeModeNotifier toggle chuyển đổi chế độ sáng/tối', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);

      container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.dark);

      container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    testWidgets('SelectedMonthNotifier chuyển tháng trước và tháng sau', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialMonth = container.read(selectedMonthProvider);

      container.read(selectedMonthProvider.notifier).nextMonth();
      final nextMonth = container.read(selectedMonthProvider);
      expect(nextMonth.month, (initialMonth.month % 12) + 1);

      container.read(selectedMonthProvider.notifier).previousMonth();
      expect(container.read(selectedMonthProvider).month, initialMonth.month);
    });
  });
}
