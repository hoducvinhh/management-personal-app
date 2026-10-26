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
import 'package:personal_expense_tracker/presentation/providers/transactions_provider.dart';
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

  const uuid = Uuid();

  group('TẬP KIỂM THỬ TỰ ĐỘNG TOÀN DIỆN TẤT CẢ CHỨC NĂNG (ALL FEATURES AUTO-TEST SUITE)', () {
    late Database db;
    late CategoryRepository catRepo;
    late TransactionRepository txRepo;
    late BudgetRepository budgetRepo;

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
          category_id TEXT,
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

      // Seed categories
      final batch = db.batch();
      for (final c in DefaultCategories.all) {
        batch.insert('categories', {
          'id': c.id,
          'name': c.name,
          'type': c.type,
          'icon_code': c.iconCode,
          'color_hex': c.colorHex,
          'is_default': c.isDefault ? 1 : 0,
        });
      }
      await batch.commit();

      final dbWrapper = _TestAppDbWrapper(db);
      catRepo = CategoryRepository(dbWrapper);
      txRepo = TransactionRepository(dbWrapper);
      budgetRepo = BudgetRepository(dbWrapper);
    });

    tearDown(() async {
      await db.close();
    });

    // 1. TÍNH NĂNG GHI CHÉP GIAO DỊCH TỰ DO & KHÔNG BẮT BUỘC DANH MỤC
    test('1. Ghi chép chi tiêu tự do: Chỉ cần ghi mục đích làm gì, không gán danh mục (categoryId == null)', () async {
      final now = DateTime.now();
      final txId = uuid.v4();

      final newTx = TransactionModel(
        id: txId,
        amount: 85000,
        type: 'EXPENSE',
        categoryId: null, // Không gán danh mục
        date: now,
        note: 'Tiền sửa xe máy thay nhớt Castrol',
        createdAt: now,
      );

      await txRepo.insertTransaction(newTx);

      final fetched = await txRepo.getTransactionById(txId);
      expect(fetched, isNotNull);
      expect(fetched!.amount, 85000);
      expect(fetched.categoryId, isNull);
      expect(fetched.hasCategory, isFalse);
      expect(fetched.note, 'Tiền sửa xe máy thay nhớt Castrol');
      expect(fetched.isExpense, isTrue);

      // Kiểm tra bộ lọc UNCATEGORIZED
      final uncatList = await txRepo.getTransactions(categoryId: 'UNCATEGORIZED');
      expect(uncatList.any((t) => t.id == txId), isTrue);
    });

    // 2. TÍNH NĂNG GÁN DANH MỤC TÙY Ý VÀ CẬP NHẬT HỦY GÁN
    test('2. Gán danh mục và sau đó hủy gán (toggle category về null) thành công', () async {
      final now = DateTime.now();
      final txId = uuid.v4();

      // Ban đầu có gán danh mục Ăn uống
      await txRepo.insertTransaction(TransactionModel(
        id: txId,
        amount: 45000,
        type: 'EXPENSE',
        categoryId: 'cat_exp_food',
        date: now,
        note: 'Ăn phở bò Hà Nội',
        createdAt: now,
      ));

      var tx = await txRepo.getTransactionById(txId);
      expect(tx!.categoryId, 'cat_exp_food');
      expect(tx.hasCategory, isTrue);

      // Cập nhật hủy gán danh mục (clearCategory = true)
      final updated = tx.copyWith(clearCategory: true);
      await txRepo.updateTransaction(updated);

      final afterUpdate = await txRepo.getTransactionById(txId);
      expect(afterUpdate!.categoryId, isNull);
      expect(afterUpdate.hasCategory, isFalse);
      expect(afterUpdate.note, 'Ăn phở bò Hà Nội');
    });

    // 3. TÍNH NĂNG GHI NHẬN KHOẢN THU VÀ TÍNH TOÁN SỐ DƯ
    test('3. Thêm khoản thu và tính toán chính xác Số dư = Thu - Chi', () async {
      final now = DateTime.now();

      // Thu: Lương 20.000.000 ₫
      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 20000000,
        type: 'INCOME',
        categoryId: 'cat_inc_salary',
        date: now,
        note: 'Lương tháng 10',
        createdAt: now,
      ));

      // Chi 1: Tiền nhà 4.500.000 ₫ (có danh mục)
      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 4500000,
        type: 'EXPENSE',
        categoryId: 'cat_exp_housing',
        date: now,
        note: 'Tiền thuê trọ',
        createdAt: now,
      ));

      // Chi 2: Mua đồ linh tinh 500.000 ₫ (KHÔNG danh mục)
      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 500000,
        type: 'EXPENSE',
        categoryId: null,
        date: now,
        note: 'Mua đồ linh tinh chợ đêm',
        createdAt: now,
      ));

      final start = AppDateUtils.startOfMonth(now);
      final end = AppDateUtils.endOfMonth(now);
      final summary = await txRepo.getMonthlySummary(start, end);

      expect(summary.income, 20000000);
      expect(summary.expense, 5000000); // 4.5Tr + 0.5Tr = 5Tr
      expect(summary.balance, 15000000); // 20Tr - 5Tr = 15Tr
    });

    // 4. TÍNH NĂNG TÌM KIẾM ĐA NĂNG (GHI CHÚ, SỐ TIỀN, TỪ KHÓA)
    test('4. Tìm kiếm nâng cao: Tìm theo nội dung làm gì, tên danh mục, hoặc chuỗi số tiền', () async {
      final now = DateTime.now();

      await txRepo.insertTransaction(TransactionModel(
        id: 'tx_coffee',
        amount: 35000,
        type: 'EXPENSE',
        categoryId: null,
        date: now,
        note: 'Cà phê vỉa hè góc phố',
        createdAt: now,
      ));

      await txRepo.insertTransaction(TransactionModel(
        id: 'tx_laptop',
        amount: 18500000,
        type: 'EXPENSE',
        categoryId: 'cat_exp_shopping',
        date: now,
        note: 'Nâng cấp Macbook Pro M3',
        createdAt: now,
      ));

      // Tìm theo từ khóa "vỉa hè" trong ghi chú
      final r1 = await txRepo.getTransactions(searchQuery: 'vỉa hè');
      expect(r1.length, 1);
      expect(r1.first.id, 'tx_coffee');

      // Tìm theo chuỗi số tiền "18500000"
      final r2 = await txRepo.getTransactions(searchQuery: '18500000');
      expect(r2.length, 1);
      expect(r2.first.id, 'tx_laptop');
    });

    // 5. TÍNH NĂNG THỐNG KÊ CƠ CẤU VÀ TỰ ĐỘNG GOM "CHƯA PHÂN LOẠI"
    test('5. Thống kê chi tiêu gom nhóm chính xác các khoản chưa phân loại vào nhóm Chưa phân loại', () async {
      final now = DateTime.now();
      final start = AppDateUtils.startOfMonth(now);
      final end = AppDateUtils.endOfMonth(now);

      // Chi có danh mục Ăn uống: 300.000 ₫
      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 300000,
        type: 'EXPENSE',
        categoryId: 'cat_exp_food',
        date: now,
        createdAt: now,
      ));

      // Chi KHÔNG danh mục: 100.000 ₫
      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 100000,
        type: 'EXPENSE',
        categoryId: null,
        date: now,
        note: 'Tiền taxi',
        createdAt: now,
      ));

      final breakdown = await txRepo.getCategoryExpenseBreakdown(start, end);
      expect(breakdown.length, 2);

      // Mục 1: Ăn uống (300k / 400k = 75%)
      expect(breakdown[0].category.name, 'Ăn uống');
      expect(breakdown[0].totalAmount, 300000);
      expect(breakdown[0].percentage, 75.0);

      // Mục 2: Chưa phân loại (100k / 400k = 25%)
      expect(breakdown[1].category.name, 'Chưa phân loại');
      expect(breakdown[1].totalAmount, 100000);
      expect(breakdown[1].percentage, 25.0);
    });

    // 6. TÍNH NĂNG NGÂN SÁCH ĐƠN & 3 CẤP ĐỘ CẢNH BÁO
    test('6. Ngân sách tổng tháng: Tính toán tiến độ chi tiêu và màu sắc cảnh báo theo 3 cấp độ', () async {
      const monthKey = '2026-10';
      final now = AppDateUtils.fromMonthKey(monthKey);

      // Đặt ngân sách 10.000.000 ₫
      await budgetRepo.setBudget(
        monthKey: monthKey,
        limitAmount: 10000000,
        categoryId: null,
      );

      // Kịch bản A: Chi 5.000.000 ₫ (50%) -> Cấp 1: Xanh an toàn
      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 5000000,
        type: 'EXPENSE',
        categoryId: null,
        date: now,
        createdAt: now,
      ));

      var budget = await budgetRepo.getOverallBudget(monthKey);
      expect(budget!.spentAmount, 5000000);
      expect(budget.percentSpent, 0.5);
      expect(budget.remainingAmount, 5000000);
      expect(budget.isOverBudget, isFalse);
      expect(AppColors.getBudgetColor(budget.percentSpent), AppColors.budgetSafe);

      // Kịch bản B: Chi thêm 3.000.000 ₫ (Tổng 80%) -> Cấp 2: Hổ phách cảnh báo
      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 3000000,
        type: 'EXPENSE',
        categoryId: null,
        date: now,
        createdAt: now,
      ));

      budget = await budgetRepo.getOverallBudget(monthKey);
      expect(budget!.percentSpent, 0.8);
      expect(AppColors.getBudgetColor(budget.percentSpent), AppColors.budgetWarning);

      // Kịch bản C: Chi thêm 2.500.000 ₫ (Tổng 105%) -> Cấp 3: Đỏ báo động vượt trần
      await txRepo.insertTransaction(TransactionModel(
        id: uuid.v4(),
        amount: 2500000,
        type: 'EXPENSE',
        categoryId: null,
        date: now,
        createdAt: now,
      ));

      budget = await budgetRepo.getOverallBudget(monthKey);
      expect(budget!.isOverBudget, isTrue);
      expect(budget.overBudgetAmount, 500000); // Vượt 500k
      expect(AppColors.getBudgetColor(budget.percentSpent), AppColors.budgetDanger);
    });

    // 7. TÍNH NĂNG TÙY BIẾN DANH MỤC
    test('7. Tạo danh mục người dùng tự định nghĩa và xóa danh mục tùy biến', () async {
      const customCat = CategoryModel(
        id: 'cat_custom_hobby',
        name: 'Đồ chơi mô hình Gundam',
        type: 'EXPENSE',
        iconCode: 'toys',
        colorHex: '#EC4899',
        isDefault: false,
      );

      await catRepo.insertCategory(customCat);

      final fetched = await catRepo.getCategoryById('cat_custom_hobby');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Đồ chơi mô hình Gundam');

      // Xóa danh mục tùy biến
      await catRepo.deleteCategory('cat_custom_hobby');
      expect(await catRepo.getCategoryById('cat_custom_hobby'), isNull);

      // Thử xóa danh mục mặc định -> Không cho phép
      await catRepo.deleteCategory('cat_exp_food');
      expect(await catRepo.getCategoryById('cat_exp_food'), isNotNull);
    });

    // 8. TÍNH NĂNG QUẢN LÝ TRẠNG THÁI RIVERPOD
    test('8. State Management: Chuyển tháng và thay đổi bộ lọc lịch sử hoạt động chính xác', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Chuyển tháng
      final currentMonth = container.read(selectedMonthProvider);
      container.read(selectedMonthProvider.notifier).nextMonth();
      final nextMonth = container.read(selectedMonthProvider);
      expect(nextMonth.month, (currentMonth.month % 12) + 1);

      // Đổi bộ lọc lịch sử
      container.read(historyFilterProvider.notifier).setType('EXPENSE');
      expect(container.read(historyFilterProvider).type, 'EXPENSE');

      container.read(historyFilterProvider.notifier).setCategoryId('UNCATEGORIZED');
      expect(container.read(historyFilterProvider).categoryId, 'UNCATEGORIZED');

      container.read(historyFilterProvider.notifier).setSearchQuery('cà phê');
      expect(container.read(historyFilterProvider).searchQuery, 'cà phê');
    });

    // 9. TÍNH NĂNG GIAO DIỆN WIDGET: HIỂN THỊ ITEM GIAO DỊCH KHI CÓ VÀ KHÔNG CÓ DANH MỤC
    testWidgets('9. UI Widget: TransactionItemTile ưu tiên hiển thị mục đích làm gì và hiển thị Chưa phân loại khi không gán danh mục', (tester) async {
      // Trường hợp A: Có ghi chú "Mua quà Tết", không gán danh mục
      final txA = TransactionModel(
        id: 'tx_a',
        amount: 350000,
        type: 'EXPENSE',
        categoryId: null,
        date: DateTime.now(),
        note: 'Mua quà Tết biếu bố mẹ',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionItemTile(transaction: txA),
          ),
        ),
      );

      // Tiêu đề chính phải là mục đích làm gì
      expect(find.text('Mua quà Tết biếu bố mẹ'), findsOneWidget);
      // Phụ đề phải là Chưa phân loại
      expect(find.text('Chưa phân loại'), findsOneWidget);
      expect(find.text(CurrencyUtils.formatSigned(350000, 'EXPENSE')), findsOneWidget);

      // Trường hợp B: Có cả ghi chú và danh mục
      final txB = TransactionModel(
        id: 'tx_b',
        amount: 55000,
        type: 'EXPENSE',
        categoryId: 'cat_food',
        date: DateTime.now(),
        note: 'Cơm tấm sườn bì chả',
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
            body: TransactionItemTile(transaction: txB),
          ),
        ),
      );

      expect(find.text('Cơm tấm sườn bì chả'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
    });

    // 10. TÍNH NĂNG GIAO DIỆN WIDGET: THẺ SỐ DƯ AURORA HERO CARD
    testWidgets('10. UI Widget: BalanceHeroCard hiển thị đầy đủ dải chuyển sắc, số dư và trạng thái Dương/Âm', (tester) async {
      const summary = MonthlySummary(
        income: 30000000,
        expense: 12500000,
        balance: 17500000,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BalanceHeroCard(summary: summary),
          ),
        ),
      );

      expect(find.text('Số dư tháng này'), findsOneWidget);
      expect(find.text(CurrencyUtils.format(17500000)), findsOneWidget);
      expect(find.text('Dương'), findsOneWidget);
      expect(find.text('Tổng thu'), findsOneWidget);
      expect(find.text(CurrencyUtils.format(30000000)), findsOneWidget);
      expect(find.text('Tổng chi'), findsOneWidget);
      expect(find.text(CurrencyUtils.format(12500000)), findsOneWidget);
    });

    // 11. TÍNH NĂNG GIAO DIỆN WIDGET: MINI BUDGET GAUGE
    testWidgets('11. UI Widget: MiniBudgetGauge hiển thị thanh tiến độ trực quan', (tester) async {
      const budget = BudgetModel(
        id: 'b_test',
        monthKey: '2026-10',
        limitAmount: 20000000,
        spentAmount: 14000000, // 70%
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
      expect(find.text('70%'), findsOneWidget);
      expect(find.textContaining('Đã chi:'), findsOneWidget);
      expect(find.textContaining('Còn lại:'), findsOneWidget);
    });

    // 12. TÍNH NĂNG GIAO DIỆN WIDGET: NHẬN ĐỊNH TÀI CHÍNH THÔNG MINH (SmartInsightsCard)
    testWidgets('12. UI Widget: SmartInsightsCard hiển thị nhận định danh mục lớn nhất và tỷ lệ tiết kiệm', (tester) async {
      const insights = SmartInsights(
        topCategoryName: 'Nhà cửa & Hóa đơn',
        topCategoryEmoji: '🏠',
        topCategoryPercent: 45.0,
        savingsRate: 35.0,
        expenseChangeVsLastMonth: -12.0,
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
          (w) => w is RichText && w.text.toPlainText().contains('Nhà cửa & Hóa đơn'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('35%'),
        ),
        findsOneWidget,
      );
    });

    // 13. TÍNH NĂNG GIAO DIỆN WIDGET: CHẾ ĐỘ SÁNG / TỐI (DARK / LIGHT MODE)
    testWidgets('13. UI Widget: ThemeModeNotifier chuyển đổi trơn tru giữa Chế độ sáng và Tối', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);

      container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.dark);

      container.read(themeModeProvider.notifier).toggle();
      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });
}
